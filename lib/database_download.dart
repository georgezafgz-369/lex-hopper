// ─────────────────────────────────────────────────────────────────────────────
// DATABASE DOWNLOAD — the app's two databases (lexicon.db, texts.db) are
// downloaded once, on first launch, from Hugging Face (about 63 MB,
// gzipped), checked against their SHA-256 and unpacked into the app's
// folder. After that everything works without internet.
//
// What to download is in assets/databases.json (scripts/upload_databases.py):
// each database's fingerprint (its copy on the phone is named after it, so a
// new version is fetched again by itself), the repository, the commit to
// download from, and each file's sizes and SHA-256.
// ─────────────────────────────────────────────────────────────────────────────

import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:material_ui/material_ui.dart';
import 'package:path/path.dart' as p;

/// One database to download.
typedef DatabaseFile = ({
  String name, // "lexicon" or "texts"
  String fingerprint,
  String path, // in the repository
  int gzBytes,
  String sha256,
  int bytes, // unpacked
});

/// What to download: from where, and which files.
class DatabaseManifest {
  final String repo, repoType, revision;
  final List<DatabaseFile> files;

  const DatabaseManifest({
    required this.repo,
    required this.repoType,
    required this.revision,
    required this.files,
  });

  factory DatabaseManifest.fromJson(Map<String, dynamic> j) {
    final files = (j['files'] as Map<String, dynamic>? ?? const {});
    return DatabaseManifest(
      repo: j['repo'] as String? ?? '',
      repoType: j['repo_type'] as String? ?? 'dataset',
      revision: j['revision'] as String? ?? '',
      files: [
        for (final name in const ['lexicon', 'texts'])
          if (files[name] case final Map<String, dynamic> f)
            (
              name: name,
              fingerprint: j[name] as String,
              path: f['path'] as String,
              gzBytes: f['gz_bytes'] as int,
              sha256: f['sha256'] as String,
              bytes: f['bytes'] as int,
            ),
      ],
    );
  }

  int get totalGzBytes => files.fold(0, (s, f) => s + f.gzBytes);

  /// The download's size in MB, shown before it starts.
  int get sizeMb => (totalGzBytes / 1e6).round();

  bool get hosted =>
      repo.isNotEmpty && revision.isNotEmpty && files.length == 2;

  Uri url(String path) => Uri.parse(
    'https://huggingface.co/${repoType == 'dataset' ? 'datasets/' : ''}'
    '$repo/resolve/$revision/$path',
  );

  /// The copy's name on the phone, e.g. `lexicon_e0eb169ae784.db`.
  static String localName(DatabaseFile f) => '${f.name}_${f.fingerprint}.db';
}

enum DatabaseState { checking, downloading, ready, failed }

class DatabaseDownload {
  /// [dir]: where the databases go; [manifest]: what to download; [urlOf]:
  /// where a file comes from. Tests give these.
  DatabaseDownload({
    required Future<String> Function() dir,
    Future<DatabaseManifest> Function()? manifest,
    Uri Function(DatabaseManifest m, String path)? urlOf,
  }) : _dirOf = dir,
       _manifestOf = manifest ?? _bundledManifest,
       _urlOf = urlOf ?? ((m, path) => m.url(path));

  static const manifestAsset = 'assets/databases.json';

  static Future<DatabaseManifest> _bundledManifest() async =>
      DatabaseManifest.fromJson(
        jsonDecode(await rootBundle.loadString(manifestAsset))
            as Map<String, dynamic>,
      );

  final Future<String> Function() _dirOf;
  final Future<DatabaseManifest> Function() _manifestOf;
  final Uri Function(DatabaseManifest, String) _urlOf;
  late final Future<DatabaseManifest> manifest = _manifestOf();

  DatabaseState _state = DatabaseState.checking;
  DatabaseState get state => _state;

  /// 0–1 while downloading.
  double get progress => _progress;
  double _progress = 0;

  /// Tells the first-launch screen when [state] or [progress] change.
  Listenable get changes => _changes;
  final _changes = _Notifier();
  void _set(DatabaseState s) {
    _state = s;
    _changes.ping();
  }

  /// For tests: as if the databases were already on the phone.
  @visibleForTesting
  void markReady() => _set(DatabaseState.ready);

  Future<(String, String)>? _getting;

  /// The paths of lexicon.db and texts.db on the phone, downloading them
  /// first if they aren't there. Concurrent callers share one download; a
  /// failed one is tried again on the next call.
  Future<(String, String)> ensure() {
    final running = _getting ??= _ensure();
    running.catchError((Object _) {
      if (identical(_getting, running)) _getting = null;
      return ('', '');
    });
    return running;
  }

  Future<(String, String)> _ensure() async {
    try {
      final m = await manifest;
      final dir = await _dirOf();
      await Directory(dir).create(recursive: true);
      await _removeOldCopies(dir, m);
      final missing = <DatabaseFile>[];
      for (final f in m.files) {
        final file = File(p.join(dir, DatabaseManifest.localName(f)));
        if (!await file.exists() || await file.length() != f.bytes) {
          missing.add(f);
        }
      }
      if (missing.isNotEmpty) {
        if (!m.hosted) throw StateError('No databases to download from');
        _progress = 0;
        _set(DatabaseState.downloading);
        await _download(dir, m, missing);
      }
      _set(DatabaseState.ready);
      String path(String name) => p.join(
        dir,
        DatabaseManifest.localName(m.files.firstWhere((f) => f.name == name)),
      );
      return (path('lexicon'), path('texts'));
    } catch (e) {
      debugPrint('Databases: download stopped: $e');
      _set(DatabaseState.failed);
      rethrow;
    }
  }

  Future<void> _download(
    String dir,
    DatabaseManifest m,
    List<DatabaseFile> files,
  ) async {
    final http = HttpClient();
    final total = files.fold(0, (s, f) => s + f.gzBytes);
    var done = 0;
    var lastShown = 0.0;
    try {
      for (final f in files) {
        final file = File(p.join(dir, DatabaseManifest.localName(f)));
        final part = File('${file.path}.part');
        final response = await (await http.getUrl(_urlOf(m, f.path))).close();
        if (response.statusCode != 200) {
          throw HttpException('HTTP ${response.statusCode} for ${f.path}');
        }
        final digest = _DigestSink();
        final hasher = sha256.startChunkedConversion(digest);
        // The gzipped bytes are hashed as they come and unpacked to disk.
        final counted = response.map((chunk) {
          hasher.add(chunk);
          done += chunk.length;
          _progress = done / total;
          if (_progress - lastShown >= 0.01) {
            lastShown = _progress;
            _changes.ping();
          }
          return chunk;
        });
        await counted.transform(gzip.decoder).pipe(part.openWrite());
        hasher.close();
        if (digest.value.toString() != f.sha256 ||
            await part.length() != f.bytes) {
          await part.delete();
          throw StateError('${f.path} is damaged (checksum)');
        }
        await part.rename(file.path);
      }
    } finally {
      http.close();
    }
  }

  /// Frees the space of copies of other versions (and of the old
  /// dictionaries, before lexicon.db and texts.db).
  static Future<void> _removeOldCopies(String dir, DatabaseManifest m) async {
    final keep = {for (final f in m.files) DatabaseManifest.localName(f)};
    final ours = RegExp(
      r'^((lexicon|texts)_.*\.db(\.part)?|dictionary(_el)?(_v\d+)?\.db)$',
    );
    await for (final f in Directory(dir).list()) {
      final name = p.basename(f.path);
      if (f is File && ours.hasMatch(name) && !keep.contains(name)) {
        await f.delete();
      }
    }
  }
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
