import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:crypto/crypto.dart';
import '../models/models.dart';
import '../services/api_service.dart';

class SwasthyaTapProvider extends ChangeNotifier {
  // Mock profiles database
  final List<MedicalProfile> _profiles = [];
  
  // App settings/state
  String _currentCitizenProfileId = 'x7k9m2';
  bool _isInternetAvailable = true;
  bool _isNfcScanning = false;
  String _selectedLanguage = 'English';
  bool _isBiometricLockEnabled = false;
  bool _isPinProtected = false;
  String _pinCode = '1234';
  bool _emergencyAlertsEnabled = true;
  bool _bloodAlertsEnabled = true;
  int _familyCount = 0;
  
  // Scanning results
  String? _scannedNdefData;
  MedicalProfile? _scannedProfile;
  bool _scannedOfflineOnly = false;
  
  // Active blood emergency requests
  final List<BloodRequest> _bloodRequests = [];
  
  // Mock SMS Inbox for notifications
  final List<Map<String, dynamic>> _mockSmsInbox = [];
  
  // Active simulation timer
  Timer? _simulationTimer;

  SwasthyaTapProvider() {
    _seedProfiles();
  }

  // Getters
  List<MedicalProfile> get profiles => _profiles;
  String get currentCitizenProfileId => _currentCitizenProfileId;
  bool get isInternetAvailable => _isInternetAvailable;
  bool get isNfcScanning => _isNfcScanning;
  String get selectedLanguage => _selectedLanguage;
  bool get isBiometricLockEnabled => _isBiometricLockEnabled;
  bool get isPinProtected => _isPinProtected;
  String get pinCode => _pinCode;
  bool get emergencyAlertsEnabled => _emergencyAlertsEnabled;
  bool get bloodAlertsEnabled => _bloodAlertsEnabled;
  int get familyCount => _familyCount;
  String? get scannedNdefData => _scannedNdefData;
  MedicalProfile? get scannedProfile => _scannedProfile;
  bool get scannedOfflineOnly => _scannedOfflineOnly;
  List<BloodRequest> get bloodRequests => _bloodRequests;
  List<Map<String, dynamic>> get mockSmsInbox => _mockSmsInbox;

  MedicalProfile get currentCitizen => 
      _profiles.firstWhere((p) => p.id == _currentCitizenProfileId);

  // Setters & Actions
  void toggleBiometricLock(bool value) {
    _isBiometricLockEnabled = value;
    notifyListeners();
  }

  void togglePinProtected(bool value) {
    _isPinProtected = value;
    notifyListeners();
  }

  void setPinCode(String code) {
    _pinCode = code;
    notifyListeners();
  }

  void toggleEmergencyAlerts(bool value) {
    _emergencyAlertsEnabled = value;
    notifyListeners();
  }

  void toggleBloodAlerts(bool value) {
    _bloodAlertsEnabled = value;
    notifyListeners();
  }

  void incrementFamilyCount() {
    _familyCount++;
    notifyListeners();
  }

  void setInternetAvailability(bool value) {
    _isInternetAvailable = value;
    notifyListeners();
  }

  void setCurrentCitizen(String id) {
    _currentCitizenProfileId = id;
    notifyListeners();
  }

  void loginCitizen(MedicalProfile profile) {
    _currentCitizenProfileId = profile.id;
    final idx = _profiles.indexWhere((p) => p.id == profile.id);
    if (idx != -1) {
      _profiles[idx] = profile;
    } else {
      _profiles.add(profile);
    }
    notifyListeners();
  }

  void toggleNfcScanning(bool scanning) {
    _isNfcScanning = scanning;
    notifyListeners();
  }

  void setSelectedLanguage(String lang) {
    _selectedLanguage = lang;
    notifyListeners();
  }

