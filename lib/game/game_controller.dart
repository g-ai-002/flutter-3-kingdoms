import 'dart:math';

import 'package:flutter/foundation.dart';

import '../models/battle.dart';
import '../models/chronicle.dart';
import '../models/city.dart';
import '../models/difficulty.dart';
import '../models/diplomacy.dart';
import '../models/faction.dart';
import '../models/game_state.dart';
import '../models/general.dart';
import 'battle_preview.dart';
import 'data/scenario.dart';
import 'diplomacy.dart';
import 'engine/battle_engine.dart';
import 'events/month_events.dart';
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
    String? scenarioId,
    double goldRatio = 1,
    int? seed,
  }) : _random = Random(seed),
       state = Scenario.build(
         playerFaction: factionId,
         difficulty: difficulty,
         scenarioId: scenarioId,
         goldRatio: goldRatio,
       );

  /// 从存档恢复：局面已由 SaveCodec 还原，随机数用新种子重开。
  GameController.fromState(this.state, {int? seed}) : _random = Random(seed);

  final Random _random;
  final GameState state;

  GameState get game => state;

  /// 选中通道：点选城池只影响高亮与城池卡片，与数据通知分开，
  /// 势力卡与顶栏不必跟着重建。地图点击本身负责唤醒渲染。
  final ValueNotifier<String?> selection = ValueNotifier<String?>(null);

  BattlePending? _pending;
  BattleSetup? _setup;
  int _revision = 0;

  /// 游戏数据的修改序号：仅在内政、任命、出征、结算等真正改数据时推进。
  /// 选中城池只影响界面高亮，不会让地图的静态图层失效。
  int get revision => _revision;

  String? get selectedCityId => selection.value;

  City? get selectedCity =>
      selectedCityId == null ? null : state.cities[selectedCityId];

  BattleSetup? get activeBattleSetup => _setup;

  BattlePending? get pendingBattle => _pending;

  bool get finished => state.finished;

  /// 数据变更入口：推进修订号再通知界面与地图。
  void _notifyChanged() {
    _revision++;
    notifyListeners();
  }

  void selectCity(String? id) {
    if (selection.value == id) return;
    selection.value = id;
  }

  /// 本方城池可选的内政指令，已执行或资源不足时由界面置灰。
  OrderResult issueOrder(CityAction action) {
    final city = selectedCity;
    if (city == null) {
      return const OrderResult(success: false, message: '请先选择城池');
    }
    if (city.owner != state.playerFaction) {
      return const OrderResult(success: false, message: '并非本方城池');
    }
    final result = OrderService.apply(state, city, action, _random);
    if (result.success) _notifyChanged();
    return result;
  }

  /// 出征前的纸面胜算，与真正开战时使用同一套守将与战力口径。
  BattlePreview previewAttack(City source, City target) => BattlePreview(
    source: source,
    target: target,
    defender: state.defenderOf(target),
  );

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
    if (result.success) _notifyChanged();
    return result;
  }

  void appointGovernor(String generalId) {
    final city = selectedCity;
    if (city == null) return;
    OrderService.appointGovernor(city, generalId);
    _notifyChanged();
  }

  /// 遣使交涉：金钱无论成败都会消耗，成败由使者与双方实力决定。
  OrderResult attemptDiplomacy(String targetId, DiplomaticMove move) {
    if (finished) {
      return const OrderResult(success: false, message: '战局已定');
    }
    final goldBefore = state.player.gold;
    final result = DiplomacyService.attempt(state, targetId, move, _random);
    if (result.success) _checkVictory();
    if (result.success || state.player.gold != goldBefore) _notifyChanged();
    return result;
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
    if (state.hasPact(source.owner, target.owner)) {
      return (setup: null, error: '两家已有盟约，背盟兴兵有失道义');
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
    _commitAttack(
      source: source,
      target: target,
      general: general,
      troops: troops,
    );
    _pending = BattlePending(
      sourceId: source.id,
      targetId: target.id,
      generalId: general?.id,
      troops: troops,
    );
    _setup = setup;
    _notifyChanged();
    return (setup: setup, error: null);
  }

  /// 出兵落账：扣减兵力、占用本月指令并写一条出征战报。
  /// 玩家战斗页与 AI 即时结算都从这里出发，避免两套扣兵逻辑走偏。
  void _commitAttack({
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
      _notifyChanged();
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
    _notifyChanged();
  }

  /// 结束本月：AI 先后行动，再统一结算钱粮、随机事件并推进月份。
  void endTurn() {
    if (finished) return;
    _runAiTurn();
    _settleMonth();
    MonthEvents.roll(state, _random);
    _advanceMonth();
    _checkVictory();
    selection.value = null;
    _notifyChanged();
  }

  /// 组装双方战力快照，供玩家战斗页与 AI 自动结算共用。
  BattleSetup buildSetup({
    required City source,
    required City target,
    required General? attacker,
    required int troops,
    required String attackerFaction,
  }) {
    return BattleSetup(
      attacker: _battleSide(
        city: source,
        general: attacker,
        attacking: true,
        factionId: attackerFaction,
        troops: troops,
        morale: (88 + (attacker?.lead ?? 50) / 8).clamp(70, 120).round(),
        terrain: target.terrain,
      ),
      defender: _battleSide(
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
  BattleSide _battleSide({
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
    );
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
      _resolveCaptives(target, defenders, attackerFaction);
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
    state.addChronicle(
      '${target.name} 守军击退 $factionName 军，'
      '${general?.name ?? '带队偏将'} 折损 ${result.attackerLosses} 人后退回 ${source.name}。',
      ChronicleKind.battle,
      factionId: target.owner,
    );
  }

  /// 破城后的武将处置：忠义者归野，其余有几率归顺新主。
  void _resolveCaptives(City city, List<General> captives, String winner) {
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
    state.syncAlive();
    for (final def in FactionDefs.all) {
      if (def.id == state.playerFaction) continue;
      if (!state.factions[def.id]!.alive) continue;
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
    final faction = state.factions[factionId]!;
    final upkeep = state.upkeepOf(factionId);
    for (final city in cities) {
      if (city.acted) continue;
      final action = _aiAction(faction, city, upkeep);
      if (faction.gold < action.goldCost || faction.food < action.foodCost) {
        continue;
      }
      OrderService.apply(state, city, action, _random);
    }
  }

  CityAction _aiAction(FactionState faction, City city, int upkeep) {
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
    return _random.nextBool() ? CityAction.reclaim : CityAction.train;
  }

  /// AI 也会在家门口登用在野名士，给玩家制造压力。
  void _aiRecruitGeneral(String factionId) {
    final faction = state.factions[factionId]!;
    if (faction.gold < 600) return;
    for (final city in state.citiesOf(factionId)) {
      if (city.acted) continue;
      final candidates = state.freeGeneralsIn(city);
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
      final setup = buildSetup(
        source: bestSource,
        target: bestTarget,
        attacker: general,
        troops: committed,
        attackerFaction: factionId,
      );
      _commitAttack(
        source: bestSource,
        target: bestTarget,
        general: general,
        troops: committed,
      );
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
      final multiplier = def.id == state.playerFaction
          ? state.difficulty.playerIncome
          : state.difficulty.aiIncome;
      final economy = state.economyOf(def.id);
      faction.gold += (economy.gold * multiplier).round();
      faction.food += (economy.food * multiplier).round() - economy.upkeep;
      if (faction.food < 0) _applyStarvation(def, faction);
    }
    state.syncAlive();
  }

  /// 粮草见底：各城按兵力比例逃散，治安同步下滑。
  void _applyStarvation(FactionDef def, FactionState faction) {
    faction.food = 0;
    var starved = 0;
    for (final city in state.citiesOf(def.id)) {
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

  void _advanceMonth() {
    state.month++;
    if (state.month > 12) {
      state.month = 1;
      state.year++;
    }
    state.tickPacts();
    for (final city in state.cities.values) {
      city.acted = false;
    }
    state.addChronicle(
      '${state.year}年${state.month}月，天下局势暗流涌动。',
      ChronicleKind.system,
    );
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

  @override
  void dispose() {
    selection.dispose();
    super.dispose();
  }
}
