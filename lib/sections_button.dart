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
//
// A moment after the start, the AI teacher says hello in a cloud over it.
// Tapping the cloud turns it into a little chat window attached to the
// button (on every page), which can grow to the full chat page; both show
// the same conversation.

import 'dart:async';
import 'dart:io' show Platform;
import 'dart:math' as math;

import 'package:material_ui/material_ui.dart';

import 'app_settings.dart';
import 'app_text.dart';
import 'chat_page.dart' show ChatBubble, ChatSession;
import 'design_system.dart';
import 'dual_text.dart';
import 'section_icon.dart';

/// The round button in an overlay of its own (the chat window's text field
/// needs one for its selection handles): goes over the navigator, in
/// main.dart's builder.
class SectionsButtonLayer extends StatefulWidget {
  final GlobalKey<NavigatorState> navigator;
  const SectionsButtonLayer({super.key, required this.navigator});

  @override
  State<SectionsButtonLayer> createState() => _SectionsButtonLayerState();
}

class _SectionsButtonLayerState extends State<SectionsButtonLayer> {
  late final _entry = OverlayEntry(
    builder: (_) => SectionsButton(navigator: widget.navigator),
  );

  @override
  void dispose() {
    _entry
      ..remove()
      ..dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Overlay(initialEntries: [_entry]);
}

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

  /// The teacher's cloud over the button, a moment after the app starts
  /// (off in widget tests unless a test turns it on). Tapped, it becomes a
  /// little chat window over the button.
  static bool teacherCloud = pulses;

  /// How long after the start the cloud shows.
  static Duration cloudDelay = const Duration(seconds: 2);

  /// How long the cloud stays before it goes away by itself.
  static Duration cloudShowFor = const Duration(seconds: 4);

  /// Closed (or used) once: not shown again until the app restarts.
  static bool cloudDismissed = false;

  /// "Hello" in each language, the first words of the cloud: in the
  /// language practised (the secondary one, or the app's).
  static const hello = {
    'en': 'Hello!',
    'el': 'Γεια σου!',
    'es': '¡Hola!',
    'de': 'Hallo!',
    'it': 'Ciao!',
    'fr': 'Bonjour !',
    'ru': 'Привет!',
  };

  @override
  State<SectionsButton> createState() => _SectionsButtonState();
}

/// [covered]: the top route is a sheet or dialog (not a page, not the
/// menu). [onChatPage]: the page showing is the full chat page.
class _TopRouteObserver extends NavigatorObserver {
  final covered = ValueNotifier(false);
  final onChatPage = ValueNotifier(false);

