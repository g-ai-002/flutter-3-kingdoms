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
import '../utils/logic_rate.dart';
import '../utils/map_layout.dart';

/// Flame 战略地图：绘制城池、驿道与势力版图，处理点击与选中脉冲。
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
  ui.Picture? _background;
  double _backgroundScale = 0;
  Brightness? _backgroundBrightness;
  final Map<String, TextPainter> _namePainters = {};
  final Map<String, TextPainter> _troopPainters = {};
  double _textScale = 0;
  Brightness? _textBrightness;
  double _labelBoost = 1;

  MapPalette get _palette => MapPalette.of(brightness.value);

  @override
  Future<void> onLoad() async {
    brightness.addListener(_invalidate);
  }

  @override
  void onRemove() {
    brightness.removeListener(_invalidate);
    _background?.dispose();
    _background = null;
    super.onRemove();
  }

  void _invalidate() {
    _background?.dispose();
    _background = null;
    _namePainters.clear();
    _troopPainters.clear();
    _textScale = 0;
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
    if ((_textScale - scale).abs() > 0.001 ||
        _textBrightness != brightness.value) {
      _textScale = scale;
      _textBrightness = brightness.value;
      // 小屏上地图整体缩得很小，按比例放大字面，保证城名仍可辨认。
      _labelBoost = scale < 0.62 ? (0.62 / scale).clamp(1.0, 1.7) : 1.0;
      _namePainters.clear();
      _troopPainters.clear();
    }
    canvas.save();
    canvas.scale(scale, scale);
    canvas.drawPicture(_backgroundPicture());
    _drawRoads(canvas);
    _drawCities(canvas);
    canvas.restore();
  }

  ui.Picture _backgroundPicture() {
    final cached = _background;
    if (cached != null &&
        (_backgroundScale - _scale).abs() < 0.0001 &&
        _backgroundBrightness == brightness.value) {
      return cached;
    }
    _background?.dispose();
    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder);
    paintMapBackground(
      canvas,
      kMapDesignSize,
      _palette,
      fontFamily: kIsWeb ? kWebFontFamily : null,
    );
    _background = recorder.endRecording();
    _backgroundScale = _scale;
    _backgroundBrightness = brightness.value;
    return _background!;
  }

  void _drawRoads(Canvas canvas) {
    final palette = _palette;
    final cities = controller.game.cities;
    final selected = controller.selectedCity;
    final seen = <String>{};
    for (final city in cities.values) {
      for (final neighborId in city.neighbors) {
        final key = city.id.compareTo(neighborId) < 0
            ? '${city.id}-$neighborId'
            : '$neighborId-${city.id}';
        if (!seen.add(key)) continue;
        final other = cities[neighborId]!;
        final sameOwner = city.owner == other.owner;
        final touchesSelected =
            selected != null &&
            (selected.id == city.id || selected.id == other.id);
        final isTarget =
            touchesSelected &&
            selected.owner == controller.game.playerFaction &&
            !sameOwner;
        final highlighted = touchesSelected;
        final color = isTarget
            ? const Color(0xFFB03A2E).withValues(alpha: 0.8)
            : sameOwner
            ? FactionDefs.colorOf(city.owner).withValues(alpha: 0.36)
            : palette.road.withValues(alpha: 0.42);
        paintRoad(
          canvas,
          city.position,
          other.position,
          color,
          highlighted ? 4.2 : 2.6,
          dashLength: isTarget ? 13 : 9,
        );
      }
    }
  }

  void _drawCities(Canvas canvas) {
    final game = controller.game;
    final selectedId = controller.selectedCityId;
    final selected = controller.selectedCity;
    final targets = <String>{};
    if (selected != null && selected.owner == game.playerFaction) {
      for (final neighbor in game.enemyNeighbors(selected)) {
        targets.add(neighbor.id);
      }
    }
    for (final city in game.cities.values) {
      _drawCity(
        canvas,
        city,
        selected: city.id == selectedId,
        target: targets.contains(city.id),
      );
    }
  }

  void _drawCity(
    Canvas canvas,
    City city, {
    required bool selected,
    required bool target,
  }) {
    final center = city.position;
    final ownerColor = FactionDefs.colorOf(city.owner);
    const width = 76.0;
    const height = 32.0;
    final rect = RRect.fromRectAndRadius(
      Rect.fromCenter(center: center, width: width, height: height),
      const Radius.circular(7),
    );

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
    }
    if (target) {
      final pulse = 0.45 + 0.4 * math.sin(_time * 5);
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromCenter(center: center, width: width + 12, height: height + 12),
          const Radius.circular(10),
        ),
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2.2
          ..color = const Color(0xFFB03A2E).withValues(alpha: 0.35 + 0.35 * pulse),
      );
    }

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
    final label = '兵 ${_compactTroops(troops)}';
    return _troopPainters.putIfAbsent(label, () {
      return TextPainter(
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
    });
  }

  String _compactTroops(int troops) {
    if (troops >= 10000) return '${(troops / 10000).toStringAsFixed(1)}万';
    if (troops >= 1000) return '${(troops / 1000).toStringAsFixed(1)}千';
    return '$troops';
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
