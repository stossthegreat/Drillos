import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../services/api_client.dart';
import '../services/local_storage.dart';
import '../services/habit_service.dart';
import '../design/feedback.dart';
import '../widgets/habit_create_edit_modal.dart';
import '../logic/habit_engine.dart';
import '../utils/schedule.dart';

class NewHabitsScreen extends StatefulWidget {
  const NewHabitsScreen({super.key});

  @override
  State<NewHabitsScreen> createState() => _NewHabitsScreenState();
}

class _NewHabitsScreenState extends State<NewHabitsScreen> with TickerProviderStateMixin {
  List<dynamic> allItems = [];
  bool isLoading = true;

  DateTime selectedDate = DateTime.now();
  String filterTab = 'habits';
  bool showCreateModal = false;
  bool showSpeedDial = false;

  Map<String, dynamic> formData = {};
  bool isEditing = false;

  late AnimationController _speedDialController;
  late AnimationController _modalController;

  final List<Map<String, dynamic>> colorOptions = [
    {'name': 'emerald', 'color': const Color(0xFF10B981)},
    {'name': 'amber', 'color': const Color(0xFFF59E0B)},
    {'name': 'sky', 'color': const Color(0xFF0EA5E9)},
    {'name': 'rose', 'color': const Color(0xFFE11D48)},
    {'name': 'violet', 'color': const Color(0xFF8B5CF6)},
    {'name': 'slate', 'color': const Color(0xFF64748B)},
  ];

  String formatDate(DateTime date) => date.toIso8601String().split('T')[0];

  List<DateTime> get weekDates {
    final startOfWeek = selectedDate.subtract(Duration(days: selectedDate.weekday % 7));
    return List.generate(7, (index) => startOfWeek.add(Duration(days: index)));
  }

