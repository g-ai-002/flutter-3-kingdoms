import 'package:flutter/material.dart';

import '../../game/data/scenario.dart';
import '../../models/difficulty.dart';
import '../../models/faction.dart';
import '../../services/sound_service.dart';
import '../../theme/app_theme.dart';
import '../../utils/constants.dart';
import 'common.dart';
import 'map_preview.dart';

/// 首页顶栏：印记、标题与主题 / 说明 / 设置入口。
class HomeTopBar extends StatelessWidget {
  const HomeTopBar({
    super.key,
    required this.darkMode,
    required this.onToggleDark,
    required this.onHelp,
    required this.onSettings,
  });

  final bool darkMode;
  final VoidCallback onToggleDark;
  final VoidCallback onHelp;
  final VoidCallback onSettings;

  @override
  Widget build(BuildContext context) {
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
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(AppConstants.appName, style: theme.textTheme.titleSmall),
              Text(
                'THREE KINGDOMS',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 8,
                  letterSpacing: 1.6,
                  color: colors.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ),
        _tool(
          darkMode ? Icons.light_mode_outlined : Icons.dark_mode_outlined,
          darkMode ? '切换浅色' : '切换深色',
          onToggleDark,
        ),
        _tool(Icons.menu_book_outlined, '玩法说明', onHelp),
        _tool(Icons.settings_outlined, '设置', onSettings),
      ],
    );
  }

  Widget _tool(IconData icon, String tooltip, VoidCallback onPressed) =>
      IconButton(
        tooltip: tooltip,
        onPressed: onPressed,
        icon: Icon(icon, size: 21),
      );
}

/// 首页主视觉：地图缩略图、标题与副标题。
class HomeHero extends StatelessWidget {
  const HomeHero({super.key, required this.brightness, required this.compact});

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

/// 势力选择卡：君主、名号、箴言与初始城池武将数。
class FactionPickCard extends StatelessWidget {
  const FactionPickCard({
    super.key,
    required this.def,
    required this.selected,
    required this.scenarioId,
    required this.gold,
    required this.onTap,
  });

  final FactionDef def;
  final bool selected;
  final String scenarioId;
  final int gold;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final cities = Scenario.cityCountOf(scenarioId, def.id);
    final generals = Scenario.generalDefs
        .where((g) => g.factionId == def.id)
        .length;
    final hint = theme.textTheme.labelSmall?.copyWith(
      color: colors.onSurfaceVariant,
      fontSize: 10,
    );
    return Material(
      color: selected
          ? colors.primaryContainer.withValues(alpha: 0.55)
          : colors.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: BorderSide(
          color: selected ? const Color(0xFFC8A15A) : colors.outline,
          width: selected ? 1.6 : 1,
        ),
      ),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
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
                        Text(def.title.split(' · ').first, style: hint),
                      ],
                    ),
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
                    Wrap(
                      spacing: 5,
                      children: [
                        for (final text in ['$cities 城', '$generals 将'])
                          InfoChip(text: text, dense: true, color: def.color),
                        InfoChip(
                          text: '金 $gold',
                          dense: true,
                          color: colors.onSurfaceVariant,
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              if (selected)
                const Icon(
                  Icons.check_circle,
                  size: 20,
                  color: Color(0xFFC8A15A),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

/// 开局设定：剧本与开局钱粮，两项合起来即自定义开局。
class StartOptions extends StatelessWidget {
  const StartOptions({
    super.key,
    required this.scenario,
    required this.supply,
    required this.onScenario,
    required this.onSupply,
  });

  final ScenarioDef scenario;
  final StartSupply supply;
  final ValueChanged<String> onScenario;
  final ValueChanged<StartSupply> onSupply;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final hint = theme.textTheme.labelSmall?.copyWith(
      color: colors.onSurfaceVariant,
    );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Icon(
              Icons.auto_stories_outlined,
              size: 15,
              color: colors.onSurfaceVariant,
            ),
            const SizedBox(width: 5),
            Text('剧本 · ${scenario.era}', style: hint),
            const Spacer(),
            Text('自定开局 · 钱粮 ×${supply.ratio}', style: hint),
          ],
        ),
        const SizedBox(height: 7),
        SegmentedButton<String>(
          showSelectedIcon: false,
          segments: [
            for (final item in Scenario.scenarios)
              ButtonSegment(value: item.id, label: Text(item.name)),
          ],
          selected: {scenario.id},
          onSelectionChanged: (ids) {
            SoundService.tap();
            onScenario(ids.first);
          },
        ),
        const SizedBox(height: 5),
        Text(scenario.summary, style: hint),
        const SizedBox(height: 9),
        SegmentedButton<StartSupply>(
          showSelectedIcon: false,
          segments: [
            for (final item in StartSupply.values)
              ButtonSegment(value: item, label: Text(item.label)),
          ],
          selected: {supply},
          onSelectionChanged: (items) {
            SoundService.tap();
            onSupply(items.first);
          },
        ),
        const SizedBox(height: 4),
        Text('${supply.summary}，只影响本方开局', style: hint),
      ],
    );
  }
}

/// 难度选择：三档分段切换，附当前难度说明。
class DifficultyPicker extends StatelessWidget {
  const DifficultyPicker({
    super.key,
    required this.value,
    required this.onChanged,
  });

  final Difficulty value;
  final ValueChanged<Difficulty> onChanged;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final hint = theme.textTheme.labelSmall?.copyWith(
      color: colors.onSurfaceVariant,
    );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Icon(
              Icons.local_fire_department_outlined,
              size: 15,
              color: colors.onSurfaceVariant,
            ),
            const SizedBox(width: 5),
            Text('难度 · ${value.label}', style: hint),
            const SizedBox(width: 6),
            Expanded(
              child: Text(
                value.summary,
                style: hint,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
        const SizedBox(height: 7),
        SegmentedButton<Difficulty>(
          showSelectedIcon: false,
          segments: [
            for (final item in Difficulty.values)
              ButtonSegment(value: item, label: Text(item.label)),
          ],
          selected: {value},
          onSelectionChanged: (items) {
            SoundService.tap();
            onChanged(items.first);
          },
        ),
      ],
    );
  }
}
