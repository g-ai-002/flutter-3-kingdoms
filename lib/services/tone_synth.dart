import 'dart:math' as math;
import 'dart:typed_data';

import 'audio_task.dart';

/// 音效采样率：短促提示音用 22.05 kHz 足够，数据量约为 44.1 kHz 的一半。
const int kSynthSampleRate = 22050;

/// 单枚乐音：正弦基频叠加二、三次谐波，可混入噪声模拟鼓皮与木质敲击。
class SynthNote {
  const SynthNote({
    required this.frequency,
    required this.start,
    required this.duration,
    this.gain = 0.5,
    this.noise = 0,
  });

  final double frequency;
  final double start;
  final double duration;
  final double gain;
  final double noise;
}

/// 把若干乐音渲染成 16 位单声道 WAV 字节。
Uint8List synthesizeWav(
  List<SynthNote> notes, {
  int sampleRate = kSynthSampleRate,
}) {
  const tailSeconds = 0.05;
  final seconds = notes.fold<double>(
    0,
    (longest, note) => math.max(longest, note.start + note.duration),
  );
  final totalSamples = ((seconds + tailSeconds) * sampleRate).round();
  final mix = Float64List(totalSamples);
  final random = math.Random(20261114);

  for (final note in notes) {
    final offset = (note.start * sampleRate).round();
    final count = (note.duration * sampleRate).round();
    final attack = math.max(1, (0.003 * sampleRate).round());
    final release = math.max(1, (0.006 * sampleRate).round());
    final gain = note.gain / 1.44;
    for (var i = 0; i < count; i++) {
      final index = offset + i;
      if (index >= totalSamples) break;
      final progress = i / count;
      final envelope =
          math.min(1, i / attack) *
          math.min(1, (count - i) / release) *
          math.exp(-3.2 * progress);
      final phase = 2 * math.pi * note.frequency * (i / sampleRate);
      final tone =
          math.sin(phase) +
          0.32 * math.sin(2 * phase) +
          0.12 * math.sin(3 * phase);
      final hit = note.noise * (random.nextDouble() * 2 - 1);
      mix[index] += envelope * (tone * gain + hit);
    }
  }

  return _encodePcm(mix, sampleRate);
}

/// 后台合成单段提示音；启动与首次点击时不再占用界面线程。
Future<Uint8List> synthesizeWavAsync(
  List<SynthNote> notes, {
  int sampleRate = kSynthSampleRate,
}) => runAudioTask(() => synthesizeWav(notes, sampleRate: sampleRate));

/// 一次在后台合成多段提示音，省去反复创建 isolate 的开销。
Future<List<Uint8List>> synthesizeWavBatchAsync(
  List<List<SynthNote>> batches, {
  int sampleRate = kSynthSampleRate,
}) => runAudioTask(
  () => [
    for (final notes in batches) synthesizeWav(notes, sampleRate: sampleRate),
  ],
);

/// 背景音乐采样率与循环长度：古筝拨弦，20 秒一循环。
const int kMusicSampleRate = 16000;
const double kMusicLoopSeconds = 20;

class _PluckNote {
  const _PluckNote({
    required this.start,
    required this.frequency,
    required this.duration,
    this.gain = 0.4,
    this.damp = 1.2,
  });

  final double start;
  final double frequency;
  final double duration;
  final double gain;
  final double damp;
}

/// D 羽五声音阶（D F G A C）的苍凉旋律，低音持续铺底。
const List<_PluckNote> _musicNotes = [
  _PluckNote(start: 0, frequency: 73.42, duration: 9.6, gain: 0.28, damp: 0.5),
  _PluckNote(
    start: 9.6,
    frequency: 73.42,
    duration: 10.2,
    gain: 0.26,
    damp: 0.5,
  ),
  _PluckNote(
    start: 0.8,
    frequency: 293.66,
    duration: 1.4,
    gain: 0.42,
    damp: 1.0,
  ),
  _PluckNote(start: 1.8, frequency: 349.23, duration: 1.2, gain: 0.4),
  _PluckNote(start: 2.6, frequency: 392.00, duration: 1.6, gain: 0.44),
  _PluckNote(start: 3.8, frequency: 349.23, duration: 1.2, gain: 0.36),
  _PluckNote(start: 4.6, frequency: 293.66, duration: 1.8, gain: 0.4),
  _PluckNote(start: 6.2, frequency: 261.63, duration: 1.4, gain: 0.36),
  _PluckNote(start: 7.2, frequency: 293.66, duration: 2.2, gain: 0.34),
  _PluckNote(start: 9.4, frequency: 293.66, duration: 1.2, gain: 0.4),
  _PluckNote(start: 10.2, frequency: 392.00, duration: 1.2, gain: 0.42),
  _PluckNote(start: 11.0, frequency: 440.00, duration: 1.6, gain: 0.44),
  _PluckNote(start: 12.2, frequency: 392.00, duration: 1.2, gain: 0.36),
  _PluckNote(start: 13.0, frequency: 349.23, duration: 1.8, gain: 0.4),
  _PluckNote(start: 14.6, frequency: 293.66, duration: 1.4, gain: 0.34),
  _PluckNote(start: 15.6, frequency: 261.63, duration: 2.6, gain: 0.32),
  _PluckNote(start: 0.0, frequency: 587.33, duration: 0.9, gain: 0.26),
  _PluckNote(start: 5.4, frequency: 523.25, duration: 0.8, gain: 0.24),
  _PluckNote(start: 10.6, frequency: 698.46, duration: 0.9, gain: 0.26),
  _PluckNote(start: 16.4, frequency: 587.33, duration: 0.8, gain: 0.24),
  _PluckNote(start: 18.2, frequency: 440.00, duration: 1.2, gain: 0.3),
];

