import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class DepositPage extends StatefulWidget {
  const DepositPage({super.key});

  @override
  State<DepositPage> createState() => _DepositPageState();
}

class _DepositPageState extends State<DepositPage> {
  final amountController = TextEditingController();
  String? selectedActivityName;
  List<String> activities = [];
  bool loading = false;

  @override
  void initState() {
    super.initState();
    _loadActivities();
  }

  Future<void> _loadActivities() async {
    final query = await FirebaseFirestore.instance
        .collection('users')
        .where('role', isEqualTo: 'cashier')
        .get();

    final Set<String> uniqueActivities = {};
    for (var doc in query.docs) {
      final activityName = doc.data()['activityName'];
      if (activityName != null) {
        uniqueActivities.add(activityName);
      }
    }

    setState(() {
      activities = uniqueActivities.toList();
    });
  }

  Future<void> _saveDeposit() async {
    if (selectedActivityName == null || amountController.text.isEmpty) {
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

      // Créer le dépôt
      await FirebaseFirestore.instance.collection('deposits').add({
        'activityName': selectedActivityName,
        'amount': amount,
        'date': FieldValue.serverTimestamp(),
        'cashierId': cashierId,
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
        title: const Text("Enregistrer Dépôt", style: TextStyle(color: Colors.white)),
        backgroundColor: Colors.black,
      ),
      body: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            DropdownButtonFormField<String>(
              value: selectedActivityName,
              decoration: InputDecoration(
                labelText: 'Activité',
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
              ),
              items: activities.map((activity) {
                return DropdownMenuItem<String>(
                  value: activity,
                  child: Text(activity),
                );
              }).toList(),
              onChanged: (value) {
                setState(() {
                  selectedActivityName = value;
                });
              },
            ),
            const SizedBox(height: 20),
            TextField(
              controller: amountController,
              keyboardType: TextInputType.number,
              decoration: InputDecoration(
                labelText: 'Montant (FC)',
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
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
                      'Enregistrer',
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

