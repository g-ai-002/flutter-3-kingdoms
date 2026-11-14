import 'package:material_ui/material_ui.dart';

import '../../../game/game_controller.dart';
import '../../../game/order_result.dart';
import '../../../game/orders.dart';
import '../../../models/city.dart';
import '../../../models/general.dart';
import '../common.dart';

/// 任命、犒赏与登用：太守可随时更换，犒赏花金稳人心，在野武将可花金登用。
Future<void> showAppointmentSheet(
  BuildContext context,
  GameController controller,
  City city,
) {
  return showGameSheet<void>(
    context,
    builder: (sheetContext) => StatefulBuilder(
      builder: (context, setSheetState) {
        final theme = Theme.of(context);
        final colors = theme.colorScheme;
        final game = controller.game;
        final residents = game.residentsOf(city);
        final free = game.freeGeneralsIn(city);
        void run(OrderResult result) {
          setSheetState(() {});
          showToast(context, result.message);
        }

        return SheetFrame(
          title: '${city.name} · 人事',
          subtitle: '任命太守 · 犒赏稳心 · 太守的政治与统率影响内政与守城',
          trailing: Text(
            '金 ${game.player.gold}',
            style: hintStyle(context),
          ),
          scrollable: true,
          gap: 6,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (residents.isEmpty)
                const HintText('城中暂无武将', body: true)
              else
                for (final general in residents)
                  _GeneralTile(
                    general: general,
                    career: true,
                    leading: FactionSeal(factionId: city.owner, size: 30),
                    trailing: city.governor == general.id
                        ? Icon(Icons.check_circle, color: colors.primary)
                        : const Icon(Icons.circle_outlined, size: 18),
                    onTap: () {
                      controller.appointGovernor(general.id);
                      setSheetState(() {});
                    },
                  ),
              if (residents.isNotEmpty) ...[
                const SizedBox(height: 4),
                OutlinedButton.icon(
                  onPressed:
                      game.player.gold >= OrderService.rewardCost &&
                          residents.any((general) => general.loyalty < 100)
                      ? () => run(controller.rewardTroops())
                      : null,
                  icon: const Icon(Icons.redeem_outlined, size: 17),
                  label: const Text(
                    '犒赏三军 · ${OrderService.rewardCost} 金 · 众将忠诚 '
                    '+${OrderService.rewardLoyalty}',
                  ),
                ),
              ],
              const Divider(height: 20),
              const HintText(
                '在野武将 · 登用花费 ${OrderService.recruitGeneralCost} 金',
              ),
              const SizedBox(height: 6),
              if (free.isEmpty)
                const HintText('城中暂无在野名士', body: true)
              else
                for (final general in free)
                  _GeneralTile(
                    general: general,
                    leading: _InitialAvatar(general.name),
                    trailing: TextButton(
                      onPressed:
                          !city.acted &&
                              game.player.gold >= OrderService.recruitGeneralCost
                          ? () {
                              run(controller.recruitGeneral(general.id));
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

/// 武将行：名称、特长与技能，[career] 时另列等级、称号与忠诚。
class _GeneralTile extends StatelessWidget {
  const _GeneralTile({
    required this.general, required this.leading, required this.trailing,
    this.career = false, this.onTap,
  });

  final General general;
  final Widget leading;
  final Widget trailing;
  final bool career;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final title = StringBuffer(
      '${general.name} · ${general.trait.label}',
    );
    if (general.skill != GeneralSkill.none) {
      title.write(' · ${general.skill.label}');
    }
    final stats =
        '武 ${general.wu} · 智 ${general.intel} · '
        '统 ${general.lead} · 政 ${general.politics}';
    return ListTile(
      dense: true,
      contentPadding: EdgeInsets.zero,
      leading: leading,
      title: Text(
        title.toString(),
        style: theme.textTheme.titleSmall?.copyWith(fontSize: 13),
      ),
      subtitle: Text(
        career
            ? 'Lv.${general.level} ${general.rank} · $stats · 忠 ${general.loyalty}'
            : stats,
        style: hintStyle(context),
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
