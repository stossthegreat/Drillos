import 'package:shared_preferences/shared_preferences.dart';
import '../services/local_storage.dart';

/// 🔥 Habit Engine - The living heart of DrillOS
/// 
/// Handles all habit logic instantly on the frontend:
/// - Ticking habits (completion)
/// - Streak calculation & resets
/// - XP awards
/// - No backend dependency (fire-and-forget logging only)
class HabitEngine {
  static String _ymd(DateTime d) => '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

  /// ⚡ Apply a tick to a habit (INSTANT, OFFLINE-FIRST)
  /// 
  /// This is the core function that makes DrillOS feel alive.
  /// It runs completely locally and updates UI immediately.
  static Future<void> applyLocalTick({
    required String habitId,
    required void Function(int newStreak, int newXp) onApplied,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    final todayKey = 'done:$habitId:${_ymd(DateTime.now())}';
    final streakKey = 'streak:$habitId';
    final xpKey = 'xp:total';
    final habitXpKey = 'xp:$habitId';
    final lastCompleteKey = 'lastComplete:$habitId';

    // Check if already completed today
    final already = prefs.getBool(todayKey) ?? false;
    if (already) {
      // Already done - just return current values
      onApplied(prefs.getInt(streakKey) ?? 0, prefs.getInt(xpKey) ?? 0);
      return;
    }

    // Calculate new streak
    final lastCompleteStr = prefs.getString(lastCompleteKey);
    final lastComplete = lastCompleteStr != null ? DateTime.tryParse(lastCompleteStr) : null;
    
    int newStreak = 1;
    if (lastComplete != null) {
      final yesterday = DateTime.now().subtract(const Duration(days: 1));
      final yesterdayKey = _ymd(yesterday);
      final lastKey = _ymd(lastComplete);
      
      if (lastKey == yesterdayKey) {
        // Completed yesterday - increment streak
        final currentStreak = prefs.getInt(streakKey) ?? 0;
        newStreak = currentStreak + 1;
      }
      // else: missed a day - streak resets to 1
    }

    // Award XP (15 XP per completion + bonus for streaks)
    final baseXP = 15;
    final streakBonus = (newStreak >= 7) ? 10 : (newStreak >= 3) ? 5 : 0;
    final xpAwarded = baseXP + streakBonus;
    
    final currentXp = prefs.getInt(xpKey) ?? 0;
    final currentHabitXp = prefs.getInt(habitXpKey) ?? 0;
    final newXp = currentXp + xpAwarded;

    // Save everything
    await prefs.setBool(todayKey, true);
    await prefs.setInt(streakKey, newStreak);
    await prefs.setInt(xpKey, newXp);
    await prefs.setInt(habitXpKey, currentHabitXp + xpAwarded);
    await prefs.setString(lastCompleteKey, DateTime.now().toIso8601String());

    // Notify UI immediately
    onApplied(newStreak, newXp);
    
    print('✅ Habit ticked: streak=$newStreak, xp=$newXp (+$xpAwarded)');
  }

  /// 🔄 Check and reset streaks for habits that missed a day
  static Future<void> checkStreakResets() async {
    final storage = localStorage;
    final habits = await storage.getAllHabits();
    final today = DateTime.now();
    final yesterday = today.subtract(const Duration(days: 1));

    for (final habit in habits) {
      final habitId = habit['id'];
      final lastComplete = await storage.getLastCompletionDate(habitId);
      
      if (lastComplete != null) {
        final daysSinceComplete = today.difference(lastComplete).inDays;
        
        // If more than 1 day passed without completion, reset streak
        if (daysSinceComplete > 1) {
          final currentStreak = await storage.getStreak(habitId);
          if (currentStreak > 0) {
            await storage.setStreak(habitId, 0);
            print('🔥 Streak reset for habit $habitId (was $currentStreak, missed ${daysSinceComplete} days)');
          }
        }
      }
    }
  }

  /// 📊 Calculate overall stats
  static Future<Map<String, dynamic>> getStats() async {
    final storage = localStorage;
    final habits = await storage.getAllHabits();
    
    int totalStreaks = 0;
    int longestStreak = 0;
    int completedToday = 0;
    
    for (final habit in habits) {
      final habitId = habit['id'];
      final streak = await storage.getStreak(habitId);
      totalStreaks += streak;
      if (streak > longestStreak) longestStreak = streak;
      
      final isCompleted = await storage.isCompletedOn(habitId, DateTime.now());
      if (isCompleted) completedToday++;
    }
    
    final totalXP = await storage.getTotalXP();
    
    return {
      'totalXP': totalXP,
      'longestStreak': longestStreak,
      'totalStreaks': totalStreaks,
      'completedToday': completedToday,
      'totalHabits': habits.length,
    };
  }

  /// 🎯 Get today's habits (filtered by schedule)
  static Future<List<Map<String, dynamic>>> getTodayHabits() async {
    final storage = localStorage;
    final allHabits = await storage.getAllHabits();
    final today = DateTime.now();
    final todayHabits = <Map<String, dynamic>>[];

    for (final habit in allHabits) {
      // Check if habit is scheduled for today
      final schedule = habit['schedule'] as Map<String, dynamic>?;
      if (schedule == null) {
        todayHabits.add(habit);
        continue;
      }

      final startDateStr = schedule['startDate'] as String?;
      final endDateStr = schedule['endDate'] as String?;
      final daysOfWeek = (schedule['daysOfWeek'] as List?)?.cast<int>() ?? [1, 2, 3, 4, 5, 6, 7];

      final startDate = startDateStr != null ? DateTime.tryParse(startDateStr) : null;
      final endDate = endDateStr != null ? DateTime.tryParse(endDateStr) : null;

      // Check date range
      if (startDate != null && today.isBefore(startDate)) continue;
      if (endDate != null && today.isAfter(endDate)) continue;

      // Check day of week
      if (!daysOfWeek.contains(today.weekday)) continue;

      // Load completion status
      final completed = await storage.isCompletedOn(habit['id'], today);
      final streak = await storage.getStreak(habit['id']);

      todayHabits.add({
        ...habit,
        'completed': completed,
        'streak': streak,
      });
    }

    return todayHabits;
  }
}
