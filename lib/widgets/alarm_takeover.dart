import 'package:flutter/material.dart';

class AlarmTakeover extends StatelessWidget {
  final String title;
  final String actionText;
  final VoidCallback onDismiss;
  const AlarmTakeover({super.key, required this.title, required this.actionText, required this.onDismiss});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: SafeArea(
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(title, style: Theme.of(context).textTheme.displayMedium),
              const SizedBox(height: 24),
              ElevatedButton(onPressed: onDismiss, child: Text(actionText)),
            ],
          ),
        ),
      ),
    );
  }
} 