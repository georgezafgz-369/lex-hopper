// The round button over every page opens a menu of the sections; a tap
// outside, the button again, or Back closes it, a row opens its page. It
// shrinks while open, can be dragged, and hides under sheets.

import 'package:flutter_test/flutter_test.dart';
import 'package:lex_hopper/app_settings.dart';
import 'package:lex_hopper/chat_page.dart' show ChatSession;
import 'package:lex_hopper/sections_button.dart';
import 'package:material_ui/material_ui.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  setUp(() async {
    ChatSession.instance.reset();
    SectionsButton.place = null;
    // A sheet a test left open would keep the button hidden.
    SectionsButton.observer.covered.value = false;
    SectionsButton.teacherCloud = false;
    SectionsButton.cloudDismissed = false;
    SectionsButton.cloudDelay = const Duration(seconds: 2);
    SectionsButton.cloudShowFor = const Duration(seconds: 4);
    SharedPreferences.setMockInitialValues({});
    await AppSettings.instance.load();
  });

  Widget page(String name) => Scaffold(body: Center(child: Text('$name page')));

  Widget app() {
    final navigator = GlobalKey<NavigatorState>();
    return MaterialApp(
      navigatorKey: navigator,
      navigatorObservers: [SectionsButton.observer],
      builder: (context, child) => Stack(
        children: [
          child!,
          Positioned.fill(child: SectionsButtonLayer(navigator: navigator)),
        ],
      ),
      routes: {
        '/': (_) => page('home'),
        '/games': (_) => page('games'),
        '/dictionary': (_) => page('dictionary'),
        '/translator': (_) => page('translator'),
        '/chat': (context) =>
            page('chat ${ModalRoute.of(context)!.settings.arguments ?? ''}'),
        '/settings': (_) => page('settings'),
      },
    );
  }

  final button = find.byKey(const Key('sections-button'));
  final menu = find.byKey(const Key('sections-menu'));

  Future<void> open(WidgetTester tester) async {
    await tester.tap(button);
    await tester.pumpAndSettle();
  }

  testWidgets('sits at the bottom right above page bars, round and small', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(400, 800));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(app());
    final rect = tester.getRect(button);
    expect(rect.width, rect.height);
    expect(rect.width, lessThanOrEqualTo(60));
    expect(rect.right, greaterThan(400 - 40));
    expect(rect.bottom, greaterThan(800 - 140));
    expect(rect.bottom, lessThan(800 - 72));
  });

  testWidgets('menu: Home first, then the sections', (tester) async {
    await tester.pumpWidget(app());
    expect(menu, findsNothing);
    await open(tester);
    expect(menu, findsOneWidget);
    double? last;
    for (final k in [
      'home',
      'language',
      'games',
      'dictionary',
      'chat',
      'translator',
      'settings',
    ]) {
      final top = tester.getRect(find.byKey(Key('sections-$k'))).top;
      if (last != null) expect(top, greaterThan(last));
      last = top;
    }
  });

  testWidgets('closes on a tap outside, the button, and Back', (tester) async {
    await tester.pumpWidget(app());
    await open(tester);
    await tester.tapAt(const Offset(20, 100));
    await tester.pumpAndSettle();
    expect(menu, findsNothing);

    await open(tester);
    await tester.tap(button);
    await tester.pumpAndSettle();
    expect(menu, findsNothing);

    await open(tester);
    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();
    expect(menu, findsNothing);
    expect(find.text('home page'), findsOneWidget);
  });

  testWidgets('on every page; a row opens its page over home', (tester) async {
    await tester.pumpWidget(app());
    await open(tester);
    await tester.tap(find.byKey(const Key('sections-games')));
    await tester.pumpAndSettle();
    expect(find.text('games page'), findsOneWidget);
    expect(menu, findsNothing);

    // Still there on the games page; from there to settings.
    await open(tester);
    await tester.tap(find.byKey(const Key('sections-settings')));
    await tester.pumpAndSettle();
    expect(find.text('settings page'), findsOneWidget);

    // Back goes home (the games page isn't kept under it).
    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();
    expect(find.text('home page'), findsOneWidget);

    await tester.tap(button);
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('sections-games')));
    await tester.pumpAndSettle();
    await open(tester);
    await tester.tap(find.byKey(const Key('sections-home')));
    await tester.pumpAndSettle();
    expect(find.text('home page'), findsOneWidget);
    expect(find.text('games page'), findsNothing);
  });

  testWidgets("the menu's Chat with AI opens the floating chat, not the "
      'page', (tester) async {
    await tester.pumpWidget(app());
    await open(tester);
    await tester.tap(find.byKey(const Key('sections-chat')));
    await tester.pumpAndSettle();
    expect(find.text('home page'), findsOneWidget);
    expect(find.byKey(const Key('chat-window')), findsOneWidget);
    // The teacher speaks first.
    expect(ChatSession.instance.messages.first.text, startsWith('Hello! '));
  });

  testWidgets('the floating chat grows with the conversation, up to about '
      'two thirds of the screen', (tester) async {
    await tester.binding.setSurfaceSize(const Size(400, 800));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(app());
    await open(tester);
    await tester.tap(find.byKey(const Key('sections-chat')));
    await tester.pumpAndSettle();
    final window = find.byKey(const Key('chat-window'));
    final first = tester.getRect(window).height;
    expect(first, lessThan(800 * 0.4));

    double last = first;
    for (var i = 0; i < 8; i++) {
      await tester.enterText(
        find.byKey(const Key('chat-window-input')),
        'Message number $i, a little longer so that it wraps onto two lines',
      );
      await tester.tap(find.byKey(const Key('chat-window-send')));
      await tester.pumpAndSettle();
      final h = tester.getRect(window).height;
      expect(h, greaterThanOrEqualTo(last));
      last = h;
    }
    expect(last, greaterThan(first + 100));
    expect(last, lessThanOrEqualTo(800 * 0.67 + 1));
  });

  testWidgets('shrinks while the menu is open', (tester) async {
    await tester.pumpWidget(app());
    final closed = tester.getRect(button).width;
    await open(tester);
    expect(tester.getRect(button).width, lessThan(closed * 0.85));
    await tester.tap(button);
    await tester.pumpAndSettle();
    expect(tester.getRect(button).width, closed);
  });

  testWidgets('dragged to the top left, the menu opens below it', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(400, 800));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(app());
    await tester.drag(button, const Offset(-600, -900));
    await tester.pumpAndSettle();
    final at = tester.getRect(button);
    expect(at.left, lessThan(40));
    expect(at.top, lessThan(80));

    await open(tester);
    final rect = tester.getRect(menu);
    expect(rect.top, greaterThan(at.bottom));
    expect(rect.left, closeTo(at.left, 1));
  });

  testWidgets('hides while a sheet is up', (tester) async {
    await tester.pumpWidget(app());
    showModalBottomSheet<void>(
      context: tester.element(find.text('home page')),
      builder: (_) => const SizedBox(height: 200, child: Text('sheet')),
    );
    await tester.pumpAndSettle();
    expect(button, findsNothing);
    Navigator.of(tester.element(find.text('sheet'))).pop();
    await tester.pumpAndSettle();
    expect(button, findsOneWidget);
  });

  group('teacher cloud', () {
    final cloud = find.byKey(const Key('teacher-cloud'));

    setUp(() => SectionsButton.teacherCloud = true);

    testWidgets('shows on home after a moment, above the button', (
      tester,
    ) async {
      await tester.pumpWidget(app());
      expect(cloud, findsNothing);
      await tester.pump(const Duration(seconds: 2));
      await tester.pump();
      expect(cloud, findsOneWidget);
      expect(find.text('Hello!'), findsOneWidget);
      expect(
        tester.getRect(cloud).bottom,
        lessThan(tester.getRect(button).top),
      );
    });

    testWidgets('goes away by itself after 4 seconds', (tester) async {
      await tester.pumpWidget(app());
      await tester.pump(const Duration(seconds: 2));
      await tester.pump();
      expect(cloud, findsOneWidget);
      await tester.pump(const Duration(milliseconds: 3900));
      expect(cloud, findsOneWidget);
      await tester.pump(const Duration(milliseconds: 200));
      await tester.pump();
      expect(cloud, findsNothing);
    });

    testWidgets('a chat box under the message, as wide as the cloud; '
        'writing keeps the cloud, sending opens the window', (tester) async {
      await tester.pumpWidget(app());
      await tester.pump(const Duration(seconds: 2));
      await tester.pump();
      final box = find.byKey(const Key('teacher-cloud-input'));
      expect(box, findsOneWidget);
      final cloudRect = tester.getRect(cloud);
      final boxRect = tester.getRect(box);
      expect(
        boxRect.top,
        greaterThan(tester.getRect(find.text('Hello!')).bottom),
      );
      expect(boxRect.width, greaterThan(cloudRect.width * 0.65));

      await tester.enterText(box, 'Hi!');
      // Typing: it doesn't go away.
      await tester.pump(const Duration(seconds: 6));
      expect(cloud, findsOneWidget);

      await tester.tap(find.byKey(const Key('teacher-cloud-send')));
      await tester.pumpAndSettle();
      expect(cloud, findsNothing);
      expect(find.byKey(const Key('chat-window')), findsOneWidget);
      final messages = ChatSession.instance.messages;
      expect(messages.first.text, startsWith('Hello! '));
      expect(messages[1], (mine: true, text: 'Hi!'));
    });

    testWidgets('in the main language, the secondary one under it; no AI '
        'yet: the offer to download it', (tester) async {
      await AppSettings.instance.setSecondaryLanguage('el');
      addTearDown(() => AppSettings.instance.setSecondaryLanguage(null));
      await tester.pumpWidget(app());
      await tester.pump(const Duration(seconds: 2));
      await tester.pump();
      expect(find.text('Hello!'), findsOneWidget);
      expect(find.textContaining('download the AI'), findsOneWidget);
      final under = tester.widget<Text>(
        find.byKey(const Key('teacher-cloud-translation')),
      );
      expect(under.data, startsWith('Γεια σου! '));
    });

    testWidgets('tapped, it becomes a chat window over the button', (
      tester,
    ) async {
      await tester.pumpWidget(app());
      await tester.pump(const Duration(seconds: 2));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Hello!'));
      await tester.pumpAndSettle();
      final window = find.byKey(const Key('chat-window'));
      expect(window, findsOneWidget);
      expect(cloud, findsNothing);
      expect(
        tester.getRect(window).bottom,
        lessThan(tester.getRect(button).top),
      );
      // The teacher spoke first.
      expect(ChatSession.instance.messages.first.text, startsWith('Hello! '));

      // Writing works (no AI on in tests: the note where to turn one on).
      await tester.enterText(
        find.byKey(const Key('chat-window-input')),
        'Hi teacher',
      );
      await tester.tap(find.byKey(const Key('chat-window-send')));
      await tester.pumpAndSettle();
      expect(ChatSession.instance.messages, hasLength(3));
      expect(ChatSession.instance.messages[1].text, 'Hi teacher');
      expect(find.byKey(const Key('chat-window')), findsOneWidget);
    });

    testWidgets('the window stays on other pages; folded away, no cloud', (
      tester,
    ) async {
      await tester.pumpWidget(app());
      await tester.pump(const Duration(seconds: 2));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Hello!'));
      await tester.pumpAndSettle();
      final window = find.byKey(const Key('chat-window'));

      // Hidden while the menu is open, back on the next page.
      await open(tester);
      expect(window, findsNothing);
      await tester.tap(find.byKey(const Key('sections-games')));
      await tester.pumpAndSettle();
      expect(find.text('games page'), findsOneWidget);
      expect(window, findsOneWidget);

      // Folded away: the cloud doesn't come back.
      await tester.tap(find.byKey(const Key('chat-window-minimize')));
      await tester.pumpAndSettle();
      expect(window, findsNothing);
      expect(cloud, findsNothing);
      await tester.pump(const Duration(seconds: 10));
      expect(cloud, findsNothing);
    });

    testWidgets('expand: the same conversation on the full page', (
      tester,
    ) async {
      await tester.pumpWidget(app());
      await tester.pump(const Duration(seconds: 2));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Hello!'));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('chat-window-expand')));
      await tester.pumpAndSettle();
      expect(find.textContaining(RegExp(r'^chat .*page$')), findsOneWidget);
      // Neither window nor cloud over the full chat.
      expect(find.byKey(const Key('chat-window')), findsNothing);
      expect(cloud, findsNothing);
      await tester.binding.handlePopRoute();
      await tester.pumpAndSettle();
      expect(cloud, findsOneWidget);
    });

    testWidgets('X closes it; it hides while the menu is open', (tester) async {
      await tester.pumpWidget(app());
      await tester.pump(const Duration(seconds: 2));
      await tester.pumpAndSettle();
      await open(tester);
      expect(cloud, findsNothing);
      await tester.tap(button);
      await tester.pumpAndSettle();
      expect(cloud, findsOneWidget);

      await tester.tap(find.byKey(const Key('teacher-cloud-close')));
      await tester.pumpAndSettle();
      expect(cloud, findsNothing);
    });
  });

  testWidgets("the menu's Language opens the language list from the bottom", (
    tester,
  ) async {
    await tester.pumpWidget(app());
    await open(tester);
    await tester.tap(find.byKey(const Key('sections-language')));
    await tester.pumpAndSettle();
    expect(menu, findsNothing);
    expect(find.text('home page'), findsOneWidget);
    expect(find.byType(BottomSheet), findsOneWidget);
    expect(find.text('English'), findsWidgets);
  });

  testWidgets('on a short screen the menu fits and scrolls', (tester) async {
    await tester.binding.setSurfaceSize(const Size(400, 460));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(app());
    await open(tester);
    final rect = tester.getRect(menu);
    expect(rect.top, greaterThanOrEqualTo(0));
    expect(rect.bottom, lessThan(tester.getRect(button).top));
    // The last row is reached by scrolling.
    final settings = find.byKey(const Key('sections-settings'));
    expect(tester.getRect(settings).bottom, greaterThan(rect.bottom));
    await tester.drag(
      find.byKey(const Key('sections-menu-scroll')),
      const Offset(0, -300),
    );
    await tester.pumpAndSettle();
    await tester.tap(settings);
    await tester.pumpAndSettle();
    expect(find.text('settings page'), findsOneWidget);
  });

  for (final name in ['dictionary', 'translator']) {
    testWidgets("the menu's ${name[0].toUpperCase()}${name.substring(1)} "
        'opens as a sheet over the page', (tester) async {
      await tester.binding.setSurfaceSize(const Size(400, 900));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      await tester.pumpWidget(app());
      await open(tester);
      await tester.tap(find.byKey(Key('sections-$name')));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));
      expect(menu, findsNothing);
      // Over the home page, not instead of it.
      expect(find.text('$name page'), findsNothing);
      expect(find.text('home page'), findsOneWidget);
      expect(find.byType(BottomSheet), findsOneWidget);
    });
  }
}
