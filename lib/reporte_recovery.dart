import 'package:flutter/material.dart';
import 'package:pdf/pdf.dart';
import 'package:printing/printing.dart';
import 'dart:io';
import 'package:path_provider/path_provider.dart';
import 'package:intl/intl.dart';
import 'package:intl/date_symbol_data_local.dart';

class RecoveryReport extends StatefulWidget {
  @override
  _RecoveryReportState createState() => _RecoveryReportState();
}

class _RecoveryReportState extends State<RecoveryReport> with SingleTickerProviderStateMixin {
  // Variables para gestionar la retención de archivos
  final int _retentionPeriodDays = 14; // Período de retención: 14 días (sin límite de cantidad)

  List<FileSystemEntity> pdfFiles = [];
  bool isLoading = true;
  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;

  @override
  void initState() {
    super.initState();
    // Inicializar los datos de formato de fecha para español
    initializeDateFormatting('es_ES', null);

    _animationController = AnimationController(
      vsync: this,
      duration: Duration(milliseconds: 800),
    );

    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0)
        .animate(CurvedAnimation(parent: _animationController, curve: Curves.easeIn));

    _loadPdfFiles(); // Cargar los archivos PDF al iniciar
    _animationController.forward();
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  Future<void> _loadPdfFiles() async {
    setState(() {
      isLoading = true;
    });

    try {
      final directory = await getApplicationDocumentsDirectory();
      final List<FileSystemEntity> files = directory.listSync();
      final DateTime cutoffDate = DateTime.now().subtract(Duration(days: _retentionPeriodDays));

      // Filtrar por archivos PDF
      final List<FileSystemEntity> allPdfFiles = files.where((file) => file.path.endsWith('.pdf')).toList();

      // Filtrar archivos más antiguos que 14 días
      List<FileSystemEntity> filesToDelete = [];
      List<FileSystemEntity> filesToKeep = [];

      for (var file in allPdfFiles) {
        final fileStats = File(file.path).statSync();
        final fileDate = fileStats.modified;

        if (fileDate.isBefore(cutoffDate)) {
          // Archivo más antiguo que 14 días
          filesToDelete.add(file);
        } else {
          // Archivo dentro del período de retención
          filesToKeep.add(file);
        }
      }

      // Ordenar por fecha de modificación (más reciente primero)
      filesToKeep.sort((a, b) => File(b.path).lastModifiedSync().compareTo(File(a.path).lastModifiedSync()));

      // Eliminar los archivos marcados para eliminación
      for (var file in filesToDelete) {
        await File(file.path).delete();
      }

      setState(() {
        pdfFiles = filesToKeep;
        isLoading = false;
      });
    } catch (e) {
      setState(() {
        isLoading = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error al cargar archivos: $e')),
      );
    }
  }

  // Obtener la fecha de creación formateada
  String _getFormattedDate(FileSystemEntity file) {
    try {
      final fileStats = File(file.path).statSync();
      final DateTime dateTime = fileStats.modified;
      return DateFormat('dd/MM/yyyy - HH:mm').format(dateTime);
    } catch (e) {
      return 'Fecha desconocida';
    }
  }

  // Formatear el nombre del archivo para mostrar día de semana y fecha
  String _formatFileName(FileSystemEntity file) {
    try {
      final fileStats = File(file.path).statSync();
      final DateTime dateTime = fileStats.modified;
      // Formato: "Lunes 22/Mar"
      final dayOfWeek = _getDayOfWeekInSpanish(dateTime.weekday);
      // Formatear para mostrar el nombre del mes en español con primera letra mayúscula
      final month = DateFormat('MMM', 'es_ES').format(dateTime);
      final capitalizedMonth = month[0].toUpperCase() + month.substring(1);
      return "$dayOfWeek ${dateTime.day}/$capitalizedMonth";
    } catch (e) {
      // Si hay un error, mostrar el nombre del archivo original
      return file.path.split('/').last;
    }
  }

  // Extraer el número del archivo si existe
  String _extractFileNumber(String fileName) {
    // Buscar patrón de número entre paréntesis como (1), (2), etc.
    final RegExp regExp = RegExp(r'\((\d+)\)');
    final match = regExp.firstMatch(fileName);

    if (match != null && match.groupCount >= 1) {
      return match.group(1)!;
    }
    return "";
  }

  // Convertir número de día de la semana a texto en español
  String _getDayOfWeekInSpanish(int weekday) {
    switch (weekday) {
      case 1: return "Lunes";
      case 2: return "Martes";
      case 3: return "Miércoles";
      case 4: return "Jueves";
      case 5: return "Viernes";
      case 6: return "Sábado";
      case 7: return "Domingo";
      default: return "";
    }
  }

  // Calcular los días restantes antes de la eliminación del archivo
  int _getDaysRemainingBeforeDeletion(FileSystemEntity file) {
    try {
      final fileStats = File(file.path).statSync();
      final creationDate = fileStats.modified;
      final expirationDate = creationDate.add(Duration(days: _retentionPeriodDays));
      final now = DateTime.now();

      // Calcular la diferencia en días
      final daysRemaining = expirationDate.difference(now).inDays;

      // Asegurarse de que no devuelva valores negativos
      return daysRemaining > 0 ? daysRemaining : 0;
    } catch (e) {
      return 0;
    }
  }

  // Obtener el color para el indicador de tiempo restante
  Color _getTimeRemainingColor(int daysRemaining) {
    if (daysRemaining > 7) {
      return Colors.green; // Más de 1 semana: verde
    } else if (daysRemaining > 3) {
      return Colors.orange; // Entre 3-7 días: naranja
    } else {
      return Colors.red; // Menos de 3 días: rojo
    }
  }

  // Obtener el tamaño del archivo
  String _getFileSize(FileSystemEntity file) {
    try {
      final fileStats = File(file.path).statSync();
      final sizeInBytes = fileStats.size;

      if (sizeInBytes < 1024) {
        return '${sizeInBytes} B';
      } else if (sizeInBytes < 1024 * 1024) {
        return '${(sizeInBytes / 1024).toStringAsFixed(1)} KB';
      } else {
        return '${(sizeInBytes / (1024 * 1024)).toStringAsFixed(1)} MB';
      }
    } catch (e) {
      return 'Tamaño desconocido';
    }
  }

  Future<void> _printPdf(FileSystemEntity file) async {
    // Mostrar un indicador de progreso con diseño personalizado
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => Dialog(
        backgroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
        child: Padding(
          padding: const EdgeInsets.all(20.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              CircularProgressIndicator(
                valueColor: AlwaysStoppedAnimation<Color>(Colors.teal),
              ),
              SizedBox(height: 20),
              Text(
                'Enviando a impresora...',
                style: TextStyle(fontSize: 16),
              ),
            ],
          ),
        ),
      ),
    );

