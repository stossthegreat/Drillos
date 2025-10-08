import 'dart:io';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/timezone.dart' as tz;
import 'package:timezone/data/latest.dart' as tzdata;

import '../services/local_storage.dart';

class AlarmService {
  static final AlarmService _instance = AlarmService._internal();
  factory AlarmService() => _instance;
  AlarmService._internal();

  final FlutterLocalNotificationsPlugin _plugin =
      FlutterLocalNotificationsPlugin();

  bool _initialized = false;

  Future<void> init() async {
    if (_initialized) return;

    // Timezone set-up (safe even if called multiple times)
    tzdata.initializeTimeZones();

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

  /// Ask for notification permissions and (on Android 13+) post-notification permission.
  /// Also checks whether exact alarms are allowed on this device.
  Future<bool> requestPermissions() async {
    await init();

    bool granted = true;

    // iOS permissions
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

    if (Platform.isAndroid) {
      final androidImpl = _plugin.resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin>();

      // Android 13 (Tiramisu) runtime permission for posting notifications
      try {
        await androidImpl?.requestNotificationsPermission();
      } catch (_) {}

      // Are notifications enabled at all?
      final enabled = await androidImpl?.areNotificationsEnabled() ?? true;
      granted = enabled && granted;
    }

    return granted;
  }

  /// Schedule a weekly alarm at [time] (HH:mm) on the given [daysOfWeek] (1=Mon..7=Sun).
  /// Uses exact alarms if permitted; otherwise falls back to inexact to avoid crashes.
  Future<void> scheduleAlarm({
    required String habitId,
    required String habitName,
    required String time,
    List<int> daysOfWeek = const [1, 2, 3, 4, 5, 6, 7],
    String? mentorMessage,
  }) async {
    await init();

    // Parse HH:mm safely
    final parts = time.split(':');
    final hour = int.tryParse(parts.elementAt(0)) ?? 8;
    final minute = int.tryParse(parts.elementAt(1)) ?? 0;

    final message =
        mentorMessage ?? '⚡ Time to complete your habit: $habitName';

    const androidDetails = AndroidNotificationDetails(
      'habit_reminders',
      'Habit Reminders',
      channelDescription: 'Reminders for your daily habits',
      importance: Importance.high,
      priority: Priority.high,
      playSound: true,
      enableVibration: true,
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

    // Decide schedule mode (exact vs inexact)
    AndroidScheduleMode scheduleMode = AndroidScheduleMode.inexactAllowWhileIdle;
    if (Platform.isAndroid) {
      final androidImpl = _plugin.resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin>();
      final canExact =
          (await androidImpl?.canScheduleExactNotifications()) ?? false;
      if (canExact) {
        scheduleMode = AndroidScheduleMode.exactAllowWhileIdle;
      }
    }

    for (final dow in daysOfWeek) {
      final id = _notificationId(habitId, dow);
      final scheduled = _nextInstanceOf(dow, hour, minute);

      try {
        await _plugin.zonedSchedule(
          id,
          '🔥 DrillOS Reminder',
          message,
          scheduled,
          details,
          androidScheduleMode: scheduleMode,
          uiLocalNotificationDateInterpretation:
              UILocalNotificationDateInterpretation.absoluteTime,
          matchDateTimeComponents: DateTimeComponents.dayOfWeekAndTime,
        );
      } on PlatformException catch (e) {
        // Fallback to inexact if exact is not permitted
        if (e.code == 'exact_alarms_not_permitted') {
          await _plugin.zonedSchedule(
            id,
            '🔥 DrillOS Reminder',
            message,
            scheduled,
            details,
            androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
            uiLocalNotificationDateInterpretation:
                UILocalNotificationDateInterpretation.absoluteTime,
            matchDateTimeComponents: DateTimeComponents.dayOfWeekAndTime,
          );
        } else {
          rethrow;
        }
      }
    }

    await localStorage.setAlarmTime(habitId, time);
  }

  Future<void> cancelAlarm(String habitId) async {
    await init();
    for (int dow = 1; dow <= 7; dow++) {
      await _plugin.cancel(_notificationId(habitId, dow));
    }
    await localStorage.removeAlarm(habitId);
  }

  Future<List<PendingNotificationRequest>> getPending() async {
    await init();
    return _plugin.pendingNotificationRequests();
  }

  // ---------- Helpers ----------

  int _notificationId(String habitId, int dow) {
    final base = habitId.hashCode & 0x7fffffff;
    return (base ^ dow) % 0x7fffffff;
  }

  tz.TZDateTime _nextInstanceOf(int dow, int hour, int minute) {
    final now = tz.TZDateTime.now(tz.local);
    var scheduled =
        tz.TZDateTime(tz.local, now.year, now.month, now.day, hour, minute);

    // Move forward until weekday matches and time is in the future
    while (scheduled.weekday != dow || !scheduled.isAfter(now)) {
      scheduled = scheduled.add(const Duration(days: 1));
    }
    return scheduled;
  }
}

final alarmService = AlarmService();
