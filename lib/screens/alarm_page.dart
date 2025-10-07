import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../services/alarm_service.dart';
import '../design/feedback.dart';

class AlarmScreen extends StatefulWidget {
  const AlarmScreen({super.key});

  @override
  State<AlarmScreen> createState() => _AlarmScreenState();
}

class _AlarmScreenState extends State<AlarmScreen> {
  String? selectedVoiceId;
  bool isLoading = true;

  final List<Map<String, dynamic>> voices = [
    {
      'id': 'standard',
      'name': 'Standard Alarm',
      'desc': 'Simple sound, no voice',
      'asset': 'assets/mentors/standard.png',
      'color': const Color(0xFF64748B),
      'message': '⏰ Time to rise and conquer the day.',
    },
    {
      'id': 'drill_sergeant',
      'name': 'Drill Sergeant',
      'desc': 'Strict • No Excuses',
      'asset': 'assets/mentors/drill.png',
      'color': const Color(0xFF10B981),
      'message':
          'GET UP, SOLDIER! The day’s not waiting for you! Move, move, move!',
    },
    {
      'id': 'marcus_aurelius',
      'name': 'Marcus Aurelius',
      'desc': 'Stoic • Calm Authority',
      'asset': 'assets/mentors/marcus.png',
      'color': const Color(0xFF6366F1),
      'message':
          'Awaken. Each morning you rise anew—act with virtue, reason, and purpose.',
    },
    {
      'id': 'buddha',
      'name': 'Buddha',
      'desc': 'Peaceful • Centered',
      'asset': 'assets/mentors/buddha.png',
      'color': const Color(0xFFFBBF24),
      'message': 'Breathe. The dawn is a new beginning. Walk the path gently.',
    },
    {
      'id': 'confucius',
      'name': 'Confucius',
      'desc': 'Wise • Disciplined',
      'asset': 'assets/mentors/confucius.png',
      'color': const Color(0xFF3B82F6),
      'message': 'Rise early, set order to your day, and wisdom will follow.',
    },
    {
      'id': 'abraham_lincoln',
      'name': 'Abraham Lincoln',
      'desc': 'Honest • Resolute',
      'asset': 'assets/mentors/lincoln.png',
      'color': const Color(0xFFE11D48),
      'message':
          'Determine that the thing can and shall be done—and then rise to do it.',
    },
  ];

  @override
  void initState() {
    super.initState();
    _loadSelectedVoice();
  }

  Future<void> _loadSelectedVoice() async {
    final prefs = await SharedPreferences.getInstance();
    final voice = prefs.getString('defaultAlarmVoice') ?? 'drill_sergeant';
    setState(() {
      selectedVoiceId = voice;
      isLoading = false;
    });
  }

  Future<void> _saveSelectedVoice(String id) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('defaultAlarmVoice', id);
    setState(() => selectedVoiceId = id);
    HapticFeedback.selectionClick();
    Toast.show(context, '✅ ${_getVoiceById(id)['name']} set as default alarm');
  }

  Map<String, dynamic> _getVoiceById(String id) {
    return voices.firstWhere((v) => v['id'] == id);
  }

  Future<void> _setTestAlarm() async {
    final voice = _getVoiceById(selectedVoiceId ?? 'drill_sergeant');
    final name = voice['name'];
    final message = voice['message'];
    final id = voice['id'];

    final pickedTime = await showTimePicker(
      context: context,
      initialTime: const TimeOfDay(hour: 8, minute: 0),
      builder: (context, child) {
        return Theme(
          data: ThemeData.dark().copyWith(
            colorScheme: const ColorScheme.dark(primary: Color(0xFF10B981)),
          ),
          child: child!,
        );
      },
    );

    if (pickedTime == null) return;

    final timeStr =
        '${pickedTime.hour.toString().padLeft(2, '0')}:${pickedTime.minute.toString().padLeft(2, '0')}';

    try {
      await alarmService.scheduleAlarm(
        habitId: '__test_alarm__',
        habitName: name,
        time: timeStr,
        daysOfWeek: [DateTime.now().weekday],
        mentorMessage: '🔔 $message',
      );

      Toast.show(context, '🕒 Test alarm set for $timeStr ($name)');
    } catch (e) {
      Toast.show(context, '❌ Failed to set alarm: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    if (isLoading) {
      return const Scaffold(
        backgroundColor: Color(0xFF0B0F0E),
        body: Center(child: CircularProgressIndicator(color: Color(0xFF10B981))),
      );
    }

    return Scaffold(
      backgroundColor: const Color(0xFF0B0F0E),
      appBar: AppBar(
        title: const Text('Alarm Voices',
            style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        backgroundColor: const Color(0xFF0B0F0E),
        elevation: 0,
        centerTitle: true,
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          const SizedBox(height: 8),
          Text(
            'Choose your wake-up voice',
            style: TextStyle(color: Colors.white.withOpacity(0.7), fontSize: 14),
          ),
          const SizedBox(height: 16),
          ...voices.map((v) => _buildVoiceCard(v)).toList(),
          const SizedBox(height: 40),
          ElevatedButton.icon(
            onPressed: _setTestAlarm,
            icon: const Icon(Icons.alarm_on, color: Colors.black),
            label: const Text(
              'Set Test Alarm',
              style: TextStyle(
                color: Colors.black,
                fontWeight: FontWeight.bold,
                fontSize: 16,
              ),
            ),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF10B981),
              minimumSize: const Size(double.infinity, 56),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
            ),
          ),
          const SizedBox(height: 40),
        ],
      ),
    );
  }

  Widget _buildVoiceCard(Map<String, dynamic> v) {
    final isSelected = v['id'] == selectedVoiceId;
    return GestureDetector(
      onTap: () => _saveSelectedVoice(v['id']),
      child: Container(
        margin: const EdgeInsets.only(bottom: 16),
        decoration: BoxDecoration(
          color: const Color(0xFF121816),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isSelected ? v['color'].withOpacity(0.9) : Colors.white10,
            width: isSelected ? 2.5 : 1.0,
          ),
          boxShadow: isSelected
              ? [
                  BoxShadow(
                    color: v['color'].withOpacity(0.4),
                    blurRadius: 12,
                    spreadRadius: 1,
                  ),
                ]
              : [],
        ),
        child: Row(
          children: [
            ClipRRect(
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(16),
                bottomLeft: Radius.circular(16),
              ),
              child: Image.asset(
                v['asset'],
                width: 90,
                height: 90,
                fit: BoxFit.cover,
              ),
            ),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      v['name'],
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      v['desc'],
                      style: const TextStyle(
                        color: Colors.white70,
                        fontSize: 13,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            if (isSelected)
              const Padding(
                padding: EdgeInsets.only(right: 16),
                child: Icon(Icons.check_circle, color: Color(0xFF10B981), size: 26),
              ),
          ],
        ),
      ),
    );
  }
}
