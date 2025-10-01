import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../design/glass.dart';
import '../design/tokens.dart';
import '../badges/rank_ribbon.dart';
import '../design/feedback.dart';
import "../services/api_client.dart";
import '../inputs/toggle_pills.dart';

enum DrillMode { strict, balanced, light }
enum ExportFormat { json, csv }

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {

  void _handleUpgrade() async {
    try {
      // Set auth token (in production this would come from authentication)
      apiClient.setAuthToken("valid-token");
      
      // Create checkout session
      final session = await apiClient.createCheckoutSession();
      
      // In a real app, you would open the checkout URL in a webview or browser
      Toast.show(context, "Opening checkout: ${session["url"]}");
      print("Checkout URL: ${session["url"]}");
      
    } catch (e) {
      print("❌ Failed to create checkout session: $e");
      Toast.show(context, "Failed to start upgrade: $e");
    }
  }
  // User settings state
  DrillMode currentMode = DrillMode.balanced;
  int intensity = 2; // 1-3
  bool roastConsent = false;
  String safeWord = 'pause';
  bool quietHoursEnabled = true;
  TimeOfDay quietStart = const TimeOfDay(hour: 22, minute: 0);
  TimeOfDay quietEnd = const TimeOfDay(hour: 7, minute: 0);
  bool notificationsEnabled = true;
  bool hapticFeedback = true;
  bool soundEffects = true;
  
  // Account info
  final String userName = 'DrillCadet47';
  final String userEmail = 'user@example.com';
  final String planType = 'FREE';
  final int daysActive = 47;
  final _apiBaseController = TextEditingController();
  
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: const GlassAppBar(title: 'Settings'),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // Account Section
          _buildAccountSection(),
          const SizedBox(height: 20),
          
          // Drill Mode Section
          _buildDrillModeSection(),
          const SizedBox(height: 20),
          
          // Behavior Section
          _buildBehaviorSection(),
          const SizedBox(height: 20),
          
          // Notifications Section
          _buildNotificationsSection(),
          const SizedBox(height: 20),
          
          // Data & Privacy Section
          _buildDataPrivacySection(),
          const SizedBox(height: 20),

          // API Config
          GlassCard(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(children: [
                    const Icon(Icons.api, size: 20),
                    const SizedBox(width: 8),
                    Text('API', style: Theme.of(context).textTheme.titleMedium),
                    const Spacer(),
                    Text(apiClient.getBaseUrl(), style: Theme.of(context).textTheme.bodySmall),
                  ]),
                  const SizedBox(height: 12),
                  TextField(
                    controller: _apiBaseController,
                    decoration: const InputDecoration(hintText: 'https://your-backend'),
                    onSubmitted: (v) {
                      if (v.trim().isNotEmpty) {
                        apiClient.setBaseUrl(v.trim());
                        Toast.show(context, 'API base set to: ${apiClient.getBaseUrl()}');
                      }
                    },
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Expanded(
                        child: GlassButton.primary('Apply API Base URL', onPressed: () {
                          final v = _apiBaseController.text.trim();
                          if (v.isNotEmpty) {
                            apiClient.setBaseUrl(v);
                            Toast.show(context, 'API base set to: ${apiClient.getBaseUrl()}');
                            setState(() {});
                          }
                        }),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: GlassButton.ghost('Test API', onPressed: () async {
                          try {
                            apiClient.setAuthToken('valid-token');
                            final res = await apiClient.getBriefToday();
                            Toast.show(context, 'OK: brief loaded');
                          } catch (e) {
                            Toast.show(context, 'API error: $e');
                          }
                        }),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 20),
          
          // Danger Zone
          _buildDangerZoneSection(),
          const SizedBox(height: 24),
        ],
      ),
    );
  }

  Widget _buildAccountSection() {
    return GlassCard(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                CircleAvatar(
                  radius: 24,
                  backgroundColor: DSXColors.accent.withOpacity(0.15),
                  child: Text(
                    userName[0].toUpperCase(),
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      color: DSXColors.accent,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        userName,
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                      Text(
                        userEmail,
                        style: Theme.of(context).textTheme.bodyMedium,
                      ),
                    ],
                  ),
                ),
                RankRibbon(
                  text: planType,
                  tone: planType == 'PRO' ? RibbonTone.balanced : RibbonTone.light,
                ),
              ],
            ),
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _buildStatCard('Days Active', '$daysActive'),
                _buildStatCard('Current Streak', '23'),
                _buildStatCard('Total Habits', '12'),
              ],
            ),
            const SizedBox(height: 16),
            if (planType == 'FREE')
              SizedBox(
                width: double.infinity,
                child: GlassButton.primary(
                  'Upgrade to Pro',
                  onPressed: () {
                    Toast.show(context, 'Opening upgrade options...');
                  },
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatCard(String label, String value) {
    return Column(
      children: [
        Text(
          value,
          style: Theme.of(context).textTheme.titleLarge?.copyWith(
            color: DSXColors.accent,
            fontWeight: FontWeight.w800,
          ),
        ),
        Text(
          label,
          style: Theme.of(context).textTheme.bodySmall,
          textAlign: TextAlign.center,
        ),
      ],
    );
  }

  Widget _buildDrillModeSection() {
    return GlassCard(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.psychology, color: DSXColors.accent, size: 20),
                const SizedBox(width: 8),
                Text(
                  'Drill Mode',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
              ],
            ),
            const SizedBox(height: 12),
            TogglePills(
              labels: const ['🪖 Strict', '📣 Balanced', '🧘 Light'],
              selectedIndex: currentMode.index,
              onChanged: (index) {
                setState(() {
                  currentMode = DrillMode.values[index];
                });
                HapticFeedback.lightImpact();
                _saveSettings();
              },
            ),
            const SizedBox(height: 16),
            Text(
              _getModeDescription(currentMode),
              style: Theme.of(context).textTheme.bodyMedium,
            ),
            const SizedBox(height: 16),
            
            // Intensity Slider
            Text(
              'Intensity Level: $intensity',
              style: Theme.of(context).textTheme.titleSmall,
            ),
            const SizedBox(height: 8),
            SliderTheme(
              data: SliderTheme.of(context).copyWith(
                activeTrackColor: DSXColors.accent,
                inactiveTrackColor: DSXColors.accent.withOpacity(0.2),
                thumbColor: DSXColors.accent,
                overlayColor: DSXColors.accent.withOpacity(0.1),
              ),
              child: Slider(
                value: intensity.toDouble(),
                min: 1,
                max: 3,
                divisions: 2,
                onChanged: (value) {
                  setState(() {
                    intensity = value.round();
                  });
                  HapticFeedback.lightImpact();
                },
                onChangeEnd: (value) {
                  _saveSettings();
                },
              ),
            ),
            Text(
              _getIntensityDescription(intensity),
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBehaviorSection() {
    return GlassCard(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.tune, color: DSXColors.warn, size: 20),
                const SizedBox(width: 8),
                Text(
                  'Behavior Settings',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
              ],
            ),
            const SizedBox(height: 16),
            
            // Roast Consent
            _buildSwitchTile(
              'Roast Consent',
              'Allow harsh feedback when appropriate',
              roastConsent,
              (value) {
                setState(() {
                  roastConsent = value;
                });
                _saveSettings();
              },
              warningIcon: true,
            ),
            
            const SizedBox(height: 16),
            
            // Safe Word
            Text(
              'Safe Word',
              style: Theme.of(context).textTheme.titleSmall,
            ),
            const SizedBox(height: 8),
            TextField(
              controller: TextEditingController(text: safeWord),
              decoration: InputDecoration(
                hintText: 'Enter your safe word',
                suffixIcon: Icon(Icons.security, color: DSXColors.textSecondary),
              ),
              onChanged: (value) {
                safeWord = value;
              },
              onEditingComplete: () {
                _saveSettings();
              },
            ),
            const SizedBox(height: 4),
            Text(
              'Say this word to immediately stop harsh feedback',
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildNotificationsSection() {
    return GlassCard(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.notifications, color: DSXColors.accent, size: 20),
                const SizedBox(width: 8),
                Text(
                  'Notifications & Audio',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
              ],
            ),
            const SizedBox(height: 16),
            
            _buildSwitchTile(
              'Push Notifications',
              'Habit reminders and streak alerts',
              notificationsEnabled,
              (value) {
                setState(() {
                  notificationsEnabled = value;
                });
                _saveSettings();
              },
            ),
            
            const SizedBox(height: 12),
            
            _buildSwitchTile(
              'Haptic Feedback',
              'Vibration for interactions',
              hapticFeedback,
              (value) {
                setState(() {
                  hapticFeedback = value;
                });
                _saveSettings();
              },
            ),
            
            const SizedBox(height: 12),
            
            _buildSwitchTile(
              'Sound Effects',
              'Audio feedback and voice lines',
              soundEffects,
              (value) {
                setState(() {
                  soundEffects = value;
                });
                _saveSettings();
              },
            ),
            
            const SizedBox(height: 16),
            
            // Quiet Hours
            _buildSwitchTile(
              'Quiet Hours',
              'Silence notifications during set hours',
              quietHoursEnabled,
              (value) {
                setState(() {
                  quietHoursEnabled = value;
                });
                _saveSettings();
              },
            ),
            
            if (quietHoursEnabled) ...[
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: _buildTimeSelector(
                      'From',
                      quietStart,
                      (time) {
                        setState(() {
                          quietStart = time;
                        });
                        _saveSettings();
                      },
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: _buildTimeSelector(
                      'To',
                      quietEnd,
                      (time) {
                        setState(() {
                          quietEnd = time;
                        });
                        _saveSettings();
                      },
                    ),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildDataPrivacySection() {
    return GlassCard(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.download, color: DSXColors.accent, size: 20),
                const SizedBox(width: 8),
                Text(
                  'Data & Privacy',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
              ],
            ),
            const SizedBox(height: 16),
            
            // Export Data
            GlassButton.ghost(
              'Export My Data',
              onPressed: () {
                _showExportDialog();
              },
            ),
            const SizedBox(height: 12),
            
            // Privacy Policy
            GlassButton.ghost(
              'Privacy Policy',
              onPressed: () {
                Toast.show(context, 'Opening privacy policy...');
              },
            ),
            const SizedBox(height: 12),
            
            // Terms of Service
            GlassButton.ghost(
              'Terms of Service',
              onPressed: () {
                Toast.show(context, 'Opening terms of service...');
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDangerZoneSection() {
    return GlassCard(
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(DSXRadii.md),
          border: Border.all(color: DSXColors.danger.withOpacity(0.3)),
        ),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(Icons.warning, color: DSXColors.danger, size: 20),
                  const SizedBox(width: 8),
                  Text(
                    'Danger Zone',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      color: DSXColors.danger,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              
              // Reset All Data
              SizedBox(
                width: double.infinity,
                child: OutlinedButton(
                  onPressed: () {
                    _showResetDialog();
                  },
                  style: OutlinedButton.styleFrom(
                    side: BorderSide(color: DSXColors.danger.withOpacity(0.5)),
                    foregroundColor: DSXColors.danger,
                  ),
                  child: const Text('Reset All Data'),
                ),
              ),
              const SizedBox(height: 8),
              
              // Delete Account
              SizedBox(
                width: double.infinity,
                child: OutlinedButton(
                  onPressed: () {
                    _showDeleteAccountDialog();
                  },
                  style: OutlinedButton.styleFrom(
                    side: BorderSide(color: DSXColors.danger),
                    foregroundColor: DSXColors.danger,
                  ),
                  child: const Text('Delete Account'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSwitchTile(
    String title,
    String subtitle,
    bool value,
    ValueChanged<bool> onChanged, {
    bool warningIcon = false,
  }) {
    return Row(
      children: [
        if (warningIcon)
          Icon(Icons.warning_amber, color: DSXColors.warn, size: 16),
        if (warningIcon) const SizedBox(width: 8),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: Theme.of(context).textTheme.titleSmall,
              ),
              Text(
                subtitle,
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ],
          ),
        ),
        Switch(
          value: value,
          onChanged: (newValue) {
            HapticFeedback.lightImpact();
            onChanged(newValue);
          },
          activeColor: DSXColors.accent,
        ),
      ],
    );
  }

  Widget _buildTimeSelector(String label, TimeOfDay time, ValueChanged<TimeOfDay> onChanged) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: Theme.of(context).textTheme.bodySmall,
        ),
        const SizedBox(height: 4),
        GestureDetector(
          onTap: () async {
            final newTime = await showTimePicker(
              context: context,
              initialTime: time,
            );
            if (newTime != null) {
              onChanged(newTime);
            }
          },
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: DSXColors.glass,
              border: Border.all(color: DSXColors.border),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(
              time.format(context),
              style: Theme.of(context).textTheme.titleSmall,
            ),
          ),
        ),
      ],
    );
  }

  String _getModeDescription(DrillMode mode) {
    switch (mode) {
      case DrillMode.strict:
        return 'No-nonsense military discipline. Harsh but effective.';
      case DrillMode.balanced:
        return 'Firm guidance with motivational support.';
      case DrillMode.light:
        return 'Gentle encouragement and mindful reminders.';
    }
  }

  String _getIntensityDescription(int intensity) {
    switch (intensity) {
      case 1:
        return 'Gentle nudges and soft reminders';
      case 2:
        return 'Moderate pressure with clear expectations';
      case 3:
        return 'Maximum intensity with tough love';
      default:
        return '';
    }
  }

  void _showExportDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: DSXColors.base,
        title: const Text('Export Data'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('Choose export format:'),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: GlassButton.ghost(
                    'JSON',
                    onPressed: () {
                      Navigator.pop(context);
                      _exportData(ExportFormat.json);
                    },
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: GlassButton.ghost(
                    'CSV',
                    onPressed: () {
                      Navigator.pop(context);
                      _exportData(ExportFormat.csv);
                    },
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  void _showResetDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: DSXColors.base,
        title: Text(
          'Reset All Data',
          style: TextStyle(color: DSXColors.danger),
        ),
        content: const Text(
          'This will permanently delete all your habits, streaks, and progress. This action cannot be undone.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              Toast.show(context, 'Data reset initiated...');
            },
            style: TextButton.styleFrom(foregroundColor: DSXColors.danger),
            child: const Text('Reset'),
          ),
        ],
      ),
    );
  }

  void _showDeleteAccountDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: DSXColors.base,
        title: Text(
          'Delete Account',
          style: TextStyle(color: DSXColors.danger),
        ),
        content: const Text(
          'This will permanently delete your account and all associated data. This action cannot be undone.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              Toast.show(context, 'Account deletion initiated...');
            },
            style: TextButton.styleFrom(foregroundColor: DSXColors.danger),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }

  void _exportData(ExportFormat format) {
    final formatName = format == ExportFormat.json ? 'JSON' : 'CSV';
    Toast.show(context, 'Exporting data as $formatName...');
    // TODO: Implement actual export functionality
  }

  void _saveSettings() {
    // TODO: Save settings to backend/local storage
    HapticFeedback.lightImpact();
  }
} 