import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';

class MeshConfig {
  static const bool kEnabledAtBuild = true;        // compile-time kill switch
  static bool enabled = false;                     // remote + consent gated, default OFF
  static int maxTtl = 8;
  static Duration requestTimeout = const Duration(seconds: 120);
  static int maxPacketSizeBytes = 128 * 1024;
  static int maxRetries = 3;
  static const List<Duration> retryDelays = [
    Duration(seconds: 5),
    Duration(seconds: 15),
    Duration(seconds: 30)
  ];
  static int maxForwardAttemptsPerPacket = 3;
  static Duration clockSkewTolerance = const Duration(minutes: 5);
  static Duration routeTtl = const Duration(minutes: 5);
  static Duration relayCacheRetention = const Duration(minutes: 30);
  static Duration maxScanDuration = const Duration(seconds: 90);
  static bool allowMeteredGatewayUpload = false;   // §24

  static const String _kConfigCacheKey = 'mesh_config_cache';
  static const String _kConsentKey = 'mesh_consent';

  /// Initialize the configuration from cached values and consent settings.
  static Future<void> loadFromPrefs() async {
    final prefs = await SharedPreferences.getInstance();
    
    // Load remote config from cache
    final cachedStr = prefs.getString(_kConfigCacheKey);
    if (cachedStr != null) {
      try {
        final Map<String, dynamic> data = jsonDecode(cachedStr);
        _applyJson(data);
      } catch (_) {
        // Fallback to default config if decode fails
      }
    }

    // Load user consent
    final userConsented = prefs.getBool(_kConsentKey) ?? false;
    
    // Evaluate if mesh is enabled: compile flag AND user consent
    // Wait, the plan says: remote + consent gated. Let's make sure enabled is evaluated correctly.
    enabled = kEnabledAtBuild && userConsented;
  }

  /// Save remote configuration response to cache and update active config.
  static Future<void> updateRemoteConfig(Map<String, dynamic> data) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_kConfigCacheKey, jsonEncode(data));
    
    _applyJson(data);
    await loadFromPrefs(); // re-evaluates 'enabled' status with consent
  }

  /// Update user consent status.
  static Future<void> setConsent(bool consented) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_kConsentKey, consented);
    await loadFromPrefs();
  }

  /// Get current user consent status.
  static Future<bool> getConsent() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_kConsentKey) ?? false;
  }

  static void _applyJson(Map<String, dynamic> data) {
    if (data.containsKey('maxTtl')) {
      maxTtl = data['maxTtl'] as int;
    }
    if (data.containsKey('requestTimeoutSeconds')) {
      requestTimeout = Duration(seconds: data['requestTimeoutSeconds'] as int);
    }
    if (data.containsKey('maxPacketSizeBytes')) {
      maxPacketSizeBytes = data['maxPacketSizeBytes'] as int;
    } else if (data.containsKey('maxPacketSizeKb')) {
      maxPacketSizeBytes = (data['maxPacketSizeKb'] as int) * 1024;
    }
    if (data.containsKey('maxRetries')) {
      maxRetries = data['maxRetries'] as int;
    }
    if (data.containsKey('maxForwardAttemptsPerPacket')) {
      maxForwardAttemptsPerPacket = data['maxForwardAttemptsPerPacket'] as int;
    }
    if (data.containsKey('allowMeteredGatewayUpload')) {
      allowMeteredGatewayUpload = data['allowMeteredGatewayUpload'] as bool;
    }
  }
}
