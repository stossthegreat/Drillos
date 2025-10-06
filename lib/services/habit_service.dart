import 'dart:convert';
import 'package:uuid/uuid.dart';
import 'local_storage.dart';
import 'api_client.dart';
import 'alarm_service.dart';

/// 🎯 Habit Service - Complete offline-first habit management
/// 
/// Creates, updates, deletes habits locally FIRST, then syncs to backend.
/// This ensures instant UI updates and offline functionality.
class HabitService {
  static final HabitService _instance = HabitService._internal();
  factory HabitService() => _instance;
  HabitService._internal();

  final _storage = localStorage;
  final _api = ApiClient();
  final _alarms = alarmService;
  final _uuid = const Uuid();

  /// ✅ Create a new habit (OFFLINE-FIRST)
  Future<Map<String, dynamic>> createHabit(Map<String, dynamic> data) async {
    print('🎯 Creating habit locally...');
    
    // Generate local ID
    final habitId = _uuid.v4();
    final now = DateTime.now();
    
    // Build habit object
    final habit = {
      'id': habitId,
      'title': data['name'] ?? data['title'] ?? 'New Habit',
      'name': data['name'] ?? data['title'] ?? 'New Habit',
      'color': data['color'] ?? 'emerald',
      'streak': 0,
      'xp': 0,
      'completed': false,
      'createdAt': now.toIso8601String(),
      'updatedAt': now.toIso8601String(),
      'type': 'habit',
      'schedule': _buildSchedule(data),
      'reminderEnabled': data['reminderOn'] ?? false,
      'reminderTime': data['reminderTime'],
      'intensity': data['intensity'] ?? 2,
    };

    // Save locally FIRST
    await _storage.saveHabit(habit);
    print('✅ Habit saved locally: ${habit['title']}');

    // Create alarm if reminder is enabled
    if (habit['reminderEnabled'] == true && habit['reminderTime'] != null) {
      await _createHabitAlarm(habit);
    }

    // Sync to backend (fire-and-forget)
    _syncHabitToBackend(habit);

    return habit;
  }

  /// ✅ Create a new task (OFFLINE-FIRST)
  Future<Map<String, dynamic>> createTask(Map<String, dynamic> data) async {
    print('🎯 Creating task locally...');
    
    final taskId = _uuid.v4();
    final now = DateTime.now();
    
    final task = {
      'id': taskId,
      'title': data['name'] ?? data['title'] ?? 'New Task',
      'name': data['name'] ?? data['title'] ?? 'New Task',
      'color': data['color'] ?? 'blue',
      'completed': false,
      'createdAt': now.toIso8601String(),
      'updatedAt': now.toIso8601String(),
      'type': 'task',
      'dueDate': data['endDate'] ?? now.add(const Duration(days: 1)).toIso8601String(),
      'schedule': _buildSchedule(data),
      'reminderEnabled': data['reminderOn'] ?? false,
      'reminderTime': data['reminderTime'],
      'priority': data['intensity'] ?? 2,
    };

    // Save locally
    await _storage.saveHabit(task); // Using same storage method
    print('✅ Task saved locally: ${task['title']}');

    // Create alarm if reminder is enabled
    if (task['reminderEnabled'] == true && task['reminderTime'] != null) {
      await _createTaskAlarm(task);
    }

    // Sync to backend
    _syncTaskToBackend(task);

    return task;
  }

  /// ✅ Update a habit
  Future<Map<String, dynamic>> updateHabit(String id, Map<String, dynamic> data) async {
    print('🎯 Updating habit locally: $id');
    
    // Get existing habit
    final habits = await _storage.getAllHabits();
    final existing = habits.firstWhere(
      (h) => h['id'] == id,
      orElse: () => <String, dynamic>{},
    );

    if (existing.isEmpty) {
      throw Exception('Habit not found: $id');
    }

    // Merge updates
    final updated = {
      ...existing,
      ...data,
      'id': id, // Preserve ID
      'updatedAt': DateTime.now().toIso8601String(),
    };

    // Update schedule if provided
    if (data.containsKey('name') || data.containsKey('schedule') || data.containsKey('frequency')) {
      updated['schedule'] = _buildSchedule(data);
    }

    // Save locally
    await _storage.saveHabit(updated);
    print('✅ Habit updated locally');

    // Update alarm if reminder settings changed
    if (data.containsKey('reminderOn') || data.containsKey('reminderTime')) {
      if (updated['reminderEnabled'] == true && updated['reminderTime'] != null) {
        await _createHabitAlarm(updated);
      } else {
        await _alarms.cancelAlarm(id);
      }
    }

    // Sync to backend
    _syncHabitToBackend(updated);

    return updated;
  }

