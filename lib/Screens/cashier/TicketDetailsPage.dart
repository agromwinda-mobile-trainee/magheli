import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

import 'EditTicketPage.dart';
import 'PaymentPage.dart';

class TicketDetailsPage extends StatelessWidget {
  final String ticketId;
  final String cashierId;

  const TicketDetailsPage({
    required this.ticketId,
    required this.cashierId,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Ticket Ouvert"),
        centerTitle: true,
        elevation: 2,
      ),

      body: FutureBuilder(
        future: FirebaseFirestore.instance.collection("tickets").doc(ticketId).get(),
        builder: (context, snapshot) {
          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }

          final ticket = snapshot.data!.data()!;
          final products = ticket["products"] as List;

          return Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              children: [

                // 🎟️ CARTE D’INFO TICKET
                Card(
                  elevation: 3,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  child: Padding(
                    padding: const EdgeInsets.all(20),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          "Informations du Ticket",
                          style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                        ),
                        const SizedBox(height: 12),

                        Row(
                          children: [
                            const Icon(Icons.person, size: 20),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                "Serveur : ${ticket['serverName']}",
                                overflow: TextOverflow.ellipsis,
                                maxLines: 1,
                              ),
                            ),
                          ],
                        ),

                        const SizedBox(height: 10),

                        Row(
                          children: [
                            const Icon(Icons.shopping_bag, size: 20),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                "Nombre de produits : ${products.length}",
                                overflow: TextOverflow.ellipsis,
                                maxLines: 1,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),

                const SizedBox(height: 20),

                // 📦 LISTE PRODUITS
                Expanded(
                  child: Card(
                    elevation: 3,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: ListView.builder(
                        itemCount: products.length,
                        itemBuilder: (context, index) {
                          final p = products[index];
                          final total = p["price"]* p["quantity"];
                          return ListTile(
                            title: Text(
                              p["name"],
                              overflow: TextOverflow.ellipsis,
                              maxLines: 1,
                            ),
                            subtitle: Text(
                              "Quantité : ${p["quantity"]}",
                              overflow: TextOverflow.ellipsis,
                              maxLines: 1,
                            ),
                            trailing: Text(
                              "$total FC",
                              overflow: TextOverflow.ellipsis,
                            ),
                          );
                        },
                      ),
                    ),
                  ),
                ),

                const SizedBox(height: 12),

                // 🟦 BOUTONS ACTION
                Row(
                  children: [
                    Expanded(
                      child: ElevatedButton.icon(
                        style: ElevatedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                        onPressed: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => EditTicketPage(ticketId: ticketId),
                            ),
                          );
                        },
                        icon: const Icon(Icons.edit),
                        label: const Text("Modifier Ticket"),
                      ),
                    ),

                    const SizedBox(width: 12),

                    Expanded(
                      child: ElevatedButton.icon(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.green,
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                        onPressed: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => PaymentPage(
                                ticketId: ticketId,
                                cashierId: cashierId,
                                serverId: ticket["serverId"],
                              ),
                            ),
                          );
                        },
                        icon: const Icon(Icons.payment),
                        label: const Text("Paiement"),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}