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
    final envoys =
        state.generals.values
            .where((general) => general.factionId == state.playerFaction)
            .toList()
          ..sort((a, b) => b.politics.compareTo(a.politics));
    return envoys.isEmpty ? null : envoys.first;
  }

  /// 势力实力估值：兵力与城池数的综合，用于成算与劝降判断。
  static int powerOf(GameState state, String factionId) {
    final tally = state.tallyOf(factionId);
    return tally.troops + tally.cities * 900;
  }

  /// 三种手段的成算，一次算齐使者与双方实力，供面板并列展示。
  static Map<DiplomaticMove, double> oddsOf(GameState state, String targetId) {
    final politics = envoyOf(state)?.politics ?? 60;
    final mine = powerOf(state, state.playerFaction);
    final theirs = max(1, powerOf(state, targetId));
    final ratio = mine / theirs;
    final edge = (ratio - 1).clamp(0.0, 1.0);
    return {
      for (final move in DiplomaticMove.values)
        move: switch (move) {
          DiplomaticMove.truce =>
            (0.28 + politics / 260 + edge * 0.18).clamp(0.08, 0.9).toDouble(),
          DiplomaticMove.marriage =>
            (0.20 + politics / 300 + edge * 0.16).clamp(0.08, 0.9).toDouble(),
          DiplomaticMove.vassalize =>
            (0.06 + politics / 420 + (ratio - 1.8).clamp(0.0, 2.4) * 0.22)
                .clamp(0.08, 0.9)
                .toDouble(),
        },
    };
  }

  /// 单一手段的成算，保留给调用方单独查询。
  static double chanceOf(
    GameState state,
    String targetId,
    DiplomaticMove move,
  ) => oddsOf(state, targetId)[move]!;

  /// 仅余两城以内的势力才可能被劝降。
  static bool canVassalize(GameState state, String targetId) =>
      state.cityCount(targetId) <= 2;

  /// 遣使前的校验，返回拒绝理由；可出使时返回 null。
  static String? _rejectReason(
    GameState state,
    String targetId,
    DiplomaticMove move,
  ) {
    final target = state.factions[targetId];
    if (target == null || targetId == state.playerFaction) return '目标无效';
    if (!target.alive || !state.hasCities(targetId)) return '该势力已亡';
    if (move != DiplomaticMove.vassalize &&
        state.hasPact(state.playerFaction, targetId)) {
      return '已与${FactionDefs.nameOf(targetId)}盟约，无需再遣使';
    }
    if (move == DiplomaticMove.vassalize && !canVassalize(state, targetId)) {
      return '其势力尚强，不肯归降';
    }
    if (state.player.gold < move.goldCost) return '金钱不足';
    return null;
  }

  static OrderResult attempt(
    GameState state,
    String targetId,
    DiplomaticMove move,
    Random random,
  ) {
    final reason = _rejectReason(state, targetId, move);
    if (reason != null) return OrderResult(success: false, message: reason);
    state.player.gold -= move.goldCost;

    final envoy = envoyOf(state);
    final envoyName =
        envoy?.name ?? FactionDefs.byId(state.playerFaction).ruler;
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
