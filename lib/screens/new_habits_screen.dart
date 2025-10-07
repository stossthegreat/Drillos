import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../services/local_storage.dart';
import '../services/habit_service.dart';
import '../services/alarm_service.dart';
import '../services/api_client.dart';

import '../logic/habit_engine.dart';
import '../utils/schedule.dart';
import '../widgets/habit_create_edit_modal.dart';
import '../design/feedback.dart';

class NewHabitsScreen extends StatefulWidget {
  const NewHabitsScreen({super.key});

  @override
  State<NewHabitsScreen> createState() => _NewHabitsScreenState();
}

class _NewHabitsScreenState extends State<NewHabitsScreen> {
  bool isLoading = true;
  DateTime selectedDate = _startOfDay(DateTime.now());

  List<Map<String, dynamic>> allItems = [];
  String filterKey = 'habits'; // habits | tasks | bad

  Map<String, dynamic> formData = {};
  bool isEditing = false;
  bool showCreateModal = false;

  final List<Map<String, dynamic>> colorOptions = const [
    {'name': 'emerald', 'color': Color(0xFF10B981)},
    {'name': 'amber', 'color': Color(0xFFF59E0B)},
    {'name': 'sky', 'color': Color(0xFF0EA5E9)},
    {'name': 'rose', 'color': Color(0xFFE11D48)},
    {'name': 'violet', 'color': Color(0xFF8B5CF6)},
    {'name': 'slate', 'color': Color(0xFF64748B)},
  ];

  @override
  void initState() {
    super.initState();
    _resetForm();
    _loadData();
  }

  static DateTime _startOfDay(DateTime d) => DateTime(d.year, d.month, d.day);
  String _ymd(DateTime d) => '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';
  bool _isToday(DateTime d) => d.year == DateTime.now().year && d.month == DateTime.now().month && d.day == DateTime.now().day;

  void _resetForm() {
    formData = {
      'id': null,
      'type': 'habit',
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
      'alarmVoice': 'drill_sergeant',
    };
  }

  Future<void> _loadData() async {
    setState(() => isLoading = true);
    try {
      await HabitEngine.checkStreakResets();

      final storage = localStorage;
      final raw = await storage.getAllHabits();

      final enriched = <Map<String, dynamic>>[];
      for (final r in raw) {
        final id = r['id'].toString();
        final completed = await storage.isCompletedOn(id, selectedDate);
        final streak = await storage.getStreak(id);
        enriched.add({
          ...r,
          'completed': completed,
          'streak': streak,
          'type': r['type'] ?? 'habit',
        });
      }

      setState(() {
        allItems = enriched;
        isLoading = false;
      });
    } catch (_) {
      setState(() => isLoading = false);
    }
  }

  // ---------- FILTERING ----------
  List<Map<String, dynamic>> get filteredItems {
    return allItems.where((item) {
      switch (filterKey) {
        case 'tasks':
          return item['type'] == 'task';
        case 'bad':
          return item['type'] == 'bad' || item['category'] == 'anti-habit';
        default:
          return item['type'] == 'habit' || item['type'] == null;
      }
    }).toList();
  }

  // ---------- COMPLETE ----------
  Future<void> _toggleCompletion(String id, DateTime date) async {
    if (!_isToday(date)) {
      Toast.show(context, 'You can only complete today');
      return;
    }

    try {
      await HabitEngine.applyLocalTick(
        habitId: id,
        onApplied: (newStreak, _) {
          final idx = allItems.indexWhere((e) => e['id'].toString() == id);
          if (idx != -1) {
            final copy = Map<String, dynamic>.from(allItems[idx]);
            setState(() {
              allItems[idx] = {...copy, 'completed': true, 'streak': newStreak};
            });
          }
        },
      );
      apiClient.tickHabit(id, idempotencyKey: '${id}_${_ymd(date)}');
      HapticFeedback.selectionClick();
    } catch (_) {}
  }

