import 'package:flutter/material.dart';

class BgOrbs extends StatelessWidget {
  const BgOrbs({super.key});

  @override
  Widget build(BuildContext context) {
    return Positioned.fill(
      child: IgnorePointer(
        child: Stack(
          children: [
            Positioned(
              top: 80,
              left: 24,
              child: _orb(Colors.amber.withOpacity(0.10), 140),
            ),
            Positioned(
              right: 24,
              bottom: 120,
              child: _orb(Colors.redAccent.withOpacity(0.10), 180),
            ),
            Positioned(
              right: 60,
              top: 220,
              child: _orb(Colors.lightBlueAccent.withOpacity(0.10), 110),
            ),
          ],
        ),
      ),
    );
  }

  Widget _orb(Color color, double size) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(color: color, shape: BoxShape.circle),
    );
  }
} 