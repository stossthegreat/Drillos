// lib/services/alarm_service.dart
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/data/latest.dart' as tzdata;
import 'package:timezone/timezone.dart' as tz;

class AlarmService {
  static final AlarmService _instance = AlarmService._internal();
  factory AlarmService() => _instance;
  AlarmService._internal();

  final FlutterLocalNotificationsPlugin _plugin =
      FlutterLocalNotificationsPlugin();

  bool _initialized = false;

  Future<void> init() async {
    if (_initialized) return;

    // Timezones
    try {
      tzdata.initializeTimeZones();
      final String localName = DateTime.now().timeZoneName;
      // Safe fallback – if timezone not resolvable, tz.local is still usable.
      tz.setLocalLocation(tz.getLocation(_safeTz(localName)));
    } catch (_) {
      // ignore – keep tz.local default
    }

    // Init (v18 API – NO requestPermission on Android here)
    const androidInit = AndroidInitializationSettings('@mipmap/ic_launcher');
    const iosInit = DarwinInitializationSettings(
      requestAlertPermission: true,
      requestBadgePermission: true,
      requestSoundPermission: true,
    );

    const initSettings = InitializationSettings(
      android: androidInit,
      iOS: iosInit,
    );

    await _plugin.initialize(initSettings);
    _initialized = true;
  }

  // On Android 13+ POST_NOTIFICATIONS permission is declared in Manifest.
  // We **don’t** call any non-existent requestPermission() on Android (v18).
  Future<bool> requestPermissions() async {
    await init();

    bool granted = true;

    final ios =
        _plugin.resolvePlatformSpecificImplementation<IOSFlutterLocalNotificationsPlugin>();
    if (ios != null) {
      final res = await ios.requestPermissions(
        alert: true,
        badge: true,
        sound: true,
      );
      granted = (res ?? true) && granted;
    }

    // For Android we rely on Manifest + user prompt by system UI.
    return granted;
  }

  /// Schedule a weekly alarm at [time] for each [daysOfWeek] (1=Mon..7=Sun)
  Future<void> scheduleAlarm({
    required String habitId,
    required String habitName,
    required String time,
    List<int> daysOfWeek = const [1, 2, 3, 4, 5, 6, 7],
    String? mentorMessage,
  }) async {
    await init();

    // Defensive parse
    final parts = time.split(':');
    final hour = int.tryParse(parts.elementAt(0)) ?? 8;
    final minute = int.tryParse(parts.elementAt(1)) ?? 0;

    final body = mentorMessage ?? '⏰ $habitName';

    const android = AndroidNotificationDetails(
      'habit_reminders',
      'Habit Reminders',
      channelDescription: 'Reminders for your daily habits',
      importance: Importance.high,
      priority: Priority.high,
      playSound: true,
      enableVibration: true,
    );

    const ios = DarwinNotificationDetails(
      presentAlert: true,
      presentBadge: true,
      presentSound: true,
    );

    const details = NotificationDetails(android: android, iOS: ios);

    // Cancel existing for this habit first (safety)
    await cancelAlarm(habitId);

    for (final dow in daysOfWeek) {
      if (dow < 1 || dow > 7) continue;

      final id = _notificationId(habitId, dow);
      final next = _nextInstanceOf(dow, hour, minute);

      await _plugin.zonedSchedule(
        id,
        'Alarm — $habitName',
        body,
        next,
        details,
        androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle, // v18 OK
        uiLocalNotificationDateInterpretation:
            UILocalNotificationDateInterpretation.absoluteTime,
        matchDateTimeComponents: DateTimeComponents.dayOfWeekAndTime,
      );
    }
  }

  Future<void> cancelAlarm(String habitId) async {
    await init();
    for (int dow = 1; dow <= 7; dow++) {
      final id = _notificationId(habitId, dow);
      try {
        await _plugin.cancel(id);
      } catch (_) {
        // ignore
      }
    }
  }

  Future<List<PendingNotificationRequest>> getPending() async {
    await init();
    return _plugin.pendingNotificationRequests();
  }

  // ===== Helpers =====

  int _notificationId(String habitId, int dow) {
    final base = habitId.hashCode & 0x7fffffff;
    return (base ^ dow) % 0x7fffffff;
  }

  tz.TZDateTime _nextInstanceOf(int dow, int hour, int minute) {
    final now = tz.TZDateTime.now(tz.local);
    tz.TZDateTime scheduled =
        tz.TZDateTime(tz.local, now.year, now.month, now.day, hour, minute);

    // Move forward to correct weekday/time
    while (scheduled.weekday != dow || !scheduled.isAfter(now)) {
      scheduled = scheduled.add(const Duration(days: 1));
    }
    return scheduled;
  }

  String _safeTz(String name) {
    // Best-effort mapping for common device labels to TZ DB names
    // (most devices already return a valid region name)
    switch (name) {
      case 'GMT':
        return 'Etc/GMT';
      default:
        return tz.local.name; // fallback
    }
  }
}

final alarmService = AlarmService();
