import 'package:flutter/material.dart';

import '../theme/app_theme.dart';
import 'widgets/common.dart';

/// 玩法说明：目标、回合流程、内政、人事与战斗规则。
class HelpPage extends StatelessWidget {
  const HelpPage({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    return Scaffold(
      appBar: AppBar(title: const Text('玩法说明')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 4, 16, 28),
        children: [
          const _Section(
            title: '争霸目标',
            icon: Icons.flag_outlined,
            children: [
              _Paragraph('占据天下全部城池即可一统山河；若本方城池尽失，则霸业成空。'),
              _Paragraph('五方势力各据一方：魏（曹操）、蜀（刘备）、吴（孙权）、袁（袁绍）、董（董卓）。'),
            ],
          ),
          const SizedBox(height: 12),
          const _Section(
            title: '回合流程',
            icon: Icons.hourglass_bottom_outlined,
            children: [
              _Paragraph('游戏以「月」为回合。每月每座城池可下达一条指令，出征同样占用该城本月指令。'),
              _Paragraph('结束本月后，其余势力先行发展或出兵，随后统一结算各城金钱、粮草与随机事件，再进入下一个月。'),
              _Paragraph('钱粮由各城农业、商业、治安与人口决定；兵越多，每月粮草消耗越大，粮尽会逃兵。'),
            ],
          ),
          const SizedBox(height: 12),
          const _Section(
            title: '内政六令',
            icon: Icons.agriculture_outlined,
            children: [
              _Paragraph('开垦：提升农业，增加每月粮草收入。'),
              _Paragraph('招商：提升商业，增加每月金钱收入。'),
              _Paragraph('治安：提升治安，收入效率与征兵数量都会提高。'),
              _Paragraph('征兵：消耗钱粮补充兵源，上限由人口决定。'),
              _Paragraph('训练：提升训练度，直接增强攻城与守城战力。'),
              _Paragraph('修城：提升城防，守城时大幅加成。'),
            ],
          ),
          const SizedBox(height: 12),
          const _Section(
            title: '人事与名将',
            icon: Icons.groups_2_outlined,
            children: [
              _Paragraph('太守影响内政效率与守城战力，可随时更换，不消耗本月指令。'),
              _Paragraph('在野武将可用金钱登用，政治越高成功率越高；破城后敌将也有机会归顺。'),
              _Paragraph('武将分猛将、谋士、统帅、能吏与全才，特长会影响战斗与内政表现。'),
            ],
          ),
          const SizedBox(height: 12),
          const _Section(
            title: '攻城战',
            icon: Icons.gavel_rounded,
            children: [
              _Paragraph('只有接壤的敌城才能进攻，出征至少 500 兵，且城中须留 200 守军。'),
              _Paragraph('每回合可选择强攻、固守、火攻或突袭；守将会依兵力与智力自动应对。'),
              _Paragraph('强攻杀伤高但自损大；固守减伤并恢复士气；火攻看智力差；突袭波动最大。'),
              _Paragraph('士气、训练度、主将统率与武力、地形与城防都会影响战力。'),
              _Paragraph('破城后我军残部进驻新城；若败退，残兵撤回原城。'),
            ],
          ),
          const SizedBox(height: 12),
          const _Section(
            title: '小贴士',
            icon: Icons.lightbulb_outline,
            children: [
              _Paragraph('先开垦与招商稳住钱粮，再征兵训练，避免粮草见底。'),
              _Paragraph('进攻前查看守军与城防，胜算不足时先削弱邻城或提升训练。'),
              _Paragraph('在野名将多藏于大城，如洛阳张辽、襄阳诸葛亮、天水马超。'),
              _Paragraph('地图操作：点选城池查看详情，底部按钮执行内政、出征与人事。'),
            ],
          ),
          const SizedBox(height: 18),
          Center(
            child: Text(
              '落子无悔，兴亡一瞬',
              style: theme.textTheme.labelSmall?.copyWith(
                color: colors.onSurfaceVariant,
                letterSpacing: 4,
              ),
            ),
          ),
          const SizedBox(height: 6),
          Center(child: TitleOrnament(width: 40, color: colors.outline)),
        ],
      ),
    );
  }
}

class _Section extends StatelessWidget {
  const _Section({
    required this.title,
    required this.icon,
    required this.children,
  });

  final String title;
  final IconData icon;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    return SectionCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 17, color: colors.primary),
              const SizedBox(width: 7),
              Text(title, style: theme.textTheme.titleSmall),
              const SizedBox(width: 10),
              Expanded(child: Divider(color: colors.outline)),
            ],
          ),
          const SizedBox(height: 9),
          ...children.map(
            (child) => Padding(
              padding: const EdgeInsets.only(bottom: 7),
              child: child,
            ),
          ),
        ],
      ),
    );
  }
}

class _Paragraph extends StatelessWidget {
  const _Paragraph(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 5,
          height: 5,
          margin: const EdgeInsets.only(top: 7, right: 8),
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: appGold.withValues(alpha: 0.9),
          ),
        ),
        Expanded(
          child: Text(
            text,
            style: theme.textTheme.bodySmall?.copyWith(
              color: colors.onSurfaceVariant,
              height: 1.65,
              fontSize: 12,
            ),
          ),
        ),
      ],
    );
  }
}
