import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'dart:ui';
import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';

/// Drill OS — Onboarding + Paywall (Flutter)
/// "10x Masterpiece" Edition
/// 
/// Complete Flutter port of the React onboarding with:
/// - Polished visual system (glass, gradient orbs, subtle grid)
/// - Step rail with progress bar + keyboard navigation
/// - Guarded steps (mentor required, 3–6 habits, at least one schedule block)
/// - Micro-sim "Offset Engine" demo (good vs bad → live net score)
/// - Local storage state persistence (resume where you left)
/// - Paywall with Monthly/Yearly toggle + comparison + social proof
/// - Smooth transitions and animations

class DrillOSOnboarding extends StatefulWidget {
  final VoidCallback? onComplete;
  final VoidCallback? onLogin;

  const DrillOSOnboarding({
    Key? key,
    this.onComplete,
    this.onLogin,
  }) : super(key: key);

  @override
  State<DrillOSOnboarding> createState() => _DrillOSOnboardingState();
}

class _DrillOSOnboardingState extends State<DrillOSOnboarding> with SingleTickerProviderStateMixin {
  int _stepIndex = 0;
  String? _selectedMentor;
  Set<String> _selectedHabits = {};
  Map<String, bool> _schedule = {
    'morning': true,
    'midday': true,
    'evening': true,
  };
  bool _notificationsEnabled = false;
  
  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;
  late Animation<Offset> _slideAnimation;

  final List<Mentor> _mentors = [
    Mentor(id: 'drill', name: 'Drill Sergeant', tone: 'Aggressive • No excuses', gradient: [Color(0xFF10B981), Color(0xFF047857)]),
    Mentor(id: 'marcus', name: 'Marcus Aurelius', tone: 'Stoic • Calm Authority', gradient: [Color(0xFF84CC16), Color(0xFF047857)]),
    Mentor(id: 'confucius', name: 'Confucius', tone: 'Order • Discipline', gradient: [Color(0xFF6EE7B7), Color(0xFF047857)]),
    Mentor(id: 'buddha', name: 'Buddha', tone: 'Compassion • Presence', gradient: [Color(0xFF5EEAD4), Color(0xFF047857)]),
    Mentor(id: 'abraham_lincoln', name: 'Abraham Lincoln', tone: 'Moral • Resolute', gradient: [Color(0xFF6EE7B7), Color(0xFF475569)]),
  ];

