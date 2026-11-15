import 'package:material_ui/material_ui.dart';
import 'package:provider/provider.dart';

import '../game/data/scenario.dart';
import '../game/game_controller.dart';
import '../game/save_codec.dart';
import '../models/difficulty.dart';
import '../models/faction.dart';
import '../models/game_state.dart';
import '../providers/settings_provider.dart';
import '../services/save_service.dart';
import '../services/sound_service.dart';
import '../utils/constants.dart';
import 'game_page.dart';
import 'help_page.dart';
import 'settings_page.dart';
import 'widgets/common.dart';
import 'widgets/game_sheets.dart';
import 'widgets/home_widgets.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  /// 势力选择只影响势力卡与开局按钮，走独立通道，点选时不重建整页。
  late final ValueNotifier<String> _faction;
  SaveSummary? _autoSave;

  @override
  void initState() {
    super.initState();
    final settings = context.read<SettingsProvider>();
    _faction = ValueNotifier<String>(
      FactionDefs.isKnown(settings.playerFactionId)
          ? settings.playerFactionId
          : FactionDefs.all.first.id,
    );
    _refreshAutoSave();
  }

  @override
  void dispose() {
    _faction.dispose();
    super.dispose();
  }

  Future<void> _refreshAutoSave() async {
    final summary = await SaveService.autoSummary();
    if (mounted) setState(() => _autoSave = summary);
  }

  Future<void> _start() async {
    final settings = context.read<SettingsProvider>();
    await settings.setPlayerFactionId(_faction.value);
    if (!mounted) return;
    SoundService.play(GameSound.turn);
    final controller = GameController(
      factionId: _faction.value,
      difficulty: settings.difficulty,
      scenarioId: settings.scenario.id,
      goldRatio: settings.supply.ratio,
      seed: DateTime.now().microsecondsSinceEpoch,
    );
    await _enter(controller);
  }

  Future<void> _continueGame() async {
    final summary = _autoSave;
    if (summary == null) return;
    final state = await SaveService.loadState(SaveService.autoKey);
    if (!mounted) return;
    if (state == null) {
      showToast(context, '自动存档已失效');
      await _refreshAutoSave();
      return;
    }
    await _play(state);
  }

  Future<void> _openLoadSheet() async {
    final state = await showLoadSheet(context);
    if (state == null || !mounted) return;
    await _play(state);
  }

  Future<void> _play(GameState state) async {
    await _enter(
      GameController.fromState(
        state,
        seed: DateTime.now().microsecondsSinceEpoch,
      ),
    );
  }

  /// 开局与读档共用：写自动存档、进入对局页，返回后刷新首页。
  Future<void> _enter(GameController controller) async {
    await SaveService.writeState(SaveService.autoKey, controller.game);
    if (!mounted) return;
    await Navigator.of(context).push(
      MaterialPageRoute<void>(builder: (_) => GamePage(controller: controller)),
    );
    controller.dispose();
    await _refreshAutoSave();
  }

  void _open(Widget page) {
    Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => page));
  }

  @override
  Widget build(BuildContext context) {
    // 只订阅首页真正用到的设置：音效、背景音乐与帧率变化不再重建首页。
    final settings = context.read<SettingsProvider>();
    final darkMode = context.select((SettingsProvider s) => s.darkMode);
    final scenario = context.select((SettingsProvider s) => s.scenario);
    final supply = context.select((SettingsProvider s) => s.supply);
    final difficulty = context.select((SettingsProvider s) => s.difficulty);
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final colors = theme.colorScheme;
    final panel = _buildFactionPanel(
      colors,
      settings,
      scenario,
      supply,
      difficulty,
    );
    return Scaffold(
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: isDark
                ? const [Color(0xFF2A1D12), Color(0xFF130C07)]
                : const [Color(0xFFFBF1DB), Color(0xFFEAD6AF)],
          ),
        ),
        child: SafeArea(
          child: LayoutBuilder(
            builder: (context, constraints) {
              final wide =
                  constraints.maxWidth >= 980 && constraints.maxHeight >= 640;
              final padding = constraints.maxWidth >= 900 ? 36.0 : 18.0;
              final maxWidth = wide ? 1180.0 : 820.0;
              return SingleChildScrollView(
                padding: EdgeInsets.fromLTRB(padding, 14, padding, 26),
                child: ConstrainedBox(
                  // 内容比屏幕矮时垂直居中；超高时仍从顶部开始滚动。
                  constraints: BoxConstraints(
                    minHeight: constraints.maxHeight > 40
                        ? constraints.maxHeight - 40
                        : 0,
                  ),
                  child: Center(
                    key: const ValueKey('home-center'),
                    child: ConstrainedBox(
                      constraints: BoxConstraints(maxWidth: maxWidth),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          HomeTopBar(
                            darkMode: darkMode,
                            onToggleDark: () =>
                                settings.setDarkMode(!darkMode),
                            onHelp: () => _open(const HelpPage()),
                            onSettings: () => _open(const SettingsPage()),
                          ),
                          const SizedBox(height: 18),
                          if (wide)
                            Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Expanded(
                                  child: HomeHero(
                                    brightness: theme.brightness,
                                    compact: false,
                                  ),
                                ),
                                const SizedBox(width: 36),
                                SizedBox(width: 470, child: panel),
                              ],
                            )
                          else ...[
                            HomeHero(
                              brightness: theme.brightness,
                              compact: constraints.maxWidth < 520,
                            ),
                            const SizedBox(height: 22),
                            panel,
                          ],
                          const SizedBox(height: 20),
                          Text(
                            'v${AppConstants.version} · 单机离线 · 无需联网',
                            style: hintStyle(context, size: 11),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              );
            },
          ),
        ),
      ),
    );
  }

  Widget _buildFactionPanel(
    ColorScheme colors,
    SettingsProvider settings,
    ScenarioDef scenario,
    StartSupply supply,
    Difficulty difficulty,
  ) {
    final theme = Theme.of(context);
    final auto = _autoSave;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (auto != null)
          _AutoSaveBanner(
            summary: auto,
            onContinue: _continueGame,
            onOpen: _openLoadSheet,
          )
        else
          Align(
            alignment: Alignment.centerLeft,
            child: TextButton.icon(
              onPressed: _openLoadSheet,
              icon: const Icon(Icons.folder_open_outlined, size: 18),
              label: const Text('读取存档'),
            ),
          ),
        const SizedBox(height: 10),
        StartOptions(
          scenario: scenario,
          supply: supply,
          onScenario: (id) => settings.setScenarioId(id),
          onSupply: (value) => settings.setSupply(value),
        ),
        const SizedBox(height: 14),
        Row(
          children: [
            const TitleOrnament(width: 20),
            const SizedBox(width: 8),
            Text('择一方势力，起兵争雄', style: theme.textTheme.titleSmall),
          ],
        ),
        const SizedBox(height: 12),
        // 点选势力只重建这一块：上方地图缩略图与标题不再跟着重排。
        ValueListenableBuilder<String>(
          valueListenable: _faction,
          builder: (context, factionId, _) => Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              ...FactionDefs.all.map((def) => Padding(
                padding: const EdgeInsets.only(bottom: 9),
                child: FactionPickCard(
                  def: def,
                  selected: def.id == factionId,
                  scenarioId: scenario.id,
                  gold: (def.gold * supply.ratio).round(),
                  onTap: () => _faction.value = def.id,
                ),
              )),
              const SizedBox(height: 4),
              DifficultyPicker(value: difficulty, onChanged: settings.setDifficulty),
              const SizedBox(height: 14),
              FilledButton.icon(
                onPressed: _start,
                icon: const Icon(Icons.flag_rounded, size: 19),
                label: Text(
                  '以 ${FactionDefs.byId(factionId).ruler} 之名起兵',
                  style: theme.textTheme.titleSmall?.copyWith(color: colors.onPrimary),
                ),
                style: FilledButton.styleFrom(minimumSize: const Size(0, 50)),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

/// 继续征战入口：显示自动存档的进度，并可展开全部存档。
class _AutoSaveBanner extends StatelessWidget {
  const _AutoSaveBanner({
    required this.summary,
    required this.onContinue,
    required this.onOpen,
  });

  final SaveSummary summary;
  final VoidCallback onContinue;
  final VoidCallback onOpen;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    return Material(
      color: colors.primaryContainer.withValues(alpha: 0.45),
      shape: outlinedShape(context, radius: 14, color: const Color(0xFFC8A15A)),
      child: InkWell(
        onTap: onContinue,
        borderRadius: BorderRadius.circular(14),
        child: ListTile(
          leading: Icon(Icons.history_edu_outlined, color: colors.primary),
          title: Text('继续征战', style: theme.textTheme.titleSmall),
          subtitle: Text(
            '自动存档 · ${summary.label}',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: hintStyle(context),
          ),
          trailing: IconButton(
            tooltip: '所有存档',
            onPressed: onOpen,
            icon: const Icon(Icons.folder_open_outlined, size: 20),
          ),
        ),
      ),
    );
  }
}
