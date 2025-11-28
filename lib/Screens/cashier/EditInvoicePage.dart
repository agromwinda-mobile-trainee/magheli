import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import '../../common/error_messages.dart';

class EditInvoicePage extends StatefulWidget {
  final String invoiceId;
  final String cashierId;

  const EditInvoicePage({
    super.key,
    required this.invoiceId,
    required this.cashierId,
  });

  @override
  State<EditInvoicePage> createState() => _EditInvoicePageState();
}

class _EditInvoicePageState extends State<EditInvoicePage> {
  Map<String, dynamic>? invoiceData;
  double totalAmount = 0;
  double amountPaid = 0;
  double balance = 0;
  bool loading = true;
  final TextEditingController amountPaidController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _loadInvoice();
  }

  @override
  void dispose() {
    amountPaidController.dispose();
    super.dispose();
  }

  Future<void> _loadInvoice() async {
    setState(() => loading = true);
    try {
      final doc = await FirebaseFirestore.instance
          .collection('invoices')
          .doc(widget.invoiceId)
          .get();

      if (!doc.exists) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Facture introuvable')),
          );
          Navigator.pop(context);
        }
        return;
      }

      invoiceData = doc.data();
      totalAmount = (invoiceData!['totalAmount'] ?? 0).toDouble();
      amountPaid = (invoiceData!['amountPaid'] ?? 0).toDouble();
      balance = totalAmount - amountPaid;

      // Par défaut, le caissier saisit UN MONTANT À AJOUTER au montant déjà payé,
      // donc on laisse le champ vide (ou à 0) au lieu de pré-remplir avec amountPaid.
      amountPaidController.text = '';

      setState(() => loading = false);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(ErrorMessages.fromException(e)),
            backgroundColor: Colors.red,
          ),
        );
        Navigator.pop(context);
      }
    }
  }

  String _getStatus(double paid, double total) {
    if (paid == 0) return 'unpaid';
    if (paid < total) return 'partial';
    return 'paid';
  }

  Future<void> _saveInvoice() async {
    // Montant supplémentaire saisi par le caissier (à ajouter à amountPaid existant)
    final additionalPayment = double.tryParse(amountPaidController.text) ?? 0;

    if (additionalPayment < 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(ErrorMessages.montantNegatif),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    final updatedAmountPaid = amountPaid + additionalPayment;

    if (updatedAmountPaid > totalAmount) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(ErrorMessages.montantSuperieurTotal),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    final newBalance = totalAmount - updatedAmountPaid;
    final newStatus = _getStatus(updatedAmountPaid, totalAmount);

    setState(() => loading = true);

    try {
      await FirebaseFirestore.instance
          .collection('invoices')
          .doc(widget.invoiceId)
          .update({
        'amountPaid': updatedAmountPaid,
        'balance': newBalance,
        'paymentStatus': newStatus,
        'updatedAt': FieldValue.serverTimestamp(),
      });

      // Mettre à jour le statut du ticket associé si nécessaire
      final ticketId = invoiceData!['ticketId'];
      if (ticketId != null) {
        await FirebaseFirestore.instance
            .collection('tickets')
            .doc(ticketId)
            .update({
          'status': newStatus,
        });
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(ErrorMessages.factureModifieeSucces),
            backgroundColor: Colors.green,
          ),
        );
        Navigator.pop(context, true); // Retour avec succès
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(ErrorMessages.fromException(e)),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => loading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (loading) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    final newAmountPaid = double.tryParse(amountPaidController.text) ?? 0;
    final previewUpdatedAmountPaid = amountPaid + newAmountPaid;
    final newBalance = totalAmount - previewUpdatedAmountPaid;
    final newStatus = _getStatus(previewUpdatedAmountPaid, totalAmount);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Modifier Facture', style: TextStyle(color: Colors.white)),
        backgroundColor: Colors.black,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Card(
              elevation: 3,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Informations de la facture',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 16),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Flexible(
                          child: Text('Total:', style: TextStyle(fontSize: 16)),
                        ),
                        Flexible(
                          child: Text(
                            '${totalAmount.toStringAsFixed(2)} FC',
                            style: const TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                            ),
                            textAlign: TextAlign.end,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Flexible(
                          child: Text('Montant payé:', style: TextStyle(fontSize: 16)),
                        ),
                        Flexible(
                          child: Text(
                            '${amountPaid.toStringAsFixed(2)} FC',
                            style: const TextStyle(
                              fontSize: 16,
                              color: Colors.blue,
                            ),
                            textAlign: TextAlign.end,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Flexible(
                          child: Text('Solde actuel:', style: TextStyle(fontSize: 16)),
                        ),
                        Flexible(
                          child: Text(
                            '${balance.toStringAsFixed(2)} FC',
                            style: TextStyle(
                              fontSize: 16,
                              color: balance > 0 ? Colors.red : Colors.green,
                              fontWeight: FontWeight.bold,
                            ),
                            textAlign: TextAlign.end,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 24),
            TextField(
              controller: amountPaidController,
              keyboardType: TextInputType.numberWithOptions(decimal: true),
              decoration: InputDecoration(
                labelText: 'Montant à ajouter',
                hintText: 'Entrez le montant à ajouter au payé actuel',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                prefixIcon: const Icon(Icons.payment),
              ),
              onChanged: (value) {
                setState(() {});
              },
            ),
            const SizedBox(height: 16),
            Card(
              color: Colors.grey[100],
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Flexible(
                          child: Text('Nouveau solde:', style: TextStyle(fontSize: 16)),
                        ),
                        Flexible(
                          child: Text(
                            '${newBalance.toStringAsFixed(2)} FC',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              color: newBalance > 0 ? Colors.red : Colors.green,
                            ),
                            textAlign: TextAlign.end,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Flexible(
                          child: Text('Nouveau statut:', style: TextStyle(fontSize: 16)),
                        ),
                        Flexible(
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 6,
                            ),
                            decoration: BoxDecoration(
                              color: _getStatusColor(newStatus).withOpacity(0.2),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                color: _getStatusColor(newStatus),
                                width: 1,
                              ),
                            ),
                            child: Text(
                              _getStatusLabel(newStatus),
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                color: _getStatusColor(newStatus),
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: loading ? null : _saveInvoice,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.black,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: loading
                    ? const CircularProgressIndicator(color: Colors.white)
                    : const Text(
                        'Enregistrer les modifications',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
              ),
            ),
          ],
        ),
      ),
    );
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
}

