import 'dart:typed_data';
import 'package:flutter/services.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:intl/intl.dart';
import 'package:printing/printing.dart';
import 'ComprobanteModel.dart';
import 'ReporteCaja.dart';
import 'pdf_optimizer.dart'; // Import the optimizer

class CargoTicketGenerator {
  final ComprobanteModel comprobanteModel;
  final ReporteCaja reporteCaja;
  final _priceFmt = NumberFormat('#,##0', 'es_CL');
  final _pdfWidth = 58 * PdfPageFormat.mm;
  final _pdfHeight = PdfPageFormat.a4.height;

  // Use our new optimizer
  final PdfOptimizer _optimizer = PdfOptimizer();
  bool _resourcesLoaded = false;

  CargoTicketGenerator(this.comprobanteModel, this.reporteCaja);

  // Preload resources method to be called at initialization
  Future<void> preloadResources() async {
    if (!_resourcesLoaded) {
      await _optimizer.preloadResources();
      _resourcesLoaded = true;
    }
  }

  pw.Document _createDoc() => _optimizer.createDocument(); // Use optimized document

  pw.Page _createPage(pw.Widget content) => pw.Page(
    pageFormat: PdfPageFormat(_pdfWidth, _pdfHeight),
    build: (_) => content,
  );

  // Simplified header builder
  pw.Widget _buildHeader(String ticketId) {
    return PdfTicketComponents.buildHeader(_optimizer.logo, ticketId);
  }

