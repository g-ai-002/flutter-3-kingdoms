import 'dart:math';

import '../models/chronicle.dart';
import '../models/city.dart';
import '../models/game_state.dart';
import '../models/general.dart';
import 'order_result.dart';

/// 城池内政指令：每城每月只能执行一条。
enum CityAction {
  reclaim('开垦', '兴修水利、开垦荒田，提升农业与每月粮草', 150, 0),
  trade('招商', '招徕商贾、开通市集，提升商业与每月金钱', 150, 0),
  patrol('治安', '巡查缉盗、安抚百姓，提升治安与收入效率', 100, 0),
  recruit('征兵', '张榜募兵，消耗钱粮补充兵源', 300, 300),
  train('训练', '操练士卒，提升训练度与全军战力', 120, 0),
  fortify('修城', '加固城墙、修缮箭楼，提升城防', 200, 0);

  const CityAction(this.label, this.description, this.goldCost, this.foodCost);

  final String label;
  final String description;
  final int goldCost;
  final int foodCost;
}

/// 指令结算：统一处理费用、上限与增益，界面只负责展示。
class OrderService {
  OrderService._();

  /// 登用一名在野武将的花费。
  static const int recruitGeneralCost = 250;

  static OrderResult apply(
    GameState state,
    City city,
    CityAction action,
    Random random,
  ) {
    if (city.acted) {
      return const OrderResult(success: false, message: '本月此城已下过指令');
    }
    final faction = state.factions[city.owner]!;
    if (faction.gold < action.goldCost) {
      return const OrderResult(success: false, message: '金钱不足');
    }
    if (faction.food < action.foodCost) {
      return const OrderResult(success: false, message: '粮草不足');
    }
    final governor = state.governorOf(city);
    final politics = governor?.politics ?? 40;
    final lead = governor?.lead ?? 40;
    var bonus = governor != null && governor.trait == GeneralTrait.statesman
        ? 2
        : 0;
    if (governor?.skill == GeneralSkill.statecraft) bonus += 1;

    faction.gold -= action.goldCost;
    faction.food -= action.foodCost;
    city.acted = true;

    final effects = <String, int>{};
    switch (action) {
      case CityAction.reclaim:
        final gain = min(7, 3 + politics ~/ 40 + bonus + random.nextInt(2));
        city.agriculture = min(100, city.agriculture + gain);
        effects['农业'] = gain;
        break;
      case CityAction.trade:
        final gain = min(7, 3 + politics ~/ 40 + bonus + random.nextInt(2));
        city.commerce = min(100, city.commerce + gain);
        effects['商业'] = gain;
        break;
      case CityAction.patrol:
        final gain = min(9, 4 + politics ~/ 40 + bonus + random.nextInt(2));
        city.order = min(100, city.order + gain);
        effects['治安'] = gain;
        break;
      case CityAction.recruit:
        final capacity = city.maxTroops - city.troops;
        if (capacity <= 0) {
          faction.gold += action.goldCost;
          faction.food += action.foodCost;
          city.acted = false;
          return const OrderResult(success: false, message: '兵力已达人口上限');
        }
        final gained = min(
          capacity,
          800 + city.order * 4 + politics * 4 + random.nextInt(200),
        );
        city.troops += gained;
        effects['兵力'] = gained;
        break;
      case CityAction.train:
        final gain = min(7, 3 + lead ~/ 40 + bonus + random.nextInt(2));
        city.training = min(100, city.training + gain);
        effects['训练'] = gain;
        break;
      case CityAction.fortify:
        final gain = min(7, 3 + lead ~/ 50 + bonus + random.nextInt(2));
        city.defense = min(100, city.defense + gain);
        effects['城防'] = gain;
        break;
    }
    final gains = effects.entries
        .map((entry) => '${entry.key} +${entry.value}')
        .join('，');
    state.addChronicle(
      '${city.name}：${action.label}，$gains',
      ChronicleKind.order,
      factionId: city.owner,
    );
    return OrderResult(
      success: true,
      message: '${city.name} ${action.label}完成 · $gains',
      effects: effects,
    );
  }

  /// 登用在野武将。政治越高越容易成功，失败也会消耗盘缠。
  static OrderResult recruit(
    GameState state,
    City city,
    General general,
    Random random,
  ) {
    if (!general.free || general.cityId != city.id) {
      return const OrderResult(success: false, message: '此人不在城中');
    }
    if (city.acted) {
      return const OrderResult(success: false, message: '本月此城已下过指令');
    }
    final faction = state.factions[city.owner]!;
    if (faction.gold < recruitGeneralCost) {
      return const OrderResult(success: false, message: '金钱不足');
    }
    final governor = state.governorOf(city);
    final politics = governor?.politics ?? 40;
    faction.gold -= recruitGeneralCost;
    city.acted = true;
    final chance = (0.3 + politics / 180).clamp(0.25, 0.9).toDouble();
    if (random.nextDouble() > chance) {
      state.addChronicle(
        '${city.name}：登用 ${general.name} 未成，此人婉言谢绝。',
        ChronicleKind.order,
        factionId: city.owner,
      );
      return OrderResult(success: false, message: '${general.name} 婉言谢绝，登用未成');
    }
    general.factionId = city.owner;
    general.loyalty = min(90, 55 + politics ~/ 3);
    if (!city.generalIds.contains(general.id)) {
      city.generalIds.add(general.id);
    }
    city.governor ??= general.id;
    state.addChronicle(
      '${city.name}：${general.name} 感其诚意，愿效犬马之劳。',
      ChronicleKind.event,
      factionId: city.owner,
    );
    return OrderResult(success: true, message: '${general.name} 归顺，帐下再添一员');
  }

  /// 任命太守：不消耗本月指令。
  static void appointGovernor(City city, String generalId) {
    if (!city.generalIds.contains(generalId)) return;
    city.governor = generalId;
  }
}
