/// 日志初始化：按平台选择实现。
library;

export 'logging_init_io.dart'
    if (dart.library.js_interop) 'logging_init_web.dart';
