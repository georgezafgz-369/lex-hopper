// ─────────────────────────────────────────────────────────────────────────────
// APP TEXT — every word the app shows: English, Greek, and the languages
// that are downloaded on request (Spanish, German)
// ─────────────────────────────────────────────────────────────────────────────
//
// Use `AppText.of(context).newGame`. The language comes from the app's locale
// (Settings > Language, or the phone's language on first start), so widgets
// rebuild when it changes. Greek is written naturally in the app's voice —
// dry, warm, encouraging — not translated word for word.

import 'package:material_ui/material_ui.dart';

class AppText {
  /// The language: "en", "el", "es" or "de".
  final String code;

  const AppText._(this.code);

  static const english = AppText._('en');
  static const greek = AppText._('el');
  static const spanish = AppText._('es');
  static const german = AppText._('de');

  /// Language codes the app's own text is available in.
  static const languageCodes = ['en', 'el', 'es', 'de'];

  static AppText of(BuildContext context) =>
      forCode(Localizations.maybeLocaleOf(context)?.languageCode);

  static AppText forCode(String? code) => switch (code) {
    'el' => greek,
    'es' => spanish,
    'de' => german,
    _ => english,
  };

  /// Greek (several texts have Greek-only rules: accents, number words).
  bool get el => code == 'el';

  /// The text in this language: English and Greek always, Spanish and
  /// German where written; anything not yet translated shows in English.
  String _(String en, String el, [String? es, String? de]) => switch (code) {
    'el' => el,
    'es' => es ?? en,
    'de' => de ?? en,
    _ => en,
  };

  /// All capitals, the Greek way: accents are dropped in capitals
  /// ("Ουσιαστικό" -> "ΟΥΣΙΑΣΤΙΚΟ"), except dialytika (ϊ -> Ϊ).
  static String upper(String text) {
    const plain = {
      'ά': 'α',
      'έ': 'ε',
      'ή': 'η',
      'ί': 'ι',
      'ό': 'ο',
      'ύ': 'υ',
      'ώ': 'ω',
      'ΐ': 'ϊ',
      'ΰ': 'ϋ',
      'Ά': 'Α',
      'Έ': 'Ε',
      'Ή': 'Η',
      'Ί': 'Ι',
      'Ό': 'Ο',
      'Ύ': 'Υ',
      'Ώ': 'Ω',
    };
    return text.split('').map((c) => plain[c] ?? c).join().toUpperCase();
  }

  // ── Home ──
  String get searchDictionaryHint => _(
    'Search dictionary...',
    'Αναζήτηση στο λεξικό...',
    'Buscar en el diccionario...',
    'Im Wörterbuch suchen...',
  );
  String get games => _('GAMES', 'ΠΑΙΧΝΙΔΙΑ', 'JUEGOS', 'SPIELE');
  String get gamesTitle => _('Games', 'Παιχνίδια', 'Juegos', 'Spiele');
  String get search => _('Search', 'Αναζήτηση', 'Buscar', 'Suchen');
  String get menu => _('Menu', 'Μενού', 'Menú', 'Menü');
  String get home => _('Home', 'Αρχική', 'Inicio', 'Start');
  String get wordOfTheDay => _(
    'WORD OF THE DAY',
    'ΛΕΞΗ ΤΗΣ ΗΜΕΡΑΣ',
    'PALABRA DEL DÍA',
    'WORT DES TAGES',
  );
  String get seeMore => _('See more', 'Περισσότερα', 'Ver más', 'Mehr');

  /// "Fri 20 Nov" / "Παρ 20 Νοε".
  String shortDate(DateTime d) {
    const daysEn = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
    const daysEl = ['Δευ', 'Τρι', 'Τετ', 'Πεμ', 'Παρ', 'Σαβ', 'Κυρ'];
    const monthsEn = [
      'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', //
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
    ];
    const monthsEl = [
      'Ιαν', 'Φεβ', 'Μαρ', 'Απρ', 'Μαΐ', 'Ιουν', //
      'Ιουλ', 'Αυγ', 'Σεπ', 'Οκτ', 'Νοε', 'Δεκ',
    ];
    const daysEs = ['lun', 'mar', 'mié', 'jue', 'vie', 'sáb', 'dom'];
    const daysDe = ['Mo', 'Di', 'Mi', 'Do', 'Fr', 'Sa', 'So'];
    const monthsEs = [
      'ene', 'feb', 'mar', 'abr', 'may', 'jun', //
      'jul', 'ago', 'sept', 'oct', 'nov', 'dic',
    ];
    const monthsDe = [
      'Jan.', 'Feb.', 'März', 'Apr.', 'Mai', 'Juni', //
      'Juli', 'Aug.', 'Sept.', 'Okt.', 'Nov.', 'Dez.',
    ];
    final (days, months) = switch (code) {
      'el' => (daysEl, monthsEl),
      'es' => (daysEs, monthsEs),
      'de' => (daysDe, monthsDe),
      _ => (daysEn, monthsEn),
    };
    final day = days[d.weekday - 1];
    final month = months[d.month - 1];
    // German writes the day with a dot: "Di 24. Nov."
    return code == 'de' ? '$day ${d.day}. $month' : '$day ${d.day} $month';
  }

