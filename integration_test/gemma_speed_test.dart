// Times the app's AI models on the phone through AiModel.chat, the way
// Chat with AI uses them. Prints SPEED lines; judging is by hand. A model
// that isn't downloaded is skipped.
//
// Measured on a Pixel 8 (2026-11-25), "I goed to the market yesterday":
//   Gemma 4 E2B, GGUF on llama.cpp (CPU)      30–60 s per answer
//   Gemma 4 E2B, LiteRT-LM on the CPU (now)   9 s the first, then about 5 s
//   Gemma 4 E2B, LiteRT-LM on the GPU         50 s the first, then 5 s, and
//                                             garbled Greek
//
// flutter test integration_test/gemma_speed_test.dart -d <device> --no-uninstall

import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:lex_hopper/ai_model.dart';

const _instructions =
    'You are a friendly language tutor. Reply in the learner\'s language, '
    'in two or three sentences; first correct any mistake.';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('AI models answer fast enough', (tester) async {
    for (final model in AiModel.all) {
      if (!await model.isReady()) {
        // ignore: avoid_print
        print('SPEED ${model.name} not downloaded: skipped');
        continue;
      }
      for (final text in const [
        'I goed to the market yesterday',
        'Χθες πήγα στη θάλασσα με τους φίλος μου.',
      ]) {
        final clock = Stopwatch()..start();
        var first = -1;
        final out = StringBuffer();
        await for (final bit in model.chat([
          (mine: true, text: text),
        ], instructions: _instructions)) {
          if (first < 0 && bit.trim().isNotEmpty) {
            first = clock.elapsedMilliseconds;
          }
          out.write(bit);
        }
        // ignore: avoid_print
        print(
          'SPEED ${model.name} first-word $first ms, all '
          '${clock.elapsedMilliseconds} ms | '
          '${out.toString().replaceAll('\n', ' ')}',
        );
        expect(out.toString().trim(), isNotEmpty);
      }
    }
  }, timeout: const Timeout(Duration(minutes: 20)));
}
