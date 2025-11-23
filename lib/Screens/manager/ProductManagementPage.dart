import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'EditProductPage.dart';

class ProductManagementPage extends StatefulWidget {
  const ProductManagementPage({super.key});

  @override
  State<ProductManagementPage> createState() => _ProductManagementPageState();
}

class _ProductManagementPageState extends State<ProductManagementPage> {
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
        title: const Text("Gérer Produits", style: TextStyle(color: Colors.white)),
        backgroundColor: Colors.black,
        actions: [
          IconButton(
            icon: const Icon(Icons.add),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => const EditProductPage(),
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
                const Text(
                  'Filtrer par activité: ',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
                const SizedBox(width: 12),
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
                      });
                    },
                  ),
                ),
              ],
            ),
          ),
          // Liste des produits
          Expanded(
            child: StreamBuilder<QuerySnapshot>(
              stream: selectedActivityFilter == null
                  ? FirebaseFirestore.instance
                      .collection('products')
                      .orderBy('activity')
                      .orderBy('name')
                      .snapshots()
                  : FirebaseFirestore.instance
                      .collection('products')
                      .where('activity', isEqualTo: selectedActivityFilter)
                      .orderBy('name')
                      .snapshots(),
              builder: (context, snapshot) {
                if (!snapshot.hasData) {
                  return const Center(child: CircularProgressIndicator());
                }

                if (snapshot.data!.docs.isEmpty) {
                  return const Center(
                    child: Text('Aucun produit trouvé'),
                  );
                }

                return ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: snapshot.data!.docs.length,
                  itemBuilder: (context, index) {
                    final doc = snapshot.data!.docs[index];
                    final data = doc.data() as Map<String, dynamic>;
                    final name = data['name'] ?? 'Produit inconnu';
                    final price = (data['price'] ?? 0).toDouble();
                    final activity = data['activity'] ?? 'Activité inconnue';
                    final createdAt = (data['createdAt'] as Timestamp?)?.toDate();

                    return Card(
                      margin: const EdgeInsets.only(bottom: 12),
                      child: ListTile(
                        leading: CircleAvatar(
                          backgroundColor: Colors.green,
                          child: const Icon(Icons.shopping_bag, color: Colors.white),
                        ),
                        title: Text(
                          name,
                          style: const TextStyle(fontWeight: FontWeight.bold),
                        ),
                        subtitle: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('Activité: $activity'),
                            Text('Prix: ${price.toStringAsFixed(2)} FC'),
                            if (createdAt != null)
                              Text(
                                'Créé le: ${_formatDate(createdAt)}',
                                style: const TextStyle(fontSize: 12, color: Colors.grey),
                              ),
                          ],
                        ),
                        trailing: IconButton(
                          icon: const Icon(Icons.edit),
                          onPressed: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) => EditProductPage(productId: doc.id),
                              ),
                            );
                          },
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

  String _formatDate(DateTime date) {
    return '${date.day}/${date.month}/${date.year}';
  }
}