  /// "Crossword · Find the Words · Riddles", under the home Games card.
  String get gamesList => '$crossword · $findTheWords · $riddles';
  String get reference => _('REFERENCE', 'ΑΝΑΦΟΡΑ', 'CONSULTA', 'NACHSCHLAGEN');
  String get other => _('OTHER', 'ΑΛΛΑ', 'OTROS', 'WEITERES');
  String get crossword =>
      _('Crossword', 'Σταυρόλεξο', 'Crucigrama', 'Kreuzworträtsel');
  String get crosswordSubtitle => _(
    'Set across and down in the printed newspaper tradition.',
    'Οριζόντια και κάθετα, όπως στο σταυρόλεξο της εφημερίδας.',
    'Horizontales y verticales, como en el periódico.',
    'Waagerecht und senkrecht, wie in der Zeitung.',
  );
  String get findTheWords => _(
    'Find the Words',
    'Βρες τις Λέξεις',
    'Encuentra las palabras',
    'Finde die Wörter',
  );
  String get findTheWordsSubtitle => _(
    'Scan for hidden words through five soft highlighter tints.',
    'Ψάξε κρυμμένες λέξεις με πέντε απαλά χρώματα μαρκαδόρου.',
    'Busca palabras escondidas con cinco suaves colores de marcador.',
    'Suche versteckte Wörter mit fünf sanften Textmarkerfarben.',
  );
  String get riddles => _('Riddles', 'Αινίγματα', 'Acertijos', 'Rätsel');
  String get riddlesSubtitle => _(
    'Pithy brain teasers with dry wit and no pressure.',
    'Σύντομοι γρίφοι με λεπτό χιούμορ και χωρίς άγχος.',
    'Adivinanzas breves, con humor seco y sin prisas.',
    'Kurze Denkaufgaben mit trockenem Humor und ohne Druck.',
  );
  String get dictionary =>
      _('Dictionary', 'Λεξικό', 'Diccionario', 'Wörterbuch');
  String get dictionarySubtitle => _(
    'Look up words and their definitions.',
    'Βρες λέξεις και τις σημασίες τους.',
    'Busca palabras y sus significados.',
    'Schlag Wörter und ihre Bedeutungen nach.',
  );
  String get translator =>
      _('Translator', 'Μεταφραστής', 'Traductor', 'Übersetzer');
  String get translateTextHint => _(
    'Translate text',
    'Μετάφραση κειμένου',
    'Traducir texto',
    'Text übersetzen',
  );
  String get paste => _('Paste', 'Επικόλληση', 'Pegar', 'Einfügen');
  String get swapLanguages => _(
    'Swap languages',
    'Αλλαγή γλωσσών',
    'Cambiar idiomas',
    'Sprachen tauschen',
  );
  String get speak => _('Speak', 'Εκφώνηση', 'Escuchar', 'Vorlesen');
  String get copy => _('Copy', 'Αντιγραφή', 'Copiar', 'Kopieren');
  String get copied => _('Copied', 'Αντιγράφηκε', 'Copiado', 'Kopiert');
  String get preparingTranslator => _(
    'Getting the translator ready…',
    'Ετοιμάζεται ο μεταφραστής…',
    'Preparando el traductor…',
    'Der Übersetzer wird vorbereitet…',
  );
  String get translating =>
      _('Translating…', 'Μετάφραση…', 'Traduciendo…', 'Übersetze…');
  String get translateFailed => _(
    "Couldn't translate this text.",
    'Δεν έγινε η μετάφραση αυτού του κειμένου.',
    'No se pudo traducir este texto.',
    'Dieser Text konnte nicht übersetzt werden.',
  );
  String get noTranslatorYet => _(
    "The translator isn't downloaded yet. Connect to the internet and it "
        'downloads by itself. Words and phrases from the dictionary work '
        'already.',
    'Ο μεταφραστής δεν έχει κατέβει ακόμα. Σύνδεσε το ίντερνετ και θα '
        'κατέβει μόνος του. Οι λέξεις και οι φράσεις του λεξικού λειτουργούν '
        'ήδη.',
    'El traductor aún no se ha descargado. Conéctate a internet y se '
        'descargará solo. Las palabras y frases del diccionario ya funcionan.',
    'Der Übersetzer ist noch nicht geladen. Verbinde dich mit dem Internet, '
        'dann lädt er sich von selbst. Wörter und Wendungen aus dem Wörterbuch '
        'funktionieren schon.',
  );
  String translatorDownloading(int percent) => _(
    'Getting the translator ready… $percent%. Words and phrases from the '
        'dictionary work already.',
    'Ο μεταφραστής ετοιμάζεται… $percent%. Οι λέξεις και οι φράσεις του '
        'λεξικού λειτουργούν ήδη.',
    'Preparando el traductor… $percent%. Las palabras y frases del '
        'diccionario ya funcionan.',
    'Der Übersetzer wird vorbereitet… $percent%. Wörter und Wendungen '
        'aus dem Wörterbuch funktionieren schon.',
  );
  String get translatorSubtitle => _(
    'Translate words and phrases.',
    'Μετάφρασε λέξεις και φράσεις.',
    'Traduce palabras y frases.',
    'Übersetze Wörter und Sätze.',
  );
  // Settings > Offline translator (OPUS-MT).
  String get offlineTranslator => _(
    'Offline translator',
    'Μεταφραστής χωρίς ίντερνετ',
    'Traductor sin conexión',
    'Offline-Übersetzer',
  );
  String offlineTranslatorDownload(int mb) => _(
    'Translates sentences without internet · download $mb MB',
    'Μεταφράζει προτάσεις χωρίς ίντερνετ · λήψη $mb MB',
    'Traduce frases sin internet · descarga de $mb MB',
    'Übersetzt Sätze ohne Internet · Download $mb MB',
  );
  String get offlineTranslatorSoon => _(
    'Translates sentences without internet · coming soon',
    'Μεταφράζει προτάσεις χωρίς ίντερνετ · έρχεται σύντομα',
    'Traduce frases sin internet · próximamente',
    'Übersetzt Sätze ohne Internet · bald verfügbar',
  );
  String offlineTranslatorDownloading(int percent) => _(
    'Downloading… $percent%',
    'Λήψη… $percent%',
    'Descargando… $percent%',
    'Lädt… $percent%',
  );
  String get offlineTranslatorReady => _(
    'Ready · works without internet · OPUS-MT by Helsinki-NLP (CC BY 4.0)',
    'Έτοιμος · λειτουργεί χωρίς ίντερνετ · OPUS-MT από το Helsinki-NLP (CC BY 4.0)',
    'Listo · funciona sin internet · OPUS-MT de Helsinki-NLP (CC BY 4.0)',
    'Bereit · funktioniert ohne Internet · OPUS-MT von Helsinki-NLP (CC BY 4.0)',
  );
  String get offlineTranslatorFailed => _(
    'Download stopped. Tap to try again.',
    'Η λήψη σταμάτησε. Πάτησε για νέα προσπάθεια.',
    'La descarga se detuvo. Toca para intentarlo de nuevo.',
    'Download angehalten. Tippe, um es erneut zu versuchen.',
  );
  String get offlineDownloadTitle => _(
    'Download the offline translator?',
    'Λήψη του μεταφραστή;',
    '¿Descargar el traductor sin conexión?',
    'Offline-Übersetzer herunterladen?',
  );
  String offlineDownloadBody(int mb) => _(
    'Translates sentences between English and Greek, without internet. '
        'A one-time download of about $mb MB (Wi-Fi recommended).',
    'Μεταφράζει προτάσεις από και προς τα αγγλικά, χωρίς ίντερνετ. '
        'Κατεβαίνει μία φορά, περίπου $mb MB (καλύτερα με Wi-Fi).',
    'Traduce frases entre inglés y griego, sin internet. Se descarga '
        'una vez, unos $mb MB (mejor con Wi-Fi).',
    'Übersetzt Sätze zwischen Englisch und Griechisch, ohne Internet. '
        'Einmaliger Download von etwa $mb MB (am besten mit WLAN).',
  );
  String get offlineDeleteTitle => _(
    'Delete the offline translator?',
    'Διαγραφή του μεταφραστή;',
    '¿Borrar el traductor sin conexión?',
    'Offline-Übersetzer löschen?',
  );
  String offlineDeleteBody(int mb) => _(
    'Frees $mb MB. Sentences won\'t be translated until you download it '
        'again.',
    'Ελευθερώνει $mb MB. Οι προτάσεις δεν θα μεταφράζονται μέχρι να τον '
        'ξανακατεβάσεις.',
    'Libera $mb MB. Las frases no se traducirán hasta que lo vuelvas a '
        'descargar.',
    'Gibt $mb MB frei. Sätze werden erst wieder übersetzt, wenn du ihn '
        'erneut herunterlädst.',
  );
  String get delete => _('Delete', 'Διαγραφή', 'Borrar', 'Löschen');

