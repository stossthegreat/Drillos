import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../design/glass.dart';
import "../services/api_client.dart";

class HabitsScreen extends StatefulWidget {
  const HabitsScreen({super.key});

  @override
  State<HabitsScreen> createState() => _HabitsScreenState();
}

class _HabitsScreenState extends State<HabitsScreen> {
  List<dynamic> habits = [];
  List<dynamic> tasks = [];
  bool isLoading = true;
  Set<String> selectedHabits = {};
  Set<String> selectedTasks = {};

  @override
  void initState() {
    super.initState();
    _loadHabits();
  }

  Future<void> _loadHabits() async {
    setState(() { isLoading = true; });
    try {
      print('🔄 Loading habits and today items...'); // Debug
      apiClient.setAuthToken("valid-token");
      final habitsList = await apiClient.getHabits();
      print('✅ Loaded ${(habitsList as List).length} habits'); // Debug
      
      // Load current today selections to show which items are already added
      final brief = await apiClient.getBriefToday();
      print('✅ Loaded brief: ${brief.keys}'); // Debug
      final todayItems = brief['today'] ?? [];
      print('📋 Today items: ${todayItems.length}'); // Debug
      final todayHabitIds = <String>{};
      final todayTaskIds = <String>{};
      
      for (final item in todayItems) {
        if (item['type'] == 'habit') {
          todayHabitIds.add(item['id'].toString());
        } else {
          todayTaskIds.add(item['id'].toString());
        }
      }
      
      setState(() { 
        habits = habitsList;
        tasks = []; // We'll add tasks later when we have the API method
        selectedHabits = todayHabitIds;
        selectedTasks = todayTaskIds;
        isLoading = false; 
      });
      print('✅ Habits screen loaded successfully'); // Debug
    } catch (e) {
      print('❌ Error loading habits: $e'); // Debug
      setState(() { isLoading = false; });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to load habits: $e')),
        );
      }
    }
  }

  Future<void> _createHabitAndGoHome(String name, int difficulty) async {
    try {
      apiClient.setAuthToken("valid-token");
      final created = await apiClient.createHabit({
        'title': name,
        'schedule': { 'type': 'daily' },
        'difficulty': difficulty,
      });
      
      // Don't update local state - let API handle it
      // The backend auto-selects the habit for today
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('✅ Habit created and added to today!')),
        );
        // Force refresh by going to home with timestamp
        context.go('/home?refresh=${DateTime.now().millisecondsSinceEpoch}');
      }
    } catch (e) {
      print('Error creating habit: $e'); // Debug logging
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to create habit: $e')),
        );
      }
    }
  }

  Future<void> _createTaskAndGoHome(String title) async {
    try {
      apiClient.setAuthToken("valid-token");
      final today = DateTime.now().toIso8601String().split('T')[0];
      final created = await apiClient.createTask({
        'title': title,
        'dueDate': DateTime.now().add(const Duration(days: 1)).toUtc().toIso8601String(),
        'priority': 2,
      });
      
      // Don't update local state - let API handle it
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('✅ Task created')),
        );
        // Force refresh by going to home with timestamp
        context.go('/home?refresh=${DateTime.now().millisecondsSinceEpoch}');
      }
    } catch (e) {
      print('Error creating task: $e'); // Debug logging
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to create task: $e')),
        );
      }
    }
  }

  Widget _buildHabitItem(Map<String, dynamic> habit) {
    final isSelected = selectedHabits.contains(habit['id']);
    
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      child: GlassCard(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      habit['name'] ?? habit['title'] ?? 'Habit',
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: Colors.white,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        Icon(
                          Icons.fitness_center,
                          size: 16,
                          color: Colors.blue[300],
                        ),
                        const SizedBox(width: 4),
                        Text(
                          'Difficulty: ${habit['difficulty'] ?? 1}',
                          style: TextStyle(
                            fontSize: 14,
                            color: Colors.grey[300],
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              GlassButton.ghost(
                isSelected ? 'Added to Today' : 'Add to Today',
                onPressed: () => _toggleTodaySelection(habit),
                icon: Icon(isSelected ? Icons.check : Icons.add),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTaskItem(Map<String, dynamic> task) {
    final isSelected = selectedTasks.contains(task['id']);
    
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      child: GlassCard(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  task['title'] ?? 'Task',
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: Colors.white,
                  ),
                ),
              ),
              GlassButton.ghost(
                isSelected ? 'Added to Today' : 'Add to Today',
                onPressed: () => _toggleTodaySelection(task),
                icon: Icon(isSelected ? Icons.check : Icons.add),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _toggleTodaySelection(Map<String, dynamic> item) async {
    final itemId = item['id'];
    final isHabit = item.containsKey('difficulty');
    final isCurrentlySelected = isHabit 
        ? selectedHabits.contains(itemId)
        : selectedTasks.contains(itemId);

    try {
      if (isCurrentlySelected) {
        print('🗑️ Deselecting $itemId from today...');
        final response = await apiClient.deselectForToday(itemId);
        print('✅ Deselect response: $response');
        setState(() {
          if (isHabit) {
            selectedHabits.remove(itemId);
          } else {
            selectedTasks.remove(itemId);
          }
        });
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Removed from today')),
          );
        }
      } else {
        print('✅ Selecting $itemId for today...');
        final response = await apiClient.selectForToday(itemId);
        print('✅ Select response: $response');
        setState(() {
          if (isHabit) {
            selectedHabits.add(itemId);
          } else {
            selectedTasks.add(itemId);
          }
        });
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('✅ Added to today! Check Home tab.')),
          );
          // Navigate to home after adding with a refresh trigger
          context.go('/home?refresh=${DateTime.now().millisecondsSinceEpoch}');
        }
      }
    } catch (e) {
      print('❌ Error toggling today selection: $e'); // Debug logging
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Daily Orders')),
      body: isLoading
        ? const Center(child: CircularProgressIndicator())
        : ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _AddTask(onAddTask: (title) => _createTaskAndGoHome(title)),
          const SizedBox(height: 8),
          _AddHabit(onAdd: (name, diff) => _createHabitAndGoHome(name, diff)),
          const SizedBox(height: 20),
          const Text('Habits', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.white)),
          const SizedBox(height: 12),
          ...habits.map((h) => _buildHabitItem(h)),
          if (tasks.isNotEmpty) ...[
            const SizedBox(height: 20),
            const Text('Tasks', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.white)),
            const SizedBox(height: 12),
            ...tasks.map((t) => _buildTaskItem(t)),
          ],
        ],
      ),
    );
  }
}

