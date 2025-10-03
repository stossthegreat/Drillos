import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:math' as math;

class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key});

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen>
    with TickerProviderStateMixin {
  int stepIndex = 0;
  String? selectedMentor;
  final Set<String> selectedHabits = {};
  bool morning = true, midday = true, evening = true;
  bool notificationsEnabled = false;
  double badScore = 0.0;
  String billing = 'monthly';

  late final AnimationController _orbController;
  late final AnimationController _fadeController;
  late final List<_OrbData> _orbs;

  final List<_StepSpec> steps = [];

  static const List<List<dynamic>> _starterHabits = [
    ['water', 'Drink 2L Water', 0.20],
    ['steps', '8k Steps', 0.20],
    ['sleep', 'Sleep by 11pm', 0.25],
    ['focus', '45m Deep Work', 0.25],
    ['gym', 'Workout', 0.30],
    ['reading', 'Read 10 pages', 0.15],
  ];

  @override
  void initState() {
    super.initState();
    _orbController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 20),
    )..repeat();
    
    _fadeController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
    );

    _generateOrbs();
    // Don't build steps here - they need context from build()
    _loadPersisted();
    _fadeController.forward();
  }

  @override
  void dispose() {
    _orbController.dispose();
    _fadeController.dispose();
    super.dispose();
  }

  void _generateOrbs() {
    final random = math.Random(42); // Fixed seed for consistent layout
    _orbs = List.generate(6, (i) {
      return _OrbData(
        x: random.nextDouble(),
        y: random.nextDouble(),
        size: 100 + random.nextDouble() * 200,
        speed: 0.3 + random.nextDouble() * 0.7,
        color: [
          const Color(0xFF10B981).withOpacity(0.1),
          const Color(0xFF3B82F6).withOpacity(0.08),
          const Color(0xFF8B5CF6).withOpacity(0.06),
          const Color(0xFFF59E0B).withOpacity(0.05),
        ][i % 4],
      );
    });
  }

  void _buildSteps() {
    steps.clear();
    steps.addAll([
      _StepSpec(
        id: 'welcome',
        title: 'Welcome to Drill OS',
        subtitle: 'The first active Habit OS — alive, not passive.',
        body: _buildWelcome(),
      ),
      _StepSpec(
        id: 'account',
        title: 'Create Account',
        subtitle: 'Sign in to sync your progress across devices.',
        body: _buildAccount(),
      ),
      _StepSpec(
        id: 'mentor',
        title: 'Choose Your Mentor',
        subtitle: 'Pick a voice to guide (or push) you.',
        body: _buildMentorChoice(),
      ),
      _StepSpec(
        id: 'habits',
        title: 'Build Your Stack',
        subtitle: 'Select 3–6 core habits. You can edit later.',
        body: _buildHabitsChoice(),
      ),
      _StepSpec(
        id: 'schedule',
        title: 'Set Your Cadence',
        subtitle: 'When should we nudge you?',
        body: _buildSchedule(),
      ),
      _StepSpec(
        id: 'engine',
        title: 'How We Judge Days',
        subtitle: 'Offset Engine preview: good vs bad → net score.',
        body: _buildOffsetEngine(),
      ),
      _StepSpec(
        id: 'permissions',
        title: 'Stay On Track',
        subtitle: 'Enable notifications so your mentor can reach you.',
        body: _buildPermissions(),
      ),
      _StepSpec(
        id: 'paywall',
        title: 'Unlock Drill OS',
        subtitle: 'Go Free or power up with Pro.',
        body: _buildPaywall(),
      ),
    ]);
  }

  bool get canProceed {
    final id = steps[stepIndex].id;
    if (id == 'mentor') return selectedMentor != null;
    if (id == 'habits') return selectedHabits.length >= 3 && selectedHabits.length <= 6;
    if (id == 'schedule') return morning || midday || evening;
    return true;
  }

  void _next() {
    if (!canProceed) return;
    if (stepIndex < steps.length - 1) {
      setState(() => stepIndex++);
      _persist();
    } else {
      _complete();
    }
  }

  void _prev() {
    if (stepIndex > 0) {
      setState(() => stepIndex--);
      _persist();
    }
  }

  Future<void> _complete() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('onboarding_done', true);
    await prefs.remove('onboarding_state');
    if (mounted) context.go('/home');
  }

  Future<void> _loadPersisted() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final json = prefs.getString('onboarding_state');
      if (json != null && json.isNotEmpty) {
        final map = _decodeJson(json);
        setState(() {
          stepIndex = (map['stepIndex'] ?? stepIndex) is int ? map['stepIndex'] : stepIndex;
          selectedMentor = (map['selectedMentor'] ?? selectedMentor) as String?;
          final List<dynamic> saved = (map['selectedHabits'] ?? []) as List<dynamic>;
          selectedHabits
            ..clear()
            ..addAll(saved.map((e) => e.toString()));
          final sched = map['schedule'] as Map<String, dynamic>?;
          if (sched != null) {
            morning = sched['morning'] == true;
            midday = sched['midday'] == true;
            evening = sched['evening'] == true;
          }
          notificationsEnabled = map['notificationsEnabled'] == true;
          badScore = (map['badScore'] is num) ? (map['badScore'] as num).toDouble() : badScore;
          billing = (map['billing'] is String) ? map['billing'] as String : billing;
        });
        _buildSteps();
      }
    } catch (_) {}
  }

  void _persist() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final map = {
        'stepIndex': stepIndex,
        'selectedMentor': selectedMentor,
        'selectedHabits': selectedHabits.toList(),
        'schedule': {'morning': morning, 'midday': midday, 'evening': evening},
        'notificationsEnabled': notificationsEnabled,
        'badScore': badScore,
        'billing': billing,
      };
      await prefs.setString('onboarding_state', _encodeJson(map));
    } catch (_) {}
  }

  Widget _buildWelcome() {
    return Column(
      children: [
        // Hero Card with Mentor Avatars
        _HeroCard(),
        const SizedBox(height: 24),
        _GlassCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Active Habit Operating System',
                style: TextStyle(fontSize: 16, color: Colors.white70, fontWeight: FontWeight.w500),
              ),
              const SizedBox(height: 8),
              const Text(
                'A council of mentors that remembers, adapts, and pushes you daily.',
                style: TextStyle(color: Colors.white60, height: 1.4),
              ),
              const SizedBox(height: 16),
              Wrap(spacing: 8, runSpacing: 8, children: const [
                _Badge('Mentor Voices'),
                _Badge('Strictness Levels'),
                _Badge('Weekly Reports'),
              ]),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildAccount() {
    return _GlassCard(
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        const Text(
          'Sign in to sync your data and keep your streaks safe.',
          style: TextStyle(color: Colors.white70, height: 1.4),
        ),
        const SizedBox(height: 16),
        Row(children: [
          Expanded(
            child: _GlassButton(
              label: 'Continue with Email',
              onTap: () { _next(); _persist(); },
              primary: true,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: _GlassButton(
              label: 'Guest Mode',
              onTap: () { _next(); _persist(); },
            ),
          ),
        ]),
        const SizedBox(height: 12),
        const Text(
          'You can link your account later in settings.',
          style: const TextStyle(fontSize: 12, color: Color(0x66FFFFFF)),
        ),
      ]),
    );
  }

  Widget _buildMentorChoice() {
    const mentorList = [
      ['drill', 'Drill Sergeant', 'Aggressive • No excuses', '🎖️'],
      ['marcus', 'Marcus Aurelius', 'Stoic • Calm Authority', '🏛️'],
      ['confucius', 'Confucius', 'Order • Discipline', '📚'],
      ['buddha', 'Buddha', 'Compassion • Presence', '🧘'],
      ['lincoln', 'Abraham Lincoln', 'Moral • Resolute', '🎩'],
    ];
    
    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        crossAxisSpacing: 12,
        mainAxisSpacing: 12,
        childAspectRatio: 1.2,
      ),
      itemCount: mentorList.length,
      itemBuilder: (context, index) {
        final m = mentorList[index];
        final active = selectedMentor == m[0];
        return _MentorCard(
          active: active,
          emoji: m[3],
          title: m[1],
          subtitle: m[2],
          onTap: () => setState(() {
            selectedMentor = m[0];
            _persist();
          }),
        );
      },
    );
  }

  Widget _buildHabitsChoice() {
    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        crossAxisSpacing: 12,
        mainAxisSpacing: 12,
        childAspectRatio: 1.8,
      ),
      itemCount: _starterHabits.length,
      itemBuilder: (context, index) {
        final h = _starterHabits[index];
        final id = h[0] as String;
        final label = h[1] as String;
        final active = selectedHabits.contains(id);
        return _HabitCard(
          active: active,
          title: label,
          weight: (h[2] as num).toDouble(),
          onTap: () => setState(() {
            if (active) {
              selectedHabits.remove(id);
            } else {
              selectedHabits.add(id);
            }
            _persist();
          }),
        );
      },
    );
  }

  Widget _buildSchedule() {
    return Row(children: [
      Expanded(
        child: _ScheduleCard(
          active: morning,
          title: 'Morning',
          subtitle: 'Primer & plan',
          icon: '🌅',
          onTap: () => setState(() { morning = !morning; _persist(); }),
        ),
      ),
      const SizedBox(width: 12),
      Expanded(
        child: _ScheduleCard(
          active: midday,
          title: 'Midday',
          subtitle: 'Adaptive nudge',
          icon: '☀️',
          onTap: () => setState(() { midday = !midday; _persist(); }),
        ),
      ),
      const SizedBox(width: 12),
      Expanded(
        child: _ScheduleCard(
          active: evening,
          title: 'Evening',
          subtitle: 'Reflection',
          icon: '🌙',
          onTap: () => setState(() { evening = !evening; _persist(); }),
        ),
      ),
    ]);
  }

  Widget _buildOffsetEngine() {
    final good = _computeGoodScore();
    final net = (good - badScore).clamp(-1.0, 1.0);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: _MetricCard(
                title: 'Good from Habits',
                value: '+${good.toStringAsFixed(2)}',
                subtitle: 'Based on selected starters',
                color: const Color(0xFF10B981),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _GlassCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Bad (Late-night/Skip/Scroll)',
                      style: TextStyle(color: Color(0xFFfda4af), fontSize: 12, fontWeight: FontWeight.w500),
                    ),
                    const SizedBox(height: 8),
                    SliderTheme(
                      data: SliderTheme.of(context).copyWith(
                        activeTrackColor: const Color(0xFFE11D48),
                        inactiveTrackColor: Colors.white10,
                        thumbColor: const Color(0xFFE11D48),
                        overlayColor: const Color(0xFFE11D48).withOpacity(0.2),
                        trackHeight: 4,
                      ),
                      child: Slider(
                        value: badScore,
                        min: 0,
                        max: 1,
                        divisions: 20,
                        onChanged: (v) => setState(() { badScore = v; _persist(); }),
                      ),
                    ),
                    Text(
                      '-${badScore.toStringAsFixed(2)}',
                      style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w600),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        _GlassCard(
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('Net Score Preview', style: TextStyle(color: Colors.white70, fontWeight: FontWeight.w500)),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: net >= 0 ? const Color(0xFF10B981).withOpacity(0.15) : const Color(0xFFE11D48).withOpacity(0.15),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: net >= 0 ? const Color(0xFF10B981).withOpacity(0.3) : const Color(0xFFE11D48).withOpacity(0.3),
                  ),
                ),
                child: Text(
                  'Net ${net.toStringAsFixed(2)}',
                  style: TextStyle(
                    color: net >= 0 ? const Color(0xFF86efac) : const Color(0xFFfca5a5),
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  double _computeGoodScore() {
    double sum = 0.0;
    for (final h in _starterHabits) {
      if (selectedHabits.contains(h[0])) {
        sum += (h[2] as num).toDouble();
      }
    }
    return sum;
  }

  Widget _buildPermissions() {
    return Column(
      children: [
        _HeroCard(showNotificationIcon: true),
        const SizedBox(height: 24),
        _GlassCard(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            const Text(
              'Enable notifications so your mentor can reach you at the right moment.',
              style: TextStyle(color: Colors.white70, height: 1.4),
            ),
            const SizedBox(height: 16),
            _GlassButton(
              label: notificationsEnabled ? '✓ Notifications Enabled' : 'Enable Notifications',
              onTap: () => setState(() { notificationsEnabled = true; _persist(); }),
              primary: !notificationsEnabled,
            ),
          ]),
        ),
      ],
    );
  }

  Widget _buildPaywall() {
    final monthly = 4.99;
    final yearly = 39.99;
    final price = billing == 'monthly' ? monthly : yearly;
    final saving = billing == 'yearly' ? (((1 - (yearly / (monthly * 12))) * 100).round()) : 0;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _GlassCard(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            const Text(
              'Unlock mentors with real voices, strictness levels, adaptive nudges, and report cards.',
              style: TextStyle(color: Colors.white70, height: 1.4),
            ),
            const SizedBox(height: 16),
            // Billing Toggle
            Container(
              padding: const EdgeInsets.all(4),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.05),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.white10),
              ),
              child: Row(children: [
                Expanded(
                  child: _ToggleChip(
                    label: 'Monthly',
                    active: billing == 'monthly',
                    onTap: () => setState(() { billing = 'monthly'; _persist(); }),
                  ),
                ),
                Expanded(
                  child: _ToggleChip(
                    label: 'Yearly',
                    active: billing == 'yearly',
                    onTap: () => setState(() { billing = 'yearly'; _persist(); }),
                  ),
                ),
              ]),
            ),
            const SizedBox(height: 12),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  '\$${price.toStringAsFixed(2)} ${billing == 'monthly' ? '/ month' : '/ year'}',
                  style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w600),
                ),
                if (saving > 0)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: const Color(0xFF10B981).withOpacity(0.15),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      'Save $saving%',
                      style: const TextStyle(color: Color(0xFF86efac), fontSize: 12, fontWeight: FontWeight.w600),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 16),
            const _FeatureList(title: 'Free includes', features: [
              'Smart alarms & streaks',
              'Habits & tasks',
              'Local stats',
            ]),
            const SizedBox(height: 16),
            const _FeatureList(title: 'Pro adds', features: [
              'AI mentors with real voices',
              'Strictness levels + adaptive nudges',
              'Weekly report cards & insights',
              'Offset engine: bad cancels good',
              'Duels, quests, seasonal events',
            ]),
            const SizedBox(height: 20),
            Row(children: [
              Expanded(
                child: _GlassButton(
                  label: billing == 'monthly' ? 'Start Pro – \$4.99' : 'Start Pro – \$39.99',
                  onTap: _complete,
                  primary: true,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _GlassButton(
                  label: 'Maybe Later',
                  onTap: _complete,
                ),
              ),
            ]),
            const SizedBox(height: 12),
            const Text(
              'By continuing you agree to our Terms & Privacy.',
              style: TextStyle(color: Colors.white30, fontSize: 10),
              textAlign: TextAlign.center,
            ),
          ]),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    // Build steps on first build when context is available
    if (steps.isEmpty) {
      _buildSteps();
    }
    final spec = steps[stepIndex];
    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          // Animated Gradient Orbs Background
          AnimatedBuilder(
            animation: _orbController,
            builder: (context, child) {
              return CustomPaint(
                painter: _OrbPainter(_orbs, _orbController.value),
                size: Size.infinite,
              );
            },
          ),
          // Subtle Grid Overlay
          CustomPaint(
            painter: _GridPainter(),
            size: Size.infinite,
          ),
          // Main Content
          SafeArea(
            child: FadeTransition(
              opacity: _fadeController,
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // Progress Rail
                    _StepRail(steps: steps, current: stepIndex),
                    const SizedBox(height: 20),
                    // Header
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Row(children: [
                          Container(
                            width: 40,
                            height: 40,
                            decoration: BoxDecoration(
                              gradient: const LinearGradient(
                                colors: [Color(0xFF10B981), Color(0xFF059669)],
                              ),
                              borderRadius: BorderRadius.circular(12),
                              boxShadow: [
                                BoxShadow(
                                  color: const Color(0xFF10B981).withOpacity(0.3),
                                  blurRadius: 8,
                                  offset: const Offset(0, 2),
                                ),
                              ],
                            ),
                            alignment: Alignment.center,
                            child: const Text(
                              'D',
                              style: TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                                fontSize: 18,
                              ),
                            ),
                          ),
                          const SizedBox(width: 12),
                          const Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Drill OS',
                                style: TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.w600),
                              ),
                              Text(
                                'Active Habit Operating System',
                                style: const TextStyle(color: Color(0x66FFFFFF), fontSize: 11),
                              ),
                            ],
                          ),
                        ]),
                        _ProgressDots(index: stepIndex, total: steps.length),
                      ],
                    ),
                    const SizedBox(height: 24),
                    // Title & Subtitle
                    Text(
                      spec.title,
                      style: const TextStyle(
                        fontSize: 28,
                        fontWeight: FontWeight.w700,
                        color: Colors.white,
                        height: 1.2,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      spec.subtitle,
                      style: const TextStyle(
                        color: Colors.white60,
                        fontSize: 16,
                        height: 1.4,
                      ),
                    ),
                    const SizedBox(height: 32),
                    // Content
                    Expanded(
                      child: AnimatedSwitcher(
                        duration: const Duration(milliseconds: 300),
                        child: Container(
                          key: ValueKey(spec.id),
                          child: spec.body,
                        ),
                      ),
                    ),
                    const SizedBox(height: 24),
                    // Navigation
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        if (stepIndex > 0)
                          _GlassButton(
                            label: '← Back',
                            onTap: _prev,
                          )
                        else
                          const SizedBox(width: 80),
                        if (!canProceed)
                          Text(
                            (steps[stepIndex].id == 'mentor') ? 'Select a mentor' :
                            (steps[stepIndex].id == 'habits') ? 'Choose 3–6' :
                            (steps[stepIndex].id == 'schedule') ? 'Pick at least one' : '',
                            style: const TextStyle(color: Color(0x66FFFFFF), fontSize: 12),
                          )
                        else
                          const SizedBox(),
                        _GlassButton(
                          label: stepIndex == steps.length - 1 ? 'Complete' : 'Next →',
                          onTap: canProceed ? _next : null,
                          primary: true,
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// Data Classes
class _StepSpec {
  final String id;
  final String title;
  final String subtitle;
  final Widget body;
  _StepSpec({required this.id, required this.title, required this.subtitle, required this.body});
}

class _OrbData {
  final double x;
  final double y;
  final double size;
  final double speed;
  final Color color;
  _OrbData({required this.x, required this.y, required this.size, required this.speed, required this.color});
}

// Custom Painters
class _OrbPainter extends CustomPainter {
  final List<_OrbData> orbs;
  final double animation;

  _OrbPainter(this.orbs, this.animation);

  @override
  void paint(Canvas canvas, Size size) {
    for (final orb in orbs) {
      final paint = Paint()
        ..shader = RadialGradient(
          colors: [
            orb.color,
            orb.color.withOpacity(0.3),
            Colors.transparent,
          ],
          stops: const [0.0, 0.7, 1.0],
        ).createShader(Rect.fromCircle(
          center: Offset(
            (orb.x + math.sin(animation * 2 * math.pi * orb.speed) * 0.1) * size.width,
            (orb.y + math.cos(animation * 2 * math.pi * orb.speed * 0.7) * 0.05) * size.height,
          ),
          radius: orb.size,
        ));

      canvas.drawCircle(
        Offset(
          (orb.x + math.sin(animation * 2 * math.pi * orb.speed) * 0.1) * size.width,
          (orb.y + math.cos(animation * 2 * math.pi * orb.speed * 0.7) * 0.05) * size.height,
        ),
        orb.size,
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}

class _GridPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.white.withOpacity(0.02)
      ..strokeWidth = 1;

    const spacing = 40.0;
    
    // Vertical lines
    for (double x = 0; x < size.width; x += spacing) {
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), paint);
    }
    
    // Horizontal lines
    for (double y = 0; y < size.height; y += spacing) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y), paint);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

// UI Components
class _GlassCard extends StatelessWidget {
  final Widget child;
  final EdgeInsets? padding;
  
  const _GlassCard({required this.child, this.padding});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: padding ?? const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.05),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: Colors.white.withOpacity(0.1),
          width: 1,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: child,
    );
  }
}

