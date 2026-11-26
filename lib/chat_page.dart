// ─────────────────────────────────────────────────────────────────────────────
// CHAT WITH AI — practise a language by chatting (opened from the home card).
//
// The AI picked in Settings > AI model (EuroLLM or Gemma 4) answers, on the
// phone, without internet. With no AI turned on, the page says where to
// turn one on.
// ─────────────────────────────────────────────────────────────────────────────

import 'dart:ui' as ui;

import 'package:material_ui/material_ui.dart';

import 'ai_model.dart';
import 'app_settings.dart';
import 'app_text.dart';
import 'design_system.dart';
import 'dual_text.dart';
import 'section_icon.dart';
import 'speech.dart';

class ChatPage extends StatefulWidget {
  const ChatPage({super.key});

  @override
  State<ChatPage> createState() => _ChatPageState();
}

/// One message: from you, or from the AI.
typedef ChatMessage = ({bool mine, String text});

/// Language names for the AI's instructions.
const _names = {
  'en': 'English',
  'el': 'Greek',
  'es': 'Spanish',
  'de': 'German',
  'it': 'Italian',
  'fr': 'French',
  'ru': 'Russian',
};

/// What the AI is told before the conversation: the learner's main
/// language (the app's) and the one they practise (the secondary language,
/// or the main one when there's none).
@visibleForTesting
String chatInstructions({required String main, String? second}) {
  final m = _names[main] ?? 'English';
  final style =
      'Keep replies short: two or three sentences. When asked to role-play '
      '(a café, asking for directions), stay in the role and ask a question '
      'back.';
  if (second == null || second == main || _names[second] == null) {
    return 'You are a friendly language tutor in a language-learning app. '
        'The learner speaks $m. Always reply in $m. If they make a mistake, '
        'first give the corrected sentence, then explain the fix in one '
        'short line, then continue the conversation naturally. $style';
  }
  final p = _names[second]!;
  return 'You are a friendly language tutor in a language-learning app. '
      'The learner\'s main language is $m and they are practising $p. '
      'Talk with them in $p, using simple $p. If they make a mistake in '
      '$p, first give the corrected sentence in $p, then explain the fix '
      'in one short line in $m. If they write in $m, show them how to say '
      'it in $p and go on in $p. Never answer in any other language than '
      '$p and $m. $style';
}

/// The conversation with the AI teacher, shared by the chat page and the
/// little chat window over the round button: one conversation, wherever
/// it is shown, while the app runs.
class ChatSession extends ChangeNotifier {
  ChatSession._();
  static final instance = ChatSession._();

  final List<ChatMessage> messages = [];

  /// The AI's reply being written, or null.
  String? writing;

  /// An AI model is on and on the phone.
  bool aiReady = false;

  /// The AI is starting up (the first time can take a while).
  bool warming = false;

  bool _checking = false;

  /// Starts a new conversation (tests).
  @visibleForTesting
  void reset() {
    messages.clear();
    writing = null;
    aiReady = warming = false;
    notifyListeners();
  }

  /// Looks whether an AI is on, and starts it so the first reply doesn't
  /// wait for it.
  Future<void> checkAi() async {
    if (_checking) return;
    _checking = true;
    try {
      final ready =
          AppSettings.instance.aiTranslator && await AiModel.instance.isReady();
      aiReady = ready;
      warming = ready;
      notifyListeners();
      if (!ready) return;
      await AiModel.instance.warmUp();
      warming = false;
      notifyListeners();
    } finally {
      _checking = false;
    }
  }

  /// The teacher speaks first ([text]), if nothing has been said yet.
  void greet(String text) {
    if (messages.isNotEmpty) return;
    messages.add((mine: false, text: text));
    notifyListeners();
  }

  /// Sends [message] and writes the AI's reply as it comes.
  Future<void> send(String message, AppText t) async {
    message = message.trim();
    if (message.isEmpty || writing != null) return;
    messages.add((mine: true, text: message));
    notifyListeners();
    if (!aiReady) {
      messages.add((mine: false, text: t.chatNoAi));
      notifyListeners();
      return;
    }
    writing = '';
    notifyListeners();
    final out = StringBuffer();
    try {
      await for (final bit in AiModel.instance.chat(
        messages,
        instructions: chatInstructions(
          main: t.code,
          second: AppSettings.instance.secondaryLanguage,
        ),
      )) {
        out.write(bit);
        writing = out.toString();
        notifyListeners();
      }
    } catch (e) {
      debugPrint('Chat: ${AiModel.instance.name} stopped: $e');
    }
    final reply = out.toString().trim();
    writing = null;
    messages.add((mine: false, text: reply.isEmpty ? t.chatFailed : reply));
    notifyListeners();
  }
}

