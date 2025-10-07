import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'design/theme.dart';
import 'screens/home_screen.dart';
import 'screens/new_home_screen.dart';
import 'screens/habits_screen.dart';
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

  // 🌐 Setup API base URL
  const apiUrl = String.fromEnvironment('API_BASE_URL', defaultValue: '');
  print('🌐 Environment API_BASE_URL: "$apiUrl"');
  print('🌐 ApiClient baseUrl before override: "${apiClient.getBaseUrl()}"');

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
        // 🎨 Design preview
        GoRoute(
          path: '/design',
          builder: (context, state) => const DesignGallery(),
        ),

        // 🚀 Onboarding flow
        GoRoute(
          path: '/onboarding',
          builder: (context, state) => DrillOSOnboarding(
            onComplete: () => context.go('/home'),
          ),
        ),

        // 🏠 Root shell (bottom navigation)
        ShellRoute(
          builder: (context, state, child) => RootShell(child: child),
          routes: [
            // ✅ NEW SCREENS
            GoRoute(
              path: '/home',
              builder: (context, state) => const NewHomeScreen(),
            ),
            GoRoute(
              path: '/habits',
              builder: (context, state) => const NewHabitsScreen(),
            ),

            // 🕹 LEGACY SCREENS (backup)
            GoRoute(
              path: '/home-old',
              builder: (context, state) =>
                  HomeScreen(refreshTrigger: state.uri.queryParameters['refresh']),
            ),
            GoRoute(
              path: '/habits-old',
              builder: (context, state) => const HabitsScreen(),
            ),

            // 📊 STREAKS / CHAT / SETTINGS
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

            // 📋 DETAIL PAGES
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
      builder: (context, child) => Directionality(
        textDirection: TextDirection.ltr,
        child: child ?? const SizedBox(),
      ),
    );
  }
}
