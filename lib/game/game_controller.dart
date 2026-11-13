import 'dart:math';

import 'package:flutter/foundation.dart';

import '../models/battle.dart';
import '../models/chronicle.dart';
import '../models/city.dart';
import '../models/difficulty.dart';
import '../models/faction.dart';
import '../models/game_state.dart';
import '../models/general.dart';
import 'data/scenario.dart';
import 'engine/battle_engine.dart';
import 'order_result.dart';
import 'orders.dart';

/// 玩家发起的一场战斗：源城、目标城、主将与出兵数。
class BattlePending {
  const BattlePending({
    required this.sourceId,
    required this.targetId,
    required this.generalId,
    required this.troops,
  });

  final String sourceId;
  final String targetId;
  final String? generalId;
  final int troops;
}

/// 战略层控制器：选择城池、下达指令、发起战斗、结束回合与 AI 结算。
class GameController extends ChangeNotifier {
  GameController({
    required String factionId,
    Difficulty difficulty = Difficulty.normal,
    int? seed,
  }) : _random = Random(seed),
       state = Scenario.build(
         playerFaction: factionId,
         difficulty: difficulty,
       );

  final Random _random;
  final GameState state;

  GameState get game => state;

  String? _selectedCityId;
  BattlePending? _pending;
  BattleSetup? _setup;

  String? get selectedCityId => _selectedCityId;

  City? get selectedCity =>
      _selectedCityId == null ? null : state.cities[_selectedCityId];

  BattleSetup? get activeBattleSetup => _setup;

  BattlePending? get pendingBattle => _pending;

  bool get finished => state.finished;

  void selectCity(String? id) {
    if (_selectedCityId == id) return;
    _selectedCityId = id;
    notifyListeners();
  }

  /// 本方城池可选的内政指令，已执行或资源不足时由界面置灰。
  List<CityAction> availableActions(City city) {
    if (city.owner != state.playerFaction) return const [];
    return CityAction.values;
  }

  OrderResult issueOrder(CityAction action) {
    final city = selectedCity;
    if (city == null) {
      return const OrderResult(success: false, message: '请先选择城池');
    }
    if (city.owner != state.playerFaction) {
      return const OrderResult(success: false, message: '并非本方城池');
    }
    final result = OrderService.apply(state, city, action, _random);
    if (result.success) notifyListeners();
    return result;
  }

  List<General> freeGeneralsIn(City city) => city.generalIds
      .map((id) => state.generals[id]!)
      .where((general) => general.free)
      .toList();

  List<General> residentsOf(City city) => city.generalIds
      .map((id) => state.generals[id]!)
      .where((general) => general.factionId == city.owner && !general.free)
      .toList();

  General? governorOf(City city) =>
      city.governor == null ? null : state.generals[city.governor];

  OrderResult recruitGeneral(String generalId) {
    final city = selectedCity;
    final general = state.generals[generalId];
    if (city == null || general == null) {
      return const OrderResult(success: false, message: '目标不存在');
    }
    if (city.owner != state.playerFaction) {
      return const OrderResult(success: false, message: '并非本方城池');
    }
    final result = OrderService.recruit(state, city, general, _random);
    if (result.success) notifyListeners();
    return result;
  }

  void appointGovernor(String generalId) {
    final city = selectedCity;
    if (city == null) return;
    OrderService.appointGovernor(city, generalId);
    notifyListeners();
  }

