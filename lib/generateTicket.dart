import 'package:flutter/material.dart';
import 'package:pdf/pdf.dart';
import 'package:printing/printing.dart';
import 'pdf_generator.dart';
import 'package:provider/provider.dart';
import 'ReporteCaja.dart';
import 'ComprobanteModel.dart';

class GenerateTicket {
  final PdfGenerator pdfGenerator = PdfGenerator();

  Future<void> generateTicketPdf(
      BuildContext context,
      double valor,
      bool isSwitchOn,
      String nombrePasaje,
      String ownerName,
      String phoneNumber,
      String itemName,
      ComprobanteModel comprobanteModel,
      bool isReprint) async {
    try {
      // Obtener el modelo de comprobante
      comprobanteModel = Provider.of<ComprobanteModel>(context, listen: false);

      // Si es reimpresión, no incrementar el número de comprobante
      // Generar el PDF
      final clientePdfData = await pdfGenerator.generateTicketPdf(
          PdfPageFormat(80 * PdfPageFormat.mm, 200 * PdfPageFormat.mm),
          valor,
          isSwitchOn,
          nombrePasaje,
          ownerName,
          phoneNumber,
          itemName,
          comprobanteModel,
          isReprint
      );

      // Almacenar la transacción en ReporteCaja solo si no es reimpresión
      if (!isReprint) {
        final reporteCaja = Provider.of<ReporteCaja>(context, listen: false);
        reporteCaja.receiveData(nombrePasaje, valor, comprobanteModel.comprobanteNumber.toString());
      }

      // Imprimir el PDF de la copia del cliente
      if (clientePdfData != null) {
        await Printing.layoutPdf(
          onLayout: (PdfPageFormat format) async => clientePdfData,
        );
      } else {
        print('No se pudo generar el PDF de la copia del cliente.');
      }
    } catch (e) {
      print('Error en generateTicketPdf: $e');
    }
  }
}