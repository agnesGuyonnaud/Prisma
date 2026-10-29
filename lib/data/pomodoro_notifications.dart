import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/data/latest.dart' as timezone_data;
import 'package:timezone/timezone.dart' as timezone;

class PomodoroAviso {
  const PomodoroAviso({
    required this.fecha,
    required this.titulo,
    required this.mensaje,
  });

  final DateTime fecha;
  final String titulo;
  final String mensaje;
}

abstract class PomodoroNotificaciones {
  bool get permiteAlarmasExactas;

  Future<bool> preparar();

  Future<bool> solicitarAlarmasExactas();

  Future<void> programar(List<PomodoroAviso> avisos);

  Future<void> cancelar();
}

class NotificacionesLocalesPomodoro implements PomodoroNotificaciones {
  NotificacionesLocalesPomodoro._();

  static final instancia = NotificacionesLocalesPomodoro._();

  static const _cantidadAvisos = 60;
  static const _idBase = 5100;
  static const _canalId = 'pomodoro_fases';
  static const _canalNombre = 'Temporizador Pomodoro';

  final FlutterLocalNotificationsPlugin _plugin =
      FlutterLocalNotificationsPlugin();
  Future<void> _operacionEnCola = Future<void>.value();
  bool _inicializado = false;
  bool _permisoAlarmasExactas = false;

  bool get _plataformaMovil =>
      !kIsWeb &&
      (defaultTargetPlatform == TargetPlatform.android ||
          defaultTargetPlatform == TargetPlatform.iOS);

  bool get _plataformaAndroid =>
      !kIsWeb && defaultTargetPlatform == TargetPlatform.android;

  @override
  bool get permiteAlarmasExactas =>
      !_plataformaAndroid || _permisoAlarmasExactas;

  @override
  Future<bool> preparar() async {
    if (!_plataformaMovil) return false;

    await _inicializar();

    if (defaultTargetPlatform == TargetPlatform.android) {
      final android = _plugin
          .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin
          >();
      final permisoAvisos =
          await android?.requestNotificationsPermission() ?? false;
      _permisoAlarmasExactas =
          await android?.canScheduleExactNotifications() ?? false;
      if (!_permisoAlarmasExactas) {
        _permisoAlarmasExactas =
            await android?.requestExactAlarmsPermission() ?? false;
      }
      return permisoAvisos;
    }

    final ios = _plugin
        .resolvePlatformSpecificImplementation<
          IOSFlutterLocalNotificationsPlugin
        >();
    return await ios?.requestPermissions(
          alert: true,
          badge: true,
          sound: true,
        ) ??
        false;
  }

  @override
  Future<bool> solicitarAlarmasExactas() async {
    if (defaultTargetPlatform != TargetPlatform.android) return true;
    final android = _plugin
        .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin
        >();
    _permisoAlarmasExactas =
        await android?.requestExactAlarmsPermission() ?? false;
    return _permisoAlarmasExactas;
  }

  @override
  Future<void> programar(List<PomodoroAviso> avisos) {
    return _encolar(() async {
      if (!_plataformaMovil) return;
      await _cancelarInterno();
      if (_plataformaAndroid && !_permisoAlarmasExactas) {
        throw StateError(
          'Android no concedió el permiso para programar alarmas exactas.',
        );
      }

      try {
        for (var index = 0; index < avisos.length; index++) {
          final aviso = avisos[index];
          await _plugin.zonedSchedule(
            id: _idBase + index,
            title: aviso.titulo,
            body: aviso.mensaje,
            scheduledDate: timezone.TZDateTime.from(
              aviso.fecha.toUtc(),
              timezone.UTC,
            ),
            notificationDetails: const NotificationDetails(
              android: AndroidNotificationDetails(
                _canalId,
                _canalNombre,
                channelDescription: 'Avisos al terminar cada fase Pomodoro.',
                importance: Importance.max,
                priority: Priority.high,
                playSound: true,
              ),
              iOS: DarwinNotificationDetails(
                presentAlert: true,
                presentSound: true,
              ),
            ),
            androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
          );
        }
        final programados = await _plugin.pendingNotificationRequests();
        final idsProgramados = programados.map((aviso) => aviso.id).toSet();
        final cantidadProgramada = avisos
            .asMap()
            .keys
            .where((index) => idsProgramados.contains(_idBase + index))
            .length;
        if (cantidadProgramada < avisos.length) {
          throw StateError(
            'Android solo confirmó $cantidadProgramada de '
            '${avisos.length} avisos Pomodoro.',
          );
        }
      } catch (_) {
        await _cancelarInterno();
        rethrow;
      }
    });
  }

  @override
  Future<void> cancelar() => _encolar(_cancelarInterno);

  Future<void> _cancelarInterno() async {
    if (!_plataformaMovil) return;
    await _inicializar();
    final pendientes = await _plugin.pendingNotificationRequests();
    for (final aviso in pendientes) {
      if (aviso.id >= _idBase && aviso.id < _idBase + _cantidadAvisos) {
        await _plugin.cancel(id: aviso.id);
      }
    }
  }

  Future<void> _inicializar() async {
    if (_inicializado) return;
    timezone_data.initializeTimeZones();
    await _plugin.initialize(
      settings: const InitializationSettings(
        android: AndroidInitializationSettings('@mipmap/ic_launcher'),
        iOS: DarwinInitializationSettings(
          requestAlertPermission: false,
          requestBadgePermission: false,
          requestSoundPermission: false,
        ),
      ),
    );
    _inicializado = true;
  }

  Future<void> _encolar(Future<void> Function() operacion) {
    final resultado = _operacionEnCola.then((_) => operacion());
    _operacionEnCola = resultado.then<void>(
      (_) {},
      onError: (Object _, StackTrace _) {},
    );
    return resultado;
  }
}
