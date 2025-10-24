import 'dart:typed_data';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:provider/provider.dart';
import 'reporte_recovery.dart';
import '../utils/pdfReport_generator.dart';
import '../utils/ReporteCaja.dart';
import 'package:printing/printing.dart';

class ReporteCajaScreen extends StatefulWidget {
  @override
  _ReporteCajaScreenState createState() => _ReporteCajaScreenState();
}

class _ReporteCajaScreenState extends State<ReporteCajaScreen> {
  bool _isLoading = false;
  bool _showPreviousTransactions = false;

  @override
  void initState() {
    super.initState();
  }

  Future<void> _generatePdfReport() async {
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
        SnackBar(content: Text('Error al generar e imprimir el PDF: $e')),
      );
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  Widget _buildTransactionList(List<Map<String, dynamic>> transactions, bool isPreviousList) {
    String emptyMessage = isPreviousList
        ? 'Sin transacciones anteriores'
        : (Random().nextInt(100) < 23 ? 'Póngase las pilas colega' : 'Sin transacciones el día de hoy');

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
          child: ListTile(
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
        title: Text(
          'Reportes',
          style: TextStyle(
            fontFamily: 'Hemiheads',
            fontSize: 24,
            letterSpacing: 0.75,
          ),
        ),
        backgroundColor: Colors.teal[700],
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
      // Notificación de transacciones de días anteriores
      body: Column(
        children: [
          if (previousTransactions.isNotEmpty)
            Container(
              color: Colors.amber[100],
              padding: EdgeInsets.all(8),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Hay transacciones de días anteriores',
                    style: TextStyle(
                      color: Colors.black87,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  TextButton(
                    onPressed: () {
                      setState(() {
                        _showPreviousTransactions = !_showPreviousTransactions;
                      });
                    },
                    child: Text(
                      _showPreviousTransactions ? 'Ocultar' : 'Ver',
                      style: TextStyle(color: Colors.teal),
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
                  colors: [Colors.teal[50]!, Colors.teal[100]!],
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
                        child: Padding(
                          padding: const EdgeInsets.all(16.0),
                          child: Column(
                            children: [
                              Text(
                                'Total de Ingresos',
                                style: TextStyle(
                                  fontSize: 18,
                                  color: Colors.teal[700],
                                ),
                              ),
                              Text(
                                '\$${reporteCaja.formatValue(totalGeneral)}',
                                style: TextStyle(
                                  fontFamily: 'Hemiheads',
                                  fontSize: 28,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.teal[800],
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
                        'Transacciones de Hoy (${DateFormat('dd/MM/yyyy').format(today)})',
                        style: TextStyle(
                          fontFamily: 'Hemiheads',
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          color: Colors.teal[700],
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
                            color: Colors.teal[700],
                            textBaseline: TextBaseline.alphabetic,
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ),

                      // Lista de transacciones anteriores (si está activado)
                      if (_showPreviousTransactions) ...[
                        SizedBox(height: 16),
                        Text(
                          'Transacciones Anteriores',
                          style: TextStyle(
                            fontFamily: 'Hemiheads',
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                            color: Colors.teal[700],
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
                              color: Colors.teal[700],
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
                    await _generatePdfReport();
                  },
                  style: ElevatedButton.styleFrom(
                    foregroundColor: Colors.white,
                    backgroundColor: Colors.teal[700],
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
                    'Cerrar Caja',
                    style: TextStyle(fontFamily: 'Hemiheads', fontSize: 18),
                  ),
                  onPressed: _isLoading || orderedTransactions.isEmpty ? null : () async {
                    await _generatePdfReport();
                    reporteCaja.clearTransactions();
                  },
                  style: ElevatedButton.styleFrom(
                    foregroundColor: Colors.white,
                    backgroundColor: Colors.greenAccent[700],
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