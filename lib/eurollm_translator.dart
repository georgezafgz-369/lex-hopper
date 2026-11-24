// ─────────────────────────────────────────────────────────────────────────────
// EUROLLM TRANSLATOR — a small AI model (EuroLLM-1.7B-Instruct) that
// translates English ↔ Greek on the phone itself, through llama.cpp.
//
// The model (about 1 GB) is not part of the app: it downloads once, when the
// person turns it on in Settings, and from then on works offline. One engine
// serves the whole app, so the model loads into memory only once.
// ─────────────────────────────────────────────────────────────────────────────

import 'dart:async';
import 'dart:io';
import 'dart:math';

import 'package:llamadart/llamadart.dart';
import 'package:material_ui/material_ui.dart';

import 'translator_service.dart';

/// Where the EuroLLM download is at, for Settings to show.
enum ModelState {
  checking,
  notDownloaded,
  downloading,
  ready,
  failed,

  /// The phone has too little memory to run the model.
  tooLittleMemory,
}

class EuroLlmTranslator implements Translator {
  EuroLlmTranslator._();
  static final EuroLlmTranslator instance = EuroLlmTranslator._();

  /// EuroLLM-1.7B-Instruct, 4-bit (Q4_K_M), pinned to one commit and checked
  /// against its SHA-256 so a changed or broken file is never used.
  static final source = ModelSource.huggingFace(
    repoId: 'mradermacher/EuroLLM-1.7B-Instruct-GGUF',
    filePath: 'EuroLLM-1.7B-Instruct.Q4_K_M.gguf',
    revision: '2951f08f66429c934c8b01a94347161362430808',
  );
  static const sha256 =
      '1cade17f491ea46a686dbee51fbd52442e0f001f102380c3b9d66b4a77f84093';

  /// The download's size, for the person to see before starting it.
  static const sizeMb = 1045;

  final _manager = DefaultModelDownloadManager();

  ModelState _state = ModelState.checking;
  ModelState get state => _state;

  /// 0–1 while downloading; null when the size isn't known yet.
  double? get progress => _progress;
  double? _progress;

  /// Tells Settings when [state] or [progress] change.
  Listenable get changes => _changes;
  final _changes = _Notifier();

  ModelDownloadCancelToken? _cancel;
  Future<LlamaEngine>? _engine;

  void _set(ModelState state) {
    _state = state;
    _changes.ping();
  }

  /// Looks whether the model is on the phone already (no download).
  Future<void> refresh() async {
    if (_state == ModelState.downloading) return;
    if (!await hasEnoughMemory()) return _set(ModelState.tooLittleMemory);
    _set(await isReady() ? ModelState.ready : ModelState.notDownloaded);
  }

  /// The model with the app around it takes about 2 GB, so it needs a phone
  /// with 4 GB of memory; with less, Android stops the app. (A "4 GB" phone
  /// reports a little under 4 GB.)
  static const minMemoryKb = 3400 * 1024;

  /// Whether this phone has the memory to run the model. Android only for
  /// now; elsewhere it's assumed.
  static Future<bool> hasEnoughMemory() async =>
      _enoughMemory ??= await _readEnoughMemory();
  static bool? _enoughMemory;

  static Future<bool> _readEnoughMemory() async {
    if (!Platform.isAndroid) return true;
    try {
      final kb = memTotalKb(await File('/proc/meminfo').readAsString());
      return kb == null || kb >= minMemoryKb;
    } catch (_) {
      return true; // can't tell: don't block it
    }
  }

  /// "MemTotal:  3809000 kB" from /proc/meminfo, in kB.
  @visibleForTesting
  static int? memTotalKb(String meminfo) {
    final m = RegExp(
      r'^MemTotal:\s+(\d+)\s+kB',
      multiLine: true,
    ).firstMatch(meminfo);
    return m == null ? null : int.parse(m.group(1)!);
  }

