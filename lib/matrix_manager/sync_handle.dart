import 'dart:async';

import 'package:connectivity/connectivity.dart';
import 'package:flutter/foundation.dart';

import 'account_controller.dart';

class SyncHandle {
  bool _isSyncing = true;
  bool _isConnected = true;

  static final _initialSyncBackoff = const Duration(milliseconds: 300);

  Duration _syncBackoff = _initialSyncBackoff;

  final AccountController accountController;

  SyncHandle(this.accountController) {
    _start();
  }

  void stop() {
    _isSyncing = false;
  }

  void _start() async {
    final subscription = Connectivity().onConnectivityChanged.listen((ConnectivityResult result) {
      _isConnected = result != ConnectivityResult.none;
    });

    while (_isSyncing) {
      if (_isConnected) {
        await accountController.sync(longPollingTimeout: 20000).then((_) {
          _syncBackoff = _initialSyncBackoff;
        }).catchError((error) {
          debugPrint('sync failed (throttle ${_syncBackoff.inSeconds}s): ${error.toString()} ');
          if (_syncBackoff.inSeconds < 30) {
            _syncBackoff = _syncBackoff * 2.0;
          }
        });
        await Future.delayed(_syncBackoff);
      } else {
        await Future.delayed(const Duration(seconds: 1));
      }
    }

    subscription.cancel();
  }
}
