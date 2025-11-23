import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class EditTicketPage extends StatefulWidget {
  final String ticketId;
  const EditTicketPage({super.key, required this.ticketId});

  @override
  State<EditTicketPage> createState() => _EditTicketPageState();
}

class _EditTicketPageState extends State<EditTicketPage> {
  Map<String, dynamic>? ticketData;
  List<Map<String, dynamic>> products = [];
  List<Map<String, dynamic>> originalProducts = []; // Pour comparer les changements
  String? activityName;
  double total = 0;
  bool loading = true;

  @override
  void initState() {
    super.initState();
    loadTicket();
  }

  Future<void> loadTicket() async {
    setState(() => loading = true);
    final doc = await FirebaseFirestore.instance.collection('tickets').doc(widget.ticketId).get();
    final data = doc.data();
    if (data == null) {
      // ticket manquant
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Ticket introuvable")));
      Navigator.pop(context);
      return;
    }
    ticketData = data;
    activityName = data['activity'] as String?;
    
    // Normalise les produits en List<Map<String,dynamic>>
    final raw = (data['products'] ?? []) as List<dynamic>;
    products = raw.map<Map<String, dynamic>>((e) {
      final m = Map<String, dynamic>.from(e as Map);
      // assure les champs nécessaires
      m['id'] = m['id']?.toString() ?? '';
      m['name'] = m['name']?.toString() ?? 'Produit';
      m['price'] = (m['price'] is num) ? (m['price'] as num).toDouble() : double.tryParse(m['price']?.toString() ?? '0') ?? 0.0;
      m['quantity'] = (m['quantity'] is int) ? m['quantity'] as int : int.tryParse(m['quantity']?.toString() ?? '1') ?? 1;
      return m;
    }).toList();

    // Sauvegarder les produits originaux pour comparer les changements
    originalProducts = products.map((p) => Map<String, dynamic>.from(p)).toList();

    _recalculateTotal();
    setState(() => loading = false);
  }


  void _recalculateTotal() {
    total = 0;
    for (var p in products) {
      final price = (p['price'] is num) ? (p['price'] as num).toDouble() : double.tryParse(p['price'].toString()) ?? 0.0;
      final qty = (p['quantity'] is int) ? p['quantity'] as int : int.tryParse(p['quantity'].toString()) ?? 1;
      total += price * qty;
    }
  }

