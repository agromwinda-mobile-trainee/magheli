import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

class AdminWeeklyReportPage extends StatefulWidget {
  const AdminWeeklyReportPage({super.key});

  @override
  State<AdminWeeklyReportPage> createState() => _AdminWeeklyReportPageState();
}

class _AdminWeeklyReportPageState extends State<AdminWeeklyReportPage> {
  DateTime selectedWeekStart = DateTime.now().subtract(Duration(days: DateTime.now().weekday - 1));
  Map<String, dynamic> weeklyStats = {};
  bool loading = true;

  @override
  void initState() {
    super.initState();
    _loadWeeklyData();
  }

  DateTime get _weekEnd => selectedWeekStart.add(const Duration(days: 6));

  Future<void> _selectWeek(BuildContext context) async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: selectedWeekStart,
      firstDate: DateTime(2020),
      lastDate: DateTime.now(),
    );
    if (picked != null) {
      setState(() {
        selectedWeekStart = picked.subtract(Duration(days: picked.weekday - 1));
      });
      _loadWeeklyData();
    }
  }

  Future<void> _loadWeeklyData() async {
    setState(() => loading = true);

    final startOfWeek = DateTime(
      selectedWeekStart.year,
      selectedWeekStart.month,
      selectedWeekStart.day,
      0,
      0,
      0,
    );
    final endOfWeek = DateTime(
      _weekEnd.year,
      _weekEnd.month,
      _weekEnd.day,
      23,
      59,
      59,
    );

    // Factures de la semaine
    final invoicesQuery = await FirebaseFirestore.instance
        .collection('invoices')
        .where('createdAt', isGreaterThanOrEqualTo: Timestamp.fromDate(startOfWeek))
        .where('createdAt', isLessThanOrEqualTo: Timestamp.fromDate(endOfWeek))
        .get();

    double totalRevenue = 0;
    double totalPaid = 0;
    int totalInvoices = invoicesQuery.docs.length;
    Map<String, double> dailyRevenue = {};

    for (var doc in invoicesQuery.docs) {
      final data = doc.data();
      final amount = (data['totalAmount'] ?? 0).toDouble();
      final paid = (data['amountPaid'] ?? 0).toDouble();
      totalRevenue += amount;
      totalPaid += paid;

      // Par jour
      final createdAt = (data['createdAt'] as Timestamp?)?.toDate();
      if (createdAt != null) {
        final dayKey = DateFormat('dd/MM').format(createdAt);
        dailyRevenue[dayKey] = (dailyRevenue[dayKey] ?? 0) + paid;
      }
    }

    // Tickets de la semaine
    final ticketsQuery = await FirebaseFirestore.instance
        .collection('tickets')
        .where('createdAt', isGreaterThanOrEqualTo: Timestamp.fromDate(startOfWeek))
        .where('createdAt', isLessThanOrEqualTo: Timestamp.fromDate(endOfWeek))
        .get();

    int totalTickets = ticketsQuery.docs.length;
    double ticketsTotal = 0;

    for (var doc in ticketsQuery.docs) {
      ticketsTotal += (doc.data()['total'] ?? 0).toDouble();
    }

    // Dépôts de la semaine
    final depositsQuery = await FirebaseFirestore.instance
        .collection('deposits')
        .where('date', isGreaterThanOrEqualTo: Timestamp.fromDate(startOfWeek))
        .where('date', isLessThanOrEqualTo: Timestamp.fromDate(endOfWeek))
        .get();

    double totalDeposits = 0;
    for (var doc in depositsQuery.docs) {
      totalDeposits += (doc.data()['amount'] ?? 0).toDouble();
    }

    setState(() {
      weeklyStats = {
        'totalRevenue': totalRevenue,
        'totalPaid': totalPaid,
        'totalInvoices': totalInvoices,
        'totalTickets': totalTickets,
        'ticketsTotal': ticketsTotal,
        'totalDeposits': totalDeposits,
        'dailyRevenue': dailyRevenue,
      };
      loading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Résumé Hebdomadaire", style: TextStyle(color: Colors.white)),
        backgroundColor: Colors.black,
        actions: [
          IconButton(
            icon: const Icon(Icons.calendar_today),
            onPressed: () => _selectWeek(context),
          ),
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadWeeklyData,
          ),
        ],
      ),
      body: loading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _loadWeeklyData,
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Card(
                      color: Colors.orange.shade50,
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text(
                                  'Semaine sélectionnée',
                                  style: TextStyle(fontSize: 12, color: Colors.grey),
                                ),
                                Text(
                                  '${DateFormat('dd MMM', 'fr').format(selectedWeekStart)} - ${DateFormat('dd MMM yyyy', 'fr').format(_weekEnd)}',
                                  style: const TextStyle(
                                    fontSize: 18,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ],
                            ),
                            IconButton(
                              icon: const Icon(Icons.calendar_today),
                              onPressed: () => _selectWeek(context),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 20),
                    _buildSummaryCard(),
                    const SizedBox(height: 20),
                    _buildDailyRevenueCard(),
                  ],
                ),
              ),
            ),
    );
  }

  Widget _buildSummaryCard() {
    return Card(
      elevation: 4,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Résumé de la Semaine',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            _buildStatRow('Chiffre d\'affaires', weeklyStats['totalRevenue'] ?? 0, Colors.green),
            _buildStatRow('Montant payé', weeklyStats['totalPaid'] ?? 0, Colors.blue),
            _buildStatRow('Total dépôts', weeklyStats['totalDeposits'] ?? 0, Colors.orange),
            const Divider(),
            _buildStatRow('Nombre de factures', weeklyStats['totalInvoices'] ?? 0, null, isCount: true),
            _buildStatRow('Nombre de tickets', weeklyStats['totalTickets'] ?? 0, null, isCount: true),
            _buildStatRow('Total tickets', weeklyStats['ticketsTotal'] ?? 0, Colors.purple),
            const Divider(),
            _buildStatRow(
              'Moyenne journalière',
              (weeklyStats['totalPaid'] ?? 0) / 7,
              Colors.grey,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatRow(String label, dynamic value, Color? color, {bool isCount = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: const TextStyle(fontSize: 14)),
          Text(
            isCount
                ? value.toString()
                : '${(value as double).toStringAsFixed(2)} FC',
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

  Widget _buildDailyRevenueCard() {
    final dailyRevenue = weeklyStats['dailyRevenue'] as Map<String, double>? ?? {};

    return Card(
      child: ExpansionTile(
        title: const Text('Revenus par Jour', style: TextStyle(fontWeight: FontWeight.bold)),
        children: [
          if (dailyRevenue.isEmpty)
            const Padding(
              padding: EdgeInsets.all(16),
              child: Text('Aucun revenu enregistré'),
            )
          else
            ...dailyRevenue.entries.map((entry) => ListTile(
                  title: Text(entry.key),
                  trailing: Text(
                    '${entry.value.toStringAsFixed(2)} FC',
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      color: Colors.green,
                    ),
                  ),
                )),
          const SizedBox(height: 8),
        ],
      ),
    );
  }
}




