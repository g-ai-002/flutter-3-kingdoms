import '../utils/constants.dart';
import 'chronicle.dart';
import 'city.dart';
import 'difficulty.dart';
import 'faction.dart';
import 'general.dart';

/// 势力版图统计：一次遍历同时得出城池数与总兵力。
typedef FactionTally = ({int cities, int troops});

/// 一局争霸的最终结局。
enum GameOutcome {
  victory('一统山河'),
  defeat('霸业成空');

  const GameOutcome(this.label);

  final String label;
}

/// 整局游戏状态：年月、五方钱粮、城池、武将与本方势力。
class GameState {
  GameState({
    required this.year,
    required this.month,
    required this.factions,
    required this.cities,
    required this.generals,
    required this.playerFaction,
    required this.difficulty,
    List<Chronicle>? chronicle,
    this.finished = false,
    this.outcome,
  }) : chronicle = chronicle ?? <Chronicle>[];

  int year;
  int month;

  final Map<String, FactionState> factions;
  final Map<String, City> cities;
  final Map<String, General> generals;
  final String playerFaction;
  final Difficulty difficulty;
  final List<Chronicle> chronicle;

  /// 两家盟约剩余月数，键为按字典序拼接的势力对。
  final Map<String, int> pacts = <String, int>{};

  bool finished;
  GameOutcome? outcome;

  FactionState get player => factions[playerFaction]!;

  bool get isVictory => outcome == GameOutcome.victory;

  /// 开局至今经过的月份，含当前月。
  int get elapsedMonths => (year - AppConstants.startYear) * 12 + month - 1;

  Iterable<City> citiesOf(String factionId) =>
      cities.values.where((city) => city.owner == factionId);

  /// 城中的本方武将，不含在野名士。
  List<General> residentsOf(City city) => city.generalIds
      .map((id) => generals[id]!)
      .where((general) => general.factionId == city.owner && !general.free)
      .toList();

  /// 城中的在野武将，可花费金钱登用。
  List<General> freeGeneralsIn(City city) => city.generalIds
      .map((id) => generals[id]!)
      .where((general) => general.free)
      .toList();

  /// 可出任攻城主将的武将，按攻城战力从高到低。
  List<General> attackLeaders(City city) =>
      residentsOf(city)
        ..sort((a, b) => b.attackFactor.compareTo(a.attackFactor));

  General? governorOf(City city) =>
      city.governor == null ? null : generals[city.governor];

  /// 守城主将：优先太守，其次守城战力最高的在城武将。
  General? defenderOf(City city) {
    final governor = governorOf(city);
    if (governor != null && governor.factionId == city.owner) return governor;
    final residents = residentsOf(city);
    if (residents.isEmpty) return null;
    residents.sort((a, b) => b.defenseFactor.compareTo(a.defenseFactor));
    return residents.first;
  }

  /// 势力版图：城池数与众兵，一次遍历算齐，供地图、面板与外交共用。
  FactionTally tallyOf(String factionId) {
    var cities = 0;
    var troops = 0;
    for (final city in this.cities.values) {
      if (city.owner != factionId) continue;
      cities++;
      troops += city.troops;
    }
    return (cities: cities, troops: troops);
  }

  int cityCount(String factionId) => tallyOf(factionId).cities;

  int troopsOf(String factionId) => tallyOf(factionId).troops;

  /// 势力每月的金、粮收入与粮草消耗，一次遍历算齐，
  /// 避免结算时对同一批城池反复扫描。
  ({int gold, int food, int upkeep}) economyOf(String factionId) {
    var gold = 0;
    var food = 0;
    var upkeep = 0;
    for (final city in cities.values) {
      if (city.owner != factionId) continue;
      gold += city.goldIncome;
      food += city.foodIncome;
      upkeep += city.foodUpkeep;
    }
    return (gold: gold, food: food, upkeep: upkeep);
  }

  /// 势力每月粮草消耗，逐城累加。
  int upkeepOf(String factionId) => economyOf(factionId).upkeep;

  int get totalCities => cities.length;

  /// 与本城接壤且属于其他势力的城池。
  List<City> enemyNeighbors(City city) => city.neighbors
      .map((id) => cities[id]!)
      .where((other) => other.owner != city.owner)
      .toList();

  /// 某势力是否仍据有城池。
  bool hasCities(String factionId) =>
      cities.values.any((city) => city.owner == factionId);

  /// 按当前版图同步各势力存亡，失去全部城池者退出争霸。
  void syncAlive() {
    for (final faction in factions.values) {
      faction.alive = hasCities(faction.id);
    }
  }

  String _pactKey(String a, String b) =>
      a.compareTo(b) <= 0 ? '$a|$b' : '$b|$a';

  /// 两家盟约的剩余月数，无盟约为 0。
  int pactMonths(String a, String b) => pacts[_pactKey(a, b)] ?? 0;

  bool hasPact(String a, String b) => pactMonths(a, b) > 0;

  void makePact(String a, String b, int months) {
    if (a == b || months <= 0) return;
    pacts[_pactKey(a, b)] = months;
  }

  /// 每月推进盟约，到期自动解除。
  void tickPacts() {
    final expired = <String>[];
    for (final entry in pacts.entries) {
      final left = entry.value - 1;
      if (left <= 0) {
        expired.add(entry.key);
      } else {
        pacts[entry.key] = left;
      }
    }
    for (final key in expired) {
      pacts.remove(key);
    }
  }

  void clearPactsWith(String factionId) {
    pacts.removeWhere((key, _) => key.split('|').contains(factionId));
  }

  void addChronicle(String text, ChronicleKind kind, {String? factionId}) {
    chronicle.add(
      Chronicle(
        year: year,
        month: month,
        text: text,
        kind: kind,
        factionId: factionId,
      ),
    );
  }
}
