import 'dart:convert';
import 'package:flutter/services.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'cargo_screen.dart';
import '../utils/generateCargo_Ticket.dart';
import 'package:flutter/material.dart';
import 'package:pdf/pdf.dart';
import 'reporte_caja_screen.dart';
import '../utils/generateTicket.dart';
import 'settings.dart';
import '../utils/ReporteCaja.dart';
import '../models/ticket_model.dart';
import '../models/sunday_ticket_model.dart';
import 'package:intl/intl.dart';
import 'dart:async';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../utils/generate_mo_ticket.dart';
import '../models/ComprobanteModel.dart';
import '../utils/pdf_optimizer.dart';


class Home extends StatefulWidget {
  @override
  _HomeState createState() => _HomeState();
}

class _HomeState extends State<Home> {
  final PdfOptimizer pdfOptimizer = PdfOptimizer(); // Add PDF optimizer
  final GenerateTicket generateTicket = GenerateTicket();
  final MoTicketGenerator moTicketGenerator = MoTicketGenerator();
  bool _isButtonDisabled = false;
  bool _isLoading = false;
  late Timer _timer;
  String _currentDay = '';
  bool _switchValue = false;
  bool _hasReprinted = false;
  bool _hasAnulado = false;
  bool _isPhoneMode = true;
  bool _resourcesPreloaded = false; // Track if resources are preloaded
  final TextEditingController _offerController = TextEditingController();
  final TextEditingController _ownerController = TextEditingController();
  final TextEditingController _phoneController = TextEditingController();
  final TextEditingController _itemController = TextEditingController();
  final FocusNode _contactFocusNode = FocusNode();
  List<Map<String, dynamic>> _appBarSlots = List.generate(8, (index) => {'isEmpty': true, 'element': null});

  bool _hasPreviousDayTransactions() {
    final reporteCaja = Provider.of<ReporteCaja>(context, listen: false);
    final yesterday = DateTime.now().subtract(Duration(days: 1));
    final yDay = DateFormat('dd').format(yesterday);
    final yMonth = DateFormat('MM').format(yesterday);
    return reporteCaja
        .getOrderedTransactions()
        .any((t) =>
    t['dia'] == yDay
        && t['mes'] == yMonth
        && !t['nombre'].toString().startsWith('Anulación:')
    );
  }
  Future<void> _showPreviousDayAlert() async {
    await showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) {
        return AlertDialog(
          title: Text('Venta Denegada'),
          content: Text(
              'No es posible generar ventas porque existen transacciones del día anterior. '
                  'Por favor cierre la caja primero.'
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(),
              child: Text('Entendido'),
            ),
          ],
        );
      },
    );
  }

  // Variables para la configuración de botones
  bool _showIcons = true;
  double _textSizeMultiplier = 0.8;
  double _iconSpacing = 1.0;
  Map<String, IconData> _buttonIcons = {};

  // Variables para la función de reimpresión
  Map<String, dynamic>? _lastTransaction;
  bool _isReprinting = false;

  // Variables para configurar AppBar
  Map<String, dynamic> _appBarConfig = {
    'report': {'name': 'Reportes', 'icon': Icons.receipt, 'position': 0, 'enabled': true},
    'delete': {'name': 'Anular', 'icon': Icons.delete, 'position': 1, 'enabled': true},
    'reprint': {'name': 'Reimprimir', 'icon': Icons.print, 'position': 2, 'enabled': true},
    'settings': {'name': 'Configuración', 'icon': Icons.settings, 'position': 3, 'enabled': true},
    'date': {'name': 'Fecha/Día', 'icon': Icons.calendar_today, 'position': 4, 'enabled': true},
  };

  @override
  void initState() {
    super.initState();
    _initializeLocalization();
    _updateDay();
    _timer = Timer.periodic(Duration(milliseconds: 250), (timer) {
      _updateDay();
    });
    _isPhoneMode = true;

    // Iniciar precarga de recursos inmediatamente y en segundo plano
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      // Usar un try-catch para evitar que errores de precarga afecten la experiencia del usuario
      try {
        await _preloadPdfResourcesAsync();
      } catch (e) {
        print('Error en precarga de recursos: $e');
        // No mostramos el error al usuario para no afectar la experiencia
      }
    });

    _loadLastTransaction();
    _loadDisplayPreferences();
    _loadIconSettings();
    _loadAppBarConfig();
  }

// Nueva función para precargar recursos de manera asíncrona
  Future<void> _preloadPdfResourcesAsync() async {
    if (_resourcesPreloaded) return; // Evitar cargar múltiples veces

    print('Iniciando precarga de recursos en segundo plano...');

    // Crear completers para cada recurso a cargar
    final completer = Completer<void>();

    // Ejecutar en un microtask para evitar bloquear la UI
    Future.microtask(() async {
      try {
        // Precargar los recursos del PDF
        await pdfOptimizer.preloadResources();
        await generateTicket.preloadResources();

        // Precargar recursos para tickets de cargo si están disponibles
        try {
          final reporteCaja = Provider.of<ReporteCaja>(context, listen: false);
          final comprobanteModel = Provider.of<ComprobanteModel>(context, listen: false);
          final cargoGen = CargoTicketGenerator(comprobanteModel, reporteCaja);
          await cargoGen.preloadResources();
        } catch (e) {
          // Si hay un error al precargar recursos de cargo, no afecta la funcionalidad principal
          print('Advertencia: No se pudieron precargar recursos de cargo: $e');
        }

        // Marcar como completado
        setState(() {
          _resourcesPreloaded = true;
        });

        completer.complete();
        print('Precarga de recursos completada con éxito');
      } catch (e) {
        completer.completeError(e);
        print('Error durante la precarga de recursos: $e');
      }
    });

    return completer.future;
  }

