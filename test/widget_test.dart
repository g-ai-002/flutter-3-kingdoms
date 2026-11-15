import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:flutter_3_kingdoms/game/data/scenario.dart';
import 'package:flutter_3_kingdoms/game/game_controller.dart';
import 'package:flutter_3_kingdoms/pages/home_page.dart';
import 'package:flutter_3_kingdoms/pages/settings_page.dart';
import 'package:flutter_3_kingdoms/pages/widgets/city_info_card.dart';
import 'package:flutter_3_kingdoms/pages/widgets/map_preview.dart';
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

  testWidgets('首页内容在屏幕可容纳时垂直居中', (tester) async {
    final settings = await _settings();
    tester.view.physicalSize = const Size(1200, 1600);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(_app(settings, const HomePage()));
    await tester.pump();

    final box = tester.renderObject<RenderBox>(
      find.byKey(const ValueKey('home-center')),
    );
    final top = box.localToGlobal(Offset.zero).dy;
    expect((top + top + box.size.height) / 2, closeTo(800, 10));
  });

  testWidgets('选择势力与无关设置都不重建首页主视觉', (tester) async {
    final settings = await _settings();
    tester.view.physicalSize = const Size(1200, 1400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(_app(settings, const HomePage()));
    await tester.pump();

    final preview = tester.widget<MapPreview>(find.byType(MapPreview));
    await tester.tap(find.text('刘备 · 蜀'));
    await tester.pump();
    expect(find.text('以 刘备 之名起兵'), findsOneWidget);
    expect(
      identical(tester.widget<MapPreview>(find.byType(MapPreview)), preview),
      isTrue,
      reason: '点选势力只重建势力面板',
    );

    await settings.setSoundEnabled(false);
    await tester.pump();
    expect(
      identical(tester.widget<MapPreview>(find.byType(MapPreview)), preview),
      isTrue,
      reason: '音效开关与首页布局无关',
    );
  });

  testWidgets('首页可切换剧本与开局钱粮', (tester) async {
    final settings = await _settings();
    tester.view.physicalSize = const Size(1200, 1400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(_app(settings, const HomePage()));
    await tester.pump();

    expect(find.text('群雄割据'), findsWidgets);
    await tester.tap(find.text('官渡对峙'));
    await tester.pumpAndSettle();
    expect(settings.scenario.id, 'guandu');
    expect(find.text('剧本 · 200年2月'), findsOneWidget);
    expect(find.text('6 城'), findsOneWidget);

    await tester.tap(find.text('丰饶'));
    await tester.pumpAndSettle();
    expect(settings.supply, StartSupply.rich);
    expect(find.text('金 2160'), findsOneWidget);
  });

  testWidgets('窄屏首页开局设定不溢出', (tester) async {
    final settings = await _settings();
    tester.view.physicalSize = const Size(360, 800);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(_app(settings, const HomePage()));
    await tester.pump();

    expect(find.text('剧本 · 196年1月'), findsOneWidget);
    await tester.ensureVisible(find.text('三分天下'));
    await tester.tap(find.text('三分天下'));
    await tester.pumpAndSettle();
    expect(find.text('剧本 · 220年4月'), findsOneWidget);
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
