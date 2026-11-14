import 'dart:async';

import 'package:flutter/foundation.dart';

import '../game/data/scenario.dart';
import '../models/difficulty.dart';
import '../services/music_service.dart';
import '../services/sound_service.dart';
import '../services/storage_service.dart';
import '../utils/logic_rate.dart';

/// 用户偏好：主题、音频、地图刷新率、默认难度与上次选择的势力。
class SettingsProvider extends ChangeNotifier {
  SettingsProvider(this._storage) {
    _syncFeedback();
  }

  final StorageService _storage;

  bool get darkMode => _storage.darkMode;
  Future<void> setDarkMode(bool value) =>
      _update(() => _storage.setDarkMode(value));

  bool get soundEnabled => _storage.soundEnabled;
  Future<void> setSoundEnabled(bool value) => _update(() async {
    await _storage.setSoundEnabled(value);
    _syncFeedback();
  });

  bool get musicEnabled => _storage.musicEnabled;
  Future<void> setMusicEnabled(bool value) => _update(() async {
    await _storage.setMusicEnabled(value);
    // 音频启停不阻塞开关反馈，加载失败时 MusicService 自行记录日志。
    unawaited(MusicService.setEnabled(value));
  });

  bool get hapticsEnabled => _storage.hapticsEnabled;
  Future<void> setHapticsEnabled(bool value) => _update(() async {
    await _storage.setHapticsEnabled(value);
    _syncFeedback();
  });

  LogicRate get logicRate => _storage.logicRate;
  Future<void> setLogicRate(LogicRate value) =>
      _update(() => _storage.setLogicRate(value));

  Difficulty get difficulty => _storage.difficulty;
  Future<void> setDifficulty(Difficulty value) =>
      _update(() => _storage.setDifficulty(value));

  String get playerFactionId => _storage.playerFactionId;
  Future<void> setPlayerFactionId(String value) =>
      _update(() => _storage.setPlayerFactionId(value));

  ScenarioDef get scenario => Scenario.byId(_storage.scenarioId);
  Future<void> setScenarioId(String value) =>
      _update(() => _storage.setScenarioId(value));

  StartSupply get supply => StartSupply.byRatio(_storage.startGoldRatio);
  Future<void> setSupply(StartSupply value) =>
      _update(() => _storage.setStartGoldRatio(value.ratio));

  void _syncFeedback() =>
      SoundService.configure(sound: soundEnabled, haptics: hapticsEnabled);

  Future<void> _update(Future<void> Function() write) async {
    await write();
    notifyListeners();
  }
}
