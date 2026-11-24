// ─────────────────────────────────────────────────────────────────────────────
// DATABASE GATE — on first launch, before the home page, downloads the
// dictionary's databases (database_download.dart) with progress, and a
// "Try again" when there's no internet. Once they're on the phone it shows
// [child] straight away.
// ─────────────────────────────────────────────────────────────────────────────

import 'package:material_ui/material_ui.dart';

import 'app_text.dart';
import 'database_download.dart';
import 'design_system.dart';
import 'dictionary_service.dart';
import 'dual_text.dart';

class DatabaseGate extends StatefulWidget {
  final Widget child;

  const DatabaseGate({super.key, required this.child});

  @override
  State<DatabaseGate> createState() => _DatabaseGateState();
}

class _DatabaseGateState extends State<DatabaseGate> {
  DatabaseDownload get _download => DictionaryService.databases;
  int? _sizeMb;

  @override
  void initState() {
    super.initState();
    _start();
    _download.manifest.then(
      (m) => mounted ? setState(() => _sizeMb = m.sizeMb) : null,
      onError: (Object _) => null,
    );
  }

  void _start() => _download.ensure().ignore();

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: _download.changes,
      builder: (context, _) {
        final state = _download.state;
        if (state == DatabaseState.ready) return widget.child;
        final brightness = Theme.of(context).brightness;
        final paper = brightness.resolve(
          light: AppColors.paperLight,
          dark: AppColors.paperDark,
        );
        final muted = brightness.resolve(
          light: AppColors.mutedLight,
          dark: AppColors.mutedDark,
        );
        final clay = brightness.resolve(
          light: AppColors.clayLight,
          dark: AppColors.clayDark,
        );
        final body = Theme.of(context).textTheme.bodyLarge!;
        return Scaffold(
          key: const Key('database-gate'),
          backgroundColor: paper,
          body: SafeArea(
            // Checking only takes a moment: show nothing, not a flash.
            child: state == DatabaseState.checking
                ? const SizedBox.expand()
                : Padding(
                    padding: const EdgeInsets.all(Spacing.lg),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Lex Hopper',
                          style: Theme.of(context).textTheme.displayMedium,
                        ),
                        const SizedBox(height: Spacing.lg),
                        DualText(
                          (t) => t.gettingDictionary,
                          style: Theme.of(context).textTheme.displaySmall,
                        ),
                        const SizedBox(height: Spacing.sm),
                        if (_sizeMb case final mb?)
                          DualText(
                            (t) => t.dictionaryDownloadNote(mb),
                            style: body.copyWith(color: muted),
                          ),
                        const SizedBox(height: Spacing.lg),
                        if (state == DatabaseState.downloading) ...[
                          LinearProgressIndicator(
                            key: const Key('database-progress'),
                            value: _download.progress,
                            color: clay,
                            backgroundColor: Theme.of(context).brightness
                                .resolve(
                                  light: AppColors.hairlineLight,
                                  dark: AppColors.hairlineDark,
                                ),
                          ),
                          const SizedBox(height: Spacing.sm),
                          DualText(
                            (t) => t.dictionaryDownloading(
                              (_download.progress * 100).floor(),
                            ),
                            style: body.copyWith(color: muted),
                          ),
                        ],
                        if (state == DatabaseState.failed) ...[
                          DualText(
                            (t) => t.dictionaryDownloadFailed,
                            style: body,
                          ),
                          const SizedBox(height: Spacing.md),
                          FilledButton(
                            key: const Key('database-retry'),
                            onPressed: _start,
                            child: Text(AppText.of(context).tryAgain),
                          ),
                        ],
                      ],
                    ),
                  ),
          ),
        );
      },
    );
  }
}
