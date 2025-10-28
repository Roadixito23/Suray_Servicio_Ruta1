import 'package:flutter/foundation.dart';
import '../services/database_service.dart';

class SundayTicketModel extends ChangeNotifier {
  final DatabaseService _dbService = DatabaseService();
  List<Map<String, dynamic>> _pasajes = [];

  SundayTicketModel() {
    _loadPasajes();
  }

  List<Map<String, dynamic>> get pasajes => _pasajes;

  // Método para editar un pasaje existente
  void editPasaje(int index, String newName, double newPrice) async {
    if (index < 0 || index >= _pasajes.length) return;

    final pasaje = _pasajes[index];
    final int id = pasaje['id'] ?? 0;

    if (id > 0) {
      await _dbService.updateTarifa(id, {
        'nombre': newName,
        'precio': newPrice,
      }, isDomingo: true);
    }

    _pasajes[index]['nombre'] = newName;
    _pasajes[index]['precio'] = newPrice;
    notifyListeners();
  }

  // Método para cargar los pasajes desde la base de datos
  Future<void> _loadPasajes() async {
    final tarifasDB = await _dbService.getTarifas(isDomingo: true);

    if (tarifasDB.isNotEmpty) {
      _pasajes = tarifasDB.map((t) => {
        'id': t['id'],
        'nombre': t['nombre'],
        'precio': t['precio'],
      }).toList();
    } else {
      // Si no hay datos, se insertarán los valores por defecto desde _onCreate
      // Solo necesitamos cargarlos
      await _loadPasajes();
    }

    notifyListeners();
  }

  // Método para agregar un nuevo pasaje
  Future<void> addPasaje(String nombre, double precio) async {
    final id = await _dbService.insertTarifa({
      'nombre': nombre,
      'precio': precio,
      'orden': _pasajes.length,
    }, isDomingo: true);

    _pasajes.add({
      'id': id,
      'nombre': nombre,
      'precio': precio,
    });

    notifyListeners();
  }

  // Método para eliminar un pasaje
  Future<void> deletePasaje(int index) async {
    if (index < 0 || index >= _pasajes.length) return;

    final pasaje = _pasajes[index];
    final int id = pasaje['id'] ?? 0;

    if (id > 0) {
      await _dbService.deleteTarifa(id, isDomingo: true);
    }

    _pasajes.removeAt(index);
    notifyListeners();
  }

  // Recargar pasajes desde la base de datos
  Future<void> reload() async {
    await _loadPasajes();
  }
}
