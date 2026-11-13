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
    final colors = theme.colorScheme;
    final governor = controller.governorOf(city);
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
        Icon(Icons.groups_outlined, size: 13, color: colors.onSurfaceVariant),
        const SizedBox(width: 2),
        Text(
          '${city.troops}',
          style: theme.textTheme.labelSmall?.copyWith(
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(width: 8),
        Icon(Icons.person_outline, size: 13, color: colors.onSurfaceVariant),
        const SizedBox(width: 2),
        Text(
          governor?.name ?? '无太守',
          style: theme.textTheme.labelSmall?.copyWith(
            color: colors.onSurfaceVariant,
          ),
        ),
        const SizedBox(width: 8),
        Icon(Icons.shield_outlined, size: 13, color: colors.onSurfaceVariant),
        const SizedBox(width: 2),
        Text(
          '${city.defense}',
          style: theme.textTheme.labelSmall?.copyWith(
            color: colors.onSurfaceVariant,
          ),
        ),
      ],
    );
  }

  Widget _buildDetailed(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final governor = controller.governorOf(city);
    final faction = FactionDefs.byId(city.owner);
    final enemies = controller.game.enemyNeighbors(city);
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
                    '${faction.name} · ${city.terrain.label}',
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
        StatBar(label: '农业', value: city.agriculture, color: appJade, compact: true),
        const SizedBox(height: 5),
        StatBar(label: '商业', value: city.commerce, color: appGold, compact: true),
        const SizedBox(height: 5),
        StatBar(label: '治安', value: city.order, color: appRed, compact: true),
        const SizedBox(height: 5),
        StatBar(
          label: '训练',
          value: city.training,
          color: colors.secondary,
          compact: true,
        ),
        const SizedBox(height: 5),
        StatBar(
          label: '城防',
          value: city.defense,
          color: colors.tertiary,
          compact: true,
        ),
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
