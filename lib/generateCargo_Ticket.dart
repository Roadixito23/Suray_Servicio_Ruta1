import 'dart:typed_data';
import 'package:flutter/services.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:intl/intl.dart';
import 'package:printing/printing.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'ComprobanteModel.dart';
import 'ReporteCaja.dart';
import 'cargo_database.dart'; // New import for cargo database

class CargoTicketGenerator {
  final ComprobanteModel comprobanteModel;
  final ReporteCaja reporteCaja;

  // Formateador de número para precios
  final _priceFormatter = NumberFormat('#,##0', 'es_CL');

  // Constantes para tamaños de PDF
  final _pdfWidth = 58 * PdfPageFormat.mm;
  final _pdfHeight = PdfPageFormat.a4.height;

  CargoTicketGenerator(this.comprobanteModel, this.reporteCaja);

  // Método auxiliar para cargar imágenes
  Future<pw.ImageProvider> _loadImage(String path) async {
    try {
      final ByteData bytes = await rootBundle.load(path);
      return pw.MemoryImage(bytes.buffer.asUint8List());
    } catch (e) {
      throw Exception('Error loading image: $e');
    }
  }

  // Método para obtener ID de ticket formateado
  Future<String> _getFormattedTicketId() async {
    final prefs = await SharedPreferences.getInstance();
    int ticketId = prefs.getInt('ticketId') ?? 1;

    return '${ticketId.toString().padLeft(2, '0')}-${comprobanteModel.comprobanteNumber.toString().padLeft(6, '0')}';
  }

  // Método común para configurar el documento PDF
  pw.Document _createPdfDocument() {
    return pw.Document();
  }

  // Método para crear una página de PDF con contenido
  pw.Page _createPdfPage(pw.Widget content) {
    return pw.Page(
      pageFormat: PdfPageFormat(_pdfWidth, _pdfHeight),
      build: (pw.Context context) => content,
    );
  }

  // Método para imprimir un PDF
  Future<void> _printPdf(Uint8List pdfData) async {
    await Printing.layoutPdf(
      onLayout: (PdfPageFormat format) async => pdfData,
    );
  }

  // GENERACIÓN DE CARGO NUEVO
  Future<void> generateNewCargoPdf(
      String destinatario,
      String remitente,
      String articulo,
      double precio,
      String telefonoDest,
      String telefonoRemit,
      bool isTelefonoDestOptional,
      bool isTelefonoRemitOptional,
      String ticketNum,
      String destino) async {

    // Incrementar y guardar el número de comprobante
    await comprobanteModel.incrementComprobante();

    // Cargar imágenes y obtener datos comunes
    final headImage = await _loadImage('assets/logobkwt.png');
    final endImage = await _loadImage('assets/endTicket.png');
    final currentDate = DateFormat('dd/MM/yyyy').format(DateTime.now());
    final currentTime = DateFormat('HH:mm:ss').format(DateTime.now());
    final ticketId = await _getFormattedTicketId();

    // Generar e imprimir "Copia de Cliente"
    final clientPdfData = await _generatePdfDocument(
        headImage,
        endImage,
        destinatario,
        remitente,
        articulo,
        precio,
        telefonoDest,
        telefonoRemit,
        isTelefonoDestOptional,
        isTelefonoRemitOptional,
        currentDate,
        currentTime,
        ticketId,
        'Copia de Cliente',
        ticketNum,
        false,  // No es reimpresión
        destino
    );

    // Save client copy to database before printing
    try {
      await CargoDatabase.saveCargoReceipt(
          destinatario,
          remitente,
          articulo,
          precio,
          telefonoDest,
          telefonoRemit,
          ticketNum,
          ticketId,
          clientPdfData,
          'Cliente',
          destino
      );
    } catch (e) {
      print('Error guardando PDF Cliente en base de datos: $e');
    }

    await _printPdf(clientPdfData);

    // Generar e imprimir "Copia de Carga"
    final cargoPdfData = await _generatePdfDocument(
        headImage,
        endImage,
        destinatario,
        remitente,
        articulo,
        precio,
        telefonoDest,
        telefonoRemit,
        isTelefonoDestOptional,
        isTelefonoRemitOptional,
        currentDate,
        currentTime,
        ticketId,
        'Copia de Carga',
        ticketNum,
        false,  // No es reimpresión
        destino
    );

    // Save cargo copy to database before printing
    try {
      await CargoDatabase.saveCargoReceipt(
          destinatario,
          remitente,
          articulo,
          precio,
          telefonoDest,
          telefonoRemit,
          ticketNum,
          ticketId,
          cargoPdfData,
          'Carga',
          destino
      );
    } catch (e) {
      print('Error guardando PDF Carga en base de datos: $e');
    }

    await _printPdf(cargoPdfData);

    // Registrar la transacción
    reporteCaja.receiveCargoData(destinatario, precio, ticketId);
  }

