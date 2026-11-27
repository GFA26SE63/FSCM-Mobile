import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:fscm_mobile/data/models/delivery_shipment.dart';
import 'package:fscm_mobile/data/repositories/auth_repository.dart';

/// Carton codes a retailer has scanned for one shipment but not submitted yet,
/// so leaving the receive screen does not throw the scanning away.
///
/// Only a convenience: the Backend re-checks every code on submit. A draft is
/// dropped once the shipment is no longer Delivering, its version moved on,
/// or it is older than [maxAge].
class ReceiptDraftStore {
  ReceiptDraftStore(
      {required this.ownerId,
      Future<SharedPreferences> Function()? preferences,
      DateTime Function()? now})
      : _preferences = preferences ?? SharedPreferences.getInstance,
        _now = now ?? DateTime.now;

  static const Duration maxAge = Duration(days: 7);

  final String ownerId;
  final Future<SharedPreferences> Function() _preferences;
  final DateTime Function() _now;

  String _key(String shipmentId) =>
      'fscm.receipt_draft.v1.${Uri.encodeComponent(ownerId)}.${Uri.encodeComponent(shipmentId)}';

  /// Saved codes for [shipment], or empty when there is no usable draft.
  Future<List<String>> read(DeliveryShipment shipment) async {
    final preferences = await _preferences();
    final raw = preferences.getString(_key(shipment.id));
    if (raw == null) return const <String>[];
    try {
      final json = jsonDecode(raw) as Map<String, dynamic>;
      final savedAt = DateTime.parse(json['savedAt'] as String);
      if (!shipment.canReceive ||
          json['version'] != shipment.version ||
          _now().difference(savedAt) > maxAge) {
        await preferences.remove(_key(shipment.id));
        return const <String>[];
      }
      return (json['codes'] as List<dynamic>).cast<String>();
    } on Object {
      // A corrupt draft is not worth an error screen; start the scan over.
      await preferences.remove(_key(shipment.id));
      return const <String>[];
    }
  }

  Future<void> save(DeliveryShipment shipment, Iterable<String> codes) async {
    // Snapshot before awaiting: the caller may clear its set right after.
    final list = codes.toList(growable: false);
    final preferences = await _preferences();
    if (list.isEmpty) {
      await preferences.remove(_key(shipment.id));
      return;
    }
    await preferences.setString(
        _key(shipment.id),
        jsonEncode(<String, dynamic>{
          'version': shipment.version,
          'savedAt': _now().toIso8601String(),
          'codes': list,
        }));
  }

  Future<void> clear(String shipmentId) async =>
      (await _preferences()).remove(_key(shipmentId));
}

final receiptDraftStoreProvider = Provider<ReceiptDraftStore>((ref) =>
    ReceiptDraftStore(ownerId: ref.watch(currentUserProvider)?.id ?? ''));

/// Draft size per shipment, for the "Đang nhận: x/y thùng" hint on the order.
final receiptDraftCountProvider = FutureProvider.autoDispose
    .family<int, DeliveryShipment>((ref, shipment) async =>
        (await ref.watch(receiptDraftStoreProvider).read(shipment)).length);
