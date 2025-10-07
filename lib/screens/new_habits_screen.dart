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

class _NewHabitsScreenState extends State<NewHabitsScreen>
    with TickerProviderStateMixin {
  // Data
  List<dynamic> allItems = [];
  bool isLoading = true;

  // UI state
  DateTime selectedDate = DateTime.now();
  String filterTab = 'habits'; // habits | tasks | bad
  bool showCreateModal = false;
  bool showSpeedDial = false;

  // Form state
  Map<String, dynamic> formData = {};
  bool isEditing = false;

  // Anim
  late AnimationController _speedDialController;
  late AnimationController _modalController;

  // Colors (keep your design)
  final List<Map<String, dynamic>> colorOptions = const [
    {'name': 'emerald', 'color': Color(0xFF10B981), 'bgColor': Color(0xFF10B981)},
    {'name': 'amber', 'color': Color(0xFFF59E0B), 'bgColor': Color(0xFFF59E0B)},
    {'name': 'sky', 'color': Color(0xFF0EA5E9), 'bgColor': Color(0xFF0EA5E9)},
    {'name': 'rose', 'color': Color(0xFFE11D48), 'bgColor': Color(0xFFE11D48)},
    {'name': 'violet', 'color': Color(0xFF8B5CF6), 'bgColor': Color(0xFF8B5CF6)},
    {'name': 'slate', 'color': Color(0xFF64748B), 'bgColor': Color(0xFF64748B)},
  ];

  String _ymd(DateTime d) =>
      '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

  List<DateTime> get weekDates {
    final start = selectedDate.subtract(Duration(days: selectedDate.weekday % 7));
    return List.generate(7, (i) => DateTime(start.year, start.month, start.day + i));
  }

  @override
  void initState() {
    super.initState();
    _speedDialController =
        AnimationController(vsync: this, duration: const Duration(milliseconds: 200));
    _modalController =
        AnimationController(vsync: this, duration: const Duration(milliseconds: 300));
    _resetForm();
    _loadData();
  }

  @override
  void dispose() {
    _speedDialController.dispose();
    _modalController.dispose();
    super.dispose();
  }

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
      // default mentor selection (used later for voice)
      'mentorId': 'drill_sergeant',
      'voicePreset': 'standard',
    };
  }

  Future<void> _loadData() async {
    setState(() => isLoading = true);
    try {
      await HabitEngine.checkStreakResets();

      // Local-only list (habits & tasks saved locally)
      final storage = localStorage;
      final items = await storage.getAllHabits();

      final enriched = await Future.wait(items.map((item) async {
        final id = item['id'].toString();
        final type = item['type'] ?? 'habit';
        final sched = HabitSchedule.fromJson((item['schedule'] as Map?)?.cast<String, dynamic>());
        final active = sched.isActiveOn(selectedDate);
        if (!active) return null;

        final completed = await storage.isCompletedOn(id, selectedDate);
        final streak = await storage.getStreak(id);
        return {
          ...item,
          'completed': completed,
          'streak': type == 'task' ? 0 : streak,
        };
      }));

      setState(() {
        allItems = enriched.whereType<Map<String, dynamic>>().toList();
        isLoading = false;
      });
    } catch (e) {
      setState(() => isLoading = false);
    }
  }

  List<dynamic> get filteredItems {
    return allItems.where((item) {
      final t = item['type'] ?? 'habit';
      switch (filterTab) {
        case 'tasks':
          return t == 'task';
        case 'bad':
          return t == 'bad' || item['category'] == 'anti-habit';
        default:
          return t == 'habit' || t == null;
      }
    }).toList();
  }

  Future<void> _toggleCompletion(String id, DateTime date, Map<String, dynamic> item) async {
    // Only allow completing on **today** (your requirement)
    final today = DateTime.now();
    final sameDay = today.year == date.year && today.month == date.month && today.day == date.day;
    if (!sameDay) {
      HapticFeedback.lightImpact();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("You can only complete items on today's date.")),
      );
      return;
    }

    final isHabit = (item['type'] ?? 'habit') == 'habit';

    try {
      if (isHabit) {
        // Proper streak handling for today
        await HabitEngine.applyLocalTick(
          habitId: id,
          onApplied: (newStreak, _) {
            if (!mounted) return;
            setState(() {
              final idx = allItems.indexWhere((x) => x['id'].toString() == id);
              if (idx != -1) {
                allItems[idx] = {
                  ...allItems[idx],
                  'streak': newStreak,
                  'completed': true,
                };
              }
            });
          },
        );
        apiClient.tickHabit(id, idempotencyKey: '${id}_${_ymd(date)}');
      } else {
        // Task or other: mark done for the day
        final prefs = await SharedPreferences.getInstance();
        await prefs.setBool('done:$id:${_ymd(date)}', true);
        if (!mounted) return;
        setState(() {
          final idx = allItems.indexWhere((x) => x['id'].toString() == id);
          if (idx != -1) {
            allItems[idx] = {
              ...allItems[idx],
              'completed': true,
            };
          }
        });
      }

      HapticFeedback.selectionClick();
      // Keep the card visible with a strikethrough (do NOT prune)
    } catch (_) {
      // silent
    }
  }

  Future<Map<String, bool>> _getWeekCompletionData(
    String habitId,
    List<DateTime> dates,
  ) async {
    final prefs = await SharedPreferences.getInstance();
    final out = <String, bool>{};
    for (final d in dates) {
      final key = 'done:$habitId:${_ymd(d)}';
      out[_ymd(d)] = prefs.getBool(key) ?? false;
    }
    return out;
  }

  Future<void> _saveItem(Map<String, dynamic> data) async {
    if ((data['name'] ?? '').toString().trim().isEmpty) return;
    try {
      Map<String, dynamic> saved;

      if (isEditing && data['id'] != null) {
        saved = await habitService.updateHabit(data['id'], data);
        Toast.show(context, '✅ Updated');
      } else {
        saved = (data['type'] == 'task')
            ? await habitService.createTask(data)
            : await habitService.createHabit(data);
        Toast.show(context, '✅ Created');
      }

      // Schedule reminder if enabled
      if ((saved['reminderEnabled'] == true) && (saved['reminderTime'] is String)) {
        final schedule = (saved['schedule'] as Map?)?.cast<String, dynamic>();
        final days = (schedule?['daysOfWeek'] as List?)
                ?.map((e) => (e is int) ? e : (e is String ? int.tryParse(e) : (e is num ? e.toInt() : null)))
                .whereType<int>()
                .toList() ??
            [1, 2, 3, 4, 5, 6, 7];

        await alarmService.requestPermissions();
        await alarmService.scheduleAlarm(
          habitId: saved['id'].toString(),
          habitName: saved['title'] ?? saved['name'] ?? 'Habit',
          time: saved['reminderTime'] as String,
          daysOfWeek: days,
          mentorMessage: '⚡ Time to complete: ${saved['title'] ?? saved['name']}',
        );
      }

      _closeModal();
      await _loadData();
      HapticFeedback.selectionClick();
    } catch (e) {
      Toast.show(context, 'Failed to save: $e');
    }
  }

  Future<void> _deleteItem(String id) async {
    try {
      await habitService.deleteHabit(id);
      await alarmService.cancelAlarm(id); // clean up notifications too
      await _loadData();
      HapticFeedback.heavyImpact();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('✅ Deleted'), duration: Duration(seconds: 1)),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to delete: $e')),
      );
    }
  }

  void _openCreateModal(String type) {
    setState(() {
      _resetForm();
      formData['type'] = type;
      isEditing = false;
      showCreateModal = true;
      showSpeedDial = false;
    });
    _modalController.forward();
  }

  void _openEditModal(dynamic item) {
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
        'mentorId': item['mentorId'] ?? 'drill_sergeant',
        'voicePreset': item['voicePreset'] ?? 'standard',
      };
      isEditing = true;
      showCreateModal = true;
    });
    _modalController.forward();
  }

  void _closeModal() {
    _modalController.reverse().then((_) {
      setState(() {
        showCreateModal = false;
        _resetForm();
      });
    });
  }

  Color _colorFor(dynamic item) {
    final n = item['color'] ?? 'emerald';
    return colorOptions.firstWhere(
      (c) => c['name'] == n,
      orElse: () => colorOptions[0],
    )['color'] as Color;
  }

  // ================= UI =================

  Widget _topBar() {
    return Container(
      padding: const EdgeInsets.fromLTRB(24, 16, 24, 8),
      child: Row(
        children: [
          const Text(
            'Daily Orders',
            style: TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.bold),
          ),
          const Spacer(),
          TextButton(
            onPressed: () async {
              await alarmService.requestPermissions();
              await alarmService.scheduleAlarm(
                habitId: '__test_alarm__',
                habitName: 'Test Alarm',
                time: '08:00',
                daysOfWeek: const [1, 2, 3, 4, 5, 6, 7],
                mentorMessage: '🔔 This is your DrillOS test alarm.',
              );
              if (!mounted) return;
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Test alarm scheduled')),
              );
            },
            child: const Text('Test Alarm', style: TextStyle(color: Colors.white70)),
          ),
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
              onPressed: () async {
                setState(() => selectedDate = selectedDate.subtract(const Duration(days: 7)));
                await _loadData();
              },
              icon: const Icon(Icons.chevron_left, color: Colors.white70),
            ),
            Text(
              '${_monthName(selectedDate.month)} ${selectedDate.year}',
              style: const TextStyle(color: Colors.white70, fontSize: 16),
            ),
            IconButton(
              onPressed: () async {
                setState(() => selectedDate = selectedDate.add(const Duration(days: 7)));
                await _loadData();
              },
              icon: const Icon(Icons.chevron_right, color: Colors.white70),
            ),
          ]),
          Row(
            children: weekDates.map((date) {
              final selected = _ymd(date) == _ymd(selectedDate);
              return Expanded(
                child: GestureDetector(
                  onTap: () async {
                    if (_ymd(date) != _ymd(selectedDate)) {
                      setState(() => selectedDate = date);
                      await _loadData();
                    }
                  },
                  child: Container(
                    margin: const EdgeInsets.symmetric(horizontal: 2),
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    decoration: BoxDecoration(
                      color: selected ? const Color(0xFF10B981) : const Color(0xFF121816),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: selected ? const Color(0xFF34D399) : Colors.white.withOpacity(0.1),
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
              _buildFilterTab('habits', 'Habits'),
              const SizedBox(width: 8),
              _buildFilterTab('tasks', 'Tasks'),
              const SizedBox(width: 8),
              _buildFilterTab('bad', 'Bad Habits'),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildFilterTab(String key, String label) {
    final selected = filterTab == key;
    return Expanded(
      child: GestureDetector(
        onTap: () => setState(() => filterTab = key),
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

  Widget _itemCard(Map<String, dynamic> item) {
    final itemColor = _colorFor(item);
    final itemType = item['type'] ?? 'habit';
    final completed = item['completed'] == true;
    final streak = (item['streak'] ?? 0) as int;
    final intensity = item['difficulty'] ?? item['intensity'] ?? 1;
    final title = item['name'] ?? item['title'] ?? 'Untitled';

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
          // header
          Row(children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(color: itemColor, borderRadius: BorderRadius.circular(8)),
              child: Icon(
                itemType == 'habit'
                    ? Icons.local_fire_department
                    : itemType == 'task'
                        ? Icons.check_box
                        : Icons.close,
                color: Colors.black,
                size: 20,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.w600,
                      decoration: completed ? TextDecoration.lineThrough : null,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    '${item['category'] ?? 'General'} • Intensity $intensity',
                    style: const TextStyle(color: Colors.white60, fontSize: 12),
                  ),
                ],
              ),
            ),
            if (item['reminderEnabled'] == true) ...[
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration:
                    BoxDecoration(color: Colors.white.withOpacity(0.1), borderRadius: BorderRadius.circular(8)),
                child: Row(mainAxisSize: MainAxisSize.min, children: [
                  const Icon(Icons.notifications, color: Color(0xFF10B981), size: 12),
                  const SizedBox(width: 4),
                  Text(item['reminderTime'] ?? '08:00',
                      style: const TextStyle(color: Color(0xFF10B981), fontSize: 12)),
                ]),
              ),
              const SizedBox(width: 8),
            ],
            IconButton(
              onPressed: () => _openEditModal(item),
              icon: Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(color: Colors.white.withOpacity(0.1), borderRadius: BorderRadius.circular(6)),
                child: const Icon(Icons.settings, color: Colors.white, size: 16),
              ),
            ),
          ]),

          const SizedBox(height: 12),

          // week rail (tap only toggles if scheduled AND is today)
          FutureBuilder<Map<String, bool>>(
            future: _getWeekCompletionData(item['id'].toString(), weekDates),
            builder: (context, snapshot) {
              final completionData = snapshot.data ?? {};
              final sched = HabitSchedule.fromJson((item['schedule'] as Map?)?.cast<String, dynamic>());

              return Row(
                children: weekDates.map((date) {
                  final dateKey = _ymd(date);
                  final isCompleted = completionData[dateKey] ?? false;
                  final isScheduled = sched.isActiveOn(date);
                  final isToday = _ymd(date) == _ymd(DateTime.now());

                  return Expanded(
                    child: GestureDetector(
                      onTap: (isScheduled && isToday)
                          ? () => _toggleCompletion(item['id'].toString(), date, item)
                          : null,
                      child: Container(
                        margin: const EdgeInsets.symmetric(horizontal: 2),
                        height: 40,
                        decoration: BoxDecoration(
                          color: isCompleted
                              ? const Color(0xFF10B981)
                              : completed && _ymd(date) == _ymd(selectedDate)
                                  ? const Color(0xFF10B981)
                                  : Colors.transparent,
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
                              ? Text(
                                  '${date.day}',
                                  style: TextStyle(
                                    color: (isCompleted ||
                                            (completed && _ymd(date) == _ymd(selectedDate)))
                                        ? Colors.black
                                        : Colors.white,
                                    fontSize: 12,
                                    fontWeight: FontWeight.w600,
                                    decoration: (completed && _ymd(date) == _ymd(selectedDate))
                                        ? TextDecoration.lineThrough
                                        : null,
                                  ),
                                )
                              : Icon(Icons.remove, size: 12, color: Colors.white.withOpacity(0.1)),
                        ),
                      ),
                    ),
                  );
                }).toList(),
              );
            },
          ),

          if (itemType != 'task') ...[
            const SizedBox(height: 8),
            Row(
              children: [
                const Icon(Icons.local_fire_department, color: Color(0xFFF59E0B), size: 16),
                const SizedBox(width: 4),
                Text(
                  '${streak}d',
                  style: const TextStyle(color: Colors.white70, fontSize: 14),
                ),
              ],
            ),
          ],

          const SizedBox(height: 12),

          // actions
          Row(
            children: [
              _actionButton('Calendar', Icons.calendar_today, () => _openEditModal(item)),
              const SizedBox(width: 8),
              _actionButton('Stats', Icons.bar_chart, () {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Stats coming soon!')),
                );
              }),
              const Spacer(),
              _actionButton('Delete', Icons.delete, () => _deleteItem(item['id'].toString()),
                  color: const Color(0xFFE11D48)),
            ],
          ),
        ],
      ),
    );
  }

  Widget _actionButton(String label, IconData icon, VoidCallback onTap, {Color? color}) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
        decoration: BoxDecoration(
          color: (color ?? Colors.white).withOpacity(0.1),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          Icon(icon, color: color ?? Colors.white70, size: 16),
          const SizedBox(width: 4),
          Text(label, style: TextStyle(color: color ?? Colors.white70, fontSize: 12)),
        ]),
      ),
    );
  }

  Widget _speedDial() {
    return Positioned(
      right: 20,
      bottom: 100,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (showSpeedDial) ...[
            _speedItem('Add Habit', Icons.local_fire_department, const Color(0xFF10B981),
                () => _openCreateModal('habit')),
            const SizedBox(height: 12),
            _speedItem('Add Task', Icons.check_box, const Color(0xFF0EA5E9),
                () => _openCreateModal('task')),
            const SizedBox(height: 12),
            _speedItem('Add Bad Habit', Icons.close, const Color(0xFFE11D48),
                () => _openCreateModal('bad')),
            const SizedBox(height: 16),
          ],
          GestureDetector(
            onTap: () {
              setState(() {
                showCreateModal = false;
                showSpeedDial = !showSpeedDial;
              });
              if (showSpeedDial) {
                _speedDialController.forward();
              } else {
                _speedDialController.reverse();
              }
            },
            child: Container(
              width: 64,
              height: 64,
              decoration: const BoxDecoration(
                color: Color(0xFF10B981),
                shape: BoxShape.circle,
                boxShadow: [BoxShadow(color: Colors.black26, blurRadius: 8, offset: Offset(0, 4))],
              ),
              child: Icon(showSpeedDial ? Icons.close : Icons.add, color: Colors.black, size: 24),
            ),
          ),
        ],
      ),
    );
  }

  Widget _speedItem(String label, IconData icon, Color color, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: color,
          borderRadius: BorderRadius.circular(12),
          boxShadow: const [BoxShadow(color: Colors.black26, blurRadius: 4, offset: Offset(0, 2))],
        ),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          Icon(icon, color: Colors.black, size: 16),
          const SizedBox(width: 8),
          Text(label, style: const TextStyle(color: Colors.black, fontSize: 14, fontWeight: FontWeight.w600)),
        ]),
      ),
    );
  }

  String _monthName(int m) =>
      const ['', 'January', 'February', 'March', 'April', 'May', 'June', 'July', 'August', 'September', 'October', 'November', 'December'][m];

  String _dayAbbr(int weekday) => const ['', 'Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'][weekday];

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
              SliverToBoxAdapter(child: _topBar()),
              SliverToBoxAdapter(child: _weekStrip()),
              const SliverToBoxAdapter(child: SizedBox(height: 24)),
              SliverList(
                delegate: SliverChildBuilderDelegate(
                  (context, index) => _itemCard(filteredItems[index] as Map<String, dynamic>),
                  childCount: filteredItems.length,
                ),
              ),
              const SliverToBoxAdapter(child: SizedBox(height: 120)),
            ],
          ),
          _speedDial(),

          if (showCreateModal)
            HabitCreateEditModal(
              formData: formData,
              isEditing: isEditing,
              colorOptions: colorOptions,
              onSave: _saveItem,
              onCancel: _closeModal,
            ),
        ],
      ),
    );
  }
}
