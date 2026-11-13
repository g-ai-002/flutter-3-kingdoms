import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';

import 'package:flutter_3_kingdoms/services/sound_service.dart';
import 'package:flutter_3_kingdoms/services/tone_synth.dart';

String _ascii(Uint8List bytes, int offset, int length) =>
    String.fromCharCodes(bytes.sublist(offset, offset + length));

void main() {
  test('合成音效是合法的 16 位单声道 WAV', () {
    final wav = synthesizeWav(const [
      SynthNote(frequency: 880, start: 0, duration: 0.1, gain: 0.5),
      SynthNote(frequency: 440, start: 0.08, duration: 0.08, gain: 0.3),
    ]);
    expect(_ascii(wav, 0, 4), 'RIFF');
    expect(_ascii(wav, 8, 4), 'WAVE');
    expect(_ascii(wav, 12, 4), 'fmt ');
    expect(_ascii(wav, 36, 4), 'data');
    final sampleRate = ByteData.sublistView(wav).getUint32(24, Endian.little);
    expect(sampleRate, kSynthSampleRate);
    final dataLength = ByteData.sublistView(wav).getUint32(40, Endian.little);
    expect(dataLength, wav.length - 44);
    expect(dataLength.isEven, isTrue);
  });

  test('背景音乐是 20 秒的无缝循环', () {
    final wav = synthesizeMusicWav();
    expect(_ascii(wav, 0, 4), 'RIFF');
    final sampleRate = ByteData.sublistView(wav).getUint32(24, Endian.little);
    expect(sampleRate, kMusicSampleRate);
    final dataLength = ByteData.sublistView(wav).getUint32(40, Endian.little);
    expect(dataLength, (kMusicLoopSeconds * sampleRate).round() * 2);
  });

  test('七种提示音各有独立且非空的合成音频', () {
    SoundService.reset();
    final lengths = <int>{};
    for (final sound in GameSound.values) {
      final clip = SoundService.clipOf(sound);
      expect(_ascii(clip, 0, 4), 'RIFF');
      expect(clip.length, greaterThan(44));
      lengths.add(clip.length);
    }
    expect(lengths.length, greaterThanOrEqualTo(5));
    SoundService.reset();
  });
}
