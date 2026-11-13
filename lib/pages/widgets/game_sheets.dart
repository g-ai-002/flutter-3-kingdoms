import 'package:flutter/material.dart';

import '../../game/game_controller.dart';
import '../../game/orders.dart';
import '../../models/chronicle.dart';
import '../../models/city.dart';
import '../../models/faction.dart';
import '../../models/general.dart';
import '../../theme/app_theme.dart';
import 'common.dart';

/// 出征面板的返回值：目标城池、主将与出兵数。
class CampaignRequest {
  const CampaignRequest({
    required this.target,
    required this.general,
    required this.troops,
  });

  final City target;
  final General? general;
  final int troops;
}

IconData actionIcon(CityAction action) => switch (action) {
  CityAction.reclaim => Icons.grass_outlined,
  CityAction.trade => Icons.storefront_outlined,
  CityAction.patrol => Icons.shield_outlined,
  CityAction.recruit => Icons.groups_outlined,
  CityAction.train => Icons.fitness_center_outlined,
  CityAction.fortify => Icons.fort_outlined,
};

/// 内政指令面板：列出六条指令与花费，已下令或资源不足时置灰。
Future<CityAction?> showInternalAffairsSheet(
  BuildContext context,
  GameController controller,
  City city,
) {
  final theme = Theme.of(context);
  final colors = theme.colorScheme;
  final faction = controller.game.player;
  return showModalBottomSheet<CityAction>(
    context: context,
    showDragHandle: true,
    builder: (sheetContext) => SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Text('${city.name} · 内政', style: theme.textTheme.titleSmall),
                const Spacer(),
                InfoChip(
                  text: city.acted ? '本月已下令' : '本月可下令',
                  color: city.acted ? colors.error : appJade,
                  dense: true,
                ),
              ],
            ),
            const SizedBox(height: 4),
            Text(
              '金 ${faction.gold} · 粮 ${faction.food} · 每城每月限一条指令',
              style: theme.textTheme.labelSmall?.copyWith(
                color: colors.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 10),
            ...CityAction.values.map((action) {
              final affordable =
                  faction.gold >= action.goldCost &&
                  faction.food >= action.foodCost;
              final enabled = !city.acted && affordable;
              return Padding(
                padding: const EdgeInsets.only(bottom: 7),
                child: _ActionTile(
                  icon: actionIcon(action),
                  label: action.label,
                  description: action.description,
                  goldCost: action.goldCost,
                  foodCost: action.foodCost,
                  enabled: enabled,
                  onTap: () => Navigator.of(sheetContext).pop(action),
                ),
              );
            }),
          ],
        ),
      ),
    ),
  );
}

/// 出征面板：选择目标、主将与出兵数，并给出守军概览。
Future<CampaignRequest?> showCampaignSheet(
  BuildContext context,
  GameController controller,
  City source, {
  City? preferredTarget,
}) {
  return showModalBottomSheet<CampaignRequest>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    builder: (sheetContext) => _CampaignSheet(
      controller: controller,
      source: source,
      preferredTarget: preferredTarget,
    ),
  );
}

class _CampaignSheet extends StatefulWidget {
  const _CampaignSheet({
    required this.controller,
    required this.source,
    this.preferredTarget,
  });

  final GameController controller;
  final City source;
  final City? preferredTarget;

  @override
  State<_CampaignSheet> createState() => _CampaignSheetState();
}

class _CampaignSheetState extends State<_CampaignSheet> {
  late final List<City> _targets;
  late City _target;
  late List<General> _generals;
  General? _general;
  late double _troops;

  @override
  void initState() {
    super.initState();
    _targets = widget.controller.game.enemyNeighbors(widget.source);
    final preferred = widget.preferredTarget;
    if (preferred != null) {
      _targets.sort((a, b) {
        if (a.id == preferred.id) return -1;
        if (b.id == preferred.id) return 1;
        return 0;
      });
    }
    _target = _targets.first;
    _generals = widget.controller
        .residentsOf(widget.source)
        .toList()
      ..sort((a, b) => b.attackFactor.compareTo(a.attackFactor));
    _general = _generals.isEmpty ? null : _generals.first;
    _troops = (widget.source.troops * 0.7).clamp(500, _maxTroops).toDouble();
  }

