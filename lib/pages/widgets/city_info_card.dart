import 'package:material_ui/material_ui.dart';

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
        InfoChip(
          icon: Icons.groups_outlined,
          text: '${city.troops}',
          plain: true,
          color: colors.onSurface,
        ),
        InfoChip(
          icon: Icons.person_outline,
          text: governor?.name ?? '无太守',
          plain: true,
        ),
        InfoChip(
          icon: Icons.shield_outlined,
          text: '${city.defense}',
          plain: true,
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
                      Text(city.region, style: hintStyle(context, size: 10)),
                    ],
                  ),
                  Text(
                    '${faction.name} · ${city.terrain.label} · ${city.troopType.label}',
                    style: hintStyle(context, size: 10.5),
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
                text: governor == null
                    ? '无太守'
                    : '太守 ${governor.name} Lv.${governor.level}',
                icon: Icons.person_outline,
                dense: true,
              ),
            ),
          ],
        ),
        const SizedBox(height: 9),
        for (final (label, value, color) in stats) ...[
          StatBar(label: label, value: value, color: color),
          if (label != stats.last.$1) const SizedBox(height: 5),
        ],
        const SizedBox(height: 9),
        Text(
          enemies.isEmpty
              ? '四境安宁，暂无接壤敌城'
              : '邻敌：${enemies.map((e) => '${e.name}（${FactionDefs.nameOf(e.owner)}）').join('、')}',
          style: hintStyle(
            context,
            size: 10.5,
            height: 1.4,
            color: enemies.isEmpty ? colors.onSurfaceVariant : colors.error,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          '本月${city.acted ? '已下令' : '可下令'} · 金收入 ${city.goldIncome} · 粮收入 ${city.foodIncome}',
          style: hintStyle(context, size: 10.5),
        ),
      ],
    );
  }
}
