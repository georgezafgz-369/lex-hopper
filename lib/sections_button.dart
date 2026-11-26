// ─────────────────────────────────────────────────────────────────────────────
// SECTIONS BUTTON — the round button at the bottom right of the home page
// ─────────────────────────────────────────────────────────────────────────────
//
// Closed: a hand-drawn dot with rings pulsing out around it. Tapped, the
// rings fade, the dot stays, and a menu of the app's sections pops up
// above it. A tap outside, or Back, closes it.

import 'dart:io' show Platform;
import 'dart:math' as math;

import 'package:material_ui/material_ui.dart';

import 'app_text.dart';
import 'design_system.dart';
import 'dual_text.dart';
import 'section_icon.dart';

/// Fills the page (in a Stack over it); only the button, and the menu while
/// open, take taps.
class SectionsButton extends StatefulWidget {
  const SectionsButton({super.key});

  /// The button's size, for pages that leave room for it.
  static const size = 60.0;

  /// The rings pulse for ever, so widget tests (which wait for animations
  /// to end) see them still.
  static bool pulses = !Platform.environment.containsKey('FLUTTER_TEST');

  @override
  State<SectionsButton> createState() => _SectionsButtonState();
}

class _SectionsButtonState extends State<SectionsButton>
    with TickerProviderStateMixin {
  bool _open = false;

  // The rings' pulse, always running while closed.
  late final _pulse = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 2400),
  );

  @override
  void initState() {
    super.initState();
    if (SectionsButton.pulses) _pulse.repeat();
  }

  // 0 closed, 1 open: fades the rings out and the menu in.
  late final _openness = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 220),
  );

  @override
  void dispose() {
    _pulse.dispose();
    _openness.dispose();
    super.dispose();
  }

  void _toggle() => _setOpen(!_open);

  void _setOpen(bool open) {
    setState(() => _open = open);
    if (open) {
      _openness.forward();
      _pulse.stop();
    } else {
      _openness.reverse();
      if (SectionsButton.pulses) _pulse.repeat();
    }
  }

  void _go(String route) {
    _setOpen(false);
    Navigator.of(context).pushNamed(route);
  }

  @override
  Widget build(BuildContext context) {
    final b = Theme.of(context).brightness;
    final clay = b.resolve(
      light: AppColors.clayLight,
      dark: AppColors.clayDark,
    );
    final card = b.resolve(
      light: AppColors.gridCellLight,
      dark: AppColors.gridCellDark,
    );
    final hairline = b.resolve(
      light: AppColors.hairlineLight,
      dark: AppColors.hairlineDark,
    );
    final ink = b.resolve(light: AppColors.inkLight, dark: AppColors.inkDark);
    final mark = b.resolve(
      light: AppColors.paperLight,
      dark: AppColors.paperDark,
    );

    final items = <(Key, Section, String Function(AppText), String)>[
      (
        const Key('sections-games'),
        Section.games,
        (t) => t.gamesTitle,
        '/games',
      ),
      (
        const Key('sections-dictionary'),
        Section.dictionary,
        (t) => t.dictionary,
        '/dictionary',
      ),
      (
        const Key('sections-translator'),
        Section.translator,
        (t) => t.translator,
        '/translator',
      ),
      (
        const Key('sections-chat'),
        Section.chatAi,
        (t) => t.chatWithAi,
        '/chat',
      ),
      (
        const Key('sections-settings'),
        Section.settings,
        (t) => t.settings,
        '/settings',
      ),
    ];

    return PopScope(
      canPop: !_open,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop && _open) _setOpen(false);
      },
      child: Stack(
        fit: StackFit.expand,
        children: [
          // A tap anywhere else closes the menu.
          if (_open)
            GestureDetector(
              key: const Key('sections-scrim'),
              behavior: HitTestBehavior.opaque,
              onTap: () => _setOpen(false),
              child: FadeTransition(
                opacity: _openness,
                child: ColoredBox(color: Colors.black.withValues(alpha: 0.25)),
              ),
            ),

          // ── The menu, above the button ─────────────────────────────────
          if (_open)
            Positioned(
              right: Spacing.md,
              bottom: Spacing.md + SectionsButton.size + Spacing.sm,
              child: FadeTransition(
                opacity: _openness,
                child: ScaleTransition(
                  scale: Tween(begin: 0.9, end: 1.0).animate(
                    CurvedAnimation(parent: _openness, curve: Curves.easeOut),
                  ),
                  alignment: Alignment.bottomRight,
                  child: Material(
                    key: const Key('sections-menu'),
                    color: card,
                    elevation: 6,
                    borderRadius: BorderRadius.circular(Radius.md),
                    clipBehavior: Clip.antiAlias,
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(
                        minWidth: 220,
                        maxWidth: 300,
                      ),
                      child: IntrinsicWidth(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            for (final (i, (key, section, title, route))
                                in items.indexed) ...[
                              if (i > 0) Divider(height: 0, color: hairline),
                              InkWell(
                                key: key,
                                onTap: () => _go(route),
                                child: Padding(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: Spacing.md,
                                    vertical: Spacing.sm,
                                  ),
                                  child: Row(
                                    children: [
                                      SectionIcon(
                                        section,
                                        size: 32,
                                        compact: true,
                                      ),
                                      const SizedBox(width: Spacing.md),
                                      Flexible(
                                        child: DualText(
                                          title,
                                          inline: true,
                                          style: TextStyle(
                                            fontSize: 16,
                                            fontWeight: FontWeight.w600,
                                            color: ink,
                                            fontFamily: 'Inter',
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),

          // ── The button ─────────────────────────────────────────────────
          Positioned(
            right: Spacing.md,
            bottom: Spacing.md,
            child: Semantics(
              button: true,
              expanded: _open,
              label: AppText.of(context).menu,
              excludeSemantics: true,
              child: Material(
                key: const Key('sections-button'),
                color: clay,
                shape: const CircleBorder(),
                elevation: 4,
                clipBehavior: Clip.antiAlias,
                child: InkWell(
                  onTap: _toggle,
                  child: SizedBox.square(
                    dimension: SectionsButton.size,
                    child: CustomPaint(
                      painter: DotWavesPainter(
                        pulse: _pulse,
                        openness: _openness,
                        color: mark,
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// A doodled dot with two rings around it. The rings pulse outward one
/// after the other ([pulse] 0–1, repeating) and fade away as [openness]
/// goes to 1, leaving just the dot.
class DotWavesPainter extends CustomPainter {
  final Animation<double> pulse;
  final Animation<double> openness;
  final Color color;

  DotWavesPainter({
    required this.pulse,
    required this.openness,
    required this.color,
  }) : super(repaint: Listenable.merge([pulse, openness]));

  @override
  void paint(Canvas canvas, Size size) {
    final c = size.center(Offset.zero);
    final unit = size.shortestSide / 60;
    final open = openness.value;

    // The dot: a slightly lumpy circle, a little bigger when open.
    final dotR = (5.5 + 1.5 * open) * unit;
    canvas.drawPath(
      _wobbly(c, dotR, wobble: 0.08, seed: 1),
      Paint()..color = color,
    );

    // Two rings, each a few hand-drawn strokes with gaps.
    final rings = 1 - open;
    if (rings <= 0) return;
    final stroke = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.2 * unit
      ..strokeCap = StrokeCap.round;
    for (var i = 0; i < 2; i++) {
      // Each ring brightens and swells a little in turn.
      final phase = (pulse.value - i * 0.25) % 1.0;
      final glow = math.max(0.0, math.sin(phase * math.pi));
      final r = (11.5 + i * 7.5 + glow * 1.5) * unit;
      stroke.color = color.withValues(alpha: (0.35 + 0.65 * glow) * rings);
      // Three strokes, gaps between them, turned differently per ring.
      for (var s = 0; s < 3; s++) {
        final start = (i * 0.9) + s * (2 * math.pi / 3);
        canvas.drawPath(
          _wobblyArc(c, r, start, 2 * math.pi / 3 - 0.55, seed: i * 3 + s),
          stroke,
        );
      }
    }
  }

  // A closed, slightly uneven circle (a doodle, not a compass circle).
  static Path _wobbly(
    Offset c,
    double r, {
    required double wobble,
    required int seed,
  }) {
    final path = Path();
    const n = 48;
    for (var k = 0; k <= n; k++) {
      final a = k / n * 2 * math.pi;
      final rr =
          r *
          (1 +
              wobble * math.sin(3 * a + seed) * 0.6 +
              wobble * math.cos(2 * a + seed * 2) * 0.4);
      final p = c + Offset(math.cos(a) * rr, math.sin(a) * rr);
      k == 0 ? path.moveTo(p.dx, p.dy) : path.lineTo(p.dx, p.dy);
    }
    return path..close();
  }

  // An arc whose radius drifts a little along it, like a hand stroke.
  static Path _wobblyArc(
    Offset c,
    double r,
    double start,
    double sweep, {
    required int seed,
  }) {
    final path = Path();
    const n = 20;
    for (var k = 0; k <= n; k++) {
      final t = k / n;
      final a = start + sweep * t;
      final rr = r * (1 + 0.05 * math.sin(t * math.pi * 2 + seed));
      final p = c + Offset(math.cos(a) * rr, math.sin(a) * rr);
      k == 0 ? path.moveTo(p.dx, p.dy) : path.lineTo(p.dx, p.dy);
    }
    return path;
  }

  @override
  bool shouldRepaint(DotWavesPainter old) => old.color != color;
}
