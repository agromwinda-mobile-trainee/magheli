import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class MainStockExitPage extends StatefulWidget {
  const MainStockExitPage({super.key});

  @override
  State<MainStockExitPage> createState() => _MainStockExitPageState();
}

class _MainStockExitPageState extends State<MainStockExitPage> {
  String? selectedProductId;
  String? selectedProductName;
  int availableQuantity = 0;
  final quantityController = TextEditingController();
  final reasonController = TextEditingController();
  List<Map<String, dynamic>> products = [];
  bool loading = false;

  @override
  void initState() {
    super.initState();
    _loadProducts();
  }

  Future<void> _loadProducts() async {
    final query = await FirebaseFirestore.instance
        .collection('central_stock')
        .where('quantity', isGreaterThan: 0)
        .get();

    setState(() {
      products = query.docs.map((doc) {
        final data = doc.data();
        return {
          'id': doc.id,
          'name': data['name'] ?? 'Produit inconnu',
          'quantity': data['quantity'] ?? 0,
          'unit': data['unit'] ?? 'unité',
        };
      }).toList();
    });
  }

  void _onProductSelected(String? productId) {
    setState(() {
      selectedProductId = productId;
      if (productId != null) {
        final product = products.firstWhere((p) => p['id'] == productId);
        selectedProductName = product['name'];
        availableQuantity = product['quantity'] as int;
      } else {
        selectedProductName = null;
        availableQuantity = 0;
      }
      quantityController.clear();
    });
  }

  Future<void> _saveExit() async {
    if (selectedProductId == null || quantityController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Veuillez sélectionner un produit et saisir la quantité')),
      );
      return;
    }

    final quantity = int.tryParse(quantityController.text);
    if (quantity == null || quantity <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Quantité invalide')),
      );
      return;
    }

    if (quantity > availableQuantity) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Quantité insuffisante. Stock disponible: $availableQuantity',
          ),
        ),
      );
      return;
    }

    setState(() => loading = true);

    try {
      final user = FirebaseAuth.instance.currentUser;
      final stockManagerId = user?.uid ?? '';
      
      final prefs = await SharedPreferences.getInstance();
      final stockManagerName = prefs.getString("fullName") ?? "Gestionnaire Stock";

      final productRef = FirebaseFirestore.instance
          .collection('central_stock')
          .doc(selectedProductId!);

      // Déduire du stock
      await FirebaseFirestore.instance.runTransaction((transaction) async {
        final snapshot = await transaction.get(productRef);
        final currentQty = (snapshot.data()?['quantity'] ?? 0) as int;
        final newQty = currentQty - quantity;

        if (newQty < 0) {
          throw Exception('Stock insuffisant');
        }

        transaction.update(productRef, {
          'quantity': newQty,
          'updatedAt': FieldValue.serverTimestamp(),
        });
      });

      // Enregistrer la sortie dans l'historique
      await FirebaseFirestore.instance.collection('stock_movements').add({
        'productName': selectedProductName,
        'quantity': quantity,
        'type': 'exit',
        'reason': reasonController.text.trim().isEmpty
            ? 'Sortie de stock'
            : reasonController.text.trim(),
        'stockManagerId': stockManagerId,
        'stockManagerName': stockManagerName,
        'date': FieldValue.serverTimestamp(),
      });

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Sortie enregistrée avec succès')),
      );

      // Réinitialiser
      setState(() {
        selectedProductId = null;
        selectedProductName = null;
        availableQuantity = 0;
        quantityController.clear();
        reasonController.clear();
      });

      // Recharger les produits
      await _loadProducts();
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Erreur: $e')),
      );
    } finally {
      setState(() => loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Sortie Stock", style: TextStyle(color: Colors.white)),
        backgroundColor: Colors.black,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            DropdownButtonFormField<String>(
              value: selectedProductId,
              decoration: InputDecoration(
                labelText: 'Produit *',
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                prefixIcon: const Icon(Icons.inventory_2),
              ),
              items: products.map((product) {
                return DropdownMenuItem<String>(
                  value: product['id'] as String,
                  child: Text(
                    '${product['name']} (${product['quantity']} ${product['unit']}${(product['quantity'] as int) > 1 ? 's' : ''})',
                  ),
                );
              }).toList(),
              onChanged: _onProductSelected,
            ),
            if (selectedProductId != null) ...[
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.blue.shade50,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.blue.shade200),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.info_outline, color: Colors.blue),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Stock disponible: $availableQuantity ${products.firstWhere((p) => p['id'] == selectedProductId)['unit']}${availableQuantity > 1 ? 's' : ''}',
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          color: Colors.blue,
                        ),
                        overflow: TextOverflow.ellipsis,
                        maxLines: 2,
                      ),
                    ),
                  ],
                ),
              ),
            ],
            const SizedBox(height: 16),
            TextField(
              controller: quantityController,
              keyboardType: TextInputType.number,
              decoration: InputDecoration(
                labelText: 'Quantité à sortir *',
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                prefixIcon: const Icon(Icons.remove_circle),
              ),
              enabled: selectedProductId != null,
            ),
            const SizedBox(height: 16),
            TextField(
              controller: reasonController,
              decoration: InputDecoration(
                labelText: 'Raison / Destination (optionnel)',
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                prefixIcon: const Icon(Icons.description),
              ),
              maxLines: 3,
              enabled: selectedProductId != null,
            ),
            const SizedBox(height: 30),
            ElevatedButton(
              onPressed: (loading || selectedProductId == null) ? null : _saveExit,
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red,
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: loading
                  ? const CircularProgressIndicator(color: Colors.white)
                  : const Text(
                      'Enregistrer la sortie',
                      style: TextStyle(color: Colors.white, fontSize: 18),
                    ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  void dispose() {
    quantityController.dispose();
    reasonController.dispose();
    super.dispose();
  }
}


