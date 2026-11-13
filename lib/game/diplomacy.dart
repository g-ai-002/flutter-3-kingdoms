import 'dart:math';

import '../models/chronicle.dart';
import '../models/diplomacy.dart';
import '../models/faction.dart';
import '../models/game_state.dart';
import '../models/general.dart';
import 'order_result.dart';

/// 外交结算：使者、成算、盟约与劝降后的势力归并。
class DiplomacyService {
  DiplomacyService._();

  /// 出使武将：本方政治最高者；无将时由君主亲往。
  static General? envoyOf(GameState state) {
    final envoys = state.generals.values
        .where((general) => general.factionId == state.playerFaction)
        .toList()
      ..sort((a, b) => b.politics.compareTo(a.politics));
    return envoys.isEmpty ? null : envoys.first;
  }

  /// 势力实力估值：兵力与城池数的综合，用于成算与劝降判断。
  static int powerOf(GameState state, String factionId) =>
      state.troopsOf(factionId) + state.cityCount(factionId) * 900;

  /// 成算：使者政治、双方实力差与手段难度共同决定。
  static double chanceOf(
    GameState state,
    String targetId,
    DiplomaticMove move,
  ) {
    final politics = envoyOf(state)?.politics ?? 60;
    final mine = powerOf(state, state.playerFaction);
    final theirs = max(1, powerOf(state, targetId));
    final edge = (mine / theirs - 1).clamp(0.0, 1.0);
    final chance = switch (move) {
      DiplomaticMove.truce => 0.28 + politics / 260 + edge * 0.18,
      DiplomaticMove.marriage => 0.20 + politics / 300 + edge * 0.16,
      DiplomaticMove.vassalize =>
        0.06 +
            politics / 420 +
            ((mine / theirs) - 1.8).clamp(0.0, 2.4) * 0.22,
    };
    return chance.clamp(0.08, 0.9).toDouble();
  }

  /// 仅余两城以内的势力才可能被劝降。
  static bool canVassalize(GameState state, String targetId) =>
      state.cityCount(targetId) <= 2;

  static OrderResult attempt(
    GameState state,
    String targetId,
    DiplomaticMove move,
    Random random,
  ) {
    final target = state.factions[targetId];
    if (target == null || targetId == state.playerFaction) {
      return const OrderResult(success: false, message: '目标无效');
    }
    if (!target.alive || !state.hasCities(targetId)) {
      return const OrderResult(success: false, message: '该势力已亡');
    }
    if (move != DiplomaticMove.vassalize &&
        state.hasPact(state.playerFaction, targetId)) {
      return OrderResult(
        success: false,
        message: '已与${FactionDefs.nameOf(targetId)}盟约，无需再遣使',
      );
    }
    if (move == DiplomaticMove.vassalize && !canVassalize(state, targetId)) {
      return const OrderResult(success: false, message: '其势力尚强，不肯归降');
    }
    if (state.player.gold < move.goldCost) {
      return const OrderResult(success: false, message: '金钱不足');
    }
    state.player.gold -= move.goldCost;

    final envoy = envoyOf(state);
    final envoyName = envoy?.name ?? FactionDefs.byId(state.playerFaction).ruler;
    final targetName = FactionDefs.nameOf(targetId);
    final chance = chanceOf(state, targetId, move);
    if (random.nextDouble() > chance) {
      state.addChronicle(
        '$envoyName 出使 $targetName，${move.label}未成，成算 ${(chance * 100).round()}%。',
        ChronicleKind.event,
        factionId: state.playerFaction,
      );
      return OrderResult(
        success: false,
        message: '$targetName 拒绝了${move.label}，使者无功而返',
      );
    }

    if (move == DiplomaticMove.vassalize) {
      final cities = _vassalize(state, targetId, envoyName);
      return OrderResult(
        success: true,
        message: '$targetName 举城归附 · 得城 $cities 座',
        effects: {'归附城池': cities},
      );
    }
    state.makePact(state.playerFaction, targetId, move.months);
    state.addChronicle(
      '$envoyName 出使 $targetName，${move.label}告成，'
      '两家约定 ${move.months} 个月内互不兴兵。',
      ChronicleKind.event,
      factionId: state.playerFaction,
    );
    return OrderResult(
      success: true,
      message: '$targetName 接受${move.label} · 盟约 ${move.months} 个月',
      effects: {'盟约月数': move.months},
    );
  }

  /// 劝降成功：城池、武将、半数钱粮并入本方，原势力退出争霸。
  static int _vassalize(GameState state, String targetId, String envoyName) {
    final target = state.factions[targetId]!;
    final cities = state.citiesOf(targetId).toList();
    for (final city in cities) {
      city.owner = state.playerFaction;
      city.acted = true;
    }
    var generals = 0;
    for (final general in state.generals.values) {
      if (general.factionId != targetId) continue;
      general.factionId = state.playerFaction;
      general.loyalty = max(40, general.loyalty - 20);
      generals++;
    }
    state.player.gold += target.gold ~/ 2;
    state.player.food += target.food ~/ 2;
    target
      ..gold = 0
      ..food = 0
      ..alive = false;
    state.clearPactsWith(targetId);
    state.addChronicle(
      '$envoyName 说降 ${FactionDefs.nameOf(targetId)}，'
      '${cities.length} 城、$generals 将归附，天下震动。',
      ChronicleKind.event,
      factionId: state.playerFaction,
    );
    return cities.length;
  }
}
