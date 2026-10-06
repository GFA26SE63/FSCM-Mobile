import 'package:flutter/widgets.dart';
import 'package:fmcg/features/retailer/application/retailer_controller.dart';

class RetailerScope extends InheritedNotifier<RetailerController> {
  const RetailerScope({
    required RetailerController controller,
    required super.child,
    super.key,
  }) : super(notifier: controller);

  static RetailerController of(BuildContext context, {bool listen = true}) {
    if (listen) {
      final scope = context.dependOnInheritedWidgetOfExactType<RetailerScope>();
      assert(scope != null, 'RetailerScope was not found.');
      return scope!.notifier!;
    }
    final element = context
        .getElementForInheritedWidgetOfExactType<RetailerScope>();
    final scope = element?.widget as RetailerScope?;
    assert(scope != null, 'RetailerScope was not found.');
    return scope!.notifier!;
  }
}
