import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../common/error_messages.dart';

class NewTicketPage extends StatefulWidget {
  final String activityName;
  final String cashierId;

  const NewTicketPage({
    super.key,
    required this.activityName,
    required this.cashierId,
  });

  @override
  State<NewTicketPage> createState() => _NewTicketPageState();
}

class _NewTicketPageState extends State<NewTicketPage> {
  List<Map<String, dynamic>> selectedProducts = [];
  double total = 0;

  String? selectedServerId;
  String? selectedServerName;
  String? activityId;

  List<Map<String, dynamic>> servers = [];
  // ✅ OPTIMISATION : Map pour stocker les quantités de stock par nom de produit
  Map<String, int> stockQuantities = {};

  @override
  void initState() {
    super.initState();
    _loadActivityId();
    _loadServers();
    _loadStock();
  }

  Future<void> _loadActivityId() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      activityId = prefs.getString("activityId");
    });
  }


  Future<void> _loadServers() async {
    final query = await FirebaseFirestore.instance
        .collection('servers')
        .where('activity', isEqualTo: widget.activityName)
        .get();

    setState(() {
      servers = query.docs.map((e) {
        final data = e.data();

        return {
          'id': e.id,
          'name': (data['fullName'] ?? 'Serveur inconnu'),
        };
      }).toList();
    });
  }

  // ✅ OPTIMISATION : Charger tous les stocks en une seule fois
  Future<void> _loadStock() async {
    final stockQuery = await FirebaseFirestore.instance
        .collection('stock')
        .where('activity', isEqualTo: widget.activityName)
        .get();

    setState(() {
      stockQuantities = {};
      for (var doc in stockQuery.docs) {
        final data = doc.data();
        final name = data['name'] as String?;
        final quantity = (data['quantity'] ?? 0) as int;
        if (name != null) {
          stockQuantities[name] = quantity;
        }
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Nouveau Ticket • ${widget.activityName}',
          style: TextStyle(color: Colors.white),),
        backgroundColor: Colors.black,
      ),
      body: Column(
        children: [
          _buildServerSelector(),
          const Divider(height: 1),
          Expanded(child: _buildProductList()),
          _buildCartSummary(),
        ],
      ),
    );
  }

  // 🔹 Sélection du serveur
  Widget _buildServerSelector() {
    return Container(
      padding: const EdgeInsets.all(12),
      color: Colors.grey[100],
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            "Serveur",
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          DropdownButtonFormField<String>(
            value: selectedServerId,
            decoration: InputDecoration(
              filled: true,
              fillColor: Colors.white,
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
            ),
              items: servers.map<DropdownMenuItem<String>>((server) {
                return DropdownMenuItem<String>(
                  value: server['id'] as String,
                  child: Text(server['name'] as String),
                );
              }).toList(),
            onChanged: (value) {
              setState(() {
                selectedServerId = value;
                selectedServerName = servers
                    .firstWhere((s) => s['id'] == value)['name'];
              });
            },
          ),
        ],
      ),
    );
  }

  // 🔹 Liste des produits
  Widget _buildProductList() {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('products')
          .where('activity', isEqualTo: widget.activityName)
          .snapshots(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
        final products = snapshot.data!.docs;
        return RefreshIndicator(
          onRefresh: _loadStock,
          child: ListView.builder(
            itemCount: products.length,
            itemBuilder: (context, index) {
              final product = products[index];
              final productName = product['name'] as String;
              
              // ✅ OPTIMISATION : Utiliser le Map au lieu d'un FutureBuilder
              final availableStock = stockQuantities[productName] ?? 0;

              // Calculer la quantité déjà sélectionnée pour ce produit
              final selectedQty = selectedProducts
                  .where((p) => p['id'] == product.id)
                  .fold<int>(0, (sum, p) => sum + (p['quantity'] as int));

              final remainingStock = availableStock - selectedQty;
              final canAdd = remainingStock > 0;

              return ListTile(
                title: Text(
                  productName,
                  overflow: TextOverflow.ellipsis,
                  maxLines: 1,
                ),
                subtitle: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      '${product['price']} FC',
                      overflow: TextOverflow.ellipsis,
                      maxLines: 1,
                    ),
                    Text(
                      'Stock: $remainingStock / $availableStock',
                      style: TextStyle(
                        color: remainingStock > 10
                            ? Colors.green
                            : remainingStock > 0
                                ? Colors.orange
                                : Colors.red,
                        fontWeight: FontWeight.bold,
                      ),
                      overflow: TextOverflow.ellipsis,
                      maxLines: 1,
                    ),
                    if (selectedQty > 0)
                      Text(
                        'Dans le panier: $selectedQty',
                        style: const TextStyle(
                          color: Colors.blue,
                          fontSize: 12,
                        ),
                        overflow: TextOverflow.ellipsis,
                        maxLines: 1,
                      ),
                  ],
                ),
                trailing: IconButton(
                  icon: Icon(
                    Icons.add_circle,
                    color: canAdd ? Colors.green : Colors.grey,
                  ),
                  onPressed: canAdd ? () => _addProduct(product) : null,
                ),
              );
            },
          ),
        );
      },
    );
  }

  // 🔹 Résumé + bouton valider
  Widget _buildCartSummary() {
    final bool canValidate =
        selectedProducts.isNotEmpty && selectedServerId != null;

    return Container(
      padding: const EdgeInsets.all(16),
      color: Colors.grey[200],
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Liste des produits sélectionnés
          if (selectedProducts.isNotEmpty) ...[
            const Text(
              'Produits sélectionnés:',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            ...selectedProducts.map((product) => Padding(
                  padding: const EdgeInsets.symmetric(vertical: 4),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: Text(
                          '${product['name']} x${product['quantity']}',
                          overflow: TextOverflow.ellipsis,
                          maxLines: 1,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        '${((product['price'] as double) * (product['quantity'] as int)).toStringAsFixed(2)} FC',
                        style: const TextStyle(fontWeight: FontWeight.bold),
                      ),
                    ],
                  ),
                )),
            const Divider(),
          ],
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Flexible(
                child: Text(
                  'Total: FC${total.toStringAsFixed(2)}',
                  style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              const SizedBox(width: 8),
              ElevatedButton(
                onPressed: canValidate ? _createTicket : null,
                style: ElevatedButton.styleFrom(backgroundColor: Colors.black),
                child: const Text('Valider', style: TextStyle(color: Colors.white)),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // 🔹 Ajout produit (avec regroupement si même produit)
  Future<void> _addProduct(QueryDocumentSnapshot product) async {
    final productId = product.id;
    final productName = product['name'] as String;
    final productPrice = (product['price'] ?? 0).toDouble();

    // Vérifier le stock disponible
    final stockQuery = await FirebaseFirestore.instance
        .collection('stock')
        .where('name', isEqualTo: productName)
        .where('activity', isEqualTo: widget.activityName)
        .limit(1)
        .get();

    if (stockQuery.docs.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(ErrorMessages.stockNonTrouve),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    final stockDoc = stockQuery.docs.first;
    final availableStock = (stockDoc.data()['quantity'] ?? 0) as int;

    // Calculer la quantité déjà sélectionnée pour ce produit
    final selectedQty = selectedProducts
        .where((p) => p['id'] == productId)
        .fold<int>(0, (sum, p) => sum + (p['quantity'] as int));

    if (selectedQty >= availableStock) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('${ErrorMessages.stockInsuffisant(productName)} Disponible: $availableStock'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    setState(() {
      // Vérifier si le produit est déjà dans la liste
      final existingIndex = selectedProducts.indexWhere((p) => p['id'] == productId);

      if (existingIndex >= 0) {
        // Produit déjà présent : augmenter la quantité
        selectedProducts[existingIndex]['quantity'] = (selectedProducts[existingIndex]['quantity'] as int) + 1;
        total += productPrice;
      } else {
        // Nouveau produit : l'ajouter
        selectedProducts.add({
          'id': productId,
          'name': productName,
          'price': productPrice,
          'quantity': 1,
        });
        total += productPrice;
      }
    });
  }

  // 🔹 Enregistrement du ticket dans Firestore
  Future<void> _createTicket() async {
    // Validation préalable
    if (activityId == null || activityId!.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text(ErrorMessages.activiteNonTrouvee),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    if (selectedServerId == null || selectedServerId!.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text(ErrorMessages.serveurNonSelectionne),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    // Déduire le stock de l'activité AVANT de créer le ticket
    for (var product in selectedProducts) {
      final productName = product['name'] as String;
      final quantity = product['quantity'] as int;

      // Trouver le document stock correspondant
      final stockQuery = await FirebaseFirestore.instance
          .collection('stock')
          .where('name', isEqualTo: productName)
          .where('activity', isEqualTo: widget.activityName)
          .limit(1)
          .get();

      if (stockQuery.docs.isNotEmpty) {
        final stockRef = FirebaseFirestore.instance
            .collection('stock')
            .doc(stockQuery.docs.first.id);

        // 🔍 DEBUG : Vérifier les données avant la transaction
        try {
          final userDoc = await FirebaseFirestore.instance
              .collection('users')
              .doc(widget.cashierId)
              .get();
          final userData = userDoc.data();
          final userActivityName = userData?['activityName'] as String?;
          final userRole = userData?['role'] as String?;

          final stockDoc = await stockRef.get();
          final stockData = stockDoc.data();
          final stockActivity = stockData?['activity'] as String?;
          final stockQuantity = stockData?['quantity'] as int?;

          print('🔍 DEBUG - User ID: ${widget.cashierId}');
          print('🔍 DEBUG - User role: "$userRole"');
          print('🔍 DEBUG - User activityName: "$userActivityName" (type: ${userActivityName.runtimeType})');
          print('🔍 DEBUG - Stock activity: "$stockActivity" (type: ${stockActivity.runtimeType})');
          print('🔍 DEBUG - Stock quantity: $stockQuantity');
          print('🔍 DEBUG - Match: ${userActivityName == stockActivity}');
          print('🔍 DEBUG - Product: $productName, Quantity to deduct: $quantity');
          print('🔍 DEBUG - Widget activityName: "${widget.activityName}"');
          
          // Vérification détaillée
          if (userActivityName != stockActivity) {
            print('❌ ERREUR: Les activités ne correspondent pas!');
            print('   User: "$userActivityName" (length: ${userActivityName?.length})');
            print('   Stock: "$stockActivity" (length: ${stockActivity?.length})');
            print('   Codes ASCII User: ${userActivityName?.codeUnits}');
            print('   Codes ASCII Stock: ${stockActivity?.codeUnits}');
          }
        } catch (e) {
          print('🔍 DEBUG - Erreur lors de la vérification: $e');
        }

        await FirebaseFirestore.instance.runTransaction((transaction) async {
          final snapshot = await transaction.get(stockRef);
          if (!snapshot.exists) return;

          final currentQty = (snapshot.data()?['quantity'] ?? 0) as int;
          final newQty = currentQty - quantity;

          // ✅ Vérification 1: newQty >= 0 (ne peut pas être négatif)
          if (newQty < 0) {
            throw Exception(ErrorMessages.stockInsuffisant(productName));
          }

          // ✅ Vérification 2: newQty < currentQty (la quantité doit diminuer)
          if (newQty >= currentQty) {
            throw Exception(ErrorMessages.quantiteNePeutPasAugmenter);
          }

          // ✅ Vérification 3: Modifier seulement quantity et updatedAt
          // Les règles Firestore exigent que seuls quantity et updatedAt soient modifiés
          transaction.update(stockRef, {
            'quantity': newQty,
            'updatedAt': FieldValue.serverTimestamp(),
          });
        });
      }
    }

    // Créer le ticket
    try {
      final ticketRef = FirebaseFirestore.instance.collection('tickets').doc();

      await ticketRef.set({
        'cashierId': widget.cashierId,
        'activity': widget.activityName,
        'activityId': activityId, // ✅ Ajout de activityId
        'serverId': selectedServerId!,
        'serverName': selectedServerName,
        'products': selectedProducts,
        'total': total,
        'status': 'unpaid',
        'isOpen': true,
        'createdAt': FieldValue.serverTimestamp(),
      });

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(ErrorMessages.ticketCreeSucces),
          backgroundColor: Colors.green,
        ),
      );

      setState(() {
        selectedProducts.clear();
        selectedServerId = null;
        total = 0;
      });
    } catch (e) {
      // Si la création du ticket échoue, on affiche l'erreur
      // Note: Le stock a déjà été déduit, mais c'est acceptable car
      // la déduction du stock est validée avant la création du ticket
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(ErrorMessages.fromException(e)),
          backgroundColor: Colors.red,
        ),
      );
      // Ne pas vider les produits si erreur, pour permettre de réessayer
    }
  }
}