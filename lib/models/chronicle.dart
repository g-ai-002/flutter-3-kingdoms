/// 战报与事件记录的类别，界面据此配色。
enum ChronicleKind { order, battle, event, system }

/// 一条战报：年月、正文与类别。
class Chronicle {
  const Chronicle({
    required this.year,
    required this.month,
    required this.text,
    required this.kind,
    this.factionId,
  });

  final int year;
  final int month;
  final String text;
  final ChronicleKind kind;
  final String? factionId;
}
