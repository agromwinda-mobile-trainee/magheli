import 'package:blue_thermal_printer/blue_thermal_printer.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import '../../services/invoice_print_service.dart';
import '../../common/error_messages.dart';

class InvoicePrintPage extends StatefulWidget {
  final String invoiceId;
  final Map<String, dynamic> invoiceData;

  const InvoicePrintPage({
    super.key,
    required this.invoiceId,
    required this.invoiceData,
  });

  @override
  State<InvoicePrintPage> createState() => _InvoicePrintPageState();
}

class _InvoicePrintPageState extends State<InvoicePrintPage> {
  List<BluetoothDevice> printers = [];
  BluetoothDevice? selectedPrinter;
  bool loading = false;
  bool searching = false;
  List<Map<String, dynamic>> products = [];
  String? serverName;
  String? activityName;
  String? clientName;
  bool loadingData = true;

  @override
  void initState() {
    super.initState();
    _loadInvoiceData();
  }

  Future<void> _loadInvoiceData() async {
    try {
      // Charger les produits depuis le ticket
      final ticketId = widget.invoiceData['ticketId'];
      if (ticketId != null) {
        final ticketDoc = await FirebaseFirestore.instance
            .collection('tickets')
            .doc(ticketId)
            .get();

        if (ticketDoc.exists) {
          final ticketData = ticketDoc.data()!;
          final rawProducts = ticketData['products'] as List<dynamic>? ?? [];
          products = rawProducts.map((p) => Map<String, dynamic>.from(p)).toList();
          activityName = ticketData['activity'] as String?;
        }
      }

      // Charger le nom du serveur
      final serverId = widget.invoiceData['serverId'];
      if (serverId != null && serverId.isNotEmpty) {
        final serverDoc = await FirebaseFirestore.instance
            .collection('servers')
            .doc(serverId)
            .get();

        if (serverDoc.exists) {
          final serverData = serverDoc.data()!;
          serverName = serverData['fullName'] as String?;
        }
      }

      // Charger le nom du client (s'il existe)
      clientName = widget.invoiceData['clientName'] as String?;

      setState(() {
        loadingData = false;
      });
    } catch (e) {
      setState(() {
        loadingData = false;
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(ErrorMessages.fromException(e)),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _searchPrinters() async {
    setState(() {
      searching = true;
      printers = [];
      selectedPrinter = null;
    });

    try {
      final foundPrinters = await InvoicePrintService.getAvailablePrinters();
      setState(() {
        printers = foundPrinters;
        searching = false;
      });

      if (foundPrinters.isEmpty) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Aucune imprimante Bluetooth trouvée. Assurez-vous que l\'imprimante est appairée avec votre appareil.'),
            ),
          );
        }
      }
    } catch (e) {
      setState(() {
        searching = false;
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text(ErrorMessages.rechercheImprimanteEchec),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _printInvoice() async {
    if (selectedPrinter == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(ErrorMessages.imprimanteNonSelectionnee),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    if (products.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text(ErrorMessages.factureDonneesChargeEchec),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    setState(() => loading = true);

    try {
      // Préparer les données de la facture avec l'ID
      final invoiceDataWithId = Map<String, dynamic>.from(widget.invoiceData);
      invoiceDataWithId['id'] = widget.invoiceId;

      await InvoicePrintService.printInvoice(
        printer: selectedPrinter!,
        invoiceData: invoiceDataWithId,
        products: products,
        activityName: activityName ?? 'Activité inconnue',
        serverName: serverName ?? 'Serveur inconnu',
        clientName: clientName,
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(ErrorMessages.impressionSucces),
            backgroundColor: Colors.green,
          ),
        );
        Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(ErrorMessages.impressionEchec),
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
    if (loadingData) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Imprimer Facture', style: TextStyle(color: Colors.white)),
        backgroundColor: Colors.black,
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Sélectionner une imprimante Bluetooth',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              'Assurez-vous que l\'imprimante est appairée avec votre appareil',
              style: TextStyle(
                fontSize: 12,
                color: Colors.grey,
              ),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: searching ? null : _searchPrinters,
                    icon: searching
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.search),
                    label: Text(searching ? 'Recherche...' : 'Rechercher imprimantes'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.black,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            if (printers.isEmpty && !searching)
              const Card(
                child: Padding(
                  padding: EdgeInsets.all(16),
                  child: Text(
                    'Aucune imprimante trouvée. Cliquez sur "Rechercher imprimantes" pour commencer.',
                    textAlign: TextAlign.center,
                  ),
                ),
              )
            else
              Expanded(
                child: ListView.builder(
                  itemCount: printers.length,
                  itemBuilder: (context, index) {
                    final printer = printers[index];
                    final isSelected = selectedPrinter?.address == printer.address;

                    return Card(
                      color: isSelected ? Colors.blue[50] : null,
                      child: ListTile(
                        leading: Icon(
                          Icons.print,
                          color: isSelected ? Colors.blue : Colors.grey,
                        ),
                        title: Text(
                          printer.name ?? 'Imprimante inconnue',
                          style: TextStyle(
                            fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                          ),
                        ),
                        subtitle: Text(printer.address ?? ''),
                        trailing: isSelected
                            ? const Icon(Icons.check_circle, color: Colors.blue)
                            : null,
                        onTap: () {
                          setState(() {
                            selectedPrinter = printer;
                          });
                        },
                      ),
                    );
                  },
                ),
              ),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: (selectedPrinter == null || loading) ? null : _printInvoice,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.green,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: loading
                    ? const CircularProgressIndicator(color: Colors.white)
                    : const Text(
                        'Imprimer la facture',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
