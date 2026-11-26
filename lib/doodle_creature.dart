// ─────────────────────────────────────────────────────────────────────────────
// DOODLE CREATURE — the round button's little shape-shifter
// ─────────────────────────────────────────────────────────────────────────────
//
// A hand-cut ink blob with eyes that keeps changing shape: a six-petal
// flower and a soft seven-point star (one almond eye), a scribbly fuzz-ball
// and a round blob face (two eyes). It blinks, glances around, morphs by
// itself every few seconds, blooms into the flower while the menu is open
// and turns into a jittering fuzz-ball while the AI is thinking.

import 'dart:math' as math;

import 'package:flutter/scheduler.dart';
import 'package:material_ui/material_ui.dart';

/// The creature's shapes.
enum CreatureShape { flower, star, fuzz, blob }

class DoodleCreature extends StatefulWidget {
  /// The menu is open: it becomes the flower.
  final bool open;

  /// The AI is writing: it becomes the fuzz-ball and jitters.
  final bool thinking;

  /// Its ink, and the colour of the whites of its eyes.
  final Color ink, paper;

  /// Moving (blinking, glancing, morphing); off in tests, where it stays
  /// still as the flower.
  final bool alive;

  const DoodleCreature({
    super.key,
    required this.open,
    required this.thinking,
    required this.ink,
    required this.paper,
    this.alive = true,
  });

  @override
  State<DoodleCreature> createState() => _DoodleCreatureState();
}

class _DoodleCreatureState extends State<DoodleCreature>
    with SingleTickerProviderStateMixin {
  final _random = math.Random();
  late final Ticker _ticker = createTicker(_tick);

  /// Seconds since it started.
  double _now = 0;

  // The morph: from one shape to another, starting at [_morphStart].
  CreatureShape _from = CreatureShape.flower, _to = CreatureShape.flower;
  double _morphStart = -10;
  static const _morphTime = 0.9;

  // The next shape change by itself, blink and glance.
  double _nextShift = 6, _nextBlink = 2.5, _blinkAt = -10;
  double _nextGlance = 3;
  Offset _look = Offset.zero, _lookFrom = Offset.zero;
  double _lookAt = -10;

  @override
  void initState() {
    super.initState();
    _settle(force: true);
    if (widget.alive) _ticker.start();
  }

  @override
  void didUpdateWidget(DoodleCreature old) {
    super.didUpdateWidget(old);
    if (old.open != widget.open || old.thinking != widget.thinking) _settle();
  }

  @override
  void dispose() {
    _ticker.dispose();
    super.dispose();
  }

  /// The shape the state asks for: the flower while the menu is open, the
  /// fuzz-ball while the AI thinks.
  void _settle({bool force = false}) {
    final want = widget.open
        ? CreatureShape.flower
        : widget.thinking
        ? CreatureShape.fuzz
        : null;
    if (want != null && (want != _to || force)) _morphTo(want);
    _nextShift = _now + 6 + _random.nextDouble() * 4;
  }

  void _morphTo(CreatureShape shape) {
    _from = _shapeNow();
    _to = shape;
    _morphStart = _now;
  }

  /// The shape it's closest to right now (to morph on from).
  CreatureShape _shapeNow() => _morph < 0.5 ? _from : _to;

  double get _morph =>
      ((_now - _morphStart) / _morphTime).clamp(0.0, 1.0).toDouble();

  void _tick(Duration elapsed) {
    _now = elapsed.inMicroseconds / 1e6;
    // By itself, now and then (not while the menu or the AI holds it).
    if (!widget.open && !widget.thinking && _now >= _nextShift) {
      final others = CreatureShape.values.where((s) => s != _to).toList();
      _morphTo(others[_random.nextInt(others.length)]);
      _nextShift = _now + 6 + _random.nextDouble() * 4;
    }
    if (_now >= _nextBlink) {
      _blinkAt = _now;
      _nextBlink = _now + 2.5 + _random.nextDouble() * 3.5;
    }
    if (_now >= _nextGlance) {
      _lookFrom = _lookNow;
      _lookAt = _now;
      // Mostly straight ahead, now and then a glance aside.
      _look = _random.nextDouble() < 0.4
          ? Offset.zero
          : Offset(
              _random.nextDouble() * 2 - 1,
              (_random.nextDouble() * 2 - 1) * 0.6,
            );
      _nextGlance = _now + 1.5 + _random.nextDouble() * 2.5;
    }
    setState(() {});
  }

  Offset get _lookNow {
    final t = ((_now - _lookAt) / 0.25).clamp(0.0, 1.0).toDouble();
    return Offset.lerp(_lookFrom, _look, Curves.easeOut.transform(t))!;
  }

  /// 1 open, 0 shut: a blink takes 0.16 s.
  double get _eyeOpen {
    final t = _now - _blinkAt;
    if (t < 0 || t > 0.16) return 1;
    return (t - 0.08).abs() / 0.08;
  }

  @override
  Widget build(BuildContext context) => CustomPaint(
    painter: CreaturePainter(
      from: _from,
      to: _to,
      // A little overshoot: it wobbles into its new shape.
      morph: Curves.easeOutBack.transform(_morph),
      time: _now,
      eyeOpen: widget.open ? 1 : _eyeOpen,
      look: widget.thinking ? const Offset(0.6, -0.8) : _lookNow,
      jitter: widget.thinking ? 1 : 0,
      ink: widget.ink,
      paper: widget.paper,
    ),
  );
}