  // Update profile — persists to backend, falls back to local cache
  Future<void> updateProfile(MedicalProfile updatedProfile) async {
    final idx = _profiles.indexWhere((p) => p.id == updatedProfile.id);
    if (idx != -1) {
      _profiles[idx] = updatedProfile;
      notifyListeners();
    }
    // Persist to backend asynchronously
    try {
      await ApiService.updateCitizen(updatedProfile.id, {
        'fullName': updatedProfile.fullName,
        'bloodGroup': updatedProfile.bloodGroup,
        'age': updatedProfile.age,
        'address': updatedProfile.address,
        'phoneNumber': updatedProfile.phoneNumber,
        'allergies': updatedProfile.allergies,
        'medications': updatedProfile.medications,
        'chronicConditions': updatedProfile.chronicConditions,
        'specialInstructions': updatedProfile.specialInstructions,
        'isDnr': updatedProfile.isDnr,
        'isBloodDonor': updatedProfile.isBloodDonor,
        'donorRadiusKm': updatedProfile.donorRadiusKm,
        'insuranceCompany': updatedProfile.insuranceCompany,
        'insurancePolicyNumber': updatedProfile.insurancePolicyNumber,
        'emergencyContacts': updatedProfile.emergencyContacts.map((c) => c.toJson()).toList(),
        'profileImage': updatedProfile.profileImage,
      });
    } catch (e) {
      debugPrint('updateProfile API error (local cache used): $e');
    }
  }

  // Sign Organ Pledge — persists to backend
  Future<void> signOrganPledge(String profileId, List<String> organs) async {
    final idx = _profiles.indexWhere((p) => p.id == profileId);
    if (idx != -1) {
      final citizen = _profiles[idx];
      final dateStr = DateTime.now().toString().split(' ')[0];
      final hash = OrganDonationPledge.generateHash(
        citizenId: citizen.id,
        fullName: citizen.fullName,
        date: dateStr,
        organs: organs,
      );
      
      final pledge = OrganDonationPledge(
        pledgeId: 'NOTTO-${citizen.id.toUpperCase()}',
        pledgedOrgans: organs,
        signedDate: dateStr,
        signatureHash: hash,
        nottoVerified: true,
      );

      _profiles[idx] = citizen.copyWith(organPledge: pledge);
      notifyListeners();

      // Persist to backend
      try {
        await ApiService.signOrganPledge(profileId, organs);
      } catch (e) {
        debugPrint('signOrganPledge API error (local cache used): $e');
      }
    }
  }

  // Reset NFC scanner state
  void clearScannedData() {
    _scannedNdefData = null;
    _scannedProfile = null;
    _scannedOfflineOnly = false;
    notifyListeners();
  }

  // Clear simulated SMS inbox
  void clearSmsInbox() {
    _mockSmsInbox.clear();
    notifyListeners();
  }

  // Simulate tapping an NFC card
  void simulateNfcTap(String ndefPayload, bool internetAvailable) {
    _scannedNdefData = ndefPayload;
    _isInternetAvailable = internetAvailable;
    
    try {
      final data = jsonDecode(ndefPayload);
      final profileId = data['id'];
      
      if (internetAvailable) {
        // Online Mode: fetch full details from backend database
        final backendProfile = _profiles.firstWhere(
          (p) => p.id == profileId,
          orElse: () => _createProfileFromNdef(data),
        );
        _scannedProfile = backendProfile;
        _scannedOfflineOnly = false;
      } else {
        // Offline Mode: create a restricted profile containing ONLY the NDEF data
        _scannedProfile = _createProfileFromNdef(data);
        _scannedOfflineOnly = true;
      }
    } catch (e) {
      // Invalid tag data
      _scannedProfile = null;
      _scannedOfflineOnly = false;
    }
    
    notifyListeners();
  }

  // Re-verify organ consent against NOTTO backend (real API with local fallback)
  Future<bool> verifyOrganConsentWithNOTTO(String signatureHash) async {
    // Try real backend first
    try {
      final profileId = _currentCitizenProfileId;
      final result = await ApiService.verifyOrganConsent(profileId, signatureHash);
      return result;
    } catch (_) {
      // Fallback: check local cache
      await Future.delayed(const Duration(seconds: 1));
      for (var p in _profiles) {
        if (p.organPledge?.signatureHash == signatureHash) return true;
      }
      return false;
    }
  }