// Modificar el método existente para verificar primero si ya está cargado
  Future<void> _preloadPdfResources() async {
    if (_resourcesPreloaded) {
      print('Recursos ya precargados, no es necesario cargar nuevamente');
      return;
    }

    // Si no está precargado, intentar cargar normalmente
    try {
      await _preloadPdfResourcesAsync();
    } catch (e) {
      print('Error al cargar recursos: $e');
      // Intentaremos nuevamente cuando sea necesario
      _resourcesPreloaded = false;
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _loadDisplayPreferences();
    _loadIconSettings();
    _loadAppBarConfig();
  }

  @override
  void dispose() {
    _timer.cancel();
    _offerController.dispose();
    _ownerController.dispose();
    _phoneController.dispose();
    _itemController.dispose();
    _contactFocusNode.dispose();
    super.dispose();
  }

  Future<void> _loadAppBarConfig() async {
    try {
      final prefs = await SharedPreferences.getInstance();

      // Try to load the slot-based configuration first
      final String? savedSlotsConfig = prefs.getString('appBarSlots');

      if (savedSlotsConfig != null) {
        List<dynamic> loadedSlots = json.decode(savedSlotsConfig);
        setState(() {
          _appBarSlots = List<Map<String, dynamic>>.from(loadedSlots);
        });
        print('Loaded AppBar config from slots format');
      } else {
        // Fall back to old configuration format
        final String? savedConfig = prefs.getString('appBarConfig');

        if (savedConfig != null) {
          Map<String, dynamic> loadedConfig = json.decode(savedConfig);

          // Convert old format to slot format
          // Explicitly define Map with dynamic values to avoid type inference issues
          var slots = List<Map<String, dynamic>>.generate(
              8,
                  (index) => <String, dynamic>{'isEmpty': true, 'element': null}
          );

          // Sort elements by position
          var sortedElements = loadedConfig.entries.toList()
            ..sort((a, b) => (a.value['position'] as int).compareTo(b.value['position'] as int));

          // Fill slots based on position
          for (var entry in sortedElements) {
            if (entry.value['enabled'] == true) {
              int position = entry.value['position'] as int;

              // Skip invalid positions
              if (position >= 0 && position < 8) {
                // Date should always be in slot 7
                if (entry.key == 'date') {
                  slots[7] = <String, dynamic>{'isEmpty': false, 'element': entry.key};
                } else if (slots[position]['isEmpty'] == true) {
                  slots[position] = <String, dynamic>{'isEmpty': false, 'element': entry.key};
                }
              }
            }
          }

          setState(() {
            _appBarSlots = slots;
          });
          print('Converted old AppBar config to slots format');
        } else {
          _setupDefaultAppBarConfig();
        }
      }
    } catch (e) {
      print('Error loading AppBar configuration: $e');
      _setupDefaultAppBarConfig();
    }
  }


  Future<void> _loadIconSettings() async {
    try {
      final prefs = await SharedPreferences.getInstance();

      setState(() {
        _iconSpacing = prefs.getDouble('iconSpacing') ?? 1.0;
      });

      final Map<String, dynamic>? savedIcons =
      prefs.getString('buttonIcons') != null
          ? json.decode(prefs.getString('buttonIcons')!)
          : null;

      if (savedIcons != null) {
        setState(() {
          _buttonIcons.clear();
          savedIcons.forEach((key, value) {
            _buttonIcons[key] = _getIconFromString(value.toString());
          });
        });
      }

      print('Icon settings loaded: spacing=$_iconSpacing, icons=${_buttonIcons.length}');
    } catch (e) {
      print('Error loading icon settings: $e');
    }
  }

  void _setupDefaultAppBarConfig() {
    setState(() {
      _appBarSlots = List.generate(8, (index) => {'isEmpty': true, 'element': null});

      _appBarSlots[0] = {'isEmpty': false, 'element': 'report'};
      _appBarSlots[1] = {'isEmpty': false, 'element': 'mail'};  // Mail button in position 1 (2nd position)
      _appBarSlots[4] = {'isEmpty': false, 'element': 'delete'};
      _appBarSlots[5] = {'isEmpty': false, 'element': 'reprint'};
      _appBarSlots[6] = {'isEmpty': false, 'element': 'settings'};
      _appBarSlots[7] = {'isEmpty': false, 'element': 'date'};
    });
  }


  Widget _buildAppBarSlotWidget(int index) {
    if (index >= _appBarSlots.length || _appBarSlots[index]['isEmpty'] == true) {
      return Container();
    }

    String? elementKey = _appBarSlots[index]['element'] as String?;
    if (elementKey == null) {
      return Container();
    }

    // Additional margin parameter
    double leftMargin = _appBarSlots[index]['leftMargin'] ?? 0.0;

    // Report button (usually in slot 0)
    if (elementKey == 'report') {
      return Container(
        width: 25,
        height: 25,
        margin: EdgeInsets.only(left: 20 + leftMargin), // Add leftMargin to existing margin
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: Color(0xFF1900A2),
        ),
        child: IconButton(
          icon: Icon(
            Icons.receipt,
            color: Colors.white,
            size: 24,
          ),
          padding: EdgeInsets.zero,
          tooltip: 'Reportes',
          onPressed: () {
            Navigator.push(
              context,
              MaterialPageRoute(builder: (context) => ReporteCajaScreen()),
            );
          },
        ),
      );
    }
    // Delete button
    else if (elementKey == 'delete') {
      return Padding(
        padding: const EdgeInsets.symmetric(horizontal: 3.0),
        child: Consumer<ReporteCaja>(
          builder: (context, reporteCaja, child) {
            bool canAnular = reporteCaja.hasActiveTransactions() && !_hasAnulado;
            return Container(
              width: 35,
              height: 35,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: canAnular ? Color(0xFFFF0C00) : Colors.white,
              ),
              child: Material(
                color: Colors.transparent,
                child: InkWell(
                  borderRadius: BorderRadius.circular(21),
                  onTap: canAnular ? () async {
                    await _showPasswordDialog();
                  } : null,
                  child: Center(
                    child: Icon(
                      Icons.delete,
                      color: Colors.black,
                      size: 24,
                    ),
                  ),
                ),
              ),
            );
          },
        ),
      );
    }

    // Reprint button
