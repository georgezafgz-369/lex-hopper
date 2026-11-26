// ─────────────────────────────────────────────────────────────────────────────
// SECTIONS BUTTON — the round button over every page
// ─────────────────────────────────────────────────────────────────────────────
//
// Closed: a hand-drawn dot with rings pulsing out around it. Tapped, the
// rings fade, the button shrinks to just the dot, and a menu of the app's
// sections pops up beside it. A tap outside, or Back, closes it. It floats
// a little, and a drag moves it anywhere on the screen.
//
// It sits over the navigator (main.dart's builder), so it stays put while
// pages change; the menu is a popup route, so Back closes it. It hides
// while a sheet or dialog is up and while the keyboard is open.

import 'dart:io' show Platform;
import 'dart:math' as math;

import 'package:material_ui/material_ui.dart';

import 'app_text.dart';
import 'design_system.dart';
import 'dual_text.dart';
import 'section_icon.dart';

class SectionsButton extends StatefulWidget {
  /// The app's navigator, to open pages and the menu.
  final GlobalKey<NavigatorState> navigator;

  const SectionsButton({super.key, required this.navigator});

  /// The button's size, for pages that leave room for it.
  static const size = 50.0;

  /// The rings pulse and the button floats for ever, so widget tests (which
  /// wait for animations to end) see them still.
  static bool pulses = !Platform.environment.containsKey('FLUTTER_TEST');

  /// Where the button was dragged to (its top-left, as a fraction of the
  /// screen), kept while the app runs; null: the bottom right corner.
  static Offset? place;

  /// Watches the navigator: the button hides while a sheet or a dialog is
  /// on top. Goes in the app's navigatorObservers.
  static final observer = _TopRouteObserver();

  @override
  State<SectionsButton> createState() => _SectionsButtonState();
}

/// True while the top route is a sheet or dialog (not a page, not the menu).
class _TopRouteObserver extends NavigatorObserver {
  final covered = ValueNotifier(false);

  void _top(Route<dynamic>? route) {
    final value = route is PopupRoute && route is! _MenuRoute;
    // Called during navigation, which may be in the middle of a build.
    WidgetsBinding.instance.addPostFrameCallback((_) => covered.value = value);
  }

  @override
  void didPush(Route route, Route? previousRoute) => _top(route);
  @override
  void didPop(Route route, Route? previousRoute) => _top(previousRoute);
  @override
  void didRemove(Route route, Route? previousRoute) => _top(previousRoute);
  @override
  void didReplace({Route? newRoute, Route? oldRoute}) => _top(newRoute);
}