  // Create a minimal MedicalProfile from NDEF data
  MedicalProfile _createProfileFromNdef(Map<String, dynamic> data) {
    final contactsJson = data['contacts'] as List? ?? [];
    final contacts = contactsJson
        .map((c) => EmergencyContact.fromJson(c as Map<String, dynamic>))
        .toList();

    OrganDonationPledge? pledge;
    if (data['consentHash'] != null && (data['consentHash'] as String).isNotEmpty) {
      pledge = OrganDonationPledge(
        pledgeId: 'NDEF-VERIFIED',
        pledgedOrgans: ['Consent Stored Offline'],
        signedDate: 'Stored on Chip',
        signatureHash: data['consentHash'],
        nottoVerified: false, // requires online check to be true
      );
    }

    return MedicalProfile(
      id: data['id'] ?? 'unknown',
      fullName: data['name'] ?? 'Unidentified Patient',
      bloodGroup: data['blood'] ?? 'Unknown',
      allergies: data['allergies'] ?? 'None specified',
      medications: data['meds'] ?? 'None specified',
      emergencyContacts: contacts,
      isDnr: data['dnr'] ?? false,
      specialInstructions: data['instructions'] ?? 'None',
      organPledge: pledge,
      phoneNumber: '',
      profileImage: data['profileImage'] as String?,
    );
  }

  // Declare emergency need (Blood Request) — persists to backend
  Future<void> declareBloodEmergency({
    required String hospitalName,
    required String hospitalAddress,
    required String bloodGroup,
    required int unitsNeeded,
    required double lat,
    required double lng,
    required double radiusKm,
  }) async {
    final requestId = 'REQ-${DateTime.now().millisecondsSinceEpoch.toString().substring(8)}';
    
    // Find all matching donors (must match blood group, be a donor, and within the radius)
    final List<DonorResponse> initialResponses = [];
    
    for (var citizen in _profiles) {
      if (citizen.isBloodDonor && _isBloodGroupCompatible(bloodGroup, citizen.bloodGroup)) {
        // Calculate mock distance (using simple Euclidean distance for simulator)
        final distance = _calculateDistance(lat, lng, citizen.homeLat, citizen.homeLng);
        if (distance <= radiusKm) {
          initialResponses.add(DonorResponse(
            donorId: citizen.id,
            donorName: citizen.fullName,
            phone: citizen.phoneNumber,
            status: DonorResponseStatus.pending,
            etaMinutes: 0,
            lat: citizen.homeLat,
            lng: citizen.homeLng,
          ));

          // Trigger simulated SMS to this donor
          _sendMockSMS(
            donorId: citizen.id,
            phoneNumber: citizen.phoneNumber,
            message: 'EMERGENCY: $hospitalName requires $bloodGroup blood immediately. Within ${distance.toStringAsFixed(1)}km. Reply "1" to accept, "2" to decline.',
            requestId: requestId,
          );
        }
      }
    }

    final newRequest = BloodRequest(
      requestId: requestId,
      hospitalName: hospitalName,
      hospitalAddress: hospitalAddress,
      bloodGroup: bloodGroup,
      unitsNeeded: unitsNeeded,
      lat: lat,
      lng: lng,
      radiusKm: radiusKm,
      status: 'active',
      responses: initialResponses,
      timestamp: DateTime.now(),
    );

    _bloodRequests.insert(0, newRequest);
    notifyListeners();

    // Persist to backend asynchronously
    ApiService.declareBloodEmergency(
      hospitalName: hospitalName,
      hospitalAddress: hospitalAddress,
      bloodGroup: bloodGroup,
      unitsNeeded: unitsNeeded,
      lat: lat,
      lng: lng,
      radiusKm: radiusKm,
    ).then((result) {
      if (result['success'] == true) {
        debugPrint('Blood emergency persisted to backend: ${result["requestId"]}');
      }
    }).catchError((e) => debugPrint('Blood emergency API error: $e'));

    // Start a timer to simulate automated responses from other mock donors in the network
    _startResponseSimulation(requestId);
  }

