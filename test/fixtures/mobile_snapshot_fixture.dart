Map<String, dynamic> mobileSnapshotFixture() {
  return {
    'version': 'snapshot-test-v1',
    'checksum': 'checksum-test',
    'deltaMode': 'Full',
    'generatedAt': '2026-11-07T03:00:00Z',
    'retailers': [
      {
        'id': 'retailer-1',
        'code': '10000001',
        'name': 'Điểm bán A',
        'address': 'Địa chỉ A',
        'status': 'Active',
        'creditTermDays': 14,
      },
      {
        'id': 'retailer-2',
        'code': '10000002',
        'name': 'Điểm bán B',
        'status': 'Active',
        'creditTermDays': 0,
      },
    ],
    'categories': [
      {
        'id': 'category-1',
        'name': 'Sữa',
        'isActive': true,
      },
    ],
    'products': [
      {
        'id': 'product-1',
        'categoryId': 'category-1',
        'sku': 'SKU001',
        'name': 'Sản phẩm 1',
        'unit': 'Thùng',
        'shelfLifeHours': 720,
        'status': 'Published',
      },
      {
        'id': 'product-2',
        'categoryId': 'category-1',
        'sku': 'SKU002',
        'name': 'Sản phẩm 2',
        'unit': 'Thùng',
        'shelfLifeHours': 720,
        'status': 'Published',
      },
      {
        'id': 'product-draft',
        'categoryId': 'category-1',
        'sku': 'DRAFT',
        'name': 'Chưa bán',
        'unit': 'Thùng',
        'shelfLifeHours': 720,
        'status': 'Draft',
      },
    ],
    'prices': [
      {
        'id': 'price-1',
        'productId': 'product-1',
        'unitPrice': 125000.5,
        'effectiveFrom': '2026-11-01T00:00:00Z',
        'effectiveTo': '2026-12-01T00:00:00Z',
        'isActive': true,
      },
    ],
    'promotions': [
      {
        'id': 'promotion-1',
        'code': 'KM001',
        'name': 'Khuyến mãi nhóm',
        'type': 'Campaign',
        'minimumQuantity': 10,
        'discountPercent': 5,
        'startAt': '2026-11-01T00:00:00Z',
        'endAt': '2026-12-01T00:00:00Z',
        'isActive': true,
        'productIds': [],
        'categoryIds': ['category-1'],
        'retailerIds': ['retailer-1'],
      },
    ],
    'indicativeStock': [
      {
        'productId': 'product-1',
        'indicativeAvailableQuantity': 42.5,
      },
    ],
    'mlors': [],
    'defaultMlor': null,
    'stockDisclaimer': 'Tồn chỉ để tham khảo.',
    'priceDisclaimer': 'Giá chốt sau allocation.',
  };
}
