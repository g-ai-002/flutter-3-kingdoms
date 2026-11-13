import 'dart:math';

import 'package:flutter_test/flutter_test.dart';

import 'package:flutter_3_kingdoms/game/engine/battle_engine.dart';
import 'package:flutter_3_kingdoms/game/game_controller.dart';
import 'package:flutter_3_kingdoms/game/orders.dart';
import 'package:flutter_3_kingdoms/models/battle.dart';
import 'package:flutter_3_kingdoms/models/city.dart';
import 'package:flutter_3_kingdoms/models/general.dart';

BattleSide _side({
  required TroopType troopType,
  GeneralSkill skill = GeneralSkill.none,
  int troops = 6000,
  int intel = 70,
  bool attacking = true,
}) => BattleSide(
  factionId: 'wei',
  cityId: 'xuchang',
  cityName: '许昌',
  generalName: '主将',
  lead: 80,
  wu: 80,
  intel: intel,
  training: 70,
  defense: 50,
  troops: troops,
  morale: 100,
  terrain: Terrain.plain,
  attacking: attacking,
  trait: GeneralTrait.commander,
  skill: skill,
  troopType: troopType,
);

({int attackerLoss, int defenderLoss}) _round(
  BattleSide attacker,
  BattleSide defender,
  BattleTactic tactic,
) {
  final state = BattleState(attacker: attacker, defender: defender);
  return BattleEngine.fightRound(state, tactic, Random(7));
}

void main() {
  group('兵种相克', () {
    test('步克骑、骑克弩、弩克步，水军不与任何兵种互克', () {
      expect(TroopType.infantry.counters(TroopType.cavalry), isTrue);
      expect(TroopType.cavalry.counters(TroopType.archer), isTrue);
      expect(TroopType.archer.counters(TroopType.infantry), isTrue);
      expect(TroopType.navy.counters(TroopType.infantry), isFalse);
      expect(TroopType.infantry.counters(TroopType.navy), isFalse);
      expect(TroopType.cavalry.against(TroopType.archer), greaterThan(1));
      expect(TroopType.archer.against(TroopType.cavalry), lessThan(1));
    });

    test('水军在水乡加成，离开水乡反而减损', () {
      expect(
        TroopType.navy.onTerrain(Terrain.river),
        greaterThan(TroopType.infantry.onTerrain(Terrain.river)),
      );
      expect(TroopType.navy.onTerrain(Terrain.plain), lessThan(0));
      expect(
        TroopType.cavalry.onTerrain(Terrain.plain),
        greaterThan(TroopType.cavalry.onTerrain(Terrain.mountain)),
      );
    });

    test('克制守军兵种的进攻方造成更多杀伤', () {
      final favored = _round(
        _side(troopType: TroopType.cavalry),
        _side(troopType: TroopType.archer, attacking: false),
        BattleTactic.assault,
      );
      final neutral = _round(
        _side(troopType: TroopType.cavalry),
        _side(troopType: TroopType.cavalry, attacking: false),
        BattleTactic.assault,
      );
      expect(favored.defenderLoss, greaterThan(neutral.defenderLoss));
    });
  });

  group('武将技能', () {
    test('火计加强火攻杀伤', () {
      final skilled = _round(
        _side(troopType: TroopType.infantry, skill: GeneralSkill.firestorm),
        _side(troopType: TroopType.infantry, attacking: false),
        BattleTactic.fire,
      );
      final plain = _round(
        _side(troopType: TroopType.infantry),
        _side(troopType: TroopType.infantry, attacking: false),
        BattleTactic.fire,
      );
      expect(skilled.defenderLoss, greaterThan(plain.defenderLoss));
    });

    test('出征快照带上城池兵种与主将技能', () {
      final controller = GameController(factionId: 'wei', seed: 5);
      final game = controller.game;
      final setup = controller.buildSetup(
        source: game.cities['puyang']!,
        target: game.cities['jiangling']!,
        attacker: game.generals['xuchu'],
        troops: 3000,
        attackerFaction: 'wei',
      );
      expect(setup.attacker.troopType, TroopType.infantry);
      expect(setup.attacker.skill, GeneralSkill.divineMight);
      expect(setup.defender.troopType, TroopType.navy);
      expect(setup.defender.skill, GeneralSkill.divineMight);
    });

    test('治世太守提升内政收益', () {
      final controller = GameController(factionId: 'wei', seed: 5);
      final state = controller.game;
      final xuchang = state.cities['xuchang']!;
      final caocao = state.generals['caocao']!;
      expect(caocao.skill, GeneralSkill.statecraft);
      xuchang.governor = 'caocao';
      final before = xuchang.agriculture;
      controller.selectCity('xuchang');
      final result = controller.issueOrder(CityAction.reclaim);
      expect(result.success, isTrue);
      expect(xuchang.agriculture, greaterThan(before));
    });
  });
}
