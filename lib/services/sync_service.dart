import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;
import 'package:connectivity_plus/connectivity_plus.dart';
import 'database_service.dart';

/// Resultado de una operación de sincronización
class SyncResult {
  final bool success;
  final int? serverId;
  final String? errorMessage;
  final int localCierreId;

  SyncResult({
    required this.success,
    required this.localCierreId,
    this.serverId,
    this.errorMessage,
  });

  @override
  String toString() {
    if (success) {
      return 'Sync exitoso: Cierre local #$localCierreId -> Server ID #$serverId';
    } else {
      return 'Sync fallido: Cierre local #$localCierreId - Error: $errorMessage';
    }
  }
}

/// Servicio de sincronización con el servidor PostgreSQL remoto
class SyncService {
  static const String API_BASE_URL =
      'https://posbus.danteaguerorodriguez.work';
  static const String SYNC_ENDPOINT = '/api/posbus/sync/cierre';
  static const String CIERRES_ENDPOINT = '/api/posbus/cierres';
  static const Duration REQUEST_TIMEOUT = Duration(seconds: 30);
  static const int MAX_RETRIES = 3;
  static const String DISPOSITIVO_ORIGEN = 'POSBUS-FLUTTER';

  // Singleton instance
  static final SyncService _instance = SyncService._internal();
  factory SyncService() => _instance;
  SyncService._internal();

  final DatabaseService _db = DatabaseService();

  /// Verifica si hay conexión a internet
  static Future<bool> hasInternetConnection() async {
    try {
      final connectivityResult = await Connectivity().checkConnectivity();

      // Verificar que no sea ninguno (sin conexión)
      if (connectivityResult.contains(ConnectivityResult.none)) {
        return false;
      }

      // Intentar ping al servidor para confirmar conectividad real
      final result = await InternetAddress.lookup('google.com')
          .timeout(const Duration(seconds: 5));

      return result.isNotEmpty && result[0].rawAddress.isNotEmpty;
    } catch (e) {
      print('❌ Error verificando conexión a internet: $e');
      return false;
    }
  }

  /// Verifica si está conectado específicamente a WiFi
  static Future<bool> isConnectedToWiFi() async {
    try {
      final connectivityResult = await Connectivity().checkConnectivity();
      return connectivityResult.contains(ConnectivityResult.wifi);
    } catch (e) {
      print('❌ Error verificando conexión WiFi: $e');
      return false;
    }
  }

  /// Obtiene el tipo de conexión actual
  static Future<String> getConnectionType() async {
    try {
      final connectivityResult = await Connectivity().checkConnectivity();

      if (connectivityResult.contains(ConnectivityResult.wifi)) {
        return 'WiFi';
      } else if (connectivityResult.contains(ConnectivityResult.mobile)) {
        return 'Datos móviles';
      } else if (connectivityResult.contains(ConnectivityResult.ethernet)) {
        return 'Ethernet';
      } else {
        return 'Sin conexión';
      }
    } catch (e) {
      return 'Desconocido';
    }
  }

