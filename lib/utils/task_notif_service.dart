import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/standalone.dart';
import 'package:timezone/timezone.dart' as tz;
import 'package:timezone/data/latest.dart' as tz;
import 'package:flutter_timezone/flutter_timezone.dart';

import '../data/tareas_repository.dart';
import '../models/tarea_model.dart';
import '../screens/tarea.dart';

void openTarea(int notifId, GlobalKey<NavigatorState> navigatorKey) async {
  final repo = TareasRepository.instancia;
  final t = await repo.obtener(-1 * notifId);
  if (t != null) {
    navigatorKey.currentState?.push(
      MaterialPageRoute(
        builder: (_) => TareaScreen(tarea: t, repositorio: repo),
      ),
    );
  }
}

/// Manages local notifications and handles notification display and routing.
class LocalNotificationService {
  static final FlutterLocalNotificationsPlugin _localNotificationPlugin =
      FlutterLocalNotificationsPlugin();

  /* static final FirebaseMessaging messaging = FirebaseMessaging.instance; */

  static const AndroidNotificationChannel _androidChannel =
      AndroidNotificationChannel(
        'high_importance_channel',
        'High Importance Notifications',
        description: 'This channel is used for important notifications.',
        importance: Importance.high,
      );

  /// Initializes local notification plugin and configures
  /// platform-specific settings.

  static Future<void> initLocalNotification(
    GlobalKey<NavigatorState> navigatorKey,
  ) async {
    tz.initializeTimeZones();
    final TimezoneInfo info = await FlutterTimezone.getLocalTimezone();
    tz.setLocalLocation(tz.getLocation(info.identifier));
    /* await _requestNotificationPermission(); */

    const androidSettings = AndroidInitializationSettings(
      '@mipmap/ic_launcher',
    );

    const settings = InitializationSettings(android: androidSettings);

    await _localNotificationPlugin.initialize(
      settings: settings,
      onDidReceiveNotificationResponse: (response) async {
        if (response.id != null && response.id! < 0) {
          openTarea(response.id!, navigatorKey);
        }
      },
    );

    await _localNotificationPlugin
        .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin
        >()
        ?.createNotificationChannel(_androidChannel);
  }

  static Future<void> plan({
    required int id,
    String? title,
    String? body,
    required TZDateTime scheduledNotifDate,
  }) async {
    final titleText = (title != null) ? title : "No title";

    final bodyText = (body != null) ? body : "No body";

    final bigTextStyleInfo = BigTextStyleInformation(
      bodyText,
      contentTitle: titleText,
      htmlFormatBigText: true,
      htmlFormatContentTitle: true,
    );

    final androidDetails = AndroidNotificationDetails(
      _androidChannel.id,
      _androidChannel.name,
      channelDescription: _androidChannel.description,
      importance: Importance.max,
      priority: Priority.high,
      playSound: true,
      styleInformation: bigTextStyleInfo,
    );
    await _localNotificationPlugin.cancel(id: id);

    await _localNotificationPlugin.zonedSchedule(
      id: id,
      scheduledDate: scheduledNotifDate,
      notificationDetails: NotificationDetails(android: androidDetails),
      androidScheduleMode: AndroidScheduleMode.inexact,
    );
  }

  static Future<void> cancel({required int id}) async {
    await _localNotificationPlugin.cancel(id: id);
  }

  static Future<void> show({int id = 0, String? title, String? body}) async {
    final titleText = (title != null) ? title : "No title";

    final bodyText = (body != null) ? body : "No body";

    final notificationId = id;

    final bigTextStyleInfo = BigTextStyleInformation(
      bodyText,
      contentTitle: titleText,
      htmlFormatBigText: true,
      htmlFormatContentTitle: true,
    );

    final androidDetails = AndroidNotificationDetails(
      _androidChannel.id,
      _androidChannel.name,
      channelDescription: _androidChannel.description,
      importance: Importance.max,
      priority: Priority.high,
      playSound: true,
      styleInformation: bigTextStyleInfo,
    );

    final notificationDetails = NotificationDetails(
      android: androidDetails,
      /* iOS: iosDetails, */
    );

    try {
      await _localNotificationPlugin.show(
        id: notificationId,
        title: titleText,
        body: bodyText,
        notificationDetails: notificationDetails,
      );
    } catch (e) {
      debugPrint('Local notification error: $e');
    }
  }

  static Future<({bool notifLaunch, int? notifId})> checkNotifLaunch() async {
    final details = await _localNotificationPlugin
        .getNotificationAppLaunchDetails();

    if (details != null && details.didNotificationLaunchApp) {
      return (notifLaunch: true, notifId: details.notificationResponse?.id);
    } else {
      return (notifLaunch: false, notifId: null);
    }
  }
}
