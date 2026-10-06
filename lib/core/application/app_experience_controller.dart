import 'package:flutter/foundation.dart';

enum MobileExperience { sales, retailer, warehouse }

class AppExperienceController extends ChangeNotifier {
  MobileExperience _experience = MobileExperience.sales;

  MobileExperience get experience => _experience;

  void select(MobileExperience experience) {
    if (_experience == experience) return;
    _experience = experience;
    notifyListeners();
  }
}
