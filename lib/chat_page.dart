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
import 'dictionary_search_bar.dart';
import 'dual_text.dart';
import 'opus_mt_service.dart';
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
      'back. Write only your reply to the learner, as plain text: no notes '
      'about your answer, no headings, no "---" lines, no ** marks.';
  if (second == null || second == main || _names[second] == null) {
    return 'You are a friendly language tutor in a language-learning app. '
        'The learner speaks $m. Always reply in $m. Only if they made a real '
        'mistake, give the corrected sentence and explain the fix in one '
        'short line; never invent a mistake. Then continue the conversation '
        'naturally. $style';
  }
  final p = _names[second]!;
  // The app shows each answer's translation into $p under it, so the
  // model mustn't translate its own reply (it did, adding notes about it).
  return 'You are a friendly language teacher in a language-learning app. '
      'The learner\'s main language is $m and they are learning $p. '
      'Reply in $m only; do not translate your reply. You may include one '
      'or two useful $p words or phrases. Only if they wrote in $p and made '
      'a real mistake, give the corrected sentence in $p and explain the '
      'fix in one short line in $m; never invent a mistake. $style';
}

/// "Hello" in each language: the teacher's first word.
const teacherHello = {
  'en': 'Hello!',
  'el': 'Γεια σου!',
  'es': '¡Hola!',
  'de': 'Hallo!',
  'it': 'Ciao!',
  'fr': 'Bonjour !',
  'ru': 'Привет!',
};

/// The teacher's greeting in [t]'s language: hello and an invitation (a
/// different one each day).
String teacherGreeting(AppText t) => '${_hello(t)} ${teacherInvitation(t)}';

/// Today's invitation to chat, in [t]'s language.
String teacherInvitation(AppText t) =>
    t.teacherInvite(DateTime.now().difference(DateTime(2024)).inDays);

/// While no AI is on the phone: hello, and the offer to download it.
String teacherOffer(AppText t) => '${_hello(t)} ${t.aiOffer}';

String _hello(AppText t) => teacherHello[t.code] ?? teacherHello['en']!;

/// The conversation with the AI teacher, shared by the chat page and the
/// little chat window over the round button: one conversation, wherever
/// it is shown, while the app runs.
class ChatSession extends ChangeNotifier {
  ChatSession._();
  static final instance = ChatSession._();

  final List<ChatMessage> messages = [];

  /// The teacher's messages in the secondary language (by the message's
  /// place in [messages]), shown under them.
  final Map<int, String> translations = {};

  /// The message that offers to download the AI (while none is on the
  /// phone), or null.
  int? offerAt;

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
    translations.clear();
    offerAt = null;
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

  /// The secondary language, when there is one other than [t]'s.
  static String? _second(AppText t) {
    final second = AppSettings.instance.secondaryLanguage;
    return second == null || second == t.code ? null : second;
  }

  /// Adds the teacher's message [text]; [translated] gives it in the
  /// secondary language (the same text from the app's own words).
  void _teacher(String text, AppText t, String Function(AppText) translated) {
    messages.add((mine: false, text: text));
    final second = _second(t);
    if (second != null) {
      translations[messages.length - 1] = translated(AppText.forCode(second));
    }
  }

  /// The teacher speaks first, if nothing has been said yet: a greeting,
  /// or (with no AI on the phone) the offer to download one.
  Future<void> greet(AppText t) async {
    if (messages.isNotEmpty) return;
    final ready =
        AppSettings.instance.aiTranslator && await AiModel.instance.isReady();
    if (messages.isNotEmpty) return;
    if (ready) {
      _teacher(teacherGreeting(t), t, teacherGreeting);
    } else {
      _offer(t);
    }
    notifyListeners();
  }

  void _offer(AppText t) {
    _teacher(teacherOffer(t), t, teacherOffer);
    offerAt = messages.length - 1;
  }

