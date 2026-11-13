import 'dart:math';

import 'package:flutter_test/flutter_test.dart';

import 'package:flutter_3_kingdoms/game/diplomacy.dart';
import 'package:flutter_3_kingdoms/game/game_controller.dart';
import 'package:flutter_3_kingdoms/game/save_codec.dart';
import 'package:flutter_3_kingdoms/models/diplomacy.dart';

/// 固定随机数：0 必成，1 必败，便于验证成败两条分支。
class _FixedRandom implements Random {
  _FixedRandom(this.value);

  final double value;

  @override
  bool nextBool() => value < 0.5;

  @override
  double nextDouble() => value;

  @override
  int nextInt(int max) => 0;
}

GameController _newGame() {
  final controller = GameController(factionId: 'wei', seed: 1);
  controller.game.player.gold = 5000;
  return controller;
}

void main() {
  group('外交', () {
    test('停战成功后盟约对称生效，期间不可进攻，到期自动解除', () {
      final controller = _newGame();
      final game = controller.game;
      final result = DiplomacyService.attempt(
        game,
        'yuan',
        DiplomaticMove.truce,
        _FixedRandom(0),
      );

      expect(result.success, isTrue);
      expect(game.pactMonths('wei', 'yuan'), 6);
      expect(game.pactMonths('yuan', 'wei'), 6);
      expect(game.player.gold, 4600);

      final source = game.cities['puyang']!..troops = 6000;
      final target = game.cities['pingyuan']!;
      final blocked = controller.prepareBattle(
        source: source,
        target: target,
        general: null,
        troops: 1000,
      );
      expect(blocked.setup, isNull);
      expect(blocked.error, contains('盟约'));

      for (var i = 0; i < 6; i++) {
        game.tickPacts();
      }
      expect(game.hasPact('wei', 'yuan'), isFalse);
      expect(
        controller
            .prepareBattle(
              source: source,
              target: target,
              general: null,
              troops: 1000,
            )
            .setup,
        isNotNull,
      );
    });

    test('联姻花费更高，盟约持续两年', () {
      final controller = _newGame();
      final game = controller.game;
      final result = DiplomacyService.attempt(
        game,
        'shu',
        DiplomaticMove.marriage,
        _FixedRandom(0),
      );

      expect(result.success, isTrue);
      expect(game.player.gold, 4100);
      expect(game.pactMonths('wei', 'shu'), 24);
      expect(result.message, contains('24'));
    });

    test('使者被拒也会消耗盘缠，不会缔结盟约', () {
      final controller = _newGame();
      final game = controller.game;
      final result = DiplomacyService.attempt(
        game,
        'dong',
        DiplomaticMove.truce,
        _FixedRandom(1),
      );

      expect(result.success, isFalse);
      expect(result.message, contains('拒绝'));
      expect(game.player.gold, 4600);
      expect(game.hasPact('wei', 'dong'), isFalse);
    });

    test('已盟约时不再重复遣使，弱小势力才可劝降', () {
      final controller = _newGame();
      final game = controller.game;
      game.makePact('wei', 'yuan', 3);

      final repeat = DiplomacyService.attempt(
        game,
        'yuan',
        DiplomaticMove.truce,
        _FixedRandom(0),
      );
      expect(repeat.success, isFalse);
      expect(repeat.message, contains('无需再遣使'));
      expect(game.player.gold, 5000);

      final strong = DiplomacyService.attempt(
        game,
        'shu',
        DiplomaticMove.vassalize,
        _FixedRandom(0),
      );
      expect(strong.success, isFalse);
      expect(strong.message, contains('尚强'));
      expect(game.player.gold, 5000);
    });

    test('劝降成功时城池、武将与半数钱粮并入本方', () {
      final controller = _newGame();
      final game = controller.game;
      for (final city in game.citiesOf('dong').toList()) {
        if (city.id != 'xinye') city.owner = 'wei';
      }
      game.factions['dong']!
        ..gold = 800
        ..food = 1000;
      final generalCount = game.generals.values
          .where((general) => general.factionId == 'dong')
          .length;
      final goldBefore = game.player.gold;

      final result = DiplomacyService.attempt(
        game,
        'dong',
        DiplomaticMove.vassalize,
        _FixedRandom(0),
      );

      expect(result.success, isTrue);
      expect(game.cityCount('dong'), 0);
      expect(game.factions['dong']!.alive, isFalse);
      expect(game.cities['xinye']!.owner, 'wei');
      expect(
        game.generals.values.where((general) => general.factionId == 'dong'),
        isEmpty,
      );
      expect(
        game.generals.values
            .where((general) => general.factionId == 'wei')
            .length,
        greaterThan(generalCount),
      );
      expect(game.player.gold, goldBefore - 1500 + 400);
      expect(game.player.food, greaterThan(0));
      expect(game.hasPact('wei', 'dong'), isFalse);
    });

    test('劝降成功后结束本月并判定一统山河', () {
      final controller = _newGame();
      final game = controller.game;
      for (final city in game.cities.values) {
        if (city.owner != 'wei' && city.owner != 'dong') city.owner = 'wei';
      }
      for (final city in game.citiesOf('dong').toList()) {
        if (city.id != 'xinye') city.owner = 'wei';
      }

      final result = DiplomacyService.attempt(
        game,
        'dong',
        DiplomaticMove.vassalize,
        _FixedRandom(0),
      );
      expect(result.success, isTrue);
      expect(game.cityCount('wei'), game.totalCities);

      controller.endTurn();
      expect(game.finished, isTrue);
      expect(game.isVictory, isTrue);
    });

    test('存档往返保留盟约剩余月数', () {
      final controller = _newGame();
      final game = controller.game;
      game.makePact('wei', 'yuan', 9);
      game.makePact('shu', 'wu', 4);

      final restored = SaveCodec.decode(SaveCodec.encode(game));

      expect(restored.pactMonths('wei', 'yuan'), 9);
      expect(restored.pactMonths('wu', 'shu'), 4);
    });
  });
}
