import 'dart:convert';
import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';

import 'package:flutter_3_kingdoms/game/campaign.dart';
import 'package:flutter_3_kingdoms/game/game_controller.dart';
import 'package:flutter_3_kingdoms/game/growth.dart';
import 'package:flutter_3_kingdoms/game/orders.dart';
import 'package:flutter_3_kingdoms/game/save_codec.dart';
import 'package:flutter_3_kingdoms/models/battle.dart';
import 'package:flutter_3_kingdoms/models/general.dart';
import 'package:flutter_3_kingdoms/pages/widgets/game_sheets.dart';

GameController _newGame() => GameController(factionId: 'wei', seed: 17);

Widget _host(void Function(BuildContext) openSheet) {
  return MaterialApp(
    home: Builder(
      builder: (context) => Scaffold(
        body: Center(
          child: FilledButton(
            onPressed: () => openSheet(context),
            child: const Text('打开'),
          ),
        ),
      ),
    ),
  );
}

void main() {
  test('武将历练每百点升一级，九级封顶并换称号', () {
    final general = General(
      id: 'test',
      name: '试将',
      factionId: 'wei',
      cityId: 'xuchang',
      wu: 80,
      intel: 60,
      lead: 70,
      politics: 50,
      loyalty: 90,
      trait: GeneralTrait.warrior,
    );
    expect(general.level, 1);
    expect(general.rank, '新锐');
    expect(general.levelBonus, 0);

    general.xp = 299;
    expect(general.level, 3);
    expect(general.rank, '骁将');

    general.xp = 500;
    expect(general.level, 6);
    expect(general.rank, '名将');

    general.xp = 800;
    expect(general.level, 9);
    expect(general.rank, '军神');
    expect(general.levelBonus, closeTo(0.12, 1e-9));

    general.xp = 99999;
    expect(general.level, General.maxLevel);
  });

  test('历练升级写入战报，在野武将不参与历练', () {
    final controller = _newGame();
    final game = controller.game;
    final caocao = game.generals['caocao']!;
    final free = game.generals['zhangliao']!;

    GrowthService.award(game, caocao, 100);
    expect(caocao.level, 2);
    expect(
      game.chronicle.any((entry) => entry.text.contains('曹操 历练有成')),
      isTrue,
    );

    GrowthService.award(game, free, 500);
    expect(free.xp, 0);
    GrowthService.award(game, null, 500);
  });

  test('内政让太守积累历练，战斗按胜负分配历练', () {
    final controller = _newGame();
    final game = controller.game;
    final city = game.cities['xuchang']!;
    final governor = game.governorOf(city)!;
    final before = governor.xp;

    controller.selectCity(city.id);
    expect(controller.issueOrder(CityAction.reclaim).success, isTrue);
    expect(governor.xp, before + GrowthService.affairXp);

    final source = game.cities['puyang']!;
    final target = game.cities['pingyuan']!;
    final attacker = game.generals['xuchu']!;
    final defender = game.defenderOf(target)!;
    controller.prepareBattle(
      source: source,
      target: target,
      general: attacker,
      troops: 3000,
    );
    controller.finishPlayerBattle(
      const BattleResult(
        attackerWon: true,
        retreated: false,
        attackerRemaining: 1800,
        defenderRemaining: 0,
        attackerLosses: 1200,
        defenderLosses: 3200,
      ),
    );
    expect(attacker.xp, GrowthService.captureXp);
    expect(defender.xp, GrowthService.defeatXp);
  });

  test('击退来敌时守将历练更多', () {
    final controller = _newGame();
    final game = controller.game;
    final source = game.cities['wan']!;
    final target = game.cities['xinye']!;
    final attacker = game.generals['caoren']!;
    final defender = game.defenderOf(target)!;

    CampaignService.applyResult(
      state: game,
      source: source,
      target: target,
      general: attacker,
      result: const BattleResult(
        attackerWon: false,
        retreated: false,
        attackerRemaining: 700,
        defenderRemaining: 1900,
        attackerLosses: 1300,
        defenderLosses: 500,
      ),
      attackerFaction: 'wei',
      random: Random(3),
    );
    expect(defender.xp, GrowthService.repelXp);
    expect(attacker.xp, GrowthService.defeatXp);
  });

  test('犒赏三军花金提升全城忠诚，忠诚满百不再累加', () {
    final controller = _newGame();
    final game = controller.game;
    final city = game.cities['xuchang']!;
    controller.selectCity(city.id);
    final residents = game.residentsOf(city);
    expect(residents, isNotEmpty);
    for (final general in residents) {
      general.loyalty = general.id == 'xunyu' ? 99 : 60;
    }
    final gold = game.player.gold;

    final result = controller.rewardTroops();
    expect(result.success, isTrue);
    expect(game.player.gold, gold - OrderService.rewardCost);
    expect(residents.every((general) => general.loyalty > 60), isTrue);
    expect(game.generals['xunyu']!.loyalty, 100);
    expect(
      game.chronicle.any((entry) => entry.text.contains('犒赏三军')),
      isTrue,
    );

    for (final general in residents) {
      general.loyalty = 100;
    }
    expect(controller.rewardTroops().success, isFalse);
  });

  test('金钱不足或城中无将时不可犒赏', () {
    final controller = _newGame();
    final game = controller.game;
    game.player.gold = 10;
    controller.selectCity('xuchang');
    expect(controller.rewardTroops().success, isFalse);

    game.player.gold = 9999;
    final empty = game.cities['puyang']!;
    empty.generalIds.clear();
    empty.governor = null;
    controller.selectCity(empty.id);
    expect(controller.rewardTroops().success, isFalse);
  });

  test('历练随存档往返，旧存档缺少历练时从一级起算', () {
    final controller = _newGame();
    final game = controller.game;
    game.generals['xuchu']!.xp = 240;
    final encoded = SaveCodec.encode(game);
    final restored = SaveCodec.decode(encoded);
    expect(restored.generals['xuchu']!.xp, 240);
    expect(restored.generals['xuchu']!.level, 3);

    final raw = jsonDecode(encoded) as Map<String, dynamic>;
    final generals = raw['generals'] as Map<String, dynamic>;
    generals['xuchu'] = (generals['xuchu'] as List).sublist(0, 3);
    final legacy = SaveCodec.decode(jsonEncode(raw));
    expect(legacy.generals['xuchu']!.xp, 0);
    expect(legacy.generals['xuchu']!.level, 1);
  });

  testWidgets('宽屏人事面板可犒赏三军', (tester) async {
    tester.view.physicalSize = const Size(900, 1600);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final controller = _newGame();
    final city = controller.game.cities['xuchang']!;
    controller.selectCity(city.id);
    final gold = controller.game.player.gold;
    await tester.pumpWidget(
      _host((context) => showAppointmentSheet(context, controller, city)),
    );
    await tester.tap(find.text('打开'));
    await tester.pumpAndSettle();

    expect(find.textContaining('Lv.1 新锐'), findsWidgets);
    expect(find.textContaining('忠 '), findsWidgets);
    await tester.tap(find.textContaining('犒赏三军'));
    await tester.pumpAndSettle();
    expect(controller.game.player.gold, gold - OrderService.rewardCost);
  });

  testWidgets('窄屏人事面板不溢出，犒赏按钮仍可点击', (tester) async {
    tester.view.physicalSize = const Size(360, 640);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final controller = _newGame();
    final city = controller.game.cities['xuchang']!;
    controller.selectCity(city.id);
    await tester.pumpWidget(
      _host((context) => showAppointmentSheet(context, controller, city)),
    );
    await tester.tap(find.text('打开'));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    expect(find.textContaining('犒赏三军'), findsOneWidget);
  });
}
