import '../utils/constants.dart';
import 'chronicle.dart';
import 'city.dart';
import 'difficulty.dart';
import 'faction.dart';
import 'general.dart';

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

  bool finished;
  GameOutcome? outcome;

  FactionState get player => factions[playerFaction]!;

  bool get isVictory => outcome == GameOutcome.victory;

  /// 开局至今经过的月份，含当前月。
  int get elapsedMonths => (year - AppConstants.startYear) * 12 + month - 1;

  Iterable<City> citiesOf(String factionId) =>
      cities.values.where((city) => city.owner == factionId);

  Iterable<General> generalsOf(String factionId) => generals.values.where(
    (general) => general.factionId == factionId && !general.free,
  );

  int cityCount(String factionId) {
    var count = 0;
    for (final city in cities.values) {
      if (city.owner == factionId) count++;
    }
    return count;
  }

  int troopsOf(String factionId) {
    var total = 0;
    for (final city in cities.values) {
      if (city.owner == factionId) total += city.troops;
    }
    return total;
  }

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

  /// 势力每月金钱收入，逐城累加。
  int goldIncomeOf(String factionId) => economyOf(factionId).gold;

  /// 势力每月粮草收入，逐城累加。
  int foodIncomeOf(String factionId) => economyOf(factionId).food;

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

  void addChronicle(
    String text,
    ChronicleKind kind, {
    String? factionId,
  }) {
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
