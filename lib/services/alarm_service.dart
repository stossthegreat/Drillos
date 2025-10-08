import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:android_alarm_manager_plus/android_alarm_manager_plus.dart';
import 'package:timezone/timezone.dart' as tz;
import 'package:timezone/data/latest.dart' as tzdata;

/// 🔔 Real Alarm Service using android_alarm_manager_plus + flutter_local_notifications
class AlarmService {
  static final AlarmService _instance = AlarmService._internal();
  factory AlarmService() => _instance;
  AlarmService._internal();

  final FlutterLocalNotificationsPlugin _notifications =
      FlutterLocalNotificationsPlugin();

  bool _initialized = false;

  Future<void> init() async {
    if (_initialized) return;
    tzdata.initializeTimeZones();

    const androidInit = AndroidInitializationSettings('@mipmap/ic_launcher');
    const initSettings = InitializationSettings(android: androidInit);
    await _notifications.initialize(initSettings);

    await AndroidAlarmManager.initialize();
    _initialized = true;
    debugPrint('✅ AlarmService initialized (real alarm mode)');
  }

  /// Requests POST_NOTIFICATIONS permission on Android 13+
  Future<void> requestPermissions() async {
    try {
      final androidPlugin = _notifications.resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin>();
      await androidPlugin?.requestNotificationsPermission();
    } catch (e) {
      debugPrint('⚠️ Notification permission failed: $e');
    }
  }

  /// Schedule a true alarm
  Future<void> scheduleAlarm({
    required String habitId,
    required String habitName,
    required String time,
    required String mentorMessage,
  }) async {
    await init();

    final parts = time.split(':');
    final hour = int.parse(parts[0]);
    final minute = int.parse(parts[1]);

    final now = DateTime.now();
    var next = DateTime(now.year, now.month, now.day, hour, minute);
    if (next.isBefore(now)) next = next.add(const Duration(days: 1));

    // Register background alarm
    await AndroidAlarmManager.oneShotAt(
      next,
      habitId.hashCode,
      _alarmCallback,
      alarmClock: true, // real OS-level alarm
      allowWhileIdle: true,
      wakeup: true,
      rescheduleOnReboot: true,
      params: {'habitName': habitName, 'mentorMessage': mentorMessage},
    );

    debugPrint('✅ Real alarm scheduled for $time ($habitName)');
  }

  /// The callback runs when the alarm fires (background-safe)
  static Future<void> _alarmCallback(Map<String, dynamic> params) async {
    final plugin = FlutterLocalNotificationsPlugin();
    const androidDetails = AndroidNotificationDetails(
      'habit_alarms',
      'Habit Alarms',
      channelDescription: 'Real alarm notifications',
      importance: Importance.max,
      priority: Priority.high,
      playSound: true,
      enableVibration: true,
      fullScreenIntent: true, // wake up the screen
    );

    final notificationDetails = const NotificationDetails(android: androidDetails);
    await plugin.initialize(const InitializationSettings(
        android: AndroidInitializationSettings('@mipmap/ic_launcher')));

    final habitName = params['habitName'] ?? 'Habit Reminder';
    final message = params['mentorMessage'] ?? 'Time to rise and conquer!';
    await plugin.show(
      DateTime.now().millisecondsSinceEpoch.remainder(100000),
      habitName,
      message,
      notificationDetails,
    );
  }

  Future<void> cancelAlarm(String habitId) async {
    try {
      await AndroidAlarmManager.cancel(habitId.hashCode);
      debugPrint('🗑️ Alarm canceled for $habitId');
    } catch (e) {
      debugPrint('⚠️ Cancel failed: $e');
    }
  }

  Future<void> cancelAll() async {
    try {
      await _notifications.cancelAll();
      debugPrint('🧹 All notifications cleared');
    } catch (e) {
      debugPrint('⚠️ Cancel all failed: $e');
    }
  }
}

final alarmService = AlarmService();
