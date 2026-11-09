/// Quantities use the existing ten-carton order increment. No artificial stock buffer is withheld.
class OrderLimits {
  OrderLimits._();
  static const int step = 10;
  static int maxQty(int available) =>
      available <= 0 ? 0 : (available ~/ step) * step;
}
