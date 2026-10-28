import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:prisma/models/asignatura_model.dart';
import 'package:prisma/models/meta_estudio_semanal.dart';

void main() {
  final asignatura = Asignatura(nombre: 'Matemáticas', color: Colors.blue);

  test('el progreso semanal nunca supera el 100%', () {
    final meta = MetaEstudioSemanal(
      asignatura: asignatura,
      segundosMeta: 3600,
      segundosEstudiados: 7200,
    );

    expect(meta.progreso, 1);
    expect(meta.porcentaje, 100);
  });

  test('sin una meta configurada el avance es cero', () {
    final meta = MetaEstudioSemanal(
      asignatura: asignatura,
      segundosMeta: null,
      segundosEstudiados: 900,
    );

    expect(meta.progreso, 0);
    expect(meta.porcentaje, 0);
  });
}