  // REIMPRIMIR CARGO NUEVO
  Future<void> reprintNewCargoPdf(
      String destinatario,
      String remitente,
      String articulo,
      double precio,
      String telefonoDest,
      String telefonoRemit,
      bool isTelefonoDestOptional,
      bool isTelefonoRemitOptional,
      bool printClient,
      bool printCargo,
      String ticketNum,
      String destino) async {

    // Cargar imágenes y obtener datos comunes
    final headImage = await _loadImage('assets/logobkwt.png');
    final endImage = await _loadImage('assets/endTicket.png');
    final currentDate = DateFormat('dd/MM/yyyy').format(DateTime.now());
    final currentTime = DateFormat('HH:mm:ss').format(DateTime.now());
    final ticketId = await _getFormattedTicketId();

    // Imprimir copia de cliente si se solicitó
    if (printClient) {
      final clientPdfData = await _generatePdfDocument(
          headImage,
          endImage,
          destinatario,
          remitente,
          articulo,
          precio,
          telefonoDest,
          telefonoRemit,
          isTelefonoDestOptional,
          isTelefonoRemitOptional,
          currentDate,
          currentTime,
          ticketId,
          'Copia de Cliente',
          ticketNum,
          true,  // Es reimpresión
          destino
      );
      await _printPdf(clientPdfData);
    }

    // Imprimir copia de carga si se solicitó
    if (printCargo) {
      final cargoPdfData = await _generatePdfDocument(
          headImage,
          endImage,
          destinatario,
          remitente,
          articulo,
          precio,
          telefonoDest,
          telefonoRemit,
          isTelefonoDestOptional,
          isTelefonoRemitOptional,
          currentDate,
          currentTime,
          ticketId,
          'Copia de Carga',
          ticketNum,
          true,  // Es reimpresión
          destino
      );
      await _printPdf(cargoPdfData);
    }
  }

  // MÉTODO UNIFICADO PARA GENERAR DOCUMENTO PDF (VERSIÓN NUEVA)
  Future<Uint8List> _generatePdfDocument(
      pw.ImageProvider headImage,
      pw.ImageProvider endImage,
      String destinatario,
      String remitente,
      String articulo,
      double precio,
      String telefonoDest,
      String telefonoRemit,
      bool isTelefonoDestOptional,
      bool isTelefonoRemitOptional,
      String currentDate,
      String currentTime,
      String ticketId,
      String title,
      String ticketNum,
      bool isReprint,
      String destino) async {

    final doc = _createPdfDocument();
    doc.addPage(_createPdfPage(
        _buildPdfContentNew(
            headImage,
            endImage,
            destinatario,
            remitente,
            articulo,
            precio,
            telefonoDest,
            telefonoRemit,
            currentDate,
            currentTime,
            ticketId,
            title,
            ticketNum,
            isReprint,
            destino
        )
    ));
    return await doc.save();
  }

