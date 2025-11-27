import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

/// Page admin pour voir les statistiques de caisse par activité
/// Affiche les entrées, sorties et la différence (entrées - sorties) avec double devise
class AdminCashReportPage extends StatefulWidget {
  const AdminCashReportPage({super.key});

  @override
  State<AdminCashReportPage> createState() => _AdminCashReportPageState();
}

class _AdminCashReportPageState extends State<AdminCashReportPage> {
  String selectedFilter = 'all'; // 'all', 'day', 'week', 'month', 'custom'
  String? selectedActivityName;
  DateTime? selectedDate;
  DateTime? startDate;
  DateTime? endDate;
  List<String> activities = [];
  bool loadingActivities = true;
  Map<String, dynamic>? summaryData;

  @override
  void initState() {
    super.initState();
    _loadActivities();
    _loadSummary();
  }

  Future<void> _loadActivities() async {
    try {
      final query = await FirebaseFirestore.instance
          .collection('activities')
          .orderBy('activityName')
          .get();

      setState(() {
        activities = query.docs
            .map((doc) => doc.data()['activityName'] as String? ?? '')
            .where((name) => name.isNotEmpty)
            .toList();
        loadingActivities = false;
      });
    } catch (e) {
      setState(() {
        loadingActivities = false;
      });
    }
  }

