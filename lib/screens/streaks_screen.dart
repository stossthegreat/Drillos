import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../design/glass.dart';
import '../design/tokens.dart';
import '../badges/flame_badge.dart';
import '../design/charts/ring_progress.dart';
import '../design/feedback.dart';
import '../audio/tts_provider.dart';
import "../services/api_client.dart";

class StreaksScreen extends StatefulWidget {
  const StreaksScreen({super.key});

  @override
  State<StreaksScreen> createState() => _StreaksScreenState();
}

class _StreaksScreenState extends State<StreaksScreen> with TickerProviderStateMixin {
  late AnimationController _flameController;
  late AnimationController _confettiController;
  
  // Mock data - will be replaced with real data from backend
  int overallStreak = 47;
  double weeklyCurrent = 4.8;
  double weeklyGoal = 6.0;
  bool loading = false;

  void _loadAchievements() async {
    setState(() { loading = true; });
    
    try {
      // Set auth token (in production this would come from authentication)
      apiClient.setAuthToken("valid-token");
      
      final achievementsData = await apiClient.getAchievements();
      final streaksData = await apiClient.getStreakSummary();
      
      setState(() {
        // Update with real data
        overallStreak = streaksData["overall"] ?? overallStreak;
        categories = _mapCategories((streaksData["categories"] ?? []) as List);
        loading = false;
      });
      
      print("✅ Achievements loaded: ${achievementsData["achievements"].length} total");
      
    } catch (e) {
      print("❌ Failed to load achievements: $e");
      setState(() { loading = false; });
      Toast.show(context, "Failed to load achievements: $e");
    }
  }
  
  List<CategoryStreak> categories = [];
  
  final List<Achievement> achievements = [
    Achievement(id: 'first_week', title: 'First Week', subtitle: '7-day streak', unlocked: true, unlockedAt: DateTime.now().subtract(const Duration(days: 20))),
    Achievement(id: 'first_month', title: 'First Month Younger', subtitle: '30-day streak', unlocked: true, unlockedAt: DateTime.now().subtract(const Duration(days: 5))),
    Achievement(id: 'time_bandit', title: 'Time Bandit', subtitle: 'Saved 100+ hours', unlocked: true, unlockedAt: DateTime.now().subtract(const Duration(days: 10))),
    Achievement(id: 'consistency_king', title: 'Consistency King', subtitle: '30-day habit streak', unlocked: true, unlockedAt: DateTime.now().subtract(const Duration(days: 5))),
    Achievement(id: 'century_club', title: 'Century Club', subtitle: '100-day streak', unlocked: false),
    Achievement(id: 'year_one', title: 'Year One', subtitle: '365-day streak', unlocked: false),
  ];

