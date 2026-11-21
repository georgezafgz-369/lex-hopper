// ─────────────────────────────────────────────────────────────────────────────
// SPEECH — says words aloud with the phone's own text-to-speech voice
// ─────────────────────────────────────────────────────────────────────────────

import 'package:flutter/foundation.dart' show debugPrint;
import 'package:flutter_tts/flutter_tts.dart';

enum Accent {
  american('en-US', 'US'),
  british('en-GB', 'UK'),
  greek('el-GR', 'ΕΛ');

  /// The voices offered for a dictionary language ("en" or "el").
  static List<Accent> forLanguage(String code) =>
      code == 'el' ? const [greek] : const [american, british];

  final String locale;
  final String label;
  const Accent(this.locale, this.label);
}

class Speech {
  Speech._();
  static final Speech instance = Speech._();

  final FlutterTts _tts = FlutterTts();
  bool _ready = false;

  Future<void> _init() async {
    if (_ready) return;
    await _tts.setSpeechRate(0.42); // a little slower than normal speech
    await _tts.setPitch(1.0);
    await _tts.awaitSpeakCompletion(false);
    _ready = true;
  }

  /// Says [text] in [accent]. Returns false if the phone has no voice for
  /// that accent (the caller can tell the user).
  Future<bool> say(String text, Accent accent) async {
    try {
      await _init();
      final available = await _tts.isLanguageAvailable(accent.locale);
      if (available != true) return false;
      await _tts.stop();
      await _tts.setLanguage(accent.locale);
      final result = await _tts.speak(text);
      return result == 1 || result == true;
    } catch (e) {
      debugPrint('Speech error: $e');
      return false;
    }
  }
}
