import 'package:flutter/material.dart';

import '../../models/faction.dart';

/// 次要说明文字的统一样式：小号 + 弱化色，可按场景覆写字号与行高。
TextStyle? hintStyle(
  BuildContext context, {
  double? size,
  Color? color,
  double? height,
}) {
  final theme = Theme.of(context);
  return theme.textTheme.labelSmall?.copyWith(
    color: color ?? theme.colorScheme.onSurfaceVariant,
    fontSize: size,
    height: height,
  );
}

/// 轻提示：新提示顶掉旧提示，对局、面板与设置页表现一致。
void showToast(BuildContext context, String text) {
  ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(SnackBar(content: Text(text)));
}

/// 面板列表项与卡片的统一描边：细边圆角，可覆盖强调色与线宽。
ShapeBorder outlinedShape(
  BuildContext context, {
  double radius = 12,
  Color? color,
  double width = 1,
}) {
  return RoundedRectangleBorder(
    borderRadius: BorderRadius.circular(radius),
    side: BorderSide(
      color: color ?? Theme.of(context).colorScheme.outline,
      width: width,
    ),
  );
}

/// 顶栏紧凑图标按钮：首页与对局工具条共用尺寸与点击区。
class HudIconButton extends StatelessWidget {
  const HudIconButton({
    super.key, required this.icon, required this.tooltip,
    required this.onPressed, this.size = 20, this.box = 48,
  });

  final IconData icon;
  final String tooltip;
  final VoidCallback onPressed;
  final double size;
  final double box;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: box,
      height: box,
      child: IconButton(
        tooltip: tooltip,
        onPressed: onPressed,
        icon: Icon(icon, size: size),
        padding: EdgeInsets.zero,
        style: IconButton.styleFrom(
          minimumSize: Size.zero,
          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
        ),
      ),
    );
  }
}

/// 底部面板统一开合：拖动条、滚动控制与高面板比例都在这里决定。
Future<T?> showGameSheet<T>(
  BuildContext context, {
  required WidgetBuilder builder,
  bool tall = false,
}) {
  return showModalBottomSheet<T>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    builder: tall
        ? (sheetContext) => SizedBox(
            height: MediaQuery.sizeOf(sheetContext).height * 0.72,
            child: builder(sheetContext),
          )
        : builder,
  );
}

/// 悬浮卡片与面板共用的描边容器：圆角、细边与浅阴影。
BoxDecoration cardDecoration(
  BuildContext context, {
  double radius = 16,
  Color? color,
  Color? borderColor,
  bool shadow = true,
}) {
  final colors = Theme.of(context).colorScheme;
  return BoxDecoration(
    color: color ?? colors.surface,
    borderRadius: BorderRadius.circular(radius),
    border: Border.all(
      color: borderColor ?? colors.outline.withValues(alpha: 0.9),
    ),
    boxShadow: shadow
        ? [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.05),
              blurRadius: 12,
              offset: const Offset(0, 4),
            ),
          ]
        : null,
  );
}

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
    super.key, required this.label, required this.value,
    this.color, this.compact = false,
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
    super.key, this.title, this.trailing, required this.child,
    this.padding = const EdgeInsets.fromLTRB(14, 12, 14, 14), this.color,
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
      decoration: cardDecoration(context, color: color),
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
                        style: theme.textTheme.titleSmall?.copyWith(
                          fontSize: 13,
                        ),
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

/// 小标签：资源、兵种与状态提示；[plain] 时只留图标与文字，不进胶囊底色。
class InfoChip extends StatelessWidget {
  const InfoChip({
    super.key, required this.text, this.icon, this.color,
    this.dense = false, this.plain = false,
  });

  final String text;
  final IconData? icon;
  final Color? color;
  final bool dense;
  final bool plain;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final tone = color ?? colors.onSurfaceVariant;
    final content = Row(
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
    );
    if (plain) return content;
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: dense ? 6 : 8,
        vertical: dense ? 2 : 4,
      ),
      decoration: BoxDecoration(
        color: tone.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(6),
      ),
      child: content,
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
    super.key, required this.title, this.subtitle, this.trailing,
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
    super.key, required this.title, required this.child, this.subtitle,
    this.trailing, this.scrollable = false, this.gap = 0,
    this.padding = const EdgeInsets.fromLTRB(16, 0, 16, 12),
  });

  final String title;
  final String? subtitle;
  final Widget? trailing;
  final Widget child;
  final bool scrollable;

  /// 标题与正文之间的间距，各面板不必再包一层 Padding。
  final double gap;
  final EdgeInsets padding;

  @override
  Widget build(BuildContext context) {
    final body = Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SheetHeader(title: title, subtitle: subtitle, trailing: trailing),
        if (gap > 0) SizedBox(height: gap),
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

/// 面板内的提示小字：分区小标题用默认样式，空状态正文用 [body]。
class HintText extends StatelessWidget {
  const HintText(
    this.text, {super.key, this.body = false, this.center = false});

  final String text;
  final bool body;
  final bool center;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final style =
        (body ? theme.textTheme.bodySmall : theme.textTheme.labelSmall)
            ?.copyWith(color: theme.colorScheme.onSurfaceVariant);
    return Text(
      text,
      style: style,
      textAlign: center ? TextAlign.center : null,
    );
  }
}