  // Settings > AI model (EuroLLM or Gemma 4): translates and chats.
  String get aiTranslator =>
      _('AI model', 'Μοντέλο AI', 'Modelo de IA', 'KI-Modell');
  String get aiTranslatorChecking =>
      _('Checking…', 'Έλεγχος…', 'Comprobando…', 'Prüfe…');
  String get aiTranslatorOff => _('Off', 'Ανενεργός', 'Desactivado', 'Aus');
  String aiTranslatorOn(String model) => _(
    'On · $model, works without internet',
    'Ενεργό · $model, λειτουργεί χωρίς ίντερνετ',
    'Activado · $model, funciona sin internet',
    'An · $model, funktioniert ohne Internet',
  );
  String aiTranslatorDownloading(String model, int? percent) => _(
    'Downloading $model… ${percent == null ? '' : '$percent%'}',
    'Λήψη $model… ${percent == null ? '' : '$percent%'}',
    'Descargando $model… ${percent == null ? '' : '$percent%'}',
    'Lade $model… ${percent == null ? '' : '$percent%'}',
  );
  String aiTranslatorNeedsMemory(int gb) => _(
    'Needs a phone with at least $gb GB of memory.',
    'Χρειάζεται κινητό με τουλάχιστον $gb GB μνήμης.',
    'Necesita un teléfono con al menos $gb GB de memoria.',
    'Braucht ein Handy mit mindestens $gb GB Speicher.',
  );
  String aiModelSize(int mb) => _(
    '${(mb / 1000).toStringAsFixed(1)} GB',
    '${(mb / 1000).toStringAsFixed(1)} GB',
    '${(mb / 1000).toStringAsFixed(1)} GB',
    '${(mb / 1000).toStringAsFixed(1)} GB',
  );
  String get aiTranslatorFailed => _(
    'Download stopped. Tap to try again.',
    'Η λήψη σταμάτησε. Πάτησε για νέα προσπάθεια.',
    'La descarga se detuvo. Toca para intentarlo de nuevo.',
    'Download angehalten. Tippe, um es erneut zu versuchen.',
  );
  String aiDownloadTitle(String model) => _(
    'Download $model?',
    'Λήψη: $model;',
    '¿Descargar $model?',
    '$model herunterladen?',
  );
  String aiDownloadBody(String model, int mb) => _(
    '$model reads the whole sentence, so it picks the right sense of a '
        'word, and it answers in Chat with AI. It is a one-time download '
        'of about $mb MB (Wi-Fi recommended); after that it works without '
        'internet.',
    'Το $model διαβάζει όλη την πρόταση, οπότε διαλέγει τη σωστή σημασία '
        'κάθε λέξης, και απαντά στη Συζήτηση με AI. Κατεβαίνει μία φορά, '
        'περίπου $mb MB (καλύτερα με Wi-Fi)· μετά λειτουργεί χωρίς ίντερνετ.',
    '$model lee la frase entera, así que elige el sentido correcto de '
        'cada palabra, y responde en el chat con la IA. Se descarga una vez, '
        'unos $mb MB (mejor con Wi-Fi); después funciona sin internet.',
    '$model liest den ganzen Satz und wählt so die richtige Bedeutung '
        'jedes Worts, und antwortet im Chat mit KI. Einmaliger Download von '
        'etwa $mb MB (am besten mit WLAN); danach funktioniert er ohne '
        'Internet.',
  );
  String get download => _('Download', 'Λήψη', 'Descargar', 'Herunterladen');
  String get cancel => _('Cancel', 'Άκυρο', 'Cancelar', 'Abbrechen');
  String get aiTurnOffTitle => _(
    'Turn off the AI translator?',
    'Απενεργοποίηση του μεταφραστή AI;',
    '¿Desactivar el traductor con IA?',
    'KI-Übersetzer ausschalten?',
  );
  String aiTurnOffBody(int mb) => _(
    'Keep the model ($mb MB) to turn it back on later without downloading '
        'again, or delete it to free the space.',
    'Κράτησε το μοντέλο ($mb MB) για να το ξαναενεργοποιήσεις χωρίς νέα '
        'λήψη, ή διάγραψέ το για να ελευθερώσεις χώρο.',
    'Guarda el modelo ($mb MB) para volver a activarlo sin descargarlo '
        'de nuevo, o bórralo para liberar espacio.',
    'Behalte das Modell ($mb MB), um ihn später ohne neuen Download '
        'einzuschalten, oder lösche es, um Platz zu schaffen.',
  );
  String get keepModel => _('Keep it', 'Κράτησέ το', 'Guardarlo', 'Behalten');
  String get deleteModel =>
      _('Delete it', 'Διάγραψέ το', 'Borrarlo', 'Löschen');

