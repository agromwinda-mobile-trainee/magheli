import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../common/error_messages.dart';

class MainStockExitPage extends StatefulWidget {
  const MainStockExitPage({super.key});

  @override
  State<MainStockExitPage> createState() => _MainStockExitPageState();
}

class _MainStockExitPageState extends State<MainStockExitPage> {
  String? selectedActivityName;
  String? selectedProductId;
  String? selectedProductName;
  int availableQuantity = 0;
  String productUnit = 'unité';
  
  final quantityController = TextEditingController();
  final reasonController = TextEditingController();
  
  List<String> activities = [];
  List<Map<String, dynamic>> products = [];
  
  bool loading = false;
  bool loadingActivities = true;
  bool loadingProducts = false;

  @override
  void initState() {
    super.initState();
    _loadActivities();
  }

  Future<void> _loadActivities() async {
    try {
      final query = await FirebaseFirestore.instance
          .collection('activities')
          .orderBy('activityName')
          .get();

      setState(() {
        activities = query.docs
            .map((doc) => doc.data()['activityName'] as String? ?? '')
            .where((name) => name.isNotEmpty)
            .toList();
        loadingActivities = false;
      });
    } catch (e) {
      setState(() {
        loadingActivities = false;
      });
    }
  }

  Future<void> _loadProducts(String activityName) async {
    setState(() {
      loadingProducts = true;
      products = [];
      selectedProductId = null;
      selectedProductName = null;
      availableQuantity = 0;
      quantityController.clear();
    });

    try {
      // Charger sans orderBy pour éviter les problèmes d'index
      final query = await FirebaseFirestore.instance
          .collection('central_stock')
          .where('activity', isEqualTo: activityName)
          .where('quantity', isGreaterThan: 0)
          .get();

      setState(() {
        products = query.docs.map((doc) {
          final data = doc.data();
          return {
            'id': doc.id,
            'name': data['name'] ?? 'Produit inconnu',
            'quantity': (data['quantity'] ?? 0) as int,
            'unit': data['unit'] ?? 'unité',
          };
        }).toList();
        // Trier manuellement par nom
        products.sort((a, b) {
          final nameA = a['name'] as String;
          final nameB = b['name'] as String;
          return nameA.compareTo(nameB);
        });
        loadingProducts = false;
      });
    } catch (e) {
      setState(() {
        loadingProducts = false;
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(ErrorMessages.fromException(e)),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  void _onProductSelected(String? productId) {
    setState(() {
      selectedProductId = productId;
      if (productId != null) {
        final product = products.firstWhere((p) => p['id'] == productId);
        selectedProductName = product['name'] as String;
        availableQuantity = product['quantity'] as int;
        productUnit = product['unit'] as String;
      } else {
        selectedProductName = null;
        availableQuantity = 0;
        productUnit = 'unité';
      }
      quantityController.clear();
    });
  }

  Future<void> _saveExit() async {
    if (selectedActivityName == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Veuillez sélectionner une activité'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    if (selectedProductId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Veuillez sélectionner un produit'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    if (quantityController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(ErrorMessages.champObligatoire),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    final quantity = int.tryParse(quantityController.text);
    if (quantity == null || quantity <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(ErrorMessages.quantiteInvalide),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    if (quantity > availableQuantity) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            '${ErrorMessages.stockInsuffisant(selectedProductName ?? 'produit')}. Stock disponible: $availableQuantity $productUnit',
          ),
          backgroundColor: Colors.orange,
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
        'activity': selectedActivityName,
        'quantity': quantity,
        'type': 'exit',
        'reason': reasonController.text.trim().isEmpty
            ? 'Sortie de stock'
            : reasonController.text.trim(),
        'stockManagerId': stockManagerId,
        'stockManagerName': stockManagerName,
        'date': FieldValue.serverTimestamp(),
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Sortie enregistrée avec succès'),
            backgroundColor: Colors.green,
          ),
        );

        // Réinitialiser
        setState(() {
          selectedProductId = null;
          selectedProductName = null;
          availableQuantity = 0;
          productUnit = 'unité';
          quantityController.clear();
          reasonController.clear();
        });

        // Recharger les produits
        await _loadProducts(selectedActivityName!);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(ErrorMessages.fromException(e)),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => loading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Sortie Stock Principal", style: TextStyle(color: Colors.white)),
        backgroundColor: Colors.black,
      ),
      body: loadingActivities
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Sélection de l'activité
                  DropdownButtonFormField<String>(
                    value: selectedActivityName,
                    decoration: InputDecoration(
                      labelText: 'Activité *',
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                      prefixIcon: const Icon(Icons.business),
                    ),
                    items: activities.map((activity) {
                      return DropdownMenuItem<String>(
                        value: activity,
                        child: Text(activity),
                      );
                    }).toList(),
                    onChanged: (value) {
                      setState(() {
                        selectedActivityName = value;
                        selectedProductId = null;
                        selectedProductName = null;
                        availableQuantity = 0;
                        productUnit = 'unité';
                        quantityController.clear();
                        products = [];
                      });
                      if (value != null) {
                        _loadProducts(value);
                      }
                    },
                  ),
                  const SizedBox(height: 20),
                  // Sélection du produit
                  if (selectedActivityName != null) ...[
                    if (loadingProducts)
                      const Center(child: CircularProgressIndicator())
                    else if (products.isEmpty)
                      Card(
                        color: Colors.orange.shade50,
                        child: Padding(
                          padding: const EdgeInsets.all(16),
                          child: Column(
                            children: [
                              const Icon(Icons.warning_amber, color: Colors.orange, size: 48),
                              const SizedBox(height: 8),
                              Text(
                                'Aucun produit en stock pour "${selectedActivityName}"',
                                textAlign: TextAlign.center,
                                style: const TextStyle(fontWeight: FontWeight.bold),
                              ),
                            ],
                          ),
                        ),
                      )
                    else
                      DropdownButtonFormField<String>(
                        value: selectedProductId,
                        decoration: InputDecoration(
                          labelText: 'Produit *',
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                          prefixIcon: const Icon(Icons.inventory_2),
                        ),
                        items: products.map((product) {
                          final qty = product['quantity'] as int;
                          final unit = product['unit'] as String;
                          return DropdownMenuItem<String>(
                            value: product['id'] as String,
                            child: Text(
                              '${product['name']} ($qty $unit${qty > 1 ? 's' : ''})',
                              overflow: TextOverflow.ellipsis,
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
                                'Stock disponible: $availableQuantity $productUnit${availableQuantity > 1 ? 's' : ''}',
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
                  ],
                  // Quantité
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
                  // Raison
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
