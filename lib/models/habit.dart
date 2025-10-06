import '../utils/schedule.dart';

/// 🎯 Habit Model - Complete local representation
class Habit {
  final String id;
  final String name;
  final String color;
  final HabitSchedule schedule;
  final String? alarmTime;
  final String? mentorId;
  final int intensity;
  
  // Local-only fields
  int streak;
  int xp;
  bool completedToday;
  DateTime? lastCompleted;

  Habit({
    required this.id,
    required this.name,
    required this.color,
    required this.schedule,
    this.alarmTime,
    this.mentorId,
    this.intensity = 2,
    this.streak = 0,
    this.xp = 0,
    this.completedToday = false,
    this.lastCompleted,
  });

  /// Create from JSON (from API or local storage)
  factory Habit.fromJson(Map<String, dynamic> json) {
    return Habit(
      id: json['id'] ?? '',
      name: json['title'] ?? json['name'] ?? '',
      color: json['color'] ?? 'emerald',
      schedule: HabitSchedule.fromJson(json['schedule'] as Map<String, dynamic>?),
      alarmTime: json['alarmTime'] ?? json['reminderTime'],
      mentorId: json['mentorId'],
      intensity: json['intensity'] ?? 2,
      streak: json['streak'] ?? 0,
      xp: json['xp'] ?? 0,
      completedToday: json['completedToday'] ?? false,
      lastCompleted: json['lastCompleted'] != null 
          ? DateTime.tryParse(json['lastCompleted']) 
          : null,
    );
  }

  /// Convert to JSON (for storage or API)
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'title': name, // Backend uses 'title'
      'color': color,
      'schedule': {
        'startDate': schedule.startDate.toIso8601String().split('T')[0],
        'endDate': schedule.endDate?.toIso8601String().split('T')[0],
        'daysOfWeek': schedule.daysOfWeek,
      },
      'alarmTime': alarmTime,
      'reminderTime': alarmTime, // Backend uses 'reminderTime'
      'mentorId': mentorId,
      'intensity': intensity,
      'streak': streak,
      'xp': xp,
      'completedToday': completedToday,
      'lastCompleted': lastCompleted?.toIso8601String(),
    };
  }

  /// Check if habit is active on a specific date
  bool isActiveOn(DateTime date) {
    return schedule.isActiveOn(date);
  }

  /// Check if habit is active today
  bool get isActiveToday => isActiveOn(DateTime.now());

  /// Create a copy with updated fields
  Habit copyWith({
    String? name,
    String? color,
    HabitSchedule? schedule,
    String? alarmTime,
    String? mentorId,
    int? intensity,
    int? streak,
    int? xp,
    bool? completedToday,
    DateTime? lastCompleted,
  }) {
    return Habit(
      id: id,
      name: name ?? this.name,
      color: color ?? this.color,
      schedule: schedule ?? this.schedule,
      alarmTime: alarmTime ?? this.alarmTime,
      mentorId: mentorId ?? this.mentorId,
      intensity: intensity ?? this.intensity,
      streak: streak ?? this.streak,
      xp: xp ?? this.xp,
      completedToday: completedToday ?? this.completedToday,
      lastCompleted: lastCompleted ?? this.lastCompleted,
    );
  }
}

