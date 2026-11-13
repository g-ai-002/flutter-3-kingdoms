import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// 手机等窄屏设备是否值得为横向地图横屏全屏。
///
/// 战略地图是 1200:760 的横向画卷，横屏能给地图更大的显示面积，因此窄屏
/// 手机自动进入横屏沉浸模式；平板、桌面与 Web 保持用户当前的窗口形态。
bool shouldImmersiveLandscape(Size size) {
  if (kIsWeb || defaultTargetPlatform != TargetPlatform.android) return false;
  // 统一折算成竖屏尺寸再判断，横屏后宽高互换结论保持不变，避免来回旋转。
  final portrait = Size(
    size.width < size.height ? size.width : size.height,
    size.width < size.height ? size.height : size.width,
  );
  return portrait.shortestSide < 600;
}

/// 地图页显示模式：满足 [shouldImmersiveLandscape] 时切到横屏并隐藏系统栏，
/// 离开后恢复系统栏与自动旋转。多个页面叠放时按引用计数只在最后一个退出时恢复。
class MapDisplayMode extends StatefulWidget {
  const MapDisplayMode({super.key, required this.child});

  final Widget child;

  @override
  State<MapDisplayMode> createState() => _MapDisplayModeState();
}

class _MapDisplayModeState extends State<MapDisplayMode> {
  static int _holders = 0;

  bool _applied = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final wanted = shouldImmersiveLandscape(MediaQuery.sizeOf(context));
    if (wanted == _applied) return;
    _applied = wanted;
    if (wanted) {
      _holders++;
      if (_holders == 1) _enter();
    } else {
      _release();
    }
  }

  Future<void> _enter() async {
    await SystemChrome.setPreferredOrientations(const [
      DeviceOrientation.landscapeLeft,
      DeviceOrientation.landscapeRight,
    ]);
    await SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
  }

  void _release() {
    if (_holders > 0) _holders--;
    if (_holders > 0) return;
    SystemChrome.setPreferredOrientations(DeviceOrientation.values);
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
  }

  @override
  void dispose() {
    if (_applied) _release();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => widget.child;
}
