import 'package:flutter_test/flutter_test.dart';

import 'package:fscm_mobile/core/auth/session.dart';
import 'package:fscm_mobile/data/models/retailer_declaration.dart';

void main() {
  test('AppUser reads backend scope and keeps it after persistence', () {
    final user = AppUser.fromJson(<String, dynamic>{
      'id': 'sales-id',
      'fullName': 'Nguyễn Sales',
      'role': 'Sales',
      'scope': <String, dynamic>{
        'regionIds': <String>['region-1'],
        'salesGroupIds': <String>['group-1'],
      },
      'scopeLabels': <String, dynamic>{
        'regions': <Map<String, dynamic>>[
          <String, dynamic>{
            'id': 'region-1',
            'code': 'HCM',
            'name': 'Hồ Chí Minh'
          }
        ],
        'salesGroups': <Map<String, dynamic>>[
          <String, dynamic>{
            'id': 'group-1',
            'code': 'Q12-A',
            'name': 'Quận 12 A'
          }
        ],
      },
    });

    final restored = AppUser.fromJson(user.toJson());

    expect(restored.salesGroupIds, <String>['group-1']);
    expect(restored.regionIds, <String>['region-1']);
    expect(restored.salesGroup, 'Q12-A');
    expect(restored.areaName, 'Hồ Chí Minh');
  });

  test('declaration input matches backend DeclareRetailerRequest', () {
    const input = RetailerDeclarationInput(
      name: 'Tạp hóa An Phú',
      contactName: 'Nguyễn Văn An',
      phone: '0909000000',
      email: 'an@example.com',
      address: '',
      retailerType: RetailerTypeOption.miniSupermarket,
      forecastRevenue: 35000000,
      storeSizeSquareMeters: 40,
      purchasingCapacity: 80,
      purchaseFrequencyPerMonth: 8,
      assessmentNote: '',
      mlorDeclarations: <MlorDeclaration>[
        MlorDeclaration(productCategoryId: 'cat-1', minimumLifeRatio: 0.6),
      ],
      submitForReview: true,
    );

    final created = input.toJson(regionId: 'region-1', salesGroupId: 'group-1');
    final updated = input.toJson();

    expect(created['regionId'], 'region-1');
    expect(created['salesGroupId'], 'group-1');
    expect(created.containsKey('requestedCreditTermDays'), isFalse);
    expect(created['retailerType'], 'MiniSupermarket');
    expect(created['address'], isNull);
    expect(created['mlorDeclarations'], <Map<String, dynamic>>[
      <String, dynamic>{
        'productCategoryId': 'cat-1',
        'productId': null,
        'minimumLifeRatio': 0.6,
        'minimumLifeHours': null,
      }
    ]);
    expect(updated.containsKey('regionId'), isFalse);
  });

  test('RetailerDetails response maps status, type and MLOR', () {
    final d = RetailerDeclaration.fromJson(<String, dynamic>{
      'id': 'r-1',
      'code': 'KB-0100',
      'name': 'Tạp hóa An Phú',
      'status': 'Rejected',
      'retailerType': 'ConvenienceStore',
      'reviewReason': 'Thiếu email',
      'storeSizeCategory': 'M',
      'potentialClass': 'B',
      'purchaseFrequencyPerMonth': 8,
      'mlorDeclarations': <Map<String, dynamic>>[
        <String, dynamic>{
          'scope': 'Category',
          'productCategoryId': 'cat-1',
          'categoryCode': 'CAT-02',
          'categoryName': 'Sữa',
          'minimumLifeRatio': 0.35,
        }
      ],
    });

    expect(d.status, DeclarationStatus.rejected);
    expect(d.status.isEditable, isTrue);
    expect(d.retailerType, RetailerTypeOption.convenienceStore);
    expect(d.mlorDeclarations.single.productCategoryId, 'cat-1');
    expect(d.mlorDeclarations.single.isSku, isFalse);
  });
}
