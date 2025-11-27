import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

class MainStockPage extends StatefulWidget {
  const MainStockPage({super.key});

  @override
  State<MainStockPage> createState() => _MainStockPageState();
}

class _MainStockPageState extends State<MainStockPage> {
  String? selectedActivityFilter;
  List<String> activities = [];
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
        activities = query.docs
            .map((doc) => doc.data()['activityName'] as String? ?? '')
            .where((name) => name.isNotEmpty)
            .toList();
        loadingActivities = false;
      });
    } catch (e) {
      setState(() {
        loadingActivities = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Stock Principal", style: TextStyle(color: Colors.white)),
        backgroundColor: Colors.black,
      ),
      body: Column(
        children: [
          // Filtre par activité
          Container(
            padding: const EdgeInsets.all(16),
            color: Colors.grey[100],
            child: Row(
              children: [
                const Text(
                  'Filtrer par activité: ',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: DropdownButtonFormField<String?>(
                    value: selectedActivityFilter,
                    decoration: InputDecoration(
                      filled: true,
                      fillColor: Colors.white,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                    items: [
                      const DropdownMenuItem<String?>(
                        value: null,
                        child: Text('Toutes les activités'),
                      ),
                      ...activities.map((activity) {
                        return DropdownMenuItem<String?>(
                          value: activity,
                          child: Text(activity),
                        );
                      }),
                    ],
                    onChanged: (value) {
                      setState(() {
                        selectedActivityFilter = value;
                      });
                    },
                  ),
                ),
              ],
            ),
          ),
          // Liste du stock
          Expanded(
            child: StreamBuilder<QuerySnapshot>(
              stream: selectedActivityFilter == null
                  ? FirebaseFirestore.instance
                      .collection('central_stock')
                      .snapshots()
                  : FirebaseFirestore.instance
                      .collection('central_stock')
                      .where('activity', isEqualTo: selectedActivityFilter)
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
                        Icon(Icons.inventory_2_outlined, size: 64, color: Colors.grey[400]),
                        const SizedBox(height: 16),
                        Text(
                          selectedActivityFilter == null
                              ? 'Aucun produit en stock principal'
                              : 'Aucun produit pour "${selectedActivityFilter}"',
                          style: TextStyle(color: Colors.grey[600]),
                        ),
                      ],
                    ),
                  );
                }

                // Grouper par activité si pas de filtre
                Map<String, List<Map<String, dynamic>>> groupedByActivity = {};
                
                for (var doc in snapshot.data!.docs) {
                  final data = doc.data() as Map<String, dynamic>;
                  final activity = data['activity'] as String? ?? 'Sans activité';
                  
                  if (!groupedByActivity.containsKey(activity)) {
                    groupedByActivity[activity] = [];
                  }
                  
                  groupedByActivity[activity]!.add({
                    'id': doc.id,
                    'name': data['name'] ?? 'Produit inconnu',
                    'quantity': (data['quantity'] ?? 0) as int,
                    'unit': data['unit'] ?? 'unité',
                  });
                }
                
                // Trier les activités et les produits dans chaque activité
                final sortedActivities = groupedByActivity.keys.toList()..sort();
                for (var activity in sortedActivities) {
                  groupedByActivity[activity]!.sort((a, b) {
                    final nameA = a['name'] as String;
                    final nameB = b['name'] as String;
                    return nameA.compareTo(nameB);
                  });
                }

                return ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: selectedActivityFilter == null
                      ? groupedByActivity.length
                      : groupedByActivity[selectedActivityFilter]?.length ?? 0,
                  itemBuilder: (context, index) {
                    if (selectedActivityFilter == null) {
                      // Afficher par groupe d'activité
                      final sortedActivities = groupedByActivity.keys.toList()..sort();
                      final activity = sortedActivities[index];
                      final products = groupedByActivity[activity]!;
                      
                      return Card(
                        margin: const EdgeInsets.only(bottom: 16),
                        elevation: 2,
                        child: ExpansionTile(
                          leading: CircleAvatar(
                            backgroundColor: Colors.blue,
                            child: const Icon(Icons.business, color: Colors.white),
                          ),
                          title: Text(
                            activity,
                            style: const TextStyle(fontWeight: FontWeight.bold),
                          ),
                          subtitle: Text('${products.length} produit${products.length > 1 ? 's' : ''}'),
                          children: products.map((product) {
                            final quantity = product['quantity'] as int;
                            final unit = product['unit'] as String;
                            
                            return ListTile(
                              leading: CircleAvatar(
                                backgroundColor: quantity > 10
                                    ? Colors.green
                                    : quantity > 0
                                        ? Colors.orange
                                        : Colors.red,
                                child: Icon(
                                  quantity > 0 ? Icons.inventory : Icons.inventory_2_outlined,
                                  color: Colors.white,
                                ),
                              ),
                              title: Text(
                                product['name'] as String,
                                style: const TextStyle(fontWeight: FontWeight.w500),
                              ),
                              subtitle: Text('Unité: $unit'),
                              trailing: Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 12,
                                  vertical: 6,
                                ),
                                decoration: BoxDecoration(
                                  color: quantity > 10
                                      ? Colors.green.shade100
                                      : quantity > 0
                                          ? Colors.orange.shade100
                                          : Colors.red.shade100,
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: Text(
                                  '$quantity $unit${quantity > 1 ? 's' : ''}',
                                  style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    color: quantity > 10
                                        ? Colors.green.shade800
                                        : quantity > 0
                                            ? Colors.orange.shade800
                                            : Colors.red.shade800,
                                  ),
                                ),
                              ),
                            );
                          }).toList(),
                        ),
                      );
                    } else {
                      // Afficher directement les produits de l'activité sélectionnée
                      final products = groupedByActivity[selectedActivityFilter]!;
                      final product = products[index];
                      final quantity = product['quantity'] as int;
                      final unit = product['unit'] as String;
                      
                      return Card(
                        margin: const EdgeInsets.only(bottom: 12),
                        child: ListTile(
                          leading: CircleAvatar(
                            backgroundColor: quantity > 10
                                ? Colors.green
                                : quantity > 0
                                    ? Colors.orange
                                    : Colors.red,
                            child: Icon(
                              quantity > 0 ? Icons.inventory : Icons.inventory_2_outlined,
                              color: Colors.white,
                            ),
                          ),
                          title: Text(
                            product['name'] as String,
                            style: const TextStyle(fontWeight: FontWeight.bold),
                          ),
                          subtitle: Text('Unité: $unit'),
                          trailing: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 6,
                            ),
                            decoration: BoxDecoration(
                              color: quantity > 10
                                  ? Colors.green.shade100
                                  : quantity > 0
                                      ? Colors.orange.shade100
                                      : Colors.red.shade100,
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Text(
                              '$quantity $unit${quantity > 1 ? 's' : ''}',
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                color: quantity > 10
                                    ? Colors.green.shade800
                                    : quantity > 0
                                        ? Colors.orange.shade800
                                        : Colors.red.shade800,
                              ),
                            ),
                          ),
                        ),
                      );
                    }
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
