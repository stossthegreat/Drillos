import 'package:flutter/material.dart';
import '../design/glass.dart';
import '../design/charts/heatmap.dart';

class HabitDetailScreen extends StatefulWidget {
  final String id;
  const HabitDetailScreen({super.key, required this.id});

  @override
  State<HabitDetailScreen> createState() => _HabitDetailScreenState();
}

class _HabitDetailScreenState extends State<HabitDetailScreen> {
  final Set<int> scheduleDays = {1,2,3,4,5}; // Mon-Fri
  final Set<int> heat = {3,5,8,9,12};
  final List<String> blockers = ['Too tired', 'Phone nearby'];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: const GlassAppBar(title: 'Habit Detail'),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          GlassCard(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Habit ${widget.id}', style: Theme.of(context).textTheme.titleLarge),
                  const SizedBox(height: 8),
                  Text('Schedule'),
                  const SizedBox(height: 8),
                  Wrap(spacing: 6, children: List.generate(7, (i) {
                    const labels = ['S','M','T','W','T','F','S'];
                    final sel = scheduleDays.contains(i);
                    return ChoiceChip(label: Text(labels[i]), selected: sel, onSelected: (_) {
                      setState(() { sel ? scheduleDays.remove(i) : scheduleDays.add(i); });
                    });
                  })),
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),
          GlassCard(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Heatmap', style: Theme.of(context).textTheme.titleMedium),
                  const SizedBox(height: 8),
                  Heatmap(columns: 7, rows: 2, activeCells: heat, cellSize: 14, activeColor: Colors.amber),
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),
          GlassCard(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Blockers', style: Theme.of(context).textTheme.titleMedium),
                  const SizedBox(height: 8),
                  ...blockers.map((b) => ListTile(title: Text(b), leading: const Icon(Icons.block_flipped))),
                  TextButton(onPressed: () { setState(() { blockers.add('New blocker'); }); }, child: const Text('Add blocker')),
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),
          GlassCard(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text('Rewards'),
                  TextButton(onPressed: (){}, child: const Text('Edit')),
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),
          Center(
            child: ElevatedButton.icon(onPressed: (){}, icon: const Icon(Icons.delete_outline), label: const Text('Delete Habit')),
          ),
        ],
      ),
    );
  }
} 