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
  /// Input:
  /// - No recibe parámetros; refleja el permiso exacto disponible.
  /// Output:
  /// - `bool`: `true` si se permiten alarmas exactas.
  /// Resumen:
  /// - Indica si el sistema puede programar avisos Pomodoro a tiempo.
  bool get permiteAlarmasExactas;

  /// Input:
  /// - No recibe parámetros; prepara los servicios y permisos requeridos.
  /// Output:
  /// - `Future<bool>`: indica si están permitidos los avisos.
  /// Resumen:
  /// - Inicializa la plataforma de notificaciones y solicita permisos.
  Future<bool> preparar();

  /// Input:
  /// - No recibe parámetros; solicita el permiso de alarmas exactas.
  /// Output:
  /// - `Future<bool>`: indica si el permiso quedó concedido.
  /// Resumen:
  /// - Pide autorización para programar alarmas exactas en Android.
  Future<bool> solicitarAlarmasExactas();

  /// Input:
  /// - `avisos` (`List<PomodoroAviso>`): avisos que se deben programar.
  /// Output:
  /// - `Future<void>`: termina cuando se solicita su programación.
  /// Resumen:
  /// - Programa la lista de avisos de la sesión Pomodoro.
  Future<void> programar(List<PomodoroAviso> avisos);

  /// Input:
  /// - No recibe parámetros; selecciona avisos propios de Pomodoro.
  /// Output:
  /// - `Future<void>`: termina cuando se han cancelado los avisos.
  /// Resumen:
  /// - Cancela las notificaciones que estén pendientes para Pomodoro.
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

  /// Input:
  /// - No recibe parámetros; consulta la plataforma de ejecución.
  /// Output:
  /// - `bool`: `true` en Android o iOS fuera de web.
  /// Resumen:
  /// - Identifica plataformas compatibles con notificaciones locales.
  bool get _plataformaMovil =>
      !kIsWeb &&
      (defaultTargetPlatform == TargetPlatform.android ||
          defaultTargetPlatform == TargetPlatform.iOS);

  /// Input:
  /// - No recibe parámetros; consulta la plataforma de ejecución.
  /// Output:
  /// - `bool`: `true` cuando se ejecuta en Android y no en web.
  /// Resumen:
  /// - Identifica Android para aplicar sus permisos y modos de alarma.
  bool get _plataformaAndroid =>
      !kIsWeb && defaultTargetPlatform == TargetPlatform.android;

  /// Input:
  /// - No recibe parámetros; combina plataforma y permiso consultado.
  /// Output:
  /// - `bool`: indica si pueden programarse alarmas puntuales.
  /// Resumen:
  /// - Considera exactas todas las alarmas fuera de Android.
  @override
  bool get permiteAlarmasExactas =>
      !_plataformaAndroid || _permisoAlarmasExactas;

  /// Input:
  /// - No recibe parámetros; usa la plataforma y el plugin de notificaciones.
  /// Output:
  /// - `Future<bool>`: indica si el permiso de avisos fue concedido.
  /// Resumen:
  /// - Inicializa el plugin y solicita permisos de notificación y alarmas.
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

  /// Input:
  /// - No recibe parámetros; solicita el permiso de alarmas exactas en Android.
  /// Output:
  /// - `Future<bool>`: indica si Android concedió el permiso.
  /// Resumen:
  /// - Actualiza el estado del permiso de alarmas exactas.
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

  /// Input:
  /// - `avisos` (`List<PomodoroAviso>`): avisos que reemplazarán los pendientes.
  /// Output:
  /// - `Future<void>`: termina al programar y verificar todas las notificaciones.
  /// Resumen:
  /// - Serializa la operación y programa avisos exactos; limpia si falla.
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

  /// Input:
  /// - No recibe parámetros; cancela solo identificadores de avisos Pomodoro.
  /// Output:
  /// - `Future<void>`: termina cuando finaliza la cancelación en cola.
  /// Resumen:
  /// - Encola la cancelación para evitar carreras con la programación.
  @override
  Future<void> cancelar() => _encolar(_cancelarInterno);

  /// Input:
  /// - No recibe parámetros; inspecciona las notificaciones pendientes.
  /// Output:
  /// - `Future<void>`: termina cuando cancela los avisos propios de Pomodoro.
  /// Resumen:
  /// - Inicializa el plugin y elimina sus notificaciones pendientes.
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

  /// Input:
  /// - No recibe parámetros; inicializa el plugin si aún no está listo.
  /// Output:
  /// - `Future<void>`: termina con el plugin preparado para operar.
  /// Resumen:
  /// - Configura zonas horarias e inicializa el plugin una sola vez.
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

  /// Input:
  /// - `operacion` (`Future<void> Function()`): tarea asíncrona que se serializará.
  /// Output:
  /// - `Future<void>`: resultado de la operación, con sus errores preservados.
  /// Resumen:
  /// - Ejecuta operaciones de notificación una por una y permite continuar la cola.
  Future<void> _encolar(Future<void> Function() operacion) {
    final resultado = _operacionEnCola.then((_) => operacion());
    _operacionEnCola = resultado.then<void>(
      (_) {},
      onError: (Object _, StackTrace _) {},
    );
    return resultado;
  }
}
