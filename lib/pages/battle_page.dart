import 'dart:math';

import 'package:flutter/material.dart';

import '../game/engine/battle_engine.dart';
import '../models/battle.dart';
import '../models/faction.dart';
import '../services/sound_service.dart';
import 'widgets/battle_widgets.dart';

/// 攻城战界面：双方营寨、士气与兵力条、回合战报与战术选择。
class BattlePage extends StatefulWidget {
  const BattlePage({super.key, required this.setup});

  final BattleSetup setup;

  @override
  State<BattlePage> createState() => _BattlePageState();
}

class _BattlePageState extends State<BattlePage> {
  final Random _random = Random(DateTime.now().microsecondsSinceEpoch);
  late final BattleState _state;
  bool _finishedHandled = false;

  @override
  void initState() {
    super.initState();
    _state = BattleEngine.start(widget.setup);
  }

  void _fight(BattleTactic tactic) {
    if (_state.finished) return;
    BattleEngine.fightRound(_state, tactic, _random);
    SoundService.play(GameSound.battle);
    setState(() {});
    if (_state.finished) _handleFinished();
  }

  void _autoResolve() {
    while (!_state.finished) {
      BattleEngine.fightRound(
        _state,
        BattleEngine.attackerTactic(_state, _random),
        _random,
      );
    }
    SoundService.play(GameSound.battle);
    setState(() {});
    _handleFinished();
  }

  void _handleFinished() {
    if (_finishedHandled) return;
    _finishedHandled = true;
    SoundService.play(
      _state.attackerWon ? GameSound.victory : GameSound.defeat,
    );
  }

  void _popWithResult() {
    Navigator.of(context).pop(BattleEngine.resultOf(_state));
  }

  Future<bool> _confirmRetreat() async {
    if (_state.finished) return true;
    final leave = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('鸣金收兵'),
        content: const Text('此时撤军将丢弃已方阵亡士卒，只带回七成残兵，确定撤退吗？'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('继续作战'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text('撤退'),
          ),
        ],
      ),
    );
    return leave ?? false;
  }

  Future<void> _onBack() async {
    if (_state.finished) {
      _popWithResult();
      return;
    }
    if (!await _confirmRetreat()) return;
    if (!mounted) return;
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final attacker = widget.setup.attacker;
    final defender = widget.setup.defender;
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) {
        if (didPop) return;
        _onBack();
      },
      child: Scaffold(
        body: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [
                const Color(0xFF241812),
                const Color(0xFF140D08),
                colors.surface.withValues(alpha: 0.98),
              ],
            ),
          ),
          child: SafeArea(
            child: Stack(
              children: [
                Positioned.fill(
                  // 战场底图只跟双方势力色有关，独立成层后回合切换不必重绘光带。
                  child: RepaintBoundary(
                    child: CustomPaint(
                      painter: BattlefieldPainter(
                        attackerColor: FactionDefs.colorOf(attacker.factionId),
                        defenderColor: FactionDefs.colorOf(defender.factionId),
                      ),
                    ),
                  ),
                ),
                Column(
                  children: [
                    _buildTopBar(theme, attacker, defender),
                    Padding(
                      padding: const EdgeInsets.fromLTRB(10, 4, 10, 8),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(
                            child: BattleCampCard(
                              side: attacker,
                              label: '攻方',
                              alignEnd: false,
                            ),
                          ),
                          BattleRoundBadge(round: _state.round),
                          Expanded(
                            child: BattleCampCard(
                              side: defender,
                              label: '守方',
                              alignEnd: true,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Expanded(child: _buildLog()),
                    if (!_state.finished) _buildTactics(),
                  ],
                ),
                if (_state.finished)
                  BattleResultOverlay(state: _state, onDone: _popWithResult),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildTopBar(
    ThemeData theme,
    BattleSide attacker,
    BattleSide defender,
  ) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(6, 4, 10, 2),
      child: Row(
        children: [
          IconButton(
            tooltip: '撤退',
            onPressed: _onBack,
            icon: const Icon(Icons.arrow_back_rounded, size: 20),
            color: const Color(0xFFEBD9BC),
          ),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '${attacker.cityName} 攻 ${defender.cityName}',
                  style: const TextStyle(
                    color: Color(0xFFF3E3C6),
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                Text(
                  '第 ${_state.round} 回合 · 共 ${BattleState.maxRounds} 回合',
                  style: const TextStyle(
                    color: Color(0xFFB9A181),
                    fontSize: 10.5,
                  ),
                ),
              ],
            ),
          ),
          TextButton.icon(
            onPressed: _state.finished ? null : _autoResolve,
            icon: const Icon(Icons.fast_forward_rounded, size: 17),
            label: const Text('直取'),
            style: TextButton.styleFrom(
              foregroundColor: const Color(0xFFE7C778),
              textStyle: const TextStyle(fontSize: 12),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLog() {
    final entries = _state.log.length <= 5
        ? _state.log
        : _state.log.sublist(_state.log.length - 5);
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 12),
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.28),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: const Color(0xFF5A4326).withValues(alpha: 0.7),
        ),
      ),
      child: SingleChildScrollView(
        reverse: true,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            for (final entry in entries)
              Padding(
                padding: const EdgeInsets.only(bottom: 6),
                child: Text(
                  entry.text,
                  style: TextStyle(
                    color: switch (entry.kind) {
                      BattleLogKind.result => const Color(0xFFF0CE8C),
                      BattleLogKind.duel => const Color(0xFFE8A87C),
                      BattleLogKind.tactic => const Color(0xFFE3D5BC),
                      BattleLogKind.normal => const Color(0xFFC9B89D),
                    },
                    fontSize: 11.5,
                    height: 1.45,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildTactics() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(10, 8, 10, 12),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final count = BattleTactic.values.length;
          final width = (constraints.maxWidth - 8 * (count - 1)) / count;
          return Row(
            children: [
              for (final tactic in BattleTactic.values) ...[
                SizedBox(
                  width: width,
                  child: BattleTacticButton(
                    tactic: tactic,
                    onPressed: () => _fight(tactic),
                  ),
                ),
                if (tactic != BattleTactic.values.last)
                  const SizedBox(width: 8),
              ],
            ],
          );
        },
      ),
    );
  }
}
