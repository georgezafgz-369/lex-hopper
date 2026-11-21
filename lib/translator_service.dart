// ─────────────────────────────────────────────────────────────────────────────
// TRANSLATOR SERVICE — English ↔ Greek translation on the phone itself
// (Google ML Kit). Free, private, and offline once the Greek model (about
// 30 MB, English is built in) has been downloaded the first time.
// ─────────────────────────────────────────────────────────────────────────────

import 'package:google_mlkit_translation/google_mlkit_translation.dart';

/// Translates text between the app's languages ("en", "el"). The page talks
/// to this, so tests can give it a fake one.
abstract class Translator {
  /// Whether the language models are on the phone already.
  Future<bool> isReady();

  /// Downloads the language models (once; over any network).
  Future<void> prepare();

  /// [text] in language [from] ("en"/"el"), translated into [to].
  Future<String> translate(
    String text, {
    required String from,
    required String to,
  });

  /// Frees what the translator holds.
  Future<void> dispose();
}

class OnDeviceTranslatorService implements Translator {
  final _models = OnDeviceTranslatorModelManager();
  final Map<String, OnDeviceTranslator> _translators = {};

  static TranslateLanguage _language(String code) =>
      code == 'el' ? TranslateLanguage.greek : TranslateLanguage.english;

  static final _needed = [TranslateLanguage.english, TranslateLanguage.greek];

  @override
  Future<bool> isReady() async {
    for (final l in _needed) {
      if (!await _models.isModelDownloaded(l.bcpCode)) return false;
    }
    return true;
  }

  @override
  Future<void> prepare() async {
    for (final l in _needed) {
      if (await _models.isModelDownloaded(l.bcpCode)) continue;
      final ok = await _models.downloadModel(l.bcpCode, isWifiRequired: false);
      if (!ok) throw StateError('Could not download the ${l.name} model');
    }
  }

  @override
  Future<String> translate(
    String text, {
    required String from,
    required String to,
  }) async {
    if (text.trim().isEmpty || from == to) return text;
    final translator = _translators.putIfAbsent(
      '$from>$to',
      () => OnDeviceTranslator(
        sourceLanguage: _language(from),
        targetLanguage: _language(to),
      ),
    );
    return translator.translateText(text);
  }

  @override
  Future<void> dispose() async {
    for (final t in _translators.values) {
      await t.close();
    }
    _translators.clear();
  }
}
