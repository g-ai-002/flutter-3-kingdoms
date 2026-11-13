import 'dart:ui' as ui;

import 'package:flame/components.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:flutter_3_kingdoms/flame/map_component.dart';
import 'package:flutter_3_kingdoms/flame/sanguo_game.dart';
import 'package:flutter_3_kingdoms/game/game_controller.dart';
import 'package:flutter_3_kingdoms/game/orders.dart';
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
    expect(map.badgeLayerBuilds, 1);
    expect(map.selectionLayerBuilds, 0);

    map.render(canvas);
    expect(map.terrainLayerBuilds, 1);
    expect(map.badgeLayerBuilds, 1);

    controller.selectCity('xuchang');
    map.render(canvas);
    expect(map.terrainLayerBuilds, 1);
    expect(map.badgeLayerBuilds, 1);
    expect(map.selectionLayerBuilds, 1);

    // 招商只改商业与钱粮，地图外观未变，三个图层都不重录。
    expect(controller.issueOrder(CityAction.trade).success, isTrue);
    map.render(canvas);
    expect(map.terrainLayerBuilds, 1);
    expect(map.badgeLayerBuilds, 1);
    expect(map.selectionLayerBuilds, 1);

    // 换太守会改变徽记上的金印，徽记与选中层一起重录。
    controller.appointGovernor('xunyu');
    map.render(canvas);
    expect(map.terrainLayerBuilds, 1);
    expect(map.badgeLayerBuilds, 2);
    expect(map.selectionLayerBuilds, 2);

    // 换选中城池只重录选中层。
    controller.selectCity('puyang');
    map.render(canvas);
    expect(map.badgeLayerBuilds, 2);
    expect(map.selectionLayerBuilds, 3);

    // 主题切换才重录地形。
    brightness.value = Brightness.dark;
    map.render(canvas);
    expect(map.terrainLayerBuilds, 2);
    expect(map.badgeLayerBuilds, 3);
    expect(map.selectionLayerBuilds, 4);

    recorder.endRecording().dispose();
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
