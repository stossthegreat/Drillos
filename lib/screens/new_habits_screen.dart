// lib/screens/new_habits_screen.dart
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
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
  // Data
  List<dynamic> allItems = [];
  bool isLoading = true;

  // UI state
  DateTime selectedDate = DateTime.now();
  String currentFilter = 'habits'; // habits | tasks | bad
  bool showCreateModal = false;
  bool showSpeedDial = false;

  // Form state
  Map<String, dynamic> formData = {};
  bool isEditing = false;

  // Anim
  late AnimationController _speedDialController;
  late AnimationController _modalController;

  // Colors for chips / picker
  final List<Map<String, dynamic>> colorOptions = const [
    {'name': 'emerald', 'color': Color(0xFF10B981)},
    {'name': 'amber', 'color': Color(0xFFF59E0B)},
    {'name': 'sky', 'color': Color(0xFF0EA5E9)},
    {'name': 'rose', 'color': Color(0xFFE11D48)},
    {'name': 'violet', 'color': Color(0xFF8B5CF6)},
    {'name': 'slate', 'color': Color(0xFF64748B)},
  ];

  String formatDate(DateTime d) => d.toIso8601String().split('T')[0];

  List<DateTime> get weekDates {
    final start = selectedDate.subtract(
      Duration(days: selectedDate.weekday % 7),
    );
    return List.generate(7, (i) => start.add(Duration(days: i)));
  }

  @override
  void initState() {
    super.initState();
    _speedDialController =
        AnimationController(duration: const Duration(milliseconds: 200), vsync: this);
    _modalController =
        AnimationController(duration: const Duration(milliseconds: 300), vsync: this);
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
      'startDate': formatDate(DateTime.now()),
      'endDate': '',
      'frequency': 'daily',
      'everyN': 2,
      'color': 'emerald',
      'intensity': 2,
      'reminderOn': false,
      'reminderTime': '08:00',
      // voice/mentor fields are handled inside HabitCreateEditModal you already pasted
    };
  }

  Future<void> _loadData() async {
    setState(() => isLoading = true);
    try {
      await HabitEngine.checkStreakResets();

      final storage = localStorage;
      final habits = await storage.getAllHabits();

      final enriched = await Future.wait(habits.map((item) async {
        final id = item['id'];
        final type = item['type'] ?? 'habit';
        final streak = await storage.getStreak(id);
        final completed = await storage.isCompletedOn(id, DateTime.now());
        return {...item, 'streak': streak, 'completed': completed, 'type': type};
      }));

      if (!mounted) return;
      setState(() {
        allItems = enriched;
        isLoading = false;
      });
    } catch (_) {
      if (mounted) setState(() => isLoading = false);
    }
  }

  List<dynamic> get filteredItems {
    return allItems.where((item) {
      switch (currentFilter) {
        case 'tasks':
          return item['type'] == 'task';
        case 'bad':
          return item['type'] == 'bad';
        default:
          return item['type'] == 'habit' || item['type'] == null;
      }
    }).toList();
  }

  bool _isSameDay(DateTime a, DateTime b) =>
      a.year == b.year && a.month == b.month && a.day == b.day;

  Future<void> _toggleCompletion(String id, DateTime date) async {
    // ⛔ only allow completing on *today* (your request)
    if (!_isSameDay(date, DateTime.now())) {
      Toast.show(context, '⚠️ You can only complete today’s items.');
      return;
    }

    try {
      await HabitEngine.applyLocalTick(
        habitId: id,
        onApplied: (newStreak, _) {
          if (!mounted) return;
          setState(() {
            final idx = allItems.indexWhere((x) => x['id'] == id);
            if (idx != -1) {
              final current = Map<String, dynamic>.from(allItems[idx]);
              allItems[idx] = {...current, 'streak': newStreak, 'completed': true};
            }
          });
        },
      );
      apiClient.tickHabit(id, idempotencyKey: '${id}_${formatDate(date)}');
      HapticFeedback.selectionClick();
    } catch (_) {}
  }

  Future<void> _saveItem(Map<String, dynamic> data) async {
    if (data['name'].toString().trim().isEmpty) return;
    try {
      if (isEditing && data['id'] != null) {
        await habitService.updateHabit(data['id'], data);
        Toast.show(context, '✅ Updated');
      } else {
        final created = (data['type'] == 'task')
            ? await habitService.createTask(data)
            : await habitService.createHabit(data);

        // Schedule alarm if enabled
        if ((created['reminderEnabled'] == true) &&
            (created['reminderTime'] is String)) {
          final schedule = (created['schedule'] as Map?)?.cast<String, dynamic>();
          final days = (schedule?['daysOfWeek'] as List?)?.map((e) {
                if (e is int) return e;
                if (e is String) return int.tryParse(e);
                if (e is num) return e.toInt();
                return null;
              }).whereType<int>().toList() ??
              [1, 2, 3, 4, 5, 6, 7];

          await alarmService.scheduleAlarm(
            habitId: created['id'].toString(),
            habitName: created['title'] ?? created['name'] ?? 'Habit',
            time: created['reminderTime'] as String,
            daysOfWeek: days,
            mentorMessage:
                '⚡ Time to complete: ${created['title'] ?? created['name']}',
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
      // remove from storage & cancel notifications
      await habitService.deleteHabit(id);
      await alarmService.cancelAlarm(id);

      // local state refresh (belt + braces)
      final items = await localStorage.getAllHabits();
      items.removeWhere((x) => x['id'] == id);
      await localStorage.saveAllHabits(items);

      await _loadData();
      HapticFeedback.heavyImpact();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('✅ Deleted'), duration: Duration(seconds: 1)),
      );
    } catch (e) {
      Toast.show(context, 'Failed to delete: $e');
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
        'startDate': item['startDate'] ?? formatDate(DateTime.now()),
        'endDate': item['endDate'] ?? '',
        'frequency': item['frequency'] ?? 'daily',
        'everyN': item['everyN'] ?? 2,
        'color': item['color'] ?? 'emerald',
        'intensity': item['difficulty'] ?? item['intensity'] ?? 2,
        'reminderOn': item['reminderEnabled'] ?? false,
        'reminderTime': item['reminderTime'] ?? '08:00',
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

  // ---------------- UI ----------------

  @override
  Widget build(BuildContext context) {
    if (isLoading) {
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
              SliverToBoxAdapter(child: _buildTopBar()),
              SliverToBoxAdapter(child: _buildWeekStrip()),
              const SliverToBoxAdapter(child: SizedBox(height: 24)),
              SliverList(
                delegate: SliverChildBuilderDelegate(
                  (context, index) => _buildItemCard(filteredItems[index]),
                  childCount: filteredItems.length,
                ),
              ),
              const SliverToBoxAdapter(child: SizedBox(height: 120)),
            ],
          ),
          _buildSpeedDial(),
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

  Widget _buildTopBar() {
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
              await alarmService.scheduleAlarm(
                habitId: '__test_alarm__',
                habitName: 'Test Alarm',
                time: '08:00',
                daysOfWeek: [DateTime.now().weekday],
                mentorMessage: '🔔 This is your DrillOS test alarm.',
              );
              Toast.show(context, 'Test alarm scheduled for 08:00');
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

  Widget _buildWeekStrip() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Column(
        children: [
          Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
            IconButton(
              onPressed: () =>
                  setState(() => selectedDate = selectedDate.subtract(const Duration(days: 7))),
              icon: const Icon(Icons.chevron_left, color: Colors.white70),
            ),
            Text(
              '${_monthName(selectedDate.month)} ${selectedDate.year}',
              style: const TextStyle(color: Colors.white70, fontSize: 16),
            ),
            IconButton(
              onPressed: () =>
                  setState(() => selectedDate = selectedDate.add(const Duration(days: 7))),
              icon: const Icon(Icons.chevron_right, color: Colors.white70),
            ),
          ]),
          Row(
            children: weekDates.map((date) {
              final selected = formatDate(date) == formatDate(selectedDate);
              return Expanded(
                child: GestureDetector(
                  onTap: () => setState(() => selectedDate = date),
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
    final selected = currentFilter == key;
    return Expanded(
      child: GestureDetector(
        onTap: () => setState(() => currentFilter = key),
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

  String _monthName(int m) =>
      ['', 'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'][m];

  String _dayAbbr(int weekday) =>
      ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'][weekday - 1];

  Widget _buildItemCard(dynamic item) {
    final color = _colorFor(item);
    final type = item['type'] ?? 'habit';
    final streak = item['streak'] ?? 0;
    final completed = item['completed'] == true;

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
              decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(8)),
              child: Icon(
                type == 'habit'
                    ? Icons.local_fire_department
                    : type == 'task'
                        ? Icons.check_box
                        : Icons.close,
                color: Colors.black,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                item['name'] ?? item['title'] ?? 'Untitled',
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                  decoration: completed ? TextDecoration.lineThrough : null,
                ),
              ),
            ),
            if (item['reminderEnabled'] == true)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.08),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.notifications, size: 14, color: Color(0xFF10B981)),
                    const SizedBox(width: 4),
                    Text(
                      item['reminderTime'] ?? '08:00',
                      style: const TextStyle(color: Color(0xFF10B981), fontSize: 12),
                    ),
                  ],
                ),
              ),
            IconButton(
              onPressed: () => _openEditModal(item),
              icon: const Icon(Icons.settings, color: Colors.white, size: 20),
            ),
          ]),
          const SizedBox(height: 12),

          Row(
            children: [
              GestureDetector(
                onTap: () => _toggleCompletion(item['id'], selectedDate),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: completed ? Colors.green : color.withOpacity(0.3),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    completed ? 'Done' : 'Complete',
                    style: const TextStyle(color: Colors.white),
                  ),
                ),
              ),
              const Spacer(),
              GestureDetector(
                onTap: () => _deleteItem(item['id']),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: Colors.red.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Text(
                    'Delete',
                    style: TextStyle(
                      color: Colors.redAccent,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ),
            ],
          ),

          if (type != 'task') ...[
            const SizedBox(height: 8),
            Row(
              children: [
                const Icon(Icons.local_fire_department, color: Color(0xFFF59E0B), size: 16),
                const SizedBox(width: 6),
                Text(
                  '${streak}d streak',
                  style: const TextStyle(color: Colors.white70, fontSize: 14),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  // Floating add buttons (unchanged look)
  Widget _buildSpeedDial() {
    return Positioned(
      right: 20,
      bottom: 100,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (showSpeedDial) ...[
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
              setState(() => showSpeedDial = !showSpeedDial);
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
                boxShadow: [
                  BoxShadow(
                    color: Colors.black26,
                    blurRadius: 8,
                    offset: Offset(0, 4),
                  ),
                ],
              ),
              child: Icon(
                showSpeedDial ? Icons.close : Icons.add,
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
}
