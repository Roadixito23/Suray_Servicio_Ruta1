import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../services/database_service.dart';

class ReporteCaja extends ChangeNotifier {
  final DatabaseService _dbService = DatabaseService();
  Map<String, List<Map<String, dynamic>>> _transacciones = {};
  double _totalIngresos = 0.0;
  bool _isAscending = true;

  // Getters
  Map<String, List<Map<String, dynamic>>> get transacciones => _transacciones;
  double get totalIngresos => _totalIngresos;
  bool get isAscending => _isAscending;

  ReporteCaja() {
    loadTransactions();
  }

  void receiveData(String nombrePasaje, double valor, String comprobante) async {
    String fecha = DateFormat('dd/MM/yyyy').format(DateTime.now());
    String dia = DateFormat('dd').format(DateTime.now());
    String mes = DateFormat('MM').format(DateTime.now());
    String hora = DateFormat('HH:mm').format(DateTime.now());

    // Insertar en la base de datos
    await _dbService.insertTransaccion({
      'fecha': fecha,
      'dia': dia,
      'mes': mes,
      'hora': hora,
      'nombre_pasaje': nombrePasaje,
      'valor': valor,
      'comprobante': comprobante,
    });

    // Actualizar datos en memoria
    if (!_transacciones.containsKey(fecha)) {
      _transacciones[fecha] = [];
    }

    _transacciones[fecha]!.add({
      'id': DateTime.now().millisecondsSinceEpoch.toString(),
      'nombre': nombrePasaje,
      'valor': valor,
      'hora': hora,
      'comprobante': comprobante,
      'dia': dia,
      'mes': mes,
    });

    _totalIngresos += valor;
    notifyListeners();
  }

  void receiveCargoData(String destinatario, double valor, String comprobante) async {
    String fecha = DateFormat('dd/MM/yyyy').format(DateTime.now());
    String dia = DateFormat('dd').format(DateTime.now());
    String mes = DateFormat('MM').format(DateTime.now());
    String hora = DateFormat('HH:mm').format(DateTime.now());

    // Insertar en la base de datos
    await _dbService.insertTransaccion({
      'fecha': fecha,
      'dia': dia,
      'mes': mes,
      'hora': hora,
      'nombre_pasaje': 'Cargo: $destinatario',
      'valor': valor,
      'comprobante': comprobante,
    });

    // Actualizar datos en memoria
    if (!_transacciones.containsKey(fecha)) {
      _transacciones[fecha] = [];
    }

    _transacciones[fecha]!.add({
      'id': DateTime.now().millisecondsSinceEpoch.toString(),
      'nombre': 'Cargo: $destinatario',
      'valor': valor,
      'hora': hora,
      'comprobante': comprobante,
      'dia': dia,
      'mes': mes,
    });

    _totalIngresos += valor;
    notifyListeners();
  }

  void addOfferEntries(List<double> subtotals, double total, String comprobante) async {
    String fecha = DateFormat('dd/MM/yyyy').format(DateTime.now());
    String dia = DateFormat('dd').format(DateTime.now());
    String mes = DateFormat('MM').format(DateTime.now());
    String hora = DateFormat('HH:mm').format(DateTime.now());

    // Insertar en la base de datos
    await _dbService.insertTransaccion({
      'fecha': fecha,
      'dia': dia,
      'mes': mes,
      'hora': hora,
      'nombre_pasaje': 'Oferta Ruta',
      'valor': total,
      'comprobante': comprobante,
    });

    // Actualizar datos en memoria
    if (!_transacciones.containsKey(fecha)) {
      _transacciones[fecha] = [];
    }

    _transacciones[fecha]!.add({
      'id': DateTime.now().millisecondsSinceEpoch.toString(),
      'nombre': 'Oferta Ruta',
      'valor': total,
      'hora': hora,
      'subtotals': subtotals,
      'comprobante': comprobante,
      'dia': dia,
      'mes': mes,
    });

    _totalIngresos += total;
    notifyListeners();
  }

