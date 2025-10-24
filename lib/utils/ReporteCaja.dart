import 'package:flutter/material.dart';
import 'package:intl/intl.dart'; // Para formatear fechas y horas
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';

class ReporteCaja extends ChangeNotifier {
  Map<String, List<Map<String, dynamic>>> _transacciones = {};
  double _totalIngresos = 0.0;
  bool _isAscending = true;

  // Getters
  Map<String, List<Map<String, dynamic>>> get transacciones => _transacciones;
  double get totalIngresos => _totalIngresos;
  bool get isAscending => _isAscending;

  ReporteCaja() {
    loadTransactions(); // Cargar transacciones al iniciar
  }

  void receiveData(String nombrePasaje, double valor, String comprobante) {
    String fecha = DateFormat('dd/MM/yyyy').format(DateTime.now());
    String dia = DateFormat('dd').format(DateTime.now()); // Obtener el día
    String mes = DateFormat('MM').format(DateTime.now()); // Obtener el mes
    String hora = DateFormat('HH:mm').format(DateTime.now());
    String id = DateTime.now().millisecondsSinceEpoch.toString();

    if (!_transacciones.containsKey(fecha)) {
      _transacciones[fecha] = [];
    }

    // Agregar la transacción con el número de comprobante
    _transacciones[fecha]!.add({
      'id': id,
      'nombre': nombrePasaje,
      'valor': valor,
      'hora': hora,
      'comprobante': comprobante,
      'dia': dia, // Guardar el día
      'mes': mes, // Guardar el mes
    });

    _totalIngresos += valor;
    _saveTransactions();
    notifyListeners();
  }

  void receiveCargoData(String destinatario, double valor, String comprobante) {
    String fecha = DateFormat('dd/MM/yyyy').format(DateTime.now());
    String dia = DateFormat('dd').format(DateTime.now()); // Obtener el día
    String mes = DateFormat('MM').format(DateTime.now()); // Obtener el mes
    String hora = DateFormat('HH:mm').format(DateTime.now());
    String id = DateTime.now().millisecondsSinceEpoch.toString();

    if (!_transacciones.containsKey(fecha)) {
      _transacciones[fecha] = [];
    }

    // Agregar la transacción de cargo
    _transacciones[fecha]!.add({
      'id': id,
      'nombre': 'Cargo: $destinatario',
      'valor': valor,
      'hora': hora,
      'comprobante': comprobante,
      'dia': dia, // Guardar el día
      'mes': mes, // Guardar el mes
    });

    _totalIngresos += valor;
    _saveTransactions();
    notifyListeners();
  }

  void addOfferEntries(List<double> subtotals, double total, String comprobante) {
    String fecha = DateFormat('dd/MM/yyyy').format(DateTime.now());
    String dia = DateFormat('dd').format(DateTime.now()); // Obtener el día
    String mes = DateFormat('MM').format(DateTime.now()); // Obtener el mes
    if (!_transacciones.containsKey(fecha)) {
      _transacciones[fecha] = [];
    }

    String id = DateTime.now().millisecondsSinceEpoch.toString();
    _transacciones[fecha]!.add({
      'id': id,
      'nombre': 'Oferta Ruta',
      'valor': total,
      'hora': DateFormat('HH:mm').format(DateTime.now()),
      'subtotals': subtotals,
      'comprobante': comprobante,
      'dia': dia, // Guardar el día
      'mes': mes, // Guardar el mes
    });

    _totalIngresos += total;
    _saveTransactions();
    notifyListeners();
  }

  void cancelTransaction() {
    if (_transacciones.isNotEmpty) {
      final lastDate = _transacciones.keys.last;
      if (_transacciones[lastDate]!.isNotEmpty) {
        final lastTransaction = _transacciones[lastDate]!.last; // Obtener la última transacción
        double lastValue = lastTransaction['valor'];

        // Crear la nueva transacción con valor negativo
        Map<String, dynamic> reversedTransaction = {
          'id': DateTime.now().millisecondsSinceEpoch.toString(), // Nuevo ID
          'nombre': 'Anulación: ${lastTransaction['nombre']}', // Indicar que es una anulación
          'valor': -lastValue, // Valor negativo
          'hora': DateFormat('HH:mm').format(DateTime.now()), // Hora actual
          'comprobante': lastTransaction['comprobante'], // Usar el mismo comprobante
          'dia': lastTransaction['dia'], // Usar el mismo día
          'mes': lastTransaction['mes'], // Usar el mismo mes
        };

        // Añadir la transacción de anulación
        _transacciones[lastDate]!.add(reversedTransaction);

        // Ajustar el total restando el valor anulado
        _totalIngresos += reversedTransaction['valor']; // Esto restará porque el valor es negativo

        _saveTransactions();
        notifyListeners();
      }
    }
  }

  String formatValue(double value) {
    return NumberFormat("#,##0", "es_ES").format(value);
  }

  void clearTransactions() {
    _transacciones.clear();
    _totalIngresos = 0.0;
    _saveTransactions();
    notifyListeners();
  }

  void toggleOrder() {
    _isAscending = !_isAscending;
    _saveOrderPreference();
    notifyListeners();
  }

  bool hasActiveTransactions() {
    // Verificar si hay transacciones del día actual que no sean anulaciones
    DateTime today = DateTime.now();
    String todayDay = DateFormat('dd').format(today);
    String todayMonth = DateFormat('MM').format(today);

    var todayTransactions = getOrderedTransactions().where((t) =>
    t['dia'] == todayDay && t['mes'] == todayMonth &&
        !t['nombre'].toString().startsWith('Anulación:')
    ).toList();

    return todayTransactions.isNotEmpty;
  }

  Future<void> _saveOrderPreference() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('isAscending', _isAscending);
  }

  List<Map<String, dynamic>> getOrderedTransactions() {
    var allTransactions = _transacciones.entries.expand((entry) => entry.value).toList();

    // Ordenar las transacciones según el estado de _isAscending
    allTransactions.sort((a, b) => _isAscending ? a['id'].compareTo(b['id']) : b['id'].compareTo(a['id']));
    return allTransactions;
  }

  Future<void> _saveTransactions() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('transactions', jsonEncode(_transacciones));
    await prefs.setDouble('totalIngresos', _totalIngresos); // Guardar también el total de ingresos
  }

  Future<void> loadTransactions() async {
    final prefs = await SharedPreferences.getInstance();
    String? transactionsJson = prefs.getString('transactions');
    if (transactionsJson != null) {
      Map<String, dynamic> decodedJson = jsonDecode(transactionsJson);
      _transacciones = decodedJson.map((key, value) => MapEntry(key, List<Map<String, dynamic>>.from(value)));

      // Cargar el total de ingresos guardado o recalcularlo si no está disponible
      _totalIngresos = prefs.getDouble('totalIngresos') ?? _recalculateTotal();

      notifyListeners();
    }
  }

  // Método para recalcular el total basado en todas las transacciones
  double _recalculateTotal() {
    double total = 0.0;
    for (var transactions in _transacciones.values) {
      for (var transaction in transactions) {
        total += transaction['valor'] ?? 0.0;
      }
    }
    return total;
  }
}