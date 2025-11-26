import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

class MainStockHistoryPage extends StatelessWidget {
  const MainStockHistoryPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Historique Stock", style: TextStyle(color: Colors.white)),
        backgroundColor: Colors.black,
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance
            .collection('stock_movements')
            .orderBy('date', descending: true)
            .limit(200)
            .snapshots(),
        builder: (context, snapshot) {
          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }

          if (snapshot.data!.docs.isEmpty) {
            return const Center(
              child: Text('Aucun mouvement enregistré'),
            );
          }

          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: snapshot.data!.docs.length,
            itemBuilder: (context, index) {
              final doc = snapshot.data!.docs[index];
              final data = doc.data() as Map<String, dynamic>;
              final productName = data['productName'] ?? 'Produit inconnu';
              final quantity = (data['quantity'] ?? 0) as int;
              final type = data['type'] ?? 'exit';
              final reason = data['reason'] ?? '';
              final stockManagerName = data['stockManagerName'] ?? 'Inconnu';
              final date = (data['date'] as Timestamp?)?.toDate() ?? DateTime.now();

              final isEntry = type == 'entry';

              return Card(
                margin: const EdgeInsets.only(bottom: 12),
                child: ListTile(
                  leading: CircleAvatar(
                    backgroundColor: isEntry ? Colors.green : Colors.red,
                    child: Icon(
                      isEntry ? Icons.add : Icons.remove,
                      color: Colors.white,
                    ),
                  ),
                  title: Text(
                    productName,
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                  subtitle: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Type: ${isEntry ? "Entrée" : "Sortie"}'),
                      if (reason.isNotEmpty) Text('Raison: $reason'),
                      Text('Par: $stockManagerName'),
                      Text('Date: ${DateFormat('dd/MM/yyyy HH:mm').format(date)}'),
                    ],
                  ),
                  trailing: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      color: isEntry
                          ? Colors.green.shade100
                          : Colors.red.shade100,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      '${isEntry ? "+" : "-"}$quantity',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: isEntry
                            ? Colors.green.shade800
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



