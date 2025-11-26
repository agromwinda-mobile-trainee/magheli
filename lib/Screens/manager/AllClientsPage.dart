import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

class AllClientsPage extends StatefulWidget {
  const AllClientsPage({super.key});

  @override
  State<AllClientsPage> createState() => _AllClientsPageState();
}

class _AllClientsPageState extends State<AllClientsPage> {
  String? selectedActivityId;
  String? selectedActivityName;
  List<Map<String, dynamic>> activities = [];
  bool loadingActivities = true;

  @override
  void initState() {
    super.initState();
    _loadActivities();
  }

  Future<void> _loadActivities() async {
    try {
      final query = await FirebaseFirestore.instance
          .collection('activities')
          .orderBy('activityName')
          .get();

      setState(() {
        activities = query.docs.map((doc) {
          final data = doc.data();
          return {
            'id': doc.id,
            'name': (data['activityName'] ?? 'Activité inconnue') as String,
          };
        }).toList();
        loadingActivities = false;
      });
    } catch (e) {
      setState(() {
        loadingActivities = false;
      });
    }
  }

  void _showAddClientBottomSheet(BuildContext context) {
    final nameController = TextEditingController();
    final phoneController = TextEditingController();
    bool loading = false;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) => Container(
          padding: EdgeInsets.only(
            bottom: MediaQuery.of(context).viewInsets.bottom,
            left: 20,
            right: 20,
            top: 20,
          ),
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Handle bar
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  margin: const EdgeInsets.only(bottom: 20),
                  decoration: BoxDecoration(
                    color: Colors.grey[300],
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const Text(
                'Ajouter un client',
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 24),
              TextField(
                controller: nameController,
                decoration: InputDecoration(
                  labelText: 'Nom complet',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  prefixIcon: const Icon(Icons.person),
                ),
                enabled: !loading,
              ),
              const SizedBox(height: 16),
              TextField(
                controller: phoneController,
                decoration: InputDecoration(
                  labelText: 'Numéro de téléphone',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  prefixIcon: const Icon(Icons.phone),
                ),
                keyboardType: TextInputType.phone,
                enabled: !loading,
              ),
              const SizedBox(height: 24),
              ElevatedButton(
                onPressed: loading
                    ? null
                    : () async {
                        if (nameController.text.trim().isEmpty) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text('Veuillez saisir le nom du client'),
                            ),
                          );
                          return;
                        }

                        setState(() => loading = true);

                        try {
                          await FirebaseFirestore.instance
                              .collection('clients')
                              .add({
                            'fullName': nameController.text.trim(),
                            'phone': phoneController.text.trim(),
                            'createdAt': FieldValue.serverTimestamp(),
                          });

                          if (context.mounted) {
                            Navigator.pop(context);
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text('Client ajouté avec succès'),
                                backgroundColor: Colors.green,
                              ),
                            );
                          }
                        } catch (e) {
                          if (context.mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text('Erreur: $e'),
                                backgroundColor: Colors.red,
                              ),
                            );
                          }
                          setState(() => loading = false);
                        }
                      },
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.black,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: loading
                    ? const SizedBox(
                        height: 20,
                        width: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                        ),
                      )
                    : const Text(
                        'Enregistrer',
                        style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                      ),
              ),
              const SizedBox(height: 20),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Clients", style: TextStyle(color: Colors.white)),
        backgroundColor: Colors.black,
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _showAddClientBottomSheet(context),
        backgroundColor: Colors.black,
        child: const Icon(Icons.add, color: Colors.white),
      ),
      body: Column(
        children: [
          // Filtre par activité
          Container(
            padding: const EdgeInsets.all(16),
            color: Colors.grey[100],
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Filtrer par activité:',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                  ),
                ),
                const SizedBox(height: 8),
                DropdownButtonFormField<String>(
                  value: selectedActivityId,
                  decoration: InputDecoration(
                    filled: true,
                    fillColor: Colors.white,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    prefixIcon: const Icon(Icons.business),
                  ),
                  items: [
                    const DropdownMenuItem<String>(
                      value: null,
                      child: Text('Toutes les activités'),
                    ),
                    ...activities.map((activity) {
                      return DropdownMenuItem<String>(
                        value: activity['id'] as String,
                        child: Text(activity['name'] as String),
                      );
                    }),
                  ],
                  onChanged: (value) {
                    setState(() {
                      selectedActivityId = value;
                      if (value != null) {
                        final activity = activities.firstWhere(
                          (a) => a['id'] == value,
                        );
                        selectedActivityName = activity['name'] as String;
                      } else {
                        selectedActivityName = null;
                      }
                    });
                  },
                ),
              ],
            ),
          ),
          // Statistiques globales
          Container(
            padding: const EdgeInsets.all(16),
            color: Colors.grey[50],
            child: StreamBuilder<QuerySnapshot>(
              stream: selectedActivityId == null
                  ? FirebaseFirestore.instance
                      .collection('invoices')
                      .snapshots()
                  : FirebaseFirestore.instance
                      .collection('invoices')
                      .where('activityId', isEqualTo: selectedActivityId)
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
              stream: selectedActivityId == null
                  ? FirebaseFirestore.instance
                      .collection('invoices')
                      .snapshots()
                  : FirebaseFirestore.instance
                      .collection('invoices')
                      .where('activityId', isEqualTo: selectedActivityId)
                      .snapshots(),
              builder: (context, snapshot) {
                if (!snapshot.hasData) {
                  return const Center(child: CircularProgressIndicator());
                }

                // Grouper les factures par client et activité
                final Map<String, Map<String, ClientDebtInfo>> clientsMap = {};

                for (var doc in snapshot.data!.docs) {
                  final data = doc.data() as Map<String, dynamic>;
                  final clientId = data['clientId'] as String?;
                  if (clientId == null) continue;

                  final activityId = data['activityId'] as String? ?? 'unknown';
                  final balance = (data['balance'] ?? 0).toDouble();
                  final amountPaid = (data['amountPaid'] ?? 0).toDouble();
                  final createdAt = data['createdAt'] as Timestamp?;
                  final clientName = data['clientName'] as String? ?? 'Client inconnu';

                  if (!clientsMap.containsKey(clientId)) {
                    clientsMap[clientId] = {};
                  }

                  if (!clientsMap[clientId]!.containsKey(activityId)) {
                    clientsMap[clientId]![activityId] = ClientDebtInfo(
                      clientId: clientId,
                      clientName: clientName,
                      activityId: activityId,
                      totalDebt: 0,
                      totalPaid: 0,
                      lastInvoiceDate: createdAt?.toDate(),
                    );
                  }

                  final clientInfo = clientsMap[clientId]![activityId]!;
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

                // Créer une liste plate de tous les clients avec leurs dettes par activité
                final List<ClientDebtInfo> allClientsWithDebt = [];
                for (var clientActivities in clientsMap.values) {
                  for (var clientInfo in clientActivities.values) {
                    if (clientInfo.totalDebt > 0) {
                      allClientsWithDebt.add(clientInfo);
                    }
                  }
                }

                // Trier par dette décroissante
                allClientsWithDebt.sort((a, b) => b.totalDebt.compareTo(a.totalDebt));

                if (allClientsWithDebt.isEmpty) {
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
                          selectedActivityId == null
                              ? 'Aucun client avec dette'
                              : 'Aucun client avec dette pour cette activité',
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
                    itemCount: allClientsWithDebt.length,
                    itemBuilder: (context, index) {
                      final client = allClientsWithDebt[index];
                      return FutureBuilder<DocumentSnapshot?>(
                        future: FirebaseFirestore.instance
                            .collection('activities')
                            .doc(client.activityId)
                            .get()
                            .then((doc) => doc.exists ? doc : null),
                        builder: (context, activitySnapshot) {
                          String activityName = 'Activité inconnue';
                          if (activitySnapshot.hasData && activitySnapshot.data != null) {
                            final activityData = activitySnapshot.data!.data() as Map<String, dynamic>?;
                            activityName = activityData?['activityName'] ?? 'Activité inconnue';
                          }

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
                              ),
                              subtitle: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const SizedBox(height: 4),
                                  Text(
                                    'Activité: $activityName',
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: Colors.grey[600],
                                      fontStyle: FontStyle.italic,
                                    ),
                                  ),
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
                                      Text(
                                        '${client.totalDebt.toStringAsFixed(2)} FC',
                                        style: const TextStyle(
                                          fontSize: 14,
                                          fontWeight: FontWeight.bold,
                                          color: Colors.red,
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
                                        label: 'Activité',
                                        value: activityName,
                                        color: Colors.blue,
                                      ),
                                      const SizedBox(height: 8),
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
  final String activityId;
  double totalDebt;
  double totalPaid;
  DateTime? lastInvoiceDate;

  ClientDebtInfo({
    required this.clientId,
    required this.clientName,
    required this.activityId,
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

