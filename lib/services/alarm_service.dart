import 'dart:io';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/timezone.dart' as tz;
import 'package:timezone/data/latest.dart' as tzdata;

import '../services/local_storage.dart';

/// 🔔 Alarm Service (v18-compatible)
/// - No Android runtime requestPermission (not available in 18.x)
/// - iOS permission request supported
/// - Uses TZ scheduling for day-of-week + time
class AlarmService {
  static final AlarmService _instance = AlarmService._internal();
  factory AlarmService() => _instance;
  AlarmService._internal();

  final FlutterLocalNotificationsPlugin _plugin =
      FlutterLocalNotificationsPlugin();

  bool _initialized = false;

  /// Call once on app start
  Future<void> init() async {
    if (_initialized) return;

    // time zones
    tzdata.initializeTimeZones();

    // init platforms
    const androidInit = AndroidInitializationSettings('@mipmap/ic_launcher');
    const iosInit = DarwinInitializationSettings(
      requestAlertPermission: true,
      requestBadgePermission: true,
      requestSoundPermission: true,
    );

    const settings = InitializationSettings(
      android: androidInit,
      iOS: iosInit,
    );

    await _plugin.initialize(settings);
    _initialized = true;
  }

  /// Request notification permissions where supported.
  /// - iOS: asks the user
  /// - Android: just checks if notifications are enabled (no runtime ask in 18.x)
  Future<bool> requestPermissions() async {
    await init();

    bool granted = true;

    // iOS permission prompt
    final ios = _plugin.resolvePlatformSpecificImplementation<
        IOSFlutterLocalNotificationsPlugin>();
    if (ios != null) {
      final result = await ios.requestPermissions(
        alert: true,
        badge: true,
        sound: true,
      );
      granted = (result ?? true) && granted;
    }

    // Android: check current state (no request API in 18.x)
    if (Platform.isAndroid) {
      final androidImpl = _plugin.resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin>();
      if (androidImpl != null) {
        final enabled = await androidImpl.areNotificationsEnabled();
        // If `enabled` is null, default to true (older devices)
        granted = (enabled ?? true) && granted;
      }
    }

    return granted;
  }

  /// Schedules weekly repeating alarms for [daysOfWeek] at [time] (HH:mm).
  /// [mentorMessage] optional custom message.
  Future<void> scheduleAlarm({
    required String habitId,
    required String habitName,
    required String time,
    List<int> daysOfWeek = const [1, 2, 3, 4, 5, 6, 7], // 1=Mon .. 7=Sun
    String? mentorMessage,
  }) async {
    await init();

    // Parse HH:mm safely
    final parts = time.split(':');
    final hour = int.tryParse(parts.elementAt(0)) ?? 8;
    final minute = int.tryParse(parts.length > 1 ? parts[1] : '0') ?? 0;

    final message =
        mentorMessage ?? '⚡ Time to complete your habit: $habitName';

    // Keep channel simple and universal so no missing resources crash build
    const androidDetails = AndroidNotificationDetails(
      'habit_reminders',
      'Habit Reminders',
      channelDescription: 'Reminders for your daily habits',
      importance: Importance.high,
      priority: Priority.high,
      playSound: true,
      enableVibration: true,
      // ⛔️ Don’t set RawResourceAndroidNotificationSound without a real res/raw file
    );

    const iosDetails = DarwinNotificationDetails(
      presentAlert: true,
      presentBadge: true,
      presentSound: true,
    );

    const details = NotificationDetails(
      android: androidDetails,
      iOS: iosDetails,
    );

    // Schedule one per selected weekday
    for (final dow in daysOfWeek) {
      final id = _notificationId(habitId, dow);
      final scheduled = _nextInstanceOf(dow, hour, minute);

      await _plugin.zonedSchedule(
        id,
        '🔥 DrillOS Reminder',
        message,
        scheduled,
        details,
        androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
        uiLocalNotificationDateInterpretation:
            UILocalNotificationDateInterpretation.absoluteTime,
        matchDateTimeComponents: DateTimeComponents.dayOfWeekAndTime,
      );
    }

    // Save chosen time locally (used by your UI)
    await localStorage.setAlarmTime(habitId, time);
  }

  /// Cancels all alarms linked to [habitId]
  Future<void> cancelAlarm(String habitId) async {
    await init();
    for (int dow = 1; dow <= 7; dow++) {
      await _plugin.cancel(_notificationId(habitId, dow));
    }
    await localStorage.removeAlarm(habitId);
  }

  /// Handy for debugging
  Future<List<PendingNotificationRequest>> getPending() async {
    await init();
    return _plugin.pendingNotificationRequests();
  }

  // ===== Helpers =====

  int _notificationId(String habitId, int dow) {
    final base = habitId.hashCode & 0x7fffffff;
    return (base ^ dow) % 0x7fffffff;
  }

  /// Next occurrence of [dow] (1=Mon..7=Sun) at [hour]:[minute]
  tz.TZDateTime _nextInstanceOf(int dow, int hour, int minute) {
    final now = tz.TZDateTime.now(tz.local);
    var scheduled =
        tz.TZDateTime(tz.local, now.year, now.month, now.day, hour, minute);

    // advance to the correct weekday in the future
    while (scheduled.weekday != dow || !scheduled.isAfter(now)) {
      scheduled = scheduled.add(const Duration(days: 1));
    }
    return scheduled;
  }
}

final alarmService = AlarmService();
