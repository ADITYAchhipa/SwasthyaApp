import 'dart:io';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:swasthya_tap/services/api_service.dart';

class NetworkManager {
  static final NetworkManager _instance = NetworkManager._internal();
  static NetworkManager get instance => _instance;

  NetworkManager._internal();

  DateTime? _lastPingTime;
  bool _lastPingResult = false;

  /// Check if the internet is actually available by pinging the backend server.
  /// Result is cached for 15 seconds to prevent hammering the server.
  Future<bool> isInternetAvailable() async {
    final now = DateTime.now();
    if (_lastPingTime != null && now.difference(_lastPingTime!) < const Duration(seconds: 15)) {
      return _lastPingResult;
    }

    try {
      final results = await Connectivity().checkConnectivity();
      final hasInterface = results.isNotEmpty && !results.contains(ConnectivityResult.none);
      if (!hasInterface) {
        _lastPingTime = now;
        _lastPingResult = false;
        return false;
      }

      // Perform a real ping probe
      final reachable = await ApiService.isServerReachable();
      _lastPingTime = now;
      _lastPingResult = reachable;
      return reachable;
    } catch (_) {
      _lastPingTime = now;
      _lastPingResult = false;
      return false;
    }
  }

  /// Returns true if the active connection is metered (e.g. mobile data).
  Future<bool> isMeteredConnection() async {
    try {
      final results = await Connectivity().checkConnectivity();
      return results.contains(ConnectivityResult.mobile);
    } catch (_) {
      return false;
    }
  }

  /// Checks if Bluetooth is turned on and permitted.
  Future<bool> isBluetoothAvailable() async {
    if (!Platform.isAndroid) return false;
    // We check if the Bluetooth permissions are granted.
    // In a real device we would check Bluetooth State, but since that requires a heavy plugin,
    // we use permission state and assume hardware state is enabled if permitted.
    final hasBtConnect = await Permission.bluetoothConnect.isGranted;
    final hasBtScan = await Permission.bluetoothScan.isGranted;
    return hasBtConnect && hasBtScan;
  }

  /// Checks if all prerequisites for Nearby Connections are met (permissions + platform).
  Future<bool> isNearbyTransportAvailable() async {
    if (!Platform.isAndroid) return false;
    
    final btConnect = await Permission.bluetoothConnect.isGranted;
    final btScan = await Permission.bluetoothScan.isGranted;
    final btAdvertise = await Permission.bluetoothAdvertise.isGranted;
    
    // Nearby connections requires location on Android
    final location = await Permission.location.isGranted;

    return btConnect && btScan && btAdvertise && location;
  }
}
