import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';

class ClientsPage extends StatefulWidget {
  const ClientsPage({super.key});

  @override
  State<ClientsPage> createState() => _ClientsPageState();
}

class _ClientsPageState extends State<ClientsPage> {
  String? activityId;
  String? activityName;
  bool loading = true;

  @override
  void initState() {
    super.initState();
    _loadActivityInfo();
  }

  Future<void> _loadActivityInfo() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      activityId = prefs.getString("activityId");
      activityName = prefs.getString("activityName");
      loading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    if (loading) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    if (activityId == null || activityName == null) {
      return Scaffold(
        appBar: AppBar(
          title: const Text("Clients", style: TextStyle(color: Colors.white)),
          backgroundColor: Colors.black,
        ),
        body: const Center(
          child: Text('Impossible de charger l\'activité'),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: Text(
          "Clients • $activityName",
          style: const TextStyle(color: Colors.white),
        ),
        backgroundColor: Colors.black,
      ),
      body: Column(
        children: [
          // Statistiques globales
          Container(
            padding: const EdgeInsets.all(16),
            color: Colors.grey[100],
            child: StreamBuilder<QuerySnapshot>(
              stream: FirebaseFirestore.instance
                  .collection('invoices')
                  .where('activityId', isEqualTo: activityId)
                  .snapshots(),
              builder: (context, snapshot) {
                if (!snapshot.hasData) {
                  return const SizedBox.shrink();
                }

                double totalDebt = 0;
                double totalPaid = 0;
                int clientsWithDebt = 0;
                final Map<String, double> clientDebts = {};

                for (var doc in snapshot.data!.docs) {
                  final data = doc.data() as Map<String, dynamic>;
                  final clientId = data['clientId'] as String?;
                  if (clientId == null) continue;

                  final balance = (data['balance'] ?? 0).toDouble();
                  final amountPaid = (data['amountPaid'] ?? 0).toDouble();

                  clientDebts[clientId] = (clientDebts[clientId] ?? 0) + balance;
                  totalPaid += amountPaid;
                }

                for (var debt in clientDebts.values) {
                  if (debt > 0) {
                    totalDebt += debt;
                    clientsWithDebt++;
                  }
                }

                return Row(
                  mainAxisAlignment: MainAxisAlignment.spaceAround,
                  children: [
                    _StatCard(
                      label: 'Clients avec dette',
                      value: clientsWithDebt.toString(),
                      color: Colors.orange,
                    ),
                    _StatCard(
                      label: 'Dette totale',
                      value: '${totalDebt.toStringAsFixed(0)} FC',
                      color: Colors.red,
                    ),
                    _StatCard(
                      label: 'Total payé',
                      value: '${totalPaid.toStringAsFixed(0)} FC',
                      color: Colors.green,
                    ),
                  ],
                );
              },
            ),
          ),
            // Liste des clients avec dettes
          Expanded(
            child: StreamBuilder<QuerySnapshot>(
              stream: FirebaseFirestore.instance
                  .collection('invoices')
                  .where('activityId', isEqualTo: activityId)
                  .snapshots(),
              builder: (context, snapshot) {
                if (!snapshot.hasData) {
                  return const Center(child: CircularProgressIndicator());
                }

                // Grouper les factures par client
                final Map<String, ClientDebtInfo> clientsMap = {};

                for (var doc in snapshot.data!.docs) {
                  final data = doc.data() as Map<String, dynamic>;
                  final clientId = data['clientId'] as String?;
                  if (clientId == null) continue;

                  final balance = (data['balance'] ?? 0).toDouble();
                  final amountPaid = (data['amountPaid'] ?? 0).toDouble();
                  final createdAt = data['createdAt'] as Timestamp?;
                  final clientName = data['clientName'] as String? ?? 'Client inconnu';

                  if (!clientsMap.containsKey(clientId)) {
                    clientsMap[clientId] = ClientDebtInfo(
                      clientId: clientId,
                      clientName: clientName,
                      totalDebt: 0,
                      totalPaid: 0,
                      lastInvoiceDate: createdAt?.toDate(),
                    );
                  }

                  final clientInfo = clientsMap[clientId]!;
                  clientInfo.totalDebt += balance;
                  clientInfo.totalPaid += amountPaid;

                  // Mettre à jour la date de la dernière facture
                  if (createdAt != null) {
                    final invoiceDate = createdAt.toDate();
                    if (clientInfo.lastInvoiceDate == null ||
                        invoiceDate.isAfter(clientInfo.lastInvoiceDate!)) {
                      clientInfo.lastInvoiceDate = invoiceDate;
                    }
                  }
                }

                // Filtrer uniquement les clients avec une dette > 0
                final clientsWithDebt = clientsMap.values
                    .where((client) => client.totalDebt > 0)
                    .toList();

                // Trier par dette décroissante
                clientsWithDebt.sort((a, b) => b.totalDebt.compareTo(a.totalDebt));

                if (clientsWithDebt.isEmpty) {
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.people_outline,
                          size: 64,
                          color: Colors.grey[400],
                        ),
                        const SizedBox(height: 16),
                        Text(
                          'Aucun client avec dette',
                          style: TextStyle(
                            fontSize: 18,
                            color: Colors.grey[600],
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Tous les clients sont à jour',
                          style: TextStyle(
                            fontSize: 14,
                            color: Colors.grey[500],
                          ),
                        ),
                      ],
                    ),
                  );
                }

                return RefreshIndicator(
                  onRefresh: () async {
                    // Le StreamBuilder se met à jour automatiquement
                  },
                  child: ListView.builder(
                    padding: const EdgeInsets.all(16),
                    itemCount: clientsWithDebt.length,
                    itemBuilder: (context, index) {
                      final client = clientsWithDebt[index];
                      return Card(
                        margin: const EdgeInsets.only(bottom: 12),
                        elevation: 2,
                        child: ExpansionTile(
                          leading: CircleAvatar(
                            backgroundColor: Colors.red.withOpacity(0.2),
                            child: const Icon(
                              Icons.person,
                              color: Colors.red,
                            ),
                          ),
                          title: Text(
                            client.clientName,
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 16,
                            ),
                            overflow: TextOverflow.ellipsis,
                            maxLines: 1,
                          ),
                          subtitle: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const SizedBox(height: 4),
                              Row(
                                children: [
                                  const Text(
                                    'Dette: ',
                                    style: TextStyle(
                                      fontSize: 14,
                                      color: Colors.grey,
                                    ),
                                  ),
                                  Flexible(
                                    child: Text(
                                      '${client.totalDebt.toStringAsFixed(2)} FC',
                                      style: const TextStyle(
                                        fontSize: 14,
                                        fontWeight: FontWeight.bold,
                                        color: Colors.red,
                                      ),
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                ],
                              ),
                              if (client.lastInvoiceDate != null)
                                Text(
                                  'Dernière facture: ${_formatDate(client.lastInvoiceDate!)}',
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: Colors.grey[600],
                                  ),
                                  overflow: TextOverflow.ellipsis,
                                  maxLines: 1,
                                ),
                            ],
                          ),
                          trailing: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 6,
                            ),
                            decoration: BoxDecoration(
                              color: Colors.red.withOpacity(0.1),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                color: Colors.red,
                                width: 1,
                              ),
                            ),
                            child: Text(
                              '${client.totalDebt.toStringAsFixed(0)} FC',
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                                color: Colors.red,
                              ),
                            ),
                          ),
                          children: [
                            Padding(
                              padding: const EdgeInsets.all(16),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  _InfoRow(
                                    label: 'Dette totale',
                                    value: '${client.totalDebt.toStringAsFixed(2)} FC',
                                    color: Colors.red,
                                  ),
                                  const SizedBox(height: 8),
                                  _InfoRow(
                                    label: 'Montant payé',
                                    value: '${client.totalPaid.toStringAsFixed(2)} FC',
                                    color: Colors.green,
                                  ),
                                  const SizedBox(height: 8),
                                  if (client.lastInvoiceDate != null)
                                    _InfoRow(
                                      label: 'Dernière facture',
                                      value: _formatDate(client.lastInvoiceDate!),
                                      color: Colors.grey,
                                    ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      );
                    },
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  String _formatDate(DateTime date) {
    return DateFormat('dd/MM/yyyy HH:mm').format(date);
  }
}

class ClientDebtInfo {
  final String clientId;
  final String clientName;
  double totalDebt;
  double totalPaid;
  DateTime? lastInvoiceDate;

  ClientDebtInfo({
    required this.clientId,
    required this.clientName,
    required this.totalDebt,
    required this.totalPaid,
    this.lastInvoiceDate,
  });
}

class _StatCard extends StatelessWidget {
  final String label;
  final String value;
  final Color color;

  const _StatCard({
    required this.label,
    required this.value,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: color.withOpacity(0.1),
            shape: BoxShape.circle,
          ),
          child: Text(
            value,
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: color,
            ),
            textAlign: TextAlign.center,
          ),
        ),
        const SizedBox(height: 4),
        SizedBox(
          width: 80,
          child: Text(
            label,
            style: TextStyle(
              fontSize: 10,
              color: Colors.grey[600],
            ),
            textAlign: TextAlign.center,
            maxLines: 2,
          ),
        ),
      ],
    );
  }
}

class _InfoRow extends StatelessWidget {
  final String label;
  final String value;
  final Color color;

  const _InfoRow({
    required this.label,
    required this.value,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: 14,
            color: Colors.grey[600],
          ),
        ),
        Text(
          value,
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.bold,
            color: color,
          ),
        ),
      ],
    );
  }
}

