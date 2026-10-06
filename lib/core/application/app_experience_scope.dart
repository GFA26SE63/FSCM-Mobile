import 'package:flutter/widgets.dart';
import 'package:fmcg/core/application/app_experience_controller.dart';

class AppExperienceScope extends InheritedNotifier<AppExperienceController> {
  const AppExperienceScope({
    required AppExperienceController controller,
    required super.child,
    super.key,
  }) : super(notifier: controller);

  static AppExperienceController of(
    BuildContext context, {
    bool listen = true,
  }) {
    if (listen) {
      final scope = context
          .dependOnInheritedWidgetOfExactType<AppExperienceScope>();
      assert(scope != null, 'AppExperienceScope was not found.');
      return scope!.notifier!;
    }
    final element = context
        .getElementForInheritedWidgetOfExactType<AppExperienceScope>();
    final scope = element?.widget as AppExperienceScope?;
    assert(scope != null, 'AppExperienceScope was not found.');
    return scope!.notifier!;
  }
}
