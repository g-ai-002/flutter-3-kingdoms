import 'package:flutter/material.dart';

import '../../../game/battle_preview.dart';
import '../../../game/game_controller.dart';
import '../../../models/city.dart';
import '../../../models/faction.dart';
import '../../../models/general.dart';
import '../../../theme/app_theme.dart';
import '../common.dart';

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

/// 出征面板：选择目标、主将与出兵数，并给出守军概览。
Future<CampaignRequest?> showCampaignSheet(
  BuildContext context,
  GameController controller,
  City source, {
  City? preferredTarget,
}) {
  return showGameSheet<CampaignRequest>(
    context,
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
  late final List<General> _generals;
  late City _target;
  General? _general;
  late double _troops;

  @override
  void initState() {
    super.initState();
    _targets = widget.controller.game.enemyNeighbors(widget.source);
    _generals = widget.controller.game.attackLeaders(widget.source);
    _target = _preferredTarget();
    _general = _generals.isEmpty ? null : _generals.first;
    _troops = (widget.source.troops * 0.7).clamp(500, _maxTroops).toDouble();
  }

  /// 从地图上直接点「攻打」时，把该城排在候选目标的第一位。
  City _preferredTarget() {
    final preferred = widget.preferredTarget;
    if (preferred == null) return _targets.first;
    final index = _targets.indexWhere((city) => city.id == preferred.id);
    if (index <= 0) return _targets.first;
    final target = _targets.removeAt(index);
    _targets.insert(0, target);
    return target;
  }

  double get _maxTroops =>
      (widget.source.troops - 200).clamp(500, double.infinity).toDouble();

  String _counterHint(City source, City target) {
    if (source.troopType.counters(target.troopType)) return '我军兵种占优';
    if (target.troopType.counters(source.troopType)) return '我军兵种受制';
    return '兵种互不克制';
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final hint = hintStyle(context);
    final source = widget.source;
    final preview = widget.controller.previewAttack(source, _target);
    final defender = preview.defender;
    final oddsColor = switch (preview.odds) {
      BattleOdds.favorable => appJade,
      BattleOdds.even => const Color(0xFF8A6A32),
      BattleOdds.unfavorable => appRed,
    };
    return SheetFrame(
      title: '${source.name} · 出征',
      trailing: InfoChip(
        text: '可出 ${source.troops - 200} 兵',
        dense: true,
        color: colors.primary,
      ),
      scrollable: true,
      gap: 10,
      padding: EdgeInsets.only(
        left: 16,
        right: 16,
        bottom: MediaQuery.viewInsetsOf(context).bottom + 12,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const HintText('择一敌城'),
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
            decoration: cardDecoration(
              context,
              radius: 12,
              color: colors.surfaceContainerHighest.withValues(alpha: 0.6),
              shadow: false,
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
                      style: theme.textTheme.titleSmall?.copyWith(fontSize: 13),
                    ),
                    const SizedBox(width: 6),
                    Text(_target.terrain.label, style: hint),
                    const SizedBox(width: 5),
                    InfoChip(
                      text: _target.troopType.label,
                      dense: true,
                      color: appRed,
                    ),
                    const Spacer(),
                    InfoChip(
                      text: preview.odds.label,
                      color: oddsColor,
                      dense: true,
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                Text(
                  '守军 ${_target.troops} · 城防 ${_target.defense} · '
                  '训练 ${_target.training} · '
                  '守将 ${defender?.name ?? '无名守将'}',
                  style: hint?.copyWith(height: 1.5),
                ),
                Text(
                  '${source.troopType.label} 对 ${_target.troopType.label} · '
                  '${_counterHint(source, _target)}',
                  style: hint?.copyWith(height: 1.5),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          const HintText('择一主将'),
          const SizedBox(height: 6),
          if (_generals.isEmpty)
            Text(
              '城中无将，只能由偏将带队（战力较低）',
              style: theme.textTheme.labelSmall?.copyWith(color: colors.error),
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
              Text('留 ${source.troops - _troops.round()} 守城', style: hint),
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
    );
  }
}
