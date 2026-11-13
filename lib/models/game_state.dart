import 'chronicle.dart';
import 'city.dart';
import 'difficulty.dart';
import 'faction.dart';
import 'general.dart';

/// 一局争霸的最终结局。
enum GameOutcome { victory, defeat }

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

  Iterable<City> get allCities => cities.values;

  Iterable<City> citiesOf(String factionId) =>
      cities.values.where((city) => city.owner == factionId);

  Iterable<General> generalsOf(String factionId) => generals.values.where(
    (general) => general.factionId == factionId && !general.free,
  );

  int cityCount(String factionId) =>
      cities.values.where((city) => city.owner == factionId).length;

  int troopsOf(String factionId) => citiesOf(
    factionId,
  ).fold<int>(0, (sum, city) => sum + city.troops);

  int get totalCities => cities.length;

  /// 与本城接壤且属于其他势力的城池。
  List<City> enemyNeighbors(City city) => city.neighbors
      .map((id) => cities[id]!)
      .where((other) => other.owner != city.owner)
      .toList();

  /// 本城接壤且属于本方的城池。
  List<City> friendlyNeighbors(City city) => city.neighbors
      .map((id) => cities[id]!)
      .where((other) => other.owner == city.owner)
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
