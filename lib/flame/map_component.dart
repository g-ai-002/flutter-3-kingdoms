import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flame/components.dart';
import 'package:flame/events.dart';
import 'package:flutter/foundation.dart';
import 'package:material_ui/material_ui.dart';

import '../game/game_controller.dart';
import '../models/city.dart';
import '../models/faction.dart';
import '../theme/map_painting.dart';
import '../utils/constants.dart';
import '../utils/formatters.dart';
import '../utils/logic_rate.dart';
import '../utils/map_layout.dart';

/// 城池徽记的矩形尺寸：选中环与脉冲环都按它外扩。
const double _cityWidth = 76;
const double _cityHeight = 32;

/// Flame 战略地图：绘制城池、驿道与势力版图，处理点击与选中脉冲。
///
/// 地形、驿道、城池徽记与选中装饰拆成四张 [ui.Picture]：地形只在主题变化时
/// 重录，驿道与选中装饰只随城池归属变化，徽记额外跟随兵数档位与太守。
/// 内政、登用等不改变地图外观的指令不再触发整幅地图重绘。
class MapComponent extends PositionComponent with TapCallbacks {
  MapComponent({
    required this.controller,
    required this.brightness,
    this.onInput,
    LogicRate logicRate = LogicRate.hz60,
  }) : _logicRate = logicRate,
       _stepper = FixedStepClock(logicRate.step);

  final GameController controller;
  final ValueListenable<Brightness> brightness;
  final VoidCallback? onInput;
  FixedStepClock _stepper;
  LogicRate _logicRate;

  double _time = 0;

  /// 逻辑更新速率，对局中切换后按新的固定步长推进动画。
  LogicRate get logicRate => _logicRate;
  set logicRate(LogicRate value) {
    if (value == _logicRate) return;
    _logicRate = value;
    _stepper = FixedStepClock(value.step);
  }

  final _terrain = _CachedLayer();
  final _roads = _CachedLayer();
  final _badges = _CachedLayer();
  final _selection = _CachedLayer();

  int _checkedRevision = -1;
  int _visualSignature = 0;
  int _ownerSignature = 0;

  final Map<String, TextPainter> _namePainters = {};

  /// 兵数标签随主题变色，按深浅色各存一份，切主题时不必重新排版。
  final Map<Brightness, Map<String, TextPainter>> _troopPainters = {
    Brightness.light: {},
    Brightness.dark: {},
  };
  double _textBoost = 0;
  double _labelBoost = 1;
  int _nameLayouts = 0;
  int _troopLayouts = 0;

  MapPalette get _palette => MapPalette.of(brightness.value);

  /// 选中脉冲是否继续逐帧播放；停帧后由 [SanguoGame] 置回 true 唤醒。
  bool pulseActive = true;

  /// 是否已经画出过一帧：首帧尺寸未就绪时先别停帧，避免留下空白地图。
  bool painted = false;

  /// 各图层累计重新录制的次数，供性能测试断言缓存命中。
  @visibleForTesting
  int get terrainLayerBuilds => _terrain.builds;
  @visibleForTesting
  int get roadLayerBuilds => _roads.builds;
  @visibleForTesting
  int get badgeLayerBuilds => _badges.builds;
  @visibleForTesting
  int get selectionLayerBuilds => _selection.builds;

  /// 城名与兵数标签的排版次数，供性能测试断言切主题不重新排版。
  @visibleForTesting
  int get cityNameLayouts => _nameLayouts;
  @visibleForTesting
  int get troopLabelLayouts => _troopLayouts;

  /// 逻辑时钟累计的动画时间，供帧率切换测试断言。
  @visibleForTesting
  double get animationTime => _time;

  @override
  void onRemove() {
    _disposeLayers();
    super.onRemove();
  }

  void _disposeLayers() {
    _terrain.dispose();
    _roads.dispose();
    _badges.dispose();
    _selection.dispose();
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
    _refreshSignatures();
    canvas.save();
    canvas.scale(scale, scale);
    canvas.drawPicture(
      _terrain.take(0, brightness.value, (layer) {
        paintMapBackground(
          layer,
          kMapDesignSize,
          _palette,
          fontFamily: kIsWeb ? kWebFontFamily : null,
        );
      }),
    );
    canvas.drawPicture(
      _roads.take(_ownerSignature, brightness.value, _drawRoads),
    );
    canvas.drawPicture(
      _badges.take(
        Object.hash(_visualSignature, _labelBoost),
        brightness.value,
        _drawCities,
      ),
    );
    _drawSelection(canvas);
    canvas.restore();
    painted = true;
  }

