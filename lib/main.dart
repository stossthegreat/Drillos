import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'design/theme.dart';
import 'screens/home_screen.dart';
import 'screens/new_home_screen.dart';
import 'screens/habits_screen.dart';
import 'screens/new_habits_screen.dart';
import 'screens/streaks_screen.dart';
import 'screens/chat_screen.dart';
// import 'screens/alarms_screen.dart'; // Removed - alarms now integrated into habits
import 'screens/settings_screen.dart';
import 'screens/design_gallery.dart';
import 'widgets/root_shell.dart';
import 'screens/onboarding_screen.dart';
import 'screens/habit_detail_screen.dart';
import 'screens/anti_habit_detail_screen.dart';
import 'services/api_client.dart';

void main() {
  // Debug: Print the environment variable and actual URL being used
  const apiUrl = String.fromEnvironment('API_BASE_URL', defaultValue: '');
  print('🌐 Environment API_BASE_URL: "$apiUrl"');
  print('🌐 ApiClient baseUrl before override: "${apiClient.getBaseUrl()}"');
  
  // Override with production URL (this will be overridden by environment variable if provided)
  if (apiUrl.isEmpty) {
  apiClient.setBaseUrl('https://drillos-production.up.railway.app');
  } else {
    apiClient.setBaseUrl(apiUrl);
  }
  
  print('🌐 Final ApiClient baseUrl: "${apiClient.getBaseUrl()}"');
  
  runApp(const DrillSergeantApp());
}

class DrillSergeantApp extends StatelessWidget {
  const DrillSergeantApp({super.key});

  @override
  Widget build(BuildContext context) {
    final router = GoRouter(
      initialLocation: '/onboarding',
      routes: [
        GoRoute(path: '/design', builder: (c, s) => const DesignGallery()),
        GoRoute(path: '/onboarding', builder: (c, s) => const DrillOSOnboarding()),
        ShellRoute(
          builder: (context, state, child) => RootShell(child: child),
          routes: [
            // New UI screens (testing)
            GoRoute(path: '/home', builder: (c, s) => NewHomeScreen(refreshTrigger: s.uri.queryParameters['refresh'])),
            GoRoute(path: '/habits', builder: (c, s) => const NewHabitsScreen()),
            
            // Old screens (backup)
            GoRoute(path: '/home-old', builder: (c, s) => HomeScreen(refreshTrigger: s.uri.queryParameters['refresh'])),
            GoRoute(path: '/habits-old', builder: (c, s) => const HabitsScreen()),
            
            // Other screens unchanged
            GoRoute(path: '/habits/:id', builder: (c, s) => HabitDetailScreen(id: s.pathParameters['id'] ?? 'id')),
            GoRoute(path: '/antihabits/:id', builder: (c, s) => AntiHabitDetailScreen(id: s.pathParameters['id'] ?? 'id')),
            GoRoute(path: '/streaks', builder: (c, s) => const StreaksScreen()),
            GoRoute(path: '/chat', builder: (c, s) => const ChatScreen()),
            // GoRoute(path: '/alarms', builder: (c, s) => const AlarmsScreen()), // Removed - alarms integrated into habits
            GoRoute(path: '/settings', builder: (c, s) => const SettingsScreen()),
          ],
        ),
      ],
    );

    return MaterialApp.router(
      title: 'DrillSergeantX',
      debugShowCheckedModeBanner: false,
      theme: buildDarkTheme(),
      routerConfig: router,
      builder: (context, child) {
        return Directionality(
          textDirection: TextDirection.ltr,
          child: child ?? const SizedBox(),
        );
      },
    );
  }
}