  /// ✅ Delete a habit
  Future<void> deleteHabit(String id) async {
    print('🗑️ HabitService.deleteHabit called for: $id');
    
    // Delete locally
    print('🗑️ Deleting from local storage...');
    await _storage.deleteHabit(id);
    print('✅ Deleted from local storage');
    
    // Cancel any alarms (wrapped in try-catch to prevent delete failure)
    print('🔔 Cancelling alarms...');
    try {
      await _alarms.cancelAlarm(id);
      print('✅ Alarms cancelled');
    } catch (e) {
      print('⚠️ Failed to cancel alarms (OK, continuing): $e');
    }
    
    // Delete from backend (fire-and-forget)
    print('🌐 Syncing delete to backend...');
    try {
      await _api.deleteHabit(id);
      print('✅ Habit deleted from backend');
    } catch (e) {
      print('⚠️ Failed to delete from backend (OK, it\'s local-first): $e');
    }
    
    print('✅ HabitService.deleteHabit complete for: $id');
  }

  /// ✅ Get all habits
  Future<List<Map<String, dynamic>>> getAllHabits() async {
    return await _storage.getAllHabits();
  }

  /// ✅ Get today's habits (filtered by schedule)
  Future<List<Map<String, dynamic>>> getTodayHabits() async {
    final allHabits = await _storage.getAllHabits();
    final today = DateTime.now();
    final todayHabits = <Map<String, dynamic>>[];

    for (final habit in allHabits) {
      if (habit['type'] == 'task') {
        // Tasks now use schedule just like habits
        final schedule = habit['schedule'] as Map<String, dynamic>?;
        final isScheduled = schedule == null ? true : _isActiveOn(schedule, today);
        if (!isScheduled) continue;

        // Completion is tracked per-day locally
        final completedToday = await _storage.isCompletedOn(habit['id'], today);
        if (!completedToday) {
          todayHabits.add({
            ...habit,
            'completed': false,
          });
        }
        continue;
      }

      // Check if habit is scheduled for today
      final schedule = habit['schedule'] as Map<String, dynamic>?;
      if (schedule == null) {
        todayHabits.add(habit);
        continue;
      }

      if (_isActiveOn(schedule, today)) {
        // Load completion status
        final completed = await _storage.isCompletedOn(habit['id'], today);
        final streak = await _storage.getStreak(habit['id']);
        
        todayHabits.add({
          ...habit,
          'completed': completed,
          'streak': streak,
        });
      }
    }

    return todayHabits;
  }

