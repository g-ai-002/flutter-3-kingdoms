import 'dart:math';

import '../models/battle.dart';
import '../models/chronicle.dart';
import '../models/city.dart';
import '../models/faction.dart';
import '../models/game_state.dart';
import '../models/general.dart';
import 'growth.dart';

/// 出征落账：扣兵、夺城、俘将与残兵回城共用一套口径。
class CampaignService {
  CampaignService._();

  /// 组装双方战力快照，供玩家战斗页与 AI 自动结算共用。
  static BattleSetup setup({
    required GameState state,
    required City source,
    required City target,
    required General? attacker,
    required int troops,
    required String attackerFaction,
  }) {
    return BattleSetup(
      attacker: _side(
        city: source,
        general: attacker,
        attacking: true,
        factionId: attackerFaction,
        troops: troops,
        morale: (88 + (attacker?.lead ?? 50) / 8).clamp(70, 120).round(),
        terrain: target.terrain,
      ),
      defender: _side(
        city: target,
        general: state.defenderOf(target),
        attacking: false,
        factionId: target.owner,
        troops: target.troops,
        morale: (96 + target.defense / 10).clamp(80, 125).round(),
        terrain: target.terrain,
      ),
    );
  }

  /// 战场一方：攻守两方只在默认主将、城防与任务名上不同，其余口径一致。
  static BattleSide _side({
    required City city,
    required General? general,
    required bool attacking,
    required String factionId,
    required int troops,
    required int morale,
    required Terrain terrain,
  }) {
    return BattleSide(
      factionId: factionId,
      cityId: city.id,
      cityName: city.name,
      generalId: general?.id,
      generalName: general?.name ?? (attacking ? '偏将' : '守将'),
      lead: general?.lead ?? (attacking ? 50 : 55),
      wu: general?.wu ?? (attacking ? 50 : 55),
      intel: general?.intel ?? 45,
      training: city.training,
      defense: attacking ? 0 : city.defense,
      troops: troops,
      morale: morale,
      terrain: terrain,
      attacking: attacking,
      trait:
          general?.trait ??
          (attacking ? GeneralTrait.balanced : GeneralTrait.commander),
      skill: general?.skill ?? GeneralSkill.none,
      troopType: city.troopType,
      level: general?.level ?? 1,
    );
  }

  /// 出兵落账：扣减兵力、占用本月指令并写一条出征战报。
  /// 玩家战斗页与 AI 即时结算都从这里出发，避免两套扣兵逻辑走偏。
  static void commitAttack({
    required GameState state,
    required City source,
    required City target,
    required General? general,
    required int troops,
  }) {
    source.troops -= troops;
    source.acted = true;
    state.addChronicle(
      '${general?.name ?? '偏将'} 率 $troops 兵自 ${source.name} 出征 ${target.name}。',
      ChronicleKind.battle,
      factionId: source.owner,
    );
  }

  /// 把战斗结果写回地图：夺城、俘虏处置与残兵回城。
  static void applyResult({
    required GameState state,
    required City source,
    required City target,
    required General? general,
    required BattleResult result,
    required String attackerFaction,
    required Random random,
  }) {
    final factionName = FactionDefs.nameOf(attackerFaction);
    final defender = state.defenderOf(target);
    if (result.attackerWon) {
      final defeatedFaction = target.owner;
      final defenders = state.residentsOf(target);
      target.owner = attackerFaction;
      target.troops = result.attackerRemaining;
      target.acted = true;
      target.order = max(25, target.order - 12);
      if (general != null) {
        general.cityId = target.id;
        source.generalIds.remove(general.id);
        target.generalIds.add(general.id);
        target.governor = general.id;
        if (source.governor == general.id) {
          source.governor = state.residentsOf(source).isEmpty
              ? null
              : (state.residentsOf(
                  source,
                )..sort((a, b) => b.lead.compareTo(a.lead))).first.id;
        }
      } else {
        target.governor = null;
      }
      GrowthService.award(state, general, GrowthService.captureXp);
      GrowthService.award(state, defender, GrowthService.defeatXp);
      _resolveCaptives(state, target, defenders, attackerFaction, random);
      state.addChronicle(
        '$factionName 军攻破 ${target.name}，'
        '${FactionDefs.nameOf(defeatedFaction)} 军弃城而走，'
        '折损 ${result.defenderLosses} 人。',
        ChronicleKind.battle,
        factionId: attackerFaction,
      );
      state.syncAlive();
      return;
    }
    source.troops += result.attackerRemaining;
    target.troops = result.defenderRemaining;
    if (general != null && general.cityId != source.id) {
      source.generalIds.add(general.id);
      general.cityId = source.id;
    }
    GrowthService.award(state, general, GrowthService.defeatXp);
    GrowthService.award(state, defender, GrowthService.repelXp);
    state.addChronicle(
      '${target.name} 守军击退 $factionName 军，'
      '${general?.name ?? '带队偏将'} 折损 ${result.attackerLosses} 人后退回 ${source.name}。',
      ChronicleKind.battle,
      factionId: target.owner,
    );
  }

  /// 破城后的武将处置：忠义者归野，其余有几率归顺新主。
  static void _resolveCaptives(
    GameState state,
    City city,
    List<General> captives,
    String winner,
    Random random,
  ) {
    for (final captive in captives) {
      final joinChance = (1 - captive.loyalty / 130).clamp(0.08, 0.55);
      final joined = random.nextDouble() < joinChance;
      captive
        ..factionId = joined ? winner : freeFactionId
        ..loyalty = joined ? 55 : 60;
      state.addChronicle(
        joined
            ? '${city.name}：${captive.name} 归降 ${FactionDefs.nameOf(winner)}。'
            : '${city.name}：${captive.name} 不愿屈事新主，从此归隐。',
        ChronicleKind.event,
        factionId: winner,
      );
    }
  }
}
