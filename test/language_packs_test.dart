// A downloadable language (Spanish, German) is one download: its dictionary
// (gzipped, checked, unpacked) and its translator files (checked). It shows
// as installed once both are there, can be removed again, and a damaged
// file stops it.

import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lex_hopper/language_packs.dart';
import 'package:lex_hopper/opus_mt_service.dart';

void main() {
  late Directory dir;
  late HttpServer server;
  late Map<String, List<int>> served;
  final dictionary = utf8.encode('spanish dictionary ' * 40);
  final model = utf8.encode('model bytes');

  setUp(() async {
    dir = await Directory.systemTemp.createTemp('packs');
    served = {
      'packs/es_v1.db.gz': gzip.encode(dictionary),
      'opus-mt/en-es/a.onnx': model,
      'opus-mt/es-en/a.onnx': model,
    };
    server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    server.listen((request) {
      final body = served[request.uri.path.substring(1)];
      request.response.statusCode = body == null ? 404 : 200;
      if (body != null) request.response.add(body);
      request.response.close();
    });
  });

  tearDown(() async {
    await server.close(force: true);
    await dir.delete(recursive: true);
  });

  LanguagePacks packs({String? sha}) {
    final gz = served['packs/es_v1.db.gz']!;
    final pack = LanguagePack(
      code: 'es',
      repo: 'me/data',
      repoType: 'dataset',
      revision: 'abc',
      path: 'packs/es_v1.db.gz',
      sha256: sha ?? sha256.convert(gz).toString(),
      fingerprint: 'v1',
      gzBytes: gz.length,
      bytes: dictionary.length,
      translator: OpusMtManifest(
        repo: 'me/models',
        revision: 'def',
        folder: 'opus-mt',
        files: [
          for (final path in ['en-es/a.onnx', 'es-en/a.onnx'])
            (
              path: path,
              bytes: model.length,
              sha256: sha256.convert(model).toString(),
            ),
        ],
      ),
    );
    final base = 'http://127.0.0.1:${server.port}';
    return LanguagePacks(
      dictionaryDir: () async => '${dir.path}/db',
      translatorRoot: () async => '${dir.path}/opus-mt',
      manifest: () async => {'es': pack},
      urlOf: (p) => Uri.parse('$base/${p.path}'),
      translatorUrlOf: (m, path) => Uri.parse('$base/opus-mt/$path'),
    );
  }

  test('offers the language, not yet installed', () async {
    final p = packs();
    await p.load();
    expect(p.offers('es'), isTrue);
    expect(p.offers('de'), isFalse);
    expect(p.state('es'), PackState.notInstalled);
    expect(p.dictionaryPath('es'), isNull);
  });

  test('one download brings the dictionary and the translator', () async {
    final p = packs();
    await p.download('es');
    expect(p.state('es'), PackState.installed);
    expect(p.progress('es'), closeTo(1, 0.01));
    final path = p.dictionaryPath('es')!;
    expect(await File(path).readAsBytes(), dictionary);
    expect(File('${dir.path}/opus-mt/es-en/a.onnx').existsSync(), isTrue);
    // A later start finds it on the phone.
    final again = packs();
    await again.load();
    expect(again.isInstalled('es'), isTrue);
  });

  test('a damaged dictionary is not kept', () async {
    final p = packs(sha: '0' * 64);
    await p.download('es');
    expect(p.state('es'), PackState.failed);
    expect(p.dictionaryPath('es'), isNull);
  });

  test('removing it frees the space', () async {
    final p = packs();
    await p.download('es');
    await p.delete('es');
    expect(p.state('es'), PackState.notInstalled);
    expect(File('${dir.path}/db/pack_es_v1.db').existsSync(), isFalse);
    expect(File('${dir.path}/opus-mt/en-es/a.onnx').existsSync(), isFalse);
  });
}
