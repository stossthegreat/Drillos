import 'dart:io';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/timezone.dart' as tz;
import 'package:timezone/data/latest.dart' as tzdata;
import '../services/local_storage.dart';

/// 🔔 Alarm Service - Local (front-end only) habit reminders
/// Works offline. No backend dependency.
class AlarmService {
  static final AlarmService _instance = AlarmService._internal();
  factory AlarmService() => _instance;
  AlarmService._internal();

  final FlutterLocalNotificationsPlugin _plugin =
      FlutterLocalNotificationsPlugin();

  bool _initialized = false;

  Future<void> init() async {
    if (_initialized) return;

    // Timezone DB
    tzdata.initializeTimeZones();

    // Android init
    const androidInit = AndroidInitializationSettings('@mipmap/ic_launcher');

    // iOS init
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

  /// Request permissions (iOS + Android 13+)
  Future<bool> requestPermissions() async {
    await init();

    bool granted = true;

    // iOS
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

    // Android 13+ runtime permission
    if (Platform.isAndroid) {
      final androidImpl = _plugin
          .resolvePlatformSpecificImplementation<
              AndroidFlutterLocalNotificationsPlugin>();
      if (androidImpl != null) {
        final res = await androidImpl.areNotificationsEnabled();
        if (res == false) {
          // Try to request (will no-op on older versions)
          await androidImpl.requestPermission();
          final after = await androidImpl.areNotificationsEnabled();
          granted = after && granted;
        }
      }
    }
    return granted;
  }

  /// Schedule a repeating alarm for specific weekdays at a time.
  ///
  /// [habitId] is used to make unique notification IDs.
  /// [time] format: "HH:mm" (24h)
  /// [daysOfWeek]: 1..7 (Mon..Sun)
  Future<void> scheduleAlarm({
    required String habitId,
    required String habitName,
    required String time,
    List<int> daysOfWeek = const [1, 2, 3, 4, 5, 6, 7],
    String? mentorMessage,
  }) async {
    await init();

    final parts = time.split(':');
    final hour = int.tryParse(parts[0]) ?? 8;
    final minute = int.tryParse(parts[1]) ?? 0;

    final message = mentorMessage ??
        '⚡ Time to complete your habit: $habitName';

    // Android channel + details (default sound to avoid missing resource issues)
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

    // Save for reference
    await localStorage.setAlarmTime(habitId, time);
    // (You can also save mentor voice choice here later)
  }

  /// Cancel all weekday notifications for this habit ID.
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

  // --- helpers ---

  int _notificationId(String habitId, int dow) {
    // stable unique ID per habit+day
    final base = habitId.hashCode & 0x7fffffff; // positive
    return (base ^ dow) % 0x7fffffff;
  }

  tz.TZDateTime _nextInstanceOf(int dow, int hour, int minute) {
    final now = tz.TZDateTime.now(tz.local);
    var scheduled =
        tz.TZDateTime(tz.local, now.year, now.month, now.day, hour, minute);

    // step forward to the requested weekday
    while (scheduled.weekday != dow || !scheduled.isAfter(now)) {
      scheduled = scheduled.add(const Duration(days: 1));
    }
    return scheduled;
  }
}

final alarmService = AlarmService();
