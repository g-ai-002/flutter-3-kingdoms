import 'dart:ui';

import '../../models/chronicle.dart';
import '../../models/city.dart';
import '../../models/difficulty.dart';
import '../../models/faction.dart';
import '../../models/game_state.dart';
import '../../models/general.dart';

/// 城池静态设定：坐标、地形、相邻城池与初始状态。
class CityDef {
  const CityDef({
    required this.id, required this.name, required this.region,
    required this.position, required this.terrain, required this.neighbors,
    required this.owner, required this.agriculture, required this.commerce,
    required this.order, required this.defense, required this.troops,
    required this.training, required this.population,
  });

  final String id, name, region, owner;
  final Offset position;
  final Terrain terrain;
  final List<String> neighbors;
  final int agriculture, commerce, order, defense, troops, training, population;
}

/// 武将静态设定。
class GeneralDef {
  const GeneralDef({
    required this.id, required this.name, required this.factionId,
    required this.cityId, required this.wu, required this.intel,
    required this.lead, required this.politics, required this.loyalty,
    required this.trait,
  });

  final String id, name, factionId, cityId;
  final int wu, intel, lead, politics, loyalty;
  final GeneralTrait trait;
}

/// 剧本：同一张天下地图的不同开局形势。
class ScenarioDef {
  const ScenarioDef({
    required this.id, required this.name, required this.year,
    required this.month, required this.summary,
    this.transfers = const {}, this.troops = const {},
  });

  final String id, name, summary;
  final int year, month;

  /// 城池易手表：只列出与初始归属不同的城池，未列出者沿用城池表。
  final Map<String, String> transfers;

  /// 势力 → 初始兵力倍率，用来拉开剧本中的强弱。
  final Map<String, double> troops;

  String get era => '$year年$month月';
}

/// 自定义开局的钱粮档位：只影响玩家开局的金钱与粮草。
enum StartSupply {
  lean('俭省', 0.75, '开局钱粮偏紧'),
  normal('常规', 1, '史实钱粮'),
  rich('丰饶', 1.35, '开局钱粮宽裕');

  const StartSupply(this.label, this.ratio, this.summary);

  final String label;
  final double ratio;
  final String summary;

  static StartSupply byRatio(double ratio) => values.reduce(
    (a, b) => (a.ratio - ratio).abs() <= (b.ratio - ratio).abs() ? a : b,
  );
}

/// 群雄割据的初始局面。
class Scenario {
  Scenario._();

  static const String defaultScenarioId = 'qunxiong';

  /// 可选剧本：群雄割据为默认，另两局把时间推到官渡与三分。
  static const List<ScenarioDef> scenarios = [
    ScenarioDef(id: defaultScenarioId, name: '群雄割据', year: 196, month: 1, summary: '五雄并立，各据一方；城寡兵薄，正可放手经营。'),
    ScenarioDef(
      id: 'guandu', name: '官渡对峙', year: 200, month: 2, summary: '袁绍并河北四州，曹操挟天子据中原，孙刘各安一隅。',
      transfers: {
        'xinye': 'shu', 'xiangyang': 'shu',
        'hanzhong': 'dong', 'zitong': 'dong', 'chengdu': 'dong', 'yongan': 'dong',
      },
      troops: {'wei': 1.1, 'yuan': 1.25},
    ),
    ScenarioDef(
      id: 'santianxia', name: '三分天下', year: 220, month: 4, summary: '魏据中原九州，蜀吴各守山川，袁董残部退保边郡。',
      transfers: {
        'jinyang': 'wei', 'ye': 'wei', 'nanpi': 'wei', 'pingyuan': 'wei', 'beihai': 'wei',
        'xinye': 'wei', 'xiangyang': 'wei', 'changan': 'wei', 'tianshui': 'shu', 'jiangling': 'wu',
      },
      troops: {'shu': 1.1, 'wu': 1.1},
    ),
  ];

