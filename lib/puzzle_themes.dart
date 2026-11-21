// ─────────────────────────────────────────────────────────────────────────────
// PUZZLE THEMES — the subjects a new crossword or Find the Words can be about
// ─────────────────────────────────────────────────────────────────────────────
//
// An answer belongs to a theme when the meaning its clue comes from clearly
// does (`puzzle_words.theme`, filled by scripts/build_puzzle_themes.py from
// WordNet's groups and topics, and from the dictionary's subject labels
// when the clue confirms them). "All subjects" (theme null) uses every
// answer, as before.

import 'dart:math';

import 'app_text.dart';

class PuzzleTheme {
  final String id;
  final String nameEn;
  final String nameEl;

  const PuzzleTheme(this.id, this.nameEn, this.nameEl);

  String name(AppText t) => t.el ? nameEl : nameEn;

  static PuzzleTheme? byId(String? id) {
    for (final t in puzzleThemes) {
      if (t.id == id) return t;
    }
    return null;
  }
}

const puzzleThemes = [
  PuzzleTheme('animals', 'Animals', 'Ζώα'),
  PuzzleTheme('plants', 'Plants & Gardens', 'Φυτά & Κήποι'),
  PuzzleTheme('food', 'Food & Drink', 'Φαγητό & Ποτό'),
  PuzzleTheme('body', 'Body & Health', 'Σώμα & Υγεία'),
  PuzzleTheme('earth', 'Earth & Places', 'Γη & Τόποι'),
  PuzzleTheme('science', 'Science', 'Επιστήμη'),
  PuzzleTheme('money', 'Money & Business', 'Χρήμα & Επιχειρήσεις'),
  PuzzleTheme('mind', 'Mind & Society', 'Νους & Κοινωνία'),
  PuzzleTheme('law', 'Law & Politics', 'Δίκαιο & Πολιτική'),
  PuzzleTheme('travel', 'Travel & Transport', 'Ταξίδια & Μεταφορές'),
  PuzzleTheme('tech', 'Tech & Numbers', 'Τεχνολογία & Αριθμοί'),
  PuzzleTheme('religion', 'Religion & Myth', 'Θρησκεία & Μύθοι'),
  PuzzleTheme('arts', 'Arts & Books', 'Τέχνες & Βιβλία'),
  PuzzleTheme('military', 'War & History', 'Πόλεμος & Ιστορία'),
  PuzzleTheme('fashion', 'Fashion', 'Μόδα'),
  PuzzleTheme('music', 'Music', 'Μουσική'),
  PuzzleTheme('language', 'Language', 'Γλώσσα'),
  PuzzleTheme('sports', 'Sports & Games', 'Αθλήματα & Παιχνίδια'),
];

/// Which of a theme's answers (sorted most common first, [count] in all) a
/// level uses: positions [start, end). Like the levels without a theme,
/// level 1 takes the most common answers and each level reaches further
/// into rarer ones; from level 3 the most common quarter is left out.
(int, int) themeWindow(int level, int count) {
  final l = max(1, level);
  final end = min(count, max(120, (count * pow(2, l - 1) / 8).round()));
  final start = l <= 2 ? 0 : min(end ~/ 4, count ~/ 2);
  return (start, end);
}
