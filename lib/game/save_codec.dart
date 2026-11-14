import 'dart:convert';

import '../models/chronicle.dart';
import '../models/difficulty.dart';
import '../models/faction.dart';
import '../models/game_state.dart';
import 'data/scenario.dart';

/// 存档摘要：首页与存档槽位用它展示年月、势力与城池数。
class SaveSummary {
  const SaveSummary({
    required this.year,
    required this.month,
    required this.factionId,
    required this.cityCount,
    this.scenarioId = '',
    this.savedAt,
  });

  final int year;
  final int month;
  final String factionId;
  final int cityCount;
  final String scenarioId;
  final DateTime? savedAt;

  String get label {
    final scenario = Scenario.byId(scenarioId);
    final tag = scenario.id == Scenario.defaultScenarioId
        ? ''
        : '${scenario.name} · ';
    return '$tag$year年$month月 · ${FactionDefs.byId(factionId).name} · $cityCount 城';
  }
}

/// 存档编解码：只写动态状态，城池地形、武将与剧本常量从剧本重建。
class SaveCodec {
  SaveCodec._();

  static const int version = 1;

  static String encode(GameState state) => jsonEncode(_toMap(state));

  static Map<String, dynamic> _toMap(GameState state) {
    return {
      'v': version,
      'savedAt': DateTime.now().toIso8601String(),
      'year': state.year,
      'month': state.month,
      'player': state.playerFaction,
      'scenario': state.scenarioId,
      'difficulty': state.difficulty.name,
      'finished': state.finished,
      'outcome': state.outcome?.name,
      'factions': {
        for (final entry in state.factions.entries)
          entry.key: [
            entry.value.gold,
            entry.value.food,
            entry.value.alive ? 1 : 0,
          ],
      },
      'cities': {
        for (final city in state.cities.values)
          city.id: [
            city.owner,
            city.governor ?? '',
            city.agriculture,
            city.commerce,
            city.order,
            city.defense,
            city.troops,
            city.training,
            city.population,
            city.acted ? 1 : 0,
            city.generalIds,
          ],
      },
      'generals': {
        for (final general in state.generals.values)
          general.id: [general.factionId, general.cityId, general.loyalty],
      },
      'pacts': state.pacts,
      'chronicle': [
        for (final entry in state.recentChronicle)
          [
            entry.year,
            entry.month,
            entry.text,
            entry.kind.name,
            entry.factionId ?? '',
          ],
      ],
    };
  }

  static SaveSummary summary(String source) {
    final raw = _parse(source);
    final player = raw['player'] as String? ?? 'wei';
    final cities = raw['cities'] as Map<String, dynamic>? ?? const {};
    final owned = cities.values.where((value) {
      final row = value as List;
      return row.isNotEmpty && row.first == player;
    }).length;
    return SaveSummary(
      year: (raw['year'] as num?)?.toInt() ?? 196,
      month: (raw['month'] as num?)?.toInt() ?? 1,
      factionId: FactionDefs.isKnown(player) ? player : 'wei',
      cityCount: owned,
      scenarioId: raw['scenario'] as String? ?? '',
      savedAt: DateTime.tryParse(raw['savedAt'] as String? ?? ''),
    );
  }

  static GameState decode(String source) {
    final raw = _parse(source);
    if (raw['v'] != version) {
      throw const FormatException('存档版本不支持');
    }
    final player = raw['player'] as String? ?? '';
    if (!FactionDefs.isKnown(player)) {
      throw const FormatException('存档势力无效');
    }
    final state = Scenario.build(
      playerFaction: player,
      difficulty: Difficulty.byName(raw['difficulty'] as String?),
      scenarioId: raw['scenario'] as String?,
    );
    state.chronicle.clear();
    state.year = (raw['year'] as num?)?.toInt() ?? 196;
    state.month = ((raw['month'] as num?)?.toInt() ?? 1).clamp(1, 12).toInt();
    state.finished = raw['finished'] == true;
    final outcome = raw['outcome'];
    state.outcome = null;
    for (final item in GameOutcome.values) {
      if (item.name == outcome) state.outcome = item;
    }

    final factions = raw['factions'] as Map<String, dynamic>? ?? const {};
    for (final entry in factions.entries) {
      final faction = state.factions[entry.key];
      if (faction == null) continue;
      final row = entry.value as List;
      faction.gold = (row[0] as num).toInt();
      faction.food = (row[1] as num).toInt();
      faction.alive = row[2] == 1;
    }

    final cities = raw['cities'] as Map<String, dynamic>? ?? const {};
    for (final entry in cities.entries) {
      final city = state.cities[entry.key];
      if (city == null) continue;
      final row = entry.value as List;
      city.owner = row[0] as String;
      city.governor = (row[1] as String).isEmpty ? null : row[1] as String;
      city.agriculture = (row[2] as num).toInt();
      city.commerce = (row[3] as num).toInt();
      city.order = (row[4] as num).toInt();
      city.defense = (row[5] as num).toInt();
      city.troops = (row[6] as num).toInt();
      city.training = (row[7] as num).toInt();
      city.population = (row[8] as num).toInt();
      city.acted = row[9] == 1;
      city.generalIds
        ..clear()
        ..addAll((row[10] as List).cast<String>());
    }

    final generals = raw['generals'] as Map<String, dynamic>? ?? const {};
    for (final entry in generals.entries) {
      final general = state.generals[entry.key];
      if (general == null) continue;
      final row = entry.value as List;
      general.factionId = row[0] as String;
      general.cityId = row[1] as String;
      general.loyalty = (row[2] as num).toInt();
    }

    final pacts = raw['pacts'] as Map<String, dynamic>? ?? const {};
    state.pacts
      ..clear()
      ..addAll({
        for (final entry in pacts.entries)
          entry.key: (entry.value as num).toInt(),
      });

    for (final value in (raw['chronicle'] as List? ?? const [])) {
      final row = value as List;
      state.chronicle.add(
        Chronicle(
          year: (row[0] as num).toInt(),
          month: (row[1] as num).toInt(),
          text: row[2] as String,
          kind: ChronicleKind.values.firstWhere(
            (item) => item.name == row[3],
            orElse: () => ChronicleKind.system,
          ),
          factionId: (row[4] as String).isEmpty ? null : row[4] as String,
        ),
      );
    }
    return state;
  }

  static Map<String, dynamic> _parse(String source) {
    final raw = jsonDecode(source);
    if (raw is! Map<String, dynamic>) {
      throw const FormatException('存档格式错误');
    }
    return raw;
  }
}
