import 'package:flutter_test/flutter_test.dart';

import 'package:flutter_3_kingdoms/game/battle_preview.dart';
import 'package:flutter_3_kingdoms/game/game_controller.dart';
import 'package:flutter_3_kingdoms/models/game_state.dart';

GameController _newGame() => GameController(factionId: 'wei', seed: 11);

void main() {
  test('势力收入、粮草收入与消耗按城池汇总', () {
    final game = _newGame().game;
    final cities = game.citiesOf('wei').toList();
    expect(
      game.goldIncomeOf('wei'),
      cities.fold<int>(0, (sum, city) => sum + city.goldIncome),
    );
    expect(
      game.foodIncomeOf('wei'),
      cities.fold<int>(0, (sum, city) => sum + city.foodIncome),
    );
    expect(
      game.upkeepOf('wei'),
      cities.fold<int>(0, (sum, city) => sum + city.foodUpkeep),
    );
    expect(game.upkeepOf('wei'), greaterThan(0));
  });

  test('失去全部城池的势力收入为零', () {
    final game = _newGame().game;
    for (final city in game.citiesOf('dong').toList()) {
      city.owner = 'wei';
    }
    expect(game.goldIncomeOf('dong'), 0);
    expect(game.foodIncomeOf('dong'), 0);
    expect(game.upkeepOf('dong'), 0);
  });

  test('出征预览的守将与实战口径一致，胜算分档有序', () {
    final controller = _newGame();
    final source = controller.game.cities['puyang']!;
    final target = controller.game.cities['pingyuan']!;
    final preview = controller.previewAttack(source, target);

    expect(preview.defender?.id, controller.game.defenderOf(target)?.id);
    expect(preview.ratio, greaterThan(0));
    expect(preview.odds, BattleOdds.of(preview.ratio));
    expect(BattleOdds.of(2.0), BattleOdds.favorable);
    expect(BattleOdds.of(1.2), BattleOdds.even);
    expect(BattleOdds.of(0.9), BattleOdds.unfavorable);
  });

  test('出征主将按攻城战力排序，空城返回空列表', () {
    final controller = _newGame();
    final city = controller.game.cities['puyang']!;
    final leaders = controller.game.attackLeaders(city);
    expect(leaders, isNotEmpty);
    for (var i = 1; i < leaders.length; i++) {
      expect(
        leaders[i - 1].attackFactor,
        greaterThanOrEqualTo(leaders[i].attackFactor),
      );
    }
    final empty = controller.game.cities['xuchang']!;
    empty.generalIds.clear();
    empty.governor = null;
    expect(controller.game.attackLeaders(empty), isEmpty);
    expect(controller.game.defenderOf(empty), isNull);
  });

  test('结局标签与征战月数', () {
    final controller = _newGame();
    expect(controller.game.elapsedMonths, 0);
    controller.endTurn();
    expect(controller.game.elapsedMonths, 1);
    expect(GameOutcome.victory.label, '一统山河');
    expect(GameOutcome.defeat.label, '霸业成空');
  });
}
