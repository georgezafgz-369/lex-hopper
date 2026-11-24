// ─────────────────────────────────────────────────────────────────────────────
// APP TEXT — every word the app shows, in English and Greek
// ─────────────────────────────────────────────────────────────────────────────
//
// Use `AppText.of(context).newGame`. The language comes from the app's locale
// (Settings > Language, or the phone's language on first start), so widgets
// rebuild when it changes. Greek is written naturally in the app's voice —
// dry, warm, encouraging — not translated word for word.

import 'package:material_ui/material_ui.dart';

class AppText {
  final bool el; // Greek

  const AppText._(this.el);

  static const english = AppText._(false);
  static const greek = AppText._(true);

  /// Language codes the app's own text is available in.
  static const languageCodes = ['en', 'el'];

  static AppText of(BuildContext context) =>
      forCode(Localizations.maybeLocaleOf(context)?.languageCode);

  static AppText forCode(String? code) => code == 'el' ? greek : english;

  /// Language code for the dictionary labels (`DictionaryLabel.name`).
  String get code => el ? 'el' : 'en';

  String _(String en, String gr) => el ? gr : en;

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
  String get searchDictionaryHint =>
      _('Search dictionary...', 'Αναζήτηση στο λεξικό...');
  String get games => _('GAMES', 'ΠΑΙΧΝΙΔΙΑ');
  String get gamesTitle => _('Games', 'Παιχνίδια');
  String get search => _('Search', 'Αναζήτηση');
  String get menu => _('Menu', 'Μενού');
  String get home => _('Home', 'Αρχική');
  String get wordOfTheDay => _('WORD OF THE DAY', 'ΛΕΞΗ ΤΗΣ ΗΜΕΡΑΣ');
  String get seeMore => _('See more', 'Περισσότερα');

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
    final day = (el ? daysEl : daysEn)[d.weekday - 1];
    final month = (el ? monthsEl : monthsEn)[d.month - 1];
    return '$day ${d.day} $month';
  }

  /// "Crossword · Find the Words · Riddles", under the home Games card.
  String get gamesList => '$crossword · $findTheWords · $riddles';
  String get reference => _('REFERENCE', 'ΑΝΑΦΟΡΑ');
  String get other => _('OTHER', 'ΑΛΛΑ');
  String get crossword => _('Crossword', 'Σταυρόλεξο');
  String get crosswordSubtitle => _(
    'Set across and down in the printed newspaper tradition.',
    'Οριζόντια και κάθετα, όπως στο σταυρόλεξο της εφημερίδας.',
  );
  String get findTheWords => _('Find the Words', 'Βρες τις Λέξεις');
  String get findTheWordsSubtitle => _(
    'Scan for hidden words through five soft highlighter tints.',
    'Ψάξε κρυμμένες λέξεις με πέντε απαλά χρώματα μαρκαδόρου.',
  );
  String get riddles => _('Riddles', 'Αινίγματα');
  String get riddlesSubtitle => _(
    'Pithy brain teasers with dry wit and no pressure.',
    'Σύντομοι γρίφοι με λεπτό χιούμορ και χωρίς άγχος.',
  );
  String get dictionary => _('Dictionary', 'Λεξικό');
  String get dictionarySubtitle => _(
    'Look up words and their definitions.',
    'Βρες λέξεις και τις σημασίες τους.',
  );
  String get translator => _('Translator', 'Μεταφραστής');
  String get translateTextHint => _('Translate text', 'Μετάφραση κειμένου');
  String get paste => _('Paste', 'Επικόλληση');
  String get swapLanguages => _('Swap languages', 'Αλλαγή γλωσσών');
  String get speak => _('Speak', 'Εκφώνηση');
  String get copy => _('Copy', 'Αντιγραφή');
  String get copied => _('Copied', 'Αντιγράφηκε');
  String get preparingTranslator =>
      _('Getting the translator ready…', 'Ετοιμάζεται ο μεταφραστής…');
  String get translating => _('Translating…', 'Μετάφραση…');
  String get translateFailed => _(
    "Couldn't translate this text.",
    'Δεν έγινε η μετάφραση αυτού του κειμένου.',
  );
  String get noTranslatorYet => _(
    'To translate sentences, download the offline translator in Settings. '
        'Words and phrases from the dictionary work already.',
    'Για να μεταφράζεις προτάσεις, κατέβασε τον μεταφραστή χωρίς ίντερνετ '
        'από τις Ρυθμίσεις. Οι λέξεις και οι φράσεις του λεξικού λειτουργούν '
        'ήδη.',
  );
  String get translatorSubtitle =>
      _('Translate words and phrases.', 'Μετάφρασε λέξεις και φράσεις.');
  // Settings > Offline translator (OPUS-MT).
  String get offlineTranslator =>
      _('Offline translator', 'Μεταφραστής χωρίς ίντερνετ');
  String offlineTranslatorDownload(int mb) => _(
    'Translates sentences without internet · download $mb MB',
    'Μεταφράζει προτάσεις χωρίς ίντερνετ · λήψη $mb MB',
  );
  String get offlineTranslatorSoon => _(
    'Translates sentences without internet · coming soon',
    'Μεταφράζει προτάσεις χωρίς ίντερνετ · έρχεται σύντομα',
  );
  String offlineTranslatorDownloading(int percent) =>
      _('Downloading… $percent%', 'Λήψη… $percent%');
  String get offlineTranslatorReady => _(
    'Ready · works without internet · OPUS-MT by Helsinki-NLP (CC BY 4.0)',
    'Έτοιμος · λειτουργεί χωρίς ίντερνετ · OPUS-MT από το Helsinki-NLP (CC BY 4.0)',
  );
  String get offlineTranslatorFailed => _(
    'Download stopped. Tap to try again.',
    'Η λήψη σταμάτησε. Πάτησε για νέα προσπάθεια.',
  );
  String get offlineDownloadTitle =>
      _('Download the offline translator?', 'Λήψη του μεταφραστή;');
  String offlineDownloadBody(int mb) => _(
    'Translates sentences between English and Greek, without internet. '
        'A one-time download of about $mb MB (Wi-Fi recommended).',
    'Μεταφράζει προτάσεις από και προς τα αγγλικά, χωρίς ίντερνετ. '
        'Κατεβαίνει μία φορά, περίπου $mb MB (καλύτερα με Wi-Fi).',
  );
  String get offlineDeleteTitle =>
      _('Delete the offline translator?', 'Διαγραφή του μεταφραστή;');
  String offlineDeleteBody(int mb) => _(
    'Frees $mb MB. Sentences won\'t be translated until you download it '
        'again.',
    'Ελευθερώνει $mb MB. Οι προτάσεις δεν θα μεταφράζονται μέχρι να τον '
        'ξανακατεβάσεις.',
  );
  String get delete => _('Delete', 'Διαγραφή');

  // Settings > AI translator (EuroLLM).
  String get aiTranslator => _('AI translator', 'Μεταφραστής AI');
  String get aiTranslatorChecking => _('Checking…', 'Έλεγχος…');
  String get aiTranslatorOff => _('Off', 'Ανενεργός');
  String get aiTranslatorOn => _(
    'On · EuroLLM, works without internet',
    'Ενεργός · EuroLLM, λειτουργεί χωρίς ίντερνετ',
  );
  String aiTranslatorDownloading(int? percent) => _(
    'Downloading EuroLLM… ${percent == null ? '' : '$percent%'}',
    'Λήψη EuroLLM… ${percent == null ? '' : '$percent%'}',
  );
  String get aiTranslatorNeedsMemory => _(
    'Needs a phone with at least 4 GB of memory.',
    'Χρειάζεται κινητό με τουλάχιστον 4 GB μνήμης.',
  );
  String get aiTranslatorFailed => _(
    'Download stopped. Tap to try again.',
    'Η λήψη σταμάτησε. Πάτησε για νέα προσπάθεια.',
  );
  String get aiDownloadTitle =>
      _('Download the AI translator?', 'Λήψη του μεταφραστή AI;');
  String aiDownloadBody(int mb) => _(
    'EuroLLM reads the whole sentence, so it picks the right sense of a '
        'word. It is a one-time download of about $mb MB (Wi-Fi '
        'recommended); after that it works without internet.',
    'Το EuroLLM διαβάζει όλη την πρόταση, οπότε διαλέγει τη σωστή σημασία '
        'κάθε λέξης. Κατεβαίνει μία φορά, περίπου $mb MB (καλύτερα με '
        'Wi-Fi)· μετά λειτουργεί χωρίς ίντερνετ.',
  );
  String get download => _('Download', 'Λήψη');
  String get cancel => _('Cancel', 'Άκυρο');
  String get aiTurnOffTitle =>
      _('Turn off the AI translator?', 'Απενεργοποίηση του μεταφραστή AI;');
  String aiTurnOffBody(int mb) => _(
    'Keep the model ($mb MB) to turn it back on later without downloading '
        'again, or delete it to free the space.',
    'Κράτησε το μοντέλο ($mb MB) για να το ξαναενεργοποιήσεις χωρίς νέα '
        'λήψη, ή διάγραψέ το για να ελευθερώσεις χώρο.',
  );
  String get keepModel => _('Keep it', 'Κράτησέ το');
  String get deleteModel => _('Delete it', 'Διάγραψέ το');

  // First launch: downloading the dictionary.
  String get gettingDictionary =>
      _('Getting the dictionary ready', 'Ετοιμάζεται το λεξικό');
  String dictionaryDownloadNote(int mb) => _(
    'A one-time download of about $mb MB. After that, Lex Hopper works '
        'without internet.',
    'Κατεβαίνει μία φορά, περίπου $mb MB. Μετά, το Lex Hopper λειτουργεί '
        'χωρίς ίντερνετ.',
  );
  String dictionaryDownloading(int percent) =>
      _('Downloading… $percent%', 'Λήψη… $percent%');
  String get dictionaryDownloadFailed => _(
    "Couldn't download the dictionary. Check the internet connection and "
        'try again.',
    'Δεν έγινε η λήψη του λεξικού. Έλεγξε τη σύνδεση στο ίντερνετ και '
        'δοκίμασε ξανά.',
  );

  String get settings => _('Settings', 'Ρυθμίσεις');
  String get settingsSubtitle =>
      _('Customize your experience.', 'Προσάρμοσε την εμπειρία σου.');
  String get comingSoon => _('Coming soon', 'Έρχεται σύντομα');

  // ── Crossword menu ──
  String get dailyCrossword => _('DAILY CROSSWORD', 'ΣΤΑΥΡΟΛΕΞΟ ΤΗΣ ΗΜΕΡΑΣ');
  String get newGame => _('New Game', 'Νέο Παιχνίδι');
  String get newGameSubtitle =>
      _('Start a fresh puzzle.', 'Ξεκίνα ένα καινούργιο σταυρόλεξο.');
  String get continueGame => _('Continue', 'Συνέχεια');
  String get noSavedGame =>
      _('No saved game.', 'Δεν υπάρχει αποθηκευμένο παιχνίδι.');
  String get chooseSubject => _('Choose a subject', 'Διάλεξε θέμα');
  String get allThemes => _('All subjects', 'Όλα τα θέματα');
  String get allSubjectsSubtitle =>
      _('Words from every subject.', 'Λέξεις από όλα τα θέματα.');
  String wordCount(int n) {
    final s = n >= 1000
        ? '${n ~/ 1000}${el ? '.' : ','}${(n % 1000).toString().padLeft(3, '0')}'
        : '$n';
    return _('$s words', '$s λέξεις');
  }

  String continueWithSubject(int level, String subject) => _(
    'Pick up where you left off — Level $level, $subject.',
    'Συνέχισε από εκεί που σταμάτησες — Επίπεδο $level, $subject.',
  );
  String continueSubtitle(int level) => _(
    'Pick up where you left off — Level $level.',
    'Συνέχισε από εκεί που σταμάτησες — Επίπεδο $level.',
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
    final names = el ? _numbersEl : _numbersEn;
    final number = n >= 0 && n < names.length ? names[n] : '$n';
    return _('Level $number', 'Επίπεδο $number');
  }

  String settingLevel(int n) =>
      _('Setting ${level(n)}…', 'Ετοιμάζεται: ${level(n)}…');
  String get couldNotSetPuzzle => _(
    "Couldn't set this puzzle. Try again?",
    'Δεν ήταν δυνατό να στηθεί ο γρίφος. Δοκιμάζεις ξανά;',
  );
  String get tryAgain => _('Try again', 'Ξανά');
  String get searchOnDictionary =>
      _('Search on dictionary', 'Αναζήτηση στο λεξικό');
  String get acrossClues => _('ACROSS CLUES', 'ΟΡΙΖΟΝΤΙΑ');
  String get downClues => _('DOWN CLUES', 'ΚΑΘΕΤΑ');
  String get clear => _('Clear', 'Σβήσιμο');
  String get hint => _('Hint', 'Βοήθεια');
  String get check => _('Check', 'Έλεγχος');
  String get nextLevel => _('Next level', 'Επόμενο επίπεδο');
  String get nextLevelTest =>
      _('Next level (test)', 'Επόμενο επίπεδο (δοκιμή)');
  // ── Find the Words ──
  String get wordSearchKicker => _('HIDDEN WORDS', 'ΚΡΥΜΜΕΝΕΣ ΛΕΞΕΙΣ');
  String get newWordSearchSubtitle =>
      _('Start a fresh grid of hidden words.', 'Ξεκίνα ένα καινούργιο πλέγμα.');
  String get wordsToFind => _('WORDS TO FIND', 'ΛΕΞΕΙΣ ΓΙΑ ΝΑ ΒΡΕΙΣ');
  String foundCount(int found, int total) =>
      _('$found of $total found', '$found από $total');
  String get allWordsFound => _('All words found!', 'Βρήκες όλες τις λέξεις!');
  String get dragToFind => _(
    'Drag across a word, from its first letter to its last.',
    'Σύρε το δάχτυλο πάνω σε μια λέξη, από το πρώτο ως το τελευταίο γράμμα.',
  );

  // ── Dictionary ──
  String get partOfSpeech => _('PART OF SPEECH', 'ΜΕΡΟΣ ΤΟΥ ΛΟΓΟΥ');
  String get structure => _('STRUCTURE', 'ΔΟΜΗ');
  String get subject => _('SUBJECT', 'ΘΕΜΑΤΙΚΟ ΠΕΔΙΟ');
  String get all => _('All', 'Όλα');
  String get allSubjects => _('All subjects', 'Όλα τα πεδία');
  String get general => _('General', 'Γενικά');
  String get generalNoSubject =>
      _('General (no subject)', 'Γενικά (χωρίς πεδίο)');
  String get loadingDictionary =>
      _('Loading dictionary…', 'Φορτώνει το λεξικό…');
  String get searchToBegin =>
      _('Search for a word to begin.', 'Ψάξε μια λέξη για να ξεκινήσεις.');
  String get noMatches => _('No matches.', 'Δεν βρέθηκε τίποτα.');
  String alsoCalledQuoted(String name) =>
      _('Also called “$name”', 'Λέγεται και «$name»');
  String meanings(int n) => el
      ? '$n ${n == 1 ? 'σημασία' : 'σημασίες'}'
      : '$n ${n == 1 ? 'meaning' : 'meanings'}';

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

  /// Part of speech name, e.g. "adj" -> "Adjective" / "Επίθετο".
  String partOfSpeechName(String pos) =>
      (el ? _posEl : _posEn)[pos] ?? pos.toUpperCase();

  // ── Word page ──
  String get close => _('Close', 'Κλείσιμο');
  String get noEntryYet => _(
    'No entry for this word yet.',
    'Δεν υπάρχει ακόμα λήμμα για αυτή τη λέξη.',
  );
  String syllables(int n) => _('$n syllables', '$n συλλαβές');
  String plural(String forms) => _('plural $forms', 'πληθυντικός: $forms');
  String get moreExamples => _('MORE EXAMPLES', 'ΠΕΡΙΣΣΟΤΕΡΑ ΠΑΡΑΔΕΙΓΜΑΤΑ');
  String get phrases => _('PHRASES', 'ΦΡΑΣΕΙΣ');
  String get aboutTheWord => _('ABOUT THE WORD', 'ΓΙΑ ΤΗ ΛΕΞΗ');
  String get structureLabel => _('Structure', 'Δομή');
  String structureWord(String name) => _('$name word', '$name λέξη');
  String get originLabel => _('Origin', 'Προέλευση');
  String borrowedFrom(String languages) =>
      _('Borrowed from $languages', 'Δάνειο από: $languages');
  String fromLanguage(String language) => _('From $language', 'Από: $language');
  String get relatedForms => _('Related forms', 'Συγγενικοί τύποι');
  String get relatingToIt => _('Relating to it', 'Σχετικά επίθετα');
  String get alsoCalled => _('Also called', 'Λέγεται και');
  String get meaningLabel => _('Meaning', 'Σημασία');
  String get examplesLabel => _('Examples', 'Παραδείγματα');
  String get synonyms => _('Synonyms', 'Συνώνυμα');
  String get opposites => _('Opposites', 'Αντίθετα');
  String moreCount(int n) => _('+$n more', '+$n ακόμα');

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
  String get preferences => _('PREFERENCES', 'ΠΡΟΤΙΜΗΣΕΙΣ');
  String get language => _('Language', 'Γλώσσα');
  String get mainLanguage => _('Main', 'Κύρια');
  String get secondaryLanguage => _('Secondary', 'Δευτερεύουσα');
  String get setAsMain => _('Set as main language', 'Ορισμός ως κύρια γλώσσα');
  String get setAsSecondary =>
      _('Set as secondary language', 'Ορισμός ως δευτερεύουσα γλώσσα');
  String get removeSecondary =>
      _('Remove as secondary language', 'Αφαίρεση από δευτερεύουσα γλώσσα');

  /// A language's name written in this text's language, e.g. 'en' →
  /// "English" / "Αγγλικά".
  String languageName(String code) => switch (code) {
    'en' => _('English', 'Αγγλικά'),
    'el' => _('Greek', 'Ελληνικά'),
    'es' => _('Spanish', 'Ισπανικά'),
    'fr' => _('French', 'Γαλλικά'),
    'de' => _('German', 'Γερμανικά'),
    'it' => _('Italian', 'Ιταλικά'),
    _ => code,
  };
  String withSecondary(String main, String second) =>
      _('$main · secondary: $second', '$main · δευτερεύουσα: $second');
  String get darkMode => _('Dark mode', 'Σκούρο θέμα');
  String get on => _('On', 'Ενεργό');
  String get off => _('Off', 'Ανενεργό');
  String get fontSize => _('Font size', 'Μέγεθος γραμμάτων');
  String get small => _('Small', 'Μικρά');
  String get medium => _('Medium', 'Μεσαία');
  String get large => _('Large', 'Μεγάλα');
  String get feedback => _('Feedback', 'Σχόλια');
  String get feedbackSubtitle => _(
    'Tell us what you think or report a problem.',
    'Πες μας τη γνώμη σου ή ανέφερε ένα πρόβλημα.',
  );
  String get feedbackSubject =>
      _('Lex Hopper feedback', 'Σχόλια για το Lex Hopper');
  String noEmailApp(String email) => _(
    'No email app found. Write to us at $email',
    'Δεν βρέθηκε εφαρμογή email. Γράψε μας στο $email',
  );
  String get aboutTheApp => _('About the app', 'Σχετικά με την εφαρμογή');
  String get aboutTheAppSubtitle => _(
    'Learn more about the team behind the puzzles.',
    'Γνώρισε την ομάδα πίσω από τους γρίφους.',
  );
}
