/// Semantic tone of a status chip; colours live in `StatusChip`.
/// Kept UI-free so data models can expose a tone without importing Flutter.
enum StatusTone {
  /// grey - Chờ đồng bộ, Đã hủy
  neutral,

  /// blue - Chờ duyệt, Đang đồng bộ, Chưa pick
  info,

  /// teal - Đã duyệt, Đã xuất kho, Trong kho
  primary,

  /// green - Đã giao, Hoàn tất, Đã thu đủ
  success,

  /// purple - Đang giao, Đang pick
  purple,

  /// amber - Đang vận chuyển, khuyến mãi, chênh lệch
  warning,

  /// red - Bị từ chối, Quá hạn, Hết hạn
  danger,
}
