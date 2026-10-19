import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as path;
import 'package:prisma/data/tareas_repository.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

void main() {
  late Directory directorio;

  setUpAll(sqfliteFfiInit);

  setUp(() async {
    directorio = await Directory.systemTemp.createTemp(
      'prisma-calendar-migration-',
    );
  });

  tearDown(() async {
    await directorio.delete(recursive: true);
  });

  test('migrates version 1 tasks and creates Calendar settings', () async {
    final ruta = path.join(directorio.path, 'tareas.db');
    final dbAntigua = await databaseFactoryFfi.openDatabase(
      ruta,
      options: OpenDatabaseOptions(
        version: 1,
        onCreate: (db, version) async {
          await db.execute('''
            CREATE TABLE tareas (
              id INTEGER PRIMARY KEY AUTOINCREMENT,
              titulo TEXT NOT NULL,
              asignatura TEXT NOT NULL,
              fecha_limite INTEGER NOT NULL,
              tipo TEXT NOT NULL,
              importancia TEXT NOT NULL,
              estado TEXT NOT NULL,
              subtareas TEXT NOT NULL
            )
          ''');
          await db.insert('tareas', {
            'titulo': 'Entrega',
            'asignatura': 'Matemáticas',
            'fecha_limite': DateTime(2026, 10, 20).millisecondsSinceEpoch,
            'tipo': 'Tarea',
            'importancia': 'media',
            'estado': 'pendiente',
            'subtareas': '[]',
          });
        },
      ),
    );
    await dbAntigua.close();

    final repositorio = TareasRepository(
      fabrica: databaseFactoryFfi,
      ruta: ruta,
    );

    final tarea = await repositorio.obtener(1);
    expect(tarea?.titulo, 'Entrega');
    expect(tarea?.importancia, 3);
    expect(await repositorio.idEventoCalendar(1), isNull);
    expect(await repositorio.sincronizacionCalendarHabilitada(), isFalse);

    await repositorio.guardarIdEventoCalendar(1, 'evento-google');
    await repositorio.guardarEstadoSincronizacionCalendar(
      habilitada: true,
      correo: 'estudiante@example.com',
    );

    expect(await repositorio.idEventoCalendar(1), 'evento-google');
    expect(await repositorio.sincronizacionCalendarHabilitada(), isTrue);
    expect(
      await repositorio.correoCalendarVinculado(),
      'estudiante@example.com',
    );
    await repositorio.cerrar();
  });
}
