import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import 'mesh_read_policy.dart';

class MeshConfig {
  // Opt in explicitly for validation builds; production enablement requires the
  // acceptance checks in OFFLINE_MESH_RELAY_PLAN.md.
  static const bool kEnabledAtBuild = bool.fromEnvironment('OFFLINE_MESH_ENABLED');
  static bool enabled = false;
  static int maxTtl = MeshReadPolicy.maxHops;
  static Duration requestTimeout = const Duration(seconds: MeshReadPolicy.maxLifetimeSeconds);
  static int maxPacketSizeBytes = MeshReadPolicy.maxPacketBytes;
  static int maxRetries = 3;
  static const List<Duration> retryDelays = [Duration(seconds: 5), Duration(seconds: 15), Duration(seconds: 30)];
  static int maxForwardAttemptsPerPacket = 3;
  static Duration clockSkewTolerance = const Duration(seconds: 30);
  static Duration routeTtl = const Duration(minutes: 2);
  static Duration relayCacheRetention = const Duration(minutes: 2);
  static Duration maxScanDuration = const Duration(seconds: 90);
  static bool allowMeteredGatewayUpload = false;
  static bool backgroundRelay = false;
  static int _fetchedAt = 0;
  static const _configKey = 'mesh_config_cache';
  static const _consentKey = 'mesh_consent';
  static const _backgroundRelayKey = 'mesh_background_relay';

  /// Continuous runtime lease validation (24 hours).
  static bool get isRuntimeLeaseValid {
    if (!kEnabledAtBuild || !enabled) return false;
    if (_fetchedAt <= 0) return false;
    final age = DateTime.now().millisecondsSinceEpoch ~/ 1000 - _fetchedAt;
    return age >= 0 && age <= 86400;
  }

  static Future<void> loadFromPrefs() async {
    enabled = false;
    final prefs = await SharedPreferences.getInstance();
    try {
      backgroundRelay = prefs.getBool(_backgroundRelayKey) ?? false;
      final data = jsonDecode(prefs.getString(_configKey) ?? '{}') as Map<String, dynamic>;
      final fetchedAt = data['fetchedAt'] as int? ?? 0;
      _fetchedAt = fetchedAt;
      final age = DateTime.now().millisecondsSinceEpoch ~/ 1000 - fetchedAt;
      enabled = kEnabledAtBuild && (prefs.getBool(_consentKey) ?? false) &&
          data['enabled'] == true && data['protocolVersion'] == MeshReadPolicy.version &&
          age >= 0 && age <= 86400;
    } catch (_) { enabled = false; }
  }

  static Future<void> updateRemoteConfig(Map<String, dynamic> data) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_configKey, jsonEncode({
      'enabled': data['enabled'] == true,
      'protocolVersion': data['protocolVersion'],
      'fetchedAt': DateTime.now().millisecondsSinceEpoch ~/ 1000,
    }));
    await loadFromPrefs();
  }

  static Future<void> setConsent(bool consented) async {
    if (!consented) enabled = false;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_consentKey, consented);
    await loadFromPrefs();
  }

  static Future<bool> getConsent() async =>
      (await SharedPreferences.getInstance()).getBool(_consentKey) ?? false;

  static Future<void> setBackgroundRelay(bool enabled) async {
    backgroundRelay = enabled;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_backgroundRelayKey, enabled);
  }

  static Future<bool> getBackgroundRelay() async =>
      (await SharedPreferences.getInstance()).getBool(_backgroundRelayKey) ?? false;
}
