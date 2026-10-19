import 'package:path/path.dart' as path;
import 'package:sqflite/sqflite.dart';

import '../models/asignatura_model.dart';
import '../models/tarea_model.dart';

class TareasRepository {
  TareasRepository({this.fabrica, this.ruta});

  static final TareasRepository instancia = TareasRepository();
  final DatabaseFactory? fabrica;
  final String? ruta;
  Future<Database>? _abriendo;

  Future<Database> get database async {
    final apertura = _abriendo ??= _iniciarBaseDeDatos();
    try {
      return await apertura;
    } catch (_) {
      if (identical(_abriendo, apertura)) _abriendo = null;
      rethrow;
    }
  }

  Future<Database> _iniciarBaseDeDatos() async {
    final proveedor = fabrica ?? databaseFactory;
    final ubicacion =
        ruta ??
        path.join(await proveedor.getDatabasesPath(), 'prisma_tareas.db');

    return await proveedor.openDatabase(
      ubicacion,
      options: OpenDatabaseOptions(
        version: 4,
        onCreate: (Database db, int version) async {
          await _crearTablaTareas(db, 'tareas');
          await db.execute(
            'ALTER TABLE tareas ADD COLUMN google_event_id TEXT',
          );
          await _crearTablaAsignaturas(db);
          await _crearTablaPreferencias(db);
          await _insertarAsignaturasPorDefecto(db);
        },
        onUpgrade: (Database db, int versionAnterior, int versionNueva) async {
          if (versionAnterior < 2) {
            await _actualizarTablaTareasV2(db);
          }

          if (versionAnterior < 3) {
            await _crearTablaAsignaturas(db);
            await _insertarAsignaturasPorDefecto(db);
          }

          if (versionAnterior < 4) {
            await db.execute(
              'ALTER TABLE tareas ADD COLUMN google_event_id TEXT',
            );
            await _crearTablaPreferencias(db);
          }
        },
      ),
    );
  }

