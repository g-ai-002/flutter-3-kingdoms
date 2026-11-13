import '../models/city.dart';
import '../models/general.dart';

/// 出征前的纸面胜算，供出征面板提示风险。
enum BattleOdds {
  favorable('胜算颇高'),
  even('势均力敌'),
  unfavorable('凶多吉少');

  const BattleOdds(this.label);

  final String label;

  static BattleOdds of(double ratio) => ratio >= 1.6
      ? favorable
      : ratio >= 1.1
      ? even
      : unfavorable;
}

/// 出兵前的双方概览：出征地、目标城、守将与战力比值。
class BattlePreview {
  const BattlePreview({
    required this.source,
    required this.target,
    required this.defender,
  });

  final City source;
  final City target;
  final General? defender;

  /// 攻方战力与守城战力的比值，1.0 表示势均力敌。
  double get ratio {
    final power = target.power;
    return source.troops * (0.6 + source.training / 160) / (power <= 0 ? 1 : power);
  }

  BattleOdds get odds => BattleOdds.of(ratio);
}
