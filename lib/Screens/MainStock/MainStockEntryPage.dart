import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../common/error_messages.dart';

class MainStockEntryPage extends StatefulWidget {
  const MainStockEntryPage({super.key});

  @override
  State<MainStockEntryPage> createState() => _MainStockEntryPageState();
}

class _MainStockEntryPageState extends State<MainStockEntryPage> {
  final quantityController = TextEditingController();
  final unitController = TextEditingController();
  final reasonController = TextEditingController();
  
  String? selectedActivityName;
  String? selectedProductId;
  String? selectedProductName;
  
  List<String> activities = [];
  List<Map<String, dynamic>> products = [];
  
  bool loading = false;
  bool loadingActivities = true;
  bool loadingProducts = false;

  @override
  void initState() {
    super.initState();
    unitController.text = 'unité'; // Valeur par défaut
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

  Future<void> _loadProducts(String activityName) async {
    setState(() {
      loadingProducts = true;
      products = [];
      selectedProductId = null;
      selectedProductName = null;
    });

    try {
      final query = await FirebaseFirestore.instance
          .collection('products')
          .where('activity', isEqualTo: activityName)
          .orderBy('name')
          .get();

      setState(() {
        products = query.docs.map((doc) {
          final data = doc.data();
          return {
            'id': doc.id,
            'name': data['name'] ?? 'Produit inconnu',
            'unit': data['unit'] ?? 'unité',
          };
        }).toList();
        loadingProducts = false;
      });

      // Si un seul produit, le sélectionner automatiquement
      if (products.length == 1) {
        setState(() {
          selectedProductId = products[0]['id'] as String;
          selectedProductName = products[0]['name'] as String;
          unitController.text = products[0]['unit'] as String? ?? 'unité';
        });
      }
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

  Future<void> _saveEntry() async {
    if (selectedActivityName == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Veuillez sélectionner une activité'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    if (selectedProductId == null || selectedProductName == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Veuillez sélectionner un produit'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    if (quantityController.text.isEmpty || unitController.text.isEmpty) {
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

    setState(() => loading = true);

    try {
      final user = FirebaseAuth.instance.currentUser;
      final stockManagerId = user?.uid ?? '';
      
      final prefs = await SharedPreferences.getInstance();
      final stockManagerName = prefs.getString("fullName") ?? "Gestionnaire Stock";

      final productName = selectedProductName!;
      final unit = unitController.text.trim();
      final activityName = selectedActivityName!;

      // Vérifier si le produit existe déjà dans le stock principal pour cette activité
      final existingProducts = await FirebaseFirestore.instance
          .collection('central_stock')
          .where('name', isEqualTo: productName)
          .where('activity', isEqualTo: activityName)
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
            'unit': unit, // Mettre à jour l'unité si elle a changé
            'updatedAt': FieldValue.serverTimestamp(),
          });
        });
      } else {
        // Nouveau produit : créer le document
        await FirebaseFirestore.instance.collection('central_stock').add({
          'name': productName,
          'activity': activityName,
          'productId': selectedProductId, // Référence au produit original
          'quantity': quantity,
          'unit': unit,
          'createdAt': FieldValue.serverTimestamp(),
          'updatedAt': FieldValue.serverTimestamp(),
        });
      }

      // Enregistrer l'entrée dans l'historique
      await FirebaseFirestore.instance.collection('stock_movements').add({
        'productName': productName,
        'activity': activityName,
        'quantity': quantity,
        'type': 'entry',
        'reason': reasonController.text.trim().isEmpty
            ? 'Entrée de stock'
            : reasonController.text.trim(),
        'stockManagerId': stockManagerId,
        'stockManagerName': stockManagerName,
        'date': FieldValue.serverTimestamp(),
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Stock mis à jour avec succès'),
            backgroundColor: Colors.green,
          ),
        );

        // Réinitialiser les champs
        quantityController.clear();
        reasonController.clear();
        selectedProductId = null;
        selectedProductName = null;
        unitController.text = 'unité';
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
        title: const Text("Entrée Stock Principal", style: TextStyle(color: Colors.white)),
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
                        products = [];
                        quantityController.clear();
                        unitController.text = 'unité';
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
                                'Aucun produit trouvé pour "${selectedActivityName}"',
                                textAlign: TextAlign.center,
                                style: const TextStyle(fontWeight: FontWeight.bold),
                              ),
                              const SizedBox(height: 8),
                              Text(
                                'Veuillez d\'abord créer des produits pour cette activité dans la section "Gérer Produits"',
                                textAlign: TextAlign.center,
                                style: TextStyle(color: Colors.grey[700]),
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
                          return DropdownMenuItem<String>(
                            value: product['id'] as String,
                            child: Text(product['name'] as String),
                          );
                        }).toList(),
                        onChanged: (value) {
                          setState(() {
                            selectedProductId = value;
                            if (value != null) {
                              final product = products.firstWhere((p) => p['id'] == value);
                              selectedProductName = product['name'] as String;
                              unitController.text = product['unit'] as String? ?? 'unité';
                            } else {
                              selectedProductName = null;
                              unitController.text = 'unité';
                            }
                          });
                        },
                      ),
                    const SizedBox(height: 20),
                  ],
                  // Quantité et Unité
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
                  // Raison
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
    quantityController.dispose();
    unitController.dispose();
    reasonController.dispose();
    super.dispose();
  }
}
