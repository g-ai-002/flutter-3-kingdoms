import 'dart:math';

import 'package:flutter/material.dart';

import '../game/engine/battle_engine.dart';
import '../models/battle.dart';
import '../models/faction.dart';
import '../services/sound_service.dart';
import '../theme/app_theme.dart';
import 'widgets/common.dart';

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
                  child: CustomPaint(
                    painter: _BattlefieldPainter(
                      attackerColor: FactionDefs.colorOf(attacker.factionId),
                      defenderColor: FactionDefs.colorOf(defender.factionId),
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
                            child: _CampCard(
                              side: attacker,
                              label: '攻方',
                              alignEnd: false,
                            ),
                          ),
                          _RoundBadge(round: _state.round),
                          Expanded(
                            child: _CampCard(
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
                  _ResultOverlay(
                    state: _state,
                    onDone: _popWithResult,
                  ),
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
        border: Border.all(color: const Color(0xFF5A4326).withValues(alpha: 0.7)),
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
                  child: _TacticButton(
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

class _CampCard extends StatelessWidget {
  const _CampCard({
    required this.side,
    required this.label,
    required this.alignEnd,
  });

  final BattleSide side;
  final String label;
  final bool alignEnd;

  @override
  Widget build(BuildContext context) {
    final color = FactionDefs.colorOf(side.factionId);
    final troopRatio = side.initialTroops == 0
        ? 0.0
        : (side.troops / side.initialTroops).clamp(0.0, 1.0);
    return Container(
      padding: const EdgeInsets.fromLTRB(10, 9, 10, 10),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: alignEnd ? Alignment.topRight : Alignment.topLeft,
          end: alignEnd ? Alignment.bottomLeft : Alignment.bottomRight,
          colors: [color.withValues(alpha: 0.5), color.withValues(alpha: 0.16)],
        ),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha: 0.85)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            textDirection: alignEnd ? TextDirection.rtl : TextDirection.ltr,
            children: [
              FactionSeal(factionId: side.factionId, size: 30),
              const SizedBox(width: 7),
              Expanded(
                child: Column(
                  crossAxisAlignment: alignEnd
                      ? CrossAxisAlignment.end
                      : CrossAxisAlignment.start,
                  children: [
                    Text(
                      '$label · ${side.cityName}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: Color(0xFFF6E8D0),
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    Text(
                      '${side.generalName} · 统 ${side.lead} 武 ${side.wu}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: Color(0xFFD9C4A4),
                        fontSize: 10,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Row(
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            textDirection: alignEnd ? TextDirection.rtl : TextDirection.ltr,
            children: [
              Text(
                '${side.troops}',
                style: const TextStyle(
                  color: Color(0xFFFFF4DF),
                  fontSize: 22,
                  fontWeight: FontWeight.w700,
                  height: 1,
                ),
              ),
              const SizedBox(width: 4),
              const Text(
                '兵',
                style: TextStyle(color: Color(0xFFCDB695), fontSize: 10),
              ),
            ],
          ),
          const SizedBox(height: 5),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: TweenAnimationBuilder<double>(
              tween: Tween(end: troopRatio),
              duration: const Duration(milliseconds: 320),
              curve: Curves.easeOut,
              builder: (context, value, _) => LinearProgressIndicator(
                value: value,
                minHeight: 5,
                backgroundColor: Colors.black.withValues(alpha: 0.3),
                valueColor: AlwaysStoppedAnimation(
                  Color.lerp(
                    const Color(0xFFC8503A),
                    const Color(0xFFE7C778),
                    value,
                  )!,
                ),
              ),
            ),
          ),
          const SizedBox(height: 4),
          Text(
            '士气 ${side.morale} · 训练 ${side.training} · 城防 ${side.defense}',
            textAlign: alignEnd ? TextAlign.right : TextAlign.left,
            style: const TextStyle(color: Color(0xFFC9B294), fontSize: 9.5),
          ),
        ],
      ),
    );
  }
}

class _RoundBadge extends StatelessWidget {
  const _RoundBadge({required this.round});

  final int round;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 6),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const SizedBox(height: 6),
          Container(
            width: 36,
            height: 36,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: const Color(0xFF2C1E12),
              border: Border.all(
                color: const Color(0xFFC8A15A).withValues(alpha: 0.8),
              ),
            ),
            child: Text(
              '$round',
              style: const TextStyle(
                color: Color(0xFFF0CE8C),
                fontSize: 15,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          const SizedBox(height: 3),
          const Text(
            '回合',
            style: TextStyle(color: Color(0xFFB9A181), fontSize: 9),
          ),
        ],
      ),
    );
  }
}

class _TacticButton extends StatelessWidget {
  const _TacticButton({required this.tactic, required this.onPressed});

  final BattleTactic tactic;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final danger = tactic == BattleTactic.retreat;
    final accent = danger ? const Color(0xFFA83E32) : const Color(0xFFC8A15A);
    return Tooltip(
      message: tactic.description,
      child: Material(
        color: Colors.black.withValues(alpha: 0.34),
        borderRadius: BorderRadius.circular(10),
        child: InkWell(
          borderRadius: BorderRadius.circular(10),
          onTap: onPressed,
          child: Container(
            height: 46,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: accent.withValues(alpha: 0.75)),
            ),
            child: Text(
              tactic.label,
              style: TextStyle(
                color: danger ? const Color(0xFFE8A197) : const Color(0xFFF3E3C6),
                fontSize: 13,
                fontWeight: FontWeight.w600,
                letterSpacing: 1,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _ResultOverlay extends StatelessWidget {
  const _ResultOverlay({required this.state, required this.onDone});

  final BattleState state;
  final VoidCallback onDone;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final won = state.attackerWon;
    final attacker = state.attacker;
    final defender = state.defender;
    return Positioned.fill(
      child: Container(
        color: Colors.black.withValues(alpha: 0.55),
        alignment: Alignment.center,
        padding: const EdgeInsets.all(24),
        child: Container(
          constraints: const BoxConstraints(maxWidth: 380),
          padding: const EdgeInsets.fromLTRB(20, 18, 20, 16),
          decoration: BoxDecoration(
            color: theme.colorScheme.surface,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: const Color(0xFFC8A15A)),
            boxShadow: const [
              BoxShadow(
                color: Colors.black38,
                blurRadius: 30,
                offset: Offset(0, 12),
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                won ? '大 捷' : (state.retreated ? '鸣 金 收 兵' : '败 退'),
                style: theme.textTheme.headlineMedium?.copyWith(
                  fontSize: 28,
                  letterSpacing: 10,
                  color: won ? appRed : theme.colorScheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                won
                    ? '${defender.cityName} 城门洞开，${attacker.generalName} 引军入城。'
                    : '${defender.cityName} 城防坚固，${attacker.generalName} 未能破城。',
                textAlign: TextAlign.center,
                style: theme.textTheme.bodySmall?.copyWith(height: 1.6),
              ),
              const SizedBox(height: 14),
              Row(
                children: [
                  Expanded(
                    child: _ResultStat(
                      label: '我军折损',
                      value: '${attacker.losses}',
                      color: appRed,
                    ),
                  ),
                  Expanded(
                    child: _ResultStat(
                      label: '敌军折损',
                      value: '${defender.losses}',
                      color: theme.colorScheme.tertiary,
                    ),
                  ),
                  Expanded(
                    child: _ResultStat(
                      label: '交战回合',
                      value: '${state.round}',
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                child: FilledButton(
                  onPressed: onDone,
                  child: Text(won ? '入城安民' : '收兵回城'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ResultStat extends StatelessWidget {
  const _ResultStat({
    required this.label,
    required this.value,
    required this.color,
  });

  final String label;
  final String value;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      children: [
        Text(
          value,
          style: theme.textTheme.titleMedium?.copyWith(
            color: color,
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          label,
          style: theme.textTheme.labelSmall?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
            fontSize: 10,
          ),
        ),
      ],
    );
  }
}

/// 战场底图：两侧军旗的斜向光带与暗角。
class _BattlefieldPainter extends CustomPainter {
  const _BattlefieldPainter({
    required this.attackerColor,
    required this.defenderColor,
  });

  final Color attackerColor;
  final Color defenderColor;

  @override
  void paint(Canvas canvas, Size size) {
    final left = Paint()
      ..shader = RadialGradient(
        center: const Alignment(-0.9, -0.5),
        radius: 1.1,
        colors: [
          attackerColor.withValues(alpha: 0.26),
          Colors.transparent,
        ],
      ).createShader(Offset.zero & size);
    canvas.drawRect(Offset.zero & size, left);
    final right = Paint()
      ..shader = RadialGradient(
        center: const Alignment(0.9, -0.5),
        radius: 1.1,
        colors: [
          defenderColor.withValues(alpha: 0.26),
          Colors.transparent,
        ],
      ).createShader(Offset.zero & size);
    canvas.drawRect(Offset.zero & size, right);

    final line = Paint()
      ..color = const Color(0xFFC8A15A).withValues(alpha: 0.05)
      ..strokeWidth = 1;
    for (var i = 1; i < 8; i++) {
      final y = size.height * i / 8;
      canvas.drawLine(Offset(0, y), Offset(size.width, y), line);
    }
    final vignette = Paint()
      ..shader = RadialGradient(
        center: Alignment.center,
        radius: 0.95,
        colors: [
          Colors.transparent,
          Colors.black.withValues(alpha: 0.5),
        ],
        stops: const [0.55, 1],
      ).createShader(Offset.zero & size);
    canvas.drawRect(Offset.zero & size, vignette);
  }

  @override
  bool shouldRepaint(_BattlefieldPainter oldDelegate) =>
      oldDelegate.attackerColor != attackerColor ||
      oldDelegate.defenderColor != defenderColor;
}