  /// 玩家发起攻城战：校验相邻关系与兵力后先扣兵，再交给战斗页。
  ({BattleSetup? setup, String? error}) prepareBattle({
    required City source,
    required City target,
    required General? general,
    required int troops,
  }) {
    if (finished) return (setup: null, error: '战局已定');
    if (source.owner != state.playerFaction) {
      return (setup: null, error: '只能从本方城池出兵');
    }
    if (!source.neighbors.contains(target.id)) {
      return (setup: null, error: '两城并不接壤');
    }
    if (target.owner == source.owner) {
      return (setup: null, error: '不可进攻本方城池');
    }
    if (source.acted) {
      return (setup: null, error: '本月此城已下过指令');
    }
    if (general != null &&
        (general.cityId != source.id || general.factionId != source.owner)) {
      return (setup: null, error: '主将不在城中');
    }
    if (troops < 500) return (setup: null, error: '至少需率 500 兵出征');
    if (troops > source.troops - 200) {
      return (setup: null, error: '城中至少需留 200 守军');
    }
    final setup = buildSetup(
      source: source,
      target: target,
      attacker: general,
      troops: troops,
      attackerFaction: source.owner,
    );
    source.troops -= troops;
    source.acted = true;
    _pending = BattlePending(
      sourceId: source.id,
      targetId: target.id,
      generalId: general?.id,
      troops: troops,
    );
    _setup = setup;
    state.addChronicle(
      '${general?.name ?? '偏将'} 率 $troops 兵自 ${source.name} 出征 ${target.name}。',
      ChronicleKind.battle,
      factionId: source.owner,
    );
    notifyListeners();
    return (setup: setup, error: null);
  }

  /// 战斗页结束（或中途退出）后写回结果；result 为空时按撤军处理并退还兵力。
  void finishPlayerBattle(BattleResult? result) {
    final pending = _pending;
    if (pending == null) return;
    final source = state.cities[pending.sourceId]!;
    final target = state.cities[pending.targetId]!;
    final general = pending.generalId == null
        ? null
        : state.generals[pending.generalId!];
    if (result == null) {
      source.troops += pending.troops;
      source.acted = false;
      _pending = null;
      _setup = null;
      state.addChronicle(
        '${source.name} 出征无功而返，兵马回城。',
        ChronicleKind.battle,
        factionId: source.owner,
      );
      notifyListeners();
      return;
    }
    _applyBattleResult(
      source: source,
      target: target,
      general: general,
      troops: pending.troops,
      result: result,
      attackerFaction: source.owner,
    );
    _pending = null;
    _setup = null;
    _checkVictory();
    notifyListeners();
  }

  void clearBattle() {
    _pending = null;
    _setup = null;
  }

  /// 结束本月：AI 先后行动，再统一结算钱粮、随机事件并推进月份。
  void endTurn() {
    if (finished) return;
    _runAiTurn();
    _settleMonth();
    _rollEvents();
    _advanceMonth();
    _checkVictory();
    _selectedCityId = null;
    notifyListeners();
  }

  /// 组装双方战力快照，供玩家战斗页与 AI 自动结算共用。
  BattleSetup buildSetup({
    required City source,
    required City target,
    required General? attacker,
    required int troops,
    required String attackerFaction,
  }) {
    final defender = _defenderGeneral(target);
    final attackerMorale =
        (88 + (attacker?.lead ?? 50) / 8).clamp(70, 120).round();
    final defenderMorale = (96 + target.defense / 10).clamp(80, 125).round();
    return BattleSetup(
      attacker: BattleSide(
        factionId: attackerFaction,
        cityId: source.id,
        cityName: source.name,
        generalId: attacker?.id,
        generalName: attacker?.name ?? '偏将',
        lead: attacker?.lead ?? 50,
        wu: attacker?.wu ?? 50,
        intel: attacker?.intel ?? 45,
        training: source.training,
        defense: 0,
        troops: troops,
        morale: attackerMorale,
        terrain: target.terrain,
        attacking: true,
        trait: attacker?.trait ?? GeneralTrait.balanced,
      ),
      defender: BattleSide(
        factionId: target.owner,
        cityId: target.id,
        cityName: target.name,
        generalId: defender?.id,
        generalName: defender?.name ?? '守将',
        lead: defender?.lead ?? 55,
        wu: defender?.wu ?? 55,
        intel: defender?.intel ?? 45,
        training: target.training,
        defense: target.defense,
        troops: target.troops,
        morale: defenderMorale,
        terrain: target.terrain,
        attacking: false,
        trait: defender?.trait ?? GeneralTrait.commander,
      ),
    );
  }

