import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:async';
import 'home.dart';

class SecurityScreen extends StatefulWidget {
  @override
  _SecurityScreenState createState() => _SecurityScreenState();
}

class _SecurityScreenState extends State<SecurityScreen> with SingleTickerProviderStateMixin {
  final TextEditingController _passwordController = TextEditingController();
  bool _isLoading = false;
  bool _showError = false;
  bool _isLocked = false;
  int _lockTimeRemaining = 0;
  Timer? _lockTimer;

  // Contador de intentos fallidos
  int _failedAttempts = 0;

  // Tiempos de bloqueo progresivos (en segundos)
  final List<int> _lockTimes = [5, 15, 30, 60, 150]; // 5s, 15s, 30s, 1min, 2min30s

  // Control de animación
  late AnimationController _shakeController;
  late Animation<double> _shakeAnimation;

  // Variables para el contador de presión del logo
  bool _showBinaryPassword = false;
  int _pressDuration = 0;
  String _binaryPassword = ""; // Ahora almacenará la contraseña real, no la representación binaria
  Timer? _pressTimer;
  Timer? _binVisibilityTimer;
  Timer? _continuousShakeTimer;

  @override
  void initState() {
    super.initState();

    // Set up shake animation for invalid password and security icon
    _shakeController = AnimationController(
      vsync: this,
      duration: Duration(milliseconds: 300),
    );

    _shakeAnimation = Tween<double>(begin: 0.0, end: 4.0)
        .chain(CurveTween(curve: Curves.elasticIn))
        .animate(_shakeController)
      ..addStatusListener((status) {
        if (status == AnimationStatus.completed) {
          _shakeController.reverse();
        }
      });

    // Cargar el contador de intentos fallidos al iniciar
    _loadFailedAttempts();
  }

  @override
  void dispose() {
    _passwordController.dispose();
    _shakeController.dispose();
    _pressTimer?.cancel();
    _binVisibilityTimer?.cancel();
    _lockTimer?.cancel();
    _continuousShakeTimer?.cancel();
    super.dispose();
  }

