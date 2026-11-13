import 'dart:math';

import 'package:flutter_test/flutter_test.dart';

import 'package:flutter_3_kingdoms/game/events/month_events.dart';
import 'package:flutter_3_kingdoms/game/game_controller.dart';
import 'package:flutter_3_kingdoms/models/faction.dart';

GameController _newGame() => GameController(factionId: 'wei', seed: 21);

/// 永远返回最大值，用于断言「未命中概率时不会触发事件」。
class _QuietRandom implements Random {
  @override
  bool nextBool() => false;

  @override
  double nextDouble() => 0.99;

  @override
  int nextInt(int max) => max - 1;
}

void main() {
  test('丰收提升粮草与农业，并写入战报', () {
    final game = _newGame().game;
    final city = game.cities['xuchang']!;
    final food = game.player.food;
    final agriculture = city.agriculture;
    final gain = city.foodIncome;
    final before = game.chronicle.length;

    MonthEvents.apply(game, city, MonthEvent.harvest, Random(1));

    expect(game.player.food, food + gain);
    expect(city.agriculture, agriculture + 2);
    expect(game.chronicle.length, before + 1);
    expect(game.chronicle.last.text, contains('风调雨顺'));
    expect(game.chronicle.last.factionId, game.playerFaction);
  });

  test('蝗灾损失不超过存粮，治安同步下滑', () {
    final game = _newGame().game;
    final city = game.cities['xuchang']!;
    game.player.food = 40;
    final order = city.order;

    MonthEvents.apply(game, city, MonthEvent.locusts, Random(2));

    expect(game.player.food, 0);
    expect(city.order, order - 3);
    expect(game.chronicle.last.text, contains('蝗灾'));
  });

  test('疫病与民变按兵力折算损失，最低不低于 15 人', () {
    final game = _newGame().game;
    final plagueCity = game.cities['xuchang']!..troops = 5000;
    MonthEvents.apply(game, plagueCity, MonthEvent.plague, Random(3));
    expect(plagueCity.troops, 5000 - 350);

    final revoltCity = game.cities['chenliu']!..troops = 100;
    final order = revoltCity.order;
    MonthEvents.apply(game, revoltCity, MonthEvent.revolt, Random(4));
    expect(revoltCity.troops, 85);
    expect(revoltCity.order, order - 8);
  });

  test('流民增加人口、商队带来金钱，均不超过上限', () {
    final game = _newGame().game;
    final city = game.cities['xuchang']!..population = 159;
    MonthEvents.apply(game, city, MonthEvent.refugees, Random(5));
    expect(city.population, 160);

    final gold = game.player.gold;
    MonthEvents.apply(game, city, MonthEvent.caravan, Random(6));
    final gain = game.player.gold - gold;
    expect(gain, inInclusiveRange(180, 339));
  });

  test('名将来投：在野武将归顺并补位太守', () {
    final game = _newGame().game;
    final city = game.cities['luoyang']!;
    final candidates = game.freeGeneralsIn(city);
    expect(candidates, isNotEmpty);
    final general = candidates.first;

    MonthEvents.apply(game, city, MonthEvent.talent, Random(7));

    expect(general.factionId, city.owner);
    expect(general.loyalty, 70);
    expect(game.chronicle.last.text, contains('慕名来投'));
  });

  test('城中无在野武将时，名将来投转为开垦荒田', () {
    final game = _newGame().game;
    final city = game.cities['puyang']!;
    expect(game.freeGeneralsIn(city), isEmpty);
    final food = game.player.food;

    MonthEvents.apply(game, city, MonthEvent.talent, Random(8));

    expect(game.player.food, food + 120);
    expect(game.chronicle.last.text, contains('垦得荒田'));
  });

  test('月度事件只落在本方城池，未命中概率时完全不触发', () {
    final game = _newGame().game;
    final snapshot = {
      for (final city in game.cities.values)
        if (city.owner != game.playerFaction) city.id: city.troops,
    };
    final chronicleBefore = game.chronicle.length;

    MonthEvents.roll(game, _QuietRandom());

    expect(game.chronicle.length, chronicleBefore);
    for (final entry in snapshot.entries) {
      expect(game.cities[entry.key]!.troops, entry.value);
    }

    MonthEvents.roll(game, Random(9));
    for (final entry in snapshot.entries) {
      final city = game.cities[entry.key]!;
      expect(city.owner, isNot(game.playerFaction));
      expect(city.troops, entry.value);
    }
  });

  test('名将来投会让在野武将进入本方序列', () {
    final game = _newGame().game;
    final city = game.cities['luoyang']!;
    final free = game.freeGeneralsIn(city).first;
    MonthEvents.apply(game, city, MonthEvent.talent, Random(10));
    expect(free.free, isFalse);
    expect(free.factionId, game.playerFaction);
    expect(game.residentsOf(city), contains(free));
    expect(FactionDefs.nameOf(free.factionId), '魏');
  });
}
