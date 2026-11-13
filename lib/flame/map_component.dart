import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flame/components.dart';
import 'package:flame/events.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../game/game_controller.dart';
import '../models/city.dart';
import '../models/faction.dart';
import '../services/sound_service.dart';
import '../theme/map_painting.dart';
import '../utils/constants.dart';
import '../utils/formatters.dart';
import '../utils/logic_rate.dart';
import '../utils/map_layout.dart';

/// Flame 战略地图：绘制城池、驿道与势力版图，处理点击与选中脉冲。
///
/// 底图、驿道与城池徽记合并成一张静态 [ui.Picture]，只有游戏数据（修订号）、
/// 主题或缩放档位变化时才重新录制；每帧只补画选中环与可进攻目标，
/// 避免在 60/120Hz 下反复排版 28 座城池的文字。
class MapComponent extends PositionComponent with TapCallbacks {
  MapComponent({
    required this.controller,
    required this.brightness,
    this.onInput,
    LogicRate logicRate = LogicRate.hz60,
  }) : _stepper = FixedStepClock(logicRate.step);

  final GameController controller;
  final ValueListenable<Brightness> brightness;
  final VoidCallback? onInput;
  final FixedStepClock _stepper;

  double _time = 0;
  ui.Picture? _staticLayer;
  int _staticRevision = -1;
  double _staticBoost = 0;
  Brightness? _staticBrightness;
  int _staticBuilds = 0;

  final Map<String, TextPainter> _namePainters = {};
  final Map<String, TextPainter> _troopPainters = {};
  double _textBoost = 0;
  Brightness? _textBrightness;
  double _labelBoost = 1;

  MapPalette get _palette => MapPalette.of(brightness.value);

  /// 静态图层累计重新录制的次数，供性能测试断言缓存命中。
  @visibleForTesting
  int get staticLayerBuilds => _staticBuilds;

  @override
  void onRemove() {
    _disposeStaticLayer();
    super.onRemove();
  }

  void _disposeStaticLayer() {
    _staticLayer?.dispose();
    _staticLayer = null;
    _staticRevision = -1;
  }

  @override
  void update(double dt) {
    super.update(dt);
    _stepper.advance(dt, (span) => _time += span);
  }

  double get _scale => size.x <= 0 ? 1 : size.x / kMapDesignSize.width;

  @override
  void render(Canvas canvas) {
    if (size.x <= 0 || size.y <= 0) return;
    final scale = _scale;
    _syncTextMetrics(scale);
    canvas.save();
    canvas.scale(scale, scale);
    canvas.drawPicture(_staticPicture());
    _drawSelection(canvas);
    canvas.restore();
  }

  /// 小屏上地图整体缩得很小，按比例放大字面，保证城名仍可辨认。
  /// 缩放档位量化到 0.05，拖动窗口时不会每一帧都重录静态图层。
  void _syncTextMetrics(double scale) {
    final boost = scale < 0.62 ? (0.62 / scale).clamp(1.0, 1.7) : 1.0;
    final quantized = (boost * 20).roundToDouble() / 20;
    if (_textBrightness == brightness.value &&
        (_textBoost - quantized).abs() < 0.001) {
      return;
    }
    _textBoost = quantized;
    _labelBoost = quantized;
    _textBrightness = brightness.value;
    _namePainters.clear();
    _troopPainters.clear();
  }