  Future<Map<String, bool>> _weekCompletion(String habitId, List<DateTime> dates) async {
    final prefs = await SharedPreferences.getInstance();
    final out = <String, bool>{};
    for (final d in dates) {
      out[_ymd(d)] = prefs.getBool('done:$habitId:${_ymd(d)}') ?? false;
    }
    return out;
  }

  // ---------- SAVE / DELETE ----------
  Future<void> _saveItem(Map<String, dynamic> data) async {
    if ((data['name'] ?? '').toString().trim().isEmpty) return;
    try {
      if (isEditing && data['id'] != null) {
        await habitService.updateHabit(data['id'].toString(), data);
        Toast.show(context, '✅ Updated');
      } else {
        final created = (data['type'] == 'task')
            ? await habitService.createTask(data)
            : await habitService.createHabit(data);

        if ((created['reminderEnabled'] == true) && (created['reminderTime'] is String)) {
          final schedule = (created['schedule'] as Map?)?.cast<String, dynamic>();
          final days = (schedule?['daysOfWeek'] as List?)?.map((e) {
                if (e is int) return e;
                if (e is String) return int.tryParse(e);
                if (e is num) return e.toInt();
                return null;
              }).whereType<int>().toList() ??
              [1, 2, 3, 4, 5, 6, 7];

          try {
            await alarmService.scheduleAlarm(
              habitId: created['id'].toString(),
              habitName: created['title'] ?? created['name'] ?? 'Habit',
              time: created['reminderTime'] as String,
              daysOfWeek: days,
              mentorMessage: '⚡ Time to complete: ${created['title'] ?? created['name']}',
            );
          } catch (_) {
            // ignore: fallback already handled inside service
          }
        }
      }
      setState(() => showCreateModal = false);
      _resetForm();
      await _loadData();
      HapticFeedback.selectionClick();
    } catch (e) {
      Toast.show(context, 'Failed to save: $e');
    }
  }

  Future<void> _deleteItem(String id) async {
    try {
      // Always cancel alarms + remove locally; backend delete is best-effort
      await alarmService.cancelAlarm(id);
      await localStorage.deleteHabit(id);
      await habitService.deleteHabit(id); // will swallow network errors internally
      Toast.show(context, '🗑️ Deleted');
      await _loadData();
      HapticFeedback.mediumImpact();
    } catch (e) {
      Toast.show(context, '❌ Failed to delete: $e');
    }
  }

  // ---------- UI ----------
  List<DateTime> get weekDates {
    final start = selectedDate.subtract(Duration(days: selectedDate.weekday % 7));
    return List.generate(7, (i) => _startOfDay(start.add(Duration(days: i))));
  }

  Color _colorOf(Map<String, dynamic> item) {
    final name = item['color'] ?? 'emerald';
    return (colorOptions.firstWhere(
      (c) => c['name'] == name,
      orElse: () => colorOptions[0],
    )['color'] as Color);
  }

  String _monthName(int m) => const [
        '', 'January', 'February', 'March', 'April', 'May', 'June',
        'July', 'August', 'September', 'October', 'November', 'December'
      ][m];

  String _dayAbbr(int w) => const ['', 'Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'][w];

  void _openCreate(String type) {
    setState(() {
      _resetForm();
      formData['type'] = type;
      isEditing = false;
      showCreateModal = true;
    });
  }

  void _openEdit(Map<String, dynamic> item) {
    setState(() {
      formData = {
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
        'alarmVoice': item['alarmVoice'] ?? 'drill_sergeant',
      };
      isEditing = true;
      showCreateModal = true;
    });
  }

