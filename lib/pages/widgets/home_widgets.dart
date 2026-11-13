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
          onPressed: onToggleDark,
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

/// 难度选择：三档并展示星级与说明。
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
