/// User-selectable font families. Bundled as local assets (offline-first).
enum AppFont {
  pixelifySans('Pixelify Sans', 'Pixelify Sans'),
  atkinsonHyperlegible('Atkinson Hyperlegible', 'Atkinson Hyperlegible'),
  nunito('Nunito', 'Nunito');

  const AppFont(this.family, this.displayName);

  /// Must match the `family:` entry in pubspec.yaml exactly.
  final String family;

  final String displayName;

  static AppFont fromKey(String? key) => AppFont.values.firstWhere(
    (f) => f.name == key,
    orElse: () => pixelifySans,
  );
}
