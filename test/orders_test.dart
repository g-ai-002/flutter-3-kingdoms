import 'dart:math';

import 'package:flutter_test/flutter_test.dart';

import 'package:flutter_3_kingdoms/game/data/scenario.dart';
import 'package:flutter_3_kingdoms/game/orders.dart';
import 'package:flutter_3_kingdoms/models/difficulty.dart';
import 'package:flutter_3_kingdoms/models/game_state.dart';

class _MinRandom implements Random {
  @override
  bool nextBool() => false;

  @override
  double nextDouble() => 0.0;

  @override
  int nextInt(int max) => 0;
}

class _MaxRandom implements Random {
  @override
  bool nextBool() => true;

  @override
  double nextDouble() => 0.999;

  @override
  int nextInt(int max) => max - 1;
}

void main() {
  late GameState state;

  setUp(() {
    state = Scenario.build(
      playerFaction: 'wei',
      difficulty: Difficulty.normal,
    );
  });

  test('开垦提升农业并消耗金钱，同月不能重复下令', () {
    final city = state.cities['xuchang']!;
    final gold = state.player.gold;
    final agriculture = city.agriculture;
    final result = OrderService.apply(state, city, CityAction.reclaim, Random(1));
    expect(result.success, isTrue);
    expect(city.agriculture, greaterThan(agriculture));
    expect(state.player.gold, gold - CityAction.reclaim.goldCost);
    expect(city.acted, isTrue);

    final again = OrderService.apply(
      state,
      city,
      CityAction.trade,
      Random(1),
    );
    expect(again.success, isFalse);
    expect(again.message, contains('已下过指令'));
  });

  test('金钱不足时指令失败且不扣费', () {
    final city = state.cities['xuchang']!;
    state.player.gold = 10;
    final result = OrderService.apply(state, city, CityAction.fortify, Random(1));
    expect(result.success, isFalse);
    expect(result.message, contains('金钱不足'));
    expect(city.acted, isFalse);
    expect(state.player.gold, 10);
  });

  test('兵力达到人口上限时征兵失败并退还钱粮', () {
    final city = state.cities['xuchang']!..troops = 15000;
    final gold = state.player.gold;
    final food = state.player.food;
    final result = OrderService.apply(state, city, CityAction.recruit, Random(1));
    expect(result.success, isFalse);
    expect(result.message, contains('上限'));
    expect(state.player.gold, gold);
    expect(state.player.food, food);
  });

  test('登用成功后在野武将加入势力并成为城中武将', () {
    final city = state.cities['luoyang']!;
    final general = state.generals['zhangliao']!;
    expect(general.free, isTrue);
    final result = OrderService.recruit(state, city, general, _MinRandom());
    expect(result.success, isTrue);
    expect(general.factionId, 'wei');
    expect(general.loyalty, greaterThan(0));
    expect(city.generalIds, contains('zhangliao'));
    expect(city.acted, isTrue);
  });

  test('登用失败也会消耗盘缠，太守可随时更换', () {
    final city = state.cities['changsha']!..owner = 'wei';
    final general = state.generals['huangzhong']!;
    final gold = state.player.gold;
    final result = OrderService.recruit(state, city, general, _MaxRandom());
    expect(result.success, isFalse);
    expect(general.free, isTrue);
    expect(state.player.gold, lessThan(gold));

    final ownCity = state.cities['xuchang']!;
    OrderService.appointGovernor(ownCity, 'xunyu');
    expect(ownCity.governor, 'xunyu');
  });
}