  Future<void> _loadSummary() async {
    setState(() {
      summaryData = null;
    });

    try {
      // Déterminer les dates selon le filtre
      DateTime? filterStartDate;
      DateTime? filterEndDate;

      if (selectedFilter == 'day' && selectedDate != null) {
        filterStartDate = DateTime(
          selectedDate!.year,
          selectedDate!.month,
          selectedDate!.day,
        );
        filterEndDate = filterStartDate.add(const Duration(days: 1));
      } else if (selectedFilter == 'week' && startDate != null && endDate != null) {
        filterStartDate = startDate;
        filterEndDate = endDate!.add(const Duration(days: 1));
      } else if (selectedFilter == 'month' && startDate != null && endDate != null) {
        filterStartDate = startDate;
        filterEndDate = endDate!.add(const Duration(days: 1));
      } else if (selectedFilter == 'custom' && startDate != null && endDate != null) {
        filterStartDate = startDate;
        filterEndDate = endDate!.add(const Duration(days: 1));
      }

      // Charger tous les mouvements (on filtrera côté client pour éviter les problèmes d'index)
      final movementsSnapshot = await FirebaseFirestore.instance
          .collection('main_cash_movements')
          .orderBy('date', descending: true)
          .get();

      // Calculer les statistiques
      Map<String, Map<String, double>> activityStats = {};

      // Initialiser toutes les activités
      for (var activityName in activities) {
        activityStats[activityName] = {
          'depositsUSD': 0.0,
          'depositsFC': 0.0,
          'withdrawalsUSD': 0.0,
          'withdrawalsFC': 0.0,
        };
      }

      // Parcourir les mouvements
      for (var doc in movementsSnapshot.docs) {
        final data = doc.data();
        final activityName = data['activityName'] as String? ?? '';
        final type = data['type'] as String? ?? '';
        final amountUSD = (data['amountUSD'] ?? 0).toDouble();
        final amountFC = (data['amountFC'] ?? 0).toDouble();
        final date = (data['date'] as Timestamp?)?.toDate();

        if (activityName.isEmpty) continue;

        // Filtrer par date si nécessaire
        if (filterStartDate != null && filterEndDate != null && date != null) {
          if (date.isBefore(filterStartDate) || date.isAfter(filterEndDate.subtract(const Duration(seconds: 1)))) {
            continue;
          }
        }

        // Filtrer par activité si sélectionnée
        if (selectedActivityName != null && activityName != selectedActivityName) {
          continue;
        }

        // Initialiser si l'activité n'existe pas encore
        if (!activityStats.containsKey(activityName)) {
          activityStats[activityName] = {
            'depositsUSD': 0.0,
            'depositsFC': 0.0,
            'withdrawalsUSD': 0.0,
            'withdrawalsFC': 0.0,
          };
        }

        if (type == 'deposit') {
          activityStats[activityName]!['depositsUSD'] =
              activityStats[activityName]!['depositsUSD']! + amountUSD;
          activityStats[activityName]!['depositsFC'] =
              activityStats[activityName]!['depositsFC']! + amountFC;
        } else if (type == 'withdrawal') {
          activityStats[activityName]!['withdrawalsUSD'] =
              activityStats[activityName]!['withdrawalsUSD']! + amountUSD;
          activityStats[activityName]!['withdrawalsFC'] =
              activityStats[activityName]!['withdrawalsFC']! + amountFC;
        }
      }

      // Calculer les totaux globaux
      double totalDepositsUSD = 0;
      double totalDepositsFC = 0;
      double totalWithdrawalsUSD = 0;
      double totalWithdrawalsFC = 0;

      for (var stats in activityStats.values) {
        totalDepositsUSD += stats['depositsUSD']!;
        totalDepositsFC += stats['depositsFC']!;
        totalWithdrawalsUSD += stats['withdrawalsUSD']!;
        totalWithdrawalsFC += stats['withdrawalsFC']!;
      }

      setState(() {
        summaryData = {
          'activities': activityStats,
          'totalDepositsUSD': totalDepositsUSD,
          'totalDepositsFC': totalDepositsFC,
          'totalWithdrawalsUSD': totalWithdrawalsUSD,
          'totalWithdrawalsFC': totalWithdrawalsFC,
          'netUSD': totalDepositsUSD - totalWithdrawalsUSD,
          'netFC': totalDepositsFC - totalWithdrawalsFC,
        };
      });
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Erreur lors du chargement: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Rapport Caisse", style: TextStyle(color: Colors.white)),
        backgroundColor: Colors.black,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadSummary,
          ),
        ],
      ),
      body: Column(
        children: [
          // Filtres
          Container(
            padding: const EdgeInsets.all(16),
            color: Colors.grey[100],
            child: Column(
              children: [
                // Filtre par période
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
                          ButtonSegment(value: 'custom', label: Text('Personnalisé')),
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
                            } else if (selectedFilter == 'week') {
                              final now = DateTime.now();
                              startDate = now.subtract(Duration(days: now.weekday - 1));
                              endDate = startDate!.add(const Duration(days: 6));
                            } else if (selectedFilter == 'month') {
                              final now = DateTime.now();
                              startDate = DateTime(now.year, now.month, 1);
                              endDate = DateTime(now.year, now.month + 1, 0);
                            }
                            _loadSummary();
                          });
                        },
                      ),
                    ),
                  ],
                ),
                // Sélection de date selon le filtre
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
                                _loadSummary();
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
                if ((selectedFilter == 'custom' || selectedFilter == 'week' || selectedFilter == 'month') &&
                    (startDate != null || endDate != null)) ...[
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: () async {
                            final picked = await showDatePicker(
                              context: context,
                              initialDate: startDate ?? DateTime.now(),
                              firstDate: DateTime(2020),
                              lastDate: endDate ?? DateTime.now(),
                            );
                            if (picked != null) {
                              setState(() {
                                startDate = picked;
                                if (selectedFilter == 'week') {
                                  endDate = startDate!.add(const Duration(days: 6));
                                } else if (selectedFilter == 'month') {
                                  endDate = DateTime(
                                    startDate!.year,
                                    startDate!.month + 1,
                                    0,
                                  );
                                }
                                _loadSummary();
                              });
                            }
                          },
                          icon: const Icon(Icons.calendar_today),
                          label: Text(
                            startDate != null
                                ? 'Du: ${DateFormat('dd/MM/yyyy').format(startDate!)}'
                                : 'Date début',
                          ),
                        ),
                      ),
                      if (selectedFilter == 'custom') ...[
                        const SizedBox(width: 12),
                        Expanded(
                          child: OutlinedButton.icon(
                            onPressed: () async {
                              final picked = await showDatePicker(
                                context: context,
                                initialDate: endDate ?? DateTime.now(),
                                firstDate: startDate ?? DateTime(2020),
                                lastDate: DateTime.now(),
                              );
                              if (picked != null) {
                                setState(() {
                                  endDate = picked;
                                  _loadSummary();
                                });
                              }
                            },
                            icon: const Icon(Icons.calendar_today),
                            label: Text(
                              endDate != null
                                  ? 'Au: ${DateFormat('dd/MM/yyyy').format(endDate!)}'
                                  : 'Date fin',
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                ],
                // Filtre par activité
                const SizedBox(height: 12),
                Row(
                  children: [
                    const Text(
                      'Activité: ',
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                    Expanded(
                      child: DropdownButtonFormField<String?>(
                        value: selectedActivityName,
                        decoration: InputDecoration(
                          filled: true,
                          fillColor: Colors.white,
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                        ),
                        items: [
                          const DropdownMenuItem<String?>(
                            value: null,
                            child: Text('Toutes les activités'),
                          ),
                          ...activities.map((activity) {
                            return DropdownMenuItem<String?>(
                              value: activity,
                              child: Text(activity),
                            );
                          }),
                        ],
                        onChanged: (value) {
                          setState(() {
                            selectedActivityName = value;
                            _loadSummary();
                          });
                        },
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          // Contenu
          Expanded(
            child: loadingActivities
                ? const Center(child: CircularProgressIndicator())
                : summaryData == null
                    ? const Center(child: CircularProgressIndicator())
                    : _buildSummary(),
          ),
        ],
      ),
    );
  }

  Widget _buildSummary() {
    final activities = summaryData!['activities'] as Map<String, Map<String, double>>;
    final totalDepositsUSD = summaryData!['totalDepositsUSD'] as double;
    final totalDepositsFC = summaryData!['totalDepositsFC'] as double;
    final totalWithdrawalsUSD = summaryData!['totalWithdrawalsUSD'] as double;
    final totalWithdrawalsFC = summaryData!['totalWithdrawalsFC'] as double;
    final netUSD = summaryData!['netUSD'] as double;
    final netFC = summaryData!['netFC'] as double;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Résumé global
          Card(
            elevation: 4,
            color: Colors.blue[50],
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Résumé Global',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 16),
                  _buildAmountRow('Total Entrées USD', totalDepositsUSD, Colors.green, isUSD: true),
                  _buildAmountRow('Total Entrées FC', totalDepositsFC, Colors.green),
                  const Divider(),
                  _buildAmountRow('Total Sorties USD', totalWithdrawalsUSD, Colors.red, isUSD: true),
                  _buildAmountRow('Total Sorties FC', totalWithdrawalsFC, Colors.red),
                  const Divider(),
                  _buildAmountRow(
                    'Différence (Entrées - Sorties) USD',
                    netUSD,
                    netUSD >= 0 ? Colors.green : Colors.red,
                    isUSD: true,
                    isBold: true,
                  ),
                  _buildAmountRow(
                    'Différence (Entrées - Sorties) FC',
                    netFC,
                    netFC >= 0 ? Colors.green : Colors.red,
                    isBold: true,
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 20),
          // Détails par activité
          const Text(
            'Détails par Activité',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 12),
          ...activities.entries.map((entry) {
            final activityName = entry.key;
            final stats = entry.value;
            final depositsUSD = stats['depositsUSD']!;
            final depositsFC = stats['depositsFC']!;
            final withdrawalsUSD = stats['withdrawalsUSD']!;
            final withdrawalsFC = stats['withdrawalsFC']!;
            final netActivityUSD = depositsUSD - withdrawalsUSD;
            final netActivityFC = depositsFC - withdrawalsFC;

            return Card(
              margin: const EdgeInsets.only(bottom: 12),
              elevation: 2,
              child: ExpansionTile(
                leading: CircleAvatar(
                  backgroundColor: Colors.blue,
                  child: const Icon(Icons.business, color: Colors.white),
                ),
                title: Text(
                  activityName,
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
                subtitle: Text(
                  'Net: ${netActivityUSD >= 0 ? '+' : ''}\$${netActivityUSD.toStringAsFixed(2)} / ${netActivityFC >= 0 ? '+' : ''}${netActivityFC.toStringAsFixed(2)} FC',
                  style: TextStyle(
                    color: (netActivityUSD >= 0 && netActivityFC >= 0)
                        ? Colors.green
                        : Colors.red,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                children: [
                  Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      children: [
                        _buildAmountRow('Entrées USD', depositsUSD, Colors.green, isUSD: true),
                        _buildAmountRow('Entrées FC', depositsFC, Colors.green),
                        const Divider(),
                        _buildAmountRow('Sorties USD', withdrawalsUSD, Colors.red, isUSD: true),
                        _buildAmountRow('Sorties FC', withdrawalsFC, Colors.red),
                        const Divider(),
                        _buildAmountRow(
                          'Différence USD',
                          netActivityUSD,
                          netActivityUSD >= 0 ? Colors.green : Colors.red,
                          isUSD: true,
                          isBold: true,
                        ),
                        _buildAmountRow(
                          'Différence FC',
                          netActivityFC,
                          netActivityFC >= 0 ? Colors.green : Colors.red,
                          isBold: true,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            );
          }),
        ],
      ),
    );
  }

  Widget _buildAmountRow(
    String label,
    double amount,
    Color color, {
    bool isUSD = false,
    bool isBold = false,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: TextStyle(
              fontSize: 14,
              fontWeight: isBold ? FontWeight.bold : FontWeight.normal,
            ),
          ),
          Text(
            isUSD
                ? '\$${amount.toStringAsFixed(2)}'
                : '${amount.toStringAsFixed(2)} FC',
            style: TextStyle(
              fontSize: 16,
              fontWeight: isBold ? FontWeight.bold : FontWeight.w500,
              color: color,
            ),
          ),
        ],
      ),
    );
  }
}

