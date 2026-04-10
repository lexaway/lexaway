import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:hive_ce/hive_ce.dart';
import 'package:lexaway/game/lexaway_game.dart';

void main() {
  test('game can be instantiated', () async {
    final box = await Hive.openBox('game_test', bytes: Uint8List(0));
    expect(
      LexawayGame(
        hiveBox: box,
        characterPath: 'characters/female/doux/base',
      ),
      isA<LexawayGame>(),
    );
  });
}
