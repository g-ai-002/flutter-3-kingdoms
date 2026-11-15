import 'package:material_ui/material_ui.dart';

import '../../game/game_controller.dart';
import '../../models/city.dart';
import '../../models/faction.dart';
import '../../theme/app_theme.dart';
import '../../utils/formatters.dart';
import 'city_info_card.dart';
import 'common.dart';
import 'map_hud.dart';

/// 左上角：势力印、年月与钱粮兵力。
class GameFactionCard extends StatelessWidget {
  const GameFactionCard({super.key, required this.controller});

  final GameController controller;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final game = controller.game;
    final faction = game.player;
    final def = FactionDefs.byId(game.playerFaction);
    final compact = HudScope.compactOf(context);
    final hint = hintStyle(context, size: compact ? 9.5 : 10);
    final identity = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          def.display,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: theme.textTheme.titleSmall?.copyWith(
            fontSize: compact ? 12.5 : 13,
          ),
        ),
        Text(
          formatYearMonth(game.year, game.month),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: hint,
        ),
        // 侧栏可能只有一百多像素宽：紧凑模式把钱粮并进第二三行，不另起标签。
        if (compact)
          Text(
            '金 ${faction.gold} · 粮 ${faction.food}',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: hint,
          ),
      ],
    );
    final seal = FactionSeal(
      factionId: game.playerFaction,
      size: compact ? 26 : 30,
    );
    final identityRow = Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        seal,
        SizedBox(width: compact ? 7 : 8),
        if (compact) Flexible(child: identity) else identity,
      ],
    );
    if (compact) return identityRow;
    return Wrap(
      spacing: 6,
      runSpacing: 4,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        identityRow,
        InfoChip(
          text: '城 ${game.tallyOf(game.playerFaction).cities}',
          dense: true,
          color: def.color,
        ),
        InfoChip(text: '金 ${faction.gold}', dense: true, color: appGold),
        InfoChip(text: '粮 ${faction.food}', dense: true, color: appJade),
      ],
    );
  }
}

/// 城池信息卡；未选中城池时只留一行点选提示。
class GameInfoPanel extends StatelessWidget {
  const GameInfoPanel({super.key, required this.controller});

  final GameController controller;

  @override
  Widget build(BuildContext context) {
    final city = controller.selectedCity;
    if (city != null) {
      return CityInfoCard(
        controller: controller,
        city: city,
        compact: HudScope.compactOf(context),
      );
    }
    final theme = Theme.of(context);
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(
          Icons.touch_app_outlined,
          size: 15,
          color: theme.colorScheme.onSurfaceVariant,
        ),
        const SizedBox(width: 5),
        Flexible(
          child: Text(
            HudScope.compactOf(context) ? '点选城池' : '点选城池查看详情；选中本方城池后可下令',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: hintStyle(context),
          ),
        ),
      ],
    );
  }
}

/// 顶栏工具：返回首页、存档、玩法说明与设置。
class GameTopTools extends StatelessWidget {
  const GameTopTools({
    super.key, required this.onHome, required this.onSave,
    required this.onHelp, required this.onSettings,
  });

  final VoidCallback onHome;
  final VoidCallback onSave;
  final VoidCallback onHelp;
  final VoidCallback onSettings;

  @override
  Widget build(BuildContext context) {
    // 侧栏很窄时四个按钮折成两行，不再横向溢出。
    return Wrap(
      alignment: WrapAlignment.end,
      children: [
        HudIconButton(
          icon: Icons.home_outlined,
          tooltip: '返回首页',
          onPressed: onHome,
          size: 18,
          box: 40,
        ),
        HudIconButton(
          icon: Icons.save_outlined,
          tooltip: '存档',
          onPressed: onSave,
          size: 18,
          box: 40,
        ),
        HudIconButton(
          icon: Icons.menu_book_outlined,
          tooltip: '玩法说明',
          onPressed: onHelp,
          size: 18,
          box: 40,
        ),
        HudIconButton(
          icon: Icons.settings_outlined,
          tooltip: '设置',
          onPressed: onSettings,
          size: 18,
          box: 40,
        ),
      ],
    );
  }
}

