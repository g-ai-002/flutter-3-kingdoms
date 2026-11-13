import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:flutter_3_kingdoms/game/game_controller.dart';
import 'package:flutter_3_kingdoms/pages/home_page.dart';
import 'package:flutter_3_kingdoms/pages/settings_page.dart';
import 'package:flutter_3_kingdoms/pages/widgets/city_info_card.dart';
import 'package:flutter_3_kingdoms/providers/settings_provider.dart';
import 'package:flutter_3_kingdoms/services/storage_service.dart';

Future<SettingsProvider> _settings() async {
  SharedPreferences.setMockInitialValues({});
  StorageService.resetForTests();
  final storage = await StorageService.instance;
  return SettingsProvider(storage);
}

Widget _app(SettingsProvider settings, Widget home) {
  return ChangeNotifierProvider<SettingsProvider>.value(
    value: settings,
    child: MaterialApp(home: home),
  );
}

void main() {
  testWidgets('首页展示五方势力并响应选择', (tester) async {
    final settings = await _settings();
    tester.view.physicalSize = const Size(1200, 1400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(_app(settings, const HomePage()));
    await tester.pump();

    expect(find.text('三国霸业'), findsWidgets);
    expect(find.text('曹操 · 魏'), findsOneWidget);
    expect(find.text('袁绍 · 袁'), findsOneWidget);
    expect(find.text('以 曹操 之名起兵'), findsOneWidget);

    await tester.tap(find.text('刘备 · 蜀'));
    await tester.pump();
    expect(find.text('以 刘备 之名起兵'), findsOneWidget);
  });

  testWidgets('设置页可切换深色模式与逻辑刷新率', (tester) async {
    final settings = await _settings();
    await tester.pumpWidget(_app(settings, const SettingsPage()));
    await tester.pump();

    expect(settings.darkMode, isFalse);
    await tester.tap(find.text('深色模式'));
    await tester.pump();
    expect(settings.darkMode, isTrue);

    await tester.tap(find.text('120 Hz 顺滑'));
    await tester.pump();
    expect(settings.logicRate.hz, 120);
  });

  testWidgets('城池信息卡展示资源与邻敌', (tester) async {
    final controller = GameController(
      factionId: 'wei',
      seed: 1,
    );
    controller.selectCity('xuchang');
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SingleChildScrollView(
            child: CityInfoCard(
              controller: controller,
              city: controller.game.cities['xuchang']!,
              compact: false,
            ),
          ),
        ),
      ),
    );
    await tester.pump();

    expect(find.text('许昌'), findsOneWidget);
    expect(find.textContaining('太守 曹操'), findsOneWidget);
    expect(find.text('农业'), findsOneWidget);
    expect(find.textContaining('邻敌'), findsNothing);
  });

  testWidgets('紧凑城池条只保留关键信息', (tester) async {
    final controller = GameController(
      factionId: 'wei',
      seed: 1,
    );
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: CityInfoCard(
            controller: controller,
            city: controller.game.cities['puyang']!,
            compact: true,
          ),
        ),
      ),
    );
    await tester.pump();
    expect(find.text('濮阳'), findsOneWidget);
    expect(find.textContaining('邻敌'), findsNothing);
  });
}
