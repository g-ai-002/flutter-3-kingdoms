/// 界面共用的中文书法字体回退链：优先楷体，其次各平台常见的中文字体。
const List<String> kKaiFontFallback = [
  'STKaiti',
  'KaiTi',
  'Microsoft YaHei UI',
  'SimSun',
  'Noto Serif CJK SC',
  'Noto Sans CJK SC',
];

/// Web 端字体：CanvasKit 没有系统中文字体回退，使用 soup_fonts 的思源黑体。
const String kWebFontFamily = 'SourceHanSansCN';

class AppConstants {
  AppConstants._();

  static const String appName = '三国霸业';
  static const String version = '0.2.2';

  /// 开局年份：建安元年（196 年）。
  static const int startYear = 196;

  static const String prefKeyDarkMode = 'dark_mode';
  static const String prefKeySound = 'sound_enabled';
  static const String prefKeyMusic = 'music_enabled';
  static const String prefKeyHaptics = 'haptics_enabled';
  static const String prefKeyLogicRate = 'logic_rate';
  static const String prefKeyDifficulty = 'difficulty';
  static const String prefKeyPlayerFaction = 'player_faction';
}