  static ScenarioDef byId(String? id) => scenarios.firstWhere(
    (item) => item.id == id,
    orElse: () => scenarios.first,
  );

  /// 剧本中某势力的城池数，首页势力卡据此更新。
  static int cityCountOf(String scenarioId, String factionId) {
    final transfers = byId(scenarioId).transfers;
    return cityDefs
        .where((city) => (transfers[city.id] ?? city.owner) == factionId)
        .length;
  }

  /// 各城兵种：北方多骑兵，山地关隘多弩兵，江河之地多水军，其余为步兵。
  static const Map<String, TroopType> troopTypes = {
    'wuwei': TroopType.cavalry, 'tianshui': TroopType.cavalry, 'changan': TroopType.cavalry,
    'jinyang': TroopType.cavalry, 'ji': TroopType.cavalry, 'ye': TroopType.cavalry,
    'nanpi': TroopType.cavalry, 'hanzhong': TroopType.archer, 'zitong': TroopType.archer,
    'yongan': TroopType.archer, 'beihai': TroopType.navy, 'xiangyang': TroopType.navy,
    'jiangling': TroopType.navy, 'changsha': TroopType.navy, 'chaisang': TroopType.navy,
    'jianye': TroopType.navy, 'wu': TroopType.navy, 'kuaiji': TroopType.navy,
  };

  /// 名将技能：只列有特技者，其余为无。
  static const Map<String, GeneralSkill> generalSkills = {
    'caocao': GeneralSkill.statecraft, 'xiahoudun': GeneralSkill.divineMight,
    'xiahouyuan': GeneralSkill.swiftRaid, 'caoren': GeneralSkill.ironWall,
    'xunyu': GeneralSkill.statecraft, 'guojia': GeneralSkill.firestorm,
    'xuchu': GeneralSkill.divineMight, 'dianwei': GeneralSkill.ironWall,
    'yujin': GeneralSkill.ironWall, 'liubei': GeneralSkill.statecraft,
    'guanyu': GeneralSkill.divineMight, 'zhangfei': GeneralSkill.swiftRaid,
    'zhaoyun': GeneralSkill.swiftRaid, 'jianyong': GeneralSkill.statecraft,
    'sunqian': GeneralSkill.statecraft, 'sunquan': GeneralSkill.statecraft,
    'zhouyu': GeneralSkill.firestorm, 'lusu': GeneralSkill.statecraft,
    'lvmeng': GeneralSkill.swiftRaid, 'ganning': GeneralSkill.swiftRaid,
    'taishici': GeneralSkill.divineMight, 'chengpu': GeneralSkill.ironWall,
    'yanliang': GeneralSkill.divineMight, 'wenchou': GeneralSkill.divineMight,
    'zhanghe': GeneralSkill.swiftRaid, 'gaolan': GeneralSkill.ironWall,
    'tianfeng': GeneralSkill.statecraft, 'jushou': GeneralSkill.firestorm,
    'dongzhuo': GeneralSkill.ironWall, 'lvbu': GeneralSkill.divineMight,
    'liru': GeneralSkill.firestorm, 'huaxiong': GeneralSkill.divineMight,
    'xurong': GeneralSkill.ironWall, 'zhangliao': GeneralSkill.swiftRaid,
    'zhugeliang': GeneralSkill.firestorm, 'pangtong': GeneralSkill.firestorm,
    'machao': GeneralSkill.swiftRaid, 'huangzhong': GeneralSkill.divineMight,
    'weiyan': GeneralSkill.swiftRaid, 'luxun': GeneralSkill.firestorm,
    'jiaxu': GeneralSkill.firestorm, 'xushu': GeneralSkill.statecraft,
    'dengai': GeneralSkill.swiftRaid, 'jiangwei': GeneralSkill.swiftRaid,
  };

