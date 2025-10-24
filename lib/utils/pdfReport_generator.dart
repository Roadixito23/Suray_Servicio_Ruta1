import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw; // Importar como 'pw'
import 'dart:typed_data'; // Para manejar Uint8List
import 'package:intl/intl.dart'; // Para formatear la fecha
import 'package:shared_preferences/shared_preferences.dart'; // Importar para SharedPreferences
import 'dart:io'; // Para manejar archivos
import 'package:path_provider/path_provider.dart'; // Para obtener la ruta del directorio

class PdfReportGenerator {
  Future<Uint8List> generatePdf(List<Map<String, dynamic>> transactions, double total, DateTime reportDate) async {
    final pdf = pw.Document();

    // Formatear el total
    String formattedTotal = NumberFormat('#,##0', 'es_ES').format(total);

    // Ordenar las transacciones de más antiguas a más nuevas
    transactions.sort((a, b) => a['id'].compareTo(b['id']));

    // Cargar las abreviaturas desde SharedPreferences
    Map<String, String> abbreviations = await _loadAbbreviations();

    // Asignar abreviaturas y filtrar transacciones
    for (var transaction in transactions) {
      if (transaction['nombre'].toString().startsWith('Anulación:')) {
        transaction['abbreviation'] = 'Anula';
      } else {
        String nombre = transaction['nombre'].toString();
        // Mejorado: Manejar el caso especial de Escolar Intermedio con mayor flexibilidad
        if (nombre.toLowerCase().contains('escolar') &&
            (nombre.toLowerCase().contains('intermedio') || nombre.toLowerCase().contains('int'))) {
          transaction['abbreviation'] = abbreviations['Escolar Intermedio'] ?? 'Int.E';
        } else if (nombre.startsWith('Cargo:')) {
          transaction['abbreviation'] = abbreviations['Cargo'] ?? 'Cargo';
        } else {
          // Buscar la abreviatura por el nombre exacto o intentar buscar coincidencias parciales
          transaction['abbreviation'] = _findBestAbbreviation(nombre, abbreviations);
        }
      }
    }

    // Filtrar transacciones según tipo
    var pasajeTransactions = transactions.where((t) =>
    !t['nombre'].toString().startsWith('Anulación:') &&
        !t['nombre'].toString().startsWith('Cargo:')).toList();

    var correspondenceTransactions = transactions.where((t) =>
        t['nombre'].toString().startsWith('Cargo:')).toList();

    var annulledTransactions = transactions.where((t) =>
        t['nombre'].toString().startsWith('Anulación:')).toList();

    // Obtener el ID antes de agregar la página
    String ticketId = await _getTicketId();

    // Obtener el día de la semana actual
    String diaDeLaSemana = DateFormat('EEEE', 'es_ES').format(DateTime.now()).toUpperCase();

    // Añadir página
    pdf.addPage(
      pw.Page(
        pageFormat: PdfPageFormat(58 * PdfPageFormat.mm, double.infinity),
        build: (pw.Context context) {
          // Función para crear tablas
          pw.Widget buildTable(String title, List<Map<String, dynamic>> transactionList) {
            if (transactionList.isEmpty) {
              return pw.Column(
                children: [
                  pw.Text(title, style: pw.TextStyle(fontSize: 14, fontWeight: pw.FontWeight.bold)),
                  pw.SizedBox(height: 5),
                  pw.Text('No hay transacciones', style: pw.TextStyle(fontSize: 12)),
                  pw.SizedBox(height: 10),
                ],
              );
            }

            // Calcular el total de la sección
            double totalValue = transactionList.fold(0, (sum, transaction) => sum + (transaction['valor'] ?? 0));
            String formattedTotalValue = NumberFormat('#,##0', 'es_ES').format(totalValue.abs());

            // Para anulaciones, mostrar el signo negativo en el formato
            String signPrefix = title == 'Anulación' ? '-' : '';

            return pw.Column(
              children: [
                pw.Text(title, style: pw.TextStyle(fontSize: 14, fontWeight: pw.FontWeight.bold)),
                pw.SizedBox(height: 5),
                pw.Table(
                  border: pw.TableBorder.all(),
                  columnWidths: {
                    0: pw.FlexColumnWidth(0.8),
                    1: pw.FlexColumnWidth(0.7),
                    2: pw.FlexColumnWidth(1.05),
                    3: pw.FlexColumnWidth(1.3),
                    4: pw.FlexColumnWidth(1.6),
                  },
                  children: [
                    // Encabezados de tabla
                    pw.TableRow(
                      children: [
                        pw.Padding(padding: const pw.EdgeInsets.all(4), child: pw.Text('N°C', style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 8))),
                        pw.Padding(padding: const pw.EdgeInsets.all(4), child: pw.Text('Día', style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 8))), // Nuevo encabezado
                        pw.Padding(padding: const pw.EdgeInsets.all(4), child: pw.Text('Hora', style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 8))),
                        pw.Padding(padding: const pw.EdgeInsets.all(4), child: pw.Text('Tipo', style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 8))),
                        pw.Padding(padding: const pw.EdgeInsets.all(4), child: pw.Text('Valor', style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 8))),
                      ],
                    ),
                    // Filas de transacciones
                    ...transactionList.map((transaction) {
                      String comprobante = transaction['comprobante'] ?? 'N/A';
                      String formattedComprobante = formatComprobante(comprobante);
                      String hora = transaction['hora'] ?? 'N/A';
                      // Asegurar que el valor se muestre positivo en la tabla, incluso para anulaciones
                      double displayValue = (transaction['valor'] ?? 0).abs();
                      String formattedValue = NumberFormat('#,##0', 'es_ES').format(displayValue);
                      String abbreviatedType = transaction['abbreviation'];
                      String dia = transaction['dia'] ?? 'N/A'; // Obtener el día de la transacción

                      // Para anulaciones en la tabla, prefija el signo negativo
                      String valuePrefix = title == 'Anulación' ? '-' : '';

                      return pw.TableRow(
                        children: [
                          pw.Padding(
                            padding: const pw.EdgeInsets.all(4),
                            child: pw.Text(formattedComprobante, textAlign: pw.TextAlign.left, overflow: pw.TextOverflow.clip, style: pw.TextStyle(fontSize: 9)),
                          ),
                          pw.Padding(
                            padding: const pw.EdgeInsets.all(4),
                            child: pw.Text(dia, textAlign: pw.TextAlign.left, overflow: pw.TextOverflow.clip, style: pw.TextStyle(fontSize: 9)), // Mostrar el día
                          ),
                          pw.Padding(
                            padding: const pw.EdgeInsets.all(4),
                            child: pw.Text(hora, textAlign: pw.TextAlign.left, overflow: pw.TextOverflow.clip, style: pw.TextStyle(fontSize: 9)),
                          ),
                          pw.Padding(
                            padding: const pw.EdgeInsets.all(4),
                            child: pw.Text(abbreviatedType, textAlign: pw.TextAlign.left, overflow: pw.TextOverflow.clip, style: pw.TextStyle(fontSize: 9)),
                          ),
                          pw.Padding(
                            padding: const pw.EdgeInsets.all(4),
                            child: pw.Text('$valuePrefix\$${formattedValue}', textAlign: pw.TextAlign.right, style: pw.TextStyle(fontSize: 9)),
                          ),
                        ],
                      );
                    }).toList(),
                  ],
                ),
                pw.SizedBox(height: 5),
                // Mostrar total
                pw.Text('Total: $signPrefix\$${formattedTotalValue}', style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
                pw.SizedBox(height: 10),
              ],
            );
          }

