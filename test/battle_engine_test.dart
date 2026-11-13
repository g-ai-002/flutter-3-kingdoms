import 'dart:math';

import 'package:flutter_test/flutter_test.dart';

import 'package:flutter_3_kingdoms/game/engine/battle_engine.dart';
import 'package:flutter_3_kingdoms/models/battle.dart';
import 'package:flutter_3_kingdoms/models/city.dart';
import 'package:flutter_3_kingdoms/models/general.dart';

BattleSetup _setup({
  int attackerTroops = 5000,
  int defenderTroops = 3000,
  int attackerInt = 80,
  int defenderInt = 70,
  int defense = 60,
  GeneralTrait attackerTrait = GeneralTrait.warrior,
}) {
  return BattleSetup(
    attacker: BattleSide(
      factionId: 'wei',
      cityId: 'puyang',
      cityName: '濮阳',
      generalName: '许褚',
      lead: 82,
      wu: 96,
      intel: attackerInt,
      training: 70,
      defense: 0,
      troops: attackerTroops,
      morale: 100,
      terrain: Terrain.plain,
      attacking: true,
      trait: attackerTrait,
    ),
    defender: BattleSide(
      factionId: 'yuan',
      cityId: 'pingyuan',
      cityName: '平原',
      generalName: '文丑',
      lead: 76,
      wu: 92,
      intel: defenderInt,
      training: 60,
      defense: defense,
      troops: defenderTroops,
      morale: 100,
      terrain: Terrain.plain,
      attacking: false,
    ),
  );
}

void main() {
  group('战斗结算', () {
    test('固守比强攻承受更少伤亡', () {
      final hold = BattleEngine.start(_setup());
      final assault = BattleEngine.start(_setup());
      final holdLoss = BattleEngine.fightRound(
        hold,
        BattleTactic.hold,
        Random(7),
      ).attackerLoss;
      final assaultLoss = BattleEngine.fightRound(
        assault,
        BattleTactic.assault,
        Random(7),
      ).attackerLoss;
      expect(holdLoss, lessThan(assaultLoss));
    });

    test('撤退立即结束战斗并保留七成兵力', () {
      final state = BattleEngine.start(_setup());
      BattleEngine.fightRound(state, BattleTactic.retreat, Random(1));
      expect(state.finished, isTrue);
      expect(state.attackerWon, isFalse);
      expect(state.retreated, isTrue);
      expect(state.attacker.troops, (5000 * 0.72).round());
    });

    test('战斗必定在回合上限内结束', () {
      final state = BattleEngine.start(
        _setup(attackerTroops: 3000, defenderTroops: 3200, defense: 90),
      );
      final random = Random(11);
      var guard = 0;
      while (!state.finished && guard < 100) {
        BattleEngine.fightRound(
          state,
          BattleEngine.attackerTactic(state, random),
          random,
        );
        guard++;
      }
      expect(state.finished, isTrue);
      expect(state.round, lessThanOrEqualTo(BattleState.maxRounds));
    });

    test('优势兵力通常能破城，且双方伤亡均为正', () {
      final random = Random(20261114);
      var wins = 0;
      for (var i = 0; i < 12; i++) {
        final result = BattleEngine.autoResolve(_setup(), random);
        expect(result.attackerLosses, greaterThan(0));
        if (result.attackerWon) wins++;
      }
      expect(wins, greaterThanOrEqualTo(9));
    });

    test('高智力主将火攻比固守更有杀伤力', () {
      final fire = BattleEngine.start(_setup(attackerInt: 96, defenderInt: 60));
      final hold = BattleEngine.start(_setup(attackerInt: 96, defenderInt: 60));
      final fireLoss = BattleEngine.fightRound(
        fire,
        BattleTactic.fire,
        Random(3),
      ).defenderLoss;
      final holdLoss = BattleEngine.fightRound(
        hold,
        BattleTactic.hold,
        Random(3),
      ).defenderLoss;
      expect(fireLoss, greaterThan(holdLoss));
    });
  });
}
