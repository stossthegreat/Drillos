// lib/services/alarm_service.dart
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'dart:convert';
import 'package:android_alarm_manager_plus/android_alarm_manager_plus.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:shared_preferences/shared_preferences.dart';
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

    final String body = mentorMessage ?? '⏰ $habitName';

    // Cancel existing for this habit first (safety)
    await cancelAlarm(habitId);

    // Persist payloads for background callback to read
    final SharedPreferences prefs = await SharedPreferences.getInstance();

    for (final int dow in daysOfWeek) {
      if (dow < 1 || dow > 7) continue;

      final int id = _notificationId(habitId, dow);
      final DateTime next = _nextInstanceOfDateTime(dow, hour, minute);

      // Store payload for callback
      await prefs.setString('alarm:payload:$id',
          '{"title":"Alarm — $habitName","body":"${_escapeJson(body)}"}');

      // Schedule exact alarm via AndroidAlarmManager
      // Note: This will fire once at the next occurrence; UI can reschedule as needed.
      await AndroidAlarmManager.oneShotAt(
        next,
        id,
        alarmManagerCallback,
        exact: true,
        wakeup: true,
        rescheduleOnReboot: true,
        allowWhileIdle: true,
      );
    }
  }

  Future<void> cancelAlarm(String habitId) async {
    await init();
    for (int dow = 1; dow <= 7; dow++) {
      final int id = _notificationId(habitId, dow);
      try {
        // Cancel any scheduled alarm
        await AndroidAlarmManager.cancel(id);
      } catch (_) {}
      try {
        // Also cancel any pending local notification with same id
        await _plugin.cancel(id);
      } catch (_) {}
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
    while (scheduled.weekday != dow || !scheduled.isAfter(now)) {
      scheduled = scheduled.add(const Duration(days: 1));
    }
    return scheduled;
  }

  DateTime _nextInstanceOfDateTime(int dow, int hour, int minute) {
    final DateTime now = DateTime.now();
    DateTime scheduled = DateTime(now.year, now.month, now.day, hour, minute);
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

// ===== AndroidAlarmManager background callback =====

@pragma('vm:entry-point')
Future<void> alarmManagerCallback(int id) async {
  // Ensure bindings and plugin registrant are available in background isolate
  WidgetsFlutterBinding.ensureInitialized();

  final FlutterLocalNotificationsPlugin plugin = FlutterLocalNotificationsPlugin();

  const InitializationSettings initSettings = InitializationSettings(
    android: AndroidInitializationSettings('@mipmap/ic_launcher'),
    iOS: DarwinInitializationSettings(),
  );

  try {
    await plugin.initialize(initSettings);
  } catch (_) {}

  final SharedPreferences prefs = await SharedPreferences.getInstance();
  final String? raw = prefs.getString('alarm:payload:$id');

  String title = 'Alarm';
  String body = 'It\'s time!';
  if (raw != null && raw.isNotEmpty) {
    try {
      final Map<String, dynamic> j = _tryDecodeJson(raw);
      title = (j['title'] as String?) ?? title;
      body = (j['body'] as String?) ?? body;
    } catch (_) {}
  }

  const AndroidNotificationDetails android = AndroidNotificationDetails(
    'habit_reminders',
    'Habit Reminders',
    channelDescription: 'Reminders for your daily habits',
    importance: Importance.high,
    priority: Priority.high,
    playSound: true,
    enableVibration: true,
  );
  const DarwinNotificationDetails ios = DarwinNotificationDetails(
    presentAlert: true,
    presentBadge: true,
    presentSound: true,
  );
  const NotificationDetails details = NotificationDetails(android: android, iOS: ios);

  try {
    await plugin.show(id, title, body, details);
  } catch (_) {}
}

Map<String, dynamic> _tryDecodeJson(String raw) {
  try {
    return jsonDecode(raw) as Map<String, dynamic>;
  } catch (_) {
    return <String, dynamic>{};
  }
}

String _escapeJson(String input) {
  return input.replaceAll('\\', r'\\').replaceAll('"', r'\"').replaceAll('\n', r'\\n');
}
