import 'package:path/path.dart' as path;
import 'package:sqflite/sqflite.dart';

import '../models/tarea_model.dart';

/// Único punto de acceso al almacenamiento local de las tareas.
/// La fábrica y la ruta opcionales permiten probar SQLite sin un teléfono.
class TareasRepository {
  TareasRepository({this.fabrica, this.ruta});

  static final instancia = TareasRepository();
  final DatabaseFactory? fabrica;
  final String? ruta;
  Future<Database>? _abriendo;

  Future<Database> _database() async {
    // Comparte la apertura si varias pantallas solicitan datos simultáneamente.
    final apertura = _abriendo ??= _abrir();
    try {
      return await apertura;
    } catch (_) {
      if (identical(_abriendo, apertura)) _abriendo = null;
      rethrow;
    }
  }

  Future<Database> _abrir() async {
    final proveedor = fabrica ?? databaseFactory;
    final ubicacion =
        ruta ??
        path.join(await proveedor.getDatabasesPath(), 'prisma_tareas.db');
    return proveedor.openDatabase(
      ubicacion,
      options: OpenDatabaseOptions(
        version: 2,
        onCreate: (db, version) => _crearTabla(db, 'tareas'),
        // sqflite ejecuta la migración en una transacción: ante un fallo,
        // conserva íntegra la base anterior y permite reintentar su apertura.
        onUpgrade: (db, anterior, nueva) async {
          if (anterior < 2) {
            await _crearTabla(db, 'tareas_v2');
            await db.execute('''
              INSERT INTO tareas_v2
                (id, titulo, asignatura, fecha_limite, tipo, importancia, estado, subtareas)
              SELECT id, titulo, asignatura, fecha_limite, tipo,
                CASE importancia
                  WHEN 'baja' THEN 1
                  WHEN 'media' THEN 3
                  WHEN 'alta' THEN 5
                  ELSE CAST(importancia AS INTEGER)
                END,
                estado, subtareas
              FROM tareas
            ''');
            // Mantiene la secuencia de ids incluso si la última tarea se borró.
            await db.execute('''
              UPDATE sqlite_sequence SET seq = MAX(seq, COALESCE(
                (SELECT seq FROM sqlite_sequence WHERE name = 'tareas'), 0))
              WHERE name = 'tareas_v2'
            ''');
            await db.execute('DROP TABLE tareas');
            await db.execute('ALTER TABLE tareas_v2 RENAME TO tareas');
          }
        },
      ),
    );
  }

  Future<void> _crearTabla(Database db, String nombre) => db.execute('''
            CREATE TABLE $nombre (
              id INTEGER PRIMARY KEY AUTOINCREMENT,
              titulo TEXT NOT NULL,
              asignatura TEXT NOT NULL,
              fecha_limite INTEGER NOT NULL,
              tipo TEXT NOT NULL,
              importancia INTEGER NOT NULL CHECK (
                typeof(importancia) = 'integer' AND importancia BETWEEN 1 AND 5
              ),
              estado TEXT NOT NULL,
              subtareas TEXT NOT NULL
            )
          ''');

  Future<List<Tarea>> listar() async {
    final db = await _database();
    final filas = await db.query(
      'tareas',
      orderBy: 'fecha_limite ASC, id DESC',
    );
    return filas.map(Tarea.fromMap).toList();
  }

  Future<Tarea?> obtener(int id) async {
    final db = await _database();
    final filas = await db.query('tareas', where: 'id = ?', whereArgs: [id]);
    return filas.isEmpty ? null : Tarea.fromMap(filas.single);
  }

  Future<Tarea> guardar(Tarea tarea) async {
    if (tarea.titulo.trim().isEmpty ||
        tarea.asignatura.trim().isEmpty ||
        tarea.tipo.trim().isEmpty ||
        tarea.subtareas.any((s) => s.titulo.trim().isEmpty)) {
      throw ArgumentError('Los campos de la tarea no pueden estar vacíos.');
    }
    final db = await _database();
    if (tarea.id == null) {
      final id = await db.insert('tareas', tarea.toMap());
      return tarea.copyWith(id: id);
    }
    final cambios = await db.update(
      'tareas',
      tarea.toMap(),
      where: 'id = ?',
      whereArgs: [tarea.id],
    );
    if (cambios != 1) throw StateError('La tarea ya no existe.');
    return tarea;
  }

  Future<void> eliminar(int id) async {
    final db = await _database();
    await db.delete('tareas', where: 'id = ?', whereArgs: [id]);
  }

  Future<void> cerrar() async {
    final apertura = _abriendo;
    if (apertura == null) return;
    await (await apertura).close();
    _abriendo = null;
  }
}
