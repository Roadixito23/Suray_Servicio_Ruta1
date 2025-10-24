import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/ComprobanteModel.dart';
import 'pdf_optimizer.dart';
import 'pdf_resource_manager.dart';

class GenerateTicket {
  final PdfOptimizer optimizer = PdfOptimizer();
  final PdfResourceManager resourceManager = PdfResourceManager();
  bool resourcesPreloaded = false;
  final Map<String, Uint8List> _cachedAssets = {};

  /// Precarga logo, headTicket y footer desde PdfResourceManager
  Future<void> preloadResources() async {
    if (resourcesPreloaded) return;
    try {
      await resourceManager.initialize();
      await optimizer.preloadResources();

      _cachedAssets['logo']      = resourceManager.getAsset('assets/logobkwt.png');
      _cachedAssets['headTicket'] = resourceManager.getAsset('assets/headTicket.png');
      _cachedAssets['endTicket'] = resourceManager.getAsset('assets/endTicket.png');

      resourcesPreloaded = true;
    } catch (e) {
      print('GenerateTicket: Error preloading resources: $e');
      resourcesPreloaded = false;
    }
  }

  /// Genera e imprime el ticket PDF
  Future<void> generateTicketPdf(
      BuildContext context,
      double valor,
      bool isSunday,
      String tipo,
      String owner,
      String contactInfo,
      String item,
      ComprobanteModel comprobanteModel,
      bool isReprint,
      ) async {
    if (!resourcesPreloaded) {
      await preloadResources();
    }

    final now = DateTime.now();
    final priceFmt = NumberFormat('#,###', 'es_CL');
    final formatted = priceFmt.format(valor);

    final doc = optimizer.createDocument();

    // Solo incrementa el comprobante si no es reimpresión
    if (!isReprint) {
      await comprobanteModel.incrementComprobante();
    }

    final ticketId = comprobanteModel.formattedComprobante;

    doc.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.roll80,
        build: (pw.Context context) {
          return pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.center,
            children: [
              // Logo
              pw.Image(
                pw.MemoryImage(_cachedAssets['logo']!),
                width: 100,
                height: 80,
              ),
              pw.SizedBox(height: 10),

              // Indicador de reimpresión si aplica
              if (isReprint)
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

              // Tipo de ticket y título
              pw.Text(
                tipo,
                style: pw.TextStyle(fontSize: 16, fontWeight: pw.FontWeight.bold),
                textAlign: pw.TextAlign.center,
              ),
              pw.SizedBox(height: 5),

              // Valor
              pw.Container(
                padding: pw.EdgeInsets.symmetric(vertical: 5, horizontal: 10),
                decoration: pw.BoxDecoration(border: pw.Border.all(width: 1)),
                child: pw.Text(
                  '\$${formatted}',
                  style: pw.TextStyle(fontSize: 20, fontWeight: pw.FontWeight.bold),
                  textAlign: pw.TextAlign.center,
                ),
              ),
              pw.SizedBox(height: 5),

              // Cliente y contacto
              pw.Text('Cliente: $owner', style: pw.TextStyle(fontSize: 12)),
              pw.SizedBox(height: 5),
              pw.Text('Contacto: $contactInfo', style: pw.TextStyle(fontSize: 12)),
              pw.SizedBox(height: 5),

              // Artículo
              pw.Text('Artículo: $item', style: pw.TextStyle(fontSize: 12)),
              pw.SizedBox(height: 10),

              // Número de ticket
              pw.Text(
                'Ticket N° $ticketId',
                style: pw.TextStyle(fontSize: 12, fontWeight: pw.FontWeight.bold),
              ),
              pw.SizedBox(height: 5),

              // Fecha y hora
              pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.center,
                children: [
                  pw.Text(
                    'Fecha: ${DateFormat('dd/MM/yyyy').format(now)}',
                    style: pw.TextStyle(fontSize: 8),
                  ),
                  pw.SizedBox(width: 10),
                  pw.Text(
                    'Hora: ${DateFormat('HH:mm:ss').format(now)}',
                    style: pw.TextStyle(fontSize: 8),
                  ),
                ],
              ),
              pw.SizedBox(height: 10),

              // Footer
              pw.Image(
                pw.MemoryImage(_cachedAssets['endTicket']!),
                width: 200,
              ),
            ],
          );
        },
      ),
    );

    // Enviar a impresión
    await Printing.layoutPdf(
      onLayout: (PdfPageFormat _) async => doc.save(),
    );

    // Guardar último ID de ticket (opcional)
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('lastTicketId', ticketId);
  }
}