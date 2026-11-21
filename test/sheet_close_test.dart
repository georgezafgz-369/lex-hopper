// The word page sheet stays at any height from a quarter of the screen up;
// pulling it on down from there closes it, but a short pull springs back.

import 'package:flutter_test/flutter_test.dart';
import 'package:lex_hopper/word_sheet.dart';
import 'package:material_ui/material_ui.dart';

void main() {
  Future<void> openSheet(WidgetTester tester) async {
    await tester.binding.setSurfaceSize(const Size(400, 800));
    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) => Scaffold(
            body: Center(
              child: TextButton(
                onPressed: () => showDraggableSheet(
                  context,
                  builder: (scroll) => ListView(
                    controller: scroll,
                    children: [for (var i = 0; i < 30; i++) Text('Line $i')],
                  ),
                ),
                child: const Text('Open'),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('Open'));
    await tester.pumpAndSettle();
    expect(find.text('Line 0'), findsOneWidget);
  }

  /// The drag handle: the top bar, left of the X.
  Offset handle(WidgetTester tester) =>
      tester.getCenter(find.byIcon(Icons.close)) - const Offset(150, 0);

  double sheetTop(WidgetTester tester) =>
      tester.getTopLeft(find.byType(DraggableScrollableSheet)).dy;

  testWidgets('a short pull below the smallest size springs back', (
    tester,
  ) async {
    await openSheet(tester);
    // Opens at 60% (480 high); down to about the smallest size (a quarter
    // of 800 = 200 high).
    await tester.timedDragFrom(
      handle(tester),
      const Offset(0, 275),
      const Duration(seconds: 1),
    );
    await tester.pumpAndSettle();
    expect(sheetTop(tester), lessThan(600));
    // A little further, slowly: it comes back and stays open.
    await tester.timedDragFrom(
      handle(tester),
      const Offset(0, 30),
      const Duration(seconds: 1),
    );
    await tester.pumpAndSettle();
    expect(find.text('Line 0'), findsOneWidget);
    // Back at the smallest size: a quarter of the 800-high screen.
    expect(sheetTop(tester), closeTo(600, 1));
  });

  testWidgets('pulling it right down closes it', (tester) async {
    await openSheet(tester);
    await tester.timedDragFrom(
      handle(tester),
      const Offset(0, 650),
      const Duration(seconds: 1),
    );
    await tester.pumpAndSettle();
    expect(find.text('Line 0'), findsNothing);
  });

  testWidgets('a flick down from the smallest size closes it', (tester) async {
    await openSheet(tester);
    await tester.timedDragFrom(
      handle(tester),
      const Offset(0, 275),
      const Duration(seconds: 1),
    );
    await tester.pumpAndSettle();
    expect(find.text('Line 0'), findsOneWidget);
    await tester.fling(
      find.byIcon(Icons.close).first,
      const Offset(0, 60),
      1500,
    );
    await tester.pumpAndSettle();
    expect(find.text('Line 0'), findsNothing);
  });
}
