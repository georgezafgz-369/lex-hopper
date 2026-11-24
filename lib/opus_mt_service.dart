// ─────────────────────────────────────────────────────────────────────────────
// OFFLINE TRANSLATOR — the OPUS-MT models (Helsinki-NLP, CC-BY-4.0) for the
// whole app: downloading them once from Hugging Face (Settings), checking
// every file's SHA-256, and translating with them, without internet.
//
// What to download is in assets/opus-mt/manifest.json (written by
// scripts/opus_mt/upload_to_hf.py): the repository, the exact version
// (commit) to download from, and each file's path, size and SHA-256.
// ─────────────────────────────────────────────────────────────────────────────

import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:material_ui/material_ui.dart';
import 'package:path_provider/path_provider.dart';

import 'eurollm_translator.dart' show ModelState;
import 'opus_mt_translator.dart';
import 'translator_service.dart';

const opusMtManifestAsset = 'assets/opus-mt/manifest.json';

/// What to download: from where, and which files.
class OpusMtManifest {
  /// "user/repository" on Hugging Face; empty until uploaded.
  final String repo;

  /// The commit to download from, so the files never change under the app.
  final String revision;

  /// The folder in the repository holding the files.
  final String folder;
  final List<({String path, int bytes, String sha256})> files;

  const OpusMtManifest({
    required this.repo,
    required this.revision,
    required this.folder,
    required this.files,
  });

  factory OpusMtManifest.fromJson(Map<String, dynamic> j) => OpusMtManifest(
    repo: j['repo'] as String? ?? '',
    revision: j['revision'] as String? ?? '',
    folder: j['folder'] as String? ?? '',
    files: [
      for (final f in (j['files'] as List).cast<Map<String, dynamic>>())
        (
          path: f['path'] as String,
          bytes: f['bytes'] as int,
          sha256: f['sha256'] as String,
        ),
    ],
  );

  int get totalBytes => files.fold(0, (s, f) => s + f.bytes);

  /// The download's size in MB, for the person to see before starting it.
  int get sizeMb => (totalBytes / 1e6).round();

  bool get hosted => repo.isNotEmpty && revision.isNotEmpty;

  Uri url(String path) => Uri.parse(
    'https://huggingface.co/$repo/resolve/$revision/'
    '${folder.isEmpty ? '' : '$folder/'}$path',
  );
}

class OpusMtService implements Translator {
  /// [root]: the models folder; [manifest]: what to download; [urlOf]:
  /// where a file comes from. Tests give these; the app uses its own
  /// folder, the bundled manifest and Hugging Face.
  OpusMtService({
    Future<String> Function()? root,
    Future<OpusMtManifest> Function()? manifest,
    Uri Function(OpusMtManifest m, String path)? urlOf,
  }) : _rootOf = root ?? _appRoot,
       _manifestOf = manifest ?? _bundledManifest,
       _urlOf = urlOf ?? ((m, path) => m.url(path));

  /// The app's one service; tests may put their own in its place.
  static OpusMtService instance = OpusMtService();

  static Future<String> _appRoot() async =>
      '${(await getApplicationSupportDirectory()).path}/opus-mt';

  static Future<OpusMtManifest> _bundledManifest() async =>
      OpusMtManifest.fromJson(
        jsonDecode(await rootBundle.loadString(opusMtManifestAsset))
            as Map<String, dynamic>,
      );

  final Future<String> Function() _rootOf;
  final Future<OpusMtManifest> Function() _manifestOf;
  final Uri Function(OpusMtManifest, String) _urlOf;

  late final Future<String> _root = _rootOf();
  late final Future<OpusMtManifest> manifest = _manifestOf();
  OpusMtTranslator? _translator;

  Future<OpusMtTranslator> _engine() async {
    final root = await _root;
    return _translator ??= OpusMtTranslator((f, t) => '$root/$f-$t');
  }

  ModelState _state = ModelState.checking;
  ModelState get state => _state;

  /// 0–1 while downloading.
  double get progress => _progress;
  double _progress = 0;

