import 'dart:math';

import '../models/chronicle.dart';
import '../models/game_state.dart';
import '../models/general.dart';

/// 名将历练：战阵与政务积累经验，升级后攻城守城更锐利。
class GrowthService {
  GrowthService._();

  /// 破城、击退与败退的历练，胜者所得更多。
  static const int captureXp = 60;
  static const int repelXp = 45;
  static const int defeatXp = 20;

  /// 太守每执行一条内政积累的政务历练。
  static const int affairXp = 8;

  /// 加历练并在晋阶时写一条战报；在野武将不参与。
  static void award(GameState state, General? general, int xp) {
    if (general == null || general.free || xp <= 0) return;
    final before = general.level;
    const ceiling = (General.maxLevel - 1) * General.xpPerLevel;
    general.xp = min(general.xp + xp, ceiling);
    if (general.level > before) {
      state.addChronicle(
        '${general.name} 历练有成，晋为 ${general.level} 级${general.rank}。',
        ChronicleKind.event,
        factionId: general.factionId,
      );
    }
  }
}