  // MÉTODO UNIFICADO PARA GENERAR DOCUMENTO PDF (VERSIÓN ANTIGUA)
  Future<Uint8List> _generateLegacyPdfDocument(
      pw.ImageProvider headImage,
      pw.ImageProvider endImage,
      String destinatario,
      String articulo,
      double precio,
      String contactInfo,
      bool isPhone,
      String currentDate,
      String currentTime,
      String ticketId,
      String title,
      bool isReprint) async {

    final doc = _createPdfDocument();
    doc.addPage(_createPdfPage(
        _buildPdfContentLegacy(
            headImage,
            endImage,
            destinatario,
            articulo,
            precio,
            contactInfo,
            isPhone,
            currentDate,
            currentTime,
            ticketId,
            title,
            isReprint
        )
    ));
    return await doc.save();
  }

  // CONSTRUCTOR DE CONTENIDO PARA CARGO NUEVO
// Modificación del método _buildPdfContentNew para ajustar el formato de negritas

  pw.Widget _buildPdfContentNew(
      pw.ImageProvider headImage,
      pw.ImageProvider endImage,
      String destinatario,
      String remitente,
      String articulo,
      double precio,
      String telefonoDest,
      String telefonoRemit,
      String currentDate,
      String currentTime,
      String ticketId,
      String title,
      String ticketNum,
      bool isReprint,
      String destino) {

    return
      pw.Column(
        mainAxisAlignment: pw.MainAxisAlignment.start,
        crossAxisAlignment: pw.CrossAxisAlignment.center,
        children: [
          // Nueva cabecera personalizada
          pw.Row(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              // Lado izquierdo - Logo
              pw.Container(
                width: _pdfWidth * 0.5,
                child: pw.Image(headImage),
              ),

              // Lado derecho - Cuadro con borde (sin fondo)
              pw.Container(
                width: 100,
                height: 50, // Hacer cuadrado, ajustar según sea necesario
                padding: pw.EdgeInsets.all(7), // Padding de 7 pixels para reducir uso de tinta
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
                        fontSize: 7,
                        fontWeight: pw.FontWeight.bold,
                      ),
                      textAlign: pw.TextAlign.center,
                    ),
                    pw.SizedBox(height: 1), // Pequeño espacio entre líneas
                    pw.Text(
                      'PAGO EN BUS',
                      style: pw.TextStyle(
                        fontSize: 7,
                        fontWeight: pw.FontWeight.bold,
                      ),
                      textAlign: pw.TextAlign.center,
                    ),
                    pw.SizedBox(height: 4),
                    pw.Text(
                      'N° $ticketId',
                      style: pw.TextStyle(
                        fontSize: 10,
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

        // Marca de reimpresión si corresponde (en negrita para destacar)
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

        // Título principal "CORRESPONDENCIA" (en negrita)
        pw.Text(
            'CORRESPONDENCIA',
            style: pw.TextStyle(fontSize: 12, fontWeight: pw.FontWeight.bold)
        ),
        pw.SizedBox(height: 5),

        // Subtítulo (Copia de Cliente o Copia de Cargo) (en negrita)
        pw.Text(
            title,
            style: pw.TextStyle(fontSize: 16, fontWeight: pw.FontWeight.bold)
        ),
        pw.SizedBox(height: 10),

        // DESTINO en la misma línea (con valor en negrita, título normal)
        pw.Container(
          decoration: pw.BoxDecoration(
            border: pw.Border.all(),
            borderRadius: pw.BorderRadius.circular(5),
          ),
          padding: pw.EdgeInsets.all(8),
          width: double.infinity,
          child: pw.Row(
            crossAxisAlignment: pw.CrossAxisAlignment.center,
            children: [
              pw.Text(
                'Destino a: ',
                style: pw.TextStyle(fontSize: 12, fontWeight: pw.FontWeight.normal),
              ),
              pw.Expanded(
                child: pw.Text(
                  destino,
                  style: pw.TextStyle(fontSize: 14, fontWeight: pw.FontWeight.bold),
                ),
              ),
            ],
          ),
        ),
        pw.SizedBox(height: 10),

        // CUADRADO AGRUPADO: Información del artículo, precio y boleto
        pw.Container(
          decoration: pw.BoxDecoration(
            border: pw.Border.all(),
            borderRadius: pw.BorderRadius.circular(5),
          ),
          padding: pw.EdgeInsets.all(8),
          width: double.infinity,
          child: pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              // Información del artículo (título normal, valor en negrita)
              pw.Text('ARTÍCULO:', style: pw.TextStyle(fontSize: 12, fontWeight: pw.FontWeight.normal)),
              pw.Text(articulo, style: pw.TextStyle(fontSize: 14, fontWeight: pw.FontWeight.bold)),
              pw.SizedBox(height: 5),

              // Precio (título normal, valor en negrita)
              pw.Row(
                children: [
                  pw.Text('PRECIO: ', style: pw.TextStyle(fontSize: 12, fontWeight: pw.FontWeight.normal)),
                  pw.Text(
                      '\$${_priceFormatter.format(precio)}',
                      style: pw.TextStyle(fontSize: 14, fontWeight: pw.FontWeight.bold)
                  ),
                ],
              ),
              pw.SizedBox(height: 5),

              // Número de ticket (título normal, valor en negrita)
              if (ticketNum.isNotEmpty) ...[
                pw.Text('N° BOLETO:', style: pw.TextStyle(fontSize: 12, fontWeight: pw.FontWeight.normal)),
                pw.Text(
                    ticketNum.length > 6 ? ticketNum.substring(0, 6) : ticketNum, // Limitar a 6 caracteres
                    style: pw.TextStyle(fontSize: 16, fontWeight: pw.FontWeight.bold)
                ),
              ],
            ],
          ),
        ),
        pw.SizedBox(height: 10),

        // Información del destinatario en recuadro (título normal, valor en negrita)
        pw.Container(
          decoration: pw.BoxDecoration(
            border: pw.Border.all(),
            borderRadius: pw.BorderRadius.circular(5),
          ),
          padding: pw.EdgeInsets.all(8),
          width: double.infinity,
          child: pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Text('DESTINATARIO:', style: pw.TextStyle(fontSize: 12, fontWeight: pw.FontWeight.normal)),
              pw.Text(
                  destinatario,
                  style: pw.TextStyle(fontSize: 16, fontWeight: pw.FontWeight.bold)
              ),
              if (telefonoDest.isNotEmpty)
                pw.Row(
                  children: [
                    pw.Text('Tel: ', style: pw.TextStyle(fontSize: 12, fontWeight: pw.FontWeight.normal)),
                    pw.Text(telefonoDest, style: pw.TextStyle(fontSize: 12, fontWeight: pw.FontWeight.bold)),
                  ],
                ),
            ],
          ),
        ),
        pw.SizedBox(height: 10),

        // Información del remitente en recuadro (título normal, valor en negrita)
        pw.Container(
          decoration: pw.BoxDecoration(
            border: pw.Border.all(),
            borderRadius: pw.BorderRadius.circular(5),
          ),
          padding: pw.EdgeInsets.all(8),
          width: double.infinity,
          child: pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Text('REMITENTE:', style: pw.TextStyle(fontSize: 12, fontWeight: pw.FontWeight.normal)),
              pw.Text(
                  remitente,
                  style: pw.TextStyle(fontSize: 16, fontWeight: pw.FontWeight.bold)
              ),
              if (telefonoRemit.isNotEmpty)
                pw.Row(
                  children: [
                    pw.Text('Tel: ', style: pw.TextStyle(fontSize: 12, fontWeight: pw.FontWeight.normal)),
                    pw.Text(telefonoRemit, style: pw.TextStyle(fontSize: 12, fontWeight: pw.FontWeight.bold)),
                  ],
                ),
            ],
          ),
        ),
        pw.SizedBox(height: 10),

        // Fecha y hora (sin negrita)
        if (isReprint) ...[
          // Información de reimpresión
          pw.Row(
            mainAxisAlignment: pw.MainAxisAlignment.center, // Añadir esta línea para centrar
            children: [
              pw.Text('Fecha original: ', style: pw.TextStyle(fontSize: 12, fontWeight: pw.FontWeight.normal)),
              pw.Text(currentDate, style: pw.TextStyle(fontSize: 14, fontWeight: pw.FontWeight.normal)),
            ],
          ),
          pw.Row(
            mainAxisAlignment: pw.MainAxisAlignment.center, // Añadir esta línea para centrar
            children: [
              pw.Text('Hora original: ', style: pw.TextStyle(fontSize: 12, fontWeight: pw.FontWeight.normal)),
              pw.Text(currentTime, style: pw.TextStyle(fontSize: 14, fontWeight: pw.FontWeight.normal)),
            ],
          ),
          pw.SizedBox(height: 5),
          pw.Align(
            alignment: pw.Alignment.center, // Añadir esta línea para centrar
            child: pw.Text(
              'Reimpreso: ${DateFormat('dd/MM/yyyy HH:mm:ss').format(DateTime.now())}',
              style: pw.TextStyle(fontSize: 10, fontStyle: pw.FontStyle.italic, fontWeight: pw.FontWeight.normal),
            ),
          ),
        ] else ...[
          // Información original
          pw.Row(
            mainAxisAlignment: pw.MainAxisAlignment.center, // Añadir esta línea para centrar
            children: [
              pw.Text('Fecha: ', style: pw.TextStyle(fontSize: 12, fontWeight: pw.FontWeight.normal)),
              pw.Text(currentDate, style: pw.TextStyle(fontSize: 12, fontWeight: pw.FontWeight.normal)),
            ],
          ),
          pw.Row(
            mainAxisAlignment: pw.MainAxisAlignment.center, // Añadir esta línea para centrar
            children: [
              pw.Text('Hora: ', style: pw.TextStyle(fontSize: 12, fontWeight: pw.FontWeight.normal)),
              pw.Text(currentTime, style: pw.TextStyle(fontSize: 12, fontWeight: pw.FontWeight.normal)),
            ],
          ),
        ],
        // Imagen de pie
        pw.Image(endImage),
      ],
    );
  }

  // CONSTRUCTOR DE CONTENIDO PARA CARGO LEGADO
  pw.Widget _buildPdfContentLegacy(
      pw.ImageProvider headImage,
      pw.ImageProvider endImage,
      String destinatario,
      String articulo,
      double precio,
      String contactInfo,
      bool isPhone,
      String currentDate,
      String currentTime,
      String ticketId,
      String title,
      bool isReprint) {

    return pw.Column(
      mainAxisAlignment: pw.MainAxisAlignment.start,
      crossAxisAlignment: pw.CrossAxisAlignment.center,
      children: [
        // Cabecera con imagen
        pw.Image(headImage),
        pw.SizedBox(height: 10),

        // Número de ticket alineado a la derecha
        pw.Row(mainAxisAlignment: pw.MainAxisAlignment.end,
          children: [
            pw.Text('N° $ticketId', style: pw.TextStyle(fontSize: 14, fontWeight: pw.FontWeight.bold)),
          ],
        ),
        pw.SizedBox(height: 10),

        // Marca de reimpresión si corresponde
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
              style: pw.TextStyle(fontSize: 12, fontWeight: pw.FontWeight.bold, color: PdfColors.red),
            ),
          ),

        // Título (Copia de Cliente o Copia de Carga)
        pw.Text(title, style: pw.TextStyle(fontSize: 12, fontWeight: pw.FontWeight.bold)),
        pw.SizedBox(height: 10),

        // Información básica
        pw.Text('Destinatario: $destinatario', style: pw.TextStyle(fontSize: 16, fontWeight: pw.FontWeight.bold)), // Aumentado a 16
        pw.Text('Artículo: $articulo', style: pw.TextStyle(fontSize: 14)),
        pw.Text('Precio: \$${_priceFormatter.format(precio)}', style: pw.TextStyle(fontSize: 14)),

        // Información de contacto según el tipo
        isPhone
            ? pw.Text('Teléfono: 9$contactInfo', style: pw.TextStyle(fontSize: 14))
            : pw.Text('N° Recibo: $contactInfo', style: pw.TextStyle(fontSize: 16, fontWeight: pw.FontWeight.bold)), // Aumentado a 16

        pw.SizedBox(height: 10),

        // Fecha y hora (original o actual según corresponda)
        if (isReprint) ...[
          // Información de reimpresión
          pw.Text('Fecha original: $currentDate', style: pw.TextStyle(fontSize: 12)),
          pw.Text('Hora original: $currentTime', style: pw.TextStyle(fontSize: 12)),
          pw.SizedBox(height: 5),
          pw.Text(
            'Reimpreso: ${DateFormat('dd/MM/yyyy HH:mm:ss').format(DateTime.now())}',
            style: pw.TextStyle(fontSize: 10, fontStyle: pw.FontStyle.italic),
          ),
        ] else ...[
          // Información original
          pw.Text('Fecha: $currentDate', style: pw.TextStyle(fontSize: 12)),
          pw.Text('Hora: $currentTime', style: pw.TextStyle(fontSize: 12)),
        ],

        // Imagen de pie
        pw.Image(endImage),
      ],
    );
  }

