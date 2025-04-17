import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import 'dart:convert';
import 'ticket_model.dart';
import 'sunday_ticket_model.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'backup_screen.dart';

class Settings extends StatefulWidget {
  @override
  _SettingsState createState() => _SettingsState();
}

class _SettingsState extends State<Settings> with SingleTickerProviderStateMixin {
  final TextEditingController passwordController = TextEditingController();
  final TextEditingController idController = TextEditingController();
  bool isAuthenticated = false;
  double _textSizeMultiplier = 0.8;
  bool _showIcons = true;

  // State variable for icon spacing
  double _iconSpacing = 1.0;

  // Map to store icon selections for each button type
  Map<String, String> _buttonIcons = {
    'Público General': 'people',
    'Escolar General': 'school',
    'Adulto Mayor': 'elderly',
    'Int. hasta 15 Km': 'directions_bus',
    'Int. hasta 50 Km': 'map',
    'Escolar Intermedio': 'school_outlined',
    'Oferta Ruta': 'local_offer',
    'Cargo': 'inventory',
  };

  // AppBar elements configuration
  Map<String, dynamic> _appBarElements = {
    'report': {
      'name': 'Reportes',
      'icon': Icons.receipt,
      'position': 0,
      'enabled': true,
      'margin': 3.0,
      'bgColor': Color(0xFF1900A2),
      'iconColor': Colors.white,
      'isText': false,
      'text': '',
    },
    'mail': {
      'name': 'Correo',
      'icon': Icons.mail,
      'position': 1, // 🔹 Antes de "Anular"
      'enabled': true,
      'margin': 3.0,
      'bgColor': Colors.pinkAccent, // 🔹 Fondo rosa
      'iconColor': Colors.black, // 🔹 Ícono negro
      'isText': false,
      'text': '',
    },
    'delete': {
      'name': 'Anular',
      'icon': Icons.delete,
      'position': 1,
      'enabled': true,
      'margin': 3.0,
      'bgColor': Color(0xFFFF0C00),
      'iconColor': Colors.black,
      'isText': false,
      'text': '',
    },
    'reprint': {
      'name': 'Reimprimir',
      'icon': Icons.print,
      'position': 2,
      'enabled': true,
      'margin': 3.0,
      'bgColor': Color(0xFFFFD71F),
      'iconColor': Colors.black,
      'isText': true,
      'text': 'R',
    },
    'settings': {
      'name': 'Configuración',
      'icon': Icons.settings,
      'position': 3,
      'enabled': true,
      'margin': 3.0,
      'bgColor': Color(0xFF00910B),
      'iconColor': Colors.white,
      'isText': false,
      'text': '',
    },
    'date': {
      'name': 'Fecha/Día',
      'icon': Icons.calendar_today,
      'position': 4,
      'enabled': true,
      'margin': 5.0,
      'bgColor': Colors.transparent,
      'iconColor': Colors.black,
      'isText': false,
      'text': '',
      'isDate': true,
    },
  };

  // Available icons for selection
  final List<Map<String, dynamic>> _availableIcons = [
    {'name': 'Personas', 'icon': Icons.people},
    {'name': 'Escuela', 'icon': Icons.school},
    {'name': 'Escuela (Alt)', 'icon': Icons.school_outlined},
    {'name': 'Adulto Mayor', 'icon': Icons.elderly},
    {'name': 'Bus', 'icon': Icons.directions_bus},
    {'name': 'Mapa', 'icon': Icons.map},
    {'name': 'Oferta', 'icon': Icons.local_offer},
    {'name': 'Inventario', 'icon': Icons.inventory},
    {'name': 'Ticket', 'icon': Icons.confirmation_number},
    {'name': 'Recibo', 'icon': Icons.receipt},
    {'name': 'Dinero', 'icon': Icons.attach_money},
    {'name': 'Correo', 'icon': Icons.mail},
  ];

  // Flag to track if settings have changed
  bool _settingsChanged = false;

  final String appVersion = '1.1.0';

  // Variables para TabController
  late TabController _tabController;

  // Colores de la aplicación
  final Color primaryColor = Colors.amber[800]!;
  final Color accentColor = Colors.orange;
  final Color backgroundColor = Colors.grey[100]!;
  final Color cardColor = Colors.white;
  final Color textColor = Colors.black87;
  final Color buttonColor = Colors.orange;

  // Variables para las abreviaturas
  final Map<String, String> _abbreviations = {
    'Público General': 'PG',
    'Escolar General': 'Esc.',
    'Adulto Mayor': 'AM',
    'Escolar Intermedio': 'Int.E',
    'Intermedio hasta 15 Km': 'Int.15',
    'Intermedio hasta 50 Km': 'Int.50',
    'Oferta Ruta': 'OR',
    'Cargo': 'Cargo',
  };

  final Map<String, TextEditingController> _abbreviationControllers = {};

  @override
  void initState() {
    super.initState();
    _loadId();
    _loadDisplayPreferences();
    _loadAbbreviations();
    _loadButtonIconPreferences();
    _loadAppBarConfig();
    _tabController = TabController(length: 5, vsync: this); // Changed from 4 to 5 tabs
  }

  @override
  void dispose() {
    _tabController.dispose();
    passwordController.dispose();
    idController.dispose();

    // Liberar controladores de abreviaturas
    _abbreviationControllers.values.forEach((controller) =>
        controller.dispose());

    super.dispose();
  }

  // Function to get IconData from string name
  IconData _getIconFromString(String iconName) {
    switch (iconName) {
      case 'people':
        return Icons.people;
      case 'school':
        return Icons.school;
      case 'school_outlined':
        return Icons.school_outlined;
      case 'elderly':
        return Icons.elderly;
      case 'directions_bus':
        return Icons.directions_bus;
      case 'map':
        return Icons.map;
      case 'local_offer':
        return Icons.local_offer;
      case 'inventory':
        return Icons.inventory;
      case 'confirmation_number':
        return Icons.confirmation_number;
      case 'receipt':
        return Icons.receipt;
      case 'attach_money':
        return Icons.attach_money;
      case 'mail':
        return Icons.mail;
      default:
        return Icons.error;
    }
  }

  // Get icon for AppBar elements
  IconData _getAppBarElementIcon(String key) {
    switch (key) {
      case 'report': return Icons.receipt;
      case 'delete': return Icons.delete;
      case 'reprint': return Icons.print;
      case 'settings': return Icons.settings;
      case 'date': return Icons.calendar_today;
      case 'mail': return Icons.mail; // 🔹 Agregar el ícono de correo
      default: return Icons.circle;
    }
  }


