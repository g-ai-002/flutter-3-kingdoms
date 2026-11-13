import 'dart:isolate';

/// 桌面与移动端把合成放到临时 isolate，主线程只等待结果。
Future<T> runAudioTask<T>(T Function() task) => Isolate.run(task);
