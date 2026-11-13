/// 外交手段：以金钱遣使，换取停战、联姻或举城归附。
enum DiplomaticMove {
  truce('停战', '罢兵休战，两家数月内互不侵犯', 400, 6),
  marriage('联姻', '结秦晋之好，两家两年内互不兴兵', 900, 24),
  vassalize('劝降', '劝说弱小势力举城归附', 1500, 0);

  const DiplomaticMove(this.label, this.summary, this.goldCost, this.months);

  final String label;
  final String summary;
  final int goldCost;

  /// 达成后互不侵犯的月数；劝降不产生盟约。
  final int months;
}