  static const List<CityDef> cityDefs = [
    CityDef(id: 'wuwei', name: '武威', region: '凉州', position: Offset(150, 190), terrain: Terrain.mountain, neighbors: ['tianshui'], owner: 'dong', agriculture: 45, commerce: 50, order: 62, defense: 55, troops: 3200, training: 60, population: 45), CityDef(id: 'tianshui', name: '天水', region: '凉州', position: Offset(255, 265), terrain: Terrain.mountain, neighbors: ['wuwei', 'changan', 'hanzhong'], owner: 'dong', agriculture: 55, commerce: 50, order: 60, defense: 58, troops: 3500, training: 58, population: 55),
    CityDef(id: 'changan', name: '长安', region: '雍州', position: Offset(360, 265), terrain: Terrain.pass, neighbors: ['tianshui', 'luoyang', 'jinyang', 'hanzhong'], owner: 'dong', agriculture: 78, commerce: 80, order: 66, defense: 72, troops: 5200, training: 66, population: 110), CityDef(id: 'luoyang', name: '洛阳', region: '司隶', position: Offset(480, 300), terrain: Terrain.pass, neighbors: ['changan', 'jinyang', 'ye', 'chenliu', 'xuchang', 'wan'], owner: 'wei', agriculture: 82, commerce: 88, order: 70, defense: 75, troops: 5600, training: 68, population: 120),
    CityDef(id: 'jinyang', name: '晋阳', region: '并州', position: Offset(480, 175), terrain: Terrain.mountain, neighbors: ['changan', 'luoyang', 'ye', 'ji'], owner: 'yuan', agriculture: 62, commerce: 60, order: 62, defense: 66, troops: 4200, training: 62, population: 70), CityDef(id: 'ji', name: '蓟', region: '幽州', position: Offset(585, 95), terrain: Terrain.mountain, neighbors: ['jinyang', 'nanpi'], owner: 'yuan', agriculture: 52, commerce: 55, order: 60, defense: 62, troops: 3000, training: 58, population: 55),
    CityDef(id: 'ye', name: '邺', region: '冀州', position: Offset(590, 205), terrain: Terrain.plain, neighbors: ['jinyang', 'luoyang', 'nanpi', 'pingyuan', 'puyang'], owner: 'yuan', agriculture: 80, commerce: 82, order: 68, defense: 74, troops: 5800, training: 68, population: 115), CityDef(id: 'nanpi', name: '南皮', region: '冀州', position: Offset(665, 150), terrain: Terrain.plain, neighbors: ['ji', 'ye', 'pingyuan'], owner: 'yuan', agriculture: 65, commerce: 62, order: 62, defense: 58, troops: 3600, training: 60, population: 65),
    CityDef(id: 'pingyuan', name: '平原', region: '青州', position: Offset(655, 235), terrain: Terrain.plain, neighbors: ['nanpi', 'ye', 'beihai', 'puyang'], owner: 'yuan', agriculture: 62, commerce: 58, order: 60, defense: 56, troops: 3200, training: 58, population: 60), CityDef(id: 'beihai', name: '北海', region: '青州', position: Offset(760, 245), terrain: Terrain.river, neighbors: ['pingyuan', 'puyang'], owner: 'yuan', agriculture: 58, commerce: 60, order: 58, defense: 55, troops: 3000, training: 56, population: 58),
    CityDef(id: 'puyang', name: '濮阳', region: '兖州', position: Offset(625, 290), terrain: Terrain.plain, neighbors: ['ye', 'pingyuan', 'beihai', 'chenliu'], owner: 'wei', agriculture: 68, commerce: 70, order: 64, defense: 62, troops: 4000, training: 62, population: 75), CityDef(id: 'chenliu', name: '陈留', region: '兖州', position: Offset(555, 335), terrain: Terrain.plain, neighbors: ['luoyang', 'puyang', 'xuchang'], owner: 'wei', agriculture: 70, commerce: 72, order: 65, defense: 62, troops: 3800, training: 62, population: 80),
    CityDef(id: 'xuchang', name: '许昌', region: '豫州', position: Offset(540, 385), terrain: Terrain.plain, neighbors: ['luoyang', 'chenliu', 'runan', 'wan'], owner: 'wei', agriculture: 80, commerce: 76, order: 70, defense: 70, troops: 5000, training: 68, population: 100), CityDef(id: 'runan', name: '汝南', region: '豫州', position: Offset(575, 445), terrain: Terrain.plain, neighbors: ['xuchang', 'shouchun', 'wan'], owner: 'wei', agriculture: 66, commerce: 62, order: 60, defense: 58, troops: 3400, training: 58, population: 72),
    CityDef(id: 'wan', name: '宛', region: '荆州', position: Offset(448, 398), terrain: Terrain.plain, neighbors: ['luoyang', 'xuchang', 'runan', 'xinye', 'xiangyang'], owner: 'wei', agriculture: 70, commerce: 68, order: 64, defense: 62, troops: 3600, training: 60, population: 78), CityDef(id: 'xinye', name: '新野', region: '荆州', position: Offset(480, 455), terrain: Terrain.plain, neighbors: ['wan', 'xiangyang'], owner: 'dong', agriculture: 52, commerce: 48, order: 58, defense: 50, troops: 2400, training: 54, population: 45),
    CityDef(id: 'xiangyang', name: '襄阳', region: '荆州', position: Offset(480, 515), terrain: Terrain.river, neighbors: ['wan', 'xinye', 'jiangling', 'hanzhong'], owner: 'dong', agriculture: 75, commerce: 76, order: 66, defense: 72, troops: 4600, training: 64, population: 90), CityDef(id: 'jiangling', name: '江陵', region: '荆州', position: Offset(505, 575), terrain: Terrain.river, neighbors: ['xiangyang', 'changsha', 'chaisang', 'yongan'], owner: 'shu', agriculture: 76, commerce: 74, order: 66, defense: 70, troops: 4400, training: 64, population: 95),
    CityDef(id: 'changsha', name: '长沙', region: '荆州', position: Offset(585, 660), terrain: Terrain.river, neighbors: ['jiangling', 'chaisang'], owner: 'wu', agriculture: 64, commerce: 62, order: 62, defense: 58, troops: 3200, training: 58, population: 70), CityDef(id: 'chaisang', name: '柴桑', region: '扬州', position: Offset(660, 560), terrain: Terrain.river, neighbors: ['jiangling', 'changsha', 'shouchun', 'jianye'], owner: 'wu', agriculture: 60, commerce: 64, order: 62, defense: 60, troops: 3400, training: 60, population: 62),
    CityDef(id: 'shouchun', name: '寿春', region: '扬州', position: Offset(665, 435), terrain: Terrain.plain, neighbors: ['runan', 'chaisang', 'jianye'], owner: 'wei', agriculture: 70, commerce: 68, order: 62, defense: 66, troops: 3800, training: 62, population: 82), CityDef(id: 'jianye', name: '建业', region: '扬州', position: Offset(745, 465), terrain: Terrain.river, neighbors: ['shouchun', 'chaisang', 'wu'], owner: 'wu', agriculture: 78, commerce: 80, order: 68, defense: 70, troops: 4600, training: 66, population: 95),
    CityDef(id: 'wu', name: '吴', region: '扬州', position: Offset(800, 525), terrain: Terrain.river, neighbors: ['jianye', 'kuaiji'], owner: 'wu', agriculture: 72, commerce: 74, order: 66, defense: 62, troops: 3600, training: 62, population: 80), CityDef(id: 'kuaiji', name: '会稽', region: '扬州', position: Offset(790, 610), terrain: Terrain.river, neighbors: ['wu'], owner: 'wu', agriculture: 62, commerce: 64, order: 62, defense: 58, troops: 2800, training: 58, population: 62),
    CityDef(id: 'hanzhong', name: '汉中', region: '益州', position: Offset(345, 370), terrain: Terrain.mountain, neighbors: ['tianshui', 'changan', 'xiangyang', 'zitong'], owner: 'shu', agriculture: 58, commerce: 54, order: 64, defense: 70, troops: 3200, training: 60, population: 56), CityDef(id: 'zitong', name: '梓潼', region: '益州', position: Offset(315, 450), terrain: Terrain.mountain, neighbors: ['hanzhong', 'chengdu'], owner: 'shu', agriculture: 52, commerce: 48, order: 62, defense: 74, troops: 2600, training: 58, population: 45),
    CityDef(id: 'chengdu', name: '成都', region: '益州', position: Offset(245, 525), terrain: Terrain.plain, neighbors: ['zitong', 'yongan'], owner: 'shu', agriculture: 82, commerce: 78, order: 70, defense: 74, troops: 4800, training: 64, population: 105), CityDef(id: 'yongan', name: '永安', region: '益州', position: Offset(405, 520), terrain: Terrain.pass, neighbors: ['chengdu', 'jiangling'], owner: 'shu', agriculture: 48, commerce: 46, order: 62, defense: 80, troops: 2400, training: 58, population: 40),
  ];

