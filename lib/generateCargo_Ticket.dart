import 'dart:typed_data';
import 'package:flutter/services.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:intl/intl.dart';
import 'package:printing/printing.dart';
import 'ComprobanteModel.dart';
import 'ReporteCaja.dart';

class CargoTicketGenerator {
  final ComprobanteModel comprobanteModel;
  final ReporteCaja reporteCaja;
  final _priceFmt = NumberFormat('#,##0', 'es_CL');
  final _pdfWidth = 58 * PdfPageFormat.mm;
  final _pdfHeight = PdfPageFormat.a4.height;

  CargoTicketGenerator(this.comprobanteModel, this.reporteCaja);

  Future<pw.ImageProvider> _loadImage(String asset) async {
    final data = await rootBundle.load(asset);
    return pw.MemoryImage(data.buffer.asUint8List());
  }

  pw.Document _createDoc() => pw.Document();

  pw.Page _createPage(pw.Widget content) => pw.Page(
    pageFormat: PdfPageFormat(_pdfWidth, _pdfHeight),
    build: (_) => content,
  );

  pw.Widget _buildHeader(pw.ImageProvider logo, String ticketId) => pw.Row(
    crossAxisAlignment: pw.CrossAxisAlignment.start,
    children: [
      pw.Container(width: _pdfWidth * 0.5, child: pw.Image(logo)),
      pw.Container(
        width: _pdfWidth * 0.5,
        padding: pw.EdgeInsets.all(4),
        decoration: pw.BoxDecoration(border: pw.Border.all(width: 1.5)),
        child: pw.Column(
          mainAxisAlignment: pw.MainAxisAlignment.center,
          crossAxisAlignment: pw.CrossAxisAlignment.center,
          children: [
            pw.Text(
              'COMPROBANTE DE CARGO',
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

  pw.Widget _buildContent(
      String destinatario,
      String articulo,
      double precio,
      String destino,
      String telefonoDest,
      String fecha,
      String hora,
      ) => pw.Column(
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

  pw.Widget _buildControlInternoBox(
      String ticketId,
      String articulo,
      double precio,
      String fechaDespacho,
      ) => pw.Container(
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

  /// Genera e imprime dos PDFs separados: copia cliente y copia carga
  Future<void> generateNewCargoPdf(
      String destinatario,
      String articulo,
      double precio,
      String destino,
      String telefonoDest,
      ) async {
    await comprobanteModel.incrementComprobante();
    final ticketId = comprobanteModel.formattedComprobante;
    final logo = await _loadImage('assets/logobkwt.png');
    final endTicket = await _loadImage('assets/endTicket.png');
    final scissors = await _loadImage('assets/tijera.png');
    final date = DateFormat('dd/MM/yyyy').format(DateTime.now());
    final time = DateFormat('HH:mm:ss').format(DateTime.now());

    // COPIA CLIENTE
    final clientDoc = _createDoc();
    clientDoc.addPage(
      _createPage(
        pw.Column(
          children: [
            _buildHeader(logo, ticketId),
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
            pw.Center(child: pw.Image(endTicket, width: _pdfWidth * 0.8)),
          ],
        ),
      ),
    );
    final clientPdf = await clientDoc.save();
    await Printing.layoutPdf(onLayout: (_) => clientPdf);

    // COPIA CARGA
    final cargaDoc = _createDoc();
    cargaDoc.addPage(
      _createPage(
        pw.Column(
          children: [
            _buildHeader(logo, ticketId),
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
                  child: pw.Image(scissors, width: 12),
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
    final cargaPdf = await cargaDoc.save();
    await Printing.layoutPdf(onLayout: (_) => cargaPdf);

    reporteCaja.receiveCargoData(destinatario, precio, ticketId);
  }

  /// Reimpresión: usa comprobante existente, permite elegir copias
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
    final logo = await _loadImage('assets/logobkwt.png');
    final scissors = await _loadImage('assets/tijeras.png');
    final date = DateFormat('dd/MM/yyyy').format(DateTime.now());
    final time = DateFormat('HH:mm:ss').format(DateTime.now());

    if (printClient) {
      final clientDoc = _createDoc();
      clientDoc.addPage(
        _createPage(
          pw.Column(
            children: [
              _buildHeader(logo, ticketId),
              pw.SizedBox(height: 4),
              pw.Center(
                child: pw.Text(
                  'COPIA CLIENTE (REIMPRESIÓN)',
                  style: pw.TextStyle(fontSize: 8, fontWeight: pw.FontWeight.bold),
                ),
              ),
              pw.SizedBox(height: 8),
              _buildContent(destinatario, articulo, precio, destino, telefonoDest, date, time),
            ],
          ),
        ),
      );
      final clientPdf = await clientDoc.save();
      await Printing.layoutPdf(onLayout: (_) => clientPdf);
    }

    if (printCargo) {
      final cargaDoc = _createDoc();
      cargaDoc.addPage(
        _createPage(
          pw.Column(
            children: [
              _buildHeader(logo, ticketId),
              pw.SizedBox(height: 4),
              pw.Center(
                child: pw.Text(
                  'COPIA CARGA (REIMPRESIÓN)',
                  style: pw.TextStyle(fontSize: 8, fontWeight: pw.FontWeight.bold),
                ),
              ),
              pw.SizedBox(height: 8),
              _buildContent(destinatario, articulo, precio, destino, telefonoDest, date, time),
              pw.SizedBox(height: 12),
              pw.Row(
                children: [
                  pw.Padding(
                    padding: pw.EdgeInsets.only(right: 4),
                    child: pw.Image(scissors, width: 12),
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
      final cargaPdf = await cargaDoc.save();
      await Printing.layoutPdf(onLayout: (_) => cargaPdf);
    }
  }
}
