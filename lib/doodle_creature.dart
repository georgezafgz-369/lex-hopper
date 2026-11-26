// ─────────────────────────────────────────────────────────────────────────────
// DOODLE CREATURE — the round button's little shape-shifter
// ─────────────────────────────────────────────────────────────────────────────
//
// A hand-cut ink blob with eyes that keeps changing shape: a six-petal
// flower and a soft seven-point star (one almond eye), a scribbly fuzz-ball
// and a round blob face (two eyes), a many-petalled daisy and a sun with
// wavy rays (one round eye), a ten-point burst (an "evil eye"), a tall
// hood and a mushroom (one eye), a cat and an amoeba (two eyes). It blinks, glances around, morphs by
// itself every few seconds, blooms into the flower while the menu is open
// and turns into a jittering fuzz-ball while the AI is thinking.

import 'dart:math' as math;

import 'package:flutter/scheduler.dart';
import 'package:material_ui/material_ui.dart';

import 'design_system.dart';

/// The creature's shapes.
enum CreatureShape {
  flower,
  star,
  fuzz,
  blob,
  daisy,
  sun,
  burst,
  hood,
  cat,
  mushroom,
  amoeba,
}

/// One of the creature's eyes: where it sits ([x], [y] from the middle),
/// how wide and tall, all as shares of the full radius; [round] (else an
/// almond), [ringed] (an "evil eye" ring round the pupil).
class CreatureEye {
  final double x, y, w, h;
  final bool round, ringed;
  const CreatureEye(
    this.x,
    this.y,
    this.w,
    this.h, {
    this.round = false,
    this.ringed = false,
  });
}

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
      colours: creatureColours(Theme.of(context).brightness),
    ),
  );
}

/// Each shape's colour, from the app's palette: light and cheerful.
Map<CreatureShape, Color> creatureColours(Brightness b) {
  Color c(Color light, Color dark) => b.resolve(light: light, dark: dark);
  final rose = c(AppColors.roseLight, AppColors.roseDark);
  final marigold = c(AppColors.marigoldLight, AppColors.marigoldDark);
  final cornflower = c(AppColors.cornflowerLight, AppColors.cornflowerDark);
  final fern = c(AppColors.fernLight, AppColors.fernDark);
  final coral = c(AppColors.coralLight, AppColors.coralDark);
  final clay = c(AppColors.claySoftLight, AppColors.claySoftDark);
  return {
    CreatureShape.flower: rose,
    CreatureShape.star: marigold,
    CreatureShape.fuzz: cornflower,
    CreatureShape.blob: fern,
    CreatureShape.daisy: marigold,
    CreatureShape.sun: clay,
    CreatureShape.burst: coral,
    CreatureShape.hood: fern,
    CreatureShape.cat: cornflower,
    CreatureShape.mushroom: coral,
    CreatureShape.amoeba: rose,
  };
}

/// Paints the creature at [morph] (0–1, a little past 1 while it wobbles)
/// between shapes [from] and [to].
class CreaturePainter extends CustomPainter {
  final CreatureShape from, to;
  final double morph, time, eyeOpen, jitter;
  final Offset look;

  /// [ink] for the pupils and smile, [paper] for the whites of the eyes.
  final Color ink, paper;