// Reprint button
    else if (elementKey == 'reprint') {
      // ¿La última transacción es de cargo?
      bool isCargo = _lastTransaction != null
          && _lastTransaction!['nombre']
              .toString()
              .toLowerCase()
              .contains('cargo');
      // ¿Podemos reimprimir? — Siempre para cargo, o solo una vez para otros
      bool canReprint = _lastTransaction != null
          && !_isReprinting
          && (isCargo || !_hasReprinted);

      return Padding(
        padding: const EdgeInsets.symmetric(horizontal: 3.0),
        child: Container(
          width: 34,
          height: 34,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: canReprint ? Color(0xFFFFD71F) : Colors.white,
          ),
          child: Material(
            color: Colors.transparent,
            child: InkWell(
              borderRadius: BorderRadius.circular(21),
              onTap: canReprint ? _handleReprint : null,
              child: Center(
                child: Image.asset(
                  'assets/reprint.png',
                  width: 20,
                  height: 20,
                  fit: BoxFit.contain,
                ),
              ),
            ),
          ),
        ),
      );
    }

    // Settings button
    else if (elementKey == 'settings') {
      return Padding(
        padding: const EdgeInsets.symmetric(horizontal: 3.0),
        child: Container(
          width: 34,
          height: 34,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: Color(0xFF00910B),
          ),
          child: Material(
            color: Colors.transparent,
            child: InkWell(
              borderRadius: BorderRadius.circular(21),
              onTap: _navigateToSettings,
              child: Center(
                child: Icon(
                  Icons.settings,
                  color: Colors.white,
                  size: 24,
                ),
              ),
            ),
          ),
        ),
      );
    }

    // Date display
    else if (elementKey == 'date') {
      return Padding(
        padding: const EdgeInsets.only(right: 5.0, left: 3.0),
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                getCurrentDate(),
                style: TextStyle(
                    color: Colors.black,
                    fontSize: 12,
                    fontWeight: FontWeight.bold
                ),
              ),
              Text(
                _currentDay,
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
    }

    // Default empty widget for unknown elements
    return Container();
  }

  IconData _getIconFromString(String iconName) {
    switch (iconName) {
      case 'people': return Icons.people;
      case 'school': return Icons.school;
      case 'school_outlined': return Icons.school_outlined;
      case 'elderly': return Icons.elderly;
      case 'directions_bus': return Icons.directions_bus;
      case 'map': return Icons.map;
      case 'local_offer': return Icons.local_offer;
      case 'inventory': return Icons.inventory;
      case 'confirmation_number': return Icons.confirmation_number;
      case 'receipt': return Icons.receipt;
      case 'attach_money': return Icons.attach_money;
      case 'mail': return Icons.mail;
      default: return Icons.error;
    }
  }

  IconData _getButtonIcon(String buttonName, IconData defaultIcon) {
    return _buttonIcons[buttonName] ?? defaultIcon;
  }

  Future<void> _loadDisplayPreferences() async {
    try {
      final prefs = await SharedPreferences.getInstance();

      final showIcons = prefs.getBool('showIcons');
      final textSizeMultiplier = prefs.getDouble('textSizeMultiplier');

      print('Loading display preferences: showIcons=$showIcons, textSizeMultiplier=$textSizeMultiplier');

      setState(() {
        if (showIcons != null) _showIcons = showIcons;
        if (textSizeMultiplier != null) _textSizeMultiplier = textSizeMultiplier;
      });

      print('Updated state: _showIcons=$_showIcons, _textSizeMultiplier=$_textSizeMultiplier');
    } catch (e) {
      print('Error loading display preferences: $e');
    }
  }

  Future<void> _initializeLocalization() async {
    await initializeDateFormatting('es_ES', null);
  }

  Future<void> _loadLastTransaction() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      String? lastTransactionJson = prefs.getString('lastTransaction');

      if (lastTransactionJson != null && lastTransactionJson.isNotEmpty) {
        setState(() {
          _lastTransaction = jsonDecode(lastTransactionJson);
          _hasReprinted = false;
        });
      }
    } catch (e) {
      print('Error al cargar la última transacción: $e');
    }
  }

  Future<void> _saveLastTransaction(Map<String, dynamic> transaction) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('lastTransaction', jsonEncode(transaction));

      setState(() {
        _lastTransaction = transaction;
        _hasReprinted = false;
        _hasAnulado = false;
      });
    } catch (e) {
      print('Error al guardar la última transacción: $e');
    }
  }

  void _updateDay() {
    setState(() {
      _currentDay = DateFormat('EEEE', 'es_ES').format(DateTime.now()).toUpperCase();
    });
  }

  String getCurrentDate() {
    return DateFormat('dd/MM/yyyy').format(DateTime.now());
  }

  String _formatContactInfo(String value, bool isPhone) {
    if (isPhone) {
      if (value.length < 8) return value;
      return '${value.substring(0, 1)} ${value.substring(1, 5)} ${value.substring(5)}';
    } else {
      return value;
    }
  }

  Future<String> _loadPassword() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString('password') ?? '232323';
  }

  Future<void> _generateTicket(String tipo, double valor, bool isCorrespondencia) async {
    if (_hasPreviousDayTransactions()) {
      await _showPreviousDayAlert();
      return;
    }

    if (_isButtonDisabled) return;

    setState(() {
      _hasReprinted = false;
      _hasAnulado = false;
      _isButtonDisabled = true;
      _isLoading = true;
    });

    // Show a SnackBar with shorter duration (2 seconds instead of 5)
    final snackBar = SnackBar(
      content: Row(
        children: [
          SizedBox(
            width: 20,
            height: 20,
            child: CircularProgressIndicator(
              strokeWidth: 2,
              valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
            ),
          ),
          SizedBox(width: 10),
          Text('Generando ticket de $tipo...'),
        ],
      ),
      duration: Duration(seconds: 2), // Reduced from 5 seconds
    );
    ScaffoldMessenger.of(context).showSnackBar(snackBar);

    try {
      final comprobanteModel = Provider.of<ComprobanteModel>(context, listen: false);
      await generateTicket.generateTicketPdf(
          context,
          valor,
          _switchValue,
          tipo,
          _ownerController.text,
          _formatContactInfo(_phoneController.text, _isPhoneMode),
          _itemController.text,
          comprobanteModel,
          false
      );

      // Update the latest transaction
      setState(() {
        _lastTransaction = {
          'nombre': tipo,
          'valor': valor,
          'switchValue': _switchValue,
          'comprobante': comprobanteModel.formattedComprobante,
        };
      });

      // Show success confirmation
      ScaffoldMessenger.of(context).hideCurrentSnackBar();
      ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Ticket generado correctamente'),
            backgroundColor: Colors.green,
            duration: Duration(seconds: 1),
          )
      );
    } catch (e) {
      print('Error generando ticket: $e');
      ScaffoldMessenger.of(context).hideCurrentSnackBar();
      ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error al generar ticket'),
            backgroundColor: Colors.red,
          )
      );
    } finally {
      setState(() {
        _isButtonDisabled = false;
        _isLoading = false;
      });
    }
  }

  // Método para verificar si el total es igual a 0
  bool _isTotalZero(List<Map<String, dynamic>> offerEntries) {
    double total = offerEntries.fold(0.0, (sum, entry) {
      double number = double.tryParse(entry['number'] ?? '0') ?? 0.0;
      double value = double.tryParse(entry['value'] ?? '0') ?? 0.0;
      return sum + (number * value);
    });
    return total == 0;
  }

  // Métodos de reimpresión
  void _handleReprint() async {
    // 1) Si no es cargo y ya reimpreso, bloqueo
    if (_hasReprinted
        && _lastTransaction != null
        && !_lastTransaction!['nombre']
            .toString()
            .toLowerCase()
            .contains('cargo')) {
      ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(
              'Ya se ha reimpreso este boleto. Genere uno nuevo para reimprimir.'
          ))
      );
      return;
    }

    // 2) Sin última transacción
    if (_lastTransaction == null) {
      ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('No hay transacción para reimprimir'))
      );
      return;
    }

    // 3) Pedir contraseña
    bool ok = await _showReprintPasswordDialog();
    if (!ok) return;

    // 4) Cargo → muestro siempre opciones Cliente/Carga/Ambas
    final nombre = _lastTransaction!['nombre'].toString().toLowerCase();
    if (nombre.contains('cargo')) {
      await _showLastCargoReprintOptions();
    } else {
      // Resto → flujo actual (una única reimpresión)
      await _showReprintOptionsDialog();
      // marcar como reimpreso
      setState(() { _hasReprinted = true; });
    }
  }



  Future<bool> _showReprintPasswordDialog() async {
    final TextEditingController passwordController = TextEditingController();
    bool isAuthenticated = false;

    await showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20.0),
          ),
          elevation: 24,
          title: Row(
            children: [
              Icon(Icons.print, color: Colors.yellow.shade600, size: 32),
              SizedBox(width: 10),
              Expanded(
                child: Text(
                    'Reimpresión de Boleta',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: Colors.yellow.shade800,
                      fontSize: 20,
                    )
                ),
              ),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Animación de advertencia
              AnimatedContainer(
                duration: Duration(milliseconds: 500),
                padding: EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.blue.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.blue.withOpacity(0.3), width: 2),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.blue.withOpacity(0.2),
                      blurRadius: 10,
                      spreadRadius: 1,
                    )
                  ],
                ),
                child: Row(
                  children: [
                    Icon(Icons.info_outline, color: Colors.yellow.shade800, size: 28),
                    SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        'Autenticación requerida para reimprimir boletas.',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          color: Colors.black,
                          fontSize: 15,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              SizedBox(height: 20),

              Text(
                  'Ingrese la contraseña para continuar:',
                  style: TextStyle(
                      fontWeight: FontWeight.w500,
                      fontSize: 16
                  )
              ),
              SizedBox(height: 10),
              TextField(
                controller: passwordController,
                decoration: InputDecoration(
                  labelText: 'Contraseña',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(color: Colors.yellow.shade300, width: 2),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(color: Colors.yellow.shade300, width: 2),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(color: Colors.yellow.shade500, width: 2),
                  ),
                  helperText: 'Máximo 6 dígitos',
                  prefixIcon: Icon(Icons.password, color: Colors.yellow.shade500),
                  filled: true,
                  fillColor: Colors.blue.shade50,
                ),
                obscureText: true,
                keyboardType: TextInputType.number,
                inputFormatters: [
                  FilteringTextInputFormatter.digitsOnly,
                  LengthLimitingTextInputFormatter(6),
                ],
                style: TextStyle(fontSize: 18, letterSpacing: 8),
              ),
            ],
          ),
          actions: [
            Container(
              margin: EdgeInsets.only(bottom: 10, right: 10),
              child: TextButton(
                onPressed: () {
                  Navigator.of(context).pop();
                },
                style: TextButton.styleFrom(
                  padding: EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
                child: Text(
                  'Cancelar',
                  style: TextStyle(
                    fontSize: 16,
                    color: Colors.grey.shade700,
                  ),
                ),
              ),
            ),
            Container(
              margin: EdgeInsets.only(bottom: 10, right: 10),
              child: ElevatedButton.icon(
                icon: Icon(Icons.check_circle_outline, color: Colors.white),
                label: Text(
                  'Continuar',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.yellow.shade600,
                  foregroundColor: Colors.white,
                  padding: EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                  elevation: 4,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
                onPressed: () async {
                  String inputPassword = passwordController.text;
                  String storedPassword = await _loadPassword();

                  if (inputPassword == storedPassword) {
                    isAuthenticated = true;
                    Navigator.of(context).pop();
                  } else {
                    ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Row(
                            children: [
                              Icon(Icons.error_outline, color: Colors.white),
                              SizedBox(width: 10),
                              Text('Contraseña incorrecta'),
                            ],
                          ),
                          backgroundColor: Colors.red.shade700,
                          behavior: SnackBarBehavior.floating,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10),
                          ),
                        )
                    );
                  }
                },
              ),
            ),
          ],
          actionsPadding: EdgeInsets.only(right: 10),
          contentPadding: EdgeInsets.fromLTRB(24, 20, 24, 24),
          titlePadding: EdgeInsets.fromLTRB(24, 24, 24, 10),
          backgroundColor: Colors.white,
        );
      },
    );

    return isAuthenticated;
  }

// 1. Diálogo para mostrar opciones de reimpresión (rediseñado)
  Future<void> _showReprintOptionsDialog() async {
    await showDialog<void>(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          title: Row(
            children: [
              Icon(Icons.print, color: Colors.yellow.shade600, size: 32),
              SizedBox(width: 10),
              Expanded(
                child: Text(
                  'Opciones de Reimpresión',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: Colors.amber.shade800,
                    fontSize: 20,
                  ),
                ),
              ),
            ],
          ),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (_lastTransaction != null && !_hasReprinted)
                  ListTile(
                    leading: Icon(Icons.receipt_long, color: Colors.blue, size: 28),
                    title: Text(
                      'Reimprimir última transacción',
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                    subtitle: Text(_lastTransaction!['nombre'] ?? 'Transacción'),
                    trailing: Icon(Icons.arrow_forward_ios, color: Colors.grey),
                    onTap: () {
                      Navigator.of(context).pop();
                      _handleLastTransactionReprint();
                    },
                  ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: Text(
                'Cancelar',
                style: TextStyle(color: Colors.grey.shade700),
              ),
            ),
          ],
        );
      },
    );
  }



