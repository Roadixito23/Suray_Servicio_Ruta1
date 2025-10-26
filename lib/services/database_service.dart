import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';
import 'dart:io';
import 'package:path_provider/path_provider.dart';

class DatabaseService {
  static final DatabaseService _instance = DatabaseService._internal();
  static Database? _database;

  factory DatabaseService() {
    return _instance;
  }

  DatabaseService._internal();

  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDatabase();
    return _database!;
  }

  Future<Database> _initDatabase() async {
    Directory documentsDirectory = await getApplicationDocumentsDirectory();
    String path = join(documentsDirectory.path, 'suray_database.db');

    return await openDatabase(
      path,
      version: 1,
      onCreate: _onCreate,
      onUpgrade: _onUpgrade,
    );
  }

  Future<void> _onCreate(Database db, int version) async {
    // Tabla de transacciones
    await db.execute('''
      CREATE TABLE transacciones (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        fecha TEXT NOT NULL,
        dia TEXT NOT NULL,
        mes TEXT NOT NULL,
        hora TEXT NOT NULL,
        nombre_pasaje TEXT NOT NULL,
        valor REAL NOT NULL,
        comprobante TEXT NOT NULL,
        cierre_id INTEGER,
        created_at TEXT NOT NULL,
        FOREIGN KEY (cierre_id) REFERENCES cierres_caja (id) ON DELETE SET NULL
      )
    ''');

    // Tabla de cierres de caja
    await db.execute('''
      CREATE TABLE cierres_caja (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        fecha_cierre TEXT NOT NULL,
        total_ingresos REAL NOT NULL,
        total_transacciones INTEGER NOT NULL,
        pdf_path TEXT,
        created_at TEXT NOT NULL
      )
    ''');

    // Tabla de tarifas (lunes a sábado)
    await db.execute('''
      CREATE TABLE tarifas (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        nombre TEXT NOT NULL UNIQUE,
        precio REAL NOT NULL,
        tipo TEXT DEFAULT 'weekday',
        orden INTEGER DEFAULT 0,
        activo INTEGER DEFAULT 1,
        updated_at TEXT NOT NULL
      )
    ''');

    // Tabla de tarifas domingo/feriados
    await db.execute('''
      CREATE TABLE tarifas_domingo (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        nombre TEXT NOT NULL UNIQUE,
        precio REAL NOT NULL,
        orden INTEGER DEFAULT 0,
        activo INTEGER DEFAULT 1,
        updated_at TEXT NOT NULL
      )
    ''');

    // Tabla de configuración
    await db.execute('''
      CREATE TABLE configuracion (
        clave TEXT PRIMARY KEY,
        valor TEXT NOT NULL,
        tipo TEXT DEFAULT 'string',
        updated_at TEXT NOT NULL
      )
    ''');

    // Tabla de abreviaturas
    await db.execute('''
      CREATE TABLE abreviaturas (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        tipo_pasaje TEXT NOT NULL UNIQUE,
        abreviatura TEXT NOT NULL,
        updated_at TEXT NOT NULL
      )
    ''');

    // Índices para mejorar el rendimiento
    await db.execute('CREATE INDEX idx_transacciones_fecha ON transacciones(fecha)');
    await db.execute('CREATE INDEX idx_transacciones_cierre ON transacciones(cierre_id)');
    await db.execute('CREATE INDEX idx_cierres_fecha ON cierres_caja(fecha_cierre)');

    // Insertar datos iniciales de tarifas (lunes a sábado)
    final String now = DateTime.now().toIso8601String();
    await db.insert('tarifas', {
      'nombre': 'Público General',
      'precio': 3600.0,
      'orden': 0,
      'updated_at': now
    });
    await db.insert('tarifas', {
      'nombre': 'Escolar General',
      'precio': 2500.0,
      'orden': 1,
      'updated_at': now
    });
    await db.insert('tarifas', {
      'nombre': 'Adulto Mayor',
      'precio': 1800.0,
      'orden': 2,
      'updated_at': now
    });
    await db.insert('tarifas', {
      'nombre': 'Int. hasta 15 Km',
      'precio': 1800.0,
      'orden': 3,
      'updated_at': now
    });
    await db.insert('tarifas', {
      'nombre': 'Int. hasta 50 Km',
      'precio': 2500.0,
      'orden': 4,
      'updated_at': now
    });
    await db.insert('tarifas', {
      'nombre': 'Escolar Intermedio',
      'precio': 1000.0,
      'orden': 5,
      'updated_at': now
    });

    // Insertar datos iniciales de tarifas domingo/feriados
    await db.insert('tarifas_domingo', {
      'nombre': 'Público General',
      'precio': 4300.0,
      'orden': 0,
      'updated_at': now
    });
    await db.insert('tarifas_domingo', {
      'nombre': 'Escolar General',
      'precio': 3000.0,
      'orden': 1,
      'updated_at': now
    });
    await db.insert('tarifas_domingo', {
      'nombre': 'Adulto Mayor',
      'precio': 2150.0,
      'orden': 2,
      'updated_at': now
    });
    await db.insert('tarifas_domingo', {
      'nombre': 'Int. hasta 15 Km',
      'precio': 3000.0,
      'orden': 3,
      'updated_at': now
    });
    await db.insert('tarifas_domingo', {
      'nombre': 'Int. hasta 50 Km',
      'precio': 3000.0,
      'orden': 4,
      'updated_at': now
    });
    await db.insert('tarifas_domingo', {
      'nombre': 'Escolar Intermedio',
      'precio': 1300.0,
      'orden': 5,
      'updated_at': now
    });

    // Insertar configuraciones iniciales
    await db.insert('configuracion', {
      'clave': 'comprobanteNumber',
      'valor': '1',
      'tipo': 'int',
      'updated_at': now
    });
    await db.insert('configuracion', {
      'clave': 'ticketId',
      'valor': '1',
      'tipo': 'int',
      'updated_at': now
    });
    await db.insert('configuracion', {
      'clave': 'isAscending',
      'valor': 'true',
      'tipo': 'bool',
      'updated_at': now
    });
  }

  Future<void> _onUpgrade(Database db, int oldVersion, int newVersion) async {
    // Aquí se manejarán futuras migraciones de esquema
  }

  // ==================== MÉTODOS PARA TRANSACCIONES ====================

  Future<int> insertTransaccion(Map<String, dynamic> transaccion) async {
    final db = await database;
    transaccion['created_at'] = DateTime.now().toIso8601String();
    return await db.insert('transacciones', transaccion);
  }

  Future<List<Map<String, dynamic>>> getTransacciones({
    String? fecha,
    int? cierreId,
    String? orderBy,
  }) async {
    final db = await database;
    String where = '';
    List<dynamic> whereArgs = [];

    if (fecha != null) {
      where = 'fecha = ?';
      whereArgs.add(fecha);
    } else if (cierreId != null) {
      where = 'cierre_id = ?';
      whereArgs.add(cierreId);
    }

    return await db.query(
      'transacciones',
      where: where.isEmpty ? null : where,
      whereArgs: whereArgs.isEmpty ? null : whereArgs,
      orderBy: orderBy ?? 'id DESC',
    );
  }

  Future<List<Map<String, dynamic>>> getTransaccionesSinCierre() async {
    final db = await database;
    return await db.query(
      'transacciones',
      where: 'cierre_id IS NULL',
      orderBy: 'fecha DESC, hora DESC',
    );
  }

  Future<Map<String, dynamic>> getResumenTransacciones({
    String? fecha,
    int? cierreId,
  }) async {
    final db = await database;
    String where = '';
    List<dynamic> whereArgs = [];

    if (fecha != null) {
      where = 'WHERE fecha = ?';
      whereArgs.add(fecha);
    } else if (cierreId != null) {
      where = 'WHERE cierre_id = ?';
      whereArgs.add(cierreId);
    }

    final result = await db.rawQuery('''
      SELECT
        COUNT(*) as total_transacciones,
        COALESCE(SUM(valor), 0) as total_ingresos
      FROM transacciones
      $where
    ''', whereArgs.isEmpty ? null : whereArgs);

    return result.first;
  }

  Future<int> updateTransaccion(int id, Map<String, dynamic> transaccion) async {
    final db = await database;
    return await db.update(
      'transacciones',
      transaccion,
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  Future<int> deleteTransaccion(int id) async {
    final db = await database;
    return await db.delete(
      'transacciones',
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  // ==================== MÉTODOS PARA CIERRES DE CAJA ====================

  Future<int> createCierreCaja({
    required String fechaCierre,
    required double totalIngresos,
    required int totalTransacciones,
    String? pdfPath,
  }) async {
    final db = await database;
    final cierreId = await db.insert('cierres_caja', {
      'fecha_cierre': fechaCierre,
      'total_ingresos': totalIngresos,
      'total_transacciones': totalTransacciones,
      'pdf_path': pdfPath,
      'created_at': DateTime.now().toIso8601String(),
    });

    // Asociar todas las transacciones sin cierre a este cierre
    await db.update(
      'transacciones',
      {'cierre_id': cierreId},
      where: 'cierre_id IS NULL',
    );

    return cierreId;
  }

  Future<List<Map<String, dynamic>>> getCierresCaja({
    int? limit,
    String? orderBy,
  }) async {
    final db = await database;
    return await db.query(
      'cierres_caja',
      orderBy: orderBy ?? 'fecha_cierre DESC, created_at DESC',
      limit: limit,
    );
  }

  Future<Map<String, dynamic>?> getCierreCaja(int id) async {
    final db = await database;
    final results = await db.query(
      'cierres_caja',
      where: 'id = ?',
      whereArgs: [id],
    );
    return results.isEmpty ? null : results.first;
  }

  Future<int> updateCierreCaja(int id, Map<String, dynamic> cierre) async {
    final db = await database;
    return await db.update(
      'cierres_caja',
      cierre,
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  // ==================== MÉTODOS PARA TARIFAS ====================

  Future<List<Map<String, dynamic>>> getTarifas({bool isDomingo = false}) async {
    final db = await database;
    final tableName = isDomingo ? 'tarifas_domingo' : 'tarifas';
    return await db.query(
      tableName,
      where: 'activo = ?',
      whereArgs: [1],
      orderBy: 'orden ASC',
    );
  }

  Future<int> insertTarifa(Map<String, dynamic> tarifa, {bool isDomingo = false}) async {
    final db = await database;
    final tableName = isDomingo ? 'tarifas_domingo' : 'tarifas';
    tarifa['updated_at'] = DateTime.now().toIso8601String();
    return await db.insert(tableName, tarifa);
  }

  Future<int> updateTarifa(int id, Map<String, dynamic> tarifa, {bool isDomingo = false}) async {
    final db = await database;
    final tableName = isDomingo ? 'tarifas_domingo' : 'tarifas';
    tarifa['updated_at'] = DateTime.now().toIso8601String();
    return await db.update(
      tableName,
      tarifa,
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  Future<int> deleteTarifa(int id, {bool isDomingo = false}) async {
    final db = await database;
    final tableName = isDomingo ? 'tarifas_domingo' : 'tarifas';
    return await db.delete(
      tableName,
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  // ==================== MÉTODOS PARA CONFIGURACIÓN ====================

  Future<String?> getConfiguracion(String clave) async {
    final db = await database;
    final results = await db.query(
      'configuracion',
      where: 'clave = ?',
      whereArgs: [clave],
    );
    return results.isEmpty ? null : results.first['valor'] as String?;
  }

  Future<int> setConfiguracion(String clave, String valor, {String tipo = 'string'}) async {
    final db = await database;
    final now = DateTime.now().toIso8601String();

    return await db.insert(
      'configuracion',
      {
        'clave': clave,
        'valor': valor,
        'tipo': tipo,
        'updated_at': now,
      },
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<int> getConfiguracionInt(String clave, {int defaultValue = 0}) async {
    final valor = await getConfiguracion(clave);
    return valor != null ? int.tryParse(valor) ?? defaultValue : defaultValue;
  }

  Future<bool> getConfiguracionBool(String clave, {bool defaultValue = false}) async {
    final valor = await getConfiguracion(clave);
    return valor != null ? valor.toLowerCase() == 'true' : defaultValue;
  }

  Future<double> getConfiguracionDouble(String clave, {double defaultValue = 0.0}) async {
    final valor = await getConfiguracion(clave);
    return valor != null ? double.tryParse(valor) ?? defaultValue : defaultValue;
  }

  // ==================== MÉTODOS PARA ABREVIATURAS ====================

  Future<String?> getAbreviatura(String tipoPasaje) async {
    final db = await database;
    final results = await db.query(
      'abreviaturas',
      where: 'tipo_pasaje = ?',
      whereArgs: [tipoPasaje],
    );
    return results.isEmpty ? null : results.first['abreviatura'] as String?;
  }

  Future<int> setAbreviatura(String tipoPasaje, String abreviatura) async {
    final db = await database;
    final now = DateTime.now().toIso8601String();

    return await db.insert(
      'abreviaturas',
      {
        'tipo_pasaje': tipoPasaje,
        'abreviatura': abreviatura,
        'updated_at': now,
      },
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  // ==================== UTILIDADES ====================

  Future<void> clearAllData() async {
    final db = await database;
    await db.delete('transacciones');
    await db.delete('cierres_caja');
  }

  Future<void> resetDatabase() async {
    final db = await database;
    await db.delete('transacciones');
    await db.delete('cierres_caja');
    await db.delete('tarifas');
    await db.delete('tarifas_domingo');
    await db.delete('configuracion');
    await db.delete('abreviaturas');

    // Reinsertar datos por defecto
    await _onCreate(db, 1);
  }

  Future<String> getDatabasePath() async {
    Directory documentsDirectory = await getApplicationDocumentsDirectory();
    return join(documentsDirectory.path, 'suray_database.db');
  }

  Future<void> close() async {
    final db = await database;
    await db.close();
  }
}