  /// Each shape's body colour (null: all [ink]).
  final Map<CreatureShape, Color>? colours;

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
    this.colours,
  });

  /// Its outline's distance from the middle at angle [a] (0 is right, a
  /// quarter turn is down), for [shape], as a share of the full radius.
  /// The wobble terms make it look hand-cut.
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
      case CreatureShape.daisy:
        // Eighteen slim petals, each a little wavy.
        return 0.42 +
            0.5 *
                math.pow(math.cos(9 * a + 0.25 * math.sin(3 * a)).abs(), 1.6) +
            cut * 0.5;
      case CreatureShape.sun:
        // A round middle with wavy rays all round.
        return 0.6 +
            0.36 *
                math.pow(
                  math.max(0.0, math.cos(14 * a + 0.5 * math.sin(4 * a))),
                  10,
                ) +
            cut * 0.4;
      case CreatureShape.burst:
        // Ten sharp points.
        return 0.48 +
            0.5 * math.pow((1 + math.cos(10 * a)) / 2, 3).toDouble() +
            cut * 0.4;
      case CreatureShape.hood:
        // A tall rounded block, a little narrower than tall.
        final x = math.cos(a).abs() / 0.68, y = math.sin(a).abs() / 0.94;
        return 0.97 *
                math.pow(math.pow(x, 4) + math.pow(y, 4), -0.25).toDouble() +
            cut * 0.6;
      case CreatureShape.cat:
        // A long low body, two ears, four legs and a tail to the right.
        final body = math
            .pow(
              math.pow(math.cos(a).abs() / 0.72, 2.6) +
                  math.pow((math.sin(a)).abs() / 0.42, 2.6),
              -1 / 2.6,
            )
            .toDouble();
        return math.min(
          0.98,
          body +
              0.42 * _bump(a, -2.05, 0.09) + // ears
              0.42 * _bump(a, -1.6, 0.09) +
              0.42 * _bump(a, 1.95, 0.06) + // legs
              0.42 * _bump(a, 1.7, 0.06) +
              0.4 * _bump(a, 1.25, 0.06) +
              0.4 * _bump(a, 1.0, 0.06) +
              0.3 * _bump(a, -0.25, 0.08) + // tail
              cut * 0.4,
        );
      case CreatureShape.mushroom:
        // A dome on top, a thin stem below.
        final top = math.sin(a) < 0;
        final cap = 0.82 + 0.06 * math.cos(2 * a);
        return top
            ? cap + cut * 0.4
            : 0.3 + 0.62 * _bump(a, math.pi / 2, 0.16) + cut * 0.3;
      case CreatureShape.amoeba:
        // Round lobes of different sizes, unevenly spread.
        return 0.42 +
            0.5 * _bump(a, 0.3, 0.32) +
            0.42 * _bump(a, 1.5, 0.26) +
            0.52 * _bump(a, 2.6, 0.3) +
            0.36 * _bump(a, 3.7, 0.22) +
            0.48 * _bump(a, 4.6, 0.3) +
            0.4 * _bump(a, 5.6, 0.24) +
            cut;
    }
  }

  /// 1 at angle [centre], fading to 0 over about [width] either side.
  static double _bump(double a, double centre, double width) {
    var d = (a - centre) % (2 * math.pi);
    if (d > math.pi) d -= 2 * math.pi;
    return math.exp(-d * d / (2 * width * width));
  }

  /// Whether it slowly turns (round shapes), or stays upright (the cat,
  /// the mushroom, the hood).
  static double spins(CreatureShape shape) => switch (shape) {
    CreatureShape.cat ||
    CreatureShape.mushroom ||
    CreatureShape.hood ||
    CreatureShape.blob => 0,
    _ => 1,
  };

  /// Its eyes: where (as shares of the full radius from the middle), how
  /// wide and tall, and their style.
  static List<CreatureEye> eyesOf(CreatureShape shape) => switch (shape) {
    CreatureShape.flower ||
    CreatureShape.star => const [CreatureEye(0, 0, 0.62, 0.34)],
    CreatureShape.fuzz || CreatureShape.blob => const [
      CreatureEye(-0.3, -0.04, 0.34, 0.26),
      CreatureEye(0.3, -0.04, 0.34, 0.26),
    ],
    CreatureShape.daisy ||
    CreatureShape.sun => const [CreatureEye(0, 0, 0.42, 0.42, round: true)],
    CreatureShape.burst => const [
      CreatureEye(0, 0, 0.5, 0.5, round: true, ringed: true),
    ],
    CreatureShape.hood => const [CreatureEye(0, -0.4, 0.42, 0.22)],
    CreatureShape.cat => const [
      CreatureEye(-0.48, -0.02, 0.26, 0.26, round: true),
      CreatureEye(-0.16, -0.02, 0.26, 0.26, round: true),
    ],
    CreatureShape.mushroom => const [CreatureEye(0, -0.42, 0.44, 0.24)],
    CreatureShape.amoeba => const [
      CreatureEye(-0.12, -0.12, 0.22, 0.22, round: true),
      CreatureEye(0.22, 0.02, 0.18, 0.18, round: true),
    ],
  };

  /// How many eyes a shape has.
  static double twoEyes(CreatureShape shape) =>
      eyesOf(shape).length > 1 ? 1 : 0;

  double _lerp(double a, double b) => a + (b - a) * morph;

  @override
  void paint(Canvas canvas, Size size) {
    final c = size.center(Offset.zero);
    final full = size.shortestSide / 2;
    // A slow turn, so round shapes' petals and points drift round.
    final turn = time * 0.15 * _lerp(spins(from), spins(to));

    final outline = Path();
    const n = 180;
    for (var k = 0; k <= n; k++) {
      final a = k / n * 2 * math.pi;
      var r = _lerp(radius(from, a - turn, time), radius(to, a - turn, time));
      // Thinking: the outline shivers.
      r += jitter * 0.03 * math.sin(23 * a + time * 30);
      final p = c + Offset(math.cos(a), math.sin(a)) * (r * full);
      k == 0 ? outline.moveTo(p.dx, p.dy) : outline.lineTo(p.dx, p.dy);
    }
    outline.close();

    // Its colour, blending into the next shape's as it morphs.
    final m0 = morph.clamp(0.0, 1.0);
    final body = colours == null
        ? ink
        : Color.lerp(colours![from], colours![to], m0)!;
    canvas.drawShadow(outline, Colors.black26, 2, false);
    canvas.drawPath(outline, Paint()..color = body);

    // ── Eyes: the old shape's fade out as the new shape's fade in ────────
    final m = morph.clamp(0.0, 1.0);
    if (from != to && m < 1) {
      for (final e in eyesOf(from)) {
        _eye(canvas, c, full, e, 1 - m);
      }
    }
    for (final e in eyesOf(to)) {
      _eye(canvas, c, full, e, from == to ? 1 : m);
    }
    // A smile and rosy cheeks under the eyes (fading with them).
    if (from != to && m < 1) _face(canvas, c, full, eyesOf(from), 1 - m);
    _face(canvas, c, full, eyesOf(to), from == to ? 1 : m);
  }

  /// A small smile (an "o" while thinking) and two pink cheeks, under
  /// [eyes].
  void _face(
    Canvas canvas,
    Offset c,
    double full,
    List<CreatureEye> eyes,
    double alpha,
  ) {
    if (alpha <= 0) return;
    final x = eyes.map((e) => e.x).reduce((a, b) => a + b) / eyes.length;
    final y = eyes.map((e) => e.y + e.h / 2).reduce(math.max) + 0.12;
    final w = math.max(0.16, eyes.length > 1 ? 0.22 : e0(eyes).w * 0.38);
    final mouth = c + Offset(x, y) * full;
    final line = Paint()
      ..color = ink.withValues(alpha: alpha)
      ..style = PaintingStyle.stroke
      ..strokeWidth = full * 0.06
      ..strokeCap = StrokeCap.round;
    if (jitter > 0) {
      canvas.drawCircle(mouth + Offset(0, full * 0.03), full * 0.045, line);
    } else {
      canvas.drawArc(
        Rect.fromCenter(center: mouth, width: w * full, height: w * full * 0.7),
        0.15 * math.pi,
        0.7 * math.pi,
        false,
        line,
      );
    }
    final cheek = Paint()
      ..color = const Color(0xFFFF8FA3).withValues(alpha: 0.55 * alpha);
    for (final side in [-1.0, 1.0]) {
      canvas.drawOval(
        Rect.fromCenter(
          center: mouth + Offset(side * (w * 0.5 + 0.12) * full, -full * 0.02),
          width: full * 0.14,
          height: full * 0.09,
        ),
        cheek,
      );
    }
  }

  static CreatureEye e0(List<CreatureEye> eyes) => eyes.first;

  /// Draws [e] at [c] (the middle; [full] the radius), its pupil looking
  /// along [look]; [eyeOpen] squeezes it shut; [alpha] fades it.
  void _eye(Canvas canvas, Offset c, double full, CreatureEye e, double alpha) {
    if (alpha <= 0) return;
    final at = c + Offset(e.x, e.y) * full;
    final w = e.w * full, h = e.h * full;
    final open = h / 2 * math.max(0.06, eyeOpen);
    final white = e.round
        ? (Path()
            ..addOval(Rect.fromCenter(center: at, width: w, height: 2 * open)))
        : (Path()
            ..moveTo(at.dx - w / 2, at.dy)
            ..quadraticBezierTo(at.dx, at.dy - 2 * open, at.dx + w / 2, at.dy)
            ..quadraticBezierTo(at.dx, at.dy + 2 * open, at.dx - w / 2, at.dy)
            ..close());
    canvas.drawPath(white, Paint()..color = paper.withValues(alpha: alpha));
    if (eyeOpen < 0.25) return;
    canvas.save();
    canvas.clipPath(white);
    final pupil = at + Offset(look.dx * w * 0.18, look.dy * open * 0.4);
    final inkA = ink.withValues(alpha: alpha);
    if (e.ringed) {
      // An "evil eye": a ring of ink round a white circle and the pupil.
      canvas.drawCircle(
        pupil,
        w * 0.3,
        Paint()
          ..color = inkA
          ..style = PaintingStyle.stroke
          ..strokeWidth = w * 0.08,
      );
    }
    final pr = math.min(w, h) * (e.round ? 0.24 : 0.18);
    canvas.drawCircle(pupil, pr, Paint()..color = inkA);
    // A sparkle: it looks bright and happy.
    canvas.drawCircle(
      pupil + Offset(-pr * 0.35, -pr * 0.38),
      pr * 0.32,
      Paint()..color = Colors.white.withValues(alpha: alpha),
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
      old.paper != paper ||
      old.colours != colours;
}