class _AddTask extends StatefulWidget {
  final Future<void> Function(String title) onAddTask;
  const _AddTask({required this.onAddTask});
  @override
  State<_AddTask> createState() => _AddTaskState();
}

class _AddTaskState extends State<_AddTask> {
  final controller = TextEditingController();
  @override
  Widget build(BuildContext context) {
    return GlassCard(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Row(
          children: [
            Expanded(
              child: TextField(
                controller: controller,
                decoration: const InputDecoration(hintText: 'Quick task for today', border: InputBorder.none),
              ),
            ),
            const SizedBox(width: 8),
            GlassButton.primary('Add Task', onPressed: () async {
              final title = controller.text.trim();
              if (title.isEmpty) return;
              await widget.onAddTask(title);
              controller.clear();
            }),
          ],
        ),
      ),
    );
  }
}

class _AddHabit extends StatefulWidget {
  final Future<void> Function(String name, int difficulty) onAdd;
  const _AddHabit({required this.onAdd});
  @override
  State<_AddHabit> createState() => _AddHabitState();
}

class _AddHabitState extends State<_AddHabit> {
  final controller = TextEditingController();
  int difficulty = 2;
  @override
  Widget build(BuildContext context) {
    return GlassCard(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          children: [
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: controller,
                    decoration: const InputDecoration(hintText: 'New habit', border: InputBorder.none),
                  ),
                ),
                const SizedBox(width: 8),
                GlassButton.primary('Add Habit', onPressed: () async {
                  final name = controller.text.trim();
                  if (name.isEmpty) return;
                  await widget.onAdd(name, difficulty);
                  controller.clear();
                }),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                const Text('Difficulty: ', style: TextStyle(color: Colors.white)),
                ...List.generate(3, (i) {
                  final level = i + 1;
                  return Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: ChoiceChip(
                      label: Text('$level'),
                      selected: difficulty == level,
                      onSelected: (selected) {
                        if (selected) setState(() => difficulty = level);
                      },
                    ),
                  );
                }),
              ],
            ),
          ],
        ),
      ),
    );
  }
} 