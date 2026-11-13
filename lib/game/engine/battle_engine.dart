import 'dart:math';

import '../../models/battle.dart';
import '../../models/general.dart';

/// 回合制攻城战：双方每回合各出一策，按兵力、训练、士气、统率与城防
/// 折算战力并结算伤亡，先支撑不住或主帅撤退的一方落败。
class BattleEngine {
  BattleEngine._();

  static BattleState start(BattleSetup setup) {
    final state = BattleState(
      attacker: setup.attacker,
      defender: setup.defender,
    );
    state.addLog(
      '${setup.attacker.generalName} 率 '
      '${setup.attacker.troops} 兵自 ${setup.attacker.cityName} 杀奔 '
      '${setup.defender.cityName}，'
      '${setup.defender.generalName} 引 ${setup.defender.troops} 兵迎战。',
      BattleLogKind.result,
    );
    return state;
  }

  /// 守将的应对策略：兵少则固守，智力占优则火攻，否则强硬反击。
  static BattleTactic defenderTactic(BattleState state, Random random) {
    final ratio = state.defender.troops / max(1, state.attacker.troops);
    if (state.defender.morale < 45) return BattleTactic.hold;
    if (state.defender.intel > state.attacker.intel + 8 &&
        random.nextDouble() < 0.42) {
      return BattleTactic.fire;
    }
    if (ratio < 0.65) {
      return random.nextDouble() < 0.62
          ? BattleTactic.hold
          : BattleTactic.raid;
    }
    if (ratio > 1.2 && random.nextDouble() < 0.45) {
      return BattleTactic.assault;
    }
    return random.nextDouble() < 0.3
        ? BattleTactic.fire
        : BattleTactic.assault;
  }

  /// 进攻方的自动策略，用于 AI 对战与「快速结束」。
  static BattleTactic attackerTactic(BattleState state, Random random) {
    final ratio = state.attacker.troops / max(1, state.defender.troops);
    if (state.attacker.morale < 35) return BattleTactic.hold;
    if (ratio > 1.35 && random.nextDouble() < 0.6) {
      return BattleTactic.assault;
    }
    if (state.attacker.intel > state.defender.intel + 10 &&
        random.nextDouble() < 0.4) {
      return BattleTactic.fire;
    }
    return random.nextDouble() < 0.3
        ? BattleTactic.raid
        : BattleTactic.assault;
  }

  /// 结算一回合，返回本回合双方伤亡。
  static ({int attackerLoss, int defenderLoss}) fightRound(
    BattleState state,
    BattleTactic attackerTactic,
    Random random,
  ) {
    if (state.finished) return (attackerLoss: 0, defenderLoss: 0);
    state.round++;

    if (attackerTactic == BattleTactic.retreat) {
      final survivors = (state.attacker.troops * 0.72).round();
      state.attacker.troops = survivors;
      state.finished = true;
      state.attackerWon = false;
      state.retreated = true;
      state.addLog(
        '${state.attacker.generalName} 见势不妙，鸣金收兵，'
        '仅带回 $survivors 名残兵。',
        BattleLogKind.result,
      );
      return (attackerLoss: 0, defenderLoss: 0);
    }

    final defTactic = defenderTactic(state, random);
    final attackerPower = _power(state.attacker, attackerTactic, state.defender);
    final defenderPower = _power(state.defender, defTactic, state.attacker);
    final total = attackerPower + defenderPower;
    final share = total <= 0 ? 0.5 : attackerPower / total;

    var defenderLoss =
        (state.defender.troops * 0.2 * share +
            state.attacker.troops * 0.018) *
        (0.85 + random.nextDouble() * 0.3);
    var attackerLoss =
        (state.attacker.troops * 0.2 * (1 - share) +
            state.defender.troops * 0.018) *
        attackerTactic.exposure *
        (0.85 + random.nextDouble() * 0.3);

    // 火攻看智力，智力压制时额外焚烧粮草与营寨。
    if (attackerTactic == BattleTactic.fire) {
      final edge = ((state.attacker.intel - state.defender.intel) / 100).clamp(
        -0.35,
        0.3,
      );
      defenderLoss *= 1 + edge;
      attackerLoss *= 1 - edge * 0.6;
    }
    if (defTactic == BattleTactic.fire) {
      final edge = ((state.defender.intel - state.attacker.intel) / 100).clamp(
        -0.35,
        0.3,
      );
      attackerLoss *= 1 + edge;
      defenderLoss *= 1 - edge * 0.6;
    }
    if (attackerTactic == BattleTactic.raid) {
      defenderLoss *= 0.75 + random.nextDouble() * 0.7;
    }

    final defenderBefore = state.defender.troops;
    final attackerBefore = state.attacker.troops;
    state.defender.troops = max(0, state.defender.troops - defenderLoss.round());
    state.attacker.troops = max(0, state.attacker.troops - attackerLoss.round());
    final actualDefenderLoss = defenderBefore - state.defender.troops;
    final actualAttackerLoss = attackerBefore - state.attacker.troops;

    _updateMorale(state, actualAttackerLoss, actualDefenderLoss, random);
    if (attackerTactic == BattleTactic.hold) {
      state.attacker.morale = min(120, state.attacker.morale + 6);
    }
    if (defTactic == BattleTactic.hold) {
      state.defender.morale = min(120, state.defender.morale + 6);
    }

    state.addLog(
      '${state.attacker.generalName} ${attackerTactic.label}，'
      '${state.defender.generalName} ${defTactic.label}：'
      '敌军折损 $actualDefenderLoss，我军折损 $actualAttackerLoss。',
      BattleLogKind.tactic,
    );

    if (state.round == 1) _tryDuel(state, random);

    if (state.defender.troops <= 0) {
      state.finished = true;
      state.attackerWon = true;
      state.addLog(
        '${state.defender.cityName} 城门告破，'
        '${state.attacker.generalName} 引军入城。',
        BattleLogKind.result,
      );
    } else if (state.attacker.troops <= 0) {
      state.finished = true;
      state.attackerWon = false;
      state.addLog(
        '${state.attacker.generalName} 全军覆没，'
        '${state.defender.cityName} 守住了城池。',
        BattleLogKind.result,
      );
    } else if (state.round >= BattleState.maxRounds) {
      final survivors = (state.attacker.troops * 0.6).round();
      state.attacker.troops = survivors;
      state.finished = true;
      state.attackerWon = false;
      state.retreated = true;
      state.addLog(
        '久攻不下，粮草将尽，${state.attacker.generalName} 只得退兵，'
        '带回 $survivors 人。',
        BattleLogKind.result,
      );
    }

    return (
      attackerLoss: actualAttackerLoss,
      defenderLoss: actualDefenderLoss,
    );
  }

