import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:fscm_mobile/data/local/app_database.dart';
import 'package:fscm_mobile/data/local/daos/inventory_snapshot_dao.dart';
import 'package:fscm_mobile/data/local/daos/offline_order_dao.dart';
import 'package:fscm_mobile/data/local/daos/product_dao.dart';
import 'package:fscm_mobile/data/local/daos/promotion_dao.dart';
import 'package:fscm_mobile/data/local/daos/retailer_dao.dart';
import 'package:fscm_mobile/data/local/daos/sync_state_dao.dart';

final appDatabaseProvider = Provider<AppDatabase>((ref) {
  final db = AppDatabase();
  ref.onDispose(() {
    db.close();
  });
  return db;
});

final syncStateDaoProvider = Provider<SyncStateDao>(
    (ref) => SyncStateDao(ref.watch(appDatabaseProvider)));
final retailerDaoProvider =
    Provider<RetailerDao>((ref) => RetailerDao(ref.watch(appDatabaseProvider)));
final productDaoProvider =
    Provider<ProductDao>((ref) => ProductDao(ref.watch(appDatabaseProvider)));
final promotionDaoProvider = Provider<PromotionDao>(
    (ref) => PromotionDao(ref.watch(appDatabaseProvider)));
final inventorySnapshotDaoProvider = Provider<InventorySnapshotDao>(
    (ref) => InventorySnapshotDao(ref.watch(appDatabaseProvider)));
final offlineOrderDaoProvider = Provider<OfflineOrderDao>(
    (ref) => OfflineOrderDao(ref.watch(appDatabaseProvider)));
