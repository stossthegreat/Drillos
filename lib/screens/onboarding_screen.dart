import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../design/glass.dart';

class OnboardingScreen extends StatelessWidget {
  const OnboardingScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: const GlassAppBar(title: 'Welcome'),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text('DrillSergeantX', style: Theme.of(context).textTheme.displayMedium),
            const SizedBox(height: 12),
            const Text('Set your tone and get started.'),
            const SizedBox(height: 24),
            ElevatedButton(onPressed: () => context.go('/home'), child: const Text('Continue')),
          ],
        ),
      ),
    );
  }
} 