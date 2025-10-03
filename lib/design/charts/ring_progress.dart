import 'dart:math' as math;
import 'package:flutter/material.dart';

class RingProgress extends StatelessWidget {
  final double value; // 0..1
  final double size;
  final double stroke;
  final Color trackColor;
  final Color progressColor;
  final Widget? center;

  const RingProgress({super.key, required this.value, this.size = 72, this.stroke = 8, this.trackColor = const Color(0x22FFFFFF), this.progressColor = Colors.amber, this.center});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: size,
      height: size,
      child: CustomPaint(
        painter: _RingPainter(value: value.clamp(0.0, 1.0), stroke: stroke, trackColor: trackColor, progressColor: progressColor),
        child: Center(child: center),
      ),
    );
  }
}

class _RingPainter extends CustomPainter {
  final double value;
  final double stroke;
  final Color trackColor;
  final Color progressColor;
  _RingPainter({required this.value, required this.stroke, required this.trackColor, required this.progressColor});

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width/2, size.height/2);
    final radius = (math.min(size.width, size.height) - stroke) / 2;
    final track = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = stroke
      ..strokeCap = StrokeCap.round
      ..color = trackColor;
    final prog = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = stroke
      ..strokeCap = StrokeCap.round
      ..shader = SweepGradient(
        startAngle: -math.pi/2,
        endAngle: 3*math.pi/2,
        colors: [progressColor.withOpacity(0.7), progressColor],
      ).createShader(Rect.fromCircle(center: center, radius: radius));

    canvas.drawCircle(center, radius, track);
    final sweep = value * 2 * math.pi;
    canvas.save();
    canvas.translate(center.dx, center.dy);
    canvas.rotate(-math.pi/2);
    canvas.drawArc(Rect.fromCircle(center: Offset.zero, radius: radius), 0, sweep, false, prog);
    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant _RingPainter old) => old.value != value || old.stroke != stroke || old.trackColor != trackColor || old.progressColor != progressColor;
} 