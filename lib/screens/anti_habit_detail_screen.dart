import 'package:flutter/material.dart';
import '../design/glass.dart';
import '../design/charts/heatmap.dart';

class AntiHabitDetailScreen extends StatefulWidget {
  final String id;
  const AntiHabitDetailScreen({super.key, required this.id});

  @override
  State<AntiHabitDetailScreen> createState() => _AntiHabitDetailScreenState();
}

class _AntiHabitDetailScreenState extends State<AntiHabitDetailScreen> {
  int targetMinutes = 15;
  final Set<int> dangerHours = {20,21,22};
  bool interception = false;
  final List<String> flaggedApps = ['YouTube', 'TikTok'];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: const GlassAppBar(title: 'Anti-Habit Detail'),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          GlassCard(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Anti-Habit ${widget.id}', style: Theme.of(context).textTheme.titleLarge),
                  const SizedBox(height: 8),
                  Row(children:[
                    const Text('Target minutes/day:'),
                    const SizedBox(width: 8),
                    DropdownButton<int>(
                      value: targetMinutes,
                      items: const [5,10,15,20,30,45,60].map((v)=>DropdownMenuItem(value: v, child: Text('$v'))).toList(),
                      onChanged: (v) => setState(() => targetMinutes = v ?? targetMinutes),
                    ),
                  ]),
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
                  Text('Danger windows', style: Theme.of(context).textTheme.titleMedium),
                  const SizedBox(height: 8),
                  Heatmap(columns: 24, rows: 1, activeCells: dangerHours, cellSize: 12, activeColor: Colors.redAccent),
                  const SizedBox(height: 8),
                  Wrap(spacing: 6, runSpacing: 6, children: [
                    for (int h=0; h<24; h++)
                      ChoiceChip(
                        label: Text(h.toString().padLeft(2, '0')),
                        selected: dangerHours.contains(h),
                        onSelected: (sel){ setState((){ sel ? dangerHours.add(h) : dangerHours.remove(h); }); },
                      ),
                  ]),
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
                  Text('Flagged apps (Android)', style: Theme.of(context).textTheme.titleMedium),
                  const SizedBox(height: 8),
                  ...flaggedApps.map((a) => ListTile(title: Text(a), leading: const Icon(Icons.app_blocking))),
                  TextButton(onPressed: () { setState(() { flaggedApps.add('New App'); }); }, child: const Text('Add app')),
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
                  const Text('Interception'),
                  Switch(value: interception, onChanged: (v)=> setState(()=> interception = v)),
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
                  const Text('Bark preview'),
                  TextButton(onPressed: (){}, child: const Text('Play')),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
} 