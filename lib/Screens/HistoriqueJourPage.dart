import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

class HistoriqueJourPage extends StatefulWidget {
  final String cashierActivityId;
  final String cashierId;

  const HistoriqueJourPage({
    required this.cashierActivityId,
    required this.cashierId,
  });

  @override
  _HistoriqueJourPageState createState() => _HistoriqueJourPageState();
}

class _HistoriqueJourPageState extends State<HistoriqueJourPage> {
  DateTime now = DateTime.now();
  Map<String, String> serverNames = {}; // serverId => serverName

  @override
  void initState() {
    super.initState();
    loadServerNames();
  }

  /// ------ CHARGE TOUS LES SERVEURS UNE SEULE FOIS ------
  Future<void> loadServerNames() async {
    final users = await FirebaseFirestore.instance
        .collection("servers")
        .get();

    setState(() {
      for (var u in users.docs) {
        serverNames[u.id] = u["fullName"] ?? "Serveur inconnu";
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    DateTime start = DateTime(now.year, now.month, now.day, 0, 0, 0);
    DateTime end = DateTime(now.year, now.month, now.day, 23, 59, 59);

    return Scaffold(
      appBar: AppBar(
        title: Text("Historique du Jour"),
        centerTitle: true,
      ),

      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance
            .collection("invoices")
            .where("activityId", isEqualTo: widget.cashierActivityId)
            .where("createdAt", isGreaterThanOrEqualTo: start)
            .where("createdAt", isLessThanOrEqualTo: end)
            .snapshots(),
        builder: (context, snapshot) {
          if (!snapshot.hasData || serverNames.isEmpty) {
            return Center(child: CircularProgressIndicator());
          }

          final docs = snapshot.data!.docs;

          double totalDuJour = 0;
          double totalPaye = 0;

          Map<String, double> ventesServeurs = {};

          for (var doc in docs) {
            double total = doc["totalAmount"] * 1.0;
            double paye = doc["amountPaid"] * 1.0;

            totalDuJour += total;
            totalPaye += paye;

            String serverId = doc["serverId"];
            String serverName = serverNames[serverId] ?? "Serveur inconnu";

            ventesServeurs.update(
              serverName,
                  (old) => old + paye,
              ifAbsent: () => paye,
            );
          }

          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // ---------------------- HEADER ----------------------
              Container(
                width: double.infinity,
                padding: EdgeInsets.all(20),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [Colors.blue.shade400, Colors.blue.shade700],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  boxShadow: [
                    BoxShadow(color: Colors.black26, blurRadius: 4),
                  ],
                  borderRadius: BorderRadius.only(
                    bottomLeft: Radius.circular(20),
                    bottomRight: Radius.circular(20),
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      "Résumé du jour",
                      style: TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.bold,
                          color: Colors.white),
                    ),
                    SizedBox(height: 12),
                    Text("Montant Total : ${totalDuJour.toStringAsFixed(2)} FC",
                        style: TextStyle(fontSize: 17, color: Colors.white)),
                    Text("Montant Payé : ${totalPaye.toStringAsFixed(2)} FC",
                        style: TextStyle(fontSize: 17, color: Colors.white)),
                    SizedBox(height: 15),
                    Text(
                      "Ventes par Serveur",
                      style: TextStyle(
                          fontSize: 19,
                          color: Colors.white,
                          fontWeight: FontWeight.bold),
                    ),
                    SizedBox(height: 8),
                    ...ventesServeurs.entries.map((e) => Padding(
                      padding: const EdgeInsets.only(top: 3.0),
                      child: Text(
                        "${e.key} : ${e.value.toStringAsFixed(2)} FC",
                        style: TextStyle(fontSize: 16, color: Colors.white),
                      ),
                    )),
                  ],
                ),
              ),

              SizedBox(height: 10),

              // ---------------------- LISTE DES FACTURES ----------------------
              Expanded(
                child: ListView.builder(
                  itemCount: docs.length,
                  itemBuilder: (context, index) {
                    final invoice = docs[index];
                    final createdAt =
                    (invoice["createdAt"] as Timestamp).toDate();

                    String serverId = invoice["serverId"];
                    String serverName = serverNames[serverId] ?? "Serveur inconnu";

                    return Container(
                      margin:
                      EdgeInsets.symmetric(horizontal: 14, vertical: 7),
                      padding: EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(14),
                        boxShadow: [
                          BoxShadow(color: Colors.black12, blurRadius: 4),
                        ],
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            "Serveur : $serverName",
                            style: TextStyle(
                                fontSize: 17, fontWeight: FontWeight.bold),
                          ),
                          SizedBox(height: 8),
                          Text("Montant Total : ${invoice['totalAmount']} FC"),
                          Text("Montant Payé : ${invoice['amountPaid']} FC"),
                          SizedBox(height: 6),
                          Text(
                            "Statut : ${invoice['paymentStatus']}",
                            style: TextStyle(
                              color: invoice['paymentStatus'] == "paid"
                                  ? Colors.green
                                  : invoice['paymentStatus'] == "partial"
                                  ? Colors.orange
                                  : Colors.red,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          SizedBox(height: 6),
                          Text("Heure : ${DateFormat.Hm().format(createdAt)}"),
                        ],
                      ),
                    );
                  },
                ),
              )
            ],
          );
        },
      ),
    );
  }
}