  // First launch: downloading the dictionary.
  String get gettingDictionary => _(
    'Getting the dictionary ready',
    'Ετοιμάζεται το λεξικό',
    'Preparando el diccionario',
    'Das Wörterbuch wird vorbereitet',
  );
  String dictionaryDownloadNote(int mb) => _(
    'A one-time download of about $mb MB. After that, Lex Hopper works '
        'without internet.',
    'Κατεβαίνει μία φορά, περίπου $mb MB. Μετά, το Lex Hopper λειτουργεί '
        'χωρίς ίντερνετ.',
    'Se descarga una vez, unos $mb MB. Después, Lex Hopper funciona '
        'sin internet.',
    'Einmaliger Download von etwa $mb MB. Danach funktioniert Lex '
        'Hopper ohne Internet.',
  );
  String dictionaryDownloading(int percent) => _(
    'Downloading… $percent%',
    'Λήψη… $percent%',
    'Descargando… $percent%',
    'Lädt… $percent%',
  );
  String get dictionaryDownloadFailed => _(
    "Couldn't download the dictionary. Check the internet connection and "
        'try again.',
    'Δεν έγινε η λήψη του λεξικού. Έλεγξε τη σύνδεση στο ίντερνετ και '
        'δοκίμασε ξανά.',
    'No se pudo descargar el diccionario. Revisa la conexión a internet '
        'e inténtalo de nuevo.',
    'Das Wörterbuch konnte nicht geladen werden. Prüfe die '
        'Internetverbindung und versuche es erneut.',
  );

  String get settings => _('Settings', 'Ρυθμίσεις', 'Ajustes', 'Einstellungen');
  String get settingsSubtitle => _(
    'Customize your experience.',
    'Προσάρμοσε την εμπειρία σου.',
    'Personaliza tu experiencia.',
    'Pass die App an dich an.',
  );
  String get comingSoon =>
      _('Coming soon', 'Έρχεται σύντομα', 'Próximamente', 'Bald verfügbar');

  // ── Crossword menu ──
  String get dailyCrossword => _(
    'DAILY CROSSWORD',
    'ΣΤΑΥΡΟΛΕΞΟ ΤΗΣ ΗΜΕΡΑΣ',
    'CRUCIGRAMA DEL DÍA',
    'KREUZWORTRÄTSEL DES TAGES',
  );
  String get newGame =>
      _('New Game', 'Νέο Παιχνίδι', 'Nueva partida', 'Neues Spiel');
  String get newGameSubtitle => _(
    'Start a fresh puzzle.',
    'Ξεκίνα ένα καινούργιο σταυρόλεξο.',
    'Empieza un crucigrama nuevo.',
    'Starte ein neues Rätsel.',
  );
  String get continueGame =>
      _('Continue', 'Συνέχεια', 'Continuar', 'Weiterspielen');
  String get noSavedGame => _(
    'No saved game.',
    'Δεν υπάρχει αποθηκευμένο παιχνίδι.',
    'No hay ninguna partida guardada.',
    'Kein gespeichertes Spiel.',
  );
  String get chooseSubject =>
      _('Choose a subject', 'Διάλεξε θέμα', 'Elige un tema', 'Wähle ein Thema');
  String get allThemes =>
      _('All subjects', 'Όλα τα θέματα', 'Todos los temas', 'Alle Themen');
  String get allSubjectsSubtitle => _(
    'Words from every subject.',
    'Λέξεις από όλα τα θέματα.',
    'Palabras de todos los temas.',
    'Wörter aus allen Themen.',
  );
  String wordCount(int n) {
    final s = n >= 1000
        ? '${n ~/ 1000}${el ? '.' : ','}${(n % 1000).toString().padLeft(3, '0')}'
        : '$n';
    return _('$s words', '$s λέξεις', '$s palabras', '$s Wörter');
  }

  String continueWithSubject(int level, String subject) => _(
    'Pick up where you left off — Level $level, $subject.',
    'Συνέχισε από εκεί που σταμάτησες — Επίπεδο $level, $subject.',
    'Sigue donde lo dejaste — Nivel $level, $subject.',
    'Mach weiter, wo du aufgehört hast — Level $level, $subject.',
  );
  String continueSubtitle(int level) => _(
    'Pick up where you left off — Level $level.',
    'Συνέχισε από εκεί που σταμάτησες — Επίπεδο $level.',
    'Sigue donde lo dejaste — Nivel $level.',
    'Mach weiter, wo du aufgehört hast — Level $level.',
  );

