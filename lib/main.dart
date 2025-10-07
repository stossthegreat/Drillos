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
import 'services/alarm_service.dart';

/// 👉 Change this to the specific time you want your test alarm to fire
/// Use 24-hour format, e.g. "08:00" = 8 AM, "20:30" = 8:30 PM
const String kDailyTestAlarmTime = "08:00";

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // 🌐 Configure API endpoint
  const apiUrl = String.fromEnvironment('API_BASE_URL', defaultValue: '');
  if (apiUrl.isEmpty) {
    apiClient.setBaseUrl('https://drillos-production.up.railway.app');
  } else {
    apiClient.setBaseUrl(apiUrl);
  }

  // 🔔 Initialize alarm service (local only)
  await alarmService.init();
  await alarmService.requestPermissions();

  // ✅ Schedule a daily test alarm (for verification)
  await alarmService.scheduleAlarm(
    habitId: '__test_alarm__',
    habitName: 'Test Alarm',
    time: kDailyTestAlarmTime,
    daysOfWeek: const [1, 2, 3, 4, 5, 6, 7],
    mentorMessage: '🔔 DrillOS test alarm fired successfully!',
  );

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
              builder: (context, state) => NewHomeScreen(
                refreshTrigger: state.uri.queryParameters['refresh'],
              ),
            ),
            GoRoute(
              path: '/habits',
              builder: (context, state) => const NewHabitsScreen(),
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
    ); // ✅ everything now closed properly

    return MaterialApp.router(
      title: 'Drill OS',
      debugShowCheckedModeBanner: false,
      theme: buildDarkTheme(),
      routerConfig: router,
    );
  }
}
