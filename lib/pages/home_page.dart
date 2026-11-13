import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../game/data/scenario.dart';
import '../game/game_controller.dart';
import '../models/difficulty.dart';
import '../models/faction.dart';
import '../providers/settings_provider.dart';
import '../services/sound_service.dart';
import '../theme/app_theme.dart';
import '../utils/constants.dart';
import 'game_page.dart';
import 'help_page.dart';
import 'settings_page.dart';
import 'widgets/common.dart';
import 'widgets/map_preview.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  late String _factionId;

  @override
  void initState() {
    super.initState();
    final settings = context.read<SettingsProvider>();
    _factionId = FactionDefs.isKnown(settings.playerFactionId)
        ? settings.playerFactionId
        : FactionDefs.all.first.id;
  }

  Future<void> _start() async {
    final settings = context.read<SettingsProvider>();
    await settings.setPlayerFactionId(_factionId);
    if (!mounted) return;
    SoundService.play(GameSound.turn);
    final controller = GameController(
      factionId: _factionId,
      difficulty: settings.difficulty,
      seed: DateTime.now().microsecondsSinceEpoch,
    );
    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => GamePage(controller: controller),
      ),
    );
    controller.dispose();
  }

  void _open(Widget page) {
    Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => page));
  }

  @override
  Widget build(BuildContext context) {
    final settings = context.watch<SettingsProvider>();
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final colors = theme.colorScheme;
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
                child: Center(
                  child: ConstrainedBox(
                    constraints: BoxConstraints(maxWidth: maxWidth),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        _TopBar(
                          darkMode: settings.darkMode,
                          onHelp: () => _open(const HelpPage()),
                          onSettings: () => _open(const SettingsPage()),
                        ),
                        const SizedBox(height: 18),
                        if (wide)
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Expanded(
                                child: _Hero(
                                  brightness: theme.brightness,
                                  compact: false,
                                ),
                              ),
                              const SizedBox(width: 36),
                              SizedBox(
                                width: 470,
                                child: _buildFactionPanel(colors),
                              ),
                            ],
                          )
                        else ...[
                          _Hero(
                            brightness: theme.brightness,
                            compact: constraints.maxWidth < 520,
                          ),
                          const SizedBox(height: 22),
                          _buildFactionPanel(colors),
                        ],
                        const SizedBox(height: 20),
                        Text(
                          'v${AppConstants.version} · 单机离线 · 无需联网',
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: colors.onSurfaceVariant,
                            fontSize: 11,
                          ),
                        ),
                      ],
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

  Widget _buildFactionPanel(ColorScheme colors) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            const TitleOrnament(width: 20),
            const SizedBox(width: 8),
            Text('择一方势力，起兵争雄', style: theme.textTheme.titleSmall),
          ],
        ),
        const SizedBox(height: 12),
        ...FactionDefs.all.map(
          (def) => Padding(
            padding: const EdgeInsets.only(bottom: 9),
            child: _FactionCard(
              def: def,
              selected: def.id == _factionId,
              onTap: () {
                SoundService.tap();
                setState(() => _factionId = def.id);
              },
            ),
          ),
        ),
        const SizedBox(height: 4),
        _DifficultyPicker(
          value: context.watch<SettingsProvider>().difficulty,
          onChanged: (value) =>
              context.read<SettingsProvider>().setDifficulty(value),
        ),
        const SizedBox(height: 14),
        FilledButton.icon(
          onPressed: _start,
          icon: const Icon(Icons.flag_rounded, size: 19),
          label: Text(
            '以 ${FactionDefs.byId(_factionId).ruler} 之名起兵',
            style: theme.textTheme.titleSmall?.copyWith(
              color: colors.onPrimary,
            ),
          ),
          style: FilledButton.styleFrom(minimumSize: const Size(0, 50)),
        ),
      ],
    );
  }
}

class _TopBar extends StatelessWidget {
  const _TopBar({
    required this.darkMode,
    required this.onHelp,
    required this.onSettings,
  });

  final bool darkMode;
  final VoidCallback onHelp;
  final VoidCallback onSettings;

  @override
  Widget build(BuildContext context) {
    final settings = context.read<SettingsProvider>();
    final colors = Theme.of(context).colorScheme;
    final theme = Theme.of(context);
    return Row(
      children: [
        Container(
          width: 42,
          height: 42,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: appRed,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
              color: const Color(0xFFE0BE82).withValues(alpha: 0.75),
            ),
          ),
          child: const Text(
            '三',
            style: TextStyle(
              color: Color(0xFFFFF4DF),
              fontSize: 22,
              height: 1,
              fontWeight: FontWeight.w700,
              fontFamilyFallback: ['KaiTi', 'Microsoft YaHei UI', 'SimSun'],
            ),
          ),
        ),
        const SizedBox(width: 11),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(AppConstants.appName, style: theme.textTheme.titleSmall),
            Text(
              'THREE KINGDOMS',
              style: TextStyle(
                fontSize: 8,
                letterSpacing: 1.6,
                color: colors.onSurfaceVariant,
              ),
            ),
          ],
        ),
        const Spacer(),
        IconButton(
          tooltip: darkMode ? '切换浅色' : '切换深色',
          onPressed: () => settings.setDarkMode(!darkMode),
          icon: Icon(
            darkMode ? Icons.light_mode_outlined : Icons.dark_mode_outlined,
            size: 21,
          ),
        ),
        IconButton(
          tooltip: '玩法说明',
          onPressed: onHelp,
          icon: const Icon(Icons.menu_book_outlined, size: 21),
        ),
        IconButton(
          tooltip: '设置',
          onPressed: onSettings,
          icon: const Icon(Icons.settings_outlined, size: 21),
        ),
      ],
    );
  }
}