  double get _maxTroops =>
      (widget.source.troops - 200).clamp(500, double.infinity).toDouble();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final source = widget.source;
    final governorId = _target.governor;
    final defender = governorId == null
        ? null
        : widget.controller.game.generals[governorId];
    final powerRatio =
        (source.troops * (0.6 + source.training / 160)) / _target.power;
    final odds = powerRatio >= 1.6
        ? '胜算颇高'
        : powerRatio >= 1.1
        ? '势均力敌'
        : '凶多吉少';
    final oddsColor = powerRatio >= 1.6
        ? appJade
        : powerRatio >= 1.1
        ? const Color(0xFF8A6A32)
        : appRed;
    return SafeArea(
      child: Padding(
        padding: EdgeInsets.only(
          left: 16,
          right: 16,
          bottom: MediaQuery.viewInsetsOf(context).bottom + 12,
        ),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  Text('${source.name} · 出征', style: theme.textTheme.titleSmall),
                  const Spacer(),
                  InfoChip(
                    text: '可出 ${source.troops - 200} 兵',
                    dense: true,
                    color: colors.primary,
                  ),
                ],
              ),
              const SizedBox(height: 10),
              Text(
                '择一敌城',
                style: theme.textTheme.labelSmall?.copyWith(
                  color: colors.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: 6),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  for (final target in _targets)
                    ChoiceChip(
                      label: Text(
                        '${target.name}（${FactionDefs.nameOf(target.owner)}）',
                      ),
                      selected: target.id == _target.id,
                      onSelected: (_) => setState(() => _target = target),
                    ),
                ],
              ),
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(11),
                decoration: BoxDecoration(
                  color: colors.surfaceContainerHighest.withValues(alpha: 0.6),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: colors.outline),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        FactionSeal(factionId: _target.owner, size: 26),
                        const SizedBox(width: 7),
                        Text(
                          _target.name,
                          style: theme.textTheme.titleSmall?.copyWith(
                            fontSize: 13,
                          ),
                        ),
                        const SizedBox(width: 6),
                        Text(
                          _target.terrain.label,
                          style: theme.textTheme.labelSmall?.copyWith(
                            color: colors.onSurfaceVariant,
                          ),
                        ),
                        const Spacer(),
                        InfoChip(text: odds, color: oddsColor, dense: true),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Text(
                      '守军 ${_target.troops} · 城防 ${_target.defense} · '
                      '训练 ${_target.training} · '
                      '守将 ${defender?.name ?? '无名守将'}',
                      style: theme.textTheme.labelSmall?.copyWith(
                        color: colors.onSurfaceVariant,
                        height: 1.5,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              Text(
                '择一主将',
                style: theme.textTheme.labelSmall?.copyWith(
                  color: colors.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: 6),
              if (_generals.isEmpty)
                Text(
                  '城中无将，只能由偏将带队（战力较低）',
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: colors.error,
                  ),
                )
              else
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    for (final general in _generals)
                      ChoiceChip(
                        label: Text(
                          '${general.name} 武${general.wu} 统${general.lead}',
                        ),
                        selected: general.id == _general?.id,
                        onSelected: (_) => setState(() => _general = general),
                      ),
                  ],
                ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Text(
                    '出兵 ${_troops.round()}',
                    style: theme.textTheme.titleSmall?.copyWith(fontSize: 13),
                  ),
                  const Spacer(),
                  Text(
                    '留 ${source.troops - _troops.round()} 守城',
                    style: theme.textTheme.labelSmall?.copyWith(
                      color: colors.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
              Slider(
                value: _troops,
                min: 500,
                max: _maxTroops,
                divisions: ((_maxTroops - 500) / 100).ceil().clamp(1, 200).toInt(),
                label: '${_troops.round()}',
                onChanged: (value) => setState(() => _troops = value),
              ),
              const SizedBox(height: 4),
              FilledButton.icon(
                onPressed: () => Navigator.of(context).pop(
                  CampaignRequest(
                    target: _target,
                    general: _general,
                    troops: _troops.round(),
                  ),
                ),
                icon: const Icon(Icons.gavel_rounded, size: 18),
                label: Text('兵发 ${_target.name}'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// 任命与登用：太守可不耗指令更换，在野武将可花金登用。
Future<void> showAppointmentSheet(
  BuildContext context,
  GameController controller,
  City city,
) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    builder: (sheetContext) => StatefulBuilder(
      builder: (context, setSheetState) {
        final theme = Theme.of(context);
        final colors = theme.colorScheme;
        final residents = controller.residentsOf(city);
        final free = controller.freeGeneralsIn(city);
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    children: [
                      Text('${city.name} · 人事', style: theme.textTheme.titleSmall),
                      const Spacer(),
                      Text(
                        '金 ${controller.game.player.gold}',
                        style: theme.textTheme.labelSmall?.copyWith(
                          color: colors.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  Text(
                    '任命太守 · 太守的政治与统率影响内政与守城',
                    style: theme.textTheme.labelSmall?.copyWith(
                      color: colors.onSurfaceVariant,
                    ),
                  ),
                  const SizedBox(height: 6),
                  if (residents.isEmpty)
                    Text(
                      '城中暂无武将',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: colors.onSurfaceVariant,
                      ),
                    )
                  else
                    ...residents.map((general) {
                      final selected = city.governor == general.id;
                      return ListTile(
                        dense: true,
                        contentPadding: EdgeInsets.zero,
                        leading: FactionSeal(factionId: city.owner, size: 30),
                        title: Text(
                          '${general.name} · ${general.trait.label}',
                          style: theme.textTheme.titleSmall?.copyWith(
                            fontSize: 13,
                          ),
                        ),
                        subtitle: Text(
                          '武 ${general.wu} · 智 ${general.intel} · '
                          '统 ${general.lead} · 政 ${general.politics}',
                          style: theme.textTheme.labelSmall?.copyWith(
                            color: colors.onSurfaceVariant,
                          ),
                        ),
                        trailing: selected
                            ? Icon(Icons.check_circle, color: colors.primary)
                            : const Icon(Icons.circle_outlined, size: 18),
                        onTap: () {
                          controller.appointGovernor(general.id);
                          setSheetState(() {});
                        },
                      );
                    }),
                  const Divider(height: 20),
                  Text(
                    '在野武将 · 登用花费 ${OrderService.recruitGeneralCost} 金',
                    style: theme.textTheme.labelSmall?.copyWith(
                      color: colors.onSurfaceVariant,
                    ),
                  ),
                  const SizedBox(height: 6),
                  if (free.isEmpty)
                    Text(
                      '城中暂无在野名士',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: colors.onSurfaceVariant,
                      ),
                    )
                  else
                    ...free.map((general) {
                      final canRecruit =
                          !city.acted &&
                          controller.game.player.gold >=
                              OrderService.recruitGeneralCost;
                      return ListTile(
                        dense: true,
                        contentPadding: EdgeInsets.zero,
                        leading: Container(
                          width: 30,
                          height: 30,
                          alignment: Alignment.center,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            border: Border.all(color: colors.outline),
                          ),
                          child: Text(
                            general.name.substring(0, 1),
                            style: theme.textTheme.labelSmall,
                          ),
                        ),
                        title: Text(
                          '${general.name} · ${general.trait.label}',
                          style: theme.textTheme.titleSmall?.copyWith(
                            fontSize: 13,
                          ),
                        ),
                        subtitle: Text(
                          '武 ${general.wu} · 智 ${general.intel} · '
                          '统 ${general.lead} · 政 ${general.politics}',
                          style: theme.textTheme.labelSmall?.copyWith(
                            color: colors.onSurfaceVariant,
                          ),
                        ),
                        trailing: TextButton(
                          onPressed: canRecruit
                              ? () {
                                  final result = controller.recruitGeneral(
                                    general.id,
                                  );
                                  setSheetState(() {});
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(content: Text(result.message)),
                                  );
                                }
                              : null,
                          child: const Text('登用'),
                        ),
                      );
                    }),
                ],
              ),
            ),
          ),
        );
      },
    ),
  );
}

