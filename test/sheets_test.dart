import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:flutter_3_kingdoms/game/game_controller.dart';
import 'package:flutter_3_kingdoms/game/orders.dart';
import 'package:flutter_3_kingdoms/models/faction.dart';
import 'package:flutter_3_kingdoms/pages/widgets/game_sheets.dart';

GameController _newGame() => GameController(factionId: 'wei', seed: 13);

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
  testWidgets('内政面板列出六令并在下令后置灰', (tester) async {
    tester.view.physicalSize = const Size(900, 1400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final controller = _newGame();
    final city = controller.game.cities['xuchang']!;
    controller.selectCity(city.id);
    CityAction? chosen;
    await tester.pumpWidget(
      _host((context) async {
        chosen = await showInternalAffairsSheet(context, controller, city);
      }),
    );
    await tester.tap(find.text('打开'));
    await tester.pumpAndSettle();

    expect(find.text('许昌 · 内政'), findsOneWidget);
    expect(find.text('本月可下令'), findsOneWidget);
    for (final action in CityAction.values) {
      expect(find.text(action.label), findsOneWidget);
    }

    await tester.tap(find.text('开垦'));
    await tester.pumpAndSettle();
    expect(chosen, CityAction.reclaim);
    expect(controller.issueOrder(chosen!).success, isTrue);
    expect(city.acted, isTrue);
  });

  testWidgets('出征面板展示守军、主将与胜算', (tester) async {
    tester.view.physicalSize = const Size(900, 1600);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final controller = _newGame();
    final source = controller.game.cities['puyang']!;
    final target = controller.game.cities['pingyuan']!;
    await tester.pumpWidget(
      _host((context) => showCampaignSheet(context, controller, source)),
    );
    await tester.tap(find.text('打开'));
    await tester.pumpAndSettle();

    expect(find.text('濮阳 · 出征'), findsOneWidget);
    expect(find.textContaining('守军'), findsOneWidget);
    expect(find.textContaining(target.name), findsWidgets);
    final verdicts = {'胜算颇高', '势均力敌', '凶多吉少'};
    expect(
      find.byWidgetPredicate(
        (widget) => widget is Text && verdicts.contains(widget.data),
      ),
      findsOneWidget,
    );
    expect(find.textContaining('兵发'), findsOneWidget);
  });

  testWidgets('势力总览列出五方与存亡状态', (tester) async {
    tester.view.physicalSize = const Size(900, 1600);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final controller = _newGame();
    await tester.pumpWidget(
      _host((context) => showFactionOverviewSheet(context, controller)),
    );
    await tester.tap(find.text('打开'));
    await tester.pumpAndSettle();

    expect(find.text('天下势力'), findsOneWidget);
    for (final def in FactionDefs.all) {
      expect(find.text('${def.ruler} · ${def.name}'), findsOneWidget);
    }
    expect(find.text('我方'), findsOneWidget);
    expect(find.text('遣使'), findsWidgets);
  });

  testWidgets('遣使对话框列出停战、联姻与劝降', (tester) async {
    tester.view.physicalSize = const Size(900, 1600);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final controller = _newGame();
    await tester.pumpWidget(
      _host((context) => showFactionOverviewSheet(context, controller)),
    );
    await tester.tap(find.text('打开'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('遣使').first);
    await tester.pumpAndSettle();

    expect(find.textContaining('停战 · '), findsOneWidget);
    expect(find.textContaining('联姻 · '), findsOneWidget);
    expect(find.textContaining('劝降 · '), findsOneWidget);
    expect(find.textContaining('成算'), findsWidgets);
  });
}
