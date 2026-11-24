// The databases are downloaded once, gzipped, checked against their SHA-256
// and unpacked; a copy already there isn't fetched again, copies of other
// versions are deleted, and a failure can be tried again.

import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lex_hopper/database_download.dart';

void main() {
  late Directory dir;
  late HttpServer server;
  late Map<String, List<int>> served;
  late List<String> requested;
  final raw = {
    'lexicon': utf8.encode('lexicon database ' * 50),
    'texts': utf8.encode('texts database ' * 40),
  };

  setUp(() async {
    dir = await Directory.systemTemp.createTemp('dbs');
    requested = [];
    served = {
      for (final MapEntry(:key, :value) in raw.entries)
        'databases/${key}_v1.db.gz': gzip.encode(value),
    };
    server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    server.listen((request) {
      final path = request.uri.path.substring(1);
      requested.add(path);
      final body = served[path];
      request.response.statusCode = body == null ? 404 : 200;
      if (body != null) request.response.add(body);
      request.response.close();
    });
  });

  tearDown(() async {
    await server.close(force: true);
    await dir.delete(recursive: true);
  });

  DatabaseManifest manifest({String? sha}) => DatabaseManifest(
    repo: 'me/data',
    repoType: 'dataset',
    revision: 'abc',
    files: [
      for (final name in ['lexicon', 'texts'])
        (
          name: name,
          fingerprint: 'v1',
          path: 'databases/${name}_v1.db.gz',
          gzBytes: served['databases/${name}_v1.db.gz']!.length,
          sha256:
              sha ??
              sha256.convert(served['databases/${name}_v1.db.gz']!).toString(),
          bytes: raw[name]!.length,
        ),
    ],
  );

  DatabaseDownload download({String? sha}) {
    final m = manifest(sha: sha);
    return DatabaseDownload(
      dir: () async => dir.path,
      manifest: () async => m,
      urlOf: (_, path) => Uri.parse('http://127.0.0.1:${server.port}/$path'),
    );
  }

  test('the address is the pinned version of the dataset', () {
    expect(
      manifest().url('databases/lexicon_v1.db.gz').toString(),
      'https://huggingface.co/datasets/me/data/resolve/abc/'
      'databases/lexicon_v1.db.gz',
    );
  });

  test('downloads, checks and unpacks both databases', () async {
    final d = download();
    final (lexicon, texts) = await d.ensure();
    expect(d.state, DatabaseState.ready);
    expect(File(lexicon).readAsBytesSync(), raw['lexicon']);
    expect(File(texts).readAsBytesSync(), raw['texts']);
    expect(lexicon, endsWith('lexicon_v1.db'));
    expect(dir.listSync().where((f) => f.path.endsWith('.part')), isEmpty);
  });

  test('already there: nothing is downloaded', () async {
    await download().ensure();
    requested.clear();
    final again = download();
    await again.ensure();
    expect(again.state, DatabaseState.ready);
    expect(requested, isEmpty);
  });

  test('a damaged download is not kept, and can be tried again', () async {
    final bad = download(sha: '0' * 64);
    await expectLater(bad.ensure(), throwsA(isA<StateError>()));
    expect(bad.state, DatabaseState.failed);
    expect(dir.listSync(), isEmpty);
    // The next call tries again (here: with a good manifest).
    final good = download();
    await good.ensure();
    expect(good.state, DatabaseState.ready);
  });

  test('no internet: fails, and a retry downloads it', () async {
    final d = download();
    final saved = Map.of(served);
    served.clear(); // the server answers 404, like a broken connection
    await expectLater(d.ensure(), throwsA(isA<HttpException>()));
    expect(d.state, DatabaseState.failed);
    served.addAll(saved);
    await d.ensure();
    expect(d.state, DatabaseState.ready);
  });

  test(
    'copies of other versions and the old dictionaries are removed',
    () async {
      File('${dir.path}/lexicon_old.db').writeAsStringSync('old');
      File('${dir.path}/dictionary_el_v3.db').writeAsStringSync('old');
      File('${dir.path}/keep_me.txt').writeAsStringSync('mine');
      await download().ensure();
      final names = dir.listSync().map((f) => f.uri.pathSegments.last).toSet();
      expect(names, {'lexicon_v1.db', 'texts_v1.db', 'keep_me.txt'});
    },
  );
}
