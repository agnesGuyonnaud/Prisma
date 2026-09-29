import 'dart:ui' show Size;

import 'package:flutter_test/flutter_test.dart';

import 'package:prisma/main.dart';

void main() {
  testWidgets('La app abre el detalle de tarea en una pantalla móvil', (
    WidgetTester tester,
  ) async {
    tester.view.physicalSize = const Size(360, 640);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(const MainApp());

    expect(find.text('Detalle de tarea'), findsOneWidget);
    expect(find.text('En progreso'), findsOneWidget);
    // La acción destructiva sigue visible incluso en una pantalla corta.
    expect(find.text('Eliminar').hitTestable(), findsOneWidget);
    expect(find.byTooltip('Editar').hitTestable(), findsOneWidget);
    await tester.tap(find.text('Eliminar'));
    await tester.pump();
    expect(
      find.text('Eliminar la tarea estará disponible próximamente.'),
      findsOneWidget,
    );
    expect(tester.takeException(), isNull);
  });
}
