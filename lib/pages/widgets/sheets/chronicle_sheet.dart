import 'package:flutter/material.dart';

import '../../../game/game_controller.dart';
import '../../../models/chronicle.dart';
import '../../../theme/app_theme.dart';
import '../common.dart';

/// 战报：按月记录的内政、战斗与随机事件。
Future<void> showChronicleSheet(
  BuildContext context,
  GameController controller,
) {
  return showGameSheet<void>(
    context,
    tall: true,
    builder: (sheetContext) => _ChronicleSheet(controller: controller),
  );
}

class _ChronicleSheet extends StatefulWidget {
  const _ChronicleSheet({required this.controller});

  final GameController controller;

  @override
  State<_ChronicleSheet> createState() => _ChronicleSheetState();
}

class _ChronicleSheetState extends State<_ChronicleSheet> {
  static const int _maxEntries = 120;

  bool _onlyMine = false;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final game = widget.controller.game;
    // 只取内存里保留的尾部战报，长篇对局不必反转整段历史。
    final entries = game.recentChronicle
        .toList()
        .reversed
        .where(
          (entry) =>
              !_onlyMine ||
              entry.factionId == null ||
              entry.factionId == game.playerFaction,
        )
        .take(_maxEntries)
        .toList();
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
          child: SheetHeader(
            title: '战报',
            subtitle: '共 ${game.chronicle.length} 条',
            trailing: FilterChip(
              label: const Text('只看我方'),
              selected: _onlyMine,
              onSelected: (value) => setState(() => _onlyMine = value),
            ),
          ),
        ),
        const Divider(height: 1),
        Expanded(
          child: entries.isEmpty
              ? const Center(child: HintText('暂无战报', body: true))
              : ListView.separated(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 20),
                  itemCount: entries.length,
                  separatorBuilder: (_, _) => const SizedBox(height: 7),
                  itemBuilder: (context, index) => _ChronicleRow(
                    entry: entries[index],
                    systemColor: colors.onSurfaceVariant,
                  ),
                ),
        ),
      ],
    );
  }
}

class _ChronicleRow extends StatelessWidget {
  const _ChronicleRow({required this.entry, required this.systemColor});

  final Chronicle entry;
  final Color systemColor;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 7,
          height: 7,
          margin: const EdgeInsets.only(top: 5, right: 9),
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: switch (entry.kind) {
              ChronicleKind.battle => appRed,
              ChronicleKind.event => appGold,
              ChronicleKind.order => appJade,
              ChronicleKind.system => systemColor,
            },
          ),
        ),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                entry.text,
                style: theme.textTheme.bodySmall?.copyWith(
                  fontSize: 12,
                  height: 1.45,
                ),
              ),
              Text(
                '${entry.year}年${entry.month}月',
                style: theme.textTheme.labelSmall?.copyWith(
                  color: colors.onSurfaceVariant,
                  fontSize: 9.5,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
