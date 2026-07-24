import 'dart:async';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Service to monitor device connectivity.
class ConnectivityService {
  final Connectivity _connectivity = Connectivity();

  Stream<List<ConnectivityResult>> get onConnectivityChanged =>
      _connectivity.onConnectivityChanged;

  Future<bool> checkConnected() async {
    final results = await _connectivity.checkConnectivity();
    return isOnlineFromResults(results);
  }

  static bool isOnlineFromResults(List<ConnectivityResult> results) {
    return results.any((r) => r != ConnectivityResult.none);
  }
}

final connectivityServiceProvider = Provider<ConnectivityService>((ref) {
  return ConnectivityService();
});

class IsOnlineNotifier extends StateNotifier<bool> {
  StreamSubscription<List<ConnectivityResult>>? _subscription;

  IsOnlineNotifier(ConnectivityService service) : super(true) {
    _init(service);
  }

  Future<void> _init(ConnectivityService service) async {
    final initialOnline = await service.checkConnected();
    state = initialOnline;

    _subscription = service.onConnectivityChanged.listen((results) {
      final isOnline = ConnectivityService.isOnlineFromResults(results);
      if (state != isOnline) {
        state = isOnline;
      }
    });
  }

  @override
  void dispose() {
    _subscription?.cancel();
    super.dispose();
  }
}

final isOnlineProvider = StateNotifierProvider<IsOnlineNotifier, bool>((ref) {
  final service = ref.watch(connectivityServiceProvider);
  return IsOnlineNotifier(service);
});

final isOfflineProvider = Provider<bool>((ref) {
  return !ref.watch(isOnlineProvider);
});
