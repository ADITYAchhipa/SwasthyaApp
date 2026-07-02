import 'dart:convert';
import 'package:crypto/crypto.dart';

class EmergencyContact {
  final String name;
  final String relation;
  final String phone;

  EmergencyContact({
    required this.name,
    required this.relation,
    required this.phone,
  });

  Map<String, dynamic> toJson() => {
        'name': name,
        'relation': relation,
        'phone': phone,
      };

  factory EmergencyContact.fromJson(Map<String, dynamic> json) => EmergencyContact(
        name: json['name'] ?? '',
        relation: json['relation'] ?? '',
        phone: json['phone'] ?? '',
      );
}

class OrganDonationPledge {
  final String pledgeId;
  final List<String> pledgedOrgans;
  final String signedDate;
  final String signatureHash;
  final bool nottoVerified;

  OrganDonationPledge({
    required this.pledgeId,
    required this.pledgedOrgans,
    required this.signedDate,
    required this.signatureHash,
    this.nottoVerified = true,
  });

  Map<String, dynamic> toJson() => {
        'pledgeId': pledgeId,
        'pledgedOrgans': pledgedOrgans,
        'signedDate': signedDate,
        'signatureHash': signatureHash,
        'nottoVerified': nottoVerified,
      };

  factory OrganDonationPledge.fromJson(Map<String, dynamic> json) {
    return OrganDonationPledge(
      pledgeId: json['pledgeId'] ?? '',
      pledgedOrgans: List<String>.from(json['pledgedOrgans'] ?? []),
      signedDate: json['signedDate'] ?? '',
      signatureHash: json['signatureHash'] ?? '',
      nottoVerified: json['nottoVerified'] ?? false,
    );
  }

  // Generate cryptographic hash of pledge details
  static String generateHash({
    required String citizenId,
    required String fullName,
    required String date,
    required List<String> organs,
  }) {
    final payload = '$citizenId|$fullName|$date|${organs.join(",")}';
    final bytes = utf8.encode(payload);
    return sha256.convert(bytes).toString();
  }
}

class MedicalProfile {
  final String id; // URL slug, e.g., 'x7k9m2'
  final String fullName;
  final String bloodGroup;
  final int? age;
  final String address;
  final String allergies;
  final String medications;
  final List<EmergencyContact> emergencyContacts;
  final bool isDnr; // Do Not Resuscitate
  final String specialInstructions;
  final OrganDonationPledge? organPledge;

  // Active / Online Details
  final String insuranceCompany;
  final String insurancePolicyNumber;
  final String chronicConditions;
  final int lifeCredits;
  final bool isBloodDonor;
  final double donorRadiusKm;
  final double homeLat;
  final double homeLng;
  final String phoneNumber;
  final String email;
  final String? profileImage;

  MedicalProfile({
    required this.id,
    required this.fullName,
    required this.bloodGroup,
    this.age,
    this.address = '',
    required this.allergies,
    required this.medications,
    required this.emergencyContacts,
    this.isDnr = false,
    required this.specialInstructions,
    this.organPledge,
    this.insuranceCompany = '',
    this.insurancePolicyNumber = '',
    this.chronicConditions = '',
    this.lifeCredits = 0,
    this.isBloodDonor = false,
    this.donorRadiusKm = 5.0,
    this.homeLat = 12.9716, // Default Bangalore
    this.homeLng = 77.5946,
    required this.phoneNumber,
    this.email = '',
    this.profileImage,
  });

  // Generates offline NDEF JSON payload (max 8KB, keeps it lightweight)
  String toNdefPayload() {
    final data = {
      'id': id,
      'name': fullName,
      'blood': bloodGroup,
      'age': age,
      'address': address,
      'allergies': allergies,
      'meds': medications,
      'contacts': emergencyContacts.map((c) => c.toJson()).toList(),
      'dnr': isDnr,
      'instructions': specialInstructions,
      'consentHash': organPledge?.signatureHash ?? '',
      'email': email,
      'profileImage': profileImage,
    };
    return jsonEncode(data);
  }

