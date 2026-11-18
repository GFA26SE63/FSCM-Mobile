import 'package:flutter_test/flutter_test.dart';

import 'package:fscm_mobile/core/network/api_exception.dart';
import 'package:fscm_mobile/features/sales/declare/declaration_errors.dart';

void main() {
  test('duplicate phone maps to a Vietnamese error on the phone field', () {
    final e = ApiException.fromProblem(409, <String, dynamic>{
      'title': 'any server text',
      'detail': 'any server text',
      'code': 'conflict',
      'field': 'phone',
      'errors': <String, dynamic>{
        'phone': <String>['any server text']
      },
    });
    final conflict = declarationConflictOf(e)!;
    expect(conflict.field, 'phone');
    expect(conflict.message, startsWith('Số điện thoại này đã được dùng'));
  });

  test('older backend English text still gets a Vietnamese message', () {
    final e = ApiException.fromProblem(409, <String, dynamic>{
      'title': 'Phone or email is already assigned to another user account.',
      'code': 'conflict',
    });
    final conflict = declarationConflictOf(e)!;
    expect(conflict.field, isNull);
    expect(conflict.message, contains('Số điện thoại hoặc email'));
  });

  test('non-conflict errors are left to the default handling', () {
    final e = ApiException.fromProblem(400, <String, dynamic>{
      'title': 'Validation failed',
    });
    expect(declarationConflictOf(e), isNull);
  });
}
