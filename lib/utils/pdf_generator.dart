import 'dart:typed_data';
import 'package:flutter/services.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:intl/intl.dart';
import '../models/ComprobanteModel.dart';
import 'pdf_optimizer.dart'; // Import our new optimizer

class PdfGenerator {
  final double dateTimeSpacing = 5; // Espacio entre la fecha y la hora

  Future<Uint8List> generateTicketPdf(
      PdfPageFormat format,
      double valor,
      bool isSwitchOn,
      String nombrePasaje,
      String ownerName,
      String phoneNumber,
      String itemName,
      ComprobanteModel comprobanteModel,
      bool isReprint) async {

    // Use our optimizer to create a lightweight document
    final optimizer = PdfOptimizer();
    await optimizer.preloadResources();
    final doc = optimizer.createDocument();

    try {
      // Use cached resources
      final logoImage = optimizer.getLogoImage();
      final endImage = optimizer.getEndImage();

      // Formatear el valor de los precios (kept the same)
      final priceFormatter = NumberFormat('#,##0', 'es_CL');
      String formattedPrice = priceFormatter.format(valor);

      // Obtener la fecha y hora actual
      String currentDate = DateFormat('dd/MM/yyyy').format(DateTime.now());
      String currentTime = DateFormat('HH:mm:ss').format(DateTime.now());

      // Incrementar el número de comprobante solo si no es reimpresión
      if (!isReprint) {
        await comprobanteModel.incrementComprobante();
      }

      // Obtener el número formateado de comprobante
      String ticketIdWithComprobante = comprobanteModel.formattedComprobante;

      // Add a single page with optimized content
      doc.addPage(
        pw.Page(
          pageFormat: format,
          build: (pw.Context context) {
            return pw.Column(
              mainAxisAlignment: pw.MainAxisAlignment.start,
              crossAxisAlignment: pw.CrossAxisAlignment.center,
              children: [
                // Reemplazar el método buildHeader con una versión personalizada
                // donde el comprobante está alineado a la derecha
                pw.Row(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    // Logo a la izquierda (50% del ancho)
                    pw.Container(
                        width: format.width * 0.5,
                        child: pw.Image(logoImage)
                    ),

                    // Espacio flexible para empujar el comprobante a la derecha
                    pw.Spacer(),

                    // Comprobante a la derecha, pegado al margen
                    pw.Container(
                      width: format.width * 0.4,
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
                            'N° $ticketIdWithComprobante',
                            style: pw.TextStyle(fontSize: 9, fontWeight: pw.FontWeight.bold),
                            textAlign: pw.TextAlign.center,
                          ),
                        ],
                      ),
                    ),
                  ],
                ),

                pw.SizedBox(height: 10),

                // Only add reprint indicator if needed (simplified)
                if (isReprint)
                  PdfTicketComponents.buildHeader(logoImage,comprobanteModel as String),

                // Title based on switch state (simplified)
                pw.Text(
                  (nombrePasaje.toLowerCase() == 'correspondencia')
                      ? 'COPIA DE CLIENTE'
                      : (isSwitchOn ? 'TARIFA DOMINGO | FERIADO' : 'TARIFA LUNES A SÁBADO'),
                  style: pw.TextStyle(fontSize: 15, fontWeight: pw.FontWeight.bold),
                  textAlign: pw.TextAlign.center,
                ),

                // Ticket name (simplified)
                pw.SizedBox(height: 5),
                pw.Text(
                  nombrePasaje,
                  style: pw.TextStyle(fontSize: 16),
                  textAlign: pw.TextAlign.center,
                ),
                pw.SizedBox(height: 5),

                // Only add correspondence details if needed (simplified)
                if (nombrePasaje.toLowerCase() == 'correspondencia') ...[
                  pw.Text(
                    'Destinatario: $ownerName',
                    style: pw.TextStyle(fontSize: 16),
                  ),
                  pw.SizedBox(height: 5),
                  pw.Text(
                    'Teléfono: $phoneNumber',
                    style: pw.TextStyle(fontSize: 16),
                  ),
                  pw.SizedBox(height: 5),
                  pw.Text(
                    'Artículo: $itemName',
                    style: pw.TextStyle(fontSize: 16),
                  ),
                  pw.SizedBox(height: 5),
                ],

                // Price (simplified)
                PdfTicketComponents.buildPriceDisplay(formattedPrice),

                pw.SizedBox(height: 5),
                pw.Text(
                  'Válido hora y fecha señalada',
                  style: pw.TextStyle(fontSize: 14, fontWeight: pw.FontWeight.bold),
                  textAlign: pw.TextAlign.center,
                ),

                pw.SizedBox(height: dateTimeSpacing),

                // Date and time footer (simplified)
                PdfTicketComponents.buildDateTimeFooter(currentDate, currentTime),

                // Footer image
                pw.Image(endImage),

                // Optional reprint date
                if (isReprint) ...[
                  pw.SizedBox(height: 5),
                  pw.Text(
                    'Fecha reimpresión: $currentDate $currentTime',
                    style: pw.TextStyle(fontSize: 8, fontStyle: pw.FontStyle.italic),
                  ),
                ],
              ],
            );
          },
        ),
      );

      // Generate and return the PDF bytes
      return await doc.save();

    } catch (e) {
      print('Error generando PDF: $e');
      // In case of error, clear the cache to free memory
      optimizer.clearCache();
      throw e;
    }
  }
}