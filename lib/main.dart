// ─────────────────────────────────────────────────────────────────────────────
// LEX HOPPER — entry point
// ─────────────────────────────────────────────────────────────────────────────

import 'package:flutter/services.dart';
import 'package:material_ui/material_ui.dart';

import 'app_settings.dart';
import 'app_text.dart';
import 'design_system.dart';
import 'home_page.dart';
import 'games_page.dart';
import 'crossword_menu_page.dart';
import 'crossword_game_page.dart';
import 'dictionary_page.dart';
import 'puzzle_themes.dart';
import 'settings_page.dart';
import 'translator_page.dart';
import 'word_search_menu_page.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  // Full screen: hide the status and navigation bars. A swipe from the edge
  // shows them for a moment, then they hide again.
  await SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
  // Saved dark mode / language, so the first frame already uses them.
  await AppSettings.instance.load();
  runApp(const LexHopper());
}

class LexHopper extends StatelessWidget {
  const LexHopper({super.key});

  @override
  Widget build(BuildContext context) {
    // Rebuilds when the user changes dark mode in Settings.
    return ListenableBuilder(
      listenable: AppSettings.instance,
      builder: (context, _) => _app(),
    );
  }

  Widget _app() {
    return MaterialApp(
      title: 'Lex Hopper',
      theme: lexTheme(brightness: Brightness.light),
      darkTheme: lexTheme(brightness: Brightness.dark),
      themeMode: AppSettings.instance.themeMode,
      // Settings > Language; on first start, the phone's language (Greek or
      // English). GlobalMaterialLocalizations covers the built-in texts.
      locale: AppSettings.instance.locale,
      supportedLocales: const [Locale('en'), Locale('el')],
      localizationsDelegates: GlobalMaterialLocalizations.delegates,
      localeResolutionCallback: (device, supported) =>
          device != null && device.languageCode == 'el'
          ? const Locale('el')
          : const Locale('en'),
      // Settings > Font size: scales all text on top of the phone's own
      // text size (the crossword grid letters opt out, see the game page).
      builder: (context, child) {
        final media = MediaQuery.of(context);
        final factor = AppSettings.instance.fontSize.scale;
        return MediaQuery(
          data: media.copyWith(
            textScaler: factor == 1.0
                ? media.textScaler
                : _ScaledTextScaler(media.textScaler, factor),
          ),
          child: child!,
        );
      },
      scrollBehavior: const _NoOverscrollBehavior(),
      initialRoute: '/',
      routes: {
        '/': (_) => const HomePage(),
        '/games': (_) => const GamesPage(),
        '/crossword': (_) => const CrosswordMenuPage(),
        '/crossword/game': (route) {
          final args =
              ModalRoute.of(route)!.settings.arguments as Map<String, dynamic>?;
          return CrosswordGamePage(
            startLevel: args?['resumeState']?['currentLevel'] ?? 1,
            resumeState: args?['resumeState'],
            language: AppText.of(route).code,
            theme: args?['theme'] as PuzzleTheme?,
          );
        },
        '/word-search': (_) => const WordSearchMenuPage(),
        '/dictionary': (_) => const DictionaryPage(),
        '/translator': (_) => const TranslatorPage(),
        '/settings': (_) => const SettingsPage(),
      },
    );
  }
}

/// Scrolling stops dead at the top and bottom: no Android stretch/glow and
/// no iOS bounce. Applies to every scrollable in the app.
class _NoOverscrollBehavior extends MaterialScrollBehavior {
  const _NoOverscrollBehavior();

  @override
  Widget buildOverscrollIndicator(
    BuildContext context,
    Widget child,
    ScrollableDetails details,
  ) => child;

  @override
  ScrollPhysics getScrollPhysics(BuildContext context) =>
      const ClampingScrollPhysics();
}

/// The phone's text scaler, multiplied by the app's font size setting.
class _ScaledTextScaler extends TextScaler {
  final TextScaler base;
  final double factor;
  const _ScaledTextScaler(this.base, this.factor);

  @override
  double scale(double fontSize) => base.scale(fontSize) * factor;

  @override
  // ignore: deprecated_member_use
  double get textScaleFactor => base.textScaleFactor * factor;

  @override
  bool operator ==(Object other) =>
      other is _ScaledTextScaler &&
      other.base == base &&
      other.factor == factor;

  @override
  int get hashCode => Object.hash(base, factor);
}
