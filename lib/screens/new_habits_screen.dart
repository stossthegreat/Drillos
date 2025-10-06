import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../services/api_client.dart';
import '../services/local_storage.dart';
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
  // Core data
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
  
  // Animation controllers
  late AnimationController _speedDialController;
  late AnimationController _modalController;
  
  // Color options matching React design
  final List<Map<String, dynamic>> colorOptions = [
    {'name': 'emerald', 'color': const Color(0xFF10B981), 'bgColor': const Color(0xFF10B981)},
    {'name': 'amber', 'color': const Color(0xFFF59E0B), 'bgColor': const Color(0xFFF59E0B)},
    {'name': 'sky', 'color': const Color(0xFF0EA5E9), 'bgColor': const Color(0xFF0EA5E9)},
    {'name': 'rose', 'color': const Color(0xFFE11D48), 'bgColor': const Color(0xFFE11D48)},
    {'name': 'violet', 'color': const Color(0xFF8B5CF6), 'bgColor': const Color(0xFF8B5CF6)},
    {'name': 'slate', 'color': const Color(0xFF64748B), 'bgColor': const Color(0xFF64748B)},
  ];

  // Date helpers
  String formatDate(DateTime date) => date.toIso8601String().split('T')[0];
  
  List<DateTime> get weekDates {
    final startOfWeek = selectedDate.subtract(Duration(days: selectedDate.weekday % 7));
    return List.generate(7, (index) => startOfWeek.add(Duration(days: index)));
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
      // ✅ OFFLINE-FIRST: Load from local storage
      print('🎯 Loading habits from local engine...');
      
      // Check for streak resets
      await HabitEngine.checkStreakResets();
      
      // Get all habits from local storage (not filtered by date)
      final storage = localStorage;
      final habits = await storage.getAllHabits();
      
      // Load streak and completion data for each habit
      final enrichedHabits = await Future.wait(habits.map((habit) async {
        final habitId = habit['id'];
        final streak = await storage.getStreak(habitId);
        final completed = await storage.isCompletedOn(habitId, DateTime.now());
        
        return {
          ...habit,
          'type': 'habit',
          'streak': streak,
          'completed': completed,
        };
      }));
      
      // Load tasks from API (tasks are still backend-managed)
      final tasksResult = await apiClient.getTasks().catchError((e) {
        print('⚠️ Failed to load tasks: $e');
        return <Map<String, dynamic>>[];
      });
      
      // Combine habits and tasks
      final List<dynamic> combinedItems = [];
      combinedItems.addAll(enrichedHabits);
      combinedItems.addAll(tasksResult.map((task) => {
        ...task,
        'type': 'task',
      }));
      
      setState(() {
        allItems = combinedItems;
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

  Future<void> _toggleCompletion(String itemId, DateTime date) async {
    try {
      // ✅ PHASE 1: Use HabitEngine for instant local streak update
      await HabitEngine.applyLocalTick(
        habitId: itemId,
        onApplied: (newStreak, newXp) {
          print('✅ Local tick applied: streak=$newStreak, xp=$newXp');
          // Update UI immediately
          if (mounted) {
            setState(() {
              final index = allItems.indexWhere((item) => item['id'] == itemId);
              if (index != -1) {
                allItems[index] = {
                  ...allItems[index],
                  'streak': newStreak,
                };
              }
            });
          }
        },
      );
      
      // Fire-and-forget: log to backend for analytics (non-blocking)
      apiClient.tickHabit(itemId, idempotencyKey: '${itemId}_${formatDate(date)}');
      
      HapticFeedback.selectionClick();
    } catch (e) {
      print('❌ Error toggling completion: $e');
    }
  }

  // ✅ PHASE 2: Get completion data for the week from SharedPreferences
  Future<Map<String, bool>> _getWeekCompletionData(String habitId, List<DateTime> dates) async {
    final prefs = await SharedPreferences.getInstance();
    final completionData = <String, bool>{};
    
    for (final date in dates) {
      final dateKey = formatDate(date);
      final storageKey = 'done:$habitId:$dateKey';
      completionData[dateKey] = prefs.getBool(storageKey) ?? false;
    }
    
    return completionData;
  }

  Future<void> _saveItem(Map<String, dynamic> data) async {
    if (data['name'].toString().trim().isEmpty) return;
    
    try {
      apiClient.setAuthToken('valid-token');
      
      if (isEditing && data['id'] != null) {
        // Update existing item (would need update endpoint)
        print('Updating item: ${data['id']}');
        _closeModal();
        _loadData();
      } else {
        // Create new item based on type
        dynamic created;
        
        if (data['type'] == 'task') {
          // CREATE TASK (with scheduling support)
          Map<String, dynamic> schedule = {
            'type': data['frequency'] ?? 'daily',
          };
          
          // Add schedule-specific data for tasks
          if (data['frequency'] == 'everyN' && data['everyN'] != null) {
            schedule['everyN'] = data['everyN'];
            schedule['startDate'] = DateTime.now().toIso8601String().split('T')[0];
          } else if (data['frequency'] == 'custom') {
            if (data['startDate'] != null) {
              schedule['startDate'] = data['startDate'];
            }
            if (data['endDate'] != null) {
              schedule['endDate'] = data['endDate'];
            }
          }
          
          created = await apiClient.createTask({
            'title': data['name'].toString().trim(),
            'description': data['category'] ?? '',
            'schedule': schedule,
            // Ensure RFC3339 date-time with seconds and Z
            'dueDate': (data['endDate'] != null && data['endDate'].toString().isNotEmpty)
                ? DateTime.parse(data['endDate']).toUtc().toIso8601String()
                : DateTime.now().add(const Duration(days: 1)).toUtc().toIso8601String(),
            'color': data['color'],
            'reminderEnabled': data['reminderOn'],
            'reminderTime': data['reminderTime'],
            // Backend expects number 1..3
            'priority': (data['intensity'] is int) ? data['intensity'] : 2,
          });
          
          // Create alarm for task reminder
          if (data['reminderOn'] == true && data['reminderTime'] != null) {
            try {
              final timeParts = data['reminderTime'].toString().split(':');
              final hour = int.parse(timeParts[0]);
              final minute = int.parse(timeParts[1]);
              
              await apiClient.createAlarm({
                'label': 'Task: ${data['name'].toString().trim()}',
                'rrule': 'FREQ=ONCE',  // Tasks are one-time
                'tone': data['intensity'] == 3 ? 'strict' : data['intensity'] == 2 ? 'balanced' : 'light',
                'metadata': {
                  'type': 'task_reminder',
                  'taskId': created['id'],
                  'taskName': data['name'].toString().trim(),
                }
              });
              print('✅ Created alarm for task reminder');
            } catch (e) {
              print('❌ Error creating task alarm: $e');
            }
          }
          
          Toast.show(context, '✅ Task created!');
          
        } else {
          // CREATE HABIT (with proper scheduling)
          Map<String, dynamic> schedule = {
            'type': data['frequency'] ?? 'daily',
          };
          
          // Add schedule-specific data
          if (data['frequency'] == 'everyN' && data['everyN'] != null) {
            schedule['everyN'] = data['everyN'];
            schedule['startDate'] = DateTime.now().toIso8601String().split('T')[0];
          } else if (data['frequency'] == 'custom') {
            if (data['startDate'] != null) {
              schedule['startDate'] = data['startDate'];
            }
            if (data['endDate'] != null) {
              schedule['endDate'] = data['endDate'];
            }
          }
          
          created = await apiClient.createHabit({
            'title': data['name'].toString().trim(),
            'schedule': schedule,
            'context': { 'difficulty': data['intensity'] },
            'color': data['color'],
            'reminderEnabled': data['reminderOn'],
            'reminderTime': data['reminderTime'],
          });
          
          // Create alarm for habit reminder (respects schedule)
          if (data['reminderOn'] == true && data['reminderTime'] != null) {
            try {
              final timeParts = data['reminderTime'].toString().split(':');
              final hour = int.parse(timeParts[0]);
              final minute = int.parse(timeParts[1]);
              
              // Generate appropriate RRULE based on schedule
              String rrule = 'FREQ=DAILY;BYHOUR=$hour;BYMINUTE=$minute';
              if (data['frequency'] == 'weekdays') {
                rrule = 'FREQ=WEEKLY;BYDAY=MO,TU,WE,TH,FR;BYHOUR=$hour;BYMINUTE=$minute';
              } else if (data['frequency'] == 'everyN' && data['everyN'] != null) {
                // For everyN, we'll use daily but the backend will handle the logic
                rrule = 'FREQ=DAILY;BYHOUR=$hour;BYMINUTE=$minute';
              }
              
              await apiClient.createAlarm({
                'label': 'Habit: ${data['name'].toString().trim()}',
                'rrule': rrule,
                'tone': data['intensity'] == 3 ? 'strict' : data['intensity'] == 2 ? 'balanced' : 'light',
                'metadata': {
                  'type': 'habit_reminder',
                  'habitId': created['id'],
                  'habitName': data['name'].toString().trim(),
                  'schedule': schedule, // Include schedule info for backend processing
                }
              });
              print('✅ Created alarm for habit reminder with schedule: ${data['frequency']}');
            } catch (e) {
              print('❌ Error creating habit alarm: $e');
            }
          }
          
          // Auto-select habit for today
          try {
            await apiClient.selectForToday(created['id'].toString());
          } catch (e) {
            print('Error auto-selecting new habit: $e');
          }
          
          Toast.show(context, '✅ Habit created and added to today!');
        }
        
        // Don't update local state - let API handle it
        _closeModal();
        
        if (mounted) {
          // Force refresh by going to home with timestamp
          context.go('/home?refresh=${DateTime.now().millisecondsSinceEpoch}');
        }
      }
      
      HapticFeedback.selectionClick();
    } catch (e) {
      print('❌ Error saving item: $e');
      Toast.show(context, 'Failed to save: $e');
    }
  }

  Future<void> _deleteItem(String itemId) async {
    try {
      // Find item to determine type
      final item = allItems.firstWhere((i) => i['id'].toString() == itemId);
      
      // Delete from API based on type
      if (item['type'] == 'habit') {
        await apiClient.deleteHabit(itemId);
      } else if (item['type'] == 'task') {
        await apiClient.deleteTask(itemId);
      }
      
      // Always refresh from API after deletion
      await _loadData();
      HapticFeedback.heavyImpact();
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('✅ Item deleted')),
        );
      }
    } catch (e) {
      print('❌ Error deleting item: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to delete: $e')),
        );
      }
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

  Color _getColorForItem(dynamic item) {
    final colorName = item['color'] ?? 'emerald';
    return colorOptions.firstWhere(
      (c) => c['name'] == colorName,
      orElse: () => colorOptions[0],
    )['color'];
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
          // Month/Year with navigation
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              IconButton(
                onPressed: () => setState(() {
                  selectedDate = selectedDate.subtract(const Duration(days: 7));
                }),
                icon: const Icon(Icons.chevron_left, color: Colors.white70),
              ),
              Text(
                '${_monthName(selectedDate.month)} ${selectedDate.year}',
                style: const TextStyle(
                  color: Colors.white70,
                  fontSize: 16,
                ),
              ),
              IconButton(
                onPressed: () => setState(() {
                  selectedDate = selectedDate.add(const Duration(days: 7));
                }),
                icon: const Icon(Icons.chevron_right, color: Colors.white70),
              ),
            ],
          ),
          
          // Week day buttons
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
          
          const SizedBox(height: 16),
          
          // Filter tabs
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
          child: Text(
            label,
            textAlign: TextAlign.center,
            style: TextStyle(
              color: isSelected ? Colors.black : Colors.white70,
              fontSize: 14,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildItemCard(dynamic item) {
    final itemColor = _getColorForItem(item);
    final itemType = item['type'] ?? 'habit';
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
          // Header row
          Row(
            children: [
              // Icon
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: itemColor,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(
                  itemType == 'habit' ? Icons.local_fire_department :
                  itemType == 'task' ? Icons.check_box :
                  Icons.close,
                  color: Colors.black,
                  size: 20,
                ),
              ),
              const SizedBox(width: 12),
              
              // Title and category
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
              
              // Reminder and settings
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
            ],
          ),
          
          const SizedBox(height: 12),
          
          // Progress bar
          Container(
            height: 8,
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.1),
              borderRadius: BorderRadius.circular(4),
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: LinearProgressIndicator(
                value: 0.7, // Would calculate based on completion data
                backgroundColor: Colors.transparent,
                valueColor: AlwaysStoppedAnimation(
                  itemType == 'bad' ? const Color(0xFFE11D48) : const Color(0xFF10B981)
                ),
              ),
            ),
          ),
          
          const SizedBox(height: 12),
          
          // Week completion rail with accurate schedule checking
          FutureBuilder<Map<String, bool>>(
            future: _getWeekCompletionData(item['id'].toString(), weekDates),
            builder: (context, snapshot) {
              final completionData = snapshot.data ?? {};
              
              return Row(
                children: weekDates.map((date) {
                  final dateKey = formatDate(date);
                  final isCompleted = completionData[dateKey] ?? false;
                  
                  // ✅ PHASE 2: Check if habit is actually scheduled for this date
                  final schedule = HabitSchedule.fromJson((item['schedule'] as Map?)?.cast<String, dynamic>());
                  final isScheduled = schedule.isActiveOn(date);
                  
                  return Expanded(
                    child: GestureDetector(
                      onTap: isScheduled ? () => _toggleCompletion(item['id'].toString(), date) : null,
                      child: Container(
                        margin: const EdgeInsets.symmetric(horizontal: 2),
                        height: 40,
                        decoration: BoxDecoration(
                          color: isCompleted ? const Color(0xFF10B981) : Colors.transparent,
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(
                            color: isCompleted ? const Color(0xFF10B981) :
                                   isScheduled ? Colors.white.withOpacity(0.2) :
                                   Colors.white.withOpacity(0.05), // Very faded for non-scheduled days
                            width: 2,
                          ),
                        ),
                        child: Center(
                          child: Text(
                            '${date.day}',
                            style: TextStyle(
                              color: isCompleted ? Colors.black : 
                                     isScheduled ? Colors.white :
                                     Colors.white.withOpacity(0.3), // Gray out non-scheduled days
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
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
          
          // Action buttons
          Row(
            children: [
              _buildActionButton('Calendar', Icons.calendar_today, () {
                // Open edit modal to change schedule
                _openEditModal(item);
              }),
              const SizedBox(width: 8),
              _buildActionButton('Stats', Icons.bar_chart, () {
                // TODO: Open stats screen
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Stats coming soon!')),
                );
              }),
              const Spacer(),
              _buildActionButton('Delete', Icons.delete, () => _deleteItem(item['id'].toString()),
                                color: const Color(0xFFE11D48)),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildActionButton(String label, IconData icon, VoidCallback onTap, {Color? color}) {
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

  Widget _buildSpeedDial() {
    return Positioned(
      right: 20,
      bottom: 100,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (showSpeedDial) ...[
            _buildSpeedDialItem('Add Habit', Icons.local_fire_department, const Color(0xFF10B981), () => _openCreateModal('habit')),
            const SizedBox(height: 12),
            _buildSpeedDialItem('Add Task', Icons.check_box, const Color(0xFF0EA5E9), () => _openCreateModal('task')),
            const SizedBox(height: 12),
            _buildSpeedDialItem('Add Bad Habit', Icons.close, const Color(0xFFE11D48), () => _openCreateModal('bad')),
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

  Widget _buildSpeedDialItem(String label, IconData icon, Color color, VoidCallback onTap) {
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

  String _monthName(int month) {
    const months = ['', 'January', 'February', 'March', 'April', 'May', 'June',
                   'July', 'August', 'September', 'October', 'November', 'December'];
    return months[month];
  }

  String _dayAbbr(int weekday) {
    const days = ['', 'Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
    return days[weekday];
  }

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
          
          // Create/Edit Modal
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