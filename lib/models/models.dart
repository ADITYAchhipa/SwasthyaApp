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
  final List<dynamic> medicalReports;
  final List<dynamic> receipts;

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
    this.medicalReports = const [],
    this.receipts = const [],
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
    List<dynamic>? medicalReports,
    List<dynamic>? receipts,
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
      medicalReports: medicalReports ?? this.medicalReports,
      receipts: receipts ?? this.receipts,
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

class HealthReport {
  final String id;
  final String reportName;
  final String hospitalName;
  final String department;
  final String doctorName;
  final String reportDate; // e.g., '12 May 2026'
  final String? bloodGroup;
  final List<String> tags;
  final String category; // 'Blood Tests', 'Radiology', 'MRI', 'CT Scan', 'Prescription', 'Discharge Summary', 'ECG', 'Others'
  final String uploadedBy;
  final String fileType; // 'PDF', 'JPG', etc.
  final String notes;
  final bool isAbnormal;
  final bool isFavorite;
  final String fileSize; // e.g. '245 KB'
  final String referenceId;
  final String version;

  HealthReport({
    required this.id,
    required this.reportName,
    required this.hospitalName,
    required this.department,
    required this.doctorName,
    required this.reportDate,
    this.bloodGroup,
    required this.tags,
    required this.category,
    required this.uploadedBy,
    required this.fileType,
    required this.notes,
    this.isAbnormal = false,
    this.isFavorite = false,
    required this.fileSize,
    required this.referenceId,
    this.version = '1.0.0',
  });

  HealthReport copyWith({
    String? reportName,
    String? hospitalName,
    String? department,
    String? doctorName,
    String? reportDate,
    String? bloodGroup,
    List<String>? tags,
    String? category,
    String? uploadedBy,
    String? fileType,
    String? notes,
    bool? isAbnormal,
    bool? isFavorite,
    String? fileSize,
    String? referenceId,
    String? version,
  }) {
    return HealthReport(
      id: id,
      reportName: reportName ?? this.reportName,
      hospitalName: hospitalName ?? this.hospitalName,
      department: department ?? this.department,
      doctorName: doctorName ?? this.doctorName,
      reportDate: reportDate ?? this.reportDate,
      bloodGroup: bloodGroup ?? this.bloodGroup,
      tags: tags ?? this.tags,
      category: category ?? this.category,
      uploadedBy: uploadedBy ?? this.uploadedBy,
      fileType: fileType ?? this.fileType,
      notes: notes ?? this.notes,
      isAbnormal: isAbnormal ?? this.isAbnormal,
      isFavorite: isFavorite ?? this.isFavorite,
      fileSize: fileSize ?? this.fileSize,
      referenceId: referenceId ?? this.referenceId,
      version: version ?? this.version,
    );
  }
}

class PrescriptionMedicine {
  final String id;
  final String name;
  final String strength;
  final bool morning;
  final bool afternoon;
  final bool night;
  final bool beforeFood;
  final bool afterFood;
  final String duration;
  final String quantity;
  final String purpose;
  final String sideEffects;
  final String storage;
  final String alternatives;
  final bool isTakenToday;

  PrescriptionMedicine({
    required this.id,
    required this.name,
    required this.strength,
    required this.morning,
    required this.afternoon,
    required this.night,
    required this.beforeFood,
    required this.afterFood,
    required this.duration,
    required this.quantity,
    required this.purpose,
    required this.sideEffects,
    required this.storage,
    required this.alternatives,
    this.isTakenToday = false,
  });

  PrescriptionMedicine copyWith({
    String? name,
    String? strength,
    bool? morning,
    bool? afternoon,
    bool? night,
    bool? beforeFood,
    bool? afterFood,
    String? duration,
    String? quantity,
    String? purpose,
    String? sideEffects,
    String? storage,
    String? alternatives,
    bool? isTakenToday,
  }) {
    return PrescriptionMedicine(
      id: id,
      name: name ?? this.name,
      strength: strength ?? this.strength,
      morning: morning ?? this.morning,
      afternoon: afternoon ?? this.afternoon,
      night: night ?? this.night,
      beforeFood: beforeFood ?? this.beforeFood,
      afterFood: afterFood ?? this.afterFood,
      duration: duration ?? this.duration,
      quantity: quantity ?? this.quantity,
      purpose: purpose ?? this.purpose,
      sideEffects: sideEffects ?? this.sideEffects,
      storage: storage ?? this.storage,
      alternatives: alternatives ?? this.alternatives,
      isTakenToday: isTakenToday ?? this.isTakenToday,
    );
  }
}

class Prescription {
  final String id;
  final String doctorName;
  final String doctorPhoto;
  final String qualification;
  final String hospitalName;
  final String prescriptionDate;
  final String validUntil;
  final String diagnosis;
  final List<PrescriptionMedicine> medicines;
  final List<String> testsRecommended;
  final String doctorNotes;
  final String status; // 'Active', 'Completed', 'Expired', 'Draft'
  final bool isFavorite;

  Prescription({
    required this.id,
    required this.doctorName,
    required this.doctorPhoto,
    required this.qualification,
    required this.hospitalName,
    required this.prescriptionDate,
    required this.validUntil,
    required this.diagnosis,
    required this.medicines,
    required this.testsRecommended,
    required this.doctorNotes,
    required this.status,
    this.isFavorite = false,
  });

  Prescription copyWith({
    String? doctorName,
    String? doctorPhoto,
    String? qualification,
    String? hospitalName,
    String? prescriptionDate,
    String? validUntil,
    String? diagnosis,
    List<PrescriptionMedicine>? medicines,
    List<String>? testsRecommended,
    String? doctorNotes,
    String? status,
    bool? isFavorite,
  }) {
    return Prescription(
      id: id,
      doctorName: doctorName ?? this.doctorName,
      doctorPhoto: doctorPhoto ?? this.doctorPhoto,
      qualification: qualification ?? this.qualification,
      hospitalName: hospitalName ?? this.hospitalName,
      prescriptionDate: prescriptionDate ?? this.prescriptionDate,
      validUntil: validUntil ?? this.validUntil,
      diagnosis: diagnosis ?? this.diagnosis,
      medicines: medicines ?? this.medicines,
      testsRecommended: testsRecommended ?? this.testsRecommended,
      doctorNotes: doctorNotes ?? this.doctorNotes,
      status: status ?? this.status,
      isFavorite: isFavorite ?? this.isFavorite,
    );
  }
}
