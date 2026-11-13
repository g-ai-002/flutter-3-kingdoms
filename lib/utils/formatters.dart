/// 全局时间与数字格式化工具。
library;

String pad2(int value) => value.toString().padLeft(2, '0');

/// `yyyyMMdd`，用于日志文件名。
String formatDateKey(DateTime date) =>
    '${date.year.toString().padLeft(4, '0')}${pad2(date.month)}${pad2(date.day)}';

/// `yyyy-MM-dd HH:mm`，设置页展示导出时间等场景共用。
String formatDateTime(DateTime time) =>
    '${time.year.toString().padLeft(4, '0')}-${pad2(time.month)}-${pad2(time.day)} '
    '${pad2(time.hour)}:${pad2(time.minute)}';

/// `HH:mm:ss.SSS`，日志行首时间戳。
String formatLogTimestamp(DateTime time) =>
    '${pad2(time.hour)}:${pad2(time.minute)}:${pad2(time.second)}.'
    '${time.millisecond.toString().padLeft(3, '0')}';

String formatLogLine(DateTime time, String level, String message) =>
    '[${formatLogTimestamp(time)}][$level] $message';

/// 兵力显示：一万以上用「万」，保留一位小数。
String formatTroops(int troops) {
  if (troops >= 10000) return '${(troops / 10000).toStringAsFixed(1)}万';
  return '$troops';
}

/// 资源显示：大数字加千分位。
String formatAmount(int value) {
  final text = value.abs().toString();
  final buffer = StringBuffer(value < 0 ? '-' : '');
  for (var i = 0; i < text.length; i++) {
    if (i > 0 && (text.length - i) % 3 == 0) buffer.write(',');
    buffer.write(text[i]);
  }
  return buffer.toString();
}

/// 农历月序：正月、二月……冬月、腊月。
const List<String> kMonthNames = [
  '正月',
  '二月',
  '三月',
  '四月',
  '五月',
  '六月',
  '七月',
  '八月',
  '九月',
  '十月',
  '冬月',
  '腊月',
];

String formatYearMonth(int year, int month) =>
    '$year年 ${kMonthNames[(month - 1) % 12]}';
