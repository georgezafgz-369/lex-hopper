// ─────────────────────────────────────────────────────────────────────────────
// TRANSLATOR SERVICE — what translates English ↔ Greek text on the phone:
// the offline translator (OPUS-MT, opus_mt_service.dart) and, when it's
// turned on, the AI model (EuroLLM, eurollm_translator.dart). Both work
// without internet once downloaded.
// ─────────────────────────────────────────────────────────────────────────────

import 'package:flutter/foundation.dart' show debugPrint;

/// Translates text between the app's languages ("en", "el"). The page talks
/// to this, so tests can give it a fake one.
abstract class Translator {
  /// Whether the translator can translate now (its model is on the phone).
  Future<bool> isReady();

  /// Gets the translator ready: loads its model into memory.
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

/// Thrown when a newer translation took over before this one finished
/// (live typing moved on). Nothing to show for it, and not a failure.
class TranslationSuperseded implements Exception {
  const TranslationSuperseded();
}

/// Thrown when no translator is on the phone yet: the offline translator
/// isn't downloaded and the AI model is off or not downloaded. The page
/// says so; the dictionary and phrasebook still answer what they know.
class NoTranslatorYet implements Exception {
  const NoTranslatorYet();
}

/// The Translator the app uses. Engines in order, each used only when it's
/// ready, the next one taking over if it fails on a text:
/// 1. [offline]: the downloaded offline translator (OPUS-MT), the most
///    accurate (93.5% on the test set; data/benchmark/);
/// 2. [ai]: EuroLLM, when turned on in Settings and downloaded.
/// With neither, [translate] throws [NoTranslatorYet].
class PreferredTranslator implements Translator {
  final Translator? offline;
  final Translator ai;

  /// Whether the AI model is turned on (Settings), asked on every text.
  final bool Function() useAi;

  PreferredTranslator({required this.ai, required this.useAi, this.offline});

  Future<bool> _aiReady() async => useAi() && await ai.isReady();

  Future<bool> _offlineReady() async =>
      offline != null && await offline!.isReady();

  /// The engines that can translate now, best first.
  Future<List<(String, Translator)>> _ready() async => [
    if (await _offlineReady()) ('offline', offline!),
    if (await _aiReady()) ('AI', ai),
  ];

  /// Always true: there's nothing to fetch in the background (the models
  /// are downloaded from Settings); [translate] says when there's no engine.
  @override
  Future<bool> isReady() async => true;

  @override
  Future<void> prepare() => warmUp();

  /// Starts loading the best ready engine, so it's loaded by the time
  /// something is typed. A failure is ignored here: the translation itself
  /// tries again, or falls back to the next engine.
  Future<void> warmUp() async {
    final ready = await _ready();
    if (ready.isEmpty) return;
    final (name, engine) = ready.first;
    try {
      await engine.prepare();
    } catch (e) {
      debugPrint('Translator: $name did not load: $e');
    }
  }

  @override
  Future<String> translate(
    String text, {
    required String from,
    required String to,
  }) async {
    final ready = await _ready();
    if (ready.isEmpty) throw const NoTranslatorYet();
    Object? lastError;
    for (final (name, engine) in ready) {
      try {
        return await engine.translate(text, from: from, to: to);
      } on TranslationSuperseded {
        rethrow;
      } catch (e) {
        debugPrint('Translator: $name failed: $e');
        lastError = e;
      }
    }
    throw lastError!;
  }

  /// Nothing to free: the offline and AI models are shared by the whole
  /// app and stay loaded.
  @override
  Future<void> dispose() async {}
}