class _ChatPageState extends State<ChatPage> {
  final _input = TextEditingController();
  final _scroll = ScrollController();
  final _session = ChatSession.instance;

  List<ChatMessage> get _messages => _session.messages;
  String? get _writing => _session.writing;
  bool get _warming => _session.warming;

  @override
  void initState() {
    super.initState();
    _session.addListener(_changed);
    _session.checkAi();
    _toBottom();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Opened with a greeting (the teacher's cloud): it starts the chat.
    final greeting = ModalRoute.of(context)?.settings.arguments;
    if (greeting is String) _session.greet(greeting);
  }

  void _changed() {
    if (!mounted) return;
    setState(() {});
    _toBottom();
  }

  @override
  void dispose() {
    _session.removeListener(_changed);
    _input.dispose();
    _scroll.dispose();
    super.dispose();
  }

  Future<void> _send([String? text]) async {
    final message = (text ?? _input.text).trim();
    if (message.isEmpty || _writing != null) return;
    _input.clear();
    await _session.send(message, AppText.of(context));
  }

  /// Reads [text] aloud in the practised language's voice (the secondary
  /// language, or the main one): only the parts written in that language's
  /// letters, so the Greek of "Καλημέρα! (Good morning!)" is read in a
  /// Greek voice and the English left out.
  Future<void> _speak(String text) async {
    final main = AppText.of(context).code;
    final language = AppSettings.instance.secondaryLanguage ?? main;
    final accent = Accent.forLanguage(language).first;
    final messenger = ScaffoldMessenger.maybeOf(context);
    final noVoice = AppText.of(context).noVoice(accent.name);
    final say = speakablePart(text, language: language, main: main);
    if (!await Speech.instance.say(say, accent)) {
      messenger?.showSnackBar(SnackBar(content: Text(noVoice)));
    }
  }

  void _toBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scroll.hasClients) {
        _scroll.animateTo(
          _scroll.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final b = Theme.of(context).brightness;
    final paper = b.resolve(
      light: AppColors.paperLight,
      dark: AppColors.paperDark,
    );
    final card = b.resolve(
      light: AppColors.gridCellLight,
      dark: AppColors.gridCellDark,
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
    final t = AppText.of(context);

    return Scaffold(
      backgroundColor: paper,
      body: SafeArea(
        child: Column(
          children: [
            // ── Back and the title ─────────────────────────────────────────
            Padding(
              padding: const EdgeInsets.fromLTRB(
                Spacing.md,
                Spacing.sm,
                Spacing.md,
                Spacing.sm,
              ),
              child: Row(
                children: [
                  GestureDetector(
                    key: const Key('chat-back'),
                    onTap: () => Navigator.of(context).pop(),
                    child: Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        color: card,
                        borderRadius: BorderRadius.circular(Radius.sm),
                      ),
                      child: Icon(Icons.arrow_back, size: 20, color: ink),
                    ),
                  ),
                  const SizedBox(width: Spacing.md),
                  Expanded(
                    child: DualText(
                      (t) => AppText.upper(t.chatWithAi),
                      style: Theme.of(context).textTheme.displayMedium,
                      inline: true,
                    ),
                  ),
                ],
              ),
            ),

            // ── The conversation ───────────────────────────────────────────
            Expanded(
              child: _messages.isEmpty
                  ? _Welcome(onStarter: _send)
                  : ListView.separated(
                      key: const Key('chat-messages'),
                      controller: _scroll,
                      padding: const EdgeInsets.all(Spacing.md),
                      itemCount: _messages.length + (_writing == null ? 0 : 1),
                      separatorBuilder: (_, _) =>
                          const SizedBox(height: Spacing.sm),
                      itemBuilder: (context, i) {
                        // The reply being written: its text so far, or "…".
                        final m = i < _messages.length
                            ? _messages[i]
                            : (
                                mine: false,
                                text: _writing!.isEmpty ? '…' : _writing!,
                              );
                        final bubble = ChatBubble(
                          text: m.text,
                          mine: m.mine,
                          fill: m.mine ? blue : card,
                          textColor: m.mine ? Colors.white : ink,
                          border: m.mine ? null : hairline,
                        );
                        // The AI's finished answers can be heard aloud.
                        if (m.mine || i >= _messages.length) return bubble;
                        return Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            bubble,
                            Tooltip(
                              message: t.listen,
                              child: IconButton(
                                key: Key('chat-speak-$i'),
                                visualDensity: VisualDensity.compact,
                                icon: Icon(
                                  Icons.volume_up_outlined,
                                  size: 20,
                                  color: muted,
                                ),
                                onPressed: () => _speak(m.text),
                              ),
                            ),
                          ],
                        );
                      },
                    ),
            ),

            // ── The AI starting up ─────────────────────────────────────────
            if (_warming)
              Padding(
                key: const Key('chat-warming'),
                padding: const EdgeInsets.only(bottom: Spacing.xs),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    SizedBox(
                      width: 14,
                      height: 14,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: muted,
                      ),
                    ),
                    const SizedBox(width: Spacing.sm),
                    Text(
                      t.chatWarming(AiModel.instance.name),
                      style: TextStyle(
                        fontSize: 13,
                        color: muted,
                        fontFamily: 'Inter',
                      ),
                    ),
                  ],
                ),
              ),

