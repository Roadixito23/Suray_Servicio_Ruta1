import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:intl/intl.dart';
import 'package:flutter/services.dart';
import 'package:printing/printing.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'ComprobanteModel.dart'; // Asegúrate de importar tu modelo

class MoTicketGenerator {
  Future<void> generateMoTicket(
      PdfPageFormat format,
      List<Map<String, dynamic>> offerEntries,
      bool isSwitchOn,
      BuildContext context,
      Function(String, double, List<double>, String) onGenerateComplete) async {
    final comprobanteModel = Provider.of<ComprobanteModel>(context, listen: false);

    // Incrementar y obtener el número de comprobante antes de crear el PDF
    await comprobanteModel.incrementComprobante();
    String comprobante = comprobanteModel.formattedComprobante;

    // Calcular subtotales y total
    double total = 0.0;
    List<double> subtotals = [];

    for (var entry in offerEntries) {
      int quantity = int.tryParse(entry['number'] ?? '0') ?? 0;
      double price = double.tryParse(entry['value'] ?? '0.0') ?? 0.0;
      double subtotal = quantity * price;

      total += subtotal;
      subtotals.add(subtotal);
    }

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

    // Llamar al callback con el nombre del pasaje, el valor total, los subtotales y el número de comprobante
    onGenerateComplete('Oferta Ruta', total, subtotals, comprobante);
  }

