import 'dart:ui' as ui;

import 'package:flame/game.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:flutter_3_kingdoms/app.dart';
import 'package:flutter_3_kingdoms/flame/map_component.dart';
import 'package:flutter_3_kingdoms/flame/sanguo_game.dart';
import 'package:flutter_3_kingdoms/game/game_controller.dart';
import 'package:flutter_3_kingdoms/game/orders.dart';
import 'package:flutter_3_kingdoms/game/save_codec.dart';
import 'package:flutter_3_kingdoms/models/chronicle.dart';
import 'package:flutter_3_kingdoms/models/game_state.dart';
import 'package:flutter_3_kingdoms/pages/game_page.dart';
import 'package:flutter_3_kingdoms/pages/home_page.dart';
import 'package:flutter_3_kingdoms/pages/widgets/map_hud.dart';
import 'package:flutter_3_kingdoms/providers/settings_provider.dart';
import 'package:flutter_3_kingdoms/services/save_service.dart';
import 'package:flutter_3_kingdoms/services/storage_service.dart';
import 'package:flutter_3_kingdoms/services/tone_synth.dart';
import 'package:flutter_3_kingdoms/theme/map_painting.dart';
import 'package:flutter_3_kingdoms/utils/logic_rate.dart';

void main() {
  test('月度收支一次汇总与逐项求和一致', () {
    final game = GameController(factionId: 'wei', seed: 11).game;
    final cities = game.citiesOf('wei').toList();
    final economy = game.economyOf('wei');
    expect(
      economy.gold,
      cities.fold<int>(0, (sum, city) => sum + city.goldIncome),
    );
    expect(
      economy.food,
      cities.fold<int>(0, (sum, city) => sum + city.foodIncome),
    );
    expect(economy.upkeep, game.upkeepOf('wei'));

    final empty = game.economyOf('none');
    expect(empty.gold, 0);
    expect(empty.food, 0);
    expect(empty.upkeep, 0);
  });

  test('选中城池不推进修订号，数据变更才推进', () {
    final controller = GameController(factionId: 'wei', seed: 5);
    controller.selectCity('xuchang');
    final base = controller.revision;
    controller.selectCity('puyang');
    controller.selectCity(null);
    controller.selectCity('puyang');
    expect(controller.revision, base);

    final result = controller.issueOrder(CityAction.reclaim);
    expect(result.success, isTrue);
    expect(controller.revision, base + 1);

    final beforeTurn = controller.revision;
    controller.endTurn();
    expect(controller.revision, beforeTurn + 1);
  });

  test('选中城池只走选中通道，数据变更才通知控制器', () {
    final controller = GameController(factionId: 'wei', seed: 5);
    addTearDown(controller.dispose);
    var dataEvents = 0;
    var selectionEvents = 0;
    controller.addListener(() => dataEvents++);
    controller.selection.addListener(() => selectionEvents++);

    controller.selectCity('xuchang');
    expect(selectionEvents, 1);
    expect(dataEvents, 0);
    controller.selectCity('xuchang');
    expect(selectionEvents, 1);

    expect(controller.issueOrder(CityAction.reclaim).success, isTrue);
    expect(dataEvents, 1);
    expect(controller.revision, 1);

    controller.endTurn();
    expect(dataEvents, 2);
    expect(controller.selectedCityId, isNull);
  });

  testWidgets('弹层覆盖按层数暂停与恢复地图引擎', (tester) async {
    final game = SanguoGame(
      controller: GameController(factionId: 'wei', seed: 2),
      brightness: Brightness.light,
    );
    expect(game.paused, isFalse);
    game.pauseForCover();
    expect(game.paused, isTrue);
    game.pauseForCover();
    game.resumeAfterCover();
    expect(game.paused, isTrue);
    game.resumeAfterCover();
    expect(game.paused, isFalse);
    game.onDispose();
  });

  testWidgets('地图地形、徽记与选中层分别缓存，内政不重录地图', (tester) async {
    final controller = GameController(factionId: 'wei', seed: 3);
    final brightness = ValueNotifier(Brightness.light);
    addTearDown(brightness.dispose);
    final map = MapComponent(controller: controller, brightness: brightness)
      ..size = Vector2(1200, 760);
    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder);

    map.render(canvas);
    expect(map.terrainLayerBuilds, 1);
    expect(map.roadLayerBuilds, 1);
    expect(map.badgeLayerBuilds, 1);
    expect(map.selectionLayerBuilds, 0);
    expect(map.painted, isTrue);

    map.render(canvas);
    expect(map.terrainLayerBuilds, 1);
    expect(map.roadLayerBuilds, 1);
    expect(map.badgeLayerBuilds, 1);

    controller.selectCity('xuchang');
    map.render(canvas);
    expect(map.roadLayerBuilds, 1);
    expect(map.badgeLayerBuilds, 1);
    expect(map.selectionLayerBuilds, 1);

    // 征兵只改兵数：徽记按兵数档位重录，驿道与选中装饰不受影响。
    final before = controller.game.cities['xuchang']!.troops;
    expect(controller.issueOrder(CityAction.recruit).success, isTrue);
    expect(controller.game.cities['xuchang']!.troops, greaterThan(before));
    map.render(canvas);
    expect(map.roadLayerBuilds, 1);
    expect(map.badgeLayerBuilds, 2);
    expect(map.selectionLayerBuilds, 1);

    // 换太守会改变徽记上的金印，但驿道与选中层只跟归属，无需重录。
    controller.appointGovernor('xunyu');
    map.render(canvas);
    expect(map.roadLayerBuilds, 1);
    expect(map.badgeLayerBuilds, 3);
    expect(map.selectionLayerBuilds, 1);

    // 换选中城池只重录选中层。
    controller.selectCity('puyang');
    map.render(canvas);
    expect(map.roadLayerBuilds, 1);
    expect(map.badgeLayerBuilds, 3);
    expect(map.selectionLayerBuilds, 2);

    // 城池易主同时改变驿道配色、徽记与选中层的可进攻目标环。
    controller.game.cities['pingyuan']!.owner = 'wei';
    expect(controller.issueOrder(CityAction.trade).success, isTrue);
    map.render(canvas);
    expect(map.roadLayerBuilds, 2);
    expect(map.badgeLayerBuilds, 4);
    expect(map.selectionLayerBuilds, 3);

    // 主题切换才重录地形，其余三层跟着换色。
    brightness.value = Brightness.dark;
    map.render(canvas);
    expect(map.terrainLayerBuilds, 2);
    expect(map.roadLayerBuilds, 3);
    expect(map.badgeLayerBuilds, 5);
    expect(map.selectionLayerBuilds, 4);

    recorder.endRecording().dispose();
  });

  test('战报在内存中封顶，存档只写最近的尾部', () {
    final game = GameController(factionId: 'wei', seed: 2).game;
    for (var i = 0; i < 1000; i++) {
      game.addChronicle('第 $i 月军报', ChronicleKind.system);
    }
    expect(
      game.chronicle.length,
      lessThanOrEqualTo(GameState.chronicleLimit * 2),
    );
    expect(game.chronicle.last.text, '第 999 月军报');
    expect(game.recentChronicle.length, GameState.chronicleLimit);

    final restored = SaveCodec.decode(SaveCodec.encode(game));
    expect(restored.chronicle.length, GameState.chronicleLimit);
    expect(restored.chronicle.last.text, '第 999 月军报');
  });

  test('切换逻辑帧率后地图按新的固定步长推进动画', () {
    final controller = GameController(factionId: 'wei', seed: 3);
    final brightness = ValueNotifier(Brightness.light);
    addTearDown(brightness.dispose);
    final map = MapComponent(
      controller: controller,
      brightness: brightness,
      logicRate: LogicRate.hz30,
    )..size = Vector2(1200, 760);

    map.update(1 / 60);
    expect(map.animationTime, 0);
    map.update(1 / 60);
    expect(map.animationTime, closeTo(1 / 30, 1e-9));

    // 对局中切到 120Hz，步长立即变细，累积时间继续推进。
    map.logicRate = LogicRate.hz120;
    map.update(1 / 120);
    expect(map.animationTime, closeTo(1 / 30 + 1 / 120, 1e-9));
  });

  test('未选中城池时数据变化只重绘一帧，选中时脉冲播完即停', () {
    final policy = MapIdlePolicy();
    expect(policy.pulse, isTrue);

    // 没有选中城池：唤醒后第一帧即可停帧。
    expect(policy.tick(1 / 60, selected: false), isTrue);
    expect(policy.pulse, isFalse);

    // 选中城池：脉冲持续 pulseSeconds，期间不停帧。
    policy.wake();
    expect(policy.tick(1.0, selected: true), isFalse);
    expect(policy.pulse, isTrue);
    expect(policy.tick(1.5, selected: true), isTrue);
    expect(policy.pulse, isFalse);

    // 脉冲结束后保持停帧，不再逐帧空转。
    expect(policy.tick(0.2, selected: true), isTrue);
    policy.wake();
    expect(policy.tick(0.016, selected: true), isFalse);
  });

  testWidgets('地图绘出首帧后停帧，选中城池时按脉冲重新唤醒', (tester) async {
    final controller = GameController(factionId: 'wei', seed: 3);
    final game = SanguoGame(
      controller: controller,
      brightness: Brightness.light,
      changes: controller.selection,
    );
    addTearDown(controller.dispose);

    await tester.pumpWidget(GameWidget(game: game));
    await tester.pump();
    expect(game.paused, isFalse, reason: '首帧尚未画出地图，不能提前停帧');
    await tester.pump(const Duration(milliseconds: 16));
    expect(game.paused, isTrue, reason: '静止画面绘制完即停帧');

    controller.selectCity('xuchang');
    await tester.pump(const Duration(milliseconds: 16));
    expect(game.paused, isFalse, reason: '选中后的脉冲仍在播放');

    for (var i = 0; i < 20; i++) {
      await tester.pump(const Duration(milliseconds: 160));
    }
    expect(game.paused, isTrue, reason: '脉冲播完回到停帧');

    // 数据变化再次唤醒，绘制一帧后继续停帧。
    expect(controller.issueOrder(CityAction.reclaim).success, isTrue);
    await tester.pump(const Duration(milliseconds: 16));
    expect(game.paused, isTrue);

    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump();
  });

  test('城名与兵数标签按主题缓存，深浅色来回切换不再重排文字', () {
    final controller = GameController(factionId: 'wei', seed: 3);
    final brightness = ValueNotifier(Brightness.light);
    addTearDown(brightness.dispose);
    final map = MapComponent(controller: controller, brightness: brightness)
      ..size = Vector2(1200, 760);
    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder);

    map.render(canvas);
    final names = map.cityNameLayouts;
    final troops = map.troopLabelLayouts;
    expect(names, controller.game.totalCities);

    brightness.value = Brightness.dark;
    map.render(canvas);
    expect(map.cityNameLayouts, names, reason: '城名配色与主题无关，不该重排');
    expect(map.troopLabelLayouts, greaterThan(troops), reason: '深色兵数标签另存一份');

    final darkTroops = map.troopLabelLayouts;
    brightness.value = Brightness.light;
    map.render(canvas);
    expect(map.cityNameLayouts, names);
    expect(map.troopLabelLayouts, darkTroops, reason: '浅色标签已缓存，切回不再排版');

    // 小屏放大字面属于字号变化，这时才重排全部城名。
    map.size = Vector2(600, 380);
    map.render(canvas);
    expect(map.cityNameLayouts, greaterThan(names));

    recorder.endRecording().dispose();
  });

  testWidgets('同一局面只写一次自动存档，退出对局不重复写盘', (tester) async {
    SharedPreferences.setMockInitialValues({});
    StorageService.resetForTests();
    SaveService.writeCount = 0;
    final settings = SettingsProvider(await StorageService.instance);
    tester.view.physicalSize = const Size(1200, 800);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final controller = GameController(factionId: 'wei', seed: 3);
    addTearDown(controller.dispose);
    await tester.pumpWidget(
      ChangeNotifierProvider<SettingsProvider>.value(
        value: settings,
        child: MaterialApp(home: GamePage(controller: controller)),
      ),
    );
    await tester.pump();
    // 进入对局时首页刚写过自动存档，退出页面不必原样再写一遍。
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump(const Duration(milliseconds: 10));
    expect(SaveService.writeCount, 0);

    // 局面推进过才写：结束本月改动了年份与钱粮。
    final next = GameController(factionId: 'wei', seed: 4);
    addTearDown(next.dispose);
    await tester.pumpWidget(
      ChangeNotifierProvider<SettingsProvider>.value(
        value: settings,
        child: MaterialApp(home: GamePage(controller: next)),
      ),
    );
    await tester.pump();
    next.endTurn();
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump(const Duration(milliseconds: 10));
    expect(SaveService.writeCount, 1);
  });

  test('州名水印文字按主题缓存，重复绘制不再排版', () {
    const font = 'CacheProbeFont';
    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder);
    final before = regionPainterCount;

    paintMapBackground(
      canvas,
      const Size(1200, 760),
      MapPalette.light,
      fontFamily: font,
    );
    final afterFirst = regionPainterCount;
    expect(afterFirst, before + kRegionLabels.length);

    paintMapBackground(
      canvas,
      const Size(1200, 760),
      MapPalette.light,
      fontFamily: font,
    );
    expect(regionPainterCount, afterFirst);

    paintMapBackground(
      canvas,
      const Size(1200, 760),
      MapPalette.dark,
      fontFamily: font,
    );
    expect(regionPainterCount, afterFirst + kRegionLabels.length);
    recorder.endRecording().dispose();
  });

  testWidgets('设置变更不重建应用外壳，只有深浅色切换才重建', (tester) async {
    SharedPreferences.setMockInitialValues({});
    StorageService.resetForTests();
    final storage = await StorageService.instance;
    await tester.pumpWidget(SanguoApp(storage: storage));
    await tester.pump();

    final settings = Provider.of<SettingsProvider>(
      tester.element(find.byType(HomePage)),
      listen: false,
    );
    final shell = tester.widget<MaterialApp>(find.byType(MaterialApp));

    // 音效、难度等设置不改变主题：外壳与 ThemeData 实例保持不变。
    await settings.setSoundEnabled(false);
    await tester.pump();
    expect(
      identical(tester.widget<MaterialApp>(find.byType(MaterialApp)), shell),
      isTrue,
    );
    expect(
      identical(
        tester.widget<MaterialApp>(find.byType(MaterialApp)).theme,
        shell.theme,
      ),
      isTrue,
      reason: '主题对象只构建一次',
    );

    await settings.setDarkMode(true);
    await tester.pump();
    final dark = tester.widget<MaterialApp>(find.byType(MaterialApp));
    expect(identical(dark, shell), isFalse);
    expect(dark.themeMode, ThemeMode.dark);
    expect(identical(dark.darkTheme, shell.darkTheme), isTrue);

    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump();
  });

  testWidgets('对局页不因设置重建地图与 HUD，切帧率直接写进对局', (tester) async {
    SharedPreferences.setMockInitialValues({});
    StorageService.resetForTests();
    final settings = SettingsProvider(await StorageService.instance);
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
    final hud = tester.widget<MapHud>(find.byType(MapHud));
    final game = tester
        .widget<GameWidget<SanguoGame>>(
          find.byKey(const ValueKey('sanguo-map')),
        )
        .game!;

    await settings.setSoundEnabled(false);
    await tester.pump();
    expect(identical(tester.widget<MapHud>(find.byType(MapHud)), hud), isTrue);

    // 帧率变更只写到引擎，地图与 HUD 仍不重建。
    await settings.setLogicRate(LogicRate.hz120);
    await tester.pump();
    expect(game.logicRate, LogicRate.hz120);
    expect(identical(tester.widget<MapHud>(find.byType(MapHud)), hud), isTrue);

    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump();
  });

  test('后台合成与主线程合成的音效字节一致', () async {
    const notes = [
      SynthNote(frequency: 880, start: 0, duration: 0.05, gain: 0.5),
      SynthNote(frequency: 440, start: 0.03, duration: 0.04, gain: 0.3),
    ];
    final sync = synthesizeWav(notes);
    final async = await synthesizeWavAsync(notes);
    expect(async, sync);

    final batch = await synthesizeWavBatchAsync([notes, notes]);
    expect(batch, hasLength(2));
    expect(batch[0], sync);
    expect(batch[1], sync);

    final music = await synthesizeMusicWavAsync(sampleRate: 4000);
    expect(music.length, greaterThan(44));
  });
}
