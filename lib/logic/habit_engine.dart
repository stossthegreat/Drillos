import '../services/local_storage.dart' as ls1;

/// HabitEngine – small helper for streak logic used by UI screens.
class HabitEngine {
  static DateTime _startOfDay(DateTime d) => DateTime(d.year, d.month, d.day);

  /// Resets streaks for habits that were missed yesterday and not yet completed today.
  static Future<void> checkStreakResets() async {
    final items = await ls1.localStorage.getAllHabits();
    final now = DateTime.now();
    final today = _startOfDay(now);
    final yesterday = today.subtract(const Duration(days: 1));

    for (final raw in items) {
      final type = (raw['type'] ?? 'habit').toString();
      if (type != 'habit') continue;
      final id = raw['id'].toString();
      final doneYesterday = await ls1.localStorage.isCompletedOn(id, yesterday);
      final doneToday = await ls1.localStorage.isCompletedOn(id, today);
      if (!doneYesterday && !doneToday) {
        final current = await ls1.localStorage.getStreak(id);
        if (current != 0) {
          await ls1.localStorage.setStreak(id, 0);
        }
      }
    }
  }

  /// Applies a local completion tick for today and updates streak + XP.
  static Future<void> applyLocalTick({
    required String habitId,
    void Function(int newStreak, int newXp)? onApplied,
  }) async {
    final now = DateTime.now();
    final today = _startOfDay(now);
    final yesterday = today.subtract(const Duration(days: 1));

    await ls1.localStorage.markCompleted(habitId, today);

    final prevStreak = await ls1.localStorage.getStreak(habitId);
    final wasYesterdayDone = await ls1.localStorage.isCompletedOn(habitId, yesterday);
    final newStreak = wasYesterdayDone ? prevStreak + 1 : 1;
    await ls1.localStorage.setStreak(habitId, newStreak);

    // Award flat XP for now; adjust as needed
    final newXpTotal = await ls1.localStorage.addXP(10);

    if (onApplied != null) {
      onApplied(newStreak, newXpTotal);
    }
  }
}
