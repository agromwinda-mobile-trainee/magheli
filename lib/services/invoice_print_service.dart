import 'package:blue_thermal_printer/blue_thermal_printer.dart';
import 'package:esc_pos_utils/esc_pos_utils.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';

class InvoicePrintService {
  static BlueThermalPrinter bluetooth = BlueThermalPrinter.instance;

  static Future<List<BluetoothDevice>> getAvailablePrinters() async {
    try {
      final devices = await bluetooth.getBondedDevices();
      return devices;
    } catch (e) {
      throw Exception('Erreur lors de la recherche d\'imprimantes: $e');
    }
  }

  static Future<void> printInvoice({
    required BluetoothDevice printer,
    required Map<String, dynamic> invoiceData,
    required List<Map<String, dynamic>> products,
    required String activityName,
    required String serverName,
    String? clientName,
  }) async {
    try {
      // Connexion à l'imprimante
      final connected = await bluetooth.connect(printer);
      if (!connected) {
        throw Exception('Impossible de se connecter à l\'imprimante');
      }

      // Génération du ticket
      final generator = Generator(PaperSize.mm80, await _getCapabilityProfile());
      List<int> bytes = [];

      // En-tête (police réduite pour raccourcir la facture)
      bytes += generator.text(
        'MAGHALI',
        styles: const PosStyles(
          align: PosAlign.center,
          bold: true,
          // taille normale (1x1) au lieu de 2x2
        ),
      );
      bytes += generator.text(
        activityName,
        styles: const PosStyles(
          align: PosAlign.center,
          bold: true,
        ),
      );
      bytes += generator.hr();
      bytes += generator.text(
        'FACTURE',
        styles: const PosStyles(
          align: PosAlign.center,
          bold: true,
          // taille normale au lieu de height size2
        ),
      );
      bytes += generator.hr();

      // Informations de la facture
      final invoiceId = invoiceData['id'] ?? '';
      bytes += generator.row([
        PosColumn(text: 'Facture #:', width: 6),
        PosColumn(text: invoiceId.length >= 8 ? invoiceId.substring(0, 8) : invoiceId, width: 6),
      ]);
      
      final createdAt = invoiceData['createdAt'];
      if (createdAt != null) {
        String dateStr = '';
        if (createdAt is DateTime) {
          dateStr = DateFormat('dd/MM/yyyy HH:mm').format(createdAt);
        } else {
          // Si c'est un Timestamp Firestore
          try {
            dateStr = DateFormat('dd/MM/yyyy HH:mm').format(createdAt.toDate());
          } catch (e) {
            dateStr = 'Date inconnue';
          }
        }
        bytes += generator.row([
          PosColumn(text: 'Date:', width: 6),
          PosColumn(text: dateStr, width: 6),
        ]);
      }

      bytes += generator.row([
        PosColumn(text: 'Serveur:', width: 6),
        PosColumn(text: serverName, width: 6),
      ]);
      
      // Afficher le nom du client uniquement s'il existe
      if (clientName != null && clientName.isNotEmpty) {
        bytes += generator.row([
          PosColumn(text: 'Client:', width: 6),
          PosColumn(text: clientName, width: 6),
        ]);
      }
      
      bytes += generator.hr();

      // Liste des produits
      bytes += generator.text(
        'PRODUITS',
        styles: const PosStyles(
          align: PosAlign.center,
          bold: true,
        ),
      );
      bytes += generator.hr();

      for (var product in products) {
        final name = product['name']?.toString() ?? 'Produit';
        final quantity = (product['quantity'] ?? 1) as int;
        final price = (product['price'] ?? 0).toDouble();
        final subtotal = price * quantity;

        // Nom du produit (peut être tronqué si trop long)
        final nameLines = _splitText(name, 20);
        for (var line in nameLines) {
          bytes += generator.text(line);
        }

        // Quantité, prix unitaire et sous-total
        bytes += generator.row([
          PosColumn(
            text: '${quantity}x',
            width: 2,
            styles: const PosStyles(align: PosAlign.left),
          ),
          PosColumn(
            text: '${price.toStringAsFixed(2)} FC',
            width: 4,
            styles: const PosStyles(align: PosAlign.right),
          ),
          PosColumn(
            text: '${subtotal.toStringAsFixed(2)} FC',
            width: 6,
            styles: const PosStyles(align: PosAlign.right, bold: true),
          ),
        ]);
        bytes += generator.hr();
      }

      // Totaux
      final totalAmount = (invoiceData['totalAmount'] ?? 0).toDouble();
      final amountPaid = (invoiceData['amountPaid'] ?? 0).toDouble();
      final balance = (invoiceData['balance'] ?? 0).toDouble();
      final paymentStatus = invoiceData['paymentStatus']?.toString() ?? 'unpaid';

      bytes += generator.hr();
      bytes += generator.row([
        PosColumn(
          text: 'TOTAL:',
          width: 6,
          styles: const PosStyles(
            bold: true,
            // taille normale pour réduire la longueur du ticket
          ),
        ),
        PosColumn(
          text: '${totalAmount.toStringAsFixed(2)} FC',
          width: 6,
          styles: const PosStyles(
            align: PosAlign.right,
            bold: true,
            // taille normale au lieu de size2
          ),
        ),
      ]);
      bytes += generator.row([
        PosColumn(text: 'Payé:', width: 6),
        PosColumn(
          text: '${amountPaid.toStringAsFixed(2)} FC',
          width: 6,
          styles: const PosStyles(align: PosAlign.right),
        ),
      ]);
      
      if (balance > 0) {
        bytes += generator.row([
          PosColumn(
            text: 'Reste:',
            width: 6,
            styles: const PosStyles(bold: true),
          ),
          PosColumn(
            text: '${balance.toStringAsFixed(2)} FC',
            width: 6,
            styles: const PosStyles(
              align: PosAlign.right,
              bold: true,
            ),
          ),
        ]);
      }

      bytes += generator.hr();
      bytes += generator.text(
        _getStatusLabel(paymentStatus),
        styles: const PosStyles(
          align: PosAlign.center,
          bold: true,
          // taille normale au lieu de size2
        ),
      );
      bytes += generator.hr();
      bytes += generator.hr();

      // Message de remerciement
      bytes += generator.text(
        'Merci de votre visite!',
        styles: const PosStyles(
          align: PosAlign.center,
        ),
      );
      bytes += generator.feed(2);
      bytes += generator.cut();

      // Envoi à l'imprimante
      await bluetooth.writeBytes(Uint8List.fromList(bytes));
      await bluetooth.disconnect();
    } catch (e) {
      try {
        await bluetooth.disconnect();
      } catch (_) {}
      throw Exception('Erreur lors de l\'impression: $e');
    }
  }

  static Future<CapabilityProfile> _getCapabilityProfile() async {
    // Utiliser un profil générique pour la plupart des imprimantes ESC/POS
    return await CapabilityProfile.load();
  }

  static List<String> _splitText(String text, int maxLength) {
    if (text.length <= maxLength) {
      return [text];
    }
    List<String> lines = [];
    for (int i = 0; i < text.length; i += maxLength) {
      int end = (i + maxLength < text.length) ? i + maxLength : text.length;
      lines.add(text.substring(i, end));
    }
    return lines;
  }

  static String _getStatusLabel(String status) {
    switch (status) {
      case 'paid':
        return 'PAYEE';
      case 'partial':
        return 'PARTIELLEMENT PAYEE';
      case 'unpaid':
        return 'IMPAYEE';
      default:
        return status.toUpperCase();
    }
  }
}
