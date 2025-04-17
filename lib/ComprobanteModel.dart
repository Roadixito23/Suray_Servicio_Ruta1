import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class ComprobanteModel extends ChangeNotifier {
  static const String _comprobanteNumberKey = 'comprobanteNumber'; // Clave para SharedPreferences
  static const String _ticketIdKey = 'ticketId'; // Clave para el ID
  int _comprobanteNumber = 1;
  int _ticketId = 1; // Valor por defecto para el ID

  ComprobanteModel() {
    _loadComprobanteNumber(); // Cargar el número de comprobante al inicializar
    _loadTicketId(); // Cargar el ID al inicializar
  }

  int get comprobanteNumber => _comprobanteNumber;
  int get ticketId => _ticketId;

  Future<void> _loadComprobanteNumber() async {
    final prefs = await SharedPreferences.getInstance();
    _comprobanteNumber = prefs.getInt(_comprobanteNumberKey) ?? 1; // Cargar o establecer a 1 si no existe
    notifyListeners();
  }

  Future<void> _loadTicketId() async {
    final prefs = await SharedPreferences.getInstance();
    _ticketId = prefs.getInt(_ticketIdKey) ?? 1; // Cargar o establecer a 1 si no existe
    notifyListeners();
  }

  String get formattedComprobante {
    // Formatear el ID con pad a la izquierda para asegurar 2 dígitos
    String formattedId = _ticketId.toString().padLeft(2, '0');
    return '$formattedId-${_comprobanteNumber.toString().padLeft(6, '0')}'; // Formato: ID<number>-<comprobanteNumber>
  }

  Future<void> incrementComprobante() async {
    _comprobanteNumber++;
    if (_comprobanteNumber > 999999) {
      _comprobanteNumber = 1; // Reiniciar si excede el límite
    }
    await _saveComprobanteNumber(); // Guardar en SharedPreferences
    notifyListeners();
  }

  Future<void> _saveComprobanteNumber() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_comprobanteNumberKey, _comprobanteNumber); // Guardar el número de comprobante
  }

  Future<void> resetComprobante() async {
    _comprobanteNumber = 1; // Reiniciar manualmente si es necesario
    await _saveComprobanteNumber(); // Guardar el valor reiniciado
    notifyListeners();
  }
}