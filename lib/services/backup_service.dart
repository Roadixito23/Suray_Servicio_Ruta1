import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:intl/intl.dart';
import 'package:file_picker/file_picker.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:share_plus/share_plus.dart';
import 'package:share_plus/src/share_plus_linux.dart' show XFile;
import 'package:archive/archive.dart';

class BackupService {
  static const String backupFolder = 'suray_backups';
  static const String backupExtension = '.suray';

  // Crear una copia de seguridad de todos los datos de la aplicación
  static Future<File> createBackup({String customName = ''}) async {
    try {
      // Paso 1: Preparar directorios
      final appDocDir = await getApplicationDocumentsDirectory();
      final backupDir = Directory('${appDocDir.path}/$backupFolder');
      if (!await backupDir.exists()) {
        await backupDir.create(recursive: true);
      }

      // Crear una marca de tiempo para el nombre del archivo de respaldo
      final timestamp = DateFormat('yyyyMMdd_HHmmss').format(DateTime.now());
      final fileName = customName.isNotEmpty
          ? '${customName}_$timestamp$backupExtension'
          : 'backup_$timestamp$backupExtension';

      final backupPath = '${backupDir.path}/$fileName';

      // Paso 2: Recopilar datos de SharedPreferences
      final prefs = await SharedPreferences.getInstance();
      final prefsMap = await _getAllSharedPreferences(prefs);

      // Paso 3: Crear un directorio temporal para ensamblar el respaldo
      final tempDir = await getTemporaryDirectory();
      final backupTempDir = Directory('${tempDir.path}/backup_temp');
      if (await backupTempDir.exists()) {
        await backupTempDir.delete(recursive: true);
      }
      await backupTempDir.create(recursive: true);

      // Paso 4: Guardar datos de SharedPreferences en un archivo JSON
      final prefsFile = File('${backupTempDir.path}/preferences.json');
      await prefsFile.writeAsString(jsonEncode(prefsMap));

      // Paso 5: Copiar archivos importantes
      // Copiar recibos de cargo
      await _copyDirectory(
          '${appDocDir.path}/cargo_receipts',
          '${backupTempDir.path}/cargo_receipts'
      );

      // Copiar informes PDF
      final pdfFiles = await _getPdfFiles(appDocDir);
      for (final pdfFile in pdfFiles) {
        final fileName = pdfFile.path.split('/').last;
        final targetFile = File('${backupTempDir.path}/pdfs/$fileName');
        await targetFile.create(recursive: true);
        await pdfFile.copy(targetFile.path);
      }

      // Paso 6: Crear un archivo ZIP
      final archive = await _createArchiveFromDirectory(backupTempDir);
      final zipFile = File(backupPath);
      await zipFile.writeAsBytes(archive);

      // Paso 7: Limpiar directorio temporal
      await backupTempDir.delete(recursive: true);

      return zipFile;
    } catch (e) {
      print('Error al crear respaldo: $e');
      rethrow;
    }
  }

  // Restaurar datos de la aplicación desde un archivo de respaldo
  static Future<bool> restoreBackup(File backupFile) async {
    try {
      // Paso 1: Preparar directorio temporal para extracción
      final tempDir = await getTemporaryDirectory();
      final extractDir = Directory('${tempDir.path}/restore_temp');
      if (await extractDir.exists()) {
        await extractDir.delete(recursive: true);
      }
      await extractDir.create(recursive: true);

      // Paso 2: Extraer el archivo de respaldo
      await _extractArchive(backupFile, extractDir);

      // Paso 3: Restaurar SharedPreferences
      final prefsFile = File('${extractDir.path}/preferences.json');
      if (await prefsFile.exists()) {
        final prefsData = jsonDecode(await prefsFile.readAsString());
        await _restoreSharedPreferences(prefsData);
      }

      // Paso 4: Restaurar archivos
      final appDocDir = await getApplicationDocumentsDirectory();

      // Restaurar recibos de cargo
      final cargoDir = Directory('${extractDir.path}/cargo_receipts');
      if (await cargoDir.exists()) {
        final targetCargoDir = Directory('${appDocDir.path}/cargo_receipts');
        if (await targetCargoDir.exists()) {
          await targetCargoDir.delete(recursive: true);
        }
        await _copyDirectory(cargoDir.path, targetCargoDir.path);
      }

      // Restaurar archivos PDF
      final pdfDir = Directory('${extractDir.path}/pdfs');
      if (await pdfDir.exists()) {
        final files = await pdfDir.list().toList();
        for (final file in files) {
          if (file is File) {
            final fileName = file.path.split('/').last;
            await file.copy('${appDocDir.path}/$fileName');
          }
        }
      }

      // Paso 5: Limpiar
      await extractDir.delete(recursive: true);

      return true;
    } catch (e) {
      print('Error al restaurar respaldo: $e');
      return false;
    }
  }

