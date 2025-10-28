import 'dart:typed_data';
import 'package:flutter/services.dart';

/// Gestiona la carga y cache de assets como bytes puros,
/// para que puedan usarse en cualquier generador de PDF.
class PdfResourceManager {
  static final PdfResourceManager _instance = PdfResourceManager._internal();
  factory PdfResourceManager() => _instance;
  PdfResourceManager._internal();

  final Map<String, Uint8List> _assetCache = {};
  bool _initialized = false;

  /// Carga una vez todos los assets necesarios.
  Future<void> initialize() async {
    if (_initialized) return;
    final paths = <String>[
      'assets/logobkwt.png',
      'assets/headTicket.png',
      'assets/endTicket.png',
      'assets/tijera.png',
    ];
    for (final path in paths) {
      final data = await rootBundle.load(path);
      _assetCache[path] = data.buffer.asUint8List();
    }
    _initialized = true;
  }

  /// Devuelve los bytes del asset precargado, o lanza excepción si no existe.
  Uint8List getAsset(String assetPath) {
    if (!_initialized) {
      throw Exception('PdfResourceManager not initialized');
    }
    final bytes = _assetCache[assetPath];
    if (bytes == null) throw Exception('Asset not found in cache: $assetPath');
    return bytes;
  }
}