  // Simplified content builder
  pw.Widget _buildContent(
      String destinatario,
      String articulo,
      double precio,
      String destino,
      String telefonoDest,
      String fecha,
      String hora,
      ) {
    // Simplified layout with fewer elements
    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.stretch,
      children: [
        pw.Container(
          decoration: pw.BoxDecoration(border: pw.Border.all()),
          padding: pw.EdgeInsets.all(6),
          child: pw.Row(
            children: [
              pw.Text('Destino:', style: pw.TextStyle(fontSize: 10)),
              pw.SizedBox(width: 4),
              pw.Text(
                destino,
                style: pw.TextStyle(fontSize: 12, fontWeight: pw.FontWeight.bold),
              ),
            ],
          ),
        ),
        pw.SizedBox(height: 6),
        pw.Container(
          decoration: pw.BoxDecoration(border: pw.Border.all()),
          padding: pw.EdgeInsets.all(6),
          child: pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Text('Artículo:', style: pw.TextStyle(fontSize: 10)),
              pw.Text(
                articulo,
                style: pw.TextStyle(fontSize: 12, fontWeight: pw.FontWeight.bold),
              ),
            ],
          ),
        ),
        pw.SizedBox(height: 6),
        pw.Container(
          decoration: pw.BoxDecoration(border: pw.Border.all()),
          padding: pw.EdgeInsets.all(6),
          child: pw.Row(
            children: [
              pw.Text('Precio:', style: pw.TextStyle(fontSize: 10)),
              pw.SizedBox(width: 4),
              pw.Text(
                '\$${_priceFmt.format(precio)}',
                style: pw.TextStyle(fontSize: 12, fontWeight: pw.FontWeight.bold),
              ),
            ],
          ),
        ),
        pw.SizedBox(height: 6),
        pw.Container(
          decoration: pw.BoxDecoration(border: pw.Border.all()),
          padding: pw.EdgeInsets.all(6),
          child: pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Text('Destinatario:', style: pw.TextStyle(fontSize: 10)),
              pw.Text(
                destinatario,
                style: pw.TextStyle(fontSize: 12, fontWeight: pw.FontWeight.bold),
              ),
            ],
          ),
        ),
        if (telefonoDest.isNotEmpty) pw.SizedBox(height: 6),
        if (telefonoDest.isNotEmpty)
          pw.Container(
            decoration: pw.BoxDecoration(border: pw.Border.all()),
            padding: pw.EdgeInsets.all(6),
            child: pw.Row(
              children: [
                pw.Text('Teléfono:', style: pw.TextStyle(fontSize: 10)),
                pw.SizedBox(width: 4),
                pw.Text(
                  telefonoDest,
                  style: pw.TextStyle(fontSize: 12, fontWeight: pw.FontWeight.bold),
                ),
              ],
            ),
          ),
        pw.SizedBox(height: 6),
        pw.Row(
          mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
          children: [
            pw.Text('Fecha: $fecha', style: pw.TextStyle(fontSize: 8)),
            pw.Text('Hora:  $hora', style: pw.TextStyle(fontSize: 8)),
          ],
        ),
      ],
    );
  }

  // Simplified control interno box
  pw.Widget _buildControlInternoBox(
      String ticketId,
      String articulo,
      double precio,
      String fechaDespacho,
      ) {
    return pw.Container(
      padding: pw.EdgeInsets.all(6),
      decoration: pw.BoxDecoration(border: pw.Border.all()),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Text(
            'N° $ticketId',
            style: pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold),
          ),
          pw.SizedBox(height: 6),
          pw.Text('Nombre: __________________________', style: pw.TextStyle(fontSize: 10)),
          pw.SizedBox(height: 4),
          pw.Text('RUT: ____________________________', style: pw.TextStyle(fontSize: 10)),
          pw.SizedBox(height: 4),
          pw.Text('Firma: ___________________________', style: pw.TextStyle(fontSize: 10)),
          pw.SizedBox(height: 6),
          pw.Text('Artículo: $articulo', style: pw.TextStyle(fontSize: 10)),
          pw.SizedBox(height: 4),
          pw.Text('Valor: \$${_priceFmt.format(precio)}', style: pw.TextStyle(fontSize: 10)),
          pw.SizedBox(height: 4),
          pw.Text('Fecha despacho: $fechaDespacho', style: pw.TextStyle(fontSize: 10)),
        ],
      ),
    );
  }

  // Optimized method to generate and print cargo PDFs
  Future<void> generateNewCargoPdf(
      String destinatario,
      String articulo,
      double precio,
      String destino,
      String telefonoDest,
      ) async {
    // Ensure resources are preloaded
    await preloadResources();

    // Increment comprobante
    await comprobanteModel.incrementComprobante();
    final ticketId = comprobanteModel.formattedComprobante;

    // Get current date and time
    final date = DateFormat('dd/MM/yyyy').format(DateTime.now());
    final time = DateFormat('HH:mm:ss').format(DateTime.now());

    try {
      // COPIA CLIENTE
      final clientPdf = await _generateClientPdf(
          ticketId,
          destinatario,
          articulo,
          precio,
          destino,
          telefonoDest,
          date,
          time
      );

      // Print client copy
      await Printing.layoutPdf(onLayout: (_) => clientPdf);

      // COPIA CARGA
      final cargaPdf = await _generateCargaPdf(
          ticketId,
          destinatario,
          articulo,
          precio,
          destino,
          telefonoDest,
          date,
          time
      );

      // Print cargo copy
      await Printing.layoutPdf(onLayout: (_) => cargaPdf);

      // Add transaction to report
      reporteCaja.receiveCargoData(destinatario, precio, ticketId);
    } catch (e) {
      print('Error generating cargo PDF: $e');
      // Clear resources in case of error
      _optimizer.clearCache();
      throw e;
    }
  }

  // Generate client PDF (optimized)
  Future<Uint8List> _generateClientPdf(
      String ticketId,
      String destinatario,
      String articulo,
      double precio,
      String destino,
      String telefonoDest,
      String date,
      String time
      ) async {
    final doc = _createDoc();

    doc.addPage(
      _createPage(
        pw.Column(
          children: [
            _buildHeader(ticketId),
            pw.SizedBox(height: 4),
            pw.Center(
              child: pw.Text(
                'COPIA CLIENTE',
                style: pw.TextStyle(fontSize: 8, fontWeight: pw.FontWeight.bold),
              ),
            ),
            pw.SizedBox(height: 8),
            _buildContent(
              destinatario,
              articulo,
              precio,
              destino,
              telefonoDest,
              date,
              time,
            ),
            pw.SizedBox(height: 6),
            pw.Center(child: pw.Image(_optimizer.endImage, width: _pdfWidth * 0.8)),
          ],
        ),
      ),
    );

    return await doc.save();
  }

  // Generate cargo PDF (optimized)
  Future<Uint8List> _generateCargaPdf(
      String ticketId,
      String destinatario,
      String articulo,
      double precio,
      String destino,
      String telefonoDest,
      String date,
      String time
      ) async {
    final doc = _createDoc();

    doc.addPage(
      _createPage(
        pw.Column(
          children: [
            _buildHeader(ticketId),
            pw.SizedBox(height: 4),
            pw.Center(
              child: pw.Text(
                'COPIA CARGA',
                style: pw.TextStyle(fontSize: 8, fontWeight: pw.FontWeight.bold),
              ),
            ),
            pw.SizedBox(height: 8),
            _buildContent(
              destinatario,
              articulo,
              precio,
              destino,
              telefonoDest,
              date,
              time,
            ),
            pw.SizedBox(height: 12),
            pw.Row(
              children: [
                pw.Padding(
                  padding: pw.EdgeInsets.only(right: 4),
                  child: pw.Image(_optimizer.scissors, width: 12),
                ),
                pw.Expanded(
                  child: pw.Container(
                    height: 0.5,
                    decoration: pw.BoxDecoration(
                      border: pw.Border(
                        top: pw.BorderSide(
                          width: 0.5,
                          style: pw.BorderStyle.dashed,
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
            pw.SizedBox(height: 12),
            pw.Center(
              child: pw.Text(
                'CONTROL INTERNO',
                style: pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold),
              ),
            ),
            pw.SizedBox(height: 4),
            _buildControlInternoBox(ticketId, articulo, precio, date),
            pw.SizedBox(height: 69),
            pw.Container(width: double.infinity, height: 2, color: PdfColors.black),
          ],
        ),
      ),
    );

    return await doc.save();
  }

  // Simplified reprint method
  Future<void> reprintNewCargoPdf(
      String destinatario,
      String articulo,
      double precio,
      String destino,
      String telefonoDest,
      bool printClient,
      bool printCargo,
      String ticketId,
      ) async {
    // Ensure resources are preloaded
    await preloadResources();

    // Get current date and time
    final date = DateFormat('dd/MM/yyyy').format(DateTime.now());
    final time = DateFormat('HH:mm:ss').format(DateTime.now());

    try {
      if (printClient) {
        final pdf = await _generateClientReprintPdf(
            ticketId,
            destinatario,
            articulo,
            precio,
            destino,
            telefonoDest,
            date,
            time
        );
        await Printing.layoutPdf(onLayout: (_) => pdf);
      }

      if (printCargo) {
        final pdf = await _generateCargoReprintPdf(
            ticketId,
            destinatario,
            articulo,
            precio,
            destino,
            telefonoDest,
            date,
            time
        );
        await Printing.layoutPdf(onLayout: (_) => pdf);
      }
    } catch (e) {
      print('Error reprinting cargo PDF: $e');
      _optimizer.clearCache();
      throw e;
    }
  }

  // Generate client reprint PDF
  Future<Uint8List> _generateClientReprintPdf(
      String ticketId,
      String destinatario,
      String articulo,
      double precio,
      String destino,
      String telefonoDest,
      String date,
      String time
      ) async {
    final doc = _createDoc();

    doc.addPage(
      _createPage(
        pw.Column(
          children: [
            _buildHeader(ticketId),
            pw.SizedBox(height: 4),
            pw.Center(
              child: pw.Text(
                'COPIA CLIENTE (REIMPRESIÓN)',
                style: pw.TextStyle(fontSize: 8, fontWeight: pw.FontWeight.bold),
              ),
            ),
            pw.SizedBox(height: 8),
            _buildContent(
              destinatario,
              articulo,
              precio,
              destino,
              telefonoDest,
              date,
              time,
            ),
            pw.SizedBox(height: 6),
            pw.Center(child: pw.Image(_optimizer.endImage, width: _pdfWidth * 0.8)),
          ],
        ),
      ),
    );

    return await doc.save();
  }

  // Generate cargo reprint PDF
  Future<Uint8List> _generateCargoReprintPdf(
      String ticketId,
      String destinatario,
      String articulo,
      double precio,
      String destino,
      String telefonoDest,
      String date,
      String time
      ) async {
    final doc = _createDoc();

    doc.addPage(
      _createPage(
        pw.Column(
          children: [
            _buildHeader(ticketId),
            pw.SizedBox(height: 4),
            pw.Center(
              child: pw.Text(
                'COPIA CARGA (REIMPRESIÓN)',
                style: pw.TextStyle(fontSize: 8, fontWeight: pw.FontWeight.bold),
              ),
            ),
            pw.SizedBox(height: 8),
            _buildContent(
              destinatario,
              articulo,
              precio,
              destino,
              telefonoDest,
              date,
              time,
            ),
            pw.SizedBox(height: 12),
            pw.Row(
              children: [
                pw.Padding(
                  padding: pw.EdgeInsets.only(right: 4),
                  child: pw.Image(_optimizer.scissors, width: 12),
                ),
                pw.Expanded(
                  child: pw.Container(
                    height: 0.5,
                    decoration: pw.BoxDecoration(
                      border: pw.Border(
                        top: pw.BorderSide(
                          width: 0.5,
                          style: pw.BorderStyle.dashed,
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
            pw.SizedBox(height: 12),
            pw.Center(
              child: pw.Text(
                'CONTROL INTERNO',
                style: pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold),
              ),
            ),
            pw.SizedBox(height: 4),
            _buildControlInternoBox(ticketId, articulo, precio, date),
            pw.SizedBox(height: 69),
            pw.Container(width: double.infinity, height: 2, color: PdfColors.black),
          ],
        ),
      ),
    );

    return await doc.save();
  }
}