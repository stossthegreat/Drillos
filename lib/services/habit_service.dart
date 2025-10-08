import 'package:uuid/uuid.dart';
import 'local_storage.dart';
import 'api_client.dart';
import 'alarm_service.dart';

/// Offline-first Habit/Task service
class HabitService {
  static final HabitService _instance = HabitService._internal();
  factory HabitService() => _instance;
  HabitService._internal();

  final _storage = localStorage;
  final _api = ApiClient();
  final _alarms = alarmService;
  final _uuid = const Uuid();

  // ---------- CREATE ----------

  Future<Map<String, dynamic>> createHabit(Map<String, dynamic> data) async {
    final id = _uuid.v4();
    final now = DateTime.now();

    final habit = {
      'id': id,
      'title': data['name'] ?? data['title'] ?? 'New Habit',
      'name': data['name'] ?? data['title'] ?? 'New Habit',
      'color': data['color'] ?? 'emerald',
      'streak': 0,
      'xp': 0,
      'completed': false,
      'createdAt': now.toIso8601String(),
      'updatedAt': now.toIso8601String(),
      'type': data['type'] ?? 'habit',
      'schedule': _buildSchedule(data),
      'reminderEnabled': data['reminderOn'] ?? false,
      'reminderTime': data['reminderTime'],
      'intensity': data['intensity'] ?? 2,
    };

    await _storage.saveHabit(habit);

    if (habit['reminderEnabled'] == true && habit['reminderTime'] != null) {
      await _createHabitAlarm(habit);
    }

    _syncHabitToBackend(habit); // fire-and-forget
    return habit;
  }

  Future<Map<String, dynamic>> createTask(Map<String, dynamic> data) async {
    final id = _uuid.v4();
    final now = DateTime.now();

    final task = {
      'id': id,
      'title': data['name'] ?? data['title'] ?? 'New Task',
      'name': data['name'] ?? data['title'] ?? 'New Task',
      'color': data['color'] ?? 'blue',
      'completed': false,
      'createdAt': now.toIso8601String(),
      'updatedAt': now.toIso8601String(),
      'type': 'task',
      'dueDate':
          data['endDate'] ?? now.add(const Duration(days: 1)).toIso8601String(),
      'schedule': _buildSchedule(data),
      'reminderEnabled': data['reminderOn'] ?? false,
      'reminderTime': data['reminderTime'],
      'priority': data['intensity'] ?? 2,
    };

    await _storage.saveHabit(task);

    if (task['reminderEnabled'] == true && task['reminderTime'] != null) {
      await _createTaskAlarm(task);
    }

    _syncTaskToBackend(task);
    return task;
  }

  // ---------- UPDATE ----------

  Future<Map<String, dynamic>> updateHabit(
      String id, Map<String, dynamic> data) async {
    final habits = await _storage.getAllHabits();
    final idx = habits.indexWhere((h) => h['id'] == id);
    if (idx == -1) throw Exception('Habit not found: $id');

    final existing = Map<String, dynamic>.from(habits[idx]);
    final updated = {
      ...existing,
      ...data,
      'id': id,
      'type': data['type'] ?? existing['type'],
      'updatedAt': DateTime.now().toIso8601String(),
    };

    if (data.containsKey('name') ||
        data.containsKey('schedule') ||
        data.containsKey('frequency') ||
        data.containsKey('daysOfWeek') ||
        data.containsKey('everyN')) {
      updated['schedule'] = _buildSchedule({...existing, ...data});
    }

    await _storage.saveHabit(updated);

    if (data.containsKey('reminderOn') || data.containsKey('reminderTime')) {
      if (updated['reminderEnabled'] == true &&
          updated['reminderTime'] != null) {
        await _createHabitAlarm(updated);
      } else {
        await _alarms.cancelAlarm(id);
      }
    }

    _syncHabitToBackend(updated);
    return updated;
  }

  // ---------- DELETE ----------

  /// Kept for backward compatibility with screens calling `deleteHabit`.
  Future<void> deleteHabit(String id) async => deleteItem(id);

