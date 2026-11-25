// ─────────────────────────────────────────────────────────────────────────────
// DICTIONARY PAGE — search, filter, and browse words
// ─────────────────────────────────────────────────────────────────────────────

import 'dart:async';

import 'package:flutter/services.dart' show HapticFeedback;

import 'package:material_ui/material_ui.dart';

import 'design_system.dart';
import 'app_text.dart';
import 'dictionary_service.dart';
import 'dual_text.dart';
import 'app_settings.dart';
import 'word_sheet.dart';

class DictionaryPage extends StatefulWidget {
  /// Search text to start with (runs immediately when non-empty).
  final String initialQuery;

  /// True when shown inside [showDictionarySheet]: no back/home buttons,
  /// no Scaffold, and every state is scrollable so the sheet can be dragged.
  final bool inSheet;

  /// Scroll controller supplied by the sheet's DraggableScrollableSheet.
  final ScrollController? scrollController;

  const DictionaryPage({
    super.key,
    this.initialQuery = '',
    this.inSheet = false,
    this.scrollController,
  });

  @override
  State<DictionaryPage> createState() => _DictionaryPageState();
}

class _DictionaryPageState extends State<DictionaryPage> {
  final TextEditingController _searchController = TextEditingController();
  final FocusNode _searchFocus = FocusNode();

  List<DictionaryEntry> _results = [];
  bool _isLoading = false;
  bool _isSearching = false;
  Timer? _debounce;

  // Active filters
  String? _selectedPos;
  String? _selectedSubject; // subject id, DictionaryService.generalSubject, or null = all

  String? _selectedStructure; // simple / compound / derived, or null = all

  /// The app's text in the current language.
  AppText get _t => AppText.of(context);

  /// The dictionary of the app's language (English or Greek).
  DictionaryService get _service => DictionaryService.forLanguage(_language);
  String? _languageCode;
  String get _language => _languageCode ?? 'en';

  // Filter options
  FilterOptions? _filterOptions;

  /// The page's scroll position: the sheet's when in a sheet, else our own.
  late final ScrollController _scroll =
      widget.scrollController ?? ScrollController();

  /// Scrolled far enough down for the "go to top" button to show.
  bool _showTop = false;

  /// The title row (Back + DICTIONARY) has scrolled out of sight, so Back
  /// moves into the pinned bar, beside the search.
  bool _titleGone = false;
  static const _titleRowHeight = 56.0;

  @override
  void initState() {
    super.initState();
    _searchController.text = widget.initialQuery;
    _scroll.addListener(_onScroll);
  }

  void _onScroll() {
    final show = _scroll.hasClients && _scroll.offset > 800;
    if (show != _showTop) setState(() => _showTop = show);
    final gone = _scroll.hasClients && _scroll.offset > _titleRowHeight;
    if (gone != _titleGone) setState(() => _titleGone = gone);
    _updateHere();
  }

  /// Each shown result's key, to find which one is at the top.
  final Map<int, GlobalKey> _itemKeys = {};
  final _listKey = GlobalKey();

  /// The letter of the first word on screen, marked on the A–Z strip.
  String? _here;

  void _updateHere() {
    final list = _listKey.currentContext?.findRenderObject() as RenderBox?;
    if (list == null || !list.hasSize || _results.isEmpty) return;
    // Just under the pinned search bar.
    final top = list.localToGlobal(Offset.zero).dy + _topBarHeight;
    var best = -1;
    for (final MapEntry(key: i, value: key) in _itemKeys.entries) {
      final box = key.currentContext?.findRenderObject() as RenderBox?;
      if (box == null || !box.attached || i >= _results.length) continue;
      final bottom = box.localToGlobal(Offset(0, box.size.height)).dy;
      if (bottom > top && (best == -1 || i < best)) best = i;
    }
    if (best == -1) return;
    final here = _letterOf(_results[best].word);
    if (here != _here) setState(() => _here = here);
  }

