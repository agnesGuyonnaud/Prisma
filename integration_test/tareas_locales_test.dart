import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:path/path.dart' as path;
import 'package:prisma/data/tareas_repository.dart';
import 'package:prisma/main.dart';
import 'package:prisma/models/tarea_model.dart';
import 'package:prisma/screens/tarea.dart';
import 'package:prisma/widgets/tarea_mini.dart';
import 'package:sqflite/sqflite.dart';

Finder campo(String etiqueta) => find.byWidgetPredicate(
  (widget) => widget is TextField && widget.decoration?.labelText == etiqueta,
);

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets(
    'Crear, reabrir, editar, completar y eliminar con SQLite en Android',
    (tester) async {
      // Esta base de prueba es distinta a prisma_tareas.db: no toca datos del usuario.
      final ruta = path.join(
        await getDatabasesPath(),
        'prisma_test_${DateTime.now().microsecondsSinceEpoch}.db',
      );
      var repositorio = TareasRepository(ruta: ruta);
      addTearDown(() async {
        await repositorio.cerrar();
        await deleteDatabase(ruta);
      });
      await tester.pumpWidget(MainApp(repositorio: repositorio));
      await tester.pumpAndSettle();
      expect(find.textContaining('Aún no tienes tareas'), findsOneWidget);
      await tester.tap(find.text('Añadir tarea'));
      await tester.pumpAndSettle();
      await tester.enterText(campo('Título'), 'Proyecto de prueba');
      FocusManager.instance.primaryFocus?.unfocus();
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('asignatura')));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Estructuras de datos').last);
      await tester.pumpAndSettle();

      // Escoge una fecha y una hora usando los controles reales del formulario.
      await tester.tap(find.text('Fecha límite'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Continuar'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Aceptar'));
      await tester.pumpAndSettle();
      await tester.scrollUntilVisible(
        find.text('Añadir subtarea'),
        200,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.tap(find.text('Añadir subtarea'));
      await tester.pumpAndSettle();
      await tester.ensureVisible(campo('Subtarea'));
      await tester.enterText(campo('Subtarea'), 'Revisar requisitos');
      FocusManager.instance.primaryFocus?.unfocus();
      await tester.pumpAndSettle();
      await tester.tap(find.text('Guardar tarea'));
      await tester.pumpAndSettle();
      expect(find.byType(TareaMini), findsOneWidget);
      expect(find.text('Proyecto de prueba'), findsOneWidget);
      final creada = (await repositorio.listar()).single;
      expect(creada.asignatura, 'Estructuras de datos');
      expect(creada.subtareas.single.titulo, 'Revisar requisitos');

      // Recrea la app y la conexión: la tarjeta debe volver desde el archivo SQLite.
      await tester.pumpWidget(const SizedBox.shrink());
      await repositorio.cerrar();
      repositorio = TareasRepository(ruta: ruta);
      await tester.pumpWidget(MainApp(repositorio: repositorio));
      await tester.pumpAndSettle();
      expect(find.text('Proyecto de prueba'), findsOneWidget);
      await tester.tap(find.byType(TareaMini));
      await tester.pumpAndSettle();
      expect(find.byType(TareaScreen), findsOneWidget);
      await tester.ensureVisible(find.byType(CheckboxListTile));
      await tester.tap(find.byType(CheckboxListTile));
      await tester.pumpAndSettle();
      expect((await repositorio.obtener(creada.id!))!.subtareasCompletadas, 1);

      await tester.tap(find.byTooltip('Editar'));
      await tester.pumpAndSettle();
      await tester.enterText(campo('Título'), 'Proyecto editado');
      FocusManager.instance.primaryFocus?.unfocus();
      await tester.pumpAndSettle();
      await tester.tap(find.text('Guardar tarea'));
      await tester.pumpAndSettle();
      expect(find.text('Proyecto editado'), findsOneWidget);
      await tester.ensureVisible(find.text('Pendiente'));
      await tester.tap(find.text('Pendiente'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Completada'));
      await tester.pumpAndSettle();
      expect(
        (await repositorio.obtener(creada.id!))!.estado,
        EstadoTarea.completada,
      );
      await tester.tap(find.byTooltip('Volver'));
      await tester.pumpAndSettle();
      final mini = tester.widget<TareaMini>(find.byType(TareaMini));
      expect(mini.titulo, 'Proyecto editado');
      expect(mini.completada, isTrue);
      expect(mini.subtareasCompletadas, 1);

      await tester.tap(find.byType(TareaMini));
      await tester.pumpAndSettle();
      await tester.tap(find.byTooltip('Más opciones'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Eliminar'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Cancelar'));
      await tester.pumpAndSettle();
      expect(await repositorio.listar(), hasLength(1));
      await tester.tap(find.byTooltip('Más opciones'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Eliminar'));
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(TextButton, 'Eliminar'));
      await tester.pumpAndSettle();
      expect(await repositorio.listar(), isEmpty);
      expect(find.byType(TareaMini), findsNothing);
      expect(tester.takeException(), isNull);
    },
  );
}
