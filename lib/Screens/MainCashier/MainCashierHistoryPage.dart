import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

/// Page d'historique des mouvements de caisse avec filtres (jour, semaine, mois)
class MainCashierHistoryPage extends StatefulWidget {
  const MainCashierHistoryPage({super.key});

  @override
  State<MainCashierHistoryPage> createState() => _MainCashierHistoryPageState();
}

class _MainCashierHistoryPageState extends State<MainCashierHistoryPage> {
  String selectedFilter = 'all'; // 'all', 'day', 'week', 'month'
  DateTime? selectedDate;
  DateTime? startDate;
  DateTime? endDate;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Historique Caisse", style: TextStyle(color: Colors.white)),
        backgroundColor: Colors.black,
      ),
      body: Column(
        children: [
          // Filtres
          Container(
            padding: const EdgeInsets.all(16),
            color: Colors.grey[100],
            child: Column(
              children: [
                // Sélection du type de filtre
                Row(
                  children: [
                    const Text(
                      'Période: ',
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                    Expanded(
                      child: SegmentedButton<String>(
                        segments: const [
                          ButtonSegment(value: 'all', label: Text('Tout')),
                          ButtonSegment(value: 'day', label: Text('Jour')),
                          ButtonSegment(value: 'week', label: Text('Semaine')),
                          ButtonSegment(value: 'month', label: Text('Mois')),
                        ],
                        selected: {selectedFilter},
                        onSelectionChanged: (Set<String> newSelection) {
                          setState(() {
                            selectedFilter = newSelection.first;
                            if (selectedFilter == 'all') {
                              selectedDate = null;
                              startDate = null;
                              endDate = null;
                            } else if (selectedFilter == 'day') {
                              selectedDate = DateTime.now();
                              startDate = null;
                              endDate = null;
                            } else if (selectedFilter == 'week') {
                              final now = DateTime.now();
                              startDate = now.subtract(Duration(days: now.weekday - 1));
                              endDate = startDate!.add(const Duration(days: 6));
                              selectedDate = null;
                            } else if (selectedFilter == 'month') {
                              final now = DateTime.now();
                              startDate = DateTime(now.year, now.month, 1);
                              endDate = DateTime(now.year, now.month + 1, 0);
                              selectedDate = null;
                            }
                          });
                        },
                      ),
                    ),
                  ],
                ),
                // Sélection de date si nécessaire
                if (selectedFilter == 'day' && selectedDate != null) ...[
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      const Text('Date: '),
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: () async {
                            final picked = await showDatePicker(
                              context: context,
                              initialDate: selectedDate!,
                              firstDate: DateTime(2020),
                              lastDate: DateTime.now(),
                            );
                            if (picked != null) {
                              setState(() {
                                selectedDate = picked;
                              });
                            }
                          },
                          icon: const Icon(Icons.calendar_today),
                          label: Text(DateFormat('dd/MM/yyyy').format(selectedDate!)),
                        ),
                      ),
                    ],
                  ),
                ],
              ],
            ),
          ),
          // Liste des mouvements
          Expanded(
            child: _MovementsList(
              filter: selectedFilter,
              selectedDate: selectedDate,
              startDate: startDate,
              endDate: endDate,
            ),
          ),
        ],
      ),
    );
  }
}

class _MovementsList extends StatelessWidget {
  final String filter;
  final DateTime? selectedDate;
  final DateTime? startDate;
  final DateTime? endDate;

  const _MovementsList({
    required this.filter,
    this.selectedDate,
    this.startDate,
    this.endDate,
  });

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('main_cash_movements')
          .orderBy('date', descending: true)
          .snapshots(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return const Center(child: CircularProgressIndicator());
        }

        final movements = snapshot.data!.docs.map((doc) {
          final data = doc.data() as Map<String, dynamic>;
          final date = (data['date'] as Timestamp?)?.toDate() ?? DateTime.now();
          return {
            'id': doc.id,
            'activityName': data['activityName'] ?? '',
            'amountUSD': (data['amountUSD'] ?? 0).toDouble(),
            'amountFC': (data['amountFC'] ?? 0).toDouble(),
            'type': data['type'] ?? 'withdrawal',
            'reason': data['reason'] ?? '',
            'cashierName': data['cashierName'] ?? 'Inconnu',
            'date': date,
          };
        }).toList();

        // Filtrer selon la période
        List<Map<String, dynamic>> filteredMovements = movements;

