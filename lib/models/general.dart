/// 武将特长：决定战斗与内政上的倾向。
enum GeneralTrait {
  warrior('猛将', '冲阵斩将，攻击更锐利'),
  strategist('谋士', '运筹帷幄，火攻与计略更见成效'),
  commander('统帅', '统兵有方，全军战力与士气更稳'),
  statesman('能吏', '长于政务，执行内政事半功倍'),
  balanced('全才', '文武兼资，无所偏废');

  const GeneralTrait(this.label, this.description);

  final String label;
  final String description;
}

/// 武将技能：在战场上或内政中提供额外的确定性加成。
enum GeneralSkill {
  none('—', '无特殊技能'),
  divineMight('神武', '阵前冲杀，战力与单挑更胜一筹'),
  ironWall('铁壁', '稳守坚城，守城战力显著提升'),
  firestorm('火计', '火攻威力大增'),
  statecraft('治世', '执行内政时效果更佳'),
  swiftRaid('疾行', '突袭更为犀利，自损更少');

  const GeneralSkill(this.label, this.description);

  final String label;
  final String description;
}

/// 武将运行时状态：能力值 1-100，可在城池间调动、被登用或成为俘虏。
class General {
  General({
    required this.id,
    required this.name,
    required this.factionId,
    required this.cityId,
    required this.wu,
    required this.intel,
    required this.lead,
    required this.politics,
    required this.loyalty,
    required this.trait,
    this.skill = GeneralSkill.none,
  });

  final String id;
  final String name;
  String factionId;
  String cityId;
  final int wu;
  final int intel;
  final int lead;
  final int politics;
  int loyalty;
  final GeneralTrait trait;
  final GeneralSkill skill;

  bool get free => factionId == freeFactionId;

  /// 综合能力，用于列表排序与 AI 选将。
  int get rating => ((wu + intel + lead + politics) / 4).round();

  /// 攻城主将的战力系数。
  double get attackFactor =>
      1 +
      (wu * 0.5 + lead * 0.5) / 200 +
      (trait == GeneralTrait.warrior ? 0.08 : 0);

  /// 守城主将的战力系数。
  double get defenseFactor =>
      1 +
      (lead * 0.6 + wu * 0.4) / 200 +
      (trait == GeneralTrait.commander ? 0.07 : 0);
}

/// 在野武将的势力标记。
const String freeFactionId = 'none';
