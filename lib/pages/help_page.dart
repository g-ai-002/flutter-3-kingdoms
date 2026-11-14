import 'package:material_ui/material_ui.dart';

import '../theme/app_theme.dart';
import 'widgets/common.dart';

/// 玩法说明的章节：标题、图标与若干段落。
typedef _HelpSection = ({String title, IconData icon, List<String> lines});

/// 玩法说明：目标、回合流程、内政、人事与战斗规则。
class HelpPage extends StatelessWidget {
  const HelpPage({super.key});

  static const List<_HelpSection> _sections = [
    (
      title: '争霸目标',
      icon: Icons.flag_outlined,
      lines: [
        '占据天下全部城池即可一统山河；若本方城池尽失，则霸业成空。',
        '五方势力各据一方：魏（曹操）、蜀（刘备）、吴（孙权）、袁（袁绍）、董（董卓）。',
        '开局可选群雄割据、官渡对峙、三分天下三个剧本，并按俭省 / 常规 / 丰饶自定本方开局钱粮。',
      ],
    ),
    (
      title: '回合流程',
      icon: Icons.hourglass_bottom_outlined,
      lines: [
        '游戏以「月」为回合。每月每座城池可下达一条指令，出征同样占用该城本月指令。',
        '结束本月后，其余势力先行发展或出兵，随后统一结算各城金钱、粮草与随机事件，再进入下一个月。',
        '钱粮由各城农业、商业、治安与人口决定；兵越多，每月粮草消耗越大，粮尽会逃兵。',
      ],
    ),
    (
      title: '内政六令',
      icon: Icons.agriculture_outlined,
      lines: [
        '开垦：提升农业，增加每月粮草收入。',
        '招商：提升商业，增加每月金钱收入。',
        '治安：提升治安，收入效率与征兵数量都会提高。',
        '征兵：消耗钱粮补充兵源，上限由人口决定。',
        '训练：提升训练度，直接增强攻城与守城战力。',
        '修城：提升城防，守城时大幅加成。',
      ],
    ),
    (
      title: '人事与名将',
      icon: Icons.groups_2_outlined,
      lines: [
        '太守影响内政效率与守城战力，可随时更换，不消耗本月指令。',
        '在野武将可用金钱登用，政治越高成功率越高；破城后敌将也有机会归顺。',
        '武将分猛将、谋士、统帅、能吏与全才，特长会影响战斗与内政表现。',
        '名将历练：出征与内政都积累历练，每百点升一级，最高九级；等级越高攻城守城越锐利。',
        '犒赏：人事面板可花金提升武将忠诚；忠义者城破之后更难被他人招降。',
      ],
    ),
    (
      title: '兵种与技能',
      icon: Icons.shield_moon_outlined,
      lines: [
        '四兵种相克：步兵克骑兵，骑兵克弩兵，弩兵克步兵；水军不参与克制，但在水乡战力大增。',
        '出兵前可在出征面板查看双方兵种；以克制守军的兵种出战，能以更少兵力破城。',
        '武将技能：神武增战力与单挑，铁壁利守城，火计强火攻，治世益内政，疾行利突袭。',
      ],
    ),
    (
      title: '外交纵横',
      icon: Icons.send_outlined,
      lines: [
        '在「势力」面板可遣使交涉，金钱无论成败都会消耗。',
        '停战：罢兵六月；联姻：结好两年。盟约期间双方不可互相进攻。',
        '劝降：仅余两城以内的弱小势力可被劝降，成功则城池、武将并入本方。',
        '使者由本方政治最高的武将担任，实力越强、政治越高，成算越大。',
      ],
    ),
    (
      title: '攻城战',
      icon: Icons.gavel_rounded,
      lines: [
        '只有接壤的敌城才能进攻，出征至少 500 兵，且城中须留 200 守军。',
        '每回合可选择强攻、固守、火攻或突袭；守将会依兵力与智力自动应对。',
        '强攻杀伤高但自损大；固守减伤并恢复士气；火攻看智力差；突袭波动最大。',
        '士气、训练度、主将统率与武力、地形与城防都会影响战力。',
        '破城后我军残部进驻新城；若败退，残兵撤回原城。',
      ],
    ),
    (
      title: '小贴士',
      icon: Icons.lightbulb_outline,
      lines: [
        '先开垦与招商稳住钱粮，再征兵训练，避免粮草见底。',
        '进攻前查看守军、城防与兵种，胜算不足时先削弱邻城或提升训练。',
        '在野名将多藏于大城，如洛阳张辽、襄阳诸葛亮、天水马超。',
        '对局顶部可随时存档；结束本月与退到后台会自动存档，首页可继续征战。',
        '地图操作：点选城池查看详情，底部按钮执行内政、出征与人事。',
      ],
    ),
  ];

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    return Scaffold(
      appBar: AppBar(title: const Text('玩法说明')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 4, 16, 28),
        children: [
          for (final section in _sections) ...[
            _Section(
              title: section.title,
              icon: section.icon,
              children: [for (final line in section.lines) _Paragraph(line)],
            ),
            const SizedBox(height: 12),
          ],
          const SizedBox(height: 6),
          Center(
            child: Text(
              '落子无悔，兴亡一瞬',
              style: hintStyle(context, size: 10)?.copyWith(letterSpacing: 4),
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
