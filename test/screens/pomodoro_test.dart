import 'package:prisma/data/pomodoro_notifications.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:prisma/data/tareas_repository.dart';
import 'package:prisma/models/asignatura_model.dart';
import 'package:prisma/models/tarea_model.dart';
import 'package:prisma/screens/pomodoro.dart';
import 'package:prisma/utils/navegacion_principal.dart';

void main() {
  testWidgets('registra estudio activo y reiniciar conserva lo registrado', (
    tester,
  ) async {
    final repositorio = _RepositorioEnMemoria();
    final notificaciones = _NotificacionesFalsas();
    await tester.pumpWidget(
      MaterialApp(
        home: PomodoroScreen(
          repositorio: repositorio,
          notificaciones: notificaciones,
          reloj: tester.binding.clock.now,
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byType(DropdownButtonFormField<String>));
    await tester.pump(const Duration(milliseconds: 500));
    await tester.tap(find.text('Física').last);
    await tester.pump(const Duration(milliseconds: 500));
    await tester.tap(find.byIcon(Icons.play_arrow));
    await tester.pump();
    await tester.pump(const Duration(seconds: 220));
    await tester.tap(find.byIcon(Icons.pause));
    await tester.pump();

    expect(repositorio.segundosEstudio['Física'], 220);
    expect(find.text('Tiempo de estudio pendiente de guardar'), findsNothing);
    expect(notificaciones.avisos, isEmpty);
    expect(notificaciones.programaciones, 1);

    await tester.tap(find.byTooltip('Reiniciar Pomodoro'));
    await tester.pump(const Duration(milliseconds: 500));

    expect(repositorio.segundosEstudio['Física'], 220);
    expect(find.text('25:00'), findsOneWidget);
  });

  testWidgets('conserva el contador al cambiar de vista', (tester) async {
    final repositorio = _RepositorioEnMemoria();
    final notificaciones = _NotificacionesFalsas();
    var ahora = DateTime(2026, 10, 27);
    await tester.pumpWidget(
      MaterialApp(
        initialRoute: rutaPomodoro,
        routes: {
          rutaPomodoro: (_) => PomodoroScreen(
            repositorio: repositorio,
            notificaciones: notificaciones,
            reloj: () => ahora,
          ),
        },
      ),
    );
    await tester.pump();

    await tester.tap(find.byType(DropdownButtonFormField<String>));
    await tester.pump(const Duration(milliseconds: 500));
    await tester.tap(find.text('Física').last);
    await tester.pump(const Duration(milliseconds: 500));
    await tester.tap(find.byIcon(Icons.play_arrow));
    await tester.pump();

    ahora = ahora.add(const Duration(seconds: 30));
    await tester.pump(const Duration(seconds: 30));
    await tester.tap(find.text('Matriz'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Pomodoro'));
    await tester.pumpAndSettle();

    expect(find.text('24:30'), findsOneWidget);
    expect(find.byType(PomodoroScreen), findsOneWidget);
  });

  testWidgets('al apagar la pantalla el Pomodoro sigue avanzando', (
    tester,
  ) async {
    final repositorio = _RepositorioEnMemoria();
    final notificaciones = _NotificacionesFalsas();
    var ahora = DateTime(2026, 10, 27);
    await tester.pumpWidget(
      MaterialApp(
        home: PomodoroScreen(
          repositorio: repositorio,
          notificaciones: notificaciones,
          reloj: () => ahora,
        ),
      ),
    );
    await tester.pump();

    await tester.tap(find.byType(DropdownButtonFormField<String>));
    await tester.pump(const Duration(milliseconds: 500));
    await tester.tap(find.text('Física').last);
    await tester.pump(const Duration(milliseconds: 500));
    await tester.tap(find.byIcon(Icons.play_arrow));
    await tester.pump();

    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
    ahora = ahora.add(const Duration(minutes: 27));
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await tester.pump(const Duration(seconds: 1));

    expect(find.text('Descanso'), findsOneWidget);
    expect(find.text('03:00'), findsOneWidget);
    expect(repositorio.segundosEstudio['Física'], 25 * 60);
    expect(notificaciones.avisos, hasLength(60));
    expect(notificaciones.programaciones, 2);
  });
}

class _NotificacionesFalsas implements PomodoroNotificaciones {
  List<PomodoroAviso> avisos = [];
  int programaciones = 0;

  @override
  bool get permiteAlarmasExactas => true;

  @override
  Future<bool> preparar() async => true;

  @override
  Future<bool> solicitarAlarmasExactas() async => true;

  @override
  Future<void> programar(List<PomodoroAviso> avisos) async {
    programaciones++;
    this.avisos = avisos;
  }

  @override
  Future<void> cancelar() async {
    avisos = [];
  }
}

class _RepositorioEnMemoria extends TareasRepository {
  final Map<String, int> segundosEstudio = {};

  @override
  Future<List<Asignatura>> listarAsignaturas() async => [
    Asignatura(nombre: 'Física', color: Colors.orange),
  ];

  @override
  Future<List<Tarea>> listar() async => [];

  @override
  Future<void> registrarTiempoEstudio({
    required String asignatura,
    required int segundos,
    DateTime? fecha,
  }) async {
    segundosEstudio.update(
      asignatura,
      (total) => total + segundos,
      ifAbsent: () => segundos,
    );
  }
}
