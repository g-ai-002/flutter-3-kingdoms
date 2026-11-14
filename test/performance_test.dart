import 'dart:ui' as ui;

import 'package:flame/components.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:flutter_3_kingdoms/flame/map_component.dart';
import 'package:flutter_3_kingdoms/flame/sanguo_game.dart';
import 'package:flutter_3_kingdoms/game/game_controller.dart';
import 'package:flutter_3_kingdoms/game/orders.dart';
import 'package:flutter_3_kingdoms/game/save_codec.dart';
import 'package:flutter_3_kingdoms/models/chronicle.dart';
import 'package:flutter_3_kingdoms/models/game_state.dart';
import 'package:flutter_3_kingdoms/services/tone_synth.dart';
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

  test('选中脉冲播完后停帧，点击或数据变化重新唤醒', () {
    final policy = MapIdlePolicy();
    expect(policy.pulse, isTrue);

    expect(policy.tick(1.0, selected: true), isFalse);
    expect(policy.pulse, isTrue);
    expect(policy.tick(1.5, selected: true), isFalse);
    expect(policy.pulse, isFalse);
    expect(policy.tick(1.1, selected: true), isFalse);
    expect(policy.tick(0.2, selected: true), isTrue);

    policy.wake();
    expect(policy.pulse, isTrue);
    expect(policy.tick(0.4, selected: true), isFalse);

    // 没有选中城池时不做脉冲，直接按静置时长停帧。
    policy.wake();
    expect(policy.tick(0.6, selected: false), isFalse);
    expect(policy.pulse, isFalse);
    expect(policy.tick(0.7, selected: false), isTrue);
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
