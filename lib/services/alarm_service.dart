import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/timezone.dart' as tz;
import 'package:timezone/data/latest.dart' as tz;
import '../services/local_storage.dart';

/// 🔔 Alarm Service - Local habit reminders
/// 
/// Handles all alarm scheduling on-device.
/// No backend dependency - alarms fire even offline.
class AlarmService {
  static final AlarmService _instance = AlarmService._internal();
  factory AlarmService() => _instance;
  AlarmService._internal();

  final FlutterLocalNotificationsPlugin _notifications = FlutterLocalNotificationsPlugin();
  bool _initialized = false;

  /// Initialize the alarm service
  Future<void> init() async {
    if (_initialized) return;

    // Initialize timezone
    tz.initializeTimeZones();

    // Initialize notifications
    const androidSettings = AndroidInitializationSettings('@mipmap/ic_launcher');
    const iosSettings = DarwinInitializationSettings(
      requestAlertPermission: true,
      requestBadgePermission: true,
      requestSoundPermission: true,
    );

    const settings = InitializationSettings(
      android: androidSettings,
      iOS: iosSettings,
    );

    await _notifications.initialize(settings);
    _initialized = true;

    print('🔔 Alarm service initialized');
  }

  /// Schedule an alarm for a habit
  /// 
  /// [habitId] - Unique habit ID
  /// [habitName] - Name to show in notification
  /// [time] - Time in "HH:mm" format (e.g. "08:00")
  /// [daysOfWeek] - Days to repeat (1=Monday, 7=Sunday)
  /// [mentorMessage] - Optional custom message from mentor
  Future<void> scheduleAlarm({
    required String habitId,
    required String habitName,
    required String time,
    List<int> daysOfWeek = const [1, 2, 3, 4, 5, 6, 7],
    String? mentorMessage,
  }) async {
    await init();

    // Parse time
    final parts = time.split(':');
    final hour = int.parse(parts[0]);
    final minute = int.parse(parts[1]);

    // Create notification details
    final message = mentorMessage ?? '⚡ Time to complete your habit: $habitName';
    
    const androidDetails = AndroidNotificationDetails(
      'habit_reminders',
      'Habit Reminders',
      channelDescription: 'Reminders for your daily habits',
      importance: Importance.high,
      priority: Priority.high,
      sound: RawResourceAndroidNotificationSound('alarm'),
    );

    const iosDetails = DarwinNotificationDetails(
      sound: 'alarm.wav',
      presentAlert: true,
      presentBadge: true,
      presentSound: true,
    );

    const details = NotificationDetails(
      android: androidDetails,
      iOS: iosDetails,
    );

    // Schedule for each day of week
    for (final day in daysOfWeek) {
      final notificationId = _getNotificationId(habitId, day);
      
      final scheduledDate = _nextInstanceOfDayAndTime(day, hour, minute);

      await _notifications.zonedSchedule(
        notificationId,
        '🔥 DrillOS Reminder',
        message,
        scheduledDate,
        details,
        androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
        uiLocalNotificationDateInterpretation: UILocalNotificationDateInterpretation.absoluteTime,
        matchDateTimeComponents: DateTimeComponents.dayOfWeekAndTime,
      );
    }

    // Store in local storage
    await localStorage.setAlarmTime(habitId, time);

    print('🔔 Alarm scheduled for $habitName at $time on ${daysOfWeek.length} days');
  }

  /// Cancel an alarm for a habit
  Future<void> cancelAlarm(String habitId) async {
    await init();

    // Cancel all day variations (1-7)
    for (int day = 1; day <= 7; day++) {
      final notificationId = _getNotificationId(habitId, day);
      await _notifications.cancel(notificationId);
    }

    // Remove from local storage
    await localStorage.removeAlarm(habitId);

    print('🔕 Alarm cancelled for habit $habitId');
  }

  /// Get all pending alarms
  Future<List<PendingNotificationRequest>> getPendingAlarms() async {
    await init();
    return await _notifications.pendingNotificationRequests();
  }

  /// Request notification permissions (required for iOS)
  Future<bool> requestPermissions() async {
    await init();

    final result = await _notifications
        .resolvePlatformSpecificImplementation<
            IOSFlutterLocalNotificationsPlugin>()
        ?.requestPermissions(
          alert: true,
          badge: true,
          sound: true,
        );

    return result ?? true; // Android doesn't need runtime permission
  }

  // ========== PRIVATE HELPERS ==========

  /// Generate a unique notification ID for habit + day combination
  int _getNotificationId(String habitId, int dayOfWeek) {
    // Use hash code of habitId + day offset to create unique ID
    return (habitId.hashCode + dayOfWeek).abs() % 2147483647;
  }

  /// Get the next instance of a specific day and time
  tz.TZDateTime _nextInstanceOfDayAndTime(int dayOfWeek, int hour, int minute) {
    final now = tz.TZDateTime.now(tz.local);
    var scheduledDate = tz.TZDateTime(tz.local, now.year, now.month, now.day, hour, minute);

    // Find next occurrence of the target day
    while (scheduledDate.weekday != dayOfWeek || scheduledDate.isBefore(now)) {
      scheduledDate = scheduledDate.add(const Duration(days: 1));
    }

    return scheduledDate;
  }
}

final alarmService = AlarmService();

