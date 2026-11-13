import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:flutter_3_kingdoms/models/battle.dart';
import 'package:flutter_3_kingdoms/models/city.dart';
import 'package:flutter_3_kingdoms/pages/widgets/battle_widgets.dart';
import 'package:flutter_3_kingdoms/pages/widgets/common.dart';
import 'package:flutter_3_kingdoms/utils/formatters.dart';

BattleSide _side({int troops = 800, int initial = 1000}) => BattleSide(
  factionId: 'wei',
  cityId: 'puyang',
  cityName: '濮阳',
  generalName: '许褚',
  lead: 72,
  wu: 96,
  intel: 35,
  training: 62,
  defense: 0,
  troops: troops,
  morale: 96,
  terrain: Terrain.plain,
  attacking: true,
);

void main() {
  test('兵力简写按千、万分档', () {
    expect(formatTroopsCompact(0), '0');
    expect(formatTroopsCompact(999), '999');
    expect(formatTroopsCompact(1000), '1.0千');
    expect(formatTroopsCompact(1250), '1.3千');
    expect(formatTroopsCompact(9999), '10.0千');
    expect(formatTroopsCompact(10000), '1.0万');
    expect(formatTroopsCompact(123456), '12.3万');
  });

  testWidgets('面板骨架统一渲染标题、副标题与右侧信息', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: SheetFrame(
            title: '许昌 · 内政',
            subtitle: '每城每月限一条指令',
            trailing: Text('本月可下令'),
            child: Text('正文'),
          ),
        ),
      ),
    );

    expect(find.text('许昌 · 内政'), findsOneWidget);
    expect(find.text('每城每月限一条指令'), findsOneWidget);
    expect(find.text('本月可下令'), findsOneWidget);
    expect(find.text('正文'), findsOneWidget);
    expect(find.byType(SafeArea), findsOneWidget);
  });

  testWidgets('面板骨架可滚动，长内容不溢出', (tester) async {
    tester.view.physicalSize = const Size(400, 320);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SheetFrame(
            title: '滚动面板',
            scrollable: true,
            child: Column(
              children: [for (var i = 0; i < 40; i++) Text('第 $i 行')],
            ),
          ),
        ),
      ),
    );

    expect(tester.takeException(), isNull);
    expect(find.text('第 0 行'), findsOneWidget);
    await tester.drag(
      find.byType(SingleChildScrollView),
      const Offset(0, -600),
    );
    await tester.pump();
    expect(find.text('第 39 行'), findsOneWidget);
  });

  testWidgets('战斗营寨卡展示兵力、兵种与士气', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: BattleCampCard(side: _side(), label: '攻方', alignEnd: false),
        ),
      ),
    );

    expect(find.text('攻方 · 濮阳'), findsOneWidget);
    expect(find.text('800'), findsOneWidget);
    expect(find.text('士气 96 · 训练 62 · 城防 0'), findsOneWidget);
    expect(find.text('步兵'), findsOneWidget);
    expect(find.byType(LinearProgressIndicator), findsOneWidget);
  });

  testWidgets('战术按钮可点击并带说明', (tester) async {
    BattleTactic? chosen;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Center(
            child: BattleTacticButton(
              tactic: BattleTactic.fire,
              onPressed: () => chosen = BattleTactic.fire,
            ),
          ),
        ),
      ),
    );

    expect(find.text('火攻'), findsOneWidget);
    expect(find.byTooltip('纵火焚营，智力越高越见效'), findsOneWidget);
    await tester.tap(find.text('火攻'));
    expect(chosen, BattleTactic.fire);
  });
}
