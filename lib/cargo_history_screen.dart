import 'dart:io';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:printing/printing.dart';
import 'package:pdf/pdf.dart';
import 'cargo_database.dart';
import 'package:provider/provider.dart';
import 'ComprobanteModel.dart';
import 'ReporteCaja.dart';

class CargoHistoryScreen extends StatefulWidget {
  @override
  _CargoHistoryScreenState createState() => _CargoHistoryScreenState();
}

class _CargoHistoryScreenState extends State<CargoHistoryScreen> {
  List<Map<String, dynamic>> _cargoReceipts = [];
  bool _isLoading = true;
  String _searchQuery = '';
  String? _selectedDestination;
  List<String> _destinations = [];

  @override
  void initState() {
    super.initState();
    _loadCargoReceipts();
    _loadDestinations();
  }

  Future<void> _loadCargoReceipts() async {
    setState(() {
      _isLoading = true;
    });

    try {
      List<Map<String, dynamic>> receipts;

      if (_selectedDestination != null) {
        receipts = await CargoDatabase.getReceiptsByDestination(_selectedDestination!);
      } else if (_searchQuery.isNotEmpty) {
        receipts = await CargoDatabase.searchReceipts(_searchQuery);
      } else {
        receipts = await CargoDatabase.getCargoReceipts();
      }

      setState(() {
        _cargoReceipts = receipts;
        _isLoading = false;
      });
    } catch (e) {
      print('Error loading cargo receipts: $e');
      setState(() {
        _cargoReceipts = [];
        _isLoading = false;
      });

      ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error cargando el historial: $e'))
      );
    }
  }

  Future<void> _loadDestinations() async {
    try {
      final destinations = await CargoDatabase.getUniqueDestinations();
      setState(() {
        _destinations = destinations;
      });
    } catch (e) {
      print('Error loading destinations: $e');
    }
  }

  // Group receipts by transaction (comprobante)
  Map<String, List<Map<String, dynamic>>> get _groupedReceipts {
    final Map<String, List<Map<String, dynamic>>> grouped = {};

    for (var receipt in _cargoReceipts) {
      final comprobante = receipt['comprobante'] as String;
      if (!grouped.containsKey(comprobante)) {
        grouped[comprobante] = [];
      }
      grouped[comprobante]!.add(receipt);
    }

    return grouped;
  }

  @override
  Widget build(BuildContext context) {
    final groupedReceipts = _groupedReceipts;

    return Scaffold(
      appBar: AppBar(
        title: Text('Historial de Cargos'),
        backgroundColor: Colors.orange,
      ),
      body: Column(
        children: [
          // Search bar
          Padding(
            padding: const EdgeInsets.all(8.0),
            child: Column(
              children: [
                TextField(
                  decoration: InputDecoration(
                    labelText: 'Buscar por destinatario, remitente, artículo...',
                    prefixIcon: Icon(Icons.search),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10.0),
                    ),
                    suffixIcon: _searchQuery.isNotEmpty ?
                    IconButton(
                      icon: Icon(Icons.clear),
                      onPressed: () {
                        setState(() {
                          _searchQuery = '';
                        });
                        _loadCargoReceipts();
                      },
                    ) : null,
                  ),
                  onChanged: (value) {
                    setState(() {
                      _searchQuery = value;
                    });
                    if (value.length > 2 || value.isEmpty) {
                      _loadCargoReceipts();
                    }
                  },
                ),

                // Destination filter
                if (_destinations.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(top: 8.0),
                    child: DropdownButtonFormField<String?>(
                      decoration: InputDecoration(
                        labelText: 'Filtrar por destino',
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10.0),
                        ),
                        prefixIcon: Icon(Icons.location_on),
                      ),
                      value: _selectedDestination,
                      items: [
                        DropdownMenuItem<String?>(
                          value: null,
                          child: Text('Todos los destinos'),
                        ),
                        ..._destinations.map((dest) => DropdownMenuItem<String?>(
                          value: dest,
                          child: Text(dest),
                        )).toList(),
                      ],
                      onChanged: (String? value) {
                        setState(() {
                          _selectedDestination = value;
                        });
                        _loadCargoReceipts();
                      },
                    ),
                  ),
              ],
            ),
          ),

          // Header showing result count
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
            child: Row(
              children: [
                Text(
                  'Cargos encontrados: ${groupedReceipts.length}',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                  ),
                ),
                Spacer(),
                if (_isLoading)
                  SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                    ),
                  ),
              ],
            ),
          ),

          // List of receipts
          Expanded(
            child: _isLoading && _cargoReceipts.isEmpty
                ? Center(child: CircularProgressIndicator())
                : groupedReceipts.isEmpty
                ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.inventory_2_outlined,
                    size: 70,
                    color: Colors.grey[400],
                  ),
                  SizedBox(height: 16),
                  Text(
                    'No se encontraron recibos de cargo',
                    style: TextStyle(
                      fontSize: 16,
                      color: Colors.grey[600],
                    ),
                  ),
                  if (_searchQuery.isNotEmpty || _selectedDestination != null)
                    TextButton.icon(
                      icon: Icon(Icons.refresh),
                      label: Text('Mostrar todos'),
                      onPressed: () {
                        setState(() {
                          _searchQuery = '';
                          _selectedDestination = null;
                        });
                        _loadCargoReceipts();
                      },
                    ),
                ],
              ),
            )
                : ListView.builder(
              itemCount: groupedReceipts.length,
              itemBuilder: (context, index) {
                final comprobante = groupedReceipts.keys.elementAt(index);
                final receipts = groupedReceipts[comprobante]!;
                final firstReceipt = receipts[0];

                // Find client and cargo copies
                final clientCopy = receipts.firstWhere(
                      (r) => r['tipo'] == 'Cliente',
                  orElse: () => receipts[0],
                );

                final cargoCopy = receipts.firstWhere(
                      (r) => r['tipo'] == 'Carga',
                  orElse: () => receipts[0],
                );

                final date = DateTime.fromMillisecondsSinceEpoch(
                    firstReceipt['timestamp'] as int
                );
                final formattedDate = DateFormat('dd/MM/yyyy HH:mm').format(date);

                return Card(
                  margin: EdgeInsets.symmetric(horizontal: 8.0, vertical: 4.0),
                  child: ExpansionTile(
                    title: Text(
                      'Cargo: ${firstReceipt['destinatario']}',
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                    subtitle: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Comprobante: $comprobante'),
                        Text('Fecha: $formattedDate'),
                      ],
                    ),
                    leading: CircleAvatar(
                      backgroundColor: Colors.orange[100],
                      child: Icon(Icons.inventory, color: Colors.orange),
                    ),
                    children: [
                      Padding(
                        padding: const EdgeInsets.all(16.0),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Detalles del Cargo:',
                              style: TextStyle(fontWeight: FontWeight.bold),
                            ),
                            SizedBox(height: 8.0),
                            _buildDetailRow('Destinatario', '${firstReceipt['destinatario']}'),
                            _buildDetailRow('Remitente', '${firstReceipt['remitente']}'),
                            _buildDetailRow('Artículo', '${firstReceipt['articulo']}'),
                            _buildDetailRow('Precio', '\$${NumberFormat('#,###', 'es_CL').format(firstReceipt['precio'])}'),
                            if (firstReceipt.containsKey('ticketNum') && firstReceipt['ticketNum'] != null && firstReceipt['ticketNum'] != '')
                              _buildDetailRow('N° Boleto', '${firstReceipt['ticketNum']}'),
                            _buildDetailRow('Destino', '${firstReceipt['destino']}'),
                            SizedBox(height: 16.0),

                            Text(
                              'Opciones de reimpresión:',
                              style: TextStyle(fontWeight: FontWeight.bold),
                            ),
                            SizedBox(height: 8.0),

                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                              children: [
                                _buildReprintButton(
                                  'Cliente',
                                  Colors.blue,
                                  Icons.person,
                                      () => _reprintCargoPdf(clientCopy, 'Cliente'),
                                ),
                                _buildReprintButton(
                                  'Carga',
                                  Colors.green,
                                  Icons.local_shipping,
                                      () => _reprintCargoPdf(cargoCopy, 'Carga'),
                                ),
                                _buildReprintButton(
                                  'Ambas',
                                  Colors.orange,
                                  Icons.print,
                                      () {
                                    _reprintCargoPdf(clientCopy, 'Cliente');
                                    _reprintCargoPdf(cargoCopy, 'Carga');
                                  },
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDetailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 100,
            child: Text(
              '$label:',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
          ),
          Expanded(
            child: Text(value),
          ),
        ],
      ),
    );
  }

  Widget _buildReprintButton(String label, Color color, IconData icon, VoidCallback onPressed) {
    return ElevatedButton.icon(
      icon: Icon(icon, color: Colors.white),
      label: Text(
        label,
        style: TextStyle(color: Colors.white),
      ),
      style: ElevatedButton.styleFrom(
        backgroundColor: color,
        padding: EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
      ),
      onPressed: onPressed,
    );
  }

  Future<void> _reprintCargoPdf(Map<String, dynamic> receipt, String tipo) async {
    try {
      setState(() {
        _isLoading = true;
      });

      // Get the file
      final filename = receipt['filename'] as String;
      final file = await CargoDatabase.getReceiptFile(filename);

      if (file == null) {
        throw 'Archivo no encontrado';
      }

      // Print the PDF
      final pdfData = await file.readAsBytes();
      await Printing.layoutPdf(
        onLayout: (PdfPageFormat format) async => pdfData,
        format: PdfPageFormat(58 * PdfPageFormat.mm, double.infinity),
      );

      ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Reimpresión de $tipo completada'))
      );
    } catch (e) {
      print('Error al reimprimir: $e');
      ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error al reimprimir: $e'))
      );
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }
}