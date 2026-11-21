// ─────────────────────────────────────────────────────────────────────────────
// WORD OF THE DAY — the card at the top of the home page: today's word, its
// part of speech and main meaning. Tapping it opens the word's full entry;
// the speaker says it aloud.
// ─────────────────────────────────────────────────────────────────────────────

import 'package:material_ui/material_ui.dart';

import 'app_settings.dart';
import 'app_text.dart';
import 'dictionary_service.dart';
import 'dual_text.dart';
import 'design_system.dart';
import 'speech.dart';
import 'word_sheet.dart';

/// Loads the word of the day for a dictionary language ("en" or "el").
typedef WordOfTheDayLoader = Future<WordOfTheDay?> Function(String language);

Future<WordOfTheDay?> _loadFromDictionary(String language) =>
    DictionaryService.forLanguage(language).wordOfTheDay(DateTime.now());

class WordOfTheDayCard extends StatefulWidget {
  /// Where the word comes from; the app's dictionary unless a test gives
  /// another.
  final WordOfTheDayLoader load;

  /// Today's date, shown on the card (tests fix it).
  final DateTime? today;

  const WordOfTheDayCard({
    super.key,
    this.load = _loadFromDictionary,
    this.today,
  });

  @override
  State<WordOfTheDayCard> createState() => _WordOfTheDayCardState();
}

class _WordOfTheDayCardState extends State<WordOfTheDayCard> {
  String? _language;
  Future<WordOfTheDay?>? _word;

  /// Loads the word again whenever the app language changes.
  Future<WordOfTheDay?> _wordFor(String language) {
    if (language != _language || _word == null) {
      _language = language;
      _word = widget.load(language).catchError((_) => null);
    }
    return _word!;
  }

  Future<void> _speak(String word, String language) async {
    final accent = Accent.forLanguage(language).first;
    final messenger = ScaffoldMessenger.maybeOf(context);
    final ok = await Speech.instance.say(word, accent);
    if (!ok) {
      messenger?.showSnackBar(
        SnackBar(
          content: DualText(
            (t) => t.noVoice(accent.name),
            style: const TextStyle(color: Colors.white),
            secondaryStyle: const TextStyle(
              color: Colors.white70,
              fontSize: 12,
            ),
          ),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final language = AppText.of(context).code;
    return FutureBuilder<WordOfTheDay?>(
      future: _wordFor(language),
      builder: (context, snapshot) {
        final word = snapshot.data;
        // Nothing while loading or when there is no word: the home page
        // simply starts with the Games card.
        if (word == null) return const SizedBox.shrink();
        return Padding(
          padding: const EdgeInsets.only(bottom: Spacing.md),
          child: _card(context, word, language),
        );
      },
    );
  }

  Widget _card(BuildContext context, WordOfTheDay word, String language) {
    final brightness = Theme.of(context).brightness;
    final muted = brightness.resolve(
      light: AppColors.mutedLight,
      dark: AppColors.mutedDark,
    );
    final ink = brightness.resolve(
      light: AppColors.inkLight,
      dark: AppColors.inkDark,
    );
    final hairline = brightness.resolve(
      light: AppColors.hairlineLight,
      dark: AppColors.hairlineDark,
    );
    final entry = word.entry;
    final text = entry.word;
    final display = text.isEmpty
        ? text
        : text[0].toUpperCase() + text.substring(1);
    final today = widget.today ?? DateTime.now();
    final titleStyle = Theme.of(context).textTheme.displaySmall!;

    return GestureDetector(
      key: const Key('word-of-the-day'),
      onTap: () => showWordSheet(context, word: text, language: language),
      child: Container(
        width: double.infinity,
        decoration: BoxDecoration(
          color: brightness.resolve(
            light: AppColors.gridCellLight,
            dark: AppColors.gridCellDark,
          ),
          borderRadius: BorderRadius.circular(Radius.sm),
          border: Border.all(color: hairline, width: 0.5),
        ),
        padding: const EdgeInsets.all(Spacing.lg),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // WORD OF THE DAY ............................. Fri 20 Nov
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: DualText(
                    (t) => t.wordOfTheDay,
                    style: kickerStyle(brightness: brightness),
                    inline: true,
                  ),
                ),
                const SizedBox(width: Spacing.sm),
                Text(
                  AppText.of(context).shortDate(today),
                  style: kickerStyle(brightness: brightness)
                      .copyWith(letterSpacing: 0.5),
                ),
              ],
            ),
            const SizedBox(height: Spacing.md),

            // The word, its translation, and the speaker.
            Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Expanded(
                  child: ListenableBuilder(
                    listenable: AppSettings.instance,
                    builder: (context, _) {
                      final translation = secondaryText(context) == null
                          ? null
                          : word.translation;
                      return Text.rich(
                        TextSpan(
                          children: [
                            TextSpan(
                              text: display,
                              style: titleStyle.copyWith(
                                fontSize: (titleStyle.fontSize ?? 24) * 1.35,
                              ),
                            ),
                            if (translation != null && translation.isNotEmpty)
                              TextSpan(
                                text: '  $translation',
                                style: titleStyle.copyWith(
                                  fontSize: (titleStyle.fontSize ?? 24) * 0.8,
                                  fontWeight: FontWeight.w400,
                                  color: translationColor(context),
                                ),
                              ),
                          ],
                        ),
                        key: const Key('word-of-the-day-word'),
                      );
                    },
                  ),
                ),
                const SizedBox(width: Spacing.sm),
                GestureDetector(
                  key: const Key('word-of-the-day-speak'),
                  onTap: () => _speak(text, language),
                  child: Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(color: hairline),
                    ),
                    child: Icon(Icons.volume_up_outlined, size: 20, color: ink),
                  ),
                ),
              ],
            ),
            const SizedBox(height: Spacing.xs),

            // Part of speech, then the main meaning.
            Text(
              AppText.of(context).partOfSpeechName(entry.partOfSpeech),
              style: Theme.of(context).textTheme.bodyMedium!
                  .copyWith(color: muted, fontStyle: FontStyle.italic),
            ),
            const SizedBox(height: Spacing.sm),
            Text(
              _sentence(entry.meaning),
              style: Theme.of(context).textTheme.bodyLarge!
                  .copyWith(color: ink, height: 1.4),
            ),
            const SizedBox(height: Spacing.md),

            // See more ›
            Align(
              alignment: Alignment.centerRight,
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    AppText.of(context).seeMore,
                    style: Theme.of(context).textTheme.bodyMedium!
                        .copyWith(color: muted),
                  ),
                  Icon(Icons.chevron_right, size: 18, color: muted),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// "the outer layer of the Earth" → "The outer layer of the Earth."
  static String _sentence(String meaning) {
    final m = meaning.trim();
    if (m.isEmpty) return m;
    final capital = m[0].toUpperCase() + m.substring(1);
    return RegExp(r'[.!?;]$').hasMatch(capital) ? capital : '$capital.';
  }
}
