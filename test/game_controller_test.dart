import 'package:flutter_test/flutter_test.dart';

import 'package:flutter_3_kingdoms/game/game_controller.dart';
import 'package:flutter_3_kingdoms/models/battle.dart';
import 'package:flutter_3_kingdoms/models/difficulty.dart';
import 'package:flutter_3_kingdoms/models/game_state.dart';

GameController _newGame({Difficulty difficulty = Difficulty.normal}) =>
    GameController(factionId: 'wei', difficulty: difficulty, seed: 7);

void main() {
  test('开局五方势力与二十八城就位，本方城池可下令', () {
    final controller = _newGame();
    final game = controller.game;
    expect(game.cities.length, 28);
    expect(game.factions.length, 5);
    expect(game.cityCount('wei'), 7);
    expect(game.playerFaction, 'wei');
    expect(game.finished, isFalse);
    expect(game.chronicle, isNotEmpty);
  });

  test('结束本月后推进月份、恢复城池行动并结算钱粮', () {
    final controller = _newGame();
    final game = controller.game;
    final gold = game.player.gold;
    game.cities['xuchang']!.acted = true;

    controller.endTurn();

    expect(game.month, 2);
    expect(game.player.gold, greaterThan(gold));
    expect(game.cities.values.every((city) => !city.acted), isTrue);
    expect(game.chronicle.length, greaterThan(1));
  });

  test('出征校验相邻、兵力与留军，成功时立即扣兵并占用本月指令', () {
    final controller = _newGame();
    final game = controller.game;
    final source = game.cities['puyang']!;
    final target = game.cities['pingyuan']!;
    final general = game.generals['xuchu'];

    expect(
      controller
          .prepareBattle(
            source: source,
            target: game.cities['xuchang']!,
            general: general,
            troops: 1000,
          )
          .error,
      isNotNull,
    );
    expect(
      controller
          .prepareBattle(
            source: source,
            target: target,
            general: general,
            troops: 300,
          )
          .error,
      contains('500'),
    );
    expect(
      controller
          .prepareBattle(
            source: source,
            target: target,
            general: general,
            troops: 3900,
          )
          .error,
      contains('200'),
    );

    final before = source.troops;
    final prepared = controller.prepareBattle(
      source: source,
      target: target,
      general: general,
      troops: 3000,
    );
    expect(prepared.setup, isNotNull);
    expect(source.troops, before - 3000);
    expect(source.acted, isTrue);
    expect(controller.pendingBattle?.targetId, 'pingyuan');
    expect(controller.activeBattleSetup?.attacker.troops, 3000);
  });

  test('攻城得手后城池易主，主将入城成为太守', () {
    final controller = _newGame();
    final game = controller.game;
    final source = game.cities['puyang']!;
    final target = game.cities['pingyuan']!;
    final general = game.generals['xuchu']!;
    controller.prepareBattle(
      source: source,
      target: target,
      general: general,
      troops: 3000,
    );
    const result = BattleResult(
      attackerWon: true,
      retreated: false,
      attackerRemaining: 1800,
      defenderRemaining: 0,
      attackerLosses: 1200,
      defenderLosses: 3200,
    );
    controller.finishPlayerBattle(result);

    expect(target.owner, 'wei');
    expect(target.troops, 1800);
    expect(target.governor, 'xuchu');
    expect(general.cityId, 'pingyuan');
    expect(source.troops, 1000);
    expect(source.governor, isNull);
    expect(game.cityCount('wei'), 8);
    expect(controller.activeBattleSetup, isNull);
  });

  test('攻城失利后残兵回城，中途退出则全额退还', () {
    final controller = _newGame();
    final game = controller.game;
    final source = game.cities['wan']!;
    final target = game.cities['xinye']!;
    final general = game.generals['caoren']!;
    final before = source.troops;
    controller.prepareBattle(
      source: source,
      target: target,
      general: general,
      troops: 2000,
    );
    controller.finishPlayerBattle(
      const BattleResult(
        attackerWon: false,
        retreated: false,
        attackerRemaining: 800,
        defenderRemaining: 1500,
        attackerLosses: 1200,
        defenderLosses: 900,
      ),
    );
    expect(target.owner, 'dong');
    expect(source.troops, before - 2000 + 800);

    final controller2 = _newGame();
    final source2 = controller2.game.cities['wan']!;
    final before2 = source2.troops;
    controller2.prepareBattle(
      source: source2,
      target: controller2.game.cities['xinye']!,
      general: controller2.game.generals['caoren'],
      troops: 1500,
    );
    controller2.finishPlayerBattle(null);
    expect(source2.troops, before2);
    expect(source2.acted, isFalse);
  });

  test('占据全部城池判胜，失尽城池判负', () {
    final winner = _newGame();
    for (final city in winner.game.cities.values) {
      city.owner = 'wei';
    }
    winner.endTurn();
    expect(winner.finished, isTrue);
    expect(winner.game.outcome, GameOutcome.victory);

    final loser = _newGame();
    for (final city in loser.game.cities.values) {
      city.owner = 'yuan';
    }
    loser.endTurn();
    expect(loser.finished, isTrue);
    expect(loser.game.outcome, GameOutcome.defeat);
  });

  test('AI 会发展内政，并在数月内发动战争', () {
    final controller = _newGame();
    final game = controller.game;
    final snapshot = {
      for (final city in game.citiesOf('yuan'))
        city.id: [
          city.agriculture,
          city.commerce,
          city.order,
          city.training,
          city.troops,
        ],
    };
    controller.endTurn();
    final changed = game.citiesOf('yuan').any((city) {
      final before = snapshot[city.id]!;
      return before[0] != city.agriculture ||
          before[1] != city.commerce ||
          before[2] != city.order ||
          before[3] != city.training ||
          before[4] != city.troops;
    });
    expect(changed, isTrue);

    for (var i = 0; i < 12; i++) {
      controller.endTurn();
    }
    expect(
      game.chronicle.any((entry) => entry.kind.name == 'battle'),
      isTrue,
    );
  });
}
