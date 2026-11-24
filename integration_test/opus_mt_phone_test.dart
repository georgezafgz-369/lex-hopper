// Runs the downloaded OPUS-MT (8-bit ONNX) on the phone over test set 2 and
// times it. Prints one OPUSPHONE line per text; judging is done by hand.
//
// flutter test integration_test/opus_mt_phone_test.dart -d <device> --no-uninstall
// (without --no-uninstall the app, and its data, is removed afterwards)

import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:lex_hopper/opus_mt_service.dart';

import 'benchmark_data.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('OPUS-MT on the phone', (tester) async {
    final opus = OpusMtService.instance;
    expect(await opus.isReady(), isTrue, reason: 'models not downloaded');

    final load = Stopwatch()..start();
    await opus.prepare();
    // ignore: avoid_print
    print('OPUSLOAD\t${load.elapsedMilliseconds}');

    final times = <int>[];
    for (final (id, from, to, text) in benchmark2) {
      final clock = Stopwatch()..start();
      final answer = await opus.translate(text, from: from, to: to);
      times.add(clock.elapsedMilliseconds);
      // ignore: avoid_print
      print('OPUSPHONE\t$id\t${clock.elapsedMilliseconds}\t$answer');
    }
    times.sort();
    // ignore: avoid_print
    print(
      'OPUSTIME\tmedian ${times[times.length ~/ 2]} ms\t'
      'p90 ${times[times.length * 9 ~/ 10]} ms\tmax ${times.last} ms\t'
      'total ${times.reduce((a, b) => a + b)} ms',
    );
    await opus.dispose();
  }, timeout: const Timeout(Duration(minutes: 30)));
}