  /// Sincroniza un cierre específico con el servidor
  Future<SyncResult> syncCierre(int cierreId) async {
    print('🔄 Iniciando sincronización del cierre #$cierreId');

    try {
      // 1. Verificar conectividad
      if (!await hasInternetConnection()) {
        final errorMsg = 'Sin conexión a internet';
        await _db.marcarErrorSincronizacion(
          localId: cierreId,
          errorMessage: errorMsg,
        );
        return SyncResult(
          success: false,
          localCierreId: cierreId,
          errorMessage: errorMsg,
        );
      }

      // 2. Obtener datos del cierre desde SQLite
      final cierreData = await _db.getCierreCaja(cierreId);
      if (cierreData == null) {
        return SyncResult(
          success: false,
          localCierreId: cierreId,
          errorMessage: 'Cierre no encontrado en base de datos local',
        );
      }

      // 3. Obtener transacciones asociadas al cierre
      final transacciones = await _db.getTransacciones(cierreId: cierreId);

      // 4. Construir payload para el servidor
      final payload = _buildSyncPayload(cierreData, transacciones);

      // 5. Enviar al servidor con reintentos
      final response = await _sendToServerWithRetries(payload);

      // 6. Procesar respuesta
      if (response['success'] == true) {
        final serverId = response['cierreId'] as int?;

        if (serverId != null) {
          await _db.marcarCierreComoSincronizado(
            localId: cierreId,
            serverId: serverId,
          );

          print('✅ Cierre #$cierreId sincronizado exitosamente. Server ID: $serverId');

          return SyncResult(
            success: true,
            localCierreId: cierreId,
            serverId: serverId,
          );
        } else {
          throw Exception('Respuesta del servidor sin cierreId');
        }
      } else {
        final errorMsg = response['message'] ?? 'Error desconocido del servidor';
        await _db.marcarErrorSincronizacion(
          localId: cierreId,
          errorMessage: errorMsg,
        );

        return SyncResult(
          success: false,
          localCierreId: cierreId,
          errorMessage: errorMsg,
        );
      }
    } catch (e) {
      final errorMsg = _parseError(e);
      print('❌ Error sincronizando cierre #$cierreId: $errorMsg');

      await _db.marcarErrorSincronizacion(
        localId: cierreId,
        errorMessage: errorMsg,
      );

      return SyncResult(
        success: false,
        localCierreId: cierreId,
        errorMessage: errorMsg,
      );
    }
  }

  /// Sincroniza todos los cierres pendientes
  Future<List<SyncResult>> syncPendingCierres() async {
    print('🔄 Iniciando sincronización de cierres pendientes...');

    try {
      // Obtener todos los cierres pendientes
      final cierresPendientes = await _db.getCierresPendientesSincronizacion();

      if (cierresPendientes.isEmpty) {
        print('ℹ️ No hay cierres pendientes de sincronizar');
        return [];
      }

      print('📦 Encontrados ${cierresPendientes.length} cierres pendientes');

      final List<SyncResult> resultados = [];

      // Sincronizar uno por uno
      for (final cierre in cierresPendientes) {
        final cierreId = cierre['id'] as int;
        final result = await syncCierre(cierreId);
        resultados.add(result);

        // Pequeña pausa entre solicitudes para no sobrecargar el servidor
        await Future.delayed(const Duration(milliseconds: 500));
      }

      final exitosos = resultados.where((r) => r.success).length;
      final fallidos = resultados.where((r) => !r.success).length;

      print('✅ Sincronización completada: $exitosos exitosos, $fallidos fallidos');

      return resultados;
    } catch (e) {
      print('❌ Error sincronizando cierres pendientes: $e');
      return [];
    }
  }

  /// Obtiene la lista de IDs de cierres que están en el servidor
  Future<List<int>> getServerCierreIds() async {
    try {
      if (!await hasInternetConnection()) {
        throw Exception('Sin conexión a internet');
      }

      final url = Uri.parse('$API_BASE_URL$CIERRES_ENDPOINT');

      final response = await http
          .get(url)
          .timeout(REQUEST_TIMEOUT);

      if (response.statusCode == 200) {
        final data = json.decode(response.body);

        if (data is List) {
          return data
              .map((cierre) => cierre['id'] as int?)
              .where((id) => id != null)
              .cast<int>()
              .toList();
        }
      }

      throw Exception('Error obteniendo lista de cierres del servidor');
    } catch (e) {
      print('❌ Error obteniendo cierres del servidor: $e');
      return [];
    }
  }

