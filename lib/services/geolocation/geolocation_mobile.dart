import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:geolocator/geolocator.dart';
import 'package:geolocator_android/geolocator_android.dart';
import 'package:permission_handler/permission_handler.dart';

/// Fetches the user's high-precision real GPS coordinates on Android / iOS.
/// Uses Google Play Services Fused Location Provider with best accuracy.
Future<({double lat, double lng})?> getUserLocation() async {
  try {
    // 1. Proactively request location permissions
    var permStatus = await Permission.locationWhenInUse.status;
    if (!permStatus.isGranted) {
      permStatus = await Permission.locationWhenInUse.request();
      if (!permStatus.isGranted) {
        permStatus = await Permission.location.request();
      }
    }

    LocationPermission geoPerm = await Geolocator.checkPermission();
    if (geoPerm == LocationPermission.denied) {
      geoPerm = await Geolocator.requestPermission();
    }

    if (geoPerm == LocationPermission.deniedForever) {
      debugPrint('GeolocationMobile: Permission permanently denied');
      return null;
    }

    bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      debugPrint('GeolocationMobile: Location services are disabled');
      // Try last known as fallback
      try {
        final lastPos = await Geolocator.getLastKnownPosition();
        if (lastPos != null) {
          return (lat: lastPos.latitude, lng: lastPos.longitude);
        }
      } catch (_) {}
      return null;
    }

    // 2. High-precision Android Fused Location Provider request
    final LocationSettings locationSettings;
    if (defaultTargetPlatform == TargetPlatform.android) {
      locationSettings = AndroidSettings(
        accuracy: LocationAccuracy.best,
        distanceFilter: 0,
        forceLocationManager: false,
        intervalDuration: const Duration(milliseconds: 500),
        timeLimit: const Duration(seconds: 15),
      );
    } else {
      locationSettings = const LocationSettings(
        accuracy: LocationAccuracy.best,
        timeLimit: Duration(seconds: 15),
      );
    }

    try {
      final position = await Geolocator.getCurrentPosition(
        locationSettings: locationSettings,
      );
      debugPrint('GeolocationMobile: Pinpoint GPS fix -> ${position.latitude}, ${position.longitude} (accuracy: ${position.accuracy}m)');
      return (lat: position.latitude, lng: position.longitude);
    } catch (e) {
      debugPrint('GeolocationMobile: CurrentPosition timeout/failed ($e), checking last known...');
    }

    // 3. Fallback: Last known hardware GPS position
    final lastPos = await Geolocator.getLastKnownPosition();
    if (lastPos != null) {
      debugPrint('GeolocationMobile: LastKnown fix -> ${lastPos.latitude}, ${lastPos.longitude}');
      return (lat: lastPos.latitude, lng: lastPos.longitude);
    }

    return null;
  } catch (e) {
    debugPrint('GeolocationMobile unexpected error: $e');
    return null;
  }
}

/// Continuous location stream for Mobile
Stream<({double lat, double lng})> watchUserLocation() {
  final controller = StreamController<({double lat, double lng})>.broadcast();
  try {
    final LocationSettings locationSettings;
    if (defaultTargetPlatform == TargetPlatform.android) {
      locationSettings = AndroidSettings(
        accuracy: LocationAccuracy.best,
        distanceFilter: 2,
        intervalDuration: const Duration(seconds: 1),
      );
    } else {
      locationSettings = const LocationSettings(
        accuracy: LocationAccuracy.best,
        distanceFilter: 2,
      );
    }

    Geolocator.getPositionStream(locationSettings: locationSettings).listen((pos) {
      controller.add((lat: pos.latitude, lng: pos.longitude));
    }, onError: (err) {
      debugPrint('Mobile getPositionStream error: $err');
    });
  } catch (e) {
    debugPrint('Mobile getPositionStream exception: $e');
  }
  return controller.stream;
}
