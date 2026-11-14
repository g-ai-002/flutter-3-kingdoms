import 'package:material_ui/material_ui.dart';

import '../../../game/game_controller.dart';
import '../../../game/save_codec.dart';
import '../../../models/game_state.dart';
import '../../../services/save_service.dart';
import '../../../utils/formatters.dart';
import '../common.dart';

/// 对局内存档面板：三个手动槽位，可覆盖写入或删除。
Future<void> showSaveSheet(BuildContext context, GameController controller) =>
    showGameSheet<GameState?>(
      context,
      builder: (_) => _SavesSheet(controller: controller),
    );

/// 首页读档面板：自动存档与三个手动槽位，点选后返回解出的对局。
Future<GameState?> showLoadSheet(BuildContext context) =>
    showGameSheet<GameState?>(context, builder: (_) => const _SavesSheet());

/// 存读档共用一套槽位列表：写入模式列出三个手动槽位，
/// 读取模式在前面多一项自动存档，其余加载与空槽表现一致。
class _SavesSheet extends StatefulWidget {
  const _SavesSheet({this.controller});

  final GameController? controller;

  @override
  State<_SavesSheet> createState() => _SavesSheetState();
}

class _SavesSheetState extends State<_SavesSheet> {
  List<SaveSummary?>? _slots;
  bool _busy = false;

  bool get _writing => widget.controller != null;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final slots = await SaveService.slotSummaries();
    final auto = _writing ? null : await SaveService.autoSummary();
    if (!mounted) return;
    setState(() => _slots = _writing ? slots : [auto, ...slots]);
  }

  Future<void> _save(int index) async {
    final ok = await SaveService.writeState(
      SaveService.slotKey(index + 1),
      widget.controller!.game,
    );
    await _load();
    if (!mounted) return;
    showToast(context, ok ? '已存入槽位 ${index + 1}' : '存档写入失败');
  }

  Future<void> _delete(int index) async {
    await SaveService.delete(SaveService.slotKey(index + 1));
    await _load();
  }

  Future<void> _open(int index) async {
    if (_busy) return;
    setState(() => _busy = true);
    final key = index == 0 ? SaveService.autoKey : SaveService.slotKey(index);
    final state = await SaveService.loadState(key);
    if (!mounted) return;
    if (state == null) {
      setState(() => _busy = false);
      showToast(context, '存档读取失败');
      return;
    }
    Navigator.of(context).pop(state);
  }

  String _titleOf(int index) {
    if (_writing) return '槽位 ${index + 1}';
    return index == 0 ? '自动存档' : '槽位 $index';
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final slots = _slots;
    final game = widget.controller?.game;
    return SheetFrame(
      title: _writing ? '存档' : '读取存档',
      subtitle: _writing ? '自动存档会在结束本月、战斗结束与退到后台时写入' : '自动存档会随对局推进更新；手动槽位在局内存档',
      trailing: game == null
          ? null
          : InfoChip(
              text: formatYearMonth(game.year, game.month),
              dense: true,
              color: colors.primary,
            ),
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 14),
      gap: 10,
      child: slots == null
          ? const Padding(
              padding: EdgeInsets.symmetric(vertical: 24),
              child: Center(child: CircularProgressIndicator()),
            )
          : Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                for (var i = 0; i < slots.length; i++) ...[
                  _SlotRow(
                    title: _titleOf(i),
                    summary: slots[i],
                    actionLabel: _writing ? '存入' : '读取',
                    enabled: !_busy,
                    onAction: () => _writing ? _save(i) : _open(i),
                    onDelete: _writing && slots[i] != null
                        ? () => _delete(i)
                        : null,
                  ),
                  if (i != slots.length - 1) const SizedBox(height: 8),
                ],
              ],
            ),
    );
  }
}

class _SlotRow extends StatelessWidget {
  const _SlotRow({
    required this.title, required this.summary, required this.actionLabel,
    required this.onAction, this.enabled = true, this.onDelete,
  });

  final String title;
  final SaveSummary? summary;
  final String actionLabel;
  final VoidCallback onAction;
  final bool enabled;
  final VoidCallback? onDelete;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final empty = summary == null;
    return Material(
      color: empty
          ? colors.surface
          : colors.primaryContainer.withValues(alpha: 0.3),
      shape: outlinedShape(context),
      child: ListTile(
        dense: true,
        onTap: enabled ? onAction : null,
        leading: Icon(
          empty ? Icons.crop_square_rounded : Icons.save_outlined,
          size: 18,
          color: empty ? colors.onSurfaceVariant : colors.primary,
        ),
        title: Text(
          title,
          style: theme.textTheme.titleSmall?.copyWith(fontSize: 13),
        ),
        subtitle: Text(summary?.label ?? '空槽位', style: hintStyle(context)),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (onDelete != null)
              IconButton(
                tooltip: '删除存档',
                onPressed: onDelete,
                icon: const Icon(Icons.delete_outline, size: 18),
                visualDensity: VisualDensity.compact,
              ),
            TextButton(
              onPressed: enabled ? onAction : null,
              child: Text(actionLabel),
            ),
          ],
        ),
      ),
    );
  }
}
