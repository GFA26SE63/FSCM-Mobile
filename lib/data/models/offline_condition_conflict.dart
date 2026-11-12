import 'dart:convert';

import 'package:fscm_mobile/data/models/json_utils.dart';

/// Commercial conditions returned by POST /orders/sync with HTTP 409.
class OfflineConditionConflict {
  const OfflineConditionConflict({
    required this.clientOrderKey,
    required this.snapshotVersion,
    required this.offlineEstimatedAmount,
    required this.currentIndicativeAmount,
    required this.changedLines,
  });

  final String clientOrderKey;
  final String? snapshotVersion;
  final num offlineEstimatedAmount;
  final num currentIndicativeAmount;
  final List<OfflineConditionDifference> changedLines;

  static OfflineConditionConflict? tryParse(Object? value) {
    if (value is! Map) {
      return null;
    }
    final json = asMap(value);
    final key = asStr(json['clientOrderKey']);
    final offline = json['offlineEstimatedAmount'];
    final current = json['currentIndicativeAmount'];
    final rawLines = json['changedLines'];
    if (json['requiresExplicitConfirmation'] != true ||
        key.isEmpty ||
        offline is! num ||
        !offline.isFinite ||
        offline < 0 ||
        current is! num ||
        !current.isFinite ||
        current < 0 ||
        rawLines is! List) {
      return null;
    }

    final lines = <OfflineConditionDifference>[];
    final ids = <String>{};
    for (final raw in rawLines) {
      final line = OfflineConditionDifference.tryParse(raw);
      if (line == null || !ids.add(line.productId)) {
        return null;
      }
      lines.add(line);
    }
    return OfflineConditionConflict(
      clientOrderKey: key,
      snapshotVersion: asStrOrNull(json['snapshotVersion']),
      offlineEstimatedAmount: offline,
      currentIndicativeAmount: current,
      changedLines: List.unmodifiable(lines),
    );
  }

  Map<String, dynamic> toJson() => {
        'clientOrderKey': clientOrderKey,
        'snapshotVersion': snapshotVersion,
        'offlineEstimatedAmount': offlineEstimatedAmount.toDouble(),
        'currentIndicativeAmount': currentIndicativeAmount.toDouble(),
        'changedLines': changedLines.map((line) => line.toJson()).toList(),
        'requiresExplicitConfirmation': true,
      };

  bool sameAs(OfflineConditionConflict other) =>
      jsonEncode(toJson()) == jsonEncode(other.toJson());
}

class OfflineConditionDifference {
  const OfflineConditionDifference({
    required this.productId,
    required this.sku,
    required this.expectedBaseUnitPrice,
    required this.currentBaseUnitPrice,
    required this.expectedMlorVersion,
    required this.currentMlorVersion,
    required this.expectedMlorRatio,
    required this.currentMlorRatio,
  });

  final String productId;
  final String sku;
  final num expectedBaseUnitPrice;
  final num currentBaseUnitPrice;
  final int expectedMlorVersion;
  final int currentMlorVersion;
  final double expectedMlorRatio;
  final double currentMlorRatio;

  static OfflineConditionDifference? tryParse(Object? value) {
    if (value is! Map) {
      return null;
    }
    final json = asMap(value);
    final productId = asStr(json['productId']);
    final expectedPrice = json['expectedBaseUnitPrice'];
    final currentPrice = json['currentBaseUnitPrice'];
    final expectedVersion = json['expectedMlorVersion'];
    final currentVersion = json['currentMlorVersion'];
    final expectedRatio = json['expectedMlorRatio'];
    final currentRatio = json['currentMlorRatio'];
    if (productId.isEmpty ||
        expectedPrice is! num ||
        !expectedPrice.isFinite ||
        expectedPrice < 0 ||
        currentPrice is! num ||
        !currentPrice.isFinite ||
        currentPrice < 0 ||
        expectedVersion is! int ||
        expectedVersion < 1 ||
        currentVersion is! int ||
        currentVersion < 1 ||
        expectedRatio is! num ||
        !expectedRatio.isFinite ||
        expectedRatio <= 0 ||
        expectedRatio >= 1 ||
        currentRatio is! num ||
        !currentRatio.isFinite ||
        currentRatio <= 0 ||
        currentRatio >= 1) {
      return null;
    }
    return OfflineConditionDifference(
      productId: productId,
      sku: asStr(json['sku'], productId),
      expectedBaseUnitPrice: expectedPrice,
      currentBaseUnitPrice: currentPrice,
      expectedMlorVersion: expectedVersion,
      currentMlorVersion: currentVersion,
      expectedMlorRatio: expectedRatio.toDouble(),
      currentMlorRatio: currentRatio.toDouble(),
    );
  }

  Map<String, dynamic> toJson() => {
        'productId': productId,
        'sku': sku,
        'expectedBaseUnitPrice': expectedBaseUnitPrice.toDouble(),
        'currentBaseUnitPrice': currentBaseUnitPrice.toDouble(),
        'expectedMlorVersion': expectedMlorVersion,
        'currentMlorVersion': currentMlorVersion,
        'expectedMlorRatio': expectedMlorRatio,
        'currentMlorRatio': currentMlorRatio,
      };
}
