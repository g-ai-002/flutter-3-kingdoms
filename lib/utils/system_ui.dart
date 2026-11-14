import 'package:flutter/services.dart';
import 'package:material_ui/material_ui.dart';

/// 系统栏（状态栏与导航栏）样式：透明底色，图标深浅由背景亮度决定。
///
/// Android 15 起系统强制边到边绘制，状态栏颜色不再生效，因此按页面底色
/// 推导图标亮度，保证深色宣纸底与浅色卡片上都看得清。
SystemUiOverlayStyle systemOverlayStyleFor(Color background) {
  final dark = background.computeLuminance() < 0.5;
  final iconBrightness = dark ? Brightness.light : Brightness.dark;
  return SystemUiOverlayStyle(
    statusBarColor: Colors.transparent,
    statusBarIconBrightness: iconBrightness,
    statusBarBrightness: dark ? Brightness.dark : Brightness.light,
    systemNavigationBarColor: Colors.transparent,
    systemNavigationBarDividerColor: Colors.transparent,
    systemNavigationBarIconBrightness: iconBrightness,
  );
}

/// 按当前主题的页面底色设置系统栏样式，随深浅色模式切换。
class SystemUiOverlay extends StatelessWidget {
  const SystemUiOverlay({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: systemOverlayStyleFor(Theme.of(context).scaffoldBackgroundColor),
      child: child,
    );
  }
}
