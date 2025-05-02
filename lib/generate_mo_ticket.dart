import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:intl/intl.dart';
import 'package:flutter/services.dart';
import 'package:printing/printing.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'ComprobanteModel.dart';
import 'pdf_optimizer.dart'; // Import our optimizer

class MoTicketGenerator {
  // Use our optimizer
  final PdfOptimizer _optimizer = PdfOptimizer();
  bool _resourcesLoaded = false;

  // Preload resources method
  Future<void> _ensureResourcesLoaded() async {
    if (!_resourcesLoaded) {
      await _optimizer.preloadResources();
      _resourcesLoaded = true;
    }
  }

  Future<void> generateMoTicket(
      PdfPageFormat format,
      List<Map<String, dynamic>> offerEntries,
      bool isSwitchOn,
      BuildContext context,
      Function(String, double, List<double>, String) onGenerateComplete) async {

    final comprobanteModel = Provider.of<ComprobanteModel>(context, listen: false);

    // Preload PDF resources
    await _ensureResourcesLoaded();

    // Incrementar y obtener el número de comprobante antes de crear el PDF
    await comprobanteModel.incrementComprobante();
    String comprobante = comprobanteModel.formattedComprobante;

    // Calcular subtotales y total
    double total = 0.0;
    List<double> subtotals = [];

    // Simplified calculation
    for (var entry in offerEntries) {
      int quantity = int.tryParse(entry['number'] ?? '0') ?? 0;
      double price = double.tryParse(entry['value'] ?? '0.0') ?? 0.0;
      double subtotal = quantity * price;

      total += subtotal;
      subtotals.add(subtotal);
    }

    try {
      // Crear y guardar el PDF
      final Uint8List pdfData = await _generateTicketPdf(
          offerEntries,
          comprobante,
          isSwitchOn,
          false, // No es reimpresión
          subtotals,
          total
      );

      // Imprimir el PDF
      await Printing.layoutPdf(
        onLayout: (PdfPageFormat format) async => pdfData,
        format: PdfPageFormat(58 * PdfPageFormat.mm, double.infinity), // Usar formato de 58mm
      );

      // Guardar el número de comprobante en SharedPreferences
      final prefs = await SharedPreferences.getInstance();
      await prefs.setInt('comprobanteNumber', comprobanteModel.comprobanteNumber);

      // Llamar al callback con los datos relevantes
      onGenerateComplete('Oferta Ruta', total, subtotals, comprobante);

    } catch (e) {
      print('Error generating MO ticket: $e');
      // Clear resources on error
      _optimizer.clearCache();
      throw e;
    }
  }

  // Método de reimpresión mejorado
  Future<void> reprintMoTicket(
      PdfPageFormat format,
      List<Map<String, dynamic>> offerEntries,
      bool isSwitchOn,
      BuildContext context,
      String comprobante) async {

    // Preload PDF resources
    await _ensureResourcesLoaded();

    try {
      // Calcular subtotales y total (simplified)
      double total = 0.0;
      List<double> subtotals = [];

      for (var entry in offerEntries) {
        int quantity = int.tryParse(entry['number'] ?? '0') ?? 0;
        double price = double.tryParse(entry['value'] ?? '0.0') ?? 0.0;
        double subtotal = quantity * price;

        total += subtotal;
        subtotals.add(subtotal);
      }

      // Generate PDF for reprint
      final Uint8List pdfData = await _generateTicketPdf(
          offerEntries,
          comprobante,
          isSwitchOn,
          true, // Es reimpresión
          subtotals,
          total
      );

      // Print it
      await Printing.layoutPdf(
        onLayout: (PdfPageFormat format) async => pdfData,
        format: PdfPageFormat(58 * PdfPageFormat.mm, double.infinity), // Usar formato de 58mm
      );

    } catch (e) {
      print('Error en reprintMoTicket: $e');
      // Clear resources on error
      _optimizer.clearCache();
      throw e;
    }
  }

  // Método común para generar el PDF (usado tanto para impresión original como reimpresión)
  Future<Uint8List> _generateTicketPdf(
      List<Map<String, dynamic>> offerEntries,
      String comprobante,
      bool isSwitchOn,
      bool isReprint,
      List<double> subtotals,
      double total) async {

    // Use our optimized document
    final doc = _optimizer.createDocument();
    final pdfWidth = 58 * PdfPageFormat.mm;

    // Obtener la fecha y hora actual
    String currentDate = DateFormat('dd/MM/yyyy').format(DateTime.now());
    String currentTime = DateFormat('HH:mm:ss').format(DateTime.now());

    // Use NumberFormat just once
    final formatter = NumberFormat('#,##0', 'es_CL');
    final formattedTotal = formatter.format(total);

    // Crear la página del PDF con formato para rollo de 58mm
    doc.addPage(
      pw.Page(
        pageFormat: PdfPageFormat(pdfWidth, double.infinity),
        build: (pw.Context context) {
          return pw.Column(
            mainAxisAlignment: pw.MainAxisAlignment.start,
            crossAxisAlignment: pw.CrossAxisAlignment.center,
            children: [
              // Use our optimized header component
              PdfTicketComponents.buildHeader(_optimizer.logo, comprobante),

              pw.SizedBox(height: 5),

              // Add reprint indicator if needed
              if (isReprint)
                PdfTicketComponents.buildReprintIndicator(),

              // Simplified title
              pw.Text('Oferta en Ruta',
                style: pw.TextStyle(fontSize: 12, fontWeight: pw.FontWeight.bold),
                textAlign: pw.TextAlign.center,
              ),
              pw.SizedBox(height: 5),

              // Simplified table using our components
              PdfTicketComponents.buildSimplifiedTable(offerEntries),

              pw.SizedBox(height: 5),

              // Total amount
              pw.Text('Total: \$$formattedTotal',
                style: pw.TextStyle(fontSize: 12, fontWeight: pw.FontWeight.bold),
                textAlign: pw.TextAlign.center,
              ),

              pw.SizedBox(height: 5),

              // Validity text
              pw.Text('Válido hora y fecha señalada',
                style: pw.TextStyle(fontSize: 9, fontWeight: pw.FontWeight.bold),
                textAlign: pw.TextAlign.center,
              ),

              pw.SizedBox(height: 3),

              // Date and time
              PdfTicketComponents.buildDateTimeFooter(currentDate, currentTime),

              // Add reprint date if needed
              if (isReprint) ...[
                pw.SizedBox(height: 5),
                pw.Text(
                  'Reimpreso: $currentDate $currentTime',
                  style: pw.TextStyle(fontSize: 8, fontStyle: pw.FontStyle.italic),
                  textAlign: pw.TextAlign.center,
                ),
              ],

              // Footer image
              pw.Image(_optimizer.endImage),
            ],
          );
        },
      ),
    );

    // Save and return the PDF
    return await doc.save();
  }
}