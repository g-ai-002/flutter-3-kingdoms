import 'package:shared_preferences/shared_preferences.dart';

import '../models/difficulty.dart';
import '../utils/constants.dart';
import '../utils/logic_rate.dart';

/// 轻量偏好存储：写入失败时静默忽略，不影响对局主流程。
class StorageService {
  static StorageService? _instance;
  SharedPreferences? _prefs;

  StorageService._();

  static Future<StorageService> get instance async {
    if (_instance != null) return _instance!;
    final service = StorageService._();
    service._prefs = await SharedPreferences.getInstance();
    _instance = service;
    return service;
  }

  /// 仅供测试：清空单例，配合 SharedPreferences 的 mock 数据使用。
  static void resetForTests() => _instance = null;

  SharedPreferences get _p {
    final prefs = _prefs;
    if (prefs == null) throw StateError('StorageService 尚未初始化');
    return prefs;
  }

  Future<void> _write(Future<bool> Function(SharedPreferences prefs) action) async {
    try {
      await action(_p);
    } catch (_) {}
  }

  bool get darkMode => _p.getBool(AppConstants.prefKeyDarkMode) ?? false;
  Future<void> setDarkMode(bool value) =>
      _write((p) => p.setBool(AppConstants.prefKeyDarkMode, value));

  bool get soundEnabled => _p.getBool(AppConstants.prefKeySound) ?? true;
  Future<void> setSoundEnabled(bool value) =>
      _write((p) => p.setBool(AppConstants.prefKeySound, value));

  bool get musicEnabled => _p.getBool(AppConstants.prefKeyMusic) ?? true;
  Future<void> setMusicEnabled(bool value) =>
      _write((p) => p.setBool(AppConstants.prefKeyMusic, value));

  bool get hapticsEnabled => _p.getBool(AppConstants.prefKeyHaptics) ?? true;
  Future<void> setHapticsEnabled(bool value) =>
      _write((p) => p.setBool(AppConstants.prefKeyHaptics, value));

  /// 地图逻辑更新速率，未设置或未知值回退到 60Hz。
  LogicRate get logicRate =>
      LogicRate.byName(_p.getString(AppConstants.prefKeyLogicRate));
  Future<void> setLogicRate(LogicRate value) =>
      _write((p) => p.setString(AppConstants.prefKeyLogicRate, value.name));

  /// 默认难度，未设置或未知值回退到「争雄」。
  Difficulty get difficulty =>
      Difficulty.byName(_p.getString(AppConstants.prefKeyDifficulty));
  Future<void> setDifficulty(Difficulty value) =>
      _write((p) => p.setString(AppConstants.prefKeyDifficulty, value.name));

  /// 上次选择的势力，未设置时回退到魏。
  String get playerFactionId =>
      _p.getString(AppConstants.prefKeyPlayerFaction) ?? 'wei';
  Future<void> setPlayerFactionId(String value) =>
      _write((p) => p.setString(AppConstants.prefKeyPlayerFaction, value));

  /// 上次选择的剧本，未设置时由剧本表回退到默认剧本。
  String get scenarioId => _p.getString(AppConstants.prefKeyScenario) ?? '';
  Future<void> setScenarioId(String value) =>
      _write((p) => p.setString(AppConstants.prefKeyScenario, value));

  /// 自定义开局的钱粮倍率，未设置时为 1。
  double get startGoldRatio =>
      _p.getDouble(AppConstants.prefKeyStartGold) ?? 1;
  Future<void> setStartGoldRatio(double value) =>
      _write((p) => p.setDouble(AppConstants.prefKeyStartGold, value));
}
