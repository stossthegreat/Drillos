import 'package:flutter/material.dart';

class Toast {
  static void show(BuildContext context, String message) {
    final overlay = Overlay.maybeOf(context);
    if (overlay == null) return;
    final entry = OverlayEntry(
      builder: (_) => Positioned(
        bottom: 80,
        left: 16,
        right: 16,
        child: Material(
          color: Colors.transparent,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: Colors.black.withOpacity(0.8),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text(message, textAlign: TextAlign.center),
          ),
        ),
      ),
    );
    overlay.insert(entry);
    Future.delayed(const Duration(seconds: 2)).then((_) => entry.remove());
  }
}

class GlassBanner extends StatelessWidget {
  final String text;
  final Color color;
  const GlassBanner({super.key, required this.text, required this.color});
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withOpacity(0.15),
        border: Border.all(color: color.withOpacity(0.4)),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Text(text),
    );
  }
}

class ConfettiStub extends StatelessWidget {
  final Widget child;
  const ConfettiStub({super.key, required this.child});
  @override
  Widget build(BuildContext context) {
    return Stack(children: [child]);
  }
} 