  // Method to load AppBar configuration
  Future<void> _loadAppBarConfig() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final String? savedConfig = prefs.getString('appBarConfig');

      if (savedConfig != null) {
        Map<String, dynamic> loadedConfig = json.decode(savedConfig);
        setState(() {
          loadedConfig.forEach((key, value) {
            if (_appBarElements.containsKey(key)) {
              // Create a copy of the loaded element
              Map<String, dynamic> elementCopy = Map<String, dynamic>.from(_appBarElements[key]!);

              // Restore all properties from loaded data
              value.forEach((propKey, propValue) {
                if (propKey == 'icon') {
                  // Convert stored codePoint back to IconData
                  elementCopy[propKey] = IconData(
                    propValue,
                    fontFamily: 'MaterialIcons',
                  );
                } else if (propKey == 'bgColor' || propKey == 'iconColor') {
                  // Convert stored int value back to Color
                  elementCopy[propKey] = Color(propValue);
                } else {
                  // Restore other values directly
                  elementCopy[propKey] = propValue;
                }
              });

              _appBarElements[key] = elementCopy;
            }
          });
        });
        print('AppBar configuration loaded successfully');
      }
    } catch (e) {
      print('Error loading AppBar configuration: $e');
    }
  }

  // Method to save AppBar configuration
  Future<void> _saveAppBarConfig() async {
    try {
      final prefs = await SharedPreferences.getInstance();

      // Create a serializable copy of _appBarElements
      Map<String, dynamic> serializableConfig = {};

      _appBarElements.forEach((key, value) {
        // Create a copy of the element
        Map<String, dynamic> elementCopy = {};

        // Copy all properties except the icon, which needs special handling
        value.forEach((propKey, propValue) {
          if (propKey == 'icon') {
            // Convert IconData to an integer (codePoint) for serialization
            elementCopy[propKey] = propValue.codePoint;
          } else if (propKey == 'bgColor' || propKey == 'iconColor') {
            // Convert Color to a serializable format (its value as int)
            elementCopy[propKey] = propValue.value;
          } else {
            // Copy other values directly
            elementCopy[propKey] = propValue;
          }
        });

        serializableConfig[key] = elementCopy;
      });

      // Save the serializable configuration
      await prefs.setString('appBarConfig', json.encode(serializableConfig));

      // Set flag that settings have changed
      _settingsChanged = true;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              Icon(Icons.check_circle, color: Colors.white),
              SizedBox(width: 10),
              Text('Configuración de la barra superior guardada'),
            ],
          ),
          behavior: SnackBarBehavior.floating,
          backgroundColor: Colors.green,
        ),
      );
      print('AppBar configuration saved successfully');
    } catch (e) {
      print('Error saving AppBar configuration: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error al guardar la configuración: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  // Function to get string name from IconData
  String _getStringFromIcon(IconData icon) {
    if (icon == Icons.people) return 'people';
    if (icon == Icons.school) return 'school';
    if (icon == Icons.school_outlined) return 'school_outlined';
    if (icon == Icons.elderly) return 'elderly';
    if (icon == Icons.directions_bus) return 'directions_bus';
    if (icon == Icons.map) return 'map';
    if (icon == Icons.local_offer) return 'local_offer';
    if (icon == Icons.inventory) return 'inventory';
    if (icon == Icons.confirmation_number) return 'confirmation_number';
    if (icon == Icons.receipt) return 'receipt';
    if (icon == Icons.attach_money) return 'attach_money';
    if (icon == Icons.mail) return 'mail';
    return 'error';
  }

  // Method to load button icons and spacing preferences
  Future<void> _loadButtonIconPreferences() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      setState(() {
        _iconSpacing = prefs.getDouble('iconSpacing') ?? 2.0;

        // Load button icons
        final Map<String, dynamic>? savedIcons =
        prefs.getString('buttonIcons') != null
            ? json.decode(prefs.getString('buttonIcons')!)
            : null;

        if (savedIcons != null) {
          savedIcons.forEach((key, value) {
            _buttonIcons[key] = value.toString();
          });
        }
      });
      print('Button icon preferences loaded: spacing=$_iconSpacing');
    } catch (e) {
      print('Error loading button icon preferences: $e');
    }
  }

  // Method to save button icons and spacing preferences
  Future<void> _saveButtonIconPreferences() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setDouble('iconSpacing', _iconSpacing);
      await prefs.setString('buttonIcons', json.encode(_buttonIcons));

      // Set flag that settings have changed
      _settingsChanged = true;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              Icon(Icons.check_circle, color: Colors.white),
              SizedBox(width: 10),
              Text('Preferencias de iconos guardadas'),
            ],
          ),
          behavior: SnackBarBehavior.floating,
          backgroundColor: Colors.green,
        ),
      );
      print('Button icon preferences saved: spacing=$_iconSpacing');
    } catch (e) {
      print('Error saving button icon preferences: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error al guardar preferencias de iconos: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  // Method to show icon selection dialog
  void _showIconSelectionDialog(String buttonName) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text('Seleccionar Ícono para "$buttonName"'),
          content: Container(
            width: double.maxFinite,
            child: GridView.builder(
              shrinkWrap: true,
              gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 4,
                mainAxisSpacing: 10,
                crossAxisSpacing: 10,
              ),
              itemCount: _availableIcons.length,
              itemBuilder: (context, index) {
                final iconInfo = _availableIcons[index];
                final bool isSelected = _buttonIcons[buttonName] ==
                    _getStringFromIcon(iconInfo['icon']);

                return InkWell(
                  onTap: () {
                    setState(() {
                      _buttonIcons[buttonName] = _getStringFromIcon(
                          iconInfo['icon']);
                    });
                    Navigator.of(context).pop();
                  },
                  child: Container(
                    decoration: BoxDecoration(
                      color: isSelected ? primaryColor.withOpacity(0.2) : Colors
                          .grey[200],
                      borderRadius: BorderRadius.circular(10),
                      border: isSelected ? Border.all(
                          color: primaryColor, width: 2) : null,
                    ),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          iconInfo['icon'],
                          size: 30,
                          color: isSelected ? primaryColor : Colors.grey[700],
                        ),
                        SizedBox(height: 5),
                        Text(
                          iconInfo['name'],
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: 10,
                            color: isSelected ? primaryColor : Colors.black,
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(context).pop();
              },
              child: Text('Cancelar'),
            ),
          ],
        );
      },
    );
  }

  // Método para cargar las abreviaturas
  Future<void> _loadAbbreviations() async {
    final prefs = await SharedPreferences.getInstance();

    // Inicializar controladores para cada abreviatura
    for (var key in _abbreviations.keys) {
      String value = prefs.getString(key) ?? _abbreviations[key]!;
      _abbreviations[key] = value; // Actualizar el mapa con el valor guardado
      _abbreviationControllers[key] = TextEditingController(text: value);
    }

    setState(() {});
  }

  // Método para guardar las abreviaturas
  Future<void> _saveAbbreviations() async {
    final prefs = await SharedPreferences.getInstance();

    // Guardar cada abreviatura
    for (var key in _abbreviations.keys) {
      String abbreviation = _abbreviationControllers[key]?.text ??
          _abbreviations[key]!;
      _abbreviations[key] = abbreviation; // Actualizar el mapa
      await prefs.setString(key, abbreviation);
    }

    // Indicar que se han cambiado las configuraciones
    _settingsChanged = true;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            Icon(Icons.check_circle, color: Colors.white),
            SizedBox(width: 10),
            Text('Abreviaturas guardadas correctamente'),
          ],
        ),
        behavior: SnackBarBehavior.floating,
        backgroundColor: Colors.green,
      ),
    );
  }

  Future<void> _loadDisplayPreferences() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      setState(() {
        _showIcons = prefs.getBool('showIcons') ?? true;
        _textSizeMultiplier = prefs.getDouble('textSizeMultiplier') ?? 0.8;
      });
      print(
          'Settings loaded: showIcons=$_showIcons, textSizeMultiplier=$_textSizeMultiplier');
    } catch (e) {
      print('Error al cargar preferencias de visualización: $e');
    }
  }

  Future<void> _saveDisplayPreferences() async {
    try {
      final prefs = await SharedPreferences.getInstance();

      // Debug print to see what we're saving
      print(
          'Saving settings: showIcons=$_showIcons, textSizeMultiplier=$_textSizeMultiplier');

      // Use await to ensure the values are actually saved
      await prefs.setBool('showIcons', _showIcons);
      await prefs.setDouble('textSizeMultiplier', _textSizeMultiplier);

      // Debug print to confirm values are saved
      print('Settings saved. Verifying...');
      bool? savedIcons = prefs.getBool('showIcons');
      double? savedSize = prefs.getDouble('textSizeMultiplier');
      print('Verified: showIcons=$savedIcons, textSizeMultiplier=$savedSize');

      // Set flag that settings have changed
      _settingsChanged = true;

      // Notificar a los usuarios inmediatamente
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              Icon(Icons.check_circle, color: Colors.white),
              SizedBox(width: 10),
              Text('Preferencias de visualización guardadas'),
            ],
          ),
          behavior: SnackBarBehavior.floating,
          backgroundColor: Colors.green,
          duration: Duration(seconds: 2),
          action: SnackBarAction(
            label: 'OK',
            textColor: Colors.white,
            onPressed: () {},
          ),
        ),
      );
    } catch (e) {
      print('Error al guardar preferencias de visualización: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error al guardar preferencias: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Future<void> _loadId() async {
    final prefs = await SharedPreferences.getInstance();
    int ticketId = prefs.getInt('ticketId') ?? 1;
    idController.text = ticketId.toString();
  }

  Future<void> _saveId() async {
    final prefs = await SharedPreferences.getInstance();
    int newId = int.tryParse(idController.text) ?? 1;

    if (newId >= 1 && newId <= 99) {
      await prefs.setInt('ticketId', newId);

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              Icon(Icons.check_circle, color: Colors.white),
              SizedBox(width: 10),
              Text('ID guardado: $newId'),
            ],
          ),
          behavior: SnackBarBehavior.floating,
          backgroundColor: Colors.green,
        ),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              Icon(Icons.error, color: Colors.white),
              SizedBox(width: 10),
              Text('Por favor, ingrese un ID válido (1-99)'),
            ],
          ),
          behavior: SnackBarBehavior.floating,
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Future<void> _resetComprobanteCounter() async {
    // Mostrar diálogo de confirmación
    bool confirm = await showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Row(
            children: [
              Icon(Icons.warning_amber_rounded, color: Colors.orange),
              SizedBox(width: 10),
              Text('Confirmar reinicio'),
            ],
          ),
          content: Text(
              '¿Está seguro que desea reiniciar el contador de comprobantes?'),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: Text('Cancelar'),
            ),
            ElevatedButton(
              onPressed: () => Navigator.of(context).pop(true),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red,
              ),
              child: Text('Reiniciar'),
            ),
          ],
        );
      },
    ) ?? false;

    if (confirm) {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setInt('comprobanteNumber', 1);

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              Icon(Icons.refresh, color: Colors.white),
              SizedBox(width: 10),
              Text('Contador de comprobantes reiniciado'),
            ],
          ),
          behavior: SnackBarBehavior.floating,
          backgroundColor: Colors.blue,
        ),
      );
    }
  }

  Future<String> _loadPassword() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString('password') ?? '232323';
  }

  Future<void> _savePassword(String newPassword) async {
    if (newPassword.length < 6) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              Icon(Icons.error, color: Colors.white),
              SizedBox(width: 10),
              Text('La contraseña debe tener 6 dígitos'),
            ],
          ),
          behavior: SnackBarBehavior.floating,
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('password', newPassword);

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            Icon(Icons.check_circle, color: Colors.white),
            SizedBox(width: 10),
            Text('Contraseña actualizada correctamente'),
          ],
        ),
        behavior: SnackBarBehavior.floating,
        backgroundColor: Colors.green,
      ),
    );
  }

  void _authenticate() async {
    String storedPassword = await _loadPassword();
    if (passwordController.text == storedPassword) {
      setState(() {
        isAuthenticated = true;
      });
      _loadId();
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              Icon(Icons.error, color: Colors.white),
              SizedBox(width: 10),
              Text('Contraseña incorrecta'),
            ],
          ),
          behavior: SnackBarBehavior.floating,
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return WillPopScope(
      onWillPop: () async {
        // When navigating back, if settings have changed, return true
        // to indicate changes to home screen
        Navigator.pop(context, _settingsChanged);
        return false; // Prevent default back action since we handle it manually
      },
      child: Scaffold(
        appBar: AppBar(
          title: Text(
            'Configuración',
            style: TextStyle(fontWeight: FontWeight.bold),
          ),
          backgroundColor: primaryColor,
          elevation: 0,
          centerTitle: true,
          actions: [
            if (isAuthenticated)
              IconButton(
                icon: Icon(Icons.logout),
                tooltip: 'Cerrar sesión',
                onPressed: () {
                  setState(() {
                    isAuthenticated = false;
                    passwordController.clear();
                  });
                },
              ),
          ],
          leading: IconButton(
            icon: Icon(Icons.arrow_back),
            onPressed: () {
              // Pass the _settingsChanged flag when popping
              Navigator.pop(context, _settingsChanged);
            },
          ),
        ),
        backgroundColor: backgroundColor,
        body: isAuthenticated
            ? _buildSettingsContent()
            : _buildAuthenticationForm(),
      ),
    );
  }

  Widget _buildAuthenticationForm() {
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [primaryColor, Colors.amber[100]!],
        ),
      ),
      child: Center(
        child: Card(
          margin: EdgeInsets.all(20),
          elevation: 10,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(15),
          ),
          child: Padding(
            padding: const EdgeInsets.all(20.0),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.security,
                  size: 60,
                  color: primaryColor,
                ),
                SizedBox(height: 20),
                Text(
                  'Ingrese la Contraseña',
                  style: TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                    color: textColor,
                  ),
                ),
                SizedBox(height: 20),
                TextField(
                  controller: passwordController,
                  decoration: InputDecoration(
                    labelText: 'Contraseña (6 dígitos)',
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                    prefixIcon: Icon(Icons.password, color: primaryColor),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                      borderSide: BorderSide(color: primaryColor, width: 2),
                    ),
                  ),
                  obscureText: true,
                  keyboardType: TextInputType.number,
                  maxLength: 6,
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 18, letterSpacing: 8),
                ),
                SizedBox(height: 20),
                SizedBox(
                  width: double.infinity,
                  height: 50,
                  child: ElevatedButton(
                    onPressed: _authenticate,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: primaryColor,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                      elevation: 5,
                    ),
                    child: Text(
                      'Ingresar',
                      style: TextStyle(
                          fontSize: 18, fontWeight: FontWeight.bold),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildSettingsContent() {
    final ticketModel = Provider.of<TicketModel>(context);
    final sundayTicketModel = Provider.of<SundayTicketModel>(context);

    return Column(
      children: [
        // Tabs en la parte superior
        Container(
          color: primaryColor,
          child: TabBar(
            controller: _tabController,
            indicator: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.only(
                topLeft: Radius.circular(10),
                topRight: Radius.circular(10),
              ),
            ),
            labelColor: primaryColor,
            unselectedLabelColor: Colors.white,
            isScrollable: true, // Make tabs scrollable
            tabs: [
              Tab(
                icon: Icon(Icons.settings),
                text: 'General',
              ),
              Tab(
                icon: Icon(Icons.attach_money),
                text: 'Precios',
              ),
              Tab(
                icon: Icon(Icons.brush),
                text: 'Apariencia',
              ),
              Tab(
                icon: Icon(Icons.short_text),
                text: 'Abreviaturas',
              ),
            ],
          ),
        ),

        // Contenido de las tabs
        Expanded(
          child: TabBarView(
            controller: _tabController,
            children: [
              // Pestaña 1: Configuración General
              _buildGeneralSettings(),

              // Pestaña 2: Configuración de Precios
              _buildPriceSettings(ticketModel, sundayTicketModel),

              // Pestaña 3: Configuración de Apariencia
              _buildAppearanceSettings(),

              // Pestaña 4: Configuración de Abreviaturas
              _buildAbbreviationSettings(),

              // Pestaña 5: Configuración de Barra Superior
              _buildAppBarLayoutSettings(),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildGeneralSettings() {
    return SingleChildScrollView(
      padding: EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildSectionCard(
            title: 'ID de Terminal',
            icon: Icons.tag,
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Identificador único para este dispositivo (1-99)',
                    style: TextStyle(color: Colors.grey[600]),
                  ),
                  SizedBox(height: 10),
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: idController,
                          decoration: InputDecoration(
                            labelText: 'ID',
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(10),
                            ),
                            prefixIcon: Icon(Icons.numbers),
                          ),
                          keyboardType: TextInputType.number,
                          maxLength: 2,
                          textAlign: TextAlign.center,
                          style: TextStyle(fontSize: 18, fontWeight: FontWeight
                              .bold),
                        ),
                      ),
                      SizedBox(width: 10),
                      ElevatedButton(
                        onPressed: _saveId,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: primaryColor,
                          padding: EdgeInsets.symmetric(
                              vertical: 15, horizontal: 20),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10),
                          ),
                        ),
                        child: Text('Guardar'),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),

          SizedBox(height: 20),
          _buildBackupRestoreSection(),
          SizedBox(height: 20),

          _buildSectionCard(
            title: 'Seguridad',
            icon: Icons.security,
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Cambiar contraseña de acceso (6 dígitos)',
                    style: TextStyle(color: Colors.grey[600]),
                  ),
                  SizedBox(height: 10),
                  TextField(
                    controller: passwordController,
                    decoration: InputDecoration(
                      labelText: 'Nueva Contraseña',
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                      prefixIcon: Icon(Icons.password),
                    ),
                    obscureText: true,
                    keyboardType: TextInputType.number,
                    maxLength: 6,
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 18, letterSpacing: 8),
                  ),
                  SizedBox(height: 10),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      onPressed: () {
                        _savePassword(passwordController.text);
                      },
                      icon: Icon(Icons.save),
                      label: Text('Guardar Contraseña'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: primaryColor,
                        padding: EdgeInsets.symmetric(vertical: 15),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),

          SizedBox(height: 20),

          // Version information added at the bottom
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Center(
              child: Text(
                'Versión de la Aplicación: $appVersion',
                style: TextStyle(
                  color: Colors.grey[600],
                  fontStyle: FontStyle.italic,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPriceSettings(TicketModel ticketModel,
      SundayTicketModel sundayTicketModel) {
    return SingleChildScrollView(
      padding: EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildSectionCard(
            title: 'Precios Lunes a Sábado',
            icon: Icons.calendar_today,
            child: ListView.separated(
              shrinkWrap: true,
              physics: NeverScrollableScrollPhysics(),
              itemCount: ticketModel.pasajes.length,
              separatorBuilder: (context, index) => Divider(height: 1),
              itemBuilder: (context, index) {
                return ListTile(
                  leading: CircleAvatar(
                    backgroundColor: Colors.blue[100],
                    child: _getIconForTicketType(
                        ticketModel.pasajes[index]['nombre']),
                  ),
                  title: Text(
                    ticketModel.pasajes[index]['nombre'],
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        padding: EdgeInsets.symmetric(
                            horizontal: 12, vertical: 6),
                        decoration: BoxDecoration(
                          color: Colors.blue[50],
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(color: Colors.blue[200]!),
                        ),
                        child: Text(
                          '\$${NumberFormat('#,##0', 'es_ES').format(
                              ticketModel.pasajes[index]['precio'])}',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                            color: Colors.blue[800],
                          ),
                        ),
                      ),
                      SizedBox(width: 8),
                      IconButton(
                        icon: Icon(Icons.edit, color: primaryColor),
                        onPressed: () {
                          _showEditDialog(context, ticketModel, index, true);
                        },
                      ),
                    ],
                  ),
                );
              },
            ),
          ),

          SizedBox(height: 20),

          _buildSectionCard(
            title: 'Precios Domingo y Feriados',
            icon: Icons.weekend,
            child: ListView.separated(
              shrinkWrap: true,
              physics: NeverScrollableScrollPhysics(),
              itemCount: sundayTicketModel.pasajes.length,
              separatorBuilder: (context, index) => Divider(height: 1),
              itemBuilder: (context, index) {
                return ListTile(
                  leading: CircleAvatar(
                    backgroundColor: Colors.red[100],
                    child: _getIconForTicketType(
                        sundayTicketModel.pasajes[index]['nombre']),
                  ),
                  title: Text(
                    sundayTicketModel.pasajes[index]['nombre'],
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        padding: EdgeInsets.symmetric(
                            horizontal: 12, vertical: 6),
                        decoration: BoxDecoration(
                          color: Colors.red[50],
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(color: Colors.red[200]!),
                        ),
                        child: Text(
                          '\$${NumberFormat('#,##0', 'es_ES').format(
                              sundayTicketModel.pasajes[index]['precio'])}',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                            color: Colors.red[800],
                          ),
                        ),
                      ),
                      SizedBox(width: 8),
                      IconButton(
                        icon: Icon(Icons.edit, color: primaryColor),
                        onPressed: () {
                          _showEditDialog(
                              context, sundayTicketModel, index, false);
                        },
                      ),
                    ],
                  ),
                );
              },
            ),
          ),

          SizedBox(height: 10),

          Center(
            child: Text(
              'Toque en el icono de lápiz para editar el nombre y precio',
              style: TextStyle(
                color: Colors.grey[600],
                fontStyle: FontStyle.italic,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAppearanceSettings() {
    return SingleChildScrollView(
      padding: EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildSectionCard(
            title: 'Apariencia de Botones',
            icon: Icons.palette,
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Switch para mostrar/ocultar íconos
                  SwitchListTile(
                    title: Text(
                      'Mostrar Íconos',
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                    subtitle: Text(
                        'Muestra íconos junto al texto en los botones'),
                    value: _showIcons,
                    activeColor: primaryColor,
                    onChanged: (value) {
                      setState(() {
                        _showIcons = value;
                      });
                    },
                    secondary: CircleAvatar(
                      backgroundColor: Colors.amber[100],
                      child: Icon(
                        _showIcons ? Icons.visibility : Icons.visibility_off,
                        color: primaryColor,
                      ),
                    ),
                  ),

                  Divider(),

                  // Add new section for icon spacing
                  if (_showIcons) ...[
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 8.0),
                      child: Column(
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text('Pequeño',
                                  style: TextStyle(color: Colors.grey[600])),
                              Text('Normal',
                                  style: TextStyle(color: Colors.grey[600])),
                              Text('Grande',
                                  style: TextStyle(color: Colors.grey[600])),
                            ],
                          ),
                          Slider(
                            value: _iconSpacing,
                            min: 2,
                            max: 20,
                            divisions: 9,
                            label: '${_iconSpacing.toInt()}px',
                            activeColor: primaryColor,
                            onChanged: (value) {
                              setState(() {
                                _iconSpacing = value;
                              });
                            },
                          ),
                          Center(
                            child: Container(
                              padding: EdgeInsets.symmetric(
                                  horizontal: 8, vertical: 8),
                              decoration: BoxDecoration(
                                color: primaryColor.withOpacity(0.1),
                                borderRadius: BorderRadius.circular(20),
                              ),
                              child: Text(
                                'Espacio: ${_iconSpacing.toInt()}px',
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  color: primaryColor,
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],

                  Divider(),

                  // Slider para ajustar el tamaño del texto
                  ListTile(
                    leading: CircleAvatar(
                      backgroundColor: Colors.amber[100],
                      child: Icon(Icons.format_size, color: primaryColor),
                    ),
                    title: Text(
                      'Tamaño del Texto',
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                    subtitle: Text('Ajuste el tamaño del texto en los botones'),
                  ),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16.0),
                    child: Column(
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text('Pequeño',
                                style: TextStyle(color: Colors.grey[600])),
                            Text('Normal',
                                style: TextStyle(color: Colors.grey[600])),
                            Text('Grande',
                                style: TextStyle(color: Colors.grey[600])),
                          ],
                        ),
                        Slider(
                          value: _textSizeMultiplier,
                          min: 0.5,
                          max: 1.1,
                          // Changed from 1.2 to 1.1 (110%)
                          divisions: 4,
                          // Changed from 7 to 4 divisions
                          label: '${(_textSizeMultiplier * 100).toInt()}%',
                          activeColor: primaryColor,
                          onChanged: (value) {
                            setState(() {
                              _textSizeMultiplier = value;
                            });
                          },
                        ),
                        Center(
                          child: Container(
                            padding: EdgeInsets.symmetric(
                                horizontal: 16, vertical: 8),
                            decoration: BoxDecoration(
                              color: primaryColor.withOpacity(0.1),
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: Text(
                              'Tamaño: ${(_textSizeMultiplier * 100).toInt()}%',
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                color: primaryColor,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),

                  SizedBox(height: 20),

                  // Vista previa de botón
                  Text(
                    'Vista Previa:',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                  SizedBox(height: 10),
                  Container(
                    height: 60,
                    decoration: BoxDecoration(
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black26,
                          blurRadius: 5,
                          offset: Offset(0, 2),
                        ),
                      ],
                    ),
                    child: ElevatedButton(
                      onPressed: null,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.blue,
                        foregroundColor: Colors.white,
                        disabledBackgroundColor: Colors.blue,
                        disabledForegroundColor: Colors.white,
                        side: BorderSide(color: Colors.black, width: 3),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          if (_showIcons) ...[
                            Icon(Icons.directions_bus,
                                size: 24 * _textSizeMultiplier),
                            SizedBox(width: _iconSpacing),
                            // Use the configurable spacing
                          ],
                          Text(
                            'Botón de Ejemplo',
                            style: TextStyle(
                              fontSize: 18 * _textSizeMultiplier,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),

                  SizedBox(height: 20),

                  // Botón para guardar las preferencias
                  SizedBox(
                    width: double.infinity,
                    height: 50,
                    child: ElevatedButton.icon(
                      onPressed: () {
                        _saveDisplayPreferences();
                        _saveButtonIconPreferences();
                      },
                      icon: Icon(Icons.save),
                      label: Text(
                        'Guardar Preferencias',
                        style: TextStyle(
                            fontSize: 16, fontWeight: FontWeight.bold),
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: primaryColor,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  // Method to build the AppBar layout settings tab
  Widget _buildAppBarLayoutSettings() {
    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildSectionCard(
            title: 'Personalizar Barra Superior',
            icon: Icons.view_compact,
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Image.asset(
                    'assets/appbar_preview.png',
                    width: double.infinity,
                    height: 80,
                    fit: BoxFit.cover,
                    errorBuilder: (context, error, stackTrace) {
                      return Container(
                        height: 80,
                        decoration: BoxDecoration(
                          color: Colors.amber[800],
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Center(
                          child: Text(
                            'Vista Previa de la Barra Superior',
                            style: TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      );
                    },
                  ),
                  SizedBox(height: 20),

                  // Description of the feature
                  Container(
                    padding: EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.blue[50],
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: Colors.blue[200]!),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Icon(Icons.info_outline, color: Colors.blue[800]),
                            SizedBox(width: 8),
                            Text(
                              'Personalización de la Barra Superior',
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                color: Colors.blue[800],
                              ),
                            ),
                          ],
                        ),
                        SizedBox(height: 8),
                        Text(
                          'Ajusta el orden y la disposición de los botones en la barra superior de la aplicación '
                              'mediante un simulador interactivo con arrastrar y soltar.',
                          style: TextStyle(color: Colors.blue[800]),
                        ),
                      ],
                    ),
                  ),

                  SizedBox(height: 24),
                  // Direct save button for the current configuration
                  SizedBox(
                    width: double.infinity,
                    height: 50,
                    child: ElevatedButton.icon(
                      icon: Icon(Icons.save),
                      label: Text(
                        'Guardar Configuración Actual',
                        style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold
                        ),
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.green,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                      ),
                      onPressed: _saveAppBarConfig,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDraggableAppBarElement(String key) {
    // Get properties from the element configuration
    final elementData = _appBarElements[key];
    final Color bgColor = elementData['bgColor'];
    final Color iconColor = elementData['iconColor'];
    final bool isText = elementData['isText'] ?? false;
    final String text = elementData['text'] ?? '';
    final bool isDate = elementData['isDate'] ?? false;

    // Widget to be displayed
    Widget elementWidget;

    if (isDate) {
      // Date display is special
      elementWidget = Padding(
        padding: const EdgeInsets.only(right: 5.0, left: 3.0),
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                'DD/MM/YYYY',
                style: TextStyle(
                    color: Colors.black,
                    fontSize: 12,
                    fontWeight: FontWeight.bold
                ),
              ),
              Text(
                'DÍA',
                style: TextStyle(
                    color: Colors.black,
                    fontSize: 12,
                    fontWeight: FontWeight.bold
                ),
              ),
            ],
          ),
        ),
      );
    } else {
      // Standard circle button
      elementWidget = Container(
        width: key == 'report' ? 25 : 34,  // Special size for report button
        height: key == 'report' ? 25 : 34,
        margin: key == 'report' ? EdgeInsets.only(left: 15) : null,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: bgColor,
        ),
        child: Center(
          child: isText
              ? Text(
            text,
            style: TextStyle(
              color: iconColor,
              fontWeight: FontWeight.bold,
              fontSize: 24,
            ),
            textAlign: TextAlign.center,
          )
              : Icon(
            elementData['icon'],
            color: iconColor,
            size: key == 'report' ? 24 : 24,
          ),
        ),
      );
    }

    // Wrap the element in a GestureDetector for horizontal drag
    return GestureDetector(
      onHorizontalDragUpdate: (details) {
        // Update margin based on drag
        setState(() {
          double newMargin = (elementData['margin'] + details.delta.dx * 0.5);
          // Constrain margin to reasonable values
          newMargin = newMargin.clamp(0.0, 20.0);
          elementData['margin'] = newMargin;
        });
      },
      child: Padding(
        padding: EdgeInsets.symmetric(horizontal: elementData['margin']),
        child: elementWidget,
      ),
    );
  }

  // Generate margin sliders for more precise control
  List<Widget> _buildMarginSliders() {
    List<Widget> sliders = [];

    for (String key in _appBarElements.keys) {
      final elementData = _appBarElements[key];

      sliders.add(
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(
                    elementData['isText'] ? (elementData['text'] == 'R' ? Icons.print : Icons.text_fields) : elementData['icon'],
                    color: primaryColor,
                    size: 20,
                  ),
                  SizedBox(width: 8),
                  Text(
                    'Margen de ${elementData['name']}',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                  Switch(
                    value: elementData['enabled'],
                    activeColor: primaryColor,
                    onChanged: (value) {
                      setState(() {
                        elementData['enabled'] = value;
                      });
                    },
                  ),
                ],
              ),
              Row(
                children: [
                  Text('0px', style: TextStyle(color: Colors.grey[600], fontSize: 12)),
                  Expanded(
                    child: Slider(
                      value: elementData['margin'],
                      min: 0,
                      max: 20,
                      divisions: 20,
                      label: '${elementData['margin'].toInt()}px',
                      activeColor: primaryColor,
                      onChanged: (value) {
                        setState(() {
                          elementData['margin'] = value;
                        });
                      },
                    ),
                  ),
                  Text('20px', style: TextStyle(color: Colors.grey[600], fontSize: 12)),
                  SizedBox(width: 8),
                  Container(
                    padding: EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                    decoration: BoxDecoration(
                      color: primaryColor.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Text(
                      '${elementData['margin'].toInt()}px',
                      style: TextStyle(fontWeight: FontWeight.bold, color: primaryColor),
                    ),
                  ),
                ],
              ),
              Divider(),
            ],
          )
      );
    }

    return sliders;
  }

  // Method to build individual AppBar element tiles
  Widget _buildAppBarElementTile(String key, int index) {
    return Card(
      key: ValueKey(key),
      elevation: 2,
      margin: EdgeInsets.only(bottom: 10),
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: Colors.grey[200],
          child: Icon(
            _appBarElements[key]['icon'],
            color: primaryColor,
          ),
        ),
        title: Text(
          _appBarElements[key]['name'],
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        subtitle: Text('Posición: ${index + 1}'),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Switch to enable/disable the element
            Switch(
              value: _appBarElements[key]['enabled'],
              activeColor: primaryColor,
              onChanged: (value) {
                setState(() {
                  _appBarElements[key]['enabled'] = value;
                });
              },
            ),
            // Drag handle
            Icon(Icons.drag_handle),
          ],
        ),
      ),
    );
  }

  // Nueva sección para configurar las abreviaturas
  Widget _buildAbbreviationSettings() {
    return SingleChildScrollView(
      padding: EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildSectionCard(
            title: 'Abreviaturas para Reportes',
            icon: Icons.short_text,
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Configure las abreviaturas que aparecerán en los reportes de caja',
                    style: TextStyle(color: Colors.grey[600]),
                  ),
                  SizedBox(height: 16),

                  ..._abbreviations.keys.map((key) {
                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Nombre original
                        Text(
                          'Texto original: $key',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            color: Colors.grey[800],
                          ),
                        ),
                        SizedBox(height: 8),

                        // Campo de entrada para la abreviatura
                        Row(
                          children: [
                            Expanded(
                              child: TextField(
                                controller: _abbreviationControllers[key],
                                decoration: InputDecoration(
                                  labelText: 'Abreviatura',
                                  hintText: 'Ejemplo: PG, Esc, AM',
                                  border: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(10),
                                  ),
                                  prefixIcon: Icon(Icons.edit_note),
                                ),
                                maxLength: 10, // Limitar longitud de abreviaturas
                              ),
                            ),
                          ],
                        ),
                        SizedBox(height: 16),
                        Divider(),
                        SizedBox(height: 8),
                      ],
                    );
                  }).toList(),

                  SizedBox(height: 20),

                  // Botón para guardar todas las abreviaturas
                  SizedBox(
                    width: double.infinity,
                    height: 50,
                    child: ElevatedButton.icon(
                      onPressed: _saveAbbreviations,
                      icon: Icon(Icons.save),
                      label: Text(
                        'Guardar Abreviaturas',
                        style: TextStyle(
                            fontSize: 16, fontWeight: FontWeight.bold),
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: primaryColor,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                      ),
                    ),
                  ),

                  SizedBox(height: 16),

                  // Información de ayuda
                  Container(
                    padding: EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.blue[50],
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: Colors.blue[200]!),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Icon(Icons.info_outline, color: Colors.blue[800]),
                            SizedBox(width: 8),
                            Text(
                              'Información',
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                color: Colors.blue[800],
                              ),
                            ),
                          ],
                        ),
                        SizedBox(height: 8),
                        Text(
                          'Las abreviaturas se utilizan en los reportes de caja para mostrar el tipo de transacción de forma compacta.',
                          style: TextStyle(color: Colors.blue[800]),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  // Widget auxiliar para crear tarjetas de sección
  Widget _buildSectionCard({
    required String title,
    required IconData icon,
    required Widget child,
  }) {
    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(15),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: primaryColor,
              borderRadius: BorderRadius.only(
                topLeft: Radius.circular(15),
                topRight: Radius.circular(15),
              ),
            ),
            child: Row(
              children: [
                Icon(icon, color: Colors.white),
                SizedBox(width: 8),
                Text(
                  title,
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 18,
                  ),
                ),
              ],
            ),
          ),
          child,
        ],
      ),
    );
  }

  // Función para obtener el ícono apropiado según el tipo de pasaje
  Icon _getIconForTicketType(String ticketName) {
    // First, check if we have a direct mapping for this ticket name
    if (_buttonIcons.containsKey(ticketName)) {
      String iconName = _buttonIcons[ticketName]!;
      IconData iconData = _getIconFromString(iconName);

      // Determine color based on ticket type (keeping consistent with original color scheme)
      Color iconColor;
      if (ticketName.contains('Público General')) {
        iconColor = Colors.orange;
      } else if (ticketName.contains('Escolar')) {
        iconColor = Colors.orange;
      } else if (ticketName.contains('Adulto Mayor')) {
        iconColor = Colors.orange;
      } else if (ticketName.contains('Int. hasta 15')) {
        iconColor = Colors.orange;
      } else if (ticketName.contains('Int. hasta 50')) {
        iconColor = Colors.orange;
      } else {
        iconColor = Colors.orange;
      }

      return Icon(iconData, color: iconColor);
    }

    // Fallback: if no custom icon is defined, use the default mapping
    if (ticketName.contains('Público General')) {
      return Icon(Icons.people, color: Colors.orange);
    } else if (ticketName.contains('Escolar')) {
      return Icon(Icons.school, color: Colors.orange);
    } else if (ticketName.contains('Adulto Mayor')) {
      return Icon(Icons.elderly, color: Colors.orange);
    } else if (ticketName.contains('Int. hasta 15')) {
      return Icon(Icons.directions_bus, color: Colors.orange);
    } else if (ticketName.contains('Int. hasta 50')) {
      return Icon(Icons.map, color: Colors.orange);
    } else {
      return Icon(Icons.mail, color: Colors.orange);
    }
  }

  void _showEditDialog(BuildContext context, dynamic model, int index,
      bool isTicketModel) {
    TextEditingController priceController = TextEditingController(
        text: model.pasajes[index]['precio'].toString());
    TextEditingController nameController = TextEditingController(
        text: model.pasajes[index]['nombre']);
    String originalName = model.pasajes[index]['nombre'];
    bool isEditing = true;

    // Obtener el ícono actual para este tipo de ticket
    String currentIconName = _buttonIcons[originalName] ?? 'people';
    IconData currentIcon = _getIconFromString(currentIconName);

    showDialog(
      context: context,
      builder: (BuildContext context) {
        return StatefulBuilder(
          builder: (context, setState) {
            return AlertDialog(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(15),
              ),
              title: Row(
                children: [
                  CircleAvatar(
                    backgroundColor: isTicketModel ? Colors.blue[100] : Colors
                        .red[100],
                    child: Icon(currentIcon,
                        color: isTicketModel ? Colors.blue : Colors.red),
                  ),
                  SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          'Editar Ticket',
                          style: TextStyle(fontWeight: FontWeight.bold),
                        ),
                        Text(
                          originalName,
                          style: TextStyle(
                            fontSize: 14,
                            color: Colors.grey[600],
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              content: SingleChildScrollView(
                child: isEditing
                    ? Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Nombre actual: $originalName',
                      style: TextStyle(
                          fontWeight: FontWeight.bold, color: Colors.grey[700]),
                    ),
                    SizedBox(height: 10),
                    TextField(
                      controller: nameController,
                      decoration: InputDecoration(
                        labelText: 'Nuevo nombre',
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                        prefixIcon: Icon(Icons.edit),
                      ),
                      autofocus: true,
                    ),
                    SizedBox(height: 15),
                    Text(
                      'Precio actual: \$${NumberFormat('#,##0', 'es_ES').format(
                          model.pasajes[index]['precio'])}',
                      style: TextStyle(
                          fontWeight: FontWeight.bold, color: Colors.grey[700]),
                    ),
                    SizedBox(height: 10),
                    TextField(
                      controller: priceController,
                      decoration: InputDecoration(
                        labelText: 'Nuevo precio',
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                        prefixIcon: Icon(Icons.attach_money),
                        prefixText: '\$',
                        helperText: 'Ingrese el nuevo precio sin puntos ni comas',
                      ),
                      keyboardType: TextInputType.number,
                      inputFormatters: [
                        FilteringTextInputFormatter.digitsOnly
                      ],
                    ),
                    SizedBox(height: 15),
                    Text(
                      'Seleccione un ícono:',
                      style: TextStyle(
                          fontWeight: FontWeight.bold, color: Colors.grey[700]),
                    ),
                    SizedBox(height: 10),
                    // Selección de íconos
                    Container(
                      height: 120,
                      decoration: BoxDecoration(
                        border: Border.all(color: Colors.grey.shade300),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: GridView.builder(
                        padding: EdgeInsets.all(8),
                        gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: 4,
                          mainAxisSpacing: 8,
                          crossAxisSpacing: 8,
                          childAspectRatio: 1,
                        ),
                        itemCount: _availableIcons.length,
                        itemBuilder: (context, iconIndex) {
                          final iconInfo = _availableIcons[iconIndex];
                          final bool isSelected = currentIcon ==
                              iconInfo['icon'];

                          return InkWell(
                            onTap: () {
                              setState(() {
                                currentIcon = iconInfo['icon'];
                                currentIconName =
                                    _getStringFromIcon(iconInfo['icon']);
                              });
                            },
                            child: Container(
                              decoration: BoxDecoration(
                                color: isSelected ? primaryColor.withOpacity(
                                    0.2) : Colors.grey[200],
                                borderRadius: BorderRadius.circular(10),
                                border: isSelected ? Border.all(
                                    color: primaryColor, width: 2) : null,
                              ),
                              child: Center(
                                child: Icon(
                                  iconInfo['icon'],
                                  size: 24,
                                  color: isSelected ? primaryColor : Colors
                                      .grey[700],
                                ),
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                  ],
                )
                    : Container(
                  padding: EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.green[50],
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: Colors.green),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.check_circle, color: Colors.green),
                      SizedBox(width: 8),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              'Nombre actualizado a:',
                              style: TextStyle(fontWeight: FontWeight.bold),
                            ),
                            Text(
                              nameController.text,
                              style: TextStyle(color: Colors.green[800]),
                            ),
                            SizedBox(height: 5),
                            Text(
                              'Precio actualizado a:',
                              style: TextStyle(fontWeight: FontWeight.bold),
                            ),
                            Text(
                              '\$${NumberFormat('#,##0', 'es_ES').format(
                                  double.parse(priceController.text))}',
                              style: TextStyle(color: Colors.green[800]),
                            ),
                            SizedBox(height: 5),
                            Text(
                              'Ícono actualizado:',
                              style: TextStyle(fontWeight: FontWeight.bold),
                            ),
                            Row(
                              children: [
                                Icon(currentIcon, color: Colors.green[800]),
                                SizedBox(width: 5),
                                Text(
                                  _availableIcons.firstWhere((
                                      icon) => icon['icon'] == currentIcon,
                                      orElse: () =>
                                      {
                                        'name': 'Desconocido'
                                      })['name'],
                                  style: TextStyle(color: Colors.green[800]),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () {
                    Navigator.of(context).pop();
                  },
                  child: Text('Cerrar'),
                ),
                if (isEditing)
                  ElevatedButton.icon(
                    icon: Icon(Icons.save),
                    label: Text('Guardar'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: primaryColor,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                    onPressed: () {
                      double newPrice = double.tryParse(priceController.text) ??
                          0;
                      String newName = nameController.text.trim();

                      // Validar datos antes de guardar
                      if (newPrice > 0 && newName.isNotEmpty) {
                        // Actualizar ticket
                        model.editPasaje(index, newName, newPrice);

                        // Actualizar el ícono para el nuevo nombre
                        _buttonIcons[newName] = currentIconName;

                        // Si el nombre cambió, eliminar la asignación anterior de ícono
                        if (newName != originalName) {
                          _buttonIcons.remove(originalName);
                        }

                        // Guardar preferencias de íconos
                        _saveButtonIconPreferences();

                        // Indicar que la configuración ha cambiado
                        _settingsChanged = true;

                        setState(() {
                          isEditing = false;
                        });
                      } else {
                        // Mostrar un mensaje de error si los datos son inválidos
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Row(
                              children: [
                                Icon(Icons.error, color: Colors.white),
                                SizedBox(width: 10),
                                Text(
                                    'Por favor, ingrese un nombre y precio válidos'),
                              ],
                            ),
                            behavior: SnackBarBehavior.floating,
                            backgroundColor: Colors.red,
                          ),
                        );
                      }
                    },
                  ),
              ],
            );
          },
        );
      },
    );
  }

  Widget _buildBackupRestoreSection() {
    return _buildSectionCard(
      title: 'Respaldo y Recuperación',
      icon: Icons.backup,
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Cree copias de seguridad de sus datos y restaure en caso de actualización o cambio de dispositivo',
              style: TextStyle(color: Colors.grey.shade600),
            ),
            SizedBox(height: 20),
            SizedBox(
              width: double.infinity,
              height: 50,
              child: ElevatedButton.icon(
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (context) => BackupScreen()),
                  );
                },
                icon: Icon(Icons.backup),
                label: Text(
                  'Gestionar Copias de Seguridad',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: primaryColor,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}