  // Handle donor response — updates local state and syncs to backend
  void respondToBloodRequest(String requestId, String donorId, DonorResponseStatus responseStatus, {int? eta}) {
    final reqIdx = _bloodRequests.indexWhere((r) => r.requestId == requestId);
    if (reqIdx == -1) return;

    final request = _bloodRequests[reqIdx];
    final respIdx = request.responses.indexWhere((r) => r.donorId == donorId);
    if (respIdx == -1) return;

    final existingResp = request.responses[respIdx];
    
    // Generate simulated ETA if accepted
    int calculatedEta = eta ?? (10 + (respIdx * 3) + 2);
    if (responseStatus == DonorResponseStatus.declined) {
      calculatedEta = 0;
    }

    final updatedResponse = existingResp.copyWith(
      status: responseStatus,
      etaMinutes: calculatedEta,
    );

    final updatedResponses = List<DonorResponse>.from(request.responses);
    updatedResponses[respIdx] = updatedResponse;

    _bloodRequests[reqIdx] = request.copyWith(responses: updatedResponses);

    // If accepted, reward life credits
    if (responseStatus == DonorResponseStatus.accepted) {
      final citizenIdx = _profiles.indexWhere((p) => p.id == donorId);
      if (citizenIdx != -1) {
        final profile = _profiles[citizenIdx];
        _profiles[citizenIdx] = profile.copyWith(
          lifeCredits: profile.lifeCredits + 100,
        );
      }
    }

    notifyListeners();

    // Sync response to backend
    final statusStr = responseStatus == DonorResponseStatus.accepted
        ? 'accepted'
        : responseStatus == DonorResponseStatus.declined
            ? 'declined'
            : 'pending';
    ApiService.respondToBloodRequest(
      requestId, donorId, statusStr,
      eta: eta ?? 15,
    ).catchError((e) => debugPrint('respondToBloodRequest API error: $e'));
  }

  // Simulates donor replying "1" or "2" to the SMS
  void simulateSmsReply(String smsId, String reply) {
    final smsIdx = _mockSmsInbox.indexWhere((s) => s['id'] == smsId);
    if (smsIdx == -1) return;

    final sms = _mockSmsInbox[smsIdx];
    final String requestId = sms['requestId'];
    final String donorId = sms['donorId'];

    _mockSmsInbox[smsIdx]['replied'] = true;
    _mockSmsInbox[smsIdx]['replyText'] = reply;

    if (reply == '1') {
      respondToBloodRequest(requestId, donorId, DonorResponseStatus.accepted);
    } else if (reply == '2') {
      respondToBloodRequest(requestId, donorId, DonorResponseStatus.declined);
    }
    notifyListeners();
  }

  // Private helpers for calculation and seed data
  bool _isBloodGroupCompatible(String patientGroup, String donorGroup) {
    // Simple exact matches or O- (universal donor) for general compatibility
    if (donorGroup == 'O-') return true;
    if (patientGroup == donorGroup) return true;
    
    // Basic Blood Compatibility Logic:
    // AB+ can receive from anyone
    if (patientGroup == 'AB+') return true;
    // O+ can receive from O+ or O-
    if (patientGroup == 'O+' && (donorGroup == 'O+' || donorGroup == 'O-')) return true;
    // A+ can receive from A+, A-, O+, O-
    if (patientGroup == 'A+' && (donorGroup == 'A+' || donorGroup == 'A-' || donorGroup == 'O+' || donorGroup == 'O-')) return true;
    // B+ can receive from B+, B-, O+, O-
    if (patientGroup == 'B+' && (donorGroup == 'B+' || donorGroup == 'B-' || donorGroup == 'O+' || donorGroup == 'O-')) return true;
    
    return false;
  }

