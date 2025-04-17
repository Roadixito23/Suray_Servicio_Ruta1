import 'dart:typed_data';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:provider/provider.dart';
import 'package:untitled3/reporte_recovery.dart';
import 'pdfReport_generator.dart';
import 'ReporteCaja.dart';
import 'package:printing/printing.dart';

class EmergencyReportScreen extends StatefulWidget {
  @override
  _EmergencyReportScreenState createState() => _EmergencyReportScreenState();
}

class _EmergencyReportScreenState extends State<EmergencyReportScreen> {
  bool _isLoading = false;
  bool _showPreviousTransactions = false;

  @override
  void initState() {
    super.initState();
  }

  Future<void> _generateEmergencyPdfReport() async {
    setState(() {
      _isLoading = true;
    });

    final reporteCaja = Provider.of<ReporteCaja>(context, listen: false);
    final pdfGenerator = PdfReportGenerator();

    var orderedTransactions = reporteCaja.getOrderedTransactions();
    double total = reporteCaja.totalIngresos;

    DateTime reportDate = DateTime.now();
    try {
      Uint8List pdfData = await pdfGenerator.generatePdf(orderedTransactions, total, reportDate);
      await Printing.layoutPdf(
        onLayout: (PdfPageFormat format) async {
          return pdfData;
        },
        format: PdfPageFormat(58 * PdfPageFormat.mm, double.infinity),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error al generar e imprimir el PDF de emergencia: $e')),
      );
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  Widget _buildTransactionList(List<Map<String, dynamic>> transactions, bool isPreviousList) {
    String emptyMessage = isPreviousList
        ? 'Sin transacciones anteriores en modo emergencia'
        : 'Sin transacciones de emergencia hoy';

    return transactions.isNotEmpty
        ? ListView.builder(
      shrinkWrap: true,
      physics: NeverScrollableScrollPhysics(),
      itemCount: transactions.length,
      itemBuilder: (context, index) {
        var transaccion = transactions[index];
        bool isAnulacion = transaccion['nombre'].toString().startsWith('Anulación:');
        return Card(
          elevation: 2,
          margin: EdgeInsets.symmetric(vertical: 4, horizontal: 8),
          color: Colors.red[50], // Fondo ligeramente rojo para indicar emergencia
          child: ListTile(
            leading: Icon(Icons.warning_amber_rounded, color: Colors.red),
            title: Text(
              transaccion['nombre'] ?? 'Sin nombre',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            subtitle: Text('Hora: ${transaccion['hora'] ?? 'Sin hora'}'),
            trailing: Text(
              isAnulacion
                  ? '-\$${Provider.of<ReporteCaja>(context).formatValue((transaccion['valor'] ?? 0.0).abs())}'
                  : '\$${Provider.of<ReporteCaja>(context).formatValue(transaccion['valor'] ?? 0.0)}',
              style: TextStyle(
                color: isAnulacion ? Colors.red : Colors.green,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        );
      },
    )
        : Center(
      child: Text(
        emptyMessage,
        style: TextStyle(
          fontSize: 18,
          fontWeight: FontWeight.bold,
          color: Colors.grey[600],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final reporteCaja = Provider.of<ReporteCaja>(context);
    var orderedTransactions = reporteCaja.getOrderedTransactions();

    // Filtrar transacciones de hoy y de días anteriores
    DateTime today = DateTime.now();
    String todayDay = DateFormat('dd').format(today);
    String todayMonth = DateFormat('MM').format(today);

    var todayTransactions = <Map<String, dynamic>>[];
    var previousTransactions = <Map<String, dynamic>>[];

    for (var t in orderedTransactions) {
      String transactionDay = t['dia'] ?? '';
      String transactionMonth = t['mes'] ?? '';

      // Comparar día y mes
      if (transactionDay == todayDay && transactionMonth == todayMonth) {
        todayTransactions.add(t);
      } else {
        previousTransactions.add(t);
      }
    }

    // Calcular totales con anulaciones incluidas
    double todayTotal = todayTransactions.fold(0, (sum, t) => sum + (t['valor'] ?? 0.0));
    double previousTotal = previousTransactions.fold(0, (sum, t) => sum + (t['valor'] ?? 0.0));

    // Calcular el total general (usar directamente el valor del modelo)
    double totalGeneral = reporteCaja.totalIngresos;

    return Scaffold(
      appBar: AppBar(
        title: Row(
          children: [
            Icon(Icons.warning_amber_rounded, color: Colors.white),
            SizedBox(width: 8),
            Text(
              'Reportes de Emergencia',
              style: TextStyle(
                fontFamily: 'Hemiheads',
                fontSize: 22,
                letterSpacing: 0.75,
              ),
            ),
          ],
        ),
        backgroundColor: Colors.red[700],
        elevation: 0,
        actions: [
          // Botón para ordenar transacciones de antiguo a más actual
          IconButton(
            icon: Icon(reporteCaja.isAscending ? Icons.arrow_upward : Icons.arrow_downward),
            onPressed: () {
              reporteCaja.toggleOrder();
            },
          ),
          // Botón para recuperar reportes anteriores
          IconButton(
            icon: Icon(Icons.calendar_today),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => RecoveryReport()),
              );
            },
          ),
        ],
      ),
      // Notificación del modo de emergencia
      body: Column(
        children: [
          Container(
            color: Colors.red[100],
            padding: EdgeInsets.all(8),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    Icon(Icons.warning_amber_rounded, color: Colors.red[900]),
                    SizedBox(width: 8),
                    Text(
                      'MODO EMERGENCIA ACTIVADO',
                      style: TextStyle(
                        color: Colors.red[900],
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
                if (previousTransactions.isNotEmpty)
                  TextButton(
                    onPressed: () {
                      setState(() {
                        _showPreviousTransactions = !_showPreviousTransactions;
                      });
                    },
                    child: Text(
                      _showPreviousTransactions ? 'Ocultar' : 'Ver Anteriores',
                      style: TextStyle(color: Colors.red[900]),
                    ),
                  ),
              ],
            ),
          ),
          Expanded(
            child: Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [Colors.red[50]!, Colors.red[100]!],
                ),
              ),
              child: SingleChildScrollView(
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      // Tarjeta de total de ingresos
                      Card(
                        elevation: 4,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        color: Colors.white,
                        child: Padding(
                          padding: const EdgeInsets.all(16.0),
                          child: Column(
                            children: [
                              Text(
                                'Total de Emergencia',
                                style: TextStyle(
                                  fontSize: 18,
                                  color: Colors.red[700],
                                ),
                              ),
                              Text(
                                '\$${reporteCaja.formatValue(totalGeneral)}',
                                style: TextStyle(
                                  fontFamily: 'Hemiheads',
                                  fontSize: 28,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.red[800],
                                  letterSpacing: 1.1,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      SizedBox(height: 16),

                      // Título de transacciones de hoy
                      Text(
                        'Emergencias de Hoy (${DateFormat('dd/MM/yyyy').format(today)})',
                        style: TextStyle(
                          fontFamily: 'Hemiheads',
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          color: Colors.red[700],
                        ),
                        textAlign: TextAlign.center,
                      ),
                      SizedBox(height: 10),

                      // Lista de transacciones de hoy
                      _buildTransactionList(todayTransactions, false),

                      // Total de transacciones de hoy
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 8.0),
                        child: Text(
                          'Total de Hoy: \$${reporteCaja.formatValue(todayTotal)}',
                          style: TextStyle(
                            fontFamily: 'Hemiheads',
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                            color: Colors.red[700],
                            textBaseline: TextBaseline.alphabetic,
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ),

                      // Lista de transacciones anteriores (si está activado)
                      if (_showPreviousTransactions) ...[
                        SizedBox(height: 16),
                        Text(
                          'Emergencias Anteriores',
                          style: TextStyle(
                            fontFamily: 'Hemiheads',
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                            color: Colors.red[700],
                          ),
                          textAlign: TextAlign.center,
                        ),
                        _buildTransactionList(previousTransactions, true),
                        Padding(
                          padding: const EdgeInsets.symmetric(vertical: 8.0),
                          child: Text(
                            'Total Anteriores: \$${reporteCaja.formatValue(previousTotal)}',
                            style: TextStyle(
                              fontFamily: 'Hemiheads',
                              fontSize: 20,
                              fontWeight: FontWeight.bold,
                              color: Colors.red[700],
                            ),
                            textAlign: TextAlign.center,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            ),
          ),

          // Botones de acciones
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                ElevatedButton.icon(
                  icon: Icon(Icons.print),
                  label: Text(
                    'Reporte',
                    style: TextStyle(fontFamily: 'Hemiheads', fontSize: 18),
                  ),
                  onPressed: _isLoading || orderedTransactions.isEmpty ? null : () async {
                    await _generateEmergencyPdfReport();
                  },
                  style: ElevatedButton.styleFrom(
                    foregroundColor: Colors.white,
                    backgroundColor: Colors.red[700],
                    padding: EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                ),
                SizedBox(width: 16),
                ElevatedButton.icon(
                  icon: Icon(Icons.close),
                  label: Text(
                    'Cerrar Emergencia',
                    style: TextStyle(fontFamily: 'Hemiheads', fontSize: 18),
                  ),
                  onPressed: _isLoading || orderedTransactions.isEmpty ? null : () async {
                    await _generateEmergencyPdfReport();
                    reporteCaja.clearTransactions();

                    // Mostrar diálogo de confirmación
                    showDialog(
                      context: context,
                      builder: (BuildContext context) {
                        return AlertDialog(
                          title: Row(
                            children: [
                              Icon(Icons.check_circle, color: Colors.green),
                              SizedBox(width: 8),
                              Text('Emergencia Cerrada'),
                            ],
                          ),
                          content: Text('El reporte de emergencia ha sido generado y la caja ha sido cerrada.'),
                          actions: [
                            TextButton(
                              onPressed: () {
                                Navigator.of(context).pop();
                                Navigator.of(context).pop(); // Vuelve a la pantalla principal
                              },
                              child: Text('OK'),
                            ),
                          ],
                        );
                      },
                    );
                  },
                  style: ElevatedButton.styleFrom(
                    foregroundColor: Colors.white,
                    backgroundColor: Colors.deepOrange[700],
                    padding: EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}