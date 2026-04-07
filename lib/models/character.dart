import 'dart:math';

class CharacterInfo {
  final String name;
  final String gender;

  const CharacterInfo({required this.name, required this.gender});

  String get basePath => 'characters/$gender/$name/base';
  String get eggPath => 'characters/$gender/$name/egg';

  String get idleAsset => '$basePath/idle.png';
  String get moveAsset => '$basePath/move.png';
  String get eggMoveAsset => '$eggPath/move.png';
  String get eggCrackAsset => '$eggPath/crack.png';
  String get eggHatchAsset => '$eggPath/hatch.png';

  /// Serialize for Hive storage.
  String get key => '$gender/$name';

  /// Deserialize from Hive storage.
  static CharacterInfo fromKey(String key) {
    final parts = key.split('/');
    return CharacterInfo(gender: parts[0], name: parts[1]);
  }
}

class CharacterRegistry {
  static const allNames = [
    'cole', 'doux', 'kira', 'kuro', 'loki', 'mono',
    'mort', 'nico', 'olaf', 'sena', 'tard', 'vita',
  ];

  /// Male characters missing base/idle.png and base/move.png.
  static const incompleteMale = {'doux', 'mort', 'tard', 'vita'};

  static List<CharacterInfo> available(String gender) {
    return allNames
        .where((n) => !(gender == 'male' && incompleteMale.contains(n)))
        .map((n) => CharacterInfo(name: n, gender: gender))
        .toList();
  }

  static final _rng = Random();

  /// Pick [count] random characters from the available pool.
  static List<CharacterInfo> randomSelection(String gender, {int count = 4}) {
    final pool = available(gender)..shuffle(_rng);
    return pool.take(count).toList();
  }
}
