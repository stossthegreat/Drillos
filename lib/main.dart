import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'design/theme.dart';
import 'screens/home_screen.dart';
import 'screens/new_home_screen.dart';
import 'screens/habits_screen.dart';
import 'screens/new_habits_screen.dart';
import 'screens/streaks_screen.dart';
import 'screens/settings_screen.dart';
import 'screens/design_gallery.dart';
import 'widgets/root_shell.dart';
import 'screens/onboarding_screen.dart';
import 'screens/habit_detail_screen.dart';
import 'screens/anti_habit_detail_screen.dart';
import 'screens/alarm_screen.dart'; // ✅ correct import for AlarmScreen
import 'services/api_client.dart';
import 'services/alarm_service.dart';

const String kDailyTestAlarmTime = "08:00";

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  print('✅ DrillOS starting...');

  // 🌐 Configure API endpoint
  const apiUrl = String.fromEnvironment('API_BASE_URL', defaultValue: '');
  if (apiUrl.isEmpty) {
    apiClient.setBaseUrl('https://drillos-production.up.railway.app');
  } else {
    apiClient.setBaseUrl(apiUrl);
  }

  // 🔔 Initialize alarm service safely
  try {
    await alarmService.init();
    await alarmService.requestPermissions();
    await alarmService.scheduleAlarm(
      habitId: '__test_alarm__',
      habitName: 'Test Alarm',
      time: kDailyTestAlarmTime,
      daysOfWeek: const [1, 2, 3, 4, 5, 6, 7],
      mentorMessage: 'DrillOS test alarm fired successfully!',
    );
    print('✅ Test alarm scheduled');
  } catch (e) {
    print('⚠️ Alarm init failed: $e');
  }

  runApp(const DrillSergeantApp());
}

class DrillSergeantApp extends StatelessWidget {
  const DrillSergeantApp({super.key});

  @override
  Widget build(BuildContext context) {
    print('🧭 GoRouter initialized');

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
              builder: (context, state) => NewHomeScreen(
                refreshTrigger: state.uri.queryParameters['refresh'],
              ),
            ),
            GoRoute(
              path: '/habits',
              builder: (context, state) => const NewHabitsScreen(),
            ),
            GoRoute(
              path: '/streaks',
              builder: (context, state) => const StreaksScreen(),
            ),
            GoRoute(
              path: '/alarm', // ✅ new alarm tab
              builder: (context, state) => const AlarmScreen(),
            ),
            GoRoute(
              path: '/settings',
              builder: (context, state) => const SettingsScreen(),
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
      errorBuilder: (context, state) {
        return Scaffold(
          backgroundColor: Colors.black,
          body: Center(
            child: Text(
              '⚠️ Route not found: ${state.error}',
              style: const TextStyle(color: Colors.white),
              textAlign: TextAlign.center,
            ),
          ),
        );
      },
    );

    return MaterialApp.router(
      title: 'Drill OS',
      debugShowCheckedModeBanner: false,
      theme: buildDarkTheme(),
      routerConfig: router,
      builder: (context, child) {
        // ✅ Safety fallback to prevent black screen
        return Directionality(
          textDirection: TextDirection.ltr,
          child: child ??
              const Scaffold(
                backgroundColor: Colors.black,
                body: Center(
                  child: Text(
                    '⚠️ Failed to load route',
                    style: TextStyle(color: Colors.white),
                  ),
                ),
              ),
        );
      },
    );
  }
}