            // ── Write a message ────────────────────────────────────────────
            Container(
              padding: const EdgeInsets.fromLTRB(
                Spacing.md,
                Spacing.sm,
                Spacing.sm,
                Spacing.sm,
              ),
              decoration: BoxDecoration(
                color: paper,
                border: Border(top: BorderSide(color: hairline, width: 0.5)),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: Spacing.md,
                      ),
                      decoration: BoxDecoration(
                        color: card,
                        borderRadius: BorderRadius.circular(24),
                        border: Border.all(color: hairline, width: 0.5),
                      ),
                      child: TextField(
                        key: const Key('chat-input'),
                        controller: _input,
                        minLines: 1,
                        maxLines: 4,
                        textInputAction: TextInputAction.send,
                        onSubmitted: (_) => _send(),
                        decoration: InputDecoration(
                          hintText: t.chatHint,
                          hintStyle: TextStyle(color: muted),
                          border: InputBorder.none,
                          enabledBorder: InputBorder.none,
                          focusedBorder: InputBorder.none,
                          filled: false,
                          isDense: true,
                          contentPadding: const EdgeInsets.symmetric(
                            vertical: 14,
                          ),
                        ),
                        style: TextStyle(fontSize: 16, color: ink),
                      ),
                    ),
                  ),
                  const SizedBox(width: Spacing.sm),
                  GestureDetector(
                    key: const Key('chat-send'),
                    onTap: _send,
                    child: Container(
                      width: 48,
                      height: 48,
                      decoration: BoxDecoration(
                        color: blue,
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.arrow_upward_rounded,
                        color: Colors.white,
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

/// Before the first message: the doodle, a hello, and starters to tap.
class _Welcome extends StatelessWidget {
  final ValueChanged<String> onStarter;
  const _Welcome({required this.onStarter});

  @override
  Widget build(BuildContext context) {
    final b = Theme.of(context).brightness;
    final ink = b.resolve(light: AppColors.inkLight, dark: AppColors.inkDark);
    final muted = b.resolve(
      light: AppColors.mutedLight,
      dark: AppColors.mutedDark,
    );
    final card = b.resolve(
      light: AppColors.gridCellLight,
      dark: AppColors.gridCellDark,
    );
    final hairline = b.resolve(
      light: AppColors.hairlineLight,
      dark: AppColors.hairlineDark,
    );
    final t = AppText.of(context);
    final starters = [
      (Icons.local_cafe_outlined, t.chatStarterCafe),
      (Icons.spellcheck_rounded, t.chatStarterCorrect),
      (Icons.lightbulb_outline_rounded, t.chatStarterWord),
      (Icons.travel_explore_rounded, t.chatStarterTravel),
    ];
    return ListView(
      key: const Key('chat-welcome'),
      padding: const EdgeInsets.fromLTRB(
        Spacing.md,
        Spacing.lg,
        Spacing.md,
        Spacing.md,
      ),
      children: [
        const Center(child: SectionIcon(Section.chatAi, size: 110)),
        const SizedBox(height: Spacing.md),
        DualText(
          (t) => t.chatHello,
          style: Theme.of(context).textTheme.displaySmall!.copyWith(color: ink),
          textAlign: TextAlign.center,
          crossAxisAlignment: CrossAxisAlignment.center,
        ),
        const SizedBox(height: Spacing.xs),
        DualText(
          (t) => t.chatIntro,
          style: Theme.of(context).textTheme.bodyLarge!.copyWith(color: muted),
          textAlign: TextAlign.center,
          crossAxisAlignment: CrossAxisAlignment.center,
        ),
        const SizedBox(height: Spacing.lg),
        for (final (i, (icon, text)) in starters.indexed) ...[
          if (i > 0) const SizedBox(height: Spacing.sm),
          GestureDetector(
            key: Key('chat-starter-$i'),
            onTap: () => onStarter(text),
            child: Container(
              padding: const EdgeInsets.symmetric(
                horizontal: Spacing.md,
                vertical: Spacing.sm + 6,
              ),
              decoration: BoxDecoration(
                color: card,
                borderRadius: BorderRadius.circular(Radius.sm),
                border: Border.all(color: hairline, width: 0.5),
              ),
              child: Row(
                children: [
                  Icon(icon, color: muted, size: 22),
                  const SizedBox(width: Spacing.sm + 4),
                  Expanded(
                    child: Text(
                      text,
                      style: TextStyle(
                        fontSize: 15,
                        color: ink,
                        fontFamily: 'Inter',
                      ),
                    ),
                  ),
                  Icon(Icons.north_east_rounded, color: muted, size: 18),
                ],
              ),
            ),
          ),
        ],
      ],
    );
  }
}

/// A chat bubble: yours on the right in blue, the AI's on the left.
class ChatBubble extends StatelessWidget {
  final String text;
  final bool mine;
  final Color fill, textColor;
  final Color? border;
  final double fontSize;

  const ChatBubble({
    super.key,
    required this.text,
    required this.mine,
    required this.fill,
    required this.textColor,
    this.border,
    this.fontSize = 16,
  });

  @override
  Widget build(BuildContext context) => Align(
    alignment: mine ? Alignment.centerRight : Alignment.centerLeft,
    child: ConstrainedBox(
      constraints: BoxConstraints(
        maxWidth: MediaQuery.sizeOf(context).width * 0.78,
      ),
      child: Container(
        padding: const EdgeInsets.symmetric(
          horizontal: Spacing.md - 2,
          vertical: Spacing.sm + 2,
        ),
        decoration: BoxDecoration(
          color: fill,
          border: border == null
              ? null
              : Border.all(color: border!, width: 0.5),
          borderRadius: BorderRadius.only(
            topLeft: const ui.Radius.circular(18),
            topRight: const ui.Radius.circular(18),
            bottomLeft: ui.Radius.circular(mine ? 18 : 4),
            bottomRight: ui.Radius.circular(mine ? 4 : 18),
          ),
        ),
        child: Text(
          text,
          style: TextStyle(
            fontSize: fontSize,
            height: 1.35,
            color: textColor,
            fontFamily: 'Inter',
          ),
        ),
      ),
    ),
  );
}

/// The part of an AI answer to read aloud in [language]: when [language]
/// and [main] use different alphabets (Greek, Cyrillic, Latin), the pieces
/// (sentences, lines, brackets) mostly in [language]'s alphabet; otherwise
/// all of it.
@visibleForTesting
String speakablePart(
  String text, {
  required String language,
  required String main,
}) {
  RegExp alphabet(String code) => switch (code) {
    'el' => RegExp(r'[Ͱ-Ͽἀ-῿]'),
    'ru' => RegExp('[Ѐ-ӿ]'),
    _ => RegExp('[A-Za-zÀ-ÿ]'),
  };
  final mine = alphabet(language), other = alphabet(main);
  if (mine.pattern == other.pattern) return text;
  final pieces = text
      .split(RegExp(r'(?<=[.!?;])\s+|\n+|[()]'))
      .map((p) => p.trim())
      .where((p) => p.isNotEmpty);
  final kept = [
    for (final p in pieces)
      if (mine.allMatches(p).length > other.allMatches(p).length) p,
  ];
  return kept.isEmpty ? text : kept.join(' ');
}
