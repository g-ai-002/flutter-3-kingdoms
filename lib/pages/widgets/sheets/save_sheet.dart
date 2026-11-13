import 'package:flutter/material.dart';

import '../../../game/game_controller.dart';
import '../../../game/save_codec.dart';
import '../../../models/game_state.dart';
import '../../../services/save_service.dart';
import '../../../utils/formatters.dart';
import '../common.dart';

/// 对局内存档面板：三个手动槽位，可覆盖写入或删除。
Future<void> showSaveSheet(
  BuildContext context,
  GameController controller,
) => showModalBottomSheet<void>(
  context: context,
  showDragHandle: true,
  builder: (_) => _SaveSheet(controller: controller),
);

class _SaveSheet extends StatefulWidget {
  const _SaveSheet({required this.controller});

  final GameController controller;

  @override
  State<_SaveSheet> createState() => _SaveSheetState();
}

class _SaveSheetState extends State<_SaveSheet> {
  List<SaveSummary?> _slots = List.filled(SaveService.slots, null);

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final slots = await SaveService.slotSummaries();
    if (mounted) setState(() => _slots = slots);
  }

  Future<void> _save(int index) async {
    final key = SaveService.slotKey(index + 1);
    final ok = await SaveService.writeState(key, widget.controller.game);
    await _load();
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(ok ? '已存入槽位 ${index + 1}' : '存档写入失败')),
    );
  }

  Future<void> _delete(int index) async {
    await SaveService.delete(SaveService.slotKey(index + 1));
    await _load();
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final game = widget.controller.game;
    return SheetFrame(
      title: '存档',
      subtitle: '自动存档会在结束本月、战斗结束与退到后台时写入',
      trailing: InfoChip(
        text: formatYearMonth(game.year, game.month),
        dense: true,
        color: colors.primary,
      ),
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 14),
      child: Padding(
        padding: const EdgeInsets.only(top: 10),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            for (var i = 0; i < SaveService.slots; i++) ...[
              _SlotRow(
                title: '槽位 ${i + 1}',
                summary: _slots[i],
                actionLabel: '存入',
                onAction: () => _save(i),
                onDelete: _slots[i] == null ? null : () => _delete(i),
              ),
              if (i != SaveService.slots - 1) const SizedBox(height: 8),
            ],
          ],
        ),
      ),
    );
  }
}

/// 首页读档面板：自动存档与三个手动槽位，点选后返回解出的对局。
Future<GameState?> showLoadSheet(BuildContext context) =>
    showModalBottomSheet<GameState?>(
      context: context,
      showDragHandle: true,
      builder: (_) => const _LoadSheet(),
    );

class _LoadSheet extends StatefulWidget {
  const _LoadSheet();

  @override
  State<_LoadSheet> createState() => _LoadSheetState();
}

class _LoadSheetState extends State<_LoadSheet> {
  List<SaveSummary?>? _summaries;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final slots = await SaveService.slotSummaries();
    final auto = await SaveService.autoSummary();
    if (!mounted) return;
    setState(() => _summaries = [auto, ...slots]);
  }

  Future<void> _open(int index) async {
    if (_busy) return;
    final summaries = _summaries;
    if (summaries == null || summaries[index] == null) return;
    setState(() => _busy = true);
    final key = index == 0 ? SaveService.autoKey : SaveService.slotKey(index);
    final state = await SaveService.loadState(key);
    if (!mounted) return;
    if (state == null) {
      setState(() => _busy = false);
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('存档读取失败')));
      return;
    }
    Navigator.of(context).pop(state);
  }

  @override
  Widget build(BuildContext context) {
    final summaries = _summaries;
    return SheetFrame(
      title: '读取存档',
      subtitle: '自动存档会随对局推进更新；手动槽位在局内存档',
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 14),
      child: Padding(
        padding: const EdgeInsets.only(top: 10),
        child: summaries == null
            ? const Padding(
                padding: EdgeInsets.symmetric(vertical: 24),
                child: Center(child: CircularProgressIndicator()),
              )
            : Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  for (var i = 0; i < summaries.length; i++) ...[
                    _SlotRow(
                      title: i == 0 ? '自动存档' : '槽位 $i',
                      summary: summaries[i],
                      actionLabel: '读取',
                      enabled: !_busy,
                      onAction: () => _open(i),
                    ),
                    if (i != summaries.length - 1) const SizedBox(height: 8),
                  ],
                ],
              ),
      ),
    );
  }
}

class _SlotRow extends StatelessWidget {
  const _SlotRow({
    required this.title,
    required this.summary,
    required this.actionLabel,
    required this.onAction,
    this.enabled = true,
    this.onDelete,
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
    return Container(
      padding: const EdgeInsets.fromLTRB(12, 8, 8, 8),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: colors.outline),
        color: empty
            ? colors.surface
            : colors.primaryContainer.withValues(alpha: 0.3),
      ),
      child: Row(
        children: [
          Icon(
            empty ? Icons.crop_square_rounded : Icons.save_outlined,
            size: 18,
            color: empty ? colors.onSurfaceVariant : colors.primary,
          ),
          const SizedBox(width: 9),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: theme.textTheme.titleSmall?.copyWith(fontSize: 13),
                ),
                Text(
                  summary?.label ?? '空槽位',
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: colors.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
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
    );
  }
}
