import 'package:flutter/material.dart';

class FlameBadge extends StatefulWidget {
  final int level; // e.g., 7|30|90|365
  final bool animated;
  const FlameBadge({super.key, required this.level, this.animated = true});

  @override
  State<FlameBadge> createState() => _FlameBadgeState();
}

class _FlameBadgeState extends State<FlameBadge> with SingleTickerProviderStateMixin {
  late final AnimationController _c;
  @override
  void initState() {
    super.initState();
    _c = AnimationController(vsync: this, duration: const Duration(milliseconds: 1400))..repeat(reverse: true);
  }
  @override
  void dispose() { _c.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext context) {
    final color = widget.level >= 365 ? Colors.deepOrangeAccent : widget.level >= 90 ? Colors.orange : widget.level >= 30 ? Colors.amber : Colors.orangeAccent;
    return AnimatedBuilder(
      animation: _c,
      builder: (context, _) {
        final glow = widget.animated ? (0.3 + 0.2 * _c.value) : 0.3;
        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            color: color.withOpacity(0.12),
            border: Border.all(color: color.withOpacity(0.4)),
            borderRadius: BorderRadius.circular(16),
            boxShadow: [BoxShadow(color: color.withOpacity(glow), blurRadius: 12, spreadRadius: 1)],
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.local_fire_department, color: color),
              const SizedBox(width: 8),
              Text('${widget.level}d', style: Theme.of(context).textTheme.labelLarge?.copyWith(color: color)),
            ],
          ),
        );
      },
    );
  }
} 