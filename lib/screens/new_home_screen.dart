import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../services/api_client.dart';
import '../services/habit_service.dart';
import '../design/feedback.dart';
import '../audio/tts_provider.dart';
import '../logic/habit_engine.dart';
import '../widgets/xp_hud.dart';

class NewHomeScreen extends StatefulWidget {
  final String? refreshTrigger;
  const NewHomeScreen({super.key, this.refreshTrigger});

  @override
  State<NewHomeScreen> createState() => _NewHomeScreenState();
}

class _NewHomeScreenState extends State<NewHomeScreen> with TickerProviderStateMixin {
  // Audio
  final tts = TtsProvider();

  // Data
  Map<String, dynamic> briefData = {};
  List<Map<String, dynamic>> todayItems = [];
  Map<String, dynamic>? currentNudge;
  bool isLoading = true;
  String? lastRefreshTrigger;

  // UI
  DateTime selectedDate = DateTime.now();
  late AnimationController _progressController;

  // Colors
  final List<Map<String, dynamic>> colorOptions = const [
    {'name': 'emerald', 'color': Color(0xFF10B981), 'neon': Color(0xFF34D399)},
    {'name': 'amber',   'color': Color(0xFFF59E0B), 'neon': Color(0xFFFBBF24)},
    {'name': 'sky',     'color': Color(0xFF0EA5E9), 'neon': Color(0xFF38BDF8)},
    {'name': 'rose',    'color': Color(0xFFE11D48), 'neon': Color(0xFFF43F5E)},
    {'name': 'violet',  'color': Color(0xFF8B5CF6), 'neon': Color(0xFFA78BFA)},
    {'name': 'slate',   'color': Color(0xFF64748B), 'neon': Color(0xFF94A3B8)},
  ];

  // Helpers
  String formatDate(DateTime d) => d.toIso8601String().split('T').first;
  List<DateTime> get weekDates {
    final start = selectedDate.subtract(Duration(days: selectedDate.weekday % 7));
    return List.generate(7, (i) => start.add(Duration(days: i)));
  }

  Color _colorForItem(Map<String, dynamic> item) {
    final name = item['color'] ?? 'emerald';
    return (colorOptions.firstWhere(
      (c) => c['name'] == name,
      orElse: () => colorOptions[0],
    )['color']) as Color;
  }

  Color _neonForItem(Map<String, dynamic> item) {
    final name = item['color'] ?? 'emerald';
    return (colorOptions.firstWhere(
      (c) => c['name'] == name,
      orElse: () => colorOptions[0],
    )['neon']) as Color;
  }

  @override
  void initState() {
    super.initState();
    _progressController = AnimationController(vsync: this, duration: const Duration(milliseconds: 800));
    lastRefreshTrigger = widget.refreshTrigger;
    _loadData();
  }

