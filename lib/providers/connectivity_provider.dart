import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Whether the device is on Wi-Fi or Ethernet (unmetered for image auto-load).
///
/// Web always returns `true` (browser has no reliable cellular distinction).
final wifiConnectedProvider = StreamProvider<bool>((ref) async* {
  if (kIsWeb) {
    yield true;
    return;
  }

  final connectivity = Connectivity();
  yield _isWifiOrEthernet(await connectivity.checkConnectivity());

  await for (final results in connectivity.onConnectivityChanged) {
    yield _isWifiOrEthernet(results);
  }
});

bool _isWifiOrEthernet(List<ConnectivityResult> results) {
  return results.any(
    (result) =>
        result == ConnectivityResult.wifi ||
        result == ConnectivityResult.ethernet,
  );
}
