/// 一次内政或登用指令的执行结果。
class OrderResult {
  const OrderResult({
    required this.success,
    required this.message,
    this.effects = const {},
  });

  final bool success;
  final String message;
  final Map<String, int> effects;
}