  // ── Crossword game ──
  static const _numbersEn = [
    'Zero',
    'One',
    'Two',
    'Three',
    'Four',
    'Five',
    'Six',
    'Seven',
    'Eight',
    'Nine',
    'Ten',
    'Eleven',
    'Twelve',
    'Thirteen',
    'Fourteen',
    'Fifteen',
    'Sixteen',
    'Seventeen',
    'Eighteen',
    'Nineteen',
    'Twenty',
  ];
  static const _numbersEl = [
    'Μηδέν',
    'Ένα',
    'Δύο',
    'Τρία',
    'Τέσσερα',
    'Πέντε',
    'Έξι',
    'Επτά',
    'Οκτώ',
    'Εννέα',
    'Δέκα',
    'Έντεκα',
    'Δώδεκα',
    'Δεκατρία',
    'Δεκατέσσερα',
    'Δεκαπέντε',
    'Δεκαέξι',
    'Δεκαεπτά',
    'Δεκαοκτώ',
    'Δεκαεννέα',
    'Είκοσι',
  ];

  /// "Level Two" / "Επίπεδο Δύο" (numerals above twenty).
  String level(int n) {
    // Number words in English and Greek ("Level Two"), digits otherwise.
    final names = switch (code) {
      'el' => _numbersEl,
      'en' => _numbersEn,
      _ => const <String>[],
    };
    final number = n >= 0 && n < names.length ? names[n] : '$n';
    return _(
      'Level $number',
      'Επίπεδο $number',
      'Nivel $number',
      'Level $number',
    );
  }

  String settingLevel(int n) => _(
    'Setting ${level(n)}…',
    'Ετοιμάζεται: ${level(n)}…',
    'Preparando: ${level(n)}…',
    'Bereite vor: ${level(n)}…',
  );
  String get couldNotSetPuzzle => _(
    "Couldn't set this puzzle. Try again?",
    'Δεν ήταν δυνατό να στηθεί ο γρίφος. Δοκιμάζεις ξανά;',
    'No se pudo montar este crucigrama. ¿Lo intentamos de nuevo?',
    'Dieses Rätsel ließ sich nicht erstellen. Noch einmal versuchen?',
  );
  String get tryAgain =>
      _('Try again', 'Ξανά', 'Reintentar', 'Erneut versuchen');
  String get searchOnDictionary => _(
    'Search on dictionary',
    'Αναζήτηση στο λεξικό',
    'Buscar en el diccionario',
    'Im Wörterbuch suchen',
  );
  String get acrossClues =>
      _('ACROSS CLUES', 'ΟΡΙΖΟΝΤΙΑ', 'HORIZONTALES', 'WAAGERECHT');
  String get downClues => _('DOWN CLUES', 'ΚΑΘΕΤΑ', 'VERTICALES', 'SENKRECHT');
  String get clear => _('Clear', 'Σβήσιμο', 'Borrar', 'Löschen');
  String get hint => _('Hint', 'Βοήθεια', 'Pista', 'Tipp');
  String get check => _('Check', 'Έλεγχος', 'Comprobar', 'Prüfen');
  String get nextLevel =>
      _('Next level', 'Επόμενο επίπεδο', 'Siguiente nivel', 'Nächstes Level');
  String get nextLevelTest => _(
    'Next level (test)',
    'Επόμενο επίπεδο (δοκιμή)',
    'Siguiente nivel (prueba)',
    'Nächstes Level (Test)',
  );
  // ── Find the Words ──
  String get wordSearchKicker => _(
    'HIDDEN WORDS',
    'ΚΡΥΜΜΕΝΕΣ ΛΕΞΕΙΣ',
    'PALABRAS ESCONDIDAS',
    'VERSTECKTE WÖRTER',
  );
  String get newWordSearchSubtitle => _(
    'Start a fresh grid of hidden words.',
    'Ξεκίνα ένα καινούργιο πλέγμα.',
    'Empieza una nueva sopa de letras.',
    'Starte ein neues Buchstabengitter.',
  );
  String get wordsToFind => _(
    'WORDS TO FIND',
    'ΛΕΞΕΙΣ ΓΙΑ ΝΑ ΒΡΕΙΣ',
    'PALABRAS POR ENCONTRAR',
    'GESUCHTE WÖRTER',
  );
  String foundCount(int found, int total) => _(
    '$found of $total found',
    '$found από $total',
    '$found de $total',
    '$found von $total',
  );
  String get allWordsFound => _(
    'All words found!',
    'Βρήκες όλες τις λέξεις!',
    '¡Encontraste todas las palabras!',
    'Alle Wörter gefunden!',
  );
  String get dragToFind => _(
    'Drag across a word, from its first letter to its last.',
    'Σύρε το δάχτυλο πάνω σε μια λέξη, από το πρώτο ως το τελευταίο γράμμα.',
    'Desliza el dedo sobre una palabra, de la primera a la última letra.',
    'Zieh den Finger über ein Wort, vom ersten bis zum letzten Buchstaben.',
  );

