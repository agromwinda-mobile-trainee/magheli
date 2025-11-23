import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

class ActivityStockEntryPage extends StatefulWidget {
  final String activityName;
  const ActivityStockEntryPage({super.key, required this.activityName});

  @override
  State<ActivityStockEntryPage> createState() => _ActivityStockEntryPageState();
}

class _ActivityStockEntryPageState extends State<ActivityStockEntryPage> {
  final productNameController = TextEditingController();
  final quantityController = TextEditingController();
  final unitController = TextEditingController();
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
        const SnackBar(content: Text('Veuillez remplir tous les champs')),
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

      final productName = productNameController.text.trim();
      final unit = unitController.text.trim();

      // Vérifier si le produit existe déjà dans le stock de l'activité
      final existingProducts = await FirebaseFirestore.instance
          .collection('stock')
          .where('name', isEqualTo: productName)
          .where('activity', isEqualTo: widget.activityName)
          .get();

      if (existingProducts.docs.isNotEmpty) {
        // Produit existant : mettre à jour la quantité
        final productDoc = existingProducts.docs.first;
        final productRef = FirebaseFirestore.instance
            .collection('stock')
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
        await FirebaseFirestore.instance.collection('stock').add({
          'name': productName,
          'activity': widget.activityName,
          'quantity': quantity,
          'unit': unit,
          'createdAt': FieldValue.serverTimestamp(),
          'updatedAt': FieldValue.serverTimestamp(),
        });

        isNewProduct = true;
      }

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            isNewProduct
                ? 'Produit créé et stock mis à jour'
                : 'Stock mis à jour avec succès',
          ),
        ),
      );

      // Réinitialiser les champs
      productNameController.clear();
      quantityController.clear();
      unitController.clear();
      unitController.text = 'unité';
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
        title: Text("Stock - ${widget.activityName}", style: const TextStyle(color: Colors.white)),
        backgroundColor: Colors.black,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Card(
              color: Colors.blue.shade50,
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  children: [
                    const Text(
                      'Activité',
                      style: TextStyle(
                        fontSize: 14,
                        color: Colors.grey,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      widget.activityName,
                      style: const TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 24),
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
                      'Enregistrer',
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
    super.dispose();
  }
}

