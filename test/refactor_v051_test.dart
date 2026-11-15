import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';

import 'package:flutter_3_kingdoms/game/data/scenario.dart';
import 'package:flutter_3_kingdoms/game/game_controller.dart';
import 'package:flutter_3_kingdoms/game/orders.dart';
import 'package:flutter_3_kingdoms/game/turn.dart';
import 'package:flutter_3_kingdoms/models/difficulty.dart';
import 'package:flutter_3_kingdoms/models/game_state.dart';
import 'package:flutter_3_kingdoms/pages/widgets/common.dart';
import 'package:flutter_3_kingdoms/pages/widgets/game_hud.dart';
import 'package:flutter_3_kingdoms/pages/widgets/home_widgets.dart';

class _MinRandom implements Random {
  @override
  bool nextBool() => false;

  @override
  double nextDouble() => 0.0;

  @override
  int nextInt(int max) => 0;
}

GameState _newState({Difficulty difficulty = Difficulty.normal}) =>
    Scenario.build(playerFaction: 'wei', difficulty: difficulty);

void main() {
  test('月度收束按难度倍率结算钱粮并恢复各城指令', () {
    final state = _newState(difficulty: Difficulty.hard);
    final economy = state.economyOf('wei');
    final gold = state.player.gold;
    final food = state.player.food;
    state.cities['xuchang']!.acted = true;

    TurnService.settle(state);
    expect(
      state.player.gold,
      gold + (economy.gold * Difficulty.hard.playerIncome).round(),
    );
    expect(
      state.player.food,
      food + (economy.food * Difficulty.hard.playerIncome).round() -
          economy.upkeep,
    );

    TurnService.advance(state);
    expect(state.month, 2);
    expect(state.cities.values.every((city) => !city.acted), isTrue);
  });

  test('粮草见底时按城逃兵、治安下滑并记录事件', () {
    final state = _newState();
    final city = state.cities['xuchang']!..troops = 400000;
    final troops = city.troops;
    final order = city.order;
    state.player.food = 0;

    TurnService.settle(state);

    expect(state.player.food, 0);
    expect(city.troops, lessThan(troops));
    expect(city.order, lessThan(order));
    expect(
      state.chronicle.where((entry) => entry.text.contains('粮草告罄')),
      isNotEmpty,
    );
  });

  test('胜负判定只写一次结局，重复调用不再改写', () {
    final state = _newState();
    for (final city in state.cities.values) {
      city.owner = 'wei';
    }
    TurnService.checkVictory(state);
    expect(state.finished, isTrue);
    expect(state.outcome, GameOutcome.victory);
    final entries = state.chronicle
        .where((entry) => entry.text.contains('一统山河'))
        .length;

    TurnService.checkVictory(state);
    expect(
      state.chronicle.where((entry) => entry.text.contains('一统山河')).length,
      entries,
    );
  });

  test('内政增益共用一条公式，政治与特长叠加到上限', () {
    final state = _newState();
    final city = state.cities['xuchang']!..order = 50;
    OrderService.appointGovernor(city, 'xunyu');

    final result = OrderService.apply(
      state,
      city,
      CityAction.patrol,
      _MinRandom(),
    );

    expect(result.success, isTrue);
    expect(city.order, 59);
    expect(result.message, contains('治安 +9'));
  });

  testWidgets('对局操作条按选中城池开关指令，结束后锁定', (tester) async {
    tester.view.physicalSize = const Size(900, 800);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final controller = GameController(factionId: 'wei', seed: 4);
    addTearDown(controller.dispose);
    controller.selectCity('xuchang');
    final changes = Listenable.merge([controller, controller.selection]);
    String? internalCity;
    var ended = 0;

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Align(
            alignment: Alignment.topLeft,
            child: AnimatedBuilder(
              animation: changes,
              builder: (context, _) => GameControls(
                controller: controller,
                onInternal: (city) => internalCity = city.id,
                onCampaign: (source, {preferred}) {},
                onAppoint: (_) {},
                onEndTurn: () => ended++,
                onFactions: () {},
                onChronicle: () {},
                onAttackSource: (_) => null,
              ),
            ),
          ),
        ),
      ),
    );

    expect(find.text('内政'), findsOneWidget);
    await tester.tap(find.text('内政'));
    expect(internalCity, 'xuchang');
    await tester.tap(find.text('结束本月'));
    expect(ended, 1);

    controller.game.cities['xuchang']!.acted = true;
    controller.appointGovernor('xunyu');
    await tester.pump();
    final internal = tester.widget<TextButton>(
      find.widgetWithText(TextButton, '内政'),
    );
    expect(internal.onPressed, isNull);

    controller.game.finished = true;
    controller.appointGovernor('xunyu');
    await tester.pump();
    final endTurn = tester.widget<FilledButton>(
      find.widgetWithText(FilledButton, '结束本月'),
    );
    expect(endTurn.onPressed, isNull);
  });

  testWidgets('城池信息卡在未选中时给出提示，选中后展开详情', (tester) async {
    final controller = GameController(factionId: 'wei', seed: 4);
    addTearDown(controller.dispose);

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: AnimatedBuilder(
            animation: controller.selection,
            builder: (context, _) => GameInfoPanel(controller: controller),
          ),
        ),
      ),
    );
    expect(find.textContaining('点选城池'), findsOneWidget);

    controller.selectCity('xuchang');
    await tester.pump();
    expect(find.text('许昌'), findsOneWidget);
    expect(find.textContaining('点选城池'), findsNothing);
  });

  testWidgets('轻提示顶掉上一条提示', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) => Scaffold(
            body: Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  FilledButton(
                    onPressed: () => showToast(context, '旧提示'),
                    child: const Text('第一条'),
                  ),
                  FilledButton(
                    onPressed: () => showToast(context, '新提示'),
                    child: const Text('第二条'),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.text('第一条'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    expect(find.text('旧提示'), findsOneWidget);

    await tester.tap(find.text('第二条'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 800));
    expect(find.text('新提示'), findsOneWidget);
    expect(find.text('旧提示'), findsNothing);
  });

  testWidgets('描边与卡片共用圆角，可覆盖强调色与阴影', (tester) async {
    late ShapeBorder shape;
    late BoxDecoration box;
    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) {
            shape = outlinedShape(
              context,
              radius: 9,
              color: Colors.red,
              width: 2,
            );
            box = cardDecoration(
              context,
              radius: 9,
              borderColor: Colors.green,
              shadow: false,
            );
            return const SizedBox.shrink();
          },
        ),
      ),
    );

    expect(shape, isA<RoundedRectangleBorder>());
    final border = (shape as RoundedRectangleBorder);
    expect(border.side.color, Colors.red);
    expect(border.side.width, 2);
    expect(border.borderRadius, BorderRadius.circular(9));
    expect(box.border!.top.color, Colors.green);
    expect(box.boxShadow, isNull);
  });

  testWidgets('首页分段选择器回传选中项', (tester) async {
    Difficulty? picked;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SegmentedPicker<Difficulty>(
            options: Difficulty.values,
            labelOf: (item) => item.label,
            value: Difficulty.normal,
            onChanged: (value) => picked = value,
          ),
        ),
      ),
    );

    await tester.tap(find.text('霸业'));
    await tester.pump();
    expect(picked, Difficulty.hard);
  });

  testWidgets('顶栏图标按钮共用尺寸与点击区', (tester) async {
    var taps = 0;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: HudIconButton(
            icon: Icons.save_outlined,
            tooltip: '存档',
            onPressed: () => taps++,
            size: 18,
            box: 40,
          ),
        ),
      ),
    );

    expect(find.byTooltip('存档'), findsOneWidget);
    expect(tester.getSize(find.byType(IconButton)), const Size(40, 40));
    await tester.tap(find.byTooltip('存档'));
    expect(taps, 1);
  });
}
