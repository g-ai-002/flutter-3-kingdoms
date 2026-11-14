import 'package:shared_preferences/shared_preferences.dart';

import '../game/save_codec.dart';
import '../models/game_state.dart';
import 'log_service.dart';

/// 存档读写：自动存档与三个手动槽位，全部存于 SharedPreferences，
/// Android / Windows / Web 共用同一套实现。
class SaveService {
  SaveService._();

  static const int slots = 3;
  static const String autoKey = 'save_auto';

  static String slotKey(int slot) => 'save_slot_$slot';

  static Future<SharedPreferences> _prefs() => SharedPreferences.getInstance();

  static Future<bool> write(String key, String data) async {
    try {
      final prefs = await _prefs();
      return await prefs.setString(key, data);
    } catch (e, stack) {
      LogService.error('写入存档失败: $key', e, stack);
      return false;
    }
  }

  static Future<bool> writeState(String key, GameState state) async {
    final data = SaveCodec.encode(state);
    LogService.info('保存存档: $key (${data.length} 字节)');
    return write(key, data);
  }

  static Future<String?> read(String key) async {
    try {
      final prefs = await _prefs();
      return prefs.getString(key);
    } catch (e, stack) {
      LogService.error('读取存档失败: $key', e, stack);
      return null;
    }
  }

  static Future<void> delete(String key) async {
    try {
      final prefs = await _prefs();
      await prefs.remove(key);
    } catch (e, stack) {
      LogService.error('删除存档失败: $key', e, stack);
    }
  }

  /// 读取存档摘要；缺失或损坏时返回 null，不抛出。
  static Future<SaveSummary?> summaryOf(String key) async {
    final data = await read(key);
    if (data == null) return null;
    try {
      return SaveCodec.summary(data);
    } catch (e, stack) {
      LogService.error('存档摘要解析失败: $key', e, stack);
      return null;
    }
  }

  static Future<SaveSummary?> autoSummary() => summaryOf(autoKey);

  /// 三个手动槽位一次并发读取，避免逐个等待平台存储往返。
  static Future<List<SaveSummary?>> slotSummaries() => Future.wait([
    for (var slot = 1; slot <= slots; slot++) summaryOf(slotKey(slot)),
  ]);

  /// 读取并解出完整对局；存档损坏时返回 null。
  static Future<GameState?> loadState(String key) async {
    final data = await read(key);
    if (data == null) return null;
    try {
      return SaveCodec.decode(data);
    } catch (e, stack) {
      LogService.error('读取存档内容失败: $key', e, stack);
      return null;
    }
  }
}