  // ── Dictionary ──
  String get partOfSpeech =>
      _('PART OF SPEECH', 'ΜΕΡΟΣ ΤΟΥ ΛΟΓΟΥ', 'CATEGORÍA GRAMATICAL', 'WORTART');
  String get structure => _('STRUCTURE', 'ΔΟΜΗ', 'ESTRUCTURA', 'AUFBAU');
  String get subject => _('SUBJECT', 'ΘΕΜΑΤΙΚΟ ΠΕΔΙΟ', 'TEMA', 'THEMA');
  String get all => _('All', 'Όλα', 'Todo', 'Alle');
  String get allSubjects =>
      _('All subjects', 'Όλα τα πεδία', 'Todos los temas', 'Alle Themen');
  String get general => _('General', 'Γενικά', 'General', 'Allgemein');
  String get generalNoSubject => _(
    'General (no subject)',
    'Γενικά (χωρίς πεδίο)',
    'General (sin tema)',
    'Allgemein (ohne Thema)',
  );
  String get loadingDictionary => _(
    'Loading dictionary…',
    'Φορτώνει το λεξικό…',
    'Cargando el diccionario…',
    'Wörterbuch wird geladen…',
  );
  String get searchToBegin => _(
    'Search for a word to begin.',
    'Ψάξε μια λέξη για να ξεκινήσεις.',
    'Busca una palabra para empezar.',
    'Suche ein Wort, um zu beginnen.',
  );
  String get noMatches => _(
    'No matches.',
    'Δεν βρέθηκε τίποτα.',
    'Sin resultados.',
    'Keine Treffer.',
  );
  String alsoCalledQuoted(String name) => _(
    'Also called “$name”',
    'Λέγεται και «$name»',
    'También llamado «$name»',
    'Auch „$name“ genannt',
  );
  String meanings(int n) => _(
    '$n ${n == 1 ? 'meaning' : 'meanings'}',
    '$n ${n == 1 ? 'σημασία' : 'σημασίες'}',
    '$n ${n == 1 ? 'significado' : 'significados'}',
    '$n ${n == 1 ? 'Bedeutung' : 'Bedeutungen'}',
  );

  static const _posEn = {
    'noun': 'Noun',
    'verb': 'Verb',
    'adj': 'Adjective',
    'adv': 'Adverb',
    'pron': 'Pronoun',
    'prep': 'Preposition',
    'conj': 'Conjunction',
    'interj': 'Interjection',
    'det': 'Determiner',
    'art': 'Article',
    'part': 'Participle',
  };
  static const _posEl = {
    'noun': 'Ουσιαστικό',
    'verb': 'Ρήμα',
    'adj': 'Επίθετο',
    'adv': 'Επίρρημα',
    'pron': 'Αντωνυμία',
    'prep': 'Πρόθεση',
    'conj': 'Σύνδεσμος',
    'interj': 'Επιφώνημα',
    'det': 'Προσδιοριστής',
    'art': 'Άρθρο',
    'part': 'Μετοχή',
  };

  static const _posEs = {
    'noun': 'Sustantivo',
    'verb': 'Verbo',
    'adj': 'Adjetivo',
    'adv': 'Adverbio',
    'pron': 'Pronombre',
    'prep': 'Preposición',
    'conj': 'Conjunción',
    'interj': 'Interjección',
    'det': 'Determinante',
    'art': 'Artículo',
    'part': 'Participio',
  };
  static const _posDe = {
    'noun': 'Substantiv',
    'verb': 'Verb',
    'adj': 'Adjektiv',
    'adv': 'Adverb',
    'pron': 'Pronomen',
    'prep': 'Präposition',
    'conj': 'Konjunktion',
    'interj': 'Interjektion',
    'det': 'Determinativ',
    'art': 'Artikel',
    'part': 'Partizip',
  };

  /// Part of speech name, e.g. "adj" -> "Adjective" / "Επίθετο".
  String partOfSpeechName(String pos) =>
      switch (code) {
        'el' => _posEl,
        'es' => _posEs,
        'de' => _posDe,
        _ => _posEn,
      }[pos] ??
      pos.toUpperCase();

  // ── Word page ──
  String get close => _('Close', 'Κλείσιμο', 'Cerrar', 'Schließen');
  String get noEntryYet => _(
    'No entry for this word yet.',
    'Δεν υπάρχει ακόμα λήμμα για αυτή τη λέξη.',
    'Aún no hay una entrada para esta palabra.',
    'Für dieses Wort gibt es noch keinen Eintrag.',
  );
  String syllables(int n) =>
      _('$n syllables', '$n συλλαβές', '$n sílabas', '$n Silben');
  String plural(String forms) => _(
    'plural $forms',
    'πληθυντικός: $forms',
    'plural $forms',
    'Plural $forms',
  );
  String get moreExamples => _(
    'MORE EXAMPLES',
    'ΠΕΡΙΣΣΟΤΕΡΑ ΠΑΡΑΔΕΙΓΜΑΤΑ',
    'MÁS EJEMPLOS',
    'WEITERE BEISPIELE',
  );
  String get phrases => _('PHRASES', 'ΦΡΑΣΕΙΣ', 'FRASES', 'WENDUNGEN');
  String get aboutTheWord =>
      _('ABOUT THE WORD', 'ΓΙΑ ΤΗ ΛΕΞΗ', 'SOBRE LA PALABRA', 'ZUM WORT');
  String get structureLabel => _('Structure', 'Δομή', 'Estructura', 'Aufbau');
  String structureWord(String name) =>
      _('$name word', '$name λέξη', 'palabra $name', '$name Wort');
  String get originLabel => _('Origin', 'Προέλευση', 'Origen', 'Herkunft');
  String borrowedFrom(String languages) => _(
    'Borrowed from $languages',
    'Δάνειο από: $languages',
    'Tomado de $languages',
    'Entlehnt aus $languages',
  );
  String fromLanguage(String language) => _(
    'From $language',
    'Από: $language',
    'Del $language',
    'Aus dem $language',
  );
  String get relatedForms => _(
    'Related forms',
    'Συγγενικοί τύποι',
    'Formas relacionadas',
    'Verwandte Formen',
  );
  String get relatingToIt =>
      _('Relating to it', 'Σχετικά επίθετα', 'Relacionado', 'Dazu gehörend');
  String get alsoCalled =>
      _('Also called', 'Λέγεται και', 'También llamado', 'Auch genannt');
  String get meaningLabel =>
      _('Meaning', 'Σημασία', 'Significado', 'Bedeutung');
  String get examplesLabel =>
      _('Examples', 'Παραδείγματα', 'Ejemplos', 'Beispiele');
  String get synonyms => _('Synonyms', 'Συνώνυμα', 'Sinónimos', 'Synonyme');
  String get opposites => _('Opposites', 'Αντίθετα', 'Antónimos', 'Gegenteile');
  String moreCount(int n) =>
      _('+$n more', '+$n ακόμα', '+$n más', '+$n weitere');

