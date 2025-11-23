import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

class AdminActivityDetailsPage extends StatefulWidget {
  final String activityId;
  final String activityName;

  const AdminActivityDetailsPage({
    super.key,
    required this.activityId,
    required this.activityName,
  });

  @override
  State<AdminActivityDetailsPage> createState() => _AdminActivityDetailsPageState();
}

class _AdminActivityDetailsPageState extends State<AdminActivityDetailsPage> {
  Map<String, dynamic> activityStats = {};
  bool loading = true;

  @override
  void initState() {
    super.initState();
    _loadActivityData();
  }

  Future<void> _loadActivityData() async {
    setState(() => loading = true);

    // Factures de l'activité
    final invoicesQuery = await FirebaseFirestore.instance
        .collection('invoices')
        .where('activityId', isEqualTo: widget.activityId)
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

    // Tickets de l'activité
    final ticketsQuery = await FirebaseFirestore.instance
        .collection('tickets')
        .where('activity', isEqualTo: widget.activityName)
        .get();

    int totalTickets = ticketsQuery.docs.length;
    int openTickets = 0;
    int closedTickets = 0;
    double ticketsTotal = 0;

    for (var doc in ticketsQuery.docs) {
      final data = doc.data();
      ticketsTotal += (data['total'] ?? 0).toDouble();
      if (data['isOpen'] == true) {
        openTickets++;
      } else {
        closedTickets++;
      }
    }

    // Dépôts de l'activité
    final depositsQuery = await FirebaseFirestore.instance
        .collection('deposits')
        .where('activityName', isEqualTo: widget.activityName)
        .get();

    double totalDeposits = 0;
    for (var doc in depositsQuery.docs) {
      totalDeposits += (doc.data()['amount'] ?? 0).toDouble();
    }

    // Produits de l'activité
    final productsQuery = await FirebaseFirestore.instance
        .collection('products')
        .where('activity', isEqualTo: widget.activityName)
        .get();

    int totalProducts = productsQuery.docs.length;

    // Stock de l'activité
    final stockQuery = await FirebaseFirestore.instance
        .collection('stock')
        .where('activity', isEqualTo: widget.activityName)
        .get();

    int totalStockItems = stockQuery.docs.length;
    int lowStockItems = 0;
    int outOfStockItems = 0;

    for (var doc in stockQuery.docs) {
      final qty = (doc.data()['quantity'] ?? 0) as int;
      if (qty == 0) outOfStockItems++;
      else if (qty <= 10) lowStockItems++;
    }

    // Utilisateurs de l'activité
    final usersQuery = await FirebaseFirestore.instance
        .collection('users')
        .where('activityId', isEqualTo: widget.activityId)
        .get();

    int totalUsers = usersQuery.docs.length;

    setState(() {
      activityStats = {
        'totalRevenue': totalRevenue,
        'totalPaid': totalPaid,
        'totalInvoices': totalInvoices,
        'paidInvoices': paidInvoices,
        'partialInvoices': partialInvoices,
        'unpaidInvoices': unpaidInvoices,
        'totalTickets': totalTickets,
        'openTickets': openTickets,
        'closedTickets': closedTickets,
        'ticketsTotal': ticketsTotal,
        'totalDeposits': totalDeposits,
        'totalProducts': totalProducts,
        'totalStockItems': totalStockItems,
        'lowStockItems': lowStockItems,
        'outOfStockItems': outOfStockItems,
        'totalUsers': totalUsers,
      };
      loading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.activityName, style: const TextStyle(color: Colors.white)),
        backgroundColor: Colors.black,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadActivityData,
          ),
        ],
      ),
      body: loading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _loadActivityData,
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildStatsCard(),
                    const SizedBox(height: 20),
                    _buildInvoicesSection(),
                    const SizedBox(height: 20),
                    _buildTicketsSection(),
                    const SizedBox(height: 20),
                    _buildDepositsSection(),
                    const SizedBox(height: 20),
                    _buildProductsSection(),
                    const SizedBox(height: 20),
                    _buildStockSection(),
                    const SizedBox(height: 20),
                    _buildUsersSection(),
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
              'Statistiques',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            _buildStatRow('Chiffre d\'affaires', activityStats['totalRevenue'] ?? 0, Colors.green),
            _buildStatRow('Montant payé', activityStats['totalPaid'] ?? 0, Colors.blue),
            _buildStatRow('Total dépôts', activityStats['totalDeposits'] ?? 0, Colors.orange),
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

  Widget _buildInvoicesSection() {
    return Card(
      child: ExpansionTile(
        title: const Text('Factures', style: TextStyle(fontWeight: FontWeight.bold)),
        children: [
          _buildStatRow('Total factures', activityStats['totalInvoices'] ?? 0, null, isCount: true),
          _buildStatRow('Payées', activityStats['paidInvoices'] ?? 0, Colors.green, isCount: true),
          _buildStatRow('Partielles', activityStats['partialInvoices'] ?? 0, Colors.orange, isCount: true),
          _buildStatRow('Impayées', activityStats['unpaidInvoices'] ?? 0, Colors.red, isCount: true),
          const SizedBox(height: 8),
        ],
      ),
    );
  }

  Widget _buildTicketsSection() {
    return Card(
      child: ExpansionTile(
        title: const Text('Tickets', style: TextStyle(fontWeight: FontWeight.bold)),
        children: [
          _buildStatRow('Total tickets', activityStats['totalTickets'] ?? 0, null, isCount: true),
          _buildStatRow('Ouverts', activityStats['openTickets'] ?? 0, Colors.orange, isCount: true),
          _buildStatRow('Fermés', activityStats['closedTickets'] ?? 0, Colors.green, isCount: true),
          _buildStatRow('Total tickets', activityStats['ticketsTotal'] ?? 0, Colors.blue),
          const SizedBox(height: 8),
        ],
      ),
    );
  }

  Widget _buildDepositsSection() {
    return Card(
      child: ExpansionTile(
        title: const Text('Dépôts', style: TextStyle(fontWeight: FontWeight.bold)),
        children: [
          _buildStatRow('Total dépôts', activityStats['totalDeposits'] ?? 0, Colors.orange),
          const SizedBox(height: 8),
        ],
      ),
    );
  }

  Widget _buildProductsSection() {
    return Card(
      child: ExpansionTile(
        title: const Text('Produits', style: TextStyle(fontWeight: FontWeight.bold)),
        children: [
          _buildStatRow('Nombre de produits', activityStats['totalProducts'] ?? 0, null, isCount: true),
          const SizedBox(height: 8),
        ],
      ),
    );
  }

  Widget _buildStockSection() {
    return Card(
      child: ExpansionTile(
        title: const Text('Stock', style: TextStyle(fontWeight: FontWeight.bold)),
        children: [
          _buildStatRow('Articles en stock', activityStats['totalStockItems'] ?? 0, null, isCount: true),
          _buildStatRow('Stock faible', activityStats['lowStockItems'] ?? 0, Colors.orange, isCount: true),
          _buildStatRow('Rupture de stock', activityStats['outOfStockItems'] ?? 0, Colors.red, isCount: true),
          const SizedBox(height: 8),
        ],
      ),
    );
  }

  Widget _buildUsersSection() {
    return Card(
      child: ExpansionTile(
        title: const Text('Utilisateurs', style: TextStyle(fontWeight: FontWeight.bold)),
        children: [
          _buildStatRow('Total utilisateurs', activityStats['totalUsers'] ?? 0, null, isCount: true),
          const SizedBox(height: 8),
        ],
      ),
    );
  }
}

