// ─────────────────────────────────────────────────────────────────────────────
// LANGUAGE PACKS — the languages you download on request (Spanish, German):
// each is one download, its dictionary and its offline translator to and
// from English, fetched from Hugging Face and checked against their SHA-256.
// English and Greek are built in and aren't packs.
//
// What to download is in assets/language_packs.json (written by
// scripts/upload_language_pack.py). A language listed there with nothing
// hosted yet shows as "Coming soon".
// ─────────────────────────────────────────────────────────────────────────────

import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:material_ui/material_ui.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import 'dictionary_service.dart';
import 'eurollm_translator.dart' show ModelState;
import 'opus_mt_service.dart';

/// One language's download.
class LanguagePack {
  final String code;

  /// The dictionary: one gzipped database, named on the phone after its
  /// fingerprint (so a new version is fetched again by itself).
  final String repo, repoType, revision, path, sha256, fingerprint;
  final int gzBytes, bytes;

  /// The offline translator to and from English.
  final OpusMtManifest translator;

  const LanguagePack({
    required this.code,
    required this.repo,
    required this.repoType,
    required this.revision,
    required this.path,
    required this.sha256,
    required this.fingerprint,
    required this.gzBytes,
    required this.bytes,
    required this.translator,
  });

  factory LanguagePack.fromJson(String code, Map<String, dynamic> j) {
    final d = j['dictionary'] as Map<String, dynamic>;
    return LanguagePack(
      code: code,
      repo: d['repo'] as String,
      repoType: d['repo_type'] as String? ?? 'dataset',
      revision: d['revision'] as String,
      path: d['path'] as String,
      sha256: d['sha256'] as String,
      fingerprint: d['fingerprint'] as String,
      gzBytes: d['gz_bytes'] as int,
      bytes: d['bytes'] as int,
      translator: OpusMtManifest.fromJson(
        j['translator'] as Map<String, dynamic>,
      ),
    );
  }

  /// The download's size in MB, shown before it starts.
  int get sizeMb => ((gzBytes + translator.totalBytes) / 1e6).round();

  Uri get dictionaryUrl => Uri.parse(
    'https://huggingface.co/${repoType == 'dataset' ? 'datasets/' : ''}'
    '$repo/resolve/$revision/$path',
  );

  /// The dictionary's name on the phone, e.g. `pack_es_1a2b3c4d5e6f.db`.
  String get localName => 'pack_${code}_$fingerprint.db';
}

enum PackState { notInstalled, downloading, installed, failed }

class LanguagePacks extends ChangeNotifier {
  /// [dictionaryDir] / [translatorRoot]: where the parts go; [manifest]:
  /// what can be downloaded; [urlOf]: where a dictionary comes from. Tests
  /// give these.
  LanguagePacks({
    Future<String> Function()? dictionaryDir,
    Future<String> Function()? translatorRoot,
    Future<Map<String, LanguagePack>> Function()? manifest,
    Uri Function(LanguagePack pack)? urlOf,
    this.translatorUrlOf,
  }) : _dictionaryDirOf = dictionaryDir ?? DictionaryService.databaseDir,
       _translatorRootOf = translatorRoot ?? _appTranslatorRoot,
       _manifestOf = manifest ?? _bundledManifest,
       _urlOf = urlOf ?? ((pack) => pack.dictionaryUrl);

  /// The app's one manager; tests may put their own in its place.
  static LanguagePacks instance = LanguagePacks();

  static const manifestAsset = 'assets/language_packs.json';

  /// The languages that come with the app (not packs).
  static const builtIn = {'en', 'el'};

  static Future<String> _appTranslatorRoot() async =>
      '${(await getApplicationSupportDirectory()).path}/opus-mt';

  static Future<Map<String, LanguagePack>> _bundledManifest() async {
    final j =
        jsonDecode(await rootBundle.loadString(manifestAsset))
            as Map<String, dynamic>;
    return {
      for (final MapEntry(:key, :value) in j.entries)
        if (value is Map<String, dynamic> && value['dictionary'] != null)
          key: LanguagePack.fromJson(key, value),
    };
  }

  final Future<String> Function() _dictionaryDirOf, _translatorRootOf;
  final Future<Map<String, LanguagePack>> Function() _manifestOf;
  final Uri Function(LanguagePack) _urlOf;
  /// Where a translator file comes from (tests); Hugging Face otherwise.
  final Uri Function(OpusMtManifest m, String path)? translatorUrlOf;

  Map<String, LanguagePack> _packs = const {};
  String _dictionaryDir = '';
  final Map<String, PackState> _states = {};
  final Map<String, double> _progress = {};
  final Set<String> _cancelled = {};
  Future<void>? _loading;

  /// Reads what can be downloaded and what is already on the phone. Safe
  /// to call more than once.
  Future<void> load() => _loading ??= () async {
    try {
      _packs = await _manifestOf();
      _dictionaryDir = await _dictionaryDirOf();
      for (final pack in _packs.values) {
        _states[pack.code] = await _onPhone(pack)
            ? PackState.installed
            : PackState.notInstalled;
      }
    } catch (e) {
      debugPrint('Language packs: could not look for them: $e');
    }
    notifyListeners();
  }();

