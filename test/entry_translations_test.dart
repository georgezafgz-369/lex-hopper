// A dictionary entry carries its meaning and each example in the other
// language, lined up with the examples; empty ones become null.

import 'package:flutter_test/flutter_test.dart';
import 'package:lex_hopper/dictionary_service.dart';

void main() {
  Map<String, dynamic> row({String? meaningTr, String? examplesTr}) => {
    'id': 1,
    'word': 'body',
    'pos': 'noun',
    'meaning': 'the main mass of a thing',
    'meaning_tr': meaningTr,
    'examples': 'the body of the car\nthe body of the message',
    'examples_tr': examplesTr,
    'domain': 'general',
    'source': 'WordNet',
  };

  test('reads the meaning and example translations', () {
    final e = DictionaryEntry.fromMap(
      row(meaningTr: 'ο κύριος όγκος', examplesTr: 'το αμάξωμα\n'),
    );
    expect(e.meaningTranslation, 'ο κύριος όγκος');
    expect(e.exampleTranslations, ['το αμάξωμα', null]);
  });

  test('no translations', () {
    final e = DictionaryEntry.fromMap(row(meaningTr: '  '));
    expect(e.meaningTranslation, isNull);
    expect(e.exampleTranslations, isEmpty);
  });
}