  void cancelTransaction() async {
    if (_transacciones.isNotEmpty) {
      final lastDate = _transacciones.keys.last;
      if (_transacciones[lastDate]!.isNotEmpty) {
        final lastTransaction = _transacciones[lastDate]!.last;
        double lastValue = lastTransaction['valor'];

        String fecha = DateFormat('dd/MM/yyyy').format(DateTime.now());
        String dia = lastTransaction['dia'];
        String mes = lastTransaction['mes'];
        String hora = DateFormat('HH:mm').format(DateTime.now());

        // Insertar anulación en la base de datos
        await _dbService.insertTransaccion({
          'fecha': fecha,
          'dia': dia,
          'mes': mes,
          'hora': hora,
          'nombre_pasaje': 'Anulación: ${lastTransaction['nombre']}',
          'valor': -lastValue,
          'comprobante': lastTransaction['comprobante'],
        });

        // Actualizar datos en memoria
        Map<String, dynamic> reversedTransaction = {
          'id': DateTime.now().millisecondsSinceEpoch.toString(),
          'nombre': 'Anulación: ${lastTransaction['nombre']}',
          'valor': -lastValue,
          'hora': hora,
          'comprobante': lastTransaction['comprobante'],
          'dia': dia,
          'mes': mes,
        };

        _transacciones[lastDate]!.add(reversedTransaction);
        _totalIngresos += reversedTransaction['valor'];

        notifyListeners();
      }
    }
  }

  String formatValue(double value) {
    return NumberFormat("#,##0", "es_ES").format(value);
  }

  void clearTransactions() async {
    // Crear cierre de caja antes de limpiar
    if (_transacciones.isNotEmpty) {
      final resumen = await _dbService.getResumenTransacciones();
      await _dbService.createCierreCaja(
        fechaCierre: DateFormat('dd/MM/yyyy HH:mm').format(DateTime.now()),
        totalIngresos: resumen['total_ingresos'] ?? 0.0,
        totalTransacciones: resumen['total_transacciones'] ?? 0,
      );
    }

    // Limpiar datos en memoria
    _transacciones.clear();
    _totalIngresos = 0.0;
    notifyListeners();
  }

  void toggleOrder() async {
    _isAscending = !_isAscending;
    await _dbService.setConfiguracion('isAscending', _isAscending.toString(), tipo: 'bool');
    notifyListeners();
  }

  bool hasActiveTransactions() {
    DateTime today = DateTime.now();
    String todayDay = DateFormat('dd').format(today);
    String todayMonth = DateFormat('MM').format(today);

    var todayTransactions = getOrderedTransactions().where((t) =>
        t['dia'] == todayDay &&
        t['mes'] == todayMonth &&
        !t['nombre'].toString().startsWith('Anulación:')
    ).toList();

    return todayTransactions.isNotEmpty;
  }

  List<Map<String, dynamic>> getOrderedTransactions() {
    var allTransactions = _transacciones.entries.expand((entry) => entry.value).toList();

    allTransactions.sort((a, b) => _isAscending
        ? a['id'].compareTo(b['id'])
        : b['id'].compareTo(a['id']));
    return allTransactions;
  }

  Future<void> loadTransactions() async {
    // Cargar configuración de orden
    _isAscending = await _dbService.getConfiguracionBool('isAscending', defaultValue: true);

    // Cargar transacciones sin cierre desde la base de datos
    final transaccionesDB = await _dbService.getTransaccionesSinCierre();

    _transacciones.clear();
    _totalIngresos = 0.0;

    for (var transaccion in transaccionesDB) {
      String fecha = transaccion['fecha'] as String;

      if (!_transacciones.containsKey(fecha)) {
        _transacciones[fecha] = [];
      }

      _transacciones[fecha]!.add({
        'id': transaccion['id'].toString(),
        'nombre': transaccion['nombre_pasaje'],
        'valor': transaccion['valor'],
        'hora': transaccion['hora'],
        'comprobante': transaccion['comprobante'],
        'dia': transaccion['dia'],
        'mes': transaccion['mes'],
      });

      _totalIngresos += (transaccion['valor'] as num).toDouble();
    }

    notifyListeners();
  }

  double _recalculateTotal() {
    double total = 0.0;
    for (var transactions in _transacciones.values) {
      for (var transaction in transactions) {
        total += transaction['valor'] ?? 0.0;
      }
    }
    return total;
  }

  // Nuevos métodos para trabajar con cierres de caja

  Future<List<Map<String, dynamic>>> getCierresCaja({int? limit}) async {
    return await _dbService.getCierresCaja(limit: limit);
  }

  Future<List<Map<String, dynamic>>> getTransaccionesByCierre(int cierreId) async {
    final transaccionesDB = await _dbService.getTransacciones(cierreId: cierreId);

    return transaccionesDB.map((t) => {
      'id': t['id'].toString(),
      'nombre': t['nombre_pasaje'],
      'valor': t['valor'],
      'hora': t['hora'],
      'comprobante': t['comprobante'],
      'dia': t['dia'],
      'mes': t['mes'],
    }).toList();
  }

  Future<Map<String, dynamic>> getResumenCierre(int cierreId) async {
    return await _dbService.getResumenTransacciones(cierreId: cierreId);
  }
}