/// 战报：按月记录的内政、战斗与随机事件。
Future<void> showChronicleSheet(
  BuildContext context,
  GameController controller,
) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    builder: (sheetContext) => SizedBox(
      height: MediaQuery.sizeOf(sheetContext).height * 0.72,
      child: _ChronicleSheet(controller: controller),
    ),
  );
}

class _ChronicleSheet extends StatefulWidget {
  const _ChronicleSheet({required this.controller});

  final GameController controller;

  @override
  State<_ChronicleSheet> createState() => _ChronicleSheetState();
}

class _ChronicleSheetState extends State<_ChronicleSheet> {
  bool _onlyMine = false;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final entries = widget.controller.game.chronicle.reversed
        .where(
          (entry) =>
              !_onlyMine ||
              entry.factionId == null ||
              entry.factionId == widget.controller.game.playerFaction,
        )
        .take(120)
        .toList();
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
          child: Row(
            children: [
              Text('战报', style: theme.textTheme.titleSmall),
              const SizedBox(width: 8),
              Text(
                '共 ${widget.controller.game.chronicle.length} 条',
                style: theme.textTheme.labelSmall?.copyWith(
                  color: colors.onSurfaceVariant,
                ),
              ),
              const Spacer(),
              FilterChip(
                label: const Text('只看我方'),
                selected: _onlyMine,
                onSelected: (value) => setState(() => _onlyMine = value),
              ),
            ],
          ),
        ),
        const Divider(height: 1),
        Expanded(
          child: entries.isEmpty
              ? Center(
                  child: Text(
                    '暂无战报',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: colors.onSurfaceVariant,
                    ),
                  ),
                )
              : ListView.separated(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 20),
                  itemCount: entries.length,
                  separatorBuilder: (_, _) => const SizedBox(height: 7),
                  itemBuilder: (context, index) {
                    final entry = entries[index];
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
                              ChronicleKind.system => colors.onSurfaceVariant,
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
                  },
                ),
        ),
      ],
    );
  }
}