// 2. Diálogo para mostrar opciones de cargo para reimprimir (rediseñado)
  Future<void> _showLastCargoReprintOptions() async {
    return showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Row(
            children: [
              Icon(
                Icons.inventory,
                color: Colors.orange,
                size: 28,
              ),
              SizedBox(width: 10),
              Expanded(
                child: Text('Reimprimir Último Cargo', style: TextStyle(fontWeight: FontWeight.bold)),
              ),
            ],
          ),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Información del cargo
                Container(
                  padding: EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: Colors.orange.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.orange.withOpacity(0.5)),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Detalles del Cargo:',
                        style: TextStyle(fontWeight: FontWeight.bold),
                      ),
                      SizedBox(height: 8),
                      Text('Destinatario: ${_lastTransaction!['destinatario'] ?? 'No disponible'}'),
                      Text('Comprobante: ${_lastTransaction!['comprobante'] ?? 'No disponible'}'),
                    ],
                  ),
                ),
                SizedBox(height: 15),
                Text(
                  '¿Qué boleta desea reimprimir?',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                  textAlign: TextAlign.center,
                ),
                SizedBox(height: 20),
              ],
            ),
          ),
          actions: [
            // Fila de botones en dos columnas
            Container(
              width: double.infinity,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Primera fila: Cliente y Carga
                  Row(
                    children: [
                      // Botón Cliente (Azul)
                      Expanded(
                        child: Padding(
                          padding: const EdgeInsets.only(right: 4.0, bottom: 4.0),
                          child: ElevatedButton.icon(
                            icon: Icon(Icons.person, color: Colors.white),
                            label: Text(
                              'Cliente',
                              style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                            ),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.blue,
                              padding: EdgeInsets.symmetric(vertical: 12),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(8),
                              ),
                            ),
                            onPressed: () {
                              Navigator.of(context).pop();
                              _reprintCargoTicket(true, false);
                            },
                          ),
                        ),
                      ),

                      // Botón Carga (Verde)
                      Expanded(
                        child: Padding(
                          padding: const EdgeInsets.only(left: 4.0, bottom: 4.0),
                          child: ElevatedButton.icon(
                            icon: Icon(Icons.local_shipping, color: Colors.white),
                            label: Text(
                              'Carga',
                              style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                            ),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.green,
                              padding: EdgeInsets.symmetric(vertical: 12),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(8),
                              ),
                            ),
                            onPressed: () {
                              Navigator.of(context).pop();
                              _reprintCargoTicket(false, true);
                            },
                          ),
                        ),
                      ),
                    ],
                  ),

                  // Segunda fila: Ambas y Cancelar
                  Row(
                    children: [
                      // Botón Ambas (Naranja)
                      Expanded(
                        child: Padding(
                          padding: const EdgeInsets.only(right: 4.0, top: 4.0),
                          child: ElevatedButton.icon(
                            icon: Icon(Icons.print, color: Colors.white),
                            label: Text(
                              'Ambas',
                              style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                            ),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.orange,
                              padding: EdgeInsets.symmetric(vertical: 12),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(8),
                              ),
                            ),
                            onPressed: () {
                              Navigator.of(context).pop();
                              _reprintCargoTicket(true, true);
                            },
                          ),
                        ),
                      ),

                      // Botón Cancelar (Gris)
                      Expanded(
                        child: Padding(
                          padding: const EdgeInsets.only(left: 4.0, top: 4.0),
                          child: ElevatedButton.icon(
                            icon: Icon(Icons.cancel, color: Colors.white),
                            label: Text(
                              'Cancelar',
                              style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                            ),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.grey,
                              padding: EdgeInsets.symmetric(vertical: 12),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(8),
                              ),
                            ),
                            onPressed: () {
                              Navigator.of(context).pop();
                            },
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        );
      },
    );
  }

// Método auxiliar para construir filas de detalles de cargo
  Widget _buildCargoDetailRow(String label, String value) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          flex: 35,
          child: Text(
            label,
            style: TextStyle(
              fontWeight: FontWeight.bold,
              color: Colors.grey.shade700,
            ),
          ),
        ),
        Expanded(
          flex: 65,
          child: Text(
            value,
            style: TextStyle(
              fontWeight: FontWeight.w500,
            ),
          ),
        ),
      ],
    );
  }

  void _handleLastTransactionReprint() async {
    if (_lastTransaction == null) {
      ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('No hay transacción para reimprimir'))
      );
      return;
    }

    setState(() {
      _isReprinting = true;
    });

    try {
      // Check transaction type by name
      String nombre = _lastTransaction!['nombre'] ?? '';

      if (nombre.toLowerCase().contains('cargo')) {
        // For cargo type, show reprint options
        await _showLastCargoReprintOptions();
      } else if (nombre == 'Oferta Ruta' || _lastTransaction!['tipo'] == 'ofertaMultiple') {
        // For offer type
        await _reprintOfferTicket();
      } else {
        // For regular tickets
        await _reprintRegularTicket();
      }

      // Only mark as reprinted if not a cargo transaction
      if (!nombre.toLowerCase().contains('cargo')) {
        setState(() {
          _hasReprinted = true;
        });
      }
    } catch (e) {
      print('Error al reimprimir: $e');
      ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error al reimprimir: $e'))
      );
    } finally {
      setState(() {
        _isReprinting = false;
      });
    }
  }

  Future<void> _reprintOfferTicket() async {
    try {
      // Verificar que existe la información necesaria
      if (_lastTransaction == null || _lastTransaction!['offerEntries'] == null) {
        ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('No hay suficientes detalles para reimprimir'))
        );
        return;
      }

      Provider.of<ComprobanteModel>(context, listen: false);
      String comprobante = _lastTransaction!['comprobante'] ?? '';
      bool switchValue = _lastTransaction!['switchValue'] ?? false;

      // Convertir la información guardada en formato utilizable por el generador
      List savedEntries = _lastTransaction!['offerEntries'] as List;

      // Crear lista de entradas con los datos necesarios y los controladores
      List<Map<String, dynamic>> offerEntries = [];
      for (var entry in savedEntries) {
        offerEntries.add({
          'number': entry['number'],
          'value': entry['value'],
          'numberController': TextEditingController(text: entry['number']),
          'valueController': TextEditingController(text: entry['value']),
        });
      }

      // Mostrar indicador de progreso
      setState(() {
        _isReprinting = true;
      });

      // Llamar al método de reimpresión
      await moTicketGenerator.reprintMoTicket(
          PdfPageFormat.standard,
          offerEntries,
          switchValue,
          context,
          comprobante
      );

      // Después de reimprimir exitosamente
      setState(() {
        _hasReprinted = true; // Marcar como reimpreso
      });

      ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Reimpresión completada correctamente'))
      );

    } catch (e) {
      print('Error en _reprintOfferTicket: $e');
      ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error al reimprimir: $e'))
      );
    } finally {
      setState(() {
        _isReprinting = false;
      });
    }
  }
  // Reimprimir un boleto normal
  Future<void> _reprintRegularTicket() async {
    final comprobanteModel = Provider.of<ComprobanteModel>(context, listen: false);

    // No incrementar el número de comprobante para reimpresión
    String tipo = _lastTransaction!['nombre'] ?? '';
    double valor = _lastTransaction!['valor'] ?? 0.0;
    bool switchValue = _lastTransaction!['switchValue'] ?? false;

    await generateTicket.generateTicketPdf(
      context,
      valor,
      switchValue,
      tipo,
      '', // Sin destinatario
      '', // Sin teléfono
      '', // Sin artículo
      comprobanteModel,
      true, // Indicar que es una reimpresión
    );

    setState(() {
      _hasReprinted = true;
    });
  }

  Future<void> _reprintCargoTicket(bool printClient, bool printCargo) async {
    final comprobanteModel = Provider.of<ComprobanteModel>(context, listen: false);
    final reporteCaja      = Provider.of<ReporteCaja>(context, listen: false);
    final cargoGen         = CargoTicketGenerator(comprobanteModel, reporteCaja);

    try {
      // Extraemos los campos de _lastTransaction
      final String destinatario = _lastTransaction!['destinatario'] as String? ?? '';
      final String articulo     = _lastTransaction!['articulo']    as String? ?? '';
      final double valor        = _lastTransaction!['precio']      as double? ?? 0.0;
      final String destino      = _lastTransaction!['destino']     as String? ?? '';
      final String telefono     = _lastTransaction!['telefono']    as String? ?? '';

      // Obtenemos el comprobante actual (no incrementa en reimpresión)
      final String ticketNum = comprobanteModel.formattedComprobante;

      // Llamada con los 8 parámetros correctos
      await cargoGen.reprintNewCargoPdf(
        destinatario,
        articulo,
        valor,
        destino,
        telefono,
        printClient,
        printCargo,
        ticketNum,
      );

      setState(() { _hasReprinted = true; });
      ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Reimpresión completada correctamente'))
      );
    } catch (e) {
      print('Error en _reprintCargoTicket: $e');
      ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error al reimprimir: $e'))
      );
      setState(() { _hasReprinted = false; });
    }
  }

