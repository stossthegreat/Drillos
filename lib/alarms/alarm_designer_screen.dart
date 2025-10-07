import 'package:flutter/material.dart';
import 'package:audioplayers/audioplayers.dart';
import 'package:uuid/uuid.dart';
import '../alarms/alarm_cache.dart';
import '../alarms/alarm_scheduler.dart';

class AlarmDesignerScreen extends StatefulWidget {
  final String? habitId; // optional link to habit

  const AlarmDesignerScreen({super.key, this.habitId});

  @override
  State<AlarmDesignerScreen> createState() => _AlarmDesignerScreenState();
}

class _AlarmDesignerScreenState extends State<AlarmDesignerScreen> {
  // Pre-cached voice lines (put matching files under assets/audio/mentors/..)
  // Update pubspec.yaml assets list accordingly.
  final Map<String, List<_VoiceLine>> _mentorLines = {
    'drill': [
      _VoiceLine('Wake up, soldier!', 'assets/audio/mentors/drill/wake_up.mp3'),
      _VoiceLine('Move! Move! Move!', 'assets/audio/mentors/drill/move.mp3'),
    ],
    'marcus': [
      _VoiceLine('Discipline is destiny.', 'assets/audio/mentors/marcus/discipline.mp3'),
      _VoiceLine('Control what you can.', 'assets/audio/mentors/marcus/control.mp3'),
    ],
    'zen': [
      _VoiceLine('Breathe. Begin again.', 'assets/audio/mentors/zen/breathe.mp3'),
      _VoiceLine('One step, one day.', 'assets/audio/mentors/zen/one_step.mp3'),
    ],
  };

  String _selectedMentor = 'drill';
  _VoiceLine? _selectedLine;
  final _timeController = TextEditingController(text: '07:00');
  List<int> _days = [1, 2, 3, 4, 5]; // default weekdays
  final _uuid = const Uuid();
  final _player = AudioPlayer();

  @override
  void initState() {
    super.initState();
    _selectedLine = _mentorLines[_selectedMentor]!.first;
  }

  @override
  void dispose() {
    _player.dispose();
    _timeController.dispose();
    super.dispose();
  }

  Future<void> _pickTime() async {
    final parts = _timeController.text.split(':');
    final initial = TimeOfDay(hour: int.parse(parts[0]), minute: int.parse(parts[1]));
    final picked = await showTimePicker(context: context, initialTime: initial);
    if (picked != null) {
      _timeController.text =
          '${picked.hour.toString().padLeft(2, '0')}:${picked.minute.toString().padLeft(2, '0')}';
      setState(() {});
    }
  }

  void _toggleDay(int day) {
    setState(() {
      if (_days.contains(day)) {
        _days.remove(day);
      } else {
        _days.add(day);
      }
      _days.sort();
    });
  }

  Future<void> _preview() async {
    if (_selectedLine == null) return;
    await _player.stop();
    await _player.play(AssetSource(_selectedLine!.asset));
  }

  Future<void> _save() async {
    if (_selectedLine == null || _days.isEmpty) return;

    final alarm = AlarmModel(
      id: _uuid.v4(),
      habitId: widget.habitId,
      mentorId: _selectedMentor,
      title: _selectedLine!.title,
      voiceAssetPath: _selectedLine!.asset,
      time: _timeController.text,
      daysOfWeek: _days,
      enabled: true,
    );

    await AlarmCache.upsert(alarm);
    await alarmScheduler.scheduleAlarm(alarm);
    if (!mounted) return;
    Navigator.of(context).pop(alarm);
  }

  @override
  Widget build(BuildContext context) {
    final lines = _mentorLines[_selectedMentor]!;
    return Scaffold(
      backgroundColor: const Color(0xFF0B0F0E),
      appBar: AppBar(
        backgroundColor: const Color(0xFF0B0F0E),
        title: const Text('Pick Your Alarm', style: TextStyle(color: Colors.white)),
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          const Text('Mentor', style: TextStyle(color: Colors.white70)),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            children: [
              for (final id in _mentorLines.keys)
                ChoiceChip(
                  label: Text(id.toUpperCase()),
                  selected: _selectedMentor == id,
                  onSelected: (_) => setState(() {
                    _selectedMentor = id;
                    _selectedLine = _mentorLines[_selectedMentor]!.first;
                  }),
                ),
            ],
          ),
          const SizedBox(height: 16),
          const Text('Voice Line', style: TextStyle(color: Colors.white70)),
          const SizedBox(height: 8),
          ...lines.map((l) {
            final selected = _selectedLine?.asset == l.asset;
            return ListTile(
              contentPadding: const EdgeInsets.symmetric(horizontal: 8),
              title: Text(l.title, style: const TextStyle(color: Colors.white)),
              subtitle: Text(l.asset, style: const TextStyle(color: Colors.white38, fontSize: 12)),
              trailing: Row(mainAxisSize: MainAxisSize.min, children: [
                IconButton(
                  icon: const Icon(Icons.play_arrow, color: Colors.white70),
                  onPressed: () => _player.play(AssetSource(l.asset)),
                ),
                Radio<_VoiceLine>(
                  value: l,
                  groupValue: _selectedLine,
                  onChanged: (v) => setState(() => _selectedLine = v),
                ),
              ]),
              tileColor: selected ? const Color(0xFF121816) : Colors.transparent,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            );
          }),
          const SizedBox(height: 16),
          const Text('Time', style: TextStyle(color: Colors.white70)),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _timeController,
                  readOnly: true,
                  style: const TextStyle(color: Colors.white),
                  decoration: InputDecoration(
                    hintText: 'HH:mm',
                    hintStyle: const TextStyle(color: Colors.white38),
                    filled: true,
                    fillColor: const Color(0xFF121816),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  onTap: _pickTime,
                ),
              ),
              const SizedBox(width: 8),
              ElevatedButton.icon(
                onPressed: _pickTime,
                icon: const Icon(Icons.access_time),
                label: const Text('Pick'),
              ),
            ],
          ),
          const SizedBox(height: 16),
          const Text('Days', style: TextStyle(color: Colors.white70)),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            children: [
              for (final d in List.generate(7, (i) => i + 1))
                FilterChip(
                  label: Text(_abbr(d)),
                  selected: _days.contains(d),
                  onSelected: (_) => _toggleDay(d),
                ),
            ],
          ),
          const SizedBox(height: 24),
          ElevatedButton.icon(
            onPressed: _save,
            icon: const Icon(Icons.alarm_on),
            label: const Text('Save & Schedule'),
            style: ElevatedButton.styleFrom(minimumSize: const Size.fromHeight(48)),
          ),
          const SizedBox(height: 8),
          OutlinedButton.icon(
            onPressed: _preview,
            icon: const Icon(Icons.volume_up),
            label: const Text('Preview Voice'),
            style: OutlinedButton.styleFrom(minimumSize: const Size.fromHeight(48)),
          ),
        ],
      ),
    );
  }

  String _abbr(int weekday) => const ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'][weekday - 1];
}

class _VoiceLine {
  final String title;
  final String asset;
  const _VoiceLine(this.title, this.asset);
}
