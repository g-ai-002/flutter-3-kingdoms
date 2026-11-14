import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:material_ui/material_ui.dart';

import 'app.dart';
import 'services/log_service.dart';
import 'services/logging_init.dart';
import 'services/music_service.dart';
import 'services/sound_service.dart';
import 'services/storage_service.dart';
import 'utils/constants.dart';
import 'utils/window_setup.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  FlutterError.onError = (details) {
    FlutterError.presentError(details);
    LogService.error('Flutter 异常', details.exception, details.stack);
  };
  PlatformDispatcher.instance.onError = (error, stack) {
    LogService.error('未捕获异常', error, stack);
    return true;
  };

  // 窗口尺寸需要首帧前就位；偏好读取与之并行，日志目录留到首帧之后再准备。
  final storageFuture = StorageService.instance;
  await setupDesktopWindow();
  final storage = await storageFuture;

  LogService.info('应用启动: ${AppConstants.appName} v${AppConstants.version}');
  MusicService.enabled = storage.musicEnabled;

  runApp(SanguoApp(storage: storage));

  // 初始化前的日志先进内存缓冲，日志目录就绪后自动补写。
  unawaited(initLogging());

  // 首页首帧渲染完再准备音频：合成已移到后台 isolate，这里只负责错峰启动。
  WidgetsBinding.instance.addPostFrameCallback((_) {
    unawaited(_warmUpAudio(storage));
  });
}

Future<void> _warmUpAudio(StorageService storage) async {
  await Future<void>.delayed(const Duration(milliseconds: 600));
  await SoundService.init();
  MusicService.enabled = storage.musicEnabled;
  if (storage.musicEnabled && !kIsWeb) unawaited(MusicService.start());
}