  @override
  Widget build(BuildContext context) {
    if (isLoading) {
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
              // header
              SliverAppBar(
                backgroundColor: const Color(0xFF0B0F0E),
                elevation: 0,
                floating: true,
                title: const Text('Daily Orders',
                    style: TextStyle(fontWeight: FontWeight.w800)),
                actions: [
                  IconButton(
                    icon: const Icon(Icons.add),
                    onPressed: () => _openCreate('habit'),
                  ),
                ],
              ),
              // week strip + tabs
              SliverToBoxAdapter(
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Column(
                    children: [
                      Row(
                        children: [
                          IconButton(
                            onPressed: () async {
                              final d = _startOfDay(selectedDate.subtract(const Duration(days: 7)));
                              setState(() => selectedDate = d);
                              await _loadData();
                            },
                            icon: const Icon(Icons.chevron_left, color: Colors.white70),
                          ),
                          Expanded(
                            child: Center(
                              child: Text(
                                '${_monthName(selectedDate.month)} ${selectedDate.year}',
                                style: const TextStyle(color: Colors.white70, fontSize: 16),
                              ),
                            ),
                          ),
                          IconButton(
                            onPressed: () async {
                              final d = _startOfDay(selectedDate.add(const Duration(days: 7)));
                              setState(() => selectedDate = d);
                              await _loadData();
                            },
                            icon: const Icon(Icons.chevron_right, color: Colors.white70),
                          ),
                        ],
                      ),
                      Row(
                        children: weekDates.map((d) {
                          final isSel = _ymd(d) == _ymd(selectedDate);
                          return Expanded(
                            child: GestureDetector(
                              onTap: () async {
                                if (!isSel) {
                                  setState(() => selectedDate = d);
                                  await _loadData();
                                }
                              },
                              child: Container(
                                margin: const EdgeInsets.symmetric(horizontal: 2),
                                padding: const EdgeInsets.symmetric(vertical: 10),
                                decoration: BoxDecoration(
                                  color: isSel ? const Color(0xFF10B981) : const Color(0xFF121816),
                                  borderRadius: BorderRadius.circular(16),
                                  border: Border.all(
                                    color: isSel ? const Color(0xFF34D399) : Colors.white.withOpacity(0.1),
                                  ),
                                ),
                                child: Column(
                                  children: [
                                    Text(_dayAbbr(d.weekday),
                                        style: TextStyle(
                                          color: isSel ? Colors.black : Colors.white70,
                                          fontSize: 12,
                                        )),
                                    const SizedBox(height: 2),
                                    Text('${d.day}',
                                        style: TextStyle(
                                          color: isSel ? Colors.black : Colors.white,
                                          fontWeight: FontWeight.bold,
                                          fontSize: 16,
                                        )),
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
                          _tab('habits', 'Habits'),
                          const SizedBox(width: 8),
                          _tab('tasks', 'Tasks'),
                          const SizedBox(width: 8),
                          _tab('bad', 'Bad Habits'),
                        ],
                      ),
                      const SizedBox(height: 12),
                    ],
                  ),
                ),
              ),
              // list
              SliverList.builder(
                itemCount: filteredItems.length,
                itemBuilder: (context, i) => _itemCard(filteredItems[i]),
              ),
              const SliverToBoxAdapter(child: SizedBox(height: 120)),
            ],
          ),

          if (showCreateModal)
            HabitCreateEditModal(
              formData: formData,
              isEditing: isEditing,
              colorOptions: colorOptions,
              onSave: _saveItem,
              onCancel: () => setState(() => showCreateModal = false),
            ),
        ],
      ),
    );
  }

  Widget _tab(String key, String label) {
    final sel = filterKey == key;
    return Expanded(
      child: GestureDetector(
        onTap: () => setState(() => filterKey = key),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 12),
          decoration: BoxDecoration(
            color: sel ? const Color(0xFF10B981) : const Color(0xFF121816),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: sel ? const Color(0xFF34D399) : Colors.white.withOpacity(0.1)),
          ),
          child: Text(label,
              textAlign: TextAlign.center,
              style: TextStyle(
                color: sel ? Colors.black : Colors.white70,
                fontWeight: FontWeight.w600,
              )),
        ),
      ),
    );
  }

  Widget _itemCard(Map<String, dynamic> item) {
    final c = _colorOf(item);
    final type = item['type'] ?? 'habit';
    final title = item['name'] ?? item['title'] ?? 'Untitled';
    final intensity = item['difficulty'] ?? item['intensity'] ?? 1;
    final streak = item['streak'] ?? 0;

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
              width: 40, height: 40,
              decoration: BoxDecoration(color: c, borderRadius: BorderRadius.circular(8)),
              child: Icon(
                type == 'task' ? Icons.check_box : (type == 'bad' ? Icons.close : Icons.local_fire_department),
                color: Colors.black, size: 20,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(title, style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w600)),
                const SizedBox(height: 2),
                Text('Intensity $intensity',
                    style: const TextStyle(color: Colors.white60, fontSize: 12)),
              ]),
            ),
            if (item['reminderEnabled'] == true)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(color: Colors.white.withOpacity(0.1), borderRadius: BorderRadius.circular(8)),
                child: Row(mainAxisSize: MainAxisSize.min, children: [
                  const Icon(Icons.notifications, color: Color(0xFF10B981), size: 12),
                  const SizedBox(width: 4),
                  Text(item['reminderTime'] ?? '08:00',
                      style: const TextStyle(color: Color(0xFF10B981), fontSize: 12)),
                ]),
              ),
            IconButton(
              icon: const Icon(Icons.settings, size: 18),
              onPressed: () => _openEdit(item),
            ),
          ]),
          const SizedBox(height: 12),

          // week rail
          FutureBuilder<Map<String, bool>>(
            future: _weekCompletion(item['id'].toString(), weekDates),
            builder: (context, snap) {
              final done = snap.data ?? {};
              final schedule = HabitSchedule.fromJson((item['schedule'] as Map?)?.cast<String, dynamic>());

              return Row(
                children: weekDates.map((d) {
                  final k = _ymd(d);
                  final isCompleted = done[k] ?? false;
                  final isScheduled = schedule.isActiveOn(d);
                  final enabled = isScheduled && _isToday(d);

                  return Expanded(
                    child: GestureDetector(
                      onTap: enabled ? () => _toggleCompletion(item['id'].toString(), d) : null,
                      child: Container(
                        margin: const EdgeInsets.symmetric(horizontal: 2),
                        height: 40,
                        decoration: BoxDecoration(
                          color: isCompleted ? const Color(0xFF10B981) : Colors.transparent,
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(
                            color: isCompleted
                                ? const Color(0xFF10B981)
                                : isScheduled
                                    ? Colors.white.withOpacity(0.2)
                                    : Colors.transparent,
                            width: 2,
                          ),
                        ),
                        child: Center(
                          child: isScheduled
                              ? Text('${d.day}',
                                  style: TextStyle(
                                    color: isCompleted ? Colors.black : (enabled ? Colors.white : Colors.white54),
                                    fontSize: 12,
                                    fontWeight: FontWeight.w600,
                                  ))
                              : Icon(Icons.remove, size: 12, color: Colors.white.withOpacity(0.1)),
                        ),
                      ),
                    ),
                  );
                }).toList(),
              );
            },
          ),

          if (type != 'task') ...[
            const SizedBox(height: 8),
            Row(children: [
              const Icon(Icons.local_fire_department, color: Color(0xFFF59E0B), size: 16),
              const SizedBox(width: 4),
              Text('${streak}d', style: const TextStyle(color: Colors.white70, fontSize: 14)),
            ]),
          ],

          const SizedBox(height: 12),
          Row(children: [
            _chipBtn('Delete', Icons.delete, () => _deleteItem(item['id'].toString()),
                color: const Color(0xFFE11D48)),
            const SizedBox(width: 8),
            _chipBtn('Edit', Icons.edit, () => _openEdit(item)),
          ]),
        ],
      ),
    );
  }

  Widget _chipBtn(String label, IconData icon, VoidCallback onTap, {Color? color}) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        decoration: BoxDecoration(
          color: (color ?? Colors.white).withOpacity(0.1),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          Icon(icon, size: 16, color: color ?? Colors.white70),
          const SizedBox(width: 6),
          Text(label, style: TextStyle(color: color ?? Colors.white70, fontSize: 12)),
        ]),
      ),
    );
  }
}
