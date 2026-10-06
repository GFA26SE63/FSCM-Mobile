import 'package:flutter/widgets.dart';
import 'package:fmcg/features/warehouse/application/warehouse_controller.dart';

class WarehouseScope extends InheritedNotifier<WarehouseController> {
  const WarehouseScope({
    super.key,
    required WarehouseController controller,
    required super.child,
  }) : super(notifier: controller);

  static WarehouseController of(BuildContext context, {bool listen = true}) {
    if (!listen) {
      final element = context
          .getElementForInheritedWidgetOfExactType<WarehouseScope>();
      return (element!.widget as WarehouseScope).notifier!;
    }
    final scope = context.dependOnInheritedWidgetOfExactType<WarehouseScope>();
    assert(scope != null, 'WarehouseScope not found in the widget tree.');
    return scope!.notifier!;
  }
}
