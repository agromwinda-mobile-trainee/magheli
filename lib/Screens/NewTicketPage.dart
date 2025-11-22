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
        final data = e.data() as Map<String, dynamic>;

        return {
          'id': e.id,
          'name': data['fullName'] ?? 'Serveur inconnu',
        };
      }).toList();
    });
  }

  // 🔥 NOUVEAU : Vérifier stock disponible
  Future<bool> checkStock(String productId) async {
    final doc = await FirebaseFirestore.instance
        .collection("stock")
        .doc(productId)
        .get();

    if (!doc.exists) return false;

    int quantity = doc["quantity"] ?? 0;
    return quantity > 0;
  }

  // 🔥 NOUVEAU : Déduire du stock
  Future<void> adjustStock(String productId, int quantity) async {
    final ref = FirebaseFirestore.instance.collection("stock").doc(productId);

    await FirebaseFirestore.instance.runTransaction((tx) async {
      final snap = await tx.get(ref);
      if (!snap.exists) return;

      final current = (snap["quantity"] ?? 0) as int;
      final newQty = current - quantity;

      tx.update(ref, {
        "quantity": newQty < 0 ? 0 : newQty,
        "updatedAt": FieldValue.serverTimestamp(),
      });
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
            return ListTile(
              title: Text(product['name']),
              subtitle: Text('${product['price']} FC'),
              trailing: IconButton(
                icon: const Icon(Icons.add_circle, color: Colors.green),
                onPressed: () => _addProduct(product),
              ),
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
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text('Total: FC${total.toStringAsFixed(2)}',
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
          ElevatedButton(
            onPressed: canValidate ? _createTicket : null,
            style: ElevatedButton.styleFrom(backgroundColor: Colors.black),
            child:
            const Text('Valider', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  // 🔹 Ajout produit (avec contrôle de stock)
  Future<void> _addProduct(QueryDocumentSnapshot product) async {
    final productId = product.id;

    bool available = await checkStock(productId);

    if (!available) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Stock insuffisant : ${product['name']}")),
      );
      return;
    }

    setState(() {
      selectedProducts.add({
        'id': product.id,
        'name': product['name'],
        'price': product['price'],
        'quantity': 1,
      });
      total += product['price'];
    });
  }

  // 🔹 Enregistrement du ticket
  Future<void> _createTicket() async {
    // 🔥 Déduire le stock AVANT de créer le ticket
    for (var p in selectedProducts) {
      await adjustStock(p['id'], p['quantity']);
    }

    final ticketRef = FirebaseFirestore.instance.collection('tickets').doc();

    await ticketRef.set({
      'cashierId': widget.cashierId,
      'activity': widget.activityName,
      'serverId': selectedServerId,
      'serverName': selectedServerName,
      'products': selectedProducts,
      'total': total,
      'status': 'unpaid',
      'isOpen' : true,
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