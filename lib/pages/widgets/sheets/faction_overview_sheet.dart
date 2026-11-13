import 'package:flutter/material.dart';

import '../../../game/game_controller.dart';
import '../../../models/faction.dart';
import '../common.dart';

/// 五方势力总览：城池、兵力、钱粮与存亡。
Future<void> showFactionOverviewSheet(
  BuildContext context,
  GameController controller,
) {
  return showModalBottomSheet<void>(
    context: context,
    showDragHandle: true,
    builder: (sheetContext) {
      final theme = Theme.of(sheetContext);
      final game = controller.game;
      return SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text('天下势力', style: theme.textTheme.titleSmall),
              const SizedBox(height: 10),
              for (final def in FactionDefs.all)
                _FactionRow(
                  def: def,
                  isPlayer: def.id == game.playerFaction,
                  alive: game.factions[def.id]!.alive,
                  cities: game.cityCount(def.id),
                  troops: game.troopsOf(def.id),
                  gold: game.factions[def.id]!.gold,
                  food: game.factions[def.id]!.food,
                ),
            ],
          ),
        ),
      );
    },
  );
}

class _FactionRow extends StatelessWidget {
  const _FactionRow({
    required this.def,
    required this.isPlayer,
    required this.alive,
    required this.cities,
    required this.troops,
    required this.gold,
    required this.food,
  });

  final FactionDef def;
  final bool isPlayer;
  final bool alive;
  final int cities;
  final int troops;
  final int gold;
  final int food;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    return Padding(
      padding: const EdgeInsets.only(bottom: 9),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isPlayer ? const Color(0xFFC8A15A) : colors.outline,
          ),
          color: isPlayer
              ? colors.primaryContainer.withValues(alpha: 0.35)
              : colors.surface,
        ),
        child: Row(
          children: [
            FactionSeal(factionId: def.id, size: 34),
            const SizedBox(width: 9),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Text(
                        '${def.ruler} · ${def.name}',
                        style: theme.textTheme.titleSmall?.copyWith(
                          fontSize: 13,
                        ),
                      ),
                      if (isPlayer) ...[
                        const SizedBox(width: 5),
                        InfoChip(
                          text: '我方',
                          dense: true,
                          color: colors.primary,
                        ),
                      ],
                      if (!alive) ...[
                        const SizedBox(width: 5),
                        const InfoChip(
                          text: '已亡',
                          dense: true,
                          color: Colors.grey,
                        ),
                      ],
                    ],
                  ),
                  Text(
                    '$cities 城 · 兵 $troops · 金 $gold · 粮 $food',
                    style: theme.textTheme.labelSmall?.copyWith(
                      color: colors.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
