import 'dart:async';

import 'package:flame/game.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../flame/sanguo_game.dart';
import '../game/game_controller.dart';
import '../models/battle.dart';
import '../models/city.dart';
import '../models/faction.dart';
import '../providers/settings_provider.dart';
import '../services/sound_service.dart';
import '../theme/app_theme.dart';
import '../utils/formatters.dart';
import '../utils/map_display_mode.dart';
import 'battle_page.dart';
import 'help_page.dart';
import 'settings_page.dart';
import 'widgets/city_info_card.dart';
import 'widgets/common.dart';
import 'widgets/game_sheets.dart';
import 'widgets/map_hud.dart';

class GamePage extends StatefulWidget {
  const GamePage({super.key, required this.controller});

  final GameController controller;

  @override
  State<GamePage> createState() => _GamePageState();
}

class _GamePageState extends State<GamePage> {
  late final SanguoGame _game;
  bool _resultShown = false;

  GameController get controller => widget.controller;

  @override
  void initState() {
    super.initState();
    _game = SanguoGame(
      controller: controller,
      brightness: Brightness.light,
      logicRate: context.read<SettingsProvider>().logicRate,
      changes: controller,
    );
    controller.addListener(_onControllerChanged);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _game.brightness = Theme.of(context).brightness;
  }

  @override
  void dispose() {
    controller.removeListener(_onControllerChanged);
    super.dispose();
  }

  void _onControllerChanged() {
    if (!mounted) return;
    if (controller.finished && !_resultShown) {
      _resultShown = true;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _showOutcome();
      });
    }
  }

  Future<void> _showOutcome() async {
    final game = controller.game;
    await _withMapPaused(
      () => showDialog<void>(
        context: context,
        barrierDismissible: false,
        builder: (dialogContext) => AlertDialog(
          title: Text(game.outcome?.label ?? '征战未决'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                game.isVictory
                    ? '${formatYearMonth(game.year, game.month)}，'
                          '${FactionDefs.byId(game.playerFaction).ruler} 扫平群雄，天下归心。'
                    : '${formatYearMonth(game.year, game.month)}，'
                          '${FactionDefs.byId(game.playerFaction).ruler} 失尽城池，霸业中道而止。',
                style: const TextStyle(height: 1.6),
              ),
              const SizedBox(height: 12),
              Text(
                '据城 ${game.cityCount(game.playerFaction)} / ${game.totalCities}',
              ),
              Text('带甲 ${game.troopsOf(game.playerFaction)}'),
              Text('征战 ${game.elapsedMonths} 个月'),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(dialogContext).pop();
                unawaited(
                  _withMapPaused(() => showChronicleSheet(context, controller)),
                );
              },
              child: const Text('查看战报'),
            ),
            FilledButton(
              onPressed: () {
                Navigator.of(dialogContext).pop();
                Navigator.of(context).pop();
              },
              child: const Text('返回首页'),
            ),
          ],
        ),
      ),
    );
  }

  void _message(String text) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(text)));
  }

  /// 全屏页与弹层期间暂停地图渲染，关闭后按前后台状态恢复。
  Future<T> _withMapPaused<T>(Future<T> Function() action) async {
    _game.pauseForCover();
    try {
      return await action();
    } finally {
      _game.resumeAfterCover();
    }
  }

  Future<void> _openInternalAffairs(City city) async {
    if (controller.finished) return;
    final action = await _withMapPaused(
      () => showInternalAffairsSheet(context, controller, city),
    );
    if (action == null || !mounted) return;
    final result = controller.issueOrder(action);
    SoundService.play(result.success ? GameSound.order : GameSound.tap);
    _message(result.message);
  }

  Future<void> _openCampaign(City source, {City? preferred}) {
    if (controller.finished) return Future<void>.value();
    return _withMapPaused(() async {
      final request = await showCampaignSheet(
        context,
        controller,
        source,
        preferredTarget: preferred,
      );
      if (request == null || !mounted) return;
      final prepared = controller.prepareBattle(
        source: source,
        target: request.target,
        general: request.general,
        troops: request.troops,
      );
      final setup = prepared.setup;
      if (setup == null) {
        _message(prepared.error ?? '无法出征');
        return;
      }
      final result = await Navigator.of(context).push<BattleResult?>(
        MaterialPageRoute<BattleResult?>(
          builder: (_) => BattlePage(setup: setup),
        ),
      );
      controller.finishPlayerBattle(result);
    });
  }

  void _openAppointment(City city) {
    if (controller.finished) return;
    unawaited(
      _withMapPaused(() => showAppointmentSheet(context, controller, city)),
    );
  }

  void _endTurn() {
    if (controller.finished) return;
    controller.endTurn();
    SoundService.play(GameSound.turn);
    final player = controller.game.player;
    _message(
      '${formatYearMonth(controller.game.year, controller.game.month)} · '
      '金 ${player.gold} · 粮 ${player.food}',
    );
  }

  void _push(Widget page) {
    unawaited(
      _withMapPaused(
        () => Navigator.of(context).push(
          MaterialPageRoute<void>(builder: (_) => page),
        ),
      ),
    );
  }

  /// 敌方城池可进攻时，选一座接壤且未行动的本方城池作为出兵地。
  City? _attackSource(City target) {
    final candidates = target.neighbors
        .map((id) => controller.game.cities[id]!)
        .where(
          (city) =>
              city.owner == controller.game.playerFaction &&
              !city.acted &&
              city.troops >= 700,
        )
        .toList();
    if (candidates.isEmpty) return null;
    candidates.sort((a, b) => b.troops.compareTo(a.troops));
    return candidates.first;
  }

  @override
  Widget build(BuildContext context) {
    return MapDisplayMode(
      child: Scaffold(
        body: SafeArea(
          child: MapHud(
            map: _buildMap(),
            topStart: AnimatedBuilder(
              animation: controller,
              builder: (context, _) => _FactionHudCard(controller: controller),
            ),
            topEnd: _buildTools(),
            info: AnimatedBuilder(
              animation: controller,
              builder: (context, _) => _buildInfo(),
            ),
            controls: AnimatedBuilder(
              animation: controller,
              builder: (context, _) => _GameControls(
                controller: controller,
                onInternal: _openInternalAffairs,
                onCampaign: (source, {preferred}) =>
                    _openCampaign(source, preferred: preferred),
                onAppoint: _openAppointment,
                onEndTurn: _endTurn,
                onFactions: () => unawaited(
                  _withMapPaused(
                    () => showFactionOverviewSheet(context, controller),
                  ),
                ),
                onChronicle: () => unawaited(
                  _withMapPaused(() => showChronicleSheet(context, controller)),
                ),
                onAttackSource: _attackSource,
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildMap() {
    return RepaintBoundary(
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(18),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.2),
              blurRadius: 22,
              offset: const Offset(0, 10),
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(18),
          child: GameWidget<SanguoGame>(
            key: const ValueKey('sanguo-map'),
            game: _game,
          ),
        ),
      ),
    );
  }

  Widget _buildInfo() {
    final city = controller.selectedCity;
    if (city == null) {
      return Builder(
        builder: (ctx) {
          final colors = Theme.of(ctx).colorScheme;
          final compact = HudScope.compactOf(ctx);
          return Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.touch_app_outlined,
                size: 15,
                color: colors.onSurfaceVariant,
              ),
              const SizedBox(width: 5),
              Flexible(
                child: Text(
                  compact ? '点选城池' : '点选城池查看详情；选中本方城池后可下令',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(ctx).textTheme.labelSmall?.copyWith(
                    color: colors.onSurfaceVariant,
                  ),
                ),
              ),
            ],
          );
        },
      );
    }
    return Builder(
      builder: (ctx) => CityInfoCard(
        controller: controller,
        city: city,
        compact: HudScope.compactOf(ctx),
      ),
    );
  }

  Widget _buildTools() {
    return Wrap(
      spacing: 0,
      runSpacing: 0,
      children: [
        _tool(
          Icons.menu_book_outlined,
          '玩法说明',
          () => _push(const HelpPage()),
        ),
        _tool(Icons.settings_outlined, '设置', () => _push(const SettingsPage())),
      ],
    );
  }

  Widget _tool(IconData icon, String tooltip, VoidCallback onTap) {
    // 顶栏只放说明与设置，势力 / 战报已由底部操作条承担。
    return IconButton(
      tooltip: tooltip,
      onPressed: onTap,
      icon: Icon(icon, size: 18),
      padding: EdgeInsets.zero,
      visualDensity: VisualDensity.compact,
      constraints: const BoxConstraints.tightFor(width: 28, height: 28),
    );
  }
}

