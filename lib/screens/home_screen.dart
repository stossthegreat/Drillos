import 'package:flutter/material.dart';
import '../services/api_client.dart';
import '../design/glass.dart';

class HomeScreen extends StatefulWidget {
  final String? refreshTrigger;
  
  const HomeScreen({super.key, this.refreshTrigger});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> with RouteAware {
  Map<String, dynamic> briefData = {};
  List<dynamic> todayItems = [];
  bool isLoading = true;
  String? lastRefreshTrigger;

  @override
  void initState() {
    super.initState();
    lastRefreshTrigger = widget.refreshTrigger;
    _loadBrief();
  }

  @override
  void didUpdateWidget(HomeScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    // Check if refresh trigger changed
    if (widget.refreshTrigger != null && 
        widget.refreshTrigger != lastRefreshTrigger) {
      print('🔄 Home screen refreshing due to habit selection');
      lastRefreshTrigger = widget.refreshTrigger;
      _loadBrief();
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Refresh data when this screen becomes active, but only if not currently loading
    if (!isLoading) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _loadBrief();
      });
    }
  }

  @override
  void didPopNext() {
    // Refresh when returning from another screen
    _loadBrief();
  }

  Future<void> _loadBrief() async {
    try {
      // Ensure API client has auth token
      apiClient.setAuthToken('valid-token');
      final brief = await apiClient.getBriefToday();
      
      print('📋 Brief loaded: ${brief.keys}');
      print('📋 Today items count: ${(brief['today'] as List?)?.length ?? 0}');
      print('📋 Raw today data: ${brief['today']}');
      
      // Fallback: if today is empty but habits exist, use a subset of habits as today
      List<dynamic> today = brief['today'] ?? [];

      // If brief does not include habits or is empty, load habits directly
      List<dynamic> habitsFromBrief = (brief['habits'] as List?) ?? [];
      if (habitsFromBrief.isEmpty) {
        try {
          habitsFromBrief = await apiClient.getHabits();
        } catch (e) {
          print('⚠️ Failed to load habits directly: $e');
        }
      }

      if (today.isEmpty && habitsFromBrief.isNotEmpty) {
        final habits = habitsFromBrief;
        print('📋 Today is empty, using fallback with ${habits.length} habits');
        // Use first 3 habits as today's items for now
        today = habits.take(3).map((habit) => {
          'id': habit['id'],
          'name': habit['title'] ?? habit['name'],
          'type': 'habit',
          'completed': habit['status'] == 'completed_today' || habit['status'] == 'completed',
          'streak': habit['streak'] ?? 0,
          'color': habit['color'] ?? 'emerald',
          'reminderEnabled': habit['reminderEnabled'] ?? false,
          'reminderTime': habit['reminderTime'],
        }).toList();
        print('📋 Fallback today items: ${today.length}');
        // Ensure brief has habits for preview section
        brief['habits'] = habitsFromBrief;
      }
      
      setState(() {
        briefData = brief;
        todayItems = today;
        isLoading = false;
      });
    } catch (e) {
      print('❌ Error loading brief: $e');
      setState(() {
        isLoading = false;
      });
    }
  }

  Future<void> _completeTodayItem(Map<String, dynamic> item) async {
    try {
      if (item['type'] == 'habit') {
        await apiClient.tickHabit(item['id']);
      } else {
        await apiClient.completeTask(item['id']); // Use correct task completion method
      }
      
      // Remove from today backend list but keep in UI as completed
      await apiClient.deselectForToday(item['id']);
      
      setState(() {
        // Mark as completed instead of removing
        final index = todayItems.indexWhere((i) => i['id'] == item['id']);
        if (index != -1) {
          todayItems[index]['completed'] = true;
        }
      });
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('✅ ${item['name']} completed!')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error completing item: $e')),
        );
      }
    }
  }

  Future<void> _removeTodayItem(Map<String, dynamic> item) async {
    try {
      await apiClient.deselectForToday(item['id']);
      setState(() {
        todayItems.removeWhere((i) => i['id'] == item['id']);
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Removed ${item['name']} from today')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error removing item: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (isLoading && briefData.isEmpty) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    final user = briefData['user'] ?? {};
    final missions = briefData['missions'] ?? [];
    final riskBanners = briefData['riskBanners'] ?? [];
    final weeklyTarget = briefData['weeklyTarget'] ?? {};
    final streaksSummary = briefData['streaksSummary'] ?? {};
    final nudges = briefData['nudges'] ?? [];

    return Scaffold(
      backgroundColor: const Color(0xFF1A1A1A),
      body: RefreshIndicator(
        onRefresh: () async => _loadBrief(),
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            const SizedBox(height: 40),
            
            // Header with Rank and XP
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(0xFF2D1B69), Color(0xFF11998E)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Row(
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Rank: ${user['rank'] ?? 'Sergeant'}',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Level ${user['level'] ?? 1}',
                        style: const TextStyle(
                          color: Colors.white70,
                          fontSize: 16,
                        ),
                      ),
                    ],
                  ),
                  const Spacer(),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(
                        '${user['xp'] ?? 0} XP',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Overall Streak: ${streaksSummary['overall'] ?? 0} days',
                        style: const TextStyle(
                          color: Colors.white70,
                          fontSize: 14,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            
            const SizedBox(height: 24),
            
            // Risk Banners
            if (riskBanners.isNotEmpty) ...[
              for (var banner in riskBanners)
                Container(
                  margin: const EdgeInsets.only(bottom: 12),
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.red.withOpacity(0.1),
                    border: Border.all(color: Colors.red.withOpacity(0.3)),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.warning, color: Colors.red),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          banner['message'] ?? '',
                          style: const TextStyle(
                            color: Colors.red,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
            ],
            
            // Weekly Target
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: const Color(0xFF2A2A2A),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Weekly Target',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: LinearProgressIndicator(
                          value: (weeklyTarget['current'] ?? 0) / (weeklyTarget['goal'] ?? 1),
                          backgroundColor: Colors.grey.withOpacity(0.3),
                          valueColor: const AlwaysStoppedAnimation<Color>(Color(0xFF11998E)),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Text(
                        '${weeklyTarget['current'] ?? 0}/${weeklyTarget['goal'] ?? 0}',
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            
            const SizedBox(height: 24),
            
            // Missions
            const Text(
              'Today\'s Missions',
              style: TextStyle(
                color: Colors.white,
                fontSize: 20,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 12),
            
            if (missions.isEmpty)
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: const Color(0xFF2A2A2A),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Text(
                  'No missions for today! 🎉',
                  style: TextStyle(
                    color: Colors.white70,
                    fontSize: 16,
                  ),
                ),
              )
            else
              for (var mission in missions)
                Container(
                  margin: const EdgeInsets.only(bottom: 12),
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: const Color(0xFF2A2A2A),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: mission['status'] == 'completed' 
                        ? Colors.green.withOpacity(0.3)
                        : Colors.blue.withOpacity(0.3),
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              mission['title'] ?? '',
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                            decoration: BoxDecoration(
                              color: mission['status'] == 'completed' 
                                ? Colors.green.withOpacity(0.2)
                                : Colors.blue.withOpacity(0.2),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Text(
                              mission['status'] ?? 'pending',
                              style: TextStyle(
                                color: mission['status'] == 'completed' 
                                  ? Colors.green
                                  : Colors.blue,
                                fontSize: 12,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          const Icon(Icons.local_fire_department, color: Colors.orange, size: 16),
                          const SizedBox(width: 4),
                          Text(
                            '${mission['streak'] ?? 0} day streak',
                            style: const TextStyle(
                              color: Colors.white70,
                              fontSize: 14,
                            ),
                          ),
                          const Spacer(),
                          Text(
                            'Next milestone: ${mission['nextMilestone'] ?? 0} days',
                            style: const TextStyle(
                              color: Colors.white70,
                              fontSize: 14,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
            
            const SizedBox(height: 24),
            
            // Streaks Summary
            if (streaksSummary['categories'] != null && (streaksSummary['categories'] as List).isNotEmpty) ...[
              const Text(
                'Streak Categories',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 12),
              for (var category in streaksSummary['categories'])
                Container(
                  margin: const EdgeInsets.only(bottom: 8),
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: const Color(0xFF2A2A2A),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(
                          category['name'] ?? '',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 16,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                      Text(
                        '${category['days'] ?? 0} days',
                        style: const TextStyle(
                          color: Colors.orange,
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ),
            ],
            
            const SizedBox(height: 24),
            
            // Nudges
            if (nudges.isNotEmpty) ...[
              const Text(
                'Nudges',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 12),
              for (var nudge in nudges)
                Container(
                  margin: const EdgeInsets.only(bottom: 12),
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: nudge['priority'] == 'high' 
                      ? Colors.orange.withOpacity(0.1)
                      : Colors.blue.withOpacity(0.1),
                    border: Border.all(
                      color: nudge['priority'] == 'high' 
                        ? Colors.orange.withOpacity(0.3)
                        : Colors.blue.withOpacity(0.3),
                    ),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        nudge['title'] ?? '',
                        style: TextStyle(
                          color: nudge['priority'] == 'high' ? Colors.orange : Colors.blue,
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        nudge['message'] ?? '',
                        style: const TextStyle(
                          color: Colors.white70,
                          fontSize: 14,
                        ),
                      ),
                    ],
                  ),
                ),
            ],
            
            const SizedBox(height: 24),
            
            // Today Items Section
            GlassCard(
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(
                          Icons.today,
                          color: Colors.blue[300],
                          size: 24,
                        ),
                        const SizedBox(width: 12),
                        const Text(
                          'Today\'s Focus',
                          style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    if (todayItems.isEmpty)
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: Colors.grey[800]?.withOpacity(0.3),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: Colors.grey[600]!.withOpacity(0.3),
                          ),
                        ),
                        child: const Text(
                          'No items for today. Add habits or tasks from the Habits tab.',
                          style: TextStyle(
                            color: Colors.grey,
                            fontSize: 14,
                          ),
                          textAlign: TextAlign.center,
                        ),
                      )
                    else
                      ...todayItems.map((item) {
                        final isCompleted = item['completed'] == true;
                        return Container(
                          margin: const EdgeInsets.only(bottom: 8),
                          child: Row(
                            children: [
                              Expanded(
                                child: Container(
                                  padding: const EdgeInsets.all(12),
                                  decoration: BoxDecoration(
                                    color: isCompleted 
                                        ? Colors.green[800]?.withOpacity(0.3)
                                        : Colors.grey[800]?.withOpacity(0.3),
                                    borderRadius: BorderRadius.circular(8),
                                    border: isCompleted ? Border.all(
                                      color: Colors.green[600]!.withOpacity(0.5),
                                      width: 1,
                                    ) : null,
                                  ),
                                  child: Row(
                                    children: [
                                      Icon(
                                        isCompleted 
                                            ? Icons.check_circle
                                            : (item['type'] == 'habit' 
                                                ? Icons.fitness_center 
                                                : Icons.task_alt),
                                        color: isCompleted 
                                            ? Colors.green[300]
                                            : Colors.blue[300],
                                        size: 18,
                                      ),
                                      const SizedBox(width: 8),
                                      Expanded(
                                        child: Text(
                                          isCompleted 
                                              ? '✅ ${item['name'] ?? 'Item'}'
                                              : item['name'] ?? 'Item',
                                          style: TextStyle(
                                            color: isCompleted 
                                                ? Colors.green[200]
                                                : Colors.white,
                                            fontSize: 14,
                                            decoration: isCompleted 
                                                ? TextDecoration.lineThrough
                                                : null,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                              const SizedBox(width: 8),
                              if (!isCompleted) ...[
                                                              GlassButton.ghost(
                              'Complete',
                              onPressed: () => _completeTodayItem(item),
                              icon: const Icon(Icons.check),
                            ),
                                const SizedBox(width: 4),
                                IconButton(
                                  onPressed: () => _removeTodayItem(item),
                                  icon: const Icon(Icons.remove_circle_outline),
                                  iconSize: 20,
                                  color: Colors.red[300],
                                ),
                              ] else
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                                  decoration: BoxDecoration(
                                    color: Colors.green[700]?.withOpacity(0.3),
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  child: Text(
                                    'COMPLETED',
                                    style: TextStyle(
                                      color: Colors.green[300],
                                      fontSize: 12,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ),
                            ],
                          ),
                        );
                      }).toList(),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 24),
            
            // Habits preview
            if (briefData['habits'] != null && (briefData['habits'] as List).isNotEmpty) ...[
              const Text(
                'Your Habits',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 12),
              ...(briefData['habits'] as List).map((h) => Container(
                margin: const EdgeInsets.only(bottom: 8),
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: const Color(0xFF2A2A2A),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  children: [
                    Icon(Icons.check_circle, color: Colors.greenAccent.withOpacity(0.8), size: 18),
                    const SizedBox(width: 8),
                    Expanded(child: Text(
                      (h['title'] ?? h['name'] ?? 'Habit').toString(),
                      style: const TextStyle(color: Colors.white),
                    )),
                    Text('Streak ${h['streak'] ?? 0}', style: const TextStyle(color: Colors.white70)),
                  ],
                ),
              )),
            ],
            
            const SizedBox(height: 100), // Bottom padding
          ],
        ),
      ),
    );
  }
}
