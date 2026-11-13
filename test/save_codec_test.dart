import 'package:flutter_test/flutter_test.dart';

import 'package:flutter_3_kingdoms/game/game_controller.dart';
import 'package:flutter_3_kingdoms/game/save_codec.dart';
import 'package:flutter_3_kingdoms/models/chronicle.dart';

void main() {
  group('存档编解码', () {
    test('完整局面往返后年月、钱粮、城池与武将一致', () {
      final controller = GameController(factionId: 'shu', seed: 21);
      final game = controller.game;
      game.year = 199;
      game.month = 7;
      game.player.gold = 4321;
      game.player.food = 8765;
      final city = game.cities['jiangling']!;
      city.owner = 'wei';
      city.troops = 1234;
      city.agriculture = 66;
      city.governor = 'guanyu';
      city.acted = true;
      city.generalIds
        ..clear()
        ..add('guanyu');
      final general = game.generals['guanyu']!;
      general.factionId = 'wei';
      general.loyalty = 71;
      game.addChronicle('测试战报', ChronicleKind.event, factionId: 'wei');

      final restored = SaveCodec.decode(SaveCodec.encode(game));

      expect(restored.year, 199);
      expect(restored.month, 7);
      expect(restored.playerFaction, 'shu');
      expect(restored.player.gold, 4321);
      expect(restored.player.food, 8765);
      final restoredCity = restored.cities['jiangling']!;
      expect(restoredCity.owner, 'wei');
      expect(restoredCity.troops, 1234);
      expect(restoredCity.agriculture, 66);
      expect(restoredCity.governor, 'guanyu');
      expect(restoredCity.acted, isTrue);
      expect(restoredCity.generalIds, contains('guanyu'));
      expect(restored.generals['guanyu']!.factionId, 'wei');
      expect(restored.generals['guanyu']!.loyalty, 71);
      expect(restored.chronicle.any((entry) => entry.text == '测试战报'), isTrue);
      expect(restored.finished, isFalse);
    });

    test('存档摘要给出年月、势力与城池数', () {
      final controller = GameController(factionId: 'wu', seed: 4);
      final summary = SaveCodec.summary(SaveCodec.encode(controller.game));
      expect(summary.year, 196);
      expect(summary.month, 1);
      expect(summary.factionId, 'wu');
      expect(summary.cityCount, 5);
      expect(summary.label, contains('吴'));
    });

    test('版本不符的存档被拒绝', () {
      expect(
        () => SaveCodec.decode('{"v":99,"player":"wei"}'),
        throwsFormatException,
      );
    });

    test('在野武将出现在所在城池的登用列表', () {
      final controller = GameController(factionId: 'wei', seed: 8);
      final luoyang = controller.game.cities['luoyang']!;
      expect(
        controller.freeGeneralsIn(luoyang).map((general) => general.id),
        contains('zhangliao'),
      );
    });
  });
}
