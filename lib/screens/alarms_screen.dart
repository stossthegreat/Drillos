import 'package:flutter/material.dart';
import '../design/glass.dart';
import '../design/tokens.dart';
import '../services/api_client.dart';
import '../design/feedback.dart';
import '../audio/alarm_audio.dart';

class AlarmItem {
  String id;
  String label;
  String rrule;
  String tone;
  bool enabled;
  String? nextRun;
  String status;
  int? timeUntilNext;
  Map<String, dynamic>? metadata;

  AlarmItem({
    required this.id,
    required this.label,
    required this.rrule,
    required this.tone,
    required this.enabled,
    this.nextRun,
    this.status = 'inactive',
    this.timeUntilNext,
    this.metadata,
  });

  factory AlarmItem.fromJson(Map<String, dynamic> json) {
    return AlarmItem(
      id: (json['id'] ?? '').toString(),
      label: (json['label'] ?? 'Alarm').toString(),
      rrule: (json['rrule'] ?? '').toString(),
      tone: (json['tone'] ?? 'balanced').toString(),
      enabled: (json['enabled'] ?? true) == true,
      nextRun: (json['nextRun'] ?? json['next_run'])?.toString(),
      status: (json['status'] ?? 'inactive').toString(),
      timeUntilNext: json['timeUntilNext'] is int ? json['timeUntilNext'] as int : int.tryParse((json['timeUntilNext'] ?? '').toString()),
      metadata: (json['metadata'] is Map<String, dynamic>) ? json['metadata'] as Map<String, dynamic> : null,
    );
  }
}

class AlarmsScreen extends StatefulWidget {
  const AlarmsScreen({super.key});

  @override
  State<AlarmsScreen> createState() => _AlarmsScreenState();
}

