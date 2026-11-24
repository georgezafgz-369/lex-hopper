// The offline translator's download: every file is fetched once from the
// pinned version, checked against its SHA-256 and only then kept; a damaged
// or missing file stops it. The manifest says what and from where.

import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lex_hopper/eurollm_translator.dart' show ModelState;
import 'package:lex_hopper/opus_mt_service.dart';

void main() {
  late Directory dir;
  late HttpServer server;
  late Map<String, List<int>> served;
  late List<String> requested;

  setUp(() async {
    dir = await Directory.systemTemp.createTemp('opus');
    requested = [];
    served = {
      'en-el/a.onnx': utf8.encode('model one'),
      'el-en/b.json': utf8.encode('{"x": 1}'),
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
    if (dir.existsSync()) await dir.delete(recursive: true);
  });

  OpusMtManifest manifest({String? sha, String repo = 'me/models'}) =>
      OpusMtManifest(
        repo: repo,
        revision: 'abc123',
        folder: 'opus-mt',
        files: [
          for (final MapEntry(:key, :value) in served.entries)
            (
              path: key,
              bytes: value.length,
              sha256: sha ?? sha256.convert(value).toString(),
            ),
        ],
      );

  OpusMtService service({String? sha}) {
    final m = manifest(sha: sha);
    return OpusMtService(
      root: () async => dir.path,
      manifest: () async => m,
      urlOf: (_, path) => Uri.parse('http://127.0.0.1:${server.port}/$path'),
    );
  }

  test('the address is the pinned version on Hugging Face', () {
    expect(
      manifest().url('en-el/a.onnx').toString(),
      'https://huggingface.co/me/models/resolve/abc123/opus-mt/en-el/a.onnx',
    );
    expect(manifest().hosted, isTrue);
    expect(manifest(repo: '').hosted, isFalse);
  });

  test('downloads and checks every file, then is ready', () async {
    final s = service();
    await s.refresh();
    expect(s.state, ModelState.notDownloaded);
    await s.download();
    expect(s.state, ModelState.ready);
    expect(await s.isReady(), isTrue);
    expect(await File('${dir.path}/el-en/b.json').readAsString(), '{"x": 1}');
    expect(
      dir.listSync(recursive: true).where((f) => f.path.endsWith('.part')),
      isEmpty,
    );
  });

  test('files already there are not downloaded again', () async {
    await service().download();
    requested.clear();
    final again = service();
    await again.download();
    expect(again.state, ModelState.ready);
    expect(requested, isEmpty);
  });

  test('a damaged file is not kept', () async {
    final s = service(sha: '0' * 64);
    await s.download();
    expect(s.state, ModelState.failed);
    expect(await s.isReady(), isFalse);
    expect(File('${dir.path}/en-el/a.onnx').existsSync(), isFalse);
  });

  test('a missing file stops the download', () async {
    final s = service();
    served.remove('el-en/b.json');
    final m = manifest()
      ..files.add((path: 'el-en/b.json', bytes: 8, sha256: ''));
    final withMissing = OpusMtService(
      root: () async => dir.path,
      manifest: () async => m,
      urlOf: (_, path) => Uri.parse('http://127.0.0.1:${server.port}/$path'),
    );
    await withMissing.download();
    expect(withMissing.state, ModelState.failed);
    expect(s.state, ModelState.checking);
  });

  test('delete frees the space', () async {
    final s = service();
    await s.download();
    await s.deleteModels();
    expect(s.state, ModelState.notDownloaded);
    expect(dir.existsSync(), isFalse);
  });
}
