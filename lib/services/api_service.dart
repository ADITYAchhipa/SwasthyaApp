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
    // Set this to true to connect to your production deployment, false for localhost
    const bool useProduction = true;

    if (useProduction) {
      return 'https://swasthyabackend.vercel.app/api';
    }

    if (kIsWeb) return 'http://localhost:3011/api';
    try {
      // NOTE: For physical Android devices testing local server, 
      // replace '10.0.2.2' with your machine's local IP address (e.g., '192.168.1.x')
      if (Platform.isAndroid) return 'http://10.0.2.2:3011/api';
    } catch (_) {}
    return 'http://localhost:3011/api';
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

  /// Send OTP to a citizen's mobile number.
  /// Returns: { success, message, devOtp? }
  static Future<Map<String, dynamic>> sendOtp(String phone) async {
    try {
      final cleanPhone = phone.trim();
      final response = await http
          .post(
            Uri.parse('$baseUrl/auth/send-otp'),
            headers: _headers,
            body: jsonEncode({'phone': cleanPhone}),
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
  static Future<Map<String, dynamic>> verifyOtp(String phone, String otp) async {
    try {
      final cleanPhone = phone.trim();
      final response = await http
          .post(
            Uri.parse('$baseUrl/auth/verify-otp'),
            headers: _headers,
            body: jsonEncode({'phone': cleanPhone, 'otp': otp}),
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

  /// Send OTP for hospital login — only hospitalId needed, backend uses registered phone.
  static Future<Map<String, dynamic>> sendHospitalOtp(String hospitalId) async {
    try {
      final response = await http
          .post(
            Uri.parse('$baseUrl/auth/hospital/send-otp'),
            headers: _headers,
            body: jsonEncode({'hospitalId': hospitalId}),
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

  /// Verify hospital OTP — only hospitalId + otp needed.
  static Future<Map<String, dynamic>> verifyHospital(
      String hospitalId, String otp) async {
    try {
      final response = await http
          .post(
            Uri.parse('$baseUrl/auth/hospital/verify'),
            headers: _headers,
            body: jsonEncode({
              'hospitalId': hospitalId,
              'otp': otp,
            }),
          )
          .timeout(const Duration(seconds: 10));
      final body = jsonDecode(response.body) as Map<String, dynamic>;
      if (body['success'] == true && body['token'] != null) {
        setToken(body['token'] as String, 'hospital_$hospitalId');
      }
      return body;
    } catch (e) {
      debugPrint('verifyHospital error: $e');
      // Offline fallback
      if (otp == '1234') {
        return {
          'success': true,
          'offline': true,
          'token': 'mock_hospital_token',
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

  /// Fetch lightweight citizen preview by SwasthyaTap ID (for hospital NFC writer).
  /// Returns: { success, citizen: { id, fullName, bloodGroup, phoneNumber } }
  static Future<Map<String, dynamic>> fetchCitizenPreview(String swasthyaId) async {
    try {
      final response = await http
          .get(Uri.parse('$baseUrl/citizens/$swasthyaId'), headers: _headers)
          .timeout(const Duration(seconds: 8));
      return jsonDecode(response.body) as Map<String, dynamic>;
    } catch (e) {
      debugPrint('fetchCitizenPreview error: $e');
      return {'success': false, 'message': 'Could not reach server'};
    }
  }

  /// Fetch (or generate) the NFC write URL for a patient — hospital auth required.
  /// Returns: { success, nfcUrl, patientName, swasthyaId }
  static Future<Map<String, dynamic>> fetchNfcWriteUrl(String swasthyaId) async {
    try {
      final response = await http
          .get(Uri.parse('$baseUrl/citizens/$swasthyaId/nfc-token'), headers: _headers)
          .timeout(const Duration(seconds: 10));
      if (response.statusCode == 200) {
        return jsonDecode(response.body) as Map<String, dynamic>;
      }
      debugPrint('fetchNfcWriteUrl non-200 status: ${response.statusCode}');
      return {
        'success': true,
        'nfcUrl': 'https://www.nfc.swasthyatap.in/card/$swasthyaId',
        'patientName': 'Patient',
        'swasthyaId': swasthyaId,
        'isMock': true,
      };
    } catch (e) {
      debugPrint('fetchNfcWriteUrl error: $e');
      return {
        'success': true,
        'nfcUrl': 'https://www.nfc.swasthyatap.in/card/$swasthyaId',
        'patientName': 'Patient',
        'swasthyaId': swasthyaId,
        'isMock': true,
      };
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
      debugPrint('getCitizen non-200 status: ${response.statusCode}, falling back to mock profile');
      return _parseCitizen(_mockCitizenJson(profileId));
    } catch (e) {
      debugPrint('getCitizen error: $e, falling back to mock profile');
      return _parseCitizen(_mockCitizenJson(profileId));
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

  /// Add a prescription for a citizen.
  static Future<MedicalProfile?> addPrescription(
    String profileId,
    Map<String, dynamic> prescriptionData, {
    List<int>? fileBytes,
    String? filename,
  }) async {
    try {
      if (fileBytes != null && filename != null) {
        final request = http.MultipartRequest(
          'POST',
          Uri.parse('$baseUrl/citizens/$profileId/prescriptions'),
        );
        
        // Copy over headers (excluding content-type)
        _headers.forEach((key, val) {
          if (key.toLowerCase() != 'content-type') {
            request.headers[key] = val;
          }
        });

        prescriptionData.forEach((key, val) {
          if (key == 'rxList') {
            request.fields[key] = jsonEncode(val);
          } else {
            request.fields[key] = val.toString();
          }
        });

        request.files.add(
          http.MultipartFile.fromBytes(
            'file',
            fileBytes,
            filename: filename,
          ),
        );

        final streamedResponse = await request.send().timeout(const Duration(seconds: 20));
        final response = await http.Response.fromStream(streamedResponse);

        if (response.statusCode == 200) {
          final body = jsonDecode(response.body) as Map<String, dynamic>;
          return _parseCitizen(body['citizen'] as Map<String, dynamic>);
        }
        debugPrint('addPrescription multipart failed: ${response.body}');
        return null;
      } else {
        final response = await http
            .post(
              Uri.parse('$baseUrl/citizens/$profileId/prescriptions'),
              headers: _headers,
              body: jsonEncode(prescriptionData),
            )
            .timeout(const Duration(seconds: 10));

        if (response.statusCode == 200) {
          final body = jsonDecode(response.body) as Map<String, dynamic>;
          return _parseCitizen(body['citizen'] as Map<String, dynamic>);
        }
        debugPrint('addPrescription failed: ${response.body}');
        return null;
      }
    } catch (e) {
      debugPrint('addPrescription error: $e');
      return null;
    }
  }

  /// Upload a medical report for a citizen.
  static Future<MedicalProfile?> uploadMedicalReport(
    String profileId, {
    required String title,
    required String issuer,
    required String date,
    required String doctor,
    required List<int> fileBytes,
    required String filename,
    String? department,
    bool? isAbnormal,
    String? category,
    List<String>? tags,
  }) async {
    try {
      final request = http.MultipartRequest(
        'POST',
        Uri.parse('$baseUrl/citizens/$profileId/medical-reports'),
      );
      
      // Copy over headers (excluding content-type)
      _headers.forEach((key, val) {
        if (key.toLowerCase() != 'content-type') {
          request.headers[key] = val;
        }
      });

      request.fields['title_key'] = title;
      request.fields['issuer_key'] = issuer;
      request.fields['date'] = date;
      request.fields['doctor_key'] = doctor;
      request.fields['status_key'] = 'verified_report';
      
      if (department != null) {
        request.fields['department'] = department;
      }
      if (isAbnormal != null) {
        request.fields['isAbnormal'] = isAbnormal.toString();
      }
      if (category != null) {
        request.fields['category'] = category;
      }
      if (tags != null) {
        request.fields['tags'] = jsonEncode(tags);
      }

      request.files.add(
        http.MultipartFile.fromBytes(
          'file',
          fileBytes,
          filename: filename,
        ),
      );

      final streamedResponse = await request.send().timeout(const Duration(seconds: 20));
      final response = await http.Response.fromStream(streamedResponse);

      if (response.statusCode == 200) {
        final body = jsonDecode(response.body) as Map<String, dynamic>;
        return _parseCitizen(body['citizen'] as Map<String, dynamic>);
      }
      debugPrint('uploadMedicalReport failed: ${response.body}');
      return null;
    } catch (e) {
      debugPrint('uploadMedicalReport error: $e');
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

  static MedicalProfile parseCitizen(Map<String, dynamic> json) {
    return _parseCitizen(json);
  }

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
      medicalReports: json['medicalReports'] as List<dynamic>? ?? [],
      receipts: json['receipts'] as List<dynamic>? ?? [],
      prescriptions: json['prescriptions'] as List<dynamic>? ?? [],
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
        'medicalReports': [
          {
            'title_key': 'cbc_report',
            'issuer_key': 'lab_name_city',
            'date': '18 Jun 2026',
            'status_key': 'verified_report',
            'doctor_key': 'dr_amit_shah',
          },
          {
            'title_key': 'lipid_profile',
            'issuer_key': 'lab_name_apollo',
            'date': '10 May 2026',
            'status_key': 'verified_report',
            'doctor_key': 'dr_patel',
          },
          {
            'title_key': 'thyroid_report',
            'issuer_key': 'lab_name_city',
            'date': '24 Apr 2026',
            'status_key': 'verified_report',
            'doctor_key': 'dr_singh',
          },
          {
            'title_key': 'chest_xray',
            'issuer_key': 'lab_name_apollo',
            'date': '15 Feb 2026',
            'status_key': 'verified_report',
            'doctor_key': 'dr_amit_shah',
          }
        ],
        'receipts': [
          {
            'title_key': 'opd_consultation_receipt',
            'issuer_key': 'dr_amit_shah',
            'date': '20 Jun 2026',
            'amount': '₹500',
            'status_key': 'paid',
          },
          {
            'title_key': 'pharmacy_invoice',
            'issuer_key': 'apollo_pharmacy',
            'date': '20 Jun 2026',
            'amount': '₹1,240',
            'status_key': 'paid',
          },
          {
            'title_key': 'diagnostics_invoice',
            'issuer_key': 'city_labs',
            'date': '12 May 2026',
            'amount': '₹1,500',
            'status_key': 'paid',
          }
        ],
        'prescriptions': [
          {
            'prescriptionId': 'RX-2026-891',
            'doctorName': 'Dr. Amit Shah',
            'qualification': 'MD (Cardiology), FACC',
            'hospitalName': 'Apollo Speciality Hospital',
            'date': '20 Jun 2026',
            'diagnosis': 'Mild Hypertension & Preventive Checkup',
            'doctorNotes': 'Maintain low sodium diet, 30 mins morning walk recommended. Follow up after 1 month with BP log.',
            'status': 'Active',
            'doctorPhoto': 'https://images.unsplash.com/photo-1622253692010-333f2da6031d?q=80&w=150',
            'validUntil': '20 Jul 2026',
            'testsRecommended': ['Lipid Profile', 'ECG'],
            'isFavorite': true,
            'rxList': [
              {
                'medicineName': 'Telmisartan 40mg',
                'dosage': '1 Tablet',
                'frequency': 'Once Daily (Morning)',
                'duration': '30 Days',
                'instructions': 'Take after breakfast with water',
                'morning': true,
                'afternoon': false,
                'night': false,
                'beforeFood': false,
                'afterFood': true,
                'quantity': '30 Tablets',
                'purpose': 'Control blood pressure',
                'sideEffects': 'Dizziness, headache',
                'storage': 'Store at room temperature',
                'alternatives': 'Telma 40',
                'isTakenToday': false
              },
              {
                'medicineName': 'Amlodipine 5mg',
                'dosage': '1 Tablet',
                'frequency': 'Once Daily (Night)',
                'duration': '30 Days',
                'instructions': 'Take before sleep',
                'morning': false,
                'afternoon': false,
                'night': true,
                'beforeFood': false,
                'afterFood': true,
                'quantity': '30 Tablets',
                'purpose': 'Control blood pressure',
                'sideEffects': 'Ankle swelling',
                'storage': 'Store in a cool dry place',
                'alternatives': 'Amlopin 5',
                'isTakenToday': false
              },
              {
                'medicineName': 'Multivitamin Complex',
                'dosage': '1 Capsule',
                'frequency': 'Once Daily',
                'duration': '15 Days',
                'instructions': 'Take after meal',
                'morning': true,
                'afternoon': false,
                'night': false,
                'beforeFood': false,
                'afterFood': true,
                'quantity': '15 Capsules',
                'purpose': 'Nutritional supplement',
                'sideEffects': 'None',
                'storage': 'Store below 25°C',
                'alternatives': 'Becosules',
                'isTakenToday': false
              }
            ]
          },
          {
            'prescriptionId': 'RX-2026-442',
            'doctorName': 'Dr. Patel',
            'qualification': 'MBBS, MD (General Medicine)',
            'hospitalName': 'City Care Clinic',
            'date': '10 May 2026',
            'diagnosis': 'Acute Upper Respiratory Tract Infection',
            'doctorNotes': 'Drink warm water and steam inhalation twice daily.',
            'status': 'Completed',
            'doctorPhoto': 'https://images.unsplash.com/photo-1559839734-2b71ea197ec2?q=80&w=150',
            'validUntil': '15 May 2026',
            'testsRecommended': [],
            'isFavorite': false,
            'rxList': [
              {
                'medicineName': 'Amoxicillin 500mg',
                'dosage': '1 Capsule',
                'frequency': 'Thrice Daily (8hrly)',
                'duration': '5 Days',
                'instructions': 'Complete full course',
                'morning': true,
                'afternoon': true,
                'night': true,
                'beforeFood': false,
                'afterFood': true,
                'quantity': '15 Capsules',
                'purpose': 'Antibiotic for throat infection',
                'sideEffects': 'Nausea, diarrhea',
                'storage': 'Keep away from moisture',
                'alternatives': 'Mox 500',
                'isTakenToday': false
              },
              {
                'medicineName': 'Paracetamol 650mg',
                'dosage': '1 Tablet',
                'frequency': 'As needed for fever',
                'duration': '5 Days',
                'instructions': 'Max 3 tablets per day',
                'morning': true,
                'afternoon': true,
                'night': true,
                'beforeFood': false,
                'afterFood': true,
                'quantity': '10 Tablets',
                'purpose': 'Fever and pain relief',
                'sideEffects': 'None when taken in limit',
                'storage': 'Store below 30°C',
                'alternatives': 'Dolo 650',
                'isTakenToday': false
              }
            ]
          }
        ],
      };

  // ══════════════════════════════════════════════════════════════════════════
  // HEALTH CENTERS ENDPOINTS (Hospitals, PHCs, Blood Banks)
  // ══════════════════════════════════════════════════════════════════════════

  /// Fetch all registered hospitals from backend API
  static Future<List<Map<String, dynamic>>> getHospitals({String? city, String? search}) async {
    try {
      final queryParams = <String, String>{};
      if (city != null && city.isNotEmpty) queryParams['city'] = city;
      if (search != null && search.isNotEmpty) queryParams['search'] = search;

      final uri = Uri.parse('$baseUrl/hospitals').replace(queryParameters: queryParams.isNotEmpty ? queryParams : null);
      final response = await http.get(uri, headers: _headers).timeout(const Duration(seconds: 8));

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data is Map && data['success'] == true && data['hospitals'] is List) {
          return (data['hospitals'] as List)
              .whereType<Map>()
              .map((e) => Map<String, dynamic>.from(e))
              .toList();
        }
      }
    } catch (e) {
      debugPrint('ApiService.getHospitals error: $e');
    }
    return [];
  }

  /// Fetch all registered PHCs from backend API
  static Future<List<Map<String, dynamic>>> getPhcs({String? city, String? search}) async {
    try {
      final queryParams = <String, String>{};
      if (city != null && city.isNotEmpty) queryParams['city'] = city;
      if (search != null && search.isNotEmpty) queryParams['search'] = search;

      final uri = Uri.parse('$baseUrl/phcs').replace(queryParameters: queryParams.isNotEmpty ? queryParams : null);
      final response = await http.get(uri, headers: _headers).timeout(const Duration(seconds: 8));

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data is Map && data['success'] == true && data['phcs'] is List) {
          return (data['phcs'] as List)
              .whereType<Map>()
              .map((e) => Map<String, dynamic>.from(e))
              .toList();
        }
      }
    } catch (e) {
      debugPrint('ApiService.getPhcs error: $e');
    }
    return [];
  }

  /// Fetch all registered Blood Banks from backend API
  static Future<List<Map<String, dynamic>>> getBloodBanks({String? city, String? search, String? bloodGroup}) async {
    try {
      final queryParams = <String, String>{};
      if (city != null && city.isNotEmpty) queryParams['city'] = city;
      if (search != null && search.isNotEmpty) queryParams['search'] = search;
      if (bloodGroup != null && bloodGroup.isNotEmpty) queryParams['bloodGroup'] = bloodGroup;

      final uri = Uri.parse('$baseUrl/blood-banks').replace(queryParameters: queryParams.isNotEmpty ? queryParams : null);
      final response = await http.get(uri, headers: _headers).timeout(const Duration(seconds: 8));

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data is Map && data['success'] == true && data['bloodBanks'] is List) {
          return (data['bloodBanks'] as List)
              .whereType<Map>()
              .map((e) => Map<String, dynamic>.from(e))
              .toList();
        }
      }
    } catch (e) {
      debugPrint('ApiService.getBloodBanks error: $e');
    }
    return [];
  }

  /// Fetch a citizen's full profile by profile ID with no mock fallback.
  static Future<MedicalProfile?> getCitizenOnlineOnly(String profileId) async {
    try {
      final response = await http
          .get(Uri.parse('$baseUrl/citizens/$profileId'), headers: _headers)
          .timeout(const Duration(seconds: 8));

      if (response.statusCode == 200) {
        final body = jsonDecode(response.body) as Map<String, dynamic>;
        return _parseCitizen(body['citizen'] as Map<String, dynamic>);
      }
      debugPrint('getCitizenOnlineOnly non-200 status: ${response.statusCode}');
      return null;
    } catch (e) {
      debugPrint('getCitizenOnlineOnly error: $e');
      return null;
    }
  }

  /// Register/enroll a device for offline mesh relay.
  static Future<Map<String, dynamic>?> registerMeshDevice(Map<String, dynamic> body) async {
    try {
      final response = await http
          .post(
            Uri.parse('$baseUrl/offline-mesh/register-device'),
            headers: _headers,
            body: jsonEncode(body),
          )
          .timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        return jsonDecode(response.body) as Map<String, dynamic>;
      }
      debugPrint('registerMeshDevice failed status: ${response.statusCode}');
      return null;
    } catch (e) {
      debugPrint('registerMeshDevice error: $e');
      return null;
    }
  }

  /// Submit a mesh packet to the server gateway.
  static Future<Map<String, dynamic>?> submitMeshPacket(Map<String, dynamic> packetJson) async {
    try {
      final response = await http
          .post(
            Uri.parse('$baseUrl/offline-mesh/request'),
            headers: _headers,
            body: jsonEncode(packetJson),
          )
          .timeout(const Duration(seconds: 15));

      if (response.statusCode == 200) {
        return jsonDecode(response.body) as Map<String, dynamic>;
      }
      debugPrint('submitMeshPacket failed status: ${response.statusCode}');
      return null;
    } catch (e) {
      debugPrint('submitMeshPacket error: $e');
      return null;
    }
  }

  /// Poll for a mesh response if the gateway lost the response mid-flight.
  static Future<Map<String, dynamic>?> pollMeshResponse(String requestId) async {
    try {
      final response = await http
          .get(
            Uri.parse('$baseUrl/offline-mesh/response/$requestId'),
            headers: _headers,
          )
          .timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        return jsonDecode(response.body) as Map<String, dynamic>;
      }
      debugPrint('pollMeshResponse failed status: ${response.statusCode}');
      return null;
    } catch (e) {
      debugPrint('pollMeshResponse error: $e');
      return null;
    }
  }

  /// Acknowledge that a mesh response was received.
  static Future<bool> ackMeshResponse(String requestId) async {
    try {
      final response = await http
          .post(
            Uri.parse('$baseUrl/offline-mesh/response-ack'),
            headers: _headers,
            body: jsonEncode({'requestId': requestId}),
          )
          .timeout(const Duration(seconds: 8));

      return response.statusCode == 200;
    } catch (e) {
      debugPrint('ackMeshResponse error: $e');
      return false;
    }
  }

  /// Fetch remote mesh config parameters.
  static Future<Map<String, dynamic>?> getMeshConfig() async {
    try {
      final response = await http
          .get(Uri.parse('$baseUrl/offline-mesh/config'))
          .timeout(const Duration(seconds: 8));

      if (response.statusCode == 200) {
        return jsonDecode(response.body) as Map<String, dynamic>;
      }
      return null;
    } catch (e) {
      debugPrint('getMeshConfig error: $e');
      return null;
    }
  }
}
