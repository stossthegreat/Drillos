import 'package:flutter/material.dart';
import '../design/glass.dart';

class MissionCard extends StatelessWidget {
  final String title;
  final String note;
  final int rewardXp;
  const MissionCard({super.key, required this.title, required this.note, required this.rewardXp});

  @override
  Widget build(BuildContext context) {
    return GlassCard(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Row(children: [
              const Icon(Icons.local_fire_department, color: Colors.orangeAccent),
              const SizedBox(width: 8),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: Theme.of(context).textTheme.titleMedium),
                  Text('Reward: $rewardXp XP', style: Theme.of(context).textTheme.bodyMedium),
                ],
              ),
            ]),
            Text(note, style: Theme.of(context).textTheme.bodyMedium),
          ],
        ),
      ),
    );
  }
} 