  /// [accent] is "american", "british" or "greek".
  String noVoice(String accent) {
    final el = this.el;
    final which = {
      'american': el ? 'αμερικανική' : 'American',
      'british': el ? 'βρετανική' : 'British',
      'greek': el ? 'ελληνική' : 'Greek',
    }[accent]!;
    return el
        ? 'Δεν υπάρχει $which φωνή σε αυτό το τηλέφωνο. Μπορείς να προσθέσεις '
              'μία από τις ρυθμίσεις μετατροπής κειμένου σε ομιλία του '
              'τηλεφώνου.'
        : "No $which voice on this phone. You can add one in the phone's "
              'text-to-speech settings.';
  }

  // ── Settings ──
  String get language => _('Language', 'Γλώσσα', 'Idioma', 'Sprache');
  String get mainLanguage => _('Main', 'Κύρια', 'Principal', 'Haupt');
  String get secondaryLanguage =>
      _('Secondary', 'Δευτερεύουσα', 'Secundario', 'Zweitsprache');
  String get setAsMain => _(
    'Set as main language',
    'Ορισμός ως κύρια γλώσσα',
    'Usar como idioma principal',
    'Als Hauptsprache festlegen',
  );
  String get setAsSecondary => _(
    'Set as secondary language',
    'Ορισμός ως δευτερεύουσα γλώσσα',
    'Usar como idioma secundario',
    'Als Zweitsprache festlegen',
  );
  String get removeSecondary => _(
    'Remove as secondary language',
    'Αφαίρεση από δευτερεύουσα γλώσσα',
    'Quitar como idioma secundario',
    'Als Zweitsprache entfernen',
  );

