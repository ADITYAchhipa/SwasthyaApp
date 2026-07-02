import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import '../models/models.dart';
import 'auth_storage.dart';

/// Centralized HTTP client for all SwasthyaTap backend calls.
/// Falls back gracefully to mock data if the server is unreachable.
class ApiService {
  // ─── Base URL Configuration ───────────────────────────────────────────────
  // For Android Emulator → 10.0.2.2 maps to host machine's localhost
  // For Web / Desktop → localhost
  // For iOS Simulator → localhost
  static String get baseUrl {
    // Set this to true to connect to your Vercel deployment, false for localhost
    const bool useProduction = true;

    if (useProduction) {
      return 'https://swasthya-114dgkwnr-adityas-projects-b63fea21.vercel.app/api';
    }

    if (kIsWeb) return 'http://localhost:3000/api';
    try {
      if (Platform.isAndroid) return 'http://10.0.2.2:3000/api';
    } catch (_) {}
    return 'http://localhost:3000/api';
  }

  // ─── Auth Token (in-memory cache + persisted to disk) ────────────────────
  static String? _authToken;
  static String? _citizenId;

  /// Call once at app startup (in SplashScreen) to restore saved session.
  static Future<AuthSession?> init() async {
    final session = await AuthStorage.loadSession();
    if (session != null) {
      _authToken = session.token;
      _citizenId = session.citizenId;
      debugPrint('ApiService: Restored ${session.role} session for ${session.citizenId ?? session.hospitalId}');
    }
    return session;
  }

  static void setToken(String token, String citizenId) {
    _authToken = token;
    _citizenId = citizenId;
    // Also persist to disk so the session survives app restarts
    AuthStorage.saveCitizenSession(token: token, citizenId: citizenId);
  }

  static void setHospitalToken(String token, String hospitalId, String hospitalName) {
    _authToken = token;
    _citizenId = null;
    AuthStorage.saveHospitalSession(
      token: token,
      hospitalId: hospitalId,
      hospitalName: hospitalName,
    );
  }

  static void clearToken() {
    _authToken = null;
    _citizenId = null;
    AuthStorage.clearSession();
  }

  static String? get currentCitizenId => _citizenId;
  static bool get isLoggedIn => _authToken != null;

  // ─── HTTP Headers ─────────────────────────────────────────────────────────
  static Map<String, String> get _headers => {
        'Content-Type': 'application/json',
        if (_authToken != null) 'Authorization': 'Bearer $_authToken',
      };

  // ─── Connectivity Check ───────────────────────────────────────────────────
  static Future<bool> isServerReachable() async {
    try {
      final response = await http
          .get(Uri.parse('$baseUrl/ping'))
          .timeout(const Duration(seconds: 3));
      return response.statusCode == 200;
    } catch (_) {
      return false;
    }
  }

  // ══════════════════════════════════════════════════════════════════════════
  // AUTH ENDPOINTS
  // ══════════════════════════════════════════════════════════════════════════

  /// Send OTP to a citizen's email address.
  /// Returns: { success, message, devOtp? }
  static Future<Map<String, dynamic>> sendOtp(String email) async {
    try {
      final cleanEmail = email.trim().toLowerCase();
      final response = await http
          .post(
            Uri.parse('$baseUrl/auth/send-otp'),
            headers: _headers,
            body: jsonEncode({'email': cleanEmail}),
          )
          .timeout(const Duration(seconds: 10));

      final body = jsonDecode(response.body) as Map<String, dynamic>;
      return body;
    } catch (e) {
      debugPrint('sendOtp error: $e');
      // Offline fallback — simulate sending
      return {
        'success': true,
        'message': 'OTP sent (offline simulation)',
        'devOtp': '1234',
        'offline': true,
      };
    }
  }

