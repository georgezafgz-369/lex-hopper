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

class ChatPage extends StatefulWidget {
  const ChatPage({super.key});

  @override
  State<ChatPage> createState() => _ChatPageState();
}

/// One message: from you, or from the AI.
typedef _Message = ({bool mine, String text});

/// What the AI is told before the conversation.
const _instructions =
    'You are a friendly language tutor in a language-learning app. '
    'Reply in the language the learner writes in, unless they ask for '
    'another. Keep replies short: two or three sentences. If the learner '
    'makes a mistake, first give the corrected sentence, then explain the '
    'fix in one short line, then continue the conversation naturally. '
    'When asked to role-play (a café, asking for directions), stay in the '
    'role and ask a question back.';

class _ChatPageState extends State<ChatPage> {
  final _input = TextEditingController();
  final _scroll = ScrollController();
  final List<_Message> _messages = [];

  /// The AI's reply being written, or null.
  String? _writing;

  /// An AI model is on and on the phone.
  bool _aiReady = false;

  @override
  void initState() {
    super.initState();
    _checkAi();
  }

  Future<void> _checkAi() async {
    final ready =
        AppSettings.instance.aiTranslator && await AiModel.instance.isReady();
    if (mounted) setState(() => _aiReady = ready);
  }

  @override
  void dispose() {
    _input.dispose();
    _scroll.dispose();
    super.dispose();
  }

  Future<void> _send([String? text]) async {
    final message = (text ?? _input.text).trim();
    if (message.isEmpty || _writing != null) return;
    final t = AppText.of(context);
    setState(() => _messages.add((mine: true, text: message)));
    _input.clear();
    _toBottom();
    if (!_aiReady) {
      setState(() => _messages.add((mine: false, text: t.chatNoAi)));
      _toBottom();
      return;
    }
    setState(() => _writing = '');
    final out = StringBuffer();
    try {
      await for (final bit in AiModel.instance.chat(
        _messages,
        instructions: _instructions,
      )) {
        out.write(bit);
        if (!mounted) return;
        setState(() => _writing = out.toString());
        _toBottom();
      }
    } catch (e) {
      debugPrint('Chat: ${AiModel.instance.name} stopped: $e');
    }
    if (!mounted) return;
    final reply = out.toString().trim();
    setState(() {
      _writing = null;
      _messages.add((mine: false, text: reply.isEmpty ? t.chatFailed : reply));
    });
    _toBottom();
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
                        return _Bubble(
                          text: m.text,
                          mine: m.mine,
                          fill: m.mine ? blue : card,
                          textColor: m.mine ? Colors.white : ink,
                          border: m.mine ? null : hairline,
                        );
                      },
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
class _Bubble extends StatelessWidget {
  final String text;
  final bool mine;
  final Color fill, textColor;
  final Color? border;

  const _Bubble({
    required this.text,
    required this.mine,
    required this.fill,
    required this.textColor,
    this.border,
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
            fontSize: 16,
            height: 1.35,
            color: textColor,
            fontFamily: 'Inter',
          ),
        ),
      ),
    ),
  );
}