  // Exportar respaldo a almacenamiento externo (para Android)
  static Future<bool> exportBackup(File backupFile) async {
    try {
      // Solicitar permiso de almacenamiento
      var status = await Permission.storage.status;
      if (!status.isGranted) {
        status = await Permission.storage.request();
        if (!status.isGranted) {
          return false;
        }
      }

      // Obtener el directorio de Descargas
      final downloadsDir = Directory('/storage/emulated/0/Download');
      if (!await downloadsDir.exists()) {
        await downloadsDir.create(recursive: true);
      }

      // Copiar el archivo a Descargas
      final fileName = backupFile.path.split('/').last;
      final targetFile = File('${downloadsDir.path}/$fileName');
      await backupFile.copy(targetFile.path);

      return true;
    } catch (e) {
      print('Error al exportar respaldo: $e');
      return false;
    }
  }

  // Importar respaldo desde almacenamiento externo (para Android)
  static Future<File?> importBackup() async {
    try {
      // Solicitar permiso de almacenamiento
      var status = await Permission.storage.status;
      if (!status.isGranted) {
        status = await Permission.storage.request();
        if (!status.isGranted) {
          return null;
        }
      }

      // Usar FileType.any en lugar de FileType.custom con extensiones
      FilePickerResult? result = await FilePicker.platform.pickFiles(
        type: FileType.any,
        allowMultiple: false,
      );

      if (result != null && result.files.single.path != null) {
        // Obtener la ruta del archivo seleccionado
        final path = result.files.single.path!;
        final fileName = path.split('/').last.toLowerCase();

        // Verificar manualmente si el archivo tiene la extensión correcta
        if (!fileName.endsWith(backupExtension)) {
          print('Archivo seleccionado no es un respaldo válido: $fileName');
          return null;
        }

        // Copiar el archivo al directorio de respaldo de la aplicación
        final appDocDir = await getApplicationDocumentsDirectory();
        final backupDir = Directory('${appDocDir.path}/$backupFolder');
        if (!await backupDir.exists()) {
          await backupDir.create(recursive: true);
        }

        final targetFile = File('${backupDir.path}/$fileName');
        await File(path).copy(targetFile.path);

        return targetFile;
      }

      return null;
    } catch (e) {
      print('Error al importar respaldo: $e');
      return null;
    }
  }

  // Compartir archivo de respaldo
  static Future<void> shareBackup(File backupFile) async {
    try {
      final result = await Share.shareXFiles(
        [XFile(backupFile.path)],
        text: 'Respaldo App Suray',
      );

      print('Estado de compartir: ${result.status}');
    } catch (e) {
      print('Error al compartir respaldo: $e');
    }
  }

  // Listar respaldos disponibles
  static Future<List<FileSystemEntity>> getAvailableBackups() async {
    try {
      final appDocDir = await getApplicationDocumentsDirectory();
      final backupDir = Directory('${appDocDir.path}/$backupFolder');

      if (!await backupDir.exists()) {
        return [];
      }

      final files = await backupDir.list().toList();
      files.sort((a, b) {
        return File(b.path).lastModifiedSync().compareTo(
            File(a.path).lastModifiedSync()
        );
      });

      return files.where((file) =>
          file.path.endsWith(backupExtension)
      ).toList();
    } catch (e) {
      print('Error al obtener respaldos disponibles: $e');
      return [];
    }
  }

  // Metodo auxiliar para obtener todas las SharedPreferences
  static Future<Map<String, dynamic>> _getAllSharedPreferences(SharedPreferences prefs) async {
    final prefsMap = <String, dynamic>{};

    final keys = prefs.getKeys();
    for (final key in keys) {
      try {
        // Intentar determinar el tipo correcto para cada clave
        if (prefs.getString(key) != null) {
          prefsMap[key] = prefs.getString(key);
          prefsMap['${key}_type'] = 'string'; // Guardar el tipo para restauración
        } else if (prefs.getBool(key) != null) {
          prefsMap[key] = prefs.getBool(key);
          prefsMap['${key}_type'] = 'bool';
        } else if (prefs.getInt(key) != null) {
          prefsMap[key] = prefs.getInt(key);
          prefsMap['${key}_type'] = 'int';
        } else if (prefs.getDouble(key) != null) {
          prefsMap[key] = prefs.getDouble(key);
          prefsMap['${key}_type'] = 'double';
        } else if (prefs.getStringList(key) != null) {
          prefsMap[key] = prefs.getStringList(key);
          prefsMap['${key}_type'] = 'stringList';
        }
      } catch (e) {
        print('Error al procesar la preferencia "$key": $e');
        // Intentar recuperar el valor como dynamic en caso de error
        final dynamic value = prefs.get(key);
        if (value != null) {
          prefsMap[key] = value;
          prefsMap['${key}_type'] = value.runtimeType.toString();
        }
      }
    }

    // Agregar versión de la aplicación y fecha de respaldo
    prefsMap['__backup_date'] = DateTime.now().toIso8601String();
    prefsMap['__backup_version'] = '1.0';

    return prefsMap;
  }

