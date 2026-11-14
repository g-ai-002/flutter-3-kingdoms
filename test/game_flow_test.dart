import 'package:flame/game.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:flutter_3_kingdoms/flame/sanguo_game.dart';
import 'package:flutter_3_kingdoms/game/game_controller.dart';
import 'package:flutter_3_kingdoms/models/battle.dart';
import 'package:flutter_3_kingdoms/pages/battle_page.dart';
import 'package:flutter_3_kingdoms/pages/game_page.dart';
import 'package:flutter_3_kingdoms/providers/settings_provider.dart';
import 'package:flutter_3_kingdoms/services/storage_service.dart';
import 'package:flutter_3_kingdoms/utils/logic_rate.dart';

Future<SettingsProvider> _settings() async {
  SharedPreferences.setMockInitialValues({});
  StorageService.resetForTests();
  final storage = await StorageService.instance;
  return SettingsProvider(storage);
}

void main() {
  testWidgets('对局页渲染地图、资源卡与底部操作条', (tester) async {
    final settings = await _settings();
    final controller = GameController(factionId: 'wei', seed: 3);
    tester.view.physicalSize = const Size(1200, 800);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      ChangeNotifierProvider<SettingsProvider>.value(
        value: settings,
        child: MaterialApp(home: GamePage(controller: controller)),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 40));

    expect(find.text('曹操 · 魏'), findsOneWidget);
    expect(find.textContaining('196年'), findsOneWidget);
    expect(find.text('结束本月'), findsOneWidget);
    expect(find.text('势力'), findsOneWidget);

    controller.selectCity('xuchang');
    await tester.pump();
    expect(find.text('许昌'), findsWidgets);
    expect(find.text('内政'), findsOneWidget);
    expect(find.text('人事'), findsOneWidget);

    controller.selectCity('puyang');
    await tester.pump();
    expect(find.text('出征'), findsOneWidget);

    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump();
  });

  testWidgets('手机横屏与竖屏下对局页自适应且不溢出', (tester) async {
    final settings = await _settings();
    for (final size in const [Size(844, 390), Size(390, 844)]) {
      final controller = GameController(factionId: 'wu', seed: 9);
      tester.view.physicalSize = size;
      tester.view.devicePixelRatio = 1.0;
      await tester.pumpWidget(
        ChangeNotifierProvider<SettingsProvider>.value(
          value: settings,
          child: MaterialApp(home: GamePage(controller: controller)),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 40));
      controller.selectCity('jianye');
      await tester.pump();
      expect(find.textContaining('孙权'), findsWidgets);
      final labelled = find.text('内政').evaluate().isNotEmpty;
      final iconOnly = find
          .byIcon(Icons.agriculture_outlined)
          .evaluate()
          .isNotEmpty;
      expect(labelled || iconOnly, isTrue);
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump();
    }
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
  });

  testWidgets('对局中切换逻辑刷新率立即生效', (tester) async {
    final settings = await _settings();
    final controller = GameController(factionId: 'wei', seed: 3);
    tester.view.physicalSize = const Size(1200, 800);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      ChangeNotifierProvider<SettingsProvider>.value(
        value: settings,
        child: MaterialApp(home: GamePage(controller: controller)),
      ),
    );
    await tester.pump();
    final game = tester
        .widget<GameWidget<SanguoGame>>(find.byKey(const ValueKey('sanguo-map')))
        .game!;
    expect(game.logicRate, LogicRate.hz60);

    await settings.setLogicRate(LogicRate.hz120);
    await tester.pump();
    expect(game.logicRate, LogicRate.hz120);

    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump();
  });

  testWidgets('战斗页可逐回合下令并返回结果', (tester) async {
    final controller = GameController(factionId: 'wei', seed: 5);
    final source = controller.game.cities['puyang']!..troops = 9500;
    final target = controller.game.cities['pingyuan']!;
    final prepared = controller.prepareBattle(
      source: source,
      target: target,
      general: controller.game.generals['xuchu'],
      troops: 9000,
    );
    final setup = prepared.setup!;
    BattleResult? received;

    tester.view.physicalSize = const Size(1100, 760);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      MaterialApp(
        home: _BattleHost(setup: setup, onResult: (result) => received = result),
      ),
    );
    await tester.pump();
    await tester.tap(find.text('开战'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));

    expect(find.text('濮阳 攻 平原'), findsOneWidget);
    expect(find.text('强攻'), findsOneWidget);
    expect(find.text('火攻'), findsOneWidget);

    for (var i = 0; i < 40; i++) {
      final assault = find.text('强攻');
      if (assault.evaluate().isEmpty) break;
      await tester.tap(assault);
      await tester.pump();
    }
    expect(find.textContaining('大 捷'), findsOneWidget);
    await tester.tap(find.text('入城安民'));
    await tester.pump();

    expect(received, isNotNull);
    expect(received!.attackerWon, isTrue);
    expect(find.text('战斗结束'), findsOneWidget);
  });
}

class _BattleHost extends StatefulWidget {
  const _BattleHost({required this.setup, required this.onResult});

  final BattleSetup setup;
  final ValueChanged<BattleResult?> onResult;

  @override
  State<_BattleHost> createState() => _BattleHostState();
}

class _BattleHostState extends State<_BattleHost> {
  BattleResult? _result;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: _result != null
            ? const Text('战斗结束')
            : FilledButton(
                onPressed: () async {
                  final result = await Navigator.of(context)
                      .push<BattleResult?>(
                        MaterialPageRoute<BattleResult?>(
                          builder: (_) => BattlePage(setup: widget.setup),
                        ),
                      );
                  widget.onResult(result);
                  if (mounted) setState(() => _result = result);
                },
                child: const Text('开战'),
              ),
      ),
    );
  }
}
