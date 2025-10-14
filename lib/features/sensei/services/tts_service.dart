import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:shared_preferences/shared_preferences.dart';

enum TtsState { playing, paused, stopped, error }

enum TtsError { notInitialized, languageUnavailable, voiceUnavailable, unknown }

class TtsService {
  final FlutterTts _flutterTts = FlutterTts();
  final ValueNotifier<TtsState> stateNotifier = ValueNotifier(TtsState.stopped);

  TtsError? _lastError;
  String? _currentLanguage;
  String? _currentVoice;
  String? _currentContent;
  int _currentProgress = 0;
  int _progressBaseOffset = 0;
  bool _suppressCompletionUpdates = false;

  // Getters
  bool get isPlaying => stateNotifier.value == TtsState.playing;
  bool get isPaused => stateNotifier.value == TtsState.paused;
  bool get isStopped => stateNotifier.value == TtsState.stopped;
  bool get hasError => stateNotifier.value == TtsState.error;
  TtsError? get lastError => _lastError;
  String? get currentLanguage => _currentLanguage;
  String? get currentVoice => _currentVoice;

  // Initialize TTS with saved preferences
  Future<bool> init() async {
    try {
      await _loadPreferences();

      // Set default settings
      await _flutterTts.awaitSpeakCompletion(true);
      await _flutterTts.setLanguage(_currentLanguage ?? 'en-US');
      await _flutterTts.setPitch(1.0);
      await _flutterTts.setSpeechRate(0.5);
      await _flutterTts.setVolume(1.0);

      // Set up handlers
      _flutterTts.setStartHandler(() {
        stateNotifier.value = TtsState.playing;
        _lastError = null;
      });

      _flutterTts.setCompletionHandler(() {
        if (_suppressCompletionUpdates) return;

        stateNotifier.value = TtsState.stopped;
        _currentProgress = _currentContent?.length ?? 0;
        _progressBaseOffset = 0;
      });

      _flutterTts.setErrorHandler((msg) {
        stateNotifier.value = TtsState.error;
        _lastError = _parseError(msg);
      });

      _flutterTts.setProgressHandler((
        String text,
        int start,
        int end,
        String word,
      ) {
        _currentProgress = _progressBaseOffset + end;
      });

      return true;
    } catch (e) {
      stateNotifier.value = TtsState.error;
      _lastError = TtsError.unknown;
      return false;
    }
  }

  // Parse error messages
  TtsError _parseError(String? message) {
    if (message == null) return TtsError.unknown;

    if (message.contains('not initialized')) {
      return TtsError.notInitialized;
    } else if (message.contains('language')) {
      return TtsError.languageUnavailable;
    } else if (message.contains('voice')) {
      return TtsError.voiceUnavailable;
    }

    return TtsError.unknown;
  }

  // Load saved preferences
  Future<void> _loadPreferences() async {
    final prefs = await SharedPreferences.getInstance();
    _currentLanguage = prefs.getString('tts_language') ?? 'en-US';
    _currentVoice = prefs.getString('tts_voice');
  }

  // Save preferences
  Future<void> _savePreferences() async {
    final prefs = await SharedPreferences.getInstance();
    if (_currentLanguage != null) {
      await prefs.setString('tts_language', _currentLanguage!);
    }
    if (_currentVoice != null) {
      await prefs.setString('tts_voice', _currentVoice!);
    }
  }

  // Set language code
  Future<bool> setLanguage(String languageCode) async {
    try {
      final result = await _flutterTts.setLanguage(languageCode);
      if (result != null) {
        _currentLanguage = languageCode;
        await _savePreferences();
        return true;
      }
      return false;
    } catch (e) {
      return false;
    }
  }

