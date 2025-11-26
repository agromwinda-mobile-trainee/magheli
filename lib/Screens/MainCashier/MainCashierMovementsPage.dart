import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:intl/intl.dart';

class MainCashierMovementsPage extends StatefulWidget {
  final bool? isDeposit; // Pour créer un mouvement (true = dépôt, false = sortie)
  final String? viewFilter; // Pour filtrer l'affichage ('deposits', 'withdrawals', null = tout)
  const MainCashierMovementsPage({super.key, this.isDeposit, this.viewFilter});

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
      // Les dépôts vont dans main_cash_deposits, les sorties dans main_cash_movements
      if (isDeposit) {
        await FirebaseFirestore.instance.collection('main_cash_deposits').add({
          'amount': amount,
          'type': 'deposit',
          'reason': reasonController.text.trim(),
          'cashierId': cashierId,
          'cashierName': cashierName,
          'date': FieldValue.serverTimestamp(),
        });
      } else {
        await FirebaseFirestore.instance.collection('main_cash_movements').add({
          'amount': amount,
          'type': 'withdrawal',
          'reason': reasonController.text.trim(),
          'cashierId': cashierId,
          'cashierName': cashierName,
          'date': FieldValue.serverTimestamp(),
        });
      }

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
    String appBarTitle = "Mouvements Caisse Principale";
    if (widget.viewFilter == 'deposits') {
      appBarTitle = "Dépôts Caisse Principale";
    } else if (widget.viewFilter == 'withdrawals') {
      appBarTitle = "Sorties Caisse Principale";
    }

    return Scaffold(
      appBar: AppBar(
        title: Text(appBarTitle, style: const TextStyle(color: Colors.white)),
        backgroundColor: Colors.black,
      ),
      body: _MovementsList(viewFilter: widget.viewFilter),
    );
  }
}

class _MovementsList extends StatefulWidget {
  final String? viewFilter;
  const _MovementsList({this.viewFilter});

  @override
  State<_MovementsList> createState() => _MovementsListState();
}

class _MovementsListState extends State<_MovementsList> {
  @override
  Widget build(BuildContext context) {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('main_cash_movements')
          .orderBy('date', descending: true)
          .limit(100)
          .snapshots(),
      builder: (context, movementsSnapshot) {
        return StreamBuilder<QuerySnapshot>(
          stream: FirebaseFirestore.instance
              .collection('main_cash_deposits')
              .orderBy('date', descending: true)
              .limit(100)
              .snapshots(),
          builder: (context, depositsSnapshot) {
            // Combiner les deux listes
            final movements = movementsSnapshot.hasData
                ? movementsSnapshot.data!.docs.map((doc) {
                    final data = doc.data() as Map<String, dynamic>;
                    return {
                      'amount': (data['amount'] ?? 0).toDouble(),
                      'type': data['type'] ?? 'withdrawal',
                      'reason': data['reason'] ?? '',
                      'cashierName': data['cashierName'] ?? 'Inconnu',
                      'date': (data['date'] as Timestamp?)?.toDate() ?? DateTime.now(),
                      'isFromDeposits': false,
                    };
                  }).toList()
                : <Map<String, dynamic>>[];

            final deposits = depositsSnapshot.hasData
                ? depositsSnapshot.data!.docs.map((doc) {
                    final data = doc.data() as Map<String, dynamic>;
                    return {
                      'amount': (data['amount'] ?? 0).toDouble(),
                      'type': 'deposit',
                      'activityName': data['activityName'] ?? '',
                      'cashierName': data['cashierName'] ?? 'Inconnu',
                      'date': (data['date'] as Timestamp?)?.toDate() ?? DateTime.now(),
                      'isFromDeposits': true,
                    };
                  }).toList()
                : <Map<String, dynamic>>[];

            // Combiner et trier par date décroissante
            List<Map<String, dynamic>> combined = [...movements, ...deposits];
            
            // Filtrer selon viewFilter
            if (widget.viewFilter == 'deposits') {
              combined = combined.where((m) => m['type'] == 'deposit').toList();
            } else if (widget.viewFilter == 'withdrawals') {
              combined = combined.where((m) => m['type'] == 'withdrawal').toList();
            }
            
            combined.sort((a, b) {
              final dateA = a['date'] as DateTime;
              final dateB = b['date'] as DateTime;
              return dateB.compareTo(dateA);
            });

            if (combined.isEmpty) {
              return const Center(
                child: Text('Aucun mouvement enregistré'),
              );
            }

            return ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: combined.length,
              itemBuilder: (context, index) {
                final movement = combined[index];
                final amount = movement['amount'] as double;
                final type = movement['type'] as String;
                final reason = movement['reason'] as String? ?? '';
                final activityName = movement['activityName'] as String?;
                final cashierName = movement['cashierName'] as String? ?? 'Inconnu';
                final date = movement['date'] as DateTime;
                final isFromDeposits = movement['isFromDeposits'] as bool? ?? false;

                final isDeposit = type == 'deposit';

                return Card(
                  margin: const EdgeInsets.only(bottom: 12),
                  elevation: 2,
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
                      overflow: TextOverflow.ellipsis,
                      maxLines: 1,
                    ),
                    subtitle: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        if (isFromDeposits && activityName != null && activityName.isNotEmpty)
                          Text(
                            'Activité: $activityName',
                            style: const TextStyle(fontWeight: FontWeight.w500),
                            overflow: TextOverflow.ellipsis,
                            maxLines: 1,
                          ),
                        if (reason.isNotEmpty)
                          Text(
                            '${isFromDeposits ? 'Dépôt de' : 'Raison'}: $reason',
                            overflow: TextOverflow.ellipsis,
                            maxLines: 1,
                          ),
                        Text(
                          'Par: $cashierName',
                          overflow: TextOverflow.ellipsis,
                          maxLines: 1,
                        ),
                        Text(
                          'Date: ${DateFormat('dd/MM/yyyy HH:mm').format(date)}',
                          overflow: TextOverflow.ellipsis,
                          maxLines: 1,
                        ),
                      ],
                    ),
                    trailing: Text(
                      '${isDeposit ? '+' : '-'}${amount.toStringAsFixed(2)} FC',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: isDeposit ? Colors.green : Colors.red,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                );
              },
            );
          },
        );
      },
    );
  }
}

