import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('lib 目录代码行数保持在 10000 行以内', () {
    final files = Directory('lib')
        .listSync(recursive: true)
        .whereType<File>()
        .where((file) => file.path.endsWith('.dart'));
    var lines = 0;
    for (final file in files) {
      lines += file.readAsLinesSync().length;
    }
    expect(
      lines,
      lessThan(10000),
      reason: '当前 $lines 行，新增功能前需先删减低优先级代码',
    );
  });
}