// FUNCIONALIDAD CARGO ANTIGUO (PARA COMPATIBILIDAD)
  Future<void> generateCargoPdf(
      String destinatario,
      String articulo,
      double precio,
      String contactInfo,
      bool isPhone) async {

    await comprobanteModel.incrementComprobante();

    final headImage = await _loadImage('assets/headTicket.png');
    final endImage = await _loadImage('assets/endTicket.png');
    final currentDate = DateFormat('dd/MM/yyyy').format(DateTime.now());
    final currentTime = DateFormat('HH:mm:ss').format(DateTime.now());
    final ticketId = await _getFormattedTicketId();

    // Crear e imprimir copia de cliente
    final clientPdfData = await _generateLegacyPdfDocument(
        headImage,
        endImage,
        destinatario,
        articulo,
        precio,
        contactInfo,
        isPhone,
        currentDate,
        currentTime,
        ticketId,
        'Copia de Cliente',
        false
    );
    await _printPdf(clientPdfData);

    // Crear e imprimir copia de carga
    final cargoPdfData = await _generateLegacyPdfDocument(
        headImage,
        endImage,
        destinatario,
        articulo,
        precio,
        contactInfo,
        isPhone,
        currentDate,
        currentTime,
        ticketId,
        'Copia de Carga',
        false
    );
    await _printPdf(cargoPdfData);

    // Guardar la transacción
    reporteCaja.receiveCargoData(destinatario, precio, ticketId);
  }

