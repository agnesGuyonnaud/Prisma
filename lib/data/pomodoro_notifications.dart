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
  bool _inicializado = false;
  bool _permisoAlarmasExactas = false;

  bool get _plataformaMovil =>
      !kIsWeb &&
      (defaultTargetPlatform == TargetPlatform.android ||
          defaultTargetPlatform == TargetPlatform.iOS);

  @override
  bool get permiteAlarmasExactas => _permisoAlarmasExactas;

  @override
  Future<bool> preparar() async {
    if (!_plataformaMovil) return false;

    if (!_inicializado) {
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
  Future<void> programar(List<PomodoroAviso> avisos) async {
    if (!_plataformaMovil) return;
    await cancelar();
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
        androidScheduleMode: _permisoAlarmasExactas
            ? AndroidScheduleMode.exactAllowWhileIdle
            : AndroidScheduleMode.inexactAllowWhileIdle,
      );
    }
    final programados = await _plugin.pendingNotificationRequests();
    if (programados.length < avisos.length) {
      throw StateError(
        'Android solo confirmó ${programados.length} de '
        '${avisos.length} avisos Pomodoro.',
      );
    }
  }

  @override
  Future<void> cancelar() async {
    if (!_plataformaMovil || !_inicializado) return;
    for (var index = 0; index < _cantidadAvisos; index++) {
      await _plugin.cancel(id: _idBase + index);
    }
  }
}
