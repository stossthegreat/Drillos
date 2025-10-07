import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../alarms/alarm_cache.dart';
import '../alarms/alarm_scheduler.dart';
import '../alarms/alarm_designer_screen.dart';

/// Drop-in widget for your Habit Create/Edit screen.
/// Shows current alarm (if any), and a button to pick/change it.
class HabitAlarmPicker extends StatefulWidget {
  final String habitId; // pass the local habit id (uuid you already use)

  const HabitAlarmPicker({super.key, required this.habitId});

  @override
  State<HabitAlarmPicker> createState() => _HabitAlarmPickerState();
}

class _HabitAlarmPickerState extends State<HabitAlarmPicker> {
  AlarmModel? _alarm;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final list = await AlarmCache.forHabit(widget.habitId);
    setState(() {
      _alarm = list.isNotEmpty ? list.first : null;
      _loading = false;
    });
  }

  Future<void> _pick() async {
    final selected = await Navigator.of(context).push<AlarmModel>(
      MaterialPageRoute(builder: (_) => AlarmDesignerScreen(habitId: widget.habitId)),
    );
    if (selected != null) {
      setState(() => _alarm = selected);
    }
  }

  Future<void> _toggleEnabled(bool v) async {
    if (_alarm == null) return;
    await AlarmCache.setEnabled(_alarm!.id, v);
    _alarm = _alarm!.copyWith(enabled: v);
    setState(() {});
    if (v) {
      await alarmScheduler.scheduleAlarm(_alarm!);
    } else {
      await alarmScheduler.cancelAlarm(_alarm!);
    }
  }

  Future<void> _remove() async {
    if (_alarm == null) return;
    await alarmScheduler.cancelAlarm(_alarm!);
    await AlarmCache.delete(_alarm!.id);
    setState(() => _alarm = null);
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return _card(
        child: const Center(
          child: Padding(
            padding: EdgeInsets.all(16),
            child: CircularProgressIndicator(),
          ),
        ),
      );
    }

    if (_alarm == null) {
      return _card(
        child: Row(
          children: [
            const Icon(Icons.alarm_add, color: Colors.white70),
            const SizedBox(width: 12),
            const Expanded(
              child: Text('No alarm set for this habit.',
                  style: TextStyle(color: Colors.white70)),
            ),
            ElevatedButton(
              onPressed: _pick,
              child: const Text('Pick Alarm'),
            ),
          ],
        ),
      );
    }

    final a = _alarm!;
    return _card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            const Icon(Icons.alarm, color: Colors.white70),
            const SizedBox(width: 8),
            Expanded(
              child: Text(a.title,
                  style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600)),
            ),
            Switch(
              value: a.enabled,
              onChanged: _toggleEnabled,
            ),
          ]),
          const SizedBox(height: 6),
          Text(
            'Mentor: ${a.mentorId.toUpperCase()} • Time: ${a.time} • Days: ${a.daysOfWeek.map(_abbr).join(', ')}',
            style: const TextStyle(color: Colors.white60, fontSize: 12),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              OutlinedButton.icon(
                onPressed: _pick,
                icon: const Icon(Icons.edit),
                label: const Text('Change'),
              ),
              const SizedBox(width: 8),
              TextButton.icon(
                onPressed: _remove,
                icon: const Icon(Icons.delete_outline, color: Color(0xFFE11D48)),
                label: const Text('Remove', style: TextStyle(color: Color(0xFFE11D48))),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _card({required Widget child}) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF121816),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withOpacity(0.1)),
      ),
      child: child,
    );
  }

  String _abbr(int weekday) => const ['Mon','Tue','Wed','Thu','Fri','Sat','Sun'][weekday - 1];
}