  double _calculateDistance(double lat1, double lng1, double lat2, double lng2) {
    // Basic Euclidean distance scaled to km for simulator simplicity
    // 1 degree latitude ~ 111 km
    final dy = (lat1 - lat2) * 111.0;
    final dx = (lng1 - lng2) * 111.0 * 0.98; // correction factor near Bangalore lat
    return double.parse((dy * dy + dx * dx).toString()); // returning distance
  }

  void _sendMockSMS({
    required String donorId,
    required String phoneNumber,
    required String message,
    required String requestId,
  }) {
    _mockSmsInbox.insert(0, {
      'id': 'SMS-${DateTime.now().millisecondsSinceEpoch}-${donorId}',
      'donorId': donorId,
      'phone': phoneNumber,
      'message': message,
      'requestId': requestId,
      'timestamp': DateTime.now(),
      'replied': false,
      'replyText': '',
    });
    notifyListeners();
  }

  void _startResponseSimulation(String requestId) {
    _simulationTimer?.cancel();
    
    int step = 0;
    _simulationTimer = Timer.periodic(const Duration(seconds: 3), (timer) {
      final reqIdx = _bloodRequests.indexWhere((r) => r.requestId == requestId);
      if (reqIdx == -1) {
        timer.cancel();
        return;
      }

      final request = _bloodRequests[reqIdx];
      // Find pending responses that are NOT the currently active simulated user
      final pendingResponses = request.responses
          .where((r) => r.status == DonorResponseStatus.pending && r.donorId != _currentCitizenProfileId)
          .toList();

      if (pendingResponses.isEmpty || step >= 4) {
        timer.cancel();
        return;
      }

      // Select a random donor to reply
      final targetDonor = pendingResponses[step % pendingResponses.length];
      
      // 70% accept rate, 30% decline rate for simulation
      final accept = (step % 3 != 2);
      final status = accept ? DonorResponseStatus.accepted : DonorResponseStatus.declined;

      respondToBloodRequest(requestId, targetDonor.donorId, status);
      
      // Update SMS inbox reply (simulated)
      final smsIdx = _mockSmsInbox.indexWhere((s) => s['requestId'] == requestId && s['donorId'] == targetDonor.donorId);
      if (smsIdx != -1) {
        _mockSmsInbox[smsIdx]['replied'] = true;
        _mockSmsInbox[smsIdx]['replyText'] = accept ? '1' : '2';
      }

      step++;
    });
  }

