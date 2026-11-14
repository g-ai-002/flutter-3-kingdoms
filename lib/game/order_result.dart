/// 一次内政、登用或外交指令的执行结果。
class OrderResult {
  const OrderResult({required this.success, required this.message});

  final bool success;
  final String message;
}
