import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class EditTicketPage extends StatefulWidget {
  final String ticketId;
  const EditTicketPage({super.key, required this.ticketId});

  @override
  State<EditTicketPage> createState() => _EditTicketPageState();
}

class _EditTicketPageState extends State<EditTicketPage> {
  Map<String, dynamic>? ticketData;
  List<Map<String, dynamic>> products = [];
  Map<String, int> oldQuantities = {};
  double total = 0;
  bool loading = true;

  @override
  void initState() {
    super.initState();
    loadTicket();
  }

  Future<void> loadTicket() async {
    setState(() => loading = true);
    final doc = await FirebaseFirestore.instance.collection('tickets').doc(widget.ticketId).get();
    final data = doc.data();
    if (data == null) {
      // ticket manquant
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Ticket introuvable")));
      Navigator.pop(context);
      return;
    }
    ticketData = data;
    // Normalise les produits en List<Map<String,dynamic>>
    final raw = (data['products'] ?? []) as List<dynamic>;
    products = raw.map<Map<String, dynamic>>((e) {
      final m = Map<String, dynamic>.from(e as Map);
      // assure les champs nécessaires
      m['id'] = m['id']?.toString() ?? '';
      m['name'] = m['name']?.toString() ?? 'Produit';
      m['price'] = (m['price'] is num) ? (m['price'] as num).toDouble() : double.tryParse(m['price']?.toString() ?? '0') ?? 0.0;
      m['quantity'] = (m['quantity'] is int) ? m['quantity'] as int : int.tryParse(m['quantity']?.toString() ?? '1') ?? 1;
      //  Sauvegarde anciennes quantités
      oldQuantities[m['id']] = m['quantity'];
      return m;
    }).toList();

    _recalculateTotal();
    setState(() => loading = false);
  }


  void _recalculateTotal() {
    total = 0;
    for (var p in products) {
      final price = (p['price'] is num) ? (p['price'] as num).toDouble() : double.tryParse(p['price'].toString()) ?? 0.0;
      final qty = (p['quantity'] is int) ? p['quantity'] as int : int.tryParse(p['quantity'].toString()) ?? 1;
      total += price * qty;
    }
  }

  //adjust stock
  Future<void> adjustStock(String productId, int diff) async {
    final ref = FirebaseFirestore.instance.collection("stock").doc(productId);

    await FirebaseFirestore.instance.runTransaction((tx) async {
      final snap = await tx.get(ref);
      if (!snap.exists) return;

      final currentQty = (snap["quantity"] ?? 0) as int;

      tx.update(ref, {
        "quantity": currentQty - diff,
        "updatedAt": FieldValue.serverTimestamp()
      });
    });
  }

  void _editQuantityDialog(int index) {
    final controller = TextEditingController(text: products[index]['quantity'].toString());
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: Text('Modifier quantité — ${products[index]['name']}'),
        content: TextField(
          controller: controller,
          keyboardType: TextInputType.number,
          decoration: const InputDecoration(labelText: 'Quantité'),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Annuler')),
          ElevatedButton(
            onPressed: () {
              final v = int.tryParse(controller.text) ?? 1;
              setState(() {
                products[index]['quantity'] = v;
                _recalculateTotal();
              });
              Navigator.pop(context);
            },
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  void _removeProduct(int index) {
    setState(() {
      products.removeAt(index);
      _recalculateTotal();
    });
  }

  Future<void> _saveTicket() async {
    setState(() => loading = true);

    try {
      // 🔥 Ajustement du stock AVANT la sauvegarde
      for (var p in products) {
        final id = p["id"];
        final oldQty = oldQuantities[id] ?? 0;
        final newQty = p["quantity"];

        final diff = newQty - oldQty; // ex: +3 ou -2

        if (diff != 0) {
          await adjustStock(id, diff);
        }
      }

      // 🔥 Produits supprimés → restituer le stock
      for (var id in oldQuantities.keys) {
        if (!products.any((p) => p["id"] == id)) {
          await adjustStock(id, -oldQuantities[id]!);
        }
      }

      // 🔥 Sauvegarde du ticket
      await FirebaseFirestore.instance.collection('tickets').doc(widget.ticketId).update({
        'products': products,
        'total': total,
        'updatedAt': FieldValue.serverTimestamp(),
      });

      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Ticket mis à jour')));
      Navigator.pop(context);

    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Erreur stock: $e')));
    } finally {
      setState(() => loading = false);
    }
  }

  // Option : ajouter un produit existant (simple UI pour ajouter manuellement)
  void _addProductManual() {
    final nameController = TextEditingController();
    final priceController = TextEditingController();
    final qtyController = TextEditingController(text: '1');

    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Ajouter produit'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(controller: nameController, decoration: const InputDecoration(labelText: 'Nom')),
            TextField(controller: priceController, decoration: const InputDecoration(labelText: 'Prix'), keyboardType: TextInputType.number),
            TextField(controller: qtyController, decoration: const InputDecoration(labelText: 'Quantité'), keyboardType: TextInputType.number),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Annuler')),
          ElevatedButton(
            onPressed: () {
              final name = nameController.text.trim();
              final price = double.tryParse(priceController.text) ?? 0.0;
              final qty = int.tryParse(qtyController.text) ?? 1;
              setState(() {
                products.add({'id': DateTime.now().millisecondsSinceEpoch.toString(), 'name': name, 'price': price, 'quantity': qty});
                _recalculateTotal();
              });
              Navigator.pop(context);
            },
            child: const Text('Ajouter'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (loading) return const Scaffold(body: Center(child: CircularProgressIndicator()));

    return Scaffold(
      appBar: AppBar(title: const Text('Modifier Ticket',style:
        TextStyle(color: Colors.white),), backgroundColor: Colors.black, actions: [
        IconButton(onPressed: _addProductManual, icon: const Icon(Icons.add)),
        IconButton(onPressed: _saveTicket, icon: const Icon(Icons.save)),
      ]),
      body: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          children: [
            Text('Serveur: ${ticketData?['serverName'] ?? '—'}', style: const TextStyle(fontSize: 16)),
            const SizedBox(height: 8),
            Expanded(
              child: ListView.separated(
                itemCount: products.length,
                separatorBuilder: (_, __) => const Divider(),
                itemBuilder: (context, i) {
                  final p = products[i];
                  return ListTile(
                    title: Text(p['name'] ?? 'Produit'),
                    subtitle: Text('Prix: ${p['price']} FC • Qté: ${p['quantity']}'),
                    trailing: Row(mainAxisSize: MainAxisSize.min, children: [
                      IconButton(icon: const Icon(Icons.edit), onPressed: () => _editQuantityDialog(i)),
                      IconButton(icon: const Icon(Icons.delete), onPressed: () => _removeProduct(i)),
                    ]),
                  );
                },
              ),
            ),
            const Divider(),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('Total', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                Text('${total.toStringAsFixed(2)} FC', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
              ],
            ),
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(onPressed: _saveTicket, child: const Text('Enregistrer les modifications')),
            ),
          ],
        ),
      ),
    );
  }
}