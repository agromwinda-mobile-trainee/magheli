import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';

class InvoicesPage extends StatefulWidget {
  final String cashierId;
  const InvoicesPage({super.key, required this.cashierId});

  @override
  State<InvoicesPage> createState() => _InvoicesPageState();
}

class _InvoicesPageState extends State<InvoicesPage> {
  String? selectedStatusFilter;
  String? activityId;
  bool loading = true;

  final List<Map<String, String?>> statusFilters = [
    {'value': null, 'label': 'Toutes les factures'},
    {'value': 'paid', 'label': 'Payées'},
    {'value': 'partial', 'label': 'Partiellement payées'},
    {'value': 'unpaid', 'label': 'Impayées'},
  ];

  @override
  void initState() {
    super.initState();
    _loadActivityId();
  }

  Future<void> _loadActivityId() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      activityId = prefs.getString("activityId");
      loading = false;
    });
  }

  String _getStatusLabel(String status) {
    switch (status) {
      case 'paid':
        return 'Payée';
      case 'partial':
        return 'Partiellement payée';
      case 'unpaid':
        return 'Impayée';
      default:
        return status;
    }
  }

  Color _getStatusColor(String status) {
    switch (status) {
      case 'paid':
        return Colors.green;
      case 'partial':
        return Colors.orange;
      case 'unpaid':
        return Colors.red;
      default:
        return Colors.grey;
    }
  }

  @override
  Widget build(BuildContext context) {
    if (loading) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    if (activityId == null) {
      return Scaffold(
        appBar: AppBar(
          title: const Text("Factures", style: TextStyle(color: Colors.white)),
          backgroundColor: Colors.black,
        ),
        body: const Center(
          child: Text('Impossible de charger l\'activité'),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text("Factures", style: TextStyle(color: Colors.white)),
        backgroundColor: Colors.black,
      ),
      body: Column(
        children: [
          // Filtre par statut
          Container(
            padding: const EdgeInsets.all(16),
            color: Colors.grey[100],
            child: Row(
              children: [
                const Text(
                  'Filtrer par statut: ',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: DropdownButtonFormField<String?>(
                    value: selectedStatusFilter,
                    decoration: InputDecoration(
                      filled: true,
                      fillColor: Colors.white,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                    items: statusFilters.map((filter) {
                      return DropdownMenuItem<String?>(
                        value: filter['value'],
                        child: Text(filter['label']!),
                      );
                    }).toList(),
                    onChanged: (value) {
                      setState(() {
                        selectedStatusFilter = value;
                      });
                    },
                  ),
                ),
              ],
            ),
          ),
          // Liste des factures
          Expanded(
            child: StreamBuilder<QuerySnapshot>(
              stream: selectedStatusFilter == null
                  ? FirebaseFirestore.instance
                      .collection('invoices')
                      .where('activityId', isEqualTo: activityId)
                      .orderBy('createdAt', descending: true)
                      .snapshots()
                  : FirebaseFirestore.instance
                      .collection('invoices')
                      .where('activityId', isEqualTo: activityId)
                      .where('paymentStatus', isEqualTo: selectedStatusFilter)
                      .orderBy('createdAt', descending: true)
                      .snapshots(),
              builder: (context, snapshot) {
                if (!snapshot.hasData) {
                  return const Center(child: CircularProgressIndicator());
                }

                if (snapshot.data!.docs.isEmpty) {
                  return const Center(
                    child: Text('Aucune facture trouvée'),
                  );
                }

                return ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: snapshot.data!.docs.length,
                  itemBuilder: (context, index) {
                    final doc = snapshot.data!.docs[index];
                    final data = doc.data() as Map<String, dynamic>;
                    final totalAmount = (data['totalAmount'] ?? 0).toDouble();
                    final amountPaid = (data['amountPaid'] ?? 0).toDouble();
                    final balance = (data['balance'] ?? 0).toDouble();
                    final paymentStatus = data['paymentStatus'] ?? 'unpaid';
                    final createdAt = (data['createdAt'] as Timestamp?)?.toDate();
                    final serverId = data['serverId'] ?? '';

                    return FutureBuilder<DocumentSnapshot?>(
                      future: serverId.isNotEmpty
                          ? FirebaseFirestore.instance
                              .collection('servers')
                              .doc(serverId)
                              .get()
                              .then((doc) => doc.exists ? doc : null)
                          : Future.value(null),
                      builder: (context, serverSnapshot) {
                        String serverName = 'Serveur inconnu';
                        if (serverSnapshot.hasData && serverSnapshot.data != null) {
                          final serverData = serverSnapshot.data!.data() as Map<String, dynamic>?;
                          serverName = serverData?['fullName'] ?? 'Serveur inconnu';
                        }

                        return Card(
                          margin: const EdgeInsets.only(bottom: 12),
                          child: ListTile(
                            leading: CircleAvatar(
                              backgroundColor: _getStatusColor(paymentStatus),
                              child: Icon(
                                paymentStatus == 'paid'
                                    ? Icons.check_circle
                                    : paymentStatus == 'partial'
                                        ? Icons.pending
                                        : Icons.cancel,
                                color: Colors.white,
                              ),
                            ),
                            title: Text(
                              'Facture #${doc.id.substring(0, 8)}',
                              style: const TextStyle(fontWeight: FontWeight.bold),
                            ),
                            subtitle: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text('Serveur: $serverName'),
                                Text('Total: ${totalAmount.toStringAsFixed(2)} FC'),
                                Text('Payé: ${amountPaid.toStringAsFixed(2)} FC'),
                                if (balance > 0)
                                  Text(
                                    'Reste: ${balance.toStringAsFixed(2)} FC',
                                    style: const TextStyle(
                                      color: Colors.red,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                if (createdAt != null)
                                  Text(
                                    'Date: ${DateFormat('dd/MM/yyyy HH:mm').format(createdAt)}',
                                    style: const TextStyle(fontSize: 12, color: Colors.grey),
                                  ),
                              ],
                            ),
                            trailing: Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 12,
                                vertical: 6,
                              ),
                              decoration: BoxDecoration(
                                color: _getStatusColor(paymentStatus).withOpacity(0.2),
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(
                                  color: _getStatusColor(paymentStatus),
                                  width: 1,
                                ),
                              ),
                              child: Text(
                                _getStatusLabel(paymentStatus),
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  color: _getStatusColor(paymentStatus),
                                ),
                              ),
                            ),
                          ),
                        );
                      },
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

