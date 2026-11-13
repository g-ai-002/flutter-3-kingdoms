import 'package:flame/game.dart';
import 'package:flutter/material.dart';

import '../game/game_controller.dart';
import '../utils/logic_rate.dart';
import 'map_component.dart';

/// Flame 游戏入口：目前只有战略地图组件，后续可扩展行军动画与战火特效。
class SanguoGame extends FlameGame {
  SanguoGame({
    required this.controller,
    required Brightness brightness,
    this.logicRate = LogicRate.hz60,
    this.changes,
  }) : _brightness = ValueNotifier(brightness) {
    _brightness.addListener(_wake);
    changes?.addListener(_wake);
  }

  /// 地图静止 [idlePauseSeconds] 后停掉渲染循环，点击与状态变化再唤醒。
  static const double idlePauseSeconds = 1.2;

  final GameController controller;
  final LogicRate logicRate;
  final Listenable? changes;
  final ValueNotifier<Brightness> _brightness;
  MapComponent? _map;
  double _idle = 0;

  Brightness get brightness => _brightness.value;
  set brightness(Brightness value) => _brightness.value = value;

  @override
  Color backgroundColor() => Colors.transparent;

  @override
  Future<void> onLoad() async {
    final map = MapComponent(
      controller: controller,
      brightness: _brightness,
      logicRate: logicRate,
      onInput: _wake,
    );
    _map = map;
    _fit(map);
    await add(map);
  }

  @override
  void update(double dt) {
    super.update(dt);
    final map = _map;
    if (paused || map == null) return;
    // 选中城池的脉冲需要逐帧推进，其余静止画面没有必要重绘。
    if (controller.selectedCityId != null) {
      _idle = 0;
      return;
    }
    _idle += dt;
    if (_idle < idlePauseSeconds) return;
    _idle = 0;
    pauseEngine();
  }

  void _wake() {
    _idle = 0;
    if (paused) resumeEngine();
  }

  @override
  void onDispose() {
    _brightness.removeListener(_wake);
    changes?.removeListener(_wake);
    super.onDispose();
  }

  @override
  void onGameResize(Vector2 size) {
    super.onGameResize(size);
    final map = _map;
    if (map != null) _fit(map);
  }

  void _fit(MapComponent map) {
    map
      ..size = size.clone()
      ..position = Vector2.zero();
  }
}
