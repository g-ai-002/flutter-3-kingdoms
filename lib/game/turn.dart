import 'dart:math';

import '../models/chronicle.dart';
import '../models/faction.dart';
import '../models/game_state.dart';

/// 月度收束：钱粮结算、饥荒、推月与胜负判定。
///
/// AI 行动与随机事件各自独立，这里只负责把一个月真正翻过去。
class TurnService {
  TurnService._();

  /// 按难度倍率结算五方钱粮；失去城池者退出争霸，粮尽者逃兵。
  static void settle(GameState state) {
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
      if (faction.food < 0) _starve(state, def, faction);
    }
    state.syncAlive();
  }

  /// 粮草见底：各城按兵力比例逃散，治安同步下滑。
  static void _starve(GameState state, FactionDef def, FactionState faction) {
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

  /// 推进月份、解除到期盟约，并恢复各城本月指令。
  static void advance(GameState state) {
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

  /// 胜负判定：失尽城池为败，占尽天下为胜；已分胜负后不再改写结局。
  static void checkVictory(GameState state) {
    if (state.finished) return;
    if (state.citiesOf(state.playerFaction).isEmpty) {
      _finish(
        state,
        GameOutcome.defeat,
        '${FactionDefs.nameOf(state.playerFaction)} 失尽城池，霸业成空。',
      );
    } else if (state.cityCount(state.playerFaction) == state.totalCities) {
      _finish(
        state,
        GameOutcome.victory,
        '${FactionDefs.nameOf(state.playerFaction)} 一统山河，天下归心！',
      );
    }
  }

  static void _finish(GameState state, GameOutcome outcome, String text) {
    state.finished = true;
    state.outcome = outcome;
    state.addChronicle(text, ChronicleKind.system);
  }
}
