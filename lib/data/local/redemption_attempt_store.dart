import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';
import 'package:fscm_mobile/core/network/api_exception.dart';
import 'package:fscm_mobile/data/models/loyalty.dart';
import 'package:fscm_mobile/data/models/redemption_attempt.dart';

/// Keeps uncertain submissions across screen/app restarts, scoped to server/user.
/// Persist before POST; never auto-send, overwrite or silently discard an attempt.
class RedemptionAttemptStore {
  RedemptionAttemptStore({required this.server,
    Future<SharedPreferences> Function()? preferences})
      : _preferences = preferences ?? SharedPreferences.getInstance;
  final String server;
  final Future<SharedPreferences> Function() _preferences;
  Future<void> _tail = Future<void>.value();
  String _key(String owner) => 'fscm.redemption.v1.${Uri.encodeComponent(server)}.${Uri.encodeComponent(owner)}';

  Future<T> _serial<T>(Future<T> Function() action) {
    final result = _tail.then((_) => action());
    _tail = result.then<void>((_) {}, onError: (Object _, StackTrace __) {});
    return result;
  }

  Future<RedemptionAttempt?> read(String owner) => _serial(() async {
    final raw = (await _preferences()).getString(_key(owner));
    if (raw == null) {
      return null;
    }
    final json = jsonDecode(raw);
    if (json is! Map<String, dynamic>) {
      invalidLoyaltyResponse();
    }
    final attempt = RedemptionAttempt.fromJson(json);
    if (attempt.ownerId != owner) {
      invalidLoyaltyResponse();
    }
    return attempt;
  });

  Future<RedemptionAttempt> create({required String ownerId,
    required String retailerId, required Gift gift, required int quantity}) => _serial(() async {
    if (quantity <= 0 || quantity * gift.points > 2147483647) {
      throw const ApiException(kind: ApiErrorKind.validation, message: 'Số lượng đổi quà không hợp lệ.');
    }
    final preferences = await _preferences();
    if (preferences.containsKey(_key(ownerId))) {
      throw const ApiException(kind: ApiErrorKind.conflict,
        message: 'Còn yêu cầu chưa xác nhận kết quả. Hãy kiểm tra hoặc thử lại yêu cầu đó trước.');
    }
    final attempt = RedemptionAttempt(ownerId: ownerId, retailerId: retailerId,
      rewardId: gift.id, giftName: gift.name, quantity: quantity, unitPoints: gift.points,
      operationKey: const Uuid().v4());
    if (!await preferences.setString(_key(ownerId), jsonEncode(attempt.toJson()))) {
      throw const ApiException(kind: ApiErrorKind.server, message: 'Không lưu được yêu cầu trên máy; chưa gửi đổi quà.');
    }
    return attempt;
  });

  Future<void> complete(String owner, String operationKey) => _serial(() async {
    final preferences = await _preferences();
    final raw = preferences.getString(_key(owner));
    if (raw == null) {
      return;
    }
    final json = jsonDecode(raw);
    if (json is! Map<String, dynamic>) {
      invalidLoyaltyResponse();
    }
    if (RedemptionAttempt.fromJson(json).operationKey != operationKey) {
      return;
    }
    if (!await preferences.remove(_key(owner))) {
      throw const ApiException(kind: ApiErrorKind.server, message: 'Chưa cập nhật được kết quả yêu cầu trên máy. Hãy tải lại.');
    }
  });

  Future<void> markSent(RedemptionAttempt attempt) => _serial(() async {
    final preferences = await _preferences();
    final raw = preferences.getString(_key(attempt.ownerId));
    if (raw == null) {
      invalidLoyaltyResponse();
    }
    final json = jsonDecode(raw);
    if (json is! Map<String, dynamic> ||
        RedemptionAttempt.fromJson(json).operationKey != attempt.operationKey) {
      invalidLoyaltyResponse();
    }
    // Persist uncertainty before POST, including when the app is killed mid-call.
    if (!await preferences.setString(_key(attempt.ownerId),
        jsonEncode({...json, 'mayHaveSucceeded': true}))) {
      throw const ApiException(kind: ApiErrorKind.server,
        message: 'Không lưu được yêu cầu trên máy; chưa gửi đổi quà.');
    }
  });
}
