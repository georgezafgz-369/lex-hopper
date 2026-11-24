// ─────────────────────────────────────────────────────────────────────────────
// BOTTOM MENU — a three-line button in the bottom-right corner of the main pages
// that opens (and closes) a row of round buttons floating over the bottom of
// the pages (Home, Games, Dictionary, Settings), one per section, each with its
// doodle from the home page cards, in colour. The page you're on is drawn
// a little bigger; Translator opens its
// sheet. Hidden while the keyboard is up.
// ─────────────────────────────────────────────────────────────────────────────

import 'dart:math' as math;

import 'package:material_ui/material_ui.dart';

import 'app_text.dart';
import 'design_system.dart';
import 'section_icon.dart';
import 'translator_page.dart' show showTranslatorSheet;

class BottomMenu extends StatelessWidget {
  /// The page this menu is on (marked), or null.
  final Section? current;

  /// The page under the menu.
  final Widget child;

  const BottomMenu({super.key, required this.current, required this.child});

  /// Room to leave at the bottom of a page so its last items can scroll
  /// clear of the menu.
  static const space = 96.0;

  /// Each section's button: its doodle (the home page cards' icon) and
  /// the page it opens (Translator: a sheet).
  static const _buttons = [
    (Section.home, '/'),
    (Section.games, '/games'),
    (Section.dictionary, '/dictionary'),
    (Section.translator, null),
    (Section.settings, '/settings'),
  ];

  static String _label(AppText t, Section s) => switch (s) {
    Section.home => t.home,
    Section.games => t.gamesTitle,
    Section.dictionary => t.dictionary,
    Section.translator => t.translator,
    _ => t.settings,
  };

  void _open(BuildContext context, Section s, String? route) {
    if (s == current) return;
    final navigator = Navigator.of(context);
    if (route == null) {
      showTranslatorSheet(context);
    } else if (route == '/') {
      navigator.popUntil((r) => r.isFirst);
    } else {
      // One main page at a time above Home, so Back always leads home.
      navigator.pushNamedAndRemoveUntil(route, (r) => r.isFirst);
    }
  }

  /// Whether the menu is open. It starts closed; once opened it stays
  /// open from page to page until closed again (for as long as the app
  /// runs).
  static final open = ValueNotifier<bool>(false);

