import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../design/glass.dart';
import '../design/tokens.dart';
import '../design/feedback.dart';
import '../audio/tts_provider.dart';
import '../services/local_storage.dart';
import '../logic/habit_engine.dart';

class StreaksScreen extends StatefulWidget {
  const StreaksScreen({super.key});

  @override
  State<StreaksScreen> createState() => _StreaksScreenState();
}

class _StreaksScreenState extends State<StreaksScreen>
    with TickerProviderStateMixin {
  late AnimationController _flameController;
  late AnimationController _confettiController;

  bool loading = false;
  int overallStreak = 0;
  double weeklyCurrent = 0;
  double weeklyGoal = 6.0;
  List<CategoryStreak> categories = [];

  final List<Achievement> achievements = [
    Achievement(
      id: 'first_week',
      title: 'First Week',
      subtitle: '7-day streak',
      unlocked: false,
    ),
    Achievement(
      id: 'first_month',
      title: 'First Month Younger',
      subtitle: '30-day streak',
      unlocked: false,
    ),
    Achievement(
      id: 'time_bandit',
      title: 'Time Bandit',
      subtitle: 'Saved 100+ hours',
      unlocked: false,
    ),
    Achievement(
      id: 'consistency_king',
      title: 'Consistency King',
      subtitle: '30-day habit streak',
      unlocked: false,
    ),
    Achievement(
      id: 'century_club',
      title: 'Century Club',
      subtitle: '100-day streak',
      unlocked: false,
    ),
    Achievement(
      id: 'year_one',
      title: 'Year One',
      subtitle: '365-day streak',
      unlocked: false,
    ),
  ];

  @override
  void initState() {
    super.initState();
    _flameController =
        AnimationController(vsync: this, duration: const Duration(milliseconds: 800));
    _confettiController =
        AnimationController(vsync: this, duration: const Duration(seconds: 2));

    WidgetsBinding.instance.addPostFrameCallback((_) => _loadStreaks());
  }

  @override
  void dispose() {
    _flameController.dispose();
    _confettiController.dispose();
    super.dispose();
  }

  Future<void> _loadStreaks() async {
    setState(() => loading = true);
    try {
      final allHabits = await localStorage.getAllHabits();
      int total = 0;
      final catList = <CategoryStreak>[];

      for (final h in allHabits) {
        final streak = await localStorage.getStreak(h['id']);
        total += streak;
        final name = (h['name'] ?? h['title'] ?? 'Habit').toString();
        catList.add(CategoryStreak(
          id: h['id'],
          name: name,
          days: streak,
          icon: Icons.local_fire_department,
          color: Colors.orangeAccent,
        ));
      }

      // Sort top 5
      catList.sort((a, b) => b.days.compareTo(a.days));
      if (catList.length > 5) catList.removeRange(5, catList.length);

      final overall = total > 0
          ? (total ~/ (allHabits.isEmpty ? 1 : allHabits.length))
          : 0;

      setState(() {
        overallStreak = overall;
        categories = catList;
        weeklyCurrent = (overallStreak / 7).clamp(0, weeklyGoal);
        loading = false;
      });
    } catch (e) {
      setState(() => loading = false);
      Toast.show(context, 'Failed to load streaks');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: const GlassAppBar(title: 'Streaks'),
      backgroundColor: const Color(0xFF0B0F0E),
      body: loading
          ? const Center(
              child: CircularProgressIndicator(color: Colors.orangeAccent),
            )
          : RefreshIndicator(
              onRefresh: _loadStreaks,
              child: ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  _buildFlameHeroCard(),
                  const SizedBox(height: 20),
                  _buildAllStreaksSection(),
                  const SizedBox(height: 20),
                  _buildWeeklyTargetSection(),
                  const SizedBox(height: 20),
                  _buildAchievementsSection(),
                  const SizedBox(height: 20),
                  _buildCtaCard(),
                ],
              ),
            ),
    );
  }

  Widget _buildFlameHeroCard() {
    return GradientGlassCard(
      colors: const [Colors.orange, Colors.redAccent],
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          children: [
            AnimatedBuilder(
              animation: _flameController,
              builder: (context, child) => Transform.scale(
                scale: 1.0 + (_flameController.value * 0.1),
                child: Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: Colors.orange.withOpacity(0.2),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.orange.withOpacity(0.4),
                        blurRadius: 20,
                        spreadRadius: 2,
                      ),
                    ],
                  ),
                  child: const Icon(
                    Icons.local_fire_department,
                    size: 64,
                    color: Colors.orange,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 16),
            Text(
              '$overallStreak',
              style: Theme.of(context).textTheme.displayLarge?.copyWith(
                    fontSize: 48,
                    fontWeight: FontWeight.w900,
                    color: Colors.orange,
                  ),
            ),
            const SizedBox(height: 4),
            Text(
              'day streak',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    color: DSXColors.textSecondary,
                  ),
            ),
            const SizedBox(height: 8),
            Text(
              overallStreak == 0
                  ? "Let's light your first flame!"
                  : "You're on fire — keep it up!",
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: Colors.orange.withOpacity(0.8),
                  ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAllStreaksSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('All Streaks', style: Theme.of(context).textTheme.titleLarge),
        const SizedBox(height: 12),
        if (categories.isEmpty)
          GlassCard(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Center(
                child: Text(
                  "No streaks yet — complete a habit to begin your journey.",
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
              ),
            ),
          )
        else
          ...categories.map((category) => Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: _buildCategoryStreakCard(category),
              )),
      ],
    );
  }

  Widget _buildCategoryStreakCard(CategoryStreak category) {
    return GlassCard(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: category.color.withOpacity(0.15),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(category.icon, color: category.color, size: 24),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(category.name,
                  style: Theme.of(context).textTheme.titleMedium),
            ),
            Text(
              '${category.days}',
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    color: category.color,
                    fontWeight: FontWeight.w800,
                  ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildWeeklyTargetSection() {
    final progress = (weeklyCurrent / weeklyGoal).clamp(0.0, 1.0);
    return GlassCard(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Weekly Target',
                style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 12),
            Text('Life days gained this week',
                style: Theme.of(context).textTheme.bodyMedium),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: Container(
                    height: 8,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(4),
                      color: Colors.white.withOpacity(0.1),
                    ),
                    child: FractionallySizedBox(
                      alignment: Alignment.centerLeft,
                      widthFactor: progress,
                      child: Container(
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(4),
                          gradient: LinearGradient(
                            colors: [DSXColors.accent, Colors.green],
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Text(
                  '${weeklyCurrent.toStringAsFixed(1)} / ${weeklyGoal.toStringAsFixed(0)}',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        color: DSXColors.accent,
                      ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAchievementsSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Achievements', style: Theme.of(context).textTheme.titleLarge),
        const SizedBox(height: 12),
        ...achievements.map((a) => Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: _buildAchievementCard(a),
            )),
      ],
    );
  }

  Widget _buildAchievementCard(Achievement a) {
    return GlassCard(
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(8),
          border: a.unlocked
              ? Border.all(color: Colors.amber.withOpacity(0.3), width: 1)
              : null,
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: a.unlocked
                    ? Colors.amber.withOpacity(0.15)
                    : Colors.white.withOpacity(0.05),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(
                _getAchievementIcon(a.id),
                color: a.unlocked ? Colors.amber : Colors.white.withOpacity(0.3),
                size: 24,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(a.title,
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                            color: a.unlocked
                                ? DSXColors.textPrimary
                                : DSXColors.textSecondary,
                          )),
                  Text(a.subtitle,
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                            color: a.unlocked
                                ? DSXColors.textSecondary
                                : Colors.white.withOpacity(0.3),
                          )),
                ],
              ),
            ),
            if (a.unlocked)
              const Icon(Icons.check_circle, color: Colors.green, size: 20),
          ],
        ),
      ),
    );
  }

  IconData _getAchievementIcon(String id) {
    switch (id) {
      case 'first_week':
      case 'first_month':
      case 'consistency_king':
        return Icons.emoji_events;
      case 'time_bandit':
        return Icons.access_time;
      case 'century_club':
        return Icons.military_tech;
      case 'year_one':
        return Icons.diamond;
      default:
        return Icons.star;
    }
  }

  Widget _buildCtaCard() {
    return GlassCard(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.security, color: DSXColors.accent, size: 20),
                const SizedBox(width: 8),
                Text('Streak Insurance',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          color: DSXColors.accent,
                        )),
              ],
            ),
            const SizedBox(height: 8),
            Text('Protect your streak for \$4.99/month',
                style: Theme.of(context).textTheme.bodyMedium),
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: GlassButton.primary('Get Protection', onPressed: () {
                Toast.show(context, 'Opening streak protection...');
              }),
            ),
          ],
        ),
      ),
    );
  }
}

// ---------------- Models ----------------
class CategoryStreak {
  final String id;
  final String name;
  final int days;
  final IconData icon;
  final Color color;

  CategoryStreak({
    required this.id,
    required this.name,
    required this.days,
    required this.icon,
    required this.color,
  });
}

class Achievement {
  final String id;
  final String title;
  final String subtitle;
  final bool unlocked;

  Achievement({
    required this.id,
    required this.title,
    required this.subtitle,
    required this.unlocked,
  });
}