  static const List<GeneralDef> generalDefs = [
    GeneralDef(id: 'caocao', name: '曹操', factionId: 'wei', cityId: 'xuchang', wu: 72, intel: 91, lead: 90, politics: 94, loyalty: 100, trait: GeneralTrait.commander), GeneralDef(id: 'xiahoudun', name: '夏侯惇', factionId: 'wei', cityId: 'chenliu', wu: 88, intel: 62, lead: 82, politics: 55, loyalty: 95, trait: GeneralTrait.warrior),
    GeneralDef(id: 'xiahouyuan', name: '夏侯渊', factionId: 'wei', cityId: 'luoyang', wu: 90, intel: 58, lead: 80, politics: 50, loyalty: 95, trait: GeneralTrait.warrior), GeneralDef(id: 'caoren', name: '曹仁', factionId: 'wei', cityId: 'wan', wu: 85, intel: 66, lead: 86, politics: 60, loyalty: 93, trait: GeneralTrait.commander),
    GeneralDef(id: 'xunyu', name: '荀彧', factionId: 'wei', cityId: 'xuchang', wu: 35, intel: 95, lead: 70, politics: 96, loyalty: 90, trait: GeneralTrait.statesman), GeneralDef(id: 'guojia', name: '郭嘉', factionId: 'wei', cityId: 'xuchang', wu: 30, intel: 97, lead: 65, politics: 78, loyalty: 88, trait: GeneralTrait.strategist),
    GeneralDef(id: 'xuchu', name: '许褚', factionId: 'wei', cityId: 'puyang', wu: 96, intel: 35, lead: 72, politics: 32, loyalty: 92, trait: GeneralTrait.warrior), GeneralDef(id: 'dianwei', name: '典韦', factionId: 'wei', cityId: 'chenliu', wu: 95, intel: 40, lead: 70, politics: 30, loyalty: 90, trait: GeneralTrait.warrior),
    GeneralDef(id: 'yujin', name: '于禁', factionId: 'wei', cityId: 'runan', wu: 78, intel: 68, lead: 80, politics: 62, loyalty: 85, trait: GeneralTrait.commander),

    GeneralDef(id: 'liubei', name: '刘备', factionId: 'shu', cityId: 'chengdu', wu: 73, intel: 78, lead: 80, politics: 85, loyalty: 100, trait: GeneralTrait.balanced), GeneralDef(id: 'guanyu', name: '关羽', factionId: 'shu', cityId: 'jiangling', wu: 97, intel: 75, lead: 92, politics: 62, loyalty: 100, trait: GeneralTrait.warrior),
    GeneralDef(id: 'zhangfei', name: '张飞', factionId: 'shu', cityId: 'zitong', wu: 96, intel: 42, lead: 84, politics: 30, loyalty: 100, trait: GeneralTrait.warrior), GeneralDef(id: 'zhaoyun', name: '赵云', factionId: 'shu', cityId: 'hanzhong', wu: 96, intel: 76, lead: 88, politics: 65, loyalty: 100, trait: GeneralTrait.warrior),
    GeneralDef(id: 'jianyong', name: '简雍', factionId: 'shu', cityId: 'chengdu', wu: 30, intel: 72, lead: 55, politics: 80, loyalty: 85, trait: GeneralTrait.statesman), GeneralDef(id: 'sunqian', name: '孙乾', factionId: 'shu', cityId: 'yongan', wu: 32, intel: 70, lead: 52, politics: 82, loyalty: 84, trait: GeneralTrait.statesman),

    GeneralDef(id: 'sunquan', name: '孙权', factionId: 'wu', cityId: 'jianye', wu: 68, intel: 80, lead: 78, politics: 86, loyalty: 100, trait: GeneralTrait.balanced), GeneralDef(id: 'zhouyu', name: '周瑜', factionId: 'wu', cityId: 'chaisang', wu: 80, intel: 96, lead: 92, politics: 85, loyalty: 98, trait: GeneralTrait.strategist),
    GeneralDef(id: 'lusu', name: '鲁肃', factionId: 'wu', cityId: 'jianye', wu: 45, intel: 90, lead: 80, politics: 92, loyalty: 95, trait: GeneralTrait.statesman), GeneralDef(id: 'lvmeng', name: '吕蒙', factionId: 'wu', cityId: 'wu', wu: 82, intel: 87, lead: 88, politics: 70, loyalty: 92, trait: GeneralTrait.commander),
    GeneralDef(id: 'ganning', name: '甘宁', factionId: 'wu', cityId: 'chaisang', wu: 94, intel: 58, lead: 82, politics: 40, loyalty: 88, trait: GeneralTrait.warrior), GeneralDef(id: 'taishici', name: '太史慈', factionId: 'wu', cityId: 'kuaiji', wu: 93, intel: 62, lead: 80, politics: 50, loyalty: 90, trait: GeneralTrait.warrior),
    GeneralDef(id: 'chengpu', name: '程普', factionId: 'wu', cityId: 'changsha', wu: 80, intel: 70, lead: 82, politics: 66, loyalty: 92, trait: GeneralTrait.commander),

    GeneralDef(id: 'yuanshao', name: '袁绍', factionId: 'yuan', cityId: 'ye', wu: 70, intel: 72, lead: 76, politics: 78, loyalty: 100, trait: GeneralTrait.balanced), GeneralDef(id: 'yanliang', name: '颜良', factionId: 'yuan', cityId: 'nanpi', wu: 93, intel: 40, lead: 78, politics: 38, loyalty: 88, trait: GeneralTrait.warrior),
    GeneralDef(id: 'wenchou', name: '文丑', factionId: 'yuan', cityId: 'pingyuan', wu: 92, intel: 38, lead: 76, politics: 36, loyalty: 87, trait: GeneralTrait.warrior), GeneralDef(id: 'zhanghe', name: '张郃', factionId: 'yuan', cityId: 'ye', wu: 88, intel: 76, lead: 86, politics: 60, loyalty: 85, trait: GeneralTrait.commander),
    GeneralDef(id: 'gaolan', name: '高览', factionId: 'yuan', cityId: 'beihai', wu: 82, intel: 55, lead: 78, politics: 48, loyalty: 84, trait: GeneralTrait.warrior), GeneralDef(id: 'tianfeng', name: '田丰', factionId: 'yuan', cityId: 'ye', wu: 30, intel: 94, lead: 76, politics: 90, loyalty: 80, trait: GeneralTrait.strategist),
    GeneralDef(id: 'jushou', name: '沮授', factionId: 'yuan', cityId: 'jinyang', wu: 40, intel: 92, lead: 80, politics: 88, loyalty: 82, trait: GeneralTrait.strategist), GeneralDef(id: 'yuanshang', name: '袁尚', factionId: 'yuan', cityId: 'ji', wu: 62, intel: 64, lead: 66, politics: 58, loyalty: 90, trait: GeneralTrait.balanced),

    GeneralDef(id: 'dongzhuo', name: '董卓', factionId: 'dong', cityId: 'changan', wu: 82, intel: 70, lead: 76, politics: 40, loyalty: 100, trait: GeneralTrait.commander), GeneralDef(id: 'lvbu', name: '吕布', factionId: 'dong', cityId: 'changan', wu: 100, intel: 45, lead: 90, politics: 25, loyalty: 55, trait: GeneralTrait.warrior),
    GeneralDef(id: 'liru', name: '李儒', factionId: 'dong', cityId: 'changan', wu: 32, intel: 94, lead: 72, politics: 80, loyalty: 85, trait: GeneralTrait.strategist), GeneralDef(id: 'huaxiong', name: '华雄', factionId: 'dong', cityId: 'tianshui', wu: 90, intel: 38, lead: 74, politics: 32, loyalty: 80, trait: GeneralTrait.warrior),
    GeneralDef(id: 'xurong', name: '徐荣', factionId: 'dong', cityId: 'wuwei', wu: 85, intel: 70, lead: 82, politics: 55, loyalty: 82, trait: GeneralTrait.commander), GeneralDef(id: 'zhangji', name: '张济', factionId: 'dong', cityId: 'xiangyang', wu: 78, intel: 58, lead: 76, politics: 52, loyalty: 80, trait: GeneralTrait.commander),
    GeneralDef(id: 'fanchou', name: '樊稠', factionId: 'dong', cityId: 'xinye', wu: 76, intel: 45, lead: 70, politics: 40, loyalty: 78, trait: GeneralTrait.warrior),

    GeneralDef(id: 'zhangliao', name: '张辽', factionId: freeFactionId, cityId: 'luoyang', wu: 92, intel: 78, lead: 88, politics: 62, loyalty: 70, trait: GeneralTrait.commander), GeneralDef(id: 'zhugeliang', name: '诸葛亮', factionId: freeFactionId, cityId: 'xiangyang', wu: 45, intel: 100, lead: 92, politics: 96, loyalty: 90, trait: GeneralTrait.strategist),
    GeneralDef(id: 'pangtong', name: '庞统', factionId: freeFactionId, cityId: 'jiangling', wu: 35, intel: 96, lead: 78, politics: 85, loyalty: 82, trait: GeneralTrait.strategist), GeneralDef(id: 'machao', name: '马超', factionId: freeFactionId, cityId: 'tianshui', wu: 97, intel: 50, lead: 88, politics: 40, loyalty: 72, trait: GeneralTrait.warrior),
    GeneralDef(id: 'huangzhong', name: '黄忠', factionId: freeFactionId, cityId: 'changsha', wu: 93, intel: 60, lead: 85, politics: 50, loyalty: 80, trait: GeneralTrait.warrior), GeneralDef(id: 'weiyan', name: '魏延', factionId: freeFactionId, cityId: 'hanzhong', wu: 92, intel: 61, lead: 84, politics: 45, loyalty: 70, trait: GeneralTrait.warrior),
    GeneralDef(id: 'luxun', name: '陆逊', factionId: freeFactionId, cityId: 'wu', wu: 65, intel: 95, lead: 90, politics: 88, loyalty: 85, trait: GeneralTrait.strategist), GeneralDef(id: 'jiaxu', name: '贾诩', factionId: freeFactionId, cityId: 'changan', wu: 42, intel: 97, lead: 80, politics: 90, loyalty: 75, trait: GeneralTrait.strategist),
    GeneralDef(id: 'xushu', name: '徐庶', factionId: freeFactionId, cityId: 'xuchang', wu: 55, intel: 93, lead: 72, politics: 84, loyalty: 78, trait: GeneralTrait.strategist), GeneralDef(id: 'dengai', name: '邓艾', factionId: freeFactionId, cityId: 'wan', wu: 78, intel: 90, lead: 88, politics: 70, loyalty: 80, trait: GeneralTrait.commander),
    GeneralDef(id: 'jiangwei', name: '姜维', factionId: freeFactionId, cityId: 'tianshui', wu: 89, intel: 90, lead: 85, politics: 68, loyalty: 80, trait: GeneralTrait.balanced),
  ];

