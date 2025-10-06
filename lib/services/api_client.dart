import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter/foundation.dart';
import '../utils/schedule.dart';

class ApiClient {
  String _baseUrl = const String.fromEnvironment('API_BASE_URL', defaultValue: '');

  static final ApiClient _singleton = ApiClient._internal();
  factory ApiClient() => _singleton;
  ApiClient._internal();

  String getBaseUrl() => _baseUrl.isNotEmpty ? _baseUrl : (kReleaseMode
      ? 'https://drillos-production.up.railway.app'
      : 'http://localhost:8080');

  void setBaseUrl(String url) {
    _baseUrl = url;
  }

  Map<String, String> _headers() => {
    'Content-Type': 'application/json',
    'x-user-id': 'demo-user-123',
  };

  // ---- HABITS (CRUD kept the same shape) ----

  Future<List<Map<String, dynamic>>> listHabits() async {
    final url = Uri.parse('${getBaseUrl()}/api/v1/habits');
    final r = await http.get(url, headers: _headers());
    if (r.statusCode != 200) throw Exception('failed listHabits');
    final decoded = jsonDecode(r.body);
    if (decoded is List) {
      return decoded.map<Map<String, dynamic>>((e) => Map<String, dynamic>.from(e)).toList();
    }
    return [];
  }

  Future<Map<String, dynamic>> createHabit(Map<String, dynamic> data) async {
    final url = Uri.parse('${getBaseUrl()}/api/v1/habits');
    final r = await http.post(url, headers: _headers(), body: jsonEncode(data));
    if (r.statusCode != 201) throw Exception('failed createHabit');
    return Map<String, dynamic>.from(jsonDecode(r.body));
  }

  Future<Map<String, dynamic>> updateHabit(String id, Map<String, dynamic> data) async {
    final url = Uri.parse('${getBaseUrl()}/api/v1/habits/$id');
    final r = await http.put(url, headers: _headers(), body: jsonEncode(data));
    if (r.statusCode != 200) throw Exception('failed updateHabit');
    return Map<String, dynamic>.from(jsonDecode(r.body));
  }

  Future<bool> deleteHabit(String id) async {
    final url = Uri.parse('${getBaseUrl()}/api/v1/habits/$id');
    final r = await http.delete(url, headers: _headers());
    return r.statusCode == 200;
  }

  // ---- TICK (fire-and-forget for UI speed) ----

  Future<void> tickHabit(String id, {DateTime? when}) async {
    // non-blocking: don't await in UI
    final url = Uri.parse('${getBaseUrl()}/api/v1/habits/$id/tick');
    unawaited(http.post(
      url,
      headers: _headers(),
      body: jsonEncode({
        if (when != null) 'date': when.toIso8601String(),
      }),
    ));
    // Local streak/XP update should be handled by the screen immediately.
  }

  // ---- BRIEF / NUDGE ----

  Future<Map<String, dynamic>> getBrief() async {
    final url = Uri.parse('${getBaseUrl()}/api/v1/brief/today');
    final r = await http.get(url, headers: _headers());
    if (r.statusCode != 200) return {};
    final d = jsonDecode(r.body);
    return (d is Map<String, dynamic>) ? d : {};
  }

  Future<Map<String, dynamic>> getNudge() async {
    final url = Uri.parse('${getBaseUrl()}/api/v1/nudges/one');
    final r = await http.get(url, headers: _headers());
    if (r.statusCode != 200) throw Exception('Failed to fetch nudge');
    final decoded = jsonDecode(r.body);
    if (decoded is List && decoded.isNotEmpty && decoded.first is Map<String, dynamic>) {
      return Map<String, dynamic>.from(decoded.first);
    }
    if (decoded is Map<String, dynamic>) {
      return decoded;
    }
    return {};
  }

  // ---- "Today" helper: filter by schedule on client ----

  Future<List<Map<String, dynamic>>> getTodayItems() async {
    final habits = await listHabits();
    final now = DateTime.now();
    final today = <Map<String, dynamic>>[];

    for (final h in habits) {
      final sched = HabitSchedule.fromJson((h['schedule'] as Map?)?.cast<String, dynamic>());
      final active = sched.isActiveOn(now);
      if (!active) continue;

      // shape compatible with existing UI:
      today.add({
        'id': h['id'],
        'name': h['title'] ?? h['name'] ?? '',
        'type': 'habit',
        'completed': await _isCompletedToday(h['id']),
        'streak': await _streakFor(h['id']),
        'color': h['color'] ?? 'emerald',
        'schedule': h['schedule'] ?? {}
      });
    }

    return today;
  }

  // ---- Local streak/XP store (SharedPreferences) ----

  Future<int> _streakFor(String habitId) async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getInt('streak:$habitId') ?? 0;
    // Streak increments should be handled by screen logic when tick happens.
  }

  Future<bool> _isCompletedToday(String habitId) async {
    final prefs = await SharedPreferences.getInstance();
    final key = 'done:$habitId:${_ymd(DateTime.now())}';
    return prefs.getBool(key) ?? false;
  }

  static String _ymd(DateTime d) => '${d.year}-${d.month}-${d.day}';

  // ---- LEGACY METHODS (keep for compatibility) ----

  Future<Map<String, dynamic>> getBriefToday() async {
    return getBrief();
  }

  Future<List<dynamic>> getHabits() async {
    return listHabits();
  }

  Future<List<dynamic>> getTasks() async {
    final url = Uri.parse('${getBaseUrl()}/api/v1/tasks');
    final r = await http.get(url, headers: _headers());
    if (r.statusCode != 200) throw Exception('Failed to load tasks');
    return jsonDecode(r.body);
  }

  Future<Map<String, dynamic>> createTask(Map<String, dynamic> taskData) async {
    final url = Uri.parse('${getBaseUrl()}/api/v1/tasks');
    final r = await http.post(url, headers: _headers(), body: jsonEncode(taskData));
    if (r.statusCode != 200 && r.statusCode != 201) throw Exception('Failed to create task');
    return Map<String, dynamic>.from(jsonDecode(r.body));
  }

  Future<Map<String, dynamic>> completeTask(String taskId) async {
    final url = Uri.parse('${getBaseUrl()}/api/v1/tasks/$taskId/complete');
    final r = await http.post(url, headers: _headers(), body: jsonEncode({}));
    if (r.statusCode != 200 && r.statusCode != 201) throw Exception('Failed to complete task');
    return Map<String, dynamic>.from(jsonDecode(r.body));
  }

  Future<void> deleteTask(String taskId) async {
    final url = Uri.parse('${getBaseUrl()}/api/v1/tasks/$taskId');
    final r = await http.delete(url, headers: _headers());
    if (r.statusCode != 200) throw Exception('Failed to delete task');
  }
}

final apiClient = ApiClient();

// Helper for fire-and-forget futures
void unawaited(Future<void> future) {
  future.catchError((e) => print('Background error: $e'));
}