  void _top(Route<dynamic>? route) {
    final popup = route is PopupRoute;
    final value = popup && route is! _MenuRoute;
    final chat = popup ? null : route?.settings.name == '/chat';
    // Called during navigation, which may be in the middle of a build.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      covered.value = value;
      if (chat != null) onChatPage.value = chat;
    });
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

  // The teacher's cloud is due (its delay has passed).
  bool _cloudDue = false;
  Timer? _cloudTimer;

  // The little chat window is open over the button.
  bool _chatOpen = false;

  // The chat box in the cloud: while it's in use the cloud stays.
  final _cloudInput = TextEditingController();
  final _cloudFocus = FocusNode();

  static const _margin = Spacing.md;
  static const _aboveBars = 72.0;

  @override
  void initState() {
    super.initState();
    if (SectionsButton.pulses) {
      _pulse.repeat();
      _float.repeat();
    }
    if (SectionsButton.teacherCloud && !SectionsButton.cloudDismissed) {
      _cloudTimer = Timer(SectionsButton.cloudDelay, _showCloud);
    }
    // Writing in the cloud's box keeps it; leaving the box (empty) lets it
    // go a few seconds later.
    _cloudFocus.addListener(() {
      if (!mounted) return;
      if (_cloudFocus.hasFocus) {
        _cloudTimer?.cancel();
        setState(() {});
      } else if (_cloudDue && !_chatOpen) {
        _showCloud();
      }
    });
  }

  @override
  void dispose() {
    _cloudInput.dispose();
    _cloudFocus.dispose();
    _cloudTimer?.cancel();
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

  /// Closes the menu and opens [route] over the home page ("/": home;
  /// "/chat": the floating chat over the page you are on).
  void _go(String route) {
    final navigator = _navigator;
    if (navigator == null) return;
    navigator.pop(); // the menu
    if (route == '/chat') {
      final (hello, invite) = _cloudText(AppText.of(context));
      _openChat('$hello $invite');
    } else if (route == '/') {
      navigator.popUntil((r) => r.isFirst);
    } else {
      navigator.pushNamedAndRemoveUntil(route, (r) => r.isFirst);
    }
  }

  void _dismissCloud() => setState(() => SectionsButton.cloudDismissed = true);

  /// Shows the cloud, which goes away by itself a few seconds later.
  void _showCloud() {
    if (!mounted) return;
    setState(() => _cloudDue = true);
    _cloudTimer?.cancel();
    _cloudTimer = Timer(SectionsButton.cloudShowFor, () {
      if (mounted) setState(() => _cloudDue = false);
    });
  }

  /// The cloud's words: hello in the language practised, then an
  /// invitation (a different one each day) in the app's language.
  (String, String) _cloudText(AppText t) {
    final practised = AppSettings.instance.secondaryLanguage ?? t.code;
    final day = DateTime.now().difference(DateTime(2024)).inDays;
    return (
      SectionsButton.hello[practised] ?? SectionsButton.hello['en']!,
      t.teacherInvite(day),
    );
  }

  /// The cloud was tapped: the chat window, the teacher speaking first.
  void _openChat(String greeting) {
    _cloudTimer?.cancel();
    ChatSession.instance
      ..greet(greeting)
      ..checkAi();
    setState(() => _chatOpen = true);
  }

  /// Sent from the cloud's box: the chat window opens with the teacher's
  /// words and the answer.
  void _sendFromCloud(String greeting) {
    final text = _cloudInput.text.trim();
    if (text.isEmpty) return;
    _cloudInput.clear();
    _cloudFocus.unfocus();
    _openChat(greeting);
    ChatSession.instance.send(text, AppText.of(context));
  }

  /// The chat window's expand button: the same conversation, full page.
  void _expandChat() {
    setState(() => _chatOpen = false);
    _navigator?.pushNamed('/chat');
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
    final rings = [
      b.resolve(
        light: AppColors.cornflowerLight,
        dark: AppColors.cornflowerDark,
      ),
      b.resolve(light: AppColors.fernLight, dark: AppColors.fernDark),
    ];
    final media = MediaQuery.of(context);
    const s = SectionsButton.size;

    final observer = SectionsButton.observer;
    return ListenableBuilder(
      listenable: Listenable.merge([observer.covered, observer.onChatPage]),
      builder: (context, _) {
        final covered = observer.covered.value;
        final onChatPage = observer.onChatPage.value;
        // The chat window, while open (not on the full chat page, the
        // same conversation is there).
        final chat = _chatOpen && !onChatPage && !_open && !covered;
        // Out of the way of sheets, dialogs and the keyboard (unless the
        // keyboard is for the chat window).
        final typing = _cloudFocus.hasFocus;
        if ((covered || media.viewInsets.bottom > 0) &&
            !_open &&
            !chat &&
            !typing) {
          return const SizedBox.shrink();
        }
        // Over the keyboard while typing in the chat window.
        return Padding(
          padding: EdgeInsets.only(bottom: media.viewInsets.bottom),
          child: SafeArea(
            child: LayoutBuilder(
              builder: (context, constraints) {
                final area = constraints.biggest;
                final at = _buttonAt(area);
                final cloud =
                    _cloudDue &&
                    !SectionsButton.cloudDismissed &&
                    !onChatPage &&
                    !_chatOpen &&
                    !_open &&
                    _dragAt == null;
                final onRight = at.dx + s / 2 > area.width / 2;
                final below = at.dy + s / 2 > area.height / 2;
                final (hello, invite) = _cloudText(AppText.of(context));
                // The chat window: as tall as its conversation, up to two
                // thirds of the screen; as wide as fits.
                final room = below
                    ? at.dy - _margin - 8
                    : area.height - at.dy - s - _margin - 8;
                final chatMaxHeight = math.max(
                  160.0,
                  math.min(area.height * 0.67, room),
                );
                final chatWidth = math.min(area.width - 2 * _margin, 380.0);
                return Stack(
                  children: [
                    // ── The chat window, attached to the button ────────────
                    if (chat)
                      Positioned(
                        left: onRight ? null : at.dx,
                        right: onRight ? area.width - at.dx - s : null,
                        top: below ? null : at.dy + s + 8,
                        bottom: below ? area.height - at.dy + 8 : null,
                        width: chatWidth,
                        child: _Floating(
                          animation: _float,
                          phase: 0.15,
                          child: _ChatWindow(
                            maxHeight: chatMaxHeight,
                            onExpand: _expandChat,
                            // Back into the cloud (which then goes away).
                            onMinimize: () {
                              setState(() => _chatOpen = false);
                              _showCloud();
                            },
                          ),
                        ),
                      ),
                    // ── The teacher's cloud, beside the button ─────────────
                    if (cloud)
                      Positioned(
                        left: onRight ? null : at.dx,
                        right: onRight ? area.width - at.dx - s : null,
                        top: below ? null : at.dy + s + 4,
                        bottom: below ? area.height - at.dy + 4 : null,
                        child: _Floating(
                          animation: _float,
                          phase: 0.15,
                          child: _TeacherCloud(
                            hello: hello,
                            invite: invite,
                            tailRight: onRight,
                            tailDown: below,
                            onTap: () => _openChat('$hello $invite'),
                            onClose: _dismissCloud,
                            input: _cloudInput,
                            focus: _cloudFocus,
                            onSend: () => _sendFromCloud('$hello $invite'),
                          ),
                        ),
                      ),
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
                                        ringColors: rings,
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
          ),
        );
      },
    );
  }
}

/// The teacher's message over the round button: a speech cloud with a
/// trail of little puffs towards the button, hello in the language
/// practised and an invitation to chat. Tapping it opens the AI chat.
class _TeacherCloud extends StatelessWidget {
  final String hello;
  final String invite;

  /// Which corner the trail of puffs leaves from (towards the button).
  final bool tailRight;
  final bool tailDown;
  final VoidCallback onTap;
  final VoidCallback onClose;

  /// The small chat box under the message: writing in it answers the
  /// teacher straight away.
  final TextEditingController input;
  final FocusNode focus;
  final VoidCallback onSend;

  /// The cloud's width; the chat box under the message is as wide.
  static const width = 270.0;

  const _TeacherCloud({
    required this.hello,
    required this.invite,
    required this.tailRight,
    required this.tailDown,
    required this.onTap,
    required this.onClose,
    required this.input,
    required this.focus,
    required this.onSend,
  });

  @override
  Widget build(BuildContext context) {
    final b = Theme.of(context).brightness;
    final card = b.resolve(
      light: AppColors.gridCellLight,
      dark: AppColors.gridCellDark,
    );
    final ink = b.resolve(light: AppColors.inkLight, dark: AppColors.inkDark);
    final muted = b.resolve(
      light: AppColors.mutedLight,
      dark: AppColors.mutedDark,
    );
    final clay = b.resolve(
      light: AppColors.clayLight,
      dark: AppColors.clayDark,
    );
    final close = AppText.of(context).close;

    Widget puff(double d) => Container(
      width: d,
      height: d,
      decoration: BoxDecoration(
        color: card,
        shape: BoxShape.circle,
        boxShadow: const [BoxShadow(blurRadius: 4, color: Colors.black26)],
      ),
    );
    // Two puffs, the smaller nearer the button, under the button's middle.
    final trail = Padding(
      padding: EdgeInsets.symmetric(horizontal: SectionsButton.size / 2 - 8),
      child: Column(
        crossAxisAlignment: tailRight
            ? CrossAxisAlignment.end
            : CrossAxisAlignment.start,
        children: tailDown
            ? [
                const SizedBox(height: 3),
                Padding(
                  padding: EdgeInsets.only(
                    right: tailRight ? 6 : 0,
                    left: tailRight ? 0 : 6,
                  ),
                  child: puff(11),
                ),
                const SizedBox(height: 3),
                puff(7),
              ]
            : [
                puff(7),
                const SizedBox(height: 3),
                Padding(
                  padding: EdgeInsets.only(
                    right: tailRight ? 6 : 0,
                    left: tailRight ? 0 : 6,
                  ),
                  child: puff(11),
                ),
                const SizedBox(height: 3),
              ],
      ),
    );

    final paper = b.resolve(
      light: AppColors.paperLight,
      dark: AppColors.paperDark,
    );
    final hairline = b.resolve(
      light: AppColors.hairlineLight,
      dark: AppColors.hairlineDark,
    );
    final blue = SectionIcon.colorOf(Section.chatAi, b);
    final t = AppText.of(context);

    final bubble = Material(
      key: const Key('teacher-cloud'),
      color: card,
      elevation: 8,
      borderRadius: BorderRadius.circular(22),
      clipBehavior: Clip.antiAlias,
      child: SizedBox(
        width: _TeacherCloud.width,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // ── The teacher's words (tap: the chat window) ──────────────────
            InkWell(
              onTap: onTap,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(14, 10, 4, 6),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Padding(
                      padding: EdgeInsets.only(top: 2),
                      child: SectionIcon(
                        Section.chatAi,
                        size: 30,
                        compact: true,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Flexible(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            hello,
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w700,
                              color: clay,
                              fontFamily: 'Inter',
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            invite,
                            style: TextStyle(
                              fontSize: 13,
                              height: 1.3,
                              color: ink,
                              fontFamily: 'Inter',
                            ),
                          ),
                        ],
                      ),
                    ),
                    // (No tooltip: there is no overlay above the pages here.)
                    Semantics(
                      button: true,
                      label: close,
                      excludeSemantics: true,
                      child: InkResponse(
                        key: const Key('teacher-cloud-close'),
                        onTap: onClose,
                        radius: 18,
                        child: Padding(
                          padding: const EdgeInsets.all(8),
                          child: Icon(
                            Icons.close_rounded,
                            size: 18,
                            color: muted,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),

            // ── A small chat box, as wide as the cloud ──────────────────────
            Padding(
              padding: const EdgeInsets.fromLTRB(10, 0, 8, 10),
              child: Row(
                children: [
                  Expanded(
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                      decoration: BoxDecoration(
                        color: paper,
                        borderRadius: BorderRadius.circular(18),
                        border: Border.all(color: hairline, width: 0.5),
                      ),
                      child: TextField(
                        key: const Key('teacher-cloud-input'),
                        controller: input,
                        focusNode: focus,
                        textInputAction: TextInputAction.send,
                        onSubmitted: (_) => onSend(),
                        decoration: InputDecoration(
                          hintText: t.chatHint,
                          hintStyle: TextStyle(color: muted, fontSize: 13),
                          border: InputBorder.none,
                          enabledBorder: InputBorder.none,
                          focusedBorder: InputBorder.none,
                          filled: false,
                          isDense: true,
                          contentPadding: const EdgeInsets.symmetric(
                            vertical: 9,
                          ),
                        ),
                        style: TextStyle(fontSize: 13, color: ink),
                      ),
                    ),
                  ),
                  const SizedBox(width: 6),
                  GestureDetector(
                    key: const Key('teacher-cloud-send'),
                    onTap: onSend,
                    child: Container(
                      width: 32,
                      height: 32,
                      decoration: BoxDecoration(
                        color: blue,
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.arrow_upward_rounded,
                        color: Colors.white,
                        size: 18,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: tailRight
          ? CrossAxisAlignment.end
          : CrossAxisAlignment.start,
      children: tailDown ? [bubble, trail] : [trail, bubble],
    );
  }
}

/// The little chat window over the round button: the conversation with the
/// AI teacher, a field to write in, and buttons to make it full page or to
/// fold it back into the cloud.
class _ChatWindow extends StatefulWidget {
  final VoidCallback onExpand;
  final VoidCallback onMinimize;

  /// It grows with the conversation up to this, then scrolls.
  final double maxHeight;

  const _ChatWindow({
    required this.maxHeight,
    required this.onExpand,
    required this.onMinimize,
  });

  @override
  State<_ChatWindow> createState() => _ChatWindowState();
}

class _ChatWindowState extends State<_ChatWindow> {
  final _session = ChatSession.instance;
  final _input = TextEditingController();
  final _scroll = ScrollController();

  @override
  void initState() {
    super.initState();
    _session.addListener(_changed);
    _toBottom();
  }

  @override
  void dispose() {
    _session.removeListener(_changed);
    _input.dispose();
    _scroll.dispose();
    super.dispose();
  }

  void _changed() {
    if (!mounted) return;
    setState(() {});
    _toBottom();
  }

  void _toBottom() => WidgetsBinding.instance.addPostFrameCallback((_) {
    if (_scroll.hasClients) {
      _scroll.jumpTo(_scroll.position.maxScrollExtent);
    }
  });

  void _send() {
    final text = _input.text.trim();
    if (text.isEmpty || _session.writing != null) return;
    _input.clear();
    _session.send(text, AppText.of(context));
  }

  @override
  Widget build(BuildContext context) {
    final b = Theme.of(context).brightness;
    final t = AppText.of(context);
    final card = b.resolve(
      light: AppColors.gridCellLight,
      dark: AppColors.gridCellDark,
    );
    final paper = b.resolve(
      light: AppColors.paperLight,
      dark: AppColors.paperDark,
    );
    final ink = b.resolve(light: AppColors.inkLight, dark: AppColors.inkDark);
    final muted = b.resolve(
      light: AppColors.mutedLight,
      dark: AppColors.mutedDark,
    );
    final hairline = b.resolve(
      light: AppColors.hairlineLight,
      dark: AppColors.hairlineDark,
    );
    final blue = SectionIcon.colorOf(Section.chatAi, b);
    final messages = _session.messages;
    final writing = _session.writing;

    Widget iconButton(Key key, IconData icon, String label, VoidCallback f) =>
        Semantics(
          button: true,
          label: label,
          excludeSemantics: true,
          child: InkResponse(
            key: key,
            onTap: f,
            radius: 20,
            child: Padding(
              padding: const EdgeInsets.all(8),
              child: Icon(icon, size: 20, color: muted),
            ),
          ),
        );

    return Material(
      key: const Key('chat-window'),
      color: card,
      elevation: 10,
      borderRadius: BorderRadius.circular(Radius.md),
      clipBehavior: Clip.antiAlias,
      child: ConstrainedBox(
        constraints: BoxConstraints(maxHeight: widget.maxHeight),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // ── Title, full page, fold back ──────────────────────────────────
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 6, 4, 6),
              child: Row(
                children: [
                  const SectionIcon(Section.chatAi, size: 26, compact: true),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      t.chatWithAi,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                        color: ink,
                        fontFamily: 'Inter',
                      ),
                    ),
                  ),
                  iconButton(
                    const Key('chat-window-expand'),
                    Icons.open_in_full_rounded,
                    t.chatWithAi,
                    widget.onExpand,
                  ),
                  iconButton(
                    const Key('chat-window-minimize'),
                    Icons.keyboard_arrow_down_rounded,
                    t.close,
                    widget.onMinimize,
                  ),
                ],
              ),
            ),
            Divider(height: 0, color: hairline),

            // ── The conversation (as tall as it is, scrolling when full) ─────
            Flexible(
              child: ListView.separated(
                key: const Key('chat-window-messages'),
                controller: _scroll,
                shrinkWrap: true,
                padding: const EdgeInsets.all(10),
                itemCount: messages.length + (writing == null ? 0 : 1),
                separatorBuilder: (_, _) => const SizedBox(height: 6),
                itemBuilder: (context, i) {
                  final m = i < messages.length
                      ? messages[i]
                      : (mine: false, text: writing!.isEmpty ? '…' : writing);
                  return ChatBubble(
                    text: m.text,
                    mine: m.mine,
                    fill: m.mine ? blue : paper,
                    textColor: m.mine ? Colors.white : ink,
                    border: m.mine ? null : hairline,
                    fontSize: 14,
                  );
                },
              ),
            ),

            // ── Write a message ──────────────────────────────────────────────
            Container(
              padding: const EdgeInsets.fromLTRB(10, 6, 6, 8),
              decoration: BoxDecoration(
                border: Border(top: BorderSide(color: hairline, width: 0.5)),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                      decoration: BoxDecoration(
                        color: paper,
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: hairline, width: 0.5),
                      ),
                      child: TextField(
                        key: const Key('chat-window-input'),
                        controller: _input,
                        minLines: 1,
                        maxLines: 3,
                        textInputAction: TextInputAction.send,
                        onSubmitted: (_) => _send(),
                        decoration: InputDecoration(
                          hintText: t.chatHint,
                          hintStyle: TextStyle(color: muted, fontSize: 14),
                          border: InputBorder.none,
                          enabledBorder: InputBorder.none,
                          focusedBorder: InputBorder.none,
                          filled: false,
                          isDense: true,
                          contentPadding: const EdgeInsets.symmetric(
                            vertical: 10,
                          ),
                        ),
                        style: TextStyle(fontSize: 14, color: ink),
                      ),
                    ),
                  ),
                  const SizedBox(width: 6),
                  GestureDetector(
                    key: const Key('chat-window-send'),
                    onTap: _send,
                    child: Container(
                      width: 38,
                      height: 38,
                      decoration: BoxDecoration(
                        color: blue,
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.arrow_upward_rounded,
                        color: Colors.white,
                        size: 20,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
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
    const gap = Spacing.sm;

    final items = <(String, Section, String Function(AppText), String)>[
      ('home', Section.home, (t) => t.home, '/'),
      ('games', Section.games, (t) => t.gamesTitle, '/games'),
      ('dictionary', Section.dictionary, (t) => t.dictionary, '/dictionary'),
      // Opens the floating chat, not the page (see _go).
      ('chat', Section.chatAi, (t) => t.chatWithAi, '/chat'),
      ('translator', Section.translator, (t) => t.translator, '/translator'),
      ('settings', Section.settings, (t) => t.settings, '/settings'),
    ];

    // The space the menu has (the screen), measured.
    return LayoutBuilder(
      builder: (context, constraints) {
        final screen = constraints.biggest;
        final onRight = button.center.dx > screen.width / 2;
        final below = button.center.dy > screen.height / 2;
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
                                      SectionIcon(
                                        section,
                                        size: 26,
                                        compact: true,
                                      ),
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
      },
    );
  }

  @override
  Widget buildTransitions(context, animation, secondaryAnimation, child) =>
      FadeTransition(opacity: animation, child: child);
}

/// A doodled dot with two rings around it, the inner one in
/// [ringColors].first, the outer in [ringColors].last. The rings pulse
/// outward one after the other ([pulse] 0–1, repeating) and fade away as
/// [openness] goes to 1, leaving just the dot.
class DotWavesPainter extends CustomPainter {
  final Animation<double> pulse;
  final Animation<double> openness;
  final Color color;
  final List<Color> ringColors;

  DotWavesPainter({
    required this.pulse,
    required this.openness,
    required this.color,
    required this.ringColors,
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
      ..strokeWidth = 2.6 * unit
      ..strokeCap = StrokeCap.round;
    for (var i = 0; i < 2; i++) {
      // Each ring brightens and swells a little in turn.
      final phase = (pulse.value - i * 0.25) % 1.0;
      final glow = math.max(0.0, math.sin(phase * math.pi));
      final r = (11.5 + i * 7.5 + glow * 1.5) * unit;
      final ring = i == 0 ? ringColors.first : ringColors.last;
      stroke.color = ring.withValues(alpha: (0.55 + 0.45 * glow) * rings);
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
  bool shouldRepaint(DotWavesPainter old) =>
      old.color != color ||
      old.ringColors.first != ringColors.first ||
      old.ringColors.last != ringColors.last;
}
