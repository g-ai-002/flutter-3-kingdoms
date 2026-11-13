import 'dart:math' as math;

import 'package:flutter/material.dart';

/// 战略地图的逻辑画布尺寸：所有城池坐标与道路都写在这个坐标系里。
const Size kMapDesignSize = Size(1200, 760);

/// 地图显示的最大宽度：再宽只会让城池离视线更远。
const double kMapMaxWidth = 1240;

/// 左右留白达到该宽度才把悬浮卡片挂到地图两侧，否则排到地图上方。
const double kHudRailWidth = 120;

/// 可用高度不足该值时改用紧凑卡片。
const double kHudCompactHeight = 540;

const double kHudPadding = 8;
const double kHudTitleRow = 60;
const double kHudInfoRow = 54;
const double kHudCompactTitleRow = 52;
const double kHudCompactInfoRow = 44;
const double kHudRowGap = 8;
const double kHudBottomRow = 64;
const double kHudCompactBottomRow = 56;

/// 地图按设计宽高比在可用空间内取最大尺寸。
Size mapFitSize(Size available, [double maxWidth = kMapMaxWidth]) {
  final widthLimit = math.max(0.0, available.width);
  final heightLimit = math.max(0.0, available.height);
  if (widthLimit <= 0 || heightLimit <= 0) return Size.zero;
  final aspect = kMapDesignSize.width / kMapDesignSize.height;
  var width = math.min(widthLimit, maxWidth);
  var height = width / aspect;
  if (height > heightLimit) {
    height = heightLimit;
    width = height * aspect;
  }
  return Size(width, height);
}

class HudMetrics {
  const HudMetrics({
    required this.map,
    required this.rail,
    required this.compact,
    required this.sideRail,
  });

  final Size map;
  final double rail;
  final bool compact;
  final bool sideRail;
}

/// 计算地图页的排版决策：操作按钮固定在下方，左右留白够宽时标题与城池
/// 信息挂到地图两侧，否则排到地图上方。
HudMetrics resolveHud(
  Size area, {
  double maxWidth = kMapMaxWidth,
  double textScale = 1,
}) {
  final scale = _scale(textScale);
  final compact = area.height < kHudCompactHeight;
  final bottom = (compact ? kHudCompactBottomRow : kHudBottomRow) * scale;
  final railMap = mapFitSize(
    Size(area.width, math.max(0, area.height - bottom)),
    maxWidth,
  );
  final rail = math.max(0.0, (area.width - railMap.width) / 2);
  if (rail >= kHudRailWidth) {
    return HudMetrics(
      map: railMap,
      rail: rail,
      compact: compact,
      sideRail: true,
    );
  }
  final title = compact ? kHudCompactTitleRow : kHudTitleRow;
  final info = compact ? kHudCompactInfoRow : kHudInfoRow;
  final top = kHudPadding * 2 + (title + kHudRowGap + info) * scale;
  return HudMetrics(
    map: mapFitSize(
      Size(area.width, math.max(0, area.height - top - bottom)),
      maxWidth,
    ),
    rail: rail,
    compact: compact,
    sideRail: false,
  );
}

double _scale(double textScale) => textScale.clamp(1.0, 1.35).toDouble();
