import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class MainStockEntryPage extends StatefulWidget {
  const MainStockEntryPage({super.key});

  @override
  State<MainStockEntryPage> createState() => _MainStockEntryPageState();
}

class _MainStockEntryPageState extends State<MainStockEntryPage> {
  final productNameController = TextEditingController();
  final quantityController = TextEditingController();
  final unitController = TextEditingController();
  final reasonController = TextEditingController();
  bool loading = false;
  bool isNewProduct = true;

  @override
  void initState() {
    super.initState();
    unitController.text = 'unité'; // Valeur par défaut
  }

  Future<void> _saveEntry() async {
    if (productNameController.text.isEmpty ||
        quantityController.text.isEmpty ||
        unitController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Veuillez remplir tous les champs obligatoires')),
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

    setState(() => loading = true);

    try {
      final user = FirebaseAuth.instance.currentUser;
      final stockManagerId = user?.uid ?? '';
      
      final prefs = await SharedPreferences.getInstance();
      final stockManagerName = prefs.getString("fullName") ?? "Gestionnaire Stock";

      final productName = productNameController.text.trim();
      final unit = unitController.text.trim();

      // Vérifier si le produit existe déjà
      final existingProducts = await FirebaseFirestore.instance
          .collection('central_stock')
          .where('name', isEqualTo: productName)
          .get();

      if (existingProducts.docs.isNotEmpty) {
        // Produit existant : mettre à jour la quantité
        final productDoc = existingProducts.docs.first;
        final productRef = FirebaseFirestore.instance
            .collection('central_stock')
            .doc(productDoc.id);

        await FirebaseFirestore.instance.runTransaction((transaction) async {
          final snapshot = await transaction.get(productRef);
          final currentQty = (snapshot.data()?['quantity'] ?? 0) as int;
          final newQty = currentQty + quantity;

          transaction.update(productRef, {
            'quantity': newQty,
            'updatedAt': FieldValue.serverTimestamp(),
          });
        });

        isNewProduct = false;
      } else {
        // Nouveau produit : créer le document
        await FirebaseFirestore.instance.collection('central_stock').add({
          'name': productName,
          'quantity': quantity,
          'unit': unit,
          'createdAt': FieldValue.serverTimestamp(),
          'updatedAt': FieldValue.serverTimestamp(),
        });

        isNewProduct = true;
      }

      // Enregistrer l'entrée dans l'historique
      await FirebaseFirestore.instance.collection('stock_movements').add({
        'productName': productName,
        'quantity': quantity,
        'type': 'entry',
        'reason': reasonController.text.trim().isEmpty
            ? 'Entrée de stock'
            : reasonController.text.trim(),
        'stockManagerId': stockManagerId,
        'stockManagerName': stockManagerName,
        'date': FieldValue.serverTimestamp(),
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            isNewProduct
                ? 'Produit créé et entrée enregistrée'
                : 'Stock mis à jour avec succès',
          ),
        ),
      );

      // Réinitialiser les champs
      productNameController.clear();
      quantityController.clear();
      reasonController.clear();
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
        title: const Text("Entrée Stock", style: TextStyle(color: Colors.white)),
        backgroundColor: Colors.black,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            TextField(
              controller: productNameController,
              decoration: InputDecoration(
                labelText: 'Nom du produit *',
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                prefixIcon: const Icon(Icons.inventory_2),
              ),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  flex: 2,
                  child: TextField(
                    controller: quantityController,
                    keyboardType: TextInputType.number,
                    decoration: InputDecoration(
                      labelText: 'Quantité *',
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      prefixIcon: const Icon(Icons.numbers),
                    ),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: TextField(
                    controller: unitController,
                    decoration: InputDecoration(
                      labelText: 'Unité *',
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      hintText: 'unité',
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            TextField(
              controller: reasonController,
              decoration: InputDecoration(
                labelText: 'Raison / Description (optionnel)',
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                prefixIcon: const Icon(Icons.description),
              ),
              maxLines: 3,
            ),
            const SizedBox(height: 30),
            ElevatedButton(
              onPressed: loading ? null : _saveEntry,
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.green,
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: loading
                  ? const CircularProgressIndicator(color: Colors.white)
                  : const Text(
                      'Enregistrer l\'entrée',
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
    productNameController.dispose();
    quantityController.dispose();
    unitController.dispose();
    reasonController.dispose();
    super.dispose();
  }
}

