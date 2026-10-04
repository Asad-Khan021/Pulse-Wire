import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter_tts/flutter_tts.dart';

enum TtsPlaybackState {
  stopped,
  playing,
  paused,
  loading,
}

class TtsService {
  final FlutterTts _flutterTts = FlutterTts();
  final ValueNotifier<TtsPlaybackState> stateNotifier =
      ValueNotifier<TtsPlaybackState>(TtsPlaybackState.stopped);

  String? _currentlyPlayingText;

  TtsService() {
    _initTts();
  }

  Future<void> _initTts() async {
    await _flutterTts.setLanguage("en-US");
    await _flutterTts.setSpeechRate(0.5);
    await _flutterTts.setVolume(1.0);
    await _flutterTts.setPitch(1.0);

    _flutterTts.setStartHandler(() {
      stateNotifier.value = TtsPlaybackState.playing;
    });

    _flutterTts.setCompletionHandler(() {
      stateNotifier.value = TtsPlaybackState.stopped;
      _currentlyPlayingText = null;
    });

    _flutterTts.setCancelHandler(() {
      stateNotifier.value = TtsPlaybackState.stopped;
      _currentlyPlayingText = null;
    });

    _flutterTts.setPauseHandler(() {
      stateNotifier.value = TtsPlaybackState.paused;
    });

    _flutterTts.setContinueHandler(() {
      stateNotifier.value = TtsPlaybackState.playing;
    });

    _flutterTts.setErrorHandler((msg) {
      stateNotifier.value = TtsPlaybackState.stopped;
      _currentlyPlayingText = null;
    });
  }

  TtsPlaybackState get currentState => stateNotifier.value;
  bool get isPlaying => stateNotifier.value == TtsPlaybackState.playing;

  Future<void> speakBullets(List<String> bullets) async {
    if (bullets.isEmpty) return;
    final speechScript = bullets.asMap().entries.map((entry) {
      return "Point ${entry.key + 1}. ${entry.value}";
    }).join(". ");

    await speak(speechScript);
  }

  Future<void> speak(String text) async {
    if (text.trim().isEmpty) return;

    if (stateNotifier.value == TtsPlaybackState.paused &&
        _currentlyPlayingText == text) {
      await _flutterTts.speak(text);
      return;
    }

    stateNotifier.value = TtsPlaybackState.loading;
    _currentlyPlayingText = text;

    final result = await _flutterTts.speak(text);
    if (result == 1) {
      stateNotifier.value = TtsPlaybackState.playing;
    } else {
      stateNotifier.value = TtsPlaybackState.stopped;
    }
  }

  Future<void> pause() async {
    if (stateNotifier.value == TtsPlaybackState.playing) {
      await _flutterTts.pause();
      stateNotifier.value = TtsPlaybackState.paused;
    }
  }

  Future<void> stop() async {
    await _flutterTts.stop();
    stateNotifier.value = TtsPlaybackState.stopped;
    _currentlyPlayingText = null;
  }

  void dispose() {
    _flutterTts.stop();
    stateNotifier.dispose();
  }
}
