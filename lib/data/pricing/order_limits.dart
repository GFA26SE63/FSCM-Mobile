/// Backend fallback when no active order-step configuration exists.
class OrderLimits {
  OrderLimits._();
  static const int step = 1;
  static int maxQty(int available, {int step = OrderLimits.step}) =>
      available <= 0 ? 0 : (available ~/ step) * step;
}
