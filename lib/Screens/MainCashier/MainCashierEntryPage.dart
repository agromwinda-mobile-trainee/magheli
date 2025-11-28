import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../common/error_messages.dart';

/// Page pour enregistrer une entrée ou sortie de caisse principale
/// avec double devise (USD + FC) et sélection d'activité
class MainCashierEntryPage extends StatefulWidget {
  final bool isDeposit; // true = entrée, false = sortie

  const MainCashierEntryPage({
    super.key,
    required this.isDeposit,
  });

  @override
  State<MainCashierEntryPage> createState() => _MainCashierEntryPageState();
}

class _MainCashierEntryPageState extends State<MainCashierEntryPage> {
  final amountUSDController = TextEditingController();
  final amountFCController = TextEditingController();
  final reasonController = TextEditingController();
  String? selectedActivityName;
  List<String> activities = [];
  bool loading = false;
  bool loadingActivities = true;

  @override
  void initState() {
    super.initState();
    _loadActivities();
  }

  Future<void> _loadActivities() async {
    try {
      final query = await FirebaseFirestore.instance
          .collection('activities')
          .orderBy('activityName')
          .get();

      setState(() {
        activities = query.docs
            .map((doc) {
              final data = doc.data();
              return data['activityName'] as String?;
            })
            .where((name) => name != null && name.isNotEmpty)
            .cast<String>()
            .toList();
        loadingActivities = false;
      });
    } catch (e) {
      setState(() {
        loadingActivities = false;
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(ErrorMessages.fromException(e)),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _saveMovement() async {
    if (selectedActivityName == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Veuillez sélectionner une activité'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    if (reasonController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(ErrorMessages.champObligatoire),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

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
      final user = FirebaseAuth.instance.currentUser;
      final cashierId = user?.uid ?? "";

      final prefs = await SharedPreferences.getInstance();
      final cashierName = prefs.getString("fullName") ?? "Caissier Principal";

      final type = widget.isDeposit ? 'deposit' : 'withdrawal';

      // Enregistrer le mouvement
      await FirebaseFirestore.instance.collection('main_cash_movements').add({
        'activityName': selectedActivityName,
        'amountUSD': amountUSD,
        'amountFC': amountFC,
        'type': type,
        'reason': reasonController.text.trim(),
        'cashierId': cashierId,
        'cashierName': cashierName,
        'date': FieldValue.serverTimestamp(),
      });

      // Mettre à jour les soldes de l'activité et le solde principal
      await _updateBalances(selectedActivityName!, amountUSD, amountFC, type);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              '${widget.isDeposit ? "Entrée" : "Sortie"} enregistrée avec succès',
            ),
            backgroundColor: Colors.green,
          ),
        );
        Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(ErrorMessages.fromException(e)),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => loading = false);
      }
    }
  }

  /// Met à jour le solde de l'activité et le solde principal
  Future<void> _updateBalances(
    String activityName,
    double amountUSD,
    double amountFC,
    String type,
  ) async {
    // 1. Mettre à jour le solde de l'activité
    final activityBalanceRef = FirebaseFirestore.instance
        .collection('activity_balances')
        .doc(activityName);

    await FirebaseFirestore.instance.runTransaction((transaction) async {
      final activitySnapshot = await transaction.get(activityBalanceRef);

      double currentUSD = 0;
      double currentFC = 0;

      if (activitySnapshot.exists) {
        final data = activitySnapshot.data()!;
        currentUSD = (data['balanceUSD'] ?? 0).toDouble();
        currentFC = (data['balanceFC'] ?? 0).toDouble();
      }

      double newUSD = widget.isDeposit
          ? currentUSD + amountUSD
          : currentUSD - amountUSD;
      double newFC = widget.isDeposit
          ? currentFC + amountFC
          : currentFC - amountFC;

      // Vérifier que les soldes ne deviennent pas négatifs
      if (newUSD < 0 || newFC < 0) {
        throw Exception('Le solde ne peut pas être négatif');
      }

      if (!activitySnapshot.exists) {
        transaction.set(activityBalanceRef, {
          'activityName': activityName,
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

    // 2. Recalculer le solde principal (somme de tous les soldes d'activités)
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
        title: Text(
          widget.isDeposit ? "Enregistrer Entrée" : "Enregistrer Sortie",
          style: const TextStyle(color: Colors.white),
        ),
        backgroundColor: Colors.black,
      ),
      body: loadingActivities
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Sélection de l'activité
                  DropdownButtonFormField<String>(
                    value: selectedActivityName,
                    decoration: InputDecoration(
                      labelText: 'Activité *',
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      prefixIcon: const Icon(Icons.business),
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
                  // Montant USD
                  TextField(
                    controller: amountUSDController,
                    keyboardType: TextInputType.numberWithOptions(decimal: true),
                    decoration: InputDecoration(
                      labelText: 'Montant USD',
                      hintText: '0.00',
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      prefixIcon: const Icon(Icons.attach_money),
                    ),
                  ),
                  const SizedBox(height: 20),
                  // Montant FC
                  TextField(
                    controller: amountFCController,
                    keyboardType: TextInputType.numberWithOptions(decimal: true),
                    decoration: InputDecoration(
                      labelText: 'Montant FC',
                      hintText: '0.00',
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      prefixIcon: const Icon(Icons.money),
                    ),
                  ),
                  const SizedBox(height: 20),
                  // Raison
                  TextField(
                    controller: reasonController,
                    decoration: InputDecoration(
                      labelText: 'Raison / Description *',
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      prefixIcon: const Icon(Icons.description),
                    ),
                    maxLines: 3,
                  ),
                  const SizedBox(height: 30),
                  ElevatedButton(
                    onPressed: loading ? null : _saveMovement,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: widget.isDeposit ? Colors.green : Colors.red,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: loading
                        ? const CircularProgressIndicator(color: Colors.white)
                        : Text(
                            'Enregistrer',
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                  ),
                ],
              ),
            ),
    );
  }

  @override
  void dispose() {
    amountUSDController.dispose();
    amountFCController.dispose();
    reasonController.dispose();
    super.dispose();
  }
}


