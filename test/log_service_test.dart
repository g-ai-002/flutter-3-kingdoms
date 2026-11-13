import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import 'package:flutter_3_kingdoms/services/log_service.dart';

void main() {
  late Directory tempDir;

  setUp(() async {
    LogService.reset();
    tempDir = await Directory.systemTemp.createTemp('sanguo_log_test');
  });

  tearDown(() async {
    LogService.reset();
    if (await tempDir.exists()) await tempDir.delete(recursive: true);
  });

  test('日志按天写入指定目录并可在内存中查看', () async {
    await LogService.init(logRoot: () async => tempDir);
    LogService.info('开局：曹操据许昌');
    LogService.warning('粮草不足');
    LogService.error('模拟异常', StateError('boom'));

    final file = File(LogService.logFilePath);
    expect(await file.exists(), isTrue);
    final content = await file.readAsString();
    expect(content, contains('开局：曹操据许昌'));
    expect(content, contains('粮草不足'));
    expect(content, contains('模拟异常'));
    expect(content, contains('boom'));

    final recent = LogService.getRecentLogs(10);
    expect(recent, isNotEmpty);
    expect(recent.last, contains('模拟异常'));
  });

  test('初始化前的日志会补写入文件', () async {
    LogService.info('初始化前的早期日志');
    await LogService.init(logRoot: () async => tempDir);
    final content = await File(LogService.logFilePath).readAsString();
    expect(content, contains('初始化前的早期日志'));
  });
}