// REIMPRIMIR CARGO ANTIGUO
  Future<void> reprintCargoPdf(
      String destinatario,
      String articulo,
      double precio,
      String contactInfo,
      bool isPhone,
      bool printClient,
      bool printCargo) async {

    final headImage = await _loadImage('assets/headTicket.png');
    final endImage = await _loadImage('assets/endTicket.png');
    final currentDate = DateFormat('dd/MM/yyyy').format(DateTime.now());
    final currentTime = DateFormat('HH:mm:ss').format(DateTime.now());
    final ticketId = await _getFormattedTicketId();

    // Imprimir copia de cliente si se solicitó
    if (printClient) {
      final clientPdfData = await _generateLegacyPdfDocument(
          headImage,
          endImage,
          destinatario,
          articulo,
          precio,
          contactInfo,
          isPhone,
          currentDate,
          currentTime,
          ticketId,
          'Copia de Cliente',
          true
      );
      await _printPdf(clientPdfData);
    }

    // Imprimir copia de carga si se solicitó
    if (printCargo) {
      final cargoPdfData = await _generateLegacyPdfDocument(
          headImage,
          endImage,
          destinatario,
          articulo,
          precio,
          contactInfo,
          isPhone,
          currentDate,
          currentTime,
          ticketId,
          'Copia de Carga',
          true
      );
      await _printPdf(cargoPdfData);
    }
  }
}