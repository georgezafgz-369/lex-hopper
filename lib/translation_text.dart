// ─────────────────────────────────────────────────────────────────────────────
// TRANSLATION TEXT — getting text ready for the offline translator.
//
// OPUS-MT learned from plain text, one sentence at a time. Text copied from
// a chat, a web page or a document is often neither: curly quotes, long
// dashes, "…", invisible spaces, **bold** marks, bullets, and whole
// paragraphs. One strange character can derail the rest of a paragraph, so
// the text is cleaned first, then translated line by line and sentence by
// sentence, and put back together.
// ─────────────────────────────────────────────────────────────────────────────

/// Plain characters in place of typographic ones: curly quotes, long
/// dashes, "…", invisible and non-breaking spaces, Markdown marks.
String cleanForTranslation(String text) {
  var s = text;
  const swaps = {
    // curly double quotes
    '\u201C': '"', '\u201D': '"', '\u201E': '"', '\u201F': '"',
    // guillemets
    '\u00AB': '"', '\u00BB': '"',
    // curly single quotes
    '\u2018': "'", '\u2019': "'", '\u201A': "'", '\u201B': "'",
    // prime, acute accent
    '\u2032': "'", '\u00B4': "'",
    // backtick (Markdown code marks)
    '\u0060': '',
    // hyphens, dashes, minus
    '\u2010': '-', '\u2011': '-', '\u2012': '-', '\u2013': '-', '\u2014': '-', '\u2015': '-', '\u2212': '-',
    // ellipsis
    '\u2026': '...',
    // Greek question mark, typed as ;
    '\u037E': ';',
    // non-breaking and thin spaces
    '\u00A0': ' ', '\u2007': ' ', '\u2009': ' ', '\u200A': ' ', '\u202F': ' ',
    // invisible characters, soft hyphen
    '\u200B': '', '\u200C': '', '\u200D': '', '\uFEFF': '', '\u00AD': '',
    '\t': ' ', '\r': '',
  };
  swaps.forEach((from, to) => s = s.replaceAll(from, to));
  // **bold**, __bold__ (Markdown copied with the text).
  s = s.replaceAll(RegExp(r'\*\*|__'), '');
  // Spaces: one at a time, none at a line's ends.
  s = s.replaceAll(RegExp(r' {2,}'), ' ');
  s = s.split('\n').map((l) => l.trim()).join('\n');
  return s.trim();
}

/// A list marker at a line's start ("- ", "• ", "* ", "1. ", "2) "), kept
/// out of the translation and put back in front of it.
final _bullet = RegExp(r'^(?:[-•*·]|\d{1,3}[.)])\s+');

/// Words ending in "." that don't end a sentence.
const _abbreviations = {
  'mr', 'mrs', 'ms', 'dr', 'prof', 'st', 'vs', 'etc', 'e.g', 'i.e', 'no',
  'fig', 'approx', 'inc', 'ltd', 'jr', 'sr', 'κ', 'κα', 'δρ', 'π.χ', 'κλπ',
  'κτλ', 'βλ', 'σελ', 'αρ', 'τηλ',
};

/// The sentences of one line. A sentence ends at ".", "!" or "?" (and ";",
/// the Greek question mark, when [lang] is "el"), with any closing quotes
/// or brackets, before a space and a capital letter, a digit or an opening
/// quote. Abbreviations ("Dr.", "e.g.", "π.χ.") and initials ("J. Smith")
/// don't end one.
List<String> splitSentences(String line, {String lang = 'en'}) {
  final ends = lang == 'el' ? r'.!?;' : r'.!?';
  final boundary = RegExp(
    '[${RegExp.escape(ends)}]+["\'\\)\\]]*'
    r'(?=\s+["\x27(\[]?[\p{Lu}\p{N}])',
    unicode: true,
  );
  final out = <String>[];
  var from = 0;
  for (final m in boundary.allMatches(line)) {
    final before = line.substring(from, m.start);
    final word = RegExp(r'(\S+)$').firstMatch(before)?.group(1) ?? '';
    final bare = word.toLowerCase().replaceAll(RegExp(r'^["\x27(\[]+'), '');
    final isDot = line[m.start] == '.' && m.end - m.start == 1;
    if (isDot &&
        (_abbreviations.contains(bare) ||
            RegExp(r'^\p{Lu}$', unicode: true).hasMatch(word))) {
      continue;
    }
    out.add(line.substring(from, m.end).trim());
    from = m.end;
  }
  final rest = line.substring(from).trim();
  if (rest.isNotEmpty) out.add(rest);
  return out;
}

/// Cleans [text], then translates it one sentence at a time with [one],
/// keeping its lines and list markers. [lang] is the text's language.
Future<String> translateBySentence(
  String text,
  String lang,
  Future<String> Function(String sentence) one,
) async {
  final lines = <String>[];
  for (final line in cleanForTranslation(text).split('\n')) {
    if (line.isEmpty) {
      lines.add('');
      continue;
    }
    final bullet = _bullet.firstMatch(line)?.group(0) ?? '';
    final body = line.substring(bullet.length);
    final parts = <String>[];
    for (final sentence in splitSentences(body, lang: lang)) {
      // Nothing to translate in "...", "-" or "42".
      final hasWords = RegExp(r'\p{L}', unicode: true).hasMatch(sentence);
      parts.add(hasWords ? (await one(sentence)).trim() : sentence);
    }
    lines.add('$bullet${parts.join(' ')}');
  }
  return lines.join('\n');
}
