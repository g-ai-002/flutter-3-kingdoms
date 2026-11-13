import 'package:flutter/material.dart';

import '../../../game/diplomacy.dart';
import '../../../game/game_controller.dart';
import '../../../models/diplomacy.dart';
import '../../../models/faction.dart';
import '../common.dart';

/// 五方势力总览：城池、兵力、钱粮、存亡与遣使交涉。
Future<void> showFactionOverviewSheet(
  BuildContext context,
  GameController controller,
) {
  return showModalBottomSheet<void>(
    context: context,
    showDragHandle: true,
    isScrollControlled: true,
    builder: (sheetContext) => StatefulBuilder(
      builder: (context, refresh) {
        final game = controller.game;
        final envoy = DiplomacyService.envoyOf(game);
        return SheetFrame(
          title: '天下势力',
          subtitle: '遣使可停战、联姻或劝降；盟约期间两不相犯',
          scrollable: true,
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
          child: Padding(
            padding: const EdgeInsets.only(top: 10),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                if (envoy != null)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: SheetLabel(
                      '使者 ${envoy.name} · 政治 ${envoy.politics}',
                    ),
                  ),
                for (final def in FactionDefs.all)
                  _FactionRow(
                    def: def,
                    isPlayer: def.id == game.playerFaction,
                    alive: game.factions[def.id]!.alive,
                    cities: game.cityCount(def.id),
                    troops: game.troopsOf(def.id),
                    gold: game.factions[def.id]!.gold,
                    food: game.factions[def.id]!.food,
                    pactMonths: game.pactMonths(game.playerFaction, def.id),
                    onEnvoy:
                        def.id == game.playerFaction ||
                            !game.factions[def.id]!.alive
                        ? null
                        : () => _openEnvoyDialog(
                            context,
                            controller,
                            def,
                            refresh,
                          ),
                  ),
              ],
            ),
          ),
        );
      },
    ),
  );
}

/// 遣使对话框：列出三种手段、费用与成算，选中后立即结算。
Future<void> _openEnvoyDialog(
  BuildContext context,
  GameController controller,
  FactionDef def,
  StateSetter refresh,
) async {
  final game = controller.game;
  final pacted = game.hasPact(game.playerFaction, def.id);
  final move = await showDialog<DiplomaticMove>(
    context: context,
    builder: (dialogContext) {
      final theme = Theme.of(dialogContext);
      return AlertDialog(
        title: Text('遣使 ${def.ruler}'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              '金钱无论成败都会消耗；实力越强、使者政治越高，成算越大。',
              style: theme.textTheme.labelSmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 10),
            for (final move in DiplomaticMove.values) ...[
              _MoveButton(
                move: move,
                gold: game.player.gold,
                chance: DiplomacyService.chanceOf(game, def.id, move),
                blocked:
                    move == DiplomaticMove.vassalize
                    ? !DiplomacyService.canVassalize(game, def.id)
                    : pacted,
                blockedLabel: move == DiplomaticMove.vassalize
                    ? '势力尚强'
                    : '已有盟约',
                onPressed: () => Navigator.of(dialogContext).pop(move),
              ),
              const SizedBox(height: 7),
            ],
          ],
        ),
      );
    },
  );
  if (move == null || !context.mounted) return;
  final result = controller.attemptDiplomacy(def.id, move);
  if (!context.mounted) return;
  refresh(() {});
  ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(SnackBar(content: Text(result.message)));
}

class _MoveButton extends StatelessWidget {
  const _MoveButton({
    required this.move,
    required this.gold,
    required this.chance,
    required this.blocked,
    required this.blockedLabel,
    required this.onPressed,
  });

  final DiplomaticMove move;
  final int gold;
  final double chance;
  final bool blocked;
  final String blockedLabel;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final affordable = gold >= move.goldCost;
    return OutlinedButton(
      onPressed: blocked || !affordable ? null : onPressed,
      style: OutlinedButton.styleFrom(
        alignment: Alignment.centerLeft,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '${move.label} · ${move.goldCost} 金',
                  style: theme.textTheme.titleSmall?.copyWith(fontSize: 13),
                ),
                Text(
                  move.summary,
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: colors.onSurfaceVariant,
                    fontSize: 10.5,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Text(
            blocked
                ? blockedLabel
                : affordable
                ? '成算 ${(chance * 100).round()}%'
                : '金钱不足',
            style: theme.textTheme.labelSmall?.copyWith(
              color: blocked || !affordable ? colors.outline : colors.primary,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
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
    required this.pactMonths,
    required this.onEnvoy,
  });

  final FactionDef def;
  final bool isPlayer;
  final bool alive;
  final int cities;
  final int troops;
  final int gold;
  final int food;
  final int pactMonths;
  final VoidCallback? onEnvoy;

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
                  Wrap(
                    spacing: 6,
                    runSpacing: 2,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: [
                      Text(
                        '$cities 城 · 兵 $troops · 金 $gold · 粮 $food',
                        style: theme.textTheme.labelSmall?.copyWith(
                          color: colors.onSurfaceVariant,
                        ),
                      ),
                      if (pactMonths > 0)
                        InfoChip(
                          text: '盟约 $pactMonths 月',
                          dense: true,
                          color: colors.tertiary,
                        ),
                    ],
                  ),
                ],
              ),
            ),
            if (onEnvoy != null)
              TextButton.icon(
                onPressed: onEnvoy,
                icon: const Icon(Icons.send_outlined, size: 14),
                label: const Text('遣使'),
                style: TextButton.styleFrom(
                  minimumSize: const Size(0, 30),
                  padding: const EdgeInsets.symmetric(horizontal: 6),
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  textStyle: theme.textTheme.labelSmall,
                ),
              ),
          ],
        ),
      ),
    );
  }
}
