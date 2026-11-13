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
/// 地形、驿道与城池徽记拆成三张 [ui.Picture]：地形只在主题变化时重录，
/// 徽记只在势力、兵数或太守变化时重录，选中层只在选中城池或版图变化时重录。
/// 内政、登用等不改变地图外观的指令不再触发整幅地图重绘。
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

  ui.Picture? _terrainLayer;
  Brightness? _terrainBrightness;
  int _terrainBuilds = 0;

  ui.Picture? _badgeLayer;
  int _badgeSignature = -1;
  double _badgeBoost = 0;
  Brightness? _badgeBrightness;
  int _badgeBuilds = 0;

  ui.Picture? _selectionLayer;
  int _selectionSignature = -1;
  String? _selectionCityId;
  Brightness? _selectionBrightness;
  int _selectionBuilds = 0;

  int _checkedRevision = -1;
  int _visualSignature = 0;

  final Map<String, TextPainter> _namePainters = {};
  final Map<String, TextPainter> _troopPainters = {};
  double _textBoost = 0;
  Brightness? _textBrightness;
  double _labelBoost = 1;

  MapPalette get _palette => MapPalette.of(brightness.value);

  /// 选中脉冲是否继续逐帧播放；停帧后由 [SanguoGame] 置回 true 唤醒。
  bool pulseActive = true;

  /// 各图层累计重新录制的次数，供性能测试断言缓存命中。
  @visibleForTesting
  int get terrainLayerBuilds => _terrainBuilds;

  @visibleForTesting
  int get badgeLayerBuilds => _badgeBuilds;

  @visibleForTesting
  int get selectionLayerBuilds => _selectionBuilds;

  @override
  void onRemove() {
    _disposeLayers();
    super.onRemove();
  }

  void _disposeLayers() {
    _terrainLayer?.dispose();
    _terrainLayer = null;
    _terrainBrightness = null;
    _badgeLayer?.dispose();
    _badgeLayer = null;
    _badgeSignature = -1;
    _checkedRevision = -1;
    _selectionLayer?.dispose();
    _selectionLayer = null;
    _selectionSignature = -1;
    _selectionCityId = null;
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
    canvas.drawPicture(_terrainPicture());
    canvas.drawPicture(_badgePicture());
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

  ui.Picture _terrainPicture() {
    final cached = _terrainLayer;
    if (cached != null && _terrainBrightness == brightness.value) return cached;
    _terrainLayer?.dispose();
    final recorder = ui.PictureRecorder();
    paintMapBackground(
      Canvas(recorder),
      kMapDesignSize,
      _palette,
      fontFamily: kIsWeb ? kWebFontFamily : null,
    );
    _terrainLayer = recorder.endRecording();
    _terrainBrightness = brightness.value;
    _terrainBuilds++;
    return _terrainLayer!;
  }

  ui.Picture _badgePicture() {
    final signature = _signature();
    final cached = _badgeLayer;
    if (cached != null &&
        _badgeSignature == signature &&
        _badgeBoost == _labelBoost &&
        _badgeBrightness == brightness.value) {
      return cached;
    }
    _badgeLayer?.dispose();
    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder);
    _drawRoads(canvas);
    _drawCities(canvas);
    _badgeLayer = recorder.endRecording();
    _badgeSignature = signature;
    _badgeBoost = _labelBoost;
    _badgeBrightness = brightness.value;
    _badgeBuilds++;
    return _badgeLayer!;
  }

  /// 地图外观签名：势力、兵数档位与太守。数值内政不改变徽记，无需重录。
  int _signature() {
    final revision = controller.revision;
    if (_checkedRevision == revision) return _visualSignature;
    _checkedRevision = revision;
    var hash = 17;
    for (final city in controller.game.cities.values) {
      hash = Object.hash(
        hash,
        city.owner,
        _troopBucket(city.troops),
        city.governor,
      );
    }
    _visualSignature = hash;
    return hash;
  }

  /// 兵数标签只显示到 0.1 万 / 0.1 千，同一档位内的变化不必重录徽记。
  int _troopBucket(int troops) {
    if (troops >= 10000) return 3000 + (troops / 1000).round();
    if (troops >= 1000) return 2000 + (troops / 100).round();
    return troops;
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

  /// 选中城池后，补画相连驿道与目标环；这些静态装饰按选中与版图签名缓存，
  /// 每帧只额外绘制一个脉冲环。
  void _drawSelection(Canvas canvas) {
    final selected = controller.selectedCity;
    if (selected == null) return;
    canvas.drawPicture(_selectionPicture(selected));
    if (pulseActive) _drawPulse(canvas, selected.position);
  }

  ui.Picture _selectionPicture(City selected) {
    final signature = _signature();
    final cached = _selectionLayer;
    if (cached != null &&
        _selectionCityId == selected.id &&
        _selectionSignature == signature &&
        _selectionBrightness == brightness.value) {
      return cached;
    }
    _selectionLayer?.dispose();
    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder);
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
    _drawRing(canvas, selected.position, alpha: 0.9, strokeWidth: 3);
    if (isPlayer) {
      for (final target in controller.game.enemyNeighbors(selected)) {
        _drawRing(canvas, target.position, alpha: 0.55, strokeWidth: 2.2);
      }
    }
    _selectionLayer = recorder.endRecording();
    _selectionCityId = selected.id;
    _selectionSignature = signature;
    _selectionBrightness = brightness.value;
    _selectionBuilds++;
    return _selectionLayer!;
  }

  void _drawRing(
    Canvas canvas,
    Offset center, {
    required double alpha,
    required double strokeWidth,
  }) {
    const width = 76.0;
    const height = 32.0;
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromCenter(center: center, width: width + 12, height: height + 12),
        const Radius.circular(10),
      ),
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = strokeWidth
        ..color = const Color(0xFFB03A2E).withValues(alpha: alpha),
    );
  }

  final Paint _pulsePaint = Paint()
    ..style = PaintingStyle.stroke
    ..strokeWidth = 3
    ..color = const Color(0xFFC8A15A).withValues(alpha: 0.9);

  void _drawPulse(Canvas canvas, Offset center) {
    const width = 76.0;
    const height = 32.0;
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
      _pulsePaint,
    );
  }

  void _drawCities(Canvas canvas) {
    for (final city in controller.game.cities.values) {
      _drawCity(canvas, city);
    }
  }

  // 徽记与选中环的画笔复用，避免每次重录都新建上百个 Paint。
  final Paint _shadowPaint = Paint()..color = const Color(0x2E000000);
  final Paint _ownerPaint = Paint();
  final Paint _innerEdgePaint = Paint()
    ..style = PaintingStyle.stroke
    ..strokeWidth = 1
    ..color = const Color(0x40FFFFFF);
  final Paint _outerEdgePaint = Paint()
    ..style = PaintingStyle.stroke
    ..strokeWidth = 1.6
    ..color = const Color(0x40000000);
  final Paint _governorPaint = Paint()..color = const Color(0xFFE7C778);
  final Paint _rulerPaint = Paint()..color = const Color(0xFFFFF1D0);

  void _drawCity(Canvas canvas, City city) {
    final center = city.position;
    const width = 76.0;
    const height = 32.0;
    final rect = RRect.fromRectAndRadius(
      Rect.fromCenter(center: center, width: width, height: height),
      const Radius.circular(7),
    );

    // 势力色的旗面，深浅两层让城池在宣纸上立起来。
    canvas.drawRRect(rect.shift(const Offset(0, 2.5)), _shadowPaint);
    canvas.drawRRect(rect, _ownerPaint..color = FactionDefs.colorOf(city.owner));
    canvas.drawRRect(rect.deflate(2.5), _innerEdgePaint);
    canvas.drawRRect(rect, _outerEdgePaint);

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
      canvas.drawCircle(center + const Offset(34, -16), 4.2, _governorPaint);
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
        _rulerPaint,
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
