import 'package:sqflite/sqflite.dart' as sql;
import 'package:path/path.dart';
import 'package:path_provider/path_provider.dart';
import 'dart:io';
import '../models/cobro_model.dart';
import '../models/cliente_models.dart';
import 'package:flutter/widgets.dart'; // Añade este import

class DatabaseHelper {
  // Nombres de tablas
  static const String tableCobros = 'cobros';
  static const String tableClientes = 'clientes';

  // Columnas para tabla cobros
  static const String columnId = 'id';
  static const String columnClienteId = 'clienteId';
  static const String columnCliente = 'cliente';
  static const String columnMonto = 'monto';
  static const String columnFecha = 'fecha';
  static const String columnUbicacion = 'ubicacion';
  static const String columnEstado = 'estado';

  // Columnas para tabla clientes
  static const String columnClienteNombre = 'nombre';
  static const String columnClienteTelefono = 'telefono';
  static const String columnClienteEmail = 'email';
  static const String columnClienteDireccion = 'direccion';
  static const String columnClienteFechaRegistro = 'fechaRegistro';

  static const _databaseName = 'cobros.db';
  static const _databaseVersion = 3;

  // Singleton
  DatabaseHelper._privateConstructor();
  static final DatabaseHelper instance = DatabaseHelper._privateConstructor();

  static sql.Database? _database;

