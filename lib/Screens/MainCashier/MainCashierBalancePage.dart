import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'MainCashierHistoryPage.dart';

class MainCashierBalancePage extends StatelessWidget {
  const MainCashierBalancePage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Solde Caisse Principale", style: TextStyle(color: Colors.white)),
        backgroundColor: Colors.black,
      ),
      body: StreamBuilder<DocumentSnapshot>(
        stream: FirebaseFirestore.instance
            .collection('main_cash')
            .doc('balance')
            .snapshots(),
        builder: (context, mainBalanceSnapshot) {
          return StreamBuilder<QuerySnapshot>(
            stream: FirebaseFirestore.instance
                .collection('activity_balances')
                .orderBy('activityName')
                .snapshots(),
            builder: (context, activitiesSnapshot) {
              if (!mainBalanceSnapshot.hasData || !activitiesSnapshot.hasData) {
                return const Center(child: CircularProgressIndicator());
              }

              final mainData = mainBalanceSnapshot.data!.data() as Map<String, dynamic>?;
              final mainBalanceUSD = (mainData?['balanceUSD'] ?? 0).toDouble();
              final mainBalanceFC = (mainData?['balanceFC'] ?? 0).toDouble();
              final updatedAt = mainData?['updatedAt'] as Timestamp?;

              final activities = activitiesSnapshot.data!.docs;

              return SingleChildScrollView(
                child: Padding(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const SizedBox(height: 20),
                      // Card principale du solde
                      Container(
                        padding: const EdgeInsets.all(32),
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                            colors: [
                              Colors.green.shade400,
                              Colors.green.shade600,
                            ],
                          ),
                          borderRadius: BorderRadius.circular(24),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.green.withOpacity(0.3),
                              blurRadius: 20,
                              offset: const Offset(0, 10),
                            ),
                          ],
                        ),
                        child: Column(
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Container(
                                  padding: const EdgeInsets.all(12),
                                  decoration: BoxDecoration(
                                    color: Colors.white.withOpacity(0.2),
                                    shape: BoxShape.circle,
                                  ),
                                  child: const Icon(
                                    Icons.account_balance_wallet,
                                    color: Colors.white,
                                    size: 32,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 20),
                            const Text(
                              'Solde Principal',
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.w500,
                                color: Colors.white70,
                              ),
                            ),
                            const SizedBox(height: 12),
                            if (mainBalanceUSD > 0)
                              Text(
                                '\$${mainBalanceUSD.toStringAsFixed(2)}',
                                style: const TextStyle(
                                  fontSize: 48,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.white,
                                  letterSpacing: 1.2,
                                ),
                              ),
                            if (mainBalanceFC > 0) ...[
                              if (mainBalanceUSD > 0) const SizedBox(height: 8),
                              Text(
                                '${mainBalanceFC.toStringAsFixed(2)} FC',
                                style: const TextStyle(
                                  fontSize: 48,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.white,
                                  letterSpacing: 1.2,
                                ),
                              ),
                            ],
                            if (mainBalanceUSD == 0 && mainBalanceFC == 0)
                              Text(
                                '0.00',
                                style: const TextStyle(
                                  fontSize: 56,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.white,
                                  letterSpacing: 1.2,
                                ),
                              ),
                            if (updatedAt != null) ...[
                              const SizedBox(height: 24),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 16,
                                  vertical: 8,
                                ),
                                decoration: BoxDecoration(
                                  color: Colors.white.withOpacity(0.2),
                                  borderRadius: BorderRadius.circular(20),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    const Icon(
                                      Icons.access_time,
                                      color: Colors.white70,
                                      size: 16,
                                    ),
                                    const SizedBox(width: 8),
                                    Text(
                                      DateFormat('dd/MM/yyyy à HH:mm').format(updatedAt.toDate()),
                                      style: const TextStyle(
                                        fontSize: 14,
                                        color: Colors.white70,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                      const SizedBox(height: 32),
                      // Titre des soldes par activité
                      const Text(
                        'Soldes par Activité',
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 16),
                      // Liste des soldes par activité
                      if (activities.isEmpty)
                        Card(
                          child: Padding(
                            padding: const EdgeInsets.all(24),
                            child: Column(
                              children: [
                                Icon(Icons.info_outline, size: 48, color: Colors.grey[400]),
                                const SizedBox(height: 16),
                                Text(
                                  'Aucun solde d\'activité enregistré',
                                  style: TextStyle(color: Colors.grey[600]),
                                ),
                              ],
                            ),
                          ),
                        )
                      else
                        ...activities.map((doc) {
                          final data = doc.data() as Map<String, dynamic>;
                          final activityName = data['activityName'] ?? 'Activité inconnue';
                          final balanceUSD = (data['balanceUSD'] ?? 0).toDouble();
                          final balanceFC = (data['balanceFC'] ?? 0).toDouble();
                          final updatedAt = data['updatedAt'] as Timestamp?;

                          return Card(
                            margin: const EdgeInsets.only(bottom: 12),
                            elevation: 2,
                            child: ListTile(
                              leading: CircleAvatar(
                                backgroundColor: Colors.blue,
                                child: const Icon(Icons.business, color: Colors.white),
                              ),
                              title: Text(
                                activityName,
                                style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 16,
                                ),
                              ),
                              subtitle: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  if (balanceUSD > 0)
                                    Text(
                                      'USD: \$${balanceUSD.toStringAsFixed(2)}',
                                      style: const TextStyle(
                                        fontWeight: FontWeight.w500,
                                        color: Colors.blue,
                                      ),
                                    ),
                                  if (balanceFC > 0)
                                    Text(
                                      'FC: ${balanceFC.toStringAsFixed(2)}',
                                      style: const TextStyle(
                                        fontWeight: FontWeight.w500,
                                        color: Colors.green,
                                      ),
                                    ),
                                  if (balanceUSD == 0 && balanceFC == 0)
                                    const Text(
                                      'Solde: 0.00',
                                      style: TextStyle(color: Colors.grey),
                                    ),
                                  if (updatedAt != null)
                                    Text(
                                      'Mis à jour: ${DateFormat('dd/MM/yyyy HH:mm').format(updatedAt.toDate())}',
                                      style: TextStyle(
                                        fontSize: 12,
                                        color: Colors.grey[600],
                                      ),
                                    ),
                                ],
                              ),
                            ),
                          );
                        }).toList(),
                      const SizedBox(height: 24),
                      // Bouton historique
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton.icon(
                          onPressed: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) => const MainCashierHistoryPage(),
                              ),
                            );
                          },
                          icon: const Icon(Icons.history, size: 24),
                          label: const Text(
                            'Voir l\'historique complet',
                            style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                          ),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.black,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 18),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(16),
                            ),
                            elevation: 4,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }
}
