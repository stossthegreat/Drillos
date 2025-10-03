import 'package:flutter/material.dart';

class TogglePills extends StatelessWidget {
  final List<String> labels;
  final int selectedIndex;
  final ValueChanged<int> onChanged;
  const TogglePills({super.key, required this.labels, required this.selectedIndex, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        for (int i = 0; i < labels.length; i++) ...[
          Expanded(
            child: GestureDetector(
              onTap: () => onChanged(i),
              child: Container(
                padding: const EdgeInsets.symmetric(vertical: 12),
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: i == selectedIndex ? Colors.amber.withOpacity(0.15) : Colors.white.withOpacity(0.06),
                  border: Border.all(color: i == selectedIndex ? Colors.amber.withOpacity(0.4) : Colors.white.withOpacity(0.12)),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(labels[i], style: Theme.of(context).textTheme.labelLarge?.copyWith(color: i == selectedIndex ? Colors.amber : Colors.white)),
              ),
            ),
          ),
          if (i != labels.length - 1) const SizedBox(width: 8),
        ],
      ],
    );
  }
} 