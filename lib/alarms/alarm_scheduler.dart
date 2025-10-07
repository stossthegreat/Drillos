import 'dart:math';
import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/data/latest_all.dart' as tzdata;
import 'package:timezone/timezone.dart' as tz;
import 'package:audioplayers/audioplayers.dart';
import 'alarm_cache.dart';

class AlarmScheduler {
  static final AlarmScheduler _singleton = AlarmScheduler._internal();
  factory AlarmScheduler() => _singleton;
  AlarmScheduler._internal();

  final _plugin = FlutterLocalNotificationsPlugin();
  bool _inited = false;

  Future<void> init() async {
    if (_inited) return;

    // tz
    tzdata.initializeTimeZones();
    final local = tz.local; // forces init

    const androidInit = AndroidInitializationSettings('@mipmap/ic_launcher');
    const iosInit = DarwinInitializationSettings(
      requestAlertPermission: true,
      requestBadgePermission: true,
      requestSoundPermission: true,
    );
    const initSettings = InitializationSettings(android: androidInit, iOS: iosInit);

    await _plugin.initialize(
      initSettings,
      onDidReceiveNotificationResponse: (resp) async {
        // When user taps the notification, play the mentor voice from assets
        final payload = resp.payload;
        if (payload == null) return;
        // payload format: assetPath|title
        final parts = payload.split('|');
        final asset = parts.isNotEmpty ? parts[0] : '';
        try {
          if (asset.isNotEmpty) {
            final p = AudioPlayer();
            await p.play(AssetSource(asset));
          }
        } catch (_) {}
      },
    );

    // Ask Android 13+ permission if needed
    await _plugin
        .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>()
        ?.requestNotificationsPermission();

    _inited = true;
    if (kDebugMode) print('🔔 AlarmScheduler initialized (tz=${local.name})');
  }

  /// Reschedule all enabled alarms from cache
  Future<void> rescheduleAll() async {
    await init();
    final alarms = await AlarmCache.loadAll();
    // clear existing
    await _plugin.cancelAll();
    for (final a in alarms) {
      if (a.enabled) {
        await scheduleAlarm(a);
      }
    }
  }

  /// Schedule an alarm weekly for its selected weekdays
  Future<void> scheduleAlarm(AlarmModel alarm) async {
    await init();
    final timeParts = alarm.time.split(':');
    final hour = int.parse(timeParts[0]);
    final minute = int.parse(timeParts[1]);

    for (final weekday in alarm.daysOfWeek) {
      final id = _notificationIdFor(alarm.id, weekday);
      final next = _nextInstanceOfWeekday(hour, minute, weekday);
      final details = _notifDetails();

      await _plugin.zonedSchedule(
        id,
        alarm.title,
        'Tap to hear your mentor',
        next,
        details,
        androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
        uiLocalNotificationDateInterpretation:
            UILocalNotificationDateInterpretation.absoluteTime,
        matchDateTimeComponents: DateTimeComponents.dayOfWeekAndTime,
        payload: '${alarm.voiceAssetPath}|${alarm.title}',
      );
    }
  }

  Future<void> cancelAlarm(AlarmModel alarm) async {
    await init();
    for (final weekday in alarm.daysOfWeek) {
      await _plugin.cancel(_notificationIdFor(alarm.id, weekday));
    }
  }

  AndroidNotificationDetails _androidDetails() {
    return const AndroidNotificationDetails(
      'drillos_alarms',
      'DrillOS Alarms',
      channelDescription: 'User-selected mentor alarms',
      importance: Importance.max,
      priority: Priority.high,
      playSound: true, // default notification sound; voice plays on tap
      enableVibration: true,
      visibility: NotificationVisibility.public,
      category: AndroidNotificationCategory.alarm,
      fullScreenIntent: true,
    );
  }

  NotificationDetails _notifDetails() {
    return NotificationDetails(
      android: _androidDetails(),
      iOS: const DarwinNotificationDetails(
        presentSound: true,
        presentAlert: true,
        presentBadge: false,
      ),
    );
  }

  int _notificationIdFor(String alarmId, int weekday) {
    // stable deterministic int from alarmId + weekday
    final h = alarmId.hashCode ^ (weekday * 131);
    return (h & 0x7fffffff) % 100000000; // keep it in safe int range
    // (no collisions for practical purposes)
  }

  tz.TZDateTime _nextInstanceOfWeekday(int hour, int minute, int weekday) {
    final now = tz.TZDateTime.now(tz.local);
    var scheduled = tz.TZDateTime(tz.local, now.year, now.month, now.day, hour, minute);
    while (scheduled.weekday != weekday) {
      scheduled = scheduled.add(const Duration(days: 1));
    }
    if (!scheduled.isAfter(now)) {
      scheduled = scheduled.add(const Duration(days: 7));
    }
    return scheduled;
  }
}

final alarmScheduler = AlarmScheduler();