class _HeroCard extends StatelessWidget {
  final bool showNotificationIcon;
  
  const _HeroCard({this.showNotificationIcon = false});

  @override
  Widget build(BuildContext context) {
    return _GlassCard(
      child: Column(
        children: [
          // Mentor Avatars Row
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              _MentorAvatar('🎖️', 'Drill'),
              _MentorAvatar('🏛️', 'Marcus'),
              _MentorAvatar('📚', 'Confucius'),
              _MentorAvatar('🧘', 'Buddha'),
              _MentorAvatar('🎩', 'Lincoln'),
            ],
          ),
          if (showNotificationIcon) ...[
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color(0xFF10B981).withOpacity(0.1),
                borderRadius: BorderRadius.circular(50),
                border: Border.all(color: const Color(0xFF10B981).withOpacity(0.3)),
              ),
              child: const Icon(
                Icons.notifications_active,
                color: Color(0xFF10B981),
                size: 24,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _MentorAvatar extends StatelessWidget {
  final String emoji;
  final String name;
  
  const _MentorAvatar(this.emoji, this.name);

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Container(
          width: 50,
          height: 50,
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.1),
            borderRadius: BorderRadius.circular(25),
            border: Border.all(color: Colors.white.withOpacity(0.2)),
          ),
          child: Center(
            child: Text(
              emoji,
              style: const TextStyle(fontSize: 20),
            ),
          ),
        ),
        const SizedBox(height: 6),
        Text(
          name,
          style: const TextStyle(
            color: Colors.white60,
            fontSize: 10,
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
  }
}

class _MentorCard extends StatelessWidget {
  final bool active;
  final String emoji;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  const _MentorCard({
    required this.active,
    required this.emoji,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: active 
            ? const Color(0xFF10B981).withOpacity(0.1)
            : Colors.white.withOpacity(0.05),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: active 
              ? const Color(0xFF10B981).withOpacity(0.5)
              : Colors.white.withOpacity(0.1),
            width: active ? 2 : 1,
          ),
          boxShadow: active ? [
            BoxShadow(
              color: const Color(0xFF10B981).withOpacity(0.2),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ] : null,
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              emoji,
              style: const TextStyle(fontSize: 32),
            ),
            const SizedBox(height: 8),
            Text(
              title,
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w600,
                fontSize: 14,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 4),
            Text(
              subtitle,
              style: const TextStyle(
                color: Colors.white60,
                fontSize: 11,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}

class _HabitCard extends StatelessWidget {
  final bool active;
  final String title;
  final double weight;
  final VoidCallback onTap;

  const _HabitCard({
    required this.active,
    required this.title,
    required this.weight,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: active 
            ? const Color(0xFF10B981).withOpacity(0.1)
            : Colors.white.withOpacity(0.05),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: active 
              ? const Color(0xFF10B981).withOpacity(0.5)
              : Colors.white.withOpacity(0.1),
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Text(
                    title,
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w600,
                      fontSize: 13,
                    ),
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: const Color(0xFF10B981).withOpacity(0.2),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    '+${weight.toStringAsFixed(2)}',
                    style: const TextStyle(
                      color: Color(0xFF86efac),
                      fontSize: 10,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _ScheduleCard extends StatelessWidget {
  final bool active;
  final String title;
  final String subtitle;
  final String icon;
  final VoidCallback onTap;

  const _ScheduleCard({
    required this.active,
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: active 
            ? const Color(0xFF10B981).withOpacity(0.1)
            : Colors.white.withOpacity(0.05),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: active 
              ? const Color(0xFF10B981).withOpacity(0.5)
              : Colors.white.withOpacity(0.1),
          ),
        ),
        child: Column(
          children: [
            Text(
              icon,
              style: const TextStyle(fontSize: 24),
            ),
            const SizedBox(height: 8),
            Text(
              title,
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w600,
                fontSize: 14,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              subtitle,
              style: const TextStyle(
                color: Colors.white60,
                fontSize: 11,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}

class _MetricCard extends StatelessWidget {
  final String title;
  final String value;
  final String subtitle;
  final Color color;

  const _MetricCard({
    required this.title,
    required this.value,
    required this.subtitle,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return _GlassCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: TextStyle(
              color: color.withOpacity(0.8),
              fontSize: 12,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            value,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 18,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            subtitle,
            style: const TextStyle(
              color: Color(0x66FFFFFF),
              fontSize: 11,
            ),
          ),
        ],
      ),
    );
  }
}

class _GlassButton extends StatelessWidget {
  final String label;
  final VoidCallback? onTap;
  final bool primary;

  const _GlassButton({
    required this.label,
    required this.onTap,
    this.primary = false,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
        decoration: BoxDecoration(
          gradient: primary ? const LinearGradient(
            colors: [Color(0xFF10B981), Color(0xFF059669)],
          ) : null,
          color: primary ? null : Colors.white.withOpacity(0.05),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: primary 
              ? Colors.transparent
              : Colors.white.withOpacity(0.1),
          ),
          boxShadow: primary ? [
            BoxShadow(
              color: const Color(0xFF10B981).withOpacity(0.3),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ] : null,
        ),
        child: Text(
          label,
          style: TextStyle(
            color: primary ? Colors.white : Colors.white70,
            fontWeight: FontWeight.w600,
            fontSize: 14,
          ),
          textAlign: TextAlign.center,
        ),
      ),
    );
  }
}

class _ProgressDots extends StatelessWidget {
  final int index;
  final int total;

  const _ProgressDots({required this.index, required this.total});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: List.generate(total, (i) {
        final active = i == index;
        final completed = i < index;
        return Container(
          margin: const EdgeInsets.symmetric(horizontal: 2),
          height: 6,
          width: active ? 24 : 6,
          decoration: BoxDecoration(
            color: completed || active 
              ? const Color(0xFF10B981)
              : Colors.white.withOpacity(0.2),
            borderRadius: BorderRadius.circular(3),
          ),
        );
      }),
    );
  }
}

class _Badge extends StatelessWidget {
  final String text;

  const _Badge(this.text);

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.1),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.white.withOpacity(0.2)),
      ),
      child: Text(
        text,
        style: const TextStyle(
          color: Colors.white70,
          fontSize: 12,
          fontWeight: FontWeight.w500,
        ),
      ),
    );
  }
}

class _StepRail extends StatelessWidget {
  final List<_StepSpec> steps;
  final int current;

  const _StepRail({required this.steps, required this.current});

  @override
  Widget build(BuildContext context) {
    final progress = (current + 1) / steps.length;
    
    return Column(
      children: [
        Container(
          height: 4,
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.1),
            borderRadius: BorderRadius.circular(2),
          ),
          child: FractionallySizedBox(
            alignment: Alignment.centerLeft,
            widthFactor: progress,
            child: Container(
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(0xFF10B981), Color(0xFF059669)],
                ),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
        ),
        const SizedBox(height: 8),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: steps.asMap().entries.map((entry) {
            final i = entry.key;
            final step = entry.value;
            final active = i == current;
            final completed = i < current;
            
            return Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 8,
                  height: 8,
                  decoration: BoxDecoration(
                    color: completed || active 
                      ? const Color(0xFF10B981)
                      : Colors.white.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(4),
                  ),
                ),
                const SizedBox(width: 4),
                Text(
                  step.id,
                  style: TextStyle(
                    color: completed || active 
                      ? const Color(0xFF86efac)
                      : Colors.white30,
                    fontSize: 10,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            );
          }).toList(),
        ),
      ],
    );
  }
}

class _ToggleChip extends StatelessWidget {
  final String label;
  final bool active;
  final VoidCallback onTap;