  @override
  void didUpdateWidget(covariant NewHomeScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.refreshTrigger != null && widget.refreshTrigger != lastRefreshTrigger) {
      lastRefreshTrigger = widget.refreshTrigger;
      _loadData();
    }
  }

  @override
  void dispose() {
    _progressController.dispose();
    super.dispose();
  }

  Future<void> _loadData() async {
    if (mounted) setState(() => isLoading = true);
    try {
      // Reset streaks that should break (local logic)
      await HabitEngine.checkStreakResets();

      // ✅ KEY: Only returns habits due TODAY (schedule already applied inside service)
      final items = await habitService.getTodayHabits();

      // Optional brief + nudge (non-blocking semantics preserved)
      final brief = await apiClient.getBrief().catchError((_) => <String, dynamic>{});
      Map<String, dynamic>? nudge;
      try {
        nudge = await apiClient.getNudge();
      } catch (_) {
        nudge = null;
      }

      final stats = await HabitEngine.getStats();

      if (!mounted) return;
      setState(() {
        todayItems = items.map((e) => Map<String, dynamic>.from(e)).toList();
        briefData = {...brief, 'stats': stats};
        currentNudge = nudge;
        isLoading = false;
      });

      _progressController.forward();
    } catch (e) {
      // Keep app running even if network fails
      if (mounted) setState(() => isLoading = false);
    }
  }

  // Unified completion handler for the visible list
  Future<void> _toggleTodayItemCompletion(Map<String, dynamic> item) async {
    try {
      final id = item['id'].toString();
      final type = (item['type'] ?? 'habit').toString();

      if (type == 'task') {
        // Local-first task completion
        if (mounted) {
          setState(() {
            final i = todayItems.indexWhere((x) => x['id'] == id);
            if (i != -1) todayItems[i] = {...todayItems[i], 'completed': true};
          });
        }
        await habitService.completeTaskLocal(id);
        apiClient.completeTask(id).catchError((_) {});
      } else {
        // Habit: mark complete immediately for snappy UI
        if (mounted) {
          setState(() {
            final i = todayItems.indexWhere((x) => x['id'] == id);
            if (i != -1) todayItems[i] = {...todayItems[i], 'completed': true};
          });
        }

        // Update streak/XP via local engine; then reflect streak in UI
        await HabitEngine.applyLocalTick(
          habitId: id,
          onApplied: (newStreak, newXp) {
            if (!mounted) return;
            setState(() {
              final i = todayItems.indexWhere((x) => x['id'] == id);
              if (i != -1) {
                final base = Map<String, dynamic>.from(todayItems[i]);
                todayItems[i] = {...base, 'streak': newStreak, 'completed': true};
              }
            });
          },
        );

        // Fire-and-forget server analytics
        apiClient.tickHabit(id, idempotencyKey: '${id}_${formatDate(DateTime.now())}');
      }

      HapticFeedback.selectionClick();
    } catch (e) {
      // soft-fail
    }
  }

  // ---------- UI ----------

  Widget _weekStrip() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Column(
        children: [
          Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
            IconButton(
              onPressed: () => setState(() => selectedDate = selectedDate.subtract(const Duration(days: 7))),
              icon: const Icon(Icons.chevron_left, color: Colors.white70),
            ),
            Text(
              '${_monthName(selectedDate.month)} ${selectedDate.year}',
              style: const TextStyle(color: Colors.white70, fontSize: 16, fontWeight: FontWeight.w600),
            ),
            IconButton(
              onPressed: () => setState(() => selectedDate = selectedDate.add(const Duration(days: 7))),
              icon: const Icon(Icons.chevron_right, color: Colors.white70),
            ),
          ]),
          const SizedBox(height: 8),
          Row(
            children: weekDates.map((date) {
              final isSelected = formatDate(date) == formatDate(selectedDate);
              return Expanded(
                child: GestureDetector(
                  onTap: () => setState(() => selectedDate = date),
                  child: Container(
                    margin: const EdgeInsets.symmetric(horizontal: 2),
                    padding: const EdgeInsets.symmetric(vertical: 10),
                    decoration: BoxDecoration(
                      color: isSelected ? const Color(0xFF10B981) : const Color(0xFF121816),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: isSelected ? const Color(0xFF34D399) : Colors.white.withOpacity(0.1),
                      ),
                    ),
                    child: Column(
                      children: [
                        Text(
                          _dayAbbr(date.weekday),
                          style: TextStyle(
                            color: isSelected ? Colors.black : Colors.white70,
                            fontSize: 12,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          '${date.day}',
                          style: TextStyle(
                            color: isSelected ? Colors.black : Colors.white,
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
        ],
      ),
    );
  }

  Widget _heroCard() {
    final stats = briefData['stats'] as Map<String, dynamic>? ?? {};
    final totalXP = (stats['totalXP'] ?? 0) as int;
    final longest = (stats['longestStreak'] ?? 0) as int;

    return Container(
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF0F201A), Color(0xFF12251E), Color(0xFF0F201A)],
          begin: Alignment.centerLeft,
          end: Alignment.centerRight,
        ),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: const Color(0xFF10B981).withOpacity(0.4)),
        boxShadow: [
          BoxShadow(color: const Color(0xFF10B981).withOpacity(0.1), blurRadius: 20, offset: const Offset(0, 8)),
        ],
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              const Text('DrillOS Status',
                  style: TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.bold)),
              const SizedBox(height: 6),
              Text('Longest streak $longest days',
                  style: const TextStyle(color: Colors.white70, fontSize: 14)),
              const SizedBox(height: 16),
              Container(
                height: 12,
                decoration: BoxDecoration(
                  color: Colors.black.withOpacity(0.4),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(6),
                  child: AnimatedBuilder(
                    animation: _progressController,
                    builder: (_, __) => LinearProgressIndicator(
                      value: _progressController.value * 0.65,
                      backgroundColor: Colors.transparent,
                      valueColor: const AlwaysStoppedAnimation(Color(0xFF10B981)),
                    ),
                  ),
                ),
              ),
            ]),
          ),
          Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
            Text(
              '$totalXP XP',
              style: const TextStyle(color: Colors.white, fontSize: 36, fontWeight: FontWeight.w900),
            ),
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: const Color(0xFFF59E0B).withOpacity(0.2),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.local_fire_department, color: Color(0xFFF59E0B), size: 16),
                  SizedBox(width: 4),
                  Text('Keep the streak', style: TextStyle(color: Color(0xFFF59E0B), fontSize: 12)),
                ],
              ),
            ),
          ]),
        ],
      ),
    );
  }

  Widget _nudgeCard() {
    if (currentNudge == null || currentNudge!['nudge'] == null) return const SizedBox.shrink();

    final message = currentNudge!['nudge'] as String;
    final mentorName = currentNudge!['mentor']?.toString() ?? 'Drill Sergeant';

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [const Color(0xFF10B981).withOpacity(0.12), const Color(0xFF34D399).withOpacity(0.06)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFF34D399).withOpacity(0.3)),
        boxShadow: [
          BoxShadow(color: const Color(0xFF10B981).withOpacity(0.1), blurRadius: 20, offset: const Offset(0, 8)),
        ],
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: const Color(0xFF10B981).withOpacity(0.2),
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Icon(Icons.military_tech_rounded, color: Color(0xFF10B981), size: 20),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(mentorName,
                style: const TextStyle(color: Color(0xFF34D399), fontSize: 14, fontWeight: FontWeight.w600)),
          ),
          if (currentNudge?['voice']?['url'] is String &&
              (currentNudge!['voice']['url'] as String).isNotEmpty)
            IconButton(
              icon: const Icon(Icons.volume_up, color: Colors.white70),
              onPressed: () async {
                try {
                  await tts.playFromUrl(currentNudge!['voice']['url'].toString());
                } catch (_) {}
              },
            ),
        ]),
        const SizedBox(height: 12),
        Text(
          message,
          style: const TextStyle(color: Colors.white, fontSize: 16, height: 1.4),
        ),
      ]),
    );
  }

  String _missionSummary() {
    final completed = todayItems.where((i) => i['completed'] == true).length;
    if (todayItems.isEmpty) return 'No missions for today 🎉';
    return '$completed / ${todayItems.length} complete';
  }

  Widget _focusCards() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Column(children: [
        // Focus
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: const Color(0xFF121816),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: Colors.white.withOpacity(0.1)),
          ),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: const [
              Text('Today\'s Focus',
                  style: TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.w600)),
              Spacer(),
              Icon(Icons.emoji_events, color: Color(0xFF10B981), size: 20),
            ]),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [const Color(0xFF10B981).withOpacity(0.2), const Color(0xFF34D399).withOpacity(0.1)],
                ),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                'Start with the highest-intensity mission for ${_dayName(selectedDate.weekday)}.',
                style: const TextStyle(color: Colors.white, fontSize: 14),
              ),
            ),
          ]),
        ),
        const SizedBox(height: 16),

        // Missions
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: const Color(0xFF121816),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: Colors.white.withOpacity(0.1)),
          ),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: const [
              Text('Today\'s Missions',
                  style: TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.w600)),
              Spacer(),
              Icon(Icons.check_box, color: Color(0xFFF59E0B), size: 20),
            ]),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [const Color(0xFFF59E0B).withOpacity(0.2), const Color(0xFFFBBF24).withOpacity(0.1)],
                ),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(_missionSummary(), style: const TextStyle(color: Colors.white, fontSize: 14)),
            ),
          ]),
        ),
      ]),
    );
  }

  Widget _todayItemsSection() {
    if (todayItems.isEmpty) {
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
            'No habits for today. Create one in the Habits tab!',
            style: TextStyle(color: Colors.white70, fontSize: 16),
            textAlign: TextAlign.center,
          ),
        ),
      );
    }

    final habits = todayItems.where((i) => (i['type'] ?? 'habit') == 'habit').toList();
    final tasks = todayItems.where((i) => i['type'] == 'task').toList();

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        if (habits.isNotEmpty) ...[
          const Text('Today\'s Habits',
              style: TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.w600)),
          const SizedBox(height: 12),
          ...habits.map(_todayItemCard),
          const SizedBox(height: 20),
        ],
        if (tasks.isNotEmpty) ...[
          const Text('Today\'s Tasks',
              style: TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.w600)),
          const SizedBox(height: 12),
          ...tasks.map(_todayItemCard),
        ],
      ]),
    );
  }

  Widget _todayItemCard(Map<String, dynamic> item) {
    final isCompleted = item['completed'] == true;
    final name = item['name'] ?? item['title'] ?? 'Habit';
    final streak = (item['streak'] ?? 0) as int;
    final color = _colorForItem(item);
    final neon = _neonForItem(item);
    final hasReminder = item['reminderEnabled'] == true;
    final reminderTime = item['reminderTime'];

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [color.withOpacity(0.2), color.withOpacity(0.1), const Color(0xFF121816)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: neon.withOpacity(0.6), width: 1.5),
        boxShadow: [
          BoxShadow(color: neon.withOpacity(0.25), blurRadius: 8, offset: const Offset(0, 2)),
        ],
      ),
      child: Row(children: [
        // Icon
        Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            color: isCompleted ? neon : color,
            borderRadius: BorderRadius.circular(8),
            boxShadow: [BoxShadow(color: (isCompleted ? neon : color).withOpacity(0.4), blurRadius: 6)],
          ),
          child: Icon(isCompleted ? Icons.check : Icons.local_fire_department, color: Colors.black, size: 20),
        ),
        const SizedBox(width: 12),

        // Text
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(
              name,
              style: TextStyle(
                color: Colors.white,
                fontSize: 16,
                fontWeight: FontWeight.w600,
                decoration: isCompleted ? TextDecoration.lineThrough : null,
              ),
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 4),
            Row(children: [
              Icon(Icons.local_fire_department, color: neon, size: 14),
              const SizedBox(width: 4),
              Text('$streak day streak', style: TextStyle(color: neon.withOpacity(0.85), fontSize: 12)),
              if (hasReminder && reminderTime != null) ...[
                const SizedBox(width: 12),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: neon.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: neon.withOpacity(0.6)),
                  ),
                  child: Row(mainAxisSize: MainAxisSize.min, children: [
                    Icon(Icons.alarm, color: neon, size: 12),
                    const SizedBox(width: 4),
                    Text(reminderTime.toString(),
                        style: TextStyle(color: neon, fontSize: 11, fontWeight: FontWeight.w600)),
                  ]),
                ),
              ],
            ]),
          ]),
        ),

        // Complete
        GestureDetector(
          onTap: () => _toggleTodayItemCompletion(item),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: isCompleted ? neon : color.withOpacity(0.3),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: neon.withOpacity(0.8)),
              boxShadow: [BoxShadow(color: neon.withOpacity(0.3), blurRadius: 4)],
            ),
            child: Text(
              isCompleted ? 'Done' : 'Complete',
              style: TextStyle(
                color: isCompleted ? Colors.black : Colors.white,
                fontSize: 12,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ),
      ]),
    );
  }

  String _monthName(int m) => const [
        '', 'January', 'February', 'March', 'April', 'May', 'June',
        'July', 'August', 'September', 'October', 'November', 'December'
      ][m];

  String _dayAbbr(int d) => const ['', 'Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'][d];

  String _dayName(int d) =>
      const ['', 'Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday', 'Saturday', 'Sunday'][d];

  @override
  Widget build(BuildContext context) {
    if (isLoading && briefData.isEmpty) {
      return const Scaffold(
        backgroundColor: Color(0xFF0B0F0E),
        body: Center(child: CircularProgressIndicator(color: Color(0xFF10B981))),
      );
    }

    final stats = briefData['stats'] as Map<String, dynamic>? ?? {};
    return Scaffold(
      backgroundColor: const Color(0xFF0B0F0E),
      body: RefreshIndicator(
        onRefresh: _loadData,
        child: CustomScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          slivers: [
            SliverAppBar(
              backgroundColor: const Color(0xFF0B0F0E),
              elevation: 0,
              floating: true,
              title: Row(children: [
                const Icon(Icons.auto_awesome, color: Color(0xFF10B981), size: 24),
                const SizedBox(width: 8),
                ShaderMask(
                  shaderCallback: (r) => const LinearGradient(
                    colors: [Color(0xFF10B981), Color(0xFFF59E0B)],
                  ).createShader(r),
                  child: const Text(
                    'Daily Orders',
                    style: TextStyle(fontSize: 28, fontWeight: FontWeight.w900, color: Colors.white),
                  ),
                ),
              ]),
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
                const SizedBox(width: 16),
              ],
            ),

            SliverList(
              delegate: SliverChildListDelegate([
                _weekStrip(),
                const SizedBox(height: 16),

                // Live stats HUD
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: XpHud(
                    totalXP: (stats['totalXP'] ?? 0) as int,
                    longestStreak: (stats['longestStreak'] ?? 0) as int,
                    completedToday: (stats['completedToday'] ?? 0) as int,
                    totalHabits: (stats['totalHabits'] ?? 0) as int,
                  ),
                ),
                const SizedBox(height: 24),

                _heroCard(),
                const SizedBox(height: 24),

                if (currentNudge != null && currentNudge!['nudge'] != null) ...[
                  _nudgeCard(),
                  const SizedBox(height: 24),
                ],

                _focusCards(),
                const SizedBox(height: 24),

                _todayItemsSection(),
                const SizedBox(height: 120),
              ]),
            ),
          ],
        ),
      ),
    );
  }
}
