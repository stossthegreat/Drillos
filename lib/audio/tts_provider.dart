import 'dart:convert';
import 'package:audioplayers/audioplayers.dart';
import '../services/api_client.dart';

class TtsProvider {
  String? _lastHash;
  final AudioPlayer _player = AudioPlayer();

  Future<void> playFromUrl(String url) async {
    try {
      print('Playing audio from URL: $url'); // Debug log
      await _player.stop();
      if (url.startsWith('data:audio')) {
        try {
          await _player.play(UrlSource(url));
        } catch (e) {
          print('Data URL playback failed: $e');
          try {
            final base64Data = url.split(',').last;
            final bytes = base64Decode(base64Data);
            await _player.play(BytesSource(bytes));
          } catch (e2) {
            print('Base64 decode error: $e2');
            throw e; // Re-throw original
          }
        }
      } else {
        await _player.play(UrlSource(url));
      }
    } catch (e) {
      print('Play URL error: $e');
    }
  }

  Future<void> playPreset(String id) async {
    final _ = _lastHash; // keep analyzer happy
    try {
      final res = await apiClient.getVoicePreset(id);
      final url = (res['url'] ?? '').toString();
      if (url.isEmpty) return;
      await _player.stop();
      if (url.startsWith('data:audio')) {
        try {
          // For web, try playing data URL directly first
          await _player.play(UrlSource(url));
        } catch (e) {
          print('Data URL playback failed: $e');
          // Try base64 decode as fallback
          try {
            final base64Data = url.split(',').last;
            final bytes = base64Decode(base64Data);
            await _player.play(BytesSource(bytes));
          } catch (e2) {
            print('Base64 decode error: $e2');
            throw e; // Re-throw original error
          }
        }
      } else {
        await _player.play(UrlSource(url));
      }
    } catch (e) {
      // ignore: avoid_print
      print('TTS preset error: $e');
    }
  }

  Future<void> speakDynamic(String text, {String voiceVariant = 'balanced'}) async {
    _lastHash = base64Url.encode(utf8.encode('$voiceVariant:$text'));
    try {
      final res = await apiClient.ttsVoice(text, voice: voiceVariant);
      print('TTS Response: $res'); // Debug log
      
      // Check multiple possible response structures
      String url = '';
      if (res['url'] != null && res['url'].toString().isNotEmpty) {
        url = res['url'].toString();
      } else if (res['audio'] != null && res['audio']['url'] != null) {
        url = res['audio']['url'].toString();
      } else if (res['voice'] != null && res['voice']['url'] != null) {
        url = res['voice']['url'].toString();
      }
      
      print('Audio URL: $url'); // Debug log
      
      if (url.isEmpty) {
        print('No audio URL found in response');
        return;
      }
      
      await _player.stop();
      print('Playing audio from: $url'); // Debug log
      
      if (url.startsWith('data:audio')) {
        try {
          // For web, try playing data URL directly first
          await _player.play(UrlSource(url));
        } catch (e) {
          print('Data URL playback failed: $e');
          // Try base64 decode as fallback
          try {
            final base64Data = url.split(',').last;
            final bytes = base64Decode(base64Data);
            await _player.play(BytesSource(bytes));
          } catch (e2) {
            print('Base64 decode error: $e2');
            throw e; // Re-throw original error
          }
        }
      } else {
        await _player.play(UrlSource(url));
      }
    } catch (e) {
      // ignore: avoid_print
      print('TTS dynamic error: $e');
    }
  }
} 