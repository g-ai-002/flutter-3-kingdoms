/// 逻辑更新速率：以固定步长推进地图动画与战斗动画，渲染仍按屏幕刷新逐帧绘制。
enum LogicRate {
  hz30('30 Hz 省电', 30),
  hz60('60 Hz 均衡', 60),
  hz120('120 Hz 顺滑', 120);

  const LogicRate(this.label, this.hz);
  final String label;
  final int hz;

  double get step => 1 / hz;

  /// 未设置或未知值时回退到默认 60Hz。
  static LogicRate byName(String? name) => values.firstWhere(
    (item) => item.name == name,
    orElse: () => LogicRate.hz60,
  );
}

/// 固定步长累加器：把不稳定的渲染帧间隔折算成固定数量的逻辑步。
class FixedStepClock {
  FixedStepClock(this.step, {this.maxSteps = 4});

  final double step;
  final int maxSteps;
  double _remainder = 0;

  /// 消费 [dt] 并回调一次合并后的逻辑步长，返回本帧推进的步数。
  /// 切后台或严重卡顿后积压的大量时间合并成一次大步推进，避免动画被拖慢。
  int advance(double dt, void Function(double span) onStep) {
    if (dt <= 0) return 0;
    _remainder += dt;
    var steps = 0;
    while (_remainder + 1e-9 >= step && steps < maxSteps) {
      _remainder -= step;
      steps++;
    }
    if (steps == 0) return 0;
    final overflow = _remainder >= step ? _remainder : 0.0;
    _remainder = overflow > 0 ? 0 : _remainder;
    onStep(steps * step + overflow);
    return steps;
  }
}

/// 地图静置策略：选中城池后先播放 [pulseSeconds] 的脉冲再停帧；没有选中时
/// 一次数据变化只重绘一帧便停帧，静止期间不再空转渲染循环。
class MapIdlePolicy {
  MapIdlePolicy({this.pulseSeconds = 2.4});

  final double pulseSeconds;
  bool _pulse = true;
  double _pulseElapsed = 0;

  bool get pulse => _pulse;

  /// 重新开始脉冲计时；点击、选中与数据变化都会调用。
  void wake() {
    _pulse = true;
    _pulseElapsed = 0;
  }

  /// 推进一帧，返回 true 表示本帧之后可以停帧。
  bool tick(double dt, {required bool selected}) {
    if (!_pulse) return true;
    if (!selected) {
      _pulse = false;
      return true;
    }
    _pulseElapsed += dt;
    if (_pulseElapsed < pulseSeconds) return false;
    _pulse = false;
    _pulseElapsed = 0;
    return true;
  }
}
