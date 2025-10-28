import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:intl/intl.dart';
import 'package:flutter/services.dart';
import 'package:printing/printing.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/ComprobanteModel.dart';
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

  Future<void> preloadResources() async {
    await _ensureResourcesLoaded();
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
    final now = DateTime.now();
    String currentDate = DateFormat('dd/MM/yy').format(now);
    String currentTime = DateFormat('HH:mm:ss').format(now);

    // Use NumberFormat just once
    final formatter = NumberFormat('#,##0', 'es_CL');
    final formattedTotal = formatter.format(total);

    // Determinar el título según el día (domingo o lunes-sábado)
    final String tarifaTitulo = isSwitchOn
        ? 'TARIFA DOMINGO O FERIADO'
        : 'TARIFA LUNES A SÁBADO';

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
              PdfTicketComponents.buildHeader(_optimizer.getLogoImage(), comprobante),
              pw.SizedBox(height: 8),

              // Add reprint indicator if needed
              if (isReprint) ...[
                pw.Container(
                  padding: pw.EdgeInsets.symmetric(vertical: 2, horizontal: 5),
                  decoration: pw.BoxDecoration(
                    border: pw.Border.all(width: 1, color: PdfColors.black),
                    color: PdfColors.grey200,
                  ),
                  child: pw.Text(
                    'REIMPRESIÓN',
                    style: pw.TextStyle(
                      fontSize: 10,
                      fontWeight: pw.FontWeight.bold,
                      fontStyle: pw.FontStyle.italic,
                    ),
                  ),
                ),
                pw.SizedBox(height: 8),
              ],

              // Título de tarifa en negrita
              pw.Text(
                tarifaTitulo,
                style: pw.TextStyle(
                  fontSize: 13,
                  fontWeight: pw.FontWeight.bold,
                ),
                textAlign: pw.TextAlign.center,
              ),
              pw.SizedBox(height: 6),

              // Subtitle "Oferta en Ruta"
              pw.Text(
                'Oferta en Ruta',
                style: pw.TextStyle(fontSize: 11),
                textAlign: pw.TextAlign.center,
              ),
              pw.SizedBox(height: 8),

              // Tabla con cantidad, precio unitario y subtotal
              pw.Table(
                border: pw.TableBorder.all(color: PdfColors.black, width: 0.5),
                columnWidths: {
                  0: pw.FlexColumnWidth(2),
                  1: pw.FlexColumnWidth(2),
                  2: pw.FlexColumnWidth(2),
                },
                children: [
                  // Encabezado de tabla
                  pw.TableRow(
                    decoration: pw.BoxDecoration(color: PdfColors.grey300),
                    children: [
                      pw.Padding(
                        padding: pw.EdgeInsets.all(3),
                        child: pw.Text(
                          'Cantidad',
                          style: pw.TextStyle(fontSize: 9, fontWeight: pw.FontWeight.bold),
                          textAlign: pw.TextAlign.center,
                        ),
                      ),
                      pw.Padding(
                        padding: pw.EdgeInsets.all(3),
                        child: pw.Text(
                          'Precio',
                          style: pw.TextStyle(fontSize: 9, fontWeight: pw.FontWeight.bold),
                          textAlign: pw.TextAlign.center,
                        ),
                      ),
                      pw.Padding(
                        padding: pw.EdgeInsets.all(3),
                        child: pw.Text(
                          'Subtotal',
                          style: pw.TextStyle(fontSize: 9, fontWeight: pw.FontWeight.bold),
                          textAlign: pw.TextAlign.center,
                        ),
                      ),
                    ],
                  ),
                  // Filas de datos
                  ...List.generate(offerEntries.length, (index) {
                    final entry = offerEntries[index];
                    int quantity = int.tryParse(entry['number'] ?? '0') ?? 0;
                    double price = double.tryParse(entry['value'] ?? '0.0') ?? 0.0;
                    double subtotal = subtotals[index];

                    return pw.TableRow(
                      children: [
                        pw.Padding(
                          padding: pw.EdgeInsets.all(3),
                          child: pw.Text(
                            '$quantity',
                            style: pw.TextStyle(fontSize: 9),
                            textAlign: pw.TextAlign.center,
                          ),
                        ),
                        pw.Padding(
                          padding: pw.EdgeInsets.all(3),
                          child: pw.Text(
                            '\$${formatter.format(price)}',
                            style: pw.TextStyle(fontSize: 9),
                            textAlign: pw.TextAlign.center,
                          ),
                        ),
                        pw.Padding(
                          padding: pw.EdgeInsets.all(3),
                          child: pw.Text(
                            '\$${formatter.format(subtotal)}',
                            style: pw.TextStyle(fontSize: 9),
                            textAlign: pw.TextAlign.center,
                          ),
                        ),
                      ],
                    );
                  }),
                ],
              ),

              pw.SizedBox(height: 8),

              // Total amount in bold
              pw.Text(
                'Total: \$$formattedTotal',
                style: pw.TextStyle(fontSize: 14, fontWeight: pw.FontWeight.bold),
                textAlign: pw.TextAlign.center,
              ),

              pw.SizedBox(height: 10),

              // Validity text in bold
              pw.Text(
                'Válido hora y fecha señalada',
                style: pw.TextStyle(fontSize: 9, fontWeight: pw.FontWeight.bold),
                textAlign: pw.TextAlign.center,
              ),

              pw.SizedBox(height: 5),

              // Fila con hora a la izquierda y fecha a la derecha
              pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Text(
                    currentTime,
                    style: pw.TextStyle(fontSize: 9),
                  ),
                  pw.Text(
                    currentDate,
                    style: pw.TextStyle(fontSize: 9),
                  ),
                ],
              ),

              pw.SizedBox(height: 10),

              // Footer image centrado
              pw.Image(
                _optimizer.getEndImage(),
                width: 180,
              ),
            ],
          );
        },
      ),
    );

    // Save and return the PDF
    return await doc.save();
  }
}