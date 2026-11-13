import 'dart:ui' as ui;

import 'package:flame/components.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:flutter_3_kingdoms/flame/map_component.dart';
import 'package:flutter_3_kingdoms/flame/sanguo_game.dart';
import 'package:flutter_3_kingdoms/game/game_controller.dart';
import 'package:flutter_3_kingdoms/game/orders.dart';
import 'package:flutter_3_kingdoms/services/tone_synth.dart';

void main() {
  test('月度收支一次汇总与逐项求和一致', () {
    final game = GameController(factionId: 'wei', seed: 11).game;
    final economy = game.economyOf('wei');
    expect(economy.gold, game.goldIncomeOf('wei'));
    expect(economy.food, game.foodIncomeOf('wei'));
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

  testWidgets('地图静态图层按修订号缓存，选中不触发重录', (tester) async {
    final controller = GameController(factionId: 'wei', seed: 3);
    final brightness = ValueNotifier(Brightness.light);
    addTearDown(brightness.dispose);
    final map = MapComponent(controller: controller, brightness: brightness)
      ..size = Vector2(1200, 760);
    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder);

    map.render(canvas);
    expect(map.staticLayerBuilds, 1);
    map.render(canvas);
    expect(map.staticLayerBuilds, 1);

    controller.selectCity('xuchang');
    map.render(canvas);
    expect(map.staticLayerBuilds, 1);

    controller.selectCity(null);
    controller.endTurn();
    map.render(canvas);
    expect(map.staticLayerBuilds, 2);

    brightness.value = Brightness.dark;
    map.render(canvas);
    expect(map.staticLayerBuilds, 3);

    recorder.endRecording().dispose();
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