  // Método de reimpresión mejorado
  Future<void> reprintMoTicket(
      PdfPageFormat format,
      List<Map<String, dynamic>> offerEntries,
      bool isSwitchOn,
      BuildContext context,
      String comprobante) async {
    try {
      // Calcular subtotales y total
      double total = 0.0;
      List<double> subtotals = [];

      for (var entry in offerEntries) {
        int quantity = int.tryParse(entry['number'] ?? '0') ?? 0;
        double price = double.tryParse(entry['value'] ?? '0.0') ?? 0.0;
        double subtotal = quantity * price;

        total += subtotal;
        subtotals.add(subtotal);
      }

      // Crear el PDF para reimpresión
      final Uint8List pdfData = await _generateTicketPdf(
          offerEntries,
          comprobante,
          isSwitchOn,
          true, // Es reimpresión
          subtotals,
          total
      );

      // Imprimir el PDF
      await Printing.layoutPdf(
        onLayout: (PdfPageFormat format) async => pdfData,
        format: PdfPageFormat(58 * PdfPageFormat.mm, double.infinity), // Usar formato de 58mm
      );
    } catch (e) {
      print('Error en reprintMoTicket: $e');
      throw e; // Re-lanzar el error para manejarlo en la capa superior
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
    final doc = pw.Document();
    final pdfWidth = 58 * PdfPageFormat.mm;

    // Cargar imágenes
    final logoImage = await _loadImage('assets/logobkwt.png'); // Cambio: usar logo en lugar de headImage
    final endImage = await _loadImage('assets/endTicket.png');

    // Obtener la fecha y hora actual
    String currentDate = DateFormat('dd/MM/yyyy').format(DateTime.now());
    String currentTime = DateFormat('HH:mm:ss').format(DateTime.now());

    // Crear la página del PDF con formato para rollo de 58mm
    doc.addPage(
      pw.Page(
        pageFormat: PdfPageFormat(pdfWidth, double.infinity),
        build: (pw.Context context) {
          return pw.Column(
            mainAxisAlignment: pw.MainAxisAlignment.start,
            crossAxisAlignment: pw.CrossAxisAlignment.center,
            children: [
              // Nueva cabecera personalizada
              pw.Row(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  // Lado izquierdo - Logo
                  pw.Container(
                    width: pdfWidth * 0.5,
                    child: pw.Image(logoImage),
                  ),
                  // Lado derecho - Cuadro con borde (sin fondo)
                  pw.Container(
                    width: 85,
                    height: 40, // Hacer cuadrado, ajustar según sea necesario
                    padding: pw.EdgeInsets.all(5),
                    decoration: pw.BoxDecoration(
                      border: pw.Border.all(width: 1.5), // Solo borde, sin fondo
                      borderRadius: pw.BorderRadius.circular(2),
                    ),
                    child: pw.Column(
                      mainAxisAlignment: pw.MainAxisAlignment.center, // Centrar verticalmente
                      crossAxisAlignment: pw.CrossAxisAlignment.center,
                      children: [
                        pw.Text(
                          'COMPROBANTE DE',
                          style: pw.TextStyle(
                            fontSize: 6,
                            fontWeight: pw.FontWeight.bold,
                          ),
                          textAlign: pw.TextAlign.center,
                        ),
                        pw.Text(
                          'PAGO EN BUS',
                          style: pw.TextStyle(
                            fontSize: 6,
                            fontWeight: pw.FontWeight.bold,
                          ),
                          textAlign: pw.TextAlign.center,
                        ),
                        pw.SizedBox(height: 3),
                        pw.Text(
                          'N° $comprobante',
                          style: pw.TextStyle(
                            fontSize: 8,
                            fontWeight: pw.FontWeight.bold,
                          ),
                          textAlign: pw.TextAlign.center,
                        ),
                      ],
                    ),
                  ),
                ],
              ),

              pw.SizedBox(height: 5),

              // Si es reimpresión, añadir recuadro indicativo
              if (isReprint)
                pw.Container(
                  decoration: pw.BoxDecoration(
                    border: pw.Border.all(),
                    color: PdfColors.grey200,
                  ),
                  padding: pw.EdgeInsets.all(2),
                  margin: pw.EdgeInsets.only(bottom: 5),
                  child: pw.Text(
                    'REIMPRESIÓN',
                    style: pw.TextStyle(
                        fontSize: 10,
                        fontWeight: pw.FontWeight.bold,
                        color: PdfColors.red
                    ),
                    textAlign: pw.TextAlign.center,
                  ),
                ),

              // Título de Oferta en Ruta (ahora debajo del comprobante)
              pw.Text('Oferta en Ruta',
                style: pw.TextStyle(fontSize: 12, fontWeight: pw.FontWeight.bold),
                textAlign: pw.TextAlign.center,
              ),
              pw.SizedBox(height: 5),

              // Tabla para mostrar subtotales (adaptada para ancho de 58mm)
              pw.Table(
                border: pw.TableBorder.all(),
                columnWidths: {
                  0: pw.FlexColumnWidth(0.8),  // Columna cantidad más pequeña
                  1: pw.FlexColumnWidth(1.2),  // Columna precio
                  2: pw.FlexColumnWidth(1.5),  // Columna subtotal
                },
                children: [
                  pw.TableRow(
                    children: [
                      pw.Padding(padding: const pw.EdgeInsets.all(2), child: pw.Text('Cant', style: pw.TextStyle(fontSize: 8), textAlign: pw.TextAlign.center)),
                      pw.Padding(padding: const pw.EdgeInsets.all(2), child: pw.Text('Precio', style: pw.TextStyle(fontSize: 8), textAlign: pw.TextAlign.center)),
                      pw.Padding(padding: const pw.EdgeInsets.all(2), child: pw.Text('Subtotal', style: pw.TextStyle(fontSize: 8), textAlign: pw.TextAlign.center)),
                    ],
                  ),
                  ...offerEntries.map((entry) {
                    int quantity = int.tryParse(entry['number'] ?? '0') ?? 0;
                    double price = double.tryParse(entry['value'] ?? '0.0') ?? 0.0;
                    double subtotal = quantity * price;

                    return pw.TableRow(
                      children: [
                        pw.Padding(padding: const pw.EdgeInsets.all(2), child: pw.Text(quantity.toString(), style: pw.TextStyle(fontSize: 8), textAlign: pw.TextAlign.center)),
                        pw.Padding(padding: const pw.EdgeInsets.all(2), child: pw.Text('\$${NumberFormat('#,##0', 'es_CL').format(price)}', style: pw.TextStyle(fontSize: 8), textAlign: pw.TextAlign.right)),
                        pw.Padding(padding: const pw.EdgeInsets.all(2), child: pw.Text('\$${NumberFormat('#,##0', 'es_CL').format(subtotal)}', style: pw.TextStyle(fontSize: 8), textAlign: pw.TextAlign.right)),
                      ],
                    );
                  }).toList(),
                ],
              ),

              pw.SizedBox(height: 5),
              pw.Text('Total: \$${NumberFormat('#,##0', 'es_CL').format(total)}',
                style: pw.TextStyle(fontSize: 12, fontWeight: pw.FontWeight.bold),
                textAlign: pw.TextAlign.center,
              ),
              pw.SizedBox(height: 5),
              pw.Text('Válido hora y fecha señalada',
                style: pw.TextStyle(fontSize: 9, fontWeight: pw.FontWeight.bold),
                textAlign: pw.TextAlign.center,
              ),
              pw.SizedBox(height: 3),

              // Mostrar fecha y hora en la misma línea con separación
              pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.center,
                children: [
                  pw.Text('$currentTime', style: pw.TextStyle(fontSize: 12)),
                  pw.SizedBox(width: 30), // Separación en medio
                  pw.Text('$currentDate', style: pw.TextStyle(fontSize: 12)),
                ],
              ),

              // Si es reimpresión, añadir fecha de reimpresión
              if (isReprint) ...[
                pw.SizedBox(height: 5),
                pw.Text(
                  'Reimpreso: ${DateFormat('dd/MM/yyyy HH:mm:ss').format(DateTime.now())}',
                  style: pw.TextStyle(fontSize: 8, fontStyle: pw.FontStyle.italic),
                  textAlign: pw.TextAlign.center,
                ),
              ],

              pw.Image(endImage),
            ],
          );
        },
      ),
    );

    // Guardar y devolver el PDF
    return await doc.save();
  }

  Future<pw.ImageProvider> _loadImage(String path) async {
    final ByteData bytes = await rootBundle.load(path);
    return pw.MemoryImage(bytes.buffer.asUint8List());
  }
}