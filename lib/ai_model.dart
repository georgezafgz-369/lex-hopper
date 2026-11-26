// ─────────────────────────────────────────────────────────────────────────────
// AI MODEL — a small AI that runs on the phone itself, through llama.cpp:
// it translates (the Translator's AI) and chats (Chat with AI). Two to
// choose from in Settings: EuroLLM-1.7B (about 1 GB, European languages,
// through llama.cpp) and Gemma 4 E2B (about 2.6 GB, smarter, Google's
// LiteRT-LM build; needs a phone with more memory).
//
// A model is not part of the app: it downloads once, when the person turns
// it on in Settings, and from then on works offline. Each model keeps one
// engine, so it loads into memory only once.
// ─────────────────────────────────────────────────────────────────────────────

import 'dart:async';
import 'dart:io';
import 'dart:math';

import 'package:llamadart/llamadart.dart';
import 'package:material_ui/material_ui.dart';

import 'app_settings.dart';
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

class AiModel implements Translator {
  AiModel._({
    required this.id,
    required this.name,
    required this.source,
    required this.sha256,
    required this.sizeMb,
    required this.minMemoryKb,
    this.device = ComputeDevice.auto,
  });

  /// EuroLLM-1.7B-Instruct, 4-bit (Q4_K_M). Each model is pinned to one
  /// commit and checked against its SHA-256, so a changed or broken file is
  /// never used.
  static final euroLlm = AiModel._(
    id: 'eurollm',
    name: 'EuroLLM',
    source: ModelSource.huggingFace(
      repoId: 'mradermacher/EuroLLM-1.7B-Instruct-GGUF',
      filePath: 'EuroLLM-1.7B-Instruct.Q4_K_M.gguf',
      revision: '2951f08f66429c934c8b01a94347161362430808',
    ),
    sha256: '1cade17f491ea46a686dbee51fbd52442e0f001f102380c3b9d66b4a77f84093',
    sizeMb: 1045,
    // With the app around it, about 2 GB: a phone with 4 GB of memory (which
    // reports a little under 4 GB).
    minMemoryKb: 3400 * 1024,
  );

  /// Google's Gemma 4 E2B (Apache 2.0), in Google's own phone build for
  /// its LiteRT-LM engine, run on the CPU. On a Pixel 8 it answers in about
  /// 5 s, 6–10 times faster than the same model through llama.cpp, and
  /// handles Greek better; on the GPU it was no faster and garbled Greek.
  static final gemma4 = AiModel._(
    id: 'gemma4',
    name: 'Gemma 4',
    source: ModelSource.huggingFace(
      repoId: 'litert-community/gemma-4-E2B-it-litert-lm',
      filePath: 'gemma-4-E2B-it.litertlm',
      revision: '2e12bfd869b2962984f97a1f2a26807316d534cc',
    ),
    sha256: '181938105e0eefd105961417e8da75903eacda102c4fce9ce90f50b97139a63c',
    sizeMb: 2590,
    device: ComputeDevice.cpu,
    // About 4.5 GB with the app: a phone with 6 GB of memory.
    minMemoryKb: 5400 * 1024,
  );

  /// Alibaba's Qwen 3.5 2B (Apache 2.0), many languages (Greek and
  /// Russian among them), in Google's phone build for LiteRT-LM like
  /// Gemma 4, on the CPU.
  static final qwen = AiModel._(
    id: 'qwen35',
    name: 'Qwen 3.5',
    source: ModelSource.huggingFace(
      repoId: 'litert-community/Qwen3.5-2B',
      filePath: 'Qwen3.5-2B_int8.litertlm',
      revision: 'ab919e9d348ec29deb9b5c3c9c559dd50a3a147d',
    ),
    sha256: 'c2438cb9c050220e667366b4beeca4daac56e693b226420674f53fc40f007c49',
    sizeMb: 2120,
    device: ComputeDevice.cpu,
    // About 3.8 GB with the app: a phone with 6 GB of memory.
    minMemoryKb: 4800 * 1024,
  );

  /// Qwen 3.5 0.8B, 4-bit (Q4_K_M) through llama.cpp: the smallest, for
  /// phones with little memory or space; simpler answers.
  static final qwenMini = AiModel._(
    id: 'qwen35mini',
    name: 'Qwen Mini',
    source: ModelSource.huggingFace(
      repoId: 'unsloth/Qwen3.5-0.8B-GGUF',
      filePath: 'Qwen3.5-0.8B-Q4_K_M.gguf',
      revision: '6ab461498e2023f6e3c1baea90a8f0fe38ab64d0',
    ),
    sha256: 'bd258782e35f7f458f8aced1adc053e6e92e89bc735ba3be89d38a06121dc517',
    sizeMb: 533,
    // About 1.2 GB with the app: a phone with 3 GB of memory.
    minMemoryKb: 2500 * 1024,
  );

  static final all = [euroLlm, gemma4, qwen, qwenMini];

  /// Models the app used before (Gemma 4's GGUF build, 3.4 GB): removed
  /// from the phone on start, so they don't keep taking space.
  static final _retired = [
    ModelSource.huggingFace(
      repoId: 'google/gemma-4-E2B-it-qat-q4_0-gguf',
      filePath: 'gemma-4-E2B_q4_0-it.gguf',
      revision: '675cff42a74c774d6cb76f76d8eacb49b48c9b93',
    ),
  ];