  /// The offer's button: turns the AI on and downloads it; once it's here
  /// the teacher says hello.
  Future<void> downloadAi(AppText t) async {
    final model = AiModel.instance;
    await AppSettings.instance.setAiTranslator(true);
    await model.download();
    if (!await model.isReady()) return;
    offerAt = null;
    _teacher(teacherGreeting(t), t, teacherGreeting);
    notifyListeners();
    await checkAi();
  }

  /// [reply] in the secondary language, under it (the offline translator;
  /// nothing when it can't).
  Future<void> _translate(int at, String reply, AppText t) async {
    final second = _second(t);
    if (second == null) return;
    try {
      final text = await OpusMtService.instance
          .translate(reply, from: t.code, to: second)
          .timeout(const Duration(seconds: 30));
      if (text.trim().isEmpty || at >= messages.length) return;
      translations[at] = text.trim();
      notifyListeners();
    } catch (e) {
      debugPrint('Chat: no translation: $e');
    }
  }

  /// Sends [message] and writes the AI's reply as it comes.
  Future<void> send(String message, AppText t) async {
    message = message.trim();
    if (message.isEmpty || writing != null) return;
    messages.add((mine: true, text: message));
    notifyListeners();
    if (!aiReady) {
      // No AI: the offer to download one (once), else where to turn it on.
      offerAt == null
          ? _offer(t)
          : messages.add((mine: false, text: t.chatNoAi));
      notifyListeners();
      return;
    }
    writing = '';
    notifyListeners();
    final out = StringBuffer();
    String? failure;
    try {
      await for (final bit in AiModel.instance.chat(
        [
          for (final (i, m) in messages.indexed)
            if (i != offerAt) m,
        ],
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
      // No room for the model to start: say so (and how much to free).
      if (e is NotEnoughSpace) failure = t.aiNeedsSpace(gbText(e.shortMb));
    }
    final reply = cleanReply(out.toString());
    writing = null;
    messages.add((
      mine: false,
      text: reply.isEmpty ? failure ?? t.chatFailed : reply,
    ));
    notifyListeners();
    if (reply.isNotEmpty) await _translate(messages.length - 1, reply, t);
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
                  const SizedBox(width: Spacing.sm),
                  Expanded(
                    child: DictionarySearchToggle(
                      beside: DualText(
                        (t) => AppText.upper(t.chatWithAi),
                        style: Theme.of(context).textTheme.displayMedium,
                        inline: true,
                      ),
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
                        // Speakers sit after each sentence, inside.
                        return chatMessageBubble(context, i);
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

/// A chat bubble: yours on the right in blue, the AI's on the left. The
/// AI's has a speaker after each sentence ([speakIn] picks each one's
/// voice), and can carry its [translation] into the secondary language
/// under it (a speaker after each of its sentences too, in
/// [translationLanguage]'s voice), and a [footer] (the download button).
class ChatBubble extends StatelessWidget {
  final String text;
  final bool mine;
  final Color fill, textColor;
  final Color? border;
  final double fontSize;
  final String? Function(String sentence)? speakIn;
  final String? translation;
  final String? translationLanguage;
  final Widget? footer;

  const ChatBubble({
    super.key,
    required this.text,
    required this.mine,
    required this.fill,
    required this.textColor,
    this.border,
    this.fontSize = 16,
    this.speakIn,
    this.translation,
    this.translationLanguage,
    this.footer,
  });

  /// [text] with a speaker after each sentence that has letters.
  static TextSpan withSpeakers(
    BuildContext context,
    String text, {
    required String? Function(String sentence) languageOf,
    required Color color,
    required double size,
    required String key,
  }) {
    final listen = AppText.of(context).listen;
    final letter = RegExp(r'\p{L}', unicode: true);
    return TextSpan(
      children: [
        for (final (i, sentence) in sentencesOf(text).indexed) ...[
          // The speaker right after the sentence, before its spaces and
          // line breaks.
          TextSpan(text: sentence.trimRight()),
          if (letter.hasMatch(sentence))
            if (languageOf(sentence.trim()) case final language?)
              WidgetSpan(
                alignment: PlaceholderAlignment.middle,
                child: Semantics(
                  button: true,
                  label: listen,
                  excludeSemantics: true,
                  child: InkResponse(
                    key: Key('$key-$i'),
                    onTap: () =>
                        sayInLanguage(context, sentence.trim(), language),
                    radius: 16,
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 4),
                      child: Icon(
                        Icons.volume_up_outlined,
                        size: size,
                        color: color,
                      ),
                    ),
                  ),
                ),
              ),
          TextSpan(text: sentence.substring(sentence.trimRight().length)),
        ],
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final b = Theme.of(context).brightness;
    final orange = b.resolve(
      light: AppColors.translationLight,
      dark: AppColors.translationDark,
    );
    final hairline = b.resolve(
      light: AppColors.hairlineLight,
      dark: AppColors.hairlineDark,
    );
    final muted = b.resolve(
      light: AppColors.mutedLight,
      dark: AppColors.mutedDark,
    );
    final style = TextStyle(
      fontSize: fontSize,
      height: 1.35,
      color: textColor,
      fontFamily: 'Inter',
    );
    return Align(
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
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              speakIn == null
                  ? Text(text, style: style)
                  : Text.rich(
                      withSpeakers(
                        context,
                        text,
                        languageOf: speakIn!,
                        color: muted,
                        size: fontSize + 1,
                        key: 'chat-sentence-speak',
                      ),
                      style: style,
                    ),
              // ── The translation, a speaker after each sentence ──────────
              if (translation != null) ...[
                const SizedBox(height: 6),
                Divider(height: 0, color: hairline),
                const SizedBox(height: 6),
                Text.rich(
                  key: const Key('chat-translation'),
                  translationLanguage == null
                      ? TextSpan(text: translation)
                      : withSpeakers(
                          context,
                          translation!,
                          languageOf: (_) => translationLanguage,
                          color: orange,
                          size: fontSize,
                          key: 'chat-translation-speak',
                        ),
                  style: TextStyle(
                    fontSize: fontSize - 1,
                    height: 1.35,
                    color: orange,
                    fontFamily: 'Inter',
                  ),
                ),
              ],
              if (footer != null) ...[const SizedBox(height: 10), footer!],
            ],
          ),
        ),
      ),
    );
  }
}

/// [text] cut into sentences, each with the spaces after it, so joined
/// they give [text] back. A sentence ends at . ! ? ; … (Greek's question
/// mark is ;), with any closing quotes or brackets, before a space or the
/// end, or at a line break.
@visibleForTesting
List<String> sentencesOf(String text) {
  final out = <String>[];
  final end = RegExp('[.!?;…]+[\'"»”’)\\]]*(\\s+|\$)|\\n\\s*');
  var start = 0;
  for (final m in end.allMatches(text)) {
    if (m.end <= start) continue;
    out.add(text.substring(start, m.end));
    start = m.end;
  }
  if (start < text.length) out.add(text.substring(start));
  return out.where((s) => s.isNotEmpty).toList();
}

/// The voice for [sentence]: Greek letters Greek, Cyrillic Russian, Latin
/// the app's language ([main]) or, when that's written in another
/// alphabet, the secondary language if it's Latin, else English.
String voiceFor(String sentence, {required String main, String? second}) {
  if (RegExp(r'[Ͱ-Ͽἀ-῿]').hasMatch(sentence)) return 'el';
  if (RegExp('[Ѐ-ӿ]').hasMatch(sentence)) return 'ru';
  bool latin(String? c) => c != null && c != 'el' && c != 'ru';
  if (latin(main)) return main;
  return latin(second) ? second! : 'en';
}

/// Message [i] of the shared conversation as a bubble: yours in blue; the
/// teacher's with its translation and speaker, and the download button on
/// the offer. [writing]: the reply being written (no translation yet).
Widget chatMessageBubble(
  BuildContext context,
  int i, {
  double fontSize = 16,
  Color? aiFill,
}) {
  final session = ChatSession.instance;
  final b = Theme.of(context).brightness;
  final card = b.resolve(
    light: AppColors.gridCellLight,
    dark: AppColors.gridCellDark,
  );
  final ink = b.resolve(light: AppColors.inkLight, dark: AppColors.inkDark);
  final hairline = b.resolve(
    light: AppColors.hairlineLight,
    dark: AppColors.hairlineDark,
  );
  final blue = SectionIcon.colorOf(Section.chatAi, b);
  final messages = session.messages;
  final writing = i >= messages.length;
  final m = writing
      ? (mine: false, text: session.writing!.isEmpty ? '…' : session.writing!)
      : messages[i];
  final translation = writing ? null : session.translations[i];
  final second = AppSettings.instance.secondaryLanguage;
  return ChatBubble(
    text: m.text,
    mine: m.mine,
    fill: m.mine ? blue : (aiFill ?? card),
    textColor: m.mine ? Colors.white : ink,
    border: m.mine ? null : hairline,
    fontSize: fontSize,
    // A speaker after each of the teacher's sentences, in its own voice
    // (not while it's still being written).
    speakIn: m.mine || writing
        ? null
        : (sentence) => voiceFor(
            sentence,
            main: AppText.of(context).code,
            second: second,
          ),
    translation: translation,
    translationLanguage: second,
    footer: !writing && i == session.offerAt ? const AiOfferButton() : null,
  );
}

/// Reads [text] aloud in [language]'s voice (a note when the phone has no
/// voice for it).
Future<void> sayInLanguage(
  BuildContext context,
  String text,
  String language,
) async {
  final accent = Accent.forLanguage(language).first;
  final messenger = ScaffoldMessenger.maybeOf(context);
  final noVoice = AppText.of(context).noVoice(accent.name);
  if (!await Speech.instance.say(text, accent)) {
    messenger?.showSnackBar(SnackBar(content: Text(noVoice)));
  }
}

/// The teacher's offer: download the AI (its size on the button), then the
/// download's progress.
class AiOfferButton extends StatelessWidget {
  const AiOfferButton({super.key});

  @override
  Widget build(BuildContext context) {
    final model = AiModel.instance;
    final t = AppText.of(context);
    final b = Theme.of(context).brightness;
    final blue = SectionIcon.colorOf(Section.chatAi, b);
    final muted = b.resolve(
      light: AppColors.mutedLight,
      dark: AppColors.mutedDark,
    );
    return ListenableBuilder(
      listenable: model.changes,
      builder: (context, _) {
        if (model.state == ModelState.downloading) {
          final p = model.progress;
          return Row(
            key: const Key('ai-offer-progress'),
            mainAxisSize: MainAxisSize.min,
            children: [
              SizedBox(
                width: 14,
                height: 14,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  value: p,
                  color: blue,
                ),
              ),
              const SizedBox(width: 8),
              Flexible(
                child: Text(
                  t.aiGettingReady(((p ?? 0) * 100).floor()),
                  style: TextStyle(
                    fontSize: 13,
                    color: muted,
                    fontFamily: 'Inter',
                  ),
                ),
              ),
            ],
          );
        }
        return FilledButton.icon(
          key: const Key('ai-offer-download'),
          style: FilledButton.styleFrom(
            backgroundColor: blue,
            foregroundColor: Colors.white,
            visualDensity: VisualDensity.compact,
          ),
          onPressed: () => ChatSession.instance.downloadAi(t),
          icon: const Icon(Icons.download_rounded, size: 18),
          label: Text(t.aiOfferButton(model.sizeMb)),
        );
      },
    );
  }
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

/// [mb] as gigabytes with one decimal ("2.1"), at least 0.1.
String gbText(int mb) => (mb < 100 ? 0.1 : mb / 1000).toStringAsFixed(1);

/// The AI's [reply] as the learner should see it: without the notes some
/// models add after a "---" line, and without Markdown's ** marks.
@visibleForTesting
String cleanReply(String reply) {
  var text = reply.replaceAll('**', '');
  final rule = RegExp(r'^\s*(-{3,}|_{3,}|\*{3,})\s*$', multiLine: true);
  final cut = rule.firstMatch(text);
  if (cut != null && cut.start > 0) text = text.substring(0, cut.start);
  return text.trim();
}
