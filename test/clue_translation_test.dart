// A clue keeps its translation (English ↔ Greek) through saving and
// building the puzzle, so the game can show it under the clue.

import 'package:flutter_test/flutter_test.dart';
import 'package:lex_hopper/crossword_puzzle.dart';

void main() {
  test('the clue translation is saved and reaches the clue list', () {
    final entry = PuzzleEntry(
      word: 'north',
      clue: 'The cardinal compass point that is at 0 or 360 degrees',
      clueTr: 'Ένα από τα κύρια σημεία του ορίζοντα',
      row: 0,
      col: 0,
      across: true,
    );
    final back = PuzzleEntry.fromJson(entry.toJson());
    expect(back.clueTr, 'Ένα από τα κύρια σημεία του ορίζοντα');

    // Older saves have no translation.
    final old = Map<String, dynamic>.from(entry.toJson())..remove('clueTr');
    expect(PuzzleEntry.fromJson(old).clueTr, isNull);
  });
}
