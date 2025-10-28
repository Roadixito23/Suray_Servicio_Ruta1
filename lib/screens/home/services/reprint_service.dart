import 'package:flutter/material.dart';
import 'package:pdf/pdf.dart';
import 'package:provider/provider.dart';
import '../../../utils/generateTicket.dart';
import '../../../utils/generate_mo_ticket.dart';
import '../../../utils/generateCargo_Ticket.dart';
import '../../../models/ComprobanteModel.dart';
import '../../../utils/ReporteCaja.dart';

/// Servicio que maneja toda la lógica de reimpresión de tickets
class ReprintService {
  final GenerateTicket generateTicket;
  final MoTicketGenerator moTicketGenerator;

  ReprintService({
    required this.generateTicket,
    required this.moTicketGenerator,
  });

  /// Maneja el proceso de reimpresión según el tipo de transacción
  Future<void> handleReprint({
    required BuildContext context,
    required Map<String, dynamic> lastTransaction,
    required Function(bool) setIsReprinting,
    required Function(bool) setHasReprinted,
  }) async {
    setIsReprinting(true);

    try {
      String nombre = lastTransaction['nombre'] ?? '';

      if (nombre.toLowerCase().contains('cargo')) {
        // Para tipo cargo, mostrar opciones de reimpresión
        await showCargoReprintOptions(context, lastTransaction);
      } else if (nombre == 'Oferta Ruta' ||
          lastTransaction['tipo'] == 'ofertaMultiple') {
        // Para ofertas
        await reprintOfferTicket(context, lastTransaction);
        // Solo marcar como reimpreso si no es cargo
        setHasReprinted(true);
      } else {
        // Para tickets regulares
        await reprintRegularTicket(context, lastTransaction);
        setHasReprinted(true);
      }
    } catch (e) {
      print('Error al reimprimir: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error al reimprimir: $e')),
      );
    } finally {
      setIsReprinting(false);
    }
  }

  /// Reimprimir un ticket regular
  Future<void> reprintRegularTicket(
    BuildContext context,
    Map<String, dynamic> lastTransaction,
  ) async {
    String tipo = lastTransaction['nombre'] ?? '';
    double valor = lastTransaction['valor'] ?? 0.0;
    bool switchValue = lastTransaction['switchValue'] ?? false;

    await generateTicket.generateTicketPdf(
      tipo,
      valor,
      switchValue,
      true, // Indicar que es una reimpresión
    );
  }

  /// Reimprimir un ticket de oferta múltiple
  Future<void> reprintOfferTicket(
    BuildContext context,
    Map<String, dynamic> lastTransaction,
  ) async {
    try {
      if (lastTransaction['offerEntries'] == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('No hay suficientes detalles para reimprimir')),
        );
        return;
      }

      String comprobante = lastTransaction['comprobante'] ?? '';
      bool switchValue = lastTransaction['switchValue'] ?? false;

      List savedEntries = lastTransaction['offerEntries'] as List;

      List<Map<String, dynamic>> offerEntries = [];
      for (var entry in savedEntries) {
        offerEntries.add({
          'number': entry['number'],
          'value': entry['value'],
          'numberController': TextEditingController(text: entry['number']),
          'valueController': TextEditingController(text: entry['value']),
        });
      }

      await moTicketGenerator.reprintMoTicket(
        PdfPageFormat.standard,
        offerEntries,
        switchValue,
        context,
        comprobante,
      );

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Reimpresión completada correctamente')),
      );
    } catch (e) {
      print('Error en reprintOfferTicket: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error al reimprimir: $e')),
      );
    }
  }

  /// Mostrar opciones de reimpresión para cargo
  Future<void> showCargoReprintOptions(
    BuildContext context,
    Map<String, dynamic> lastTransaction,
  ) async {
    return showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext dialogContext) {
        return AlertDialog(
          title: Row(
            children: [
              Icon(Icons.inventory, color: Colors.orange, size: 28),
              SizedBox(width: 10),
              Expanded(
                child: Text(
                  'Reimprimir Último Cargo',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
              ),
            ],
          ),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _buildCargoInfo(lastTransaction),
                SizedBox(height: 15),
                Text(
                  '¿Qué boleta desea reimprimir?',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                  textAlign: TextAlign.center,
                ),
                SizedBox(height: 20),
              ],
            ),
          ),
          actions: [
            Container(
              width: double.infinity,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Row(
                    children: [
                      _buildClientButton(context, dialogContext, lastTransaction),
                      _buildCargoButton(context, dialogContext, lastTransaction),
                    ],
                  ),
                  Row(
                    children: [
                      _buildBothButton(context, dialogContext, lastTransaction),
                      _buildCancelButton(dialogContext),
                    ],
                  ),
                ],
              ),
            ),
          ],
        );
      },
    );
  }

  /// Reimprimir ticket de cargo
  Future<void> reprintCargoTicket(
    BuildContext context,
    Map<String, dynamic> lastTransaction,
    bool printClient,
    bool printCargo,
  ) async {
    final comprobanteModel =
        Provider.of<ComprobanteModel>(context, listen: false);
    final reporteCaja = Provider.of<ReporteCaja>(context, listen: false);
    final cargoGen = CargoTicketGenerator(comprobanteModel, reporteCaja);

    try {
      final String destinatario =
          lastTransaction['destinatario'] as String? ?? '';
      final String articulo = lastTransaction['articulo'] as String? ?? '';
      final double valor = lastTransaction['precio'] as double? ?? 0.0;
      final String destino = lastTransaction['destino'] as String? ?? '';
      final String telefono = lastTransaction['telefono'] as String? ?? '';
      final String ticketNum = comprobanteModel.formattedComprobante;

      await cargoGen.reprintNewCargoPdf(
        destinatario,
        articulo,
        valor,
        destino,
        telefono,
        printClient,
        printCargo,
        ticketNum,
      );

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Reimpresión completada correctamente')),
      );
    } catch (e) {
      print('Error en reprintCargoTicket: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error al reimprimir: $e')),
      );
    }
  }

  // Widgets auxiliares

  Widget _buildCargoInfo(Map<String, dynamic> lastTransaction) {
    return Container(
      padding: EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: Colors.orange.withOpacity(0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.orange.withOpacity(0.5)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Detalles del Cargo:',
            style: TextStyle(fontWeight: FontWeight.bold),
          ),
          SizedBox(height: 8),
          Text('Destinatario: ${lastTransaction['destinatario'] ?? 'No disponible'}'),
          Text('Comprobante: ${lastTransaction['comprobante'] ?? 'No disponible'}'),
        ],
      ),
    );
  }

  Widget _buildClientButton(
    BuildContext context,
    BuildContext dialogContext,
    Map<String, dynamic> lastTransaction,
  ) {
    return Expanded(
      child: Padding(
        padding: const EdgeInsets.only(right: 4.0, bottom: 4.0),
        child: ElevatedButton.icon(
          icon: Icon(Icons.person, color: Colors.white),
          label: Text(
            'Cliente',
            style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
          ),
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.blue,
            padding: EdgeInsets.symmetric(vertical: 12),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(8),
            ),
          ),
          onPressed: () {
            Navigator.of(dialogContext).pop();
            reprintCargoTicket(context, lastTransaction, true, false);
          },
        ),
      ),
    );
  }

  Widget _buildCargoButton(
    BuildContext context,
    BuildContext dialogContext,
    Map<String, dynamic> lastTransaction,
  ) {
    return Expanded(
      child: Padding(
        padding: const EdgeInsets.only(left: 4.0, bottom: 4.0),
        child: ElevatedButton.icon(
          icon: Icon(Icons.local_shipping, color: Colors.white),
          label: Text(
            'Carga',
            style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
          ),
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.green,
            padding: EdgeInsets.symmetric(vertical: 12),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(8),
            ),
          ),
          onPressed: () {
            Navigator.of(dialogContext).pop();
            reprintCargoTicket(context, lastTransaction, false, true);
          },
        ),
      ),
    );
  }

  Widget _buildBothButton(
    BuildContext context,
    BuildContext dialogContext,
    Map<String, dynamic> lastTransaction,
  ) {
    return Expanded(
      child: Padding(
        padding: const EdgeInsets.only(right: 4.0, top: 4.0),
        child: ElevatedButton.icon(
          icon: Icon(Icons.print, color: Colors.white),
          label: Text(
            'Ambas',
            style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
          ),
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.orange,
            padding: EdgeInsets.symmetric(vertical: 12),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(8),
            ),
          ),
          onPressed: () {
            Navigator.of(dialogContext).pop();
            reprintCargoTicket(context, lastTransaction, true, true);
          },
        ),
      ),
    );
  }

  Widget _buildCancelButton(BuildContext context) {
    return Expanded(
      child: Padding(
        padding: const EdgeInsets.only(left: 4.0, top: 4.0),
        child: ElevatedButton.icon(
          icon: Icon(Icons.cancel, color: Colors.white),
          label: Text(
            'Cancelar',
            style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
          ),
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.grey,
            padding: EdgeInsets.symmetric(vertical: 12),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(8),
            ),
          ),
          onPressed: () => Navigator.of(context).pop(),
        ),
      ),
    );
  }
}
