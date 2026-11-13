import 'package:flutter/material.dart';

import '../../game/game_controller.dart';
import '../../models/city.dart';
import '../../models/faction.dart';
import '../../theme/app_theme.dart';
import 'common.dart';

/// 城池信息：横条模式压缩成一行，侧栏模式展开为完整面板。
class CityInfoCard extends StatelessWidget {
  const CityInfoCard({
    super.key,
    required this.controller,
    required this.city,
    required this.compact,
  });

  final GameController controller;
  final City city;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    return compact ? _buildCompact(context) : _buildDetailed(context);
  }

  Widget _buildCompact(BuildContext context) {
    final theme = Theme.of(context);
    final governor = controller.game.governorOf(city);
    return Wrap(
      spacing: 6,
      runSpacing: 3,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        FactionSeal(factionId: city.owner, size: 26),
        Text(
          city.name,
          style: theme.textTheme.titleSmall?.copyWith(fontSize: 14),
        ),
        InfoChip(text: city.terrain.label, dense: true),
        InfoChip(text: city.troopType.label, dense: true, color: appRed),
        _metric(Icons.groups_outlined, '${city.troops}', theme, bold: true),
        _metric(Icons.person_outline, governor?.name ?? '无太守', theme),
        _metric(Icons.shield_outlined, '${city.defense}', theme),
      ],
    );
  }

  /// 紧凑模式的一枚小指标：图标 + 文字，视觉上并入同一行。
  Widget _metric(
    IconData icon,
    String text,
    ThemeData theme, {
    bool bold = false,
  }) {
    final colors = theme.colorScheme;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        const SizedBox(width: 2),
        Icon(icon, size: 13, color: colors.onSurfaceVariant),
        const SizedBox(width: 3),
        Text(
          text,
          style: theme.textTheme.labelSmall?.copyWith(
            color: bold ? null : colors.onSurfaceVariant,
            fontWeight: bold ? FontWeight.w600 : null,
          ),
        ),
      ],
    );
  }

  Widget _buildDetailed(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final governor = controller.game.governorOf(city);
    final faction = FactionDefs.byId(city.owner);
    final enemies = controller.game.enemyNeighbors(city);
    final stats = <(String, int, Color)>[
      ('农业', city.agriculture, appJade),
      ('商业', city.commerce, appGold),
      ('治安', city.order, appRed),
      ('训练', city.training, colors.secondary),
      ('城防', city.defense, colors.tertiary),
    ];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Row(
          children: [
            FactionSeal(factionId: city.owner, size: 34),
            const SizedBox(width: 9),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Text(
                        city.name,
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontSize: 16,
                        ),
                      ),
                      const SizedBox(width: 6),
                      Text(
                        city.region,
                        style: theme.textTheme.labelSmall?.copyWith(
                          color: colors.onSurfaceVariant,
                          fontSize: 10,
                        ),
                      ),
                    ],
                  ),
                  Text(
                    '${faction.name} · ${city.terrain.label} · ${city.troopType.label}',
                    style: theme.textTheme.labelSmall?.copyWith(
                      color: colors.onSurfaceVariant,
                      fontSize: 10.5,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 9),
        Row(
          children: [
            InfoChip(
              text: '兵 ${city.troops}',
              icon: Icons.groups_outlined,
              dense: true,
              color: colors.primary,
            ),
            const SizedBox(width: 5),
            Flexible(
              child: InfoChip(
                text: governor == null ? '无太守' : '太守 ${governor.name}',
                icon: Icons.person_outline,
                dense: true,
              ),
            ),
          ],
        ),
        const SizedBox(height: 9),
        for (final (label, value, color) in stats) ...[
          StatBar(label: label, value: value, color: color, compact: true),
          if (label != stats.last.$1) const SizedBox(height: 5),
        ],
        const SizedBox(height: 9),
        Text(
          enemies.isEmpty
              ? '四境安宁，暂无接壤敌城'
              : '邻敌：${enemies.map((e) => '${e.name}（${FactionDefs.nameOf(e.owner)}）').join('、')}',
          style: theme.textTheme.labelSmall?.copyWith(
            color: enemies.isEmpty ? colors.onSurfaceVariant : colors.error,
            fontSize: 10.5,
            height: 1.4,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          '本月${city.acted ? '已下令' : '可下令'} · 金收入 ${city.goldIncome} · 粮收入 ${city.foodIncome}',
          style: theme.textTheme.labelSmall?.copyWith(
            color: colors.onSurfaceVariant,
            fontSize: 10.5,
          ),
        ),
      ],
    );
  }
}
