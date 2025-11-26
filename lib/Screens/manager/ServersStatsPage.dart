import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../common/error_messages.dart';

class ServersStatsPage extends StatefulWidget {
  const ServersStatsPage({super.key});

  @override
  State<ServersStatsPage> createState() => _ServersStatsPageState();
}

class _ServersStatsPageState extends State<ServersStatsPage> {
  String? selectedActivityFilter;
  String? selectedServerFilter;
  List<Map<String, dynamic>> activities = [];
  List<Map<String, dynamic>> servers = [];
  Map<String, ServerStats> serverStats = {};
  bool loading = true;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() => loading = true);

    try {
      // Charger les activités
      final activitiesQuery = await FirebaseFirestore.instance
          .collection('activities')
          .get();

      setState(() {
        activities = activitiesQuery.docs.map((doc) {
          final data = doc.data();
          return {
            'id': doc.id,
            'name': (data['activityName'] ?? 'Activité inconnue') as String,
          };
        }).toList();
      });

      // Charger les serveurs
      await _loadServers();

      // Charger les statistiques
      await _loadStats();
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
      setState(() => loading = false);
    }
  }

  Future<void> _loadServers() async {
    Query query = FirebaseFirestore.instance.collection('servers');

    if (selectedActivityFilter != null) {
      query = query.where('activity', isEqualTo: selectedActivityFilter);
    }

    final serversQuery = await query.get();

    setState(() {
      servers = serversQuery.docs.map((doc) {
        final data = doc.data() as Map<String, dynamic>;
        return {
          'id': doc.id,
          'name': data['fullName'] ?? 'Nom inconnu',
          'activity': data['activity'] ?? 'Activité inconnue',
        };
      }).toList();
    });
  }

  Future<void> _loadStats() async {
    final now = DateTime.now();
    final startOfDay = DateTime(now.year, now.month, now.day);
    final startOfWeek = startOfDay.subtract(Duration(days: now.weekday - 1));
    final startOfMonth = DateTime(now.year, now.month, 1);

    final statsMap = <String, ServerStats>{};

    // Charger tous les tickets
    Query ticketsQuery = FirebaseFirestore.instance.collection('tickets');

    if (selectedActivityFilter != null) {
      ticketsQuery = ticketsQuery.where('activity', isEqualTo: selectedActivityFilter);
    }

    final tickets = await ticketsQuery.get();

    for (var ticketDoc in tickets.docs) {
      final ticketData = ticketDoc.data() as Map<String, dynamic>;
      final serverId = ticketData['serverId'] as String?;
      final serverName = ticketData['serverName'] as String?;
      final total = (ticketData['total'] ?? 0).toDouble();
      final createdAt = (ticketData['createdAt'] as Timestamp?)?.toDate();

      if (serverId == null || serverId.isEmpty) continue;

      // Filtrer par serveur si sélectionné
      if (selectedServerFilter != null && serverId != selectedServerFilter) {
        continue;
      }

      if (!statsMap.containsKey(serverId)) {
        statsMap[serverId] = ServerStats(
          serverId: serverId,
          serverName: serverName ?? 'Serveur inconnu',
        );
      }

      final stats = statsMap[serverId]!;
      stats.totalTickets++;
      stats.totalRevenue += total;

      if (createdAt != null) {
        // Statistiques du jour
        if (createdAt.isAfter(startOfDay)) {
          stats.todayTickets++;
          stats.todayRevenue += total;
        }

        // Statistiques de la semaine
        if (createdAt.isAfter(startOfWeek)) {
          stats.weekTickets++;
          stats.weekRevenue += total;
        }

        // Statistiques du mois
        if (createdAt.isAfter(startOfMonth)) {
          stats.monthTickets++;
          stats.monthRevenue += total;
        }
      }
    }

    // Charger les factures pour les statistiques de paiement
    Query invoicesQuery = FirebaseFirestore.instance.collection('invoices');

    if (selectedActivityFilter != null) {
      invoicesQuery = invoicesQuery.where('activity', isEqualTo: selectedActivityFilter);
    }

    final invoices = await invoicesQuery.get();

    for (var invoiceDoc in invoices.docs) {
      final invoiceData = invoiceDoc.data() as Map<String, dynamic>;
      final ticketId = invoiceData['ticketId'] as String?;
      final paymentStatus = invoiceData['paymentStatus'] as String?;
      final totalAmount = (invoiceData['totalAmount'] ?? 0).toDouble();
      final amountPaid = (invoiceData['amountPaid'] ?? 0).toDouble();

      if (ticketId == null || ticketId.isEmpty) continue;

      // Trouver le ticket correspondant
      final ticketDoc = await FirebaseFirestore.instance
          .collection('tickets')
          .doc(ticketId)
          .get();

      if (!ticketDoc.exists) continue;

      final ticketData = ticketDoc.data()!;
      final serverId = ticketData['serverId'] as String?;

      if (serverId == null || serverId.isEmpty) continue;

      // Filtrer par serveur si sélectionné
      if (selectedServerFilter != null && serverId != selectedServerFilter) {
        continue;
      }

      if (!statsMap.containsKey(serverId)) {
        final serverName = ticketData['serverName'] as String?;
        statsMap[serverId] = ServerStats(
          serverId: serverId,
          serverName: serverName ?? 'Serveur inconnu',
        );
      }

      final stats = statsMap[serverId]!;
      stats.totalInvoices++;
      stats.totalInvoiceRevenue += totalAmount;

      if (paymentStatus == 'paid') {
        stats.paidInvoices++;
        stats.paidRevenue += amountPaid;
      } else if (paymentStatus == 'partial') {
        stats.partialInvoices++;
        stats.partialRevenue += amountPaid;
      } else {
        stats.unpaidInvoices++;
        stats.unpaidRevenue += (totalAmount - amountPaid);
      }
    }

    setState(() {
      serverStats = statsMap;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.black,
        title: const Text(
          'Statistiques des Serveurs',
          style: TextStyle(color: Colors.white),
        ),
      ),
      body: loading
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                // Filtres
                Container(
                  padding: const EdgeInsets.all(16),
                  color: Colors.grey[100],
                  child: Column(
                    children: [
                      Row(
                        children: [
                          const Text(
                            'Activité: ',
                            style: TextStyle(fontWeight: FontWeight.bold),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: DropdownButtonFormField<String>(
                              value: selectedActivityFilter,
                              decoration: InputDecoration(
                                filled: true,
                                fillColor: Colors.white,
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(8),
                                ),
                              ),
                              hint: const Text('Toutes les activités'),
                              items: [
                                const DropdownMenuItem<String>(
                                  value: null,
                                  child: Text('Toutes les activités'),
                                ),
                                ...activities.map((activity) {
                                  return DropdownMenuItem<String>(
                                    value: activity['name'] as String,
                                    child: Text(activity['name'] as String),
                                  );
                                }),
                              ],
                              onChanged: (value) {
                                setState(() {
                                  selectedActivityFilter = value;
                                  selectedServerFilter = null;
                                });
                                _loadData();
                              },
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          const Text(
                            'Serveur: ',
                            style: TextStyle(fontWeight: FontWeight.bold),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: DropdownButtonFormField<String>(
                              value: selectedServerFilter,
                              decoration: InputDecoration(
                                filled: true,
                                fillColor: Colors.white,
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(8),
                                ),
                              ),
                              hint: const Text('Tous les serveurs'),
                              items: [
                                const DropdownMenuItem<String>(
                                  value: null,
                                  child: Text('Tous les serveurs'),
                                ),
                                ...servers.map((server) {
                                  return DropdownMenuItem<String>(
                                    value: server['id'] as String,
                                    child: Text(server['name'] as String),
                                  );
                                }),
                              ],
                              onChanged: (value) {
                                setState(() {
                                  selectedServerFilter = value;
                                });
                                _loadStats();
                              },
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                // Statistiques
                Expanded(
                  child: serverStats.isEmpty
                      ? Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(
                                Icons.bar_chart_outlined,
                                size: 64,
                                color: Colors.grey[400],
                              ),
                              const SizedBox(height: 16),
                              Text(
                                'Aucune statistique disponible',
                                style: TextStyle(
                                  fontSize: 18,
                                  color: Colors.grey[600],
                                ),
                              ),
                            ],
                          ),
                        )
                      : ListView.builder(
                          padding: const EdgeInsets.all(16),
                          itemCount: serverStats.length,
                          itemBuilder: (context, index) {
                            final stats = serverStats.values.elementAt(index);
                            return Card(
                              margin: const EdgeInsets.only(bottom: 16),
                              child: Padding(
                                padding: const EdgeInsets.all(16),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      children: [
                                        CircleAvatar(
                                          backgroundColor: Colors.blue[100],
                                          child: Icon(
                                            Icons.person,
                                            color: Colors.blue[700],
                                          ),
                                        ),
                                        const SizedBox(width: 12),
                                        Expanded(
                                          child: Text(
                                            stats.serverName,
                                            style: const TextStyle(
                                              fontSize: 18,
                                              fontWeight: FontWeight.bold,
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                    const Divider(),
                                    _buildStatRow('Tickets totaux', '${stats.totalTickets}'),
                                    _buildStatRow('Revenus totaux', '${stats.totalRevenue.toStringAsFixed(2)} FC'),
                                    const SizedBox(height: 8),
                                    const Text(
                                      'Aujourd\'hui',
                                      style: TextStyle(
                                        fontWeight: FontWeight.bold,
                                        fontSize: 16,
                                      ),
                                    ),
                                    _buildStatRow('Tickets', '${stats.todayTickets}'),
                                    _buildStatRow('Revenus', '${stats.todayRevenue.toStringAsFixed(2)} FC'),
                                    const SizedBox(height: 8),
                                    const Text(
                                      'Cette semaine',
                                      style: TextStyle(
                                        fontWeight: FontWeight.bold,
                                        fontSize: 16,
                                      ),
                                    ),
                                    _buildStatRow('Tickets', '${stats.weekTickets}'),
                                    _buildStatRow('Revenus', '${stats.weekRevenue.toStringAsFixed(2)} FC'),
                                    const SizedBox(height: 8),
                                    const Text(
                                      'Ce mois',
                                      style: TextStyle(
                                        fontWeight: FontWeight.bold,
                                        fontSize: 16,
                                      ),
                                    ),
                                    _buildStatRow('Tickets', '${stats.monthTickets}'),
                                    _buildStatRow('Revenus', '${stats.monthRevenue.toStringAsFixed(2)} FC'),
                                    const Divider(),
                                    const Text(
                                      'Factures',
                                      style: TextStyle(
                                        fontWeight: FontWeight.bold,
                                        fontSize: 16,
                                      ),
                                    ),
                                    _buildStatRow('Total factures', '${stats.totalInvoices}'),
                                    _buildStatRow('Payées', '${stats.paidInvoices}', Colors.green),
                                    _buildStatRow('Partiellement payées', '${stats.partialInvoices}', Colors.orange),
                                    _buildStatRow('Impayées', '${stats.unpaidInvoices}', Colors.red),
                                    _buildStatRow('Revenus payés', '${stats.paidRevenue.toStringAsFixed(2)} FC', Colors.green),
                                    _buildStatRow('Revenus partiels', '${stats.partialRevenue.toStringAsFixed(2)} FC', Colors.orange),
                                    _buildStatRow('Revenus impayés', '${stats.unpaidRevenue.toStringAsFixed(2)} FC', Colors.red),
                                  ],
                                ),
                              ),
                            );
                          },
                        ),
                ),
              ],
            ),
    );
  }

  Widget _buildStatRow(String label, String value, [Color? color]) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label),
          Text(
            value,
            style: TextStyle(
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
        ],
      ),
    );
  }
}

class ServerStats {
  final String serverId;
  final String serverName;
  int totalTickets = 0;
  double totalRevenue = 0;
  int todayTickets = 0;
  double todayRevenue = 0;
  int weekTickets = 0;
  double weekRevenue = 0;
  int monthTickets = 0;
  double monthRevenue = 0;
  int totalInvoices = 0;
  double totalInvoiceRevenue = 0;
  int paidInvoices = 0;
  double paidRevenue = 0;
  int partialInvoices = 0;
  double partialRevenue = 0;
  int unpaidInvoices = 0;
  double unpaidRevenue = 0;

  ServerStats({
    required this.serverId,
    required this.serverName,
  });
}

