import 'package:flutter/foundation.dart';
import 'package:fmcg/features/retailer/data/demo_retailer_data.dart';
import 'package:fmcg/features/retailer/domain/retailer_models.dart';
import 'package:fmcg/shared/domain/fscm_models.dart';

class RetailerController extends ChangeNotifier {
  bool isAuthenticated = false;
  int currentTab = 0;
  int loyaltyPoints = DemoRetailerData.retailer.points;

  final Retailer retailer = DemoRetailerData.retailer;
  final List<SalesOrder> orders = DemoRetailerData.orders().toList();
  final List<FscmNotification> notifications = DemoRetailerData.notifications()
      .toList();
  final List<LoyaltyTransaction> loyaltyHistory =
      DemoRetailerData.loyaltyHistory().toList();
  final List<RetailerComplaint> complaints = [];
  final Map<String, Set<String>> _scannedLabels = {};

  int get unreadCount => notifications.where((item) => !item.isRead).length;
  List<SalesOrder> get outstandingOrders => orders
      .where(
        (order) =>
            order.payment.method == PaymentMethod.credit &&
            !order.payment.isPaid,
      )
      .toList();
  int get outstandingBalance => outstandingOrders.fold(
    0,
    (sum, order) => sum + order.total - order.payment.paidAmount,
  );

  void login() {
    isAuthenticated = true;
    notifyListeners();
  }

  void logout() {
    isAuthenticated = false;
    currentTab = 0;
    notifyListeners();
  }

  void setTab(int index) {
    currentTab = index;
    notifyListeners();
  }

  SalesOrder? orderById(String? id) {
    for (final order in orders) {
      if (order.id == id) return order;
    }
    return null;
  }

  List<BatchAllocation> labelsFor(SalesOrder order) => order.lines
      .expand((line) => line.batches)
      .where((batch) => batch.labelCode != null)
      .toList();

  Set<String> scannedFor(String orderId) =>
      _scannedLabels.putIfAbsent(orderId, () => <String>{});

  LabelScanResult scanLabel(SalesOrder order, String code) {
    if (code == 'TEM-OTHER-001') {
      return LabelScanResult.wrongRetailer;
    }
    final labels = labelsFor(order);
    final match = labels.where((batch) => batch.labelCode == code);
    if (match.isEmpty) {
      return LabelScanResult.unknown;
    }
    if (scannedFor(order.id).contains(code)) {
      return LabelScanResult.alreadyScanned;
    }
    scannedFor(order.id).add(code);
    notifyListeners();
    return LabelScanResult.matched;
  }

  LabelScanResult scanNext(SalesOrder order) {
    final next = labelsFor(order)
        .where((batch) => !scannedFor(order.id).contains(batch.labelCode))
        .firstOrNull;
    if (next?.labelCode == null) return LabelScanResult.alreadyScanned;
    return scanLabel(order, next!.labelCode!);
  }

  bool allLabelsScanned(SalesOrder order) =>
      labelsFor(order).isNotEmpty &&
      scannedFor(order.id).length == labelsFor(order).length;

  void confirmReceipt(SalesOrder order) {
    if (!allLabelsScanned(order)) return;
    final index = orders.indexWhere((item) => item.id == order.id);
    if (index < 0) return;
    final paid = order.payment.method == PaymentMethod.cod
        ? order.payment.copyWith(
            isPaid: true,
            paidAmount: order.total,
            paidAt: '27/09',
          )
        : order.payment;
    orders[index] = order.copyWith(
      status: SalesOrderStatus.delivered,
      payment: paid,
    );
    if (paid.isPaid) {
      final earned = order.total ~/ 100000;
      loyaltyPoints += earned;
      loyaltyHistory.insert(
        0,
        LoyaltyTransaction(
          date: '27/09',
          description: '${order.id} · đã nhận và thanh toán',
          points: earned,
        ),
      );
    }
    notifications.insert(
      0,
      FscmNotification(
        id: DateTime.now().microsecondsSinceEpoch,
        message: 'Đã xác nhận nhận đơn ${order.id}.',
        time: '10:32 27/09',
        orderId: order.id,
        isRead: true,
      ),
    );
    notifyListeners();
  }

  void submitComplaint(RetailerComplaint complaint) {
    complaints.insert(0, complaint);
    notifyListeners();
  }

  void markNotificationRead(int id) {
    final index = notifications.indexWhere((item) => item.id == id);
    if (index < 0) return;
    notifications[index] = notifications[index].markRead();
    notifyListeners();
  }

  void redeemPoints(int points) {
    if (points <= 0 || points > loyaltyPoints) return;
    loyaltyPoints -= points;
    loyaltyHistory.insert(
      0,
      LoyaltyTransaction(
        date: '27/09',
        description: 'Đổi điểm lấy ưu đãi',
        points: -points,
      ),
    );
    notifyListeners();
  }
}
