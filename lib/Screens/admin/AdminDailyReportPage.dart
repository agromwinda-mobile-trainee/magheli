import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

class AdminDailyReportPage extends StatefulWidget {
  const AdminDailyReportPage({super.key});

  @override
  State<AdminDailyReportPage> createState() => _AdminDailyReportPageState();
}

class _AdminDailyReportPageState extends State<AdminDailyReportPage> {
  DateTime selectedDate = DateTime.now();
  Map<String, dynamic> dailyStats = {};
  bool loading = true;

  @override
  void initState() {
    super.initState();
    _loadDailyData();
  }

  Future<void> _selectDate(BuildContext context) async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: selectedDate,
      firstDate: DateTime(2020),
      lastDate: DateTime.now(),
    );
    if (picked != null && picked != selectedDate) {
      setState(() {
        selectedDate = picked;
      });
      _loadDailyData();
    }
  }

  Future<void> _loadDailyData() async {
    setState(() => loading = true);

    final startOfDay = DateTime(selectedDate.year, selectedDate.month, selectedDate.day, 0, 0, 0);
    final endOfDay = DateTime(selectedDate.year, selectedDate.month, selectedDate.day, 23, 59, 59);

    // Factures du jour
    final invoicesQuery = await FirebaseFirestore.instance
        .collection('invoices')
        .where('createdAt', isGreaterThanOrEqualTo: Timestamp.fromDate(startOfDay))
        .where('createdAt', isLessThanOrEqualTo: Timestamp.fromDate(endOfDay))
        .get();

    double totalRevenue = 0;
    double totalPaid = 0;
    int totalInvoices = invoicesQuery.docs.length;
    Map<String, double> revenueByActivity = {};

    for (var doc in invoicesQuery.docs) {
      final data = doc.data();
      final amount = (data['totalAmount'] ?? 0).toDouble();
      final paid = (data['amountPaid'] ?? 0).toDouble();
      totalRevenue += amount;
      totalPaid += paid;

      // Par activité
      final activityId = data['activityId'] ?? '';
      if (activityId.isNotEmpty) {
        final activityDoc = await FirebaseFirestore.instance
            .collection('activities')
            .doc(activityId)
            .get();
        final activityName = activityDoc.data()?['activityName'] ?? 'Inconnue';
        revenueByActivity[activityName] = (revenueByActivity[activityName] ?? 0) + paid;
      }
    }

    // Tickets du jour
    final ticketsQuery = await FirebaseFirestore.instance
        .collection('tickets')
        .where('createdAt', isGreaterThanOrEqualTo: Timestamp.fromDate(startOfDay))
        .where('createdAt', isLessThanOrEqualTo: Timestamp.fromDate(endOfDay))
        .get();

    int totalTickets = ticketsQuery.docs.length;
    double ticketsTotal = 0;

    for (var doc in ticketsQuery.docs) {
      ticketsTotal += (doc.data()['total'] ?? 0).toDouble();
    }

    // Dépôts du jour
    final depositsQuery = await FirebaseFirestore.instance
        .collection('deposits')
        .where('date', isGreaterThanOrEqualTo: Timestamp.fromDate(startOfDay))
        .where('date', isLessThanOrEqualTo: Timestamp.fromDate(endOfDay))
        .get();

    double totalDeposits = 0;
    Map<String, double> depositsByActivity = {};

    for (var doc in depositsQuery.docs) {
      final data = doc.data();
      final amount = (data['amount'] ?? 0).toDouble();
      totalDeposits += amount;

      final activityName = data['activityName'] ?? 'Inconnue';
      depositsByActivity[activityName] = (depositsByActivity[activityName] ?? 0) + amount;
    }

    setState(() {
      dailyStats = {
        'totalRevenue': totalRevenue,
        'totalPaid': totalPaid,
        'totalInvoices': totalInvoices,
        'totalTickets': totalTickets,
        'ticketsTotal': ticketsTotal,
        'totalDeposits': totalDeposits,
        'revenueByActivity': revenueByActivity,
        'depositsByActivity': depositsByActivity,
      };
      loading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Résumé Journalier", style: TextStyle(color: Colors.white)),
        backgroundColor: Colors.black,
        actions: [
          IconButton(
            icon: const Icon(Icons.calendar_today),
            onPressed: () => _selectDate(context),
          ),
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadDailyData,
          ),
        ],
      ),
      body: loading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _loadDailyData,
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Card(
                      color: Colors.blue.shade50,
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text(
                                  'Date sélectionnée',
                                  style: TextStyle(fontSize: 12, color: Colors.grey),
                                ),
                                Text(
                                  DateFormat('dd MMMM yyyy', 'fr').format(selectedDate),
                                  style: const TextStyle(
                                    fontSize: 18,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ],
                            ),
                            IconButton(
                              icon: const Icon(Icons.calendar_today),
                              onPressed: () => _selectDate(context),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 20),
                    _buildSummaryCard(),
                    const SizedBox(height: 20),
                    _buildRevenueByActivityCard(),
                    const SizedBox(height: 20),
                    _buildDepositsByActivityCard(),
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
              'Résumé du Jour',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            _buildStatRow('Chiffre d\'affaires', dailyStats['totalRevenue'] ?? 0, Colors.green),
            _buildStatRow('Montant payé', dailyStats['totalPaid'] ?? 0, Colors.blue),
            _buildStatRow('Total dépôts', dailyStats['totalDeposits'] ?? 0, Colors.orange),
            const Divider(),
            _buildStatRow('Nombre de factures', dailyStats['totalInvoices'] ?? 0, null, isCount: true),
            _buildStatRow('Nombre de tickets', dailyStats['totalTickets'] ?? 0, null, isCount: true),
            _buildStatRow('Total tickets', dailyStats['ticketsTotal'] ?? 0, Colors.purple),
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

  Widget _buildRevenueByActivityCard() {
    final revenueByActivity = dailyStats['revenueByActivity'] as Map<String, double>? ?? {};

    return Card(
      child: ExpansionTile(
        title: const Text('Revenus par Activité', style: TextStyle(fontWeight: FontWeight.bold)),
        children: [
          if (revenueByActivity.isEmpty)
            const Padding(
              padding: EdgeInsets.all(16),
              child: Text('Aucun revenu enregistré'),
            )
          else
            ...revenueByActivity.entries.map((entry) => ListTile(
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

  Widget _buildDepositsByActivityCard() {
    final depositsByActivity = dailyStats['depositsByActivity'] as Map<String, double>? ?? {};

    return Card(
      child: ExpansionTile(
        title: const Text('Dépôts par Activité', style: TextStyle(fontWeight: FontWeight.bold)),
        children: [
          if (depositsByActivity.isEmpty)
            const Padding(
              padding: EdgeInsets.all(16),
              child: Text('Aucun dépôt enregistré'),
            )
          else
            ...depositsByActivity.entries.map((entry) => ListTile(
                  title: Text(entry.key),
                  trailing: Text(
                    '${entry.value.toStringAsFixed(2)} FC',
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      color: Colors.orange,
                    ),
                  ),
                )),
          const SizedBox(height: 8),
        ],
      ),
    );
  }
}

