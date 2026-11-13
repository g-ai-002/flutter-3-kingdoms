import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../utils/map_layout.dart';

/// 侧栏窄于该宽度时改用紧凑卡片：隐藏次要文字，操作只留图标。
const double _compactRailWidth = 200;

/// 两侧栏的最大宽度，超宽屏上让 HUD 贴着地图而不是甩到屏幕边缘。
const double _maxRailWidth = 330;

/// HUD 密度标记：紧凑模式下卡片只保留关键信息，把空间让给地图。
class HudScope extends InheritedWidget {
  const HudScope({super.key, required this.compact, required super.child});

  final bool compact;

  static bool compactOf(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<HudScope>()?.compact ?? false;

  @override
  bool updateShouldNotify(HudScope oldWidget) => oldWidget.compact != compact;
}

/// 对局页的悬浮骨架：地图居中，标题与城池信息浮在地图上方或两侧，
/// 控制按钮统一浮在地图下方。
class MapHud extends StatelessWidget {
  const MapHud({
    super.key,
    required this.map,
    this.topStart,
    this.topEnd,
    this.info,
    this.controls,
    this.maxWidth = kMapMaxWidth,
    this.padding = const EdgeInsets.all(kHudPadding),
    this.gap = kHudRowGap,
  });

  final Widget map;
  final Widget? topStart;
  final Widget? topEnd;
  final Widget? info;
  final Widget? controls;
  final double maxWidth;
  final EdgeInsets padding;
  final double gap;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final area = Size(
          constraints.hasBoundedWidth ? constraints.maxWidth : maxWidth,
          constraints.hasBoundedHeight
              ? constraints.maxHeight
              : maxWidth * kMapDesignSize.height / kMapDesignSize.width,
        );
        final metrics = resolveHud(
          area,
          maxWidth: maxWidth,
          textScale: _textScale(context),
        );
        final compact =
            metrics.compact ||
            (metrics.sideRail &&
                math.min(metrics.rail, _maxRailWidth) < _compactRailWidth);
        return Column(
          children: [
            Expanded(
              child: metrics.sideRail
                  ? _railBody(metrics, compact)
                  : _bandBody(context, compact),
            ),
            if (controls != null)
              Padding(
                padding: padding,
                child: Center(
                  child: HudScope(compact: compact, child: controls!),
                ),
              ),
          ],
        );
      },
    );
  }

  /// 两侧栏：标题与城池信息挂在左栏，结束回合等状态挂在右栏。
  Widget _railBody(HudMetrics metrics, bool compact) {
    final railWidth = math.min(metrics.rail, _maxRailWidth);
    final inset = metrics.rail - railWidth;
    return Stack(
      children: [
        Positioned.fill(
          child: LayoutBuilder(
            builder: (context, constraints) {
              final size = mapFitSize(
                Size(
                  constraints.maxWidth - metrics.rail * 2,
                  constraints.maxHeight,
                ),
                maxWidth,
              );
              return Center(child: SizedBox.fromSize(size: size, child: map));
            },
          ),
        ),
        if (topStart != null || info != null)
          Positioned(
            left: inset,
            top: 0,
            bottom: 0,
            width: railWidth,
            child: Padding(
              padding: padding,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (topStart != null) _card(topStart!, compact),
                  if (info != null)
                    Expanded(
                      child: Center(
                        child: SingleChildScrollView(
                          child: _card(info!, compact),
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),
        if (topEnd != null)
          Positioned(
            right: inset,
            top: 0,
            width: railWidth,
            child: Padding(
              padding: padding,
              child: Align(
                alignment: Alignment.topRight,
                child: _card(topEnd!, compact),
              ),
            ),
          ),
      ],
    );
  }

  /// 上下横条：标题与资源在上，城池信息紧随地图上方。
  Widget _bandBody(BuildContext context, bool compact) {
    final hasTop = topStart != null || topEnd != null;
    return Column(
      children: [
        if (hasTop || info != null)
          Padding(
            padding: padding,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                if (hasTop) _topWrap(compact),
                if (hasTop && info != null) SizedBox(height: gap),
                if (info != null)
                  SizedBox(
                    height: _infoRowHeight(context, true),
                    child: Align(
                      alignment: Alignment.centerLeft,
                      child: SingleChildScrollView(
                        scrollDirection: Axis.horizontal,
                        child: _card(info!, true),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        Expanded(
          child: LayoutBuilder(
            builder: (context, constraints) {
              final size = mapFitSize(constraints.biggest, maxWidth);
              return Center(child: SizedBox.fromSize(size: size, child: map));
            },
          ),
        ),
      ],
    );
  }

  Widget _topWrap(bool compact) {
    return Wrap(
      spacing: gap,
      runSpacing: gap,
      alignment: WrapAlignment.spaceBetween,
      children: [
        if (topStart != null) _card(topStart!, compact),
        if (topEnd != null) _card(topEnd!, compact),
      ],
    );
  }

  double _infoRowHeight(BuildContext context, bool compact) {
    final base = compact ? kHudCompactInfoRow : kHudInfoRow;
    return base * _textScale(context);
  }

  double _textScale(BuildContext context) =>
      MediaQuery.textScalerOf(context).scale(14) / 14;

  Widget _card(Widget child, bool compact) {
    return Builder(
      builder: (context) {
        final theme = Theme.of(context);
        final colors = theme.colorScheme;
        final isDark = theme.brightness == Brightness.dark;
        return HudScope(
          compact: compact,
          child: Container(
            padding: compact
                ? const EdgeInsets.symmetric(horizontal: 8, vertical: 6)
                : const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
            decoration: BoxDecoration(
              color: colors.surface.withValues(alpha: isDark ? 0.92 : 0.95),
              borderRadius: BorderRadius.circular(compact ? 14 : 16),
              border: Border.all(color: colors.outline.withValues(alpha: 0.9)),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.06),
                  blurRadius: 12,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: child,
          ),
        );
      },
    );
  }
}
