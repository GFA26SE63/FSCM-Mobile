import 'package:flutter/material.dart';
import 'package:fmcg/core/theme/fscm_theme.dart';
import 'package:fmcg/features/warehouse/domain/warehouse_models.dart';

String pickingStatusLabel(PickingStatus status) => switch (status) {
  PickingStatus.notStarted => 'Chưa pick',
  PickingStatus.inProgress => 'Đang pick',
  PickingStatus.shipped => 'Đã xuất',
};

Color pickingStatusColor(PickingStatus status) => switch (status) {
  PickingStatus.notStarted => FscmColors.info,
  PickingStatus.inProgress => FscmColors.purple,
  PickingStatus.shipped => const Color(0xFF15703A),
};

String stockStatusLabel(StockLabelStatus status) => switch (status) {
  StockLabelStatus.inStock => 'Trong kho',
  StockLabelStatus.picked => 'Đã pick',
  StockLabelStatus.inTransit => 'Đang vận chuyển',
  StockLabelStatus.expired => 'Hết hạn',
};

Color stockStatusColor(StockLabelStatus status) => switch (status) {
  StockLabelStatus.inStock => FscmColors.primary,
  StockLabelStatus.picked => FscmColors.purple,
  StockLabelStatus.inTransit => FscmColors.info,
  StockLabelStatus.expired => FscmColors.danger,
};
