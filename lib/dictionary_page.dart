// ─────────────────────────────────────────────────────────────────────────────
// DICTIONARY PAGE — search, filter, and browse words
// ─────────────────────────────────────────────────────────────────────────────

import 'dart:async';

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

  // Which label list is open under the filters, and which subject groups
  // are expanded inside it.
  bool _subjectListOpen = false;
  final Set<String> _expandedGroups = {};

  String? _selectedStructure; // simple / compound / derived, or null = all

  /// The app's text in the current language.
  AppText get _t => AppText.of(context);

  /// The dictionary of the app's language (English or Greek).
  DictionaryService get _service => DictionaryService.forLanguage(_language);
  String? _languageCode;
  String get _language => _languageCode ?? 'en';

  /// Greek has no word-structure labels; its parts of speech are the 10 of
  /// Greek grammar (articles and participles are Greek only).
  static const _greekPartsOfSpeech = [
    'noun',
    'verb',
    'adj',
    'adv',
    'pron',
    'art',
    'part',
    'prep',
    'conj',
    'interj',
  ];
  bool get _greek => _language == 'el';

  // Filter options
  FilterOptions? _filterOptions;

  @override
  void initState() {
    super.initState();
    _searchController.text = widget.initialQuery;
  }

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

  Future<List<DictionaryEntry>> _browsePage(String after) {
    return _service.browse(
      after: after,
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

  Future<void> _startBrowse() async {
    final request = ++_request;
    setState(() => _isLoading = true);
    _browsing = true;
    _browseSymbols = false;
    _browseDone = false;
    _loadingMore = false;
    try {
      final page = await _nextBrowsePage('');
      if (!mounted || request != _request) return;
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
            if (!widget.inSheet) ...[
              // Back button
              GestureDetector(
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
              const SizedBox(width: Spacing.sm),
            ],
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
            if (!widget.inSheet) ...[
              const SizedBox(width: Spacing.sm),
              const HomeButton(),
            ],
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
        controller: widget.scrollController,
        slivers: [
          SliverPersistentHeader(
            pinned: true,
            delegate: _PinnedBar(height: _topBarHeight, child: topBar),
          ),
          if (_filterOptions != null)
            SliverToBoxAdapter(
              child: _buildFilterChips(
                options: _filterOptions!,
                selectedPos: _selectedPos,
                gridCell: gridCell,
                hairline: hairline,
                clay: clay,
                ink: ink,
                muted: muted,
                onPosChanged: (pos) {
                  setState(() {
                    _selectedPos = pos;
                  });
                  _refreshResults();
                },
              ),
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
        ],
      ),
    );

    if (widget.inSheet) return body; // the sheet supplies the background
    return Scaffold(
      backgroundColor: paper,
      body: SafeArea(child: body),
    );
  }

  // ── Filter chips ─────────────────────────────────────────────────────────

  Widget _buildFilterChips({
    required FilterOptions options,
    required String? selectedPos,
    required Color gridCell,
    required Color hairline,
    required Color clay,
    required Color ink,
    required Color muted,
    required ValueChanged<String?> onPosChanged,
  }) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(Spacing.md, 0, Spacing.md, Spacing.sm),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Part of speech filters
          DualText(
            (t) => t.partOfSpeech,
            inline: true,
            style: kickerStyle(brightness: Theme.of(context).brightness)
                .copyWith(color: clay),
          ),
          const SizedBox(height: 6),
          Wrap(
            spacing: 6,
            runSpacing: 4,
            children: [
              _filterChip(
                label: (t) => t.all,
                active: selectedPos == null,
                clay: clay,
                gridCell: gridCell,
                hairline: hairline,
                ink: ink,
                muted: muted,
                onTap: () => onPosChanged(null),
              ),
              ...(_greek ? _greekPartsOfSpeech : options.partOfSpeech).map((
                pos,
              ) {
                return _filterChip(
                  label: (t) => t.partOfSpeechName(pos),
                  active: selectedPos == pos,
                  clay: clay,
                  gridCell: gridCell,
                  hairline: hairline,
                  ink: ink,
                  muted: muted,
                  onTap: () => onPosChanged(pos),
                );
              }),
            ],
          ),
          const SizedBox(height: 8),
          // Structure (from "types of words": simple / compound / derived)
          if (options.structures.isNotEmpty && !_greek) ...[
            DualText(
              (t) => t.structure,
              inline: true,
              style: kickerStyle(brightness: Theme.of(context).brightness)
                  .copyWith(color: clay),
            ),
            const SizedBox(height: 6),
            Wrap(
              spacing: 6,
              runSpacing: 4,
              children: [
                _filterChip(
                  label: (t) => t.all,
                  active: _selectedStructure == null,
                  clay: clay,
                  gridCell: gridCell,
                  hairline: hairline,
                  ink: ink,
                  muted: muted,
                  onTap: () => _pickStructure(null),
                ),
                for (final st in options.structures)
                  _filterChip(
                    label: (t) => st.name(t.code),
                    active: _selectedStructure == st.id,
                    clay: clay,
                    gridCell: gridCell,
                    hairline: hairline,
                    ink: ink,
                    muted: muted,
                    onTap: () => _pickStructure(st.id),
                  ),
              ],
            ),
            const SizedBox(height: 8),
          ],
          // Subject selector (opens the grouped list below)
          _labelSelector(
            title: (t) => t.subject,
            value: (t) => _subjectName(options, t),
            active: _selectedSubject != null,
            open: _subjectListOpen,
            onTap: _toggleSubjectList,
            gridCell: gridCell,
            hairline: hairline,
            clay: clay,
            ink: ink,
            muted: muted,
          ),
          if (_subjectListOpen) ...[
            const SizedBox(height: Spacing.sm),
            _buildLabelPanel(
              options: options,
              gridCell: gridCell,
              hairline: hairline,
              clay: clay,
              ink: ink,
              muted: muted,
            ),
          ],
        ],
      ),
    );
  }

  // ── Subject list ────────────────────────────────────────────────────────

  String _subjectName(FilterOptions options, AppText t) {
    final id = _selectedSubject;
    if (id == null) return t.allSubjects;
    if (id == DictionaryService.generalSubject) return t.general;
    return options.subjectsById[id]?.name(t.code) ?? id;
  }

  void _toggleSubjectList() {
    FocusScope.of(context).unfocus();
    setState(() => _subjectListOpen = !_subjectListOpen);
  }

  void _pickStructure(String? id) {
    setState(() => _selectedStructure = id);
    _refreshResults();
  }

  void _pickSubject(String? id) {
    setState(() {
      _selectedSubject = id;
      _subjectListOpen = false;
    });
    _refreshResults();
  }

  /// "SUBJECT  [ Law / Legal  ▾ ]" — shows the current choice; tap to open.
  Widget _labelSelector({
    required TextPick title,
    required TextPick value,
    required bool active,
    required bool open,
    required VoidCallback onTap,
    required Color gridCell,
    required Color hairline,
    required Color clay,
    required Color ink,
    required Color muted,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        DualText(
          title,
          inline: true,
          style: kickerStyle(brightness: Theme.of(context).brightness)
              .copyWith(color: clay),
        ),
        const SizedBox(height: 6),
        GestureDetector(
          onTap: onTap,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: active ? clay : gridCell,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: active || open ? clay : hairline,
                width: active || open ? 1.5 : 0.5,
              ),
            ),
            child: Row(
              children: [
                Expanded(
                  child: DualText(
                    value,
                    inline: true,
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: active ? FontWeight.w700 : FontWeight.w500,
                      color: active ? Colors.white : muted,
                      fontFamily: 'Inter',
                    ),
                    secondaryStyle: TextStyle(
                      fontSize: 10,
                      color: active
                          ? Colors.white.withValues(alpha: 0.75)
                          : translationColor(context),
                      fontFamily: 'Inter',
                    ),
                  ),
                ),
                Icon(
                  open ? Icons.keyboard_arrow_up : Icons.keyboard_arrow_down,
                  size: 18,
                  color: active ? Colors.white : muted,
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  /// The open list: subject groups as expandable titles with their subjects
  /// underneath.
  Widget _buildLabelPanel({
    required FilterOptions options,
    required Color gridCell,
    required Color hairline,
    required Color clay,
    required Color ink,
    required Color muted,
  }) {
    Widget row({
      required TextPick label,
      required bool selected,
      required VoidCallback onTap,
      int? count,
      double indent = 0,
    }) {
      return InkWell(
        onTap: onTap,
        child: Padding(
          padding: EdgeInsets.fromLTRB(12 + indent, 10, 12, 10),
          child: Row(
            children: [
              Expanded(
                child: DualText(
                  label,
                  inline: true,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: selected ? FontWeight.w700 : FontWeight.w400,
                    color: selected ? clay : ink,
                    fontFamily: 'Inter',
                  ),
                ),
              ),
              if (count != null)
                Text(
                  '$count',
                  style: TextStyle(
                    fontSize: 12,
                    color: muted,
                    fontFamily: 'Inter',
                  ),
                ),
              if (selected) ...[
                const SizedBox(width: 6),
                Icon(Icons.check, size: 16, color: clay),
              ],
            ],
          ),
        ),
      );
    }

    final children = <Widget>[];
    children
      ..add(
        row(
          label: (t) => t.allSubjects,
          selected: _selectedSubject == null,
          onTap: () => _pickSubject(null),
        ),
      )
      ..add(
        row(
          label: (t) => t.generalNoSubject,
          selected: _selectedSubject == DictionaryService.generalSubject,
          onTap: () => _pickSubject(DictionaryService.generalSubject),
        ),
      );
    for (final group in options.subjectGroups) {
      final expanded =
          _expandedGroups.contains(group.label.id) ||
          group.subjects.any((s) => s.id == _selectedSubject);
      children.add(
        InkWell(
          onTap: () => setState(() {
            if (!_expandedGroups.remove(group.label.id)) {
              _expandedGroups.add(group.label.id);
            }
          }),
          child: Container(
            decoration: BoxDecoration(
              border: Border(top: BorderSide(color: hairline, width: 0.5)),
            ),
            padding: const EdgeInsets.fromLTRB(12, 12, 8, 12),
            child: Row(
              children: [
                Expanded(
                  child: DualText(
                    (t) => group.label.name(t.code),
                    inline: true,
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                      color: ink,
                      fontFamily: 'Inter',
                    ),
                  ),
                ),
                Icon(
                  expanded
                      ? Icons.keyboard_arrow_up
                      : Icons.keyboard_arrow_down,
                  size: 20,
                  color: muted,
                ),
              ],
            ),
          ),
        ),
      );
      if (expanded) {
        for (final subject in group.subjects) {
          children.add(
            row(
              label: (t) => subject.name(t.code),
              count: subject.count,
              indent: Spacing.md,
              selected: _selectedSubject == subject.id,
              onTap: () => _pickSubject(subject.id),
            ),
          );
        }
      }
    }

    return Container(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.sizeOf(context).height * 0.4,
      ),
      decoration: BoxDecoration(
        color: gridCell,
        borderRadius: BorderRadius.circular(Radius.sm),
        border: Border.all(color: hairline, width: 0.5),
      ),
      child: Material(
        type: MaterialType.transparency,
        child: ListView(
          padding: EdgeInsets.zero,
          shrinkWrap: true,
          children: children,
        ),
      ),
    );
  }

  Widget _filterChip({
    required TextPick label,
    required bool active,
    required Color clay,
    required Color gridCell,
    required Color hairline,
    required Color ink,
    required Color muted,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: active ? clay : gridCell,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: active ? clay : hairline,
            width: active ? 1.5 : 0.5,
          ),
        ),
        child: DualText(
          label,
          inline: true,
          style: TextStyle(
            fontSize: 12,
            fontWeight: active ? FontWeight.w700 : FontWeight.w500,
            color: active ? Colors.white : muted,
            fontFamily: 'Inter',
          ),
          secondaryStyle: TextStyle(
            fontSize: 10,
            color: active
                ? Colors.white.withValues(alpha: 0.75)
                : translationColor(context),
            fontFamily: 'Inter',
          ),
        ),
      ),
    );
  }

  // ── Content area ─────────────────────────────────────────────────────────

  /// Search bar row: 40 px tall plus padding above and below.
  static const _topBarHeight = 40.0 + Spacing.sm * 2;

  /// The results (or a loading / empty message) as slivers, below the
  /// filters in the page's single scroll view.
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
        padding: const EdgeInsets.symmetric(horizontal: Spacing.md),
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
            return _buildEntryCard(
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
                    color: clay,
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
