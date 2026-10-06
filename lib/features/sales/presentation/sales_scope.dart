import 'package:flutter/widgets.dart';
import 'package:fmcg/features/sales/application/sales_controller.dart';

class SalesScope extends InheritedNotifier<SalesController> {
  const SalesScope({
    required SalesController controller,
    required super.child,
    super.key,
  }) : super(notifier: controller);

  static SalesController of(BuildContext context, {bool listen = true}) {
    if (listen) {
      final scope = context.dependOnInheritedWidgetOfExactType<SalesScope>();
      assert(scope != null, 'SalesScope was not found in the widget tree.');
      return scope!.notifier!;
    }

    final element = context
        .getElementForInheritedWidgetOfExactType<SalesScope>();
    final scope = element?.widget as SalesScope?;
    assert(scope != null, 'SalesScope was not found in the widget tree.');
    return scope!.notifier!;
  }
}
