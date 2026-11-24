// The phrasebook key must match the one scripts/build_databases.py writes:
// case, Greek accents, punctuation and "(formal)" notes don't matter.

import 'package:flutter_test/flutter_test.dart';
import 'package:lex_hopper/dictionary_service.dart';

void main() {
  test('ignores case, accents, punctuation and notes', () {
    expect(phraseKey('Καλημέρα, τι κάνεις;'), 'καλημερα τι κανεισ');
    expect(phraseKey('καλημερα τι κανεις'), 'καλημερα τι κανεισ');
    expect(phraseKey('  How are you?? '), 'how are you');
    expect(phraseKey("I don't understand."), 'i don t understand');
    expect(phraseKey('hello (formal)'), 'hello');
    expect(phraseKey('?!'), '');
  });
}
