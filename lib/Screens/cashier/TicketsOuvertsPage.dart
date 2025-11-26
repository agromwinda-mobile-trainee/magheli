import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

import 'TicketDetailsPage.dart';

class TicketsOuvertsPage extends StatelessWidget {
  final String activityName;
  final String cashierId;

  const TicketsOuvertsPage({
    super.key,
    required this.activityName,
    required this.cashierId,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.black,
        title: const Text("Tickets Ouverts",style: TextStyle(color: Colors.white),),
        centerTitle: true,
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance
            .collection('tickets')
            .where('activity', isEqualTo: activityName)
            .where('isOpen', isEqualTo: true)
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
            return const Center(
              child: Text(
                "Aucun ticket ouvert",
                style: TextStyle(fontSize: 18),
              ),
            );
          }

          final tickets = snapshot.data!.docs;

          return ListView.builder(
            itemCount: tickets.length,
            itemBuilder: (context, index) {
              final t = tickets[index];
              final total = (t['total'] ?? 0).toDouble();
              final server = t['serverName'] ?? "Serveur inconnu";
              final products = t['products'] as List<dynamic>? ?? [];
              final productsCount = products.length;

              return Card(
                margin: const EdgeInsets.all(12),
                child: ListTile(
                  title: Text(
                    "Ticket • $server",
                    overflow: TextOverflow.ellipsis,
                    maxLines: 1,
                  ),
                  subtitle: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        "Total : ${total.toStringAsFixed(2)} FC",
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                        ),
                        overflow: TextOverflow.ellipsis,
                        maxLines: 1,
                      ),
                      Text(
                        "$productsCount produit${productsCount > 1 ? 's' : ''}",
                        overflow: TextOverflow.ellipsis,
                        maxLines: 1,
                      ),
                    ],
                  ),
                  trailing: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        "${total.toStringAsFixed(2)} FC",
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                          color: Colors.green,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                      const Icon(Icons.chevron_right),
                    ],
                  ),
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => TicketDetailsPage(ticketId: t.id, cashierId: cashierId,),
                      ),
                    );
                  },
                ),
              );
            },
          );
        },
      ),
    );
  }
}