  /// Deletes local item + cancels alarms + tries both remote endpoints
  /// when type is unknown (fixes “old tasks” that kept reappearing).
  Future<void> deleteItem(String id, {String? type}) async {
    // local
    await _storage.deleteHabit(id);
    try {
      await _alarms.cancelAlarm(id);
    } catch (_) {}

    // try to figure out type from local
    String? t = type ?? await _findType(id);

    // remote – try both if unknown
    try {
      if (t == 'task') {
        await _api.deleteTask(id);
      } else if (t == 'habit') {
        await _api.deleteHabit(id);
      } else {
        // Unknown: attempt task first, then habit
        try {
          await _api.deleteTask(id);
        } catch (_) {
          try {
            await _api.deleteHabit(id);
          } catch (_) {}
        }
      }
    } catch (_) {}
  }

  // ---------- READ ----------

  Future<List<Map<String, dynamic>>> getAllHabits() =>
      _storage.getAllHabits();

  Future<List<Map<String, dynamic>>> getHabitsForDate(DateTime date) async {
    final allHabits = await _storage.getAllHabits();
    final result = <Map<String, dynamic>>[];

    for (final habit in allHabits) {
      final schedule = habit['schedule'] as Map<String, dynamic>?;
      final isActive = schedule == null ? true : _isActiveOn(schedule, date);
      if (!isActive) continue;

      final completed = await _storage.isCompletedOn(habit['id'], date);

      if (habit['type'] == 'task') {
        result.add({
          ...Map<String, dynamic>.from(habit),
          'completed': completed,
        });
      } else {
        final streak = await _storage.getStreak(habit['id']);
        result.add({
          ...Map<String, dynamic>.from(habit),
          'completed': completed,
          'streak': streak,
        });
      }
    }

    return result;
  }

  // ---------- HELPERS ----------

  Future<String?> _findType(String id) async {
    final all = await _storage.getAllHabits();
    return all.firstWhere((e) => e['id'] == id, orElse: () => {})['type'];
  }

  Map<String, dynamic> _buildSchedule(Map<String, dynamic> data) {
    final frequency = data['frequency'] ?? 'daily';
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);

    Map<String, dynamic> schedule;
    if (frequency == 'daily') {
      schedule = {
        'startDate': data['startDate'] ?? today.toIso8601String(),
        'endDate': data['endDate'],
        'daysOfWeek': [1, 2, 3, 4, 5, 6, 7],
      };
    } else if (frequency == 'weekdays') {
      schedule = {
        'startDate': data['startDate'] ?? today.toIso8601String(),
        'endDate': data['endDate'],
        'daysOfWeek': [1, 2, 3, 4, 5],
      };
    } else if (frequency == 'weekends') {
      schedule = {
        'startDate': data['startDate'] ?? today.toIso8601String(),
        'endDate': data['endDate'],
        'daysOfWeek': [6, 7],
      };
    } else if (frequency == 'everyN') {
      final everyN = data['everyN'] ?? 2;
      schedule = {
        'startDate': data['startDate'] ?? today.toIso8601String(),
        'endDate': data['endDate'],
        'daysOfWeek': [1, 2, 3, 4, 5, 6, 7],
        'everyN': everyN,
        'lastCompleted': null,
      };
    } else if (frequency == 'custom' && data['daysOfWeek'] != null) {
      schedule = {
        'startDate': data['startDate'] ?? today.toIso8601String(),
        'endDate': data['endDate'],
        'daysOfWeek': data['daysOfWeek'],
      };
    } else {
      schedule = {
        'startDate': data['startDate'] ?? today.toIso8601String(),
        'endDate': data['endDate'],
        'daysOfWeek': [1, 2, 3, 4, 5, 6, 7],
      };
    }