/// 底部悬浮操作条：城池指令与结束回合。
class GameControls extends StatelessWidget {
  const GameControls({
    super.key, required this.controller, required this.onInternal,
    required this.onCampaign, required this.onAppoint, required this.onEndTurn,
    required this.onFactions, required this.onChronicle,
    required this.onAttackSource,
  });

  final GameController controller;
  final ValueChanged<City> onInternal;
  final void Function(City source, {City? preferred}) onCampaign;
  final ValueChanged<City> onAppoint;
  final VoidCallback onEndTurn;
  final VoidCallback onFactions;
  final VoidCallback onChronicle;
  final City? Function(City target) onAttackSource;

  @override
  Widget build(BuildContext context) {
    // 操作条按屏幕宽度决定是否只留图标：手机横屏放得下文字，竖屏与窄窗才收成图标。
    final compact = MediaQuery.sizeOf(context).width < 480;
    final city = controller.selectedCity;
    final own = city != null && city.owner == controller.game.playerFaction;
    final enemy = city != null && !own;
    final canCampaign =
        own && controller.game.enemyNeighbors(city).isNotEmpty && !city.acted;
    final source = enemy ? onAttackSource(city) : null;
    final canAttack = enemy && source != null;
    final locked = controller.finished;
    return Wrap(
      alignment: WrapAlignment.center,
      crossAxisAlignment: WrapCrossAlignment.center,
      spacing: 4,
      runSpacing: 4,
      children: [
        if (own) ...[
          _action(
            context,
            compact,
            Icons.agriculture_outlined,
            '内政',
            locked || city.acted ? null : () => onInternal(city),
          ),
          _action(
            context,
            compact,
            Icons.gavel_rounded,
            '出征',
            !locked && canCampaign ? () => onCampaign(city) : null,
          ),
          _action(
            context,
            compact,
            Icons.groups_2_outlined,
            '人事',
            locked ? null : () => onAppoint(city),
          ),
        ],
        if (enemy)
          _action(
            context,
            compact,
            Icons.gavel_rounded,
            '攻打',
            !locked && canAttack
                ? () => onCampaign(source, preferred: city)
                : null,
          ),
        _action(
          context,
          compact,
          Icons.public_outlined,
          '势力',
          locked ? null : onFactions,
        ),
        _action(
          context,
          compact,
          Icons.history_edu_outlined,
          '战报',
          onChronicle,
        ),
        const SizedBox(width: 6),
        FilledButton.icon(
          onPressed: controller.finished ? null : onEndTurn,
          icon: const Icon(Icons.skip_next_rounded, size: 18),
          label: Text(compact ? '结束' : '结束本月'),
          style: FilledButton.styleFrom(
            minimumSize: Size(compact ? 74 : 108, 42),
            padding: EdgeInsets.symmetric(horizontal: compact ? 10 : 16),
          ),
        ),
      ],
    );
  }

  Widget _action(
    BuildContext context,
    bool compact,
    IconData icon,
    String label,
    VoidCallback? onPressed,
  ) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final enabled = onPressed != null;
    final button = TextButton(
      onPressed: onPressed,
      style: TextButton.styleFrom(
        minimumSize: Size(compact ? 38 : 54, compact ? 38 : 42),
        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
        padding: EdgeInsets.symmetric(
          horizontal: compact ? 2 : 4,
          vertical: compact ? 0 : 2,
        ),
        foregroundColor: enabled ? colors.onSurface : colors.onSurfaceVariant,
      ),
      child: compact
          ? Icon(icon, size: 20)
          : Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(icon, size: 19),
                const SizedBox(height: 1),
                Text(
                  label,
                  style: theme.textTheme.labelSmall?.copyWith(
                    fontSize: 10,
                    color: enabled ? colors.onSurface : colors.onSurfaceVariant,
                  ),
                ),
              ],
            ),
    );
    return compact ? Tooltip(message: label, child: button) : button;
  }
}
