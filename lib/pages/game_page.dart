import 'dart:async';

import 'package:flame/game.dart';
import 'package:material_ui/material_ui.dart';
import 'package:provider/provider.dart';

import '../flame/sanguo_game.dart';
import '../game/game_controller.dart';
import '../models/battle.dart';
import '../models/city.dart';
import '../models/faction.dart';
import '../providers/settings_provider.dart';
import '../services/save_service.dart';
import '../services/sound_service.dart';
import '../utils/formatters.dart';
import '../utils/map_display_mode.dart';
import 'battle_page.dart';
import 'help_page.dart';
import 'settings_page.dart';
import 'widgets/common.dart';
import 'widgets/game_hud.dart';
import 'widgets/game_sheets.dart';
import 'widgets/map_hud.dart';

class GamePage extends StatefulWidget {
  const GamePage({super.key, required this.controller});

  final GameController controller;

  @override
  State<GamePage> createState() => _GamePageState();
}

class _GamePageState extends State<GamePage> with WidgetsBindingObserver {
  late final SanguoGame _game;
  late final SettingsProvider _settings = context.read<SettingsProvider>();

  /// 城池卡片与底部操作条跟随选中与数据两条通道；势力卡只跟随数据。
  late final Listenable _cityChanges = Listenable.merge([
    controller,
    controller.selection,
  ]);
  bool _resultShown = false;

  /// 已写入自动存档的数据修订号：进入对局时首页刚写过一次，故从当前值起算。
  int _savedRevision = 0;

  GameController get controller => widget.controller;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _savedRevision = controller.revision;
    // 帧率直接写到对局，不必为一条设置重建地图与 HUD。
    _settings.addListener(_syncLogicRate);
    _game = SanguoGame(
      controller: controller,
      brightness: Brightness.light,
      logicRate: _settings.logicRate,
      // 数据变更与选中变化都要唤醒地图，静置停帧后仍能立即重绘。
      changes: _cityChanges,
    );
    controller.addListener(_onControllerChanged);
  }

  void _syncLogicRate() {
    if (mounted) _game.logicRate = _settings.logicRate;
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _game.brightness = Theme.of(context).brightness;
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.hidden) {
      unawaited(_autosave());
    }
  }

  @override
  void dispose() {
    controller.removeListener(_onControllerChanged);
    _settings.removeListener(_syncLogicRate);
    WidgetsBinding.instance.removeObserver(this);
    unawaited(_autosave());
    super.dispose();
  }

  /// 自动存档：结束本月、战斗结束与退到后台时写入；胜负已分则清除。
  Future<void> _autosave() async {
    if (controller.finished) {
      await SaveService.delete(SaveService.autoKey);
      return;
    }
    // 同一局面只写一次：退到后台、退出页面不再重复编码与写盘。
    final revision = controller.revision;
    if (revision == _savedRevision) return;
    if (await SaveService.writeState(SaveService.autoKey, controller.game)) {
      _savedRevision = revision;
    }
  }

  void _onControllerChanged() {
    if (!mounted) return;
    if (controller.finished && !_resultShown) {
      _resultShown = true;
      unawaited(SaveService.delete(SaveService.autoKey));
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _showOutcome();
      });
    }
  }

  Future<void> _showOutcome() async {
    final game = controller.game;
    final tally = game.tallyOf(game.playerFaction);
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
              Text('据城 ${tally.cities} / ${game.totalCities}'),
              Text('带甲 ${tally.troops}'),
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
    showToast(context, result.message);
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
        showToast(context, prepared.error ?? '无法出征');
        return;
      }
      final result = await Navigator.of(context).push<BattleResult?>(
        MaterialPageRoute<BattleResult?>(
          builder: (_) => BattlePage(setup: setup),
        ),
      );
      controller.finishPlayerBattle(result);
      unawaited(_autosave());
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
    unawaited(_autosave());
    SoundService.play(GameSound.turn);
    final player = controller.game.player;
    showToast(
      context,
      '${formatYearMonth(controller.game.year, controller.game.month)} · '
      '金 ${player.gold} · 粮 ${player.food}',
    );
  }

  void _push(Widget page) {
    unawaited(
      _withMapPaused(
        () =>
            Navigator.of(context)
                .push(MaterialPageRoute<void>(builder: (_) => page)),
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
              builder: (context, _) => GameFactionCard(controller: controller),
            ),
            topEnd: GameTopTools(
              onSave: () => unawaited(
                _withMapPaused(() => showSaveSheet(context, controller)),
              ),
              onHelp: () => _push(const HelpPage()),
              onSettings: () => _push(const SettingsPage()),
            ),
            info: AnimatedBuilder(
              animation: _cityChanges,
              builder: (context, _) => GameInfoPanel(controller: controller),
            ),
            controls: AnimatedBuilder(
              animation: _cityChanges,
              builder: (context, _) => GameControls(
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
    final radius = BorderRadius.circular(18);
    // Flame 的 GameWidget 自带重绘边界，这里只留圆角与阴影，
    // 地图逐帧重绘时不会带上外层装饰，也不再套一层多余的边界。
    return Container(
      decoration: BoxDecoration(
        borderRadius: radius,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.2),
            blurRadius: 22,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: radius,
        child: GameWidget<SanguoGame>(
          key: const ValueKey('sanguo-map'),
          game: _game,
        ),
      ),
    );
  }
}
