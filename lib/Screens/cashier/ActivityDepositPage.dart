import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Page pour que le caissier d'une activité dépose en fin de soirée
class ActivityDepositPage extends StatefulWidget {
  final String activityName;
  final String cashierId;

  const ActivityDepositPage({
    super.key,
    required this.activityName,
    required this.cashierId,
  });

  @override
  State<ActivityDepositPage> createState() => _ActivityDepositPageState();
}

class _ActivityDepositPageState extends State<ActivityDepositPage> {
  final amountController = TextEditingController();
  bool loading = false;

  Future<void> _saveDeposit() async {
    if (amountController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Veuillez saisir le montant')),
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
      final prefs = await SharedPreferences.getInstance();
      final cashierName = prefs.getString("fullName") ?? "Caissier";

      // Créer le dépôt
      await FirebaseFirestore.instance.collection('deposits').add({
        'activityName': widget.activityName,
        'amount': amount,
        'date': FieldValue.serverTimestamp(),
        'cashierId': widget.cashierId,
        'cashierName': cashierName,
        'type': 'deposit',
      });

      // Mettre à jour le solde de la caisse principale
      await _updateMainCashBalance(amount, 'deposit');

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Dépôt enregistré avec succès')),
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
    return Scaffold(
      appBar: AppBar(
        title: const Text("Déposer en Caisse Principale", style: TextStyle(color: Colors.white)),
        backgroundColor: Colors.black,
      ),
      body: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Card(
              color: Colors.blue.shade50,
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  children: [
                    const Text(
                      'Activité',
                      style: TextStyle(
                        fontSize: 14,
                        color: Colors.grey,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      widget.activityName,
                      style: const TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 24),
            TextField(
              controller: amountController,
              keyboardType: TextInputType.number,
              decoration: InputDecoration(
                labelText: 'Montant à déposer (FC)',
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                prefixIcon: const Icon(Icons.money),
              ),
            ),
            const SizedBox(height: 30),
            ElevatedButton(
              onPressed: loading ? null : _saveDeposit,
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
                      'Enregistrer le dépôt',
                      style: TextStyle(color: Colors.white, fontSize: 18),
                    ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  void dispose() {
    amountController.dispose();
    super.dispose();
  }
}