  /// Downloaded, and the phone can run it.
  @override
  Future<bool> isReady() async {
    if (!await hasEnoughMemory()) return false;
    try {
      return await _manager.get(source.cacheKey) != null;
    } catch (_) {
      return false;
    }
  }

  /// Downloads the model; [progress] and [state] follow along. Downloads
  /// only once: a model already on the phone is ready straight away, and an
  /// interrupted download carries on where it stopped.
  Future<void> download() async {
    if (_state == ModelState.downloading) return;
    final cancel = _cancel = ModelDownloadCancelToken();
    _progress = null;
    _set(ModelState.downloading);
    var lastShown = -1.0;
    try {
      await _manager.ensureModel(
        source,
        options: ModelLoadOptions(sha256: sha256, cancelToken: cancel),
        onProgress: (p) {
          _progress = p.fraction;
          // Repaint every 1%, not on every chunk of bytes.
          final f = p.fraction ?? 0;
          if (f - lastShown >= 0.01) {
            lastShown = f;
            _changes.ping();
          }
        },
      );
      _set(ModelState.ready);
    } catch (e) {
      debugPrint('EuroLLM: download stopped: $e');
      _set(cancel.isCancelled ? ModelState.notDownloaded : ModelState.failed);
    } finally {
      if (identical(_cancel, cancel)) _cancel = null;
    }
  }

  /// Stops a download in progress; what's there so far is kept for next
  /// time.
  void cancelDownload() => _cancel?.cancel();

  /// Removes the model from the phone (frees about 1 GB).
  Future<void> deleteModel() async {
    cancelDownload();
    await _unload();
    try {
      await _manager.remove(source.cacheKey);
    } catch (e) {
      debugPrint('EuroLLM: could not delete: $e');
    }
    _set(ModelState.notDownloaded);
  }

  /// Loads the model into memory (about 15 s on a Pixel 8), so the first
  /// translation doesn't wait for it. The model is downloaded only from
  /// Settings, never as a side effect of this.
  @override
  Future<void> prepare() async {
    if (!await isReady()) throw StateError('EuroLLM is not downloaded');
    await _loaded();
  }

  /// Loads the model into memory the first time it's needed.
  Future<LlamaEngine> _loaded() => _engine ??= () async {
    final engine = LlamaEngine(LlamaBackend(), modelDownloadManager: _manager);
    final clock = Stopwatch()..start();
    try {
      await engine.setModel(
        LlamaModel(source),
        // Room for a paragraph and its translation.
        params: const ModelParams(contextSize: 2048),
        download: ModelLoadOptions(cachePolicy: ModelCachePolicy.cacheOnly),
      );
      debugPrint('EuroLLM: loaded in ${clock.elapsedMilliseconds} ms');
      return engine;
    } catch (_) {
      _engine = null; // try again next time
      unawaited(engine.dispose());
      rethrow;
    }
  }();

  Future<void> _unload() async {
    final engine = _engine;
    _engine = null;
    if (engine == null) return;
    try {
      final e = await engine;
      e.cancelGeneration();
      await e.dispose();
    } catch (_) {}
  }

  /// One translation runs at a time. A new one stops the one running (live
  /// typing has moved on) and older ones still waiting give up.
  Future<void> _idle = Future.value();
  int _latest = 0;
  bool _generating = false;

  static const _names = {'en': 'English', 'el': 'Greek'};

