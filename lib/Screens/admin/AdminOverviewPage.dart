import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'AdminActivityDetailsPage.dart';

class AdminOverviewPage extends StatefulWidget {
  const AdminOverviewPage({super.key});

  @override
  State<AdminOverviewPage> createState() => _AdminOverviewPageState();
}

class _AdminOverviewPageState extends State<AdminOverviewPage> {
  Map<String, dynamic> globalStats = {};
  List<Map<String, dynamic>> activities = [];
  bool loading = true;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() => loading = true);

    // Charger les activités
    final activitiesQuery = await FirebaseFirestore.instance
        .collection('activities')
        .get();

    activities = activitiesQuery.docs.map((doc) {
      final data = doc.data();
      return {
        'id': doc.id,
        'name': data['activityName'] ?? 'Activité inconnue',
      };
    }).toList();

    // Calculer les statistiques globales
    await _calculateGlobalStats();

    setState(() => loading = false);
  }

  Future<void> _calculateGlobalStats() async {
    // Total des factures
    final invoicesQuery = await FirebaseFirestore.instance
        .collection('invoices')
        .get();

    double totalRevenue = 0;
    double totalPaid = 0;
    int totalInvoices = invoicesQuery.docs.length;
    int paidInvoices = 0;
    int partialInvoices = 0;
    int unpaidInvoices = 0;

    for (var doc in invoicesQuery.docs) {
      final data = doc.data();
      totalRevenue += (data['totalAmount'] ?? 0).toDouble();
      totalPaid += (data['amountPaid'] ?? 0).toDouble();
      
      final status = data['paymentStatus'] ?? 'unpaid';
      if (status == 'paid') paidInvoices++;
      else if (status == 'partial') partialInvoices++;
      else unpaidInvoices++;
    }

    // Total des tickets
    final ticketsQuery = await FirebaseFirestore.instance
        .collection('tickets')
        .get();

    int totalTickets = ticketsQuery.docs.length;
    int openTickets = 0;
    int closedTickets = 0;

    for (var doc in ticketsQuery.docs) {
      final data = doc.data();
      if (data['isOpen'] == true) {
        openTickets++;
      } else {
        closedTickets++;
      }
    }

    // Total des dépôts
    final depositsQuery = await FirebaseFirestore.instance
        .collection('deposits')
        .get();

    double totalDeposits = 0;
    for (var doc in depositsQuery.docs) {
      totalDeposits += (doc.data()['amount'] ?? 0).toDouble();
    }

    // Solde caisse principale
    final cashDoc = await FirebaseFirestore.instance
        .collection('main_cash')
        .doc('balance')
        .get();

    double mainCashBalance = 0;
    if (cashDoc.exists) {
      mainCashBalance = (cashDoc.data()?['balance'] ?? 0).toDouble();
    }

    // Nombre d'utilisateurs
    final usersQuery = await FirebaseFirestore.instance
        .collection('users')
        .get();

    int totalUsers = usersQuery.docs.length;

    setState(() {
      globalStats = {
        'totalRevenue': totalRevenue,
        'totalPaid': totalPaid,
        'totalInvoices': totalInvoices,
        'paidInvoices': paidInvoices,
        'partialInvoices': partialInvoices,
        'unpaidInvoices': unpaidInvoices,
        'totalTickets': totalTickets,
        'openTickets': openTickets,
        'closedTickets': closedTickets,
        'totalDeposits': totalDeposits,
        'mainCashBalance': mainCashBalance,
        'totalUsers': totalUsers,
      };
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Vue Globale", style: TextStyle(color: Colors.white)),
        backgroundColor: Colors.black,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadData,
          ),
        ],
      ),
      body: loading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _loadData,
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Statistiques globales
                    _buildStatsCard(),
                    const SizedBox(height: 20),
                    // Liste des activités
                    const Text(
                      'Activités',
                      style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 12),
                    ...activities.map((activity) => _buildActivityCard(activity)),
                  ],
                ),
              ),
            ),
    );
  }

  Widget _buildStatsCard() {
    return Card(
      elevation: 4,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Statistiques Globales',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            _buildStatRow('Chiffre d\'affaires total', globalStats['totalRevenue'] ?? 0, Colors.green),
            _buildStatRow('Montant payé total', globalStats['totalPaid'] ?? 0, Colors.blue),
            _buildStatRow('Solde caisse principale', globalStats['mainCashBalance'] ?? 0, Colors.purple),
            _buildStatRow('Total dépôts', globalStats['totalDeposits'] ?? 0, Colors.orange),
            const Divider(),
            _buildStatRow('Total factures', globalStats['totalInvoices'] ?? 0, null, isCount: true),
            _buildStatRow('Factures payées', globalStats['paidInvoices'] ?? 0, Colors.green, isCount: true),
            _buildStatRow('Factures partielles', globalStats['partialInvoices'] ?? 0, Colors.orange, isCount: true),
            _buildStatRow('Factures impayées', globalStats['unpaidInvoices'] ?? 0, Colors.red, isCount: true),
            const Divider(),
            _buildStatRow('Total tickets', globalStats['totalTickets'] ?? 0, null, isCount: true),
            _buildStatRow('Tickets ouverts', globalStats['openTickets'] ?? 0, Colors.orange, isCount: true),
            _buildStatRow('Tickets fermés', globalStats['closedTickets'] ?? 0, Colors.green, isCount: true),
            const Divider(),
            _buildStatRow('Total utilisateurs', globalStats['totalUsers'] ?? 0, null, isCount: true),
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

  Widget _buildActivityCard(Map<String, dynamic> activity) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: Colors.blue,
          child: const Icon(Icons.business, color: Colors.white),
        ),
        title: Text(
          activity['name'],
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        subtitle: Text('ID: ${activity['id']}'),
        trailing: const Icon(Icons.chevron_right),
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => AdminActivityDetailsPage(
                activityId: activity['id'],
                activityName: activity['name'],
              ),
            ),
          );
        },
      ),
    );
  }
}

