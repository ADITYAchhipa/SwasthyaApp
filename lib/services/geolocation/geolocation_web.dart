// ignore: avoid_web_libraries_in_flutter
import 'dart:async';
import 'dart:html' as html;
import 'package:flutter/foundation.dart';

/// Returns user's [lat, lng] using browser Geolocation API (Web only).
/// Tries high accuracy first, falling back gracefully to network/Wi-Fi positioning.
Future<({double lat, double lng})?> getUserLocation() async {
  try {
    // 1. Try high accuracy first
    final pos = await html.window.navigator.geolocation.getCurrentPosition(
      enableHighAccuracy: true,
      timeout: const Duration(seconds: 6),
      maximumAge: const Duration(minutes: 1),
    );
    final lat = pos.coords?.latitude?.toDouble();
    final lng = pos.coords?.longitude?.toDouble();
    if (lat != null && lng != null) {
      debugPrint('Web Geolocation (High Accuracy): $lat, $lng');
      return (lat: lat, lng: lng);
    }
  } catch (e) {
    debugPrint('Web Geolocation high accuracy failed/timed out: $e, trying standard...');
  }

  try {
    // 2. Fallback to standard network accuracy (Wi-Fi / ISP)
    final pos = await html.window.navigator.geolocation.getCurrentPosition(
      enableHighAccuracy: false,
      timeout: const Duration(seconds: 8),
      maximumAge: const Duration(minutes: 5),
    );
    final lat = pos.coords?.latitude?.toDouble();
    final lng = pos.coords?.longitude?.toDouble();
    if (lat != null && lng != null) {
      debugPrint('Web Geolocation (Standard Accuracy): $lat, $lng');
      return (lat: lat, lng: lng);
    }
  } catch (e) {
    debugPrint('Web Geolocation fallback failed: $e');
  }

  return null;
}

/// Continuous location stream for Web
Stream<({double lat, double lng})> watchUserLocation() {
  final controller = StreamController<({double lat, double lng})>.broadcast();
  try {
    html.window.navigator.geolocation.watchPosition(
      enableHighAccuracy: true,
      maximumAge: const Duration(seconds: 10),
    ).listen((pos) {
      final lat = pos.coords?.latitude?.toDouble();
      final lng = pos.coords?.longitude?.toDouble();
      if (lat != null && lng != null) {
        controller.add((lat: lat, lng: lng));
      }
    }, onError: (err) {
      debugPrint('Web watchPosition error: $err');
    });
  } catch (e) {
    debugPrint('Web watchPosition exception: $e');
  }
  return controller.stream;
}