  Future<sql.Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDatabase();
    return _database!;
  }

  Future<sql.Database> _initDatabase() async {
    // Asegurar que los widgets de Flutter estén inicializados
    WidgetsFlutterBinding.ensureInitialized();

    final documentsDirectory = await getApplicationDocumentsDirectory();
    final path = join(documentsDirectory.path, _databaseName);

    try {
      await Directory(dirname(path)).create(recursive: true);
    } catch (e) {
      print('Error al crear directorio: $e');
    }

    return await sql.openDatabase(
      path,
      version: _databaseVersion,
      onCreate: _onCreate,
      onUpgrade: _onUpgrade,
      onConfigure: (db) async {
        await db.execute('PRAGMA foreign_keys = ON');
      },
    );
  }

  Future _onCreate(sql.Database db, int version) async {
    await db.execute('''
      CREATE TABLE $tableClientes (
        $columnId INTEGER PRIMARY KEY AUTOINCREMENT,
        $columnClienteNombre TEXT NOT NULL,
        $columnClienteTelefono TEXT,
        $columnClienteEmail TEXT,
        $columnClienteDireccion TEXT,
        $columnClienteFechaRegistro TEXT NOT NULL
      )
    ''');

    await db.execute('''
      CREATE TABLE $tableCobros (
        $columnId INTEGER PRIMARY KEY AUTOINCREMENT,
        $columnClienteId INTEGER NOT NULL,
        $columnCliente TEXT NOT NULL,
        $columnMonto REAL NOT NULL,
        $columnFecha TEXT NOT NULL,
        $columnUbicacion TEXT NOT NULL,
        $columnEstado TEXT DEFAULT 'pendiente',
        FOREIGN KEY ($columnClienteId) REFERENCES $tableClientes ($columnId)
      )
    ''');
  }

  Future _onUpgrade(sql.Database db, int oldVersion, int newVersion) async {
    if (oldVersion < 2) {
      await db.execute(
        'ALTER TABLE $tableCobros ADD COLUMN $columnEstado TEXT DEFAULT "pendiente"',
      );
    }

    if (oldVersion < 3) {
      try {
        await db.execute('''
          CREATE TABLE IF NOT EXISTS $tableClientes (
            $columnId INTEGER PRIMARY KEY AUTOINCREMENT,
            $columnClienteNombre TEXT NOT NULL,
            $columnClienteTelefono TEXT,
            $columnClienteEmail TEXT,
            $columnClienteDireccion TEXT,
            $columnClienteFechaRegistro TEXT NOT NULL
          )
        ''');

        await db.insert(tableClientes, {
          columnClienteNombre: 'Cliente General',
          columnClienteFechaRegistro: DateTime.now().toIso8601String(),
        });

        await db.execute('''
          CREATE TABLE ${tableCobros}_temp (
            $columnId INTEGER PRIMARY KEY AUTOINCREMENT,
            $columnClienteId INTEGER NOT NULL DEFAULT 1,
            $columnCliente TEXT NOT NULL,
            $columnMonto REAL NOT NULL,
            $columnFecha TEXT NOT NULL,
            $columnUbicacion TEXT NOT NULL,
            $columnEstado TEXT DEFAULT 'pendiente',
            FOREIGN KEY ($columnClienteId) REFERENCES $tableClientes ($columnId)
          )
        ''');

        await db.execute('''
          INSERT INTO ${tableCobros}_temp 
          ($columnId, $columnClienteId, $columnCliente, $columnMonto, $columnFecha, $columnUbicacion, $columnEstado)
          SELECT $columnId, 1, $columnCliente, $columnMonto, $columnFecha, $columnUbicacion, 
          COALESCE($columnEstado, 'pendiente') FROM $tableCobros
        ''');

        await db.execute('DROP TABLE $tableCobros');
        await db.execute(
          'ALTER TABLE ${tableCobros}_temp RENAME TO $tableCobros',
        );
      } catch (e) {
        print('Error durante migración a v3: $e');
        rethrow;
      }
    }
  }

  // Métodos para clientes
  Future<int> insertCliente(Cliente cliente) async {
    final db = await database;
    return await db.insert(
      tableClientes,
      cliente.toMap(),
      conflictAlgorithm: sql.ConflictAlgorithm.replace,
    );
  }

  Future<List<Cliente>> getClientes() async {
    final db = await database;
    final List<Map<String, dynamic>> maps = await db.query(tableClientes);
    return List.generate(maps.length, (i) => Cliente.fromMap(maps[i]));
  }

  // Métodos para cobros
  Future<int> insertCobro(Cobro cobro) async {
    final db = await database;
    return await db.insert(tableCobros, {
      columnClienteId: cobro.clienteId,
      columnCliente: cobro.clienteNombre,
      columnMonto: cobro.monto,
      columnFecha: cobro.fecha.toIso8601String(),
      columnUbicacion: cobro.ubicacion,
      columnEstado: cobro.estado ?? 'pendiente',
    });
  }

  Future<List<Cobro>> getCobros() async {
    final db = await database;
    final List<Map<String, dynamic>> maps = await db.query(
      tableCobros,
      orderBy: '$columnFecha DESC',
    );

    return List.generate(maps.length, (i) {
      return Cobro(
        id: maps[i][columnId],
        clienteId: maps[i][columnClienteId],
        clienteNombre: maps[i][columnCliente] ?? 'Sin nombre',
        monto: (maps[i][columnMonto] as num).toDouble(),
        fecha: DateTime.parse(maps[i][columnFecha]),
        ubicacion: maps[i][columnUbicacion] ?? 'Sin ubicación',
        estado: maps[i][columnEstado] ?? 'pendiente',
      );
    });
  }

  Future<int> updateCobro(Cobro cobro) async {
    final db = await database;
    return await db.update(
      tableCobros,
      {
        columnClienteId: cobro.clienteId,
        columnCliente: cobro.clienteNombre,
        columnMonto: cobro.monto,
        columnFecha: cobro.fecha.toIso8601String(),
        columnUbicacion: cobro.ubicacion,
        columnEstado: cobro.estado,
      },
      where: '$columnId = ?',
      whereArgs: [cobro.id],
    );
  }

  Future<int> deleteCobro(int id) async {
    final db = await database;
    return await db.delete(
      tableCobros,
      where: '$columnId = ?',
      whereArgs: [id],
    );
  }

  Future<void> close() async {
    if (_database != null) {
      await _database!.close();
      _database = null;
    }
  }
}