        if (filter == 'day' && selectedDate != null) {
          filteredMovements = movements.where((m) {
            final date = m['date'] as DateTime;
            return date.year == selectedDate!.year &&
                date.month == selectedDate!.month &&
                date.day == selectedDate!.day;
          }).toList();
        } else if (filter == 'week' && startDate != null && endDate != null) {
          filteredMovements = movements.where((m) {
            final date = m['date'] as DateTime;
            return date.isAfter(startDate!.subtract(const Duration(days: 1))) &&
                date.isBefore(endDate!.add(const Duration(days: 1)));
          }).toList();
        } else if (filter == 'month' && startDate != null && endDate != null) {
          filteredMovements = movements.where((m) {
            final date = m['date'] as DateTime;
            return date.isAfter(startDate!.subtract(const Duration(days: 1))) &&
                date.isBefore(endDate!.add(const Duration(days: 1)));
          }).toList();
        }

        if (filteredMovements.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.history, size: 64, color: Colors.grey[400]),
                const SizedBox(height: 16),
                Text(
                  'Aucun mouvement pour cette période',
                  style: TextStyle(color: Colors.grey[600]),
                ),
              ],
            ),
          );
        }

        // Calculer les totaux
        double totalDepositsUSD = 0;
        double totalDepositsFC = 0;
        double totalWithdrawalsUSD = 0;
        double totalWithdrawalsFC = 0;

        for (var m in filteredMovements) {
          final amountUSD = m['amountUSD'] as double;
          final amountFC = m['amountFC'] as double;
          final type = m['type'] as String;

          if (type == 'deposit') {
            totalDepositsUSD += amountUSD;
            totalDepositsFC += amountFC;
          } else {
            totalWithdrawalsUSD += amountUSD;
            totalWithdrawalsFC += amountFC;
          }
        }

        return Column(
          children: [
            // Résumé
            Container(
              padding: const EdgeInsets.all(16),
              color: Colors.blue[50],
              child: Column(
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: _SummaryCard(
                          label: 'Entrées',
                          amountUSD: totalDepositsUSD,
                          amountFC: totalDepositsFC,
                          color: Colors.green,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: _SummaryCard(
                          label: 'Sorties',
                          amountUSD: totalWithdrawalsUSD,
                          amountFC: totalWithdrawalsFC,
                          color: Colors.red,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            // Liste
            Expanded(
              child: ListView.builder(
                padding: const EdgeInsets.all(16),
                itemCount: filteredMovements.length,
                itemBuilder: (context, index) {
                  final movement = filteredMovements[index];
                  final amountUSD = movement['amountUSD'] as double;
                  final amountFC = movement['amountFC'] as double;
                  final type = movement['type'] as String;
                  final reason = movement['reason'] as String;
                  final activityName = movement['activityName'] as String;
                  final cashierName = movement['cashierName'] as String;
                  final date = movement['date'] as DateTime;
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
                        isDeposit ? 'Entrée' : 'Sortie',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          color: isDeposit ? Colors.green : Colors.red,
                        ),
                      ),
                      subtitle: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            'Activité: $activityName',
                            style: const TextStyle(fontWeight: FontWeight.w500),
                            overflow: TextOverflow.ellipsis,
                            maxLines: 1,
                          ),
                          if (reason.isNotEmpty)
                            Text(
                              reason,
                              overflow: TextOverflow.ellipsis,
                              maxLines: 1,
                            ),
                          Text(
                            'Par: $cashierName',
                            overflow: TextOverflow.ellipsis,
                            maxLines: 1,
                          ),
                          Text(
                            DateFormat('dd/MM/yyyy HH:mm').format(date),
                            style: TextStyle(color: Colors.grey[600], fontSize: 12),
                          ),
                        ],
                      ),
                      trailing: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          if (amountUSD > 0)
                            Text(
                              '${isDeposit ? '+' : '-'}\$${amountUSD.toStringAsFixed(2)}',
                              style: TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.bold,
                                color: isDeposit ? Colors.green : Colors.red,
                              ),
                            ),
                          if (amountFC > 0)
                            Text(
                              '${isDeposit ? '+' : '-'}${amountFC.toStringAsFixed(2)} FC',
                              style: TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.bold,
                                color: isDeposit ? Colors.green : Colors.red,
                              ),
                            ),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),
          ],
        );
      },
    );
  }
}

class _SummaryCard extends StatelessWidget {
  final String label;
  final double amountUSD;
  final double amountFC;
  final Color color;

  const _SummaryCard({
    required this.label,
    required this.amountUSD,
    required this.amountFC,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: TextStyle(
              fontSize: 12,
              color: Colors.grey[700],
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 4),
          if (amountUSD > 0)
            Text(
              '\$${amountUSD.toStringAsFixed(2)}',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: color,
              ),
            ),
          if (amountFC > 0)
            Text(
              '${amountFC.toStringAsFixed(2)} FC',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: color,
              ),
            ),
          if (amountUSD == 0 && amountFC == 0)
            Text(
              '0.00',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: color,
              ),
            ),
        ],
      ),
    );
  }
}

