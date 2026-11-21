// ─────────────────────────────────────────────────────────────────────────────
// TRANSLATE LIST — a one-off build tool, not part of the app.
//
// Translates text lists on a phone/emulator with the on-device translator.
// Reads app_flutter/en_el.txt and app_flutter/el_en.txt (one text per line,
// made by scripts/texts_to_translate.py and copied onto the device) and
// writes "text<TAB>translation" lines to en_el.tsv / el_en.tsv next to
// them. One text per call (several in one call leak into each other), a few
// calls at once. Picks up where it left off if stopped.
//
//   adb push build/texts/en_el.txt /data/local/tmp/
//   adb shell run-as com.lexhopper.lex_hopper cp /data/local/tmp/en_el.txt app_flutter/
//   flutter run -d emulator-5554 -t tool/translate_list.dart
//   adb exec-out run-as com.lexhopper.lex_hopper cat app_flutter/en_el.tsv
// ─────────────────────────────────────────────────────────────────────────────

import 'dart:io';

import 'package:google_mlkit_translation/google_mlkit_translation.dart';
import 'package:lex_hopper/translator_service.dart';
import 'package:material_ui/material_ui.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

final status = ValueNotifier<String>('Starting…');

void log(String line) {
  status.value = line;
  // ignore: avoid_print
  print('LIST: $line');
}

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(
    MaterialApp(
      home: Scaffold(
        body: Center(
          child: ValueListenableBuilder<String>(
            valueListenable: status,
            builder: (_, s, _) => Padding(
              padding: const EdgeInsets.all(24),
              child: Text(s, textAlign: TextAlign.center),
            ),
          ),
        ),
      ),
    ),
  );
  try {
    log('Getting the language models…');
    await OnDeviceTranslatorService().prepare();
    final dir = (await getApplicationDocumentsDirectory()).path;
    // Greek first: it's small.
    await translateFile(
      p.join(dir, 'el_en'),
      TranslateLanguage.greek,
      TranslateLanguage.english,
    );
    await translateFile(
      p.join(dir, 'en_el'),
      TranslateLanguage.english,
      TranslateLanguage.greek,
    );
    log('DONE');
  } catch (e) {
    log('FAILED: $e');
  }
}

Future<void> translateFile(
  String base,
  TranslateLanguage from,
  TranslateLanguage to,
) async {
  final input = File('$base.txt');
  if (!await input.exists()) {
    log('${p.basename(base)}: no input, skipped');
    return;
  }
  final texts = [
    for (final l in await input.readAsLines())
      if (l.trim().isNotEmpty) l,
  ];
  final out = File('$base.tsv');
  final done = <String>{};
  if (await out.exists()) {
    for (final line in await out.readAsLines()) {
      final tab = line.indexOf('\t');
      if (tab > 0) done.add(line.substring(0, tab));
    }
  }
  final todo = [for (final t in texts) if (!done.contains(t)) t];
  final translator = OnDeviceTranslator(
    sourceLanguage: from,
    targetLanguage: to,
  );
  final sink = out.openWrite(mode: FileMode.append);
  String clean(String s) =>
      s.replaceAll('\t', ' ').replaceAll('\n', ' ').trim();
  const parallel = 8;
  var n = texts.length - todo.length;
  final clock = Stopwatch()..start();
  for (var i = 0; i < todo.length; i += parallel) {
    final batch = todo.sublist(
      i,
      i + parallel > todo.length ? todo.length : i + parallel,
    );
    final results = await Future.wait([
      for (final t in batch) translator.translateText(t).then(clean),
    ]);
    for (var j = 0; j < batch.length; j++) {
      if (results[j].isNotEmpty) sink.writeln('${batch[j]}\t${results[j]}');
    }
    final before = n;
    n += batch.length;
    if (n ~/ 2000 != before ~/ 2000) {
      await sink.flush();
      log(
        '${p.basename(base)}: $n / ${texts.length} '
        '(${clock.elapsed.inMinutes} min)',
      );
    }
  }
  await sink.flush();
  await sink.close();
  await translator.close();
  log('${p.basename(base)}: finished, ${texts.length} texts');
}
