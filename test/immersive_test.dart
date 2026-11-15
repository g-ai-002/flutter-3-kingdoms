import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:flutter_3_kingdoms/app.dart';
import 'package:flutter_3_kingdoms/services/storage_service.dart';

void main() {
  testWidgets('Android 上启动即进入沉浸全屏，回到前台再隐藏一次系统栏', (tester) async {
    SharedPreferences.setMockInitialValues({});
    StorageService.resetForTests();
    debugDefaultTargetPlatformOverride = TargetPlatform.android;

    final calls = <MethodCall>[];
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(SystemChannels.platform, (call) async {
          calls.add(call);
          return null;
        });
    addTearDown(() {
      debugDefaultTargetPlatformOverride = null;
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(SystemChannels.platform, null);
    });

    final storage = await StorageService.instance;
    await tester.pumpWidget(SanguoApp(storage: storage));
    await tester.pump();

    List<Object?> modes() => [
      for (final call in calls)
        if (call.method == 'SystemChrome.setEnabledSystemUIMode')
          call.arguments,
    ];

    expect(modes(), ['SystemUiMode.immersiveSticky']);

    calls.clear();
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await tester.pump();
    expect(modes(), ['SystemUiMode.immersiveSticky']);

    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump();
  });

  testWidgets('桌面与 Web 不触碰系统栏', (tester) async {
    SharedPreferences.setMockInitialValues({});
    StorageService.resetForTests();
    debugDefaultTargetPlatformOverride = TargetPlatform.linux;

    final calls = <MethodCall>[];
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(SystemChannels.platform, (call) async {
          calls.add(call);
          return null;
        });
    addTearDown(() {
      debugDefaultTargetPlatformOverride = null;
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(SystemChannels.platform, null);
    });

    final storage = await StorageService.instance;
    await tester.pumpWidget(SanguoApp(storage: storage));
    await tester.pump();

    expect(
      calls.where((call) => call.method.contains('SystemUiMode')),
      isEmpty,
    );

    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump();
  });
}
