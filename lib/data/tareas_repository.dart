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

  /// Input:
  /// - No recibe parámetros; usa la fábrica y ruta configuradas.
  /// Output:
  /// - `Future<Database>`: base de datos abierta o en proceso de apertura.
  /// Resumen:
  /// - Comparte la apertura concurrente y permite reintentar si falla.
  Future<Database> get database async {
    final apertura = _abriendo ??= _iniciarBaseDeDatos();
    try {
      return await apertura;
    } catch (_) {
      if (identical(_abriendo, apertura)) _abriendo = null;
      rethrow;
    }
  }

  /// Input:
  /// - No recibe parámetros; utiliza las opciones de fábrica y ruta del repositorio.
  /// Output:
  /// - `Future<Database>`: conexión abierta y migrada a la versión actual.
  /// Resumen:
  /// - Abre la base de datos y crea o migra sus tablas.
  Future<Database> _iniciarBaseDeDatos() async {
    final proveedor = fabrica ?? databaseFactory;
    final ubicacion =
        ruta ??
        path.join(await proveedor.getDatabasesPath(), 'prisma_tareas.db');

    return await proveedor.openDatabase(
      ubicacion,
      options: OpenDatabaseOptions(
        version: 6,
        onCreate: (Database db, int version) async {
          await _crearTablaTareas(db, 'tareas');
          await db.execute(
            'ALTER TABLE tareas ADD COLUMN google_event_id TEXT',
          );
          await _crearTablaAsignaturas(db);
          await _crearTablaPreferencias(db);
          await _crearTablaTiempoEstudio(db);
          await _crearTablasMetasSemanales(db);
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

          if (versionAnterior < 5) {
            await _crearTablaTiempoEstudio(db);
          }

          if (versionAnterior < 6) {
            await _crearTablasMetasSemanales(db);
          }
        },
      ),
    );
  }

  /// Input:
  /// - `db` (`Database`): conexión donde se creará la tabla.
  /// - `nombre` (`String`): nombre SQL de la tabla de tareas.
  /// Output:
  /// - `Future<void>`: termina al ejecutar la creación.
  /// Resumen:
  /// - Crea la tabla de tareas con sus columnas y restricciones.
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

  /// Input:
  /// - `db` (`Database`): conexión donde se creará la tabla.
  /// Output:
  /// - `Future<void>`: termina al ejecutar la creación.
  /// Resumen:
  /// - Crea la tabla de preferencias clave-valor.
  Future<void> _crearTablaPreferencias(Database db) async {
    await db.execute('''
      CREATE TABLE preferencias (
        clave TEXT PRIMARY KEY,
        valor TEXT NOT NULL
      )
    ''');
  }

  /// Input:
  /// - `db` (`Database`): conexión donde se creará la tabla.
  /// Output:
  /// - `Future<void>`: termina al ejecutar la creación.
  /// Resumen:
  /// - Crea la tabla con el total de segundos estudiados por asignatura.
  Future<void> _crearTablaTiempoEstudio(Database db) async {
    await db.execute('''
      CREATE TABLE tiempo_estudio (
        asignatura TEXT PRIMARY KEY NOT NULL,
        segundos INTEGER NOT NULL CHECK (
          typeof(segundos) = 'integer' AND segundos >= 0
        )
      )
    ''');
  }

  /// Input:
  /// - `db` (`Database`): conexión donde se crearán las tablas e índice.
  /// Output:
  /// - `Future<void>`: termina al completar el esquema semanal.
  /// Resumen:
  /// - Crea metas semanales, sesiones de estudio y su índice de consulta.
  Future<void> _crearTablasMetasSemanales(Database db) async {
    await db.execute('''
      CREATE TABLE metas_semanales (
        asignatura TEXT PRIMARY KEY NOT NULL,
        segundos INTEGER NOT NULL CHECK (
          typeof(segundos) = 'integer' AND segundos > 0
        )
      )
    ''');
    await db.execute('''
      CREATE TABLE sesiones_estudio (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        asignatura TEXT NOT NULL,
        segundos INTEGER NOT NULL CHECK (
          typeof(segundos) = 'integer' AND segundos > 0
        ),
        fecha INTEGER NOT NULL
      )
    ''');
    await db.execute('''
      CREATE INDEX sesiones_estudio_fecha_asignatura
      ON sesiones_estudio (fecha, asignatura)
    ''');
  }

  /// Input:
  /// - `db` (`Database`): conexión con el esquema antiguo que se migrará.
  /// Output:
  /// - `Future<void>`: termina al reemplazar la tabla antigua.
  /// Resumen:
  /// - Migra tareas al esquema v2 y convierte importancia a valores numéricos.
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

  /// Input:
  /// - `db` (`Database`): conexión donde se creará la tabla.
  /// Output:
  /// - `Future<void>`: termina al ejecutar la creación.
  /// Resumen:
  /// - Crea la tabla que almacena asignaturas y sus colores.
  Future<void> _crearTablaAsignaturas(Database db) async {
    await db.execute('''
      CREATE TABLE asignaturas (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        nombre TEXT NOT NULL,
        color INTEGER NOT NULL
      )
    ''');
  }

  /// Input:
  /// - `db` (`Database`): conexión donde se insertarán los registros.
  /// Output:
  /// - `Future<void>`: termina al insertar las asignaturas iniciales.
  /// Resumen:
  /// - Carga las asignaturas predeterminadas de una instalación nueva.
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

  /// Input:
  /// - No recibe parámetros; consulta las tareas almacenadas.
  /// Output:
  /// - `Future<List<Tarea>>`: tareas ordenadas por fecha límite e identificador.
  /// Resumen:
  /// - Lee y convierte todas las filas de tareas a modelos.
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

  /// Input:
  /// - `id` (`int`): identificador de la tarea que se buscará.
  /// Output:
  /// - `Future<Tarea?>`: tarea encontrada o `null` si no existe.
  /// Resumen:
  /// - Consulta una tarea por su identificador.
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

  /// Input:
  /// - `tarea` (`Tarea`): datos validados que se insertarán o actualizarán.
  /// Output:
  /// - `Future<Tarea>`: tarea guardada, con el ID generado si era nueva.
  /// Resumen:
  /// - Valida campos obligatorios y persiste la tarea en la base de datos.
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

  /// Input:
  /// - `id` (`int`): identificador de la tarea que se eliminará.
  /// Output:
  /// - `Future<void>`: termina al ejecutar la eliminación.
  /// Resumen:
  /// - Borra de la base de datos la tarea indicada.
  Future<void> eliminar(int id) async {
    Database db = await database;
    await db.delete('tareas', where: 'id = ?', whereArgs: [id]);
  }

  /// Input:
  /// - No recibe parámetros; consulta la preferencia de sincronización.
  /// Output:
  /// - `Future<bool>`: `true` si Calendar está habilitado.
  /// Resumen:
  /// - Lee el estado de sincronización guardado en preferencias.
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

  /// Input:
  /// - No recibe parámetros; consulta la cuenta guardada en preferencias.
  /// Output:
  /// - `Future<String?>`: correo vinculado o `null` si no hay uno guardado.
  /// Resumen:
  /// - Recupera el correo asociado a Google Calendar.
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

  /// Input:
  /// - `habilitada` (`bool`): nuevo estado de sincronización.
  /// - `correo` (`String?`): correo opcional de la cuenta vinculada.
  /// Output:
  /// - `Future<void>`: termina al guardar las preferencias en una transacción.
  /// Resumen:
  /// - Persiste la activación de Calendar y, si se indicó, su cuenta.
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

  /// Input:
  /// - `tareaId` (`int`): identificador local de la tarea.
  /// Output:
  /// - `Future<String?>`: ID del evento de Calendar o `null` si no existe.
  /// Resumen:
  /// - Consulta el ID remoto vinculado a la tarea.
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

  /// Input:
  /// - `tareaId` (`int`): identificador local de la tarea.
  /// - `eventoId` (`String?`): ID remoto que se asociará o eliminará.
  /// Output:
  /// - `Future<void>`: termina al actualizar la fila de la tarea.
  /// Resumen:
  /// - Guarda o limpia la relación entre tarea y evento de Calendar.
  Future<void> guardarIdEventoCalendar(int tareaId, String? eventoId) async {
    final db = await database;
    await db.update(
      'tareas',
      {'google_event_id': eventoId},
      where: 'id = ?',
      whereArgs: [tareaId],
    );
  }

  /// Input:
  /// - No recibe parámetros; consulta las asignaturas almacenadas.
  /// Output:
  /// - `Future<List<Asignatura>>`: asignaturas ordenadas por nombre.
  /// Resumen:
  /// - Lee y convierte las filas de asignaturas a modelos.
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

  /// Input:
  /// - `asignatura` (`Asignatura`): nombre, color y posible ID a guardar.
  /// Output:
  /// - `Future<Asignatura>`: asignatura guardada, con ID si fue nueva.
  /// Resumen:
  /// - Valida el nombre y crea o actualiza la asignatura.
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

  /// Input:
  /// - `id` (`int`): identificador de la asignatura que se eliminará.
  /// Output:
  /// - `Future<void>`: termina al ejecutar la eliminación.
  /// Resumen:
  /// - Borra de la base de datos la asignatura indicada.
  Future<void> eliminarAsignatura(int id) async {
    Database db = await database;
    await db.delete('asignaturas', where: 'id = ?', whereArgs: [id]);
  }

  /// Input:
  /// - `asignatura` (`String`): asignatura a la que se atribuye el tiempo.
  /// - `segundos` (`int`): cantidad positiva de segundos de estudio.
  /// - `fecha` (`DateTime?`): fecha opcional de la sesión; por defecto, ahora.
  /// Output:
  /// - `Future<void>`: termina al registrar la sesión y actualizar el total.
  /// Resumen:
  /// - Guarda la sesión y suma sus segundos al acumulado de la asignatura.
  Future<void> registrarTiempoEstudio({
    required String asignatura,
    required int segundos,
    DateTime? fecha,
  }) async {
    if (asignatura.trim().isEmpty) {
      throw ArgumentError('Debes seleccionar una asignatura.');
    }
    if (segundos <= 0) {
      throw ArgumentError.value(segundos, 'segundos', 'Debe ser mayor que 0.');
    }

    final db = await database;
    final momento = (fecha ?? DateTime.now()).millisecondsSinceEpoch;
    await db.transaction((txn) async {
      await txn.insert('sesiones_estudio', {
        'asignatura': asignatura.trim(),
        'segundos': segundos,
        'fecha': momento,
      });
      await txn.rawInsert(
        '''
        INSERT INTO tiempo_estudio (asignatura, segundos)
        VALUES (?, ?)
        ON CONFLICT(asignatura) DO UPDATE SET
          segundos = tiempo_estudio.segundos + excluded.segundos
        ''',
        [asignatura.trim(), segundos],
      );
    });
  }

  /// Input:
  /// - `asignatura` (`String`): nombre de la asignatura que se consultará.
  /// Output:
  /// - `Future<int>`: segundos acumulados, o cero si aún no hay registro.
  /// Resumen:
  /// - Consulta el tiempo total de estudio de una asignatura.
  Future<int> obtenerTiempoEstudio(String asignatura) async {
    final db = await database;
    final filas = await db.query(
      'tiempo_estudio',
      columns: ['segundos'],
      where: 'asignatura = ?',
      whereArgs: [asignatura.trim()],
      limit: 1,
    );
    return filas.isEmpty ? 0 : filas.first['segundos'] as int;
  }

  /// Input:
  /// - `asignatura` (`String`): asignatura para la meta semanal.
  /// - `segundos` (`int`): duración objetivo, hasta 168 horas.
  /// Output:
  /// - `Future<void>`: termina al insertar o reemplazar la meta.
  /// Resumen:
  /// - Valida y guarda la meta semanal de la asignatura.
  Future<void> guardarMetaSemanal({
    required String asignatura,
    required int segundos,
  }) async {
    if (asignatura.trim().isEmpty) {
      throw ArgumentError('Debes seleccionar una asignatura.');
    }
    if (segundos <= 0 || segundos > const Duration(hours: 168).inSeconds) {
      throw ArgumentError.value(
        segundos,
        'segundos',
        'La meta debe estar entre 1 segundo y 168 horas.',
      );
    }
    final db = await database;
    await db.insert(
      'metas_semanales',
      {'asignatura': asignatura.trim(), 'segundos': segundos},
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  /// Input:
  /// - No recibe parámetros; consulta todas las metas guardadas.
  /// Output:
  /// - `Future<Map<String, int>>`: segundos objetivo indexados por asignatura.
  /// Resumen:
  /// - Devuelve el conjunto de metas semanales almacenadas.
  Future<Map<String, int>> listarMetasSemanales() async {
    final db = await database;
    final filas = await db.query('metas_semanales');
    return {
      for (final fila in filas)
        fila['asignatura'] as String: fila['segundos'] as int,
    };
  }

  /// Input:
  /// - `fecha` (`DateTime?`): fecha opcional para determinar la semana.
  /// Output:
  /// - `Future<Map<String, int>>`: segundos estudiados por asignatura esa semana.
  /// Resumen:
  /// - Suma las sesiones desde el lunes hasta el inicio de la semana siguiente.
  Future<Map<String, int>> obtenerTiempoEstudioSemanal({
    DateTime? fecha,
  }) async {
    final ahora = fecha ?? DateTime.now();
    final inicioSemana = DateTime(
      ahora.year,
      ahora.month,
      ahora.day,
    ).subtract(Duration(days: ahora.weekday - DateTime.monday));
    final finSemana = inicioSemana.add(const Duration(days: 7));
    final db = await database;
    final filas = await db.rawQuery(
      '''
      SELECT asignatura, SUM(segundos) AS segundos
      FROM sesiones_estudio
      WHERE fecha >= ? AND fecha < ?
      GROUP BY asignatura
      ''',
      [
        inicioSemana.millisecondsSinceEpoch,
        finSemana.millisecondsSinceEpoch,
      ],
    );
    return {
      for (final fila in filas)
        fila['asignatura'] as String: fila['segundos'] as int,
    };
  }

  /// Input:
  /// - No recibe parámetros; usa la conexión abierta por este repositorio.
  /// Output:
  /// - `Future<void>`: termina cuando la conexión queda cerrada.
  /// Resumen:
  /// - Cierra la base de datos si fue abierta y permite abrirla nuevamente.
  Future<void> cerrar() async {
    final apertura = _abriendo;
    if (apertura == null) return;
    await (await apertura).close();
    _abriendo = null;
  }
}