  /// 依据剧本、所选势力、难度与开局钱粮建立初始局面。
  static GameState build({
    required String playerFaction,
    required Difficulty difficulty,
    String? scenarioId,
    double goldRatio = 1,
  }) {
    final scenario = byId(scenarioId);
    final owners = <String, String>{
      for (final def in cityDefs) def.id: scenario.transfers[def.id] ?? def.owner,
    };
    double wealthOf(String factionId) =>
        factionId == playerFaction ? goldRatio : 1;
    final factions = <String, FactionState>{
      for (final def in FactionDefs.all)
        def.id: FactionState(
          id: def.id,
          gold: (def.gold * wealthOf(def.id)).round(),
          food: (def.food * wealthOf(def.id)).round(),
        ),
    };
    // 逐字段照搬静态设定，紧凑写法与上面的数据表保持一致。
    final cities = <String, City>{
      for (final def in cityDefs)
        def.id: City(
          id: def.id, name: def.name, region: def.region,
          position: def.position, terrain: def.terrain,
          neighbors: List.unmodifiable(def.neighbors),
          owner: owners[def.id]!, agriculture: def.agriculture,
          commerce: def.commerce, order: def.order, defense: def.defense,
          troops: (def.troops * (scenario.troops[owners[def.id]] ?? 1)).round(),
          training: def.training, population: def.population,
          troopType: troopTypes[def.id] ?? TroopType.infantry,
        ),
    };
    final generals = <String, General>{
      for (final def in generalDefs)
        def.id: General(
          id: def.id, name: def.name, factionId: def.factionId,
          cityId: def.cityId, wu: def.wu, intel: def.intel, lead: def.lead,
          politics: def.politics, loyalty: def.loyalty, trait: def.trait,
          skill: generalSkills[def.id] ?? GeneralSkill.none,
        ),
    };
    // 剧本改换归属后，名将随本势力迁往人口最多的城池，避免滞留敌境。
    final capitals = <String, String>{};
    for (final city in cities.values) {
      final capital = capitals[city.owner];
      if (capital == null || city.population > cities[capital]!.population) {
        capitals[city.owner] = city.id;
      }
    }
    for (final general in generals.values) {
      if (general.free) continue;
      if (cities[general.cityId]?.owner != general.factionId) {
        general.cityId = capitals[general.factionId] ?? general.cityId;
      }
    }
    // 在野武将也记在所在城池名下，登用与来投事件据此找到他们。
    for (final general in generals.values) {
      cities[general.cityId]?.generalIds.add(general.id);
    }
    // 太守：都城由君主兼任，其余城池选统率最高者。
    for (final city in cities.values) {
      final residents = city.generalIds
          .map((id) => generals[id]!)
          .where((general) => !general.free);
      if (residents.isEmpty) continue;
      final ruler = FactionDefs.byId(city.owner).ruler;
      final governor = residents.firstWhere(
        (general) => general.name == ruler,
        orElse: () =>
            residents.reduce((a, b) => a.lead >= b.lead ? a : b),
      );
      city.governor = governor.id;
    }
    final state = GameState(
      year: scenario.year,
      month: scenario.month,
      startYear: scenario.year,
      startMonth: scenario.month,
      scenarioId: scenario.id,
      factions: factions,
      cities: cities,
      generals: generals,
      playerFaction: playerFaction,
      difficulty: difficulty,
    );
    state.addChronicle(
      '${scenario.name}：${FactionDefs.byId(playerFaction).ruler} 于 '
      '${FactionDefs.byId(playerFaction).name} 起兵，天下群雄并起。',
      ChronicleKind.system,
      factionId: playerFaction,
    );
    return state;
  }
}
