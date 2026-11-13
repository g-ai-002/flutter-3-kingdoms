/// 桌面窗口初始化：按平台选择实现。
library;

export 'window_setup_io.dart' if (dart.library.js_interop) 'window_setup_web.dart';
