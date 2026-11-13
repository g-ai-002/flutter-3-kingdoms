import 'package:flutter/material.dart';

/// 势力静态设定：名称、君主、配色、初始城池与武将。
class FactionDef {
  const FactionDef({
    required this.id,
    required this.name,
    required this.ruler,
    required this.title,
    required this.motto,
    required this.color,
    required this.gold,
    required this.food,
  });

  final String id;
  final String name;
  final String ruler;
  final String title;
  final String motto;
  final Color color;
  final int gold;
  final int food;
}

/// 势力运行时状态：钱粮与存亡。
class FactionState {
  FactionState({
    required this.id,
    required this.gold,
    required this.food,
    this.alive = true,
  });

  final String id;
  int gold;
  int food;
  bool alive;
}

/// 五大势力与配色，顺序即回合结算顺序。
class FactionDefs {
  FactionDefs._();

  static const List<FactionDef> all = [
    FactionDef(
      id: 'wei',
      name: '魏',
      ruler: '曹操',
      title: '魏王 · 挟天子以令诸侯',
      motto: '宁我负人，毋人负我',
      color: Color(0xFF34558B),
      gold: 1600,
      food: 2400,
    ),
    FactionDef(
      id: 'shu',
      name: '蜀',
      ruler: '刘备',
      title: '汉中王 · 仁德布于四海',
      motto: '惟贤惟德，能服于人',
      color: Color(0xFFA83E32),
      gold: 1200,
      food: 2200,
    ),
    FactionDef(
      id: 'wu',
      name: '吴',
      ruler: '孙权',
      title: '吴侯 · 据江东而观天下',
      motto: '生子当如孙仲谋',
      color: Color(0xFF2F7D68),
      gold: 1400,
      food: 2400,
    ),
    FactionDef(
      id: 'yuan',
      name: '袁',
      ruler: '袁绍',
      title: '冀州牧 · 四世三公',
      motto: '吾乃名门之后',
      color: Color(0xFF7A4E9B),
      gold: 1700,
      food: 2600,
    ),
    FactionDef(
      id: 'dong',
      name: '董',
      ruler: '董卓',
      title: '相国 · 西凉铁骑入洛阳',
      motto: '顺我者昌，逆我者亡',
      color: Color(0xFF8A6A32),
      gold: 1500,
      food: 2300,
    ),
  ];

  static FactionDef byId(String id) =>
      all.firstWhere((item) => item.id == id, orElse: () => all.first);

  static String nameOf(String id) => byId(id).name;

  static Color colorOf(String id) => byId(id).color;

  static bool isKnown(String id) => all.any((item) => item.id == id);
}