  /// 小屏上地图整体缩得很小，按比例放大字面，保证城名仍可辨认。
  /// 缩放档位量化到 0.05，拖动窗口时不会每一帧都重录静态图层。
  ///
  /// 只有字号变化才重排文字：城名颜色与主题无关，兵数标签按深浅色各存一份，
  /// 来回切换深色模式不再重排任何一条文字。
  void _syncTextMetrics(double scale) {
    final boost = scale < 0.62 ? (0.62 / scale).clamp(1.0, 1.7) : 1.0;
    final quantized = (boost * 20).roundToDouble() / 20;
    if ((_textBoost - quantized).abs() < 0.001) return;
    _textBoost = quantized;
    _labelBoost = quantized;
    _namePainters.clear();
    for (final cache in _troopPainters.values) {
      cache.clear();
    }
  }

  /// 地图签名：归属签名只看谁是城主，视觉签名还看兵数档位与太守。
  /// 修订号未变时两个签名都不必重算，避免每帧遍历城池。
  void _refreshSignatures() {
    final revision = controller.revision;
    if (_checkedRevision == revision) return;
    _checkedRevision = revision;
    var owner = 23;
    var visual = 17;
    for (final city in controller.game.cities.values) {
      owner = Object.hash(owner, city.owner);
      visual = Object.hash(
        visual,
        city.owner,
        _troopBucket(city.troops),
        city.governor,
      );
    }
    _ownerSignature = owner;
    _visualSignature = visual;
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
    canvas.drawPicture(
      _selection.take(
        Object.hash(_ownerSignature, selected.id),
        brightness.value,
        (layer) => _paintSelection(layer, selected),
      ),
    );
    if (pulseActive) _drawPulse(canvas, selected.position);
  }

  void _paintSelection(Canvas canvas, City selected) {
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
  }

  void _drawRing(
    Canvas canvas,
    Offset center, {
    required double alpha,
    required double strokeWidth,
  }) {
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromCenter(
          center: center,
          width: _cityWidth + 12,
          height: _cityHeight + 12,
        ),
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
    final pulse = 1 + 0.06 * math.sin(_time * 4.6);
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromCenter(
          center: center,
          width: _cityWidth * pulse + 14,
          height: _cityHeight * pulse + 14,
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
    final rect = RRect.fromRectAndRadius(
      Rect.fromCenter(center: center, width: _cityWidth, height: _cityHeight),
      const Radius.circular(7),
    );

    // 势力色的旗面，深浅两层让城池在宣纸上立起来。
    canvas.drawRRect(rect.shift(const Offset(0, 2.5)), _shadowPaint);
    canvas.drawRRect(
      rect,
      _ownerPaint..color = FactionDefs.colorOf(city.owner),
    );
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
      center + Offset(-troopPainter.width / 2, _cityHeight / 2 + 2),
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
    _nameLayouts++;
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
    final cache = _troopPainters[brightness.value]!;
    final cached = cache[label];
    if (cached != null) return cached;
    // 长期对局里兵数标签会不断出现新组合，超过上限就整体重建，避免缓存无限增长。
    if (cache.length >= 96) cache.clear();
    _troopLayouts++;
    return cache[label] = TextPainter(
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
    controller.selectCity(hit);
  }
}

/// 按签名与主题缓存的静态图层：签名不变时直接复用上一张 [ui.Picture]。
class _CachedLayer {
  ui.Picture? _picture;
  int _signature = -1;
  Brightness? _brightness;
  int builds = 0;

  ui.Picture take(
    int signature,
    Brightness brightness,
    void Function(Canvas canvas) paint,
  ) {
    final cached = _picture;
    if (cached != null &&
        _signature == signature &&
        _brightness == brightness) {
      return cached;
    }
    cached?.dispose();
    final recorder = ui.PictureRecorder();
    paint(Canvas(recorder));
    _signature = signature;
    _brightness = brightness;
    builds++;
    return _picture = recorder.endRecording();
  }

  void dispose() {
    _picture?.dispose();
    _picture = null;
    _signature = -1;
  }
}