  /// 自动打完一场战斗，供 AI 势力之间即时结算。
  static BattleResult autoResolve(BattleSetup setup, Random random) {
    final state = start(setup);
    while (!state.finished) {
      fightRound(state, attackerTactic(state, random), random);
    }
    return resultOf(state);
  }

  static BattleResult resultOf(BattleState state) => BattleResult(
    attackerWon: state.attackerWon,
    retreated: state.retreated,
    attackerRemaining: state.attacker.troops,
    defenderRemaining: state.defender.troops,
    attackerLosses: state.attacker.initialTroops - state.attacker.troops,
    defenderLosses: state.defender.initialTroops - state.defender.troops,
    rounds: state.round,
  );

  static double _power(BattleSide side, BattleTactic tactic, BattleSide foe) {
    final traitBonus = switch (side.trait) {
      GeneralTrait.warrior => 0.08,
      GeneralTrait.commander => 0.07,
      GeneralTrait.strategist => 0.03,
      GeneralTrait.statesman => 0.0,
      GeneralTrait.balanced => 0.04,
    };
    final terrainFactor = side.attacking ? side.terrain.attackFactor : 1.0;
    final defenseFactor = 1 +
        (side.defense + side.terrain.defenseBonus * 100) / 240;
    final moraleFactor = 0.62 + side.morale / 260;
    final trainFactor = 0.62 + side.training / 220;
    final generalFactor =
        0.78 + side.lead / 240 + side.wu / 700 + traitBonus;
    final tacticFactor = switch (tactic) {
      BattleTactic.fire =>
        (1.18 + (side.intel - foe.intel) / 150).clamp(0.8, 1.7).toDouble(),
      _ => tactic.attack,
    };
    return side.troops *
        trainFactor *
        moraleFactor *
        generalFactor *
        tacticFactor *
        (side.attacking ? terrainFactor : defenseFactor);
  }

  static void _updateMorale(
    BattleState state,
    int attackerLoss,
    int defenderLoss,
    Random random,
  ) {
    final attackerRate = attackerLoss / max(1, state.attacker.troops);
    final defenderRate = defenderLoss / max(1, state.defender.troops);
    if (attackerRate > defenderRate) {
      state.attacker.morale = max(20, state.attacker.morale - 6);
      state.defender.morale = min(120, state.defender.morale + 4);
    } else if (defenderRate > attackerRate) {
      state.defender.morale = max(20, state.defender.morale - 6);
      state.attacker.morale = min(120, state.attacker.morale + 4);
    }
    if (state.attacker.troops < state.attacker.initialTroops * 0.35) {
      state.attacker.morale = max(15, state.attacker.morale - 2);
    }
    if (state.defender.troops < state.defender.initialTroops * 0.35) {
      state.defender.morale = max(15, state.defender.morale - 2);
    }
    // 小概率的士气波动，让同一场仗不至于完全按纸面推演。
    if (random.nextDouble() < 0.12) {
      state.attacker.morale = min(120, state.attacker.morale + 3);
      state.defender.morale = max(15, state.defender.morale - 3);
    }
  }

  static bool _tryDuel(BattleState state, Random random) {
    if (state.attacker.wu < 88 || state.defender.wu < 88) return false;
    if (random.nextDouble() > 0.3) return false;
    final attackerWins =
        state.attacker.wu + random.nextInt(20) >=
        state.defender.wu + random.nextInt(20);
    if (attackerWins) {
      state.defender.morale = max(20, state.defender.morale - 12);
      state.attacker.morale = min(120, state.attacker.morale + 10);
    } else {
      state.attacker.morale = max(20, state.attacker.morale - 12);
      state.defender.morale = min(120, state.defender.morale + 10);
    }
    state.addLog(
      attackerWins
          ? '${state.attacker.generalName} 阵前单挑得胜，'
                '${state.defender.generalName} 败走，守军士气大挫。'
          : '${state.defender.generalName} 出阵迎战，'
                '${state.attacker.generalName} 不敌退回本阵。',
      BattleLogKind.duel,
    );
    return true;
  }
}
