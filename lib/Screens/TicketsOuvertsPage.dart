import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

import 'EditTicketPage.dart';
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
            .where('status', isEqualTo: 'unpaid')
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
              final total = t['total'];
              final server = t['serverName'] ?? "Serveur inconnu";

              return Card(
                margin: const EdgeInsets.all(12),
                child: ListTile(
                  title: Text("Ticket • $server"),
                  subtitle: Text("Total : ${total.toString()} FC"),
                  trailing: const Icon(Icons.chevron_right),

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