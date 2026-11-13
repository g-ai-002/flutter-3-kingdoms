/// 难度：影响 AI 的扩张欲望与经济加成。
enum Difficulty {
  easy(
    label: '悠闲',
    summary: 'AI 发展迟缓，适合熟悉规则',
    aiIncome: 0.85,
    aiAggression: 1.55,
    playerIncome: 1.1,
    stars: 1,
  ),
  normal(
    label: '争雄',
    summary: 'AI 正常扩张，攻守有度',
    aiIncome: 1.0,
    aiAggression: 1.22,
    playerIncome: 1.0,
    stars: 2,
  ),
  hard(
    label: '霸业',
    summary: 'AI 富侵略性，稍有不慎便兵临城下',
    aiIncome: 1.15,
    aiAggression: 1.0,
    playerIncome: 0.95,
    stars: 3,
  );

  const Difficulty({
    required this.label,
    required this.summary,
    required this.aiIncome,
    required this.aiAggression,
    required this.playerIncome,
    required this.stars,
  });

  final String label;
  final String summary;

  /// AI 势力每月钱粮收入倍率。
  final double aiIncome;

  /// AI 出兵所需的兵力优势：己方兵力 / 敌方兵力。
  final double aiAggression;

  /// 玩家势力每月收入倍率。
  final double playerIncome;

  final int stars;

  static Difficulty byName(String? name) => values.firstWhere(
    (item) => item.name == name,
    orElse: () => Difficulty.normal,
  );
}
