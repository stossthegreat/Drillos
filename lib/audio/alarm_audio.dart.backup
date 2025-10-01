import 'dart:async';
import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/material.dart';

class AlarmAudioProvider {
  static final AlarmAudioProvider _instance = AlarmAudioProvider._internal();
  factory AlarmAudioProvider() => _instance;
  AlarmAudioProvider._internal();

  final AudioPlayer _player = AudioPlayer();
  bool _userHasInteracted = false;
  
  void markUserInteraction() {
    _userHasInteracted = true;
  }

  Future<void> playAlarmSound() async {
    if (!_userHasInteracted) {
      print('⚠️ User interaction required before playing alarm audio');
      return;
    }
    
    try {
      await _player.stop();
      
      // Use working audio URLs for web
      const List<String> fallbackUrls = [
        'https://www.soundjay.com/misc/sounds/bell-ringing-05.wav',
        'https://assets.mixkit.co/active_storage/sfx/2869/2869-preview.mp3',
        'https://www.soundjay.com/misc/sounds/bell-ringing-04.wav',
        'data:audio/wav;base64,UklGRnoGAABXQVZFZm10IBAAAAABAAEAQB8AAEAfAAABAAgAZGF0YQoGAACBhYqFbF1fdJivrJBhNjVgodDbq2EcBj+a2/LDciUFLIHO8tiJNwgZaLvt559NEAxQp+PwtmMcBjiR1/LMeSMFl2+z9N2QQAoUXrTp66hVFApGn+DyvmwhBjeR2O/NeSYELILM8tyOSQUUXbXn4p9dGBVhq+nzvmEaA'
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
      
    } catch (e) {
      print('Alarm audio error: $e');
      // Fallback: show visual alert if audio fails
      _showVisualAlert();
    }
  }

  Future<void> stopAlarm() async {
    try {
      await _player.stop();
      await _player.setReleaseMode(ReleaseMode.release);
    } catch (e) {
      print('Stop alarm error: $e');
    }
  }

  void _showVisualAlert() {
    print('🚨 ALARM! 🚨 (Audio not available)');
  }

  Future<void> testAlarmSound() async {
    if (!_userHasInteracted) {
      print('⚠️ User interaction required before playing alarm audio');
      return;
    }
    
    try {
      await playAlarmSound();
      // Stop after 3 seconds for test
      Future.delayed(const Duration(seconds: 3), () => stopAlarm());
    } catch (e) {
      print('Test alarm error: $e');
    }
  }
}

// Widget to prompt user interaction for alarm audio
class AlarmAudioPermissionButton extends StatefulWidget {
  final VoidCallback? onPermissionGranted;
  
  const AlarmAudioPermissionButton({
    super.key,
    this.onPermissionGranted,
  });

  @override
  State<AlarmAudioPermissionButton> createState() => _AlarmAudioPermissionButtonState();
}

class _AlarmAudioPermissionButtonState extends State<AlarmAudioPermissionButton> {
  bool _permissionGranted = false;

  @override
  Widget build(BuildContext context) {
    if (_permissionGranted) {
      return const Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.volume_up, color: Colors.green, size: 16),
          SizedBox(width: 4),
          Text('Audio Enabled', style: TextStyle(color: Colors.green, fontSize: 12)),
        ],
      );
    }

    return ElevatedButton.icon(
      onPressed: () async {
        AlarmAudioProvider().markUserInteraction();
        await AlarmAudioProvider().testAlarmSound();
        setState(() {
          _permissionGranted = true;
        });
        widget.onPermissionGranted?.call();
      },
      icon: const Icon(Icons.volume_up, size: 16),
      label: const Text('Enable Alarm Audio', style: TextStyle(fontSize: 12)),
      style: ElevatedButton.styleFrom(
        backgroundColor: Colors.orange.withValues(alpha: 0.2),
        foregroundColor: Colors.orange,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        minimumSize: const Size(0, 32),
      ),
    );
  }
}
 