  General? _defenderGeneral(City city) {
    if (city.governor != null) {
      final governor = state.generals[city.governor!];
      if (governor != null && governor.factionId == city.owner) {
        return governor;
      }
    }
    final residents = residentsOf(city);
    if (residents.isEmpty) return null;
    residents.sort((a, b) => b.defenseFactor.compareTo(a.defenseFactor));
    return residents.first;
  }

  /// 把战斗结果写回地图：夺城、俘虏处置与残兵回城。
  void _applyBattleResult({
    required City source,
    required City target,
    required General? general,
    required int troops,
    required BattleResult result,
    required String attackerFaction,
  }) {
    final factionName = FactionDefs.nameOf(attackerFaction);
    if (result.attackerWon) {
      final defeatedFaction = target.owner;
      final defenders = residentsOf(target);
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
          source.governor = residentsOf(source).isEmpty
              ? null
              : (residentsOf(source)..sort((a, b) => b.lead.compareTo(a.lead)))
                    .first
                    .id;
        }
      } else {
        target.governor = null;
      }
      _resolveCaptives(target, defenders, attackerFaction);
      state.addChronicle(
        '$factionName 军攻破 ${target.name}，'
        '${FactionDefs.nameOf(defeatedFaction)} 军弃城而走，'
        '折损 ${result.defenderLosses} 人。',
        ChronicleKind.battle,
        factionId: attackerFaction,
      );
      _refreshAlive();
      return;
    }
    source.troops += result.attackerRemaining;
    target.troops = result.defenderRemaining;
    if (general != null && general.cityId != source.id) {
      source.generalIds.add(general.id);
      general.cityId = source.id;
    }
    state.addChronicle(
      '${target.name} 守军击退 $factionName 军，'
      '${general?.name ?? '带队偏将'} 折损 ${result.attackerLosses} 人后退回 ${source.name}。',
      ChronicleKind.battle,
      factionId: target.owner,
    );
  }

  /// 破城后的武将处置：忠义者归野，其余有几率归顺新主。
  void _resolveCaptives(
    City city,
    List<General> captives,
    String winner,
  ) {
    for (final captive in captives) {
      final joinChance = (1 - captive.loyalty / 130).clamp(0.08, 0.55);
      if (_random.nextDouble() < joinChance) {
        captive.factionId = winner;
        captive.loyalty = 55;
        state.addChronicle(
          '${city.name}：${captive.name} 归降 ${FactionDefs.nameOf(winner)}。',
          ChronicleKind.event,
          factionId: winner,
        );
      } else {
        captive.factionId = freeFactionId;
        captive.loyalty = 60;
        state.addChronicle(
          '${city.name}：${captive.name} 不愿屈事新主，从此归隐。',
          ChronicleKind.event,
          factionId: winner,
        );
      }
    }
  }

  // ======================== AI ========================

  void _runAiTurn() {
    for (final def in FactionDefs.all) {
      if (def.id == state.playerFaction) continue;
      final faction = state.factions[def.id]!;
      if (!faction.alive) continue;
      if (!state.hasCities(def.id)) {
        faction.alive = false;
        continue;
      }
      // 先议战事再理内政：出征会占用城池本月指令，发展则填满剩余城池。
      _aiAttack(def.id);
      _aiDevelop(def.id);
      _aiRecruitGeneral(def.id);
    }
  }

  /// AI 内政：缺粮开垦、缺钱招商，边城优先修城，其余资源投入兵源与训练。
  void _aiDevelop(String factionId) {
    final cities = state.citiesOf(factionId).toList()
      ..sort((a, b) => b.troops.compareTo(a.troops));
    for (final city in cities) {
      if (city.acted) continue;
      final faction = state.factions[factionId]!;
      final upkeep = state
          .citiesOf(factionId)
          .fold<int>(0, (sum, item) => sum + item.foodUpkeep);
      final frontier = city.neighbors.any(
        (id) => state.cities[id]!.owner != factionId,
      );
      CityAction? action;
      if (faction.food < upkeep * 3 || city.agriculture < 45) {
        action = CityAction.reclaim;
      } else if (faction.gold < 500 || city.commerce < 45) {
        action = CityAction.trade;
      } else if (city.order < 55) {
        action = CityAction.patrol;
      } else if (frontier && city.defense < 55) {
        action = CityAction.fortify;
      } else if (city.training < 65) {
        action = CityAction.train;
      } else if (city.troops < city.maxTroops * 0.7) {
        action = CityAction.recruit;
      } else {
        action = _random.nextBool()
            ? CityAction.reclaim
            : CityAction.train;
      }
      if (faction.gold < action.goldCost || faction.food < action.foodCost) {
        continue;
      }
      OrderService.apply(state, city, action, _random);
    }
  }

  /// AI 也会在家门口登用在野名士，给玩家制造压力。
  void _aiRecruitGeneral(String factionId) {
    final faction = state.factions[factionId]!;
    if (faction.gold < 600) return;
    for (final city in state.citiesOf(factionId)) {
      if (city.acted) continue;
      final candidates = freeGeneralsIn(city);
      if (candidates.isEmpty) continue;
      if (_random.nextDouble() > 0.22) continue;
      candidates.sort((a, b) => b.rating.compareTo(a.rating));
      OrderService.recruit(state, city, candidates.first, _random);
    }
  }

  /// AI 出击：挑选兵力最充足且邻敌最弱的城池，按难度阈值决定是否开战。
  void _aiAttack(String factionId) {
    final difficulty = state.difficulty;
    var attempts = factionId == 'dong' || factionId == 'yuan' ? 2 : 1;
    while (attempts-- > 0) {
      City? bestSource;
      City? bestTarget;
      var bestScore = 0.0;
      for (final city in state.citiesOf(factionId)) {
        if (city.troops < 1800 || city.acted) continue;
        for (final target in state.enemyNeighbors(city)) {
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
      final residents = residentsOf(bestSource);
      residents.sort((a, b) => b.attackFactor.compareTo(a.attackFactor));
      final general = residents.isEmpty ? null : residents.first;
      final committed = max(500, (bestSource.troops * 0.72).round());
      if (committed > bestSource.troops - 300) return;
      final setup = buildSetup(
        source: bestSource,
        target: bestTarget,
        attacker: general,
        troops: committed,
        attackerFaction: factionId,
      );
      bestSource.troops -= committed;
      bestSource.acted = true;
      final result = BattleEngine.autoResolve(setup, _random);
      _applyBattleResult(
        source: bestSource,
        target: bestTarget,
        general: general,
        troops: committed,
        result: result,
        attackerFaction: factionId,
      );
    }
  }

  // ======================== 月度结算 ========================

  void _settleMonth() {
    for (final def in FactionDefs.all) {
      final faction = state.factions[def.id]!;
      if (!state.hasCities(def.id)) {
        faction.alive = false;
        continue;
      }
      final cities = state.citiesOf(def.id).toList();
      final gold = cities.fold<int>(0, (sum, city) => sum + city.goldIncome);
      final food = cities.fold<int>(0, (sum, city) => sum + city.foodIncome);
      final upkeep = cities.fold<int>(0, (sum, city) => sum + city.foodUpkeep);
      final multiplier = def.id == state.playerFaction
          ? state.difficulty.playerIncome
          : state.difficulty.aiIncome;
      faction.gold += (gold * multiplier).round();
      faction.food += (food * multiplier).round() - upkeep;
      if (faction.food < 0) {
        faction.food = 0;
        var starved = 0;
        for (final city in cities) {
          final loss = max(30, (city.troops * 0.08).round());
          starved += min(city.troops, loss);
          city.troops = max(0, city.troops - loss);
          city.order = max(10, city.order - 4);
        }
        state.addChronicle(
          '${def.name} 军粮草告罄，士卒逃散，折兵 $starved。',
          ChronicleKind.event,
        );
      }
    }
    _refreshAlive();
  }

  void _rollEvents() {
    for (final city in state.citiesOf(state.playerFaction).toList()) {
      if (_random.nextDouble() > 0.2) continue;
      final event = _random.nextInt(7);
      final faction = state.player;
      switch (event) {
        case 0:
          final gain = city.foodIncome;
          faction.food += gain;
          city.agriculture = min(100, city.agriculture + 2);
          state.addChronicle(
            '${city.name} 风调雨顺，仓廪充实，得粮 $gain 石。',
            ChronicleKind.event,
            factionId: city.owner,
          );
          break;
        case 1:
          final loss = min(faction.food, city.foodIncome);
          faction.food -= loss;
          city.order = max(0, city.order - 3);
          state.addChronicle(
            '${city.name} 蝗灾肆虐，损失粮草 $loss 石。',
            ChronicleKind.event,
            factionId: city.owner,
          );
          break;
        case 2:
          final loss = max(20, (city.troops * 0.07).round());
          city.troops = max(0, city.troops - loss);
          state.addChronicle(
            '${city.name} 疫病流行，折损士卒 $loss 人。',
            ChronicleKind.event,
            factionId: city.owner,
          );
          break;
        case 3:
          city.population = min(160, city.population + 2);
          city.order = max(0, city.order - 2);
          state.addChronicle(
            '${city.name} 流民来投，人口渐增。',
            ChronicleKind.event,
            factionId: city.owner,
          );
          break;
        case 4:
          city.order = max(0, city.order - 8);
          final loss = max(15, (city.troops * 0.04).round());
          city.troops = max(0, city.troops - loss);
          state.addChronicle(
            '${city.name} 民变四起，治安下降，折兵 $loss。',
            ChronicleKind.event,
            factionId: city.owner,
          );
          break;
        case 5:
          final gain = 180 + _random.nextInt(160);
          faction.gold += gain;
          state.addChronicle(
            '${city.name} 商队云集，得金 $gain。',
            ChronicleKind.event,
            factionId: city.owner,
          );
          break;
        case 6:
          final candidates = freeGeneralsIn(city);
          if (candidates.isEmpty) {
            final gain = 120;
            faction.food += gain;
            state.addChronicle(
              '${city.name} 垦得荒田，得粮 $gain 石。',
              ChronicleKind.event,
              factionId: city.owner,
            );
            break;
          }
          candidates.sort((a, b) => b.rating.compareTo(a.rating));
          final general = candidates.first;
          general.factionId = city.owner;
          general.loyalty = 70;
          city.governor ??= general.id;
          state.addChronicle(
            '${city.name}：${general.name} 慕名来投，愿为本方效力。',
            ChronicleKind.event,
            factionId: city.owner,
          );
          break;
      }
    }
  }

  void _advanceMonth() {
    state.month++;
    if (state.month > 12) {
      state.month = 1;
      state.year++;
    }
    for (final city in state.cities.values) {
      city.acted = false;
    }
    state.addChronicle(
      '${state.year}年${state.month}月，天下局势暗流涌动。',
      ChronicleKind.system,
    );
  }

  void _refreshAlive() {
    for (final def in FactionDefs.all) {
      final faction = state.factions[def.id]!;
      faction.alive = state.hasCities(def.id);
    }
  }

  void _checkVictory() {
    if (state.finished) return;
    if (state.citiesOf(state.playerFaction).isEmpty) {
      state.finished = true;
      state.outcome = GameOutcome.defeat;
      state.addChronicle(
        '${FactionDefs.nameOf(state.playerFaction)} 失尽城池，霸业成空。',
        ChronicleKind.system,
      );
    } else if (state.cityCount(state.playerFaction) == state.totalCities) {
      state.finished = true;
      state.outcome = GameOutcome.victory;
      state.addChronicle(
        '${FactionDefs.nameOf(state.playerFaction)} 一统山河，天下归心！',
        ChronicleKind.system,
      );
    }
  }
}
