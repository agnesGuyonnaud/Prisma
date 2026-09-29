import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:prisma/data/tareas_repository.dart';
import 'package:prisma/main.dart';
import 'package:prisma/models/tarea_model.dart';
import 'package:prisma/screens/tarea_formulario.dart';
import 'package:prisma/widgets/tarea_mini.dart';

// Simula fallos de almacenamiento para comprobar que no se pierda el formulario.
class _RepositorioPrueba extends TareasRepository {
  bool fallaLectura = false;
  bool fallaEscritura = false;
  final tareas = <Tarea>[];

  @override
  Future<List<Tarea>> listar() async {
    if (fallaLectura) throw StateError('Fallo de prueba');
    return [...tareas];
  }

  @override
  Future<Tarea> guardar(Tarea tarea) async {
    if (fallaEscritura) throw StateError('Fallo de prueba');
    final guardada = tarea.copyWith(id: tareas.length + 1);
    tareas.add(guardada);
    return guardada;
  }
}

Finder campo(String etiqueta) => find.byWidgetPredicate(
  (widget) => widget is TextField && widget.decoration?.labelText == etiqueta,
);

void main() {
  testWidgets(
    'Valida, conserva los datos si falla SQLite y permite reintentar',
    (tester) async {
      final repositorio = _RepositorioPrueba()..fallaEscritura = true;
      await tester.pumpWidget(MainApp(repositorio: repositorio));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Añadir tarea'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Guardar tarea'));
      await tester.pumpAndSettle();
      expect(find.text('Completa este campo'), findsWidgets);
      expect(repositorio.tareas, isEmpty);

      await tester.enterText(campo('Título'), 'Ensayo');
      FocusManager.instance.primaryFocus?.unfocus();
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('asignatura')));
      await tester.pumpAndSettle();
      expect(find.text('Matemáticas').hitTestable(), findsOneWidget);
      expect(find.text('Estructuras de datos').hitTestable(), findsOneWidget);
      expect(find.text('Física').hitTestable(), findsOneWidget);
      await tester.tap(find.text('Matemáticas').last);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Guardar tarea'));
      await tester.pumpAndSettle();
      expect(find.byType(TareaFormulario), findsOneWidget);
      expect(find.textContaining('No se pudo guardar'), findsOneWidget);
      expect(find.text('Ensayo'), findsOneWidget);
      expect(find.text('Matemáticas'), findsOneWidget);

      repositorio.fallaEscritura = false;
      await tester.tap(find.text('Guardar tarea'));
      await tester.pumpAndSettle();
      expect(repositorio.tareas, hasLength(1));
      expect(repositorio.tareas.single.asignatura, 'Matemáticas');
      expect(find.byType(TareaFormulario), findsNothing);
      expect(find.byType(TareaMini), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('Cancelar una tarea nueva no la guarda', (tester) async {
    final repositorio = _RepositorioPrueba();
    await tester.pumpWidget(MainApp(repositorio: repositorio));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Añadir tarea'));
    await tester.pumpAndSettle();
    await tester.enterText(campo('Título'), 'Sin guardar');
    await tester.tap(find.byTooltip('Volver'));
    await tester.pumpAndSettle();
    expect(repositorio.tareas, isEmpty);
    expect(find.byType(TareaMini), findsNothing);
  });

  testWidgets('Un fallo al cargar muestra Reintentar y se recupera', (
    tester,
  ) async {
    final repositorio = _RepositorioPrueba()..fallaLectura = true;
    await tester.pumpWidget(MainApp(repositorio: repositorio));
    await tester.pumpAndSettle();
    expect(find.text('No se pudieron cargar tus tareas.'), findsOneWidget);
    repositorio.fallaLectura = false;
    await tester.tap(find.text('Reintentar'));
    await tester.pumpAndSettle();
    expect(find.textContaining('Aún no tienes tareas'), findsOneWidget);
  });
}
