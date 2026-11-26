// ─────────────────────────────────────────────────────────────────────────────
// APP TEXT — every word the app shows: English, Greek, and the languages
// that are downloaded on request (Spanish, German, Italian, French, Russian)
// ─────────────────────────────────────────────────────────────────────────────
//
// Use `AppText.of(context).newGame`. The language comes from the app's locale
// (Settings > Language, or the phone's language on first start), so widgets
// rebuild when it changes. Greek is written naturally in the app's voice —
// dry, warm, encouraging — not translated word for word.

import 'package:material_ui/material_ui.dart';

class AppText {
  /// The language: "en", "el", "es", "de", "it", "fr" or "ru".
  final String code;

  const AppText._(this.code);

  static const english = AppText._('en');
  static const greek = AppText._('el');
  static const spanish = AppText._('es');
  static const german = AppText._('de');
  static const italian = AppText._('it');
  static const french = AppText._('fr');
  static const russian = AppText._('ru');

  /// Language codes the app's own text is available in.
  static const languageCodes = ['en', 'el', 'es', 'de', 'it', 'fr', 'ru'];

  static AppText of(BuildContext context) =>
      forCode(Localizations.maybeLocaleOf(context)?.languageCode);

  static AppText forCode(String? code) => switch (code) {
    'el' => greek,
    'es' => spanish,
    'de' => german,
    'it' => italian,
    'fr' => french,
    'ru' => russian,
    _ => english,
  };

  /// Greek (several texts have Greek-only rules: accents, number words).
  bool get el => code == 'el';

  /// The text in this language: English and Greek always, the
  /// downloadable languages where written; anything not yet translated
  /// shows in English.
  String _(
    String en,
    String el, [
    String? es,
    String? de,
    String? it,
    String? fr,
    String? ru,
  ]) => switch (code) {
    'el' => el,
    'es' => es ?? en,
    'de' => de ?? en,
    'it' => it ?? en,
    'fr' => fr ?? en,
    'ru' => ru ?? en,
    _ => en,
  };

