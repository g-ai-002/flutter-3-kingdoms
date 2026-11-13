import 'dart:math';

import '../../models/chronicle.dart';
import '../../models/city.dart';
import '../../models/game_state.dart';

/// 每月可能降临在本方城池上的随机事件。
enum MonthEvent {
  harvest('丰收'),
  locusts('蝗灾'),
  plague('疫病'),
  refugees('流民'),
  revolt('民变'),
  caravan('商队'),
  talent('名将来投');

  const MonthEvent(this.label);

  final String label;
}

/// 月度随机事件：逐城判定是否触发，再按事件类型改写城池、钱粮与武将。
///
/// 事件只落在玩家势力的城池上，AI 势力的月度变化由内政与出征产生。
class MonthEvents {
  MonthEvents._();

  /// 每座城池每月触发事件的概率。
  static const double triggerChance = 0.2;

  /// 遍历本方城池并随机触发事件。
  static void roll(GameState state, Random random) {
    for (final city in state.citiesOf(state.playerFaction).toList()) {
      if (random.nextDouble() > triggerChance) continue;
      final event = MonthEvent.values[random.nextInt(MonthEvent.values.length)];
      apply(state, city, event, random);
    }
  }

  /// 结算单个事件，供月度流程与测试直接调用。
  static void apply(
    GameState state,
    City city,
    MonthEvent event,
    Random random,
  ) {
    switch (event) {
      case MonthEvent.harvest:
        _harvest(state, city);
      case MonthEvent.locusts:
        _locusts(state, city);
      case MonthEvent.plague:
        _plague(state, city);
      case MonthEvent.refugees:
        _refugees(state, city);
      case MonthEvent.revolt:
        _revolt(state, city);
      case MonthEvent.caravan:
        _caravan(state, city, random);
      case MonthEvent.talent:
        _talent(state, city);
    }
  }

  static void _harvest(GameState state, City city) {
    final gain = city.foodIncome;
    state.player.food += gain;
    city.agriculture = min(100, city.agriculture + 2);
    _log(state, city, '${city.name} 风调雨顺，仓廪充实，得粮 $gain 石。');
  }

  static void _locusts(GameState state, City city) {
    final loss = min(state.player.food, city.foodIncome);
    state.player.food -= loss;
    city.order = max(0, city.order - 3);
    _log(state, city, '${city.name} 蝗灾肆虐，损失粮草 $loss 石。');
  }

  static void _plague(GameState state, City city) {
    final loss = max(20, (city.troops * 0.07).round());
    city.troops = max(0, city.troops - loss);
    _log(state, city, '${city.name} 疫病流行，折损士卒 $loss 人。');
  }

  static void _refugees(GameState state, City city) {
    city.population = min(160, city.population + 2);
    city.order = max(0, city.order - 2);
    _log(state, city, '${city.name} 流民来投，人口渐增。');
  }

  static void _revolt(GameState state, City city) {
    city.order = max(0, city.order - 8);
    final loss = max(15, (city.troops * 0.04).round());
    city.troops = max(0, city.troops - loss);
    _log(state, city, '${city.name} 民变四起，治安下降，折兵 $loss。');
  }

  static void _caravan(GameState state, City city, Random random) {
    final gain = 180 + random.nextInt(160);
    state.player.gold += gain;
    _log(state, city, '${city.name} 商队云集，得金 $gain。');
  }

  /// 名将来投；城中无人可投时改为开垦荒田。
  static void _talent(GameState state, City city) {
    final candidates = state.freeGeneralsIn(city);
    if (candidates.isEmpty) {
      const gain = 120;
      state.player.food += gain;
      _log(state, city, '${city.name} 垦得荒田，得粮 $gain 石。');
      return;
    }
    candidates.sort((a, b) => b.rating.compareTo(a.rating));
    final general = candidates.first;
    general.factionId = city.owner;
    general.loyalty = 70;
    city.governor ??= general.id;
    _log(state, city, '${city.name}：${general.name} 慕名来投，愿为本方效力。');
  }

  static void _log(GameState state, City city, String text) =>
      state.addChronicle(text, ChronicleKind.event, factionId: city.owner);
}
