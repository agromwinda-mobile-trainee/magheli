import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class ActivityStockPage extends StatefulWidget {
  const ActivityStockPage({super.key});

  @override
  State<ActivityStockPage> createState() => _ActivityStockPageState();
}

class _ActivityStockPageState extends State<ActivityStockPage> {
  String? activityName;
  String? activityId;
  bool loading = true;

  @override
  void initState() {
    super.initState();
    _loadActivityInfo();
  }

  Future<void> _loadActivityInfo() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      activityName = prefs.getString("activityName");
      activityId = prefs.getString("activityId");
      loading = false;
    });
  }

  Color _getStockColor(int quantity) {
    if (quantity == 0) return Colors.red;
    if (quantity <= 10) return Colors.orange;
    return Colors.green;
  }

  String _getStockStatus(int quantity) {
    if (quantity == 0) return 'Rupture de stock';
    if (quantity <= 10) return 'Stock faible';
    return 'En stock';
  }

  @override
  Widget build(BuildContext context) {
    if (loading) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    if (activityName == null) {
      return Scaffold(
        appBar: AppBar(
          title: const Text("Stock Activité", style: TextStyle(color: Colors.white)),
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
          "Stock • $activityName",
          style: const TextStyle(color: Colors.white),
        ),
        backgroundColor: Colors.black,
      ),
      body: Column(
        children: [
          // Statistiques rapides
          Container(
            padding: const EdgeInsets.all(16),
            color: Colors.grey[100],
            child: StreamBuilder<QuerySnapshot>(
              stream: FirebaseFirestore.instance
                  .collection('stock')
                  .where('activity', isEqualTo: activityName)
                  .snapshots(),
              builder: (context, snapshot) {
                if (!snapshot.hasData) {
                  return const SizedBox.shrink();
                }

                final items = snapshot.data!.docs;
                int totalItems = items.length;
                int inStock = 0;
                int lowStock = 0;
                int outOfStock = 0;

                for (var doc in items) {
                  final data = doc.data() as Map<String, dynamic>?;
                  final qty = (data?['quantity'] ?? 0) as int;
                  if (qty == 0) {
                    outOfStock++;
                  } else if (qty <= 10) {
                    lowStock++;
                  } else {
                    inStock++;
                  }
                }

                return Row(
                  mainAxisAlignment: MainAxisAlignment.spaceAround,
                  children: [
                    _StatCard(
                      label: 'Total',
                      value: totalItems.toString(),
                      color: Colors.blue,
                    ),
                    _StatCard(
                      label: 'En stock',
                      value: inStock.toString(),
                      color: Colors.green,
                    ),
                    _StatCard(
                      label: 'Stock faible',
                      value: lowStock.toString(),
                      color: Colors.orange,
                    ),
                    _StatCard(
                      label: 'Rupture',
                      value: outOfStock.toString(),
                      color: Colors.red,
                    ),
                  ],
                );
              },
            ),
          ),
          // Liste des produits
          Expanded(
            child: StreamBuilder<QuerySnapshot>(
              stream: FirebaseFirestore.instance
                  .collection('stock')
                  .where('activity', isEqualTo: activityName)
                  .orderBy('name')
                  .snapshots(),
              builder: (context, snapshot) {
                if (!snapshot.hasData) {
                  return const Center(child: CircularProgressIndicator());
                }

                if (snapshot.data!.docs.isEmpty) {
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.inventory_2_outlined,
                          size: 64,
                          color: Colors.grey[400],
                        ),
                        const SizedBox(height: 16),
                        Text(
                          'Aucun produit en stock',
                          style: TextStyle(
                            fontSize: 18,
                            color: Colors.grey[600],
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Le manager doit ajouter des produits au stock',
                          style: TextStyle(
                            fontSize: 14,
                            color: Colors.grey[500],
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ],
                    ),
                  );
                }

                final products = snapshot.data!.docs;

                return RefreshIndicator(
                  onRefresh: () async {
                    // Le StreamBuilder se met à jour automatiquement
                  },
                  child: ListView.builder(
                    padding: const EdgeInsets.all(16),
                    itemCount: products.length,
                    itemBuilder: (context, index) {
                      final doc = products[index];
                      final data = doc.data() as Map<String, dynamic>;
                      final name = data['name'] ?? 'Produit inconnu';
                      final quantity = (data['quantity'] ?? 0) as int;
                      final unit = data['unit'] ?? 'unité';
                      final updatedAt = data['updatedAt'] as Timestamp?;

                      return Card(
                        margin: const EdgeInsets.only(bottom: 12),
                        elevation: 2,
                        child: ListTile(
                          leading: CircleAvatar(
                            backgroundColor: _getStockColor(quantity).withOpacity(0.2),
                            child: Icon(
                              quantity == 0
                                  ? Icons.error_outline
                                  : quantity <= 10
                                      ? Icons.warning_amber_rounded
                                      : Icons.check_circle_outline,
                              color: _getStockColor(quantity),
                            ),
                          ),
                          title: Text(
                            name,
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 16,
                            ),
                          ),
                          subtitle: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const SizedBox(height: 4),
                              Row(
                                children: [
                                  Text(
                                    'Quantité: ',
                                    style: TextStyle(
                                      fontSize: 14,
                                      color: Colors.grey[600],
                                    ),
                                  ),
                                  Text(
                                    '$quantity $unit${quantity > 1 ? 's' : ''}',
                                    style: TextStyle(
                                      fontSize: 14,
                                      fontWeight: FontWeight.bold,
                                      color: _getStockColor(quantity),
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 4),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 8,
                                  vertical: 4,
                                ),
                                decoration: BoxDecoration(
                                  color: _getStockColor(quantity).withOpacity(0.1),
                                  borderRadius: BorderRadius.circular(8),
                                  border: Border.all(
                                    color: _getStockColor(quantity).withOpacity(0.3),
                                    width: 1,
                                  ),
                                ),
                                child: Text(
                                  _getStockStatus(quantity),
                                  style: TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w500,
                                    color: _getStockColor(quantity),
                                  ),
                                ),
                              ),
                              if (updatedAt != null) ...[
                                const SizedBox(height: 4),
                                Text(
                                  'Mis à jour: ${_formatDate(updatedAt.toDate())}',
                                  style: TextStyle(
                                    fontSize: 11,
                                    color: Colors.grey[500],
                                  ),
                                ),
                              ],
                            ],
                          ),
                          trailing: Icon(
                            Icons.chevron_right,
                            color: Colors.grey[400],
                          ),
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
    return '${date.day}/${date.month}/${date.year} ${date.hour}:${date.minute.toString().padLeft(2, '0')}';
  }
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
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
        ),
        const SizedBox(height: 4),
        Text(
          label,
          style: TextStyle(
            fontSize: 11,
            color: Colors.grey[600],
          ),
          textAlign: TextAlign.center,
        ),
      ],
    );
  }
}

