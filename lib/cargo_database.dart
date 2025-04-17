import 'dart:io';
import 'dart:typed_data';
import 'package:path_provider/path_provider.dart';
import 'package:intl/intl.dart';
import 'dart:convert';
import 'package:flutter/foundation.dart';

class CargoDatabase {
  // Store cargo receipt information
  static Future<void> saveCargoReceipt(
      String destinatario,
      String remitente,
      String articulo,
      double precio,
      String telefonoDest,
      String telefonoRemit,
      String ticketNum,
      String comprobante,
      Uint8List pdfData,
      String tipo,
      String destino) async {
    try {
      final directory = await getApplicationDocumentsDirectory();
      final cargoDir = Directory('${directory.path}/cargo_receipts');

      // Create directory if it doesn't exist
      if (!await cargoDir.exists()) {
        await cargoDir.create(recursive: true);
      }

      // Create filename using current date and comprobante number
      String currentDate = DateFormat('yyyyMMdd_HHmmss').format(DateTime.now());
      String filename = '${currentDate}_${comprobante}_${tipo}.pdf';

      // Save PDF file
      final file = File('${cargoDir.path}/$filename');
      await file.writeAsBytes(pdfData);

      // Save metadata to help with searching and display
      await _saveMetadata(
          destinatario,
          remitente,
          articulo,
          precio,
          telefonoDest,
          telefonoRemit,
          ticketNum,
          comprobante,
          currentDate,
          filename,
          tipo,
          destino
      );

      // Delete old receipts
      await _cleanOldReceipts();
    } catch (e) {
      print('Error saving cargo receipt: $e');
    }
  }

  // Save metadata for easier searching and display
  static Future<void> _saveMetadata(
      String destinatario,
      String remitente,
      String articulo,
      double precio,
      String telefonoDest,
      String telefonoRemit,
      String ticketNum,
      String comprobante,
      String currentDate,
      String filename,
      String tipo,
      String destino) async {
    try {
      final directory = await getApplicationDocumentsDirectory();
      final metadataFile = File('${directory.path}/cargo_receipts/metadata.json');

      // Create or read existing metadata
      Map<String, dynamic> metadata = {};
      if (await metadataFile.exists()) {
        String content = await metadataFile.readAsString();
        metadata = json.decode(content);
      }

      // Add new entry
      if (!metadata.containsKey('receipts')) {
        metadata['receipts'] = [];
      }

      metadata['receipts'].add({
        'destinatario': destinatario,
        'remitente': remitente,
        'articulo': articulo,
        'precio': precio,
        'telefonoDest': telefonoDest,
        'telefonoRemit': telefonoRemit,
        'ticketNum': ticketNum,
        'comprobante': comprobante,
        'date': currentDate,
        'filename': filename,
        'tipo': tipo,
        'destino': destino,
        'timestamp': DateTime.now().millisecondsSinceEpoch
      });

      // Save updated metadata
      await metadataFile.writeAsString(json.encode(metadata));
    } catch (e) {
      print('Error saving metadata: $e');
    }
  }

  // Get list of available cargo receipts
  static Future<List<Map<String, dynamic>>> getCargoReceipts() async {
    try {
      final directory = await getApplicationDocumentsDirectory();
      final metadataFile = File('${directory.path}/cargo_receipts/metadata.json');

      if (!await metadataFile.exists()) {
        return [];
      }

      String content = await metadataFile.readAsString();
      Map<String, dynamic> metadata = json.decode(content);

      if (!metadata.containsKey('receipts')) {
        return [];
      }

      // Convert to list and sort by timestamp (newest first)
      List<Map<String, dynamic>> receipts = List<Map<String, dynamic>>.from(metadata['receipts']);
      receipts.sort((a, b) => (b['timestamp'] as int).compareTo(a['timestamp'] as int));

      return receipts;
    } catch (e) {
      print('Error getting cargo receipts: $e');
      return [];
    }
  }

  // Get PDF file for a specific receipt
  static Future<File?> getReceiptFile(String filename) async {
    try {
      final directory = await getApplicationDocumentsDirectory();
      final file = File('${directory.path}/cargo_receipts/$filename');

      if (await file.exists()) {
        return file;
      }

      return null;
    } catch (e) {
      print('Error getting receipt file: $e');
      return null;
    }
  }

  // Clean up receipts older than 2 weeks
  static Future<void> _cleanOldReceipts() async {
    try {
      final twoWeeksAgo = DateTime.now().subtract(Duration(days: 14));
      final twoWeeksAgoTimestamp = twoWeeksAgo.millisecondsSinceEpoch;

      // Get metadata
      final directory = await getApplicationDocumentsDirectory();
      final metadataFile = File('${directory.path}/cargo_receipts/metadata.json');

      if (!await metadataFile.exists()) {
        return;
      }

      String content = await metadataFile.readAsString();
      Map<String, dynamic> metadata = json.decode(content);

      if (!metadata.containsKey('receipts')) {
        return;
      }

      // Filter out old receipts and collect filenames to delete
      List<dynamic> oldReceipts = [];
      List<dynamic> currentReceipts = [];

      for (var receipt in metadata['receipts']) {
        if (receipt['timestamp'] < twoWeeksAgoTimestamp) {
          oldReceipts.add(receipt);
        } else {
          currentReceipts.add(receipt);
        }
      }

      // Delete old files
      for (var receipt in oldReceipts) {
        final file = File('${directory.path}/cargo_receipts/${receipt['filename']}');
        if (await file.exists()) {
          await file.delete();
        }
      }

      // Update metadata with only current receipts
      metadata['receipts'] = currentReceipts;
      await metadataFile.writeAsString(json.encode(metadata));

    } catch (e) {
      print('Error cleaning old receipts: $e');
    }
  }

  // Get unique destinations from the database
  static Future<List<String>> getUniqueDestinations() async {
    try {
      final receipts = await getCargoReceipts();
      final Set<String> destinations = {};

      for (var receipt in receipts) {
        if (receipt.containsKey('destino') && receipt['destino'] != null) {
          destinations.add(receipt['destino'] as String);
        }
      }

      return destinations.toList();
    } catch (e) {
      print('Error getting unique destinations: $e');
      return [];
    }
  }

  // Filter receipts by destination
  static Future<List<Map<String, dynamic>>> getReceiptsByDestination(String destino) async {
    try {
      final receipts = await getCargoReceipts();

      return receipts.where((receipt) =>
      receipt.containsKey('destino') &&
          receipt['destino'] == destino
      ).toList();
    } catch (e) {
      print('Error filtering receipts by destination: $e');
      return [];
    }
  }

  // Search receipts by text
  static Future<List<Map<String, dynamic>>> searchReceipts(String query) async {
    try {
      final receipts = await getCargoReceipts();
      final lowerQuery = query.toLowerCase();

      return receipts.where((receipt) =>
      (receipt['destinatario'].toString().toLowerCase().contains(lowerQuery)) ||
          (receipt['remitente'].toString().toLowerCase().contains(lowerQuery)) ||
          (receipt['articulo'].toString().toLowerCase().contains(lowerQuery)) ||
          (receipt['comprobante'].toString().toLowerCase().contains(lowerQuery)) ||
          (receipt['ticketNum'].toString().toLowerCase().contains(lowerQuery))
      ).toList();
    } catch (e) {
      print('Error searching receipts: $e');
      return [];
    }
  }
}