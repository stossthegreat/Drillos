// lib/screens/new_habits_screen.dart
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../services/api_client.dart';
import '../services/local_storage.dart';
import '../services/habit_service.dart';
import '../services/alarm_service.dart';
import '../design/feedback.dart';
import '../widgets/habit_create_edit_modal.dart';
import '../logic/habit_engine.dart';
import '../utils/schedule.dart';

class NewHabitsScreen extends StatefulWidget {
  const NewHabitsScreen({super.key});

  @override
  State<NewHabitsScreen> createState() => _NewHabitsScreenState();
}

class _NewHabitsScreenState extends State<NewHabitsScreen>
    with TickerProviderStateMixin {
  // Core data
  List<Map<String, dynamic>> _allItems = [];
  bool _isLoading = true;

  // UI state
  DateTime _selectedDate = _startOfDay(DateTime.now());
  String _filterTab = 'habits'; // habits | tasks | bad
  bool _showCreateModal = false;
  bool _showSpeedDial = false;

  // Form state (passed to modal)
  Map<String, dynamic> _formData = {};
  bool _isEditing = false;

  // Animations
  late AnimationController _speedDialController;
  late AnimationController _modalController;

  // Colors (with bgColor for the modal’s swatches)
  final List<Map<String, dynamic>> _colorOptions = const [
    {'name': 'emerald', 'color': Color(0xFF10B981), 'bgColor': Color(0xFF10B981)},
    {'name': 'amber',   'color': Color(0xFFF59E0B), 'bgColor': Color(0xFFF59E0B)},
    {'name': 'sky',     'color': Color(0xFF0EA5E9), 'bgColor': Color(0xFF0EA5E9)},
    {'name': 'rose',    'color': Color(0xFFE11D48), 'bgColor': Color(0xFFE11D48)},
    {'name': 'violet',  'color': Color(0xFF8B5CF6), 'bgColor': Color(0xFF8B5CF6)},
    {'name': 'slate',   'color': Color(0xFF64748B), 'bgColor': Color(0xFF64748B)},
  ];

  // Mentor options (for create/edit modal)
  static const List<String> _mentorOptions = [
    'Standard',
    'Drill Sergeant',
    'Marcus Aurelius',
    'Confucius',
    'Buddha',
    'Abraham Lincoln',
  ];

  String _formatDate(DateTime d) => d.toIso8601String().split('T')[0];

  List<DateTime> get _weekDates {
    final start = _selectedDate.subtract(
      Duration(days: _selectedDate.weekday % 7),
    );
    return List.generate(7, (i) => _startOfDay(start.add(Duration(days: i))));
  }

  @override
  void initState() {
    super.initState();
    _speedDialController = AnimationController(
      duration: const Duration(milliseconds: 200),
      vsync: this,
    );
    _modalController = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );
    _resetForm();
    _loadData();
  }

  @override
  void dispose() {
    _speedDialController.dispose();
    _modalController.dispose();
    super.dispose();
  }

  // ------------------------------------------------------------
  // LOAD & FILTER
  // ------------------------------------------------------------
  Future<void> _loadData() async {
    setState(() => _isLoading = true);
    try {
      // Keep streaks sane (only needs to run for "today")
      await HabitEngine.checkStreakResets();

      final storage = localStorage;
      final all = await storage.getAllHabits();

      final List<Map<String, dynamic>> enriched = [];
      for (final raw in all) {
        final item = Map<String, dynamic>.from(raw);
        final id = item['id'].toString();
        final type = item['type'] ?? 'habit';

        if (type == 'habit') {
          final streak = await storage.getStreak(id);
          final completed = await storage.isCompletedOn(id, DateTime.now());
          enriched.add({...item, 'streak': streak, 'completed': completed, 'type': type});
        } else {
          // tasks / bad
          enriched.add({...item, 'type': type});
        }
      }

      // (Optional) merge backend tasks if you still pull them
      final tasks = await apiClient.getTasks().catchError((_) => <Map<String, dynamic>>[]);
      for (final t in tasks) {
        final tid = t['id']?.toString();
        if (tid != null && !enriched.any((i) => i['id'].toString() == tid)) {
          enriched.add({...t, 'type': 'task'});
        }
      }

      if (!mounted) return;
      setState(() {
        _allItems = enriched;
        _isLoading = false;
      });
    } catch (_) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  List<Map<String, dynamic>> get _filteredItems {
    return _allItems.where((item) {
      switch (_filterTab) {
        case 'tasks':
          return item['type'] == 'task';
        case 'bad':
          return item['type'] == 'bad' || item['category'] == 'anti-habit';
        default:
          return item['type'] == 'habit' || item['type'] == null;
      }
    }).toList();
  }

  // ------------------------------------------------------------
  // ACTIONS
  // ------------------------------------------------------------
  Future<void> _toggleCompletion(String id, DateTime date) async {
    // ❗Only allow completing "today"
    if (!_isSameDay(date, DateTime.now())) {
      HapticFeedback.heavyImpact();
      Toast.show(context, 'You can only complete today\'s mission.');
      return;
    }

    try {
      await HabitEngine.applyLocalTick(
        habitId: id,
        onApplied: (newStreak, _) {
          if (!mounted) return;
          setState(() {
            final idx = _allItems.indexWhere((x) => x['id'].toString() == id);
            if (idx != -1) {
              final b = Map<String, dynamic>.from(_allItems[idx]);
              _allItems[idx] = {...b, 'streak': newStreak, 'completed': true};
            }
          });
        },
      );
      apiClient.tickHabit(id, idempotencyKey: '${id}_${_formatDate(date)}');
      HapticFeedback.selectionClick();
    } catch (_) {
      // ignore
    }
  }

  Future<Map<String, bool>> _getWeekCompletionData(
    String habitId,
    List<DateTime> dates,
  ) async {
    final prefs = await SharedPreferences.getInstance();
    final out = <String, bool>{};
    for (final d in dates) {
      final key = 'done:$habitId:${_formatDate(d)}';
      out[_formatDate(d)] = prefs.getBool(key) ?? false;
    }
    return out;
  }

  Future<void> _saveItem(Map<String, dynamic> data) async {
    final name = (data['name'] ?? '').toString().trim();
    if (name.isEmpty) return;

    // Ensure we always carry a mentorVoice from modal; fallback default
    data['mentorVoice'] ??= 'Drill Sergeant';

    try {
      Map<String, dynamic> saved;
      if (_isEditing && data['id'] != null) {
        saved = await habitService.updateHabit(data['id'].toString(), data);
        Toast.show(context, '✅ Updated');
      } else {
        saved = (data['type'] == 'task')
            ? await habitService.createTask(data)
            : await habitService.createHabit(data);
        Toast.show(context, saved['type'] == 'task' ? '✅ Task created' : '✅ Habit created');

        // Schedule local alarm if requested
        if ((saved['reminderEnabled'] == true) && (saved['reminderTime'] is String)) {
          final schedule = (saved['schedule'] as Map?)?.cast<String, dynamic>();
          final days = (schedule?['daysOfWeek'] as List?)
                  ?.map((e) {
                    if (e is int) return e;
                    if (e is String) return int.tryParse(e);
                    if (e is num) return e.toInt();
                    return null;
                  })
                  .whereType<int>()
                  .toList() ??
              [1, 2, 3, 4, 5, 6, 7];

          final mentorVoice = (saved['mentorVoice'] ?? 'Drill Sergeant').toString();
          final msgPrefix = mentorVoice == 'Standard'
              ? '⏰'
              : mentorVoice == 'Drill Sergeant'
                  ? '🔥'
                  : '🎧';

          await alarmService.scheduleAlarm(
            habitId: saved['id'].toString(),
            habitName: saved['title'] ?? saved['name'] ?? 'Habit',
            time: saved['reminderTime'] as String,
            daysOfWeek: days,
            mentorMessage:
                '$msgPrefix ${mentorVoice == "Standard" ? "" : "[$mentorVoice] "}Time to complete: ${saved['title'] ?? saved['name']}',
          );
        }
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
      await alarmService.cancelAlarm(id);
      await _loadData();
      HapticFeedback.heavyImpact();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('✅ Deleted'), duration: Duration(seconds: 1)),
      );
    } catch (_) {
      // ignore
    }
  }

  void _openCreateModal(String type) {
    setState(() {
      _resetForm();
      _formData['type'] = type;
      _isEditing = false;
      _showCreateModal = true;
      _showSpeedDial = false;
    });
    _modalController.forward();
  }

  void _openEditModal(Map<String, dynamic> item) {
    setState(() {
      _formData = {
        'id': item['id'],
        'type': item['type'] ?? 'habit',
        'name': item['name'] ?? item['title'] ?? '',
        'category': item['category'] ?? 'General',
        'startDate': item['startDate'] ?? _formatDate(DateTime.now()),
        'endDate': item['endDate'] ?? '',
        'frequency': item['frequency'] ?? 'daily',
        'everyN': item['everyN'] ?? 2,
        'color': item['color'] ?? 'emerald',
        'intensity': item['difficulty'] ?? item['intensity'] ?? 2,
        'reminderOn': item['reminderEnabled'] ?? false,
        'reminderTime': item['reminderTime'] ?? '08:00',
        // mentorVoice default/fallback
        'mentorVoice': item['mentorVoice'] ?? 'Drill Sergeant',
      };
      _isEditing = true;
      _showCreateModal = true;
    });
    _modalController.forward();
  }

  void _closeModal() {
    _modalController.reverse().then((_) {
      setState(() {
        _showCreateModal = false;
        _resetForm();
      });
    });
  }

  void _resetForm() {
    _formData = {
      'id': null,
      'type': 'habit',
      'name': '',
      'category': 'General',
      'startDate': _formatDate(DateTime.now()),
      'endDate': '',
      'frequency': 'daily',
      'everyN': 2,
      'color': 'emerald',
      'intensity': 2,
      'reminderOn': false,
      'reminderTime': '08:00',
      // NEW: chosen mentor for alarm voice/message
      'mentorVoice': 'Drill Sergeant', // default
    };
  }

  // ------------------------------------------------------------
  // HELPERS
  // ------------------------------------------------------------
  static DateTime _startOfDay(DateTime d) => DateTime(d.year, d.month, d.day);

  static bool _isSameDay(DateTime a, DateTime b) =>
      a.year == b.year && a.month == b.month && a.day == b.day;

  Color _colorFor(Map<String, dynamic> item) {
    final n = item['color'] ?? 'emerald';
    return _colorOptions.firstWhere(
      (c) => c['name'] == n,
      orElse: () => _colorOptions[0],
    )['color'] as Color;
  }

  String _monthName(int m) =>
      ['', 'January', 'February', 'March', 'April', 'May', 'June',
        'July', 'August', 'September', 'October', 'November', 'December'][m];

  String _dayAbbr(int weekday) =>
      ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'][weekday - 1];

  // ------------------------------------------------------------
  // UI
  // ------------------------------------------------------------
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
          TextButton(
            onPressed: () async {
              // Temporary test alarm
              await alarmService.scheduleAlarm(
                habitId: '__test_alarm__',
                habitName: 'Test Alarm',
                time: '08:00',
                daysOfWeek: const [1, 2, 3, 4, 5, 6, 7],
                mentorMessage: '🔔 Test alarm fired.',
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
              onPressed: () => setState(() {
                _selectedDate = _startOfDay(_selectedDate.subtract(const Duration(days: 7)));
              }),
              icon: const Icon(Icons.chevron_left, color: Colors.white70),
            ),
            Text(
              '${_monthName(_selectedDate.month)} ${_selectedDate.year}',
              style: const TextStyle(color: Colors.white70, fontSize: 16),
            ),
            IconButton(
              onPressed: () => setState(() {
                _selectedDate = _startOfDay(_selectedDate.add(const Duration(days: 7)));
              }),
              icon: const Icon(Icons.chevron_right, color: Colors.white70),
            ),
          ]),
          Row(
            children: _weekDates.map((date) {
              final selected = _isSameDay(date, _selectedDate);
              return Expanded(
                child: GestureDetector(
                  onTap: () => setState(() => _selectedDate = date),
                  child: Container(
                    margin: const EdgeInsets.symmetric(horizontal: 2),
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    decoration: BoxDecoration(
                      color: selected ? const Color(0xFF10B981) : const Color(0xFF121816),
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
              _filterTab('habits', 'Habits'),
              const SizedBox(width: 8),
              _filterTab('tasks', 'Tasks'),
              const SizedBox(width: 8),
              _filterTab('bad', 'Bad Habits'),
            ],
          ),
        ],
      ),
    );
  }

  Widget _filterTab(String key, String label) {
    final selected = _filterTab == key;
    return Expanded(
      child: GestureDetector(
        onTap: () => setState(() => _filterTab = key),
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
    final itemType = (item['type'] ?? 'habit') as String;
    final streak = item['streak'] ?? 0;
    final intensity = item['difficulty'] ?? item['intensity'] ?? 1;

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
          // Header
          Row(children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: itemColor,
                borderRadius: BorderRadius.circular(8),
              ),
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
                    item['name'] ?? item['title'] ?? 'Untitled',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    '${item['category'] ?? 'General'} • Intensity $intensity',
                    style: const TextStyle(
                      color: Colors.white60,
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ),
            if (item['reminderEnabled'] == true) ...[
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.notifications, color: Color(0xFF10B981), size: 12),
                    const SizedBox(width: 4),
                    Text(
                      item['reminderTime'] ?? '08:00',
                      style: const TextStyle(
                        color: Color(0xFF10B981),
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
            ],
            IconButton(
              onPressed: () => _openEditModal(item),
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

          // Week rail (respect schedule + disable future)
          FutureBuilder<Map<String, bool>>(
            future: _getWeekCompletionData(item['id'].toString(), _weekDates),
            builder: (context, snapshot) {
              final completionData = snapshot.data ?? {};
              final schedule = HabitSchedule.fromJson(
                (item['schedule'] as Map?)?.cast<String, dynamic>(),
              );

              return Row(
                children: _weekDates.map((date) {
                  final dateKey = _formatDate(date);
                  final isCompleted = completionData[dateKey] ?? false;
                  final isScheduled = schedule.isActiveOn(date);
                  final isToday = _isSameDay(date, DateTime.now());
                  final canTap = isScheduled && isToday; // 🚫 future/past disabled

                  return Expanded(
                    child: GestureDetector(
                      onTap: canTap
                          ? () => _toggleCompletion(item['id'].toString(), date)
                          : null,
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
                                    ? (canTap
                                        ? Colors.white.withOpacity(0.25)
                                        : Colors.white.withOpacity(0.08))
                                    : Colors.transparent,
                            width: 2,
                          ),
                        ),
                        child: Center(
                          child: isScheduled
                              ? Text(
                                  '${date.day}',
                                  style: TextStyle(
                                    color: isCompleted
                                        ? Colors.black
                                        : (canTap ? Colors.white : Colors.white38),
                                    fontSize: 12,
                                    fontWeight: FontWeight.w600,
                                    decoration: (!canTap && isCompleted == false)
                                        ? TextDecoration.none
                                        : null,
                                  ),
                                )
                              : Icon(Icons.remove,
                                  size: 12, color: Colors.white.withOpacity(0.08)),
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

          // Actions
          Row(
            children: [
              _actionButton('Calendar', Icons.calendar_today, () {
                _openEditModal(item);
              }),
              const SizedBox(width: 8),
              _actionButton('Stats', Icons.bar_chart, () {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Stats coming soon!')),
                );
              }),
              const Spacer(),
              _actionButton(
                'Delete',
                Icons.delete,
                () => _deleteItem(item['id'].toString()),
                color: const Color(0xFFE11D48),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _actionButton(String label, IconData icon, VoidCallback onTap,
      {Color? color}) {
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
            Text(
              label,
              style: TextStyle(
                color: color ?? Colors.white70,
                fontSize: 12,
              ),
            ),
          ],
        ),
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
          if (_showSpeedDial) ...[
            _speedItem('Add Habit', Icons.local_fire_department,
                const Color(0xFF10B981), () => _openCreateModal('habit')),
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
              setState(() => _showCreateModal = false);
              setState(() => _showSpeedDial = !_showSpeedDial);
              if (_showSpeedDial) {
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
                boxShadow: [
                  BoxShadow(
                    color: Colors.black26,
                    blurRadius: 8,
                    offset: Offset(0, 4),
                  ),
                ],
              ),
              child: Icon(
                _showSpeedDial ? Icons.close : Icons.add,
                color: Colors.black,
                size: 24,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _speedItem(
    String label,
    IconData icon,
    Color color,
    VoidCallback onTap,
  ) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: color,
          borderRadius: BorderRadius.circular(12),
          boxShadow: const [
            BoxShadow(
              color: Colors.black26,
              blurRadius: 4,
              offset: Offset(0, 2),
            ),
          ],
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, color: Colors.black, size: 16),
            const SizedBox(width: 8),
            Text(
              label,
              style: const TextStyle(
                color: Colors.black,
                fontSize: 14,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ------------------------------------------------------------
  // BUILD
  // ------------------------------------------------------------
  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(
        backgroundColor: Color(0xFF0B0F0E),
        body: Center(
          child: CircularProgressIndicator(color: Color(0xFF10B981)),
        ),
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
                  (context, index) => _itemCard(_filteredItems[index]),
                  childCount: _filteredItems.length,
                ),
              ),
              const SliverToBoxAdapter(child: SizedBox(height: 120)),
            ],
          ),
          _speedDial(),

          if (_showCreateModal)
            HabitCreateEditModal(
              formData: {
                ..._formData,
                // Pass mentor options to the modal via formData (modal can read this)
                'mentorOptions': _mentorOptions,
              },
              isEditing: _isEditing,
              colorOptions: _colorOptions,
              onSave: _saveItem,
              onCancel: _closeModal,
            ),
        ],
      ),
    );
  }
}
