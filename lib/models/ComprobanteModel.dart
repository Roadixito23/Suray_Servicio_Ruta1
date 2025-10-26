import 'package:flutter/material.dart';
import '../services/database_service.dart';

class ComprobanteModel extends ChangeNotifier {
  final DatabaseService _dbService = DatabaseService();

  int _comprobanteNumber = 0;
  int _ticketId = 1;

  ComprobanteModel() {
    _loadComprobanteNumber();
    _loadTicketId();
  }

  int get comprobanteNumber => _comprobanteNumber;
  int get ticketId => _ticketId;

  Future<void> _loadComprobanteNumber() async {
    _comprobanteNumber = await _dbService.getConfiguracionInt('comprobanteNumber', defaultValue: 0);
    notifyListeners();
  }

  Future<void> _loadTicketId() async {
    _ticketId = await _dbService.getConfiguracionInt('ticketId', defaultValue: 1);
    notifyListeners();
  }

  String get formattedComprobante {
    String formattedId = _ticketId.toString().padLeft(2, '0');
    String comp = _comprobanteNumber.toString().padLeft(6, '0');
    return '$formattedId-$comp';
  }

  Future<void> incrementComprobante() async {
    _comprobanteNumber++;
    if (_comprobanteNumber > 999999) {
      _comprobanteNumber = 1;
    }
    await _dbService.setConfiguracion('comprobanteNumber', _comprobanteNumber.toString(), tipo: 'int');
    notifyListeners();
  }

  Future<void> resetComprobante() async {
    _comprobanteNumber = 0;
    await _dbService.setConfiguracion('comprobanteNumber', _comprobanteNumber.toString(), tipo: 'int');
    notifyListeners();
  }

  Future<void> updateTicketId(int newId) async {
    _ticketId = newId;
    await _dbService.setConfiguracion('ticketId', _ticketId.toString(), tipo: 'int');
    notifyListeners();
  }
}
