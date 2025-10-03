import 'dart:async';
import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/material.dart';
import '../services/api_client.dart';

class AlarmAudioProvider {
  static final AlarmAudioProvider _instance = AlarmAudioProvider._internal();
  factory AlarmAudioProvider() => _instance;
  AlarmAudioProvider._internal();

  final AudioPlayer _player = AudioPlayer();
  bool _userHasInteracted = false;
  final ApiClient _apiClient = ApiClient();
  
  void markUserInteraction() {
    _userHasInteracted = true;
  }

  Future<void> playAlarmSound({String? alarmId, String? mentorVoiceUrl}) async {
    if (!_userHasInteracted) {
      print('⚠️ User interaction required before playing alarm audio');
      return;
    }
    
    try {
      await _player.stop();
      
      // Try to get drill sergeant voice from backend first
      if (alarmId != null) {
        try {
          final alarmResponse = await _apiClient.fireAlarm(alarmId);
          if (alarmResponse['voice'] != null && alarmResponse['voice']['url'] != null) {
            await _player.play(UrlSource(alarmResponse['voice']['url']));
            print('🎵 Playing drill sergeant alarm voice');
            return;
          }
        } catch (e) {
          print('⚠️ Failed to get alarm voice from backend: $e');
        }
      }
      
      // Fallback to mentor voice if provided
      if (mentorVoiceUrl != null) {
        try {
          await _player.play(UrlSource(mentorVoiceUrl));
          print('🎵 Playing mentor voice alarm');
          return;
        } catch (e) {
          print('⚠️ Failed to play mentor voice: $e');
        }
      }
      
      // Final fallback to generic alarm sounds
      await _playGenericAlarm();
      
    } catch (e) {
      print('Alarm audio error: $e');
      _showVisualAlert();
    }
  }

  Future<void> _playGenericAlarm() async {
    const List<String> fallbackUrls = [
      'https://www.soundjay.com/misc/sounds/bell-ringing-05.wav',
      'https://assets.mixkit.co/active_storage/sfx/2869/2869-preview.mp3',
      'https://www.soundjay.com/misc/sounds/bell-ringing-04.wav',
    ];
    
    bool audioPlayed = false;
    for (String url in fallbackUrls) {
      try {
        await _player.play(UrlSource(url));
        audioPlayed = true;
        break;
      } catch (e) {
        print('Failed to play from $url: $e');
        continue;
      }
    }
    
    if (!audioPlayed) {
      throw Exception('All audio sources failed');
    }
    
    // Set to loop for alarm persistence
    await _player.setReleaseMode(ReleaseMode.loop);
  }

  Future<void> stopAlarm() async {
    await _player.stop();
  }

  void _showVisualAlert() {
    // Fallback visual alert if audio fails
    print('🔔 Visual alarm alert triggered');
  }
}