class _AlarmsScreenState extends State<AlarmsScreen> with TickerProviderStateMixin {
  bool isLoading = true;
  List<AlarmItem> alarms = [];
  late AnimationController _pulseController;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      duration: const Duration(milliseconds: 1000),
      vsync: this,
    )..repeat(reverse: true);
    
    _loadAlarms();
    
    // Refresh every 30 seconds to update countdowns
    _startPeriodicRefresh();
  }

  @override
  void dispose() {
    _pulseController.dispose();
    super.dispose();
  }

  void _startPeriodicRefresh() {
    Future.delayed(const Duration(seconds: 30), () {
      if (mounted) {
        _loadAlarms();
        _startPeriodicRefresh();
      }
    });
  }

  void _loadAlarms() async {
    setState(() { isLoading = true; });
    
    try {
      // Set auth token (in production this would come from authentication)
      apiClient.setAuthToken('valid-token');
      
      final response = await apiClient.getAlarms();
      
      setState(() {
        alarms = (response as List).map((json) => AlarmItem.fromJson(json)).toList();
        isLoading = false;
      });
      
      print('✅ Loaded ${alarms.length} alarms');
      
    } catch (e) {
      print('❌ Failed to load alarms: $e');
      setState(() { isLoading = false; });
      Toast.show(context, 'Failed to load alarms: $e');
    }
  }

  void _createAlarm() async {
    final result = await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (context) => _CreateAlarmDialog(),
    );
    
    if (result != null) {
      try {
        setState(() { isLoading = true; });
        
        final newAlarm = await apiClient.createAlarm(result);
        
        setState(() {
          alarms.add(AlarmItem.fromJson(newAlarm));
          isLoading = false;
        });
        
        Toast.show(context, 'Alarm created successfully!');
        
        // Show confirmation with countdown
        final timeUntil = newAlarm['timeUntilNext'];
        if (timeUntil != null && timeUntil > 0) {
          _showAlarmScheduledDialog(newAlarm['label'], timeUntil);
        }
        
      } catch (e) {
        setState(() { isLoading = false; });
        Toast.show(context, 'Failed to create alarm: $e');
      }
    }
  }

  void _showAlarmScheduledDialog(String label, int seconds) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: DSXColors.base,
        title: Row(
          children: [
            Icon(Icons.alarm, color: DSXColors.accent, size: 28),
            const SizedBox(width: 8),
            const Text('Alarm Scheduled'),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('"$label"'),
            const SizedBox(height: 8),
            Text('Will fire in $seconds seconds', 
              style: Theme.of(context).textTheme.titleMedium?.copyWith(color: DSXColors.accent)),
            const SizedBox(height: 16),
            Text('Get ready for action!', 
              style: Theme.of(context).textTheme.bodyMedium),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Roger that!'),
          ),
        ],
      ),
    );
  }

  void _deleteAlarm(AlarmItem alarm) async {
    try {
      await apiClient.deleteAlarm(alarm.id);
      
      setState(() {
        alarms.remove(alarm);
      });
      
      Toast.show(context, 'Alarm deleted');
      
    } catch (e) {
      Toast.show(context, 'Failed to delete alarm: $e');
    }
  }

  void _dismissAlarm(AlarmItem alarm) async {
    try {
      await apiClient.dismissAlarm(alarm.id);
      Toast.show(context, 'Alarm dismissed');
    } catch (e) {
      Toast.show(context, 'Failed to dismiss alarm: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    if (isLoading && alarms.isEmpty) {
      return Scaffold(
        appBar: const GlassAppBar(title: 'Mission Alarms'),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    return Scaffold(
      appBar: const GlassAppBar(title: 'Mission Alarms'),
      body: RefreshIndicator(
        onRefresh: () async => _loadAlarms(),
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            // Quick actions
            Row(
              children: [
                Expanded(
                  child: GlassButton.primary('Create Alarm', onPressed: _createAlarm),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: GlassButton.ghost('Test 10s', onPressed: () => _createTestAlarm()),
                ),
              ],
            ),
            const SizedBox(height: 12),
            
            // Audio permission for Chrome
            Center(
              child: AlarmAudioPermissionButton(
                onPermissionGranted: () {
                  Toast.show(context, 'Alarm audio enabled! 🔊');
                },
              ),
            ),
            const SizedBox(height: 20),
            
            // Active alarms section
            _buildSection('Active Alarms', alarms.where((a) => a.enabled).toList()),
            
            const SizedBox(height: 16),
            
            // Inactive alarms section
            if (alarms.any((a) => !a.enabled))
              _buildSection('Inactive Alarms', alarms.where((a) => !a.enabled).toList()),
            
            const SizedBox(height: 24),
            
            // Info card
            GlassCard(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(Icons.info_outline, color: DSXColors.accent, size: 20),
                        const SizedBox(width: 8),
                        Text('Alarm System', style: Theme.of(context).textTheme.titleMedium),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Text('• Alarms will fire even if app is closed', 
                      style: Theme.of(context).textTheme.bodyMedium),
                    Text('• Escalation occurs after 2 minutes if not dismissed', 
                      style: Theme.of(context).textTheme.bodyMedium),
                    Text('• Daily alarms auto-reschedule for next day', 
                      style: Theme.of(context).textTheme.bodyMedium),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSection(String title, List<AlarmItem> sectionAlarms) {
    if (sectionAlarms.isEmpty) return const SizedBox.shrink();
    
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title, style: Theme.of(context).textTheme.titleLarge),
        const SizedBox(height: 12),
        ...sectionAlarms.map((alarm) => _AlarmTile(
          alarm: alarm,
          onDelete: () => _deleteAlarm(alarm),
          onDismiss: () => _dismissAlarm(alarm),
          pulseAnimation: _pulseController,
        )),
      ],
    );
  }

  void _createTestAlarm() async {
    try {
      setState(() { isLoading = true; });
      
      final testAlarm = await apiClient.createAlarm({
        'label': 'Test Alarm (10s)',
        'delaySeconds': 10,
        'tone': 'strict',
      });
      
      setState(() {
        alarms.add(AlarmItem.fromJson(testAlarm));
        isLoading = false;
      });
      
      Toast.show(context, 'Test alarm will fire in 10 seconds!');
      
    } catch (e) {
      setState(() { isLoading = false; });
      Toast.show(context, 'Failed to create test alarm: $e');
    }
  }
}

class _AlarmTile extends StatelessWidget {
  final AlarmItem alarm;
  final VoidCallback onDelete;
  final VoidCallback onDismiss;
  final AnimationController pulseAnimation;

  const _AlarmTile({
    required this.alarm,
    required this.onDelete,
    required this.onDismiss,
    required this.pulseAnimation,
  });

  String _formatTimeUntil(int? seconds) {
    if (seconds == null || seconds <= 0) return 'Inactive';
    
    if (seconds < 60) return '${seconds}s';
    if (seconds < 3600) return '${(seconds / 60).round()}m';
    if (seconds < 86400) return '${(seconds / 3600).round()}h';
    return '${(seconds / 86400).round()}d';
  }

  Color _getToneColor(String tone) {
    switch (tone) {
      case 'strict': return DSXColors.danger;
      case 'balanced': return DSXColors.accent;
      case 'light': return Colors.lightBlue;
      default: return DSXColors.accent;
    }
  }

  IconData _getToneIcon(String tone) {
    switch (tone) {
      case 'strict': return Icons.campaign;
      case 'balanced': return Icons.notifications;
      case 'light': return Icons.notifications_none;
      default: return Icons.notifications;
    }
  }

  @override
  Widget build(BuildContext context) {
    final toneColor = _getToneColor(alarm.tone);
    final isScheduled = alarm.status == 'scheduled';
    
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: AnimatedBuilder(
        animation: pulseAnimation,
        builder: (context, child) {
          final pulseOpacity = isScheduled ? (0.6 + 0.4 * pulseAnimation.value) : 1.0;
          
          return GlassCard(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: toneColor.withOpacity(0.15),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Icon(
                          _getToneIcon(alarm.tone),
                          color: toneColor.withOpacity(pulseOpacity),
                          size: 20,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              alarm.label,
                              style: Theme.of(context).textTheme.titleMedium,
                            ),
                            const SizedBox(height: 4),
                            Row(
                              children: [
                                Text(
                                  alarm.tone.toUpperCase(),
                                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                    color: toneColor,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Text('•', style: TextStyle(color: DSXColors.textSecondary)),
                                const SizedBox(width: 8),
                                Text(
                                  _formatTimeUntil(alarm.timeUntilNext),
                                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                    color: isScheduled ? DSXColors.accent : DSXColors.textSecondary,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                      if (isScheduled)
                        GlassButton.ghost('Dismiss', onPressed: onDismiss)
                      else
                        IconButton(
                          onPressed: onDelete,
                          icon: Icon(Icons.delete_outline, color: DSXColors.danger, size: 20),
                        ),
                    ],
                  ),
                  
                  if (alarm.metadata?['type'] == 'habit_reminder') ...[
                    const SizedBox(height: 12),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: DSXColors.accent.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        'Habit Reminder',
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: DSXColors.accent,
                        ),
                      ),
                    ),
                  ],
                  
                  if (alarm.rrule.contains('DAILY')) ...[
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Icon(Icons.repeat, color: DSXColors.textSecondary, size: 16),
                        const SizedBox(width: 4),
                        Text(
                          'Repeats daily',
                          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: DSXColors.textSecondary,
                          ),
                        ),
                      ],
                    ),
                  ],
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}

class _CreateAlarmDialog extends StatefulWidget {
  @override
  State<_CreateAlarmDialog> createState() => _CreateAlarmDialogState();
}

class _CreateAlarmDialogState extends State<_CreateAlarmDialog> {
  final labelController = TextEditingController();
  String tone = 'balanced';
  int delaySeconds = 60;

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      backgroundColor: DSXColors.base,
      title: const Text('Create New Alarm'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: labelController,
              decoration: const InputDecoration(hintText: 'Alarm label'),
            ),
            const SizedBox(height: 16),
            
            Text('Tone: ${tone.toUpperCase()}'),
            SegmentedButton<String>(
              segments: const [
                ButtonSegment(value: 'light', label: Text('Light')),
                ButtonSegment(value: 'balanced', label: Text('Balanced')),
                ButtonSegment(value: 'strict', label: Text('Strict')),
              ],
              selected: {tone},
              onSelectionChanged: (selection) {
                setState(() => tone = selection.first);
              },
            ),
            
            const SizedBox(height: 16),
            Text('Fire in: ${delaySeconds}s'),
            Slider(
              value: delaySeconds.toDouble(),
              min: 10,
              max: 300,
              divisions: 29,
              onChanged: (value) => setState(() => delaySeconds = value.round()),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        TextButton(
          onPressed: () {
            if (labelController.text.trim().isNotEmpty) {
              Navigator.pop(context, {
                'label': labelController.text.trim(),
                'tone': tone,
                'delaySeconds': delaySeconds,
              });
            }
          },
          child: const Text('Create'),
        ),
      ],
    );
  }
} 