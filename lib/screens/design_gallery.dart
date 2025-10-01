import 'package:flutter/material.dart';
import '../design/glass.dart';
import '../design/charts/ring_progress.dart';
import '../badges/flame_badge.dart';
import '../badges/rank_ribbon.dart';

class DesignGallery extends StatelessWidget {
  const DesignGallery({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: const GlassAppBar(title: 'Design Gallery'),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Text('GlassCard', style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 8),
          GlassCard(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('DrillSergeantX', style: Theme.of(context).textTheme.displayMedium?.copyWith(color: Colors.amber)),
                  const SizedBox(height: 8),
                  Text('Reusable glass surface with border & blur.', style: Theme.of(context).textTheme.bodyMedium),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          Text('Buttons', style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 8),
          Wrap(
            spacing: 12,
            runSpacing: 12,
            children: const [
              GlassButton.primary('Primary'),
              GlassButton.ghost('Ghost'),
              GlassButton.danger('Danger'),
            ],
          ),
          const SizedBox(height: 16),
          Text('RingProgress', style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 8),
          GlassCard(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: const [
                  RingProgress(value: 0.25),
                  SizedBox(width: 16),
                  RingProgress(value: 0.6, progressColor: Colors.amber),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          Text('Badges', style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 8),
          Wrap(
            spacing: 12,
            runSpacing: 12,
            children: const [
              FlameBadge(level: 7),
              FlameBadge(level: 30),
              FlameBadge(level: 90),
              FlameBadge(level: 365),
              RankRibbon(text: 'Sergeant'),
            ],
          ),
        ],
      ),
    );
  }
} 