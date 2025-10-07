import 'dart:io';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/data/latest.dart' as tzdata;
import 'package:timezone/timezone.dart' as tz;
import '../services/local_storage.dart';

/// 🔔 Alarm Service (Flutter Local Notifications v18)
/// - Works offline
/// - iOS permission request handled
/// - Android: uses exactAllowWhileIdle + channel
class AlarmService {
  static final AlarmService _instance = AlarmService._internal();
  factory AlarmService() => _instance;
  AlarmService._internal();

  final FlutterLocalNotificationsPlugin _plugin =
      FlutterLocalNotificationsPlugin();

  bool _initialized = false;

  Future<void> init() async {
    if (_initialized) return;

    // timezones
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

  /// Ask runtime notification permissions where supported.
  /// - iOS handled via plugin
  /// - Android: plugin v18 has no requestPermission; on 13+ you must ask at app level.
  Future<bool> requestPermissions() async {
    await init();

    bool granted = true;

    // iOS
    final ios =
        _plugin.resolvePlatformSpecificImplementation<IOSFlutterLocalNotificationsPlugin>();
    if (ios != null) {
      final res = await ios.requestPermissions(alert: true, badge: true, sound: true);
      granted = (res ?? true) && granted;
    }

    // Android check only (cannot request here on v18)
    if (Platform.isAndroid) {
      final android = _plugin
          .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>();
      if (android != null) {
        final enabled = await android.areNotificationsEnabled();
        granted = (enabled ?? true) && granted;
      }
    }
    return granted;
  }

  /// Schedule repeating alarms for specific weekdays at [time] ("HH:mm").
  Future<void> scheduleAlarm({
    required String habitId,
    required String habitName,
    required String time,
    List<int> daysOfWeek = const [1, 2, 3, 4, 5, 6, 7], // 1=Mon ... 7=Sun
    String? mentorMessage,
  }) async {
    await init();

    final parts = time.split(':');
    final hour = int.tryParse(parts[0]) ?? 8;
    final minute = int.tryParse(parts[1]) ?? 0;
    final body = mentorMessage ?? '⚡ Time to complete your habit: $habitName';

    const androidDetails = AndroidNotificationDetails(
      'habit_reminders',
      'Habit Reminders',
      channelDescription: 'Reminders for your daily habits',
      importance: Importance.high,
      priority: Priority.high,
      playSound: true,
      enableVibration: true,
      category: AndroidNotificationCategory.alarm,
    );

    const iosDetails = DarwinNotificationDetails(
      presentAlert: true,
      presentBadge: true,
      presentSound: true,
    );

    const details = NotificationDetails(android: androidDetails, iOS: iosDetails);

    // schedule one entry per weekday
    for (final dow in daysOfWeek) {
      final id = _notificationId(habitId, dow);
      final next = _nextInstanceOf(dow, hour, minute);

      await _plugin.zonedSchedule(
        id,
        '🔥 DrillOS Reminder',
        body,
        next,
        details,
        androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
        uiLocalNotificationDateInterpretation: UILocalNotificationDateInterpretation.absoluteTime,
        matchDateTimeComponents: DateTimeComponents.dayOfWeekAndTime,
      );
    }

    await localStorage.setAlarmTime(habitId, time);
  }

  /// Cancel all weekly alarms for a habit
  Future<void> cancelAlarm(String habitId) async {
    await init();
    for (int d = 1; d <= 7; d++) {
      await _plugin.cancel(_notificationId(habitId, d));
    }
    await localStorage.removeAlarm(habitId);
  }

  Future<List<PendingNotificationRequest>> getPending() async {
    await init();
    return _plugin.pendingNotificationRequests();
  }

  // ===== helpers =====

  int _notificationId(String habitId, int dow) {
    final base = habitId.hashCode & 0x7fffffff;
    return (base ^ dow) % 0x7fffffff;
  }

  tz.TZDateTime _nextInstanceOf(int dow, int hour, int minute) {
    final now = tz.TZDateTime.now(tz.local);
    var scheduled = tz.TZDateTime(tz.local, now.year, now.month, now.day, hour, minute);

    // move forward to the next matching weekday/time in the future
    while (scheduled.weekday != dow || !scheduled.isAfter(now)) {
      scheduled = scheduled.add(const Duration(days: 1));
    }
    return scheduled;
  }
}

final alarmService = AlarmService();
