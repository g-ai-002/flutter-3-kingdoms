/// 全局时间与数字格式化工具。
library;

String pad2(int value) => value.toString().padLeft(2, '0');

/// `yyyyMMdd`，用于日志文件名。
String formatDateKey(DateTime date) =>
    '${date.year.toString().padLeft(4, '0')}${pad2(date.month)}${pad2(date.day)}';

/// `HH:mm:ss.SSS`，日志行首时间戳。
String formatLogTimestamp(DateTime time) =>
    '${pad2(time.hour)}:${pad2(time.minute)}:${pad2(time.second)}.'
    '${time.millisecond.toString().padLeft(3, '0')}';

String formatLogLine(DateTime time, String level, String message) =>
    '[${formatLogTimestamp(time)}][$level] $message';

/// 兵力简写：一万以上用「万」，一千以上用「千」，保留一位小数。
///
/// 地图徽记与列表里的兵数空间有限，统一走这一套口径。
String formatTroopsCompact(int troops) {
  if (troops >= 10000) return '${(troops / 10000).toStringAsFixed(1)}万';
  if (troops >= 1000) return '${(troops / 1000).toStringAsFixed(1)}千';
  return '$troops';
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
