import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../common/error_messages.dart';
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
  String? selectedClientId;
  String? selectedClientName;
  List<Map<String, dynamic>> clients = [];
  bool loadingClients = true;
  bool _isCreatingInvoice = false;

  @override
  void initState() {
    super.initState();
    loadTicket();
    _loadClients();
  }

  Future<void> _loadClients() async {
    try {
      final query = await FirebaseFirestore.instance
          .collection('clients')
          .orderBy('fullName')
          .get();

      setState(() {
        clients = query.docs.map((doc) {
          final data = doc.data();
          return {
            'id': doc.id,
            'fullName': (data['fullName'] ?? '') as String,
            'phone': (data['phone'] ?? '') as String,
          };
        }).toList();
        loadingClients = false;
      });
    } catch (e) {
      setState(() {
        loadingClients = false;
      });
      // Erreur silencieuse - les clients sont optionnels
    }
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
    if (_isCreatingInvoice) return;

    setState(() {
      _isCreatingInvoice = true;
    });

    try {
      final balance = total - amountPaid;
      String? activityName = await getActivityName();
      String? activityId = await getActivityId();

      // Validation selon les règles Firestore
      if (activityId == null || activityId.isEmpty) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text(ErrorMessages.activiteNonTrouvee),
              backgroundColor: Colors.red,
            ),
          );
        }
        return;
      }

      if (widget.serverId.isEmpty) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text(ErrorMessages.serveurNonDefini),
              backgroundColor: Colors.red,
            ),
          );
        }
        return;
      }

      // Vérifier que balance == totalAmount - amountPaid (règle Firestore)
      final calculatedBalance = total - amountPaid;
      if ((balance - calculatedBalance).abs() > 0.01) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text(ErrorMessages.calculSoldeIncoherent),
              backgroundColor: Colors.red,
            ),
          );
        }
        return;
      }

      final invoiceData = <String, dynamic>{
        "ticketId": widget.ticketId,
        "cashierId": widget.cashierId,
        "serverId": widget.serverId, // string - requis par les règles
        "activityId": activityId, // requis pour validation caissier
        "totalAmount": total, // number - requis
        "amountPaid": amountPaid, // number - requis
        "balance": balance, // number - requis et doit être totalAmount - amountPaid
        "paymentStatus": getStatus(), // doit être dans ["paid","partial","unpaid"]
        "createdAt": FieldValue.serverTimestamp(), // timestamp - requis
      };

      // Ajouter les informations du client si sélectionné (optionnel, non validé par les règles)
      if (selectedClientId != null && selectedClientName != null) {
        invoiceData["clientId"] = selectedClientId;
        invoiceData["clientName"] = selectedClientName;
      }

      await FirebaseFirestore.instance.collection("invoices").add(invoiceData);

      // Fermer le ticket
      await FirebaseFirestore.instance
          .collection("tickets")
          .doc(widget.ticketId)
          .update({"status": getStatus(), "isOpen": false});

      if (!mounted) return;

      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (_) => TicketsOuvertsPage(
            activityName: activityName ?? "",
            cashierId: widget.cashierId,
          ),
        ),
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text(ErrorMessages.paiementEchec),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isCreatingInvoice = false;
        });
      } else {
        _isCreatingInvoice = false;
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Paiement"),
        backgroundColor: Colors.black,
      ),
      body: SingleChildScrollView(
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
            // Sélection du client (optionnel)
            DropdownButtonFormField<String>(
              value: selectedClientId,
              decoration: InputDecoration(
                labelText: "Client (optionnel)",
                hintText: "Sélectionner un client",
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                prefixIcon: const Icon(Icons.person),
              ),
              items: [
                const DropdownMenuItem<String>(
                  value: null,
                  child: Text("Aucun client"),
                ),
                ...clients.map((client) {
                  final displayName = client['phone'] != null && client['phone'].toString().isNotEmpty
                      ? "${client['fullName']} (${client['phone']})"
                      : client['fullName'].toString();
                  return DropdownMenuItem<String>(
                    value: client['id'] as String,
                    child: Text(
                      displayName,
                      overflow: TextOverflow.ellipsis,
                      maxLines: 1,
                    ),
                  );
                }),
              ],
              onChanged: (value) {
                setState(() {
                  selectedClientId = value;
                  if (value != null) {
                    final client = clients.firstWhere((c) => c['id'] == value);
                    selectedClientName = client['fullName'] as String;
                  } else {
                    selectedClientName = null;
                  }
                });
              },
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
            const SizedBox(height: 30),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _isCreatingInvoice ? null : createInvoice,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.black,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: _isCreatingInvoice
                    ? const SizedBox(
                        height: 22,
                        width: 22,
                        child: CircularProgressIndicator(
                          strokeWidth: 2.5,
                          valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                        ),
                      )
                    : const Text(
                        "Créer facture",
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
              ),
            )
          ],
        ),
      ),
    );
  }
}