import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/timezone.dart' as tz;
import 'package:timezone/data/latest.dart' as tzdata;

/// 🔔 Alarm Service (Flutter Local Notifications v18 compatible)
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
    debugPrint('✅ AlarmService initialized');
  }

  /// Request notification permission (Android 13+ safe)
  Future<void> requestPermissions() async {
    try {
      final androidPlugin = _plugin.resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin>();

      if (androidPlugin != null) {
        await androidPlugin.requestNotificationsPermission();
        debugPrint('✅ Notification permission requested');
      }
    } catch (e) {
      debugPrint('⚠️ Permission request failed: $e');
    }
  }

  /// Schedule an alarm notification
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
      debugPrint('🗑️ Alarm canceled for $habitId');
    } catch (e) {
      debugPrint('⚠️ Cancel failed: $e');
    }
  }

  Future<void> cancelAll() async {
    try {
      await _plugin.cancelAll();
      debugPrint('🧹 All alarms canceled');
    } catch (e) {
      debugPrint('⚠️ Cancel all failed: $e');
    }
  }
}

final alarmService = AlarmService();
