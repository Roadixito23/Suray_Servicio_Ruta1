import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/ComprobanteModel.dart';
import 'ReporteCaja.dart';
import 'pdf_optimizer.dart';

class GenerateTicket {
  final ComprobanteModel comprobanteModel;
  final ReporteCaja reporteCaja;
  final PdfOptimizer _optimizer = PdfOptimizer();
  bool _resourcesLoaded = false;

  GenerateTicket(this.comprobanteModel, this.reporteCaja);

  /// Precarga recursos del optimizador
  Future<void> preloadResources() async {
    if (_resourcesLoaded) return;
    try {
      await _optimizer.preloadResources();
      _resourcesLoaded = true;
    } catch (e) {
      print('GenerateTicket: Error preloading resources: $e');
      _resourcesLoaded = false;
    }
  }

  /// Genera e imprime el ticket PDF
  Future<void> generateTicketPdf(
      String tipo,
      double valor,
      bool isSunday,
      bool isReprint,
      ) async {
    if (!_resourcesLoaded) {
      await preloadResources();
    }

    final now = DateTime.now();
    final priceFmt = NumberFormat('#,##0', 'es_CL');
    final formatted = priceFmt.format(valor);

    final doc = _optimizer.createDocument();

    // Solo incrementa el comprobante si no es reimpresión
    if (!isReprint) {
      await comprobanteModel.incrementComprobante();
    }

    final ticketId = comprobanteModel.formattedComprobante;

    // Determinar el título según el día
    final String tarifaTitulo = isSunday
        ? 'TARIFA DOMINGO O FERIADO'
        : 'TARIFA LUNES A SÁBADO';

    doc.addPage(
      pw.Page(
        pageFormat: PdfPageFormat(58 * PdfPageFormat.mm, double.infinity),
        build: (pw.Context context) {
          return pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.center,
            children: [
              // Logo y encabezado
              PdfTicketComponents.buildHeader(_optimizer.getLogoImage(), ticketId),
              pw.SizedBox(height: 8),

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
              if (isReprint) pw.SizedBox(height: 8),

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

              // Tipo de tarifa (Escolar o Público General)
              pw.Text(
                tipo,
                style: pw.TextStyle(fontSize: 11),
                textAlign: pw.TextAlign.center,
              ),
              pw.SizedBox(height: 8),

              // Precio formateado
              pw.Text(
                'Precio: \$$formatted',
                style: pw.TextStyle(
                  fontSize: 14,
                  fontWeight: pw.FontWeight.bold,
                ),
                textAlign: pw.TextAlign.center,
              ),
              pw.SizedBox(height: 10),

              // "Válido hora y fecha señalada" en negrita
              pw.Text(
                'Válido hora y fecha señalada',
                style: pw.TextStyle(
                  fontSize: 9,
                  fontWeight: pw.FontWeight.bold,
                ),
                textAlign: pw.TextAlign.center,
              ),
              pw.SizedBox(height: 5),

              // Fila con hora a la izquierda y fecha a la derecha
              pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Text(
                    DateFormat('HH:mm:ss').format(now),
                    style: pw.TextStyle(fontSize: 9),
                  ),
                  pw.Text(
                    DateFormat('dd/MM/yy').format(now),
                    style: pw.TextStyle(fontSize: 9),
                  ),
                ],
              ),
              pw.SizedBox(height: 10),

              // Footer centrado
              pw.Image(
                _optimizer.getEndImage(),
                width: 180,
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

    // Registrar en caja solo si no es reimpresión
    if (!isReprint) {
      reporteCaja.receiveData(tipo, valor, ticketId);
    }

    // Guardar último ID de ticket
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('lastTicketId', ticketId);
  }
}