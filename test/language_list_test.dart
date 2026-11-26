// The language list: a language to download has a "Download · size"
// button in the app's language only, so the language's name beside it has
// room and doesn't break mid-word.

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:lex_hopper/app_settings.dart';
import 'package:lex_hopper/language_packs.dart';
import 'package:lex_hopper/opus_mt_service.dart';
import 'package:lex_hopper/settings_page.dart';
import 'package:material_ui/material_ui.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  late LanguagePacks before;
  late Directory dir;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    await AppSettings.instance.load();
    dir = await Directory.systemTemp.createTemp('packs');
    before = LanguagePacks.instance;
    LanguagePacks.instance = LanguagePacks(
      dictionaryDir: () async => '${dir.path}/db',
      translatorRoot: () async => '${dir.path}/opus-mt',
      manifest: () async => {
        'it': const LanguagePack(
          code: 'it',
          repo: 'me/data',
          repoType: 'dataset',
          revision: 'abc',
          path: 'packs/it.db.gz',
          sha256: '0',
          fingerprint: 'v1',
          gzBytes: 7000000,
          bytes: 20000000,
          translator: OpusMtManifest(
            repo: 'me/models',
            revision: 'def',
            folder: 'opus-mt',
            files: [],
          ),
        ),
      },
    );
    await LanguagePacks.instance.load();
  });

  tearDown(() async {
    LanguagePacks.instance = before;
    await dir.delete(recursive: true);
  });

  testWidgets('the download button is in the main language only', (
    tester,
  ) async {
    await AppSettings.instance.setSecondaryLanguage('el');
    await tester.binding.setSurfaceSize(const Size(400, 1400));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(const MaterialApp(home: SettingsPage()));
    await tester.tap(find.byKey(const Key('settings-language')));
    await tester.pumpAndSettle();

    final button = find.byKey(const Key('pack-download-it'));
    expect(button, findsOneWidget);
    expect(
      find.descendant(of: button, matching: find.textContaining('Download ·')),
      findsOneWidget,
    );
    expect(
      find.descendant(of: button, matching: find.textContaining('Λήψη')),
      findsNothing,
    );
  });
}
