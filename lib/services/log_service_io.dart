import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';

import '../utils/formatters.dart';

/// 日志服务：内存环形缓冲 + 按天文件落盘。
///
/// 日志先进待写队列，再由定时器整批异步写入：界面线程不再为每条日志做同步
/// stat 与写盘，结算、战斗这类集中输出也只写一次文件。初始化前的日志先进入
/// 早期缓冲，初始化后补写；日志目录不可用时降级为内存模式。
class LogService {
  static LogService? _instance;
  static final List<String> _earlyBuffer = [];
  final List<String> _buffer = [];
  final List<String> _pending = [];
  Timer? _flushTimer;
  Directory? _logDir;
  File? _logFile;
  DateTime? _logDate;
  int _fileBytes = 0;
  int _bufferStart = 0;
  bool _flushing = false;
  bool _initialized = false;
  DateTime Function() _now = DateTime.now;

  static const int _maxBufferLines = 2000;
  static const int _maxEarlyLines = 500;
  static const int _maxFileSize = 5 * 1024 * 1024;
  static const int _maxRetentionDays = 7;
  static const Duration _flushDelay = Duration(milliseconds: 250);

  /// 累计写盘批次数，供性能测试断言日志是批量落盘。
  @visibleForTesting
  static int writeBatches = 0;

  LogService._();

  static Future<void> init({
    Future<Directory> Function()? logRoot,
    DateTime Function()? clock,
  }) async {
    _instance ??= LogService._();
    await _instance!._init(logRoot, clock);
  }

  /// 立即把待写日志刷入文件：切后台、退出与测试结束前调用。
  static Future<void> flush() async => _instance?._flush();

  /// 仅用于测试。
  static void reset() {
    _instance?._flushTimer?.cancel();
    _instance?._pending.clear();
    _instance = null;
    _earlyBuffer.clear();
    writeBatches = 0;
  }

  Future<void> _init(
    Future<Directory> Function()? logRoot,
    DateTime Function()? clock,
  ) async {
    if (_initialized) return;
    if (clock != null) _now = clock;
    if (logRoot != null) {
      try {
        _logDir = await logRoot();
      } catch (e) {
        debugPrint('[LogService] 日志目录不可用，降级为内存日志: $e');
      }
    }
    _initialized = true;
    _logFile = await _fileForToday();
    _pending.addAll(_earlyBuffer);
    _earlyBuffer.forEach(_remember);
    _earlyBuffer.clear();
    _write('INFO', '==== LogService 已初始化, 日志文件: ${_logFile?.path ?? '内存模式'} ====');
    await _flush();
  }

  static String get logFilePath => _instance?._logFile?.path ?? '';

  static void info(String message) => _log('INFO', message);

  static void warning(String message) => _log('WARN', message);

  static void error(String message, [Object? error, StackTrace? stack]) {
    _log('ERROR', error != null ? '$message | $error' : message);
    if (stack != null) _log('ERROR', stack.toString());
  }

  static void _log(String level, String message) {
    final inst = _instance;
    if (inst == null || !inst._initialized) {
      final line = formatLogLine(inst?._now() ?? DateTime.now(), level, message);
      _earlyBuffer.add(line);
      if (_earlyBuffer.length > _maxEarlyLines) _earlyBuffer.removeAt(0);
      return;
    }
    inst._write(level, message);
  }

  void _write(String level, String message) {
    final line = formatLogLine(_now(), level, message);
    _remember(line);
    _pending.add(line);
    _flushTimer ??= Timer(_flushDelay, () => unawaited(_flush()));
  }

  /// 环形写入：缓冲满后覆盖最旧一行，长期对局每条日志都是 O(1)。
  void _remember(String line) {
    if (_buffer.length < _maxBufferLines) return _buffer.add(line);
    _buffer[_bufferStart] = line;
    _bufferStart = (_bufferStart + 1) % _maxBufferLines;
  }

  Future<void> _flush() async {
    _flushTimer?.cancel();
    _flushTimer = null;
    if (_flushing || _pending.isEmpty) return;
    _flushing = true;
    final batch = _pending.join('\n');
    _pending.clear();
    try {
      final file = await _fileForToday();
      if (file != null) {
        await file.writeAsString('$batch\n', mode: FileMode.append);
        _fileBytes += batch.length + 1;
        writeBatches++;
      }
    } catch (_) {
      // 磁盘不可写时丢弃这一批，内存日志仍可在设置页查看。
    } finally {
      _flushing = false;
      if (_pending.isNotEmpty) {
        _flushTimer ??= Timer(_flushDelay, () => unawaited(_flush()));
      }
    }
  }

  /// 取今天的日志文件：跨天换文件，超过 5 MB 先改名备份再新建。
  /// 体积由内存计数得知，不必每条日志都去问文件系统。
  Future<File?> _fileForToday() async {
    final dir = _logDir;
    if (dir == null) return null;
    final now = _now();
    final date = _logDate;
    final sameDay =
        date != null &&
        date.year == now.year &&
        date.month == now.month &&
        date.day == now.day;
    final current = _logFile;
    if (sameDay && current != null && _fileBytes < _maxFileSize) return current;
    try {
      if (sameDay && current != null) {
        final stem = current.path.substring(0, current.path.length - 4);
        var index = 1;
        while (await File('${stem}_$index.log').exists()) {
          index++;
        }
        await current.rename('${stem}_$index.log');
      }
      final file = File(
        '${dir.path}${Platform.pathSeparator}app_${formatDateKey(now)}.log',
      );
      if (!await file.exists()) await file.create(recursive: true);
      _fileBytes = await file.length();
      _logFile = file;
      _logDate = now;
      if (!sameDay) _cleanOldLogs();
      return file;
    } catch (_) {
      return current;
    }
  }

  void _cleanOldLogs() {
    final dir = _logDir;
    if (dir == null) return;
    try {
      final cutoff = _now().subtract(const Duration(days: _maxRetentionDays));
      for (final entity in dir.listSync()) {
        if (entity is! File) continue;
        final name = entity.uri.pathSegments.last;
        if (!name.startsWith('app_') || !name.endsWith('.log')) continue;
        try {
          if (entity.statSync().modified.isBefore(cutoff)) entity.deleteSync();
        } catch (_) {}
      }
    } catch (_) {}
  }

  /// 最近日志（内存缓冲，含尚未落盘的早期日志）。
  static List<String> getRecentLogs([int lines = 200]) {
    final inst = _instance;
    final all = <String>[..._earlyBuffer, ...?inst?._orderedBuffer];
    if (all.length <= lines) return all;
    return all.sublist(all.length - lines);
  }

  List<String> get _orderedBuffer => _buffer.length < _maxBufferLines
      ? _buffer
      : [..._buffer.skip(_bufferStart), ..._buffer.take(_bufferStart)];
}
