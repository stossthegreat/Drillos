import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

class RootShell extends StatelessWidget {
  final Widget child;
  const RootShell({super.key, required this.child});

  int _indexForLocation(String loc) {
    if (loc.startsWith('/habits')) return 1;
    if (loc.startsWith('/streaks')) return 2;
    if (loc.startsWith('/alarm')) return 3; // ✅ new alarm tab
    if (loc.startsWith('/settings')) return 4;
    return 0; // home
  }

  @override
  Widget build(BuildContext context) {
    final loc = GoRouter.of(context).location;
    final idx = _indexForLocation(loc);

    return Scaffold(
      body: child,
      bottomNavigationBar: NavigationBar(
        selectedIndex: idx,
        backgroundColor: Colors.black.withOpacity(0.8),
        indicatorColor: const Color(0xFF10B981).withOpacity(0.15),
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.home_outlined),
            selectedIcon: Icon(Icons.home),
            label: 'Home',
          ),
          NavigationDestination(
            icon: Icon(Icons.check_box_outlined),
            selectedIcon: Icon(Icons.check_box),
            label: 'Habits',
          ),
          NavigationDestination(
            icon: Icon(Icons.local_fire_department_outlined),
            selectedIcon: Icon(Icons.local_fire_department),
            label: 'Streaks',
          ),
          NavigationDestination(
            icon: Icon(Icons.alarm_outlined), // ✅ replaced Sergeant icon
            selectedIcon: Icon(Icons.alarm),
            label: 'Alarms', // ✅ new label
          ),
          NavigationDestination(
            icon: Icon(Icons.settings_outlined),
            selectedIcon: Icon(Icons.settings),
            label: 'Settings',
          ),
        ],
        onDestinationSelected: (i) {
          switch (i) {
            case 0:
              context.go('/home');
              break;
            case 1:
              context.go('/habits');
              break;
            case 2:
              context.go('/streaks');
              break;
            case 3:
              context.go('/alarm'); // ✅ route fixed
              break;
            case 4:
              context.go('/settings');
              break;
          }
        },
      ),
    );
  }
}