  @override
  void initState() {
    super.initState();
    _speedDialController = AnimationController(vsync: this, duration: const Duration(milliseconds: 200));
    _modalController = AnimationController(vsync: this, duration: const Duration(milliseconds: 300));
    _loadData();
    _resetForm();
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

  Future<void> _loadData() async {
    setState(() => isLoading = true);
    try {
      await HabitEngine.checkStreakResets();
      final storage = localStorage;
      final habits = await storage.getAllHabits();

      final enriched = await Future.wait(habits.map((item) async {
        final id = item['id'];
        final type = item['type'] ?? 'habit';
        if (type == 'habit') {
          final streak = await storage.getStreak(id);
          final completed = await storage.isCompletedOn(id, DateTime.now());
          return {...item, 'streak': streak, 'completed': completed};
        }
        return item;
      }));

      final tasks = await apiClient.getTasks().catchError((_) => <Map<String, dynamic>>[]);
      final combined = [...enriched];
      for (final task in tasks) {
        if (!combined.any((i) => i['id'] == task['id'])) {
          combined.add({...task, 'type': 'task'});
        }
      }

      setState(() {
        allItems = combined;
        isLoading = false;
      });
    } catch (e) {
      print('❌ Error loading habits: $e');
      setState(() => isLoading = false);
    }
  }

  List<dynamic> get filteredItems {
    return allItems.where((item) {
      switch (filterTab) {
        case 'tasks':
          return item['type'] == 'task';
        case 'bad':
          return item['type'] == 'bad' || item['category'] == 'anti-habit';
        default:
          return item['type'] == 'habit' || item['type'] == null;
      }
    }).toList();
  }

  /// ✅ FIXED: Toggling completion works instantly and persists
  Future<void> _toggleCompletion(String itemId, DateTime date) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final key = 'done:$itemId:${formatDate(date)}';
      final wasDone = prefs.getBool(key) ?? false;
      final nowDone = !wasDone;

      await prefs.setBool(key, nowDone);

      // ✅ Update streak logic
      final streakKey = 'streak:$itemId';
      int currentStreak = prefs.getInt(streakKey) ?? 0;

      if (nowDone) {
        final lastDateStr = prefs.getString('lastComplete:$itemId');
        if (lastDateStr != null) {
          final lastDate = DateTime.tryParse(lastDateStr);
          final diff = lastDate == null ? 99 : date.difference(lastDate).inDays;
          currentStreak = (diff == 1) ? currentStreak + 1 : 1;
        } else {
          currentStreak = 1;
        }
        await prefs.setString('lastComplete:$itemId', date.toIso8601String());

        // XP
        final xpKey = 'xp:$itemId';
        final oldXp = prefs.getInt(xpKey) ?? 0;
        await prefs.setInt(xpKey, oldXp + 15);
      }

      await prefs.setInt(streakKey, currentStreak);

      // ✅ Update local cache and UI
      if (mounted) {
        setState(() {
          final idx = allItems.indexWhere((i) => i['id'] == itemId);
          if (idx != -1) {
            final base = Map<String, dynamic>.from(allItems[idx]);
            allItems[idx] = {...base, 'completed': nowDone, 'streak': currentStreak};
          }
        });
      }

      apiClient.tickHabit(itemId, idempotencyKey: '${itemId}_${formatDate(date)}');
      HapticFeedback.selectionClick();
    } catch (e) {
      print('❌ Error toggling completion: $e');
    }
  }

  Future<Map<String, bool>> _getWeekCompletionData(String habitId, List<DateTime> dates) async {
    final prefs = await SharedPreferences.getInstance();
    final completion = <String, bool>{};
    for (final date in dates) {
      final key = 'done:$habitId:${formatDate(date)}';
      completion[formatDate(date)] = prefs.getBool(key) ?? false;
    }
    return completion;
  }

  Future<void> _saveItem(Map<String, dynamic> data) async {
    if (data['name'].toString().trim().isEmpty) return;
    try {
      if (isEditing && data['id'] != null) {
        await habitService.updateHabit(data['id'], data);
        Toast.show(context, '✅ Updated!');
        _closeModal();
        await _loadData();
      } else {
        if (data['type'] == 'task') {
          await habitService.createTask(data);
        } else {
          await habitService.createHabit(data);
        }
        _closeModal();
        await _loadData();
        Toast.show(context, '✅ Created!');
      }
    } catch (e) {
      print('❌ Error saving: $e');
      Toast.show(context, 'Failed to save');
    }
  }

  Future<void> _deleteItem(String id) async {
    try {
      await habitService.deleteHabit(id);
      await _loadData();
      HapticFeedback.heavyImpact();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('✅ Deleted'), duration: Duration(seconds: 1)),
      );
    } catch (e) {
      print('❌ Delete error: $e');
    }
  }

  // 🧱 --- UI Helpers ---

  Color _getColorForItem(dynamic item) {
    final colorName = item['color'] ?? 'emerald';
    return colorOptions.firstWhere((c) => c['name'] == colorName, orElse: () => colorOptions[0])['color'];
  }

  Widget _buildTopBar() => Container(
        padding: const EdgeInsets.fromLTRB(24, 16, 24, 8),
        child: Row(
          children: [
            const Text('Daily Orders',
                style: TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.bold)),
            const Spacer(),
            IconButton(
              onPressed: () => Toast.show(context, 'Settings coming soon'),
              icon: const Icon(Icons.settings, color: Colors.white70),
            ),
          ],
        ),
      );

  Widget _buildWeekStrip() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Column(
        children: [
          Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
            IconButton(
              onPressed: () => setState(() => selectedDate = selectedDate.subtract(const Duration(days: 7))),
              icon: const Icon(Icons.chevron_left, color: Colors.white70),
            ),
            Text('${_monthName(selectedDate.month)} ${selectedDate.year}',
                style: const TextStyle(color: Colors.white70, fontSize: 16)),
            IconButton(
              onPressed: () => setState(() => selectedDate = selectedDate.add(const Duration(days: 7))),
              icon: const Icon(Icons.chevron_right, color: Colors.white70),
            ),
          ]),
          Row(
            children: weekDates.map((date) {
              final isSelected = formatDate(date) == formatDate(selectedDate);
              return Expanded(
                child: GestureDetector(
                  onTap: () => setState(() => selectedDate = date),
                  child: Container(
                    margin: const EdgeInsets.symmetric(horizontal: 2),
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    decoration: BoxDecoration(
                      color: isSelected ? const Color(0xFF10B981) : const Color(0xFF121816),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: isSelected ? const Color(0xFF34D399) : Colors.white.withOpacity(0.1),
                      ),
                    ),
                    child: Column(
                      children: [
                        Text(_dayAbbr(date.weekday),
                            style: TextStyle(
                                color: isSelected ? Colors.black : Colors.white70, fontSize: 12)),
                        const SizedBox(height: 2),
                        Text('${date.day}',
                            style: TextStyle(
                                color: isSelected ? Colors.black : Colors.white,
                                fontSize: 16,
                                fontWeight: FontWeight.bold)),
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
    final isSelected = filterTab == key;
    return Expanded(
      child: GestureDetector(
        onTap: () => setState(() => filterTab = key),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 12),
          decoration: BoxDecoration(
            color: isSelected ? const Color(0xFF10B981) : const Color(0xFF121816),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: isSelected ? const Color(0xFF34D399) : Colors.white.withOpacity(0.1),
            ),
          ),
          child: Text(label,
              textAlign: TextAlign.center,
              style: TextStyle(
                  color: isSelected ? Colors.black : Colors.white70,
                  fontSize: 14,
                  fontWeight: FontWeight.w600)),
        ),
      ),
    );
  }

  // 🔥 Core Card UI
  Widget _buildItemCard(dynamic item) {
    final itemColor = _getColorForItem(item);
    final itemType = item['type'] ?? 'habit';
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
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(item['name'] ?? item['title'] ?? 'Untitled',
                  style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w600)),
            ),
            IconButton(
              onPressed: () => _openEditModal(item),
              icon: const Icon(Icons.settings, color: Colors.white70, size: 20),
            ),
          ]),
          const SizedBox(height: 12),
          FutureBuilder<Map<String, bool>>(
            future: _getWeekCompletionData(item['id'].toString(), weekDates),
            builder: (context, snapshot) {
              final data = snapshot.data ?? {};
              return Row(
                children: weekDates.map((date) {
                  final dateKey = formatDate(date);
                  final isDone = data[dateKey] ?? false;
                  final schedule = HabitSchedule.fromJson((item['schedule'] as Map?)?.cast<String, dynamic>());
                  final isScheduled = schedule.isActiveOn(date);
                  return Expanded(
                    child: GestureDetector(
                      onTap: isScheduled ? () => _toggleCompletion(item['id'].toString(), date) : null,
                      child: Container(
                        margin: const EdgeInsets.symmetric(horizontal: 2),
                        height: 36,
                        decoration: BoxDecoration(
                          color: isDone ? const Color(0xFF10B981) : Colors.transparent,
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(
                            color: isDone
                                ? const Color(0xFF10B981)
                                : isScheduled
                                    ? Colors.white.withOpacity(0.2)
                                    : Colors.transparent,
                            width: 2,
                          ),
                        ),
                        child: Center(
                          child: isScheduled
                              ? Text('${date.day}',
                                  style: TextStyle(
                                      color: isDone ? Colors.black : Colors.white,
                                      fontWeight: FontWeight.w600,
                                      fontSize: 12))
                              : const Icon(Icons.remove, size: 12, color: Colors.white24),
                        ),
                      ),
                    ),
                  );
                }).toList(),
              );
            },
          ),
          const SizedBox(height: 8),
          Row(children: [
            const Icon(Icons.local_fire_department, color: Color(0xFFF59E0B), size: 16),
            const SizedBox(width: 4),
            Text('${streak}d', style: const TextStyle(color: Colors.white70, fontSize: 14)),
          ]),
        ],
      ),
    );
  }

  String _monthName(int m) => [
        '',
        'Jan',
        'Feb',
        'Mar',
        'Apr',
        'May',
        'Jun',
        'Jul',
        'Aug',
        'Sep',
        'Oct',
        'Nov',
        'Dec'
      ][m];
  String _dayAbbr(int d) => ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'][d - 1];

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
      body: Stack(children: [
        CustomScrollView(
          slivers: [
            SliverToBoxAdapter(child: _buildTopBar()),
            SliverToBoxAdapter(child: _buildWeekStrip()),
            const SliverToBoxAdapter(child: SizedBox(height: 24)),
            SliverList(
              delegate: SliverChildBuilderDelegate(
                (context, i) => _buildItemCard(filteredItems[i]),
                childCount: filteredItems.length,
              ),
            ),
            const SliverToBoxAdapter(child: SizedBox(height: 120)),
          ],
        ),
      ]),
    );
  }

  void _openEditModal(dynamic item) {
    setState(() {
      formData = {...item};
      isEditing = true;
      showCreateModal = true;
    });
    _modalController.forward();
  }

  void _closeModal() {
    _modalController.reverse().then((_) => setState(() => showCreateModal = false));
  }
}
