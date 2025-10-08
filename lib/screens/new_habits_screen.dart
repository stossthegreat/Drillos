// lib/screens/new_habits_screen.dart
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../services/local_storage.dart' as ls1;
import '../services/habit_service.dart';
import '../services/alarm_service.dart';
import '../design/feedback.dart';
import '../logic/habit_engine.dart';
import '../utils/schedule.dart';
import '../widgets/habit_create_edit_modal.dart';

class NewHabitsScreen extends StatefulWidget {
  const NewHabitsScreen({super.key});

  @override
  State<NewHabitsScreen> createState() => _NewHabitsScreenState();
}

class _NewHabitsScreenState extends State<NewHabitsScreen>
    with TickerProviderStateMixin {
  // Core data (LOCAL ONLY – no API merge to avoid ghost/stuck items)
  List<Map<String, dynamic>> _allItems = [];
  bool _loading = true;

  // UI state
  DateTime _selectedDate = DateTime.now();
  String _tab = 'habits'; // habits | tasks | bad
  bool _showModal = false;
  bool _isEditing = false;
  Map<String, dynamic> _form = {};

  // Bottom FAB dial state
  bool _showDial = false;
  late AnimationController _dialCtrl;
  late Animation<double> _dialAnim;

  // Color options used by modal (must have 'name' + 'color')
  final List<Map<String, dynamic>> _colorOptions = const [
    {'name': 'emerald', 'color': Color(0xFF10B981)},
    {'name': 'amber', 'color': Color(0xFFF59E0B)},
    {'name': 'sky', 'color': Color(0xFF0EA5E9)},
    {'name': 'rose', 'color': Color(0xFFE11D48)},
    {'name': 'violet', 'color': Color(0xFF8B5CF6)},
    {'name': 'slate', 'color': Color(0xFF64748B)},
  ];

  String _ymd(DateTime d) => d.toIso8601String().split('T').first;

  @override
  void initState() {
    super.initState();
    _dialCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 180),
    );
    _dialAnim = CurvedAnimation(parent: _dialCtrl, curve: Curves.easeOutCubic);
    _resetForm();
    _load();
  }

  @override
  void dispose() {
    _dialCtrl.dispose();
    super.dispose();
  }

  void _resetForm() {
    _form = {
      'id': null,
      // Default type follows selected tab
      'type': _tab, // 'habits'|'tasks'|'bad' → we normalize below
      'name': '',
      'category': 'General',
      'startDate': _ymd(DateTime.now()),
      'endDate': '',
      'frequency': 'daily',
      'everyN': 2,
      'color': 'emerald',
      'intensity': 2,
      'reminderOn': false,
      'reminderTime': '08:00',
    };
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      await HabitEngine.checkStreakResets();

      // 🔥 LOCAL ONLY to avoid “ghost” API tasks coming back
      final items = await ls1.localStorage.getAllHabits();

      // Normalize types & enrich current streak/completed for today
      final enriched = <Map<String, dynamic>>[];
      for (final raw in items) {
        final it = Map<String, dynamic>.from(raw);

        // Normalize legacy tab values to 'habit'|'task'|'bad'
        final t = (it['type'] ?? 'habit').toString().toLowerCase();
        if (t == 'habits') it['type'] = 'habit';
        if (t == 'tasks') it['type'] = 'task';

        if (it['type'] == 'habit') {
          final streak = await ls1.localStorage.getStreak(it['id'].toString());
          final done = await ls1.localStorage.isCompletedOn(
              it['id'].toString(), DateTime.now());
          it['streak'] = streak;
          it['completed'] = done;
        }
        enriched.add(it);
      }

      if (!mounted) return;
      setState(() {
        _allItems = enriched;
        _loading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _loading = false);
    }
  }

  // ===== Filtering by tab =====
  List<Map<String, dynamic>> get _filtered {
    final tab = _tab;
    return _allItems.where((it) {
      final typ = (it['type'] ?? 'habit').toString().toLowerCase();
      if (tab == 'habits') return typ == 'habit';
      if (tab == 'tasks') return typ == 'task';
      if (tab == 'bad') return typ == 'bad' || typ == 'anti-habit';
      return true;
    }).toList();
  }

  // ===== Create / Update / Delete =====
  Future<void> _saveItem(Map<String, dynamic> data) async {
    try {
      // Normalize chosen type from tab
      String type = (data['type'] ?? _tab).toString().toLowerCase();
      if (type == 'habits') type = 'habit';
      if (type == 'tasks') type = 'task';
      data['type'] = type;

      if ((_isEditing) && data['id'] != null) {
        await habitService.updateHabit(data['id'].toString(), data);
        Toast.show(context, '✅ Updated');
      } else {
        final created = (type == 'task')
            ? await habitService.createTask(data)
            : await habitService.createHabit(data);

        // If reminder was enabled, schedule using AlarmService
        if ((created['reminderEnabled'] == true) &&
            (created['reminderTime'] is String)) {
          final schedule =
              (created['schedule'] as Map?)?.cast<String, dynamic>();
          final days = (schedule?['daysOfWeek'] as List?)
                  ?.map((e) => e is int
                      ? e
                      : e is String
                          ? int.tryParse(e)
                          : e is num
                              ? e.toInt()
                              : null)
                  .whereType<int>()
                  .toList() ??
              [1, 2, 3, 4, 5, 6, 7];

          await alarmService.scheduleAlarm(
            habitId: created['id'].toString(),
            habitName: created['title'] ?? created['name'] ?? 'Habit',
            time: created['reminderTime'] as String,
            daysOfWeek: days,
            mentorMessage:
                '⏰ Time to complete: ${created['title'] ?? created['name']}',
          );
        }
      }

      _closeModal();
      await _load();
      HapticFeedback.selectionClick();
    } catch (e) {
      Toast.show(context, 'Failed to save: $e');
    }
  }

  Future<void> _delete(String id) async {
    try {
      // Local delete + cancel alarms. (We DO NOT re-merge API items anymore.)
      await habitService.deleteHabit(id);
      await alarmService.cancelAlarm(id);
      await _load();
      HapticFeedback.heavyImpact();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('✅ Deleted'), duration: Duration(seconds: 1)),
      );
    } catch (_) {}
  }

  // ===== UI helpers =====
  String _monthName(int m) =>
      const [
        '',
        'January',
        'February',
        'March',
        'April',
        'May',
        'June',
        'July',
        'August',
        'September',
        'October',
        'November',
        'December'
      ][m];

  String _dayAbbr(int weekday) =>
      const ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'][weekday - 1];

  List<DateTime> get _weekDates {
    final start = _selectedDate
        .subtract(Duration(days: _selectedDate.weekday % 7));
    return List.generate(7, (i) => start.add(Duration(days: i)));
  }

  Color _colorOf(dynamic item) {
    final n = (item['color'] ?? 'emerald').toString();
    final found = _colorOptions.firstWhere(
      (c) => c['name'] == n,
      orElse: () => _colorOptions[0],
    );
    return (found['color'] as Color);
  }

  // ===== Modal controls =====
  void _openCreate(String typeKey) {
    setState(() {
      _tab = typeKey; // switch tab to where we add
      _resetForm();
      // normalize to 'habit'|'task'|'bad' for the modal
      _form['type'] = (typeKey == 'habits')
          ? 'habit'
          : (typeKey == 'tasks')
              ? 'task'
              : 'bad';
      _isEditing = false;
      _showModal = true;
      _showDial = false;
    });
  }

  void _openEdit(Map<String, dynamic> item) {
    setState(() {
      _form = {
        'id': item['id'],
        'type': item['type'] ?? 'habit',
        'name': item['name'] ?? item['title'] ?? '',
        'category': item['category'] ?? 'General',
        'startDate': item['startDate'] ?? _ymd(DateTime.now()),
        'endDate': item['endDate'] ?? '',
        'frequency': item['frequency'] ?? 'daily',
        'everyN': item['everyN'] ?? 2,
        'color': item['color'] ?? 'emerald',
        'intensity': item['difficulty'] ?? item['intensity'] ?? 2,
        'reminderOn': item['reminderEnabled'] ?? false,
        'reminderTime': item['reminderTime'] ?? '08:00',
      };
      _isEditing = true;
      _showModal = true;
    });
  }

  void _closeModal() {
    setState(() {
      _showModal = false;
      _resetForm();
    });
  }

  // ===== Widgets =====
  Widget _topBar() {
    return Container(
      padding: const EdgeInsets.fromLTRB(24, 16, 24, 8),
      child: Row(
        children: [
          const Text(
            'Daily Orders',
            style: TextStyle(
              color: Colors.white,
              fontSize: 24,
              fontWeight: FontWeight.bold,
            ),
          ),
          const Spacer(),
          IconButton(
            onPressed: () => Toast.show(context, 'Settings coming soon'),
            icon: Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Icon(Icons.settings, color: Colors.white, size: 20),
            ),
          ),
        ],
      ),
    );
  }

  Widget _weekStrip() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Column(
        children: [
          Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
            IconButton(
              onPressed: () => setState(() {
                _selectedDate = _selectedDate.subtract(const Duration(days: 7));
              }),
              icon: const Icon(Icons.chevron_left, color: Colors.white70),
            ),
            Text(
              '${_monthName(_selectedDate.month)} ${_selectedDate.year}',
              style: const TextStyle(color: Colors.white70, fontSize: 16),
            ),
            IconButton(
              onPressed: () => setState(() {
                _selectedDate = _selectedDate.add(const Duration(days: 7));
              }),
              icon: const Icon(Icons.chevron_right, color: Colors.white70),
            ),
          ]),
          Row(
            children: _weekDates.map((date) {
              final selected = _ymd(date) == _ymd(_selectedDate);
              return Expanded(
                child: GestureDetector(
                  onTap: () => setState(() => _selectedDate = date),
                  child: Container(
                    margin: const EdgeInsets.symmetric(horizontal: 2),
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    decoration: BoxDecoration(
                      color:
                          selected ? const Color(0xFF10B981) : const Color(0xFF121816),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: selected
                            ? const Color(0xFF34D399)
                            : Colors.white.withOpacity(0.1),
                      ),
                    ),
                    child: Column(
                      children: [
                        Text(
                          _dayAbbr(date.weekday),
                          style: TextStyle(
                            color: selected ? Colors.black : Colors.white70,
                            fontSize: 12,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          '${date.day}',
                          style: TextStyle(
                            color: selected ? Colors.black : Colors.white,
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              );
            }).toList(),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              _tabChip('habits', 'Habits'),
              const SizedBox(width: 8),
              _tabChip('tasks', 'Tasks'),
              const SizedBox(width: 8),
              _tabChip('bad', 'Bad Habits'),
            ],
          ),
        ],
      ),
    );
  }

  Widget _tabChip(String key, String label) {
    final selected = _tab == key;
    return Expanded(
      child: GestureDetector(
        onTap: () => setState(() => _tab = key),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 12),
          decoration: BoxDecoration(
            color: selected ? const Color(0xFF10B981) : const Color(0xFF121816),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: selected ? const Color(0xFF34D399) : Colors.white.withOpacity(0.1),
            ),
          ),
          child: Text(
            label,
            textAlign: TextAlign.center,
            style: TextStyle(
              color: selected ? Colors.black : Colors.white70,
              fontSize: 14,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ),
    );
  }

  Future<Map<String, bool>> _weekDone(String id, List<DateTime> dates) async {
    final prefs = await SharedPreferences.getInstance();
    final out = <String, bool>{};
    for (final d in dates) {
      final k = 'done:$id:${_ymd(d)}';
      out[_ymd(d)] = prefs.getBool(k) ?? false;
    }
    return out;
  }

  Future<void> _toggleComplete(String id, DateTime date) async {
    try {
      await HabitEngine.applyLocalTick(
        habitId: id,
        onApplied: (_, __) {},
      );
      HapticFeedback.selectionClick();
      await _load();
    } catch (_) {}
  }

  Widget _itemCard(Map<String, dynamic> item) {
    final color = _colorOf(item);
    final type = (item['type'] ?? 'habit').toString();
    final streak = item['streak'] ?? 0;
    final name = item['name'] ?? item['title'] ?? 'Untitled';

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF121816),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withOpacity(0.1)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: color,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(
                type == 'habit'
                    ? Icons.local_fire_department
                    : type == 'task'
                        ? Icons.check_box
                        : Icons.close,
                color: Colors.black,
                size: 20,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                name,
                style: const TextStyle(
                    color: Colors.white, fontSize: 18, fontWeight: FontWeight.w600),
              ),
            ),
            IconButton(
              onPressed: () => _openEdit(item),
              icon: Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: const Icon(Icons.settings, color: Colors.white, size: 16),
              ),
            ),
          ]),
          const SizedBox(height: 12),
          // Week rail
          FutureBuilder<Map<String, bool>>(
            future: _weekDone(item['id'].toString(), _weekDates),
            builder: (context, snap) {
              final data = snap.data ?? {};
              return Row(
                children: _weekDates.map((d) {
                  final key = _ymd(d);
                  final done = data[key] ?? false;

                  final schedule = HabitSchedule.fromJson(
                    (item['schedule'] as Map?)?.cast<String, dynamic>(),
                  );
                  final scheduled = schedule.isActiveOn(d);

                  return Expanded(
                    child: GestureDetector(
                      onTap: scheduled ? () => _toggleComplete(item['id'].toString(), d) : null,
                      child: Container(
                        margin: const EdgeInsets.symmetric(horizontal: 2),
                        height: 40,
                        decoration: BoxDecoration(
                          color: done ? const Color(0xFF10B981) : Colors.transparent,
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(
                            color: done
                                ? const Color(0xFF10B981)
                                : scheduled
                                    ? Colors.white.withOpacity(0.2)
                                    : Colors.transparent,
                            width: 2,
                          ),
                        ),
                        child: Center(
                          child: scheduled
                              ? Text(
                                  '${d.day}',
                                  style: TextStyle(
                                    color: done ? Colors.black : Colors.white,
                                    fontSize: 12,
                                    fontWeight: FontWeight.w600,
                                  ),
                                )
                              : Icon(Icons.remove,
                                  size: 12, color: Colors.white.withOpacity(0.1)),
                        ),
                      ),
                    ),
                  );
                }).toList(),
              );
            },
          ),
          if (type == 'habit') ...[
            const SizedBox(height: 8),
            Row(
              children: [
                const Icon(Icons.local_fire_department,
                    color: Color(0xFFF59E0B), size: 16),
                const SizedBox(width: 4),
                Text(
                  '${streak}d',
                  style: const TextStyle(color: Colors.white70, fontSize: 14),
                ),
              ],
            ),
          ],
          const SizedBox(height: 12),
          Row(
            children: [
              _chipBtn('Calendar', Icons.calendar_today, () => _openEdit(item)),
              const SizedBox(width: 8),
              _chipBtn('Stats', Icons.bar_chart, () {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Stats coming soon!')),
                );
              }),
              const Spacer(),
              _chipBtn('Delete', Icons.delete, () => _delete(item['id'].toString()),
                  color: const Color(0xFFE11D48)),
            ],
          ),
        ],
      ),
    );
  }

  Widget _chipBtn(String label, IconData icon, VoidCallback onTap, {Color? color}) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
        decoration: BoxDecoration(
          color: (color ?? Colors.white).withOpacity(0.1),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, color: color ?? Colors.white70, size: 16),
            const SizedBox(width: 4),
            Text(label, style: TextStyle(color: color ?? Colors.white70, fontSize: 12)),
          ],
        ),
      ),
    );
  }

  Widget _fabDial() {
    return Positioned(
      right: 20,
      bottom: 28,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (_showDial) ...[
            _dialItem('Add Habit', Icons.local_fire_department, const Color(0xFF10B981),
                () => _openCreate('habits')),
            const SizedBox(height: 12),
            _dialItem('Add Task', Icons.check_box, const Color(0xFF0EA5E9),
                () => _openCreate('tasks')),
            const SizedBox(height: 12),
            _dialItem('Add Bad Habit', Icons.close, const Color(0xFFE11D48),
                () => _openCreate('bad')),
            const SizedBox(height: 16),
          ],
          GestureDetector(
            onTap: () {
              setState(() => _showDial = !_showDial);
              if (_showDial) {
                _dialCtrl.forward();
              } else {
                _dialCtrl.reverse();
              }
            },
            child: Container(
              width: 64,
              height: 64,
              decoration: const BoxDecoration(
                color: Color(0xFF10B981),
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: Colors.black26,
                    blurRadius: 8,
                    offset: Offset(0, 4),
                  ),
                ],
              ),
              child: Icon(_showDial ? Icons.close : Icons.add, color: Colors.black, size: 24),
            ),
          ),
        ],
      ),
    );
  }

  Widget _dialItem(String label, IconData icon, Color color, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: color,
          borderRadius: BorderRadius.circular(12),
          boxShadow: const [
            BoxShadow(color: Colors.black26, blurRadius: 4, offset: Offset(0, 2)),
          ],
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, color: Colors.black, size: 16),
            const SizedBox(width: 8),
            Text(label,
                style: const TextStyle(
                    color: Colors.black, fontSize: 14, fontWeight: FontWeight.w600)),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Scaffold(
        backgroundColor: Color(0xFF0B0F0E),
        body: Center(child: CircularProgressIndicator(color: Color(0xFF10B981))),
      );
    }

    return Scaffold(
      backgroundColor: const Color(0xFF0B0F0E),
      body: Stack(
        children: [
          CustomScrollView(
            slivers: [
              SliverToBoxAdapter(child: _topBar()),
              SliverToBoxAdapter(child: _weekStrip()),
              const SliverToBoxAdapter(child: SizedBox(height: 24)),
              SliverList(
                delegate: SliverChildBuilderDelegate(
                  (context, i) => _itemCard(_filtered[i]),
                  childCount: _filtered.length,
                ),
              ),
              const SliverToBoxAdapter(child: SizedBox(height: 120)),
            ],
          ),
          _fabDial(),
          if (_showModal)
            HabitCreateEditModal(
              formData: _form,
              isEditing: _isEditing,
              onSave: _saveItem,
              onCancel: _closeModal,
              colorOptions: _colorOptions,
            ),
        ],
      ),
    );
  }
}