  static Future<void> removeRetired() async {
    final manager = DefaultModelDownloadManager();
    for (final source in _retired) {
      try {
        if (await manager.get(source.cacheKey) != null) {
          await manager.remove(source.cacheKey);
          debugPrint('AI: removed an old model (${source.cacheKey})');
        }
      } catch (_) {}
    }
  }

  /// The model picked in Settings.
  static AiModel get instance => all.firstWhere(
    (m) => m.id == AppSettings.instance.aiModel,
    orElse: () => euroLlm,
  );

  /// "eurollm", "gemma4", "qwen35" or "qwen35mini" (Settings keeps this).
  final String id;

  /// Its name, as shown in Settings.
  final String name;
  final ModelSource source;
  final String sha256;

  /// The download's size, for the person to see before starting it.
  final int sizeMb;

  /// The phone's memory needed to run it.
  final int minMemoryKb;

  /// Where it runs (CPU, GPU, or the engine's choice).
  final ComputeDevice device;

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

  /// Whether this phone has the memory to run the model (with less,
  /// Android stops the app). Android only for now; elsewhere it's assumed.
  Future<bool> hasEnoughMemory() async {
    final kb = await _phoneMemoryKb();
    return kb == null || kb >= minMemoryKb;
  }

  static Future<int?> _phoneMemoryKb() => _memoryKb ??= _readMemoryKb();
  static Future<int?>? _memoryKb;

  static Future<int?> _readMemoryKb() async {
    if (!Platform.isAndroid) return null;
    try {
      return memTotalKb(await File('/proc/meminfo').readAsString());
    } catch (_) {
      return null; // can't tell: don't block it
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
      debugPrint('$name: download stopped: $e');
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
      debugPrint('$name: could not delete: $e');
    }
    _set(ModelState.notDownloaded);
  }

  /// Loads the model into memory (about 15 s on a Pixel 8), so the first
  /// translation doesn't wait for it. The model is downloaded only from
  /// Settings, never as a side effect of this.
  @override
  Future<void> prepare() async {
    if (!await isReady()) throw StateError('$name is not downloaded');
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
        params: ModelParams(contextSize: 2048, device: device),
        download: ModelLoadOptions(cachePolicy: ModelCachePolicy.cacheOnly),
      );
      debugPrint('$name: loaded in ${clock.elapsedMilliseconds} ms');
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
        enableThinking: false,
      )) {
        out.write(chunk.text);
      }
      if (mine != _latest) throw const TranslationSuperseded();
      final answer = cleanTranslation(out.toString());
      debugPrint(
        '$name: translated ${text.length} characters in '
        '${clock.elapsedMilliseconds} ms',
      );
      // Nothing usable: the next translator takes over.
      if (!isInLanguage(answer, to) || isCopy(answer, text)) {
        throw StateError('$name gave no $to translation: "$answer"');
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
  /// for "el", Cyrillic for "ru", Latin for the rest. Catches the model
  /// copying the text instead of translating it, and empty answers.
  @visibleForTesting
  static bool isInLanguage(String answer, String language) {
    final greek = RegExp(r'[\u0370-\u03FF\u1F00-\u1FFF]').allMatches(answer);
    final cyrillic = RegExp(r'[\u0400-\u04FF]').allMatches(answer);
    final latin = RegExp('[A-Za-zÀ-ÿ]').allMatches(answer);
    final counts = {
      'el': greek.length,
      'ru': cyrillic.length,
      'latin': latin.length,
    };
    if (counts.values.every((n) => n == 0)) return false;
    final mine =
        counts[language == 'el' || language == 'ru' ? language : 'latin']!;
    return counts.values.every((n) => mine >= n);
  }

  /// Starts the model up before the first question (loading it, and for
  /// Gemma 4 its engine, which takes up to ~45 s the first time), so the
  /// first chat reply comes as fast as the rest. Done once.
  Future<void> warmUp() => _warm ??= () async {
    try {
      await for (final _ in chat(
        [(mine: true, text: 'Hi')],
        instructions: 'Reply with one word.',
        maxTokens: 1,
      )) {}
    } catch (e) {
      _warm = null; // try again next time
      debugPrint('$name: warm-up failed: $e');
    }
  }();
  Future<void>? _warm;

  /// A chat reply to [history] (oldest first; `mine` = the person's
  /// messages), following [instructions], arriving bit by bit. A new chat
  /// message or translation stops a reply still being written.
  Stream<String> chat(
    List<({bool mine, String text})> history, {
    required String instructions,
    int maxTokens = 400,
  }) async* {
    final mine = ++_latest;
    final engine = await _loaded();
    if (_generating) engine.cancelGeneration();
    final before = _idle;
    final done = Completer<void>();
    _idle = done.future;
    await before;
    try {
      if (mine != _latest) return;
      _generating = true;
      await for (final chunk in engine.create(
        [
          LlamaChatMessage.fromText(
            role: LlamaChatRole.system,
            text: instructions,
          ),
          for (final m in history)
            LlamaChatMessage.fromText(
              role: m.mine ? LlamaChatRole.user : LlamaChatRole.assistant,
              text: m.text,
            ),
        ],
        params: GenerationParams(maxTokens: maxTokens, temp: 0.7),
        // No hidden "thinking" before the answer (Gemma 4 thinks by
        // default): that made the learner wait for nothing to show.
        enableThinking: false,
      )) {
        if (mine != _latest) return;
        yield chunk.text;
      }
    } finally {
      _generating = false;
      done.complete();
    }
  }

  /// The model stays loaded for the whole app; pages don't dispose it.
  @override
  Future<void> dispose() async {}
}

class _Notifier extends ChangeNotifier {
  void ping() => notifyListeners();
}