  MedicalProfile copyWith({
    String? fullName,
    String? bloodGroup,
    int? age,
    String? address,
    String? allergies,
    String? medications,
    List<EmergencyContact>? emergencyContacts,
    bool? isDnr,
    String? specialInstructions,
    OrganDonationPledge? organPledge,
    String? insuranceCompany,
    String? insurancePolicyNumber,
    String? chronicConditions,
    int? lifeCredits,
    bool? isBloodDonor,
    double? donorRadiusKm,
    double? homeLat,
    double? homeLng,
    String? phoneNumber,
    String? email,
    String? profileImage,
  }) {
    return MedicalProfile(
      id: id,
      fullName: fullName ?? this.fullName,
      bloodGroup: bloodGroup ?? this.bloodGroup,
      age: age ?? this.age,
      address: address ?? this.address,
      allergies: allergies ?? this.allergies,
      medications: medications ?? this.medications,
      emergencyContacts: emergencyContacts ?? this.emergencyContacts,
      isDnr: isDnr ?? this.isDnr,
      specialInstructions: specialInstructions ?? this.specialInstructions,
      organPledge: organPledge ?? this.organPledge,
      insuranceCompany: insuranceCompany ?? this.insuranceCompany,
      insurancePolicyNumber: insurancePolicyNumber ?? this.insurancePolicyNumber,
      chronicConditions: chronicConditions ?? this.chronicConditions,
      lifeCredits: lifeCredits ?? this.lifeCredits,
      isBloodDonor: isBloodDonor ?? this.isBloodDonor,
      donorRadiusKm: donorRadiusKm ?? this.donorRadiusKm,
      homeLat: homeLat ?? this.homeLat,
      homeLng: homeLng ?? this.homeLng,
      phoneNumber: phoneNumber ?? this.phoneNumber,
      email: email ?? this.email,
      profileImage: profileImage ?? this.profileImage,
    );
  }

  double get profileCompleteness {
    double score = 0.0;
    if (fullName.trim().isNotEmpty && fullName != 'SwasthyaTap User') score += 0.15;
    if (bloodGroup.trim().isNotEmpty && bloodGroup != 'Unknown') score += 0.15;
    if (age != null) score += 0.10;
    if (address.trim().isNotEmpty) score += 0.10;
    if (allergies.trim().isNotEmpty && allergies != 'None') score += 0.10;
    if (medications.trim().isNotEmpty && medications != 'None') score += 0.10;
    if (emergencyContacts.isNotEmpty) score += 0.15;
    if (organPledge != null) score += 0.10;
    if (insuranceCompany.trim().isNotEmpty) score += 0.05;
    return score;
  }
}

enum DonorResponseStatus { pending, accepted, declined }

class DonorResponse {
  final String donorId;
  final String donorName;
  final String phone;
  final DonorResponseStatus status;
  final int etaMinutes;
  final double lat;
  final double lng;

  DonorResponse({
    required this.donorId,
    required this.donorName,
    required this.phone,
    required this.status,
    required this.etaMinutes,
    required this.lat,
    required this.lng,
  });

  DonorResponse copyWith({
    DonorResponseStatus? status,
    int? etaMinutes,
    double? lat,
    double? lng,
  }) {
    return DonorResponse(
      donorId: donorId,
      donorName: donorName,
      phone: phone,
      status: status ?? this.status,
      etaMinutes: etaMinutes ?? this.etaMinutes,
      lat: lat ?? this.lat,
      lng: lng ?? this.lng,
    );
  }
}

class BloodRequest {
  final String requestId;
  final String hospitalName;
  final String hospitalAddress;
  final String bloodGroup;
  final int unitsNeeded;
  final double lat;
  final double lng;
  final double radiusKm;
  final String status; // 'active', 'completed'
  final List<DonorResponse> responses;
  final DateTime timestamp;

  BloodRequest({
    required this.requestId,
    required this.hospitalName,
    required this.hospitalAddress,
    required this.bloodGroup,
    required this.unitsNeeded,
    required this.lat,
    required this.lng,
    required this.radiusKm,
    required this.status,
    required this.responses,
    required this.timestamp,
  });

  BloodRequest copyWith({
    String? status,
    List<DonorResponse>? responses,
  }) {
    return BloodRequest(
      requestId: requestId,
      hospitalName: hospitalName,
      hospitalAddress: hospitalAddress,
      bloodGroup: bloodGroup,
      unitsNeeded: unitsNeeded,
      lat: lat,
      lng: lng,
      radiusKm: radiusKm,
      status: status ?? this.status,
      responses: responses ?? this.responses,
      timestamp: timestamp,
    );
  }
}
