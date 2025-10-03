import 'package:flutter/material.dart';
import '../design/glass.dart';

class InterceptionCard extends StatelessWidget {
  final bool enabled;
  final VoidCallback onToggle;
  final String title;
  final String subtitle;
  const InterceptionCard({super.key, required this.enabled, required this.onToggle, required this.title, required this.subtitle});

  @override
  Widget build(BuildContext context) {
    return GlassCard(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Row(
          children: [
            const Icon(Icons.shield_moon, color: Colors.cyanAccent),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: Theme.of(context).textTheme.titleMedium),
                  Text(subtitle, style: Theme.of(context).textTheme.bodyMedium),
                ],
              ),
            ),
            Switch(value: enabled, onChanged: (_) => onToggle()),
          ],
        ),
      ),
    );
  }
} 