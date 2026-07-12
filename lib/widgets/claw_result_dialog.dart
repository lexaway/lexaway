import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';

import '../data/collectibles/collectible.dart';
import '../data/collectibles/registry.dart';
import '../game/audio_manager.dart';
import '../game/claw_machine/prize_sphere.dart';
import '../l10n/app_localizations.dart';
import '../theme/app_colors.dart';

/// Result splash shown over the zoomed-in cabinet after the session
/// resolves. Continue tap zooms the camera back out.
class ClawResultDialog extends StatelessWidget {
  final bool won;
  final Collectible? prize;
  final bool isNewPrize;
  final int tryAgainCost;
  final bool canAffordTryAgain;
  final VoidCallback onContinue;
  final VoidCallback onTryAgain;

  const ClawResultDialog({
    super.key,
    required this.won,
    required this.prize,
    required this.isNewPrize,
    required this.tryAgainCost,
    required this.canAffordTryAgain,
    required this.onContinue,
    required this.onTryAgain,
  });

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return Material(
      color: Colors.black.withValues(alpha: 0.45),
      child: Center(
        child: Container(
          margin: const EdgeInsets.all(24),
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: ClawColors.panel,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: ClawColors.frame, width: 3),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.25),
                blurRadius: 12,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (won && prize != null) ...[
                _PrizePreview(collectible: prize!),
                const SizedBox(height: 12),
                Text(
                  prize!.displayName,
                  style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w700,
                    color: ClawColors.text,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  isNewPrize ? l10n.clawPrizeNew : l10n.clawPrizeOwned,
                  style: TextStyle(
                    fontSize: 14,
                    color:
                        isNewPrize ? ClawColors.frame : ClawColors.textOwned,
                  ),
                ),
              ] else ...[
                // Every claw sphere carries a flag, so a win always has a
                // prize and lands in the branch above — this branch is the
                // loss case.
                Text(
                  l10n.clawLost,
                  style: const TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.w700,
                    color: ClawColors.frame,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  l10n.clawLostDetail,
                  style: const TextStyle(
                    fontSize: 16,
                    color: ClawColors.text,
                  ),
                ),
              ],
              const SizedBox(height: 20),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  OutlinedButton(
                    onPressed: onContinue,
                    style: OutlinedButton.styleFrom(
                      foregroundColor: ClawColors.frame,
                      side: const BorderSide(
                        color: ClawColors.frame,
                        width: 2,
                      ),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 20,
                        vertical: 12,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(6),
                      ),
                    ),
                    child: Text(
                      l10n.continueLabel,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  ElevatedButton(
                    onPressed: canAffordTryAgain ? onTryAgain : null,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: ClawColors.action,
                      foregroundColor: Colors.white,
                      disabledBackgroundColor: ClawColors.actionDisabled,
                      disabledForegroundColor: Colors.white70,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 20,
                        vertical: 12,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(6),
                      ),
                    ),
                    child: Text(
                      l10n.clawTryAgain(tryAgainCost),
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Big two-tone sphere preview for the result dialog. Composes the shell +
/// sprite into a small offscreen image and renders it with `RawImage` at
/// `FilterQuality.none`, so the preview matches the chunky in-game ball.
class _PrizePreview extends StatefulWidget {
  final Collectible collectible;
  const _PrizePreview({required this.collectible});

  @override
  State<_PrizePreview> createState() => _PrizePreviewState();
}

class _PrizePreviewState extends State<_PrizePreview>
    with SingleTickerProviderStateMixin {
  static const Duration _crackDelay = Duration(milliseconds: 450);
  static const Duration _crackDuration = Duration(milliseconds: 650);
  static const double _previewSize = 96;

  PrizeSphereLayers? _layers;
  late final AnimationController _ctrl;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(vsync: this, duration: _crackDuration);

    // A stable shell color so the same dialog frame doesn't flicker if it
    // rebuilds mid-animation. Index off the collectible id so two retries
    // landing on the same prize get the same shell.
    final shell = shellPalette[
        widget.collectible.id.codeUnits.fold(0, (a, b) => a + b) %
            shellPalette.length];
    () async {
      final assetPath = widget.collectible.spriteAsset;
      final sprite = CollectibleRegistry.instance.cachedSprite(assetPath) ??
          await CollectibleRegistry.instance.loadSprite(assetPath);
      final layers = await composePrizeSphereLayers(
        sprite: sprite,
        shellLeft: shell.$1,
        shellRight: shell.$2,
      );
      if (!mounted) return;
      setState(() => _layers = layers);
      // Brief beat so the user registers the closed shell before it cracks.
      await Future<void>.delayed(_crackDelay);
      if (!mounted) return;
      AudioManager.instance.playClawShellCrack();
      _ctrl.forward();
    }();
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final layers = _layers;
    if (layers == null) {
      return const SizedBox(width: _previewSize, height: _previewSize);
    }
    return SizedBox(
      width: _previewSize,
      height: _previewSize,
      child: AnimatedBuilder(
        animation: _ctrl,
        builder: (context, _) {
          // easeOut so the halves swing open fast at first, then settle.
          final t = Curves.easeOutCubic.transform(_ctrl.value);
          // Hinge at the bottom-center: rotate the top edge of each half
          // outward (clamshell opening). A bit past 90° so the halves
          // overshoot horizontal before falling.
          final angle = t * (math.pi / 2 + 0.25);
          // Once the halves are mostly open, let them drift down and fade
          // out — looks like the shell pieces tumble off the prize.
          final fadeT = ((t - 0.5) * 2).clamp(0.0, 1.0);
          final shellAlpha = 1 - fadeT;
          final drop = _previewSize * 0.35 * fadeT * fadeT;
          // The sprite occupies the same fraction of the sphere as it
          // does inside [paintPrizeSphere]: width = `radius * innerScale`
          // in sphere-pixel space, so divide by the full diameter
          // (pixelSize) to get the screen-space ratio. Sizing the
          // SizedBox to this fraction and rendering the raw sprite gives
          // a single clean upscale from the source PNG to screen.
          final radius = layers.pixelSize / 2 - 0.5;
          final innerFraction =
              (radius * layers.innerScale) / layers.pixelSize;
          return Stack(
            fit: StackFit.expand,
            children: [
              Center(
                child: FractionallySizedBox(
                  widthFactor: innerFraction,
                  child: AspectRatio(
                    aspectRatio:
                        layers.sprite.width / layers.sprite.height,
                    child: RawImage(
                      image: layers.sprite,
                      fit: BoxFit.fill,
                      filterQuality: FilterQuality.none,
                      isAntiAlias: false,
                    ),
                  ),
                ),
              ),
              _ShellHalf(
                image: layers.leftHalf,
                angle: -angle,
                drop: drop,
                opacity: shellAlpha,
              ),
              _ShellHalf(
                image: layers.rightHalf,
                angle: angle,
                drop: drop,
                opacity: shellAlpha,
              ),
            ],
          );
        },
      ),
    );
  }
}

/// One half of the cracking shell: rotates around its own bottom-center
/// (the seam where the two halves meet) and optionally drops + fades as
/// it falls away.
class _ShellHalf extends StatelessWidget {
  final ui.Image image;
  final double angle;
  final double drop;
  final double opacity;
  const _ShellHalf({
    required this.image,
    required this.angle,
    required this.drop,
    required this.opacity,
  });

  @override
  Widget build(BuildContext context) {
    return Transform.translate(
      offset: Offset(0, drop),
      child: Transform.rotate(
        angle: angle,
        alignment: Alignment.bottomCenter,
        child: Opacity(
          opacity: opacity,
          child: RawImage(
            image: image,
            fit: BoxFit.contain,
            filterQuality: FilterQuality.none,
            isAntiAlias: false,
          ),
        ),
      ),
    );
  }
}
