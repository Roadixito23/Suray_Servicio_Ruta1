import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class ComprobanteModel extends ChangeNotifier {
  static const String _comprobanteNumberKey = 'comprobanteNumber'; // Clave para SharedPreferences
  static const String _ticketIdKey = 'ticketId';                  // Clave para el ID

  int _comprobanteNumber = 0;  // Ahora arranca en 0 en vez de 1
  int _ticketId = 1;           // Valor por defecto para el ID

  ComprobanteModel() {
    _loadComprobanteNumber();
    _loadTicketId();
  }

  int get comprobanteNumber => _comprobanteNumber;
  int get ticketId => _ticketId;

  Future<void> _loadComprobanteNumber() async {
    final prefs = await SharedPreferences.getInstance();
    // Carga o establece a 0 si no existe
    _comprobanteNumber = prefs.getInt(_comprobanteNumberKey) ?? 0;
    notifyListeners();
  }

  Future<void> _loadTicketId() async {
    final prefs = await SharedPreferences.getInstance();
    _ticketId = prefs.getInt(_ticketIdKey) ?? 1;
    notifyListeners();
  }

  String get formattedComprobante {
    // Formatear el ID con dos dígitos y el número de comprobante con seis
    String formattedId = _ticketId.toString().padLeft(2, '0');
    String comp = _comprobanteNumber.toString().padLeft(6, '0');
    return '$formattedId-$comp';
  }

  Future<void> incrementComprobante() async {
    _comprobanteNumber++;
    if (_comprobanteNumber > 999999) {
      _comprobanteNumber = 1; // Sigue reiniciando a 1 tras máximo
    }
    await _saveComprobanteNumber();
    notifyListeners();
  }

  Future<void> _saveComprobanteNumber() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_comprobanteNumberKey, _comprobanteNumber);
  }

  /// Reinicia el contador a 0
  Future<void> resetComprobante() async {
    _comprobanteNumber = 0;    // ← ahora reinicia a 0
    await _saveComprobanteNumber();
    notifyListeners();
  }
}
