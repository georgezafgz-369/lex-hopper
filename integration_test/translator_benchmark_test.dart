// Scores the offline Translator on the fixed test sets
// (data/benchmark/translator_test*.csv): each text goes through what the
// Translator does without AI — the phrasebook and dictionary first, then
// the offline translator (OPUS-MT, downloaded first). Prints one
// BENCH line per text; judging is done by hand.
// Use --no-uninstall on a real phone, or its app data is wiped.
//
// flutter test integration_test/translator_benchmark_test.dart -d <device>

import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:lex_hopper/translator_page.dart' show lookUpInLexicon;
import 'package:lex_hopper/opus_mt_service.dart';

import 'benchmark_data.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('offline Translator on the test set', (tester) async {
    final opus = OpusMtService.instance;
    expect(await opus.isReady(), isTrue, reason: 'OPUS-MT not downloaded');
    for (final (set, items) in [(1, benchmark), (2, benchmark2)]) {
      for (final (id, from, to, text) in items) {
        var source = 'app data';
        String? answer = (await lookUpInLexicon(text, from)).main;
        if (answer == null) {
          source = 'opus';
          answer = await opus.translate(text, from: from, to: to);
        }
        // ignore: avoid_print
        print('BENCH\t$set\t$id\t$source\t$answer');
      }
    }
  }, timeout: const Timeout(Duration(minutes: 20)));
}
