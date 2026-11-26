// AI models on the fast engine (LiteRT-LM) need room for a copy of their
// weights on the first start, so a download checks for about twice the
// model's size; the chat says how much space to free.

import 'package:flutter_test/flutter_test.dart';
import 'package:lex_hopper/ai_model.dart';
import 'package:lex_hopper/app_text.dart';
import 'package:lex_hopper/chat_page.dart' show gbText;

void main() {
  test('a LiteRT-LM model needs room for itself and its first start', () {
    expect(AiModel.qwen.liteRt, isTrue);
    expect(AiModel.gemma4.liteRt, isTrue);
    expect(AiModel.qwen.spaceToDownloadMb, 2120 * 2 + 300);
    // llama.cpp models only need their own size.
    expect(AiModel.qwenMini.liteRt, isFalse);
    expect(AiModel.qwenMini.spaceToDownloadMb, 533 + 300);
    expect(AiModel.euroLlm.spaceToDownloadMb, 1045 + 300);
  });

  test('space in GB, one decimal, at least 0.1', () {
    expect(gbText(2120), '2.1');
    expect(gbText(4540), '4.5');
    expect(gbText(40), '0.1');
  });

  test('the message says how much to free', () {
    expect(AppText.forCode('en').aiNeedsSpace('2.1'), contains('2.1 GB'));
    expect(AppText.forCode('el').aiNeedsSpace('2.1'), contains('2.1 GB'));
    expect(const NotEnoughSpace(500).toString(), contains('500 MB'));
  });
}
