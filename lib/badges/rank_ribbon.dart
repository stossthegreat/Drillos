import 'package:flutter/material.dart';

enum RibbonTone { strict, balanced, light }

class RankRibbon extends StatelessWidget {
  final String text;
  final RibbonTone tone;
  const RankRibbon({super.key, required this.text, this.tone = RibbonTone.strict});

  @override
  Widget build(BuildContext context) {
    Color c;
    switch (tone) {
      case RibbonTone.light: c = const Color(0xFF7CFFB2); break;
      case RibbonTone.balanced: c = const Color(0xFFFFB84D); break;
      case RibbonTone.strict: default: c = Colors.amber; break;
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: c.withOpacity(0.14),
        border: Border.all(color: c.withOpacity(0.4)),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.military_tech, color: c, size: 18),
          const SizedBox(width: 6),
          Text(text, style: Theme.of(context).textTheme.labelLarge?.copyWith(color: c)),
        ],
      ),
    );
  }
} 