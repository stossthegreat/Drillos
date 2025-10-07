import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'design/theme.dart';
import 'screens/home_screen.dart';
import 'screens/new_home_screen.dart';
import 'screens/habits_screen.dart';
// ✅ remove duplicate import – only this one
import 'screens/new_habits_screen.dart';
import 'screens/streaks_screen.dart';
import 'screens/chat_screen.dart';
import 'screens/settings_screen.dart';
import 'screens/design_gallery.dart';
import 'widgets/root_shell.dart';
import 'screens/onboarding_screen.dart';
import 'screens/habit_detail_screen.dart';
import 'screens/anti_habit_detail_screen.dart';
import 'services/api_client.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();

  // 🌐 Configure API URL
  const apiUrl = String.fromEnvironment('API_BASE_URL', defaultValue: '');
  if (apiUrl.isEmpty) {
    apiClient.setBaseUrl('https://drillos-production.up.railway.app');
  } else {
    apiClient.setBaseUrl(apiUrl);
  }

  runApp(const DrillSergeantApp());
}

class DrillSergeantApp extends StatelessWidget {
  const DrillSergeantApp({super.key});

  @override
  Widget build(BuildContext context) {
    final router = GoRouter(
      initialLocation: '/onboarding',
      routes: [
        GoRoute(
          path: '/design',
          builder: (context, state) => const DesignGallery(),
        ),
        GoRoute(
          path: '/onboarding',
          builder: (context, state) => DrillOSOnboarding(
            onComplete: () => context.go('/home'),
          ),
        ),
        ShellRoute(
          builder: (context, state, child) => RootShell(child: child),
          routes: [
            GoRoute(
              path: '/home',
              // ❌ remove const
              builder: (context, state) => NewHomeScreen(
                refreshTrigger: state.uri.queryParameters['refresh'],
              ),
            ),
            GoRoute(
              path: '/habits',
              // ❌ remove const
              builder: (context, state) => NewHabitsScreen(),
            ),
            GoRoute(
              path: '/home-old',
              builder: (context, state) => HomeScreen(
                refreshTrigger: state.uri.queryParameters['refresh'],
              ),
            ),
            GoRoute(
              path: '/habits-old',
              builder: (context, state) => const HabitsScreen(),
            ),
            GoRoute(
              path: '/streaks',
              builder: (context, state) => const StreaksScreen(),
            ),
            GoRoute(
              path: '/chat',
              builder: (context, state) => const ChatScreen(),
            ),
            GoRoute(
              path: '/settings',
              builder: (context, state) => const SettingsScreen(),
            ),
            GoRoute(
              path: '/habits/:id',
              builder: (context, state) => HabitDetailScreen(
                id: state.pathParameters['id'] ?? '',
              ),
            ),
            GoRoute(
              path: '/antihabits/:id',
              builder: (context, state) => AntiHabitDetailScreen(
                id: state.pathParameters['id'] ?? '',
              ),
            ),
          ],
        ),
      ],
    );

    return MaterialApp.router(
      title: 'Drill OS',
      debugShowCheckedModeBanner: false,
      theme: buildDarkTheme(),
      routerConfig: router,
    );
  }
}
