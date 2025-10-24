import 'dart:convert';
import 'package:flutter/services.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'cargo_screen.dart';
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

// Importar widgets personalizados
import 'home/widgets/widgets.dart';
import 'home/dialogs/password_dialog.dart';
import 'home/services/reprint_service.dart';


class Home extends StatefulWidget {
  @override
  _HomeState createState() => _HomeState();
}

class _HomeState extends State<Home> {
  final PdfOptimizer pdfOptimizer = PdfOptimizer();
  final GenerateTicket generateTicket = GenerateTicket();
  final MoTicketGenerator moTicketGenerator = MoTicketGenerator();
  late final ReprintService reprintService;
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

    // Inicializar servicio de reimpresión
    reprintService = ReprintService(
      generateTicket: generateTicket,
      moTicketGenerator: moTicketGenerator,
    );

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
    String password = await _loadPassword();
    bool ok = await PasswordDialog.showReprintPasswordDialog(
      context: context,
      storedPassword: password,
    );
    if (!ok) return;

    // 4) Delegar al servicio de reimpresión
    await reprintService.handleReprint(
      context: context,
      lastTransaction: _lastTransaction!,
      setIsReprinting: (value) => setState(() => _isReprinting = value),
      setHasReprinted: (value) => setState(() => _hasReprinted = value),
    );
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

    String password = await _loadPassword();
    bool authenticated = await PasswordDialog.showDeletePasswordDialog(
      context: context,
      storedPassword: password,
    );

    if (authenticated) {
      await _cancelLastTransaction();
    }
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
      appBar: CustomHomeAppBar(
        currentDay: _currentDay,
        lastTransaction: _lastTransaction,
        hasReprinted: _hasReprinted,
        isReprinting: _isReprinting,
        hasAnulado: _hasAnulado,
        onReportPressed: () {
          Navigator.push(
            context,
            MaterialPageRoute(builder: (context) => ReporteCajaScreen()),
          );
        },
        onReprintPressed: _handleReprint,
        onDeletePressed: _showPasswordDialog,
        onSettingsPressed: _navigateToSettings,
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
                  TransactionCounter(),
                  ComprobanteIndicator(),
                ],
              ),
            ),

            Expanded(
              child: Center(
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    // Contenedor del switch a la izquierda
                    DaySwitch(
                      switchValue: _switchValue,
                      onChanged: (value) {
                        setState(() {
                          _switchValue = value;
                        });
                      },
                      textSize: textSize * 1,
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

            // Grid de botones de pasajes
            TicketButtonsGrid(
              pasajes: pasajes,
              switchValue: _switchValue,
              isButtonDisabled: _isButtonDisabled,
              onGenerateTicket: _generateTicket,
              onShowMultiOfferDialog: _showMultiOfferDialog,
              onShowOfferDialog: _showOfferDialog,
              showIcons: _showIcons,
              textSizeMultiplier: _textSizeMultiplier,
              buttonIcons: _buttonIcons,
            ),
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