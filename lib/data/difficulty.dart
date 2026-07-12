import '../l10n/app_localizations.dart';

/// Question difficulty tiers.
///
/// `name` doubles as the Hive value and the `level` column value in pack
/// databases, so renaming a member is a data migration — don't.
enum Difficulty {
  beginner(reviewRatio: 0.33),
  intermediate(reviewRatio: 0.25),
  advanced(reviewRatio: 0.15);

  const Difficulty({required this.reviewRatio});

  /// How often a review item is served in place of a fresh one — beginners
  /// see more review to reinforce basics; advanced players see less
  /// repetition.
  final double reviewRatio;

  /// Label shown in the Settings picker.
  String label(AppLocalizations l10n) => switch (this) {
        beginner => l10n.difficultyBeginner,
        intermediate => l10n.difficultyIntermediate,
        advanced => l10n.difficultyAdvanced,
      };

  static Difficulty fromKey(String? key) => Difficulty.values.firstWhere(
        (d) => d.name == key,
        orElse: () => beginner,
      );
}
