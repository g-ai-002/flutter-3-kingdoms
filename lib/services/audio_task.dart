import 'audio_task_stub.dart' if (dart.library.io) 'audio_task_io.dart' as impl;

/// 在后台 isolate 执行纯计算任务，避免音频合成阻塞界面线程。
/// Web 没有可用 isolate 时退回主线程执行。
Future<T> runAudioTask<T>(T Function() task) => impl.runAudioTask(task);
