import 'package:flutter_test/flutter_test.dart';
import 'package:fscm_mobile/data/models/enums.dart';
import 'package:fscm_mobile/data/models/timeline_entry.dart';

void main() {
  test('retailer sees the simplified order stages; backend codes are unchanged',
      () {
    final expected = <String, String>{
      'Allocating': 'Đã đặt',
      'Quoted': 'Chờ xác nhận báo giá',
      'PaymentPending': 'Chờ xác nhận báo giá',
      'ConvertedToPo': 'Đã xác nhận báo giá',
      'Picking': 'Đã xác nhận báo giá',
      'Issued': 'Đã xác nhận báo giá',
      'Delivering': 'Đang giao',
      'Delivered': 'Đã nhận',
      'Completed': 'Hoàn tất',
    };
    expected.forEach((code, label) {
      final status = OrderStatus.fromCode(code);
      expect(status.code, code);
      expect(status.retailerLabel, label, reason: code);
    });
  });

  test('exit statuses keep their wording and Sales labels are untouched', () {
    expect(OrderStatus.outOfStock.retailerLabel, OrderStatus.outOfStock.label);
    expect(
        OrderStatus.quoteExpired.retailerLabel, OrderStatus.quoteExpired.label);
    expect(OrderStatus.allocating.label, 'Đang phân bổ');
    expect(OrderStatus.convertedToPo.label, 'Đã phát hành đơn thực hiện');
  });

  test('retailer timeline shows one step per stage, in order', () {
    TimelineEntry e(int minute, String code, [String label = 'reason']) =>
        TimelineEntry(
            time: DateTime(2026, 11, 25, 8, minute),
            label: label,
            statusCode: code);
    final shown = retailerOrderTimeline(<TimelineEntry>[
      e(0, 'Allocating', 'Sales tạo đơn hỗ trợ'),
      e(1, 'Quoted'),
      e(2, 'PaymentPending'),
      e(3, 'ConvertedToPo'),
      e(4, 'Picking'),
      e(5, 'Issued'),
      e(6, 'Delivering', 'All warehouse shipments were handed to transport'),
      e(7, 'Delivered'),
      e(8, 'Completed'),
      const TimelineEntry(time: null, label: 'Ghi chú khác'),
    ]);
    expect(shown.map((x) => x.label).toList(), <String>[
      'Đã đặt',
      'Chờ xác nhận báo giá',
      'Đã xác nhận báo giá',
      'Đang giao',
      'Đã nhận',
      'Hoàn tất',
      'Ghi chú khác',
    ]);
    expect(shown[2].time, DateTime(2026, 11, 25, 8, 3),
        reason: 'stage time is when it was first reached');
  });

  test('history JSON from the backend keeps the status code', () {
    final entry = TimelineEntry.fromJson(<String, dynamic>{
      'fromStatus': null,
      'toStatus': 'Allocating',
      'reason': 'Sales gửi đơn nháp offline',
      'changedAt': '2026-11-25T01:00:00Z',
    });
    expect(entry.statusCode, 'Allocating');
    expect(
        retailerOrderTimeline(<TimelineEntry>[entry]).single.label, 'Đã đặt');
    final cached = TimelineEntry.fromJson(entry.toJson());
    expect(cached.statusCode, 'Allocating');
  });
}