  Future<void> _editQuantityDialog(int index) async {
    final product = products[index];
    final productName = product['name'] as String;
    final currentQty = product['quantity'] as int;
    final controller = TextEditingController(text: currentQty.toString());

    // Récupérer le stock disponible
    int availableStock = 0;
    if (activityName != null) {
      final stockQuery = await FirebaseFirestore.instance
          .collection('stock')
          .where('name', isEqualTo: productName)
          .where('activity', isEqualTo: activityName)
          .limit(1)
          .get();

      if (stockQuery.docs.isNotEmpty) {
        availableStock = (stockQuery.docs.first.data()['quantity'] ?? 0) as int;
      }
    }

    // Calculer la quantité déjà utilisée dans le ticket (hors ce produit)
    final otherProductsQty = products
        .where((p) => p['id'] == product['id'] && products.indexOf(p) != index)
        .fold<int>(0, (sum, p) => sum + (p['quantity'] as int));

    // Quantité originale de ce produit dans le ticket
    final originalQty = originalProducts
        .where((p) => p['id'] == product['id'])
        .fold<int>(0, (sum, p) => sum + (p['quantity'] as int));

    // Stock réellement disponible = stock actuel + quantité originale - autres quantités dans le ticket
    final realAvailableStock = availableStock + originalQty - otherProductsQty;

    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: Text('Modifier quantité — $productName'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('Stock disponible: $realAvailableStock'),
            const SizedBox(height: 16),
            TextField(
              controller: controller,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(labelText: 'Quantité'),
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Annuler')),
          ElevatedButton(
            onPressed: () async {
              final v = int.tryParse(controller.text) ?? 1;
              
              if (v <= 0) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('La quantité doit être supérieure à 0')),
                );
                return;
              }

              if (v > realAvailableStock) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('Stock insuffisant. Disponible: $realAvailableStock')),
                );
                return;
              }

              setState(() {
                products[index]['quantity'] = v;
                _recalculateTotal();
              });
              Navigator.pop(context);
            },
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  void _removeProduct(int index) {
    setState(() {
      products.removeAt(index);
      _recalculateTotal();
    });
  }

  Future<void> _saveTicket() async {
    if (activityName == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Impossible de déterminer l\'activité')),
      );
      return;
    }

    setState(() => loading = true);

    try {
      // Calculer les différences de stock pour chaque produit
      final Map<String, int> stockChanges = {}; // productName -> diff (positif = ajout, négatif = retrait)

      // Grouper les produits originaux par nom
      final Map<String, int> originalQuantities = {};
      for (var p in originalProducts) {
        final name = p['name'] as String;
        originalQuantities[name] = (originalQuantities[name] ?? 0) + (p['quantity'] as int);
      }

      // Grouper les nouveaux produits par nom
      final Map<String, int> newQuantities = {};
      for (var p in products) {
        final name = p['name'] as String;
        newQuantities[name] = (newQuantities[name] ?? 0) + (p['quantity'] as int);
      }

      // Calculer les différences
      final allProductNames = {...originalQuantities.keys, ...newQuantities.keys};
      for (var productName in allProductNames) {
        final originalQty = originalQuantities[productName] ?? 0;
        final newQty = newQuantities[productName] ?? 0;
        final diff = newQty - originalQty;
        
        if (diff != 0) {
          stockChanges[productName] = diff;
        }
      }

      // Appliquer les changements de stock
      for (var entry in stockChanges.entries) {
        final productName = entry.key;
        final diff = entry.value;

        // Trouver le document stock
        final stockQuery = await FirebaseFirestore.instance
            .collection('stock')
            .where('name', isEqualTo: productName)
            .where('activity', isEqualTo: activityName)
            .limit(1)
            .get();

        if (stockQuery.docs.isNotEmpty) {
          final stockRef = FirebaseFirestore.instance
              .collection('stock')
              .doc(stockQuery.docs.first.id);

          await FirebaseFirestore.instance.runTransaction((transaction) async {
            final snapshot = await transaction.get(stockRef);
            if (!snapshot.exists) return;

            final currentQty = (snapshot.data()?['quantity'] ?? 0) as int;
            final newQty = currentQty - diff; // diff est positif si on augmente la quantité dans le ticket

            if (newQty < 0) {
              throw Exception('Stock insuffisant pour $productName');
            }

            transaction.update(stockRef, {
              'quantity': newQty,
              'updatedAt': FieldValue.serverTimestamp(),
            });
          });
        }
      }

      // Mettre à jour le ticket
      await FirebaseFirestore.instance.collection('tickets').doc(widget.ticketId).update({
        'products': products,
        'total': total,
        'updatedAt': FieldValue.serverTimestamp(),
      });

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Ticket mis à jour avec succès')),
      );
      Navigator.pop(context);
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Erreur lors de la sauvegarde: $e')),
      );
    } finally {
      setState(() => loading = false);
    }
  }

  // Option : ajouter un produit existant depuis les produits de l'activité
  Future<void> _addProductManual() async {
    if (activityName == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Impossible de déterminer l\'activité')),
      );
      return;
    }

    // Charger les produits de l'activité
    final productsQuery = await FirebaseFirestore.instance
        .collection('products')
        .where('activity', isEqualTo: activityName)
        .get();

    if (productsQuery.docs.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Aucun produit disponible pour cette activité')),
      );
      return;
    }

    String? selectedProductId;
    int selectedQuantity = 1;

    await showDialog(
      context: context,
      builder: (_) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text('Ajouter produit'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              DropdownButtonFormField<String>(
                value: selectedProductId,
                decoration: const InputDecoration(labelText: 'Produit'),
                items: productsQuery.docs.map((doc) {
                  final data = doc.data();
                  return DropdownMenuItem<String>(
                    value: doc.id,
                    child: Text('${data['name']} - ${data['price']} FC'),
                  );
                }).toList(),
                onChanged: (value) {
                  setDialogState(() {
                    selectedProductId = value;
                  });
                },
              ),
              const SizedBox(height: 16),
              TextField(
                controller: TextEditingController(text: selectedQuantity.toString()),
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(labelText: 'Quantité'),
                onChanged: (value) {
                  selectedQuantity = int.tryParse(value) ?? 1;
                },
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Annuler'),
            ),
            ElevatedButton(
              onPressed: selectedProductId == null
                  ? null
                  : () async {
                      final productDoc = productsQuery.docs
                          .firstWhere((doc) => doc.id == selectedProductId);
                      final productData = productDoc.data();
                      final productName = productData['name'] as String;

                      // Vérifier le stock
                      final stockQuery = await FirebaseFirestore.instance
                          .collection('stock')
                          .where('name', isEqualTo: productName)
                          .where('activity', isEqualTo: activityName)
                          .limit(1)
                          .get();

                      int availableStock = 0;
                      if (stockQuery.docs.isNotEmpty) {
                        availableStock = (stockQuery.docs.first.data()['quantity'] ?? 0) as int;
                      }

                      // Quantité déjà dans le ticket
                      final existingQty = products
                          .where((p) => p['id'] == selectedProductId)
                          .fold<int>(0, (sum, p) => sum + (p['quantity'] as int));

                      if (selectedQuantity > (availableStock + existingQty)) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text('Stock insuffisant. Disponible: ${availableStock + existingQty}')),
                        );
                        return;
                      }

                      setState(() {
                        // Vérifier si le produit existe déjà
                        final existingIndex = products.indexWhere((p) => p['id'] == selectedProductId);
                        if (existingIndex >= 0) {
                          products[existingIndex]['quantity'] = (products[existingIndex]['quantity'] as int) + selectedQuantity;
                        } else {
                          products.add({
                            'id': selectedProductId!,
                            'name': productName,
                            'price': (productData['price'] ?? 0).toDouble(),
                            'quantity': selectedQuantity,
                          });
                        }
                        _recalculateTotal();
                      });
                      Navigator.pop(context);
                    },
              child: const Text('Ajouter'),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (loading) return const Scaffold(body: Center(child: CircularProgressIndicator()));

    return Scaffold(
      appBar: AppBar(title: const Text('Modifier Ticket',style:
        TextStyle(color: Colors.white),), backgroundColor: Colors.black, actions: [
        IconButton(onPressed: _addProductManual, icon: const Icon(Icons.add)),
        IconButton(onPressed: _saveTicket, icon: const Icon(Icons.save)),
      ]),
      body: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          children: [
            Text('Serveur: ${ticketData?['serverName'] ?? '—'}', style: const TextStyle(fontSize: 16)),
            const SizedBox(height: 8),
            Expanded(
              child: ListView.separated(
                itemCount: products.length,
                separatorBuilder: (_, __) => const Divider(),
                itemBuilder: (context, i) {
                  final p = products[i];
                  final productName = p['name'] ?? 'Produit';
                  final quantity = p['quantity'] as int;
                  final price = (p['price'] ?? 0).toDouble();
                  final subtotal = price * quantity;

                  return FutureBuilder<DocumentSnapshot?>(
                    future: activityName != null
                        ? FirebaseFirestore.instance
                            .collection('stock')
                            .where('name', isEqualTo: productName)
                            .where('activity', isEqualTo: activityName)
                            .limit(1)
                            .get()
                            .then((query) => query.docs.isNotEmpty ? query.docs.first : null)
                        : Future.value(null),
                    builder: (context, stockSnapshot) {
                      int availableStock = 0;
                      if (stockSnapshot.hasData && stockSnapshot.data != null && stockSnapshot.data!.exists) {
                        final stockData = stockSnapshot.data!.data() as Map<String, dynamic>?;
                        availableStock = (stockData?['quantity'] ?? 0) as int;
                      }

                      // Quantité déjà dans le ticket (hors ce produit)
                      final otherQty = products
                          .where((prod) => prod['id'] == p['id'] && products.indexOf(prod) != i)
                          .fold<int>(0, (sum, prod) => sum + (prod['quantity'] as int));

                      // Quantité originale
                      final originalQty = originalProducts
                          .where((prod) => prod['id'] == p['id'])
                          .fold<int>(0, (sum, prod) => sum + (prod['quantity'] as int));

                      final realAvailableStock = availableStock + originalQty - otherQty;

                      return ListTile(
                        title: Text(productName),
                        subtitle: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('Prix: ${price.toStringAsFixed(2)} FC • Qté: $quantity'),
                            Text(
                              'Sous-total: ${subtotal.toStringAsFixed(2)} FC',
                              style: const TextStyle(fontWeight: FontWeight.bold),
                            ),
                            Text(
                              'Stock disponible: $realAvailableStock',
                              style: TextStyle(
                                color: realAvailableStock > 10
                                    ? Colors.green
                                    : realAvailableStock > 0
                                        ? Colors.orange
                                        : Colors.red,
                                fontSize: 12,
                              ),
                            ),
                          ],
                        ),
                        trailing: Row(mainAxisSize: MainAxisSize.min, children: [
                          IconButton(
                            icon: const Icon(Icons.edit),
                            onPressed: () => _editQuantityDialog(i),
                          ),
                          IconButton(
                            icon: const Icon(Icons.delete),
                            onPressed: () => _removeProduct(i),
                          ),
                        ]),
                      );
                    },
                  );
                },
              ),
            ),
            const Divider(),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('Total', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                Text('${total.toStringAsFixed(2)} FC', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
              ],
            ),
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(onPressed: _saveTicket, child: const Text('Enregistrer les modifications')),
            ),
          ],
        ),
      ),
    );
  }
}