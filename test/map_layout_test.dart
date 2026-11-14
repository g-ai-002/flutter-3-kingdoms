import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:flutter_3_kingdoms/utils/map_display_mode.dart';
import 'package:flutter_3_kingdoms/utils/map_layout.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('地图排版', () {
    test('地图按 1200:760 的比例在可用空间内取最大尺寸', () {
      final wide = mapFitSize(const Size(1400, 900));
      expect(wide.width, 1240);
      expect(wide.height, closeTo(1240 * 760 / 1200, 0.01));

      final narrow = mapFitSize(const Size(600, 280));
      expect(narrow.height, 280);
      expect(narrow.width, closeTo(280 * 1200 / 760, 0.01));

      expect(mapFitSize(Size.zero), Size.zero);
    });

    test('超宽屏把信息卡挂到两侧，普通屏排在地图上方', () {
      final wide = resolveHud(const Size(1700, 900));
      expect(wide.sideRail, isTrue);
      expect(wide.rail, greaterThan(kHudRailWidth));

      final normal = resolveHud(const Size(900, 900));
      expect(normal.sideRail, isFalse);
      expect(normal.rail, lessThan(kHudRailWidth));
    });

    test('矮屏使用紧凑卡片并给底部按钮留出空间', () {
      final compact = resolveHud(const Size(900, 480));
      expect(compact.compact, isTrue);
      expect(compact.rail, lessThan(kHudRailWidth));
    });
  });

  group('横屏策略', () {
    tearDown(() => debugDefaultTargetPlatformOverride = null);

    test('窄屏手机进入地图页自动横屏全屏', () {
      expect(shouldImmersiveLandscape(const Size(400, 800)), isTrue);
      expect(shouldImmersiveLandscape(const Size(800, 400)), isTrue);
    });

    test('平板与桌面保持用户当前窗口形态', () {
      expect(shouldImmersiveLandscape(const Size(800, 1280)), isFalse);
      expect(shouldImmersiveLandscape(const Size(1280, 900)), isFalse);
      debugDefaultTargetPlatformOverride = TargetPlatform.windows;
      expect(shouldImmersiveLandscape(const Size(400, 800)), isFalse);
    });
  });
}