/// 左上角：势力印、年月与钱粮兵力。
class _FactionHudCard extends StatelessWidget {
  const _FactionHudCard({required this.controller});

  final GameController controller;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final game = controller.game;
    final faction = game.player;
    final def = FactionDefs.byId(game.playerFaction);
    final compact = HudScope.compactOf(context);
    final resources = '金 ${faction.gold} · 粮 ${faction.food}';
    final identity = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          '${def.ruler} · ${def.name}',
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
          style: theme.textTheme.labelSmall?.copyWith(
            color: colors.onSurfaceVariant,
            fontSize: compact ? 9.5 : 10,
          ),
        ),
        // 侧栏可能只有一百多像素宽：紧凑模式把钱粮并进第二三行，不另起标签。
        if (compact)
          Text(
            resources,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: theme.textTheme.labelSmall?.copyWith(
              color: colors.onSurfaceVariant,
              fontSize: 9.5,
            ),
          ),
      ],
    );
    if (compact) {
      return Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          FactionSeal(factionId: game.playerFaction, size: 26),
          const SizedBox(width: 7),
          Flexible(child: identity),
        ],
      );
    }
    return Wrap(
      spacing: 6,
      runSpacing: 4,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            FactionSeal(factionId: game.playerFaction, size: 30),
            const SizedBox(width: 8),
            identity,
          ],
        ),
        InfoChip(
          text: '城 ${game.cityCount(game.playerFaction)}',
          dense: true,
          color: def.color,
        ),
        InfoChip(text: '金 ${faction.gold}', dense: true, color: appGold),
        InfoChip(text: '粮 ${faction.food}', dense: true, color: appJade),
      ],
    );
  }
}

/// 底部悬浮操作条：城池指令与结束回合。
class _GameControls extends StatelessWidget {
  const _GameControls({
    required this.controller,
    required this.onInternal,
    required this.onCampaign,
    required this.onAppoint,
    required this.onEndTurn,
    required this.onFactions,
    required this.onChronicle,
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
                    color: enabled
                        ? colors.onSurface
                        : colors.onSurfaceVariant,
                  ),
                ),
              ],
            ),
    );
    return compact ? Tooltip(message: label, child: button) : button;
  }
}
