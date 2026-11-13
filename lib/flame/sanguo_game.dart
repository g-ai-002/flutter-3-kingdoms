import 'package:flame/game.dart';
import 'package:flutter/material.dart';

import '../game/game_controller.dart';
import '../utils/logic_rate.dart';
import 'map_component.dart';

/// Flame 游戏入口：目前只有战略地图组件，后续可扩展行军动画与战火特效。
class SanguoGame extends FlameGame with WidgetsBindingObserver {
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
  bool _appActive = true;
  int _coverDepth = 0;

  Brightness get brightness => _brightness.value;
  set brightness(Brightness value) => _brightness.value = value;

  /// 对局页被全屏页或弹层覆盖时暂停渲染，避免地图在后台空转。
  void pauseForCover() {
    _coverDepth++;
    pauseEngine();
  }

  /// 覆盖层关闭后恢复；嵌套弹层按层数配对。
  void resumeAfterCover() {
    if (_coverDepth > 0) _coverDepth--;
    _wake();
  }

  bool get _suspended => !_appActive || _coverDepth > 0;

  @override
  Color backgroundColor() => Colors.transparent;

  @override
  Future<void> onLoad() async {
    WidgetsBinding.instance.addObserver(this);
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

  /// 切到后台立即停掉渲染循环，回到前台再按需恢复。
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    final active = state == AppLifecycleState.resumed;
    _appActive = active;
    if (active) {
      _wake();
    } else {
      pauseEngine();
    }
  }

  void _wake() {
    _idle = 0;
    if (!_suspended && paused) resumeEngine();
  }

  @override
  void onDispose() {
    WidgetsBinding.instance.removeObserver(this);
    _brightness.removeListener(_wake);
    changes?.removeListener(_wake);
    _brightness.dispose();
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
