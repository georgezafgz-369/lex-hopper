// The bundled filter labels match dictionary-subject-labels.docx.

import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:lex_hopper/dictionary_service.dart';

void main() {
  final options = FilterOptions.fromJson(
    jsonDecode(File('assets/dictionary_filters.json').readAsStringSync())
        as Map<String, dynamic>,
  );

  test('8 subject groups with 76 subjects, and 19 usage labels', () {
    expect(options.subjectGroups, hasLength(8));
    expect(options.subjectsById, hasLength(76));
    expect(options.usageLabels, hasLength(19));
  });

  test('labels have English names and stable ids', () {
    expect(
      options.subjectGroups.first.label.name(),
      'Law, Government & Institutions',
    );
    expect(options.subjectsById['law']!.name(), 'Law / Legal');
    expect(options.usageById['slang']!.name(), 'Slang');
    // Unknown languages fall back to English.
    expect(options.subjectsById['music']!.name('fr'), 'Music');
  });

  test('most subjects have tagged words', () {
    final empty = options.subjectsById.values.where((s) => s.count == 0);
    expect(empty, isEmpty);
  });

  test('an entry keeps every usage label, most significant first', () {
    final entry = DictionaryEntry.fromMap({
      'id': 1,
      'word': 'arse',
      'pos': 'noun',
      'meaning': 'vulgar slang for anus',
      'domain': 'general',
      'source': 'WordNet',
      'subject': null,
      'usage': 'vulgar,slang',
    });
    expect(entry.usages, ['vulgar', 'slang']);

    final plain = DictionaryEntry.fromMap({
      'id': 2,
      'word': 'cat',
      'pos': 'noun',
      'meaning': 'feline mammal',
      'domain': 'general',
      'source': 'WordNet',
      'subject': 'zoology',
      'usage': null,
    });
    expect(plain.usages, isEmpty);
  });

  test('structures: simple, compound, derived with descriptions', () {
    expect(options.structures.map((s) => s.id), [
      'simple',
      'compound',
      'derived',
    ]);
    expect(options.structures[1].description(), contains('bookshop'));
    expect(options.structures.every((s) => s.count > 0), isTrue);
  });

  test('an entry carries structure, synonyms and origin', () {
    final entry = DictionaryEntry.fromMap({
      'id': 3,
      'word': 'nosh',
      'pos': 'noun',
      'meaning': '(Yiddish) a snack',
      'domain': 'general',
      'source': 'WordNet',
      'subject': null,
      'usage': null,
      'structure': 'simple',
      'synonyms': 'bite,snack',
      'origin': 'Yiddish',
    });
    expect(entry.structure, 'simple');
    expect(entry.synonyms, ['bite', 'snack']);
    expect(entry.origin, 'Yiddish');
  });

  test('all nine parts of speech, in display order', () {
    expect(options.partOfSpeech, [
      'noun',
      'verb',
      'adj',
      'adv',
      'pron',
      'prep',
      'conj',
      'interj',
      'det',
    ]);
  });

  test('an entry carries WordNet examples, opposites and related forms', () {
    final entry = DictionaryEntry.fromMap({
      'id': 1,
      'word': 'fast',
      'pos': 'adj',
      'meaning': 'acting quickly',
      'domain': 'general',
      'source': 'WordNet',
      'examples': 'a fast car\nfast reflexes',
      'antonyms': 'slow',
      'related': 'fastness',
      'sense': 1,
    });
    expect(entry.examples, ['a fast car', 'fast reflexes']);
    expect(entry.antonyms, ['slow']);
    expect(entry.related, ['fastness']);
    expect(entry.sense, 1);
  });

  test('a medical entry carries its code, category and matched alias', () {
    final entry = DictionaryEntry.fromMap({
      'id': 1,
      'word': 'abdominal distention',
      'pos': 'noun',
      'meaning': 'Distention of the abdomen.',
      'domain': 'medical',
      'source': 'Human Phenotype Ontology',
      'category': 'Sign / symptom / phenotype',
      'code': 'ICD-10 R14.0',
      'matched_alias': 'abdominal bloating',
    });
    expect(entry.code, 'ICD-10 R14.0');
    expect(entry.category, 'Sign / symptom / phenotype');
    expect(entry.matchedAlias, 'abdominal bloating');
  });
}
