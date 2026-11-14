import '../models/city.dart';
import '../models/general.dart';

/// 战斗指令：玩家每回合选择一种，AI 守将自动应对。
enum BattleTactic {
  assault('强攻', '正面冲阵，杀伤最高，自损亦重', 1.32, 1.15),
  hold('固守', '稳住阵脚，减少伤亡并恢复士气', 0.72, 0.62),
  fire('火攻', '纵火焚营，智力越高越见效', 1.08, 1.0),
  raid('突袭', '轻骑穿插，胜负系于一击', 1.46, 1.32),
  retreat('撤退', '鸣金收兵，保存实力', 0, 0);

  const BattleTactic(this.label, this.description, this.attack, this.exposure);

  final String label;
  final String description;

  /// 本方战力系数。
  final double attack;

  /// 本方承受伤害的系数。
  final double exposure;
}

/// 战场一方：兵力、士气与主将。
class BattleSide {
  BattleSide({
    required this.factionId, required this.cityId, required this.cityName,
    required this.generalName, required this.lead, required this.wu,
    required this.intel, required this.training, required this.defense,
    required this.troops, required this.morale, required this.terrain,
    required this.attacking, this.generalId,
    this.trait = GeneralTrait.balanced,
    this.skill = GeneralSkill.none,
    this.troopType = TroopType.infantry,
    this.level = 1,
  }) : initialTroops = troops;

  final String factionId;
  final String cityId;
  final String cityName;
  final String? generalId;
  final String generalName;
  final int lead;
  final int wu;
  final int intel;
  final int training;
  final int defense;
  final Terrain terrain;
  final bool attacking;
  final GeneralTrait trait;
  final GeneralSkill skill;
  final TroopType troopType;

  /// 主将等级：历练越深，战力越强。
  final int level;

  int troops;
  int morale;
  final int initialTroops;

  int get losses => initialTroops - troops;
}

/// 战斗开始前的双方快照。
class BattleSetup {
  const BattleSetup({required this.attacker, required this.defender});

  final BattleSide attacker;
  final BattleSide defender;
}

enum BattleLogKind { normal, tactic, duel, result }

class BattleLogEntry {
  const BattleLogEntry(this.round, this.text, this.kind);

  final int round;
  final String text;
  final BattleLogKind kind;
}

/// 战斗过程状态，界面直接监听它刷新。
class BattleState {
  BattleState({required this.attacker, required this.defender})
    : round = 0,
      attackerWon = false,
      retreated = false,
      finished = false;

  final BattleSide attacker;
  final BattleSide defender;
  final List<BattleLogEntry> log = [];

  int round;
  bool finished;
  bool attackerWon;
  bool retreated;

  static const int maxRounds = 14;

  void addLog(String text, BattleLogKind kind) =>
      log.add(BattleLogEntry(round, text, kind));
}

/// 战斗结果：由控制器写回战略地图。
class BattleResult {
  const BattleResult({
    required this.attackerWon, required this.retreated,
    required this.attackerRemaining, required this.defenderRemaining,
    required this.attackerLosses, required this.defenderLosses,
    required this.rounds,
  });

  final bool attackerWon;
  final bool retreated;
  final int attackerRemaining;
  final int defenderRemaining;
  final int attackerLosses;
  final int defenderLosses;
  final int rounds;
}