class _SectionsButtonState extends State<SectionsButton>
    with TickerProviderStateMixin {
  _MenuRoute? _menu;
  bool get _open => _menu != null;

  // The rings' pulse, always running while closed.
  late final _pulse = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 2400),
  );

  // A slow up-and-down float, for the button and the open menu.
  late final _float = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 3200),
  );

  // 0 closed, 1 open: fades the rings out and shrinks the button.
  late final _openness = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 220),
  );

  // The button's top-left while being dragged (pixels in the screen).
  Offset? _dragAt;

  static const _margin = Spacing.md;
  static const _aboveBars = 72.0;

  @override
  void initState() {
    super.initState();
    if (SectionsButton.pulses) {
      _pulse.repeat();
      _float.repeat();
    }
  }

  @override
  void dispose() {
    _pulse.dispose();
    _float.dispose();
    _openness.dispose();
    super.dispose();
  }

  NavigatorState? get _navigator => widget.navigator.currentState;

  void _toggle(Rect button, Size area, EdgeInsets padding) {
    final navigator = _navigator;
    if (navigator == null) return;
    if (_open) {
      final menu = _menu!;
      menu.isCurrent ? navigator.pop() : navigator.removeRoute(menu);
      return _closed();
    }
    final menu = _MenuRoute(
      button: button.shift(Offset(padding.left, padding.top)),
      float: _float,
      onPick: _go,
    );
    setState(() => _menu = menu);
    _openness.forward();
    _pulse.stop();
    navigator.push(menu).whenComplete(() {
      if (mounted && _menu == menu) _closed();
    });
  }

  void _closed() {
    setState(() => _menu = null);
    _openness.reverse();
    if (SectionsButton.pulses) _pulse.repeat();
  }

  /// Closes the menu and opens [route] over the home page ("/": home).
  void _go(String route) {
    final navigator = _navigator;
    if (navigator == null) return;
    navigator.pop(); // the menu
    if (route == '/') {
      navigator.popUntil((r) => r.isFirst);
    } else {
      navigator.pushNamedAndRemoveUntil(route, (r) => r.isFirst);
    }
  }

  /// The button's top-left in [area], kept clear of the edges.
  Offset _buttonAt(Size area) {
    const s = SectionsButton.size;
    final maxX = math.max(_margin, area.width - s - _margin);
    final maxY = math.max(_margin, area.height - s - _margin);
    final place = SectionsButton.place;
    final at =
        _dragAt ??
        (place == null
            // Above the bars some pages have at the bottom (the
            // translator's languages, the chat's message field).
            ? Offset(maxX, maxY - _aboveBars)
            : Offset(place.dx * area.width, place.dy * area.height));
    return Offset(at.dx.clamp(_margin, maxX), at.dy.clamp(_margin, maxY));
  }

  @override
  Widget build(BuildContext context) {
    final b = Theme.of(context).brightness;
    final clay = b.resolve(
      light: AppColors.clayLight,
      dark: AppColors.clayDark,
    );
    final mark = b.resolve(
      light: AppColors.paperLight,
      dark: AppColors.paperDark,
    );
    final media = MediaQuery.of(context);
    const s = SectionsButton.size;

    return ValueListenableBuilder(
      valueListenable: SectionsButton.observer.covered,
      builder: (context, covered, _) {
        // Out of the way of sheets, dialogs and the keyboard.
        if ((covered || media.viewInsets.bottom > 0) && !_open) {
          return const SizedBox.shrink();
        }
        return SafeArea(
          child: LayoutBuilder(
            builder: (context, constraints) {
              final area = constraints.biggest;
              final at = _buttonAt(area);
              return Stack(
                children: [
                  Positioned(
                    left: at.dx,
                    top: at.dy,
                    child: GestureDetector(
                      onPanStart: _open
                          ? null
                          : (_) => setState(() => _dragAt = at),
                      onPanUpdate: _open
                          ? null
                          : (d) => setState(
                              () => _dragAt = _buttonAt(area) + d.delta,
                            ),
                      onPanEnd: _open
                          ? null
                          : (_) => setState(() {
                              final end = _buttonAt(area);
                              SectionsButton.place = Offset(
                                end.dx / area.width,
                                end.dy / area.height,
                              );
                              _dragAt = null;
                            }),
                      child: _Floating(
                        animation: _float,
                        // Smaller while the menu is open.
                        child: ScaleTransition(
                          scale: Tween(begin: 1.0, end: 0.78).animate(
                            CurvedAnimation(
                              parent: _openness,
                              curve: Curves.easeOut,
                            ),
                          ),
                          child: Semantics(
                            button: true,
                            expanded: _open,
                            label: AppText.of(context).menu,
                            excludeSemantics: true,
                            child: Material(
                              key: const Key('sections-button'),
                              color: clay,
                              shape: const CircleBorder(),
                              elevation: _dragAt != null ? 10 : 6,
                              clipBehavior: Clip.antiAlias,
                              child: InkWell(
                                onTap: () => _toggle(
                                  at & const Size.square(s),
                                  area,
                                  media.padding,
                                ),
                                child: SizedBox.square(
                                  dimension: s,
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
                      ),
                    ),
                  ),
                ],
              );
            },
          ),
        );
      },
    );
  }
}

/// Moves [child] a few pixels up and down with [animation].
class _Floating extends StatelessWidget {
  final Animation<double> animation;
  final double phase;
  final Widget child;

  const _Floating({
    required this.animation,
    required this.child,
    this.phase = 0,
  });

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
    animation: animation,
    builder: (_, child) => Transform.translate(
      offset: Offset(0, 3 * math.sin((animation.value + phase) * 2 * math.pi)),
      child: child,
    ),
    child: child,
  );
}

/// The menu: a dimmed screen and the sections, beside [button] (its place
/// on the screen), opening towards the middle. A tap outside closes it.
class _MenuRoute extends PopupRoute<void> {
  final Rect button;
  final Animation<double> float;
  final void Function(String route) onPick;

  _MenuRoute({required this.button, required this.float, required this.onPick});

  @override
  Color? get barrierColor => Colors.black.withValues(alpha: 0.25);
  @override
  bool get barrierDismissible => true;
  @override
  String? get barrierLabel => 'menu';
  @override
  Duration get transitionDuration => const Duration(milliseconds: 200);

  @override
  Widget buildPage(context, animation, secondaryAnimation) {
    final b = Theme.of(context).brightness;
    final card = b.resolve(
      light: AppColors.gridCellLight,
      dark: AppColors.gridCellDark,
    );
    final hairline = b.resolve(
      light: AppColors.hairlineLight,
      dark: AppColors.hairlineDark,
    );
    final ink = b.resolve(light: AppColors.inkLight, dark: AppColors.inkDark);
    final screen = MediaQuery.sizeOf(context);
    const gap = Spacing.sm;
    final onRight = button.center.dx > screen.width / 2;
    final below = button.center.dy > screen.height / 2;

    final items = <(String, Section, String Function(AppText), String)>[
      ('home', Section.home, (t) => t.home, '/'),
      ('games', Section.games, (t) => t.gamesTitle, '/games'),
      ('dictionary', Section.dictionary, (t) => t.dictionary, '/dictionary'),
      ('translator', Section.translator, (t) => t.translator, '/translator'),
      ('chat', Section.chatAi, (t) => t.chatWithAi, '/chat'),
      ('settings', Section.settings, (t) => t.settings, '/settings'),
    ];

    return Stack(
      children: [
        Positioned(
          left: onRight ? null : button.left,
          right: onRight ? screen.width - button.right : null,
          top: below ? null : button.bottom + gap,
          bottom: below ? screen.height - button.top + gap : null,
          child: _Floating(
            animation: float,
            phase: 0.25,
            child: ScaleTransition(
              scale: Tween(begin: 0.9, end: 1.0).animate(
                CurvedAnimation(parent: animation, curve: Curves.easeOut),
              ),
              alignment: Alignment(onRight ? 1 : -1, below ? 1 : -1),
              child: Material(
                key: const Key('sections-menu'),
                color: card,
                elevation: 10,
                borderRadius: BorderRadius.circular(Radius.md),
                clipBehavior: Clip.antiAlias,
                child: ConstrainedBox(
                  constraints: const BoxConstraints(
                    minWidth: 180,
                    maxWidth: 260,
                  ),
                  child: IntrinsicWidth(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        for (final (i, (name, section, title, route))
                            in items.indexed) ...[
                          if (i > 0) Divider(height: 0, color: hairline),
                          InkWell(
                            key: Key('sections-$name'),
                            onTap: () => onPick(route),
                            child: Padding(
                              padding: const EdgeInsets.symmetric(
                                horizontal: Spacing.sm + 4,
                                vertical: 7,
                              ),
                              child: Row(
                                children: [
                                  SectionIcon(section, size: 26, compact: true),
                                  const SizedBox(width: Spacing.sm + 2),
                                  Flexible(
                                    child: DualText(
                                      title,
                                      inline: true,
                                      style: TextStyle(
                                        fontSize: 14,
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
      ],
    );
  }

  @override
  Widget buildTransitions(context, animation, secondaryAnimation, child) =>
      FadeTransition(opacity: animation, child: child);
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
