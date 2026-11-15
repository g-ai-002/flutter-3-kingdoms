import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:flutter_3_kingdoms/game/game_controller.dart';
import 'package:flutter_3_kingdoms/game/save_codec.dart';
import 'package:flutter_3_kingdoms/services/save_service.dart';

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  test('自动存档与手动槽位可写入、读取与删除', () async {
    final controller = GameController(factionId: 'yuan', seed: 2);
    controller.game.month = 5;
    controller.game.player.gold = 999;

    expect(await SaveService.autoSummary(), isNull);
    expect(await SaveService.writeState(SaveService.autoKey, controller.game), isTrue);
    final auto = await SaveService.autoSummary();
    expect(auto, isNotNull);
    expect(auto!.month, 5);
    expect(auto.factionId, 'yuan');

    expect(
      await SaveService.writeState(
        SaveService.slotKey(2),
        controller.game,
      ),
      isTrue,
    );
    final slots = await SaveService.slotSummaries();
    expect(slots[0], isNull);
    expect(slots[1], isNotNull);

    final loaded = await SaveService.loadState(SaveService.slotKey(2));
    expect(loaded, isNotNull);
    expect(loaded!.player.gold, 999);

    await SaveService.delete(SaveService.slotKey(2));
    expect(await SaveService.summaryOf(SaveService.slotKey(2)), isNull);
  });

  test('损坏的存档读取返回 null 而不抛出', () async {
    SharedPreferences.setMockInitialValues({
      'flutter.${SaveService.autoKey}': '{broken',
    });
    expect(await SaveService.autoSummary(), isNull);
    expect(await SaveService.loadState(SaveService.autoKey), isNull);
  });

  test('写档时单存一份摘要，读摘要不再解析整份存档', () async {
    final controller = GameController(factionId: 'wu', seed: 7);
    controller.game.month = 9;
    await SaveService.writeState(SaveService.autoKey, controller.game);

    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getString('${SaveService.autoKey}__summary'), isNotNull);

    // 把整份存档换成坏数据：摘要仍能读出，说明没有解析整份存档。
    await prefs.setString(SaveService.autoKey, '{broken');
    final summary = await SaveService.autoSummary();
    expect(summary, isNotNull);
    expect(summary!.factionId, 'wu');
    expect(summary.month, 9);
    expect(summary.cityCount, controller.game.cityCount('wu'));
    expect(await SaveService.loadState(SaveService.autoKey), isNull);
  });

  test('旧存档没有摘要时回退解析整份存档', () async {
    final controller = GameController(factionId: 'shu', seed: 3);
    SharedPreferences.setMockInitialValues({
      'flutter.${SaveService.autoKey}': SaveCodec.encode(controller.game),
    });
    final summary = await SaveService.autoSummary();
    expect(summary, isNotNull);
    expect(summary!.factionId, 'shu');
    expect(summary.cityCount, controller.game.cityCount('shu'));
  });
}