  /// Russian plural: 1 слово, 2 слова, 5 слов (21 слово, 11 слов).
  static String _ru(int n, String one, String few, String many) {
    final tens = n % 100, ones = n % 10;
    if (tens >= 11 && tens <= 14) return many;
    if (ones == 1) return one;
    if (ones >= 2 && ones <= 4) return few;
    return many;
  }

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
    'Cerca nel dizionario...',
    'Rechercher dans le dictionnaire...',
    'Поиск в словаре...',
  );
  String get games =>
      _('GAMES', 'ΠΑΙΧΝΙΔΙΑ', 'JUEGOS', 'SPIELE', 'GIOCHI', 'JEUX', 'ИГРЫ');
  String get gamesTitle =>
      _('Games', 'Παιχνίδια', 'Juegos', 'Spiele', 'Giochi', 'Jeux', 'Игры');
  String get search => _(
    'Search',
    'Αναζήτηση',
    'Buscar',
    'Suchen',
    'Cerca',
    'Rechercher',
    'Поиск',
  );
  String get menu => _('Menu', 'Μενού', 'Menú', 'Menü', 'Menu', 'Menu', 'Меню');
  String get home =>
      _('Home', 'Αρχική', 'Inicio', 'Start', 'Home', 'Accueil', 'Главная');
  String get wordOfTheDay => _(
    'WORD OF THE DAY',
    'ΛΕΞΗ ΤΗΣ ΗΜΕΡΑΣ',
    'PALABRA DEL DÍA',
    'WORT DES TAGES',
    'PAROLA DEL GIORNO',
    'MOT DU JOUR',
    'СЛОВО ДНЯ',
  );
  String get seeMore => _(
    'See more',
    'Περισσότερα',
    'Ver más',
    'Mehr',
    'Altro',
    'Voir plus',
    'Ещё',
  );

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
    const daysIt = ['lun', 'mar', 'mer', 'gio', 'ven', 'sab', 'dom'];
    const daysFr = ['lun.', 'mar.', 'mer.', 'jeu.', 'ven.', 'sam.', 'dim.'];
    const daysRu = ['пн', 'вт', 'ср', 'чт', 'пт', 'сб', 'вс'];
    const monthsIt = [
      'gen', 'feb', 'mar', 'apr', 'mag', 'giu', //
      'lug', 'ago', 'set', 'ott', 'nov', 'dic',
    ];
    const monthsFr = [
      'janv.', 'févr.', 'mars', 'avr.', 'mai', 'juin', //
      'juil.', 'août', 'sept.', 'oct.', 'nov.', 'déc.',
    ];
    const monthsRu = [
      'янв.', 'февр.', 'мар.', 'апр.', 'мая', 'июн.', //
      'июл.', 'авг.', 'сент.', 'окт.', 'нояб.', 'дек.',
    ];
    final (days, months) = switch (code) {
      'el' => (daysEl, monthsEl),
      'es' => (daysEs, monthsEs),
      'de' => (daysDe, monthsDe),
      'it' => (daysIt, monthsIt),
      'fr' => (daysFr, monthsFr),
      'ru' => (daysRu, monthsRu),
      _ => (daysEn, monthsEn),
    };
    final day = days[d.weekday - 1];
    final month = months[d.month - 1];
    // German writes the day with a dot: "Di 24. Nov."
    return code == 'de' ? '$day ${d.day}. $month' : '$day ${d.day} $month';
  }

  /// "Crossword · Find the Words · Riddles", under the home Games card.
  String get gamesList => '$crossword · $findTheWords · $riddles';
  String get reference => _(
    'REFERENCE',
    'ΑΝΑΦΟΡΑ',
    'CONSULTA',
    'NACHSCHLAGEN',
    'CONSULTAZIONE',
    'RÉFÉRENCE',
    'СПРАВКА',
  );
  String get other =>
      _('OTHER', 'ΑΛΛΑ', 'OTROS', 'WEITERES', 'ALTRO', 'AUTRES', 'ДРУГОЕ');
  String get crossword => _(
    'Crossword',
    'Σταυρόλεξο',
    'Crucigrama',
    'Kreuzworträtsel',
    'Cruciverba',
    'Mots croisés',
    'Кроссворд',
  );
  String get crosswordSubtitle => _(
    'Set across and down in the printed newspaper tradition.',
    'Οριζόντια και κάθετα, όπως στο σταυρόλεξο της εφημερίδας.',
    'Horizontales y verticales, como en el periódico.',
    'Waagerecht und senkrecht, wie in der Zeitung.',
    'Orizzontali e verticali, come sul giornale.',
    'Horizontalement et verticalement, comme dans le journal.',
    'По горизонтали и по вертикали, как в газете.',
  );
  String get findTheWords => _(
    'Find the Words',
    'Βρες τις Λέξεις',
    'Encuentra las palabras',
    'Finde die Wörter',
    'Trova le parole',
    'Trouve les mots',
    'Найди слова',
  );
  String get findTheWordsSubtitle => _(
    'Scan for hidden words through five soft highlighter tints.',
    'Ψάξε κρυμμένες λέξεις με πέντε απαλά χρώματα μαρκαδόρου.',
    'Busca palabras escondidas con cinco suaves colores de marcador.',
    'Suche versteckte Wörter mit fünf sanften Textmarkerfarben.',
    'Cerca parole nascoste con cinque tenui colori da evidenziatore.',
    'Cherche des mots cachés avec cinq douces couleurs de surligneur.',
    'Ищи спрятанные слова пятью мягкими цветами маркера.',
  );
  String get riddles => _(
    'Riddles',
    'Αινίγματα',
    'Acertijos',
    'Rätsel',
    'Indovinelli',
    'Énigmes',
    'Загадки',
  );
  String get riddlesSubtitle => _(
    'Pithy brain teasers with dry wit and no pressure.',
    'Σύντομοι γρίφοι με λεπτό χιούμορ και χωρίς άγχος.',
    'Adivinanzas breves, con humor seco y sin prisas.',
    'Kurze Denkaufgaben mit trockenem Humor und ohne Druck.',
    'Brevi rompicapi, con umorismo asciutto e senza fretta.',
    'De courtes énigmes, avec un humour pince-sans-rire et sans pression.',
    'Короткие головоломки с тонким юмором и без спешки.',
  );
  String get dictionary => _(
    'Dictionary',
    'Λεξικό',
    'Diccionario',
    'Wörterbuch',
    'Dizionario',
    'Dictionnaire',
    'Словарь',
  );
  String get dictionarySubtitle => _(
    'Look up words and their definitions.',
    'Βρες λέξεις και τις σημασίες τους.',
    'Busca palabras y sus significados.',
    'Schlag Wörter und ihre Bedeutungen nach.',
    'Cerca parole e i loro significati.',
    'Cherche des mots et leurs sens.',
    'Ищи слова и их значения.',
  );
  String get translator => _(
    'Translator',
    'Μεταφραστής',
    'Traductor',
    'Übersetzer',
    'Traduttore',
    'Traducteur',
    'Переводчик',
  );
  String get translateTextHint => _(
    'Translate text',
    'Μετάφραση κειμένου',
    'Traducir texto',
    'Text übersetzen',
    'Traduci un testo',
    'Traduire un texte',
    'Перевести текст',
  );
  String get paste => _(
    'Paste',
    'Επικόλληση',
    'Pegar',
    'Einfügen',
    'Incolla',
    'Coller',
    'Вставить',
  );
  String get swapLanguages => _(
    'Swap languages',
    'Αλλαγή γλωσσών',
    'Cambiar idiomas',
    'Sprachen tauschen',
    'Scambia le lingue',
    'Inverser les langues',
    'Поменять языки',
  );
  String get speak => _(
    'Speak',
    'Εκφώνηση',
    'Escuchar',
    'Vorlesen',
    'Ascolta',
    'Écouter',
    'Озвучить',
  );
  String get copy => _(
    'Copy',
    'Αντιγραφή',
    'Copiar',
    'Kopieren',
    'Copia',
    'Copier',
    'Копировать',
  );
  String get copied => _(
    'Copied',
    'Αντιγράφηκε',
    'Copiado',
    'Kopiert',
    'Copiato',
    'Copié',
    'Скопировано',
  );
  String get preparingTranslator => _(
    'Getting the translator ready…',
    'Ετοιμάζεται ο μεταφραστής…',
    'Preparando el traductor…',
    'Der Übersetzer wird vorbereitet…',
    'Preparazione del traduttore…',
    'Préparation du traducteur…',
    'Переводчик готовится…',
  );
  String get translating => _(
    'Translating…',
    'Μετάφραση…',
    'Traduciendo…',
    'Übersetze…',
    'Traduzione…',
    'Traduction…',
    'Перевод…',
  );
  String get translateFailed => _(
    "Couldn't translate this text.",
    'Δεν έγινε η μετάφραση αυτού του κειμένου.',
    'No se pudo traducir este texto.',
    'Dieser Text konnte nicht übersetzt werden.',
    'Impossibile tradurre questo testo.',
    'Impossible de traduire ce texte.',
    'Не удалось перевести этот текст.',
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
    'Il traduttore non è ancora scaricato. Connettiti a internet e si scaricherà da solo. Le parole e le frasi del dizionario funzionano già.',
    'Le traducteur n’est pas encore téléchargé. Connecte-toi à internet et il se téléchargera tout seul. Les mots et expressions du dictionnaire fonctionnent déjà.',
    'Переводчик ещё не загружен. Подключись к интернету, и он загрузится сам. Слова и фразы из словаря уже работают.',
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
    'Preparazione del traduttore… $percent%. Le parole e le frasi del dizionario funzionano già.',
    'Préparation du traducteur… $percent %. Les mots et expressions du dictionnaire fonctionnent déjà.',
    'Переводчик готовится… $percent%. Слова и фразы из словаря уже работают.',
  );
  String get translatorSubtitle => _(
    'Translate words and phrases.',
    'Μετάφρασε λέξεις και φράσεις.',
    'Traduce palabras y frases.',
    'Übersetze Wörter und Sätze.',
    'Traduci parole e frasi.',
    'Traduis des mots et des phrases.',
    'Переводи слова и фразы.',
  );
  // Settings > Offline translator (OPUS-MT).
  String get offlineTranslator => _(
    'Offline translator',
    'Μεταφραστής χωρίς ίντερνετ',
    'Traductor sin conexión',
    'Offline-Übersetzer',
    'Traduttore offline',
    'Traducteur hors ligne',
    'Офлайн-переводчик',
  );
  String offlineTranslatorDownload(int mb) => _(
    'Translates sentences without internet · download $mb MB',
    'Μεταφράζει προτάσεις χωρίς ίντερνετ · λήψη $mb MB',
    'Traduce frases sin internet · descarga de $mb MB',
    'Übersetzt Sätze ohne Internet · Download $mb MB',
    'Traduce frasi senza internet · download di $mb MB',
    'Traduit des phrases sans internet · téléchargement de $mb Mo',
    'Переводит предложения без интернета · загрузка $mb МБ',
  );
  String get offlineTranslatorSoon => _(
    'Translates sentences without internet · coming soon',
    'Μεταφράζει προτάσεις χωρίς ίντερνετ · έρχεται σύντομα',
    'Traduce frases sin internet · próximamente',
    'Übersetzt Sätze ohne Internet · bald verfügbar',
    'Traduce frasi senza internet · in arrivo',
    'Traduit des phrases sans internet · bientôt disponible',
    'Переводит предложения без интернета · скоро',
  );
  String offlineTranslatorDownloading(int percent) => _(
    'Downloading… $percent%',
    'Λήψη… $percent%',
    'Descargando… $percent%',
    'Lädt… $percent%',
    'Download… $percent%',
    'Téléchargement… $percent %',
    'Загрузка… $percent%',
  );
  String get offlineTranslatorReady => _(
    'Ready · works without internet · OPUS-MT by Helsinki-NLP (CC BY 4.0)',
    'Έτοιμος · λειτουργεί χωρίς ίντερνετ · OPUS-MT από το Helsinki-NLP (CC BY 4.0)',
    'Listo · funciona sin internet · OPUS-MT de Helsinki-NLP (CC BY 4.0)',
    'Bereit · funktioniert ohne Internet · OPUS-MT von Helsinki-NLP (CC BY 4.0)',
    'Pronto · funziona senza internet · OPUS-MT di Helsinki-NLP (CC BY 4.0)',
    'Prêt · fonctionne sans internet · OPUS-MT de Helsinki-NLP (CC BY 4.0)',
    'Готов · работает без интернета · OPUS-MT от Helsinki-NLP (CC BY 4.0)',
  );
  String get offlineTranslatorFailed => _(
    'Download stopped. Tap to try again.',
    'Η λήψη σταμάτησε. Πάτησε για νέα προσπάθεια.',
    'La descarga se detuvo. Toca para intentarlo de nuevo.',
    'Download angehalten. Tippe, um es erneut zu versuchen.',
    'Download interrotto. Tocca per riprovare.',
    'Téléchargement interrompu. Touche pour réessayer.',
    'Загрузка прервана. Нажми, чтобы повторить.',
  );
  String get offlineDownloadTitle => _(
    'Download the offline translator?',
    'Λήψη του μεταφραστή;',
    '¿Descargar el traductor sin conexión?',
    'Offline-Übersetzer herunterladen?',
    'Scaricare il traduttore offline?',
    'Télécharger le traducteur hors ligne ?',
    'Скачать офлайн-переводчик?',
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
    'Traduce frasi tra inglese e greco, senza internet. Si scarica una volta sola, circa $mb MB (meglio con il Wi-Fi).',
    'Traduit des phrases entre l’anglais et le grec, sans internet. Un seul téléchargement d’environ $mb Mo (de préférence en Wi-Fi).',
    'Переводит предложения между английским и греческим без интернета. Загружается один раз, около $mb МБ (лучше по Wi-Fi).',
  );
  String get offlineDeleteTitle => _(
    'Delete the offline translator?',
    'Διαγραφή του μεταφραστή;',
    '¿Borrar el traductor sin conexión?',
    'Offline-Übersetzer löschen?',
    'Eliminare il traduttore offline?',
    'Supprimer le traducteur hors ligne ?',
    'Удалить офлайн-переводчик?',
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
    'Libera $mb MB. Le frasi non verranno tradotte finché non lo scarichi di nuovo.',
    'Libère $mb Mo. Les phrases ne seront plus traduites tant que tu ne l’auras pas retéléchargé.',
    'Освободит $mb МБ. Предложения не будут переводиться, пока ты не скачаешь его снова.',
  );
  String get delete => _(
    'Delete',
    'Διαγραφή',
    'Borrar',
    'Löschen',
    'Elimina',
    'Supprimer',
    'Удалить',
  );

  // Settings > AI model (EuroLLM or Gemma 4): translates and chats.
  String get aiTranslator => _(
    'AI model',
    'Μοντέλο AI',
    'Modelo de IA',
    'KI-Modell',
    'Modello IA',
    'Modèle d’IA',
    'Модель ИИ',
  );
  String get aiTranslatorChecking => _(
    'Checking…',
    'Έλεγχος…',
    'Comprobando…',
    'Prüfe…',
    'Verifica…',
    'Vérification…',
    'Проверка…',
  );
  String get aiTranslatorOff => _(
    'Off',
    'Ανενεργός',
    'Desactivado',
    'Aus',
    'Disattivato',
    'Désactivé',
    'Выкл.',
  );
  String aiTranslatorOn(String model) => _(
    'On · $model, works without internet',
    'Ενεργό · $model, λειτουργεί χωρίς ίντερνετ',
    'Activado · $model, funciona sin internet',
    'An · $model, funktioniert ohne Internet',
    'Attivo · $model, funziona senza internet',
    'Activé · $model, fonctionne sans internet',
    'Вкл. · $model, работает без интернета',
  );
  String aiTranslatorDownloading(String model, int? percent) => _(
    'Downloading $model… ${percent == null ? '' : '$percent%'}',
    'Λήψη $model… ${percent == null ? '' : '$percent%'}',
    'Descargando $model… ${percent == null ? '' : '$percent%'}',
    'Lade $model… ${percent == null ? '' : '$percent%'}',
    'Download di $model… ${percent == null ? '' : '$percent%'}',
    'Téléchargement de $model… ${percent == null ? '' : '$percent %'}',
    'Загрузка $model… ${percent == null ? '' : '$percent%'}',
  );
  String aiTranslatorNeedsMemory(int gb) => _(
    'Needs a phone with at least $gb GB of memory.',
    'Χρειάζεται κινητό με τουλάχιστον $gb GB μνήμης.',
    'Necesita un teléfono con al menos $gb GB de memoria.',
    'Braucht ein Handy mit mindestens $gb GB Speicher.',
    'Serve un telefono con almeno $gb GB di memoria.',
    'Nécessite un téléphone avec au moins $gb Go de mémoire.',
    'Нужен телефон с памятью не меньше $gb ГБ.',
  );
  String aiModelSize(int mb) => _(
    '${(mb / 1000).toStringAsFixed(1)} GB',
    '${(mb / 1000).toStringAsFixed(1)} GB',
    '${(mb / 1000).toStringAsFixed(1)} GB',
    '${(mb / 1000).toStringAsFixed(1)} GB',
    '${(mb / 1000).toStringAsFixed(1)} GB',
    '${(mb / 1000).toStringAsFixed(1).replaceAll('.', ',')} Go',
    '${(mb / 1000).toStringAsFixed(1).replaceAll('.', ',')} ГБ',
  );
  String get aiTranslatorFailed => _(
    'Download stopped. Tap to try again.',
    'Η λήψη σταμάτησε. Πάτησε για νέα προσπάθεια.',
    'La descarga se detuvo. Toca para intentarlo de nuevo.',
    'Download angehalten. Tippe, um es erneut zu versuchen.',
    'Download interrotto. Tocca per riprovare.',
    'Téléchargement interrompu. Touche pour réessayer.',
    'Загрузка прервана. Нажми, чтобы повторить.',
  );
  String aiDownloadTitle(String model) => _(
    'Download $model?',
    'Λήψη: $model;',
    '¿Descargar $model?',
    '$model herunterladen?',
    'Scaricare $model?',
    'Télécharger $model ?',
    'Скачать $model?',
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
    '$model legge tutta la frase, quindi sceglie il senso giusto di ogni parola, e risponde nella chat con l’IA. Si scarica una volta sola, circa $mb MB (meglio con il Wi-Fi); poi funziona senza internet.',
    '$model lit toute la phrase, il choisit donc le bon sens de chaque mot, et il répond dans la discussion avec l’IA. Un seul téléchargement d’environ $mb Mo (de préférence en Wi-Fi) ; ensuite, il fonctionne sans internet.',
    '$model читает всё предложение целиком, поэтому выбирает правильное значение каждого слова, и отвечает в чате с ИИ. Загружается один раз, около $mb МБ (лучше по Wi-Fi); потом работает без интернета.',
  );
  String get download => _(
    'Download',
    'Λήψη',
    'Descargar',
    'Herunterladen',
    'Scarica',
    'Télécharger',
    'Скачать',
  );
  String get cancel => _(
    'Cancel',
    'Άκυρο',
    'Cancelar',
    'Abbrechen',
    'Annulla',
    'Annuler',
    'Отмена',
  );
  String get aiTurnOffTitle => _(
    'Turn off the AI translator?',
    'Απενεργοποίηση του μεταφραστή AI;',
    '¿Desactivar el traductor con IA?',
    'KI-Übersetzer ausschalten?',
    'Disattivare il traduttore IA?',
    'Désactiver le traducteur IA ?',
    'Выключить ИИ-переводчик?',
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
    'Tieni il modello ($mb MB) per riattivarlo in seguito senza scaricarlo di nuovo, oppure eliminalo per liberare spazio.',
    'Garde le modèle ($mb Mo) pour le réactiver plus tard sans le retélécharger, ou supprime-le pour libérer de la place.',
    'Оставь модель ($mb МБ), чтобы потом включить её без новой загрузки, или удали её, чтобы освободить место.',
  );
  String get keepModel => _(
    'Keep it',
    'Κράτησέ το',
    'Guardarlo',
    'Behalten',
    'Tienilo',
    'Le garder',
    'Оставить',
  );
  String get deleteModel => _(
    'Delete it',
    'Διάγραψέ το',
    'Borrarlo',
    'Löschen',
    'Eliminalo',
    'Le supprimer',
    'Удалить',
  );

  // First launch: downloading the dictionary.
  String get gettingDictionary => _(
    'Getting the dictionary ready',
    'Ετοιμάζεται το λεξικό',
    'Preparando el diccionario',
    'Das Wörterbuch wird vorbereitet',
    'Preparazione del dizionario',
    'Préparation du dictionnaire',
    'Словарь готовится',
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
    'Si scarica una volta sola, circa $mb MB. Poi Lex Hopper funziona senza internet.',
    'Un seul téléchargement d’environ $mb Mo. Ensuite, Lex Hopper fonctionne sans internet.',
    'Загружается один раз, около $mb МБ. Потом Lex Hopper работает без интернета.',
  );
  String dictionaryDownloading(int percent) => _(
    'Downloading… $percent%',
    'Λήψη… $percent%',
    'Descargando… $percent%',
    'Lädt… $percent%',
    'Download… $percent%',
    'Téléchargement… $percent %',
    'Загрузка… $percent%',
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
    'Impossibile scaricare il dizionario. Controlla la connessione a internet e riprova.',
    'Impossible de télécharger le dictionnaire. Vérifie la connexion internet et réessaie.',
    'Не удалось загрузить словарь. Проверь подключение к интернету и попробуй ещё раз.',
  );

  String get settings => _(
    'Settings',
    'Ρυθμίσεις',
    'Ajustes',
    'Einstellungen',
    'Impostazioni',
    'Réglages',
    'Настройки',
  );
  String get settingsSubtitle => _(
    'Customize your experience.',
    'Προσάρμοσε την εμπειρία σου.',
    'Personaliza tu experiencia.',
    'Pass die App an dich an.',
    'Personalizza la tua esperienza.',
    'Personnalise ton expérience.',
    'Настрой приложение под себя.',
  );

  /// The Home card for lessons (coming soon).
  String get learnTitle => _(
    'Language Lessons',
    'Μαθήματα γλώσσας',
    'Lecciones de idiomas',
    'Sprachkurse',
    'Lezioni di lingua',
    'Cours de langue',
    'Уроки языка',
  );
  String get learnSubtitle => _(
    'Lessons from your first words to how languages work.',
    'Μαθήματα από τις πρώτες λέξεις ως το πώς δουλεύουν οι γλώσσες.',
    'Lecciones desde tus primeras palabras hasta cómo funcionan los idiomas.',
    'Lektionen von den ersten Wörtern bis dazu, wie Sprachen funktionieren.',
    'Lezioni dalle prime parole a come funzionano le lingue.',
    'Des leçons, des premiers mots au fonctionnement des langues.',
    'Уроки от первых слов до того, как устроены языки.',
  );
  String get comingSoon => _(
    'Coming soon',
    'Έρχεται σύντομα',
    'Próximamente',
    'Bald verfügbar',
    'In arrivo',
    'Bientôt disponible',
    'Скоро',
  );

  // ── Crossword menu ──
  String get dailyCrossword => _(
    'DAILY CROSSWORD',
    'ΣΤΑΥΡΟΛΕΞΟ ΤΗΣ ΗΜΕΡΑΣ',
    'CRUCIGRAMA DEL DÍA',
    'KREUZWORTRÄTSEL DES TAGES',
    'CRUCIVERBA DEL GIORNO',
    'MOTS CROISÉS DU JOUR',
    'КРОССВОРД ДНЯ',
  );
  String get newGame => _(
    'New Game',
    'Νέο Παιχνίδι',
    'Nueva partida',
    'Neues Spiel',
    'Nuova partita',
    'Nouvelle partie',
    'Новая игра',
  );
  String get newGameSubtitle => _(
    'Start a fresh puzzle.',
    'Ξεκίνα ένα καινούργιο σταυρόλεξο.',
    'Empieza un crucigrama nuevo.',
    'Starte ein neues Rätsel.',
    'Inizia un nuovo cruciverba.',
    'Commence une nouvelle grille.',
    'Начни новый кроссворд.',
  );
  String get continueGame => _(
    'Continue',
    'Συνέχεια',
    'Continuar',
    'Weiterspielen',
    'Continua',
    'Continuer',
    'Продолжить',
  );
  String get noSavedGame => _(
    'No saved game.',
    'Δεν υπάρχει αποθηκευμένο παιχνίδι.',
    'No hay ninguna partida guardada.',
    'Kein gespeichertes Spiel.',
    'Nessuna partita salvata.',
    'Aucune partie enregistrée.',
    'Нет сохранённой игры.',
  );
  String get chooseSubject => _(
    'Choose a subject',
    'Διάλεξε θέμα',
    'Elige un tema',
    'Wähle ein Thema',
    'Scegli un tema',
    'Choisis un thème',
    'Выбери тему',
  );
  String get allThemes => _(
    'All subjects',
    'Όλα τα θέματα',
    'Todos los temas',
    'Alle Themen',
    'Tutti i temi',
    'Tous les thèmes',
    'Все темы',
  );
  String get allSubjectsSubtitle => _(
    'Words from every subject.',
    'Λέξεις από όλα τα θέματα.',
    'Palabras de todos los temas.',
    'Wörter aus allen Themen.',
    'Parole da tutti i temi.',
    'Des mots de tous les thèmes.',
    'Слова из всех тем.',
  );
  String wordCount(int n) {
    // Thousands: 1,234 / 1.234 / 1 234 (French and Russian, a thin space).
    final sep = switch (code) {
      'en' => ',',
      'fr' || 'ru' => '\u202F',
      _ => '.',
    };
    final s = n >= 1000
        ? '${n ~/ 1000}$sep${(n % 1000).toString().padLeft(3, '0')}'
        : '$n';
    return _(
      '$s words',
      '$s λέξεις',
      '$s palabras',
      '$s Wörter',
      '$s parole',
      '$s mots',
      '$s ${_ru(n, 'слово', 'слова', 'слов')}',
    );
  }

  String continueWithSubject(int level, String subject) => _(
    'Pick up where you left off — Level $level, $subject.',
    'Συνέχισε από εκεί που σταμάτησες — Επίπεδο $level, $subject.',
    'Sigue donde lo dejaste — Nivel $level, $subject.',
    'Mach weiter, wo du aufgehört hast — Level $level, $subject.',
    'Riprendi da dove avevi lasciato — Livello $level, $subject.',
    'Reprends là où tu t’étais arrêté — Niveau $level, $subject.',
    'Продолжи с того места, где остановился, — уровень $level, $subject.',
  );
  String continueSubtitle(int level) => _(
    'Pick up where you left off — Level $level.',
    'Συνέχισε από εκεί που σταμάτησες — Επίπεδο $level.',
    'Sigue donde lo dejaste — Nivel $level.',
    'Mach weiter, wo du aufgehört hast — Level $level.',
    'Riprendi da dove avevi lasciato — Livello $level.',
    'Reprends là où tu t’étais arrêté — Niveau $level.',
    'Продолжи с того места, где остановился, — уровень $level.',
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
      'Livello $number',
      'Niveau $number',
      'Уровень $number',
    );
  }

  String settingLevel(int n) => _(
    'Setting ${level(n)}…',
    'Ετοιμάζεται: ${level(n)}…',
    'Preparando: ${level(n)}…',
    'Bereite vor: ${level(n)}…',
    'Preparazione: ${level(n)}…',
    'Préparation : ${level(n)}…',
    'Готовится: ${level(n)}…',
  );
  String get couldNotSetPuzzle => _(
    "Couldn't set this puzzle. Try again?",
    'Δεν ήταν δυνατό να στηθεί ο γρίφος. Δοκιμάζεις ξανά;',
    'No se pudo montar este crucigrama. ¿Lo intentamos de nuevo?',
    'Dieses Rätsel ließ sich nicht erstellen. Noch einmal versuchen?',
    'Impossibile creare questo cruciverba. Riprovare?',
    'Impossible de créer cette grille. On réessaie ?',
    'Не удалось составить этот кроссворд. Попробовать ещё раз?',
  );
  String get tryAgain => _(
    'Try again',
    'Ξανά',
    'Reintentar',
    'Erneut versuchen',
    'Riprova',
    'Réessayer',
    'Ещё раз',
  );
  String get searchOnDictionary => _(
    'Search on dictionary',
    'Αναζήτηση στο λεξικό',
    'Buscar en el diccionario',
    'Im Wörterbuch suchen',
    'Cerca nel dizionario',
    'Rechercher dans le dictionnaire',
    'Искать в словаре',
  );
  String get acrossClues => _(
    'ACROSS CLUES',
    'ΟΡΙΖΟΝΤΙΑ',
    'HORIZONTALES',
    'WAAGERECHT',
    'ORIZZONTALI',
    'HORIZONTALEMENT',
    'ПО ГОРИЗОНТАЛИ',
  );
  String get downClues => _(
    'DOWN CLUES',
    'ΚΑΘΕΤΑ',
    'VERTICALES',
    'SENKRECHT',
    'VERTICALI',
    'VERTICALEMENT',
    'ПО ВЕРТИКАЛИ',
  );
  String get clear => _(
    'Clear',
    'Σβήσιμο',
    'Borrar',
    'Löschen',
    'Cancella',
    'Effacer',
    'Стереть',
  );
  String get hint =>
      _('Hint', 'Βοήθεια', 'Pista', 'Tipp', 'Aiuto', 'Indice', 'Подсказка');
  String get check => _(
    'Check',
    'Έλεγχος',
    'Comprobar',
    'Prüfen',
    'Verifica',
    'Vérifier',
    'Проверить',
  );
  String get nextLevel => _(
    'Next level',
    'Επόμενο επίπεδο',
    'Siguiente nivel',
    'Nächstes Level',
    'Livello successivo',
    'Niveau suivant',
    'Следующий уровень',
  );
  String get nextLevelTest => _(
    'Next level (test)',
    'Επόμενο επίπεδο (δοκιμή)',
    'Siguiente nivel (prueba)',
    'Nächstes Level (Test)',
    'Livello successivo (prova)',
    'Niveau suivant (test)',
    'Следующий уровень (тест)',
  );
  // ── Find the Words ──
  String get wordSearchKicker => _(
    'HIDDEN WORDS',
    'ΚΡΥΜΜΕΝΕΣ ΛΕΞΕΙΣ',
    'PALABRAS ESCONDIDAS',
    'VERSTECKTE WÖRTER',
    'PAROLE NASCOSTE',
    'MOTS CACHÉS',
    'СПРЯТАННЫЕ СЛОВА',
  );
  String get newWordSearchSubtitle => _(
    'Start a fresh grid of hidden words.',
    'Ξεκίνα ένα καινούργιο πλέγμα.',
    'Empieza una nueva sopa de letras.',
    'Starte ein neues Buchstabengitter.',
    'Inizia una nuova griglia di parole nascoste.',
    'Commence une nouvelle grille de mots cachés.',
    'Начни новую сетку со спрятанными словами.',
  );
  String get wordsToFind => _(
    'WORDS TO FIND',
    'ΛΕΞΕΙΣ ΓΙΑ ΝΑ ΒΡΕΙΣ',
    'PALABRAS POR ENCONTRAR',
    'GESUCHTE WÖRTER',
    'PAROLE DA TROVARE',
    'MOTS À TROUVER',
    'СЛОВА ДЛЯ ПОИСКА',
  );
  String foundCount(int found, int total) => _(
    '$found of $total found',
    '$found από $total',
    '$found de $total',
    '$found von $total',
    '$found di $total',
    '$found sur $total',
    '$found из $total',
  );
  String get allWordsFound => _(
    'All words found!',
    'Βρήκες όλες τις λέξεις!',
    '¡Encontraste todas las palabras!',
    'Alle Wörter gefunden!',
    'Hai trovato tutte le parole!',
    'Tous les mots sont trouvés !',
    'Все слова найдены!',
  );
  String get dragToFind => _(
    'Drag across a word, from its first letter to its last.',
    'Σύρε το δάχτυλο πάνω σε μια λέξη, από το πρώτο ως το τελευταίο γράμμα.',
    'Desliza el dedo sobre una palabra, de la primera a la última letra.',
    'Zieh den Finger über ein Wort, vom ersten bis zum letzten Buchstaben.',
    'Trascina il dito su una parola, dalla prima all’ultima lettera.',
    'Fais glisser ton doigt sur un mot, de la première à la dernière lettre.',
    'Проведи пальцем по слову от первой до последней буквы.',
  );

  // ── Dictionary ──
  String get partOfSpeech => _(
    'PART OF SPEECH',
    'ΜΕΡΟΣ ΤΟΥ ΛΟΓΟΥ',
    'CATEGORÍA GRAMATICAL',
    'WORTART',
    'PARTE DEL DISCORSO',
    'NATURE',
    'ЧАСТЬ РЕЧИ',
  );
  String get structure => _(
    'STRUCTURE',
    'ΔΟΜΗ',
    'ESTRUCTURA',
    'AUFBAU',
    'STRUTTURA',
    'STRUCTURE',
    'СТРОЕНИЕ',
  );
  String get subject =>
      _('SUBJECT', 'ΘΕΜΑΤΙΚΟ ΠΕΔΙΟ', 'TEMA', 'THEMA', 'TEMA', 'THÈME', 'ТЕМА');
  String get all => _('All', 'Όλα', 'Todo', 'Alle', 'Tutto', 'Tout', 'Все');
  String get allSubjects => _(
    'All subjects',
    'Όλα τα πεδία',
    'Todos los temas',
    'Alle Themen',
    'Tutti i temi',
    'Tous les thèmes',
    'Все темы',
  );
  String get general => _(
    'General',
    'Γενικά',
    'General',
    'Allgemein',
    'Generale',
    'Général',
    'Общее',
  );
  String get generalNoSubject => _(
    'General (no subject)',
    'Γενικά (χωρίς πεδίο)',
    'General (sin tema)',
    'Allgemein (ohne Thema)',
    'Generale (nessun tema)',
    'Général (sans thème)',
    'Общее (без темы)',
  );
  String get loadingDictionary => _(
    'Loading dictionary…',
    'Φορτώνει το λεξικό…',
    'Cargando el diccionario…',
    'Wörterbuch wird geladen…',
    'Caricamento del dizionario…',
    'Chargement du dictionnaire…',
    'Словарь загружается…',
  );
  String get searchToBegin => _(
    'Search for a word to begin.',
    'Ψάξε μια λέξη για να ξεκινήσεις.',
    'Busca una palabra para empezar.',
    'Suche ein Wort, um zu beginnen.',
    'Cerca una parola per iniziare.',
    'Cherche un mot pour commencer.',
    'Найди слово, чтобы начать.',
  );
  String get noMatches => _(
    'No matches.',
    'Δεν βρέθηκε τίποτα.',
    'Sin resultados.',
    'Keine Treffer.',
    'Nessun risultato.',
    'Aucun résultat.',
    'Ничего не найдено.',
  );
  String alsoCalledQuoted(String name) => _(
    'Also called “$name”',
    'Λέγεται και «$name»',
    'También llamado «$name»',
    'Auch „$name“ genannt',
    'Detto anche «$name»',
    'Aussi appelé « $name »',
    'Также называется «$name»',
  );
  String meanings(int n) => _(
    '$n ${n == 1 ? 'meaning' : 'meanings'}',
    '$n ${n == 1 ? 'σημασία' : 'σημασίες'}',
    '$n ${n == 1 ? 'significado' : 'significados'}',
    '$n ${n == 1 ? 'Bedeutung' : 'Bedeutungen'}',
    '$n ${n == 1 ? 'significato' : 'significati'}',
    '$n sens',
    '$n ${_ru(n, 'значение', 'значения', 'значений')}',
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

  static const _posIt = {
    'noun': 'Sostantivo',
    'verb': 'Verbo',
    'adj': 'Aggettivo',
    'adv': 'Avverbio',
    'pron': 'Pronome',
    'prep': 'Preposizione',
    'conj': 'Congiunzione',
    'interj': 'Interiezione',
    'det': 'Determinante',
    'art': 'Articolo',
    'part': 'Participio',
  };
  static const _posFr = {
    'noun': 'Nom',
    'verb': 'Verbe',
    'adj': 'Adjectif',
    'adv': 'Adverbe',
    'pron': 'Pronom',
    'prep': 'Préposition',
    'conj': 'Conjonction',
    'interj': 'Interjection',
    'det': 'Déterminant',
    'art': 'Article',
    'part': 'Participe',
  };
  static const _posRu = {
    'noun': 'Существительное',
    'verb': 'Глагол',
    'adj': 'Прилагательное',
    'adv': 'Наречие',
    'pron': 'Местоимение',
    'prep': 'Предлог',
    'conj': 'Союз',
    'interj': 'Междометие',
    'det': 'Определитель',
    'art': 'Артикль',
    'part': 'Причастие',
  };

  /// Part of speech name, e.g. "adj" -> "Adjective" / "Επίθετο".
  String partOfSpeechName(String pos) =>
      switch (code) {
        'el' => _posEl,
        'es' => _posEs,
        'de' => _posDe,
        'it' => _posIt,
        'fr' => _posFr,
        'ru' => _posRu,
        _ => _posEn,
      }[pos] ??
      pos.toUpperCase();

  // ── Word page ──
  String get close => _(
    'Close',
    'Κλείσιμο',
    'Cerrar',
    'Schließen',
    'Chiudi',
    'Fermer',
    'Закрыть',
  );
  String get noEntryYet => _(
    'No entry for this word yet.',
    'Δεν υπάρχει ακόμα λήμμα για αυτή τη λέξη.',
    'Aún no hay una entrada para esta palabra.',
    'Für dieses Wort gibt es noch keinen Eintrag.',
    'Non c’è ancora una voce per questa parola.',
    'Pas encore d’entrée pour ce mot.',
    'Для этого слова пока нет статьи.',
  );
  String syllables(int n) => _(
    '$n syllables',
    '$n συλλαβές',
    '$n sílabas',
    '$n Silben',
    '$n sillabe',
    '$n syllabes',
    '$n ${_ru(n, 'слог', 'слога', 'слогов')}',
  );
  String plural(String forms) => _(
    'plural $forms',
    'πληθυντικός: $forms',
    'plural $forms',
    'Plural $forms',
    'plurale $forms',
    'pluriel $forms',
    'мн. ч. $forms',
  );
  String get moreExamples => _(
    'MORE EXAMPLES',
    'ΠΕΡΙΣΣΟΤΕΡΑ ΠΑΡΑΔΕΙΓΜΑΤΑ',
    'MÁS EJEMPLOS',
    'WEITERE BEISPIELE',
    'ALTRI ESEMPI',
    'AUTRES EXEMPLES',
    'ЕЩЁ ПРИМЕРЫ',
  );
  String get phrases => _(
    'PHRASES',
    'ΦΡΑΣΕΙΣ',
    'FRASES',
    'WENDUNGEN',
    'ESPRESSIONI',
    'EXPRESSIONS',
    'ВЫРАЖЕНИЯ',
  );
  String get aboutTheWord => _(
    'ABOUT THE WORD',
    'ΓΙΑ ΤΗ ΛΕΞΗ',
    'SOBRE LA PALABRA',
    'ZUM WORT',
    'SULLA PAROLA',
    'À PROPOS DU MOT',
    'О СЛОВЕ',
  );
  String get structureLabel => _(
    'Structure',
    'Δομή',
    'Estructura',
    'Aufbau',
    'Struttura',
    'Structure',
    'Строение',
  );
  String structureWord(String name) => _(
    '$name word',
    '$name λέξη',
    'palabra $name',
    '$name Wort',
    'parola $name',
    'mot $name',
    '$name слово',
  );
  String get originLabel => _(
    'Origin',
    'Προέλευση',
    'Origen',
    'Herkunft',
    'Origine',
    'Origine',
    'Происхождение',
  );
  String borrowedFrom(String languages) => _(
    'Borrowed from $languages',
    'Δάνειο από: $languages',
    'Tomado de $languages',
    'Entlehnt aus $languages',
    'Preso in prestito da: $languages',
    'Emprunté à : $languages',
    'Заимствовано из: $languages',
  );
  String fromLanguage(String language) => _(
    'From $language',
    'Από: $language',
    'Del $language',
    'Aus dem $language',
    'Da: $language',
    'De : $language',
    'Из: $language',
  );
  String get relatedForms => _(
    'Related forms',
    'Συγγενικοί τύποι',
    'Formas relacionadas',
    'Verwandte Formen',
    'Forme correlate',
    'Formes apparentées',
    'Родственные формы',
  );
  String get relatingToIt => _(
    'Relating to it',
    'Σχετικά επίθετα',
    'Relacionado',
    'Dazu gehörend',
    'Collegati',
    'Qui s’y rapportent',
    'Связанные',
  );
  String get alsoCalled => _(
    'Also called',
    'Λέγεται και',
    'También llamado',
    'Auch genannt',
    'Detto anche',
    'Aussi appelé',
    'Также называется',
  );
  String get meaningLabel => _(
    'Meaning',
    'Σημασία',
    'Significado',
    'Bedeutung',
    'Significato',
    'Sens',
    'Значение',
  );
  String get examplesLabel => _(
    'Examples',
    'Παραδείγματα',
    'Ejemplos',
    'Beispiele',
    'Esempi',
    'Exemples',
    'Примеры',
  );
  String get synonyms => _(
    'Synonyms',
    'Συνώνυμα',
    'Sinónimos',
    'Synonyme',
    'Sinonimi',
    'Synonymes',
    'Синонимы',
  );
  String get opposites => _(
    'Opposites',
    'Αντίθετα',
    'Antónimos',
    'Gegenteile',
    'Contrari',
    'Contraires',
    'Антонимы',
  );
  String moreCount(int n) => _(
    '+$n more',
    '+$n ακόμα',
    '+$n más',
    '+$n weitere',
    '+$n altri',
    '+$n de plus',
    'ещё $n',
  );

  /// [accent] is the accent's name: "american", "british", "greek",
  /// "spanish", "german", "italian", "french" or "russian".
  String noVoice(String accent) {
    // The voice's adjective (Russian: genitive, "нет русского голоса").
    String voice(
      String en,
      String el,
      String es,
      String de,
      String it,
      String fr,
      String ru,
    ) => _(en, el, es, de, it, fr, ru);
    final which = switch (accent) {
      'american' => voice(
        'American',
        'αμερικανική',
        'estadounidense',
        'amerikanische',
        'americana',
        'américaine',
        'американского',
      ),
      'british' => voice(
        'British',
        'βρετανική',
        'británica',
        'britische',
        'britannica',
        'britannique',
        'британского',
      ),
      'greek' => voice(
        'Greek',
        'ελληνική',
        'griega',
        'griechische',
        'greca',
        'grecque',
        'греческого',
      ),
      'spanish' => voice(
        'Spanish',
        'ισπανική',
        'española',
        'spanische',
        'spagnola',
        'espagnole',
        'испанского',
      ),
      'italian' => voice(
        'Italian',
        'ιταλική',
        'italiana',
        'italienische',
        'italiana',
        'italienne',
        'итальянского',
      ),
      'french' => voice(
        'French',
        'γαλλική',
        'francesa',
        'französische',
        'francese',
        'française',
        'французского',
      ),
      'russian' => voice(
        'Russian',
        'ρωσική',
        'rusa',
        'russische',
        'russa',
        'russe',
        'русского',
      ),
      _ => voice(
        'German',
        'γερμανική',
        'alemana',
        'deutsche',
        'tedesca',
        'allemande',
        'немецкого',
      ),
    };
    return _(
      "No $which voice on this phone. You can add one in the phone's "
          'text-to-speech settings.',
      'Δεν υπάρχει $which φωνή σε αυτό το τηλέφωνο. Μπορείς να προσθέσεις '
          'μία από τις ρυθμίσεις μετατροπής κειμένου σε ομιλία του '
          'τηλεφώνου.',
      'No hay voz $which en este teléfono. Puedes añadir una en los ajustes '
          'de texto a voz del teléfono.',
      'Keine $which Stimme auf diesem Handy. Du kannst eine in den '
          'Text-zu-Sprache-Einstellungen des Handys hinzufügen.',
      'Nessuna voce $which su questo telefono. Puoi aggiungerne una nelle '
          'impostazioni di sintesi vocale del telefono.',
      'Aucune voix $which sur ce téléphone. Tu peux en ajouter une dans les '
          'réglages de synthèse vocale du téléphone.',
      'На этом телефоне нет $which голоса. Его можно добавить в настройках '
          'синтеза речи телефона.',
    );
  }

  // ── Settings ──
  String get language =>
      _('Language', 'Γλώσσα', 'Idioma', 'Sprache', 'Lingua', 'Langue', 'Язык');
  String get mainLanguage => _(
    'Main',
    'Κύρια',
    'Principal',
    'Haupt',
    'Principale',
    'Principale',
    'Основной',
  );
  String get secondaryLanguage => _(
    'Secondary',
    'Δευτερεύουσα',
    'Secundario',
    'Zweitsprache',
    'Secondaria',
    'Secondaire',
    'Второй',
  );
  String get setAsMain => _(
    'Set as main language',
    'Ορισμός ως κύρια γλώσσα',
    'Usar como idioma principal',
    'Als Hauptsprache festlegen',
    'Imposta come lingua principale',
    'Définir comme langue principale',
    'Сделать основным языком',
  );
  String get setAsSecondary => _(
    'Set as secondary language',
    'Ορισμός ως δευτερεύουσα γλώσσα',
    'Usar como idioma secundario',
    'Als Zweitsprache festlegen',
    'Imposta come lingua secondaria',
    'Définir comme langue secondaire',
    'Сделать вторым языком',
  );
  String get removeSecondary => _(
    'Remove as secondary language',
    'Αφαίρεση από δευτερεύουσα γλώσσα',
    'Quitar como idioma secundario',
    'Als Zweitsprache entfernen',
    'Rimuovi come lingua secondaria',
    'Retirer comme langue secondaire',
    'Убрать как второй язык',
  );

  /// A language's name written in this text's language, e.g. 'en' →
  /// "English" / "Αγγλικά".
  String languageName(String code) => switch (code) {
    'en' => _(
      'English',
      'Αγγλικά',
      'Inglés',
      'Englisch',
      'Inglese',
      'Anglais',
      'Английский',
    ),
    'el' => _(
      'Greek',
      'Ελληνικά',
      'Griego',
      'Griechisch',
      'Greco',
      'Grec',
      'Греческий',
    ),
    'es' => _(
      'Spanish',
      'Ισπανικά',
      'Español',
      'Spanisch',
      'Spagnolo',
      'Espagnol',
      'Испанский',
    ),
    'fr' => _(
      'French',
      'Γαλλικά',
      'Francés',
      'Französisch',
      'Francese',
      'Français',
      'Французский',
    ),
    'de' => _(
      'German',
      'Γερμανικά',
      'Alemán',
      'Deutsch',
      'Tedesco',
      'Allemand',
      'Немецкий',
    ),
    'it' => _(
      'Italian',
      'Ιταλικά',
      'Italiano',
      'Italienisch',
      'Italiano',
      'Italien',
      'Итальянский',
    ),
    'ru' => _(
      'Russian',
      'Ρωσικά',
      'Ruso',
      'Russisch',
      'Russo',
      'Russe',
      'Русский',
    ),
    _ => code,
  };
  String withSecondary(String main, String second) => _(
    '$main · secondary: $second',
    '$main · δευτερεύουσα: $second',
    '$main · secundario: $second',
    '$main · Zweitsprache: $second',
    '$main · secondaria: $second',
    '$main · secondaire : $second',
    '$main · второй: $second',
  );
  String get darkMode => _(
    'Dark mode',
    'Σκούρο θέμα',
    'Modo oscuro',
    'Dunkler Modus',
    'Tema scuro',
    'Mode sombre',
    'Тёмная тема',
  );
  String get wordLookUp => _(
    'Double-tap a word',
    'Διπλό πάτημα σε λέξη',
    'Doble toque en una palabra',
    'Doppeltippen auf ein Wort',
    'Doppio tocco su una parola',
    'Toucher deux fois un mot',
    'Двойное касание слова',
  );
  String get wordLookUpOn => _(
    'Opens it in the dictionary',
    'Την ανοίγει στο λεξικό',
    'La abre en el diccionario',
    'Öffnet es im Wörterbuch',
    'La apre nel dizionario',
    'L’ouvre dans le dictionnaire',
    'Открывает его в словаре',
  );
  String get on =>
      _('On', 'Ενεργό', 'Activado', 'An', 'Attivo', 'Activé', 'Вкл.');
  String get off => _(
    'Off',
    'Ανενεργό',
    'Desactivado',
    'Aus',
    'Disattivato',
    'Désactivé',
    'Выкл.',
  );
  String get fontSize => _(
    'Font size',
    'Μέγεθος γραμμάτων',
    'Tamaño del texto',
    'Schriftgröße',
    'Dimensione del testo',
    'Taille du texte',
    'Размер шрифта',
  );
  String get small =>
      _('Small', 'Μικρά', 'Pequeño', 'Klein', 'Piccolo', 'Petit', 'Мелкий');
  String get medium =>
      _('Medium', 'Μεσαία', 'Mediano', 'Mittel', 'Medio', 'Moyen', 'Средний');
  String get large =>
      _('Large', 'Μεγάλα', 'Grande', 'Groß', 'Grande', 'Grand', 'Крупный');
  String get feedback => _(
    'Feedback',
    'Σχόλια',
    'Comentarios',
    'Feedback',
    'Commenti',
    'Avis',
    'Отзыв',
  );
  String get feedbackSubtitle => _(
    'Tell us what you think or report a problem.',
    'Πες μας τη γνώμη σου ή ανέφερε ένα πρόβλημα.',
    'Dinos qué te parece o informa de un problema.',
    'Sag uns deine Meinung oder melde ein Problem.',
    'Dicci cosa ne pensi o segnala un problema.',
    'Dis-nous ce que tu en penses ou signale un problème.',
    'Расскажи, что думаешь, или сообщи о проблеме.',
  );
  String get feedbackSubject => _(
    'Lex Hopper feedback',
    'Σχόλια για το Lex Hopper',
    'Comentarios sobre Lex Hopper',
    'Feedback zu Lex Hopper',
    'Commenti su Lex Hopper',
    'Avis sur Lex Hopper',
    'Отзыв о Lex Hopper',
  );
  String noEmailApp(String email) => _(
    'No email app found. Write to us at $email',
    'Δεν βρέθηκε εφαρμογή email. Γράψε μας στο $email',
    'No se encontró ninguna app de correo. Escríbenos a $email',
    'Keine E-Mail-App gefunden. Schreib uns an $email',
    'Nessuna app di posta trovata. Scrivici a $email',
    'Aucune app de messagerie trouvée. Écris-nous à $email',
    'Почтовое приложение не найдено. Напиши нам на $email',
  );

  /// The teacher's cloud over the round button: an invitation to chat,
  /// one of three, picked by [variant].
  String teacherInvite(int variant) => switch (variant % 3) {
    0 => _(
      "I'm your language teacher. Shall we practise together?",
      'Είμαι ο δάσκαλός σου στις γλώσσες. Κάνουμε λίγη εξάσκηση μαζί;',
      'Soy tu profesor de idiomas. ¿Practicamos juntos?',
      'Ich bin dein Sprachlehrer. Wollen wir zusammen üben?',
      'Sono il tuo insegnante di lingue. Ci esercitiamo insieme?',
      "Je suis ton professeur de langues. On s'entraîne ensemble ?",
      'Я твой учитель языков. Попрактикуемся вместе?',
    ),
    1 => _(
      "Got five minutes? Let's have a little chat.",
      'Έχεις πέντε λεπτά; Ας πούμε δυο κουβέντες.',
      '¿Tienes cinco minutos? Charlemos un poco.',
      'Hast du fünf Minuten? Lass uns ein bisschen plaudern.',
      'Hai cinque minuti? Facciamo due chiacchiere.',
      'Tu as cinq minutes ? Bavardons un peu.',
      'Есть пять минут? Давай немного поболтаем.',
    ),
    _ => _(
      "A few new words every day. Shall we start today's?",
      'Κάθε μέρα λίγες καινούργιες λέξεις. Πάμε για τις σημερινές;',
      'Cada día unas palabras nuevas. ¿Vamos con las de hoy?',
      'Jeden Tag ein paar neue Wörter. Fangen wir mit den heutigen an?',
      'Ogni giorno qualche parola nuova. Iniziamo con quelle di oggi?',
      "Chaque jour quelques mots nouveaux. On commence ceux d'aujourd'hui ?",
      'Каждый день несколько новых слов. Начнём с сегодняшних?',
    ),
  };

  String get chatWithAi => _(
    'Chat with AI',
    'Συζήτηση με AI',
    'Chatea con la IA',
    'Chat mit KI',
    'Chatta con l’IA',
    'Discuter avec l’IA',
    'Чат с ИИ',
  );
  String get chatWithAiSubtitle => _(
    'Practise a language by chatting.',
    'Εξασκήσου σε μια γλώσσα συζητώντας.',
    'Practica un idioma conversando.',
    'Übe eine Sprache im Gespräch.',
    'Esercitati in una lingua chiacchierando.',
    'Pratique une langue en discutant.',
    'Практикуй язык в разговоре.',
  );
  String get chatHello => _(
    'Hi! Let’s practise.',
    'Γεια! Ας εξασκηθούμε.',
    '¡Hola! Vamos a practicar.',
    'Hallo! Lass uns üben.',
    'Ciao! Esercitiamoci.',
    'Salut ! On s’entraîne ?',
    'Привет! Давай потренируемся.',
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
    'Scrivi in una lingua che stai imparando. Ti risponderò e correggerò con delicatezza i tuoi errori.',
    'Écris dans la langue que tu apprends. Je te réponds et je corrige tes erreurs en douceur.',
    'Пиши на языке, который учишь. Я отвечу и мягко поправлю ошибки.',
  );
  String get chatHint => _(
    'Write a message…',
    'Γράψε ένα μήνυμα…',
    'Escribe un mensaje…',
    'Schreib eine Nachricht…',
    'Scrivi un messaggio…',
    'Écris un message…',
    'Напиши сообщение…',
  );
  String get chatStarterCafe => _(
    'Let’s order a coffee in a café',
    'Ας παραγγείλουμε καφέ σε ένα καφέ',
    'Pidamos un café en una cafetería',
    'Lass uns im Café einen Kaffee bestellen',
    'Ordiniamo un caffè al bar',
    'Commandons un café en terrasse',
    'Давай закажем кофе в кафе',
  );
  String get chatStarterCorrect => _(
    'Correct my sentence',
    'Διόρθωσε την πρότασή μου',
    'Corrige mi frase',
    'Korrigiere meinen Satz',
    'Correggi la mia frase',
    'Corrige ma phrase',
    'Исправь моё предложение',
  );
  String get chatStarterWord => _(
    'Teach me a new word',
    'Μάθε μου μια καινούργια λέξη',
    'Enséñame una palabra nueva',
    'Bring mir ein neues Wort bei',
    'Insegnami una parola nuova',
    'Apprends-moi un nouveau mot',
    'Научи меня новому слову',
  );
  String get chatStarterTravel => _(
    'Help me ask for directions',
    'Βοήθησέ με να ρωτήσω πώς θα πάω κάπου',
    'Ayúdame a pedir indicaciones',
    'Hilf mir, nach dem Weg zu fragen',
    'Aiutami a chiedere indicazioni',
    'Aide-moi à demander mon chemin',
    'Помоги мне спросить дорогу',
  );

  /// The teacher's first words while no AI is on the phone.
  String get aiOffer => _(
    "I'm your language teacher. To chat with me, download the AI: "
        'it lives on your phone and works without internet.',
    'Είμαι ο δάσκαλός σου στις γλώσσες. Για να συζητήσουμε, '
        'κατέβασε το AI: μένει στο κινητό σου και λειτουργεί χωρίς ίντερνετ.',
    'Soy tu profesor de idiomas. Para chatear conmigo, descarga la '
        'IA: vive en tu móvil y funciona sin internet.',
    'Ich bin dein Sprachlehrer. Um mit mir zu chatten, lade die KI '
        'herunter: Sie läuft auf deinem Handy, ohne Internet.',
    'Sono il tuo insegnante di lingue. Per chattare con me, scarica '
        "l'IA: vive sul tuo telefono e funziona senza internet.",
    'Je suis ton professeur de langues. Pour discuter avec moi, '
        "télécharge l'IA : elle vit sur ton téléphone et marche sans internet.",
    'Я твой учитель языков. Чтобы поговорить со мной, скачай ИИ: '
        'он работает на телефоне без интернета.',
  );

  /// The button under [aiOffer].
  String aiOfferButton(int mb) => _(
    'Download the AI · $mb MB',
    'Λήψη του AI · $mb MB',
    'Descargar la IA · $mb MB',
    'KI herunterladen · $mb MB',
    "Scarica l'IA · $mb MB",
    "Télécharger l'IA · $mb Mo",
    'Скачать ИИ · $mb МБ',
  );

  /// The AI downloading, in the chat.
  String aiGettingReady(int percent) => _(
    'Downloading the AI… $percent%',
    'Λήψη του AI… $percent%',
    'Descargando la IA… $percent%',
    'KI wird geladen… $percent%',
    "Download dell'IA… $percent%",
    "Téléchargement de l'IA… $percent%",
    'Загрузка ИИ… $percent%',
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
    'Per chattare, attiva un modello IA in Impostazioni > Modello IA (EuroLLM o Gemma 4). Si scarica una volta sola e poi funziona senza internet.',
    'Pour discuter, active un modèle d’IA dans Réglages > Modèle d’IA (EuroLLM ou Gemma 4). Il se télécharge une fois, puis fonctionne sans internet.',
    'Чтобы общаться, включи модель ИИ в разделе Настройки > Модель ИИ (EuroLLM или Gemma 4). Она загружается один раз и потом работает без интернета.',
  );
  String chatWarming(String model) => _(
    'Getting $model ready…',
    'Το $model ετοιμάζεται…',
    'Preparando $model…',
    '$model wird vorbereitet…',
    'Preparazione di $model…',
    'Préparation de $model…',
    '$model готовится…',
  );
  String get listen => _(
    'Listen',
    'Άκουσε',
    'Escuchar',
    'Anhören',
    'Ascolta',
    'Écouter',
    'Слушать',
  );
  String get chatFailed => _(
    'Sorry, I couldn’t answer that. Try again?',
    'Συγγνώμη, δεν μπόρεσα να απαντήσω. Ξανά;',
    'Lo siento, no pude responder. ¿Otra vez?',
    'Entschuldige, das konnte ich nicht beantworten. Noch einmal?',
    'Scusa, non sono riuscito a rispondere. Riprovi?',
    'Désolé, je n’ai pas pu répondre. On réessaie ?',
    'Извини, не получилось ответить. Ещё раз?',
  );
  String get goToTop => _(
    'Go to top',
    'Στην αρχή',
    'Ir arriba',
    'Nach oben',
    'Torna su',
    'Haut de page',
    'Наверх',
  );
  // Downloadable languages (Settings > Language).
  String downloadLanguageTitle(String name) => _(
    'Download $name?',
    'Λήψη: $name;',
    '¿Descargar $name?',
    '$name herunterladen?',
    'Scaricare: $name?',
    'Télécharger : $name ?',
    'Скачать: $name?',
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
    'Il suo dizionario e il suo traduttore offline, circa $mb MB (meglio con il Wi-Fi). Poi funziona senza internet.',
    'Son dictionnaire et son traducteur hors ligne, environ $mb Mo (de préférence en Wi-Fi). Ensuite, tout fonctionne sans internet.',
    'Словарь и офлайн-переводчик, около $mb МБ (лучше по Wi-Fi). Потом всё работает без интернета.',
  );
  String removeLanguagePack(int mb) => _(
    'Remove from the phone (frees $mb MB)',
    'Αφαίρεση από το κινητό (ελευθερώνει $mb MB)',
    'Quitar del teléfono (libera $mb MB)',
    'Vom Handy entfernen (gibt $mb MB frei)',
    'Rimuovi dal telefono (libera $mb MB)',
    'Retirer du téléphone (libère $mb Mo)',
    'Удалить с телефона (освободит $mb МБ)',
  );
  String get packCredits => _(
    'Downloadable languages: Spanish words from the Multilingual Central '
        'Repository (CC BY 3.0); German words and definitions from OdeNet '
        '(CC BY-SA 4.0); Italian words from MultiWordNet (CC BY 3.0); French '
        'words from WOLF (CeCILL-C); Russian words from Wiktionary via '
        'kaikki.org (CC BY-SA 4.0); definitions and examples from Princeton '
        'WordNet, translated with OPUS-MT.',
    'Γλώσσες για λήψη: ισπανικές λέξεις από το Multilingual Central '
        'Repository (CC BY 3.0)· γερμανικές λέξεις και ορισμοί από το OdeNet '
        '(CC BY-SA 4.0)· ιταλικές λέξεις από το MultiWordNet (CC BY 3.0)· '
        'γαλλικές λέξεις από το WOLF (CeCILL-C)· ρωσικές λέξεις από το '
        'Wiktionary μέσω του kaikki.org (CC BY-SA 4.0)· ορισμοί και '
        'παραδείγματα από το Princeton WordNet, μεταφρασμένα με το OPUS-MT.',
    'Idiomas descargables: palabras en español del Multilingual Central '
        'Repository (CC BY 3.0); palabras y definiciones en alemán de OdeNet '
        '(CC BY-SA 4.0); palabras en italiano de MultiWordNet (CC BY 3.0); '
        'palabras en francés de WOLF (CeCILL-C); palabras en ruso de '
        'Wiktionary vía kaikki.org (CC BY-SA 4.0); definiciones y ejemplos '
        'de Princeton WordNet, traducidos con OPUS-MT.',
    'Ladbare Sprachen: spanische Wörter aus dem Multilingual Central '
        'Repository (CC BY 3.0); deutsche Wörter und Definitionen aus OdeNet '
        '(CC BY-SA 4.0); italienische Wörter aus MultiWordNet (CC BY 3.0); '
        'französische Wörter aus WOLF (CeCILL-C); russische Wörter aus '
        'Wiktionary über kaikki.org (CC BY-SA 4.0); Definitionen und '
        'Beispiele aus Princeton WordNet, übersetzt mit OPUS-MT.',
    'Lingue da scaricare: parole spagnole dal Multilingual Central '
        'Repository (CC BY 3.0); parole e definizioni tedesche da OdeNet '
        '(CC BY-SA 4.0); parole italiane da MultiWordNet (CC BY 3.0); parole '
        'francesi da WOLF (CeCILL-C); parole russe da Wiktionary tramite '
        'kaikki.org (CC BY-SA 4.0); definizioni ed esempi da Princeton '
        'WordNet, tradotti con OPUS-MT.',
    'Langues à télécharger : mots espagnols du Multilingual Central '
        'Repository (CC BY 3.0) ; mots et définitions allemands d’OdeNet '
        '(CC BY-SA 4.0) ; mots italiens de MultiWordNet (CC BY 3.0) ; mots '
        'français de WOLF (CeCILL-C) ; mots russes du Wiktionnaire via '
        'kaikki.org (CC BY-SA 4.0) ; définitions et exemples de Princeton '
        'WordNet, traduits avec OPUS-MT.',
    'Загружаемые языки: испанские слова из Multilingual Central '
        'Repository (CC BY 3.0); немецкие слова и определения из OdeNet '
        '(CC BY-SA 4.0); итальянские слова из MultiWordNet (CC BY 3.0); '
        'французские слова из WOLF (CeCILL-C); русские слова из Викисловаря '
        'через kaikki.org (CC BY-SA 4.0); определения и примеры из Princeton '
        'WordNet, переведённые с помощью OPUS-MT.',
  );
  String get aboutTheApp => _(
    'About the app',
    'Σχετικά με την εφαρμογή',
    'Acerca de la app',
    'Über die App',
    'Informazioni sull’app',
    'À propos de l’app',
    'О приложении',
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
    'Il traduttore offline usa OPUS-MT di Helsinki-NLP (Università di Helsinki), con licenza CC BY 4.0, ridotto per i telefoni.',
    'Le traducteur hors ligne utilise OPUS-MT de Helsinki-NLP (Université d’Helsinki), sous licence CC BY 4.0, allégé pour les téléphones.',
    'Офлайн-переводчик использует OPUS-MT от Helsinki-NLP (Хельсинкский университет), лицензия CC BY 4.0, уменьшен для телефонов.',
  );
  String get aboutTheAppSubtitle => _(
    'Learn more about the team behind the puzzles.',
    'Γνώρισε την ομάδα πίσω από τους γρίφους.',
    'Conoce al equipo detrás de los acertijos.',
    'Lerne das Team hinter den Rätseln kennen.',
    'Scopri il team dietro gli enigmi.',
    'Découvre l’équipe derrière les énigmes.',
    'Познакомься с командой, которая создаёт головоломки.',
  );
}
