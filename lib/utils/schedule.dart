class HabitSchedule {
  final DateTime startDate;
  final DateTime? endDate;
  final List<int> daysOfWeek;

  HabitSchedule({
    required this.startDate,
    this.endDate,
    this.daysOfWeek = const [1,2,3,4,5,6,7],
  });

  factory HabitSchedule.fromJson(Map<String, dynamic>? json) {
    if (json == null) {
      final now = DateTime.now();
      return HabitSchedule(startDate: DateTime(now.year, now.month, now.day));
    }
    DateTime? parseDate(dynamic v) {
      if (v == null) return null;
      if (v is String && v.isNotEmpty) return DateTime.tryParse(v);
      return null;
    }

    final now = DateTime.now();
    final sd = parseDate(json['startDate']) ?? DateTime(now.year, now.month, now.day);
    final ed = parseDate(json['endDate']);
    final days = <int>[];
    final raw = json['daysOfWeek'];
    if (raw is List) {
      for (final r in raw) {
        final i = int.tryParse('$r');
        if (i != null && i >= 1 && i <= 7) days.add(i);
      }
    }
    return HabitSchedule(
      startDate: sd,
      endDate: ed,
      daysOfWeek: days.isEmpty ? const [1,2,3,4,5,6,7] : days,
    );
  }

  bool isActiveOn(DateTime date) {
    final d = DateTime(date.year, date.month, date.day);
    final s = DateTime(startDate.year, startDate.month, startDate.day);
    if (d.isBefore(s)) return false;
    if (endDate != null) {
      final e = DateTime(endDate!.year, endDate!.month, endDate!.day, 23, 59, 59);
      if (d.isAfter(e)) return false;
    }
    return daysOfWeek.contains(d.weekday);
  }
}

