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
    await LogService.flush();

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

  test('连续日志合并成一批写入，界面线程不必逐条落盘', () async {
    await LogService.init(logRoot: () async => tempDir);
    final before = LogService.writeBatches;
    for (var i = 0; i < 40; i++) {
      LogService.info('第 $i 条军报');
    }
    await LogService.flush();
    expect(LogService.writeBatches - before, 1, reason: '四十条日志只写一次文件');

    final content = await File(LogService.logFilePath).readAsString();
    expect(content, contains('第 0 条军报'));
    expect(content, contains('第 39 条军报'));

    // 空队列再次刷新不产生写盘。
    await LogService.flush();
    expect(LogService.writeBatches - before, 1);
  });

  test('内存日志环形滚动，超出上限后仍按时间顺序取最近若干条', () async {
    await LogService.init(logRoot: () async => tempDir);
    for (var i = 0; i < 2100; i++) {
      LogService.info('滚动日志 $i');
    }
    final recent = LogService.getRecentLogs(3);
    expect(recent, hasLength(3));
    expect(recent[0], contains('滚动日志 2097'));
    expect(recent[1], contains('滚动日志 2098'));
    expect(recent[2], contains('滚动日志 2099'));
  });
}