/// 合成背景音乐：古筝质感的拨弦叠加低音，首尾淡入淡出后无缝循环。
Uint8List synthesizeMusicWav({int sampleRate = kMusicSampleRate}) {
  final totalSamples = (kMusicLoopSeconds * sampleRate).round();
  final mix = Float64List(totalSamples);
  final random = math.Random(20261115);
  for (final note in _musicNotes) {
    final offset = (note.start * sampleRate).round();
    final count = math.min(
      (note.duration * sampleRate).round(),
      totalSamples - offset,
    );
    final attack = math.max(1, (0.004 * sampleRate).round());
    for (var i = 0; i < count; i++) {
      final time = i / sampleRate;
      final envelope = math.min(1, i / attack) * math.exp(-note.damp * time);
      final phase = 2 * math.pi * note.frequency * time;
      final tone =
          math.sin(phase) +
          0.34 * math.sin(2.002 * phase) +
          0.14 * math.sin(3.006 * phase) +
          0.05 * math.sin(4.011 * phase);
      final pick = (random.nextDouble() * 2 - 1) * 0.16 * math.exp(-70 * time);
      mix[offset + i] += envelope * note.gain * (tone * 0.42 + pick);
    }
  }

  var peak = 0.0;
  for (final value in mix) {
    final magnitude = value.abs();
    if (magnitude > peak) peak = magnitude;
  }
  final scale = peak > 0 ? 0.78 / peak : 1.0;
  final edge = (0.03 * sampleRate).round();
  for (var i = 0; i < totalSamples; i++) {
    final fadeIn = i < edge ? i / edge : 1.0;
    final fadeOut = i >= totalSamples - edge ? (totalSamples - i) / edge : 1.0;
    mix[i] *= scale * fadeIn * fadeOut;
  }
  return _encodePcm(mix, sampleRate);
}

/// 后台合成背景音乐，避免启动后第一帧被二十秒的循环渲染拖慢。
Future<Uint8List> synthesizeMusicWavAsync({
  int sampleRate = kMusicSampleRate,
}) => runAudioTask(() => synthesizeMusicWav(sampleRate: sampleRate));

/// 把 [-1,1] 的浮点混音编码为 16 位单声道 WAV。
Uint8List _encodePcm(Float64List mix, int sampleRate) {
  final totalSamples = mix.length;
  final data = ByteData(44 + totalSamples * 2);
  _writeAscii(data, 0, 'RIFF');
  data.setUint32(4, 36 + totalSamples * 2, Endian.little);
  _writeAscii(data, 8, 'WAVE');
  _writeAscii(data, 12, 'fmt ');
  data.setUint32(16, 16, Endian.little);
  data.setUint16(20, 1, Endian.little);
  data.setUint16(22, 1, Endian.little);
  data.setUint32(24, sampleRate, Endian.little);
  data.setUint32(28, sampleRate * 2, Endian.little);
  data.setUint16(32, 2, Endian.little);
  data.setUint16(34, 16, Endian.little);
  _writeAscii(data, 36, 'data');
  data.setUint32(40, totalSamples * 2, Endian.little);

  for (var i = 0; i < totalSamples; i++) {
    final sample = (mix[i].clamp(-1.0, 1.0) * 32767).round();
    data.setInt16(44 + i * 2, sample, Endian.little);
  }
  return data.buffer.asUint8List();
}

void _writeAscii(ByteData data, int offset, String text) {
  for (var i = 0; i < text.length; i++) {
    data.setUint8(offset + i, text.codeUnitAt(i));
  }
}