          // Calcular el total de ingresos de hoy
          DateTime today = DateTime.now();
          String todayDay = today.day.toString();
          String todayMonth = today.month.toString();

          double totalPasajes = pasajeTransactions.fold(0.0, (sum, t) => sum + (t['valor'] ?? 0.0));
          double totalCorrespondencia = correspondenceTransactions.fold(0.0, (sum, t) => sum + (t['valor'] ?? 0.0));
          double totalAnulaciones = annulledTransactions.fold(0.0, (sum, t) => sum + (t['valor'] ?? 0.0));

          // Calcular el total de ingresos acumulado
          double totalAcumulado = totalPasajes + totalCorrespondencia + totalAnulaciones;

          // El totalAcumulado debe ser igual al 'total' pasado como parámetro (para verificación)
          if (totalAcumulado.toStringAsFixed(2) != total.toStringAsFixed(2)) {
            print("Advertencia: Diferencia entre total calculado ($totalAcumulado) y total pasado ($total)");
          }

          return pw.Column(
            children: [
              // Título centrado
              pw.Align(
                alignment: pw.Alignment.center,
                child: pw.Text('REPORTE DE PALOMAS', style: pw.TextStyle(fontSize: 13, fontWeight: pw.FontWeight.bold)),
              ),
              pw.SizedBox(height: 5),
              // Día de la semana centrado
              pw.Center(
                child: pw.Text(diaDeLaSemana, style: pw.TextStyle(fontSize: 14, fontWeight: pw.FontWeight.bold)), // Día en mayúsculas
              ),
              pw.SizedBox(height: 5),
              // ID y Fecha centrados
              pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Text('ID: $ticketId', style: pw.TextStyle(fontSize: 12)), // Mostrar ID
                  pw.Text('Fecha: ${DateFormat('dd/MM/yyyy HH:mm').format(reportDate)}', style: pw.TextStyle(fontSize: 12)),
                ],
              ),
              pw.SizedBox(height: 5),
              // Total acumulado (usando el valor pasado como parámetro)
              pw.Center(
                child: pw.Text('Total de Ingresos: \$${NumberFormat('#,##0', 'es_ES').format(total)}', style: pw.TextStyle(fontSize: 16, fontWeight: pw.FontWeight.bold)),
              ),
              pw.SizedBox(height: 5),

              // Construir las tablas
              buildTable('Pasajes', pasajeTransactions),
              buildTable('Correspondencias', correspondenceTransactions),
              buildTable('Anulaciones', annulledTransactions), // Nueva tabla para anulaciones

              // Mensaje si no hay anulaciones
              if (annulledTransactions.isEmpty)
                pw.Text('Sin anulaciones el día de Hoy', style: pw.TextStyle(fontSize: 12, fontStyle: pw.FontStyle.italic)),

              // Margen en la parte inferior
              pw.SizedBox(height: 69), // Espacio de margen

              // Barra negra
              pw.Container(
                width: double.infinity,
                height: 2,
                color: PdfColors.black,
              ),
            ],
          );
        },
      ),
    );

    // Guardar el PDF generado
    Uint8List pdfData = await pdf.save(); // Esperar el resultado del PDF
    await _savePdfToLocal(pdfData, diaDeLaSemana, reportDate); // Llamar a la función para guardar el PDF

    // Guardar información del día
    await _saveDailyReport(diaDeLaSemana, reportDate, ticketId, correspondenceTransactions, pasajeTransactions, annulledTransactions);

    return pdfData; // Retornar el PDF generado
  }

  // NUEVA FUNCIÓN: Encuentra la mejor abreviatura para un nombre de ticket
  String _findBestAbbreviation(String nombre, Map<String, String> abbreviations) {
    // Intenta encontrar la abreviatura exacta primero
    if (abbreviations.containsKey(nombre)) {
      return abbreviations[nombre]!;
    }

    // Convertir a minúsculas para comparaciones menos estrictas
    String lowerNombre = nombre.toLowerCase();

    // Buscar coincidencias parciales
    if (lowerNombre.contains('público') || lowerNombre.contains('general')) {
      return abbreviations['Público General'] ?? 'PG';
    }
    if (lowerNombre.contains('escolar') && !lowerNombre.contains('intermedio')) {
      return abbreviations['Escolar General'] ?? 'Esc.';
    }
    if (lowerNombre.contains('adulto') || lowerNombre.contains('mayor')) {
      return abbreviations['Adulto Mayor'] ?? 'AM';
    }
    if (lowerNombre.contains('intermedio') || lowerNombre.contains('int')) {
      if (lowerNombre.contains('15')) {
        return abbreviations['Intermedio hasta 15 Km'] ?? 'Int.15';
      }
      if (lowerNombre.contains('50')) {
        return abbreviations['Intermedio hasta 50 Km'] ?? 'Int.50';
      }
    }
    if (lowerNombre.contains('oferta') || lowerNombre.contains('ruta')) {
      return abbreviations['Oferta Ruta'] ?? 'OR';
    }

    // Si no se encuentra coincidencia, devolver el nombre original
    return nombre;
  }

  // Función para cargar abreviaturas desde SharedPreferences
  Future<Map<String, String>> _loadAbbreviations() async {
    final prefs = await SharedPreferences.getInstance();

    return {
      'Público General': prefs.getString('Público General') ?? 'PG',
      'Escolar General': prefs.getString('Escolar General') ?? 'Esc.',
      'Adulto Mayor': prefs.getString('Adulto Mayor') ?? 'AM',
      'Escolar Intermedio': prefs.getString('Escolar Intermedio') ?? 'Int.E',
      'Intermedio hasta 15 Km': prefs.getString('Intermedio hasta 15 Km') ?? 'Int.15',
      'Int. hasta 15 Km': prefs.getString('Intermedio hasta 15 Km') ?? 'Int.15',  // Variante adicional
      'Intermedio hasta 50 Km': prefs.getString('Intermedio hasta 50 Km') ?? 'Int.50',
      'Int. hasta 50 Km': prefs.getString('Intermedio hasta 50 Km') ?? 'Int.50',  // Variante adicional
      'Oferta Ruta': prefs.getString('Oferta Ruta') ?? 'OR',
      'Cargo': prefs.getString('Cargo') ?? 'Cargo',
    };
  }

  // Función para guardar el informe del día
  Future<void> _saveDailyReport(String diaDeLaSemana, DateTime reportDate, String ticketId, List<Map<String, dynamic>> correspondenceTransactions, List<Map<String, dynamic>> pasajeTransactions, List<Map<String, dynamic>> annulledTransactions) async {
    double totalCorrespondencia = correspondenceTransactions.fold(0, (sum, t) => sum + (t['valor'] ?? 0));
    double totalPasaje = pasajeTransactions.fold(0, (sum, t) => sum + (t['valor'] ?? 0));
    double totalAnulacion = annulledTransactions.fold(0, (sum, t) => sum + (t['valor'] ?? 0));

    double totalDelDia = totalCorrespondencia + totalPasaje + totalAnulacion;

    final directory = await getApplicationDocumentsDirectory();
    final filePath = '${directory.path}/informe_dia_${DateFormat('yyyyMMdd').format(reportDate)}.txt';
    final file = File(filePath);

    String reportContent = '''
Día de la semana: $diaDeLaSemana
Fecha: ${DateFormat('dd/MM/yyyy').format(reportDate)}
ID: $ticketId
Total Correspondencia: \$${totalCorrespondencia.toStringAsFixed(2)}
Total Pasaje: \$${totalPasaje.toStringAsFixed(2)}
Total Anulación: \$${totalAnulacion.toStringAsFixed(2)}
Total del Día: \$${totalDelDia.toStringAsFixed(2)}
''';

    await file.writeAsString(reportContent); // Guardar el contenido en un archivo
  }

  // Función para obtener el ID del ticket desde SharedPreferences
  Future<String> _getTicketId() async {
    final prefs = await SharedPreferences.getInstance();
    int ticketId = prefs.getInt('ticketId') ?? 1; // Obtiene el ID actual o establece en 1
    return ticketId.toString(); // Retorna el ID como cadena
  }

  // Función para formatear el comprobante
  String formatComprobante(String comprobante) {
    // Eliminar el prefijo '01-' si existe
    comprobante = comprobante.replaceAll(RegExp(r'^01-'), '');

    // Truncar ceros a la izquierda
    final regexZeros = RegExp(r'^(0+)?(\d+)$');
    final matchZeros = regexZeros.firstMatch(comprobante);
    if (matchZeros != null) {
      return matchZeros.group(2) ?? comprobante; // Retornar el número sin ceros a la izquierda
    }

    // Si el formato no coincide, retornar el comprobante original
    return comprobante;
  }

  // Función mejorada para guardar PDF con manejo de múltiples archivos por día
  Future<void> _savePdfToLocal(Uint8List pdfData, String diaDeLaSemana, DateTime reportDate) async {
    final directory = await getApplicationDocumentsDirectory();
    final String formattedDia = diaDeLaSemana.toUpperCase();
    final String datePrefix = '${reportDate.day}_${reportDate.month}_${reportDate.year.toString().substring(2)}';
    final String baseFileName = 'reporte_${formattedDia}_$datePrefix';

    // Buscar archivos existentes con el mismo patrón base para este día
    final List<FileSystemEntity> files = directory.listSync();
    final RegExp regExp = RegExp(r'^reporte_' + formattedDia + r'_' + datePrefix + r'(?:\((\d+)\))?.pdf$');

    // Lista para almacenar nombres de archivos y sus números secuenciales
    List<MapEntry<String, int>> existingFiles = [];

    // Identificar archivos existentes y extraer su número secuencial
    for (var file in files) {
      String fileName = file.path.split('/').last;
      final match = regExp.firstMatch(fileName);

      if (match != null) {
        int numero = 1; // Por defecto, si no hay número es el primero
        if (match.groupCount >= 1 && match.group(1) != null) {
          numero = int.parse(match.group(1)!);
        }
        existingFiles.add(MapEntry(file.path, numero));
      }
    }

    // Determinar el número para el nuevo archivo
    int nuevoNumero = 1;
    if (existingFiles.isNotEmpty) {
      // Encontrar el número más alto usado
      nuevoNumero = existingFiles.map((e) => e.value).reduce((max, value) => value > max ? value : max) + 1;

      // Renombrar los archivos existentes sin número para que tengan (1)
      for (var entry in existingFiles) {
        String originalPath = entry.key;
        String originalName = originalPath.split('/').last;

        // Si el archivo no tiene número en su nombre (número == 1 pero no tiene paréntesis)
        if (entry.value == 1 && !originalName.contains('(1)')) {
          String newName = originalName.replaceAll('.pdf', '(1).pdf');
          File(originalPath).renameSync('${directory.path}/$newName');
        }
      }
    }

    // Crear el nuevo nombre de archivo con el número
    String newFileName = '$baseFileName(${nuevoNumero}).pdf';
    final filePath = '${directory.path}/$newFileName';
    final file = File(filePath);

    await file.writeAsBytes(pdfData);
  }
}