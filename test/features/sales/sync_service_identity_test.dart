import 'dart:async';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:fscm_mobile/core/auth/session.dart';
import 'package:fscm_mobile/core/auth/user_role.dart';
import 'package:fscm_mobile/core/network/network_monitor.dart';
import 'package:fscm_mobile/data/repositories/auth_repository.dart';
import 'package:fscm_mobile/sync/sync_service.dart';

AppUser _user(String id, {String name = 'Sales'}) =>
    AppUser(id: id, fullName: name, phone: '', role: UserRole.sales);

void main() {
  // MOB-01: login triggers a /me refresh that replaces AppUser with a new
  // object for the same account. The sync service (and its in-flight first
  // snapshot pull) must survive that, but must be rebuilt on account switch.
  test('profile refresh keeps sync service; account switch rebuilds it', () {
    final connectivity = _Connectivity();
    final user = StateProvider<AppUser?>((_) => _user('sales-a'));
    final container = ProviderContainer(overrides: [
      currentUserProvider.overrideWith((ref) => ref.watch(user)),
      networkMonitorProvider
          .overrideWith((ref) => NetworkMonitor(connectivity: connectivity)),
    ]);
    addTearDown(() {
      container.dispose();
      unawaited(connectivity.events.close());
    });
    container.listen(syncServiceProvider, (_, __) {});

    final first = container.read(syncServiceProvider.notifier);
    container.read(user.notifier).state = _user('sales-a', name: 'Renamed');
    expect(identical(container.read(syncServiceProvider.notifier), first),
        isTrue);

    container.read(user.notifier).state = _user('sales-b');
    final second = container.read(syncServiceProvider.notifier);
    expect(identical(second, first), isFalse);
    expect(first.mounted, isFalse);
  });
}

class _Connectivity implements Connectivity {
  final events = StreamController<List<ConnectivityResult>>.broadcast();

  @override
  Future<List<ConnectivityResult>> checkConnectivity() async =>
      [ConnectivityResult.wifi];

  @override
  Stream<List<ConnectivityResult>> get onConnectivityChanged => events.stream;
}