// Método para mostrar diálogo de oferta múltiple (modificado con actualización de total en tiempo real)
  Future<void> _showMultiOfferDialog() async {
    // 1) Bloquear si hay transacciones del día anterior
    if (_hasPreviousDayTransactions()) {
      await _showPreviousDayAlert();
      return;
    }

    // Asegurar que los recursos estén precargados
    if (!_resourcesPreloaded) {
      await _preloadPdfResources();
    }

    final reporteCaja = Provider.of<ReporteCaja>(context, listen: false);
    // Formateador solo para miles, sin decimales
    final decimalFormatter = NumberFormat.decimalPattern('es_CL');

    List<Map<String, dynamic>> offerEntries = [
      {
        'numberController': TextEditingController(),
        'valueController': TextEditingController(),
        'numberFocus': FocusNode(),
        'valueFocus': FocusNode(),
      }
    ];

    // Variable para guardar el valor total actual
    double currentTotal = 0.0;


    // Función para calcular el total actual basado en entradas
    double calculateTotal(List<Map<String, dynamic>> entries) {
      return entries.fold(0.0, (sum, e) {
        final qty = double.tryParse(e['numberController'].text) ?? 0;
        final val = double.tryParse(e['valueController'].text) ?? 0;
        return sum + qty * val;
      });
    }

    await showGeneralDialog(
      context: context,
      barrierDismissible: false,
      barrierLabel: 'Oferta Ruta',
      transitionDuration: Duration(milliseconds: 300),
      pageBuilder: (ctx, anim1, anim2) {
        return StatefulBuilder(
          builder: (BuildContext dialogContext, StateSetter dialogSetState) {
            bool isLoading = false;

            // Configura los listeners de texto para actualizar el total en tiempo real
            void setupControllerListeners() {
              for (var entry in offerEntries) {
                // Add null checks before calling methods
                final numberController = entry['numberController'] as TextEditingController?;
                final valueController = entry['valueController'] as TextEditingController?;

                if (numberController != null) {
                  numberController.removeListener(() {});
                  numberController.addListener(() {
                    dialogSetState(() {
                      currentTotal = calculateTotal(offerEntries);
                    });
                  });
                }

                if (valueController != null) {
                  valueController.removeListener(() {});
                  valueController.addListener(() {
                    dialogSetState(() {
                      currentTotal = calculateTotal(offerEntries);
                    });
                  });
                }
              }
            }

            // Configurar listeners para la primera entrada al inicio
            if (currentTotal == 0.0) {
              setupControllerListeners();
            }

            Future<void> _submitAndPrint() async {
              dialogSetState(() => isLoading = true);
              Navigator.of(dialogContext).pop();
              if (!mounted) return;
              setState(() {
                _isButtonDisabled = true;
                _isLoading = true;
              });

              try {
                // Mostrar feedback al usuario
                ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('Generando oferta...'),
                      duration: Duration(milliseconds: 800),
                    )
                );

                final entriesForTicket = offerEntries.map((e) => {
                  'number': e['numberController'].text,
                  'value': e['valueController'].text,
                }).toList();

                await moTicketGenerator.generateMoTicket(
                  PdfPageFormat.standard,
                  entriesForTicket,
                  _switchValue,
                  context,
                      (String nombre, double valor, List<double> subtots, String comprobante) {
                    reporteCaja.addOfferEntries(subtots, valor, comprobante);
                    if (!mounted) return;
                    setState(() {
                      _lastTransaction = {
                        'nombre': 'Oferta Ruta',
                        'valor': currentTotal,
                        'switchValue': _switchValue,
                        'comprobante': comprobante,
                        'offerEntries': entriesForTicket,
                        'tipo': 'ofertaMultiple',
                      };
                      _hasReprinted = false;
                      _hasAnulado = false;
                    });
                  },
                );

                // Mostrar mensaje de éxito
                ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('Oferta generada correctamente'),
                      backgroundColor: Colors.green,
                    )
                );
              } catch (e) {
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                        content: Text('Error al imprimir: $e'),
                        backgroundColor: Colors.red
                    ),
                  );
                  // Liberar recursos en caso de error
                  _clearCacheIfNeeded();
                }
              } finally {
                if (!mounted) return;
                setState(() {
                  _isButtonDisabled = false;
                  _isLoading = false;
                });
              }
            }

            // UI del diálogo con actualización en tiempo real
            return Scaffold(
              backgroundColor: Colors.white,
              appBar: AppBar(
                backgroundColor: Colors.amber.shade800,
                title: Text('Oferta en Ruta'),
                actions: [
                  IconButton(
                    icon: Icon(Icons.close),
                    onPressed: () => Navigator.of(dialogContext).pop(),
                  )
                ],
              ),
              body: Padding(
                padding: EdgeInsets.all(16),
                child: Column(
                  children: [
                    Expanded(
                      child: ListView.builder(
                        itemCount: offerEntries.length,
                        itemBuilder: (_, i) {
                          final e = offerEntries[i];
                          return Row(
                            children: [
                              Expanded(
                                flex: 2,
                                child: TextField(
                                  controller: e['numberController'],
                                  focusNode: e['numberFocus'],
                                  decoration: InputDecoration(
                                    labelText: 'Cantidad',
                                    border: OutlineInputBorder(),
                                  ),
                                  keyboardType: TextInputType.number,
                                  onChanged: (_) {
                                    // Asegurar que la actualización ocurra inmediatamente
                                    dialogSetState(() {
                                      currentTotal = calculateTotal(offerEntries);
                                    });
                                  },
                                ),
                              ),
                              SizedBox(width: 8),
                              Expanded(
                                flex: 3,
                                child: TextField(
                                  controller: e['valueController'],
                                  focusNode: e['valueFocus'],
                                  decoration: InputDecoration(
                                    labelText: 'Valor',
                                    border: OutlineInputBorder(),
                                  ),
                                  keyboardType: TextInputType.number,
                                  onChanged: (_) {
                                    // Asegurar que la actualización ocurra inmediatamente
                                    dialogSetState(() {
                                      currentTotal = calculateTotal(offerEntries);
                                    });
                                  },
                                ),
                              ),
                              if (offerEntries.length > 1) ...[
                                IconButton(
                                  icon: Icon(Icons.remove_circle, color: Colors.red),
                                  onPressed: () {
                                    dialogSetState(() {
                                      offerEntries.removeAt(i);
                                      // Recalcular total después de eliminar una línea
                                      currentTotal = calculateTotal(offerEntries);
                                    });
                                  },
                                )
                              ]
                            ],
                          );
                        },
                      ),
                    ),
                    SizedBox(height: 16),
                    Container(
                      padding: EdgeInsets.symmetric(vertical: 12, horizontal: 16),
                      decoration: BoxDecoration(
                        color: Colors.amber.shade50,
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: Colors.amber.shade200),
                      ),
                      child: Row(
                        children: [
                          Text(
                              'Total:',
                              style: TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.amber.shade800
                              )
                          ),
                          Spacer(),
                          Text(
                              '\$${decimalFormatter.format(currentTotal)}',
                              style: TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.amber.shade800
                              )
                          ),
                        ],
                      ),
                    ),
                    SizedBox(height: 16),
                    if (!isLoading)
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          ElevatedButton.icon(
                            onPressed: () {
                              dialogSetState(() {
                                // Agregar nueva línea
                                final newEntry = {
                                  'numberController': TextEditingController(),
                                  'valueController': TextEditingController(),
                                  'numberFocus': FocusNode(),
                                  'valueFocus': FocusNode(),
                                };
                                offerEntries.add(newEntry);

                                // Configurar listeners para la nueva entrada con verificación de nulidad
                                final newNumberController = newEntry['numberController'] as TextEditingController?;
                                final newValueController = newEntry['valueController'] as TextEditingController?;

                                if (newNumberController != null) {
                                  newNumberController.addListener(() {
                                    dialogSetState(() {
                                      currentTotal = calculateTotal(offerEntries);
                                    });
                                  });
                                }

                                if (newValueController != null) {
                                  newValueController.addListener(() {
                                    dialogSetState(() {
                                      currentTotal = calculateTotal(offerEntries);
                                    });
                                  });
                                }
                              });
                            },
                            icon: Icon(Icons.add),
                            label: Text('Agregar línea'),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.blue,
                              foregroundColor: Colors.white,
                            ),
                          ),
                          ElevatedButton.icon(
                            onPressed: _submitAndPrint,
                            icon: Icon(Icons.print),
                            label: Text('Imprimir'),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.amber.shade800,
                              foregroundColor: Colors.white,
                            ),
                          ),
                        ],
                      )
                    else
                      Center(
                          child: CircularProgressIndicator(
                            valueColor: AlwaysStoppedAnimation<Color>(Colors.amber.shade800),
                          )
                      ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  void _showOfferDialog() {
    if (_hasPreviousDayTransactions()) {
      _showPreviousDayAlert();
      return;
    }
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => CargoScreen(
          onTransactionComplete: (transactionData) {
            _saveLastTransaction(transactionData);
          },
        ),
      ),
    );
  }

  // Modificar el diálogo de contraseña para anular venta
  Future<void> _showPasswordDialog() async {
    if (_hasAnulado) {
      ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Ya se ha anulado una venta. Genere un nuevo boleto para poder anular de nuevo.'))
      );
      return;
    }

    final TextEditingController passwordController = TextEditingController();

    return showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20.0),
          ),
          elevation: 24,
          title: Row(
            children: [
              Icon(
                Icons.warning_amber_rounded,
                color: Colors.orange,
                size: 32,
              ),
              SizedBox(width: 10),
              Expanded(
                child: Text(
                    'Anular Última Venta',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: Colors.red.shade800,
                      fontSize: 20,
                    )
                ),
              ),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Animación de advertencia
              AnimatedContainer(
                duration: Duration(milliseconds: 500),
                padding: EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.red.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.red.withOpacity(0.3), width: 2),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.red.withOpacity(0.2),
                      blurRadius: 10,
                      spreadRadius: 1,
                    )
                  ],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(Icons.error_outline, color: Colors.red.shade800, size: 28),
                        SizedBox(width: 8),
                        Text(
                          '¡ADVERTENCIA!',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            color: Colors.red.shade800,
                            fontSize: 18,
                          ),
                        ),
                      ],
                    ),
                    SizedBox(height: 10),
                    Text(
                      'Esta acción no se puede deshacer y quedará registrada en el cierre de caja.',
                      style: TextStyle(
                        color: Colors.red.shade800,
                        fontSize: 15,
                      ),
                    ),
                  ],
                ),
              ),
              SizedBox(height: 20),
              Text(
                  'Ingrese la contraseña para confirmar:',
                  style: TextStyle(
                      fontWeight: FontWeight.w500,
                      fontSize: 16
                  )
              ),
              SizedBox(height: 10),
              TextField(
                controller: passwordController,
                decoration: InputDecoration(
                  labelText: 'Contraseña',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(color: Colors.red.shade300, width: 2),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(color: Colors.red.shade300, width: 2),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(color: Colors.red.shade500, width: 2),
                  ),
                  helperText: 'Máximo 6 dígitos',
                  prefixIcon: Icon(Icons.password, color: Colors.red.shade500),
                  filled: true,
                  fillColor: Colors.red.shade50,
                ),
                obscureText: true,
                keyboardType: TextInputType.number,
                inputFormatters: [
                  FilteringTextInputFormatter.digitsOnly,
                  LengthLimitingTextInputFormatter(6),
                ],
                style: TextStyle(fontSize: 18, letterSpacing: 8),
              ),
            ],
          ),
          actions: <Widget>[
            Container(
              margin: EdgeInsets.only(bottom: 10, right: 10),
              child: TextButton(
                onPressed: () {
                  Navigator.of(context).pop();
                },
                style: TextButton.styleFrom(
                  padding: EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
                child: Text(
                  'Cancelar',
                  style: TextStyle(
                    fontSize: 16,
                    color: Colors.grey.shade700,
                  ),
                ),
              ),
            ),
            Container(
              margin: EdgeInsets.only(bottom: 10, right: 10),
              child: ElevatedButton.icon(
                icon: Icon(Icons.delete_outline, color: Colors.white),
                label: Text(
                  'Anular',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.red.shade600,
                  foregroundColor: Colors.white,
                  padding: EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                  elevation: 4,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
                onPressed: () async {
                  String inputPassword = passwordController.text;
                  String storedPassword = await _loadPassword();

                  if (inputPassword == storedPassword) {
                    Navigator.of(context).pop();
                    await _cancelLastTransaction();
                  } else {
                    ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Row(
                            children: [
                              Icon(Icons.error_outline, color: Colors.white),
                              SizedBox(width: 10),
                              Text('Contraseña incorrecta.'),
                            ],
                          ),
                          backgroundColor: Colors.red.shade700,
                          behavior: SnackBarBehavior.floating,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10),
                          ),
                        )
                    );
                  }
                },
              ),
            ),
          ],
          actionsPadding: EdgeInsets.only(right: 10),
          contentPadding: EdgeInsets.fromLTRB(24, 20, 24, 24),
          titlePadding: EdgeInsets.fromLTRB(24, 24, 24, 10),
          backgroundColor: Colors.white,
        );
      },
    );
  }

  Future<void> _cancelLastTransaction() async {
    final prefs = await SharedPreferences.getInstance();

    int comprobanteNumber = prefs.getInt('comprobanteNumber') ?? 1;

    if (comprobanteNumber > 1) {
      comprobanteNumber--;
      await prefs.setInt('comprobanteNumber', comprobanteNumber);
    }

    final reporteCaja = Provider.of<ReporteCaja>(context, listen: false);
    reporteCaja.cancelTransaction();

    setState(() {
      _hasAnulado = true;
    });

    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Última venta anulada.')));
  }

  void _navigateToSettings() async {
    final settingsChanged = await Navigator.push<bool>(
      context,
      MaterialPageRoute(builder: (context) => Settings()),
    );

    if (settingsChanged == true) {
      print('Settings changed, reloading preferences');
      await _loadDisplayPreferences();
      setState(() {});
    }
  }

  Widget _buildConfigurableButton({
    required String text,
    required IconData icon,
    required Color backgroundColor,
    required Color borderColor,
    required Function() onPressed,
    bool isDisabled = false,
    Color textColor = Colors.white,
  }) {
    double screenWidth = MediaQuery.of(context).size.width;
    double buttonWidth = screenWidth - (MediaQuery.of(context).size.width * 0.1);
    double textSize = buttonWidth * 0.056;

    IconData buttonIcon = _getButtonIcon(text, icon);

    return Container(
      constraints: BoxConstraints(
        minHeight: 60,
      ),
      child: ElevatedButton(
        onPressed: isDisabled ? null : onPressed,
        style: ElevatedButton.styleFrom(
          backgroundColor: backgroundColor,
          side: BorderSide(
            color: borderColor,
            width: 3,
          ),
          foregroundColor: textColor,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          disabledBackgroundColor: Colors.grey,
          padding: EdgeInsets.symmetric(vertical: 12, horizontal: 8),
        ),
        child: _showIcons
            ? Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              buttonIcon,
              size: textSize * _textSizeMultiplier * 0.9,
            ),
            SizedBox(width: 0),
            Flexible(
              child: Text(
                text,
                style: TextStyle(
                  fontSize: textSize * _textSizeMultiplier,
                  height: 1.2,
                ),
                textAlign: TextAlign.center,
                maxLines: 2,
                overflow: TextOverflow.visible,
              ),
            ),
          ],
        )
            : Padding(
          padding: EdgeInsets.symmetric(horizontal: 4),
          child: Text(
            text,
            style: TextStyle(
              fontSize: textSize * _textSizeMultiplier,
              height: 1.2,
            ),
            textAlign: TextAlign.center,
            maxLines: 2,
            overflow: TextOverflow.visible,
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    double marginSize = MediaQuery.of(context).size.width * 0.05;
    double screenWidth = MediaQuery.of(context).size.width;
    double buttonWidth = screenWidth - (marginSize * 2);
    double buttonHeight = 60;
    double textSize = buttonWidth * 0.06;
    double buttonMargin = 9.0;
    double _reportButtonLeftMargin = 15;

    final ticketModel = Provider.of<TicketModel>(context);
    final sundayTicketModel = Provider.of<SundayTicketModel>(context);

    List<Map<String, dynamic>> pasajes = _switchValue
        ? sundayTicketModel.pasajes
        : ticketModel.pasajes;

    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.amber[800],
        automaticallyImplyLeading: false,
        title: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            // Grupo izquierdo - 3 botones juntos con márgenes ajustables
            Row(
              children: [
                // Botón Reportes
                Container(
                  width: 35,
                  height: 35,
                  margin: EdgeInsets.only(left: _reportButtonLeftMargin, right: buttonMargin), // Margen izquierdo configurable
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: Color(0xFF1900A2),
                  ),
                  child: IconButton(
                    icon: Icon(
                      Icons.receipt,
                      color: Colors.white,
                      size: 24,
                    ),
                    padding: EdgeInsets.zero,
                    tooltip: 'Reportes',
                    onPressed: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(builder: (context) => ReporteCajaScreen()),
                      );
                    },
                  ),
                ),

                // Botón Reimprimir
                Container(
                  width: 35,
                  height: 35,
                  margin: EdgeInsets.symmetric(horizontal: buttonMargin), // Margen ajustable a ambos lados
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: _lastTransaction == null || _isReprinting || _hasReprinted ? Colors.white : Color(0xFFFFD71F),
                  ),
                  child: Material(
                    color: Colors.transparent,
                    child: InkWell(
                      borderRadius: BorderRadius.circular(21),
                      onTap: _lastTransaction == null || _isReprinting || _hasReprinted ? null : _handleReprint,
                      child: Center(
                        child: Image.asset(
                          'assets/reprint.png',
                          width: 32,
                          height: 32,
                          fit: BoxFit.contain,
                        ),
                      ),
                    ),
                  ),
                ),

                // Botón Anular
                Consumer<ReporteCaja>(
                  builder: (context, reporteCaja, child) {
                    bool canAnular = reporteCaja.hasActiveTransactions() && !_hasAnulado;
                    return Container(
                      width: 35,
                      height: 35,
                      margin: EdgeInsets.symmetric(horizontal: buttonMargin), // Margen ajustable a ambos lados
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: canAnular ? Color(0xFFFF0C00) : Colors.white,
                      ),
                      child: Material(
                        color: Colors.transparent,
                        child: InkWell(
                          borderRadius: BorderRadius.circular(21),
                          onTap: canAnular ? () async {
                            await _showPasswordDialog();
                          } : null,
                          child: Center(
                            child: Icon(
                              Icons.delete,
                              color: Colors.black,
                              size: 24,
                            ),
                          ),
                        ),
                      ),
                    );
                  },
                ),
              ],
            ),

            // Espacio flexible en el medio
            Spacer(),

            // Grupo derecho - 2 botones + fecha/día
            Row(
              children: [
                // Botón Ajustes
                Container(
                  width: 35,
                  height: 35,
                  margin: EdgeInsets.symmetric(horizontal: 10),                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: Color(0xFF00910B),
                  ),
                  child: Material(
                    color: Colors.transparent,
                    child: InkWell(
                      borderRadius: BorderRadius.circular(21),
                      onTap: _navigateToSettings,
                      child: Center(
                        child: Icon(
                          Icons.settings,
                          color: Colors.white,
                          size: 24,
                        ),
                      ),
                    ),
                  ),
                ),

                // Fecha y Día
                Container(
                  margin: EdgeInsets.only(left: 0, right: 5),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        getCurrentDate(),
                        style: TextStyle(
                            color: Colors.black,
                            fontSize: 15,
                            fontWeight: FontWeight.bold
                        ),
                      ),
                      Text(
                        _currentDay,
                        style: TextStyle(
                            color: Colors.black,
                            fontSize: 15,
                            fontWeight: FontWeight.bold
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ],
        ),
        titleSpacing: 0,
      ),

      body: Container(
        decoration: BoxDecoration(
          image: DecorationImage(
            image: AssetImage(
              _switchValue ? 'assets/bgRojo.png' : 'assets/bgBlanco.png',
            ),
            fit: BoxFit.cover,
          ),
        ),
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.only(top: 10.0, left: 10.0, right: 10.0),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Container(
                    height: 50,
                    width: 150,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(13),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black26,
                          blurRadius: 2,
                          offset: Offset(0, 1),
                        ),
                      ],
                    ),
                    child: Stack(
                      alignment: Alignment.center,
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: Container(
                                decoration: BoxDecoration(
                                  color: Color(0xFF1900A2),
                                  borderRadius: BorderRadius.only(
                                    topLeft: Radius.circular(13),
                                    bottomLeft: Radius.circular(13),
                                  ),
                                ),
                              ),
                            ),

                            Expanded(
                              child: Container(
                                decoration: BoxDecoration(
                                  color: Color(0xFFFF0C00),
                                  borderRadius: BorderRadius.only(
                                    topRight: Radius.circular(13),
                                    bottomRight: Radius.circular(13),
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),

                        Positioned(
                          left: 13,
                          child: Consumer<ReporteCaja>(
                            builder: (context, reporteCaja, child) {
                              DateTime today = DateTime.now();
                              String todayDay = DateFormat('dd').format(today);
                              String todayMonth = DateFormat('MM').format(today);

                              var allTransactions = reporteCaja.getOrderedTransactions();
                              var todayTransactions = allTransactions.where((t) =>
                              t['dia'] == todayDay && t['mes'] == todayMonth &&
                                  !t['nombre'].toString().startsWith('Anulación:')
                              ).toList();

                              return Text(
                                '${todayTransactions.length}',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 23,
                                ),
                                textAlign: TextAlign.center,
                              );
                            },
                          ),
                        ),

                        Positioned(
                          right: 13,
                          child: Consumer<ReporteCaja>(
                            builder: (context, reporteCaja, child) {
                              DateTime today = DateTime.now();
                              String todayDay = DateFormat('dd').format(today);
                              String todayMonth = DateFormat('MM').format(today);

                              var allTransactions = reporteCaja.getOrderedTransactions();
                              var todayAnulaciones = allTransactions.where((t) =>
                              t['dia'] == todayDay && t['mes'] == todayMonth &&
                                  t['nombre'].toString().startsWith('Anulación:')
                              ).toList();

                              return Text(
                                '${todayAnulaciones.length}',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 23,
                                ),
                                textAlign: TextAlign.center,
                              );
                            },
                          ),
                        ),

                        Consumer<ReporteCaja>(
                          builder: (context, reporteCaja, child) {
                            DateTime today = DateTime.now();
                            String todayDay = DateFormat('dd').format(today);
                            String todayMonth = DateFormat('MM').format(today);

                            var allTransactions = reporteCaja.getOrderedTransactions();

                            var todayTransactions = allTransactions.where((t) =>
                            t['dia'] == todayDay && t['mes'] == todayMonth &&
                                !t['nombre'].toString().startsWith('Anulación:')
                            ).toList();

                            var todayAnulaciones = allTransactions.where((t) =>
                            t['dia'] == todayDay && t['mes'] == todayMonth &&
                                t['nombre'].toString().startsWith('Anulación:')
                            ).toList();

                            int netCount = todayTransactions.length - todayAnulaciones.length;

                            return Container(
                              width: 60,
                              height: 40,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                color: Colors.green,
                                border: Border.all(color: Colors.white, width: 1.5),
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.black38,
                                    blurRadius: 3,
                                    offset: Offset(0, 5),
                                  ),
                                ],
                              ),
                              child: Center(
                                child: Text(
                                  '$netCount',
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.bold,
                                    fontSize: 18,
                                  ),
                                  textAlign: TextAlign.center,
                                ),
                              ),
                            );
                          },
                        ),
                      ],
                    ),
                  ),

                  Consumer<ComprobanteModel>(
                    builder: (context, comprobanteModel, child) {
                      return Container(
                        height: 36,
                        width: 100,
                        padding: EdgeInsets.symmetric(horizontal: 15),
                        decoration: BoxDecoration(
                          color: Colors.orange,
                          borderRadius: BorderRadius.circular(13),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black26,
                              blurRadius: 2,
                              offset: Offset(0, 1),
                            ),
                          ],
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              Icons.receipt_long,
                              color: Colors.white,
                              size: 20,
                            ),
                            SizedBox(width: 5),
                            Text(
                              '${comprobanteModel.comprobanteNumber}',
                              style: TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                                fontSize: 20,
                              ),
                            ),
                          ],
                        ),
                      );
                    },
                  ),
                ],
              ),
            ),

            Expanded(
              child: Center(
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    // Contenedor del switch a la izquierda
                    Container(
                      decoration: BoxDecoration(
                        color: Colors.black.withOpacity(0.5),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      padding: EdgeInsets.all(8),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Stack(
                            children: [
                              Text(
                                _switchValue ? 'Domingo/Feriado' : 'Lunes a Sábado',
                                style: TextStyle(
                                  fontFamily: 'Hemiheads',
                                  fontSize: textSize * 1,
                                  foreground: Paint()
                                    ..style = PaintingStyle.stroke
                                    ..strokeWidth = 2
                                    ..color = Colors.black,
                                ),
                              ),
                              Text(
                                _switchValue ? 'Domingo/Feriado' : 'Lunes a Sábado',
                                style: TextStyle(
                                  fontFamily: 'Hemiheads',
                                  fontSize: textSize * 1,
                                  color: _switchValue ? Colors.red : Colors.white,
                                ),
                              ),
                            ],
                          ),
                          SizedBox(height: 5),

                          Switch(
                            value: _switchValue,
                            onChanged: (value) {
                              setState(() {
                                _switchValue = value;
                              });
                            },
                            activeColor: Colors.red,
                            activeTrackColor: Colors.red.withOpacity(0.5),
                          ),
                        ],
                      ),
                    ),

                    // Columna derecha con botón de emergencia y logo
                    Container(
                      margin: const EdgeInsets.only(right: 16.0),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Image.asset(
                            'assets/logo.png',
                            width: 130,
                            height: 100,
                            fit: BoxFit.contain,
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),

            // Primera fila: Público General | Intermedio hasta 50kms
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                SizedBox(
                  width: (buttonWidth / 2) - 10,
                  height: buttonHeight,
                  child: _buildConfigurableButton(
                    text: pasajes[0]['nombre'],
                    icon: Icons.people,
                    backgroundColor: _switchValue ? Colors.grey : Colors.red,
                    borderColor: _switchValue ? Colors.blueAccent : Colors.black,
                    onPressed: () {
                      _generateTicket(pasajes[0]['nombre'], pasajes[0]['precio'], false);
                    },
                    isDisabled: _isButtonDisabled,
                  ),
                ),

                SizedBox(
                  width: (buttonWidth / 2) - 10,
                  height: buttonHeight,
                  child: _buildConfigurableButton(
                    text: pasajes[4]['nombre'],
                    icon: Icons.map,
                    backgroundColor: _switchValue ? Colors.red : Colors.green,
                    borderColor: _switchValue ? Colors.pinkAccent : Colors.black,
                    onPressed: () {
                      _generateTicket(pasajes[4]['nombre'], pasajes[4]['precio'], false);
                    },
                    isDisabled: _isButtonDisabled,
                  ),
                ),
              ],
            ),
            SizedBox(height: 5),

            // Segunda fila: Escolar | Intermedio hasta 15 km
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                SizedBox(
                  width: (buttonWidth / 2) - 10,
                  height: buttonHeight,
                  child: _buildConfigurableButton(
                    text: pasajes[1]['nombre'],
                    icon: Icons.school,
                    backgroundColor: _switchValue ? Colors.red : Colors.green,
                    borderColor: _switchValue ? Colors.pinkAccent : Colors.black,
                    onPressed: () {
                      _generateTicket(pasajes[1]['nombre'], pasajes[1]['precio'], false);
                    },
                    isDisabled: _isButtonDisabled,
                  ),
                ),

                SizedBox(
                  width: (buttonWidth / 2) - 10,
                  height: buttonHeight,
                  child: _buildConfigurableButton(
                    text: pasajes[3]['nombre'],
                    icon: Icons.directions_bus,
                    backgroundColor: _switchValue ? Colors.red : Colors.blue,
                    borderColor: _switchValue ? Colors.pinkAccent : Colors.black,
                    onPressed: () {
                      _generateTicket(pasajes[3]['nombre'], pasajes[3]['precio'], false);
                    },
                    isDisabled: _isButtonDisabled,
                  ),
                ),
              ],
            ),
            SizedBox(height: 5),

            // Tercera fila: Adulto Mayor | Escolar Intermedio
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                SizedBox(
                  width: (buttonWidth / 2) - 10,
                  height: buttonHeight,
                  child: _buildConfigurableButton(
                    text: pasajes[2]['nombre'],
                    icon: Icons.elderly,
                    backgroundColor: _switchValue ? Colors.green : Colors.blue,
                    borderColor: _switchValue ? Colors.yellowAccent : Colors.black,
                    onPressed: () {
                      _generateTicket(pasajes[2]['nombre'], pasajes[2]['precio'], false);
                    },
                    isDisabled: _isButtonDisabled,
                  ),
                ),

                SizedBox(
                  width: (buttonWidth / 2) - 10,
                  height: buttonHeight,
                  child: _buildConfigurableButton(
                    text: pasajes.length > 5 ? pasajes[5]['nombre'] : 'Escolar Intermedio',
                    icon: Icons.school_outlined,
                    backgroundColor: _switchValue ? Colors.white : Colors.white,
                    borderColor: _switchValue ? Colors.black : Colors.black,
                    textColor: Colors.black,
                    onPressed: () {
                      // Asegurar que hay al menos 6 elementos en la lista
                      if (pasajes.length > 5) {
                        // Usar directamente el sexto elemento (índice 5)
                        _generateTicket(pasajes[5]['nombre'], pasajes[5]['precio'], false);
                      } else {
                        // En el improbable caso que no exista, usar un precio por defecto
                        double defaultPrice = _switchValue ? 1300.0 : 1000.0;
                        _generateTicket('Escolar Intermedio', defaultPrice, false);

                        // Y generar un mensaje de advertencia
                        print('ADVERTENCIA: No se encontró Escolar Intermedio en la posición 5. ' +
                            'Usando precio por defecto: $defaultPrice');
                      }
                    },
                    isDisabled: _isButtonDisabled,
                  ),
                ),
              ],
            ),
            SizedBox(height: 5),

            // Cuarta fila: Multi Oferta y Oferta (manteniendo estos como estaban)
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                SizedBox(
                  width: (buttonWidth / 2) - 10,
                  height: buttonHeight,
                  child: _buildConfigurableButton(
                    text: 'Oferta en Ruta',
                    icon: Icons.local_offer,
                    backgroundColor: Colors.red,
                    borderColor: Colors.black,
                    textColor: Colors.yellow,
                    onPressed: _showMultiOfferDialog,
                    isDisabled: _isButtonDisabled,
                  ),
                ),

                SizedBox(
                  width: (buttonWidth / 2) - 10,
                  height: buttonHeight,
                  child: _buildConfigurableButton(
                    text: 'Cargo',
                    icon: Icons.inventory,
                    backgroundColor: _isButtonDisabled ? Colors.grey : Colors.orange,
                    borderColor: Colors.black,
                    onPressed: _showOfferDialog,
                    isDisabled: _isButtonDisabled,
                  ),
                ),
              ],
            ),
            SizedBox(height: 10),
          ],
        ),
      ),
    );
  }

  void _clearCacheIfNeeded() {
    print('Liberando memoria para PDF...');
    pdfOptimizer.clearCache();
    _resourcesPreloaded = false;

    // También podemos liberar otras cachés si es necesario
    if (generateTicket.resourcesPreloaded) {
      generateTicket.optimizer.clearCache();
      generateTicket.resourcesPreloaded = false;
    }
  }
}