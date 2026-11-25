// The Translator uses the offline translator (OPUS-MT) first, then the AI
// model (EuroLLM) when it's on; with neither it says there's no translator
// yet. A translation that a newer one replaced is not a failure.

import 'package:flutter_test/flutter_test.dart';
import 'package:lex_hopper/ai_model.dart';
import 'package:lex_hopper/translator_service.dart';

class FakeTranslator implements Translator {
  final String name;
  bool ready;
  Object? error;
  int prepared = 0;
  int disposed = 0;
  final calls = <String>[];

  FakeTranslator(this.name, {this.ready = true});

  @override
  Future<bool> isReady() async => ready;

  @override
  Future<void> prepare() async {
    prepared++;
    ready = true;
  }

  @override
  Future<String> translate(
    String text, {
    required String from,
    required String to,
  }) async {
    calls.add(text);
    if (error case final e?) throw e;
    return '$name:$text';
  }

  @override
  Future<void> dispose() async => disposed++;
}

void main() {
  late FakeTranslator offline, ai;
  var aiOn = false;
  PreferredTranslator make({bool withOffline = true}) => PreferredTranslator(
    ai: ai,
    useAi: () => aiOn,
    offline: withOffline ? offline : null,
  );

  setUp(() {
    offline = FakeTranslator('offline');
    ai = FakeTranslator('ai');
    aiOn = false;
  });

  Future<String> run(PreferredTranslator t) =>
      t.translate('house', from: 'en', to: 'el');

  test('the offline translator comes first, even with the AI on', () async {
    aiOn = true;
    expect(await run(make()), 'offline:house');
    expect(ai.calls, isEmpty);
  });

  test('offline not downloaded, AI on: the AI translates', () async {
    offline.ready = false;
    aiOn = true;
    expect(await run(make()), 'ai:house');
  });

  test('no translator on the phone yet: says so', () async {
    offline.ready = false;
    await expectLater(run(make()), throwsA(isA<NoTranslatorYet>()));
    aiOn = true;
    ai.ready = false;
    await expectLater(run(make()), throwsA(isA<NoTranslatorYet>()));
    await expectLater(
      run(make(withOffline: false)),
      throwsA(isA<NoTranslatorYet>()),
    );
  });

  test('offline fails on a text: the AI translates it instead', () async {
    offline.error = StateError('broken model');
    aiOn = true;
    expect(await run(make()), 'ai:house');
  });

  test('every engine fails: the error comes through', () async {
    offline.error = StateError('broken model');
    await expectLater(run(make()), throwsA(isA<StateError>()));
  });

  test('a replaced translation is passed on, not retried', () async {
    offline.error = const TranslationSuperseded();
    aiOn = true;
    await expectLater(run(make()), throwsA(isA<TranslationSuperseded>()));
    expect(ai.calls, isEmpty);
  });

  test('always ready: nothing is fetched in the background', () async {
    offline.ready = false;
    expect(await make().isReady(), isTrue);
  });

  test('warming up loads the best ready engine only', () async {
    aiOn = true;
    await make().warmUp();
    expect(offline.prepared, 1);
    expect(ai.prepared, 0);

    offline.ready = false;
    await make().prepare();
    expect(ai.prepared, 1, reason: 'prepare warms up too');

    aiOn = false;
    await make().warmUp(); // nothing ready: nothing to load
    expect(ai.prepared, 1);
  });

  test('a model that fails to load does not break warming up', () async {
    final broken = PreferredTranslator(
      ai: ai,
      useAi: () => aiOn,
      offline: _FailingPrepare(),
    );
    await broken.warmUp(); // no throw
  });

  test('dispose leaves the shared models loaded', () async {
    await make().dispose();
    expect(offline.disposed, 0);
    expect(ai.disposed, 0);
  });

  group('EuroLLM prompt', () {
    test('asks for the translation only', () {
      expect(
        AiModel.translationPrompt('καλη μερα', from: 'el', to: 'en'),
        'Translate this Greek text into English. '
        'Reply with the translation only.\n\nκαλη μερα',
      );
    });

    test('a repeat of the text is not a translation', () {
      expect(
        AiModel.isCopy(
          'Καλή μέρα, τι καλό είναι να κάνουμε',
          'καλη μερα, τι καλό είναι να κάνουμε;',
        ),
        isTrue,
      );
      expect(AiModel.isCopy('Good day', 'καλη μερα'), isFalse);
    });

    test('answers lose a repeated label and chat markers', () {
      expect(AiModel.cleanTranslation(' σπίτι<|im_end|>'), 'σπίτι');
      expect(AiModel.cleanTranslation('Greek: σπίτι'), 'σπίτι');
      expect(AiModel.cleanTranslation('English: house'), 'house');
      expect(
        AiModel.cleanTranslation('Ελληνικά: Η εξουσία στον λαό!'),
        'Η εξουσία στον λαό!',
      );
      expect(
        AiModel.cleanTranslation('Απάντηση: Άφησα τα κλειδιά μου.'),
        'Άφησα τα κλειδιά μου.',
      );
    });

    test('an answer in the wrong alphabet is not a translation', () {
      expect(AiModel.isInLanguage('Το σώμα είναι κόκκινο', 'el'), isTrue);
      expect(AiModel.isInLanguage('The body of the car', 'el'), isFalse);
      expect(AiModel.isInLanguage('Where is the beach?', 'en'), isTrue);
      expect(AiModel.isInLanguage('Πού είναι;', 'en'), isFalse);
      expect(AiModel.isInLanguage('', 'el'), isFalse);
      // A brand name inside Greek is fine.
      expect(AiModel.isInLanguage('Αγόρασα ένα iPhone χθες', 'el'), isTrue);
    });

    test('the answer is its first non-empty line', () {
      expect(
        AiModel.cleanTranslation('\nΤο σώμα είναι κόκκινο\nExtra'),
        'Το σώμα είναι κόκκινο',
      );
    });
  });

  test('reads the total memory from /proc/meminfo', () {
    expect(
      AiModel.memTotalKb('MemTotal:        4004500 kB\nMemFree:  12 kB\n'),
      4004500,
    );
    expect(AiModel.memTotalKb('nothing here'), isNull);
    // A 2 GB phone is too small; a 4 GB one is enough.
    expect(2013212 >= AiModel.euroLlm.minMemoryKb, isFalse);
    expect(3809000 >= AiModel.euroLlm.minMemoryKb, isTrue);
  });
}

class _FailingPrepare extends FakeTranslator {
  _FailingPrepare() : super('ai');

  @override
  Future<void> prepare() async => throw StateError('out of memory');
}
