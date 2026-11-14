import 'dart:collection';

import 'package:flutter_test/flutter_test.dart';

import 'package:flutter_3_kingdoms/game/data/scenario.dart';
import 'package:flutter_3_kingdoms/models/difficulty.dart';
import 'package:flutter_3_kingdoms/models/faction.dart';

void main() {
  group('初始局面', () {
    test('每座城池归属合法势力，邻接关系双向一致', () {
      final cities = {for (final city in Scenario.cityDefs) city.id: city};
      expect(cities.length, 28);
      for (final city in Scenario.cityDefs) {
        expect(FactionDefs.isKnown(city.owner), isTrue, reason: city.id);
        for (final neighbor in city.neighbors) {
          expect(cities.containsKey(neighbor), isTrue, reason: '$city -> $neighbor');
          expect(
            cities[neighbor]!.neighbors.contains(city.id),
            isTrue,
            reason: '$neighbor 未回指 ${city.id}',
          );
        }
      }
    });

    test('所有城池连通，不存在孤岛', () {
      final cities = {for (final city in Scenario.cityDefs) city.id: city};
      final visited = <String>{'xuchang'};
      final queue = Queue<String>()..add('xuchang');
      while (queue.isNotEmpty) {
        final id = queue.removeFirst();
        for (final next in cities[id]!.neighbors) {
          if (visited.add(next)) queue.add(next);
        }
      }
      expect(visited.length, cities.length);
    });

    test('武将归属与所在城池一致，没有重复 id', () {
      final cityIds = {for (final city in Scenario.cityDefs) city.id};
      final generalIds = <String>{};
      for (final general in Scenario.generalDefs) {
        expect(generalIds.add(general.id), isTrue, reason: general.id);
        expect(cityIds.contains(general.cityId), isTrue, reason: general.id);
        if (general.factionId != 'none') {
          expect(FactionDefs.isKnown(general.factionId), isTrue);
        }
      }
      expect(generalIds.length, greaterThanOrEqualTo(45));
    });

    test('五方势力均据有城池', () {
      for (final def in FactionDefs.all) {
        expect(
          Scenario.cityDefs.any((city) => city.owner == def.id),
          isTrue,
          reason: def.id,
        );
      }
    });
  });

  group('剧本', () {
    test('三个剧本的易手表合法且城池守恒', () {
      final cityIds = {for (final city in Scenario.cityDefs) city.id};
      expect(
        Scenario.scenarios.map((item) => item.id),
        containsAll([Scenario.defaultScenarioId, 'guandu', 'santianxia']),
      );
      for (final scenario in Scenario.scenarios) {
        expect(scenario.month, inInclusiveRange(1, 12));
        for (final entry in scenario.transfers.entries) {
          expect(cityIds, contains(entry.key));
          expect(FactionDefs.isKnown(entry.value), isTrue);
        }
        var total = 0;
        for (final def in FactionDefs.all) {
          final count = Scenario.cityCountOf(scenario.id, def.id);
          expect(count, greaterThan(0), reason: '${scenario.id}/${def.id}');
          total += count;
        }
        expect(total, cityIds.length, reason: scenario.id);
      }
    });

    test('官渡开局：年月、归属、兵势与名将随势力迁移', () {
      final state = Scenario.build(
        playerFaction: 'yuan',
        difficulty: Difficulty.normal,
        scenarioId: 'guandu',
      );
      final base = Scenario.build(
        playerFaction: 'yuan',
        difficulty: Difficulty.normal,
      );
      expect(state.startYear, 200);
      expect(state.month, 2);
      expect(state.scenarioId, 'guandu');
      expect(state.cities['xinye']!.owner, 'shu');
      expect(state.cities['chengdu']!.owner, 'dong');
      expect(state.generals['liubei']!.cityId, 'jiangling');
      for (final general in state.generals.values.where((g) => !g.free)) {
        expect(
          state.cities[general.cityId]!.owner,
          general.factionId,
          reason: general.name,
        );
      }
      expect(state.cities['ye']!.troops, greaterThan(base.cities['ye']!.troops));
      expect(state.cities['ye']!.governor, isNotNull);
    });

    test('自定义开局钱粮只作用于玩家', () {
      final rich = Scenario.build(
        playerFaction: 'shu',
        difficulty: Difficulty.normal,
        goldRatio: StartSupply.rich.ratio,
      );
      final normal = Scenario.build(
        playerFaction: 'shu',
        difficulty: Difficulty.normal,
      );
      expect(rich.player.gold, greaterThan(normal.player.gold));
      expect(rich.player.food, greaterThan(normal.player.food));
      expect(rich.factions['wei']!.gold, normal.factions['wei']!.gold);
      expect(StartSupply.byRatio(1.34), StartSupply.rich);
    });
  });
}