  // Cargar intentos fallidos de SharedPreferences
  Future<void> _loadFailedAttempts() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _failedAttempts = prefs.getInt('failedAttempts') ?? 0;
    });

    // Si hay intentos fallidos previos, verificar si aún debe estar bloqueado
    if (_failedAttempts >= 3) {
      final lastLockTime = prefs.getInt('lastLockTime') ?? 0;
      final currentTime = DateTime.now().millisecondsSinceEpoch;
      final timeIndex = _getLockTimeIndex();

      // Si el tiempo de bloqueo aún no ha expirado, reiniciar el bloqueo por el tiempo restante
      if (lastLockTime > 0) {
        final lockDuration = _lockTimes[timeIndex] * 1000; // convertir a milisegundos
        final elapsedTime = currentTime - lastLockTime;

        if (elapsedTime < lockDuration) {
          final remainingTime = (lockDuration - elapsedTime) ~/ 1000;
          _startLockdown(remainingTime);
        }
      }
    }
  }

  // Guardar intentos fallidos en SharedPreferences
  Future<void> _saveFailedAttempts() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt('failedAttempts', _failedAttempts);
  }

  // Guardar el tiempo de inicio del último bloqueo
  Future<void> _saveLastLockTime() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt('lastLockTime', DateTime.now().millisecondsSinceEpoch);
  }

  // Obtener el índice del tiempo de bloqueo basado en intentos fallidos
  int _getLockTimeIndex() {
    // Restar 3 porque el bloqueo comienza después del tercer intento fallido
    // y limitar al máximo índice disponible
    return (_failedAttempts - 3).clamp(0, _lockTimes.length - 1);
  }

  // Ya no necesitamos convertir a binario, simplemente pasamos la contraseña directamente

  // Iniciar el timer para contar la duración de presión y hacer temblar continuamente
  void _startPressTimer() {
    _pressDuration = 0;

    // Iniciar un temporizador para hacer temblar el icono continuamente mientras se presiona
    _continuousShakeTimer = Timer.periodic(Duration(milliseconds: 150), (timer) {
      if (_shakeController.status == AnimationStatus.dismissed) {
        _shakeController.forward(from: 0.0);
      }
    });

    // Iniciar el contador para mostrar la contraseña después de 15 segundos
    _pressTimer = Timer.periodic(Duration(milliseconds: 100), (timer) {
      _pressDuration += 100;

      if (_pressDuration >= 15000) {
        _loadPassword().then((password) {
          setState(() {
            _binaryPassword = password; // Guardamos la contraseña normal, sin convertir
            _showBinaryPassword = true;
          });
        });
        timer.cancel();
        _continuousShakeTimer?.cancel();

        // Auto-ocultar después de 2.3 segundos
        _binVisibilityTimer = Timer(Duration(milliseconds: 2300), () {
          setState(() {
            _showBinaryPassword = false;
          });
        });
      }
    });
  }

  void _stopPressTimer() {
    _pressTimer?.cancel();
    _continuousShakeTimer?.cancel();
    _pressDuration = 0;
  }

  Future<String> _loadPassword() async {
    final prefs = await SharedPreferences.getInstance();
    // Default password is 232323 if none is set
    return prefs.getString('password') ?? '232323';
  }

  // Método para iniciar el bloqueo por tiempo específico
  void _startLockdown(int seconds) {
    setState(() {
      _isLocked = true;
      _lockTimeRemaining = seconds;
      _passwordController.clear();
    });

    // Guardar el tiempo de inicio del bloqueo
    _saveLastLockTime();

    // Iniciar un temporizador que disminuya el contador cada segundo
    _lockTimer?.cancel();
    _lockTimer = Timer.periodic(Duration(seconds: 1), (timer) {
      setState(() {
        _lockTimeRemaining--;
      });

      if (_lockTimeRemaining <= 0) {
        _lockTimer?.cancel();
        setState(() {
          _isLocked = false;
          _showError = false;
        });
      }
    });
  }

  // Método para gestionar intentos fallidos y aplicar bloqueo progresivo
  void _handleFailedAttempt() {
    setState(() {
      _failedAttempts++;
      _showError = true;
    });

    _saveFailedAttempts();
    _shakeController.forward(from: 0.0);

    // Aplicar bloqueo si se alcanzan 3 o más intentos fallidos
    if (_failedAttempts >= 3) {
      int timeIndex = _getLockTimeIndex();
      _startLockdown(_lockTimes[timeIndex]);
    }
  }

  // Método para restablecer el contador de intentos fallidos
  Future<void> _resetFailedAttempts() async {
    setState(() {
      _failedAttempts = 0;
    });

    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt('failedAttempts', 0);
    await prefs.remove('lastLockTime');
  }

  void _verifyPassword() async {
    // Si está bloqueado, no hacer nada
    if (_isLocked) return;

    setState(() {
      _isLoading = true;
      _showError = false;
    });

    String storedPassword = await _loadPassword();
    String enteredPassword = _passwordController.text.trim();

    // Small delay to show loading indicator
    await Future.delayed(Duration(milliseconds: 500));

    setState(() {
      _isLoading = false;
    });

    if (enteredPassword == storedPassword) {
      // Resetear intentos fallidos al ingresar correctamente
      await _resetFailedAttempts();

      // Navigate to home screen
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (context) => Home()),
      );
    } else {
      // Gestionar intento fallido
      _handleFailedAttempt();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Colors.amber[800]!, Colors.amber[100]!],
          ),
        ),
        child: Center(
          child: AnimatedBuilder(
            animation: _shakeAnimation,
            builder: (context, child) {
              return Transform.translate(
                offset: Offset(_shakeAnimation.value * (_showError ? 1 : 0), 0),
                child: child,
              );
            },
            child: Card(
              margin: EdgeInsets.all(32),
              elevation: 10,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(20),
              ),
              child: Padding(
                padding: const EdgeInsets.all(24.0),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Logo or Icon with long press detection
                    Column(
                      children: [
                        AnimatedBuilder(
                          animation: _shakeAnimation,
                          builder: (context, child) {
                            return Transform.translate(
                              offset: Offset(_shakeAnimation.value, 0),
                              child: GestureDetector(
                                onLongPressStart: (_) => _startPressTimer(),
                                onLongPressEnd: (_) => _stopPressTimer(),
                                child: Icon(
                                  Icons.security,
                                  size: 70,
                                  color: Colors.amber[800],
                                ),
                              ),
                            );
                          },
                        ),
                        // Mostrar la contraseña normal si se ha presionado lo suficiente
                        if (_showBinaryPassword)
                          Padding(
                            padding: const EdgeInsets.only(top: 8.0),
                            child: Container(
                              padding: EdgeInsets.all(8),
                              decoration: BoxDecoration(
                                color: Colors.black87,
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Text(
                                _binaryPassword,
                                style: TextStyle(
                                  color: Colors.green,
                                  fontSize: 20,
                                  letterSpacing: 4,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          ),
                      ],
                    ),
                    SizedBox(height: 24),

                    // Title
                    Text(
                      'Iniciar Sesión',
                      style: TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                        color: Colors.amber[800],
                      ),
                    ),
                    SizedBox(height: 6),

                    // Subtitle
                    Text(
                      'Ingrese la contraseña para continuar',
                      style: TextStyle(
                        fontSize: 16,
                        color: Colors.grey[600],
                      ),
                      textAlign: TextAlign.center,
                    ),
                    SizedBox(height: 30),

                    // Lockdown message if applicable
                    if (_isLocked)
                      Container(
                        padding: EdgeInsets.all(12),
                        margin: EdgeInsets.only(bottom: 16),
                        decoration: BoxDecoration(
                          color: Colors.red.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: Colors.red),
                        ),
                        child: Column(
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(Icons.lock_clock, color: Colors.red),
                                SizedBox(width: 8),
                                Text(
                                  'Sistema bloqueado',
                                  style: TextStyle(
                                    color: Colors.red,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ],
                            ),
                            SizedBox(height: 8),
                            Text(
                              'Espere $_lockTimeRemaining segundos',
                              style: TextStyle(color: Colors.red),
                            ),
                          ],
                        ),
                      ),

                    // Mostrar contador de intentos restantes
                    if (_failedAttempts > 0 && _failedAttempts < 3 && !_isLocked)
                      Container(
                        padding: EdgeInsets.all(12),
                        margin: EdgeInsets.only(bottom: 16),
                        decoration: BoxDecoration(
                          color: Colors.orange.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: Colors.orange),
                        ),
                        child: Column(
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(Icons.warning, color: Colors.orange),
                                SizedBox(width: 8),
                                Text(
                                  'Advertencia',
                                  style: TextStyle(
                                    color: Colors.orange,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ],
                            ),
                            SizedBox(height: 8),
                            Text(
                              'Intentos fallidos: $_failedAttempts/3',
                              style: TextStyle(color: Colors.orange[700]),
                            ),
                          ],
                        ),
                      ),

                    // Password field
                    TextField(
                      controller: _passwordController,
                      decoration: InputDecoration(
                        labelText: 'Contraseña',
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        prefixIcon: Icon(Icons.lock, color: Colors.amber[800]),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide(color: Colors.amber[800]!, width: 2),
                        ),
                        errorText: _showError ? 'Contraseña incorrecta' : null,
                      ),
                      obscureText: true,
                      keyboardType: TextInputType.number,
                      inputFormatters: [
                        FilteringTextInputFormatter.digitsOnly,
                        LengthLimitingTextInputFormatter(6),
                      ],
                      maxLength: 6,
                      textAlign: TextAlign.center,
                      style: TextStyle(fontSize: 20, letterSpacing: 8),
                      onSubmitted: (value) => _verifyPassword(),
                      enabled: !_isLocked, // Deshabilitar durante el bloqueo
                    ),
                    SizedBox(height: 24),

                    // Login button
                    SizedBox(
                      width: double.infinity,
                      height: 50,
                      child: ElevatedButton(
                        onPressed: (_isLoading || _isLocked) ? null : _verifyPassword,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.amber[800],
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          elevation: 5,
                        ),
                        child: _isLoading
                            ? CircularProgressIndicator(color: Colors.white)
                            : Text(
                          'Ingresar',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}