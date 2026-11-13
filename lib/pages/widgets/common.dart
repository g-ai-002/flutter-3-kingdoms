import 'package:flutter/material.dart';

import '../../models/faction.dart';

/// 势力印：朱文方印，用作logo、势力卡与战斗旗帜。
class FactionSeal extends StatelessWidget {
  const FactionSeal({
    super.key,
    required this.factionId,
    this.size = 44,
    this.showBorder = true,
  });

  final String factionId;
  final double size;
  final bool showBorder;

  @override
  Widget build(BuildContext context) {
    final color = FactionDefs.colorOf(factionId);
    final name = FactionDefs.nameOf(factionId);
    return Container(
      width: size,
      height: size,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(size * 0.16),
        border: showBorder
            ? Border.all(
                color: const Color(0xFFE0BE82).withValues(alpha: 0.75),
                width: 1.2,
              )
            : null,
      ),
      child: Text(
        name,
        style: TextStyle(
          color: const Color(0xFFFFF4DF),
          fontSize: size * 0.5,
          fontWeight: FontWeight.w700,
          height: 1,
          fontFamilyFallback: const ['KaiTi', 'Microsoft YaHei UI', 'SimSun'],
        ),
      ),
    );
  }
}

/// 数值条：城池的农业、商业、治安、训练与城防。
class StatBar extends StatelessWidget {
  const StatBar({
    super.key,
    required this.label,
    required this.value,
    this.color,
    this.compact = false,
  });

  final String label;
  final int value;
  final Color? color;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final accent = color ?? colors.primary;
    return Row(
      children: [
        SizedBox(
          width: compact ? 32 : 40,
          child: Text(
            label,
            style: theme.textTheme.labelSmall?.copyWith(
              fontSize: compact ? 10 : 11,
              color: colors.onSurfaceVariant,
            ),
          ),
        ),
        Expanded(
          child: ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: value / 100,
              minHeight: compact ? 5 : 6,
              backgroundColor: colors.surfaceContainerHighest,
              valueColor: AlwaysStoppedAnimation(accent),
            ),
          ),
        ),
        SizedBox(
          width: 30,
          child: Text(
            '$value',
            textAlign: TextAlign.right,
            style: theme.textTheme.labelSmall?.copyWith(
              fontSize: compact ? 10 : 11,
              color: colors.onSurface,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ],
    );
  }
}

/// 带标题的卡片容器，统一内边距与标题样式。
class SectionCard extends StatelessWidget {
  const SectionCard({
    super.key,
    this.title,
    this.trailing,
    required this.child,
    this.padding = const EdgeInsets.fromLTRB(14, 12, 14, 14),
    this.color,
  });

  final String? title;
  final Widget? trailing;
  final Widget child;
  final EdgeInsets padding;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    return Container(
      padding: padding,
      decoration: BoxDecoration(
        color: color ?? colors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: colors.outline.withValues(alpha: 0.9)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Material(
        type: MaterialType.transparency,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          mainAxisSize: MainAxisSize.min,
          children: [
            if (title != null)
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Row(
                  children: [
                    Container(
                      width: 3,
                      height: 13,
                      decoration: BoxDecoration(
                        color: colors.primary,
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                    const SizedBox(width: 7),
                    Expanded(
                      child: Text(
                        title!,
                        style: theme.textTheme.titleSmall?.copyWith(fontSize: 13),
                      ),
                    ),
                    ?trailing,
                  ],
                ),
              ),
            child,
          ],
        ),
      ),
    );
  }
}

/// 小标签：资源、兵种与状态提示。
class InfoChip extends StatelessWidget {
  const InfoChip({
    super.key,
    required this.text,
    this.icon,
    this.color,
    this.dense = false,
  });

  final String text;
  final IconData? icon;
  final Color? color;
  final bool dense;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final tone = color ?? colors.onSurfaceVariant;
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: dense ? 6 : 8,
        vertical: dense ? 2 : 4,
      ),
      decoration: BoxDecoration(
        color: tone.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(icon, size: dense ? 11 : 13, color: tone),
            const SizedBox(width: 3),
          ],
          Text(
            text,
            style: theme.textTheme.labelSmall?.copyWith(
              color: tone,
              fontSize: dense ? 10 : 11,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

/// 一点朱砂：标题下的短横线装饰。
class TitleOrnament extends StatelessWidget {
  const TitleOrnament({super.key, this.width = 42, this.color});

  final double width;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: width,
      height: 2,
      decoration: BoxDecoration(
        color: color ?? Theme.of(context).colorScheme.primary,
        borderRadius: BorderRadius.circular(1),
      ),
    );
  }
}

/// 面板标题行：主标题、可选副标题与右侧附属信息。
class SheetHeader extends StatelessWidget {
  const SheetHeader({
    super.key,
    required this.title,
    this.subtitle,
    this.trailing,
  });

  final String title;
  final String? subtitle;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        Row(
          children: [
            Expanded(child: Text(title, style: theme.textTheme.titleSmall)),
            ?trailing,
          ],
        ),
        if (subtitle != null) ...[
          const SizedBox(height: 4),
          Text(
            subtitle!,
            style: theme.textTheme.labelSmall?.copyWith(
              color: colors.onSurfaceVariant,
            ),
          ),
        ],
      ],
    );
  }
}

/// 底部面板骨架：安全区、统一内边距与标题，内容可选滚动。
class SheetFrame extends StatelessWidget {
  const SheetFrame({
    super.key,
    required this.title,
    required this.child,
    this.subtitle,
    this.trailing,
    this.scrollable = false,
    this.padding = const EdgeInsets.fromLTRB(16, 0, 16, 12),
  });

  final String title;
  final String? subtitle;
  final Widget? trailing;
  final Widget child;
  final bool scrollable;
  final EdgeInsets padding;

  @override
  Widget build(BuildContext context) {
    final body = Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SheetHeader(title: title, subtitle: subtitle, trailing: trailing),
        child,
      ],
    );
    return SafeArea(
      child: Padding(
        padding: padding,
        child: scrollable ? SingleChildScrollView(child: body) : body,
      ),
    );
  }
}

/// 面板内的分区小标题。
class SheetLabel extends StatelessWidget {
  const SheetLabel(this.text, {super.key});

  final String text;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Text(
      text,
      style: theme.textTheme.labelSmall?.copyWith(
        color: theme.colorScheme.onSurfaceVariant,
      ),
    );
  }
}

/// 面板内的空状态提示。
class EmptyHint extends StatelessWidget {
  const EmptyHint(this.text, {super.key});

  final String text;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Text(
      text,
      style: theme.textTheme.bodySmall?.copyWith(
        color: theme.colorScheme.onSurfaceVariant,
      ),
    );
  }
}

