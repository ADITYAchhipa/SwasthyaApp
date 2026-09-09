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

  // Health Reports state
  final List<HealthReport> _healthReports = [];

  // Prescriptions state
  final List<Prescription> _prescriptions = [];

  SwasthyaTapProvider() {
    _seedProfiles();
    _seedHealthReports();
    _seedPrescriptions();
    _syncFromCurrentProfile();
  }

  // Getters
  List<Prescription> get prescriptions => _prescriptions;
  List<HealthReport> get healthReports => _healthReports;
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
    _syncFromCurrentProfile();
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
    _syncFromCurrentProfile();
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
      _syncFromCurrentProfile();
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
          orElse: () => createProfileFromNdef(data),
        );
        _scannedProfile = backendProfile;
        _scannedOfflineOnly = false;
      } else {
        // Offline Mode: create a restricted profile containing ONLY the NDEF data
        _scannedProfile = createProfileFromNdef(data);
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
  MedicalProfile createProfileFromNdef(Map<String, dynamic> data) {
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

  void toggleReportFavorite(String reportId) {
    final idx = _healthReports.indexWhere((r) => r.id == reportId);
    if (idx != -1) {
      _healthReports[idx] = _healthReports[idx].copyWith(
        isFavorite: !_healthReports[idx].isFavorite,
      );
      notifyListeners();
    }
  }

  void updateReportNotes(String reportId, String notes) {
    final idx = _healthReports.indexWhere((r) => r.id == reportId);
    if (idx != -1) {
      _healthReports[idx] = _healthReports[idx].copyWith(
        notes: notes,
      );
      notifyListeners();
    }
  }

  void deleteReport(String reportId) {
    _healthReports.removeWhere((r) => r.id == reportId);
    notifyListeners();
  }

  void _seedHealthReports() {
    _healthReports.addAll([
      HealthReport(
        id: 'rep1',
        reportName: 'Complete Blood Count (CBC)',
        hospitalName: 'CityCare Hospital',
        department: 'Hematology',
        doctorName: 'Dr. Rahul Sharma',
        reportDate: '12 May 2026',
        bloodGroup: 'B+',
        tags: ['Hematology', 'Routine Checkup'],
        category: 'Blood Tests',
        uploadedBy: 'CityCare Lab - Tech 04',
        fileType: 'PDF',
        notes: 'Platelets are slightly on the lower side. Rest parameters are within limits. Advised to stay hydrated and repeat test in 2 weeks.',
        isAbnormal: true,
        isFavorite: false,
        fileSize: '245 KB',
        referenceId: 'CBC1205250001',
      ),
      HealthReport(
        id: 'rep2',
        reportName: 'MRI Brain',
        hospitalName: 'Apollo Hospitals',
        department: 'Neurology',
        doctorName: 'Dr. Priya Iyer',
        reportDate: '02 May 2026',
        bloodGroup: 'B+',
        tags: ['Neurology', 'Diagnostic'],
        category: 'MRI',
        uploadedBy: 'Apollo Imaging Wing',
        fileType: 'PDF',
        notes: 'Brain scan shows normal grey-white matter distribution. No acute infarct or hemorrhage detected.',
        isAbnormal: false,
        isFavorite: true,
        fileSize: '4.2 MB',
        referenceId: 'MRI0205268892',
      ),
      HealthReport(
        id: 'rep3',
        reportName: 'Liver Function Test (LFT)',
        hospitalName: 'Manipal Hospital',
        department: 'Biochemistry',
        doctorName: 'Dr. Vikram Sen',
        reportDate: '20 Apr 2026',
        bloodGroup: 'B+',
        tags: ['Biochemistry', 'Liver'],
        category: 'Blood Tests',
        uploadedBy: 'Manipal Diagnostics Lab',
        fileType: 'PDF',
        notes: 'SGOT and SGPT levels are elevated, indicating mild liver inflammation. Limit oily food and alcohol intake.',
        isAbnormal: true,
        isFavorite: false,
        fileSize: '180 KB',
        referenceId: 'LFT2004260023',
      ),
      HealthReport(
        id: 'rep4',
        reportName: 'X-Ray Chest',
        hospitalName: 'CityCare Hospital',
        department: 'Radiology',
        doctorName: 'Dr. Rahul Sharma',
        reportDate: '10 Apr 2026',
        bloodGroup: 'B+',
        tags: ['Pulmonology', 'Imaging'],
        category: 'Radiology',
        uploadedBy: 'CityCare Radiology Dept',
        fileType: 'PDF',
        notes: 'Lung fields are clear. No active infiltrates, cardiomegaly or pleural effusion.',
        isAbnormal: false,
        isFavorite: false,
        fileSize: '1.5 MB',
        referenceId: 'XRY1004261192',
      ),
      HealthReport(
        id: 'rep5',
        reportName: 'Thyroid Profile (T3, T4, TSH)',
        hospitalName: 'Dr. Lal PathLabs',
        department: 'Endocrinology',
        doctorName: 'Dr. S. K. Gupta',
        reportDate: '05 Apr 2026',
        bloodGroup: 'B+',
        tags: ['Endocrinology', 'Thyroid'],
        category: 'Blood Tests',
        uploadedBy: 'Dr. Lal PathLabs Center 12',
        fileType: 'PDF',
        notes: 'TSH is slightly high, suggesting subclinical hypothyroidism. Consult endocrinologist.',
        isAbnormal: true,
        isFavorite: false,
        fileSize: '195 KB',
        referenceId: 'THY0504265431',
      ),
      HealthReport(
        id: 'rep6',
        reportName: 'ECG Report',
        hospitalName: 'Fortis Hospital',
        department: 'Cardiology',
        doctorName: 'Dr. Anil Mehta',
        reportDate: '28 Mar 2026',
        bloodGroup: 'B+',
        tags: ['Cardiology', 'Heart'],
        category: 'ECG',
        uploadedBy: 'Fortis Cardiac Unit',
        fileType: 'PDF',
        notes: 'Normal sinus rhythm, heart rate 72 bpm. No ST-T changes observed.',
        isAbnormal: false,
        isFavorite: false,
        fileSize: '850 KB',
        referenceId: 'ECG2803260908',
      ),
      HealthReport(
        id: 'rep7',
        reportName: 'Lipid Profile',
        hospitalName: 'CityCare Hospital',
        department: 'Cardiology',
        doctorName: 'Dr. Rahul Sharma',
        reportDate: '18 Mar 2026',
        bloodGroup: 'B+',
        tags: ['Cardiology', 'Cholesterol'],
        category: 'Blood Tests',
        uploadedBy: 'CityCare Lab - Tech 04',
        fileType: 'PDF',
        notes: 'Borderline high LDL cholesterol. Advised daily walk and dietary modifications.',
        isAbnormal: true,
        isFavorite: false,
        fileSize: '210 KB',
        referenceId: 'LPD1803262241',
      ),
      HealthReport(
        id: 'rep8',
        reportName: 'Urine Routine',
        hospitalName: 'Apollo Hospitals',
        department: 'Pathology',
        doctorName: 'Dr. Priya Iyer',
        reportDate: '05 Mar 2026',
        bloodGroup: 'B+',
        tags: ['Pathology', 'Routine'],
        category: 'Others',
        uploadedBy: 'Apollo Diagnostics',
        fileType: 'PDF',
        notes: 'Urine routine examination is unremarkable. No signs of infection.',
        isAbnormal: false,
        isFavorite: false,
        fileSize: '140 KB',
        referenceId: 'URN0503260074',
      ),
      HealthReport(
        id: 'rep9',
        reportName: 'CT Scan Abdomen',
        hospitalName: 'Manipal Hospital',
        department: 'Radiology',
        doctorName: 'Dr. Vikram Sen',
        reportDate: '22 Feb 2026',
        bloodGroup: 'B+',
        tags: ['Radiology', 'Abdominal'],
        category: 'CT Scan',
        uploadedBy: 'Manipal Imaging Center',
        fileType: 'PDF',
        notes: 'No abnormal mass or calcification seen in abdominal organs. Liver size is normal.',
        isAbnormal: false,
        isFavorite: false,
        fileSize: '3.8 MB',
        referenceId: 'CTS2202268809',
      ),
      HealthReport(
        id: 'rep10',
        reportName: 'Discharge Summary',
        hospitalName: 'Apollo Hospitals',
        department: 'Surgery',
        doctorName: 'Dr. Rajesh Rao',
        reportDate: '15 Jan 2026',
        bloodGroup: 'B+',
        tags: ['Surgery', 'Inpatient'],
        category: 'Discharge Summary',
        uploadedBy: 'Apollo Medical Records',
        fileType: 'PDF',
        notes: 'Discharged in stable condition post lap-cholecystectomy. Advised follow up in outpatient clinic in 10 days.',
        isAbnormal: false,
        isFavorite: false,
        fileSize: '1.2 MB',
        referenceId: 'DIS1501260421',
      ),
    ]);
  }

  void togglePrescriptionFavorite(String id) {
    final idx = _prescriptions.indexWhere((p) => p.id == id);
    if (idx != -1) {
      _prescriptions[idx] = _prescriptions[idx].copyWith(
        isFavorite: !_prescriptions[idx].isFavorite,
      );
      notifyListeners();
    }
  }

  void toggleMedicineTakenToday(String prescriptionId, String medicineId) {
    final rxIdx = _prescriptions.indexWhere((p) => p.id == prescriptionId);
    if (rxIdx != -1) {
      final medicines = List<PrescriptionMedicine>.from(_prescriptions[rxIdx].medicines);
      final medIdx = medicines.indexWhere((m) => m.id == medicineId);
      if (medIdx != -1) {
        medicines[medIdx] = medicines[medIdx].copyWith(
          isTakenToday: !medicines[medIdx].isTakenToday,
        );
        _prescriptions[rxIdx] = _prescriptions[rxIdx].copyWith(medicines: medicines);
        notifyListeners();
      }
    }
  }

  void deletePrescription(String id) {
    _prescriptions.removeWhere((p) => p.id == id);
    notifyListeners();
  }

  void addPrescription(Prescription p) {
    _prescriptions.insert(0, p);
    notifyListeners();
  }

  void _seedPrescriptions() {
    _prescriptions.addAll([
      Prescription(
        id: 'RX-2026-891',
        doctorName: 'Dr. Amit Shah',
        doctorPhoto: 'https://images.unsplash.com/photo-1622253692010-333f2da6031d?q=80&w=150',
        qualification: 'MD (Cardiology), FACC',
        hospitalName: 'Apollo Speciality Hospital',
        prescriptionDate: '20 Jun 2026',
        validUntil: '20 Jul 2026',
        diagnosis: 'Mild Hypertension & Preventive Checkup',
        medicines: [
          PrescriptionMedicine(
            id: 'med1',
            name: 'Telmisartan 40mg',
            strength: '1 Tablet',
            morning: true,
            afternoon: false,
            night: false,
            beforeFood: false,
            afterFood: true,
            duration: '30 Days',
            quantity: '30 Tablets',
            purpose: 'Control blood pressure',
            sideEffects: 'Dizziness, headache',
            storage: 'Store at room temperature',
            alternatives: 'Telma 40',
            isTakenToday: false,
          ),
          PrescriptionMedicine(
            id: 'med2',
            name: 'Amlodipine 5mg',
            strength: '1 Tablet',
            morning: false,
            afternoon: false,
            night: true,
            beforeFood: false,
            afterFood: true,
            duration: '30 Days',
            quantity: '30 Tablets',
            purpose: 'Control blood pressure',
            sideEffects: 'Ankle swelling',
            storage: 'Store in a cool dry place',
            alternatives: 'Amlopin 5',
            isTakenToday: false,
          ),
          PrescriptionMedicine(
            id: 'med3',
            name: 'Multivitamin Complex',
            strength: '1 Capsule',
            morning: true,
            afternoon: false,
            night: false,
            beforeFood: false,
            afterFood: true,
            duration: '15 Days',
            quantity: '15 Capsules',
            purpose: 'Nutritional supplement',
            sideEffects: 'None',
            storage: 'Store below 25°C',
            alternatives: 'Becosules',
            isTakenToday: false,
          ),
        ],
        testsRecommended: ['Lipid Profile', 'ECG'],
        doctorNotes: 'Maintain low sodium diet, 30 mins morning walk recommended. Follow up after 1 month with BP log.',
        status: 'Active',
      ),
      Prescription(
        id: 'RX-2026-442',
        doctorName: 'Dr. Patel',
        doctorPhoto: 'https://images.unsplash.com/photo-1559839734-2b71ea197ec2?q=80&w=150',
        qualification: 'MBBS, MD (General Medicine)',
        hospitalName: 'City Care Clinic',
        prescriptionDate: '10 May 2026',
        validUntil: '15 May 2026',
        diagnosis: 'Acute Upper Respiratory Tract Infection',
        medicines: [
          PrescriptionMedicine(
            id: 'med4',
            name: 'Amoxicillin 500mg',
            strength: '1 Capsule',
            morning: true,
            afternoon: true,
            night: true,
            beforeFood: false,
            afterFood: true,
            duration: '5 Days',
            quantity: '15 Capsules',
            purpose: 'Antibiotic for throat infection',
            sideEffects: 'Nausea, diarrhea',
            storage: 'Keep away from moisture',
            alternatives: 'Mox 500',
            isTakenToday: false,
          ),
          PrescriptionMedicine(
            id: 'med5',
            name: 'Paracetamol 650mg',
            strength: '1 Tablet',
            morning: true,
            afternoon: true,
            night: true,
            beforeFood: false,
            afterFood: true,
            duration: '5 Days',
            quantity: '10 Tablets',
            purpose: 'Fever and pain relief',
            sideEffects: 'None when taken in limit',
            storage: 'Store below 30°C',
            alternatives: 'Dolo 650',
            isTakenToday: false,
          ),
        ],
        testsRecommended: [],
        doctorNotes: 'Drink warm water and steam inhalation twice daily.',
        status: 'Completed',
      ),
    ]);
  }

  static Prescription _parsePrescriptionFromJson(Map<String, dynamic> json) {
    final rxListJson = (json['rxList'] as List<dynamic>?) ?? [];
    final medicines = rxListJson.map((m) {
      final mMap = m as Map<String, dynamic>;
      
      final freq = (mMap['frequency'] as String? ?? '').toLowerCase();
      final instructions = (mMap['instructions'] as String? ?? '').toLowerCase();
      
      final morning = mMap['morning'] is bool
          ? mMap['morning'] as bool
          : (mMap['morning'] == 'true' || freq.contains('morning') || freq.contains('1-') || freq.contains('1-0-1') || freq.contains('1-1-1') || freq.contains('daily'));
      final afternoon = mMap['afternoon'] is bool
          ? mMap['afternoon'] as bool
          : (mMap['afternoon'] == 'true' || freq.contains('afternoon') || freq.contains('-1-') || freq.contains('1-1-1') || freq.contains('daily'));
      final night = mMap['night'] is bool
          ? mMap['night'] as bool
          : (mMap['night'] == 'true' || freq.contains('night') || freq.contains('-1') || freq.contains('1-0-1') || freq.contains('1-1-1') || freq.contains('daily'));
      
      final beforeFood = mMap['beforeFood'] is bool
          ? mMap['beforeFood'] as bool
          : (mMap['beforeFood'] == 'true' || instructions.contains('before') || instructions.contains('empty'));
      final afterFood = mMap['afterFood'] is bool
          ? mMap['afterFood'] as bool
          : (mMap['afterFood'] == 'true' || !beforeFood);

      return PrescriptionMedicine(
        id: mMap['_id'] as String? ?? mMap['id'] as String? ?? UniqueKey().toString(),
        name: mMap['medicineName'] as String? ?? 'Medicine',
        strength: mMap['dosage'] as String? ?? '1 Tablet',
        morning: morning,
        afternoon: afternoon,
        night: night,
        beforeFood: beforeFood,
        afterFood: afterFood,
        duration: mMap['duration'] as String? ?? '5 days',
        quantity: mMap['quantity'] as String? ?? '10 Units',
        purpose: mMap['purpose'] as String? ?? 'Treatment',
        sideEffects: mMap['sideEffects'] as String? ?? 'None reported',
        storage: mMap['storage'] as String? ?? 'Store in a cool dry place',
        alternatives: mMap['alternatives'] as String? ?? 'N/A',
        isTakenToday: mMap['isTakenToday'] is bool ? mMap['isTakenToday'] as bool : (mMap['isTakenToday'] == 'true'),
      );
    }).toList();

    final testsRecommendedJson = json['testsRecommended'] as List<dynamic>?;
    final List<String> testsRec = testsRecommendedJson != null
        ? testsRecommendedJson.map((e) => e.toString()).toList()
        : [];

    return Prescription(
      id: json['prescriptionId'] as String? ?? json['_id'] as String? ?? UniqueKey().toString(),
      doctorName: json['doctorName'] as String? ?? 'Dr. Unknown',
      doctorPhoto: json['doctorPhoto'] as String? ?? 'https://images.unsplash.com/photo-1612349317150-e413f6a5b16d?w=150',
      qualification: json['qualification'] as String? ?? 'MBBS',
      hospitalName: json['hospitalName'] as String? ?? 'General Hospital',
      prescriptionDate: json['date'] as String? ?? 'Today',
      validUntil: json['validUntil'] as String? ?? '30 Days',
      diagnosis: json['diagnosis'] as String? ?? 'General Consultation',
      medicines: medicines,
      testsRecommended: testsRec,
      doctorNotes: json['doctorNotes'] as String? ?? 'Take medicines as directed.',
      status: json['status'] as String? ?? 'Active',
      isFavorite: json['isFavorite'] is bool ? json['isFavorite'] as bool : (json['isFavorite'] == 'true'),
    );
  }

  static HealthReport _parseHealthReportFromJson(Map<String, dynamic> json) {
    final name = json['name'] as String? ?? 'Report';
    final isPdf = name.toLowerCase().endsWith('.pdf');
    final fileType = json['fileType'] as String? ?? (isPdf ? 'PDF' : 'JPG');
    
    final title = json['title_key'] as String? ?? '';
    String category = json['category'] as String? ?? 'Others';
    if (category == 'Others' && title.isNotEmpty) {
      if (title.toLowerCase().contains('blood') || title.toLowerCase().contains('cbc') || title.toLowerCase().contains('lft')) {
        category = 'Blood Tests';
      } else if (title.toLowerCase().contains('mri')) {
        category = 'MRI';
      } else if (title.toLowerCase().contains('ct scan')) {
        category = 'CT Scan';
      } else if (title.toLowerCase().contains('x-ray') || title.toLowerCase().contains('radiology')) {
        category = 'Radiology';
      } else if (title.toLowerCase().contains('ecg') || title.toLowerCase().contains('ekg')) {
        category = 'ECG';
      } else if (title.toLowerCase().contains('prescription')) {
        category = 'Prescription';
      } else if (title.toLowerCase().contains('discharge')) {
        category = 'Discharge Summary';
      }
    }

    final tagsJson = json['tags'] as List<dynamic>?;
    final List<String> tags = tagsJson != null
        ? tagsJson.map((e) => e.toString()).toList()
        : [category, 'Lab Upload'];

    return HealthReport(
      id: json['_id'] as String? ?? json['id'] as String? ?? UniqueKey().toString(),
      reportName: title.isNotEmpty ? title : 'Medical Report',
      hospitalName: json['issuer_key'] as String? ?? 'General Hospital',
      department: json['department'] as String? ?? (category == 'Blood Tests' ? 'Biochemistry' : (category == 'MRI' || category == 'CT Scan' || category == 'Radiology' ? 'Radiology' : 'General Medicine')),
      doctorName: json['doctor_key'] as String? ?? 'Dr. Unknown',
      reportDate: json['date'] as String? ?? 'Today',
      bloodGroup: json['bloodGroup'] as String?,
      tags: tags,
      category: category,
      uploadedBy: json['uploadedBy'] as String? ?? json['issuer_key'] as String? ?? 'Lab',
      fileType: fileType,
      notes: json['notes'] as String? ?? json['doctorRemarks'] as String? ?? json['status_key'] as String? ?? 'Verified Digital Record',
      isAbnormal: json['isAbnormal'] is bool ? json['isAbnormal'] as bool : (json['isAbnormal'] == 'true'),
      isFavorite: json['isFavorite'] is bool ? json['isFavorite'] as bool : (json['isFavorite'] == 'true'),
      fileSize: json['fileSize'] as String? ?? '1.2 MB',
      referenceId: json['referenceId'] as String? ?? json['_id'] as String? ?? 'REF-UNKNOWN',
      version: json['version'] as String? ?? '1.0.0',
      url: json['url'] as String? ?? json['fileUrl'] as String?,
    );
  }

  void _syncFromCurrentProfile() {
    try {
      final citizen = currentCitizen;
      
      // Sync prescriptions — always rebuild from profile data when available
      if (citizen.prescriptions.isNotEmpty || _currentCitizenProfileId != 'x7k9m2') {
        _prescriptions.clear();
        for (var p in citizen.prescriptions) {
          if (p is Map<String, dynamic>) {
            _prescriptions.add(_parsePrescriptionFromJson(p));
          } else if (p is Prescription) {
            _prescriptions.add(p);
          }
        }
      }
      
      // Sync health reports — always rebuild from MongoDB data (includes web-app-uploaded reports)
      if (citizen.medicalReports.isNotEmpty) {
        _healthReports.clear();
        for (var r in citizen.medicalReports) {
          if (r is Map<String, dynamic>) {
            _healthReports.add(_parseHealthReportFromJson(r));
          } else if (r is HealthReport) {
            _healthReports.add(r);
          }
        }
      } else if (_currentCitizenProfileId != 'x7k9m2') {
        // Non-demo citizen with no reports yet — clear the seeded data
        _healthReports.clear();
      }
      // Note: for demo profile 'x7k9m2' with no reports in DB, keep the seeded data for demo purposes
    } catch (e) {
      debugPrint('Error syncing profiles data: $e');
    }
  }

  Future<void> refreshCurrentCitizen() async {
    try {
      final updatedProfile = await ApiService.getCitizen(_currentCitizenProfileId);
      if (updatedProfile != null) {
        final idx = _profiles.indexWhere((p) => p.id == updatedProfile.id);
        if (idx != -1) {
          _profiles[idx] = updatedProfile;
        } else {
          _profiles.add(updatedProfile);
        }
        _syncFromCurrentProfile();
        notifyListeners();
      }
    } catch (e) {
      debugPrint('Error refreshing citizen profile: $e');
    }
  }

  @override
  void dispose() {
    _simulationTimer?.cancel();
    super.dispose();
  }
}