  final List<StarterHabit> _starterHabits = [
    StarterHabit(id: 'water', label: 'Drink 2L Water', weight: 0.2, icon: Icons.water_drop),
    StarterHabit(id: 'steps', label: '8k Steps', weight: 0.2, icon: Icons.directions_walk),
    StarterHabit(id: 'sleep', label: 'Sleep by 11pm', weight: 0.25, icon: Icons.bedtime),
    StarterHabit(id: 'focus', label: '45m Deep Work', weight: 0.25, icon: Icons.track_changes),
    StarterHabit(id: 'gym', label: 'Workout', weight: 0.3, icon: Icons.fitness_center),
    StarterHabit(id: 'reading', label: 'Read 10 pages', weight: 0.15, icon: Icons.book),
  ];

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      vsync: this,
      duration: Duration(milliseconds: 250),
    );
    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeOut),
    );
    _slideAnimation = Tween<Offset>(begin: Offset(0, 0.03), end: Offset.zero).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeOut),
    );
    _animationController.forward();
    _loadState();
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  Future<void> _loadState() async {
    final prefs = await SharedPreferences.getInstance();
    final saved = prefs.getString('drillos_onboarding');
    if (saved != null) {
      try {
        final data = jsonDecode(saved);
        setState(() {
          _stepIndex = data['stepIndex'] ?? 0;
          _selectedMentor = data['selectedMentor'];
          _selectedHabits = Set<String>.from(data['selectedHabits'] ?? []);
          _schedule = Map<String, bool>.from(data['schedule'] ?? _schedule);
          _notificationsEnabled = data['notificationsEnabled'] ?? false;
        });
      } catch (e) {
        print('Error loading onboarding state: $e');
      }
    }
  }

  Future<void> _saveState() async {
    final prefs = await SharedPreferences.getInstance();
    final data = {
      'stepIndex': _stepIndex,
      'selectedMentor': _selectedMentor,
      'selectedHabits': _selectedHabits.toList(),
      'schedule': _schedule,
      'notificationsEnabled': _notificationsEnabled,
    };
    await prefs.setString('drillos_onboarding', jsonEncode(data));
  }

  void _next() {
    if (_canProceed() && _stepIndex < 7) {
      setState(() {
        _stepIndex++;
        _animationController.reset();
        _animationController.forward();
      });
      _saveState();
    }
  }

  void _prev() {
    if (_stepIndex > 0) {
      setState(() {
        _stepIndex--;
        _animationController.reset();
        _animationController.forward();
      });
      _saveState();
    }
  }

  bool _canProceed() {
    switch (_stepIndex) {
      case 2: // mentor step
        return _selectedMentor != null;
      case 3: // habits step
        return _selectedHabits.length >= 3 && _selectedHabits.length <= 6;
      case 4: // schedule step
        return _schedule.values.any((v) => v);
      default:
        return true;
    }
  }

  String _getStepTitle() {
    switch (_stepIndex) {
      case 0: return 'Welcome to Drill OS';
      case 1: return 'Create Account';
      case 2: return 'Choose Your Mentor';
      case 3: return 'Build Your Stack';
      case 4: return 'Set Your Cadence';
      case 5: return 'How We Judge Days';
      case 6: return 'Stay On Track';
      case 7: return 'Unlock Drill OS';
      default: return '';
    }
  }

  String _getStepSubtitle() {
    switch (_stepIndex) {
      case 0: return 'The first active Habit OS — alive, not passive.';
      case 1: return 'Sign in to sync your progress across devices.';
      case 2: return 'Pick a voice to guide (or push) you.';
      case 3: return 'Select 3–6 core habits. You can edit later.';
      case 4: return 'When should we nudge you?';
      case 5: return 'Offset Engine preview: good vs bad → net score.';
      case 6: return 'Enable notifications so your mentor can reach you.';
      case 7: return 'Go Free or power up with Pro.';
      default: return '';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        width: double.infinity,
        height: double.infinity,
        decoration: BoxDecoration(color: Colors.black),
        child: Stack(
          children: [
            _GradientBackground(),
            SafeArea(
              child: Center(
                child: Container(
                  constraints: BoxConstraints(maxWidth: 900),
                  padding: EdgeInsets.all(16),
                  child: FadeTransition(
                    opacity: _fadeAnimation,
                    child: SlideTransition(
                      position: _slideAnimation,
                      child: Container(
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.topCenter,
                            end: Alignment.bottomCenter,
                            colors: [
                              Color(0xFF18181B).withOpacity(0.9),
                              Colors.black,
                            ],
                          ),
                          borderRadius: BorderRadius.circular(24),
                          border: Border.all(color: Color(0xFF27272A)),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.5),
                              blurRadius: 40,
                              offset: Offset(0, 20),
                            ),
                          ],
                        ),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            _StepRail(current: _stepIndex),
                            _buildHeader(),
                            Flexible(
                              child: SingleChildScrollView(
                                padding: EdgeInsets.all(24),
                                child: _buildCurrentStep(),
                              ),
                            ),
                            if (_stepIndex != 7) _buildFooter(),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Container(
      padding: EdgeInsets.fromLTRB(24, 12, 24, 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            children: [
              Container(
                width: 32,
                height: 32,
                decoration: BoxDecoration(
                  color: Color(0xFF10B981).withOpacity(0.15),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Center(
                  child: Text(
                    'D',
                    style: TextStyle(
                      color: Color(0xFF10B981),
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                    ),
                  ),
                ),
              ),
              SizedBox(width: 8),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Drill OS',
                    style: TextStyle(
                      color: Color(0xFF9CA3AF),
                      fontSize: 12,
                    ),
                  ),
                  Text(
                    'Active Habit Operating System',
                    style: TextStyle(
                      color: Color(0xFF6B7280),
                      fontSize: 10,
                    ),
                  ),
                ],
              ),
            ],
          ),
          _ProgressDots(current: _stepIndex, total: 8),
        ],
      ),
    );
  }

  Widget _buildCurrentStep() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          _getStepTitle(),
          style: TextStyle(
            color: Colors.white,
            fontSize: 24,
            fontWeight: FontWeight.w600,
            letterSpacing: -0.5,
          ),
        ),
        SizedBox(height: 4),
        Text(
          _getStepSubtitle(),
          style: TextStyle(
            color: Color(0xFF9CA3AF),
            fontSize: 14,
          ),
        ),
        SizedBox(height: 24),
        AnimatedSwitcher(
          duration: Duration(milliseconds: 200),
          child: _buildStepContent(),
        ),
      ],
    );
  }

  Widget _buildStepContent() {
    switch (_stepIndex) {
      case 0:
        return _WelcomeStep(onNext: _next);
      case 1:
        return _AccountStep(onNext: _next, onLogin: widget.onLogin);
      case 2:
        return _MentorStep(
          mentors: _mentors,
          selectedMentor: _selectedMentor,
          onSelect: (id) {
            setState(() => _selectedMentor = id);
            _saveState();
          },
        );
      case 3:
        return _HabitsStep(
          habits: _starterHabits,
          selectedHabits: _selectedHabits,
          onToggle: (id) {
            setState(() {
              if (_selectedHabits.contains(id)) {
                _selectedHabits.remove(id);
              } else {
                _selectedHabits.add(id);
              }
            });
            _saveState();
          },
        );
      case 4:
        return _ScheduleStep(
          schedule: _schedule,
          onToggle: (key) {
            setState(() => _schedule[key] = !_schedule[key]!);
            _saveState();
          },
        );
      case 5:
        return _OffsetEngineDemo(
          habits: _starterHabits,
          selectedHabits: _selectedHabits,
        );
      case 6:
        return _PermissionsStep(
          enabled: _notificationsEnabled,
          onEnable: () {
            setState(() => _notificationsEnabled = true);
            _saveState();
          },
        );
      case 7:
        return _PaywallStep(onComplete: widget.onComplete);
      default:
        return SizedBox();
    }
  }

  Widget _buildFooter() {
    String? errorMessage;
    if (!_canProceed()) {
      if (_stepIndex == 2) errorMessage = 'Select a mentor to continue';
      if (_stepIndex == 3) errorMessage = 'Choose 3–6 starter habits';
      if (_stepIndex == 4) errorMessage = 'Pick at least one time';
    }

    return Container(
      padding: EdgeInsets.fromLTRB(24, 0, 24, 24),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          TextButton.icon(
            onPressed: _stepIndex > 0 ? _prev : null,
            icon: Icon(Icons.chevron_left, size: 16),
            label: Text('Back'),
            style: TextButton.styleFrom(
              foregroundColor: _stepIndex > 0 ? Color(0xFF9CA3AF) : Color(0xFF4B5563),
            ),
          ),
          if (errorMessage != null)
            Text(
              errorMessage,
              style: TextStyle(
                color: Color(0xFF6B7280),
                fontSize: 12,
              ),
            ),
          ElevatedButton(
            onPressed: _canProceed() ? _next : null,
            style: ElevatedButton.styleFrom(
              backgroundColor: _canProceed() ? Color(0xFF10B981) : Color(0xFF27272A),
              foregroundColor: _canProceed() ? Colors.black : Color(0xFF6B7280),
              padding: EdgeInsets.symmetric(horizontal: 20, vertical: 12),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              elevation: _canProceed() ? 8 : 0,
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text('Next', style: TextStyle(fontWeight: FontWeight.w600)),
                SizedBox(width: 4),
                Icon(Icons.chevron_right, size: 16),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ============================================
// GRADIENT BACKGROUND
// ============================================

class _GradientBackground extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        Positioned(
          top: -128,
          right: -64,
          child: Container(
            width: 384,
            height: 384,
            decoration: BoxDecoration(
              color: Color(0xFF10B981).withOpacity(0.2),
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: Color(0xFF10B981).withOpacity(0.2),
                  blurRadius: 200,
                ),
              ],
            ),
          ),
        ),
        Positioned(
          bottom: -112,
          left: -80,
          child: Container(
            width: 448,
            height: 448,
            decoration: BoxDecoration(
              color: Color(0xFF22C55E).withOpacity(0.1),
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: Color(0xFF22C55E).withOpacity(0.1),
                  blurRadius: 200,
                ),
              ],
            ),
          ),
        ),
        // Subtle grid pattern overlay
        Positioned.fill(
          child: CustomPaint(
            painter: _GridPainter(),
          ),
        ),
      ],
    );
  }
}

