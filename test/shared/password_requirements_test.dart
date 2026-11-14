import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:fscm_mobile/shared/widgets/password_requirements.dart';

void main() {
  group('PasswordPolicy', () {
    test('accepts a password meeting every backend rule', () {
      expect(PasswordPolicy.isValid('Fscm@Retail2026'), isTrue);
    });

    test('rejects each missing rule', () {
      expect(PasswordPolicy.isValid('Fscm@Retai1'), isFalse); // 11 chars
      expect(PasswordPolicy.isValid('fscm@retail2026'), isFalse); // no upper
      expect(PasswordPolicy.isValid('FSCM@RETAIL2026'), isFalse); // no lower
      expect(PasswordPolicy.isValid('Fscm@Retailxyz'), isFalse); // no digit
      expect(PasswordPolicy.isValid('FscmRetail2026'), isFalse); // no special
    });

    test('treats Vietnamese letters as letters, like the backend', () {
      // "ă" is a letter, not a special character.
      expect(PasswordPolicy.isValid('Matkhaumoiă2026'), isFalse);
      expect(PasswordPolicy.isValid('Mật khẩu 2026!'), isTrue);
    });
  });

  testWidgets('checklist ticks only the rules the input satisfies',
      (tester) async {
    await tester.pumpWidget(const MaterialApp(
      home: Scaffold(body: PasswordRequirementsChecklist(password: 'abc1')),
    ));
    // lower + digit met; length, upper, special not met.
    expect(find.byIcon(Icons.check_circle), findsNWidgets(2));
    expect(find.byIcon(Icons.radio_button_unchecked), findsNWidgets(3));

    await tester.pumpWidget(const MaterialApp(
      home: Scaffold(
          body: PasswordRequirementsChecklist(password: 'Fscm@Retail2026')),
    ));
    await tester.pumpAndSettle();
    expect(find.byIcon(Icons.check_circle), findsNWidgets(5));
  });
}