    try {
      final pdfData = await File(file.path).readAsBytes(); // Leer el archivo PDF

      // Imprimir el PDF
      await Printing.layoutPdf(
        onLayout: (PdfPageFormat format) async {
          return pdfData;
        },
        format: PdfPageFormat(58 * PdfPageFormat.mm, double.infinity), // Tamaño de rollo de 58 mm
      );

      // Mostrar mensaje de éxito
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Documento enviado a impresora'),
          backgroundColor: Colors.green,
          duration: Duration(seconds: 2),
        ),
      );
    } catch (e) {
      // Mostrar un mensaje de error
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error al imprimir el PDF: $e'),
          backgroundColor: Colors.red,
          duration: Duration(seconds: 3),
        ),
      );
    } finally {
      // Cerrar el indicador de progreso
      Navigator.of(context).pop(); // Cerrar el diálogo de carga
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          'Reporte Semanal',
          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 22),
        ),
        backgroundColor: Colors.teal.shade600,
        elevation: 8,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(bottom: Radius.circular(15)),
        ),
        actions: [
          IconButton(
            icon: Icon(Icons.refresh),
            tooltip: 'Actualizar',
            onPressed: _loadPdfFiles,
          ),
          IconButton(
            icon: Icon(Icons.info_outline),
            tooltip: 'Información',
            onPressed: () {
              showDialog(
                context: context,
                builder: (context) => AlertDialog(
                  title: Text('Información', style: TextStyle(color: Colors.teal)),
                  content: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Esta sección le permite ver e imprimir los reportes semanales generados por el sistema.'),
                      SizedBox(height: 12),
                      Text('Política de retención:', style: TextStyle(fontWeight: FontWeight.bold)),
                      Text('• Se conservan todos los reportes de los últimos $_retentionPeriodDays días.'),
                      Text('• Los reportes más antiguos se eliminan automáticamente.'),
                      SizedBox(height: 8),
                      Row(
                        children: [
                          Icon(Icons.circle, size: 12, color: Colors.green),
                          SizedBox(width: 4),
                          Text('Más de 7 días restantes'),
                        ],
                      ),
                      Row(
                        children: [
                          Icon(Icons.circle, size: 12, color: Colors.orange),
                          SizedBox(width: 4),
                          Text('Entre 3-7 días restantes'),
                        ],
                      ),
                      Row(
                        children: [
                          Icon(Icons.circle, size: 12, color: Colors.red),
                          SizedBox(width: 4),
                          Text('Menos de 3 días restantes'),
                        ],
                      ),
                    ],
                  ),
                  actions: [
                    TextButton(
                      child: Text('OK', style: TextStyle(color: Colors.teal)),
                      onPressed: () => Navigator.of(context).pop(),
                    ),
                  ],
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
                ),
              );
            },
          ),
        ],
      ),
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Colors.teal.shade50, Colors.white],
          ),
        ),
        child: FadeTransition(
          opacity: _fadeAnimation,
          child: isLoading
              ? Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                CircularProgressIndicator(valueColor: AlwaysStoppedAnimation<Color>(Colors.teal)),
                SizedBox(height: 20),
                Text('Cargando reportes...', style: TextStyle(fontSize: 16, color: Colors.teal.shade700)),
              ],
            ),
          )
              : pdfFiles.isEmpty
              ? Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.folder_open, size: 80, color: Colors.teal.withOpacity(0.4)),
                SizedBox(height: 16),
                Text(
                  'No hay archivos PDF guardados',
                  style: TextStyle(fontSize: 18, color: Colors.teal.shade700),
                ),
                SizedBox(height: 8),
                Text(
                  'Los reportes semanales se generarán automáticamente',
                  style: TextStyle(fontSize: 14, color: Colors.grey.shade700),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          )
              : ListView.builder(
            itemCount: pdfFiles.length,
            padding: EdgeInsets.all(12),
            itemBuilder: (context, index) {
              final file = pdfFiles[index];
              final originalFileName = file.path.split('/').last;
              final formattedFileName = _formatFileName(file);
              final fileNumber = _extractFileNumber(originalFileName);

              return Card(
                margin: EdgeInsets.symmetric(vertical: 8, horizontal: 4),
                elevation: 4,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                child: InkWell(
                  borderRadius: BorderRadius.circular(12),
                  onTap: () {
                    // Opcional: mostrar previsualización o más opciones
                    showModalBottomSheet(
                      context: context,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
                      ),
                      builder: (context) => Container(
                        padding: EdgeInsets.all(20),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              fileNumber.isNotEmpty
                                  ? '$formattedFileName - Reporte #$fileNumber'
                                  : formattedFileName,
                              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                              textAlign: TextAlign.center,
                            ),
                            Text(
                              originalFileName,
                              style: TextStyle(fontSize: 14, color: Colors.grey),
                              textAlign: TextAlign.center,
                            ),
                            SizedBox(height: 20),
                            ListTile(
                              leading: Icon(Icons.print, color: Colors.teal),
                              title: Text('Imprimir reporte'),
                              onTap: () {
                                Navigator.pop(context);
                                _printPdf(file);
                              },
                            ),
                            ListTile(
                              leading: Icon(Icons.remove_red_eye, color: Colors.blue),
                              title: Text('Ver detalles'),
                              onTap: () {
                                Navigator.pop(context);
                                // Implementar visualización de detalles aquí
                              },
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                  child: Padding(
                    padding: const EdgeInsets.all(12.0),
                    child: Row(
                      children: [
                        Container(
                          padding: EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: Colors.teal.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Stack(
                            alignment: Alignment.center,
                            children: [
                              Icon(
                                Icons.picture_as_pdf,
                                color: Colors.red.shade700,
                                size: 32,
                              ),
                              if (fileNumber.isNotEmpty)
                                Positioned(
                                  right: -5,
                                  top: -5,
                                  child: Container(
                                    padding: EdgeInsets.all(4),
                                    decoration: BoxDecoration(
                                      color: Colors.teal,
                                      shape: BoxShape.circle,
                                    ),
                                    child: Text(
                                      fileNumber,
                                      style: TextStyle(
                                        color: Colors.white,
                                        fontSize: 10,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ),
                                ),
                            ],
                          ),
                        ),
                        SizedBox(width: 16),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Expanded(
                                    child: Text(
                                      formattedFileName,
                                      style: TextStyle(
                                        fontSize: 16,
                                        fontWeight: FontWeight.bold,
                                      ),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                  if (fileNumber.isNotEmpty)
                                    Container(
                                      margin: EdgeInsets.only(left: 4),
                                      padding: EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                      decoration: BoxDecoration(
                                        color: Colors.teal.shade100,
                                        borderRadius: BorderRadius.circular(4),
                                      ),
                                      child: Text(
                                        '#$fileNumber',
                                        style: TextStyle(
                                          fontSize: 12,
                                          fontWeight: FontWeight.bold,
                                          color: Colors.teal.shade800,
                                        ),
                                      ),
                                    ),
                                ],
                              ),
                              SizedBox(height: 4),
                              Row(
                                children: [
                                  Icon(Icons.timer, size: 14, color:
                                  _getTimeRemainingColor(_getDaysRemainingBeforeDeletion(file))),
                                  SizedBox(width: 4),
                                  Text(
                                    'Se elimina en ${_getDaysRemainingBeforeDeletion(file)} días',
                                    style: TextStyle(
                                      fontSize: 12,
                                      fontWeight: FontWeight.bold,
                                      color: _getTimeRemainingColor(_getDaysRemainingBeforeDeletion(file)),
                                    ),
                                  ),
                                ],
                              ),
                              SizedBox(height: 4),
                              Row(
                                children: [
                                  Icon(Icons.access_time, size: 14, color: Colors.grey),
                                  SizedBox(width: 4),
                                  Text(
                                    _getFormattedDate(file),
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: Colors.grey.shade700,
                                    ),
                                  ),
                                ],
                              ),
                              SizedBox(height: 2),
                              Row(
                                children: [
                                  Icon(Icons.data_usage, size: 14, color: Colors.grey),
                                  SizedBox(width: 4),
                                  Text(
                                    _getFileSize(file),
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: Colors.grey.shade700,
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                        IconButton(
                          icon: Icon(Icons.print, color: Colors.teal),
                          tooltip: 'Imprimir',
                          onPressed: () => _printPdf(file),
                        ),
                      ],
                    ),
                  ),
                ),
              );
            },
          ),
        ),
      ),
    );
  }
}