  /// Whether [code] can be downloaded (it's hosted).
  bool offers(String code) => _packs.containsKey(code);

  PackState state(String code) => _states[code] ?? PackState.notInstalled;

  bool isInstalled(String code) => state(code) == PackState.installed;

  /// 0–1 while downloading.
  double progress(String code) => _progress[code] ?? 0;

  int sizeMb(String code) => _packs[code]?.sizeMb ?? 0;

  /// The downloaded dictionary of [code], or null.
  String? dictionaryPath(String code) {
    final pack = _packs[code];
    if (pack == null || !isInstalled(code)) return null;
    return p.join(_dictionaryDir, pack.localName);
  }

  OpusMtService _translator(LanguagePack pack) => OpusMtService(
    root: _translatorRootOf,
    manifest: () async => pack.translator,
    urlOf: translatorUrlOf,
  );

  Future<bool> _onPhone(LanguagePack pack) async {
    final file = File(p.join(_dictionaryDir, pack.localName));
    if (!await file.exists() || await file.length() != pack.bytes) {
      return false;
    }
    return _translator(pack).isReady();
  }

  void _set(String code, PackState s) {
    _states[code] = s;
    notifyListeners();
  }

  /// Downloads [code]: the dictionary, then the translator. A stopped
  /// download carries on from the parts already there.
  Future<void> download(String code) async {
    await load();
    final pack = _packs[code];
    if (pack == null || state(code) == PackState.downloading) return;
    _cancelled.remove(code);
    _progress[code] = 0;
    _set(code, PackState.downloading);
    final total = pack.gzBytes + pack.translator.totalBytes;
    try {
      await _downloadDictionary(pack, (done) {
        _progress[code] = done / total;
        notifyListeners();
      });
      final translator = _translator(pack);
      void moved() {
        _progress[code] =
            (pack.gzBytes + translator.progress * pack.translator.totalBytes) /
            total;
        notifyListeners();
      }

      translator.changes.addListener(moved);
      try {
        final cancel = Timer.periodic(const Duration(milliseconds: 300), (_) {
          if (_cancelled.contains(code)) translator.cancelDownload();
        });
        await translator.download();
        cancel.cancel();
      } finally {
        translator.changes.removeListener(moved);
      }
      if (_cancelled.contains(code)) {
        _set(code, PackState.notInstalled);
      } else {
        _set(
          code,
          translator.state == ModelState.ready
              ? PackState.installed
              : PackState.failed,
        );
      }
    } catch (e) {
      debugPrint('Language packs: $code stopped: $e');
      _set(
        code,
        _cancelled.contains(code) ? PackState.notInstalled : PackState.failed,
      );
    }
  }

  void cancel(String code) => _cancelled.add(code);

  Future<void> _downloadDictionary(
    LanguagePack pack,
    void Function(int done) onBytes,
  ) async {
    final file = File(p.join(_dictionaryDir, pack.localName));
    if (await file.exists() && await file.length() == pack.bytes) {
      onBytes(pack.gzBytes);
      return;
    }
    await Directory(_dictionaryDir).create(recursive: true);
    // Older versions of this language's dictionary go first.
    await for (final f in Directory(_dictionaryDir).list()) {
      final name = p.basename(f.path);
      if (f is File && name.startsWith('pack_${pack.code}_')) await f.delete();
    }
    final part = File('${file.path}.part');
    final http = HttpClient();
    try {
      final response = await (await http.getUrl(_urlOf(pack))).close();
      if (response.statusCode != 200) {
        throw HttpException('HTTP ${response.statusCode} for ${pack.path}');
      }
      final digest = _DigestSink();
      final hasher = sha256.startChunkedConversion(digest);
      var done = 0;
      final counted = response.map((chunk) {
        if (_cancelled.contains(pack.code)) throw const _Cancelled();
        hasher.add(chunk);
        done += chunk.length;
        onBytes(done);
        return chunk;
      });
      await counted.transform(gzip.decoder).pipe(part.openWrite());
      hasher.close();
      if (digest.value.toString() != pack.sha256 ||
          await part.length() != pack.bytes) {
        await part.delete();
        throw StateError('${pack.path} is damaged (checksum)');
      }
      await part.rename(file.path);
    } finally {
      http.close();
    }
  }

  /// Removes [code] from the phone: its dictionary and its translator.
  Future<void> delete(String code) async {
    final pack = _packs[code];
    if (pack == null) return;
    cancel(code);
    final file = File(p.join(_dictionaryDir, pack.localName));
    if (await file.exists()) await file.delete();
    final root = await _translatorRootOf();
    for (final f in pack.translator.files) {
      final file = File('$root/${f.path}');
      if (await file.exists()) await file.delete();
    }
    _set(code, PackState.notInstalled);
  }
}

class _Cancelled implements Exception {
  const _Cancelled();
}

/// Receives the SHA-256 once all the bytes are in.
class _DigestSink implements Sink<Digest> {
  late Digest value;
  @override
  void add(Digest data) => value = data;
  @override
  void close() {}
}