/// 五方势力总览。
Future<void> showFactionOverviewSheet(
  BuildContext context,
  GameController controller,
) {
  return showModalBottomSheet<void>(
    context: context,
    showDragHandle: true,
    builder: (sheetContext) {
      final theme = Theme.of(sheetContext);
      final colors = theme.colorScheme;
      final game = controller.game;
      return SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text('天下势力', style: theme.textTheme.titleSmall),
              const SizedBox(height: 10),
              for (final def in FactionDefs.all)
                Builder(
                  builder: (context) {
                    final faction = game.factions[def.id]!;
                    final cities = game.cityCount(def.id);
                    final troops = game.troopsOf(def.id);
                    final isPlayer = def.id == game.playerFaction;
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 9),
                      child: Container(
                        padding: const EdgeInsets.fromLTRB(10, 8, 10, 8),
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: isPlayer
                                ? const Color(0xFFC8A15A)
                                : colors.outline,
                          ),
                          color: isPlayer
                              ? colors.primaryContainer.withValues(alpha: 0.35)
                              : colors.surface,
                        ),
                        child: Row(
                          children: [
                            FactionSeal(factionId: def.id, size: 34),
                            const SizedBox(width: 9),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      Text(
                                        '${def.ruler} · ${def.name}',
                                        style: theme.textTheme.titleSmall
                                            ?.copyWith(fontSize: 13),
                                      ),
                                      if (isPlayer) ...[
                                        const SizedBox(width: 5),
                                        InfoChip(
                                          text: '我方',
                                          dense: true,
                                          color: colors.primary,
                                        ),
                                      ],
                                      if (!faction.alive) ...[
                                        const SizedBox(width: 5),
                                        const InfoChip(
                                          text: '已亡',
                                          dense: true,
                                          color: Colors.grey,
                                        ),
                                      ],
                                    ],
                                  ),
                                  Text(
                                    '$cities 城 · 兵 $troops · '
                                    '金 ${faction.gold} · 粮 ${faction.food}',
                                    style: theme.textTheme.labelSmall?.copyWith(
                                      color: colors.onSurfaceVariant,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
            ],
          ),
        ),
      );
    },
  );
}

class _ActionTile extends StatelessWidget {
  const _ActionTile({
    required this.icon,
    required this.label,
    required this.description,
    required this.goldCost,
    required this.foodCost,
    required this.enabled,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final String description;
  final int goldCost;
  final int foodCost;
  final bool enabled;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    return Material(
      color: colors.surface,
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        onTap: enabled ? onTap : null,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          padding: const EdgeInsets.fromLTRB(10, 8, 10, 8),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: colors.outline),
          ),
          child: Row(
            children: [
              Container(
                width: 34,
                height: 34,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: (enabled ? colors.primary : colors.onSurfaceVariant)
                      .withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(9),
                ),
                child: Icon(
                  icon,
                  size: 18,
                  color: enabled ? colors.primary : colors.onSurfaceVariant,
                ),
              ),
              const SizedBox(width: 9),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      label,
                      style: theme.textTheme.titleSmall?.copyWith(
                        fontSize: 13,
                        color: enabled ? colors.onSurface : colors.onSurfaceVariant,
                      ),
                    ),
                    Text(
                      description,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.labelSmall?.copyWith(
                        color: colors.onSurfaceVariant,
                        fontSize: 10.5,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 6),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  if (goldCost > 0)
                    InfoChip(text: '金 $goldCost', dense: true, color: appGold),
                  if (foodCost > 0) ...[
                    const SizedBox(height: 3),
                    InfoChip(text: '粮 $foodCost', dense: true, color: appJade),
                  ],
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
