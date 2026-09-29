import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as path;
import 'package:prisma/data/tareas_repository.dart';
import 'package:prisma/models/tarea_model.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

void main() {
  late Directory directorio;
  late String ruta;
  late TareasRepository repositorio;

  setUpAll(sqfliteFfiInit);
  setUp(() async {
    directorio = await Directory.systemTemp.createTemp('prisma_tareas_test_');
    ruta = path.join(directorio.path, 'tareas.db');
    repositorio = TareasRepository(fabrica: databaseFactoryFfi, ruta: ruta);
  });
  tearDown(() async {
    await repositorio.cerrar();
    // Solo se elimina el directorio temporal creado por esta prueba.
    await directorio.delete(recursive: true);
  });

  Tarea ejemplo({String titulo = "Entrega de O'Connor"}) => Tarea(
    titulo: titulo,
    asignatura: 'Aplicaciones móviles',
    fechaLimite: DateTime(2026, 10, 20, 23, 59),
    tipo: 'Proyecto',
    importancia: ImportanciaTarea.alta,
    estado: EstadoTarea.enProgreso,
    subtareas: const [
      Subtarea(titulo: 'Diseñar'),
      Subtarea(titulo: 'Programar'),
    ],
  );

  test(
    'Guarda todos los campos y sobreviven a cerrar y reabrir SQLite',
    () async {
      final guardada = await repositorio.guardar(ejemplo());
      expect(guardada.id, isNotNull);
      await repositorio.cerrar();
      repositorio = TareasRepository(fabrica: databaseFactoryFfi, ruta: ruta);
      final recuperada = (await repositorio.listar()).single;
      expect(recuperada.toMap(), guardada.toMap());
      expect(recuperada.fechaLimite, DateTime(2026, 10, 20, 23, 59));
    },
  );

  test('Edita sin duplicar y persiste estado, fecha y subtareas', () async {
    final guardada = await repositorio.guardar(ejemplo());
    final editada = guardada.copyWith(
      titulo: 'Entrega final',
      fechaLimite: DateTime(2026, 10, 22, 9, 30),
      estado: EstadoTarea.completada,
      importancia: ImportanciaTarea.baja,
      subtareas: const [Subtarea(titulo: 'Diseñar', completada: true)],
    );
    await repositorio.guardar(editada);
    await repositorio.cerrar();
    final recuperada = await repositorio.obtener(guardada.id!);
    expect(recuperada!.toMap(), editada.toMap());
    expect(recuperada.subtareasCompletadas, 1);
    expect(await repositorio.listar(), hasLength(1));
  });

  test(
    'Eliminar una tarea no afecta las otras y persiste al reabrir',
    () async {
      final primera = await repositorio.guardar(ejemplo());
      final segunda = await repositorio.guardar(ejemplo(titulo: 'Segunda'));
      await repositorio.eliminar(primera.id!);
      await repositorio.cerrar();
      expect(await repositorio.obtener(primera.id!), isNull);
      expect((await repositorio.listar()).single.id, segunda.id);
    },
  );

  test('Rechaza campos vacíos sin escribir registros incompletos', () async {
    await expectLater(
      repositorio.guardar(ejemplo(titulo: '  ')),
      throwsArgumentError,
    );
    await expectLater(
      repositorio.guardar(
        ejemplo().copyWith(subtareas: const [Subtarea(titulo: '  ')]),
      ),
      throwsArgumentError,
    );
    expect(await repositorio.listar(), isEmpty);
  });

  test('Actualizar un id inexistente no crea otra tarea', () async {
    await expectLater(
      repositorio.guardar(ejemplo().copyWith(id: 999)),
      throwsStateError,
    );
    expect(await repositorio.listar(), isEmpty);
  });

  test('Lista por fecha límite y comparte la apertura concurrente', () async {
    await Future.wait([
      repositorio.guardar(ejemplo(titulo: 'Después')),
      repositorio.guardar(
        ejemplo(titulo: 'Antes').copyWith(fechaLimite: DateTime(2026, 10, 10)),
      ),
    ]);
    expect((await repositorio.listar()).map((t) => t.titulo), [
      'Antes',
      'Después',
    ]);
  });
}
