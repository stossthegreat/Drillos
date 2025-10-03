import 'package:flutter/material.dart';

class Heatmap extends StatelessWidget {
  final int columns;
  final int rows;
  final Set<int> activeCells; // indices 0..(rows*cols-1)
  final double cellSize;
  final Color activeColor;
  final Color inactiveColor;

  const Heatmap({super.key, required this.columns, required this.rows, required this.activeCells, this.cellSize = 16, this.activeColor = Colors.redAccent, this.inactiveColor = const Color(0x22FFFFFF)});

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 4,
      runSpacing: 4,
      children: [
        for (int i = 0; i < rows * columns; i++)
          Container(
            width: cellSize,
            height: cellSize,
            decoration: BoxDecoration(
              color: activeCells.contains(i) ? activeColor.withOpacity(0.8) : inactiveColor,
              borderRadius: BorderRadius.circular(4),
            ),
          ),
      ],
    );
  }
} 