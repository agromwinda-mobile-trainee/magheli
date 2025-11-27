import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:intl/intl.dart';
import '../../common/error_messages.dart';

/// Page pour que le caissier d'une activité dépose en fin de soirée
/// Avec support de double devise (USD + FC) et historique amélioré
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
  final amountUSDController = TextEditingController();
  final amountFCController = TextEditingController();
  bool loading = false;

  Future<void> _saveDeposit() async {
    // Au moins un montant doit être saisi
    final amountUSD = double.tryParse(amountUSDController.text) ?? 0.0;
    final amountFC = double.tryParse(amountFCController.text) ?? 0.0;

    if (amountUSD <= 0 && amountFC <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Veuillez saisir au moins un montant (USD ou FC)'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    if (amountUSD < 0 || amountFC < 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(ErrorMessages.montantNegatif),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    setState(() => loading = true);

    try {
      final prefs = await SharedPreferences.getInstance();
      final cashierName = prefs.getString("fullName") ?? "Caissier";

      // Créer le dépôt avec double devise
      await FirebaseFirestore.instance.collection('deposits').add({
        'activityName': widget.activityName,
        'amountUSD': amountUSD,
        'amountFC': amountFC,
        'date': FieldValue.serverTimestamp(),
        'cashierId': widget.cashierId,
        'cashierName': cashierName,
        'type': 'deposit',
      });

      // Mettre à jour le solde de l'activité dans activity_balances
     //await _updateActivityBalance(amountUSD, amountFC);

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(ErrorMessages.depotEnregistreSucces),
          backgroundColor: Colors.green,
        ),
      );

      // Réinitialiser les champs
      amountUSDController.clear();
      amountFCController.clear();
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

  /// Met à jour le solde de l'activité dans activity_balances
  Future<void> _updateActivityBalance(double amountUSD, double amountFC) async {
    final activityBalanceRef = FirebaseFirestore.instance
        .collection('activity_balances')
        .doc(widget.activityName);

    await FirebaseFirestore.instance.runTransaction((transaction) async {
      final snapshot = await transaction.get(activityBalanceRef);

      double currentUSD = 0;
      double currentFC = 0;

      if (snapshot.exists) {
        final data = snapshot.data()!;
        currentUSD = (data['balanceUSD'] ?? 0).toDouble();
        currentFC = (data['balanceFC'] ?? 0).toDouble();
      }

      double newUSD = currentUSD + amountUSD;
      double newFC = currentFC + amountFC;

      if (!snapshot.exists) {
        transaction.set(activityBalanceRef, {
          'activityName': widget.activityName,
          'balanceUSD': newUSD,
          'balanceFC': newFC,
          'updatedAt': FieldValue.serverTimestamp(),
        });
      } else {
        transaction.update(activityBalanceRef, {
          'balanceUSD': newUSD,
          'balanceFC': newFC,
          'updatedAt': FieldValue.serverTimestamp(),
        });
      }
    });

    // Recalculer le solde principal
    await _recalculateMainBalance();
  }

  /// Recalcule le solde principal en sommant tous les soldes d'activités
  Future<void> _recalculateMainBalance() async {
    final allBalances = await FirebaseFirestore.instance
        .collection('activity_balances')
        .get();

    double totalUSD = 0;
    double totalFC = 0;

    for (var doc in allBalances.docs) {
      final data = doc.data();
      totalUSD += (data['balanceUSD'] ?? 0).toDouble();
      totalFC += (data['balanceFC'] ?? 0).toDouble();
    }

    final mainBalanceRef = FirebaseFirestore.instance
        .collection('main_cash')
        .doc('balance');

    await FirebaseFirestore.instance.runTransaction((transaction) async {
      transaction.set(mainBalanceRef, {
        'balanceUSD': totalUSD,
        'balanceFC': totalFC,
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
    });
  }

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
            child: SingleChildScrollView(
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
                  // Montant USD
                  TextField(
                    controller: amountUSDController,
                    keyboardType: TextInputType.numberWithOptions(decimal: true),
                    decoration: InputDecoration(
                      labelText: 'Montant USD',
                      hintText: '0.00',
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                      prefixIcon: const Icon(Icons.attach_money),
                    ),
                  ),
                  const SizedBox(height: 16),
                  // Montant FC
                  TextField(
                    controller: amountFCController,
                    keyboardType: TextInputType.numberWithOptions(decimal: true),
                    decoration: InputDecoration(
                      labelText: 'Montant FC',
                      hintText: '0.00',
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
                        return Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Icons.history, size: 64, color: Colors.grey[400]),
                              const SizedBox(height: 16),
                              const Text(
                                'Aucun dépôt enregistré',
                                style: TextStyle(color: Colors.grey),
                              ),
                            ],
                          ),
                        );
                      }

                      final deposits = snapshot.data!.docs;
                      
                      // Calculer les totaux
                      double totalDepositsUSD = 0;
                      double totalDepositsFC = 0;
                      
                      for (var doc in deposits) {
                        final data = doc.data() as Map<String, dynamic>?;
                        if (data != null) {
                          // Support de l'ancien format (amount) et du nouveau (amountUSD/amountFC)
                          if (data.containsKey('amountUSD')) {
                            totalDepositsUSD += ((data['amountUSD'] ?? 0) as num).toDouble();
                          }
                          if (data.containsKey('amountFC')) {
                            totalDepositsFC += ((data['amountFC'] ?? 0) as num).toDouble();
                          } else if (data.containsKey('amount')) {
                            // Ancien format : amount est en FC
                            totalDepositsFC += ((data['amount'] ?? 0) as num).toDouble();
                          }
                        }
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
                            child: Column(
                              children: [
                                const Text(
                                  'Total des dépôts',
                                  style: TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                const SizedBox(height: 8),
                                if (totalDepositsUSD > 0)
                                  Row(
                                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                    children: [
                                      const Text('USD:', style: TextStyle(fontSize: 14)),
                                      Text(
                                        '\$${totalDepositsUSD.toStringAsFixed(2)}',
                                        style: TextStyle(
                                          fontSize: 18,
                                          fontWeight: FontWeight.bold,
                                          color: Colors.green.shade700,
                                        ),
                                      ),
                                    ],
                                  ),
                                if (totalDepositsFC > 0) ...[
                                  if (totalDepositsUSD > 0) const SizedBox(height: 4),
                                  Row(
                                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                    children: [
                                      const Text('FC:', style: TextStyle(fontSize: 14)),
                                      Text(
                                        '${totalDepositsFC.toStringAsFixed(2)} FC',
                                        style: TextStyle(
                                          fontSize: 18,
                                          fontWeight: FontWeight.bold,
                                          color: Colors.green.shade700,
                                        ),
                                      ),
                                    ],
                                  ),
                                ],
                                if (totalDepositsUSD == 0 && totalDepositsFC == 0)
                                  Text(
                                    '0.00',
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
                                final data = doc.data() as Map<String, dynamic>?;
                                if (data == null) return const SizedBox.shrink();
                                
                                // Support de l'ancien format (amount) et du nouveau (amountUSD/amountFC)
                                final amountUSD = data.containsKey('amountUSD')
                                    ? ((data['amountUSD'] ?? 0) as num).toDouble()
                                    : 0.0;
                                final amountFC = data.containsKey('amountFC')
                                    ? ((data['amountFC'] ?? 0) as num).toDouble()
                                    : (data.containsKey('amount')
                                        ? ((data['amount'] ?? 0) as num).toDouble()
                                        : 0.0);
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
                                    title: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        if (amountUSD > 0)
                                          Text(
                                            '\$${amountUSD.toStringAsFixed(2)}',
                                            style: TextStyle(
                                              fontWeight: FontWeight.bold,
                                              fontSize: 16,
                                              color: Colors.blue.shade700,
                                            ),
                                          ),
                                        if (amountFC > 0) ...[
                                          if (amountUSD > 0) const SizedBox(height: 4),
                                          Text(
                                            '${amountFC.toStringAsFixed(2)} FC',
                                            style: TextStyle(
                                              fontWeight: FontWeight.bold,
                                              fontSize: 16,
                                              color: Colors.green.shade700,
                                            ),
                                          ),
                                        ],
                                        if (amountUSD == 0 && amountFC == 0)
                                          Text(
                                            '0.00',
                                            style: TextStyle(
                                              fontWeight: FontWeight.bold,
                                              fontSize: 16,
                                            ),
                                          ),
                                      ],
                                    ),
                                    subtitle: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        const SizedBox(height: 4),
                                        Text(
                                          'Caissier: $cashierName',
                                          overflow: TextOverflow.ellipsis,
                                          maxLines: 1,
                                        ),
                                        if (date != null)
                                          Text(
                                            DateFormat('dd/MM/yyyy à HH:mm').format(date.toDate()),
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
    amountUSDController.dispose();
    amountFCController.dispose();
    super.dispose();
  }
}