  /// The strip's letter for [word]: its first letter without accents, or
  /// null for a number or symbol.
  String? _letterOf(String word) {
    if (word.isEmpty) return null;
    final first = (_language == 'el' ? greekPlain(word[0]) : word[0])
        .toUpperCase();
    final letters = _language == 'el' ? _greekLetters : _latinLetters;
    return letters.contains(first) ? first : null;
  }

  /// New results: forget the old ones' keys, and mark the new top letter
  /// once they're laid out.
  void _newResults() {
    _itemKeys.clear();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _updateHere();
    });
  }

  /// The letter the A–Z list was last started at by the strip.
  String? _letter;

  /// The A–Z strip: list the words from [letter] on, from the top.
  void _jumpToLetter(String letter) {
    if (letter == _letter) return;
    _letter = letter;
    HapticFeedback.selectionClick();
    if (_scroll.hasClients) _scroll.jumpTo(0);
    _startBrowse(letter: letter.toLowerCase());
  }

  /// Back to the first results, smoothly.
  void _goToTop() => _scroll.animateTo(
    0,
    duration: const Duration(milliseconds: 400),
    curve: Curves.easeOutCubic,
  );

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Open the dictionary of the app's language, and switch to the other
    // one if the language changes while this page is open.
    final code = AppText.of(context).code;
    if (code == _languageCode) return;
    final first = _languageCode == null;
    _languageCode = code;
    if (!first) {
      _selectedPos = null;
      _selectedStructure = null;
      _selectedSubject = null;
    }
    _initDictionary();
  }

  Future<void> _initDictionary() async {
    setState(() {
      _isLoading = true;
    });
    try {
      await _service.init();
      _filterOptions = await FilterOptions.load();
    } catch (e) {
      debugPrint('Dictionary init error: $e');
    }
    if (!mounted) return;
    setState(() {
      _isLoading = false;
    });

    _refreshResults();
  }

  @override
  void dispose() {
    _scroll.removeListener(_onScroll);
    if (widget.scrollController == null) _scroll.dispose();
    _searchController.dispose();
    _searchFocus.dispose();
    _debounce?.cancel();
    super.dispose();
  }

  void _onSearchChanged(String query) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 300), _refreshResults);
  }

  // ── A–Z list (empty search) ──
  // One card per word, alphabetically, 100 at a time: first the words that
  // start with a letter, then (after Z) the ones starting with a number or
  // symbol.
  static const _pageSize = 100;
  bool _browsing = false;
  bool _browseSymbols = false;
  bool _browseDone = false;
  bool _loadingMore = false;
  int _request = 0; // drops answers to outdated searches

  Future<List<DictionaryEntry>> _browsePage(String after, {String? from}) {
    return _service.browse(
      after: after,
      from: from,
      symbols: _browseSymbols,
      partOfSpeech: _selectedPos,
      subject: _selectedSubject,
      structure: _selectedStructure,
      limit: _pageSize,
    );
  }

  /// Next page of the A–Z list, moving on to numbers/symbols after Z.
  Future<List<DictionaryEntry>> _nextBrowsePage(String after) async {
    var page = await _browsePage(after);
    if (page.length < _pageSize && !_browseSymbols) {
      _browseSymbols = true;
      page = [...page, ...await _browsePage('')];
    }
    if (page.length < _pageSize && _browseSymbols) _browseDone = true;
    return page;
  }

  /// The A–Z list from the start, or from [letter] (the A–Z strip).
  Future<void> _startBrowse({String? letter}) async {
    final request = ++_request;
    setState(() => _isLoading = true);
    _browsing = true;
    _browseSymbols = false;
    _browseDone = false;
    _loadingMore = false;
    try {
      if (letter == null) _letter = null; // the whole list again
      final page = letter == null
          ? await _nextBrowsePage('')
          : await _browsePage('', from: letter);
      if (!mounted || request != _request) return;
      _newResults();
      setState(() {
        _results = page;
        _isSearching = true;
      });
    } catch (e) {
      debugPrint('Browse error: $e');
    }
    if (!mounted || request != _request) return;
    setState(() => _isLoading = false);
  }

  Future<void> _loadMore() async {
    if (!_browsing || _browseDone || _loadingMore || _results.isEmpty) return;
    final request = _request;
    _loadingMore = true;
    try {
      final page = await _nextBrowsePage(_results.last.word);
      if (!mounted || request != _request) return;
      setState(() => _results = [..._results, ...page]);
    } catch (e) {
      debugPrint('Browse error: $e');
    } finally {
      _loadingMore = false;
    }
  }

  Future<void> _doSearch(String query) async {
    final request = ++_request;
    _browsing = false;
    setState(() {
      _isLoading = true;
    });
    try {
      final results = await _service.search(
        query: query,
        partOfSpeech: _selectedPos,
        subject: _selectedSubject,
        structure: _selectedStructure,
      );
      if (!mounted || request != _request) return;
      _newResults();
      setState(() {
        _results = results;
        _isSearching = true;
      });
    } catch (e) {
      debugPrint('Search error: $e');
    }
    if (!mounted) return;
    setState(() {
      _isLoading = false;
    });
  }

  /// Re-run the search for the current text and filters. With no text,
  /// list the dictionary A–Z (only the words matching the filters).
  void _refreshResults() {
    final query = _searchController.text.trim();
    if (query.isNotEmpty) {
      _doSearch(query);
    } else {
      _startBrowse();
    }
  }

  // ── Build ───────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final brightness = Theme.of(context).brightness;
    final paper = brightness.resolve(
      light: AppColors.paperLight,
      dark: AppColors.paperDark,
    );
    final gridCell = brightness.resolve(
      light: AppColors.gridCellLight,
      dark: AppColors.gridCellDark,
    );
    final hairline = brightness.resolve(
      light: AppColors.hairlineLight,
      dark: AppColors.hairlineDark,
    );
    final clay = brightness.resolve(
      light: AppColors.clayLight,
      dark: AppColors.clayDark,
    );
    final ink = brightness.resolve(
      light: AppColors.inkLight,
      dark: AppColors.inkDark,
    );
    final muted = brightness.resolve(
      light: AppColors.mutedLight,
      dark: AppColors.mutedDark,
    );

    final topBar = ColoredBox(
      color: paper, // results scroll underneath it
      child: Padding(
        padding: const EdgeInsets.fromLTRB(
          Spacing.md,
          Spacing.sm,
          Spacing.md,
          Spacing.sm,
        ),
        child: Row(
          children: [
            // Back, beside the search bar once the title row (with its own
            // Back) has scrolled away.
            AnimatedSize(
              duration: const Duration(milliseconds: 180),
              curve: Curves.easeOut,
              child: !widget.inSheet && _titleGone
                  ? Padding(
                      padding: const EdgeInsets.only(right: Spacing.sm),
                      child: GestureDetector(
                        key: const Key('dictionary-back-pinned'),
                        onTap: () => Navigator.of(context).pop(),
                        child: Container(
                          width: 40,
                          height: 40,
                          decoration: BoxDecoration(
                            color: gridCell,
                            borderRadius: BorderRadius.circular(Radius.sm),
                          ),
                          child: Icon(Icons.arrow_back, size: 20, color: ink),
                        ),
                      ),
                    )
                  : const SizedBox.shrink(),
            ),
            // Search bar
            Expanded(
              child: Container(
                height: 40,
                decoration: BoxDecoration(
                  color: gridCell,
                  borderRadius: BorderRadius.circular(Radius.sm),
                  border: Border.all(color: hairline, width: 0.5),
                ),
                child: ListenableBuilder(
                  listenable: AppSettings.instance,
                  builder: (context, _) => TextField(
                    controller: _searchController,
                    focusNode: _searchFocus,
                    onChanged: _onSearchChanged,
                    onSubmitted: (_) =>
                        _doSearch(_searchController.text.trim()),
                    decoration: InputDecoration(
                      hintText: dualString(
                        context,
                        (t) => t.searchDictionaryHint,
                      ),
                      hintStyle: TextStyle(fontSize: 14, color: muted),
                      prefixIcon: Icon(Icons.search, size: 20, color: muted),
                      suffixIcon: _searchController.text.isNotEmpty
                          ? IconButton(
                              icon: Icon(Icons.clear, size: 18, color: muted),
                              onPressed: () {
                                _searchController.clear();
                                _refreshResults();
                                _searchFocus.requestFocus();
                              },
                            )
                          : null,
                      border: InputBorder.none,
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: Spacing.sm,
                      ),
                    ),
                    style: TextStyle(fontSize: 14, color: ink),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );

    // One scrolling page: the search bar stays pinned at the top while the
    // filters and results scroll together beneath it. In a sheet, dragging
    // anywhere (search bar and filters too) scrolls or resizes the sheet.
    final body = NotificationListener<ScrollNotification>(
      onNotification: (n) {
        if (n.metrics.axis == Axis.vertical && n.metrics.extentAfter < 1000) {
          _loadMore();
        }
        return false;
      },
      child: CustomScrollView(
        key: _listKey,
        controller: _scroll,
        slivers: [
          // Back and the page's title, big and bold (not in the sheet);
          // they scroll away, the search bar under them stays.
          if (!widget.inSheet)
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(
                  Spacing.md,
                  Spacing.sm,
                  Spacing.md,
                  0,
                ),
                child: Row(
                  children: [
                    GestureDetector(
                      key: const Key('dictionary-back'),
                      onTap: () => Navigator.of(context).pop(),
                      child: Container(
                        width: 40,
                        height: 40,
                        decoration: BoxDecoration(
                          color: gridCell,
                          borderRadius: BorderRadius.circular(Radius.sm),
                        ),
                        child: Icon(Icons.arrow_back, size: 20, color: ink),
                      ),
                    ),
                    const SizedBox(width: Spacing.md),
                    Expanded(
                      child: DualText(
                        (t) => AppText.upper(t.dictionary),
                        style: Theme.of(context).textTheme.displayLarge,
                        inline: true,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          SliverPersistentHeader(
            pinned: true,
            delegate: _PinnedBar(height: _topBarHeight, child: topBar),
          ),
          ..._buildContent(
            brightness: brightness,
            gridCell: gridCell,
            hairline: hairline,
            clay: clay,
            ink: ink,
            muted: muted,
            paper: paper,
          ),
          // Clear of the bottom menu (the sheet has none).
          if (!widget.inSheet)
            const SliverToBoxAdapter(child: SizedBox(height: Spacing.xxl)),
        ],
      ),
    );

    if (widget.inSheet) return body; // the sheet supplies the background
    // The A–Z strip down the right edge, while listing (not searching).
    final strip = _searchController.text.trim().isEmpty && _browsing;
    return Scaffold(
      backgroundColor: paper,
      body: SafeArea(
        child: Stack(
          children: [
            body,
            if (strip)
              Positioned(
                right: 0,
                top: _topBarHeight + 64,
                // Above the "go to top" button and the bottom menu.
                bottom: 72,
                child: _AlphabetStrip(
                  letters: _language == 'el' ? _greekLetters : _latinLetters,
                  active: _here ?? _letter,
                  onLetter: _jumpToLetter,
                ),
              ),
          ],
        ),
      ),
      // "Go to top" in the bottom-right corner, once scrolled down.
      floatingActionButton: AnimatedScale(
        scale: _showTop ? 1 : 0,
        duration: const Duration(milliseconds: 200),
        child: Tooltip(
          message: AppText.of(context).goToTop,
          child: FloatingActionButton.small(
            key: const Key('dictionary-go-to-top'),
            heroTag: null,
            onPressed: _showTop ? _goToTop : null,
            backgroundColor: brightness.resolve(
              light: AppColors.claySoftLight,
              dark: AppColors.claySoftDark,
            ),
            foregroundColor: Colors.white,
            elevation: 2,
            child: const Icon(Icons.arrow_upward),
          ),
        ),
      ),
    );
  }

  // ── Filter chips ─────────────────────────────────────────────────────────

  // ── Content area ─────────────────────────────────────────────────────────

  /// Search bar row: 40 px tall plus padding above and below.
  static const _topBarHeight = 40.0 + Spacing.sm * 2;

  /// The results (or a loading / empty message) as slivers, below the
  /// search bar in the page's single scroll view.
  List<Widget> _buildContent({
    required Brightness brightness,
    required Color gridCell,
    required Color hairline,
    required Color clay,
    required Color ink,
    required Color muted,
    required Color paper,
  }) {
    if (_isLoading && !_isSearching) {
      return _message(
        Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const CircularProgressIndicator(),
              const SizedBox(height: Spacing.md),
              DualText(
                (t) => t.loadingDictionary,
                crossAxisAlignment: CrossAxisAlignment.center,
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 14,
                  color: muted,
                  fontFamily: 'Inter',
                ),
              ),
            ],
          ),
        ),
      );
    }

    if (!_isSearching && _results.isEmpty) {
      // Empty state
      return _message(
        Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.menu_book, size: 64, color: muted),
              const SizedBox(height: Spacing.md),
              DualText(
                (t) => t.searchToBegin,
                crossAxisAlignment: CrossAxisAlignment.center,
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 16,
                  color: muted,
                  fontFamily: 'Inter',
                ),
              ),
            ],
          ),
        ),
      );
    }

    if (_isLoading && _isSearching) {
      return _message(const Center(child: CircularProgressIndicator()));
    }

    if (_results.isEmpty) {
      return _message(
        Center(
          child: DualText(
            (t) => t.noMatches,
            crossAxisAlignment: CrossAxisAlignment.center,
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 16, color: muted, fontFamily: 'Inter'),
          ),
        ),
      );
    }

    // Results list. In the A–Z list, more words load near the bottom (see
    // the scroll listener in build) and a spinner shows at the end.
    final showMore = _browsing && !_browseDone;
    return [
      SliverPadding(
        // Room on the right for the A–Z strip while listing.
        padding: EdgeInsets.fromLTRB(
          Spacing.md,
          0,
          _browsing && !widget.inSheet && _searchController.text.trim().isEmpty
              ? Spacing.md + 12
              : Spacing.md,
          0,
        ),
        sliver: SliverList.separated(
          itemCount: _results.length + (showMore ? 1 : 0),
          separatorBuilder: (_, _) => const SizedBox(height: 2),
          itemBuilder: (context, index) {
            if (index == _results.length) {
              return const Padding(
                padding: EdgeInsets.all(Spacing.lg),
                child: Center(child: CircularProgressIndicator()),
              );
            }
            final entry = _results[index];
            final card = _buildEntryCard(
              entry: entry,
              gridCell: gridCell,
              hairline: hairline,
              clay: clay,
              ink: ink,
              muted: muted,
              onTap: () {
                // Unfocus the search box itself (not just the page), so
                // closing the word page doesn't hand focus back and pop the
                // keyboard up.
                _searchFocus.unfocus();
                showWordSheet(
                  context,
                  word: entry.word,
                  highlightId: entry.id,
                  language: _language,
                );
              },
            );
            return KeyedSubtree(
              key: _itemKeys.putIfAbsent(index, GlobalKey.new),
              child: card,
            );
          },
        ),
      ),
      const SliverToBoxAdapter(child: SizedBox(height: Spacing.xl)),
    ];
  }

  /// A loading / empty message below the filters.
  List<Widget> _message(Widget child) => [
    SliverPadding(
      padding: const EdgeInsets.only(top: Spacing.xxl, bottom: Spacing.xxl),
      sliver: SliverToBoxAdapter(child: child),
    ),
  ];

  // ── Entry card ───────────────────────────────────────────────────────────

  Widget _buildEntryCard({
    required DictionaryEntry entry,
    required Color gridCell,
    required Color hairline,
    required Color clay,
    required Color ink,
    required Color muted,
    required VoidCallback onTap,
  }) {
    final labels = entryLabels(entry, _filterOptions, t: _t);

    return GestureDetector(
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(
          color: gridCell,
          borderRadius: BorderRadius.circular(Radius.sm),
          border: Border.all(color: hairline, width: 0.5),
        ),
        padding: const EdgeInsets.all(Spacing.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header: word + POS badge
            Row(
              children: [
                Flexible(
                  child: Text(
                    entry.word,
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                      color: ink,
                      fontFamily: 'Inter',
                      fontStyle: FontStyle.italic,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                const SizedBox(width: 8),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 3,
                  ),
                  decoration: BoxDecoration(
                    color: Theme.of(context).brightness.resolve(
                      light: AppColors.claySoftLight,
                      dark: AppColors.claySoftDark,
                    ),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: DualText(
                    (t) =>
                        AppText.upper(t.partOfSpeechName(entry.partOfSpeech)),
                    inline: true,
                    style: const TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w700,
                      color: Colors.white,
                      fontFamily: 'Inter',
                    ),
                    secondaryStyle: const TextStyle(
                      fontSize: 9,
                      color: Colors.white70,
                      fontFamily: 'Inter',
                    ),
                  ),
                ),
                // A–Z list: how many meanings the word has.
                if ((entry.meaningCount ?? 1) > 1) ...[
                  const SizedBox(width: 8),
                  DualText(
                    (t) => t.meanings(entry.meaningCount!),
                    inline: true,
                    style: TextStyle(
                      fontSize: 12,
                      color: muted,
                      fontFamily: 'Inter',
                    ),
                  ),
                ],
              ],
            ),
            // Subject tag and usage labels
            if (labels.subject != null || labels.usages.isNotEmpty) ...[
              const SizedBox(height: 6),
              Wrap(
                spacing: 4,
                runSpacing: 4,
                children: [
                  if (labels.subject != null) SubjectTag(labels.subject!),
                  for (final u in labels.usages) UsageTag(u, color: muted),
                ],
              ),
            ],
            // Found through another name (medical alias).
            if (entry.matchedAlias != null) ...[
              const SizedBox(height: 4),
              DualText(
                (t) => t.alsoCalledQuoted(entry.matchedAlias!),
                style: TextStyle(
                  fontSize: 12,
                  fontStyle: FontStyle.italic,
                  color: muted,
                  fontFamily: 'Inter',
                ),
              ),
            ],
            // Meaning preview; the word page has the rest.
            const SizedBox(height: 8),
            Text(
              entry.preview,
              style: TextStyle(
                fontSize: 14,
                color: ink,
                height: 1.5,
                fontFamily: 'Inter',
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// DICTIONARY SHEET — the dictionary sliding up from the bottom
// ─────────────────────────────────────────────────────────────────────────────

/// Opens the dictionary as a sheet at ~60% height. Drag the handle (or scroll
/// the results) up for full screen; drag it down to close.
Future<void> showDictionarySheet(
  BuildContext context, {
  String initialQuery = '',
}) {
  return showDraggableSheet(
    context,
    builder: (scrollController) => DictionaryPage(
      inSheet: true,
      initialQuery: initialQuery,
      scrollController: scrollController,
    ),
  );
}

/// Keeps the search bar pinned at the top of the dictionary's scroll view.
class _PinnedBar extends SliverPersistentHeaderDelegate {
  final double height;
  final Widget child;
  const _PinnedBar({required this.height, required this.child});

  @override
  double get minExtent => height;
  @override
  double get maxExtent => height;

  @override
  Widget build(BuildContext context, double shrinkOffset, bool overlaps) =>
      SizedBox.expand(child: child);

  @override
  bool shouldRebuild(_PinnedBar old) => true;
}

const _latinLetters = [
  'A', 'B', 'C', 'D', 'E', 'F', 'G', 'H', 'I', 'J', 'K', 'L', 'M', //
  'N', 'O', 'P', 'Q', 'R', 'S', 'T', 'U', 'V', 'W', 'X', 'Y', 'Z',
];
const _greekLetters = [
  'Α', 'Β', 'Γ', 'Δ', 'Ε', 'Ζ', 'Η', 'Θ', 'Ι', 'Κ', 'Λ', 'Μ', //
  'Ν', 'Ξ', 'Ο', 'Π', 'Ρ', 'Σ', 'Τ', 'Υ', 'Φ', 'Χ', 'Ψ', 'Ω',
];

/// The alphabet down the right edge of the Dictionary: tap a letter, or
/// slide a finger along it, to jump to the words starting with it. The
/// letter under the finger shows big in a bubble beside the strip.
class _AlphabetStrip extends StatefulWidget {
  final List<String> letters;
  final String? active;
  final ValueChanged<String> onLetter;

  const _AlphabetStrip({
    required this.letters,
    required this.active,
    required this.onLetter,
  });

  @override
  State<_AlphabetStrip> createState() => _AlphabetStripState();
}

class _AlphabetStripState extends State<_AlphabetStrip> {
  String? _touched; // the letter under the finger, while touching

  void _at(Offset local, double height) {
    final i = (local.dy / height * widget.letters.length).floor().clamp(
      0,
      widget.letters.length - 1,
    );
    final letter = widget.letters[i];
    if (letter != _touched) setState(() => _touched = letter);
    widget.onLetter(letter);
  }

  void _release() => setState(() => _touched = null);

  @override
  Widget build(BuildContext context) {
    final brightness = Theme.of(context).brightness;
    final muted = brightness.resolve(
      light: AppColors.mutedLight,
      dark: AppColors.mutedDark,
    );
    final soft = brightness.resolve(
      light: AppColors.claySoftLight,
      dark: AppColors.claySoftDark,
    );
    return LayoutBuilder(
      builder: (context, box) {
        final h = box.maxHeight;
        return Stack(
          clipBehavior: Clip.none,
          children: [
            GestureDetector(
              key: const Key('alphabet-strip'),
              behavior: HitTestBehavior.opaque,
              onTapDown: (d) => _at(d.localPosition, h),
              onTapUp: (_) => _release(),
              onVerticalDragStart: (d) => _at(d.localPosition, h),
              onVerticalDragUpdate: (d) => _at(d.localPosition, h),
              onVerticalDragEnd: (_) => _release(),
              onVerticalDragCancel: _release,
              child: SizedBox(
                width: 22,
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    for (final l in widget.letters)
                      if (l == (_touched ?? widget.active))
                        // Where you are: bigger, bold, in a small circle.
                        Container(
                          key: Key('alphabet-$l'),
                          width: 20,
                          height: 20,
                          alignment: Alignment.center,
                          decoration: BoxDecoration(
                            color: soft,
                            shape: BoxShape.circle,
                          ),
                          child: Text(
                            l,
                            style: const TextStyle(
                              fontFamily: 'Inter',
                              fontSize: 13,
                              height: 1,
                              fontWeight: FontWeight.w800,
                              color: Colors.white,
                            ),
                          ),
                        )
                      else
                        Text(
                          l,
                          key: Key('alphabet-$l'),
                          style: TextStyle(
                            fontFamily: 'Inter',
                            fontSize: 10,
                            height: 1,
                            fontWeight: FontWeight.w600,
                            color: muted,
                          ),
                        ),
                  ],
                ),
              ),
            ),
            // The letter under the finger, big, beside the strip.
            if (_touched case final l?)
              Positioned(
                right: 34,
                top:
                    (widget.letters.indexOf(l) + 0.5) /
                        widget.letters.length *
                        h -
                    28,
                child: IgnorePointer(
                  child: Container(
                    width: 56,
                    height: 56,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: soft,
                      shape: BoxShape.circle,
                    ),
                    child: Text(
                      l,
                      style: Theme.of(context).textTheme.displaySmall!
                          .copyWith(color: Colors.white),
                    ),
                  ),
                ),
              ),
          ],
        );
      },
    );
  }
}
