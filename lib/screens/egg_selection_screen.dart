import 'dart:math';

import 'package:flame/game.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';

import '../data/hive_keys.dart';
import '../game/egg_preview_game.dart';
import '../l10n/app_localizations.dart';
import '../models/character.dart';
import '../providers.dart';
import '../theme/app_colors.dart';
import '../theme/app_spacing.dart';
import '../widgets/tiled_background.dart';

class EggSelectionScreen extends ConsumerStatefulWidget {
  const EggSelectionScreen({super.key});

  @override
  ConsumerState<EggSelectionScreen> createState() => _EggSelectionScreenState();
}

class _EggSelectionScreenState extends ConsumerState<EggSelectionScreen>
    with TickerProviderStateMixin {
  /// The character names are chosen once; switching gender keeps the same names
  /// but swaps the sprite set.
  late List<String> _eggNames;
  late List<CharacterInfo> _eggs;
  final Map<int, EggPreviewGame> _games = {};
  int? _selected;
  bool _hatching = false;
  final _rng = Random();

  late AnimationController _fadeController;
  late Animation<double> _fadeAnimation;

  late List<AnimationController> _shakeControllers;
  late List<Animation<double>> _shakeAnimations;

  @override
  void initState() {
    super.initState();
    _fadeController = AnimationController(
      duration: const Duration(milliseconds: 400),
      vsync: this,
    );
    _fadeAnimation = CurvedAnimation(
      parent: _fadeController,
      curve: Curves.easeOut,
    );

    // Per-egg shake: each has a different cycle length so they desync
    _shakeControllers = List.generate(3, (i) {
      final duration = 2000 + _rng.nextInt(1500); // 2–3.5s per cycle
      return AnimationController(
        duration: Duration(milliseconds: duration),
        vsync: this,
      );
    });
    _shakeAnimations = _shakeControllers.map((c) {
      return TweenSequence<double>([
        TweenSequenceItem(tween: ConstantTween(0), weight: 55),
        TweenSequenceItem(tween: Tween(begin: 0, end: -0.06), weight: 5),
        TweenSequenceItem(tween: Tween(begin: -0.06, end: 0.07), weight: 8),
        TweenSequenceItem(tween: Tween(begin: 0.07, end: -0.05), weight: 7),
        TweenSequenceItem(tween: Tween(begin: -0.05, end: 0.03), weight: 6),
        TweenSequenceItem(tween: Tween(begin: 0.03, end: 0), weight: 4),
        TweenSequenceItem(tween: ConstantTween(0), weight: 15),
      ]).animate(c);
    }).toList();
    // Start each at a random point in its cycle
    for (final c in _shakeControllers) {
      c.value = _rng.nextDouble();
      c.repeat();
    }

    // Pick 3 names that are valid for both genders so toggling works.
    final pool =
        CharacterRegistry.allNames
            .where((n) => !CharacterRegistry.incompleteMale.contains(n))
            .toList()
          ..shuffle();
    _eggNames = pool.take(3).toList();
    _rebuildGames();
  }

  @override
  void dispose() {
    _fadeController.dispose();
    for (final c in _shakeControllers) {
      c.dispose();
    }
    super.dispose();
  }

  void _rebuildGames() {
    final gender = ref.read(genderProvider);
    _eggs = _eggNames
        .map((n) => CharacterInfo(name: n, gender: gender))
        .toList();
    _games.clear();
    _selected = null;
    _hatching = false;
    _fadeController.reset();
    for (var i = 0; i < _eggs.length; i++) {
      _games[i] = EggPreviewGame(character: _eggs[i]);
    }
  }

  void _onEggTapped(int index) {
    if (_hatching) return;
    setState(() {
      _selected = index;
      _hatching = true;
    });

    // Stop all egg shakes (reset to 0 so eggs aren't stuck mid-tilt)
    for (final c in _shakeControllers) {
      c
        ..stop()
        ..value = 0;
    }
    _fadeController.forward();

    // Start the hatch sequence on the selected egg
    final game = _games[index]!;
    game.onAllPhasesComplete = _onHatchComplete;
    game.startHatchSequence();
  }

  void _onHatchComplete() {
    if (!mounted || _selected == null) return;
    final lang = ref.read(activePackProvider.notifier).activeLang;
    if (lang == null) return;

    final character = _eggs[_selected!];
    ref.read(hiveBoxProvider).put(HiveKeys.character(lang), character.key);

    // Brief pause to admire the new dino, then go
    Future.delayed(const Duration(milliseconds: 800), () {
      if (mounted) context.go('/game');
    });
  }

  void _onGenderChanged(String gender) {
    ref.read(genderProvider.notifier).set(gender);
    setState(_rebuildGames);
  }

  @override
  Widget build(BuildContext context) {
    final gender = ref.watch(genderProvider);
    final l10n = AppLocalizations.of(context)!;

    return Scaffold(
      backgroundColor: AppColors.scaffold,
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
          SafeArea(
            child: Column(
              children: [
                const SizedBox(height: AppSpacing.xl),

                // Title
                Text(
                  l10n.chooseYourEgg,
                  textAlign: TextAlign.center,
                  style: GoogleFonts.pixelifySans(
                    color: AppColors.textPrimary,
                    fontSize: 36,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: AppSpacing.sm),
                Text(
                  l10n.whoWillHatch,
                  style: GoogleFonts.pixelifySans(
                    color: AppColors.textTertiary,
                    fontSize: 20,
                  ),
                ),

                // Eggs in a triad: one top-centre, two bottom
                Expanded(
                  child: Stack(
                    children: List.generate(_eggs.length, (i) {
                      final isSelected = _selected == i;
                      final shouldFade = _selected != null && !isSelected;

                      // Triad positions
                      const triad = [
                        Alignment(0, -0.35), // top centre
                        Alignment(-0.45, 0.3), // bottom left
                        Alignment(0.45, 0.3), // bottom right
                      ];
                      final alignment = _hatching && isSelected
                          ? Alignment.center
                          : triad[i % triad.length];

                      return AnimatedAlign(
                        duration: const Duration(milliseconds: 400),
                        curve: Curves.easeInOut,
                        alignment: alignment,
                        child: AnimatedBuilder(
                          animation: _fadeAnimation,
                          builder: (context, child) {
                            final opacity = shouldFade
                                ? 1.0 - _fadeAnimation.value
                                : 1.0;
                            return Opacity(opacity: opacity, child: child);
                          },
                          child: AnimatedBuilder(
                            animation: _shakeAnimations[i],
                            builder: (context, child) {
                              return Transform.rotate(
                                angle: _shakeAnimations[i].value,
                                child: child,
                              );
                            },
                            child: GestureDetector(
                              onTap: _hatching ? null : () => _onEggTapped(i),
                              child: SizedBox(
                                width: 120,
                                height: 120,
                                child: GameWidget(
                                  game: _games[i]!,
                                  backgroundBuilder: (_) =>
                                      const SizedBox.shrink(),
                                ),
                              ),
                            ),
                          ),
                        ),
                      );
                    }),
                  ),
                ),

                // Gender toggle at the bottom
                if (!_hatching)
                  Padding(
                    padding: const EdgeInsets.only(bottom: AppSpacing.lg),
                    child: _GenderToggle(
                      selected: gender,
                      onChanged: _onGenderChanged,
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _GenderToggle extends StatelessWidget {
  final String selected;
  final ValueChanged<String> onChanged;

  const _GenderToggle({required this.selected, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        _GenderButton(
          label: '\u2640',
          value: 'female',
          selected: selected == 'female',
          onTap: () => onChanged('female'),
        ),
        const SizedBox(width: AppSpacing.md),
        _GenderButton(
          label: '\u2642',
          value: 'male',
          selected: selected == 'male',
          onTap: () => onChanged('male'),
        ),
      ],
    );
  }
}

class _GenderButton extends StatelessWidget {
  final String label;
  final String value;
  final bool selected;
  final VoidCallback onTap;

  const _GenderButton({
    required this.label,
    required this.value,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Opacity(
        opacity: selected ? 1.0 : 0.5,
        child: Container(
          width: 52,
          height: 52,
          decoration: const BoxDecoration(
            image: DecorationImage(
              image: AssetImage('assets/images/ui/fab_circle_bg.png'),
              filterQuality: FilterQuality.none,
            ),
          ),
          alignment: Alignment.center,
          child: Text(
            label,
            style: TextStyle(
              fontSize: 24,
              color: selected ? AppColors.textPrimary : AppColors.textSecondary,
            ),
          ),
        ),
      ),
    );
  }
}
