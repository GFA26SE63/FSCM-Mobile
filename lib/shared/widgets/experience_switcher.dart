import 'package:flutter/material.dart';
import 'package:fmcg/core/application/app_experience_controller.dart';
import 'package:fmcg/core/application/app_experience_scope.dart';

class ExperienceSwitcher extends StatelessWidget {
  const ExperienceSwitcher({super.key});

  @override
  Widget build(BuildContext context) {
    final controller = AppExperienceScope.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Trải nghiệm demo',
          style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700),
        ),
        const SizedBox(height: 8),
        SizedBox(
          width: double.infinity,
          child: SegmentedButton<MobileExperience>(
            segments: const [
              ButtonSegment(
                value: MobileExperience.sales,
                icon: Icon(Icons.badge_outlined),
                label: Text('Sales'),
              ),
              ButtonSegment(
                value: MobileExperience.retailer,
                icon: Icon(Icons.storefront_outlined),
                label: Text('Retailer'),
              ),
              ButtonSegment(
                value: MobileExperience.warehouse,
                icon: Icon(Icons.warehouse_outlined),
                label: Text('Kho'),
              ),
            ],
            selected: {controller.experience},
            onSelectionChanged: (value) => controller.select(value.first),
            showSelectedIcon: false,
          ),
        ),
      ],
    );
  }
}
