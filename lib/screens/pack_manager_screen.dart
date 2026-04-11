import 'package:flutter/material.dart';
import '../l10n/app_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../data/pack_manager.dart';
import '../data/tts_manager.dart';
import '../providers.dart';
import '../theme/app_colors.dart';
import '../theme/app_spacing.dart';
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
  static const _endonyms = {
    'en': 'English',
    'es': 'Español',
    'fr': 'Français',
    'de': 'Deutsch',
    'it': 'Italiano',
    'pt': 'Português',
  };

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
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Globe icon instead of localized text — universally
                    // recognizable even if the user is stuck in the wrong
                    // language (#5 fix).
                    const Padding(
                      padding: EdgeInsets.fromLTRB(AppSpacing.lg, AppSpacing.md, AppSpacing.lg, AppSpacing.xs),
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
                    const SizedBox(height: AppSpacing.sm),
                  ],
                ),
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

  Future<void> _download(PackInfo pack) async {
    try {
      await ref
          .read(localPacksProvider.notifier)
          .download(pack.lang, fromLang: pack.fromLang, includeVoice: false);
    } catch (e) {
      if (mounted) {
        _showError(
          AppLocalizations.of(context)!.downloadFailed(e.toString()),
          onRetry: () => _download(pack),
        );
      }
    }
  }

  Future<void> _downloadVoice(String lang, String modelId) async {
    try {
      await ref.read(localPacksProvider.notifier).downloadVoice(lang, modelId: modelId);
    } catch (e) {
      if (mounted) {
        _showError(
          AppLocalizations.of(context)!.downloadFailed(e.toString()),
          onRetry: () => _downloadVoice(lang, modelId),
        );
      }
    }
  }

  Future<void> _delete(String packId) async {
    await ref.read(localPacksProvider.notifier).delete(packId);
  }

  Future<void> _deleteVoice(String lang) async {
    ref.read(ttsServiceProvider).releaseEngine();
    await ref.read(ttsManagerProvider).deleteModel(lang);
    // Invalidate so the UI picks up the removed voice state.
    ref.invalidate(localPacksProvider);
  }

  Future<void> _select(String packId) async {
    await ref.read(activePackProvider.notifier).switchPack(packId);
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
    final nativeLang = ref.watch(nativeLangProvider);

    // Watch the state so we rebuild when it changes; read the notifier for the packId.
    final hasActiveQuestions = ref.watch(activePackProvider).valueOrNull?.hasQuestions ?? false;
    final activePackId = ref.read(activePackProvider.notifier).activePackId;
    final canGoBack = hasActiveQuestions && activePackId != null && local.containsKey(activePackId);

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
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              SizedBox(
                height: MediaQuery.of(context).padding.top + kToolbarHeight,
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
                child: Text(
                  AppLocalizations.of(context)!.packManagerSubtitle,
                  textAlign: TextAlign.center,
                  style:
                      TextStyle(color: AppColors.textSecondary, fontSize: 14),
                ),
              ),
              const SizedBox(height: AppSpacing.md),

              // Pack list
              Expanded(
                child: manifest.when(
                  loading: () => const Center(
                    child: CircularProgressIndicator(
                        color: AppColors.textTertiary),
                  ),
                  error: (_, __) => const SizedBox.shrink(),
                  data: (m) {
                    final packs = m.packsFor(nativeLang);
                    return ListView.builder(
                      padding: const EdgeInsets.fromLTRB(AppSpacing.lg, 0, AppSpacing.lg, AppSpacing.xxxl),
                      itemCount: packs.length + 1,
                      itemBuilder: (context, i) {
                        if (i == 0) {
                          return FractionallySizedBox(
                            widthFactor: 0.5,
                            child: Container(
                              margin: const EdgeInsets.only(bottom: AppSpacing.md),
                              padding: const EdgeInsets.fromLTRB(AppSpacing.sm, AppSpacing.md, AppSpacing.sm, AppSpacing.md),
                              decoration: const BoxDecoration(
                                image: DecorationImage(
                                  image: AssetImage(
                                    'assets/images/ui/panel_metal_bg.png',
                                  ),
                                  centerSlice: Rect.fromLTRB(12, 12, 84, 84),
                                  filterQuality: FilterQuality.none,
                                ),
                              ),
                              child: Text(
                                AppLocalizations.of(context)!.communityContent,
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                  color: AppColors.textTertiary,
                                  fontSize: 12,
                                ),
                              ),
                            ),
                          );
                        }
                        final pack = packs[i - 1];
                        final status = packUpdateStatus(pack, local[pack.packId]);
                        final ttsManager = ref.watch(ttsManagerProvider);
                        return PackTile(
                          pack: pack,
                          local: local[pack.packId],
                          packStatus: status,
                          packProgress: ref.watch(
                            downloadProgressProvider(pack.packId),
                          ),
                          voiceProgress: ref.watch(
                            voiceDownloadProgressProvider(pack.lang),
                          ),
                          voiceModels: ttsModelRegistry[pack.lang] ?? const [],
                          downloadedModelId: ttsManager.downloadedModelId(pack.lang),
                          hasCharacter:
                              ref.watch(characterProvider(pack.lang)) != null,
                          onDownload: () => _download(pack),
                          onUpdate: () => _download(pack),
                          onDownloadVoice: (modelId) => _downloadVoice(pack.lang, modelId),
                          onDelete: () => _delete(pack.packId),
                          onDeleteVoice: () => _deleteVoice(pack.lang),
                          onSelect: () => _select(pack.packId),
                        );
                      },
                    );
                  },
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
