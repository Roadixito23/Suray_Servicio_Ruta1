import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw; // Importar como 'pw'
import 'dart:typed_data'; // Para manejar Uint8List
import 'package:intl/intl.dart'; // Para formatear la fecha
import 'dart:io'; // Para manejar archivos
import 'package:path_provider/path_provider.dart'; // Para obtener la ruta del directorio
import 'package:shared_preferences/shared_preferences.dart'; // Para manejar preferencias compartidas

Future<Uint8List> generateRecoveryPdf(String dia) async {
  final pdf = pw.Document();

  // Obtener las abreviaturas desde SharedPreferences
  final Map<String, String> abbreviations = await _loadAbbreviations();

  // Contenido del PDF basado en el día
  String contenido = 'Este es el contenido del reporte para el día: $dia'; // Ajusta según sea necesario

  // Añadir una página co n tamaño específico para rollo térmico de 58 mm
  pdf.addPage(
    pw.Page(
      pageFormat: PdfPageFormat(58 * PdfPageFormat.mm, double.infinity),
      build: (pw.Context context) => pw.Column(
        children: [
          pw.Center(
            child: pw.Text('REPORTE SEMANAL', style: pw.TextStyle(fontSize: 16, fontWeight: pw.FontWeight.bold)),
          ),
          pw.SizedBox(height: 5),
          // Mostrar el día de la semana en mayúsculas
          pw.Center(
            child: pw.Text(dia.toUpperCase(), style: pw.TextStyle(fontSize: 14, fontWeight: pw.FontWeight.bold)),
          ),
          pw.SizedBox(height: 5),
          pw.Center(
            child: pw.Text(contenido, style: pw.TextStyle(fontSize: 12)),
          ),
          pw.SizedBox(height: 10),
          // Mostrar abreviaturas
          pw.Text('Abreviaturas:', style: pw.TextStyle(fontSize: 12, fontWeight: pw.FontWeight.bold)),
          pw.SizedBox(height: 5),
          ...abbreviations.entries.map((entry) {
            return pw.Text('${entry.key}: ${entry.value}', style: pw.TextStyle(fontSize: 12));
          }).toList(),
        ],
      ),
    ),
  );

  // Obtener los datos del PDF y guardarlos en el sistema de archivos
  Uint8List pdfData = await pdf.save();
  await _savePdfToLocal(pdfData, dia);

  return pdfData; // Retornar el PDF generado
}

// Función para guardar el PDF en el sistema de archivos
Future<void> _savePdfToLocal(Uint8List pdfData, String dia) async {
  final directory = await getApplicationDocumentsDirectory();
  final filePath = '${directory.path}/reporte_$dia.pdf'; // Definir la ruta del archivo
  final file = File(filePath);

  await file.writeAsBytes(pdfData); // Guardar el PDF
}

// Función para cargar abreviaturas desde SharedPreferences
Future<Map<String, String>> _loadAbbreviations() async {
  final prefs = await SharedPreferences.getInstance();
  return {
    'Público General': prefs.getString('Público General') ?? 'PG',
    'Escolar': prefs.getString('Escolar') ?? 'Esc.',
    'Adulto Mayor': prefs.getString('Adulto Mayor') ?? 'AM',
    'Escolar Intermedio': prefs.getString('Escolar Intermedio') ?? 'Int.E',
    'Intermedio hasta 15 Km': prefs.getString('Intermedio hasta 15 Km') ?? 'Int.15',
    'Intermedio hasta 50 Km': prefs.getString('Intermedio hasta 50 Km') ?? 'Int.50',
    'Oferta Ruta': prefs.getString('Oferta Ruta') ?? 'OR',
    'Cargo': prefs.getString('Cargo') ?? 'Cargo',
  };
}