  /// Tells Settings when [state] or [progress] change.
  Listenable get changes => _changes;
  final _changes = _Notifier();
  void _set(ModelState s) {
    _state = s;
    _changes.ping();
  }

  bool _cancelled = false;

  /// Every file is on the phone with the right size (checksums are checked
  /// when downloading, not on every start).
  @override
  Future<bool> isReady() async {
    try {
      final root = await _root;
      for (final f in (await manifest).files) {
        final file = File('$root/${f.path}');
        if (!await file.exists() || await file.length() != f.bytes) {
          return false;
        }
      }
      return true;
    } catch (e) {
      debugPrint('OPUS-MT: could not look for the models: $e');
      return false;
    }
  }

  /// Looks whether the models are on the phone (no download).
  Future<void> refresh() async {
    if (_state == ModelState.downloading) return;
    _set(await isReady() ? ModelState.ready : ModelState.notDownloaded);
  }

  /// Downloads the files that are missing, checking each one's SHA-256; a
  /// file that doesn't match is thrown away and the download fails. Files
  /// already there are kept, so a stopped download carries on.
  Future<void> download({HttpClient? client}) async {
    if (_state == ModelState.downloading) return;
    _cancelled = false;
    _progress = 0;
    _set(ModelState.downloading);
    final http = client ?? HttpClient();
    try {
      final m = await manifest;
      final root = await _root;
      var done = 0;
      var lastShown = 0.0;
      for (final f in m.files) {
        final file = File('$root/${f.path}');
        if (await file.exists() && await file.length() == f.bytes) {
          done += f.bytes;
          continue;
        }
        await file.parent.create(recursive: true);
        final part = File('${file.path}.part');
        final request = await http.getUrl(_urlOf(m, f.path));
        final response = await request.close();
        if (response.statusCode != 200) {
          throw HttpException('HTTP ${response.statusCode} for ${f.path}');
        }
        final sink = part.openWrite();
        final digest = _DigestSink();
        final hasher = sha256.startChunkedConversion(digest);
        try {
          await for (final chunk in response) {
            if (_cancelled) throw const _Cancelled();
            sink.add(chunk);
            hasher.add(chunk);
            done += chunk.length;
            _progress = done / m.totalBytes;
            if (_progress - lastShown >= 0.01) {
              lastShown = _progress;
              _changes.ping();
            }
          }
        } finally {
          await sink.close();
        }
        hasher.close();
        if (digest.value.toString() != f.sha256) {
          await part.delete();
          throw StateError('${f.path} is damaged (checksum)');
        }
        await part.rename(file.path);
      }
      _set(ModelState.ready);
    } catch (e) {
      debugPrint('OPUS-MT: download stopped: $e');
      _set(e is _Cancelled ? ModelState.notDownloaded : ModelState.failed);
    } finally {
      if (client == null) http.close();
    }
  }

  /// The translator is part of the app, not a choice: downloads it if it
  /// isn't on the phone yet (on every start, and again from the translator
  /// page after a failed try). Does nothing while a download is running.
  Future<void> ensure() async {
    if (_state == ModelState.downloading) return;
    if (await isReady()) {
      _set(ModelState.ready);
      return;
    }
    await download();
  }

  void cancelDownload() => _cancelled = true;

  /// Removes the models from the phone.
  Future<void> deleteModels() async {
    cancelDownload();
    await _translator?.dispose();
    _translator = null;
    final dir = Directory(await _root);
    if (await dir.exists()) await dir.delete(recursive: true);
    _set(ModelState.notDownloaded);
  }

  /// Loads both directions into memory (about 2 s on a Pixel 8).
  @override
  Future<void> prepare() async => (await _engine()).prepare();

  @override
  Future<String> translate(
    String text, {
    required String from,
    required String to,
  }) async => (await _engine()).translate(text, from: from, to: to);

  /// The models stay loaded for the whole app; pages don't dispose them.
  @override
  Future<void> dispose() async {}
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

class _Notifier extends ChangeNotifier {
  void ping() => notifyListeners();
}