  @override
  Future<String> translate(
    String text, {
    required String from,
    required String to,
  }) async {
    if (text.trim().isEmpty || from == to) return text;
    final mine = ++_latest;
    final engine = await _loaded();
    if (_generating) engine.cancelGeneration();
    final before = _idle;
    final done = Completer<void>();
    _idle = done.future;
    await before;
    try {
      if (mine != _latest) throw const TranslationSuperseded();
      _generating = true;
      final clock = Stopwatch()..start();
      final out = StringBuffer();
      await for (final chunk in engine.create(
        [
          LlamaChatMessage.fromText(
            role: LlamaChatRole.user,
            text: translationPrompt(text, from: from, to: to),
          ),
        ],
        params: GenerationParams(
          // A translation is about as long as its text; Greek a bit longer.
          maxTokens: min(768, 32 + text.length),
          // Always the most likely words: the same text, the same answer.
          temp: 0,
          topK: 1,
          penalty: 1.0,
        ),
      )) {
        out.write(chunk.text);
      }
      if (mine != _latest) throw const TranslationSuperseded();
      final answer = cleanTranslation(out.toString());
      debugPrint(
        'EuroLLM: translated ${text.length} characters in '
        '${clock.elapsedMilliseconds} ms',
      );
      // Nothing usable: the next translator takes over.
      if (!isInLanguage(answer, to) || isCopy(answer, text)) {
        throw StateError('EuroLLM gave no $to translation: "$answer"');
      }
      return answer;
    } finally {
      _generating = false;
      done.complete();
    }
  }

  /// What EuroLLM is asked. (The model card's "Greek: … English: " form
  /// made it repeat greetings instead of translating them; this one
  /// translated every test sentence, both ways.)
  @visibleForTesting
  static String translationPrompt(
    String text, {
    required String from,
    required String to,
  }) {
    final source = _names[from]!, target = _names[to]!;
    return 'Translate this $source text into $target. '
        'Reply with the translation only.\n\n$text';
  }

  /// Labels the model sometimes puts before its answer ("Greek:",
  /// "Απάντηση:").
  static final _label = RegExp(
    r'^(english|greek|translation|answer|αγγλικά|ελληνικά|μετάφραση|'
    r'απάντηση)\s*:\s*',
    caseSensitive: false,
    unicode: true,
  );

  /// The model's answer: its first line, without chat markers or a label.
  /// (The text to translate arrives on one line, so its translation is the
  /// first line; the model may start with an empty one.)
  @visibleForTesting
  static String cleanTranslation(String raw) {
    final line = raw
        .replaceAll('<|im_end|>', '')
        .split('\n')
        .map((l) => l.trim())
        .firstWhere((l) => l.isNotEmpty, orElse: () => '');
    var s = line, before = '';
    while (s != before) {
      before = s;
      s = s.replaceFirst(_label, '');
    }
    return s;
  }

  /// Whether [answer] just repeats [text] (ignoring case, accents,
  /// spacing and punctuation) instead of translating it.
  static bool isCopy(String answer, String text) {
    String bare(String s) => s
        .toLowerCase()
        .replaceAll(RegExp('[άὰᾶ]'), 'α')
        .replaceAll(RegExp('[έὲ]'), 'ε')
        .replaceAll(RegExp('[ήὴῆ]'), 'η')
        .replaceAll(RegExp('[ίὶῖϊΐ]'), 'ι')
        .replaceAll(RegExp('[όὸ]'), 'ο')
        .replaceAll(RegExp('[ύὺῦϋΰ]'), 'υ')
        .replaceAll(RegExp('[ώὼῶ]'), 'ω')
        .replaceAll(RegExp(r'[^\p{L}\p{N}]', unicode: true), '');
    final a = bare(answer);
    return a.isNotEmpty && a == bare(text);
  }

  /// Whether [answer] is written in [language]'s alphabet: Greek letters
  /// for "el", Latin ones for "en". Catches the model copying the text
  /// instead of translating it, and empty answers.
  @visibleForTesting
  static bool isInLanguage(String answer, String language) {
    final greek = RegExp(r'[\u0370-\u03FF\u1F00-\u1FFF]').allMatches(answer);
    final latin = RegExp('[A-Za-z]').allMatches(answer);
    if (greek.isEmpty && latin.isEmpty) return false;
    return language == 'el'
        ? greek.length >= latin.length
        : latin.length >= greek.length;
  }

  /// The model stays loaded for the whole app; pages don't dispose it.
  @override
  Future<void> dispose() async {}
}

class _Notifier extends ChangeNotifier {
  void ping() => notifyListeners();
}
