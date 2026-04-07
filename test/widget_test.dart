import 'package:flutter_test/flutter_test.dart';
import 'package:lexaway/game/lexaway_game.dart';

void main() {
  test('game can be instantiated', () {
    expect(
      LexawayGame(characterPath: 'characters/female/doux/base'),
      isA<LexawayGame>(),
    );
  });
}