  ui.Picture _staticPicture() {
    final cached = _staticLayer;
    if (cached != null &&
        _staticRevision == controller.revision &&
        _staticBoost == _labelBoost &&
        _staticBrightness == brightness.value) {
      return cached;
    }
    _staticLayer?.dispose();
    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder);
    paintMapBackground(
      canvas,
      kMapDesignSize,
      _palette,
      fontFamily: kIsWeb ? kWebFontFamily : null,
    );
    _drawRoads(canvas);
    _drawCities(canvas);
    _staticLayer = recorder.endRecording();
    _staticRevision = controller.revision;
    _staticBoost = _labelBoost;
    _staticBrightness = brightness.value;
    _staticBuilds++;
    return _staticLayer!;
  }

  void _drawRoads(Canvas canvas) {
    final palette = _palette;
    final cities = controller.game.cities;
    final seen = <String>{};
    for (final city in cities.values) {
      for (final neighborId in city.neighbors) {
        final key = city.id.compareTo(neighborId) < 0
            ? '${city.id}-$neighborId'
            : '$neighborId-${city.id}';
        if (!seen.add(key)) continue;
        final other = cities[neighborId]!;
        final sameOwner = city.owner == other.owner;
        final color = sameOwner
            ? FactionDefs.colorOf(city.owner).withValues(alpha: 0.36)
            : palette.road.withValues(alpha: 0.42);
        paintRoad(
          canvas,
          city.position,
          other.position,
          color,
          2.6,
          dashLength: 9,
        );
      }
    }
  }

  /// 选中城池后，只补画相连驿道与脉冲环；底图与城池仍来自静态图层。
  void _drawSelection(Canvas canvas) {
    final selected = controller.selectedCity;
    if (selected == null) return;
    final palette = _palette;
    final isPlayer = selected.owner == controller.game.playerFaction;
    for (final neighborId in selected.neighbors) {
      final other = controller.game.cities[neighborId];
      if (other == null) continue;
      final sameOwner = other.owner == selected.owner;
      final isTarget = isPlayer && !sameOwner;
      final color = isTarget
          ? const Color(0xFFB03A2E).withValues(alpha: 0.8)
          : sameOwner
          ? FactionDefs.colorOf(selected.owner).withValues(alpha: 0.5)
          : palette.road.withValues(alpha: 0.6);
      paintRoad(
        canvas,
        selected.position,
        other.position,
        color,
        4.2,
        dashLength: isTarget ? 13 : 9,
      );
    }
    _drawPulse(canvas, selected.position, selected: true);
    if (!isPlayer) return;
    for (final target in controller.game.enemyNeighbors(selected)) {
      _drawPulse(canvas, target.position, selected: false);
    }
  }

  void _drawPulse(Canvas canvas, Offset center, {required bool selected}) {
    const width = 76.0;
    const height = 32.0;
    if (selected) {
      final pulse = 1 + 0.06 * math.sin(_time * 4.6);
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromCenter(
            center: center,
            width: width * pulse + 14,
            height: height * pulse + 14,
          ),
          const Radius.circular(11),
        ),
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 3
          ..color = const Color(0xFFC8A15A).withValues(alpha: 0.9),
      );
      return;
    }
    final pulse = 0.45 + 0.4 * math.sin(_time * 5);
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromCenter(center: center, width: width + 12, height: height + 12),
        const Radius.circular(10),
      ),
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.2
        ..color = const Color(0xFFB03A2E)
            .withValues(alpha: 0.35 + 0.35 * pulse),
    );
  }

  void _drawCities(Canvas canvas) {
    for (final city in controller.game.cities.values) {
      _drawCity(canvas, city);
    }
  }

  void _drawCity(Canvas canvas, City city) {
    final center = city.position;
    final ownerColor = FactionDefs.colorOf(city.owner);
    const width = 76.0;
    const height = 32.0;
    final rect = RRect.fromRectAndRadius(
      Rect.fromCenter(center: center, width: width, height: height),
      const Radius.circular(7),
    );

    // 势力色的旗面，深浅两层让城池在宣纸上立起来。
    canvas.drawRRect(
      rect.shift(const Offset(0, 2.5)),
      Paint()..color = Colors.black.withValues(alpha: 0.18),
    );
    canvas.drawRRect(rect, Paint()..color = ownerColor);
    canvas.drawRRect(
      rect.deflate(2.5),
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1
        ..color = Colors.white.withValues(alpha: 0.25),
    );
    canvas.drawRRect(
      rect,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.6
        ..color = Colors.black.withValues(alpha: 0.25),
    );

    final namePainter = _namePainter(city.name);
    namePainter.paint(
      canvas,
      center - Offset(namePainter.width / 2, namePainter.height / 2 + 1),
    );

    final troopPainter = _troopPainter(city.troops);
    troopPainter.paint(
      canvas,
      center + Offset(-troopPainter.width / 2, height / 2 + 2),
    );

    // 有太守的城池右上角点一颗金色小印。
    if (city.governor != null) {
      canvas.drawCircle(
        center + const Offset(34, -16),
        4.2,
        Paint()..color = const Color(0xFFE7C778),
      );
    }
    // 该势力君主所在城池用一个小方块标出。
    final rulerName = FactionDefs.byId(city.owner).ruler;
    final governor = city.governor == null
        ? null
        : controller.game.generals[city.governor];
    if (governor != null && governor.name == rulerName) {
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromCenter(
            center: center + const Offset(-34, -16),
            width: 7,
            height: 7,
          ),
          const Radius.circular(1.5),
        ),
        Paint()..color = const Color(0xFFFFF1D0),
      );
    }
  }

  TextPainter _namePainter(String name) => _namePainters.putIfAbsent(name, () {
    return TextPainter(
      text: TextSpan(
        text: name,
        style: TextStyle(
          fontSize: 18 * _labelBoost,
          fontWeight: FontWeight.w700,
          letterSpacing: 2,
          color: const Color(0xFFFFF6E4),
          fontFamily: kIsWeb ? kWebFontFamily : null,
          fontFamilyFallback: kKaiFontFallback,
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
  });

  TextPainter _troopPainter(int troops) {
    final label = '兵 ${formatTroopsCompact(troops)}';
    final cached = _troopPainters[label];
    if (cached != null) return cached;
    // 长期对局里兵数标签会不断出现新组合，超过上限就整体重建，避免缓存无限增长。
    if (_troopPainters.length >= 96) _troopPainters.clear();
    return _troopPainters[label] = TextPainter(
      text: TextSpan(
        text: label,
        style: TextStyle(
          fontSize: 11 * math.min(_labelBoost, 1.4),
          letterSpacing: 0.4,
          color: _palette.ink.withValues(alpha: 0.75),
          fontFamily: kIsWeb ? kWebFontFamily : null,
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
  }

  @override
  void onTapDown(TapDownEvent event) {
    onInput?.call();
    final scale = _scale;
    if (scale <= 0) return;
    final point = Offset(
      event.localPosition.x / scale,
      event.localPosition.y / scale,
    );
    String? hit;
    var best = math.max(44.0, 26 / scale);
    for (final city in controller.game.cities.values) {
      final distance = (city.position - point).distance;
      if (distance < best) {
        best = distance;
        hit = city.id;
      }
    }
    final before = controller.selectedCityId;
    controller.selectCity(hit);
    if (controller.selectedCityId != before) SoundService.tap();
  }
}
