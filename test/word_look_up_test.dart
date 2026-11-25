import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:lex_hopper/app_settings.dart';
import 'package:lex_hopper/word_look_up.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  test('wordAt finds the word under the tap', () {
    const text = 'Cancel, annul, or reverse';
    expect(WordLookUp.wordAt(text, 0), 'Cancel');
    expect(WordLookUp.wordAt(text, 10), 'annul');
    expect(WordLookUp.wordAt(text, 13), 'annul'); // just past its end
    expect(WordLookUp.wordAt('a  b', 2), isNull); // between spaces
    expect(WordLookUp.wordAt('Κάντε ένα δώρο', 7), 'ένα');
    expect(WordLookUp.wordAt("don't stop", 2), "don't");
  });

  test('Greek words read the Greek dictionary, others the Latin ones', () {
    expect(WordLookUp.dictionariesFor('δώρο', main: 'en', second: 'es'), [
      'el',
    ]);
    expect(WordLookUp.dictionariesFor('gift', main: 'el', second: 'es'), [
      'es',
      'en',
    ]);
    expect(WordLookUp.dictionariesFor('gift', main: 'de'), ['de', 'en']);
  });

  group('double tap', () {
    final looked = <String>[];
    setUp(() async {
      SharedPreferences.setMockInitialValues({});
      await AppSettings.instance.load();
      looked.clear();
      WordLookUp.onLookUpForTest = looked.add;
    });
    tearDown(() => WordLookUp.onLookUpForTest = null);

    Future<void> pump(WidgetTester tester, Widget body) => tester.pumpWidget(
      MaterialApp(
        home: WordLookUp(
          navigator: GlobalKey<NavigatorState>(),
          child: Center(child: body),
        ),
      ),
    );

    // Taps with their times, as on a phone.
    Future<void> tapAt(WidgetTester tester, Offset at, int ms) async {
      final gesture = await tester.createGesture();
      await gesture.down(at, timeStamp: Duration(milliseconds: ms));
      await gesture.up(timeStamp: Duration(milliseconds: ms + 50));
      await tester.pump();
    }

    Future<void> doubleTap(WidgetTester tester, Offset at) async {
      await tapAt(tester, at, 1000);
      await tapAt(tester, at, 1150);
    }

    testWidgets('on a word looks it up', (tester) async {
      await pump(tester, const Text('gift'));
      await doubleTap(tester, tester.getCenter(find.text('gift')));
      expect(looked, ['gift']);
      expect(WordLookUp.justLookedUp, isTrue);
    });

    testWidgets('one tap does nothing', (tester) async {
      await pump(tester, const Text('gift'));
      final at = tester.getCenter(find.text('gift'));
      await tapAt(tester, at, 1000);
      await tapAt(tester, at, 2000); // a second later: two single taps
      expect(looked, isEmpty);
    });

    testWidgets('not inside NoWordLookUp', (tester) async {
      await pump(tester, const NoWordLookUp(child: Text('hint')));
      await doubleTap(tester, tester.getCenter(find.text('hint')));
      expect(looked, isEmpty);
    });

    testWidgets('not when turned off in Settings', (tester) async {
      await AppSettings.instance.setWordLookUp(false);
      await pump(tester, const Text('gift'));
      await doubleTap(tester, tester.getCenter(find.text('gift')));
      expect(looked, isEmpty);
      await AppSettings.instance.setWordLookUp(true);
    });
  });
}
