import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:flutter_3_kingdoms/game/ai.dart';
import 'package:flutter_3_kingdoms/game/campaign.dart';
import 'package:flutter_3_kingdoms/game/data/scenario.dart';
import 'package:flutter_3_kingdoms/models/battle.dart';
import 'package:flutter_3_kingdoms/models/difficulty.dart';
import 'package:flutter_3_kingdoms/pages/widgets/common.dart';
import 'package:flutter_3_kingdoms/pages/widgets/sheets/save_sheet.dart';

void main() {
  testWidgets('面板开合统一，关闭时把选择带回调用方', (tester) async {
    int? picked;
    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) => Scaffold(
            body: Center(
              child: FilledButton(
                onPressed: () async {
                  picked = await showGameSheet<int>(
                    context,
                    builder: (sheetContext) => SheetFrame(
                      title: '测试面板',
                      child: FilledButton(
                        onPressed: () => Navigator.of(sheetContext).pop(7),
                        child: const Text('确认'),
                      ),
                    ),
                  );
                },
                child: const Text('打开'),
              ),
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.text('打开'));
    await tester.pumpAndSettle();
    expect(find.text('测试面板'), findsOneWidget);
    expect(find.byType(BottomSheet), findsOneWidget);

    await tester.tap(find.text('确认'));
    await tester.pumpAndSettle();
    expect(picked, 7);
  });

  testWidgets('提示小字与无底标签共用一套样式', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: Column(
            children: [
              HintText('分区标题'),
              HintText('空状态正文', body: true),
              InfoChip(text: '兵 800', icon: Icons.groups_outlined, plain: true),
            ],
          ),
        ),
      ),
    );

    expect(find.text('分区标题'), findsOneWidget);
    expect(find.text('空状态正文'), findsOneWidget);
    expect(find.text('兵 800'), findsOneWidget);
    expect(find.byIcon(Icons.groups_outlined), findsOneWidget);
    expect(
      find.descendant(
        of: find.byType(InfoChip),
        matching: find.byType(Container),
      ),
      findsNothing,
    );
  });

  testWidgets('读档面板列出自动存档与三个手动槽位', (tester) async {
    SharedPreferences.setMockInitialValues({});
    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) => Scaffold(
            body: Center(
              child: FilledButton(
                onPressed: () => showLoadSheet(context),
                child: const Text('读档'),
              ),
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.text('读档'));
    await tester.pumpAndSettle();

    expect(find.text('读取存档'), findsOneWidget);
    expect(find.text('自动存档'), findsOneWidget);
    expect(find.text('槽位 1'), findsOneWidget);
    expect(find.text('槽位 3'), findsOneWidget);
    expect(find.text('空槽位'), findsNWidgets(4));
  });

  test('AI 只替非玩家势力行动，不影响玩家城池', () {
    final state = Scenario.build(
      playerFaction: 'wei',
      difficulty: Difficulty.normal,
    );
    AiService.runTurn(state, Random(5));

    expect(state.citiesOf('yuan').any((city) => city.acted), isTrue);
    expect(state.citiesOf('wei').every((city) => !city.acted), isTrue);
  });

  test('出征落账与战果写回共用一套口径', () {
    final state = Scenario.build(
      playerFaction: 'wei',
      difficulty: Difficulty.normal,
    );
    final source = state.cities['puyang']!..troops = 5000;
    final target = state.cities['pingyuan']!;
    final general = state.generals['xuchu']!;

    CampaignService.commitAttack(
      state: state,
      source: source,
      target: target,
      general: general,
      troops: 2000,
    );
    expect(source.troops, 3000);
    expect(source.acted, isTrue);

    CampaignService.applyResult(
      state: state,
      source: source,
      target: target,
      general: general,
      attackerFaction: 'wei',
      random: Random(1),
      result: const BattleResult(
        attackerWon: true,
        retreated: false,
        attackerRemaining: 1500,
        defenderRemaining: 0,
        attackerLosses: 500,
        defenderLosses: 3600,
      ),
    );
    expect(target.owner, 'wei');
    expect(target.troops, 1500);
    expect(target.governor, 'xuchu');
    expect(general.cityId, 'pingyuan');
    expect(state.cityCount('wei'), 8);
  });

  test('战败只把残兵送回原城，城池归属不变', () {
    final state = Scenario.build(
      playerFaction: 'wei',
      difficulty: Difficulty.normal,
    );
    final source = state.cities['puyang']!..troops = 5000;
    final target = state.cities['pingyuan']!;
    final general = state.generals['xuchu']!;

    CampaignService.commitAttack(
      state: state,
      source: source,
      target: target,
      general: general,
      troops: 2000,
    );
    CampaignService.applyResult(
      state: state,
      source: source,
      target: target,
      general: general,
      attackerFaction: 'wei',
      random: Random(2),
      result: const BattleResult(
        attackerWon: false,
        retreated: false,
        attackerRemaining: 800,
        defenderRemaining: 1500,
        attackerLosses: 1200,
        defenderLosses: 900,
      ),
    );
    expect(target.owner, 'yuan');
    expect(target.troops, 1500);
    expect(source.troops, 3800);
    expect(general.cityId, 'puyang');
  });
}
