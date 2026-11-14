import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:provider/provider.dart';

import 'pages/home_page.dart';
import 'providers/settings_provider.dart';
import 'services/log_service.dart';
import 'services/music_service.dart';
import 'services/storage_service.dart';
import 'theme/app_theme.dart';
import 'utils/constants.dart';
import 'utils/system_ui.dart';

class SanguoApp extends StatefulWidget {
  const SanguoApp({super.key, required this.storage});

  final StorageService storage;

  @override
  State<SanguoApp> createState() => _SanguoAppState();
}

class _SanguoAppState extends State<SanguoApp> with WidgetsBindingObserver {
  /// 字体与两套主题只在启动时确定：设置变更不再重复构建 ThemeData。
  late final String? _fontFamily = kIsWeb
      ? kWebFontFamily
      : defaultTargetPlatform == TargetPlatform.windows
      ? 'Microsoft YaHei UI'
      : null;
  late final ThemeData _lightTheme = buildLightTheme(fontFamily: _fontFamily);
  late final ThemeData _darkTheme = buildDarkTheme(fontFamily: _fontFamily);

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    switch (state) {
      case AppLifecycleState.resumed:
        MusicService.resumeForLifecycle();
        break;
      case AppLifecycleState.paused:
      case AppLifecycleState.hidden:
        MusicService.pauseForLifecycle();
        // 系统随时可能回收后台进程，先把待写日志刷进文件。
        unawaited(LogService.flush());
        break;
      case AppLifecycleState.inactive:
        break;
      case AppLifecycleState.detached:
        unawaited(LogService.flush());
        break;
    }
  }

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (_) => SettingsProvider(widget.storage),
      // 外壳只跟随深浅色：音效、难度等设置变更不再重建整个应用。
      child: Selector<SettingsProvider, bool>(
        selector: (_, settings) => settings.darkMode,
        builder: (context, darkMode, _) {
          return MaterialApp(
            title: AppConstants.appName,
            debugShowCheckedModeBanner: false,
            theme: _lightTheme,
            darkTheme: _darkTheme,
            themeMode: darkMode ? ThemeMode.dark : ThemeMode.light,
            localizationsDelegates: const [
              GlobalMaterialLocalizations.delegate,
              GlobalWidgetsLocalizations.delegate,
              GlobalCupertinoLocalizations.delegate,
            ],
            supportedLocales: const [Locale('zh', 'CN')],
            locale: const Locale('zh', 'CN'),
            // Web 首次点击用于解除浏览器的自动播放限制。
            builder: (context, child) => SystemUiOverlay(
              child: Listener(
                behavior: HitTestBehavior.translucent,
                onPointerDown: kIsWeb
                    ? (_) => MusicService.retryOnInteraction()
                    : null,
                child: child ?? const SizedBox.shrink(),
              ),
            ),
            home: const HomePage(),
          );
        },
      ),
    );
  }
}