  // ========== PRIVATE HELPERS ==========

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
    } else if (frequency == 'custom' && data['daysOfWeek'] != null) {
      schedule = {
        'startDate': data['startDate'] ?? today.toIso8601String(),
        'endDate': data['endDate'],
        'daysOfWeek': data['daysOfWeek'],
      };
    } else {
      // Default to daily
      schedule = {
        'startDate': data['startDate'] ?? today.toIso8601String(),
        'endDate': data['endDate'],
        'daysOfWeek': [1, 2, 3, 4, 5, 6, 7],
      };
    }
    
    print('📅 Built schedule: frequency=$frequency, daysOfWeek=${schedule['daysOfWeek']}');
    return schedule;
  }

  bool _isActiveOn(Map<String, dynamic> schedule, DateTime date) {
    final d = DateTime(date.year, date.month, date.day);
    
    // Check start date
    final startDateStr = schedule['startDate'] as String?;
    if (startDateStr != null) {
      final startDate = DateTime.parse(startDateStr);
      final s = DateTime(startDate.year, startDate.month, startDate.day);
      if (d.isBefore(s)) return false;
    }
    
    // Check end date
    final endDateStr = schedule['endDate'] as String?;
    if (endDateStr != null && endDateStr.isNotEmpty) {
      final endDate = DateTime.parse(endDateStr);
      final e = DateTime(endDate.year, endDate.month, endDate.day, 23, 59, 59);
      if (d.isAfter(e)) return false;
    }
    
    // ✅ FIX: Robust parsing of daysOfWeek from JSON
    final rawDays = schedule['daysOfWeek'];
    final daysOfWeek = <int>[];
    
    if (rawDays is List) {
      for (final day in rawDays) {
        if (day is int && day >= 1 && day <= 7) {
          daysOfWeek.add(day);
        } else if (day is String) {
          final parsed = int.tryParse(day);
          if (parsed != null && parsed >= 1 && parsed <= 7) {
            daysOfWeek.add(parsed);
          }
        } else if (day is num) {
          final intDay = day.toInt();
          if (intDay >= 1 && intDay <= 7) {
            daysOfWeek.add(intDay);
          }
        }
      }
    }
    
    // Default to all days if empty
    if (daysOfWeek.isEmpty) {
      daysOfWeek.addAll([1, 2, 3, 4, 5, 6, 7]);
    }
    
    print('🔍 Schedule check: date=${d.weekday}, daysOfWeek=$daysOfWeek, active=${daysOfWeek.contains(d.weekday)}');
    return daysOfWeek.contains(d.weekday);
  }

  Future<void> _createHabitAlarm(Map<String, dynamic> habit) async {
    try {
      final timeParts = (habit['reminderTime'] as String).split(':');
      final schedule = habit['schedule'] as Map<String, dynamic>?;
      final daysOfWeek = (schedule?['daysOfWeek'] as List?)?.cast<int>() ?? [1, 2, 3, 4, 5, 6, 7];

      await _alarms.scheduleAlarm(
        habitId: habit['id'],
        habitName: habit['title'] ?? habit['name'],
        time: habit['reminderTime'],
        daysOfWeek: daysOfWeek,
        mentorMessage: '⚡ Time to complete: ${habit['title'] ?? habit['name']}',
      );
      print('✅ Created alarm for habit');
    } catch (e) {
      print('❌ Error creating habit alarm: $e');
    }
  }

  Future<void> _createTaskAlarm(Map<String, dynamic> task) async {
    try {
      // Use schedule days if available; otherwise default to all days
      final schedule = task['schedule'] as Map<String, dynamic>?;
      List<int> daysOfWeek = [1, 2, 3, 4, 5, 6, 7];
      final rawDays = schedule?['daysOfWeek'];
      if (rawDays is List) {
        final parsed = <int>[];
        for (final day in rawDays) {
          if (day is int && day >= 1 && day <= 7) parsed.add(day);
          else if (day is String) {
            final d = int.tryParse(day);
            if (d != null && d >= 1 && d <= 7) parsed.add(d);
          } else if (day is num) {
            final d = day.toInt();
            if (d >= 1 && d <= 7) parsed.add(d);
          }
        }
        if (parsed.isNotEmpty) daysOfWeek = parsed;
      }

      await _alarms.scheduleAlarm(
        habitId: task['id'],
        habitName: task['title'] ?? task['name'],
        time: task['reminderTime'],
        daysOfWeek: daysOfWeek,
        mentorMessage: '📋 Task reminder: ${task['title'] ?? task['name']}',
      );
      print('✅ Created alarm for task');
    } catch (e) {
      print('❌ Error creating task alarm: $e');
    }
  }

  /// ✅ Mark a task as completed locally for today (instant UI)
  Future<void> completeTaskLocal(String taskId, {DateTime? when}) async {
    final date = when ?? DateTime.now();
    await _storage.markCompleted(taskId, date);

    // Also update task object 'completed' flag to help UI lists that depend on it
    final items = await _storage.getAllHabits();
    final index = items.indexWhere((i) => i['id'] == taskId);
    if (index >= 0) {
      items[index] = {
        ...items[index],
        'completed': true,
        'updatedAt': DateTime.now().toIso8601String(),
      };
      await _storage.saveAllHabits(items);
    }
  }

  void _syncHabitToBackend(Map<String, dynamic> habit) {
    // Fire-and-forget sync
    _api.createHabit({
      'title': habit['title'] ?? habit['name'],
      'schedule': habit['schedule'],
      'color': habit['color'],
      'reminderEnabled': habit['reminderEnabled'],
      'reminderTime': habit['reminderTime'],
    }).then((response) {
      print('✅ Habit synced to backend: ${habit['title']}');
    }).catchError((e) {
      print('⚠️ Failed to sync habit to backend: $e');
    });
  }

  void _syncTaskToBackend(Map<String, dynamic> task) {
    // Fire-and-forget sync
    _api.createTask({
      'title': task['title'] ?? task['name'],
      'dueDate': task['dueDate'],
      'description': task['description'] ?? '',
      'priority': task['priority'],
      'color': task['color'],
    }).then((response) {
      print('✅ Task synced to backend: ${task['title']}');
    }).catchError((e) {
      print('⚠️ Failed to sync task to backend: $e');
    });
  }
}

final habitService = HabitService();

