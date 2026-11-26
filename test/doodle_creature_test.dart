// The round button's shape-shifting creature: four shapes, one or two
// eyes, painted at any point of a morph; the flower while the menu is open.

import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter_test/flutter_test.dart';
import 'package:lex_hopper/doodle_creature.dart';
import 'package:material_ui/material_ui.dart';

void main() {
  test('each shape stays inside the button and has its own outline', () {
    for (final shape in CreatureShape.values) {
      for (var k = 0; k < 360; k++) {
        final r = CreaturePainter.radius(shape, k * math.pi / 180, 0);
        expect(r, inInclusiveRange(0.2, 1.0), reason: '$shape at $k°');
      }
    }
    // The flower has deep notches, the blob none.
    double dip(CreatureShape s) => [
      for (var k = 0; k < 360; k++)
        CreaturePainter.radius(s, k * math.pi / 180, 0),
    ].reduce(math.min);
    expect(dip(CreatureShape.flower), lessThan(0.6));
    expect(dip(CreatureShape.blob), greaterThan(0.75));
  });

  test('one eye or two, each shape its own', () {
    for (final s in [
      CreatureShape.flower,
      CreatureShape.star,
      CreatureShape.daisy,
      CreatureShape.sun,
      CreatureShape.burst,
      CreatureShape.hood,
      CreatureShape.mushroom,
    ]) {
      expect(CreaturePainter.eyesOf(s), hasLength(1), reason: '$s');
    }
    for (final s in [
      CreatureShape.fuzz,
      CreatureShape.blob,
      CreatureShape.cat,
      CreatureShape.amoeba,
    ]) {
      expect(CreaturePainter.eyesOf(s), hasLength(2), reason: '$s');
    }
    expect(CreaturePainter.eyesOf(CreatureShape.burst).single.ringed, isTrue);
    // Eyes sit inside the button.
    for (final s in CreatureShape.values) {
      for (final e in CreaturePainter.eyesOf(s)) {
        expect(e.x.abs() + e.w / 2, lessThan(1), reason: '$s');
        expect(e.y.abs() + e.h / 2, lessThan(1), reason: '$s');
      }
    }
  });

  test('the cat, mushroom and hood stay upright; round shapes turn', () {
    expect(CreaturePainter.spins(CreatureShape.cat), 0);
    expect(CreaturePainter.spins(CreatureShape.mushroom), 0);
    expect(CreaturePainter.spins(CreatureShape.hood), 0);
    expect(CreaturePainter.spins(CreatureShape.daisy), 1);
  });

  test('paints at every point of a morph, eyes open or shut', () {
    for (final from in CreatureShape.values) {
      for (final to in CreatureShape.values) {
        for (final morph in [0.0, 0.5, 1.0, 1.1]) {
          final recorder = ui.PictureRecorder();
          CreaturePainter(
            from: from,
            to: to,
            morph: morph,
            time: 1,
            eyeOpen: morph == 0.5 ? 0 : 1,
            look: const Offset(0.5, -0.5),
            jitter: morph == 1.0 ? 1 : 0,
            ink: Colors.black,
            paper: Colors.white,
          ).paint(Canvas(recorder), const Size(58, 58));
          recorder.endRecording().dispose();
        }
      }
    }
  });

  testWidgets('still in tests, and a flower', (tester) async {
    await tester.pumpWidget(
      const Center(
        child: SizedBox.square(
          dimension: 58,
          child: DoodleCreature(
            open: false,
            thinking: false,
            ink: Colors.black,
            paper: Colors.white,
            alive: false,
          ),
        ),
      ),
    );
    final paint = tester.widget<CustomPaint>(
      find.descendant(
        of: find.byType(DoodleCreature),
        matching: find.byType(CustomPaint),
      ),
    );
    final painter = paint.painter! as CreaturePainter;
    expect(painter.to, CreatureShape.flower);
  });
}
