import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

class RootShell extends StatelessWidget {
  final Widget child;
  const RootShell({super.key, required this.child});

  int _indexForLocation(String loc) {
    if (loc.startsWith('/habits')) return 1;
    if (loc.startsWith('/streaks')) return 2;
    if (loc.startsWith('/chat')) return 3;
    if (loc.startsWith('/settings')) return 4;
    return 0; // home
  }

  @override
  Widget build(BuildContext context) {
    final loc = GoRouterState.of(context).uri.toString();
    final idx = _indexForLocation(loc);
    return Scaffold(
      body: child,
      bottomNavigationBar: NavigationBar(
        selectedIndex: idx,
        backgroundColor: Colors.black.withOpacity(0.8),
        destinations: const [
          NavigationDestination(icon: Icon(Icons.home_outlined), selectedIcon: Icon(Icons.home), label: 'Home'),
          NavigationDestination(icon: Icon(Icons.check_box_outlined), selectedIcon: Icon(Icons.check_box), label: 'Habits'),
          NavigationDestination(icon: Icon(Icons.local_fire_department_outlined), selectedIcon: Icon(Icons.local_fire_department), label: 'Streaks'),
          NavigationDestination(icon: Icon(Icons.military_tech_outlined), selectedIcon: Icon(Icons.military_tech), label: 'Sergeant'),
          NavigationDestination(icon: Icon(Icons.settings_outlined), selectedIcon: Icon(Icons.settings), label: 'Settings'),
        ],
        onDestinationSelected: (i) {
          switch (i) {
            case 0: context.go('/home'); break;
            case 1: context.go('/habits'); break;
            case 2: context.go('/streaks'); break;
            case 3: context.go('/chat'); break;
            case 4: context.go('/settings'); break;
          }
        },
      ),
    );
  }
} 