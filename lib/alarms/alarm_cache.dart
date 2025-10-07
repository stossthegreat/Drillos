import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';

class AlarmModel {
  final String id;             // uuid
  final String? habitId;       // link to habit (optional)
  final String mentorId;       // e.g. 'drill', 'marcus', 'zen'
  final String title;          // display title
  final String voiceAssetPath; // assets/audio/mentors/...
  final String time;           // "HH:mm"
  final List<int> daysOfWeek;  // 1=Mon .. 7=Sun
  final bool enabled;

  const AlarmModel({
    required this.id,
    required this.mentorId,
    required this.title,
    required this.voiceAssetPath,
    required this.time,
    required this.daysOfWeek,
    this.habitId,
    this.enabled = true,
  });

  AlarmModel copyWith({
    String? id,
    String? habitId,
    String? mentorId,
    String? title,
    String? voiceAssetPath,
    String? time,
    List<int>? daysOfWeek,
    bool? enabled,
  }) {
    return AlarmModel(
      id: id ?? this.id,
      habitId: habitId ?? this.habitId,
      mentorId: mentorId ?? this.mentorId,
      title: title ?? this.title,
      voiceAssetPath: voiceAssetPath ?? this.voiceAssetPath,
      time: time ?? this.time,
      daysOfWeek: daysOfWeek ?? this.daysOfWeek,
      enabled: enabled ?? this.enabled,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'habitId': habitId,
        'mentorId': mentorId,
        'title': title,
        'voiceAssetPath': voiceAssetPath,
        'time': time,
        'daysOfWeek': daysOfWeek,
        'enabled': enabled,
      };

  static AlarmModel fromJson(Map<String, dynamic> j) => AlarmModel(
        id: j['id'] as String,
        habitId: j['habitId'] as String?,
        mentorId: j['mentorId'] as String,
        title: j['title'] as String,
        voiceAssetPath: j['voiceAssetPath'] as String,
        time: j['time'] as String,
        daysOfWeek: (j['daysOfWeek'] as List).map((e) => int.parse('$e')).toList(),
        enabled: j['enabled'] as bool? ?? true,
      );
}

class AlarmCache {
  static const _key = 'alarms:v1';

  static Future<List<AlarmModel>> loadAll() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_key);
    if (raw == null || raw.isEmpty) return [];
    final list = (jsonDecode(raw) as List).cast<Map<String, dynamic>>();
    return list.map(AlarmModel.fromJson).toList();
  }

  static Future<void> saveAll(List<AlarmModel> alarms) async {
    final prefs = await SharedPreferences.getInstance();
    final encoded = jsonEncode(alarms.map((a) => a.toJson()).toList());
    await prefs.setString(_key, encoded);
  }

  static Future<void> upsert(AlarmModel alarm) async {
    final list = await loadAll();
    final idx = list.indexWhere((a) => a.id == alarm.id);
    if (idx >= 0) {
      list[idx] = alarm;
    } else {
      list.add(alarm);
    }
    await saveAll(list);
  }

  static Future<void> delete(String alarmId) async {
    final list = await loadAll();
    list.removeWhere((a) => a.id == alarmId);
    await saveAll(list);
  }

  static Future<List<AlarmModel>> forHabit(String habitId) async {
    final list = await loadAll();
    return list.where((a) => a.habitId == habitId).toList();
  }

  static Future<AlarmModel?> byId(String alarmId) async {
    final list = await loadAll();
    try {
      return list.firstWhere((a) => a.id == alarmId);
    } catch (_) {
      return null;
    }
  }

  static Future<void> setEnabled(String alarmId, bool enabled) async {
    final list = await loadAll();
    final idx = list.indexWhere((a) => a.id == alarmId);
    if (idx >= 0) {
      list[idx] = list[idx].copyWith(enabled: enabled);
      await saveAll(list);
    }
  }
}
