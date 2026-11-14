import 'dart:math';

import '../models/city.dart';
import '../models/faction.dart';
import '../models/game_state.dart';
import 'campaign.dart';
import 'engine/battle_engine.dart';
import 'orders.dart';

/// AI 势力按月行动：择弱出击，再补内政与登用。
class AiService {
  AiService._();

  static void runTurn(GameState state, Random random) {
    state.syncAlive();
    for (final def in FactionDefs.all) {
      final faction = state.factions[def.id]!;
      if (def.id == state.playerFaction || !faction.alive) continue;
      // 先议战事再理内政：出征会占用城池本月指令，发展则填满剩余城池。
      _attack(state, def.id, random);
      _develop(state, faction, random);
      _recruit(state, faction, random);
    }
  }

  /// AI 内政：缺粮开垦、缺钱招商，边城优先修城，其余资源投入兵源与训练。
  static void _develop(GameState state, FactionState faction, Random random) {
    final cities = state.citiesOf(faction.id).toList()
      ..sort((a, b) => b.troops.compareTo(a.troops));
    final upkeep = state.upkeepOf(faction.id);
    for (final city in cities) {
      if (city.acted) continue;
      final action = _action(state, faction, city, upkeep, random);
      if (faction.gold < action.goldCost || faction.food < action.foodCost) {
        continue;
      }
      OrderService.apply(state, city, action, random);
    }
  }

  static CityAction _action(
    GameState state,
    FactionState faction,
    City city,
    int upkeep,
    Random random,
  ) {
    final frontier = city.neighbors.any(
      (id) => state.cities[id]!.owner != faction.id,
    );
    if (faction.food < upkeep * 3 || city.agriculture < 45) {
      return CityAction.reclaim;
    }
    if (faction.gold < 500 || city.commerce < 45) return CityAction.trade;
    if (city.order < 55) return CityAction.patrol;
    if (frontier && city.defense < 55) return CityAction.fortify;
    if (city.training < 65) return CityAction.train;
    if (city.troops < city.maxTroops * 0.7) return CityAction.recruit;
    return random.nextBool() ? CityAction.reclaim : CityAction.train;
  }

  /// AI 也会在家门口登用在野名士，给玩家制造压力。
  static void _recruit(GameState state, FactionState faction, Random random) {
    if (faction.gold < 600) return;
    for (final city in state.citiesOf(faction.id)) {
      if (city.acted) continue;
      final candidates = state.freeGeneralsIn(city);
      if (candidates.isEmpty) continue;
      if (random.nextDouble() > 0.22) continue;
      candidates.sort((a, b) => b.rating.compareTo(a.rating));
      OrderService.recruit(state, city, candidates.first, random);
    }
  }

  /// AI 出击：挑选兵力最充足且邻敌最弱的城池，按难度阈值决定是否开战。
  static void _attack(GameState state, String factionId, Random random) {
    final difficulty = state.difficulty;
    var attempts = factionId == 'dong' || factionId == 'yuan' ? 2 : 1;
    while (attempts-- > 0) {
      City? bestSource;
      City? bestTarget;
      var bestScore = 0.0;
      for (final city in state.citiesOf(factionId)) {
        if (city.troops < 1800 || city.acted) continue;
        for (final target in state.enemyNeighbors(city)) {
          if (state.hasPact(factionId, target.owner)) continue;
          final ratio = city.troops / max(600, target.power);
          if (ratio < difficulty.aiAggression) continue;
          final score =
              ratio * 100 +
              (100 - target.defense) +
              (target.owner == state.playerFaction ? 18 : 0);
          if (score > bestScore) {
            bestScore = score;
            bestSource = city;
            bestTarget = target;
          }
        }
      }
      if (bestSource == null || bestTarget == null) return;
      final leaders = state.attackLeaders(bestSource);
      final general = leaders.isEmpty ? null : leaders.first;
      final committed = max(500, (bestSource.troops * 0.72).round());
      if (committed > bestSource.troops - 300) return;
      final setup = CampaignService.setup(
        state: state,
        source: bestSource,
        target: bestTarget,
        attacker: general,
        troops: committed,
        attackerFaction: factionId,
      );
      CampaignService.commitAttack(
        state: state,
        source: bestSource,
        target: bestTarget,
        general: general,
        troops: committed,
      );
      final result = BattleEngine.autoResolve(setup, random);
      CampaignService.applyResult(
        state: state,
        source: bestSource,
        target: bestTarget,
        general: general,
        result: result,
        attackerFaction: factionId,
        random: random,
      );
    }
  }
}
