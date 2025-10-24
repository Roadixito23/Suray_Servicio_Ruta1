// lib/pdf_optimizer.dart

import 'dart:typed_data';
import 'package:flutter/services.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:intl/intl.dart';

/// Clase que precarga y gestiona imágenes para generación de PDFs,
/// y ofrece componentes comunes para los tickets.
class PdfOptimizer {
  // Imágenes en memoria
  late pw.MemoryImage _logo;
  late pw.MemoryImage _endImage;
  late pw.MemoryImage _tijera;

  bool _resourcesLoaded = false;

  /// Precarga todas las imágenes necesarias desde assets.
  /// Llama a este método antes de generar cualquier PDF.
  Future<void> preloadResources() async {
    if (_resourcesLoaded) return;
    try {
      // Logo principal
      final ByteData logoData = await rootBundle.load('assets/logobkwt.png');
      _logo = pw.MemoryImage(logoData.buffer.asUint8List());

      // Imagen de pie de página
      final ByteData endData = await rootBundle.load('assets/endTicket.png');
      _endImage = pw.MemoryImage(endData.buffer.asUint8List());

      // Imagen de tijera para control interno
      final ByteData tijeraData = await rootBundle.load('assets/tijera.png');
      _tijera = pw.MemoryImage(tijeraData.buffer.asUint8List());

      _resourcesLoaded = true;
    } catch (e) {
      throw Exception('Error cargando recursos PDF: $e');
    }
  }

  /// Devuelve la imagen del logo precargada.
  pw.MemoryImage getLogoImage() {
    if (!_resourcesLoaded) {
      throw Exception('Recursos no precargados. Llama a preloadResources() primero.');
    }
    return _logo;
  }

  /// Devuelve la imagen de pie de página precargada.
  pw.MemoryImage getEndImage() {
    if (!_resourcesLoaded) {
      throw Exception('Recursos no precargados. Llama a preloadResources() primero.');
    }
    return _endImage;
  }

  /// Devuelve la imagen de tijera precargada.
  pw.MemoryImage getScissorsImage() {
    if (!_resourcesLoaded) {
      throw Exception('Recursos no precargados. Llama a preloadResources() primero.');
    }
    return _tijera;
  }

  /// Alias en español de getScissorsImage().
  pw.MemoryImage getTijeraImage() => getScissorsImage();

  /// Crea un nuevo documento PDF optimizado (comprimido, versión 1.4).
  pw.Document createDocument() {
    return pw.Document(
      compress: true,
      version: PdfVersion.pdf_1_4,
    );
  }

  /// Limpia el estado de recursos para permitir recarga si es necesario.
  void clearCache() {
    _resourcesLoaded = false;
  }
}

/// Componentes reutilizables para generar el contenido de los tickets PDF.
class PdfTicketComponents {
  /// Cabecera con logo y número de comprobante.
  static pw.Widget buildHeader(pw.MemoryImage logoImage, String ticketId) {
    return pw.Row(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        // Logo a la izquierda
        pw.Container(
          width: 100,
          child: pw.Image(logoImage),
        ),
        // Espacio flexible
        pw.Spacer(),
        // Caja de comprobante
        pw.Container(
          width: 80,
          padding: pw.EdgeInsets.all(4),
          decoration: pw.BoxDecoration(border: pw.Border.all(width: 1.5)),
          child: pw.Column(
            mainAxisAlignment: pw.MainAxisAlignment.center,
            crossAxisAlignment: pw.CrossAxisAlignment.center,
            children: [
              pw.Text(
                'COMPROBANTE DE',
                style: pw.TextStyle(fontSize: 8, fontWeight: pw.FontWeight.bold),
                textAlign: pw.TextAlign.center,
              ),
              pw.Text(
                'PAGO EN BUS',
                style: pw.TextStyle(fontSize: 8, fontWeight: pw.FontWeight.bold),
                textAlign: pw.TextAlign.center,
              ),
              pw.SizedBox(height: 3),
              pw.Text(
                'N° $ticketId',
                style: pw.TextStyle(fontSize: 9, fontWeight: pw.FontWeight.bold),
                textAlign: pw.TextAlign.center,
              ),
            ],
          ),
        ),
      ],
    );
  }

  /// Indicador de reimpresión.
  static pw.Widget buildReprintIndicator() {
    return pw.Container(
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
    );
  }

  /// Genera una tabla simple con descripción, cantidad y precio unitario.
  static pw.Widget buildSimplifiedTable(List<Map<String, dynamic>> offerEntries) {
    final headers = ['Descripción', 'Cant.', 'Precio Unit.'];
    final rows = <List<String>>[];
    final formatter = NumberFormat('#,##0', 'es_CL');

    for (var e in offerEntries) {
      final desc = e['description']?.toString() ?? '';
      final qty = int.tryParse(e['number']?.toString() ?? '') ?? 0;
      final price = double.tryParse(e['value']?.toString() ?? '') ?? 0.0;
      rows.add([desc, qty.toString(), '\$${formatter.format(price)}']);
    }

    return pw.Table(
      border: pw.TableBorder.all(width: 0.5),
      columnWidths: {
        0: pw.FlexColumnWidth(2), // Descripción más ancha
        1: pw.FlexColumnWidth(1),
        2: pw.FlexColumnWidth(1),
      },
      children: [
        // Encabezados
        pw.TableRow(
          decoration: pw.BoxDecoration(color: PdfColors.grey200),
          children: headers.map((h) {
            return pw.Padding(
              padding: pw.EdgeInsets.all(3),
              child: pw.Text(
                h,
                style: pw.TextStyle(fontSize: 8, fontWeight: pw.FontWeight.bold),
                textAlign: pw.TextAlign.center,
              ),
            );
          }).toList(),
        ),
        // Filas de datos
        for (var cells in rows)
          pw.TableRow(
            children: cells.asMap().entries.map((entry) {
              final idx = entry.key;
              return pw.Padding(
                padding: pw.EdgeInsets.all(3),
                child: pw.Text(
                  entry.value,
                  style: pw.TextStyle(fontSize: 8),
                  textAlign:
                  (idx == 0) ? pw.TextAlign.left : pw.TextAlign.center,
                ),
              );
            }).toList(),
          ),
      ],
    );
  }

  /// Muestra el precio total en un recuadro centrado.
  static pw.Widget buildPriceDisplay(String formattedPrice) {
    return pw.Container(
      padding: pw.EdgeInsets.symmetric(vertical: 5, horizontal: 10),
      decoration: pw.BoxDecoration(border: pw.Border.all(width: 1)),
      child: pw.Text(
        '\$$formattedPrice',
        style: pw.TextStyle(fontSize: 20, fontWeight: pw.FontWeight.bold),
        textAlign: pw.TextAlign.center,
      ),
    );
  }

  /// Pie de página con fecha y hora.
  static pw.Widget buildDateTimeFooter(String date, String time) {
    return pw.Row(
      mainAxisAlignment: pw.MainAxisAlignment.center,
      children: [
        pw.Text('Fecha: $date', style: pw.TextStyle(fontSize: 8)),
        pw.SizedBox(width: 10),
        pw.Text('Hora: $time', style: pw.TextStyle(fontSize: 8)),
      ],
    );
  }
}