  @override
  void initState() {
    super.initState();
    _flameController = AnimationController(
      duration: const Duration(milliseconds: 800),
      vsync: this,
    );
    _confettiController = AnimationController(
      duration: const Duration(milliseconds: 2000),
      vsync: this,
    );
    
    // Simulate checking for new achievements
_loadAchievements();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _checkForNewAchievements();
    });
  }

  @override
  void dispose() {
    _flameController.dispose();
    _confettiController.dispose();
    super.dispose();
  }

  void _checkForNewAchievements() {
    // Simulate achievement unlock animation
    if (overallStreak >= 30) {
      Future.delayed(const Duration(milliseconds: 500), () {
        _triggerAchievementUnlock('First Month Younger');
      });
    }
  }

  void _triggerAchievementUnlock(String title) {
    HapticFeedback.mediumImpact();
    _confettiController.forward().then((_) => _confettiController.reset());
    // ConfettiStub.burst(context); // TODO: Implement confetti
    
    // Play praise audio
    final tts = TtsProvider();
    tts.playPreset('praise_30_day');
    
    Toast.show(context, '🎉 Achievement Unlocked: $title!');
  }

  List<CategoryStreak> _mapCategories(List apiCategories) {
    final mapped = apiCategories.map((c) {
      final id = (c['id'] ?? '').toString();
      final icon = _iconForCategory(id);
      final color = _colorForCategory(id);
      return CategoryStreak(
        id: id,
        name: (c['name'] ?? '').toString(),
        days: (c['days'] ?? 0) as int,
        icon: icon,
        color: color,
      );
    }).toList();

    // Always include overall, even if 0; filter others with > 0
    final overall = mapped.where((m) => m.id == 'overall').toList();
    final others = mapped.where((m) => m.id != 'overall' && m.days > 0).toList();

    // Sort others by days desc
    others.sort((a, b) => b.days.compareTo(a.days));

    // Cap to top 6 (including overall)
    final limited = <CategoryStreak>[];
    if (overall.isNotEmpty) limited.add(overall.first);
    for (final c in others) {
      if (limited.length >= 6) break;
      limited.add(c);
    }
    return limited;
  }

  IconData _iconForCategory(String id) {
    switch (id) {
      case 'overall':
        return Icons.local_fire_department;
      case 'clean':
        return Icons.health_and_safety;
      case 'morning':
        return Icons.wb_sunny;
      case 'deep_work':
        return Icons.timer_outlined;
      case 'two_plus':
        return Icons.done_all;
      case 'perfect':
        return Icons.verified;
      case 'alarm':
        return Icons.alarm_on;
      case 'commit':
        return Icons.task_alt;
      default:
        return Icons.star_outline;
    }
  }

  Color _colorForCategory(String id) {
    switch (id) {
      case 'overall':
        return Colors.orange;
      case 'clean':
        return Colors.teal;
      case 'morning':
        return Colors.amber;
      case 'deep_work':
        return Colors.indigo;
      case 'two_plus':
        return Colors.green;
      case 'perfect':
        return Colors.amberAccent;
      case 'alarm':
        return Colors.redAccent;
      case 'commit':
        return Colors.blueAccent;
      default:
        return DSXColors.accent;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: const GlassAppBar(title: 'Streaks'),
      body: loading 
        ? const Center(child: CircularProgressIndicator())
        : ListView(
            padding: const EdgeInsets.all(16),
            children: [
              // Flame Hero Card
              _buildFlameHeroCard(),
              const SizedBox(height: 20),
              
              // All Streaks Section
              _buildAllStreaksSection(),
              const SizedBox(height: 20),
              
              // Weekly Target
              _buildWeeklyTargetSection(),
              const SizedBox(height: 20),
              
              // Achievements
              _buildAchievementsSection(),
              const SizedBox(height: 20),
              
              // CTA Card
              _buildCtaCard(),
              const SizedBox(height: 24),
            ],
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
              builder: (context, child) {
                return Transform.scale(
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
                    child: Icon(
                      Icons.local_fire_department,
                      size: 64,
                      color: Colors.orange,
                    ),
                  ),
                );
              },
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
              "You're in the top 15% for consistency!",
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
        Text(
          'All Streaks',
          style: Theme.of(context).textTheme.titleLarge,
        ),
        const SizedBox(height: 12),
        ...categories.map((category) => Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: _buildCategoryStreakCard(category),
        )),
      ],
    );
  }

  Widget _buildCategoryStreakCard(CategoryStreak category) {
    return GlassCard(
      child: InkWell(
        onTap: () {
          // Navigate to habits with filter
          HapticFeedback.lightImpact();
          // context.push('/habits?category=${category.id}');
        },
        borderRadius: BorderRadius.circular(DSXRadii.md),
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
                child: Icon(
                  category.icon,
                  color: category.color,
                  size: 24,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  category.name,
                  style: Theme.of(context).textTheme.titleMedium,
                ),
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
            Text(
              'Weekly Target',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 12),
            Text(
              'Life days gained this week',
              style: Theme.of(context).textTheme.bodyMedium,
            ),
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
        Text(
          'Achievements',
          style: Theme.of(context).textTheme.titleLarge,
        ),
        const SizedBox(height: 12),
        ...achievements.map((achievement) => Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: _buildAchievementCard(achievement),
        )),
      ],
    );
  }

  Widget _buildAchievementCard(Achievement achievement) {
    return GlassCard(
      child: InkWell(
        onTap: achievement.unlocked ? () {
          HapticFeedback.lightImpact();
          if (achievement.presetAudioId != null) {
            final tts = TtsProvider();
            tts.playPreset(achievement.presetAudioId!);
          }
          Toast.show(context, achievement.subtitle);
        } : null,
        borderRadius: BorderRadius.circular(DSXRadii.md),
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: achievement.unlocked ? BoxDecoration(
            borderRadius: BorderRadius.circular(DSXRadii.md),
            border: Border.all(
              color: Colors.amber.withOpacity(0.3),
              width: 1,
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.amber.withOpacity(0.1),
                blurRadius: 8,
                spreadRadius: 1,
              ),
            ],
          ) : null,
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: achievement.unlocked 
                    ? Colors.amber.withOpacity(0.15)
                    : Colors.white.withOpacity(0.05),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(
                  _getAchievementIcon(achievement.id),
                  color: achievement.unlocked 
                    ? Colors.amber
                    : Colors.white.withOpacity(0.3),
                  size: 24,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      achievement.title,
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        color: achievement.unlocked 
                          ? DSXColors.textPrimary
                          : DSXColors.textSecondary,
                      ),
                    ),
                    Text(
                      achievement.subtitle,
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: achievement.unlocked 
                          ? DSXColors.textSecondary
                          : Colors.white.withOpacity(0.3),
                      ),
                    ),
                  ],
                ),
              ),
              if (achievement.unlocked)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.green.withOpacity(0.15),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.green.withOpacity(0.3)),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.check, color: Colors.green, size: 16),
                      const SizedBox(width: 4),
                      Text(
                        'Earned',
                        style: Theme.of(context).textTheme.labelSmall?.copyWith(
                          color: Colors.green,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
            ],
          ),
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
                Text(
                  'Streak Insurance',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    color: DSXColors.accent,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              'Protect your streak for \$5/month',
              style: Theme.of(context).textTheme.bodyMedium,
            ),
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: GlassButton.primary(
                'Get Protection',
                onPressed: () {
                  // Open paywall/Stripe
                  Toast.show(context, 'Opening streak protection...');
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// Data models
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
  final DateTime? unlockedAt;
  final String? presetAudioId;

  Achievement({
    required this.id,
    required this.title,
    required this.subtitle,
    required this.unlocked,
    this.unlockedAt,
    this.presetAudioId,
  });
} 