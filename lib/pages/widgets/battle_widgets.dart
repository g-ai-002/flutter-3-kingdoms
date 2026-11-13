import 'package:flutter/material.dart';

import '../../models/battle.dart';
import '../../models/faction.dart';
import '../../models/general.dart';
import '../../theme/app_theme.dart';
import 'common.dart';

/// 攻城战双方营寨：兵力、士气、训练、城防与主将技能。
class BattleCampCard extends StatelessWidget {
  const BattleCampCard({
    super.key,
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
    final direction = alignEnd ? TextDirection.rtl : TextDirection.ltr;
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
            textDirection: direction,
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
                      side.skill == GeneralSkill.none
                          ? '${side.generalName} · 统 ${side.lead} 武 ${side.wu}'
                          : '${side.generalName} · ${side.skill.label} · '
                                '统 ${side.lead} 武 ${side.wu}',
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
            textDirection: direction,
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
          Text(
            side.troopType.label,
            textAlign: alignEnd ? TextAlign.right : TextAlign.left,
            style: const TextStyle(color: Color(0xFFC9B294), fontSize: 9.5),
          ),
        ],
      ),
    );
  }
}

/// 回合数徽章：双方营寨之间的圆形回合计数。
class BattleRoundBadge extends StatelessWidget {
  const BattleRoundBadge({super.key, required this.round});

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

/// 战术按钮：强攻、固守、火攻、突袭与撤退。
class BattleTacticButton extends StatelessWidget {
  const BattleTacticButton({
    super.key,
    required this.tactic,
    required this.onPressed,
  });

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
                color: danger
                    ? const Color(0xFFE8A197)
                    : const Color(0xFFF3E3C6),
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

/// 战果浮层：胜负标题、伤亡与入城按钮。
class BattleResultOverlay extends StatelessWidget {
  const BattleResultOverlay({
    super.key,
    required this.state,
    required this.onDone,
  });

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
class BattlefieldPainter extends CustomPainter {
  const BattlefieldPainter({
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
        colors: [attackerColor.withValues(alpha: 0.26), Colors.transparent],
      ).createShader(Offset.zero & size);
    canvas.drawRect(Offset.zero & size, left);
    final right = Paint()
      ..shader = RadialGradient(
        center: const Alignment(0.9, -0.5),
        radius: 1.1,
        colors: [defenderColor.withValues(alpha: 0.26), Colors.transparent],
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
        colors: [Colors.transparent, Colors.black.withValues(alpha: 0.5)],
        stops: const [0.55, 1],
      ).createShader(Offset.zero & size);
    canvas.drawRect(Offset.zero & size, vignette);
  }

  @override
  bool shouldRepaint(BattlefieldPainter oldDelegate) =>
      oldDelegate.attackerColor != attackerColor ||
      oldDelegate.defenderColor != defenderColor;
}