  // Set voice by ID
  Future<bool> setVoice(String voiceId) async {
    try {
      final result = await _flutterTts.setVoice({'id': voiceId});
      if (result == 1) {
        _currentVoice = voiceId;
        await _savePreferences();
        return true;
      }
      return false;
    } catch (e) {
      stateNotifier.value = TtsState.error;
      _lastError = TtsError.voiceUnavailable;
      return false;
    }
  }

  // Speak text
  Future<bool> speak(String text) async {
    if (text.isEmpty) return false;

    try {
      _currentContent = text;
      _currentProgress = 0;
      _progressBaseOffset = 0;
      final result = await _flutterTts.speak(text);
      if (result == 1) {
        stateNotifier.value = TtsState.playing;
        return true;
      }
      return false;
    } catch (e) {
      stateNotifier.value = TtsState.error;
      _lastError = TtsError.unknown;
      return false;
    }
  }

  // Update the cached content without triggering playback
  void updateContent(String text) {
    final trimmed = text.trim();
    if (trimmed.isEmpty) {
      _currentContent = null;
      _currentProgress = 0;
      _progressBaseOffset = 0;
    } else {
      if (_currentContent != trimmed) {
        _currentContent = trimmed;
        _currentProgress = 0;
        _progressBaseOffset = 0;
      }
    }
  }

  // Stop TTS and clean up
  Future<void> stop() async {
    try {
      await _flutterTts.stop();
      if (stateNotifier.value != TtsState.error) {
        stateNotifier.value = TtsState.stopped;
      }
      _currentContent = null;
      _currentProgress = 0;
      _progressBaseOffset = 0;
    } catch (e) {
      stateNotifier.value = TtsState.error;
      _lastError = TtsError.unknown;
    }
  }

  // Pause speaking
  Future<bool> pause() async {
    try {
      final result = await _flutterTts.pause();
      if (result == 1) {
        stateNotifier.value = TtsState.paused;
        return true;
      }
      _suppressCompletionUpdates = true;
      try {
        await _flutterTts.stop();
      } finally {
        _suppressCompletionUpdates = false;
      }
      stateNotifier.value = TtsState.paused;
      return true;
    } catch (e) {
      stateNotifier.value = TtsState.error;
      _lastError = TtsError.unknown;
      return false;
    }
  }

  // Resume speaking from where it was paused
  Future<bool> resume() async {
    if (_currentContent == null) return false;

    try {
      if (_currentProgress >= _currentContent!.length) {
        return false;
      }

      _suppressCompletionUpdates = true;
      try {
        await _flutterTts.stop();
      } finally {
        _suppressCompletionUpdates = false;
      }
      _progressBaseOffset = _currentProgress;
      final remaining = _currentContent!.substring(_currentProgress);
      final result = await _flutterTts.speak(remaining);
      if (result == 1) {
        stateNotifier.value = TtsState.playing;
        return true;
      }
      return false;
    } catch (e) {
      stateNotifier.value = TtsState.error;
      _lastError = TtsError.unknown;
      return false;
    }
  }

  // Toggle play/pause
  Future<void> togglePlayPause() async {
    if (isPlaying) {
      await pause();
    } else if (isPaused) {
      await resume();
    } else if (_currentContent != null) {
      // If stopped, start from beginning
      await speak(_currentContent!);
    }
  }

  // Get available voices
  Future<List<dynamic>> getVoices() async {
    try {
      return await _flutterTts.getVoices;
    } catch (e) {
      return [];
    }
  }

  // Get available languages
  Future<List<dynamic>> getLanguages() async {
    try {
      return await _flutterTts.getLanguages;
    } catch (e) {
      return [];
    }
  }

  // Dispose resources
  Future<void> dispose() async {
    await stop();
    // Set empty handlers to avoid memory leaks
    _flutterTts.setStartHandler(() {});
    _flutterTts.setCompletionHandler(() {});
    _flutterTts.setErrorHandler((_) {});
    _flutterTts.setProgressHandler((_, __, ___, ____) {});
    await _flutterTts.stop();
    stateNotifier.dispose();
  }
}
