import 'dart:typed_data';
import 'package:flutter/services.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:intl/intl.dart';
import 'ComprobanteModel.dart'; // Asegúrate de importar tu modelo
import 'package:shared_preferences/shared_preferences.dart';

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
    final doc = pw.Document();

    try {
      // Cargar logotipo en lugar de la cabecera
      final logoImage = await _loadImage('assets/logobkwt.png');

      // Cargar la imagen de pie
      final endImage = await _loadImage('assets/endTicket.png');

      // Formatear el valor de los precios
      final priceFormatter = NumberFormat('#,##0', 'es_CL'); // Formato chileno
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

      // Generar una sola página para el ticket
      doc.addPage(
        pw.Page(
          pageFormat: format,
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
                      width: format.width * 0.5,
                      child: pw.Image(logoImage),
                    ),
                    // Lado derecho - Cuadro con borde (sin fondo)
                    pw.Container(
                      width: 110,
                      height: 60, // Hacer cuadrado, ajustar según sea necesario
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
                              fontSize: 8,
                              fontWeight: pw.FontWeight.bold,
                            ),
                            textAlign: pw.TextAlign.center,
                          ),
                          pw.Text(
                            'PAGO EN BUS',
                            style: pw.TextStyle(
                              fontSize: 8,
                              fontWeight: pw.FontWeight.bold,
                            ),
                            textAlign: pw.TextAlign.center,
                          ),
                          pw.SizedBox(height: 3),
                          pw.Text(
                            'N° $ticketIdWithComprobante',
                            style: pw.TextStyle(
                              fontSize: 14,
                              fontWeight: pw.FontWeight.bold,
                            ),
                            textAlign: pw.TextAlign.center,
                          ),
                        ],
                      ),
                    ),
                  ],
                ),

                pw.SizedBox(height: 10),

                // Si es reimpresión, añadir texto de reimpresión en un recuadro
                if (isReprint)
                  pw.Container(
                    decoration: pw.BoxDecoration(
                      border: pw.Border.all(),
                      color: PdfColors.grey200,
                    ),
                    padding: pw.EdgeInsets.all(4),
                    margin: pw.EdgeInsets.only(bottom: 5),
                    child: pw.Text(
                      'REIMPRESIÓN',
                      style: pw.TextStyle(
                          fontSize: 12,
                          fontWeight: pw.FontWeight.bold,
                          color: PdfColors.red
                      ),
                    ),
                  ),

                // Título según el estado del switch
                pw.Align(
                  alignment: pw.Alignment.center,
                  child: pw.Text(
                    (nombrePasaje.toLowerCase() == 'correspondencia')
                        ? 'COPIA DE CLIENTE'
                        : (isSwitchOn ? 'TARIFA DOMINGO | FERIADO' : 'TARIFA LUNES A SÁBADO'),
                    style: pw.TextStyle(fontSize: 15, fontWeight: pw.FontWeight.bold),
                    textAlign: pw.TextAlign.center,
                  ),
                ),

                // Mostrar nombre del pasaje
                pw.SizedBox(height: 5),
                pw.Align(
                  alignment: pw.Alignment.center,
                  child: pw.Text(
                    '$nombrePasaje',
                    style: pw.TextStyle(fontSize: 18),
                    textAlign: pw.TextAlign.center,
                  ),
                ),
                pw.SizedBox(height: 5),

                // Mostrar detalles solo si es "Correspondencia"
                if (nombrePasaje.toLowerCase() == 'correspondencia') ...[
                  pw.Align(
                    alignment: pw.Alignment.center,
                    child: pw.Text(
                      'Destinatario: $ownerName',
                      style: pw.TextStyle(fontSize: 18),
                    ),
                  ),
                  pw.SizedBox(height: 5),
                  pw.Align(
                    alignment: pw.Alignment.center,
                    child: pw.Text(
                      'Teléfono: $phoneNumber',
                      style: pw.TextStyle(fontSize: 18),
                    ),
                  ),
                  pw.SizedBox(height: 5),
                  pw.Align(
                    alignment: pw.Alignment.center,
                    child: pw.Text(
                      'Artículo: $itemName',
                      style: pw.TextStyle(fontSize: 18),
                    ),
                  ),
                  pw.SizedBox(height: 5),
                ],

                pw.Align(
                  alignment: pw.Alignment.center,
                  child: pw.Text(
                    'Precio: \$${formattedPrice}',
                    style: pw.TextStyle(fontSize: 18),
                  ),
                ),
                pw.SizedBox(height: 5),
                pw.Text(
                  'Válido hora y fecha señalada',
                  style: pw.TextStyle(fontSize: 16, fontWeight: pw.FontWeight.bold),
                  textAlign: pw.TextAlign.center,
                ),
                pw.SizedBox(height: dateTimeSpacing),
                pw.Row(
                  mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                  children: [
                    pw.Text(currentTime, style: pw.TextStyle(fontSize: 16)),
                    pw.Text(currentDate, style: pw.TextStyle(fontSize: 16)),
                  ],
                ),
                pw.Image(endImage), // Pie de página
                if (isReprint) ...[
                  pw.SizedBox(height: 5),
                  pw.Text(
                    'Fecha reimpresión: $currentDate $currentTime',
                    style: pw.TextStyle(fontSize: 10, fontStyle: pw.FontStyle.italic),
                  ),
                ],
              ],
            );
          },
        ),
      );

      return doc.save(); // Devuelve el PDF generado
    } catch (e) {
      print('Error generando PDF: $e');
      throw e; // Re-lanza el error para que pueda ser manejado por el llamador
    }
  }

  Future<pw.ImageProvider> _loadImage(String path) async {
    try {
      final ByteData bytes = await rootBundle.load(path);
      final Uint8List list = bytes.buffer.asUint8List();
      return pw.MemoryImage(list);
    } catch (e) {
      throw Exception('Error loading image: $e');
    }
  }
}