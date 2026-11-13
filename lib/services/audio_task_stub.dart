/// Web 端没有后台 isolate，直接在调用线程完成任务。
Future<T> runAudioTask<T>(T Function() task) async => task();
