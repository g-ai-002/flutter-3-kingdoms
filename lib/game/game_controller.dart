import 'dart:math';

import 'package:flutter/foundation.dart';

import '../models/battle.dart';
import '../models/chronicle.dart';
import '../models/city.dart';
import '../models/difficulty.dart';
import '../models/diplomacy.dart';
import '../models/game_state.dart';
import '../models/general.dart';
import 'ai.dart';
import 'battle_preview.dart';
import 'campaign.dart';
import 'data/scenario.dart';
import 'diplomacy.dart';
import 'events/month_events.dart';
import 'order_result.dart';
import 'orders.dart';
import 'turn.dart';

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

  /// 犒赏三军：花金稳住城中众将，不占用本月指令。
  OrderResult rewardTroops() {
    final city = selectedCity;
    if (city == null) {
      return const OrderResult(success: false, message: '请先选择城池');
    }
    if (city.owner != state.playerFaction) {
      return const OrderResult(success: false, message: '并非本方城池');
    }
    final result = OrderService.reward(state, city);
    if (result.success) _notifyChanged();
    return result;
  }

  /// 遣使交涉：金钱无论成败都会消耗，成败由使者与双方实力决定。
  OrderResult attemptDiplomacy(String targetId, DiplomaticMove move) {
    if (finished) {
      return const OrderResult(success: false, message: '战局已定');
    }
    final goldBefore = state.player.gold;
    final result = DiplomacyService.attempt(state, targetId, move, _random);
    if (result.success) TurnService.checkVictory(state);
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
    CampaignService.commitAttack(
      state: state,
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
    CampaignService.applyResult(
      state: state,
      source: source,
      target: target,
      general: general,
      result: result,
      attackerFaction: source.owner,
      random: _random,
    );
    _pending = null;
    _setup = null;
    TurnService.checkVictory(state);
    _notifyChanged();
  }

  /// 结束本月：AI 先后行动，再统一结算钱粮、随机事件并推进月份。
  void endTurn() {
    if (finished) return;
    AiService.runTurn(state, _random);
    TurnService.settle(state);
    MonthEvents.roll(state, _random);
    TurnService.advance(state);
    TurnService.checkVictory(state);
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
  }) => CampaignService.setup(
    state: state,
    source: source,
    target: target,
    attacker: attacker,
    troops: troops,
    attackerFaction: attackerFaction,
  );

  @override
  void dispose() {
    selection.dispose();
    super.dispose();
  }
}
