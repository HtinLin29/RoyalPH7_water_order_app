import 'dart:async';

import 'package:flutter/foundation.dart';

import '../services/connectivity_service.dart';

enum ConnectivityBannerState { hidden, offline, connected }

class ConnectivityProvider extends ChangeNotifier {
  ConnectivityProvider() {
    _startMonitoring();
  }

  Timer? _timer;
  ConnectivityBannerState _bannerState = ConnectivityBannerState.hidden;
  bool _isOnline = true;
  VoidCallback? _onReconnect;

  ConnectivityBannerState get bannerState => _bannerState;
  bool get isOnline => _isOnline;

  void setOnReconnect(VoidCallback? callback) {
    _onReconnect = callback;
  }

  void _startMonitoring() {
    _checkConnectivity();
    _timer = Timer.periodic(const Duration(seconds: 5), (_) {
      _checkConnectivity();
    });
  }

  Future<void> _checkConnectivity() async {
    final online = await ConnectivityService.isConnected();
    if (online == _isOnline) return;

    final wasOffline = !_isOnline;
    _isOnline = online;

    if (!online) {
      _bannerState = ConnectivityBannerState.offline;
      notifyListeners();
      return;
    }

    if (wasOffline) {
      _bannerState = ConnectivityBannerState.connected;
      notifyListeners();
      _onReconnect?.call();
      Future.delayed(const Duration(seconds: 2), () {
        if (_isOnline && _bannerState == ConnectivityBannerState.connected) {
          _bannerState = ConnectivityBannerState.hidden;
          notifyListeners();
        }
      });
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }
}
