import 'dart:ui';

/// 兵种：骑克弩、弩克步、步克骑；水军不参与克制，但在水乡战力大增。
enum TroopType {
  infantry('步兵', '结阵而战，克制骑兵'),
  cavalry('骑兵', '冲突驰突，克制弩兵'),
  archer('弩兵', '远射制敌，克制步兵'),
  navy('水军', '习于舟楫，水乡战力大增');

  const TroopType(this.label, this.description);

  final String label;
  final String description;

  /// 是否克制另一兵种。
  bool counters(TroopType other) => switch (this) {
    TroopType.infantry => other == TroopType.cavalry,
    TroopType.cavalry => other == TroopType.archer,
    TroopType.archer => other == TroopType.infantry,
    TroopType.navy => false,
  };

  /// 对另一兵种的战力系数。
  double against(TroopType other) => counters(other)
      ? 1.12
      : other.counters(this)
      ? 0.9
      : 1.0;

  /// 在某种地形上的战力加成。
  double onTerrain(Terrain terrain) => switch (this) {
    TroopType.navy => terrain == Terrain.river ? 0.12 : -0.05,
    TroopType.cavalry => terrain == Terrain.plain ? 0.07 : 0.0,
    TroopType.archer =>
      terrain == Terrain.mountain || terrain == Terrain.pass ? 0.07 : 0.0,
    TroopType.infantry => 0.03,
  };
}

/// 地形：影响攻城难度与进攻方的战力发挥。
enum Terrain {
  plain('平原', 0.0, 1.0),
  mountain('山地', 0.18, 0.9),
  river('水乡', 0.12, 0.94),
  pass('关隘', 0.28, 0.85);

  const Terrain(this.label, this.defenseBonus, this.attackFactor);

  final String label;

  /// 守方城防的额外加成。
  final double defenseBonus;

  /// 进攻方在此地形作战的战力系数。
  final double attackFactor;
}

/// 城池运行时状态。
class City {
  City({
    required this.id,
    required this.name,
    required this.region,
    required this.position,
    required this.terrain,
    required this.neighbors,
    required this.owner,
    required this.agriculture,
    required this.commerce,
    required this.order,
    required this.defense,
    required this.troops,
    required this.training,
    required this.population,
    this.troopType = TroopType.infantry,
    this.governor,
    List<String>? generals,
    this.acted = false,
  }) : generalIds = generals ?? <String>[];

  final String id;
  final String name;
  final String region;
  final Offset position;
  final Terrain terrain;
  final List<String> neighbors;
  final TroopType troopType;

  String owner;
  String? governor;
  final List<String> generalIds;

  int agriculture;
  int commerce;
  int order;
  int defense;
  int troops;
  int training;

  /// 人口（万），决定征兵上限与部分收入。
  int population;

  /// 本月是否已执行过指令。
  bool acted;

  /// 征兵上限：人口越多可征之兵越多。
  int get maxTroops => population * 150;

  /// 治安对收入的折算系数。
  double get orderFactor => 0.55 + order / 200;

  int get goldIncome => ((commerce * 3 + population) * orderFactor).round();

  int get foodIncome => ((agriculture * 2 + population) * orderFactor).round();

  /// 每千兵每月消耗的粮草。
  int get foodUpkeep => (troops / 50).round();

  /// 城池战力估值：兵力、训练与城防的综合，供 AI 与界面参考。
  int get power => (troops * (0.6 + training / 160) * (1 + defense / 220)).round();
}
