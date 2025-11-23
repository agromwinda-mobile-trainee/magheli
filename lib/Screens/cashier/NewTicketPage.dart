import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class NewTicketPage extends StatefulWidget {
  final String activityName;
  final String cashierId;

  const NewTicketPage({
    super.key,
    required this.activityName,
    required this.cashierId,
  });

  @override
  State<NewTicketPage> createState() => _NewTicketPageState();
}

class _NewTicketPageState extends State<NewTicketPage> {
  List<Map<String, dynamic>> selectedProducts = [];
  double total = 0;

  String? selectedServerId;
  String? selectedServerName;

  List<Map<String, dynamic>> servers = [];

  @override
  void initState() {
    super.initState();
    _loadServers();
  }

  Future<void> _loadServers() async {
    final query = await FirebaseFirestore.instance
        .collection('servers')
        .where('activity', isEqualTo: widget.activityName)
        .get();

    setState(() {
      servers = query.docs.map((e) {
        final data = e.data();

        return {
          'id': e.id,
          'name': (data['fullName'] ?? 'Serveur inconnu'),
        };
      }).toList();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Nouveau Ticket • ${widget.activityName}',
          style: TextStyle(color: Colors.white),),
        backgroundColor: Colors.black,
      ),
      body: Column(
        children: [
          _buildServerSelector(),
          const Divider(height: 1),
          Expanded(child: _buildProductList()),
          _buildCartSummary(),
        ],
      ),
    );
  }

  // 🔹 Sélection du serveur
  Widget _buildServerSelector() {
    return Container(
      padding: const EdgeInsets.all(12),
      color: Colors.grey[100],
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            "Serveur",
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          DropdownButtonFormField<String>(
            value: selectedServerId,
            decoration: InputDecoration(
              filled: true,
              fillColor: Colors.white,
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
            ),
              items: servers.map<DropdownMenuItem<String>>((server) {
                return DropdownMenuItem<String>(
                  value: server['id'] as String,
                  child: Text(server['name'] as String),
                );
              }).toList(),
            onChanged: (value) {
              setState(() {
                selectedServerId = value;
                selectedServerName = servers
                    .firstWhere((s) => s['id'] == value)['name'];
              });
            },
          ),
        ],
      ),
    );
  }

  // 🔹 Liste des produits
  Widget _buildProductList() {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('products')
          .where('activity', isEqualTo: widget.activityName)
          .snapshots(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
        final products = snapshot.data!.docs;
        return ListView.builder(
          itemCount: products.length,
          itemBuilder: (context, index) {
            final product = products[index];
            return FutureBuilder<DocumentSnapshot?>(
              future: FirebaseFirestore.instance
                  .collection('stock')
                  .where('name', isEqualTo: product['name'])
                  .where('activity', isEqualTo: widget.activityName)
                  .limit(1)
                  .get()
                  .then((query) => query.docs.isNotEmpty ? query.docs.first : null),
              builder: (context, stockSnapshot) {
                int availableStock = 0;
                if (stockSnapshot.hasData && stockSnapshot.data != null && stockSnapshot.data!.exists) {
                  final stockData = stockSnapshot.data!.data() as Map<String, dynamic>?;
                  availableStock = (stockData?['quantity'] ?? 0) as int;
                }

                // Calculer la quantité déjà sélectionnée pour ce produit
                final selectedQty = selectedProducts
                    .where((p) => p['id'] == product.id)
                    .fold<int>(0, (sum, p) => sum + (p['quantity'] as int));

                final remainingStock = availableStock - selectedQty;
                final canAdd = remainingStock > 0;

                return ListTile(
                  title: Text(product['name']),
                  subtitle: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('${product['price']} FC'),
                      Text(
                        'Stock: $remainingStock / $availableStock',
                        style: TextStyle(
                          color: remainingStock > 10
                              ? Colors.green
                              : remainingStock > 0
                                  ? Colors.orange
                                  : Colors.red,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      if (selectedQty > 0)
                        Text(
                          'Dans le panier: $selectedQty',
                          style: const TextStyle(
                            color: Colors.blue,
                            fontSize: 12,
                          ),
                        ),
                    ],
                  ),
                  trailing: IconButton(
                    icon: Icon(
                      Icons.add_circle,
                      color: canAdd ? Colors.green : Colors.grey,
                    ),
                    onPressed: canAdd ? () => _addProduct(product) : null,
                  ),
                );
              },
            );
          },
        );
      },
    );
  }

  // 🔹 Résumé + bouton valider
  Widget _buildCartSummary() {
    final bool canValidate =
        selectedProducts.isNotEmpty && selectedServerId != null;

    return Container(
      padding: const EdgeInsets.all(16),
      color: Colors.grey[200],
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Liste des produits sélectionnés
          if (selectedProducts.isNotEmpty) ...[
            const Text(
              'Produits sélectionnés:',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            ...selectedProducts.map((product) => Padding(
                  padding: const EdgeInsets.symmetric(vertical: 4),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text('${product['name']} x${product['quantity']}'),
                      Text('${((product['price'] as double) * (product['quantity'] as int)).toStringAsFixed(2)} FC'),
                    ],
                  ),
                )),
            const Divider(),
          ],
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('Total: FC${total.toStringAsFixed(2)}',
                  style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
              ElevatedButton(
                onPressed: canValidate ? _createTicket : null,
                style: ElevatedButton.styleFrom(backgroundColor: Colors.black),
                child: const Text('Valider', style: TextStyle(color: Colors.white)),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // 🔹 Ajout produit (avec regroupement si même produit)
  Future<void> _addProduct(QueryDocumentSnapshot product) async {
    final productId = product.id;
    final productName = product['name'] as String;
    final productPrice = (product['price'] ?? 0).toDouble();

    // Vérifier le stock disponible
    final stockQuery = await FirebaseFirestore.instance
        .collection('stock')
        .where('name', isEqualTo: productName)
        .where('activity', isEqualTo: widget.activityName)
        .limit(1)
        .get();

    if (stockQuery.docs.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Produit "$productName" non trouvé dans le stock de l\'activité')),
      );
      return;
    }

    final stockDoc = stockQuery.docs.first;
    final availableStock = (stockDoc.data()['quantity'] ?? 0) as int;

    // Calculer la quantité déjà sélectionnée pour ce produit
    final selectedQty = selectedProducts
        .where((p) => p['id'] == productId)
        .fold<int>(0, (sum, p) => sum + (p['quantity'] as int));

    if (selectedQty >= availableStock) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Stock insuffisant pour "$productName". Stock disponible: $availableStock')),
      );
      return;
    }

    setState(() {
      // Vérifier si le produit est déjà dans la liste
      final existingIndex = selectedProducts.indexWhere((p) => p['id'] == productId);

      if (existingIndex >= 0) {
        // Produit déjà présent : augmenter la quantité
        selectedProducts[existingIndex]['quantity'] = (selectedProducts[existingIndex]['quantity'] as int) + 1;
        total += productPrice;
      } else {
        // Nouveau produit : l'ajouter
        selectedProducts.add({
          'id': productId,
          'name': productName,
          'price': productPrice,
          'quantity': 1,
        });
        total += productPrice;
      }
    });
  }

  // 🔹 Enregistrement du ticket dans Firestore
  Future<void> _createTicket() async {
    // Déduire le stock de l'activité AVANT de créer le ticket
    for (var product in selectedProducts) {
      final productName = product['name'] as String;
      final quantity = product['quantity'] as int;

      // Trouver le document stock correspondant
      final stockQuery = await FirebaseFirestore.instance
          .collection('stock')
          .where('name', isEqualTo: productName)
          .where('activity', isEqualTo: widget.activityName)
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
          final newQty = currentQty - quantity;

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

    // Créer le ticket
    final ticketRef = FirebaseFirestore.instance.collection('tickets').doc();

    await ticketRef.set({
      'cashierId': widget.cashierId,
      'activity': widget.activityName,
      'serverId': selectedServerId,
      'serverName': selectedServerName,
      'products': selectedProducts,
      'total': total,
      'status': 'unpaid',
      'isOpen': true,
      'createdAt': FieldValue.serverTimestamp(),
    });

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Ticket créé avec succès')),
    );

    setState(() {
      selectedProducts.clear();
      selectedServerId = null;
      total = 0;
    });
  }
}