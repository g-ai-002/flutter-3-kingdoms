import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_soloud/flutter_soloud.dart';

import 'log_service.dart';
import 'tone_synth.dart';

/// 游戏内的提示音类型。
enum GameSound { tap, order, recruit, battle, victory, defeat, turn }

/// 音效与触感反馈。
///
/// 音效由 [synthesizeWav] 在运行时合成，不随包携带音频文件；合成好的 WAV
/// 交给 flutter_soloud 的内存音源播放，Android、Windows 与 Web 共用一套实现。
class SoundService {
  SoundService._();

  static bool soundEnabled = true;
  static bool hapticsEnabled = true;

  /// 测试注入的音频出口，非空时不再触碰平台播放器。
  @visibleForTesting
  static void Function(GameSound sound)? sink;

  static final Map<GameSound, AudioSource> _sources = {};
  static final Map<GameSound, Uint8List> _clips = {};
  static Future<void>? _loading;
  static bool _loadFailed = false;

  /// 战鼓、号角与木鱼质感的提示音配方。
  static const Map<GameSound, List<SynthNote>> _presets = {
    GameSound.tap: [
      SynthNote(frequency: 1240, start: 0, duration: 0.045, gain: 0.45, noise: 0.1),
      SynthNote(frequency: 820, start: 0.004, duration: 0.07, gain: 0.3),
    ],
    GameSound.order: [
      SynthNote(frequency: 523.25, start: 0, duration: 0.09, gain: 0.5),
      SynthNote(frequency: 783.99, start: 0.08, duration: 0.16, gain: 0.45),
    ],
    GameSound.recruit: [
      SynthNote(frequency: 523.25, start: 0, duration: 0.12, gain: 0.45),
      SynthNote(frequency: 659.25, start: 0.1, duration: 0.12, gain: 0.45),
      SynthNote(frequency: 783.99, start: 0.2, duration: 0.24, gain: 0.5),
    ],
    GameSound.battle: [
      SynthNote(frequency: 92, start: 0, duration: 0.22, gain: 0.8, noise: 0.45),
      SynthNote(frequency: 138, start: 0.02, duration: 0.18, gain: 0.55, noise: 0.3),
      SynthNote(frequency: 330, start: 0.16, duration: 0.4, gain: 0.35, noise: 0.6),
      SynthNote(frequency: 110, start: 0.34, duration: 0.24, gain: 0.6, noise: 0.4),
    ],
    GameSound.victory: [
      SynthNote(frequency: 523.25, start: 0, duration: 0.16, gain: 0.5),
      SynthNote(frequency: 659.25, start: 0.14, duration: 0.16, gain: 0.5),
      SynthNote(frequency: 783.99, start: 0.28, duration: 0.18, gain: 0.5),
      SynthNote(frequency: 1046.50, start: 0.44, duration: 0.5, gain: 0.55),
    ],
    GameSound.defeat: [
      SynthNote(frequency: 392.00, start: 0, duration: 0.24, gain: 0.5),
      SynthNote(frequency: 329.63, start: 0.2, duration: 0.26, gain: 0.5),
      SynthNote(frequency: 261.63, start: 0.42, duration: 0.55, gain: 0.55),
    ],
    GameSound.turn: [
      SynthNote(frequency: 440, start: 0, duration: 0.09, gain: 0.4),
      SynthNote(frequency: 587.33, start: 0.09, duration: 0.18, gain: 0.4),
    ],
  };

  static void configure({required bool sound, required bool haptics}) {
    soundEnabled = sound;
    hapticsEnabled = haptics;
  }

  /// 预合成音效并载入 SoLoud 音源；失败时保持静默，不影响对局。
  static Future<void> init() => _ensureLoaded();

  static Future<void> _ensureLoaded() {
    if (_loadFailed || _sources.isNotEmpty) return Future.value();
    return _loading ??= _load();
  }

  static Future<void> _load() async {
    try {
      final soloud = SoLoud.instance;
      if (!soloud.isInitialized) await soloud.init();
      for (final sound in GameSound.values) {
        _sources[sound] = await soloud.loadMem(
          'sanguo-${sound.name}.wav',
          clipOf(sound),
        );
      }
    } catch (error) {
      _loadFailed = true;
      _disposeAll();
      debugPrint('[SoundService] 音效初始化失败，已静音: $error');
      LogService.warning('音效初始化失败，已静音: $error');
    }
  }

  /// 某个提示音对应的合成音频，供测试校验音效配方。
  @visibleForTesting
  static Uint8List clipOf(GameSound sound) =>
      _clips.putIfAbsent(sound, () => synthesizeWav(_presets[sound]!));

  /// 轻触反馈：只走触感，不播放提示音。
  static void tap() {
    if (hapticsEnabled) HapticFeedback.selectionClick();
  }

  static void play(GameSound sound) {
    if (soundEnabled) {
      final target = sink;
      if (target != null) {
        target(sound);
      } else {
        unawaited(_play(sound));
      }
    }
    if (!hapticsEnabled) return;
    final haptic = switch (sound) {
      GameSound.tap => HapticFeedback.selectionClick,
      GameSound.order => HapticFeedback.lightImpact,
      GameSound.recruit => HapticFeedback.mediumImpact,
      GameSound.battle => HapticFeedback.heavyImpact,
      GameSound.victory => HapticFeedback.vibrate,
      GameSound.defeat => HapticFeedback.heavyImpact,
      GameSound.turn => HapticFeedback.selectionClick,
    };
    haptic();
  }

  static Future<void> _play(GameSound sound) async {
    try {
      await _ensureLoaded();
      final source = _sources[sound];
      if (source == null) return;
      final soloud = SoLoud.instance;
      soloud.stopAudioSource(source);
      soloud.play(source);
    } catch (error) {
      debugPrint('[SoundService] 播放失败: $error');
    }
  }

  static void _disposeAll() {
    final sources = _sources.values.toList();
    _sources.clear();
    for (final source in sources) {
      unawaited(_dispose(source));
    }
  }

  static Future<void> _dispose(AudioSource source) async {
    try {
      await SoLoud.instance.disposeSource(source);
    } catch (_) {
      // 音源已失效时无需再处理。
    }
  }

  @visibleForTesting
  static void reset() {
    sink = null;
    _disposeAll();
    _clips.clear();
    _loading = null;
    _loadFailed = false;
    soundEnabled = true;
    hapticsEnabled = true;
  }
}