class _Hero extends StatelessWidget {
  const _Hero({required this.brightness, required this.compact});

  final Brightness brightness;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    return Column(
      children: [
        MapPreview(brightness: brightness),
        SizedBox(height: compact ? 14 : 20),
        Text(
          '三国霸业',
          textAlign: TextAlign.center,
          style: theme.textTheme.headlineMedium?.copyWith(
            fontSize: compact ? 30 : 40,
            letterSpacing: compact ? 8 : 14,
            color: colors.onSurface,
          ),
        ),
        const SizedBox(height: 8),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            TitleOrnament(width: compact ? 26 : 40, color: colors.outline),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              child: Text(
                '群 雄 逐 鹿 · 一 统 山 河',
                style: theme.textTheme.labelSmall?.copyWith(
                  color: colors.onSurfaceVariant,
                  letterSpacing: 2,
                  fontSize: compact ? 10 : 11,
                ),
              ),
            ),
            TitleOrnament(width: compact ? 26 : 40, color: colors.outline),
          ],
        ),
        const SizedBox(height: 10),
        Text(
          '回合制争霸 · 内政经营 · 武将登用 · 攻城略地',
          textAlign: TextAlign.center,
          style: theme.textTheme.bodySmall?.copyWith(
            color: colors.onSurfaceVariant,
            fontSize: compact ? 11 : 12,
          ),
        ),
      ],
    );
  }
}

class _FactionCard extends StatelessWidget {
  const _FactionCard({
    required this.def,
    required this.selected,
    required this.onTap,
  });

  final FactionDef def;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final cities = Scenario.cityDefs.where((c) => c.owner == def.id).length;
    final generals = Scenario.generalDefs
        .where((g) => g.factionId == def.id)
        .length;
    return Material(
      color: selected
          ? colors.primaryContainer.withValues(alpha: 0.55)
          : colors.surface,
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: Container(
          padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: selected ? const Color(0xFFC8A15A) : colors.outline,
              width: selected ? 1.6 : 1,
            ),
          ),
          child: Row(
            children: [
              FactionSeal(factionId: def.id, size: 42),
              const SizedBox(width: 11),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Flexible(
                          child: Text(
                            '${def.ruler} · ${def.name}',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: theme.textTheme.titleSmall,
                          ),
                        ),
                        const SizedBox(width: 6),
                        Text(
                          def.title.split(' · ').first,
                          style: theme.textTheme.labelSmall?.copyWith(
                            color: colors.onSurfaceVariant,
                            fontSize: 10,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 3),
                    Text(
                      def.motto,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: colors.onSurfaceVariant,
                        fontSize: 11,
                      ),
                    ),
                    const SizedBox(height: 5),
                    Row(
                      children: [
                        InfoChip(
                          text: '$cities 城',
                          dense: true,
                          color: def.color,
                        ),
                        const SizedBox(width: 5),
                        InfoChip(
                          text: '$generals 将',
                          dense: true,
                          color: def.color,
                        ),
                        const SizedBox(width: 5),
                        InfoChip(
                          text: '金 ${def.gold}',
                          dense: true,
                          color: colors.onSurfaceVariant,
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              if (selected)
                const Icon(Icons.check_circle, size: 20, color: Color(0xFFC8A15A)),
            ],
          ),
        ),
      ),
    );
  }
}

class _DifficultyPicker extends StatelessWidget {
  const _DifficultyPicker({required this.value, required this.onChanged});

  final Difficulty value;
  final ValueChanged<Difficulty> onChanged;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Icon(Icons.local_fire_department_outlined,
                size: 15, color: colors.onSurfaceVariant),
            const SizedBox(width: 5),
            Text(
              '难度：${value.label} · ${value.summary}',
              style: theme.textTheme.bodySmall?.copyWith(
                color: colors.onSurfaceVariant,
                fontSize: 11,
              ),
            ),
          ],
        ),
        const SizedBox(height: 7),
        Row(
          children: [
            for (final item in Difficulty.values) ...[
              Expanded(
                child: Padding(
                  padding: EdgeInsets.only(
                    right: item == Difficulty.values.last ? 0 : 8,
                  ),
                  child: _DifficultyOption(
                    difficulty: item,
                    selected: item == value,
                    onTap: () {
                      SoundService.tap();
                      onChanged(item);
                    },
                  ),
                ),
              ),
            ],
          ],
        ),
      ],
    );
  }
}

class _DifficultyOption extends StatelessWidget {
  const _DifficultyOption({
    required this.difficulty,
    required this.selected,
    required this.onTap,
  });

  final Difficulty difficulty;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    return Material(
      color: selected ? colors.primaryContainer : colors.surface,
      borderRadius: BorderRadius.circular(10),
      child: InkWell(
        borderRadius: BorderRadius.circular(10),
        onTap: onTap,
        child: Container(
          height: 38,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
              color: selected ? colors.primary : colors.outline,
            ),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                difficulty.label,
                style: theme.textTheme.labelMedium?.copyWith(
                  fontWeight: FontWeight.w600,
                  color: selected ? colors.primary : colors.onSurface,
                ),
              ),
              const SizedBox(width: 3),
              for (var i = 0; i < difficulty.stars; i++)
                Icon(
                  Icons.star,
                  size: 9,
                  color: selected ? colors.primary : colors.onSurfaceVariant,
                ),
            ],
          ),
        ),
      ),
    );
  }
}
