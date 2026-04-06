import 'package:flutter/material.dart';
import '../l10n/app_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';

import '../data/pack_manager.dart';
import '../providers.dart';

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
  };

  void _showLocalePicker(BuildContext context) {
    // Resolve what "System default" would actually give the user.
    final systemLang =
        WidgetsBinding.instance.platformDispatcher.locale.languageCode;
    final systemEndonym = _endonyms[systemLang] ?? _endonyms['en']!;

    showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.brown.shade800,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (_) {
        // Consumer so the checkmark stays reactive (#1 fix).
        return Consumer(builder: (ctx, ref, _) {
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
                  child: Icon(Icons.language, color: Colors.white70, size: 32),
                ),
                // System default — show resolved endonym as subtitle so
                // it's understandable regardless of current UI language.
                _LocaleOption(
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
                  _LocaleOption(
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
        });
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
      await ref.read(localPacksProvider.notifier).download(lang);
    } catch (e) {
      if (mounted) {
        _showError(
          AppLocalizations.of(context)!.downloadFailed(e.toString()),
          onRetry: () => _download(lang),
        );
      }
    }
  }

  Future<void> _delete(String lang) async {
    await ref.read(localPacksProvider.notifier).delete(lang);
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

    return Scaffold(
      backgroundColor: Colors.brown.shade900,
      appBar: AppBar(
        backgroundColor: Colors.brown.shade900,
        foregroundColor: Colors.white70,
        title: Text(AppLocalizations.of(context)!.packManagerTitle),
        actions: [
          IconButton(
            icon: const Icon(Icons.language),
            tooltip: AppLocalizations.of(context)!.appLanguage,
            onPressed: () => _showLocalePicker(context),
          ),
        ],
      ),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Text(
              AppLocalizations.of(context)!.packManagerSubtitle,
              style: TextStyle(color: Colors.white54, fontSize: 14),
            ),
          ),
          const SizedBox(height: 20),

          // Pack list
          Expanded(
            child: manifest.when(
              loading: () => const Center(
                  child: CircularProgressIndicator(color: Colors.white54)),
              error: (_, __) => const SizedBox.shrink(),
              data: (m) => ListView.builder(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                itemCount: m.packs.length,
                itemBuilder: (context, i) {
                  final pack = m.packs[i];
                  final progress =
                      ref.watch(downloadProgressProvider(pack.lang));
                  return _PackTile(
                    pack: pack,
                    local: local[pack.lang],
                    progress: progress,
                    onDownload: () => _download(pack.lang),
                    onDelete: () => _delete(pack.lang),
                    onSelect: () => _select(pack.lang),
                  );
                },
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _PackTile extends StatelessWidget {
  final PackInfo pack;
  final LocalPack? local;
  final double? progress;
  final VoidCallback onDownload;
  final VoidCallback onDelete;
  final VoidCallback onSelect;

  const _PackTile({
    required this.pack,
    required this.local,
    required this.progress,
    required this.onDownload,
    required this.onDelete,
    required this.onSelect,
  });

  bool get _isDownloaded => local != null;
  bool get _isDownloading => progress != null;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.brown.shade800.withValues(alpha: 0.7),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: _isDownloaded
              ? Colors.green.shade700.withValues(alpha: 0.5)
              : Colors.brown.shade600.withValues(alpha: 0.4),
          width: 2,
        ),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(14),
          onTap: _isDownloaded ? onSelect : null,
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                Row(
                  children: [
                    Container(
                      width: 44,
                      height: 44,
                      decoration: BoxDecoration(
                        color: Colors.brown.shade700,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      alignment: Alignment.center,
                      child: Text(
                        pack.lang.toUpperCase(),
                        style: GoogleFonts.pixelifySans(
                          color: Colors.white70,
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            pack.name,
                            style: GoogleFonts.pixelifySans(
                              color: Colors.white,
                              fontSize: 20,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          if (_isDownloaded)
                            Text(
                              AppLocalizations.of(context)!.sizeMB(
                                (local!.sizeBytes / 1024 / 1024)
                                    .toStringAsFixed(1),
                              ),
                              style: const TextStyle(
                                  color: Colors.white38, fontSize: 12),
                            ),
                        ],
                      ),
                    ),
                    _buildAction(),
                  ],
                ),
                if (_isDownloading) ...[
                  const SizedBox(height: 10),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(4),
                    child: LinearProgressIndicator(
                      value: progress,
                      backgroundColor: Colors.brown.shade700,
                      valueColor: AlwaysStoppedAnimation(Colors.green.shade400),
                      minHeight: 6,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildAction() {
    if (_isDownloading) {
      return const SizedBox(
        width: 24,
        height: 24,
        child: CircularProgressIndicator(
            strokeWidth: 2, color: Colors.white54),
      );
    }
    if (_isDownloaded) {
      return Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.check_circle, color: Colors.green, size: 22),
          const SizedBox(width: 8),
          IconButton(
            icon: Icon(Icons.delete_outline,
                color: Colors.white.withValues(alpha: 0.4), size: 20),
            onPressed: onDelete,
          ),
        ],
      );
    }
    return IconButton(
      icon: const Icon(Icons.download_rounded,
          color: Colors.white70, size: 28),
      onPressed: onDownload,
    );
  }
}

class _LocaleOption extends StatelessWidget {
  final String label;
  final String? subtitle;
  final bool selected;
  final VoidCallback onTap;

  const _LocaleOption({
    required this.label,
    this.subtitle,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return ListTile(
      title: Text(
        label,
        style: TextStyle(
          color: selected ? Colors.white : Colors.white70,
          fontWeight: selected ? FontWeight.bold : FontWeight.normal,
        ),
      ),
      subtitle: subtitle != null
          ? Text(subtitle!, style: const TextStyle(color: Colors.white38))
          : null,
      trailing: selected
          ? const Icon(Icons.check, color: Colors.green, size: 20)
          : null,
      onTap: onTap,
    );
  }
}