/// Paints the creature at [morph] (0–1, a little past 1 while it wobbles)
/// between shapes [from] and [to].
class CreaturePainter extends CustomPainter {
  final CreatureShape from, to;
  final double morph, time, eyeOpen, jitter;
  final Offset look;
  final Color ink, paper;

  const CreaturePainter({
    required this.from,
    required this.to,
    required this.morph,
    required this.time,
    required this.eyeOpen,
    required this.look,
    required this.jitter,
    required this.ink,
    required this.paper,
  });

  /// Its outline's distance from the middle at angle [a], for [shape], as
  /// a share of the full radius. The wobble terms make it look hand-cut.
  static double radius(CreatureShape shape, double a, double time) {
    final cut = 0.025 * math.sin(5 * a + 2) + 0.02 * math.sin(9 * a + 0.7);
    switch (shape) {
      case CreatureShape.flower:
        // Six round petals with deep notches between them.
        return 0.48 + 0.46 * math.pow(math.cos(3 * a).abs(), 0.55) + cut;
      case CreatureShape.star:
        // Seven soft points.
        return 0.56 +
            0.38 * math.pow((1 + math.cos(7 * a)) / 2, 1.5).toDouble() +
            cut;
      case CreatureShape.fuzz:
        // Scribbly: many small bumps, a few spikes.
        return 0.7 +
            0.09 * math.sin(11 * a + 1) +
            0.06 * math.sin(17 * a + 3) +
            0.1 * math.pow(math.max(0.0, math.sin(5 * a + 1)), 8) +
            cut;
      case CreatureShape.blob:
        return 0.86 + 0.05 * math.sin(2 * a + 1) + cut;
    }
  }

  /// How many eyes a shape has: the flower and star one, the others two.
  static double twoEyes(CreatureShape shape) =>
      shape == CreatureShape.flower || shape == CreatureShape.star ? 0 : 1;

  double _lerp(double a, double b) => a + (b - a) * morph;

  @override
  void paint(Canvas canvas, Size size) {
    final c = size.center(Offset.zero);
    final full = size.shortestSide / 2;
    // A slow turn, so its petals and points drift round.
    final turn = time * 0.15;

    final outline = Path();
    const n = 144;
    for (var k = 0; k <= n; k++) {
      final a = k / n * 2 * math.pi;
      var r = _lerp(radius(from, a - turn, time), radius(to, a - turn, time));
      // Thinking: the outline shivers.
      r += jitter * 0.03 * math.sin(23 * a + time * 30);
      final p = c + Offset(math.cos(a), math.sin(a)) * (r * full);
      k == 0 ? outline.moveTo(p.dx, p.dy) : outline.lineTo(p.dx, p.dy);
    }
    outline.close();

    canvas.drawShadow(outline, Colors.black54, 3, false);
    canvas.drawPath(outline, Paint()..color = ink);

    // ── Eyes: one big almond, or two smaller ones ────────────────────────
    final two = _lerp(twoEyes(from), twoEyes(to)).clamp(0.0, 1.0);
    if (two < 1) _eye(canvas, c, full * 0.62, full * 0.34, 1 - two);
    if (two > 0) {
      for (final side in [-1.0, 1.0]) {
        _eye(
          canvas,
          c + Offset(side * full * 0.3, -full * 0.04),
          full * 0.34,
          full * 0.26,
          two,
        );
      }
    }
  }

  /// An almond eye [w] wide and [h] tall at [at], its pupil looking along
  /// [look]; [eyeOpen] squeezes it shut; [alpha] fades it in or out.
  void _eye(Canvas canvas, Offset at, double w, double h, double alpha) {
    final open = h * math.max(0.06, eyeOpen);
    final white = Path()
      ..moveTo(at.dx - w / 2, at.dy)
      ..quadraticBezierTo(at.dx, at.dy - open, at.dx + w / 2, at.dy)
      ..quadraticBezierTo(at.dx, at.dy + open, at.dx - w / 2, at.dy)
      ..close();
    canvas.drawPath(
      white,
      Paint()..color = paper.withValues(alpha: alpha.toDouble()),
    );
    if (eyeOpen < 0.25) return;
    canvas.save();
    canvas.clipPath(white);
    final pupil = at + Offset(look.dx * w * 0.2, look.dy * open * 0.25);
    canvas.drawCircle(
      pupil,
      h * 0.36,
      Paint()..color = ink.withValues(alpha: alpha.toDouble()),
    );
    canvas.restore();
  }

  @override
  bool shouldRepaint(CreaturePainter old) =>
      old.morph != morph ||
      old.time != time ||
      old.eyeOpen != eyeOpen ||
      old.look != look ||
      old.jitter != jitter ||
      old.from != from ||
      old.to != to ||
      old.ink != ink ||
      old.paper != paper;
}
