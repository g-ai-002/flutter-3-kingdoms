import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// 收集 pubspec.yaml 中直接声明的依赖版本；SDK 依赖没有版本行，不在结果里。
Map<String, String> _directDependencies() {
  final declared = <String, String>{};
  var inDependencies = false;
  for (final line in File('pubspec.yaml').readAsLinesSync()) {
    final trimmed = line.trim();
    if (trimmed.isEmpty || trimmed.startsWith('#')) continue;
    if (!line.startsWith(' ')) {
      inDependencies =
          trimmed == 'dependencies:' || trimmed == 'dev_dependencies:';
      continue;
    }
    if (!inDependencies) continue;
    final match = RegExp(r'^ {2}([a-z0-9_]+):\s*(\S.*)$').firstMatch(line);
    if (match != null) declared[match.group(1)!] = match.group(2)!.trim();
  }
  return declared;
}

void main() {
  test('直接依赖一律使用固定版本号', () {
    final declared = _directDependencies();
    expect(declared, isNotEmpty);
    for (final entry in declared.entries) {
      expect(
        entry.value,
        matches(RegExp(r'^\d+\.\d+\.\d+(\+\d+)?$')),
        reason: '${entry.key} 必须写死版本号，不能使用 ^ 或 ~ 等范围写法',
      );
    }
  });

  test('flutter_soloud 固定为 5.3.0', () {
    expect(_directDependencies()['flutter_soloud'], '5.3.0');
  });
}