  /// Verify OTP and log in / register citizen.
  /// Returns: { success, token, citizen, isNewUser }
  static Future<Map<String, dynamic>> verifyOtp(String email, String otp) async {
    try {
      final cleanEmail = email.trim().toLowerCase();
      final response = await http
          .post(
            Uri.parse('$baseUrl/auth/verify-otp'),
            headers: _headers,
            body: jsonEncode({'email': cleanEmail, 'otp': otp}),
          )
          .timeout(const Duration(seconds: 10));

      final body = jsonDecode(response.body) as Map<String, dynamic>;

      if (body['success'] == true && body['token'] != null) {
        final citizenData = body['citizen'] as Map<String, dynamic>;
        setToken(body['token'] as String, citizenData['id'] as String);
        return {
          'success': true,
          'isNewUser': body['isNewUser'] == true,
          'token': body['token'] as String,
          'citizen': _parseCitizen(citizenData),
        };
      }
      return body;
    } catch (e) {
      debugPrint('verifyOtp error: $e');
      // Offline fallback — accept any OTP and return Rajesh Kumar's profile
      if (otp == '1234') {
        setToken('offline_token', 'x7k9m2');
        return {
          'success': true,
          'isNewUser': false,
          'token': 'offline_token',
          'offline': true,
          'citizen': _parseCitizen(_mockCitizenJson('x7k9m2')),
        };
      }
      return {'success': false, 'message': 'Incorrect OTP'};
    }
  }

  /// Send OTP for hospital login.
  static Future<Map<String, dynamic>> sendHospitalOtp(String phone, String hospitalId) async {
    try {
      final cleanPhone = phone.replaceAll(RegExp(r'\D'), '');
      final response = await http
          .post(
            Uri.parse('$baseUrl/auth/hospital/send-otp'),
            headers: _headers,
            body: jsonEncode({'phone': cleanPhone, 'hospitalId': hospitalId}),
          )
          .timeout(const Duration(seconds: 10));
      return jsonDecode(response.body) as Map<String, dynamic>;
    } catch (e) {
      debugPrint('sendHospitalOtp error: $e');
      return {
        'success': true,
        'message': 'OTP sent (offline simulation)',
        'devOtp': '1234',
        'offline': true,
      };
    }
  }

  /// Verify hospital credentials + OTP.
  static Future<Map<String, dynamic>> verifyHospital(
      String hospitalId, String personnelId, String phone, String otp) async {
    try {
      final cleanPhone = phone.replaceAll(RegExp(r'\D'), '');
      final response = await http
          .post(
            Uri.parse('$baseUrl/auth/hospital/verify'),
            headers: _headers,
            body: jsonEncode({
              'hospitalId': hospitalId,
              'personnelId': personnelId,
              'phone': cleanPhone,
              'otp': otp,
            }),
          )
          .timeout(const Duration(seconds: 10));
      final body = jsonDecode(response.body) as Map<String, dynamic>;
      if (body['success'] == true && body['token'] != null) {
        setToken(body['token'] as String, 'hospital_${hospitalId}');
      }
      return body;
    } catch (e) {
      debugPrint('verifyHospital error: $e');
      // Offline fallback
      if (otp == '1234') {
        return {
          'success': true,
          'offline': true,
          'hospital': {
            'hospitalId': hospitalId,
            'name': 'Demo Hospital',
            'address': 'Bangalore, Karnataka',
          },
        };
      }
      return {'success': false, 'message': 'Incorrect OTP'};
    }
  }

  // ══════════════════════════════════════════════════════════════════════════
  // CITIZEN ENDPOINTS
  // ══════════════════════════════════════════════════════════════════════════

  /// Fetch a citizen's full profile by profile ID.
  static Future<MedicalProfile?> getCitizen(String profileId) async {
    try {
      final response = await http
          .get(Uri.parse('$baseUrl/citizens/$profileId'), headers: _headers)
          .timeout(const Duration(seconds: 8));

      if (response.statusCode == 200) {
        final body = jsonDecode(response.body) as Map<String, dynamic>;
        return _parseCitizen(body['citizen'] as Map<String, dynamic>);
      }
      return null;
    } catch (e) {
      debugPrint('getCitizen error: $e');
      return null;
    }
  }

