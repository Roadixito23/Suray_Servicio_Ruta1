import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/services.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

/// Singleton class to optimize PDF generation by caching resources
class PdfOptimizer {
  // Singleton pattern implementation
  static final PdfOptimizer _instance = PdfOptimizer._internal();
  factory PdfOptimizer() => _instance;
  PdfOptimizer._internal();

  // Cached resources
  pw.ImageProvider? _cachedLogo;
  pw.ImageProvider? _cachedEndImage;
  pw.ImageProvider? _cachedScissors;

  // Flag to track if resources have been loaded
  bool _resourcesLoaded = false;

  // Lightweight PDF configuration
  static const pdfConfig = {
    'compress': true,
    'version': PdfVersion.pdf_1_4,
  };

  /// Preload all common PDF resources
  Future<void> preloadResources() async {
    if (_resourcesLoaded) return;

    try {
      // Load logo image
      final ByteData logoData = await rootBundle.load('assets/logobkwt.png');
      _cachedLogo = pw.MemoryImage(logoData.buffer.asUint8List());

      // Load end ticket image
      final ByteData endData = await rootBundle.load('assets/endTicket.png');
      _cachedEndImage = pw.MemoryImage(endData.buffer.asUint8List());

      // Load scissors image
      final ByteData scissorsData = await rootBundle.load('assets/tijera.png');
      _cachedScissors = pw.MemoryImage(scissorsData.buffer.asUint8List());

      _resourcesLoaded = true;
    } catch (e) {
      print('Error preloading PDF resources: $e');
      throw Exception('Failed to preload PDF resources: $e');
    }
  }

  /// Create optimized PDF document
  pw.Document createDocument() {
    return pw.Document(
      compress: true,
      version: PdfVersion.pdf_1_4,
    );
  }

  /// Get cached logo
  pw.ImageProvider get logo {
    if (_cachedLogo == null) {
      throw Exception('Resources not preloaded. Call preloadResources() first.');
    }
    return _cachedLogo!;
  }

  /// Get cached end image
  pw.ImageProvider get endImage {
    if (_cachedEndImage == null) {
      throw Exception('Resources not preloaded. Call preloadResources() first.');
    }
    return _cachedEndImage!;
  }

  /// Get cached scissors image
  pw.ImageProvider get scissors {
    if (_cachedScissors == null) {
      throw Exception('Resources not preloaded. Call preloadResources() first.');
    }
    return _cachedScissors!;
  }

  /// Clear cached resources (call when low on memory)
  void clearCache() {
    _cachedLogo = null;
    _cachedEndImage = null;
    _cachedScissors = null;
    _resourcesLoaded = false;
  }
}

/// Optimized building blocks for PDF tickets
class PdfTicketComponents {
  /// Build optimized ticket header
  static pw.Widget buildHeader(pw.ImageProvider logo, String ticketId) {
    return pw.Row(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Container(width: 58 * PdfPageFormat.mm * 0.5, child: pw.Image(logo)),
        pw.Container(
          width: 58 * PdfPageFormat.mm * 0.5,
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

  /// Build reprint indicator
  static pw.Widget buildReprintIndicator() {
    return pw.Container(
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
    );
  }

  /// Build simple price display
  static pw.Widget buildPriceDisplay(String price) {
    return pw.Text(
      'Precio: \$$price',
      style: pw.TextStyle(fontSize: 14),
    );
  }

  /// Build date time footer
  static pw.Widget buildDateTimeFooter(String currentDate, String currentTime) {
    return pw.Row(
      mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
      children: [
        pw.Text(currentTime, style: pw.TextStyle(fontSize: 12)),
        pw.Text(currentDate, style: pw.TextStyle(fontSize: 12)),
      ],
    );
  }

  /// Build simplified table for multi-offer tickets
  static pw.Widget buildSimplifiedTable(List<Map<String, dynamic>> entries) {
    final rows = <pw.TableRow>[];

    // Add header with minimal styling
    rows.add(
      pw.TableRow(
        children: [
          pw.Padding(padding: const pw.EdgeInsets.all(2),
              child: pw.Text('Cant', style: pw.TextStyle(fontSize: 8), textAlign: pw.TextAlign.center)),
          pw.Padding(padding: const pw.EdgeInsets.all(2),
              child: pw.Text('Precio', style: pw.TextStyle(fontSize: 8), textAlign: pw.TextAlign.center)),
          pw.Padding(padding: const pw.EdgeInsets.all(2),
              child: pw.Text('Subtotal', style: pw.TextStyle(fontSize: 8), textAlign: pw.TextAlign.center)),
        ],
      ),
    );

    // Add data rows with minimal styling
    for (var entry in entries) {
      int quantity = int.tryParse(entry['number'] ?? '0') ?? 0;
      double price = double.tryParse(entry['value'] ?? '0.0') ?? 0.0;
      double subtotal = quantity * price;

      rows.add(
        pw.TableRow(
          children: [
            pw.Padding(padding: const pw.EdgeInsets.all(2),
                child: pw.Text('$quantity', style: pw.TextStyle(fontSize: 8), textAlign: pw.TextAlign.center)),
            pw.Padding(padding: const pw.EdgeInsets.all(2),
                child: pw.Text('\$${price.toInt()}', style: pw.TextStyle(fontSize: 8), textAlign: pw.TextAlign.right)),
            pw.Padding(padding: const pw.EdgeInsets.all(2),
                child: pw.Text('\$${subtotal.toInt()}', style: pw.TextStyle(fontSize: 8), textAlign: pw.TextAlign.right)),
          ],
        ),
      );
    }

    return pw.Table(
      border: pw.TableBorder.all(width: 0.5), // Thinner borders
      columnWidths: {
        0: pw.FlexColumnWidth(0.8),
        1: pw.FlexColumnWidth(1.2),
        2: pw.FlexColumnWidth(1.5),
      },
      children: rows,
    );
  }
}