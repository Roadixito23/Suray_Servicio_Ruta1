import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';

class SundayTicketModel extends ChangeNotifier {
  List<Map<String, dynamic>> _pasajes = [];

  SundayTicketModel() {
    _loadPasajes();
  }

  List<Map<String, dynamic>> get pasajes => _pasajes;

  // Método para editar un pasaje existente
  void editPasaje(int index, String newName, double newPrice) {
    if (index < 0 || index >= _pasajes.length) return; // Validar índice
    _pasajes[index]['nombre'] = newName;
    _pasajes[index]['precio'] = newPrice;
    _savePasajes(); // Guardar los cambios en SharedPreferences
    notifyListeners(); // Notificar a los oyentes que los datos han cambiado
  }

  // Método para cargar los pasajes desde SharedPreferences
  Future<void> _loadPasajes() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    String? jsonString = prefs.getString('sunday_pasajes');
    if (jsonString != null) {
      List<dynamic> jsonList = json.decode(jsonString);
      _pasajes = jsonList
          .map((item) => {
        'nombre': item['nombre'],
        'precio': item['precio'],
      })
          .toList()
          .cast<Map<String, dynamic>>();

      // Eliminar posibles duplicados
      _removeDuplicates();

      // Asegurar que todos los tickets esenciales existen
      _ensureEssentialTickets();
    } else {
      // Valores predeterminados si no hay datos guardados
      _initializeDefaultTickets();
    }
    notifyListeners();
  }

  // Inicializar con valores predeterminados para domingo
  void _initializeDefaultTickets() {
    _pasajes = [
      {'nombre': 'Público General', 'precio': 4300.0},
      {'nombre': 'Escolar General', 'precio': 3000.0},
      {'nombre': 'Adulto Mayor', 'precio': 2150.0},
      {'nombre': 'Int. hasta 15 Km', 'precio': 3000.0},
      {'nombre': 'Int. hasta 50 Km', 'precio': 3000.0},
      {'nombre': 'Escolar Intermedio', 'precio': 1300.0}, // Escolar Intermedio como 6º ticket, con precio de domingo
    ];
    _savePasajes();
  }

  // Asegurar que todos los tickets esenciales existen
  void _ensureEssentialTickets() {
    // Verificar que existen todos los tickets esenciales
    List<Map<String, String>> essentialNames = [
      {'nombre': 'Público General', 'defaultPrice': '4300.0'},
      {'nombre': 'Escolar General', 'defaultPrice': '3000.0'},
      {'nombre': 'Adulto Mayor', 'defaultPrice': '2150.0'},
      {'nombre': 'Int. hasta 15 Km', 'defaultPrice': '3000.0'},
      {'nombre': 'Int. hasta 50 Km', 'defaultPrice': '3000.0'},
      {'nombre': 'Escolar Intermedio', 'defaultPrice': '1300.0'},
    ];

    bool needsSave = false;

    for (var essential in essentialNames) {
      bool exists = _pasajes.any((ticket) => ticket['nombre'] == essential['nombre']);

      if (!exists) {
        double defaultPrice = double.parse(essential['defaultPrice']!);
        _pasajes.add({'nombre': essential['nombre'], 'precio': defaultPrice});
        print('Añadido ticket esencial faltante: ${essential['nombre']}');
        needsSave = true;
      }
    }

    if (needsSave) {
      _savePasajes();
    }
  }

  // Eliminar duplicados en la lista de pasajes
  void _removeDuplicates() {
    // Usar un conjunto para rastrear nombres ya vistos
    Set<String> seenNames = {};
    List<Map<String, dynamic>> uniqueTickets = [];

    for (var ticket in _pasajes) {
      String name = ticket['nombre'] as String;

      // Si no hemos visto este nombre antes, añadirlo a la lista única
      if (!seenNames.contains(name)) {
        seenNames.add(name);
        uniqueTickets.add(ticket);
      } else {
        print('Eliminando duplicado: $name');
      }
    }

    // Reemplazar la lista original solo si se encontraron duplicados
    if (uniqueTickets.length != _pasajes.length) {
      _pasajes = uniqueTickets;
      _savePasajes();
    }
  }

  // Método para guardar los pasajes en SharedPreferences
  Future<void> _savePasajes() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    String jsonString = json.encode(_pasajes);
    await prefs.setString('sunday_pasajes', jsonString);
  }
}