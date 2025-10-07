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
  List<Map<String, dynamic>> allItems = [];
  bool isLoading = true;

  // UI state
  DateTime selectedDate = DateTime.now();
  String filterTab = 'habits'; // habits | tasks | bad
  bool showCreateModal = false;
  bool showSpeedDial = false;

  // Form state
  Map<String, dynamic> formData = {};
  bool isEditing = false;

  // Animation controllers
  late AnimationController _speedDialController;
  late AnimationController _modalController;

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
    final start =
        selectedDate.subtract(Duration(days: selectedDate.weekday % 7));
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
    };
  }

  // ------------------ LOAD ------------------

  Future<void> _loadData() async {
    setState(() => isLoading = true);
    try {
      await HabitEngine.checkStreakResets();

      final storage = localStorage;
      final habits = await storage.getAllHabits();

      // ensure maps
      final local = habits.map((e) => Map<String, dynamic>.from(e)).toList();

      // attach streak + completed for habits
      for (final item in local) {
        if (item['type'] == 'task') continue;
        final id = item['id'];
        item['streak'] = await storage.getStreak(id);
        item['completed'] = await storage.isCompletedOn(id, DateTime.now());
      }

      // (Optional) merge with backend tasks (if your API returns some)
      final remoteTasks =
          await apiClient.getTasks().catchError((_) => <Map<String, dynamic>>[]);
      for (final t in remoteTasks) {
        if (!local.any((i) => i['id'] == t['id'])) {
          local.add({...t, 'type': 'task'});
        }
      }

      if (mounted) {
        setState(() {
          allItems = local;
          isLoading = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => isLoading = false);
    }
  }

  List<Map<String, dynamic>> get filteredItems {
    return allItems.where((item) {
      final t = (item['type'] ?? 'habit').toString();
      switch (filterTab) {
        case 'tasks':
          return t == 'task';
        case 'bad':
          return t == 'bad';
        default:
          return t == 'habit';
      }
    }).toList();
  }

  // ------------------ ACTIONS ------------------

  Future<void> _toggleCompletion(String id, DateTime date) async {
    try {
      await HabitEngine.applyLocalTick(
        habitId: id,
        onApplied: (newStreak, _) {
          if (!mounted) return;
          final idx = allItems.indexWhere((x) => x['id'] == id);
          if (idx != -1) {
            final b = Map<String, dynamic>.from(allItems[idx]);
            allItems[idx] = {...b, 'streak': newStreak, 'completed': true};
          }
          setState(() {});
        },
      );
      apiClient.tickHabit(id, idempotencyKey: '${id}_${formatDate(date)}');
      HapticFeedback.selectionClick();
    } catch (_) {}
  }

  Future<Map<String, bool>> _getWeekCompletionData(
    String habitId,
    List<DateTime> dates,
  ) async {
    final prefs = await SharedPreferences.getInstance();
    final out = <String, bool>{};
    for (final d in dates) {
      final key = 'done:$habitId:${formatDate(d)}';
      out[formatDate(d)] = prefs.getBool(key) ?? false;
    }
    return out;
  }

  Future<void> _saveItem(Map<String, dynamic> data) async {
    if (data['name'].toString().trim().isEmpty) return;

    try {
      Map<String, dynamic> created;
      if (isEditing && data['id'] != null) {
        created = await habitService.updateHabit(data['id'], data);
      } else {
        final type = (data['type'] ?? 'habit').toString();
        if (type == 'task') {
          created = await habitService.createTask(data);
        } else {
          // 'habit' or 'bad'
          created = await habitService.createHabit(data);
        }
      }

      // If reminder requested, schedule immediately (safe; AlarmService will fallback)
      if ((created['reminderEnabled'] == true) &&
          (created['reminderTime'] is String)) {
        final schedule =
            (created['schedule'] as Map?)?.cast<String, dynamic>();
        final days = (schedule?['daysOfWeek'] as List?)
                ?.map((e) => e is int
                    ? e
                    : e is String
                        ? int.tryParse(e) ?? 1
                        : (e as num).toInt())
                .toList() ??
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

      _closeModal();
      await _loadData();

      // After creation, switch to the correct tab so the user sees it.
      final createdType = (created['type'] ?? 'habit').toString();
      setState(() {
        filterTab = createdType == 'task'
            ? 'tasks'
            : createdType == 'bad'
                ? 'bad'
                : 'habits';
      });

      HapticFeedback.selectionClick();
    } catch (e) {
      Toast.show(context, 'Failed to save: $e');
    }
  }

  Future<void> _deleteItem(Map<String, dynamic> item) async {
    try {
      await habitService.deleteItem(
        item['id'].toString(),
        type: (item['type'] ?? 'habit').toString(),
      );
      await _loadData();
      HapticFeedback.heavyImpact();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('✅ Deleted'),
          duration: Duration(seconds: 1),
        ),
      );
    } catch (_) {
      // ignore
    }
  }

  void _openCreateModal(String type) {
    setState(() {
      _resetForm();
      formData['type'] = type; // 'habit' | 'task' | 'bad'
      isEditing = false;
      showCreateModal = true;
      showSpeedDial = false;
    });
    _modalController.forward();
  }

  void _openEditModal(Map<String, dynamic> item) {
    setState(() {
      formData = {
        'id': item['id'],
        'type': (item['type'] ?? 'habit').toString(),
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

  Color _colorFor(Map<String, dynamic> item) {
    final n = item['color'] ?? 'emerald';
    return colorOptions.firstWhere(
      (c) => c['name'] == n,
      orElse: () => colorOptions[0],
    )['color'] as Color;
  }

  // ------------------ UI ------------------

  Widget _buildTopBar() {
    return Container(
      padding: const EdgeInsets.fromLTRB(24, 16, 24, 8),
      child: const Row(
        children: [
          Text(
            'Daily Orders',
            style: TextStyle(
              color: Colors.white,
              fontSize: 24,
              fontWeight: FontWeight.bold,
            ),
          ),
          Spacer(),
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
              onPressed: () => setState(() {
                selectedDate = selectedDate.subtract(const Duration(days: 7));
              }),
              icon: const Icon(Icons.chevron_left, color: Colors.white70),
            ),
            Text(
              '${_monthName(selectedDate.month)} ${selectedDate.year}',
              style: const TextStyle(color: Colors.white70, fontSize: 16),
            ),
            IconButton(
              onPressed: () => setState(() {
                selectedDate = selectedDate.add(const Duration(days: 7));
              }),
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

  Widget _buildItemCard(Map<String, dynamic> item) {
    final itemColor = _colorFor(item);
    final itemType = (item['type'] ?? 'habit').toString();
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
          Row(children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: itemColor,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(
                itemType == 'task'
                    ? Icons.check_box
                    : itemType == 'bad'
                        ? Icons.close
                        : Icons.local_fire_department,
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

          // Week rail + completion
          FutureBuilder<Map<String, bool>>(
            future: _getWeekCompletionData(item['id'].toString(), weekDates),
            builder: (context, snapshot) {
              final completionData = snapshot.data ?? {};
              return Row(
                children: weekDates.map((date) {
                  final dateKey = formatDate(date);
                  final isCompleted = completionData[dateKey] ?? false;

                  final schedule = HabitSchedule.fromJson(
                    (item['schedule'] as Map?)?.cast<String, dynamic>(),
                  );
                  final isScheduled = schedule.isActiveOn(date);

                  return Expanded(
                    child: GestureDetector(
                      onTap: isScheduled
                          ? () => _toggleCompletion(item['id'].toString(), date)
                          : null,
                      child: Container(
                        margin: const EdgeInsets.symmetric(horizontal: 2),
                        height: 40,
                        decoration: BoxDecoration(
                          color:
                              isCompleted ? const Color(0xFF10B981) : Colors.transparent,
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
                                    color: isCompleted ? Colors.black : Colors.white,
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
                () => _deleteItem(item),
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

  // ---------- Speed Dial (bottom-right) ----------

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
              setState(() => showCreateModal = false);
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

  // ---------- Misc ----------

  String _monthName(int m) => const [
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
}