  /// Update a citizen's medical profile.
  static Future<MedicalProfile?> updateCitizen(
      String profileId, Map<String, dynamic> updates) async {
    try {
      final response = await http
          .put(
            Uri.parse('$baseUrl/citizens/$profileId'),
            headers: _headers,
            body: jsonEncode(updates),
          )
          .timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        final body = jsonDecode(response.body) as Map<String, dynamic>;
        return _parseCitizen(body['citizen'] as Map<String, dynamic>);
      }
      debugPrint('updateCitizen failed: ${response.body}');
      return null;
    } catch (e) {
      debugPrint('updateCitizen error: $e');
      return null;
    }
  }

  /// Sign organ donation pledge.
  static Future<Map<String, dynamic>?> signOrganPledge(
      String profileId, List<String> organs) async {
    try {
      final response = await http
          .post(
            Uri.parse('$baseUrl/citizens/$profileId/organ-pledge'),
            headers: _headers,
            body: jsonEncode({'organs': organs}),
          )
          .timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        return jsonDecode(response.body) as Map<String, dynamic>;
      }
      return null;
    } catch (e) {
      debugPrint('signOrganPledge error: $e');
      return null;
    }
  }

  /// Verify organ consent hash against NOTTO.
  static Future<bool> verifyOrganConsent(String profileId, String signatureHash) async {
    try {
      final response = await http
          .post(
            Uri.parse('$baseUrl/citizens/$profileId/verify-organ-consent'),
            headers: _headers,
            body: jsonEncode({'signatureHash': signatureHash}),
          )
          .timeout(const Duration(seconds: 6));
      final body = jsonDecode(response.body) as Map<String, dynamic>;
      return body['verified'] == true;
    } catch (e) {
      debugPrint('verifyOrganConsent error: $e');
      return false;
    }
  }

  // ══════════════════════════════════════════════════════════════════════════
  // ORDER ENDPOINTS
  // ══════════════════════════════════════════════════════════════════════════

  /// Place an NFC card order.
  /// Returns: { success, orderId, status, estimatedDelivery }
  static Future<Map<String, dynamic>> placeOrder({
    required String cardType,
    required int price,
    required String citizenName,
    required String phone,
    required String deliveryAddress,
    required String city,
    required String state,
    required String pincode,
  }) async {
    try {
      final response = await http
          .post(
            Uri.parse('$baseUrl/orders'),
            headers: _headers,
            body: jsonEncode({
              'cardType': cardType,
              'price': price,
              'citizenName': citizenName,
              'phone': phone,
              'deliveryAddress': deliveryAddress,
              'city': city,
              'state': state,
              'pincode': pincode,
            }),
          )
          .timeout(const Duration(seconds: 10));

      return jsonDecode(response.body) as Map<String, dynamic>;
    } catch (e) {
      debugPrint('placeOrder error: $e');
      // Offline fallback — simulate a successful order
      final mockOrderId = 'STAP${DateTime.now().millisecondsSinceEpoch.toString().substring(5)}';
      return {
        'success': true,
        'orderId': mockOrderId,
        'status': 'ordered',
        'statusStep': 0,
        'offline': true,
      };
    }
  }

  // ══════════════════════════════════════════════════════════════════════════
  // BLOOD REQUEST ENDPOINTS
  // ══════════════════════════════════════════════════════════════════════════

  /// Declare a blood emergency.
  static Future<Map<String, dynamic>> declareBloodEmergency({
    required String hospitalName,
    required String hospitalAddress,
    required String bloodGroup,
    required int unitsNeeded,
    required double lat,
    required double lng,
    required double radiusKm,
  }) async {
    try {
      final response = await http
          .post(
            Uri.parse('$baseUrl/blood-requests'),
            headers: _headers,
            body: jsonEncode({
              'hospitalName': hospitalName,
              'hospitalAddress': hospitalAddress,
              'bloodGroup': bloodGroup,
              'unitsNeeded': unitsNeeded,
              'lat': lat,
              'lng': lng,
              'radiusKm': radiusKm,
            }),
          )
          .timeout(const Duration(seconds: 10));
      return jsonDecode(response.body) as Map<String, dynamic>;
    } catch (e) {
      debugPrint('declareBloodEmergency error: $e');
      return {'success': false, 'message': 'Server unreachable. Request saved locally.'};
    }
  }

  /// Get active blood requests.
  static Future<List<BloodRequest>> getBloodRequests() async {
    try {
      final response = await http
          .get(Uri.parse('$baseUrl/blood-requests?status=active'), headers: _headers)
          .timeout(const Duration(seconds: 8));

      if (response.statusCode == 200) {
        final body = jsonDecode(response.body) as Map<String, dynamic>;
        final list = (body['requests'] as List<dynamic>);
        return list.map((r) => _parseBloodRequest(r as Map<String, dynamic>)).toList();
      }
      return [];
    } catch (e) {
      debugPrint('getBloodRequests error: $e');
      return [];
    }
  }

  /// Respond to a blood emergency request.
  static Future<bool> respondToBloodRequest(
      String requestId, String donorId, String responseStatus,
      {int eta = 15}) async {
    try {
      final response = await http
          .put(
            Uri.parse('$baseUrl/blood-requests/$requestId/respond'),
            headers: _headers,
            body: jsonEncode({
              'donorId': donorId,
              'responseStatus': responseStatus,
              'eta': eta,
            }),
          )
          .timeout(const Duration(seconds: 10));
      final body = jsonDecode(response.body) as Map<String, dynamic>;
      return body['success'] == true;
    } catch (e) {
      debugPrint('respondToBloodRequest error: $e');
      return false;
    }
  }

  // ══════════════════════════════════════════════════════════════════════════
  // HEALTH REPORT ENDPOINTS
  // ══════════════════════════════════════════════════════════════════════════

  /// Submit a health issue report.
  static Future<bool> submitHealthReport({
    required String disease,
    required List<String> symptoms,
    String severityLevel = 'mild',
    double? lat,
    double? lng,
    String? locationDescription,
    String additionalNotes = '',
    String reportingFor = 'self',
    String duration = '',
    bool submitAnonymously = false,
  }) async {
    try {
      final response = await http
          .post(
            Uri.parse('$baseUrl/health-reports'),
            headers: _headers,
            body: jsonEncode({
              'disease': disease,
              'symptoms': symptoms,
              'severityLevel': severityLevel,
              'lat': lat,
              'lng': lng,
              'locationDescription': locationDescription,
              'additionalNotes': additionalNotes,
              'reportingFor': reportingFor,
              'duration': duration,
              'submitAnonymously': submitAnonymously,
            }),
          )
          .timeout(const Duration(seconds: 10));
      final body = jsonDecode(response.body) as Map<String, dynamic>;
      return body['success'] == true;
    } catch (e) {
      debugPrint('submitHealthReport error: $e');
      return false;
    }
  }

  /// Get previously submitted health reports.
  static Future<List<dynamic>> getHealthReports() async {
    try {
      final response = await http
          .get(Uri.parse('$baseUrl/health-reports'), headers: _headers)
          .timeout(const Duration(seconds: 8));

      if (response.statusCode == 200) {
        final body = jsonDecode(response.body) as Map<String, dynamic>;
        return body['reports'] as List<dynamic>;
      }
      return [];
    } catch (e) {
      debugPrint('getHealthReports error: $e');
      return [];
    }
  }

  // ══════════════════════════════════════════════════════════════════════════
  // PARSERS — JSON → Flutter Model Objects
  // ══════════════════════════════════════════════════════════════════════════

  static MedicalProfile _parseCitizen(Map<String, dynamic> json) {
    final contactsJson = (json['emergencyContacts'] as List<dynamic>?) ?? [];
    final contacts = contactsJson
        .map((c) => EmergencyContact.fromJson(c as Map<String, dynamic>))
        .toList();

    OrganDonationPledge? pledge;
    final pledgeJson = json['organPledge'] as Map<String, dynamic>?;
    if (pledgeJson != null) {
      pledge = OrganDonationPledge.fromJson(pledgeJson);
    }

    return MedicalProfile(
      id: json['id'] as String? ?? '',
      fullName: json['fullName'] as String? ?? 'Unknown',
      bloodGroup: json['bloodGroup'] as String? ?? 'Unknown',
      age: json['age'] != null ? (json['age'] as num).toInt() : null,
      address: json['address'] as String? ?? '',
      allergies: json['allergies'] as String? ?? 'None',
      medications: json['medications'] as String? ?? 'None',
      emergencyContacts: contacts,
      isDnr: json['isDnr'] as bool? ?? false,
      specialInstructions: json['specialInstructions'] as String? ?? 'None',
      organPledge: pledge,
      insuranceCompany: json['insuranceCompany'] as String? ?? '',
      insurancePolicyNumber: json['insurancePolicyNumber'] as String? ?? '',
      chronicConditions: json['chronicConditions'] as String? ?? 'None',
      lifeCredits: (json['lifeCredits'] as num?)?.toInt() ?? 0,
      isBloodDonor: json['isBloodDonor'] as bool? ?? false,
      donorRadiusKm: (json['donorRadiusKm'] as num?)?.toDouble() ?? 5.0,
      homeLat: (json['homeLat'] as num?)?.toDouble() ?? 12.9716,
      homeLng: (json['homeLng'] as num?)?.toDouble() ?? 77.5946,
      phoneNumber: json['phoneNumber'] as String? ?? '',
      email: json['email'] as String? ?? '',
      profileImage: json['profileImage'] as String?,
    );
  }

  static BloodRequest _parseBloodRequest(Map<String, dynamic> json) {
    final responsesJson = (json['responses'] as List<dynamic>?) ?? [];
    final responses = responsesJson.map((r) {
      final rMap = r as Map<String, dynamic>;
      final statusStr = rMap['status'] as String? ?? 'pending';
      DonorResponseStatus status;
      switch (statusStr) {
        case 'accepted':
          status = DonorResponseStatus.accepted;
          break;
        case 'declined':
          status = DonorResponseStatus.declined;
          break;
        default:
          status = DonorResponseStatus.pending;
      }
      return DonorResponse(
        donorId: rMap['donorId'] as String? ?? '',
        donorName: rMap['donorName'] as String? ?? 'Unknown',
        phone: rMap['phone'] as String? ?? '',
        status: status,
        etaMinutes: (rMap['etaMinutes'] as num?)?.toInt() ?? 0,
        lat: (rMap['lat'] as num?)?.toDouble() ?? 0,
        lng: (rMap['lng'] as num?)?.toDouble() ?? 0,
      );
    }).toList();

    return BloodRequest(
      requestId: json['requestId'] as String? ?? '',
      hospitalName: json['hospitalName'] as String? ?? '',
      hospitalAddress: json['hospitalAddress'] as String? ?? '',
      bloodGroup: json['bloodGroup'] as String? ?? '',
      unitsNeeded: (json['unitsNeeded'] as num?)?.toInt() ?? 1,
      lat: (json['lat'] as num?)?.toDouble() ?? 0,
      lng: (json['lng'] as num?)?.toDouble() ?? 0,
      radiusKm: (json['radiusKm'] as num?)?.toDouble() ?? 10,
      status: json['status'] as String? ?? 'active',
      responses: responses,
      timestamp: json['timestamp'] != null
          ? DateTime.tryParse(json['timestamp'].toString()) ?? DateTime.now()
          : DateTime.now(),
    );
  }

  // ─── Offline mock citizen JSON ─────────────────────────────────────────────
  static Map<String, dynamic> _mockCitizenJson(String id) => {
        'id': id,
        'fullName': 'Rajesh Kumar',
        'phoneNumber': '9900112233',
        'email': 'rajesh.kumar@gmail.com',
        'bloodGroup': 'B+',
        'allergies': 'None',
        'medications': 'None',
        'chronicConditions': 'None',
        'specialInstructions': 'None',
        'isDnr': false,
        'emergencyContacts': [
          {'name': 'Sneha Kumar', 'relation': 'Spouse', 'phone': '+91 98765 43210'},
        ],
        'organPledge': null,
        'insuranceCompany': 'HDFC Ergo Health Optima',
        'insurancePolicyNumber': 'POL-8873491-02',
        'isBloodDonor': true,
        'donorRadiusKm': 5.0,
        'homeLat': 12.9722,
        'homeLng': 77.5938,
        'lifeCredits': 350,
        'selectedLanguage': 'English',
        'profileCompleteness': 75,
        'profileImage': null,
      };
}
