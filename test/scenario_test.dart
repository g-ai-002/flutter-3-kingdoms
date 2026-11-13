import 'dart:collection';

import 'package:flutter_test/flutter_test.dart';

import 'package:flutter_3_kingdoms/game/data/scenario.dart';
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
}
