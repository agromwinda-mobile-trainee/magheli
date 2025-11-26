import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'ActivityStockEntryPage.dart';

class ActivityStockPage extends StatefulWidget {
  const ActivityStockPage({super.key});

  @override
  State<ActivityStockPage> createState() => _ActivityStockPageState();
}

class _ActivityStockPageState extends State<ActivityStockPage> {
  String? selectedActivityFilter;
  List<Map<String, dynamic>> activities = [];

  @override
  void initState() {
    super.initState();
    _loadActivities();
  }

  Future<void> _loadActivities() async {
    final query = await FirebaseFirestore.instance
        .collection('activities')
        .get();

    setState(() {
      activities = query.docs.map((doc) {
        final data = doc.data();
        return {
          'id': doc.id,
          'name': data['activityName'] ?? 'Activité inconnue',
        };
      }).toList();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Stock Activités", style: TextStyle(color: Colors.white)),
        backgroundColor: Colors.black,
        actions: [
          if (selectedActivityFilter != null)
            IconButton(
              icon: const Icon(Icons.add),
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => ActivityStockEntryPage(
                      activityName: selectedActivityFilter!,
                    ),
                  ),
                );
              },
            ),
        ],
      ),
      body: Column(
        children: [
          // Filtre par activité
          Container(
            padding: const EdgeInsets.all(16),
            color: Colors.grey[100],
            child: Row(
              children: [
                Flexible(
                  child: Text(
                    'Sélectionner une activité: ',
                    style: const TextStyle(fontWeight: FontWeight.bold),
                    overflow: TextOverflow.ellipsis,
                    maxLines: 1,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  flex: 2,
                  child: DropdownButtonFormField<String>(
                    value: selectedActivityFilter,
                    isExpanded: true,
                    decoration: InputDecoration(
                      filled: true,
                      fillColor: Colors.white,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                    items: [
                      const DropdownMenuItem<String>(
                        value: null,
                        child: Text(
                          'Sélectionner une activité',
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      ...activities.map((activity) {
                        return DropdownMenuItem<String>(
                          value: activity['name'] as String,
                          child: Text(
                            activity['name'] as String,
                            overflow: TextOverflow.ellipsis,
                            maxLines: 1,
                          ),
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
            child: selectedActivityFilter == null
                ? const Center(
                    child: Text('Veuillez sélectionner une activité'),
                  )
                : StreamBuilder<QuerySnapshot>(
                    stream: FirebaseFirestore.instance
                        .collection('stock')
                        .where('activity', isEqualTo: selectedActivityFilter)
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
                              const Text('Aucun produit en stock pour cette activité'),
                              const SizedBox(height: 16),
                              ElevatedButton.icon(
                                onPressed: () {
                                  Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                      builder: (_) => ActivityStockEntryPage(
                                        activityName: selectedActivityFilter!,
                                      ),
                                    ),
                                  );
                                },
                                icon: const Icon(Icons.add),
                                label: const Text('Ajouter un produit'),
                              ),
                            ],
                          ),
                        );
                      }

                      return ListView.builder(
                        padding: const EdgeInsets.all(16),
                        itemCount: snapshot.data!.docs.length,
                        itemBuilder: (context, index) {
                          final doc = snapshot.data!.docs[index];
                          final data = doc.data() as Map<String, dynamic>;
                          final name = data['name'] ?? 'Produit inconnu';
                          final quantity = (data['quantity'] ?? 0) as int;
                          final unit = data['unit'] ?? 'unité';

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
                                  quantity > 0
                                      ? Icons.inventory
                                      : Icons.inventory_2_outlined,
                                  color: Colors.white,
                                ),
                              ),
                              title: Text(
                                name,
                                style: const TextStyle(fontWeight: FontWeight.bold),
                                overflow: TextOverflow.ellipsis,
                                maxLines: 1,
                              ),
                              subtitle: Text(
                                'Unité: $unit',
                                overflow: TextOverflow.ellipsis,
                                maxLines: 1,
                              ),
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
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ),
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

