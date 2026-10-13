/// Maximum orderable quantity rule shown in the product list:
/// available stock minus the safety buffer, rounded DOWN to a multiple of 10
/// (e.g. 120 cartons left with buffer 20 -> max 100).
class OrderLimits {
  OrderLimits._();

  static const int safetyBuffer = 20;
  static const int step = 10;

  static int maxQty(int available, {int buffer = safetyBuffer}) {
    final usable = available - buffer;
    if (usable <= 0) return 0;
    return (usable ~/ step) * step;
  }
}
