import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'TicketsOuvertsPage.dart';

class PaymentPage extends StatefulWidget {
  final String ticketId;
  final String cashierId;
  final String serverId;
 // final String activityId;

  const PaymentPage({
    super.key,
    required this.ticketId,
    required this.cashierId,
    required this.serverId,
    //required this.activityId,
  });

  @override
  _PaymentPageState createState() => _PaymentPageState();
}

class _PaymentPageState extends State<PaymentPage> {
  double total = 0;
  double amountPaid = 0;
  List<dynamic> products = [];

  @override
  void initState() {
    super.initState();
    loadTicket();
  }

  double calculateTotal(List products) {
    double total = 0;
    for (var p in products) {
      total += (p["price"] * p["quantity"]);
    }
    return total;
  }

  Future<void> loadTicket() async {
    final doc = await FirebaseFirestore.instance
        .collection("tickets")
        .doc(widget.ticketId)
        .get();

    products = doc["products"];
    total = calculateTotal(products);

    setState(() {});
  }

  String getStatus() {
    if (amountPaid == 0) return "unpaid";
    if (amountPaid < total) return "partial";
    return "paid";
  }
  Future<String?> getActivityId() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString("activityId");
  }

  Future<String?> getActivityName() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString("activityName");
  }

  Future<void> createInvoice() async {
    final balance = total - amountPaid;
    String? activityName = await getActivityName();

    await FirebaseFirestore.instance.collection("invoices").add({
      "ticketId": widget.ticketId,
      "cashierId": widget.cashierId,
      "serverId": widget.serverId,
      "activityId":await getActivityId(),
      "totalAmount": total,
      "amountPaid": amountPaid,
      "balance": balance,
      "paymentStatus": getStatus(),
      "createdAt": FieldValue.serverTimestamp(),
    });

    // Fermer le ticket
    await FirebaseFirestore.instance
        .collection("tickets")
        .doc(widget.ticketId)
        .update({"status" :getStatus(),"isOpen": false });

    //Navigator.pop(context);
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(
        builder: (_) => TicketsOuvertsPage(
          activityName: activityName ?? "",
          cashierId: widget.cashierId,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Paiement"),
        backgroundColor: Colors.black,
      ),
      body: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              "Total : ${total.toStringAsFixed(2)} FC",
              style: const TextStyle(
                  fontSize: 22, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 20),
            TextField(
              keyboardType: TextInputType.number,
              decoration: InputDecoration(
                labelText: "Montant payé",
                border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12)),
              ),
              onChanged: (v) {
                setState(() {
                  amountPaid = double.tryParse(v) ?? 0;
                });
              },
            ),
            const SizedBox(height: 20),
            Text(
              "Status : ${getStatus()}",
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w500),
            ),
            const Spacer(),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: createInvoice,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.black,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: const Text(
                  "Créer facture",
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
              ),
            )
          ],
        ),
      ),
    );
  }
}