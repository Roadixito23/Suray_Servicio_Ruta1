import 'package:flutter/material.dart';
import 'package:pdf/pdf.dart';
import 'package:printing/printing.dart';
import 'pdf_generator.dart';
import 'package:provider/provider.dart';
import 'ReporteCaja.dart';
import 'ComprobanteModel.dart';
import 'pdf_optimizer.dart'; // Import our optimizer

class GenerateTicket {
  final PdfGenerator pdfGenerator = PdfGenerator();
  final PdfOptimizer optimizer = PdfOptimizer(); // Add the optimizer
  bool resourcesPreloaded = false;

  // Preload resources method to be called at app initialization
  Future<void> preloadResources() async {
    if (!resourcesPreloaded) {
      await optimizer.preloadResources();
      resourcesPreloaded = true;
    }
  }

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
      // Ensure resources are preloaded
      if (!resourcesPreloaded) {
        await preloadResources();
      }

      // Show immediate feedback to user
      ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Generando ticket...'),
            duration: Duration(milliseconds: 800),
          )
      );

      // Obtener el modelo de comprobante
      comprobanteModel = Provider.of<ComprobanteModel>(context, listen: false);

      // Generate the PDF
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

      // Success message
      ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Ticket generado correctamente'),
            duration: Duration(seconds: 1),
            backgroundColor: Colors.green,
          )
      );

    } catch (e) {
      // Show error message
      ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error al generar ticket: $e'),
            backgroundColor: Colors.red,
          )
      );

      // Clear cached resources on error to free memory
      optimizer.clearCache();
      resourcesPreloaded = false;

      print('Error en generateTicketPdf: $e');
    }
  }
}