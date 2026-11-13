import 'package:flutter/material.dart';

import '../../../game/game_controller.dart';
import '../../../game/orders.dart';
import '../../../models/city.dart';
import '../../../models/general.dart';
import '../common.dart';

/// 任命与登用：太守可不耗指令更换，在野武将可花金登用。
Future<void> showAppointmentSheet(
  BuildContext context,
  GameController controller,
  City city,
) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    builder: (sheetContext) => StatefulBuilder(
      builder: (context, setSheetState) {
        final theme = Theme.of(context);
        final colors = theme.colorScheme;
        final residents = controller.game.residentsOf(city);
        final free = controller.game.freeGeneralsIn(city);
        return SheetFrame(
          title: '${city.name} · 人事',
          subtitle: '任命太守 · 太守的政治与统率影响内政与守城',
          trailing: Text(
            '金 ${controller.game.player.gold}',
            style: theme.textTheme.labelSmall?.copyWith(
              color: colors.onSurfaceVariant,
            ),
          ),
          scrollable: true,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const SizedBox(height: 6),
              if (residents.isEmpty)
                const EmptyHint('城中暂无武将')
              else
                for (final general in residents)
                  _GeneralTile(
                    general: general,
                    leading: FactionSeal(factionId: city.owner, size: 30),
                    trailing: city.governor == general.id
                        ? Icon(Icons.check_circle, color: colors.primary)
                        : const Icon(Icons.circle_outlined, size: 18),
                    onTap: () {
                      controller.appointGovernor(general.id);
                      setSheetState(() {});
                    },
                  ),
              const Divider(height: 20),
              const SheetLabel(
                '在野武将 · 登用花费 ${OrderService.recruitGeneralCost} 金',
              ),
              const SizedBox(height: 6),
              if (free.isEmpty)
                const EmptyHint('城中暂无在野名士')
              else
                for (final general in free)
                  _GeneralTile(
                    general: general,
                    leading: _InitialAvatar(general.name),
                    trailing: TextButton(
                      onPressed:
                          !city.acted &&
                              controller.game.player.gold >=
                                  OrderService.recruitGeneralCost
                          ? () {
                              final result = controller.recruitGeneral(
                                general.id,
                              );
                              setSheetState(() {});
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(content: Text(result.message)),
                              );
                            }
                          : null,
                      child: const Text('登用'),
                    ),
                  ),
            ],
          ),
        );
      },
    ),
  );
}

/// 武将行：人事面板中太守与在野名士共用同一套名称与能力展示。
class _GeneralTile extends StatelessWidget {
  const _GeneralTile({
    required this.general,
    required this.leading,
    required this.trailing,
    this.onTap,
  });

  final General general;
  final Widget leading;
  final Widget trailing;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    return ListTile(
      dense: true,
      contentPadding: EdgeInsets.zero,
      leading: leading,
      title: Text(
        general.skill == GeneralSkill.none
            ? '${general.name} · ${general.trait.label}'
            : '${general.name} · ${general.trait.label} · ${general.skill.label}',
        style: theme.textTheme.titleSmall?.copyWith(fontSize: 13),
      ),
      subtitle: Text(
        '武 ${general.wu} · 智 ${general.intel} · '
        '统 ${general.lead} · 政 ${general.politics}',
        style: theme.textTheme.labelSmall?.copyWith(
          color: colors.onSurfaceVariant,
        ),
      ),
      trailing: trailing,
      onTap: onTap,
    );
  }
}

class _InitialAvatar extends StatelessWidget {
  const _InitialAvatar(this.name);

  final String name;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      width: 30,
      height: 30,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        border: Border.all(color: theme.colorScheme.outline),
      ),
      child: Text(name.substring(0, 1), style: theme.textTheme.labelSmall),
    );
  }
}