  // Metodo auxiliar para restaurar SharedPreferences
  static Future<void> _restoreSharedPreferences(Map<String, dynamic> data) async {
    final prefs = await SharedPreferences.getInstance();

    // Crear una lista de claves a procesar (excluyendo las claves de tipo)
    final keysToProcess = data.keys.where((key) =>
    !key.endsWith('_type') &&
        !key.startsWith('__')
    ).toList();

    // Procesar cada clave
    for (final key in keysToProcess) {
      final value = data[key];
      final String? typeKey = '${key}_type';
      final String? valueType = data.containsKey(typeKey) ? data[typeKey] as String? : null;

      try {
        if (value == null) continue;

        if (valueType == 'string' || value is String) {
          await prefs.setString(key, value.toString());
        } else if (valueType == 'bool' || value is bool) {
          await prefs.setBool(key, value is bool ? value : value.toString().toLowerCase() == 'true');
        } else if (valueType == 'int' || value is int) {
          await prefs.setInt(key, value is int ? value : int.tryParse(value.toString()) ?? 0);
        } else if (valueType == 'double' || value is double) {
          await prefs.setDouble(key, value is double ? value : double.tryParse(value.toString()) ?? 0.0);
        } else if (valueType == 'stringList' || value is List) {
          if (value is List<String>) {
            await prefs.setStringList(key, value);
          } else if (value is List) {
            await prefs.setStringList(key, value.map((e) => e.toString()).toList());
          }
        } else {
          // Fallback para tipos desconocidos - intentar guardar como string
          await prefs.setString(key, value.toString());
        }
      } catch (e) {
        print('Error al restaurar la preferencia "$key": $e');
      }
    }
  }

  // Metodo auxiliar para crear archivo desde directorio
  static Future<List<int>> _createArchiveFromDirectory(Directory dir) async {
    final archive = Archive();
    final files = await dir.list(recursive: true).toList();

    for (final fileEntity in files) {
      if (fileEntity is File) {
        final relPath = fileEntity.path.substring(dir.path.length + 1);
        final data = await fileEntity.readAsBytes();

        final archiveFile = ArchiveFile(relPath, data.length, data);
        archive.addFile(archiveFile);
      }
    }

    return ZipEncoder().encode(archive)!;
  }

  // Metodo auxiliar para extraer archivo
  static Future<void> _extractArchive(File zipFile, Directory targetDir) async {
    final bytes = await zipFile.readAsBytes();
    final archive = ZipDecoder().decodeBytes(bytes);

    for (final file in archive) {
      final filename = file.name;
      if (file.isFile) {
        final outFile = File('${targetDir.path}/$filename');
        await outFile.create(recursive: true);
        await outFile.writeAsBytes(file.content as List<int>);
      } else {
        await Directory('${targetDir.path}/$filename').create(recursive: true);
      }
    }
  }

  // Metodo auxiliar para copiar directorio recursivamente
  static Future<void> _copyDirectory(String source, String target) async {
    final sourceDir = Directory(source);
    final targetDir = Directory(target);

    if (!await sourceDir.exists()) {
      return;
    }

    if (!await targetDir.exists()) {
      await targetDir.create(recursive: true);
    }

    await for (final entity in sourceDir.list(recursive: false)) {
      if (entity is File) {
        final newFile = File('${targetDir.path}/${entity.path.split('/').last}');
        await entity.copy(newFile.path);
      } else if (entity is Directory) {
        final newDir = Directory('${targetDir.path}/${entity.path.split('/').last}');
        await _copyDirectory(entity.path, newDir.path);
      }
    }
  }

  // Metodo auxiliar para obtener archivos PDF
  static Future<List<File>> _getPdfFiles(Directory dir) async {
    final files = <File>[];
    final entities = await dir.list(recursive: false).toList();

    for (final entity in entities) {
      if (entity is File && entity.path.toLowerCase().endsWith('.pdf')) {
        files.add(entity);
      }
    }

    return files;
  }
}