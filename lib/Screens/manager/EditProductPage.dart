import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

class EditProductPage extends StatefulWidget {
  final String? productId;
  const EditProductPage({super.key, this.productId});

  @override
  State<EditProductPage> createState() => _EditProductPageState();
}

class _EditProductPageState extends State<EditProductPage> {
  final _formKey = GlobalKey<FormState>();
  final nameController = TextEditingController();
  final priceController = TextEditingController();
  
  String? selectedActivityId;
  String? selectedActivityName;
  List<Map<String, dynamic>> activities = [];
  bool loading = false;
  bool isEditing = false;

  @override
  void initState() {
    super.initState();
    isEditing = widget.productId != null;
    _initializeData();
  }

  Future<void> _initializeData() async {
    // Charger d'abord les activités
    await _loadActivities();
    
    // Ensuite charger le produit si on est en mode édition
    if (isEditing) {
      await _loadProduct();
    }
  }

  Future<void> _loadActivities() async {
    try {
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
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erreur lors du chargement des activités: $e')),
        );
      }
    }
  }

  Future<void> _loadProduct() async {
    if (widget.productId == null) return;

    setState(() => loading = true);

    try {
      final doc = await FirebaseFirestore.instance
          .collection('products')
          .doc(widget.productId!)
          .get();

      if (doc.exists && mounted) {
        final data = doc.data()!;
        nameController.text = data['name'] ?? '';
        priceController.text = (data['price'] ?? 0).toString();
        
        final activityName = data['activity'] as String? ?? '';
        
        // Trouver l'activité dans la liste chargée
        if (activityName.isNotEmpty && activities.isNotEmpty) {
          final activity = activities.firstWhere(
            (a) => (a['name'] as String) == activityName,
            orElse: () => {'id': '', 'name': activityName},
          );
          
          setState(() {
            selectedActivityId = activity['id'] as String?;
            selectedActivityName = activityName;
          });
        } else {
          // Si l'activité n'est pas trouvée, garder juste le nom
          setState(() {
            selectedActivityName = activityName;
          });
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erreur lors du chargement: $e')),
        );
      }
    } finally {
      if (mounted) {
        setState(() => loading = false);
      }
    }
  }

  Future<void> _saveProduct() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    if (selectedActivityName == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Veuillez sélectionner une activité')),
      );
      return;
    }

    setState(() => loading = true);

    try {
      final price = double.tryParse(priceController.text);
      if (price == null || price <= 0) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Prix invalide')),
        );
        setState(() => loading = false);
        return;
      }

      final productData = {
        'name': nameController.text.trim(),
        'activity': selectedActivityName,
        'price': price,
        'updatedAt': FieldValue.serverTimestamp(),
      };

      if (isEditing) {
        // Mettre à jour le produit existant
        await FirebaseFirestore.instance
            .collection('products')
            .doc(widget.productId!)
            .update(productData);
        
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Produit mis à jour avec succès')),
        );
      } else {
        // Créer un nouveau produit
        productData['createdAt'] = FieldValue.serverTimestamp();
        await FirebaseFirestore.instance
            .collection('products')
            .add(productData);
        
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Produit créé avec succès')),
        );
      }

      Navigator.pop(context);
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Erreur: $e')),
      );
    } finally {
      setState(() => loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          isEditing ? "Modifier Produit" : "Créer Produit",
          style: const TextStyle(color: Colors.white),
        ),
        backgroundColor: Colors.black,
      ),
      body: loading && isEditing
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    TextFormField(
                      controller: nameController,
                      decoration: InputDecoration(
                        labelText: 'Nom du produit *',
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        prefixIcon: const Icon(Icons.shopping_bag),
                      ),
                      validator: (value) {
                        if (value == null || value.isEmpty) {
                          return 'Veuillez saisir le nom du produit';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 16),
                    DropdownButtonFormField<String>(
                      value: selectedActivityId,
                      decoration: InputDecoration(
                        labelText: 'Activité *',
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        prefixIcon: const Icon(Icons.business),
                      ),
                      items: activities.map((activity) {
                        return DropdownMenuItem<String>(
                          value: activity['id'] as String,
                          child: Text(activity['name'] as String),
                        );
                      }).toList(),
                      onChanged: (value) {
                        if (value != null) {
                          setState(() {
                            selectedActivityId = value;
                            final activity = activities.firstWhere(
                              (a) => a['id'] == value,
                              orElse: () => {'id': value, 'name': 'Activité inconnue'},
                            );
                            selectedActivityName = activity['name'] as String;
                          });
                        }
                      },
                      validator: (value) {
                        if (value == null) {
                          return 'Veuillez sélectionner une activité';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: priceController,
                      keyboardType: TextInputType.number,
                      decoration: InputDecoration(
                        labelText: 'Prix (FC) *',
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        prefixIcon: const Icon(Icons.attach_money),
                      ),
                      validator: (value) {
                        if (value == null || value.isEmpty) {
                          return 'Veuillez saisir le prix';
                        }
                        final price = double.tryParse(value);
                        if (price == null || price <= 0) {
                          return 'Prix invalide';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 30),
                    ElevatedButton(
                      onPressed: loading ? null : _saveProduct,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.black,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child: loading
                          ? const CircularProgressIndicator(color: Colors.white)
                          : Text(
                              isEditing ? 'Mettre à jour' : 'Créer le produit',
                              style: const TextStyle(color: Colors.white, fontSize: 18),
                            ),
                    ),
                  ],
                ),
              ),
            ),
    );
  }

  @override
  void dispose() {
    nameController.dispose();
    priceController.dispose();
    super.dispose();
  }
}

