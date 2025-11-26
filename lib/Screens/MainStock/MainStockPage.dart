import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

class MainStockPage extends StatelessWidget {
  const MainStockPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Stock Général", style: TextStyle(color: Colors.white)),
        backgroundColor: Colors.black,
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance
            .collection('central_stock')
            .orderBy('name')
            .snapshots(),
        builder: (context, snapshot) {
          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }

          if (snapshot.data!.docs.isEmpty) {
            return const Center(
              child: Text(
                'Aucun produit en stock général',
                style: TextStyle(fontSize: 16),
              ),
            );
          }

          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: snapshot.data!.docs.length,
            itemBuilder: (context, index) {
              final doc = snapshot.data!.docs[index];
              final data = doc.data() as Map<String, dynamic>;
              final name = data['name'] ?? 'Produit inconnu';
              final quantity = (data['quantity'] ?? 0) as int;
              final unit = data['unit'] ?? 'unité';

              return Card(
                margin: const EdgeInsets.only(bottom: 12),
                child: ListTile(
                  leading: CircleAvatar(
                    backgroundColor: quantity > 10
                        ? Colors.green
                        : quantity > 0
                            ? Colors.orange
                            : Colors.red,
                    child: Icon(
                      quantity > 0 ? Icons.inventory : Icons.inventory_2_outlined,
                      color: Colors.white,
                    ),
                  ),
                  title: Text(
                    name,
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                  subtitle: Text('Unité: $unit'),
                  trailing: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      color: quantity > 10
                          ? Colors.green.shade100
                          : quantity > 0
                              ? Colors.orange.shade100
                              : Colors.red.shade100,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      '$quantity $unit${quantity > 1 ? 's' : ''}',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: quantity > 10
                            ? Colors.green.shade800
                            : quantity > 0
                                ? Colors.orange.shade800
                                : Colors.red.shade800,
                      ),
                    ),
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }
}