  const _ToggleChip({
    required this.label,
    required this.active,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          gradient: active ? const LinearGradient(
            colors: [Color(0xFF10B981), Color(0xFF059669)],
          ) : null,
          color: active ? null : Colors.transparent,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: active ? Colors.white : Colors.white60,
            fontSize: 12,
            fontWeight: FontWeight.w600,
          ),
          textAlign: TextAlign.center,
        ),
      ),
    );
  }
}

class _FeatureList extends StatelessWidget {
  final String title;
  final List<String> features;

  const _FeatureList({required this.title, required this.features});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: const TextStyle(
            color: Colors.white70,
            fontWeight: FontWeight.w600,
            fontSize: 14,
          ),
        ),
        const SizedBox(height: 8),
        ...features.map((feature) => Padding(
          padding: const EdgeInsets.only(bottom: 4),
          child: Row(
            children: [
              const Icon(
                Icons.check_circle,
                size: 16,
                color: Color(0xFF10B981),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  feature,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 12,
                    height: 1.4,
                  ),
                ),
              ),
            ],
          ),
        )),
      ],
    );
  }
}

// Lightweight JSON helpers
String _encodeJson(Map<String, dynamic> map) => map.toString();
Map<String, dynamic> _decodeJson(String s) {
  try {
    final trimmed = s.trim();
    if (!trimmed.startsWith('{') || !trimmed.endsWith('}')) return {};
    final body = trimmed.substring(1, trimmed.length - 1);
    final parts = body.isEmpty ? <String>[] : body.split(', ');
    final map = <String, dynamic>{};
    for (final p in parts) {
      final idx = p.indexOf(': ');
      if (idx <= 0) continue;
      final k = p.substring(0, idx);
      final v = p.substring(idx + 2);
      final key = k;
      dynamic val = v == 'true' ? true : v == 'false' ? false : int.tryParse(v) ?? double.tryParse(v) ?? (v == 'null' ? null : v);
      if (key == 'selectedHabits') {
        if (v.startsWith('[') && v.endsWith(']')) {
          final inner = v.substring(1, v.length - 1);
          final items = inner.isEmpty ? <String>[] : inner.split(', ').map((e) => e.trim());
          val = items.toList();
        } else {
          val = <String>[];
        }
      }
      if (key == 'schedule') {
        final sched = <String, dynamic>{};
        sched['morning'] = s.contains('morning: true');
        sched['midday'] = s.contains('midday: true');
        sched['evening'] = s.contains('evening: true');
        val = sched;
      }
      map[key] = val;
    }
    return map;
  } catch (_) {
    return {};
  }
} 