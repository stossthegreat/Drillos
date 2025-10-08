import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/timezone.dart' as tz;
import 'package:timezone/data/latest.dart' as tzdata;

class AlarmService {
  static final AlarmService _instance = AlarmService._internal();
  factory AlarmService() => _instance;
  AlarmService._internal();

  final _plugin = FlutterLocalNotificationsPlugin();
  bool _initialized = false;

  Future<void> init() async {
    if (_initialized) return;

    tzdata.initializeTimeZones();

    const androidInit = AndroidInitializationSettings('@mipmap/ic_launcher');
    const initSettings = InitializationSettings(android: androidInit);

    await _plugin.initialize(initSettings);
    _initialized = true;
  }

  Future<void> requestPermissions() async {
    try {
      await _plugin
          .resolvePlatformSpecificImplementation<
              AndroidFlutterLocalNotificationsPlugin>()
          ?.requestPermission();
    } catch (e) {
      debugPrint('⚠️ Alarm permission request failed: $e');
    }
  }

  Future<void> scheduleAlarm({
    required String habitId,
    required String habitName,
    required String time,
    required List<int> daysOfWeek,
    required String mentorMessage,
  }) async {
    await init();

    try {
      final parts = time.split(':');
      final hour = int.parse(parts[0]);
      final minute = int.parse(parts[1]);

      final now = tz.TZDateTime.now(tz.local);
      var next = tz.TZDateTime(tz.local, now.year, now.month, now.day, hour, minute);
      if (next.isBefore(now)) {
        next = next.add(const Duration(days: 1));
      }

      const androidDetails = AndroidNotificationDetails(
        'habit_alarms',
        'Habit Alarms',
        channelDescription: 'Reminds user to complete habits',
        importance: Importance.max,
        priority: Priority.high,
        playSound: true,
      );

      await _plugin.zonedSchedule(
        habitId.hashCode,
        habitName,
        mentorMessage,
        next,
        const NotificationDetails(android: androidDetails),
        androidAllowWhileIdle: true,
        uiLocalNotificationDateInterpretation:
            UILocalNotificationDateInterpretation.absoluteTime,
        matchDateTimeComponents: DateTimeComponents.time,
      );

      debugPrint('✅ Alarm scheduled for $time ($habitName)');
    } catch (e, st) {
      debugPrint('❌ Alarm scheduling failed: $e\n$st');
      rethrow;
    }
  }

  Future<void> cancelAlarm(String habitId) async {
    try {
      await _plugin.cancel(habitId.hashCode);
    } catch (e) {
      debugPrint('⚠️ Cancel failed for $habitId: $e');
    }
  }

  Future<void> cancelAll() async {
    try {
      await _plugin.cancelAll();
    } catch (e) {
      debugPrint('⚠️ Cancel all failed: $e');
    }
  }
}

final alarmService = AlarmService();
