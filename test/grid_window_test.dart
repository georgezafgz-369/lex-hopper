// A grid too big for the screen keeps squares of a readable size inside a
// window that can be dragged around (and pinch-zoomed); picking a clue whose
// squares are out of view moves the window to them.

import 'package:flutter_test/flutter_test.dart';
import 'package:lex_hopper/crossword_game_page.dart';
import 'package:lex_hopper/crossword_puzzle.dart';
import 'package:material_ui/material_ui.dart';
import 'package:shared_preferences/shared_preferences.dart';

CrosswordPuzzle bigPuzzle(int size) => CrosswordPuzzle.fromEntries(
  level: 1,
  size: size,
  entries: [
    PuzzleEntry(
      word: 'ABCDEFGHIJKLM'.substring(0, size),
      clue: 'Top row',
      row: 0,
      col: 0,
      across: true,
    ),
    PuzzleEntry(
      word: 'MNOPQRSTUVWXY'.substring(0, size),
      clue: 'Right column',
      row: 0,
      col: size - 1,
      across: false,
    ),
  ],
);

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  Future<void> pump(
    WidgetTester tester,
    int size, {
    Size screen = const Size(400, 1400),
  }) async {
    await tester.binding.setSurfaceSize(screen);
    await tester.pumpWidget(
      MaterialApp(home: CrosswordGamePage(puzzle: bigPuzzle(size))),
    );
    await tester.pump();
  }

  Offset translation(WidgetTester tester) {
    final viewer = tester.widget<InteractiveViewer>(
      find.byType(InteractiveViewer),
    );
    final t = viewer.transformationController!.value.getTranslation();
    return Offset(t.x, t.y);
  }

  testWidgets('a grid that fits the screen has no window', (tester) async {
    await pump(tester, 7);
    expect(find.byKey(const Key('grid-window')), findsNothing);
  });

  testWidgets('a big grid can be dragged around', (tester) async {
    await pump(tester, 13);
    expect(find.byKey(const Key('grid-window')), findsOneWidget);
    expect(translation(tester), Offset.zero);

    await tester.drag(
      find.byKey(const Key('grid-window')),
      const Offset(-150, -100),
    );
    await tester.pumpAndSettle();
    final moved = translation(tester);
    expect(moved.dx, lessThan(0));
    expect(moved.dy, lessThan(0));
  });

  testWidgets('on a page that scrolls, dragging the grid moves the grid', (
    tester,
  ) async {
    // A short screen, so the page itself can scroll too.
    await pump(tester, 13, screen: const Size(400, 800));
    final window = find.byKey(const Key('grid-window'));
    final before = tester.getTopLeft(window);
    await tester.drag(window, const Offset(-150, -100));
    await tester.pumpAndSettle();
    expect(translation(tester).dx, lessThan(0));
    expect(translation(tester).dy, lessThan(0));
    // The page stayed where it was.
    expect(tester.getTopLeft(window), before);
  });

  testWidgets('picking a clue out of view moves the window to it', (
    tester,
  ) async {
    await pump(tester, 13);
    await tester.tap(find.textContaining('DOWN').first);
    await tester.pump();
    await tester.tap(find.text('Right column'));
    await tester.pump();
    await tester.pump();
    // The right column (x ≈ 482) was off the 368-wide window; now the
    // whole column (13 squares) is inside it.
    final m = tester
        .widget<InteractiveViewer>(find.byType(InteractiveViewer))
        .transformationController!
        .value;
    final scale = m.getMaxScaleOnAxis();
    final t = m.getTranslation();
    final window = tester.getSize(find.byKey(const Key('grid-window')));
    expect((2 + 13 * 40) * scale + t.x, lessThanOrEqualTo(window.width));
    expect(2 * scale + t.y, greaterThanOrEqualTo(0));
    expect((2 + 13 * 40) * scale + t.y, lessThanOrEqualTo(window.height));
  });

  testWidgets('double-tapping a clue scrolls back up to the grid', (
    tester,
  ) async {
    await pump(tester, 13, screen: const Size(400, 600));
    final page = find.byKey(const Key('crossword-page-scroll'));
    // Scrolled down to the clues.
    final scroll = tester.widget<SingleChildScrollView>(page).controller!;
    scroll.jumpTo(scroll.position.maxScrollExtent);
    await tester.pump();
    expect(scroll.offset, greaterThan(0));

    await tester.tap(find.text('Top row'));
    await tester.pump(const Duration(milliseconds: 100));
    await tester.tap(find.text('Top row'));
    await tester.pumpAndSettle();
    expect(scroll.offset, 0);
  });

  testWidgets('picking a clue shows every square of its word', (tester) async {
    await pump(tester, 13);
    // The top row has 13 squares of 40 (520 wide), more than the window
    // (368): picking its clue zooms out just enough to show all of it.
    await tester.tap(find.text('Top row'));
    await tester.pump();
    await tester.pump();
    final viewer = tester.widget<InteractiveViewer>(
      find.byType(InteractiveViewer),
    );
    final m = viewer.transformationController!.value;
    final scale = m.getMaxScaleOnAxis();
    expect(scale, lessThan(1));
    final window = tester.getSize(find.byKey(const Key('grid-window')));
    final left = 2 * scale + m.getTranslation().x;
    final right = (2 + 13 * 40) * scale + m.getTranslation().x;
    expect(left, greaterThanOrEqualTo(0));
    expect(right, lessThanOrEqualTo(window.width));
  });
}