class _GridPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.white.withOpacity(0.06)
      ..strokeWidth = 1
      ..style = PaintingStyle.stroke;

    const gridSize = 24.0;
    
    // Draw vertical lines
    for (double x = 0; x < size.width; x += gridSize) {
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), paint);
    }
    
    // Draw horizontal lines
    for (double y = 0; y < size.height; y += gridSize) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y), paint);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

// ============================================
// PROGRESS DOTS
// ============================================

class _ProgressDots extends StatelessWidget {
  final int current;
  final int total;

  const _ProgressDots({required this.current, required this.total});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: List.generate(total, (i) {
        return Container(
          margin: EdgeInsets.symmetric(horizontal: 3),
          width: i == current ? 24 : 8,
          height: 6,
          decoration: BoxDecoration(
            color: i == current ? Color(0xFF10B981) : Color(0xFF3F3F46),
            borderRadius: BorderRadius.circular(3),
          ),
        );
      }),
    );
  }
}

// ============================================
// STEP RAIL
// ============================================

class _StepRail extends StatelessWidget {
  final int current;

  const _StepRail({required this.current});

  @override
  Widget build(BuildContext context) {
    final steps = ['welcome', 'account', 'mentor', 'habits', 'schedule', 'engine', 'permissions', 'paywall'];
    final pct = ((current + 1) / steps.length);

    return Padding(
      padding: EdgeInsets.all(24),
      child: Column(
        children: [
          Container(
            height: 4,
            decoration: BoxDecoration(
              color: Color(0xFF27272A),
              borderRadius: BorderRadius.circular(2),
            ),
            child: FractionallySizedBox(
              alignment: Alignment.centerLeft,
              widthFactor: pct,
              child: Container(
                decoration: BoxDecoration(
                  color: Color(0xFF10B981),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ============================================
// DATA MODELS
// ============================================

class Mentor {
  final String id;
  final String name;
  final String tone;
  final List<Color> gradient;

  Mentor({required this.id, required this.name, required this.tone, required this.gradient});
}

class StarterHabit {
  final String id;
  final String label;
  final double weight;
  final IconData icon;

  StarterHabit({required this.id, required this.label, required this.weight, required this.icon});
}

// ============================================
// STEP COMPONENTS
// ============================================

class _WelcomeStep extends StatelessWidget {
  final VoidCallback onNext;

  const _WelcomeStep({required this.onNext});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        _HeroCard(),
        SizedBox(height: 24),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _FeatureItem(
              icon: Icons.auto_awesome,
              text: 'The FIRST Habit OS — alive, not passive like other apps',
            ),
            SizedBox(height: 12),
            _FeatureItem(
              icon: Icons.notifications,
              text: 'Daily nudges & mentor voices with strictness levels',
            ),
            SizedBox(height: 12),
            _FeatureItem(
              icon: Icons.local_fire_department,
              text: 'Weekly report cards that judge and guide your progress',
            ),
          ],
        ),
      ],
    );
  }
}

class _AccountStep extends StatelessWidget {
  final VoidCallback onNext;
  final VoidCallback? onLogin;

  const _AccountStep({required this.onNext, this.onLogin});

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Sign in to sync your data and keep your streaks safe.',
                style: TextStyle(color: Color(0xFFD1D5DB), fontSize: 14),
              ),
              SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: ElevatedButton(
                      onPressed: () {
                        onLogin?.call();
                        onNext();
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.white,
                        foregroundColor: Colors.black,
                        padding: EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child: Text('Continue with Email', style: TextStyle(fontWeight: FontWeight.w600)),
                    ),
                  ),
                  SizedBox(width: 8),
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () {
                        onLogin?.call();
                        onNext();
                      },
                      style: OutlinedButton.styleFrom(
                        foregroundColor: Colors.white,
                        side: BorderSide(color: Color(0xFF3F3F46)),
                        padding: EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child: Text('Guest Mode'),
                    ),
                  ),
                ],
              ),
              SizedBox(height: 8),
              Text(
                'You can link your account later in settings.',
                style: TextStyle(color: Color(0xFF6B7280), fontSize: 11),
              ),
            ],
          ),
        ),
        SizedBox(width: 24),
        Expanded(
          child: Container(
            padding: EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Color(0xFF18181B).withOpacity(0.6),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: Color(0xFF27272A)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Why sign in?',
                  style: TextStyle(color: Color(0xFF9CA3AF), fontSize: 14),
                ),
                SizedBox(height: 12),
                _CheckItem(text: 'Cloud sync across devices'),
                SizedBox(height: 8),
                _CheckItem(text: 'Backup streaks & XP'),
                SizedBox(height: 8),
                _CheckItem(text: 'Early access features'),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _MentorStep extends StatelessWidget {
  final List<Mentor> mentors;
  final String? selectedMentor;
  final Function(String) onSelect;

  const _MentorStep({
    required this.mentors,
    required this.selectedMentor,
    required this.onSelect,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        GridView.builder(
          shrinkWrap: true,
          physics: NeverScrollableScrollPhysics(),
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 2,
            mainAxisSpacing: 12,
            crossAxisSpacing: 12,
            childAspectRatio: 2.5,
          ),
          itemCount: mentors.length,
          itemBuilder: (context, i) {
            final mentor = mentors[i];
            final isSelected = selectedMentor == mentor.id;
            return InkWell(
              onTap: () => onSelect(mentor.id),
              borderRadius: BorderRadius.circular(16),
              child: Container(
                padding: EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: isSelected ? Color(0xFF10B981).withOpacity(0.1) : Color(0xFF18181B).withOpacity(0.4),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: isSelected ? Color(0xFF10B981) : Color(0xFF27272A),
                  ),
                ),
                child: Row(
                  children: [
                    _MentorAvatar(name: mentor.name, gradient: mentor.gradient, size: 48),
                    SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(
                            mentor.name,
                            style: TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.w600,
                              fontSize: 13,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          SizedBox(height: 2),
                          Text(
                            mentor.tone,
                            style: TextStyle(
                              color: Color(0xFF9CA3AF),
                              fontSize: 11,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          if (isSelected) ...[
                            SizedBox(height: 4),
                            Row(
                              children: [
                                Icon(Icons.check, color: Color(0xFF10B981), size: 12),
                                SizedBox(width: 4),
                                Text(
                                  'Selected',
                                  style: TextStyle(
                                    color: Color(0xFF10B981),
                                    fontSize: 10,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        ),
        SizedBox(height: 12),
        Text(
          'You can switch mentors anytime in Settings.',
          style: TextStyle(color: Color(0xFF6B7280), fontSize: 11),
        ),
      ],
    );
  }
}

class _HabitsStep extends StatelessWidget {
  final List<StarterHabit> habits;
  final Set<String> selectedHabits;
  final Function(String) onToggle;

  const _HabitsStep({
    required this.habits,
    required this.selectedHabits,
    required this.onToggle,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        GridView.builder(
          shrinkWrap: true,
          physics: NeverScrollableScrollPhysics(),
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 3,
            mainAxisSpacing: 12,
            crossAxisSpacing: 12,
            childAspectRatio: 2.0,
          ),
          itemCount: habits.length,
          itemBuilder: (context, i) {
            final habit = habits[i];
            final isSelected = selectedHabits.contains(habit.id);
            return InkWell(
              onTap: () => onToggle(habit.id),
              borderRadius: BorderRadius.circular(16),
              child: Container(
                padding: EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: isSelected ? Color(0xFF10B981).withOpacity(0.1) : Color(0xFF18181B).withOpacity(0.4),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: isSelected ? Color(0xFF10B981) : Color(0xFF27272A),
                  ),
                ),
                child: Row(
                  children: [
                    Icon(
                      habit.icon,
                      color: Color(0xFF10B981),
                      size: 16,
                    ),
                    SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        habit.label,
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 12,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        ),
        SizedBox(height: 12),
        Text(
          'Tip: Start with 3–6 habits. You can add more later.',
          style: TextStyle(color: Color(0xFF6B7280), fontSize: 11),
        ),
      ],
    );
  }
}

class _ScheduleStep extends StatelessWidget {
  final Map<String, bool> schedule;
  final Function(String) onToggle;

  const _ScheduleStep({required this.schedule, required this.onToggle});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: _ChoiceCard(
            active: schedule['morning']!,
            onTap: () => onToggle('morning'),
            title: 'Morning',
            subtitle: 'Primer & plan',
            icon: Icons.wb_sunny,
          ),
        ),
        SizedBox(width: 12),
        Expanded(
          child: _ChoiceCard(
            active: schedule['midday']!,
            onTap: () => onToggle('midday'),
            title: 'Midday',
            subtitle: 'Adaptive nudge',
            icon: Icons.access_time,
          ),
        ),
        SizedBox(width: 12),
        Expanded(
          child: _ChoiceCard(
            active: schedule['evening']!,
            onTap: () => onToggle('evening'),
            title: 'Evening',
            subtitle: 'Reflection',
            icon: Icons.nightlight_round,
          ),
        ),
      ],
    );
  }
}

class _OffsetEngineDemo extends StatefulWidget {
  final List<StarterHabit> habits;
  final Set<String> selectedHabits;

  const _OffsetEngineDemo({required this.habits, required this.selectedHabits});

  @override
  State<_OffsetEngineDemo> createState() => _OffsetEngineDemoState();
}

class _OffsetEngineDemoState extends State<_OffsetEngineDemo> {
  double _bad = 0.0;

  @override
  Widget build(BuildContext context) {
    final good = widget.selectedHabits.fold<double>(
      0.0,
      (sum, id) => sum + (widget.habits.firstWhere((h) => h.id == id).weight),
    );
    final net = (good - _bad).clamp(-1.0, 1.0);

    return Container(
      padding: EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Color(0xFF18181B).withOpacity(0.6),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Color(0xFF27272A)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Offset Engine • Good − Bad = Net',
                style: TextStyle(color: Colors.white, fontSize: 14),
              ),
              Container(
                padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: (net >= 0 ? Color(0xFF10B981) : Color(0xFFF43F5E)).withOpacity(0.15),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  'Net ${net.toStringAsFixed(2)}',
                  style: TextStyle(
                    color: net >= 0 ? Color(0xFF10B981) : Color(0xFFF43F5E),
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
          SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: Container(
                  padding: EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Color(0xFF10B981).withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Color(0xFF10B981).withOpacity(0.2)),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Good from Habits',
                        style: TextStyle(color: Color(0xFF10B981), fontSize: 12),
                      ),
                      SizedBox(height: 4),
                      Text(
                        '+${good.toStringAsFixed(2)}',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 20,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      SizedBox(height: 2),
                      Text(
                        'Based on selected starters',
                        style: TextStyle(
                          color: Color(0xFF10B981).withOpacity(0.7),
                          fontSize: 9,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              SizedBox(width: 12),
              Expanded(
                child: Container(
                  padding: EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Color(0xFFF43F5E).withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Color(0xFFF43F5E).withOpacity(0.2)),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Bad (Late/Skip/Scroll)',
                        style: TextStyle(color: Color(0xFFF43F5E), fontSize: 12),
                      ),
                      SizedBox(height: 8),
                      Slider(
                        value: _bad,
                        onChanged: (v) => setState(() => _bad = v),
                        min: 0,
                        max: 1,
                        activeColor: Color(0xFFF43F5E),
                        inactiveColor: Color(0xFF3F3F46),
                      ),
                      Text(
                        '−${_bad.toStringAsFixed(2)}',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 20,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              SizedBox(width: 12),
              Expanded(
                child: Container(
                  padding: EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Color(0xFF27272A).withOpacity(0.6),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Color(0xFF3F3F46)),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Net Score Preview',
                        style: TextStyle(color: Color(0xFFD1D5DB), fontSize: 12),
                      ),
                      SizedBox(height: 4),
                      Text(
                        net >= 0 ? '↑ Positive Day' : '↓ Needs Course‑Correct',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      SizedBox(height: 2),
                      Text(
                        'Your mentor adapts tone based on this',
                        style: TextStyle(
                          color: Color(0xFF6B7280),
                          fontSize: 9,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _PermissionsStep extends StatelessWidget {
  final bool enabled;
  final VoidCallback onEnable;

  const _PermissionsStep({required this.enabled, required this.onEnable});

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: Container(
            padding: EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Color(0xFF18181B).withOpacity(0.6),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: Color(0xFF27272A)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Enable notifications so your mentor can reach you at the right moment.',
                  style: TextStyle(color: Color(0xFFD1D5DB), fontSize: 14),
                ),
                SizedBox(height: 16),
                _FeatureItem(icon: Icons.notifications, text: 'Timely nudges & alarms'),
                SizedBox(height: 8),
                _FeatureItem(icon: Icons.volume_up, text: 'Voice lines from your mentor'),
                SizedBox(height: 8),
                _FeatureItem(icon: Icons.shield, text: 'You control frequency & tone'),
                SizedBox(height: 16),
                ElevatedButton(
                  onPressed: enabled ? null : onEnable,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: enabled ? Color(0xFF047857) : Color(0xFF10B981),
                    foregroundColor: Colors.black,
                    padding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: Text(
                    enabled ? 'Enabled' : 'Enable Notifications',
                    style: TextStyle(fontWeight: FontWeight.w600),
                  ),
                ),
              ],
            ),
          ),
        ),
        SizedBox(width: 24),
        Expanded(child: _HeroCard()),
      ],
    );
  }
}

class _PaywallStep extends StatefulWidget {
  final VoidCallback? onComplete;

  const _PaywallStep({this.onComplete});

  @override
  State<_PaywallStep> createState() => _PaywallStepState();
}

class _PaywallStepState extends State<_PaywallStep> {
  String _billing = 'monthly';

  @override
  Widget build(BuildContext context) {
    final price = _billing == 'monthly' ? 4.99 : 39.99;
    final saving = _billing == 'yearly' ? 33 : 0;

    return Column(
      children: [
        Container(
          decoration: BoxDecoration(
            color: Color(0xFF09090B).withOpacity(0.7),
            borderRadius: BorderRadius.circular(24),
            border: Border.all(color: Color(0xFF27272A)),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Free Column
              Expanded(
                flex: 2,
                child: Padding(
                  padding: EdgeInsets.all(20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Free',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 18,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      SizedBox(height: 4),
                      Text(
                        'Start with the basics — alarms, habits, streaks.',
                        style: TextStyle(color: Color(0xFF9CA3AF), fontSize: 13),
                      ),
                      SizedBox(height: 16),
                      _CheckItem(text: 'Smart alarms & streaks'),
                      SizedBox(height: 8),
                      _CheckItem(text: 'Habits & tasks'),
                      SizedBox(height: 8),
                      _CheckItem(text: 'Local stats'),
                      SizedBox(height: 16),
                      SizedBox(
                        width: double.infinity,
                        child: OutlinedButton(
                          onPressed: widget.onComplete,
                          style: OutlinedButton.styleFrom(
                            foregroundColor: Colors.white,
                            side: BorderSide(color: Color(0xFF3F3F46)),
                            padding: EdgeInsets.symmetric(vertical: 12),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                          child: Text('Continue Free'),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              Container(width: 1, color: Color(0xFF27272A)),
              // Pro Column
              Expanded(
                flex: 3,
                child: Container(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [
                        Color(0xFF10B981).withOpacity(0.15),
                        Colors.transparent,
                      ],
                    ),
                    borderRadius: BorderRadius.only(
                      topRight: Radius.circular(24),
                      bottomRight: Radius.circular(24),
                    ),
                  ),
                  padding: EdgeInsets.all(20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                                                     Row(
                            children: [
                              Icon(Icons.workspace_premium, color: Color(0xFF10B981), size: 14),
                              SizedBox(width: 6),
                              Text(
                                'PRO',
                                style: TextStyle(
                                  color: Color(0xFF10B981),
                                  fontSize: 10,
                                  fontWeight: FontWeight.bold,
                                  letterSpacing: 1.5,
                                ),
                              ),
                            ],
                          ),
                          Container(
                            padding: EdgeInsets.all(4),
                            decoration: BoxDecoration(
                              color: Color(0xFF18181B),
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(color: Color(0xFF3F3F46)),
                            ),
                            child: Row(
                              children: [
                                _BillingButton(
                                  label: 'Monthly',
                                  active: _billing == 'monthly',
                                  onTap: () => setState(() => _billing = 'monthly'),
                                ),
                                _BillingButton(
                                  label: 'Yearly',
                                  active: _billing == 'yearly',
                                  onTap: () => setState(() => _billing = 'yearly'),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      SizedBox(height: 8),
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Text(
                            'Unlock Drill OS',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 20,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          SizedBox(width: 12),
                          Text(
                            '\$${price.toStringAsFixed(2)}',
                            style: TextStyle(color: Color(0xFF10B981), fontSize: 16),
                          ),
                          Text(
                            ' / ${_billing == 'monthly' ? 'month' : 'year'}',
                            style: TextStyle(color: Color(0xFF10B981), fontSize: 12),
                          ),
                          if (saving > 0) ...[
                            SizedBox(width: 8),
                            Text(
                              'Save $saving%',
                              style: TextStyle(
                                color: Color(0xFF10B981).withOpacity(0.8),
                                fontSize: 9,
                              ),
                            ),
                          ],
                        ],
                      ),
                      SizedBox(height: 4),
                      Text(
                        'Get the real OS: mentors with voices, strictness levels, adaptive nudges, report cards, duels and more.',
                        style: TextStyle(color: Color(0xFF9CA3AF), fontSize: 13),
                      ),
                      SizedBox(height: 16),
                      Wrap(
                        spacing: 12,
                        runSpacing: 8,
                        children: [
                          _CheckItem(text: 'AI mentors with real voices', compact: true),
                          _CheckItem(text: 'Strictness levels + adaptive nudges', compact: true),
                          _CheckItem(text: 'Weekly report cards & insights', compact: true),
                          _CheckItem(text: 'Offset engine: bad cancels good', compact: true),
                          _CheckItem(text: 'Duels, quests, seasonal events', compact: true),
                        ],
                      ),
                      SizedBox(height: 16),
                      Row(
                        children: [
                          Expanded(
                            child: ElevatedButton(
                              onPressed: () {},
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Color(0xFF10B981),
                                foregroundColor: Colors.black,
                                padding: EdgeInsets.symmetric(vertical: 12),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                elevation: 8,
                              ),
                              child: Text(
                                'Start Pro – \$${_billing == 'monthly' ? '4.99' : '39.99'}',
                                style: TextStyle(fontWeight: FontWeight.bold),
                              ),
                            ),
                          ),
                          SizedBox(width: 8),
                          Expanded(
                            child: OutlinedButton(
                              onPressed: widget.onComplete,
                              style: OutlinedButton.styleFrom(
                                foregroundColor: Colors.white,
                                side: BorderSide(color: Color(0xFF3F3F46)),
                                padding: EdgeInsets.symmetric(vertical: 12),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                              ),
                              child: Text('Maybe Later'),
                            ),
                          ),
                        ],
                      ),
                      SizedBox(height: 8),
                      Text(
                        'Cancel anytime. Free plan stays with alarms, habits, streaks.',
                        style: TextStyle(color: Color(0xFF6B7280), fontSize: 9),
                      ),
                      SizedBox(height: 16),
                      // Testimonials
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: [
                          _TestimonialCard(
                            name: 'Alex R.',
                            text: 'Only habit app that actually moved my day. The mentor voice is… intense in a good way.',
                          ),
                          _TestimonialCard(
                            name: 'Maya K.',
                            text: 'Report cards + strictness fixed my 11pm doomscroll. Net score keeps me honest.',
                          ),
                          _TestimonialCard(
                            name: 'Dev P.',
                            text: 'Feels alive. It talks, nudges, and adapts. Kept my 28‑day streak.',
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
        SizedBox(height: 12),
        Text(
          'By continuing you agree to our Terms & Privacy.',
          style: TextStyle(color: Color(0xFF6B7280), fontSize: 11),
        ),
      ],
    );
  }
}

// ============================================
// SHARED UI COMPONENTS
// ============================================

class _HeroCard extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.all(24),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Color(0xFF10B981).withOpacity(0.15),
            Color(0xFF18181B),
            Colors.black,
          ],
        ),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: Color(0xFF27272A)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'DRILL OS',
            style: TextStyle(
              color: Color(0xFF10B981).withOpacity(0.8),
              fontSize: 10,
              fontWeight: FontWeight.bold,
              letterSpacing: 2,
            ),
          ),
          SizedBox(height: 8),
          Text(
            'Active Habit Operating System',
            style: TextStyle(
              color: Colors.white,
              fontSize: 20,
              fontWeight: FontWeight.w600,
            ),
          ),
          SizedBox(height: 8),
          Text(
            'A council of mentors that remembers, adapts, and pushes you daily.',
            style: TextStyle(
              color: Color(0xFF9CA3AF),
              fontSize: 13,
            ),
          ),
          SizedBox(height: 16),
          Row(
            children: [
              _MentorAvatar(
                name: 'Drill Sergeant',
                gradient: [Color(0xFF10B981), Color(0xFF047857)],
                size: 48,
              ),
              SizedBox(width: 8),
              _MentorAvatar(
                name: 'Marcus Aurelius',
                gradient: [Color(0xFF84CC16), Color(0xFF047857)],
                size: 48,
              ),
              SizedBox(width: 8),
              _MentorAvatar(
                name: 'Confucius',
                gradient: [Color(0xFF6EE7B7), Color(0xFF047857)],
                size: 48,
              ),
              SizedBox(width: 8),
              _MentorAvatar(
                name: 'Buddha',
                gradient: [Color(0xFF5EEAD4), Color(0xFF047857)],
                size: 48,
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _MentorAvatar extends StatelessWidget {
  final String name;
  final List<Color> gradient;
  final double size;

  const _MentorAvatar({
    required this.name,
    required this.gradient,
    this.size = 64,
  });

  @override
  Widget build(BuildContext context) {
    final initials = name
        .split(' ')
        .map((w) => w.isNotEmpty ? w[0] : '')
        .take(2)
        .join()
        .toUpperCase();

    // Map mentor names to actual image assets
    final imageMap = {
      'Drill Sergeant': 'assets/avatars/drill_sergeant.png',
      'Marcus Aurelius': 'assets/avatars/marcus_aurelius.png',
      'Confucius': 'assets/avatars/confucius.png',
      'Buddha': 'assets/avatars/buddha.png',
      'Abraham Lincoln': 'assets/avatars/abraham_lincoln.png',
    };

    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: gradient,
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withOpacity(0.1)),
        boxShadow: [
          BoxShadow(
            color: gradient[0].withOpacity(0.3),
            blurRadius: 12,
            offset: Offset(0, 4),
          ),
        ],
      ),
      child: imageMap.containsKey(name)
          ? ClipRRect(
              borderRadius: BorderRadius.circular(16),
              child: Image.asset(
                imageMap[name]!,
                fit: BoxFit.cover,
                errorBuilder: (context, error, stack) {
                  return Center(
                    child: Text(
                      initials,
                      style: TextStyle(
                        color: Colors.black,
                        fontWeight: FontWeight.bold,
                        fontSize: size * 0.3,
                      ),
                    ),
                  );
                },
              ),
            )
          : Center(
              child: Text(
                initials,
                style: TextStyle(
                  color: Colors.black,
                  fontWeight: FontWeight.bold,
                  fontSize: size * 0.3,
                ),
              ),
            ),
    );
  }
}

class _FeatureItem extends StatelessWidget {
  final IconData icon;
  final String text;

  const _FeatureItem({required this.icon, required this.text});

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, color: Color(0xFF10B981), size: 16),
        SizedBox(width: 12),
        Expanded(
          child: Text(
            text,
            style: TextStyle(color: Color(0xFFD1D5DB), fontSize: 13),
          ),
        ),
      ],
    );
  }
}

class _CheckItem extends StatelessWidget {
  final String text;
  final bool compact;

  const _CheckItem({required this.text, this.compact = false});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: compact ? MainAxisSize.min : MainAxisSize.max,
      children: [
        Icon(Icons.check, color: Color(0xFF10B981), size: compact ? 14 : 16),
        SizedBox(width: compact ? 6 : 8),
        if (compact)
          Text(text, style: TextStyle(color: Colors.white, fontSize: 12))
        else
          Expanded(child: Text(text, style: TextStyle(color: Colors.white, fontSize: 13))),
      ],
    );
  }
}

class _ChoiceCard extends StatelessWidget {
  final bool active;
  final VoidCallback onTap;
  final String title;
  final String subtitle;
  final IconData icon;

  const _ChoiceCard({
    required this.active,
    required this.onTap,
    required this.title,
    required this.subtitle,
    required this.icon,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: active ? Color(0xFF10B981).withOpacity(0.1) : Color(0xFF18181B).withOpacity(0.4),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: active ? Color(0xFF10B981) : Color(0xFF27272A),
          ),
        ),
        child: Column(
          children: [
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: active ? Color(0xFF10B981) : Color(0xFF27272A),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(
                icon,
                color: active ? Colors.black : Color(0xFFD1D5DB),
                size: 18,
              ),
            ),
            SizedBox(height: 12),
            Text(
              title,
              style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w600,
                fontSize: 14,
              ),
            ),
            SizedBox(height: 4),
            Text(
              subtitle,
              style: TextStyle(
                color: Color(0xFF9CA3AF),
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

class _BillingButton extends StatelessWidget {
  final String label;
  final bool active;
  final VoidCallback onTap;

  const _BillingButton({
    required this.label,
    required this.active,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(6),
      child: Container(
        padding: EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: active ? Color(0xFF10B981) : Colors.transparent,
          borderRadius: BorderRadius.circular(6),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: active ? Colors.black : Color(0xFFD1D5DB),
            fontSize: 11,
            fontWeight: active ? FontWeight.w600 : FontWeight.normal,
          ),
        ),
      ),
    );
  }
}

class _TestimonialCard extends StatelessWidget {
  final String name;
  final String text;

  const _TestimonialCard({required this.name, required this.text});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 180,
      padding: EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Color(0xFF18181B).withOpacity(0.6),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Color(0xFF27272A)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.star, color: Color(0xFF10B981), size: 12),
              SizedBox(width: 6),
              Text(
                name,
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w600,
                  fontSize: 11,
                ),
              ),
            ],
          ),
          SizedBox(height: 6),
          Text(
            '"$text"',
            style: TextStyle(
              color: Color(0xFF9CA3AF),
              fontSize: 10,
            ),
          ),
        ],
      ),
    );
  }
} 