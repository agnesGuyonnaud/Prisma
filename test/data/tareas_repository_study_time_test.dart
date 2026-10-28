import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as path;
import 'package:prisma/data/tareas_repository.dart';
import 'package:prisma/models/asignatura_model.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

void main() {
  late Directory directorio;
  late TareasRepository repositorio;

  setUpAll(sqfliteFfiInit);

  setUp(() async {
    directorio = await Directory.systemTemp.createTemp('prisma-study-time-');
    repositorio = TareasRepository(
      fabrica: databaseFactoryFfi,
      ruta: path.join(directorio.path, 'tareas.db'),
    );
  });

  tearDown(() async {
    await repositorio.cerrar();
    await directorio.delete(recursive: true);
  });

  test('acumula los segundos de estudio por asignatura', () async {
    await repositorio.guardarAsignatura(
      Asignatura(nombre: 'Biología', color: Colors.green),
    );

    await repositorio.registrarTiempoEstudio(
      asignatura: 'Biología',
      segundos: 75,
    );
    await repositorio.registrarTiempoEstudio(
      asignatura: 'Biología',
      segundos: 40,
    );
    await repositorio.registrarTiempoEstudio(
      asignatura: 'Historia',
      segundos: 20,
    );

    expect(await repositorio.obtenerTiempoEstudio('Biología'), 115);
    expect(await repositorio.obtenerTiempoEstudio('Historia'), 20);
    expect(await repositorio.obtenerTiempoEstudio('Química'), 0);
  });

  test('calcula tiempo y metas solamente para la semana actual', () async {
    final semana = DateTime(2026, 10, 27, 12);
    await repositorio.registrarTiempoEstudio(
      asignatura: 'Biología',
      segundos: 3600,
      fecha: DateTime(2026, 10, 19, 12),
    );
    await repositorio.registrarTiempoEstudio(
      asignatura: 'Biología',
      segundos: 5400,
      fecha: DateTime(2026, 10, 26, 9),
    );
    await repositorio.registrarTiempoEstudio(
      asignatura: 'Biología',
      segundos: 1800,
      fecha: DateTime(2026, 11, 2),
    );
    await repositorio.guardarMetaSemanal(
      asignatura: 'Biología',
      segundos: 7200,
    );

    expect(await repositorio.obtenerTiempoEstudioSemanal(fecha: semana), {
      'Biología': 5400,
    });
    expect(await repositorio.listarMetasSemanales(), {'Biología': 7200});
  });

  test(
    'conserva los segundos de una sesión parcial en el resumen semanal',
    () async {
      const segundosEstudio = 3 * 60 * 60 + 40 * 60;
      await repositorio.registrarTiempoEstudio(
        asignatura: 'Biología',
        segundos: segundosEstudio,
        fecha: DateTime(2026, 10, 27, 12),
      );

      expect(
        await repositorio.obtenerTiempoEstudioSemanal(
          fecha: DateTime(2026, 10, 27),
        ),
        {'Biología': segundosEstudio},
      );
    },
  );
}