  void _seedProfiles() {
    // Profile 1: Rajesh Kumar (Active citizen being simulated)
    _profiles.add(MedicalProfile(
      id: 'x7k9m2',
      fullName: 'Rajesh Kumar',
      bloodGroup: 'B+',
      allergies: 'None',
      medications: 'None',
      emergencyContacts: [
        EmergencyContact(name: 'Sneha Kumar', relation: 'Spouse', phone: '+91 98765 43210'),
        EmergencyContact(name: 'Anil Kumar', relation: 'Father', phone: '+91 98765 01234'),
      ],
      isDnr: false,
      specialInstructions: 'None',
      insuranceCompany: 'HDFC Ergo Health Optima',
      insurancePolicyNumber: 'POL-8873491-02',
      chronicConditions: 'None',
      lifeCredits: 350,
      isBloodDonor: true,
      donorRadiusKm: 5.0,
      homeLat: 12.9722, // Near MG Road Bangalore
      homeLng: 77.5938,
      phoneNumber: '+91 99001 12233',
    ));

    // Profile 2: Priya Patel (A+ Donor, near hospital)
    _profiles.add(MedicalProfile(
      id: 'p3n8k1',
      fullName: 'Priya Patel',
      bloodGroup: 'A+',
      allergies: 'Peanut allergy, Latex',
      medications: 'None',
      emergencyContacts: [
        EmergencyContact(name: 'Ketan Patel', relation: 'Brother', phone: '+91 99223 34455'),
      ],
      isDnr: false,
      specialInstructions: 'Severe peanut allergy. Epipen in backpack.',
      insuranceCompany: 'Star Health Assure',
      insurancePolicyNumber: 'POL-1092842',
      chronicConditions: 'None',
      lifeCredits: 800,
      isBloodDonor: true,
      donorRadiusKm: 4.5,
      homeLat: 12.9592, // Richmond Town, Bangalore
      homeLng: 77.5978,
      phoneNumber: '+91 99112 23344',
    ));

    // Profile 3: Amit Verma (O- Universal Donor, close to hospital)
    _profiles.add(MedicalProfile(
      id: 'a2m9b7',
      fullName: 'Amit Verma',
      bloodGroup: 'O-',
      allergies: 'None',
      medications: 'Metformin 500mg',
      emergencyContacts: [
        EmergencyContact(name: 'Sunita Verma', relation: 'Mother', phone: '+91 99887 76655'),
      ],
      isDnr: true, // DNR ORDERED
      specialInstructions: 'Type-2 Diabetic. DNR active. See medical directive.',
      insuranceCompany: 'ICICI Lombard Health Shield',
      insurancePolicyNumber: 'POL-7763102',
      chronicConditions: 'Type-2 Diabetes',
      lifeCredits: 1200,
      isBloodDonor: true,
      donorRadiusKm: 6.0,
      homeLat: 12.9782, // Vasanth Nagar, Bangalore
      homeLng: 77.5912,
      phoneNumber: '+91 99334 45566',
    ));

    // Profile 4: Dr. Vikram Roy (B+ Donor, slightly further away)
    _profiles.add(MedicalProfile(
      id: 'v5t2y8',
      fullName: 'Dr. Vikram Roy',
      bloodGroup: 'B+',
      allergies: 'Aspirin',
      medications: 'Atorvastatin 10mg',
      emergencyContacts: [
        EmergencyContact(name: 'Ritu Roy', relation: 'Spouse', phone: '+91 99556 67788'),
      ],
      isDnr: false,
      specialInstructions: 'Hypertension. Has medical ID bracelet.',
      insuranceCompany: 'Niva Bupa Health Companion',
      insurancePolicyNumber: 'POL-5542109',
      chronicConditions: 'Hypertension',
      lifeCredits: 50,
      isBloodDonor: true,
      donorRadiusKm: 3.0,
      homeLat: 12.9855, // Indiranagar, Bangalore (further away)
      homeLng: 77.6385,
      phoneNumber: '+91 99667 78899',
    ));

    // Profile 5: Meera Sen (O+ Donor, very close)
    _profiles.add(MedicalProfile(
      id: 'm1s4q9',
      fullName: 'Meera Sen',
      bloodGroup: 'O+',
      allergies: 'None',
      medications: 'None',
      emergencyContacts: [
        EmergencyContact(name: 'Rajesh Sen', relation: 'Father', phone: '+91 99778 89900'),
      ],
      isDnr: false,
      specialInstructions: 'None',
      insuranceCompany: 'Aditya Birla Activ Health',
      insurancePolicyNumber: 'POL-4432190',
      chronicConditions: 'None',
      lifeCredits: 600,
      isBloodDonor: true,
      donorRadiusKm: 5.0,
      homeLat: 12.9648, // Shanti Nagar, Bangalore (very close)
      homeLng: 77.5960,
      phoneNumber: '+91 99889 90011',
    ));
    
    // Seed organ pledges for some users to allow instant verification demo
    signOrganPledge('x7k9m2', ['Corneas', 'Heart', 'Kidneys']);
    signOrganPledge('a2m9b7', ['All Organs', 'Tissues']);
  }

  @override
  void dispose() {
    _simulationTimer?.cancel();
    super.dispose();
  }
}