    return schedule;
  }

  bool _isActiveOn(Map<String, dynamic> schedule, DateTime date) {
    final d = DateTime(date.year, date.month, date.day);

    final startDateStr = schedule['startDate'] as String?;
    if (startDateStr != null) {
      final startDate = DateTime.parse(startDateStr);
      if (d.isBefore(DateTime(startDate.year, startDate.month, startDate.day))) {
        return false;
      }
    }

    final endDateStr = schedule['endDate'] as String?;
    if (endDateStr != null && endDateStr.isNotEmpty) {
      final endDate = DateTime.parse(endDateStr);
      if (d.isAfter(DateTime(endDate.year, endDate.month, endDate.day, 23, 59))) {
        return false;
      }
    }

    if (schedule['everyN'] != null) {
      final everyN = schedule['everyN'] as int? ?? 2;
      final start = DateTime.parse(startDateStr ?? DateTime.now().toIso8601String());
      final daysSince =
          d.difference(DateTime(start.year, start.month, start.day)).inDays;
      return daysSince % everyN == 0;
    }

    final rawDays = schedule['daysOfWeek'];
    final daysOfWeek = <int>[];
    if (rawDays is List) {
      for (final day in rawDays) {
        if (day is int && day >= 1 && day <= 7) {
          daysOfWeek.add(day);
        } else if (day is String) {
          final parsed = int.tryParse(day);
          if (parsed != null && parsed >= 1 && parsed <= 7) daysOfWeek.add(parsed);
        } else if (day is num) {
          final intDay = day.toInt();
          if (intDay >= 1 && intDay <= 7) daysOfWeek.add(intDay);
        }
      }
    }
    if (daysOfWeek.isEmpty) daysOfWeek.addAll([1, 2, 3, 4, 5, 6, 7]);
    return daysOfWeek.contains(d.weekday);
  }

  Future<void> _createHabitAlarm(Map<String, dynamic> habit) async {
    try {
      final schedule = habit['schedule'] as Map<String, dynamic>?;
      final daysOfWeek = (schedule?['daysOfWeek'] as List?)
              ?.map((e) => e is int ? e : int.tryParse(e.toString()) ?? 1)
              .toList() ??
          [1, 2, 3, 4, 5, 6, 7];

      await _alarms.scheduleAlarm(
        habitId: habit['id'],
        habitName: habit['title'] ?? habit['name'],
        time: habit['reminderTime'] ?? '08:00',
        daysOfWeek: daysOfWeek,
        mentorMessage:
            '⚡ Time to complete: ${habit['title'] ?? habit['name']}',
      );
    } catch (_) {}
  }

  Future<void> _createTaskAlarm(Map<String, dynamic> task) async {
    try {
      final schedule = task['schedule'] as Map<String, dynamic>?;
      final rawDays = schedule?['daysOfWeek'];
      List<int> daysOfWeek = [1, 2, 3, 4, 5, 6, 7];
      if (rawDays is List) {
        daysOfWeek = rawDays
            .map((e) => e is int ? e : int.tryParse(e.toString()) ?? 1)
            .toList();
      }

      await _alarms.scheduleAlarm(
        habitId: task['id'],
        habitName: task['title'] ?? task['name'],
        time: task['reminderTime'] ?? '08:00',
        daysOfWeek: daysOfWeek,
        mentorMessage: '📋 Task reminder: ${task['title'] ?? task['name']}',
      );
    } catch (_) {}
  }

 Future<void> cleanupOldItems() async {
  final items = await _storage.getAllHabits();
  for (final h in items) {
    final id = h['id'];
    if (id == null || id.toString().isEmpty) {
      await _storage.deleteHabit(id);
      continue;
    }
    final type = h['type'];
    if (type != 'habit' && type != 'task' && type != 'bad') {
      await _storage.deleteHabit(id);
    }
  }
 } // ---------- REMOTE SYNC ----------

  void _syncHabitToBackend(Map<String, dynamic> habit) {
    _api
        .createHabit({
          'title': habit['title'] ?? habit['name'],
          'schedule': habit['schedule'],
          'color': habit['color'],
          'reminderEnabled': habit['reminderEnabled'],
          'reminderTime': habit['reminderTime'],
          'type': habit['type'],
        })
        .catchError((_) {});
  }

  void _syncTaskToBackend(Map<String, dynamic> task) {
    _api
        .createTask({
          'title': task['title'] ?? task['name'],
          'dueDate': task['dueDate'],
          'description': task['description'] ?? '',
          'priority': task['priority'],
          'color': task['color'],
        })
        .catchError((_) {});
  }
}

final habitService = HabitService();
