import 'package:shared_preferences/shared_preferences.dart';

/// Persists authentication state between app launches using shared_preferences.
/// Stores: JWT token, citizen/hospital ID, and the user role.
class AuthStorage {
  static const _keyToken = 'auth_token';
  static const _keyCitizenId = 'citizen_id';
  static const _keyRole = 'auth_role'; // 'citizen' | 'hospital'
  static const _keyHospitalId = 'hospital_id';
  static const _keyHospitalName = 'hospital_name';

  // ─── Save citizen session ─────────────────────────────────────────────────
  static Future<void> saveCitizenSession({
    required String token,
    required String citizenId,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_keyToken, token);
    await prefs.setString(_keyCitizenId, citizenId);
    await prefs.setString(_keyRole, 'citizen');
  }

  // ─── Save hospital session ────────────────────────────────────────────────
  static Future<void> saveHospitalSession({
    required String token,
    required String hospitalId,
    required String hospitalName,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_keyToken, token);
    await prefs.setString(_keyHospitalId, hospitalId);
    await prefs.setString(_keyHospitalName, hospitalName);
    await prefs.setString(_keyRole, 'hospital');
  }

  // ─── Read session ─────────────────────────────────────────────────────────
  static Future<String?> getToken() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_keyToken);
  }

  static Future<String?> getCitizenId() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_keyCitizenId);
  }

  static Future<String?> getHospitalId() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_keyHospitalId);
  }

  static Future<String?> getHospitalName() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_keyHospitalName);
  }

  static Future<String?> getRole() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_keyRole);
  }

  // ─── Check if logged in ───────────────────────────────────────────────────
  static Future<bool> hasSession() async {
    final token = await getToken();
    return token != null && token.isNotEmpty;
  }

  // ─── Clear session (logout) ───────────────────────────────────────────────
  static Future<void> clearSession() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_keyToken);
    await prefs.remove(_keyCitizenId);
    await prefs.remove(_keyHospitalId);
    await prefs.remove(_keyHospitalName);
    await prefs.remove(_keyRole);
  }

  // ─── Load full session into memory ────────────────────────────────────────
  static Future<AuthSession?> loadSession() async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString(_keyToken);
    final role = prefs.getString(_keyRole);
    if (token == null || role == null) return null;

    if (role == 'citizen') {
      final citizenId = prefs.getString(_keyCitizenId);
      if (citizenId == null) return null;
      return AuthSession.citizen(token: token, citizenId: citizenId);
    } else if (role == 'hospital') {
      final hospitalId = prefs.getString(_keyHospitalId);
      final hospitalName = prefs.getString(_keyHospitalName) ?? '';
      if (hospitalId == null) return null;
      return AuthSession.hospital(
          token: token, hospitalId: hospitalId, hospitalName: hospitalName);
    }
    return null;
  }
}

/// A simple value object representing a restored session.
class AuthSession {
  final String token;
  final String role; // 'citizen' | 'hospital'
  final String? citizenId;
  final String? hospitalId;
  final String? hospitalName;

  AuthSession._({
    required this.token,
    required this.role,
    this.citizenId,
    this.hospitalId,
    this.hospitalName,
  });

  factory AuthSession.citizen({required String token, required String citizenId}) =>
      AuthSession._(token: token, role: 'citizen', citizenId: citizenId);

  factory AuthSession.hospital({
    required String token,
    required String hospitalId,
    required String hospitalName,
  }) =>
      AuthSession._(
          token: token, role: 'hospital', hospitalId: hospitalId, hospitalName: hospitalName);

  bool get isCitizen => role == 'citizen';
  bool get isHospital => role == 'hospital';
}
