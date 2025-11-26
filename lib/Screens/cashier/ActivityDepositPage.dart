import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:intl/intl.dart';
import '../../common/error_messages.dart';

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
      //await _updateMainCashBalance(amount, 'deposit');

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(ErrorMessages.depotEnregistreSucces),
          backgroundColor: Colors.green,
        ),
      );

      Navigator.pop(context);
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(ErrorMessages.fromException(e)),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      setState(() => loading = false);
    }
  }

  // Future<void> _updateMainCashBalance(double amount, String type) async {
  //   final balanceRef = FirebaseFirestore.instance
  //       .collection('main_cash')
  //       .doc('balance');
  //
  //   await FirebaseFirestore.instance.runTransaction((transaction) async {
  //     final snapshot = await transaction.get(balanceRef);
  //     double currentBalance = 0;
  //
  //     if (snapshot.exists) {
  //       currentBalance = (snapshot.data()?['balance'] ?? 0).toDouble();
  //     }
  //
  //     double newBalance = type == 'deposit'
  //         ? currentBalance + amount
  //         : currentBalance - amount;
  //
  //     if (!snapshot.exists) {
  //       transaction.set(balanceRef, {
  //         'balance': newBalance,
  //         'updatedAt': FieldValue.serverTimestamp(),
  //       });
  //     } else {
  //       transaction.update(balanceRef, {
  //         'balance': newBalance,
  //         'updatedAt': FieldValue.serverTimestamp(),
  //       });
  //     }
  //   });
  // }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Déposer en Caisse Principale", style: TextStyle(color: Colors.white)),
        backgroundColor: Colors.black,
      ),
      body: Column(
        children: [
          // Section formulaire de dépôt
          Container(
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
          // Divider
          const Divider(height: 1),
          // Section historique des dépôts
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: Row(
                    children: [
                      const Icon(Icons.history, color: Colors.black),
                      const SizedBox(width: 8),
                      const Text(
                        'Historique des dépôts',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ),
                Expanded(
                  child: StreamBuilder<QuerySnapshot>(
                    stream: FirebaseFirestore.instance
                        .collection('deposits')
                        .where('activityName', isEqualTo: widget.activityName)
                        .orderBy('date', descending: true)
                        .snapshots(),
                    builder: (context, snapshot) {
                      if (snapshot.connectionState == ConnectionState.waiting) {
                        return const Center(child: CircularProgressIndicator());
                      }

                      if (snapshot.hasError) {
                        return Center(
                          child: Text('Erreur: ${snapshot.error}'),
                        );
                      }

                      if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                        return const Center(
                          child: Text(
                            'Aucun dépôt enregistré',
                            style: TextStyle(color: Colors.grey),
                          ),
                        );
                      }

                      final deposits = snapshot.data!.docs;
                      double totalDeposits = 0;
                      for (var doc in deposits) {
                        final data = doc.data() as Map<String, dynamic>;
                        totalDeposits += (data['amount'] ?? 0).toDouble();
                      }

                      return Column(
                        children: [
                          // Statistique totale
                          Container(
                            margin: const EdgeInsets.symmetric(horizontal: 16),
                            padding: const EdgeInsets.all(16),
                            decoration: BoxDecoration(
                              color: Colors.green.shade50,
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(color: Colors.green.shade200),
                            ),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                const Text(
                                  'Total des dépôts:',
                                  style: TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                Text(
                                  '${totalDeposits.toStringAsFixed(2)} FC',
                                  style: TextStyle(
                                    fontSize: 18,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.green.shade700,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 8),
                          // Liste des dépôts
                          Expanded(
                            child: ListView.builder(
                              padding: const EdgeInsets.symmetric(horizontal: 16),
                              itemCount: deposits.length,
                              itemBuilder: (context, index) {
                                final doc = deposits[index];
                                final data = doc.data() as Map<String, dynamic>;
                                final amount = (data['amount'] ?? 0).toDouble();
                                final date = data['date'] as Timestamp?;
                                final cashierName = data['cashierName'] ?? 'Caissier inconnu';

                                return Card(
                                  margin: const EdgeInsets.only(bottom: 12),
                                  elevation: 2,
                                  child: ListTile(
                                    leading: CircleAvatar(
                                      backgroundColor: Colors.green.shade100,
                                      child: Icon(
                                        Icons.arrow_upward,
                                        color: Colors.green.shade700,
                                      ),
                                    ),
                                    title: Text(
                                      '${amount.toStringAsFixed(2)} FC',
                                      style: const TextStyle(
                                        fontWeight: FontWeight.bold,
                                        fontSize: 16,
                                      ),
                                    ),
                                    subtitle: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        const SizedBox(height: 4),
                                        Text('Caissier: $cashierName'),
                                        if (date != null)
                                          Text(
                                            DateFormat('dd/MM/yyyy à HH:mm')
                                                .format(date.toDate()),
                                            style: const TextStyle(
                                              fontSize: 12,
                                              color: Colors.grey,
                                            ),
                                          ),
                                      ],
                                    ),
                                    trailing: Icon(
                                      Icons.check_circle,
                                      color: Colors.green.shade700,
                                    ),
                                  ),
                                );
                              },
                            ),
                          ),
                        ],
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    amountController.dispose();
    super.dispose();
  }
}

