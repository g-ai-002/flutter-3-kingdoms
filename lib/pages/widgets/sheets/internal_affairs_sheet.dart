import 'package:flutter/material.dart';

import '../../../game/game_controller.dart';
import '../../../game/orders.dart';
import '../../../models/city.dart';
import '../../../models/faction.dart';
import '../../../theme/app_theme.dart';
import '../common.dart';

IconData actionIcon(CityAction action) => switch (action) {
  CityAction.reclaim => Icons.grass_outlined,
  CityAction.trade => Icons.storefront_outlined,
  CityAction.patrol => Icons.shield_outlined,
  CityAction.recruit => Icons.groups_outlined,
  CityAction.train => Icons.fitness_center_outlined,
  CityAction.fortify => Icons.fort_outlined,
};

/// 内政指令面板：列出六条指令与花费，已下令或资源不足时置灰。
Future<CityAction?> showInternalAffairsSheet(
  BuildContext context,
  GameController controller,
  City city,
) {
  final colors = Theme.of(context).colorScheme;
  final faction = controller.game.player;
  return showModalBottomSheet<CityAction>(
    context: context,
    showDragHandle: true,
    builder: (sheetContext) => SheetFrame(
      title: '${city.name} · 内政',
      subtitle: '金 ${faction.gold} · 粮 ${faction.food} · 每城每月限一条指令',
      trailing: InfoChip(
        text: city.acted ? '本月已下令' : '本月可下令',
        color: city.acted ? colors.error : appJade,
        dense: true,
      ),
      child: Padding(
        padding: const EdgeInsets.only(top: 10),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            for (final action in CityAction.values)
              Padding(
                padding: const EdgeInsets.only(bottom: 7),
                child: _ActionTile(
                  action: action,
                  enabled: !city.acted && _affordable(faction, action),
                  onTap: () => Navigator.of(sheetContext).pop(action),
                ),
              ),
          ],
        ),
      ),
    ),
  );
}

bool _affordable(FactionState faction, CityAction action) =>
    faction.gold >= action.goldCost && faction.food >= action.foodCost;

class _ActionTile extends StatelessWidget {
  const _ActionTile({
    required this.action,
    required this.enabled,
    required this.onTap,
  });

  final CityAction action;
  final bool enabled;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final tone = enabled ? colors.primary : colors.onSurfaceVariant;
    return Material(
      color: colors.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: colors.outline),
      ),
      child: InkWell(
        onTap: enabled ? onTap : null,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
          child: Row(
            children: [
              Container(
                width: 34,
                height: 34,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: tone.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(9),
                ),
                child: Icon(actionIcon(action), size: 18, color: tone),
              ),
              const SizedBox(width: 9),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      action.label,
                      style: theme.textTheme.titleSmall?.copyWith(
                        fontSize: 13,
                        color: enabled
                            ? colors.onSurface
                            : colors.onSurfaceVariant,
                      ),
                    ),
                    Text(
                      action.description,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.labelSmall?.copyWith(
                        color: colors.onSurfaceVariant,
                        fontSize: 10.5,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 6),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  if (action.goldCost > 0)
                    InfoChip(
                      text: '金 ${action.goldCost}',
                      dense: true,
                      color: appGold,
                    ),
                  if (action.foodCost > 0) ...[
                    const SizedBox(height: 3),
                    InfoChip(
                      text: '粮 ${action.foodCost}',
                      dense: true,
                      color: appJade,
                    ),
                  ],
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
