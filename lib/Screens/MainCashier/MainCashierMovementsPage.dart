import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:intl/intl.dart';

class MainCashierMovementsPage extends StatefulWidget {
  final bool? isDeposit;
  const MainCashierMovementsPage({super.key, this.isDeposit});

  @override
  State<MainCashierMovementsPage> createState() => _MainCashierMovementsPageState();
}

class _MainCashierMovementsPageState extends State<MainCashierMovementsPage> {
  final amountController = TextEditingController();
  final reasonController = TextEditingController();
  bool loading = false;

  Future<void> _saveMovement() async {
    if (amountController.text.isEmpty || reasonController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Veuillez remplir tous les champs')),
      );
      return;
    }

    final amount = double.tryParse(amountController.text);
    if (amount == null || amount <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Montant invalide')),
      );
      return;
    }

    setState(() => loading = true);

    try {
      final user = FirebaseAuth.instance.currentUser;
      final cashierId = user?.uid ?? "";
      
      final prefs = await SharedPreferences.getInstance();
      final cashierName = prefs.getString("fullName") ?? "Caissier Principale";

      final isDeposit = widget.isDeposit ?? false;
      final type = isDeposit ? 'deposit' : 'withdrawal';

      // Enregistrer le mouvement
      await FirebaseFirestore.instance.collection('main_cash_movements').add({
        'amount': amount,
        'type': type,
        'reason': reasonController.text.trim(),
        'cashierId': cashierId,
        'cashierName': cashierName,
        'date': FieldValue.serverTimestamp(),
      });

      // Mettre à jour le solde
      await _updateMainCashBalance(amount, type);

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('${isDeposit ? "Dépôt" : "Sortie"} enregistré avec succès')),
      );

      Navigator.pop(context);
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Erreur: $e')),
      );
    } finally {
      setState(() => loading = false);
    }
  }

  Future<void> _updateMainCashBalance(double amount, String type) async {
    final balanceRef = FirebaseFirestore.instance
        .collection('main_cash')
        .doc('balance');

    await FirebaseFirestore.instance.runTransaction((transaction) async {
      final snapshot = await transaction.get(balanceRef);
      double currentBalance = 0;

      if (snapshot.exists) {
        currentBalance = (snapshot.data()?['balance'] ?? 0).toDouble();
      }

      double newBalance = type == 'deposit'
          ? currentBalance + amount
          : currentBalance - amount;

      if (!snapshot.exists) {
        transaction.set(balanceRef, {
          'balance': newBalance,
          'updatedAt': FieldValue.serverTimestamp(),
        });
      } else {
        transaction.update(balanceRef, {
          'balance': newBalance,
          'updatedAt': FieldValue.serverTimestamp(),
        });
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    // Si isDeposit est spécifié, on est en mode création
    if (widget.isDeposit != null) {
      return Scaffold(
        appBar: AppBar(
          title: Text(
            widget.isDeposit! ? "Enregistrer Dépôt" : "Enregistrer Sortie",
            style: const TextStyle(color: Colors.white),
          ),
          backgroundColor: Colors.black,
        ),
        body: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              TextField(
                controller: amountController,
                keyboardType: TextInputType.number,
                decoration: InputDecoration(
                  labelText: 'Montant (FC)',
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                ),
              ),
              const SizedBox(height: 20),
              TextField(
                controller: reasonController,
                decoration: InputDecoration(
                  labelText: 'Raison / Description',
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                ),
                maxLines: 3,
              ),
              const SizedBox(height: 30),
              ElevatedButton(
                onPressed: loading ? null : _saveMovement,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.black,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: loading
                    ? const CircularProgressIndicator(color: Colors.white)
                    : const Text(
                        'Enregistrer',
                        style: TextStyle(color: Colors.white, fontSize: 18),
                      ),
              ),
            ],
          ),
        ),
      );
    }

    // Sinon, on affiche la liste des mouvements
    return Scaffold(
      appBar: AppBar(
        title: const Text("Mouvements Caisse Principale", style: TextStyle(color: Colors.white)),
        backgroundColor: Colors.black,
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance
            .collection('main_cash_movements')
            .orderBy('date', descending: true)
            .limit(100)
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
              final amount = (data['amount'] ?? 0).toDouble();
              final type = data['type'] ?? 'withdrawal';
              final reason = data['reason'] ?? '';
              final cashierName = data['cashierName'] ?? 'Inconnu';
              final date = (data['date'] as Timestamp?)?.toDate() ?? DateTime.now();

              final isDeposit = type == 'deposit';

              return Card(
                margin: const EdgeInsets.only(bottom: 12),
                child: ListTile(
                  leading: CircleAvatar(
                    backgroundColor: isDeposit ? Colors.green : Colors.red,
                    child: Icon(
                      isDeposit ? Icons.add : Icons.remove,
                      color: Colors.white,
                    ),
                  ),
                  title: Text(
                    isDeposit ? 'Dépôt' : 'Sortie',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: isDeposit ? Colors.green : Colors.red,
                    ),
                  ),
                  subtitle: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Raison: $reason'),
                      Text('Par: $cashierName'),
                      Text('Date: ${DateFormat('dd/MM/yyyy HH:mm').format(date)}'),
                    ],
                  ),
                  trailing: Text(
                    '${isDeposit ? '+' : '-'}${amount.toStringAsFixed(2)} FC',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: isDeposit ? Colors.green : Colors.red,
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

  @override
  void dispose() {
    amountController.dispose();
    reasonController.dispose();
    super.dispose();
  }
}