  /// A language's name written in this text's language, e.g. 'en' →
  /// "English" / "Αγγλικά".
  String languageName(String code) => switch (code) {
    'en' => _('English', 'Αγγλικά', 'Inglés', 'Englisch'),
    'el' => _('Greek', 'Ελληνικά', 'Griego', 'Griechisch'),
    'es' => _('Spanish', 'Ισπανικά', 'Español', 'Spanisch'),
    'fr' => _('French', 'Γαλλικά', 'Francés', 'Französisch'),
    'de' => _('German', 'Γερμανικά', 'Alemán', 'Deutsch'),
    'it' => _('Italian', 'Ιταλικά', 'Italiano', 'Italienisch'),
    _ => code,
  };
  String withSecondary(String main, String second) => _(
    '$main · secondary: $second',
    '$main · δευτερεύουσα: $second',
    '$main · secundario: $second',
    '$main · Zweitsprache: $second',
  );
  String get darkMode =>
      _('Dark mode', 'Σκούρο θέμα', 'Modo oscuro', 'Dunkler Modus');
  String get on => _('On', 'Ενεργό', 'Activado', 'An');
  String get off => _('Off', 'Ανενεργό', 'Desactivado', 'Aus');
  String get fontSize =>
      _('Font size', 'Μέγεθος γραμμάτων', 'Tamaño del texto', 'Schriftgröße');
  String get small => _('Small', 'Μικρά', 'Pequeño', 'Klein');
  String get medium => _('Medium', 'Μεσαία', 'Mediano', 'Mittel');
  String get large => _('Large', 'Μεγάλα', 'Grande', 'Groß');
  String get feedback => _('Feedback', 'Σχόλια', 'Comentarios', 'Feedback');
  String get feedbackSubtitle => _(
    'Tell us what you think or report a problem.',
    'Πες μας τη γνώμη σου ή ανέφερε ένα πρόβλημα.',
    'Dinos qué te parece o informa de un problema.',
    'Sag uns deine Meinung oder melde ein Problem.',
  );
  String get feedbackSubject => _(
    'Lex Hopper feedback',
    'Σχόλια για το Lex Hopper',
    'Comentarios sobre Lex Hopper',
    'Feedback zu Lex Hopper',
  );
  String noEmailApp(String email) => _(
    'No email app found. Write to us at $email',
    'Δεν βρέθηκε εφαρμογή email. Γράψε μας στο $email',
    'No se encontró ninguna app de correo. Escríbenos a $email',
    'Keine E-Mail-App gefunden. Schreib uns an $email',
  );
  String get chatWithAi =>
      _('Chat with AI', 'Συζήτηση με AI', 'Chatea con la IA', 'Chat mit KI');
  String get chatWithAiSubtitle => _(
    'Practise a language by chatting.',
    'Εξασκήσου σε μια γλώσσα συζητώντας.',
    'Practica un idioma conversando.',
    'Übe eine Sprache im Gespräch.',
  );
  String get chatHello => _(
    'Hi! Let’s practise.',
    'Γεια! Ας εξασκηθούμε.',
    '¡Hola! Vamos a practicar.',
    'Hallo! Lass uns üben.',
  );
  String get chatIntro => _(
    'Write in any language you’re learning. I’ll answer, and gently fix '
        'your mistakes.',
    'Γράψε σε όποια γλώσσα μαθαίνεις. Θα σου απαντώ και θα διορθώνω '
        'απαλά τα λάθη σου.',
    'Escribe en el idioma que estés aprendiendo. Te responderé y '
        'corregiré tus errores con suavidad.',
    'Schreib in der Sprache, die du lernst. Ich antworte und korrigiere '
        'sanft deine Fehler.',
  );
  String get chatHint => _(
    'Write a message…',
    'Γράψε ένα μήνυμα…',
    'Escribe un mensaje…',
    'Schreib eine Nachricht…',
  );
  String get chatStarterCafe => _(
    'Let’s order a coffee in a café',
    'Ας παραγγείλουμε καφέ σε ένα καφέ',
    'Pidamos un café en una cafetería',
    'Lass uns im Café einen Kaffee bestellen',
  );
  String get chatStarterCorrect => _(
    'Correct my sentence',
    'Διόρθωσε την πρότασή μου',
    'Corrige mi frase',
    'Korrigiere meinen Satz',
  );
  String get chatStarterWord => _(
    'Teach me a new word',
    'Μάθε μου μια καινούργια λέξη',
    'Enséñame una palabra nueva',
    'Bring mir ein neues Wort bei',
  );
  String get chatStarterTravel => _(
    'Help me ask for directions',
    'Βοήθησέ με να ρωτήσω πώς θα πάω κάπου',
    'Ayúdame a pedir indicaciones',
    'Hilf mir, nach dem Weg zu fragen',
  );
  String get chatNoAi => _(
    'To chat, turn on an AI model in Settings > AI model (EuroLLM or '
        'Gemma 4). It downloads once and then works without internet.',
    'Για να συζητήσουμε, ενεργοποίησε ένα μοντέλο AI στις Ρυθμίσεις > '
        'Μοντέλο AI (EuroLLM ή Gemma 4). Κατεβαίνει μία φορά και μετά '
        'λειτουργεί χωρίς ίντερνετ.',
    'Para chatear, activa un modelo de IA en Ajustes > Modelo de IA '
        '(EuroLLM o Gemma 4). Se descarga una vez y luego funciona sin '
        'internet.',
    'Zum Chatten schalte in Einstellungen > KI-Modell ein KI-Modell ein '
        '(EuroLLM oder Gemma 4). Es wird einmal geladen und funktioniert '
        'dann ohne Internet.',
  );
  String chatWarming(String model) => _(
    'Getting $model ready…',
    'Το $model ετοιμάζεται…',
    'Preparando $model…',
    '$model wird vorbereitet…',
  );
  String get chatFailed => _(
    'Sorry, I couldn’t answer that. Try again?',
    'Συγγνώμη, δεν μπόρεσα να απαντήσω. Ξανά;',
    'Lo siento, no pude responder. ¿Otra vez?',
    'Entschuldige, das konnte ich nicht beantworten. Noch einmal?',
  );
  String get goToTop => _('Go to top', 'Στην αρχή', 'Ir arriba', 'Nach oben');
  // Downloadable languages (Settings > Language).
  String downloadLanguageTitle(String name) => _(
    'Download $name?',
    'Λήψη: $name;',
    '¿Descargar $name?',
    '$name herunterladen?',
  );
  String downloadLanguageBody(int mb) => _(
    'Its dictionary and its offline translator, about $mb MB (Wi-Fi '
        'recommended). After that it works without internet.',
    'Το λεξικό και ο μεταφραστής της, περίπου $mb MB (καλύτερα με Wi-Fi). '
        'Μετά λειτουργεί χωρίς ίντερνετ.',
    'Su diccionario y su traductor sin conexión, unos $mb MB (mejor con '
        'Wi-Fi). Después funciona sin internet.',
    'Wörterbuch und Offline-Übersetzer, etwa $mb MB (am besten mit WLAN). '
        'Danach funktioniert alles ohne Internet.',
  );
  String removeLanguagePack(int mb) => _(
    'Remove from the phone (frees $mb MB)',
    'Αφαίρεση από το κινητό (ελευθερώνει $mb MB)',
    'Quitar del teléfono (libera $mb MB)',
    'Vom Handy entfernen (gibt $mb MB frei)',
  );
  String get packCredits => _(
    'Downloadable languages: Spanish words from the Multilingual Central '
        'Repository (CC BY 3.0); German words and definitions from OdeNet '
        '(CC BY-SA 4.0); definitions and examples from Princeton WordNet, '
        'translated with OPUS-MT.',
    'Γλώσσες για λήψη: ισπανικές λέξεις από το Multilingual Central '
        'Repository (CC BY 3.0)· γερμανικές λέξεις και ορισμοί από το OdeNet '
        '(CC BY-SA 4.0)· ορισμοί και παραδείγματα από το Princeton WordNet, '
        'μεταφρασμένα με το OPUS-MT.',
    'Idiomas descargables: palabras en español del Multilingual Central '
        'Repository (CC BY 3.0); palabras y definiciones en alemán de OdeNet '
        '(CC BY-SA 4.0); definiciones y ejemplos de Princeton WordNet, '
        'traducidos con OPUS-MT.',
    'Ladbare Sprachen: spanische Wörter aus dem Multilingual Central '
        'Repository (CC BY 3.0); deutsche Wörter und Definitionen aus OdeNet '
        '(CC BY-SA 4.0); Definitionen und Beispiele aus Princeton WordNet, '
        'übersetzt mit OPUS-MT.',
  );
  String get aboutTheApp => _(
    'About the app',
    'Σχετικά με την εφαρμογή',
    'Acerca de la app',
    'Über die App',
  );
  String get translatorCredit => _(
    'The offline translator uses OPUS-MT by Helsinki-NLP (University of '
        'Helsinki), licensed CC BY 4.0, made smaller for phones.',
    'Ο μεταφραστής χωρίς ίντερνετ χρησιμοποιεί το OPUS-MT του Helsinki-NLP '
        '(Πανεπιστήμιο του Ελσίνκι), με άδεια CC BY 4.0, σε μικρότερη μορφή '
        'για κινητά.',
    'El traductor sin conexión usa OPUS-MT de Helsinki-NLP (Universidad '
        'de Helsinki), con licencia CC BY 4.0, reducido para teléfonos.',
    'Der Offline-Übersetzer nutzt OPUS-MT von Helsinki-NLP (Universität '
        'Helsinki), lizenziert unter CC BY 4.0, verkleinert für Handys.',
  );
  String get aboutTheAppSubtitle => _(
    'Learn more about the team behind the puzzles.',
    'Γνώρισε την ομάδα πίσω από τους γρίφους.',
    'Conoce al equipo detrás de los acertijos.',
    'Lerne das Team hinter den Rätseln kennen.',
  );
}