  /// Verifica el estado de sincronización de todos los cierres
  Future<Map<String, dynamic>> getEstadoSincronizacion() async {
    try {
      final todosCierres = await _db.getCierresCaja();
      final cierresSincronizados = todosCierres.where(
        (c) => (c['sincronizado'] as int? ?? 0) == 1
      ).length;
      final cierresPendientes = todosCierres.where(
        (c) => (c['sincronizado'] as int? ?? 0) == 0
      ).length;

      return {
        'total': todosCierres.length,
        'sincronizados': cierresSincronizados,
        'pendientes': cierresPendientes,
      };
    } catch (e) {
      print('❌ Error obteniendo estado de sincronización: $e');
      return {
        'total': 0,
        'sincronizados': 0,
        'pendientes': 0,
      };
    }
  }

  // ==================== MÉTODOS PRIVADOS ====================

  /// Construye el payload JSON para enviar al servidor
  Map<String, dynamic> _buildSyncPayload(
    Map<String, dynamic> cierreData,
    List<Map<String, dynamic>> transacciones,
  ) {
    return {
      'cierre': {
        'fecha_cierre': cierreData['fecha_cierre'],
        'total_ingresos': cierreData['total_ingresos'],
        'total_transacciones': cierreData['total_transacciones'],
        'pdf_path': cierreData['pdf_path'] ?? '',
        'dispositivo_origen': DISPOSITIVO_ORIGEN,
      },
      'transacciones': transacciones.map((t) {
        return {
          'fecha': t['fecha'],
          'hora': t['hora'],
          'nombre_pasaje': t['nombre_pasaje'],
          'valor': t['valor'],
          'comprobante': t['comprobante'],
          'dispositivo_origen': DISPOSITIVO_ORIGEN,
        };
      }).toList(),
    };
  }

  /// Envía datos al servidor con reintentos automáticos
  Future<Map<String, dynamic>> _sendToServerWithRetries(
    Map<String, dynamic> payload,
  ) async {
    int attempts = 0;
    Exception? lastException;

    while (attempts < MAX_RETRIES) {
      attempts++;

      try {
        print('🌐 Intento $attempts de $MAX_RETRIES...');

        final url = Uri.parse('$API_BASE_URL$SYNC_ENDPOINT');
        final response = await http
            .post(
              url,
              headers: {
                'Content-Type': 'application/json',
                'Accept': 'application/json',
              },
              body: json.encode(payload),
            )
            .timeout(REQUEST_TIMEOUT);

        // Log de respuesta para debugging
        print('📡 Response Status: ${response.statusCode}');
        print('📡 Response Body: ${response.body}');

        if (response.statusCode == 200 || response.statusCode == 201) {
          final data = json.decode(response.body);
          return data;
        } else {
          throw HttpException(
            'Error HTTP ${response.statusCode}: ${response.body}',
          );
        }
      } on TimeoutException catch (e) {
        lastException = e;
        print('⏱️ Timeout en intento $attempts');

        if (attempts < MAX_RETRIES) {
          await Future.delayed(Duration(seconds: attempts * 2));
        }
      } on SocketException catch (e) {
        lastException = e;
        print('🔌 Error de conexión en intento $attempts');

        if (attempts < MAX_RETRIES) {
          await Future.delayed(Duration(seconds: attempts * 2));
        }
      } catch (e) {
        lastException = Exception(e.toString());
        print('❌ Error en intento $attempts: $e');

        if (attempts < MAX_RETRIES) {
          await Future.delayed(Duration(seconds: attempts * 2));
        }
      }
    }

    throw lastException ?? Exception('Falló después de $MAX_RETRIES intentos');
  }

  /// Parsea errores para mensajes amigables al usuario
  String _parseError(dynamic error) {
    if (error is TimeoutException) {
      return 'Tiempo de espera agotado. Verifica tu conexión.';
    } else if (error is SocketException) {
      return 'Error de conexión. Verifica tu red.';
    } else if (error is HttpException) {
      return 'Error del servidor: ${error.message}';
    } else if (error is FormatException) {
      return 'Error de formato en la respuesta del servidor.';
    } else {
      return error.toString();
    }
  }
}
