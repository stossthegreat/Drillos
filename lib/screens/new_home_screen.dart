import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../services/local_storage.dart';
import '../services/habit_service.dart';
import '../services/api_client.dart';
import '../logic/habit_engine.dart';
import '../utils/schedule.dart';
import '../widgets/xp_hud.dart';
import '../design/feedback.dart';

class NewHomeScreen extends StatefulWidget {
  final String? refreshTrigger;
  const NewHomeScreen({super.key, this.refreshTrigger});

  @override
  State<NewHomeScreen> createState() => _NewHomeScreenState();
}

class _NewHomeScreenState extends State<NewHomeScreen>
    with TickerProviderStateMixin {
  // Data
  bool isLoading = true;
  DateTime selectedDate = _startOfDay(DateTime.now());
  List<Map<String, dynamic>> itemsForDay = [];
  Map<String, dynamic> briefData = {};
  Map<String, dynamic>? currentNudge;

  // Anim
  late AnimationController _progressController;

  // Colors
  final List<Map<String, dynamic>> colorOptions = const [
    {'name': 'emerald', 'color': Color(0xFF10B981), 'neon': Color(0xFF34D399)},
    {'name': 'amber', 'color': Color(0xFFF59E0B), 'neon': Color(0xFFFBBF24)},
    {'name': 'sky', 'color': Color(0xFF0EA5E9), 'neon': Color(0xFF38BDF8)},
    {'name': 'rose', 'color': Color(0xFFE11D48), 'neon': Color(0xFFF43F5E)},
    {'name': 'violet', 'color': Color(0xFF8B5CF6), 'neon': Color(0xFFA78BFA)},
    {'name': 'slate', 'color': Color(0xFF64748B), 'neon': Color(0xFF94A3B8)},
  ];

  // Services
  final _local = localStorage;
  final _habits = habitService;
  final _api = apiClient;

  @override
  void initState() {
    super.initState();
    _progressController =
        AnimationController(vsync: this, duration: const Duration(milliseconds: 800));
    _loadAll(selectedDate);
  }

  @override
  void didUpdateWidget(covariant NewHomeScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.refreshTrigger != oldWidget.refreshTrigger) {
      _loadAll(selectedDate);
    }
  }

  @override
  void dispose() {
    _progressController.dispose();
    super.dispose();
  }

  // ========================= LOADERS =========================

  Future<void> _loadAll(DateTime day) async {
    setState(() => isLoading = true);

    try {
      // Streak resets for "today" only
      if (_isSameDay(day, DateTime.now())) {
        await HabitEngine.checkStreakResets();
      }

      // 1) Build the list for the selected day from local storage only
      final all = await _local.getAllHabits();
      final List<Map<String, dynamic>> filtered = [];
      for (final raw in all) {
        final item = Map<String, dynamic>.from(raw);
        final type = item['type'] ?? 'habit';

        // Keep tasks too if you store them locally (same schedule rules)
        final sched = HabitSchedule.fromJson(
          (item['schedule'] as Map?)?.cast<String, dynamic>(),
        );

        final active = sched.isActiveOn(day);
        if (!active) continue;

        final completed = await _local.isCompletedOn(item['id'].toString(), day);
        final streak = await _local.getStreak(item['id'].toString());

        filtered.add({
          ...item,
          'completed': completed,
          'streak': streak,
          'type': type,
        });
      }

      // 2) Optional: pull brief + nudge (non-blocking if they fail)
      Map<String, dynamic> brief = {};
      Map<String, dynamic>? nudge;
      try {
        brief = await _api.getBrief();
      } catch (_) {}
      try {
        nudge = await _api.getNudge();
      } catch (_) {}

      if (!mounted) return;
      setState(() {
        itemsForDay = filtered;
        briefData = brief;
        currentNudge = nudge;
        isLoading = false;
      });

      _progressController.forward();
    } catch (e) {
      if (!mounted) return;
      setState(() => isLoading = false);
      // keep going quietly
    }
  }

  // ========================= ACTIONS =========================

  Future<void> _toggleItem(Map<String, dynamic> item) async {
    final id = item['id'].toString();
    final isHabit = (item['type'] ?? 'habit') == 'habit';

    // If the user is viewing today, use HabitEngine so streak/XP update correctly.
    final viewingToday = _isSameDay(selectedDate, DateTime.now());

    try {
      if (isHabit && viewingToday) {
        // Use HabitEngine for proper streak logic on "today"
        await HabitEngine.applyLocalTick(
          habitId: id,
          onApplied: (newStreak, newXp) {
            if (!mounted) return;
            setState(() {
              final idx = itemsForDay.indexWhere((x) => x['id'].toString() == id);
              if (idx != -1) {
                itemsForDay[idx] = {
                  ...itemsForDay[idx],
                  'completed': true,
                  'streak': newStreak,
                };
              }
            });
          },
        );
        // Fire-and-forget backend analytics
        _api.tickHabit(id, idempotencyKey: '${id}_${_ymd(selectedDate)}');
      } else {
        // For past/future dates (or tasks): toggle the per-day completion flag only.
        final prefs = await SharedPreferences.getInstance();
        final key = 'done:$id:${_ymd(selectedDate)}';
        final was = prefs.getBool(key) ?? false;
        final now = !was;

        if (now) {
          await prefs.setBool(key, true);
          await _local.setLastCompletionDate(id, selectedDate);
        } else {
          await prefs.remove(key);
        }

        if (!mounted) return;
        setState(() {
          final idx = itemsForDay.indexWhere((x) => x['id'].toString() == id);
          if (idx != -1) {
            itemsForDay[idx] = {
              ...itemsForDay[idx],
              'completed': now,
            };
          }
        });
      }

      HapticFeedback.selectionClick();

      // If the item just became completed for that day, hide it from the list
      // (people want to preview forward days with only scheduled, not already-done items)
      _pruneCompletedForSelectedDay();
    } catch (e) {
      // keep quiet
    }
  }

  void _pruneCompletedForSelectedDay() {
    setState(() {
      itemsForDay = itemsForDay.where((it) => it['completed'] != true).toList();
    });
  }

  // ========================= UI HELPERS =========================

  static DateTime _startOfDay(DateTime d) => DateTime(d.year, d.month, d.day);

  static bool _isSameDay(DateTime a, DateTime b) =>
      a.year == b.year && a.month == b.month && a.day == b.day;

  String _ymd(DateTime d) =>
      '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

  Color _colorOf(Map<String, dynamic> item) {
    final name = item['color'] ?? 'emerald';
    return (colorOptions.firstWhere(
      (c) => c['name'] == name,
      orElse: () => colorOptions[0],
    )['color'] as Color);
  }

  Color _neonOf(Map<String, dynamic> item) {
    final name = item['color'] ?? 'emerald';
    return (colorOptions.firstWhere(
      (c) => c['name'] == name,
      orElse: () => colorOptions[0],
    )['neon'] as Color);
  }

  List<DateTime> get _weekDates {
    final start = selectedDate.subtract(Duration(days: selectedDate.weekday % 7));
    return List.generate(7, (i) => _startOfDay(start.add(Duration(days: i))));
    }

  String _monthName(int m) =>
      const ['', 'January', 'February', 'March', 'April', 'May', 'June', 'July',
        'August', 'September', 'October', 'November', 'December'][m];

  String _dayAbbr(int w) =>
      const ['', 'Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'][w];

  // ========================= WIDGETS =========================

  Widget _weekStrip() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Column(
        children: [
          Row(
            children: [
              IconButton(
                onPressed: () async {
                  final d = _startOfDay(selectedDate.subtract(const Duration(days: 7)));
                  setState(() => selectedDate = d);
                  await _loadAll(d);
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
                  await _loadAll(d);
                },
                icon: const Icon(Icons.chevron_right, color: Colors.white70),
              ),
            ],
          ),
          Row(
            children: _weekDates.map((d) {
              final isSel = _isSameDay(d, selectedDate);
              return Expanded(
                child: GestureDetector(
                  onTap: () async {
                    if (!_isSameDay(d, selectedDate)) {
                      setState(() => selectedDate = d);
                      await _loadAll(d);
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
                        Text(
                          _dayAbbr(d.weekday),
                          style: TextStyle(
                            color: isSel ? Colors.black : Colors.white70,
                            fontSize: 12,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          '${d.day}',
                          style: TextStyle(
                            color: isSel ? Colors.black : Colors.white,
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              );
            }).toList(),
          ),
        ],
      ),
    );
  }

  Widget _xpHud() {
    final stats = briefData['stats'] ?? {};
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: XpHud(
        totalXP: (stats['totalXP'] ?? 0) as int,
        longestStreak: (stats['longestStreak'] ?? 0) as int,
        completedToday: (stats['completedToday'] ?? 0) as int,
        totalHabits: (stats['totalHabits'] ?? 0) as int,
      ),
    );
  }

  Widget _itemsList() {
    if (itemsForDay.isEmpty) {
      return Container(
        margin: const EdgeInsets.symmetric(horizontal: 16),
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: const Color(0xFF121816),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Colors.white.withOpacity(0.1)),
        ),
        child: const Center(
          child: Text(
            'No missions scheduled for this day.',
            style: TextStyle(color: Colors.white70, fontSize: 16),
            textAlign: TextAlign.center,
          ),
        ),
      );
    }

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Column(
        children: itemsForDay.map((it) => _itemCard(it)).toList(),
      ),
    );
  }

  Widget _itemCard(Map<String, dynamic> item) {
    final itemColor = _colorOf(item);
    final neon = _neonOf(item);
    final completed = item['completed'] == true;
    final streak = (item['streak'] ?? 0) as int;
    final title = item['name'] ?? item['title'] ?? 'Habit';

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [itemColor.withOpacity(0.18), itemColor.withOpacity(0.08), const Color(0xFF121816)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: neon.withOpacity(0.55), width: 1.4),
      ),
      child: Row(
        children: [
          // Icon
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: completed ? neon : itemColor,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(completed ? Icons.check : Icons.local_fire_department, color: Colors.black),
          ),
          const SizedBox(width: 12),

          // Texts
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    decoration: completed ? TextDecoration.lineThrough : null,
                  ),
                ),
                const SizedBox(height: 4),
                Row(
                  children: [
                    Icon(Icons.local_fire_department, color: neon, size: 14),
                    const SizedBox(width: 4),
                    Text('$streak day streak',
                        style: TextStyle(color: neon.withOpacity(0.85), fontSize: 12)),
                  ],
                ),
              ],
            ),
          ),

          // Button
          GestureDetector(
            onTap: () async {
              await _toggleItem(item);
              // After toggling, if completed, it will be pruned from the list
              // so users can flip through days and only see what's left to do.
            },
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: completed ? neon : itemColor.withOpacity(0.35),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: neon.withOpacity(0.8)),
              ),
              child: Text(
                completed ? 'Done' : 'Complete',
                style: TextStyle(
                  color: completed ? Colors.black : Colors.white,
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ========================= BUILD =========================

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
      body: RefreshIndicator(
        onRefresh: () => _loadAll(selectedDate),
        child: CustomScrollView(
          slivers: [
            SliverAppBar(
              backgroundColor: const Color(0xFF0B0F0E),
              elevation: 0,
              floating: true,
              title: Row(
                children: [
                  const Icon(Icons.auto_awesome, color: Color(0xFF10B981), size: 24),
                  const SizedBox(width: 8),
                  ShaderMask(
                    shaderCallback: (b) => const LinearGradient(
                      colors: [Color(0xFF10B981), Color(0xFFF59E0B)],
                    ).createShader(b),
                    child: const Text(
                      'Daily Orders',
                      style: TextStyle(fontSize: 28, fontWeight: FontWeight.w900, color: Colors.white),
                    ),
                  ),
                ],
              ),
              actions: [
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
                const SizedBox(width: 8),
              ],
            ),
            SliverList(
              delegate: SliverChildListDelegate([
                _weekStrip(),
                const SizedBox(height: 16),
                _xpHud(),
                const SizedBox(height: 16),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Text(
                    'Missions for ${_ymd(selectedDate)}',
                    style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w700),
                  ),
                ),
                const SizedBox(height: 12),
                _itemsList(),
                const SizedBox(height: 120),
              ]),
            ),
          ],
        ),
      ),
    );
  }
}
