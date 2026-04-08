import 'package:flutter/material.dart';
import '../l10n/app_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../data/hive_keys.dart';
import '../providers.dart';
import '../theme/app_colors.dart';
import '../widgets/locale_option.dart';
import '../widgets/pack_tile.dart';
import '../widgets/tiled_background.dart';

class PackManagerScreen extends ConsumerStatefulWidget {
  const PackManagerScreen({super.key});

  @override
  ConsumerState<PackManagerScreen> createState() => _PackManagerScreenState();
}

class _PackManagerScreenState extends ConsumerState<PackManagerScreen> {
  /// Endonyms — language names in their own language. Always display these
  /// regardless of the current UI locale.
  static const _endonyms = {'en': 'English', 'es': 'Español'};

  void _showLocalePicker(BuildContext context) {
    // Resolve what "System default" would actually give the user.
    final systemLang =
        WidgetsBinding.instance.platformDispatcher.locale.languageCode;
    final systemEndonym = _endonyms[systemLang] ?? _endonyms['en']!;

    showModalBottomSheet<void>(
      context: context,
      backgroundColor: AppColors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (_) {
        // Consumer so the checkmark stays reactive (#1 fix).
        return Consumer(
          builder: (ctx, ref, _) {
            final current = ref.watch(localeProvider);
            final l10n = AppLocalizations.of(context)!;
            return SafeArea(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Globe icon instead of localized text — universally
                  // recognizable even if the user is stuck in the wrong
                  // language (#5 fix).
                  const Padding(
                    padding: EdgeInsets.fromLTRB(20, 16, 20, 4),
                    child: Icon(
                      Icons.language,
                      color: AppColors.textSecondary,
                      size: 32,
                    ),
                  ),
                  // System default — show resolved endonym as subtitle so
                  // it's understandable regardless of current UI language.
                  LocaleOption(
                    label: l10n.systemDefault,
                    subtitle: systemEndonym,
                    selected: current == null,
                    onTap: () {
                      ref.read(localeProvider.notifier).setLocale(null);
                      Navigator.pop(ctx);
                    },
                  ),
                  // Each supported locale
                  for (final locale in AppLocalizations.supportedLocales)
                    LocaleOption(
                      label:
                          _endonyms[locale.languageCode] ?? locale.languageCode,
                      selected: current?.languageCode == locale.languageCode,
                      onTap: () {
                        ref.read(localeProvider.notifier).setLocale(locale);
                        Navigator.pop(ctx);
                      },
                    ),
                  const SizedBox(height: 8),
                ],
              ),
            );
          },
        );
      },
    );
  }

  void _showError(String message, {VoidCallback? onRetry}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        duration: const Duration(seconds: 10),
        action: onRetry != null
            ? SnackBarAction(
                label: AppLocalizations.of(context)!.retry,
                onPressed: onRetry,
              )
            : null,
      ),
    );
  }

  Future<void> _download(String lang) async {
    try {
      await ref
          .read(localPacksProvider.notifier)
          .download(lang, includeVoice: false);
    } catch (e) {
      if (mounted) {
        _showError(
          AppLocalizations.of(context)!.downloadFailed(e.toString()),
          onRetry: () => _download(lang),
        );
      }
    }
  }

  Future<void> _downloadVoice(String lang) async {
    try {
      await ref.read(localPacksProvider.notifier).downloadVoice(lang);
    } catch (e) {
      if (mounted) {
        _showError(
          AppLocalizations.of(context)!.downloadFailed(e.toString()),
          onRetry: () => _downloadVoice(lang),
        );
      }
    }
  }

  Future<void> _delete(String lang) async {
    await ref.read(localPacksProvider.notifier).delete(lang);
  }

  Future<void> _deleteVoice(String lang) async {
    ref.read(ttsServiceProvider).releaseEngine();
    await ref.read(ttsManagerProvider).deleteModel(lang);
    // Invalidate so the UI picks up the removed voice state.
    ref.invalidate(localPacksProvider);
  }

  Future<void> _select(String lang) async {
    await ref.read(activePackProvider.notifier).switchPack(lang);
    if (mounted) context.go('/game');
  }

  @override
  void initState() {
    super.initState();
    ref.listenManual(manifestProvider, (_, next) {
      if (next.hasError && mounted) {
        _showError(
          '${next.error}',
          onRetry: () => ref.invalidate(manifestProvider),
        );
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final manifest = ref.watch(manifestProvider);
    final localPacks = ref.watch(localPacksProvider);
    final local = localPacks.valueOrNull ?? {};

    // Watch the state so we rebuild when it changes; read the notifier for the lang.
    final hasActiveQuestions = ref.watch(activePackProvider).valueOrNull?.isNotEmpty ?? false;
    final activeLang = ref.read(activePackProvider.notifier).activeLang;
    final canGoBack = hasActiveQuestions && activeLang != null && local.containsKey(activeLang);

    return Scaffold(
      backgroundColor: AppColors.scaffold,
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        foregroundColor: AppColors.textSecondary,
        automaticallyImplyLeading: canGoBack,
        title: Text(AppLocalizations.of(context)!.packManagerTitle),
        actions: [
          IconButton(
            icon: const Icon(Icons.language),
            tooltip: AppLocalizations.of(context)!.appLanguage,
            onPressed: () => _showLocalePicker(context),
          ),
        ],
      ),
      body: Stack(
        children: [
          Opacity(
            opacity: 0.15,
            child: TiledBackground(
              texture: BackgroundTexture.chevron,
              color: AppColors.surfaceBright,
              scale: 8,
              scrollDirection: const Offset(-1, 1),
              scrollSpeed: 12,
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SizedBox(
                height: MediaQuery.of(context).padding.top + kToolbarHeight,
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Text(
                  AppLocalizations.of(context)!.packManagerSubtitle,
                  style:
                      TextStyle(color: AppColors.textSecondary, fontSize: 14),
                ),
              ),
              const SizedBox(height: 20),

              // Pack list
              Expanded(
                child: manifest.when(
                  loading: () => const Center(
                    child: CircularProgressIndicator(
                        color: AppColors.textTertiary),
                  ),
                  error: (_, __) => const SizedBox.shrink(),
                  data: (m) => ListView.builder(
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    itemCount: m.packs.length,
                    itemBuilder: (context, i) {
                      final pack = m.packs[i];
                      final box = ref.read(hiveBoxProvider);
                      return PackTile(
                        pack: pack,
                        local: local[pack.lang],
                        packProgress: ref.watch(
                          downloadProgressProvider(pack.lang),
                        ),
                        voiceProgress: ref.watch(
                          voiceDownloadProgressProvider(pack.lang),
                        ),
                        voiceDownloaded: ref.watch(ttsManagerProvider)
                            .isModelDownloaded(pack.lang),
                        hasCharacter:
                            box.get(HiveKeys.character(pack.lang)) != null,
                        onDownload: () => _download(pack.lang),
                        onDownloadVoice: () => _downloadVoice(pack.lang),
                        onDelete: () => _delete(pack.lang),
                        onDeleteVoice: () => _deleteVoice(pack.lang),
                        onSelect: () => _select(pack.lang),
                      );
                    },
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
