import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

class AdminMonthlyReportPage extends StatefulWidget {
  const AdminMonthlyReportPage({super.key});

  @override
  State<AdminMonthlyReportPage> createState() => _AdminMonthlyReportPageState();
}

class _AdminMonthlyReportPageState extends State<AdminMonthlyReportPage> {
  DateTime selectedMonth = DateTime.now();
  Map<String, dynamic> monthlyStats = {};
  bool loading = true;

  @override
  void initState() {
    super.initState();
    _loadMonthlyData();
  }

  Future<void> _selectMonth(BuildContext context) async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: selectedMonth,
      firstDate: DateTime(2020),
      lastDate: DateTime.now(),
      helpText: 'Sélectionner un mois',
    );
    if (picked != null) {
      setState(() {
        selectedMonth = DateTime(picked.year, picked.month);
      });
      _loadMonthlyData();
    }
  }

  Future<void> _loadMonthlyData() async {
    setState(() => loading = true);

    final startOfMonth = DateTime(selectedMonth.year, selectedMonth.month, 1, 0, 0, 0);
    final endOfMonth = DateTime(
      selectedMonth.year,
      selectedMonth.month + 1,
      0,
      23,
      59,
      59,
    );

    // ✅ OPTIMISATION : Charger toutes les activités en une seule fois
    final activitiesQuery = await FirebaseFirestore.instance
        .collection('activities')
        .get();
    
    final Map<String, String> activityNames = {};
    for (var doc in activitiesQuery.docs) {
      final data = doc.data();
      activityNames[doc.id] = data['activityName'] ?? 'Inconnue';
    }

    // Factures du mois
    final invoicesQuery = await FirebaseFirestore.instance
        .collection('invoices')
        .where('createdAt', isGreaterThanOrEqualTo: Timestamp.fromDate(startOfMonth))
        .where('createdAt', isLessThanOrEqualTo: Timestamp.fromDate(endOfMonth))
        .get();

    double totalRevenue = 0;
    double totalPaid = 0;
    int totalInvoices = invoicesQuery.docs.length;
    Map<String, double> weeklyRevenue = {};
    Map<String, double> revenueByActivity = {};

    for (var doc in invoicesQuery.docs) {
      final data = doc.data();
      final amount = (data['totalAmount'] ?? 0).toDouble();
      final paid = (data['amountPaid'] ?? 0).toDouble();
      totalRevenue += amount;
      totalPaid += paid;

      // Par semaine
      final createdAt = (data['createdAt'] as Timestamp?)?.toDate();
      if (createdAt != null) {
        final weekNumber = ((createdAt.day - 1) ~/ 7) + 1;
        final weekKey = 'Semaine $weekNumber';
        weeklyRevenue[weekKey] = (weeklyRevenue[weekKey] ?? 0) + paid;
      }

      // ✅ OPTIMISATION : Utiliser le Map au lieu d'une requête Firestore
      final activityId = data['activityId'] ?? '';
      if (activityId.isNotEmpty && activityNames.containsKey(activityId)) {
        final activityName = activityNames[activityId]!;
        revenueByActivity[activityName] = (revenueByActivity[activityName] ?? 0) + paid;
      }
    }

    // Tickets du mois
    final ticketsQuery = await FirebaseFirestore.instance
        .collection('tickets')
        .where('createdAt', isGreaterThanOrEqualTo: Timestamp.fromDate(startOfMonth))
        .where('createdAt', isLessThanOrEqualTo: Timestamp.fromDate(endOfMonth))
        .get();

    int totalTickets = ticketsQuery.docs.length;
    double ticketsTotal = 0;

    for (var doc in ticketsQuery.docs) {
      ticketsTotal += (doc.data()['total'] ?? 0).toDouble();
    }

    // Dépôts du mois
    final depositsQuery = await FirebaseFirestore.instance
        .collection('deposits')
        .where('date', isGreaterThanOrEqualTo: Timestamp.fromDate(startOfMonth))
        .where('date', isLessThanOrEqualTo: Timestamp.fromDate(endOfMonth))
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
      monthlyStats = {
        'totalRevenue': totalRevenue,
        'totalPaid': totalPaid,
        'totalInvoices': totalInvoices,
        'totalTickets': totalTickets,
        'ticketsTotal': ticketsTotal,
        'totalDeposits': totalDeposits,
        'weeklyRevenue': weeklyRevenue,
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
        title: const Text("Résumé Mensuel", style: TextStyle(color: Colors.white)),
        backgroundColor: Colors.black,
        actions: [
          IconButton(
            icon: const Icon(Icons.calendar_today),
            onPressed: () => _selectMonth(context),
          ),
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadMonthlyData,
          ),
        ],
      ),
      body: loading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _loadMonthlyData,
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Card(
                      color: Colors.purple.shade50,
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text(
                                  'Mois sélectionné',
                                  style: TextStyle(fontSize: 12, color: Colors.grey),
                                ),
                                Text(
                                  DateFormat('MMMM yyyy', 'fr').format(selectedMonth),
                                  style: const TextStyle(
                                    fontSize: 18,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ],
                            ),
                            IconButton(
                              icon: const Icon(Icons.calendar_today),
                              onPressed: () => _selectMonth(context),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 20),
                    _buildSummaryCard(),
                    const SizedBox(height: 20),
                    _buildWeeklyRevenueCard(),
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
    final daysInMonth = DateTime(selectedMonth.year, selectedMonth.month + 1, 0).day;
    final avgDaily = (monthlyStats['totalPaid'] ?? 0) / daysInMonth;

    return Card(
      elevation: 4,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Résumé du Mois',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            _buildStatRow('Chiffre d\'affaires', monthlyStats['totalRevenue'] ?? 0, Colors.green),
            _buildStatRow('Montant payé', monthlyStats['totalPaid'] ?? 0, Colors.blue),
            _buildStatRow('Total dépôts', monthlyStats['totalDeposits'] ?? 0, Colors.orange),
            const Divider(),
            _buildStatRow('Nombre de factures', monthlyStats['totalInvoices'] ?? 0, null, isCount: true),
            _buildStatRow('Nombre de tickets', monthlyStats['totalTickets'] ?? 0, null, isCount: true),
            _buildStatRow('Total tickets', monthlyStats['ticketsTotal'] ?? 0, Colors.purple),
            const Divider(),
            _buildStatRow('Moyenne journalière', avgDaily, Colors.grey),
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

  Widget _buildWeeklyRevenueCard() {
    final weeklyRevenue = monthlyStats['weeklyRevenue'] as Map<String, double>? ?? {};

    return Card(
      child: ExpansionTile(
        title: const Text('Revenus par Semaine', style: TextStyle(fontWeight: FontWeight.bold)),
        children: [
          if (weeklyRevenue.isEmpty)
            const Padding(
              padding: EdgeInsets.all(16),
              child: Text('Aucun revenu enregistré'),
            )
          else
            ...weeklyRevenue.entries.map((entry) => ListTile(
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

  Widget _buildRevenueByActivityCard() {
    final revenueByActivity = monthlyStats['revenueByActivity'] as Map<String, double>? ?? {};

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
    final depositsByActivity = monthlyStats['depositsByActivity'] as Map<String, double>? ?? {};

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


