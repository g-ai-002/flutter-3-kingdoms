import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:flutter_3_kingdoms/game/game_controller.dart';
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
}
