import 'dart:io';

import 'package:bluetooth_print/bluetooth_print.dart';
import 'package:bluetooth_print/bluetooth_print_model.dart';

class IosInvoicePrintService {
  static final BluetoothPrint _bt = BluetoothPrint.instance;

  static Future<List<BluetoothDevice>> getAvailablePrinters() async {
    if (!Platform.isIOS) return [];

    await _bt.startScan(timeout: const Duration(seconds: 4));
    final results = await _bt.scanResults.first;
    return results;
  }

  static Future<void> printInvoice({
    required BluetoothDevice printer,
    required Map<String, dynamic> invoiceData,
    required List<Map<String, dynamic>> products,
    required String activityName,
    required String serverName,
    String? clientName,
  }) async {
    if (!Platform.isIOS) return;

    await _bt.connect(printer);

    final List<LineText> lines = [];

    // En-tête
    lines.add(LineText(
      type: LineText.TYPE_TEXT,
      content: 'MAGHALI',
      align: LineText.ALIGN_CENTER,
      weight: 2,
      linefeed: 1,
    ));
    lines.add(LineText(
      type: LineText.TYPE_TEXT,
      content: activityName,
      align: LineText.ALIGN_CENTER,
      weight: 1,
      linefeed: 1,
    ));
    lines.add(LineText(
      type: LineText.TYPE_TEXT,
      content: 'FACTURE',
      align: LineText.ALIGN_CENTER,
      weight: 1,
      linefeed: 1,
    ));

    // Infos facture
    final invoiceId = (invoiceData['id'] ?? '').toString();
    lines.add(LineText(
      type: LineText.TYPE_TEXT,
      content: 'Facture: ${invoiceId.length > 8 ? invoiceId.substring(0, 8) : invoiceId}',
      align: LineText.ALIGN_LEFT,
      linefeed: 1,
    ));

    lines.add(LineText(
      type: LineText.TYPE_TEXT,
      content: 'Serveur: $serverName',
      align: LineText.ALIGN_LEFT,
      linefeed: 1,
    ));

    if (clientName != null && clientName.isNotEmpty) {
      lines.add(LineText(
        type: LineText.TYPE_TEXT,
        content: 'Client: $clientName',
        align: LineText.ALIGN_LEFT,
        linefeed: 1,
      ));
    }

    lines.add(LineText(
      type: LineText.TYPE_TEXT,
      content: '------------------------------',
      align: LineText.ALIGN_LEFT,
      linefeed: 1,
    ));

    // Produits
    for (final product in products) {
      final name = (product['name'] ?? 'Produit').toString();
      final quantity = (product['quantity'] ?? 1) as int;
      final price = (product['price'] ?? 0).toDouble();
      final subtotal = price * quantity;

      lines.add(LineText(
        type: LineText.TYPE_TEXT,
        content: name,
        align: LineText.ALIGN_LEFT,
        linefeed: 1,
      ));
      lines.add(LineText(
        type: LineText.TYPE_TEXT,
        content:
            '${quantity}x  ${price.toStringAsFixed(2)} FC   ${subtotal.toStringAsFixed(2)} FC',
        align: LineText.ALIGN_RIGHT,
        linefeed: 1,
      ));
    }

    lines.add(LineText(
      type: LineText.TYPE_TEXT,
      content: '------------------------------',
      align: LineText.ALIGN_LEFT,
      linefeed: 1,
    ));

    final totalAmount = (invoiceData['totalAmount'] ?? 0).toDouble();
    final amountPaid = (invoiceData['amountPaid'] ?? 0).toDouble();
    final balance = (invoiceData['balance'] ?? 0).toDouble();
    final paymentStatus = (invoiceData['paymentStatus'] ?? 'unpaid').toString();

    lines.add(LineText(
      type: LineText.TYPE_TEXT,
      content: 'TOTAL: ${totalAmount.toStringAsFixed(2)} FC',
      align: LineText.ALIGN_RIGHT,
      weight: 2,
      linefeed: 1,
    ));

    lines.add(LineText(
      type: LineText.TYPE_TEXT,
      content: 'Payé: ${amountPaid.toStringAsFixed(2)} FC',
      align: LineText.ALIGN_RIGHT,
      linefeed: 1,
    ));

    if (balance > 0) {
      lines.add(LineText(
        type: LineText.TYPE_TEXT,
        content: 'Reste: ${balance.toStringAsFixed(2)} FC',
        align: LineText.ALIGN_RIGHT,
        linefeed: 1,
      ));
    }

    lines.add(LineText(
      type: LineText.TYPE_TEXT,
      content: _getStatusLabel(paymentStatus),
      align: LineText.ALIGN_CENTER,
      weight: 2,
      linefeed: 1,
    ));

    lines.add(LineText(
      type: LineText.TYPE_TEXT,
      content: 'Merci de votre visite!',
      align: LineText.ALIGN_CENTER,
      linefeed: 2,
    ));

    await _bt.printReceipt({}, lines);
    await _bt.disconnect();
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