  Future<void> _crearTablaTareas(Database db, String nombre) async {
    await db.execute('''
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
  }

  Future<void> _crearTablaPreferencias(Database db) async {
    await db.execute('''
      CREATE TABLE preferencias (
        clave TEXT PRIMARY KEY,
        valor TEXT NOT NULL
      )
    ''');
  }

  Future<void> _actualizarTablaTareasV2(Database db) async {
    await _crearTablaTareas(db, 'tareas_v2');

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

    await db.execute('''
      UPDATE sqlite_sequence SET seq = MAX(seq, COALESCE(
        (SELECT seq FROM sqlite_sequence WHERE name = 'tareas'), 0))
      WHERE name = 'tareas_v2'
    ''');
    await db.execute('DROP TABLE tareas');
    await db.execute('ALTER TABLE tareas_v2 RENAME TO tareas');
  }

  Future<void> _crearTablaAsignaturas(Database db) async {
    await db.execute('''
      CREATE TABLE asignaturas (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        nombre TEXT NOT NULL,
        color INTEGER NOT NULL
      )
    ''');
  }

  Future<void> _insertarAsignaturasPorDefecto(Database db) async {
    await db.insert('asignaturas', {
      'nombre': 'Matemáticas',
      'color': 0xFF4CAF50,
    });
    await db.insert('asignaturas', {
      'nombre': 'Estructuras de datos',
      'color': 0xFF2196F3,
    });
    await db.insert('asignaturas', {'nombre': 'Física', 'color': 0xFFFF9800});
  }

  Future<List<Tarea>> listar() async {
    Database db = await database;
    List<Map<String, dynamic>> filas = await db.query(
      'tareas',
      orderBy: 'fecha_limite ASC, id DESC',
    );

    List<Tarea> listaTareas = [];
    for (int i = 0; i < filas.length; i++) {
      Map<String, dynamic> fila = filas[i];
      Tarea tarea = Tarea.fromMap(fila);
      listaTareas.add(tarea);
    }
    return listaTareas;
  }

  Future<Tarea?> obtener(int id) async {
    Database db = await database;
    List<Map<String, dynamic>> filas = await db.query(
      'tareas',
      where: 'id = ?',
      whereArgs: [id],
    );

    if (filas.isEmpty) {
      return null;
    } else {
      return Tarea.fromMap(filas.first);
    }
  }

  Future<Tarea> guardar(Tarea tarea) async {
    if (tarea.titulo.trim().isEmpty) {
      throw ArgumentError('Debes rellenar el título.');
    }

    if (tarea.asignatura.trim().isEmpty) {
      throw ArgumentError('Debes rellenar la asignatura.');
    }

    if (tarea.tipo.trim().isEmpty) {
      throw ArgumentError('Debes rellenar el tipo.');
    }

    for (var subtarea in tarea.subtareas) {
      if (subtarea.titulo.trim().isEmpty) {
        throw ArgumentError('Debes rellenar las subtareas.');
      }
    }

    Database db = await database;

    if (tarea.id == null) {
      int idGenerado = await db.insert('tareas', tarea.toMap());
      return tarea.copyWith(id: idGenerado);
    } else {
      int cambios = await db.update(
        'tareas',
        tarea.toMap(),
        where: 'id = ?',
        whereArgs: [tarea.id],
      );

      if (cambios == 0) {
        throw StateError('La tarea que intentas actualizar ya no existe.');
      }
      return tarea;
    }
  }

  Future<void> eliminar(int id) async {
    Database db = await database;
    await db.delete('tareas', where: 'id = ?', whereArgs: [id]);
  }

  Future<bool> sincronizacionCalendarHabilitada() async {
    final db = await database;
    final filas = await db.query(
      'preferencias',
      columns: ['valor'],
      where: 'clave = ?',
      whereArgs: ['calendar_sync_enabled'],
      limit: 1,
    );
    return filas.isNotEmpty && filas.first['valor'] == 'true';
  }

  Future<String?> correoCalendarVinculado() async {
    final db = await database;
    final filas = await db.query(
      'preferencias',
      columns: ['valor'],
      where: 'clave = ?',
      whereArgs: ['calendar_account_email'],
      limit: 1,
    );
    return filas.isEmpty ? null : filas.first['valor'] as String;
  }

  Future<void> guardarEstadoSincronizacionCalendar({
    required bool habilitada,
    String? correo,
  }) async {
    final db = await database;
    await db.transaction((txn) async {
      await txn.insert('preferencias', {
        'clave': 'calendar_sync_enabled',
        'valor': habilitada.toString(),
      }, conflictAlgorithm: ConflictAlgorithm.replace);
      if (correo != null) {
        await txn.insert('preferencias', {
          'clave': 'calendar_account_email',
          'valor': correo,
        }, conflictAlgorithm: ConflictAlgorithm.replace);
      }
    });
  }

  Future<String?> idEventoCalendar(int tareaId) async {
    final db = await database;
    final filas = await db.query(
      'tareas',
      columns: ['google_event_id'],
      where: 'id = ?',
      whereArgs: [tareaId],
      limit: 1,
    );
    if (filas.isEmpty) return null;
    return filas.first['google_event_id'] as String?;
  }

  Future<void> guardarIdEventoCalendar(int tareaId, String? eventoId) async {
    final db = await database;
    await db.update(
      'tareas',
      {'google_event_id': eventoId},
      where: 'id = ?',
      whereArgs: [tareaId],
    );
  }

  Future<List<Asignatura>> listarAsignaturas() async {
    Database db = await database;
    List<Map<String, dynamic>> filas = await db.query(
      'asignaturas',
      orderBy: 'nombre ASC',
    );

    List<Asignatura> listaAsignaturas = [];
    for (int i = 0; i < filas.length; i++) {
      listaAsignaturas.add(Asignatura.fromMap(filas[i]));
    }
    return listaAsignaturas;
  }

  Future<Asignatura> guardarAsignatura(Asignatura asignatura) async {
    if (asignatura.nombre.trim().isEmpty) {
      throw ArgumentError('Debes rellenar el nombre.');
    }

    Database db = await database;

    if (asignatura.id == null) {
      int idGenerado = await db.insert('asignaturas', asignatura.toMap());
      return asignatura.copyWith(id: idGenerado);
    } else {
      await db.update(
        'asignaturas',
        asignatura.toMap(),
        where: 'id = ?',
        whereArgs: [asignatura.id],
      );
      return asignatura;
    }
  }

  Future<void> eliminarAsignatura(int id) async {
    Database db = await database;
    await db.delete('asignaturas', where: 'id = ?', whereArgs: [id]);
  }

  Future<void> cerrar() async {
    final apertura = _abriendo;
    if (apertura == null) return;
    await (await apertura).close();
    _abriendo = null;
  }
}
