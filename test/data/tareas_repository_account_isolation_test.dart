import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as path;
import 'package:prisma/data/tareas_repository.dart';
import 'package:prisma/models/tarea_model.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

void main() {
  late Directory directorio;
  late TareasRepository repositorio;
  var uidActual = 'cuenta-a';

  setUpAll(sqfliteFfiInit);

  setUp(() async {
    directorio = await Directory.systemTemp.createTemp(
      'prisma-account-isolation-',
    );
    uidActual = 'cuenta-a';
    repositorio = TareasRepository(
      fabrica: databaseFactoryFfi,
      ruta: path.join(directorio.path, 'tareas.db'),
      uidUsuarioActual: () => uidActual,
    );
  });

  tearDown(() async {
    await repositorio.cerrar();
    await directorio.delete(recursive: true);
  });

  test('las tareas solo se consultan y modifican desde su cuenta', () async {
    final guardada = await repositorio.guardar(
      Tarea(
        titulo: 'Entrega',
        asignatura: 'Matemáticas',
        fechaLimite: DateTime(2026, 12, 1),
        tipo: 'Tarea',
      ),
    );

    uidActual = 'cuenta-b';
    expect(await repositorio.listar(), isEmpty);
    expect(await repositorio.obtener(guardada.id!), isNull);
    await repositorio.eliminar(guardada.id!);
    await expectLater(
      repositorio.guardar(guardada.copyWith(titulo: 'Editada')),
      throwsA(isA<StateError>()),
    );

    uidActual = 'cuenta-a';
    expect((await repositorio.obtener(guardada.id!))?.titulo, 'Entrega');
  });
}