  Widget _button(BuildContext context, AppText t, Section s, String? route) =>
      Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8),
        child: Tooltip(
          message: _label(t, s),
          child: Semantics(
            button: true,
            selected: s == current,
            label: _label(t, s),
            child: GestureDetector(
              key: Key('bottom-menu-${s.name}'),
              onTap: () => _open(context, s, route),
              // A small button with its doodle, all in colour; the page
              // you're on is drawn a little bigger.
              child: SizedBox(
                width: 44,
                height: 44,
                child: OverflowBox(
                  maxWidth: 60,
                  maxHeight: 60,
                  child: AnimatedScale(
                    key: Key('bottom-menu-scale-${s.name}'),
                    scale: s == current ? 1.0 : 0.8,
                    duration: const Duration(milliseconds: 200),
                    child: SectionIcon(s, size: 50, compact: true),
                  ),
                ),
              ),
            ),
          ),
        ),
      );

  @override
  Widget build(BuildContext context) {
    // The keyboard, read from the screen itself: a Scaffold hides it from
    // its body (which it shrinks instead).
    final keyboard = View.of(context).viewInsets.bottom > 0;
    final t = AppText.of(context);
    return Stack(
      children: [
        child,
        if (!keyboard)
          Positioned(
            right: 12,
            bottom: 16 + MediaQuery.paddingOf(context).bottom,
            child: ValueListenableBuilder<bool>(
              valueListenable: open,
              builder: (context, isOpen, _) => Row(
                key: const Key('bottom-menu'),
                mainAxisSize: MainAxisSize.min,
                children: [
                  // The sections slide out to the left of the button.
                  AnimatedSize(
                    duration: const Duration(milliseconds: 250),
                    curve: Curves.easeOutCubic,
                    alignment: Alignment.centerRight,
                    child: AnimatedOpacity(
                      opacity: isOpen ? 1 : 0,
                      duration: const Duration(milliseconds: 200),
                      child: isOpen
                          ? Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                for (final (s, route) in _buttons)
                                  _button(context, t, s, route),
                              ],
                            )
                          : const SizedBox(height: 44),
                    ),
                  ),
                  // Open / close: a doodle of three lines that springs into a funnel
                  // when open.
                  Tooltip(
                    message: isOpen ? t.closeMenu : t.openMenu,
                    child: Semantics(
                      button: true,
                      expanded: isOpen,
                      label: isOpen ? t.closeMenu : t.openMenu,
                      child: GestureDetector(
                        key: const Key('bottom-menu-toggle'),
                        onTap: () => open.value = !open.value,
                        child: Padding(
                          padding: const EdgeInsets.only(left: 8),
                          child: SizedBox(
                            width: 48,
                            height: 48,
                            child: OverflowBox(
                              maxWidth: 60,
                              maxHeight: 60,
                              child: _MenuLines(open: isOpen, size: 56),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
      ],
    );
  }
}

/// The menu button's drawing: three thick ink lines on the clay circle,
/// like the section doodles. Opening springs them, one after another, into
/// a funnel (long, medium, short) with a little bounce; closing springs them
/// back. A tap also squeezes the button for a moment.
class _MenuLines extends StatefulWidget {
  final bool open;
  final double size;

  const _MenuLines({required this.open, required this.size});

  @override
  State<_MenuLines> createState() => _MenuLinesState();
}

class _MenuLinesState extends State<_MenuLines>
    with SingleTickerProviderStateMixin {
  late final _c = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 700),
    value: widget.open ? 1 : 0,
  );

  @override
  void didUpdateWidget(_MenuLines old) {
    super.didUpdateWidget(old);
    if (widget.open != old.open) {
      widget.open ? _c.forward() : _c.reverse();
    }
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final b = Theme.of(context).brightness;
    final blob = SectionIcon.colorOf(Section.menu, b);
    final ink = b.resolve(light: AppColors.inkLight, dark: AppColors.inkDark);
    return AnimatedBuilder(
      animation: _c,
      builder: (context, _) {
        // A quick squeeze in the first part of the move, either way.
        final squeeze = 1 - 0.12 * math.sin(math.pi * (_c.value.clamp(0, 1)));
        return Transform.scale(
          scale: _c.isAnimating ? squeeze : 1,
          child: CustomPaint(
            key: const Key('bottom-menu-lines'),
            size: Size.square(widget.size),
            painter: _LinesPainter(_c, blob: blob, ink: ink),
          ),
        );
      },
    );
  }
}

class _LinesPainter extends CustomPainter {
  final Animation<double> t;
  final Color blob, ink;

  _LinesPainter(this.t, {required this.blob, required this.ink})
    : super(repaint: t);

  // On the doodles' 120 × 120 canvas: the circle, and each line's ends
  // closed (full width) and open (the funnel).
  static const _closed = [(38.0, 82.0), (38.0, 82.0), (38.0, 82.0)];
  static const _open = [(36.0, 84.0), (46.0, 74.0), (55.0, 65.0)];
  static const _ys = [48.0, 64.0, 80.0];

  @override
  void paint(Canvas canvas, Size size) {
    final k = size.width / 120;
    canvas.drawCircle(Offset(60 * k, 64 * k), 40 * k, Paint()..color = blob);
    final line = Paint()
      ..color = ink
      ..strokeWidth = 7 * k
      ..strokeCap = StrokeCap.round;
    for (var i = 0; i < 3; i++) {
      // One after another: each line starts a little later, and overshoots.
      final start = i * 0.15;
      final local = ((t.value - start) / (1 - 0.3)).clamp(0.0, 1.0);
      final p = Curves.elasticOut.transform(local);
      final (x1c, x2c) = _closed[i];
      final (x1o, x2o) = _open[i];
      final x1 = x1c + (x1o - x1c) * p;
      final x2 = x2c + (x2o - x2c) * p;
      canvas.drawLine(
        Offset(x1 * k, _ys[i] * k),
        Offset(x2 * k, _ys[i] * k),
        line,
      );
    }
  }

  @override
  bool shouldRepaint(_LinesPainter old) =>
      old.blob != blob || old.ink != ink || old.t != t;
}
