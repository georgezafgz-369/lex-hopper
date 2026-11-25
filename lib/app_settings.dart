// ─────────────────────────────────────────────────────────────────────────────
// APP SETTINGS — dark mode, language, text size and the AI translator,
// saved on the device
// ─────────────────────────────────────────────────────────────────────────────

import 'package:material_ui/material_ui.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'language_packs.dart';

/// A language the app can be shown in: built in (English, Greek), a
/// download (Spanish, German: usable once downloaded), or "Coming soon".
class AppLanguage {
  final String code;
  final String name; // in its own language, e.g. "Ελληνικά"
  final bool builtIn;

  const AppLanguage(this.code, this.name, {this.builtIn = false});

  /// Downloaded on request (Settings > Language).
  bool get isPack => !builtIn && LanguagePacks.instance.offers(code);

  /// Can be picked now.
  bool get available => builtIn || LanguagePacks.instance.isInstalled(code);
}

/// Where Settings > Feedback sends email.
/// TODO: replace with the real support address before release.
const feedbackEmail = 'feedback@example.com';

const appLanguages = [
  AppLanguage('en', 'English', builtIn: true),
  AppLanguage('el', 'Ελληνικά', builtIn: true),
  AppLanguage('es', 'Español'),
  AppLanguage('fr', 'Français'),
  AppLanguage('de', 'Deutsch'),
  AppLanguage('it', 'Italiano'),
];

/// Text size options in Settings. Medium is the normal size.
enum FontSizeOption {
  small('Small', 0.85),
  medium('Medium', 1.0),
  large('Large', 1.2);

  final String label;

  /// Multiplies the phone's own text size.
  final double scale;
  const FontSizeOption(this.label, this.scale);
}

/// The user's settings. Listen to it to rebuild when they change.
class AppSettings extends ChangeNotifier {
  AppSettings._();
  static final AppSettings instance = AppSettings._();

  static const _darkModeKey = 'settings_dark_mode';
  static const _languageKey = 'settings_language';
  static const _fontSizeKey = 'settings_font_size';
  static const _secondaryKey = 'settings_secondary_language';
  static const _aiTranslatorKey = 'settings_ai_translator';
  static const _aiModelKey = 'settings_ai_model';
  static const _wordLookUpKey = 'settings_word_look_up';

  /// True = always dark, false = always light, null = follow the phone
  /// (until the user first flips the switch).
  bool? _darkMode;

  /// Chosen language code, or null to follow the phone (until the user
  /// first picks one in Settings).
  String? _language;

  /// The secondary language's code, or null for none. Never the same as
  /// the main language.
  String? _secondary;
  FontSizeOption _fontSize = FontSizeOption.medium;

  FontSizeOption get fontSize => _fontSize;

  /// Whether the Translator uses the AI model (EuroLLM) once it's
  /// downloaded, when the offline translator isn't (or fails on a text).
  /// Off until turned on.
  bool get aiTranslator => _aiTranslator;
  bool _aiTranslator = false;

  /// Which AI model: "eurollm" (the first) or "gemma4".
  String get aiModel => _aiModel;
  String _aiModel = 'eurollm';

  /// Whether double-tapping a word anywhere in the app opens its page in
  /// the dictionary. On until turned off.
  bool get wordLookUp => _wordLookUp;
  bool _wordLookUp = true;

  bool? get darkMode => _darkMode;
  String? get language => _language;

  /// The secondary language ("en"/"el"), or null when there is none.
  String? get secondaryLanguage =>
      _secondary == languageCode ? null : _secondary;

  /// The app's locale: the chosen language, or null to let the app follow
  /// the phone (Greek if the phone is Greek, otherwise English).
  /// The chosen language, while it can be used (a downloaded language that
  /// was removed falls back to the phone's).
  Locale? get locale {
    final code = _language;
    if (code == null) return null;
    final language = appLanguages.where((l) => l.code == code).firstOrNull;
    return language != null && language.available ? Locale(code) : null;
  }

  /// The language the app is in right now, for code without a
  /// BuildContext: the chosen one, or the phone's ("el" if the phone is in
  /// Greek, otherwise "en"), the same rule as MaterialApp's
  /// localeResolutionCallback.
  String get languageCode =>
      _language ??
      (WidgetsBinding.instance.platformDispatcher.locale.languageCode == 'el'
          ? 'el'
          : 'en');

  /// The language the app is showing: [codeInUse] is the app's actual
  /// locale (pass `Localizations.localeOf(context).languageCode`).
  AppLanguage languageInUse(String codeInUse) => appLanguages.firstWhere(
    (l) => l.code == codeInUse,
    orElse: () => appLanguages.first,
  );

  ThemeMode get themeMode => switch (_darkMode) {
    null => ThemeMode.system,
    true => ThemeMode.dark,
    false => ThemeMode.light,
  };

  /// Reads the saved settings. Call once before the app starts.
  Future<void> load() async {
    final prefs = await SharedPreferences.getInstance();
    _darkMode = prefs.getBool(_darkModeKey);
    _language = prefs.getString(_languageKey);
    _secondary = prefs.getString(_secondaryKey);
    _aiTranslator = prefs.getBool(_aiTranslatorKey) ?? false;
    _aiModel = prefs.getString(_aiModelKey) ?? 'eurollm';
    _wordLookUp = prefs.getBool(_wordLookUpKey) ?? true;
    final size = prefs.getString(_fontSizeKey);
    _fontSize = FontSizeOption.values.firstWhere(
      (o) => o.name == size,
      orElse: () => FontSizeOption.medium,
    );
    notifyListeners();
  }

  Future<void> setDarkMode(bool dark) async {
    _darkMode = dark;
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_darkModeKey, dark);
  }

  Future<void> setWordLookUp(bool on) async {
    _wordLookUp = on;
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_wordLookUpKey, on);
  }

  Future<void> setAiTranslator(bool on) async {
    _aiTranslator = on;
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_aiTranslatorKey, on);
  }

  Future<void> setAiModel(String id) async {
    _aiModel = id;
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_aiModelKey, id);
  }

  Future<void> setFontSize(FontSizeOption option) async {
    _fontSize = option;
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_fontSizeKey, option.name);
  }

  /// Makes [code] the main language. If it was the secondary one, the old
  /// main language becomes the secondary (they swap).
  Future<void> setLanguage(String code) async {
    final language = appLanguages.where((l) => l.code == code).firstOrNull;
    if (language == null || !language.available) return;
    final oldMain = languageCode;
    final swap = _secondary == code && oldMain != code;
    _language = code;
    if (swap) _secondary = oldMain;
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_languageKey, code);
    if (swap) await prefs.setString(_secondaryKey, oldMain);
  }

  /// Makes [code] the secondary language, or removes it with null. The
  /// main language can't also be the secondary one.
  Future<void> setSecondaryLanguage(String? code) async {
    if (code != null) {
      final language = appLanguages.where((l) => l.code == code).firstOrNull;
      if (language == null || !language.available || code == languageCode) {
        return;
      }
    }
    _secondary = code;
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    if (code == null) {
      await prefs.remove(_secondaryKey);
    } else {
      await prefs.setString(_secondaryKey, code);
    }
  }
}
