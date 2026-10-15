import 'dart:async';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

final networkMonitorProvider =
    StateNotifierProvider<NetworkMonitor, NetworkState>(
        (ref) => NetworkMonitor());

class NetworkState {
  const NetworkState(
      {required this.deviceOnline, this.simulatedOffline = false});

  /// What connectivity_plus reports (wifi / mobile / ethernet).
  final bool deviceOnline;

  /// Demo switch on the Sales home ("Đang online / offline (giả lập)"),
  /// mirrors the prototype's network chip.
  final bool simulatedOffline;

  bool get online => deviceOnline && !simulatedOffline;

  NetworkState copyWith({bool? deviceOnline, bool? simulatedOffline}) =>
      NetworkState(
        deviceOnline: deviceOnline ?? this.deviceOnline,
        simulatedOffline: simulatedOffline ?? this.simulatedOffline,
      );
}

/// Wraps connectivity_plus. Note: "has a network interface" does not
/// guarantee the API is reachable, so the sync service still treats any
/// network [ApiException] as offline and retries with backoff.
class NetworkMonitor extends StateNotifier<NetworkState> {
  NetworkMonitor({Connectivity? connectivity})
      : _connectivity = connectivity ?? Connectivity(),
        super(const NetworkState(deviceOnline: true)) {
    _sub = _connectivity.onConnectivityChanged.listen(_apply);
    unawaited(_connectivity
        .checkConnectivity()
        .then(_apply)
        .catchError((Object _) {}));
  }

  final Connectivity _connectivity;
  StreamSubscription<List<ConnectivityResult>>? _sub;

  void _apply(List<ConnectivityResult> results) {
    if (!mounted) return;
    final online = results.any((r) => r != ConnectivityResult.none);
    if (online != state.deviceOnline) {
      state = state.copyWith(deviceOnline: online);
    }
  }

  bool get isOnline => state.online;

  void setSimulatedOffline(bool value) {
    state = state.copyWith(simulatedOffline: value);
  }

  void toggleSimulated() => setSimulatedOffline(!state.simulatedOffline);

  @override
  void dispose() {
    unawaited(_sub?.cancel());
    super.dispose();
  }
}
