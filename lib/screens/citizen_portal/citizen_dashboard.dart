import 'dart:ui';
import 'package:crypto/crypto.dart';
import 'dart:convert';
import 'dart:io' as io;
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:image_picker/image_picker.dart';
import '../../providers/swasthya_tap_provider.dart';
import '../../utils/translation_service.dart';
import '../../models/models.dart';
import '../../theme/app_theme.dart';
import '../../widgets/glass_card.dart';
import '../../services/api_service.dart';
import 'edit_medical_profile.dart';
import 'organ_donation_pledge.dart';
import 'nearby_health_centers_screen.dart';
import 'card_viewer_screen.dart';
import 'scanned_profile_screen.dart';
import '../onboarding_screen.dart' hide HeartEcgPainter;
import 'submit_report_screen.dart';
import 'previous_reports_screen.dart';
import 'medical_reports/my_reports_screen.dart';
import 'prescriptions/prescriptions_dashboard_screen.dart';

class CitizenDashboard extends StatefulWidget {
  const CitizenDashboard({Key? key}) : super(key: key);

  @override
  State<CitizenDashboard> createState() => _CitizenDashboardState();
}

class _CitizenDashboardState extends State<CitizenDashboard> with SingleTickerProviderStateMixin {
  int _currentIndex = 0;
  bool _flashOn = false;
  late AnimationController _scannerController;
  late MobileScannerController _cameraController;



  // Form Key & Controllers for editable Health Profile
  final _profileFormKey = GlobalKey<FormState>();
  
  late TextEditingController _fullNameController;
  late TextEditingController _ageController;
  late TextEditingController _addressController;
  late TextEditingController _phoneController;
  late TextEditingController _emailController;
  late TextEditingController _allergiesController;
  late TextEditingController _medicationsController;
  late TextEditingController _chronicConditionsController;
  late TextEditingController _insuranceCompanyController;
  late TextEditingController _insurancePolicyNumberController;
  late TextEditingController _specialInstructionsController;
  
  // Emergency Contacts
  late TextEditingController _contact1NameController;
  late TextEditingController _contact1RelationController;
  late TextEditingController _contact1PhoneController;
  late TextEditingController _contact2NameController;
  late TextEditingController _contact2RelationController;
  late TextEditingController _contact2PhoneController;

  String _bloodGroup = 'O+';
  bool _isDnr = false;
  bool _isProfileInitialized = false;

  void _initProfileFields(MedicalProfile citizen) {
    if (_isProfileInitialized) return;
    
    _fullNameController = TextEditingController(text: citizen.fullName);
    _ageController = TextEditingController(text: citizen.age?.toString() ?? '');
    _addressController = TextEditingController(text: citizen.address);
    _phoneController = TextEditingController(text: citizen.phoneNumber);
    _emailController = TextEditingController(text: citizen.email);
    _allergiesController = TextEditingController(text: citizen.allergies);
    _medicationsController = TextEditingController(text: citizen.medications);
    _chronicConditionsController = TextEditingController(text: citizen.chronicConditions);
    _insuranceCompanyController = TextEditingController(text: citizen.insuranceCompany);
    _insurancePolicyNumberController = TextEditingController(text: citizen.insurancePolicyNumber);
    _specialInstructionsController = TextEditingController(text: citizen.specialInstructions);
    
    // Contacts
    if (citizen.emergencyContacts.isNotEmpty) {
      _contact1NameController = TextEditingController(text: citizen.emergencyContacts[0].name);
      _contact1RelationController = TextEditingController(text: citizen.emergencyContacts[0].relation);
      _contact1PhoneController = TextEditingController(text: citizen.emergencyContacts[0].phone);
    } else {
      _contact1NameController = TextEditingController();
      _contact1RelationController = TextEditingController();
      _contact1PhoneController = TextEditingController();
    }
    
    if (citizen.emergencyContacts.length > 1) {
      _contact2NameController = TextEditingController(text: citizen.emergencyContacts[1].name);
      _contact2RelationController = TextEditingController(text: citizen.emergencyContacts[1].relation);
      _contact2PhoneController = TextEditingController(text: citizen.emergencyContacts[1].phone);
    } else {
      _contact2NameController = TextEditingController();
      _contact2RelationController = TextEditingController();
      _contact2PhoneController = TextEditingController();
    }

    _bloodGroup = citizen.bloodGroup.isNotEmpty && citizen.bloodGroup != 'Unknown' ? citizen.bloodGroup : 'O+';
    _isDnr = citizen.isDnr;

    _isProfileInitialized = true;
  }

  void _saveProfileFromTab(SwasthyaTapProvider provider) async {
    if (_profileFormKey.currentState!.validate()) {
      _profileFormKey.currentState!.save();
      
      final ageStr = _ageController.text.trim();
      final age = ageStr.isNotEmpty ? int.tryParse(ageStr) : null;

      final List<EmergencyContact> contacts = [
        EmergencyContact(
          name: _contact1NameController.text.trim(),
          relation: _contact1RelationController.text.trim(),
          phone: _contact1PhoneController.text.trim(),
        ),
      ];

      if (_contact2NameController.text.trim().isNotEmpty &&
          _contact2PhoneController.text.trim().isNotEmpty) {
        contacts.add(EmergencyContact(
          name: _contact2NameController.text.trim(),
          relation: _contact2RelationController.text.trim(),
          phone: _contact2PhoneController.text.trim(),
        ));
      }

      final updatedProfile = provider.currentCitizen.copyWith(
        fullName: _fullNameController.text.trim(),
        bloodGroup: _bloodGroup,
        age: age,
        address: _addressController.text.trim(),
        allergies: _allergiesController.text.trim(),
        medications: _medicationsController.text.trim(),
        emergencyContacts: contacts,
        isDnr: _isDnr,
        specialInstructions: _specialInstructionsController.text.trim(),
        insuranceCompany: _insuranceCompanyController.text.trim(),
        insurancePolicyNumber: _insurancePolicyNumberController.text.trim(),
        chronicConditions: _chronicConditionsController.text.trim(),
      );

      await provider.updateProfile(updatedProfile);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Profile successfully saved to DB!'),
            backgroundColor: AppTheme.accentTeal,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } else {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Please correct errors in the form first.'),
            backgroundColor: AppTheme.accentRed,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }

  // Localizations Map for High-Fidelity App Conversion
  static const Map<String, Map<String, String>> _localizations = {
    'en': {
      'good_morning': 'Good Morning, ',
      'stay_healthy': 'Stay healthy, Stay safe',
      'emergency_title': 'In Emergency,\nanyone can tap your card',
      'emergency_sub': 'Your health information in < 1 second',
      'quick_actions': 'Quick Actions',
      'see_all': 'See All',
      'tap_nfc': 'Tap NFC',
      'generate_qr': 'Generate QR',
      'blood_network': 'Blood Network',
      'nearby_centers': 'Nearby Centers',
      'emergency_alert': 'Emergency Alert',
      'my_health_card': 'My Health Card',
      'nfc_identity': 'Your NFC Health Identity',
      'view_full_card': 'View Full Card',
      'health_profile': 'Health Profile',
      'complete_profile_desc': 'Complete your profile to help in emergencies',
      'complete_profile_btn': 'Complete\nProfile',
      'educational_videos': 'Educational Videos',
      'report_health_issue': 'Report Health Issue',
      'report_issue_desc': 'Report Dengue / Malaria / Virus symptoms',
      'report_now': 'Report Now',
      'blood_donation': 'Blood Donation',
      'blood_donation_desc': 'Register as donor and save lives',
      'register_now': 'Register Now',
      
      // Bottom Nav
      'nav_home': 'Home',
      'nav_scan': 'Scan',
      'nav_profile': 'Profile',
      'nav_learn': 'Learn',
      'nav_more': 'More',
    },
    'hi': {
      'good_morning': 'शुभ प्रभात, ',
      'stay_healthy': 'स्वस्थ रहें, सुरक्षित रहें',
      'emergency_title': 'आपातकाल में,\nकोई भी आपका कार्ड टैप कर सकता है',
      'emergency_sub': 'आपकी स्वास्थ्य जानकारी < 1 सेकंड में',
      'quick_actions': 'त्वरित कार्रवाई',
      'see_all': 'सभी देखें',
      'tap_nfc': 'एनएफसी टैप',
      'generate_qr': 'क्यूआर जनरेट',
      'blood_network': 'रक्त नेटवर्क',
      'nearby_centers': 'पास के केंद्र',
      'emergency_alert': 'आपातकालीन अलर्ट',
      'my_health_card': 'मेरा स्वास्थ्य कार्ड',
      'nfc_identity': 'आपकी एनएफसी स्वास्थ्य पहचान',
      'view_full_card': 'पूरा कार्ड देखें',
      'health_profile': 'स्वास्थ्य प्रोफ़ाइल',
      'complete_profile_desc': 'आपात स्थिति में मदद के लिए प्रोफ़ाइल पूरी करें',
      'complete_profile_btn': 'प्रोफ़ाइल\nपूरी करें',
      'educational_videos': 'शैक्षणिक वीडियो',
      'report_health_issue': 'स्वास्थ्य समस्या रिपोर्ट',
      'report_issue_desc': 'डेंगू / मलेरिया / वायरस के लक्षणों की रिपोर्ट करें',
      'report_now': 'अभी रिपोर्ट करें',
      'blood_donation': 'रक्तदान',
      'blood_donation_desc': 'दाता के रूप में पंजीकरण करें और जीवन बचाएं',
      'register_now': 'अभी पंजीकरण करें',
      
      // Bottom Nav
      'nav_home': 'होम',
      'nav_scan': 'स्कैन',
      'nav_profile': 'प्रोफ़ाइल',
      'nav_learn': 'सीखें',
      'nav_more': 'अधिक',
    }
  };

  // Translation Helper Function
  String _t(String key, String selectedLanguage) {
    return TranslationService.t(context, key);
  }

  @override
  void initState() {
    super.initState();
    _cameraController = MobileScannerController();
    _scannerController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1800),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _cameraController.dispose();
    _scannerController.dispose();
    if (_isProfileInitialized) {
      _fullNameController.dispose();
      _ageController.dispose();
      _addressController.dispose();
      _phoneController.dispose();
      _emailController.dispose();
      _allergiesController.dispose();
      _medicationsController.dispose();
      _chronicConditionsController.dispose();
      _insuranceCompanyController.dispose();
      _insurancePolicyNumberController.dispose();
      _specialInstructionsController.dispose();
      _contact1NameController.dispose();
      _contact1RelationController.dispose();
      _contact1PhoneController.dispose();
      _contact2NameController.dispose();
      _contact2RelationController.dispose();
      _contact2PhoneController.dispose();
    }
    super.dispose();
  }

  void _onTabSelected(int index) async {
    if (index == 1) {
      try {
        await _cameraController.start();
      } catch (e) {
        debugPrint('Error starting camera: $e');
      }
    } else {
      try {
        await _cameraController.stop();
      } catch (e) {
        debugPrint('Error stopping camera: $e');
      }
    }
    setState(() {
      _currentIndex = index;
    });
  }

  @override
  Widget build(BuildContext context) {
    final provider = Provider.of<SwasthyaTapProvider>(context);
    final citizen = provider.currentCitizen;

    return PopScope(
      canPop: _currentIndex == 0,
      onPopInvoked: (bool didPop) {
        if (didPop) return;
        _onTabSelected(0);
      },
      child: Scaffold(
        backgroundColor: AppTheme.lightBg,
        body: Stack(
          children: [
            // Main Body Content
            SafeArea(
              bottom: false,
              top: _currentIndex != 1, // Full screen for scanner
              child: IndexedStack(
                index: _currentIndex,
                children: [
                  _buildHomeTab(context, provider, citizen),
                  _buildScanTab(context, provider, citizen),
                  _buildHealthProfileTab(context, provider, citizen),
                  _buildMoreTab(context, provider, citizen),
                ],
              ),
            ),

            // Custom Frosted Glass Bottom Navigation Bar
            Positioned(
              left: 0,
              right: 0,
              bottom: 0,
              child: _buildBottomNavigationBar(provider),
            ),
          ],
        ),
      ),
    );
  }

  // ─── 1. Home Tab ───────────────────────────────────────────────────────────
  Widget _buildHomeTab(BuildContext context, SwasthyaTapProvider provider, citizen) {
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 100),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Top Bar (Greeting + Profile + Settings/Notification)
          _buildHomeTopBar(context, provider, citizen),
          const SizedBox(height: 20),

          // Red Emergency Banner
          _buildEmergencyBanner(context, provider),
          const SizedBox(height: 24),

          // Quick Actions Row
          _buildQuickActions(context, provider),
          const SizedBox(height: 26),

          // My Health Card Preview
          _buildHealthCardPreview(context, provider, citizen),
          const SizedBox(height: 26),

          // Health Profile Ring
          _buildHealthProfileProgress(context, provider),
          const SizedBox(height: 26),

          // Bottom Split Cards: Report Health Issue & Blood Donation
          _buildBottomCards(context, provider),
        ],
      ),
    );
  }

  Widget _buildHomeTopBar(BuildContext context, SwasthyaTapProvider provider, citizen) {
    return Row(
      children: [
        // Profile Avatar
        Container(
          width: 50,
          height: 50,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            border: Border.all(color: Colors.white, width: 2),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.08),
                blurRadius: 10,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(25),
            child: _buildAvatarImage(citizen, fontSize: 16),
          ),
        ),
        const SizedBox(width: 14),
        // Greeting Text
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Text(
                    _t('good_morning', provider.selectedLanguage),
                    style: const TextStyle(color: AppTheme.textSecondary, fontSize: 14, fontWeight: FontWeight.w500),
                  ),
                  Text(
                    '${citizen.fullName.split(" ")[0]} 👋',
                    style: const TextStyle(color: AppTheme.textPrimary, fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                ],
              ),
              const SizedBox(height: 3),
              Text(
                _t('stay_healthy', provider.selectedLanguage),
                style: const TextStyle(color: AppTheme.accentTeal, fontSize: 12, fontWeight: FontWeight.bold),
              ),
            ],
          ),
        ),
        // Notification Icon with Badge
        Stack(
          children: [
            IconButton(
              onPressed: () => _onTabSelected(3),
              icon: const Icon(Icons.notifications_none_rounded, color: AppTheme.textPrimary, size: 26),
              style: IconButton.styleFrom(
                backgroundColor: Colors.white,
                elevation: 0.5,
                padding: const EdgeInsets.all(10),
              ),
            ),
            Positioned(
              right: 6,
              top: 6,
              child: Container(
                padding: const EdgeInsets.all(4),
                decoration: const BoxDecoration(
                  color: AppTheme.accentRed,
                  shape: BoxShape.circle,
                ),
                child: const Text(
                  '3',
                  style: TextStyle(color: Colors.white, fontSize: 8, fontWeight: FontWeight.bold),
                ),
              ),
            ),
          ],
        ),
        const SizedBox(width: 10),
        // Settings Icon
        IconButton(
          onPressed: () => _onTabSelected(3),
          icon: const Icon(Icons.settings_outlined, color: AppTheme.textPrimary, size: 26),
          style: IconButton.styleFrom(
            backgroundColor: Colors.white,
            elevation: 0.5,
            padding: const EdgeInsets.all(10),
          ),
        ),
      ],
    );
  }

  Widget _buildEmergencyBanner(BuildContext context, SwasthyaTapProvider provider) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFFEF4444), Color(0xFFDC2626)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFFEF4444).withOpacity(0.25),
            blurRadius: 15,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Stack(
        children: [
          Positioned(
            right: -10,
            bottom: -15,
            child: Opacity(
              opacity: 0.12,
              child: const Icon(Icons.contactless_outlined, size: 100, color: Colors.white),
            ),
          ),
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _t('emergency_title', provider.selectedLanguage),
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        height: 1.3,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      _t('emergency_sub', provider.selectedLanguage),
                      style: TextStyle(
                        color: Colors.white.withOpacity(0.85),
                        fontSize: 11.5,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              // Forward Arrow Circular button
              Container(
                padding: const EdgeInsets.all(10),
                decoration: const BoxDecoration(
                  color: Colors.white,
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.arrow_forward_rounded,
                  color: AppTheme.accentRed,
                  size: 20,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  void _showGenerateQrDialog(BuildContext context, MedicalProfile citizen) {
    showDialog(
      context: context,
      barrierDismissible: true,
      builder: (BuildContext context) {
        String? qrLink;
        bool isLoading = true;

        return StatefulBuilder(
          builder: (context, setState) {
            if (isLoading && qrLink == null) {
              ApiService.fetchNfcWriteUrl(citizen.id).then((result) {
                if (result['success'] == true && result['nfcUrl'] != null) {
                  final String rawUrl = result['nfcUrl'];
                  final String hash = rawUrl.substring(rawUrl.lastIndexOf('/') + 1);
                  setState(() {
                    qrLink = "www.nfc.swasthyatap.in/card/$hash";
                    isLoading = false;
                  });
                } else {
                  // Fallback: generate a 64-character SHA-256 hash of the citizen ID
                  final String fallbackHash = sha256.convert(utf8.encode(citizen.id)).toString();
                  setState(() {
                    qrLink = "www.nfc.swasthyatap.in/card/$fallbackHash";
                    isLoading = false;
                  });
                }
              }).catchError((err) {
                // Fallback: generate a 64-character SHA-256 hash of the citizen ID
                final String fallbackHash = sha256.convert(utf8.encode(citizen.id)).toString();
                setState(() {
                  qrLink = "www.nfc.swasthyatap.in/card/$fallbackHash";
                  isLoading = false;
                });
              });
            }

            return BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 5, sigmaY: 5),
              child: Dialog(
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
                elevation: 10,
                backgroundColor: Colors.transparent,
                child: Container(
                  padding: const EdgeInsets.all(24),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(28),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.15),
                        blurRadius: 20,
                        offset: const Offset(0, 10),
                      ),
                    ],
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const SizedBox(width: 32),
                          Text(
                            "My Swasthya QR",
                            style: GoogleFonts.outfit(
                              fontSize: 20,
                              fontWeight: FontWeight.bold,
                              color: AppTheme.textPrimary,
                            ),
                          ),
                          IconButton(
                            onPressed: () => Navigator.pop(context),
                            icon: const Icon(Icons.close_rounded, color: AppTheme.textSecondary),
                            padding: EdgeInsets.zero,
                            constraints: const BoxConstraints(),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Text(
                        "Scan this code to instantly view your secure digital medical profile.",
                        textAlign: TextAlign.center,
                        style: GoogleFonts.outfit(
                          fontSize: 13,
                          color: AppTheme.textSecondary,
                          height: 1.4,
                        ),
                      ),
                      const SizedBox(height: 24),
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF8FAFC),
                          borderRadius: BorderRadius.circular(24),
                          border: Border.all(color: const Color(0xFFE2E8F0), width: 1.5),
                        ),
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(16),
                          child: SizedBox(
                            width: 200,
                            height: 200,
                            child: isLoading
                                ? const Center(
                                    child: CircularProgressIndicator(
                                      valueColor: AlwaysStoppedAnimation<Color>(AppTheme.accentTeal),
                                    ),
                                  )
                                : Image.network(
                                    "https://api.qrserver.com/v1/create-qr-code/?size=250x250&data=${Uri.encodeComponent(qrLink!)}",
                                    loadingBuilder: (context, child, loadingProgress) {
                                      if (loadingProgress == null) return child;
                                      return const Center(
                                        child: CircularProgressIndicator(
                                          valueColor: AlwaysStoppedAnimation<Color>(AppTheme.accentTeal),
                                        ),
                                      );
                                    },
                                    errorBuilder: (context, error, stackTrace) {
                                      return const Center(
                                        child: Icon(Icons.qr_code_rounded, size: 80, color: Colors.grey),
                                      );
                                    },
                                  ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                        decoration: BoxDecoration(
                          color: const Color(0xFFECFDF5),
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(color: const Color(0xFFA7F3D0), width: 1),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(Icons.verified_user_rounded, color: Color(0xFF059669), size: 16),
                            const SizedBox(width: 6),
                            Text(
                              "Verified SwasthyaTap Link",
                              style: GoogleFonts.outfit(
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                                color: const Color(0xFF047857),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 24),
                      if (!isLoading && qrLink != null) ...[
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                          decoration: BoxDecoration(
                            color: const Color(0xFFF1F5F9),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Row(
                            children: [
                              Expanded(
                                child: Text(
                                  qrLink!,
                                  style: GoogleFonts.outfit(
                                    fontSize: 12,
                                    color: AppTheme.textPrimary,
                                    fontWeight: FontWeight.w500,
                                  ),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                              const SizedBox(width: 8),
                              GestureDetector(
                                onTap: () {
                                  Clipboard.setData(ClipboardData(text: qrLink!));
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(
                                      content: Row(
                                        children: [
                                          const Icon(Icons.check_circle_outline, color: Colors.white, size: 20),
                                          const SizedBox(width: 8),
                                          Text(
                                            "Link copied to clipboard!",
                                            style: GoogleFonts.outfit(fontWeight: FontWeight.w500),
                                          ),
                                        ],
                                      ),
                                      backgroundColor: AppTheme.accentTeal,
                                      behavior: SnackBarBehavior.floating,
                                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                                    ),
                                  );
                                },
                                child: const Icon(
                                  Icons.copy_rounded,
                                  size: 18,
                                  color: AppTheme.accentTeal,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                      const SizedBox(height: 12),
                    ],
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildQuickActions(BuildContext context, SwasthyaTapProvider provider) {
    final actions = [
      {'icon': Icons.phone_android_rounded, 'label': _t('tap_nfc', provider.selectedLanguage), 'color': const Color(0xFF0F766E)},
      {'icon': Icons.qr_code_rounded, 'label': _t('generate_qr', provider.selectedLanguage), 'color': const Color(0xFFF59E0B)},
      {'icon': Icons.assignment_rounded, 'label': 'My Reports', 'color': AppTheme.accentTeal},
      {'icon': Icons.description_rounded, 'label': 'Prescriptions', 'color': const Color(0xFF0F8B8D)},
      {'icon': Icons.bloodtype_outlined, 'label': _t('blood_network', provider.selectedLanguage), 'color': const Color(0xFFDC2626)},
      {'icon': Icons.local_hospital_outlined, 'label': _t('nearby_centers', provider.selectedLanguage), 'color': const Color(0xFF1E40AF)},
      {'icon': Icons.notifications_active_outlined, 'label': _t('emergency_alert', provider.selectedLanguage), 'color': const Color(0xFFF97316)},
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          _t('quick_actions', provider.selectedLanguage),
          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: AppTheme.textPrimary),
        ),
        const SizedBox(height: 14),
        SizedBox(
          height: 100,
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            itemCount: actions.length,
            clipBehavior: Clip.none,
            itemBuilder: (context, index) {
              final action = actions[index];
              return GestureDetector(
                onTap: () {
                  if (index == 0) {
                    _onTabSelected(1);
                  } else if (index == 1) {
                    _showGenerateQrDialog(context, provider.currentCitizen);
                  } else if (index == 2) {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => MyReportsScreen(
                          onTabSelected: (idx) {
                            setState(() {
                              _currentIndex = idx;
                            });
                          },
                        ),
                      ),
                    );
                  } else if (index == 3) {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => PrescriptionsDashboardScreen(
                          onTabSelected: (idx) {
                            setState(() {
                              _currentIndex = idx;
                            });
                          },
                        ),
                      ),
                    );
                  } else if (index == 4) {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => const NearbyHealthCentersScreen(
                          initialFilter: 'Blood Banks',
                        ),
                      ),
                    );
                  } else if (index == 5) {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => const NearbyHealthCentersScreen(
                          initialFilter: 'Hospitals',
                        ),
                      ),
                    );
                  } else if (index == 6) {
                    _showEmergencyAlerts(context, provider);
                  }
                },
                child: Container(
                  width: 78,
                  margin: const EdgeInsets.only(right: 14),
                  child: Column(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: AppTheme.borderColor),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.02),
                              blurRadius: 10,
                              offset: const Offset(0, 4),
                            ),
                          ],
                        ),
                        child: Icon(
                          action['icon'] as IconData,
                          color: action['color'] as Color,
                          size: 24,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        action['label'] as String,
                        style: const TextStyle(
                          fontSize: 10.5,
                          fontWeight: FontWeight.w700,
                          color: AppTheme.textPrimary,
                        ),
                        textAlign: TextAlign.center,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildHealthCardPreview(BuildContext context, SwasthyaTapProvider provider, citizen) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text(
              _t('my_health_card', provider.selectedLanguage),
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: AppTheme.textPrimary),
            ),
            const SizedBox(width: 6),
            const Icon(Icons.verified_user_rounded, color: AppTheme.accentTeal, size: 16),
          ],
        ),
        const SizedBox(height: 3),
        Text(
          _t('nfc_identity', provider.selectedLanguage),
          style: const TextStyle(color: AppTheme.textSecondary, fontSize: 12),
        ),
        const SizedBox(height: 14),
        Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Expanded(
              flex: 5,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const SizedBox(height: 12),
                  GestureDetector(
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => const CardViewerScreen(),
                        ),
                      );
                    },
                    child: Row(
                      children: [
                        Text(
                          _t('view_full_card', provider.selectedLanguage),
                          style: const TextStyle(color: AppTheme.accentTeal, fontSize: 13, fontWeight: FontWeight.bold),
                        ),
                        const SizedBox(width: 4),
                        const Icon(Icons.chevron_right_rounded, size: 16, color: AppTheme.accentTeal),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            // The Premium Card Preview
            Expanded(
              flex: 7,
              child: Container(
                height: 110,
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [
                      Color(0xFF018086),
                      Color(0xFF014757),
                      Color(0xFF011E30),
                    ],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(14),
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFF018086).withOpacity(0.3),
                      blurRadius: 12,
                      offset: const Offset(0, 6),
                    ),
                  ],
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(14),
                  child: Stack(
                    children: [
                      // Tricolor wave detail at bottom right
                      Positioned(
                        bottom: 0,
                        right: 0,
                        left: 45,
                        height: 22,
                        child: CustomPaint(
                          painter: CardTricolorWavePainter(variant: 'Standard'),
                        ),
                      ),
                      
                      // Contactless waves at top right
                      Positioned(
                        top: 10,
                        right: 10,
                        child: CustomPaint(
                          size: const Size(12, 13),
                          painter: ContactlessWavesPainter(color: Colors.white.withOpacity(0.9)),
                        ),
                      ),

                      // QR Code at bottom left
                      Positioned(
                        bottom: 8,
                        left: 8,
                        child: Container(
                          padding: const EdgeInsets.all(2),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(3),
                          ),
                          child: Image.network(
                            'https://api.qrserver.com/v1/create-qr-code/?size=150x150&data=https://swasthtap.in/citizen/${citizen.id}',
                            width: 26,
                            height: 26,
                            fit: BoxFit.contain,
                          ),
                        ),
                      ),

                      // Center Logo, Name & Tagline
                      Center(
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          crossAxisAlignment: CrossAxisAlignment.center,
                          children: [
                            CustomPaint(
                              size: const Size(24, 24),
                              painter: HeartEcgPainter(color: Colors.white),
                            ),
                            const SizedBox(width: 8),
                            Column(
                              mainAxisSize: MainAxisSize.min,
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'SwasthTap',
                                  style: GoogleFonts.poppins(
                                    color: Colors.white,
                                    fontWeight: FontWeight.bold,
                                    fontSize: 16,
                                    letterSpacing: -0.3,
                                  ),
                                ),
                                Text(
                                  TranslationService.t(context, 'card_tagline'),
                                  style: GoogleFonts.poppins(
                                    color: Colors.white.withOpacity(0.85),
                                    fontSize: 6.0,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildHealthProfileProgress(BuildContext context, SwasthyaTapProvider provider) {
    final citizen = provider.currentCitizen;
    return GestureDetector(
      onTap: () => _onTabSelected(2),
      behavior: HitTestBehavior.opaque,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: AppTheme.borderColor),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.015),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Row(
          children: [
            // Progress Ring
            Stack(
              alignment: Alignment.center,
              children: [
                SizedBox(
                  width: 60,
                  height: 60,
                  child: CircularProgressIndicator(
                    value: citizen.profileCompleteness,
                    strokeWidth: 5.5,
                    color: AppTheme.accentTeal,
                    backgroundColor: AppTheme.borderColor.withOpacity(0.5),
                  ),
                ),
                Text(
                  '${(citizen.profileCompleteness * 100).toInt()}%',
                  style: const TextStyle(color: AppTheme.textPrimary, fontWeight: FontWeight.bold, fontSize: 13),
                ),
              ],
            ),
            const SizedBox(width: 16),
            // Description
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    _t('health_profile', provider.selectedLanguage),
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: AppTheme.textPrimary),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    _t('complete_profile_desc', provider.selectedLanguage),
                    style: const TextStyle(color: AppTheme.textSecondary, fontSize: 11.5),
                  ),
                  const SizedBox(height: 8),
                  // Linear Progress bar matching
                  ClipRRect(
                    borderRadius: BorderRadius.circular(3),
                    child: Container(
                      height: 5,
                      width: 120,
                      color: AppTheme.borderColor,
                      child: Align(
                        alignment: Alignment.centerLeft,
                        child: FractionallySizedBox(
                          widthFactor: citizen.profileCompleteness,
                          child: Container(
                            height: 5,
                            color: AppTheme.accentTeal,
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            // Complete button
            OutlinedButton(
              onPressed: () => _onTabSelected(2),
              style: OutlinedButton.styleFrom(
                side: const BorderSide(color: AppTheme.accentTeal, width: 1.2),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              ),
              child: Text(
                _t('complete_profile_btn', provider.selectedLanguage),
                style: const TextStyle(color: AppTheme.accentTeal, fontWeight: FontWeight.bold, fontSize: 11, height: 1.2),
                textAlign: TextAlign.center,
              ),
            ),
          ],
        ),
      ),
    );
  }



  Widget _buildBottomCards(BuildContext context, SwasthyaTapProvider provider) {
    return Row(
      children: [
        // Report Health Issue Card
        Expanded(
          child: Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFFFFF7ED), Color(0xFFFFEDD5)], // Light orange gradient
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: const Color(0xFFFFD8A8)),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.01),
                  blurRadius: 8,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Icon
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(Icons.assignment_late_outlined, color: Color(0xFFF97316), size: 24),
                ),
                const SizedBox(height: 12),
                Text(
                  _t('report_health_issue', provider.selectedLanguage),
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: AppTheme.textPrimary),
                ),
                const SizedBox(height: 4),
                Text(
                  _t('report_issue_desc', provider.selectedLanguage),
                  style: const TextStyle(color: AppTheme.textSecondary, fontSize: 9.5, height: 1.3),
                ),
                const SizedBox(height: 14),
                // Button
                GestureDetector(
                  onTap: () => _showHealthReportOptions(context, provider),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          _t('report_now', provider.selectedLanguage),
                          style: const TextStyle(color: Color(0xFFF97316), fontSize: 11, fontWeight: FontWeight.bold),
                        ),
                        const SizedBox(width: 4),
                        const Icon(Icons.chevron_right_rounded, size: 14, color: Color(0xFFF97316)),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(width: 14),
        // Blood Donation Card
        Expanded(
          child: Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFFF0FDF4), Color(0xFFDCFCE7)], // Light green gradient
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: const Color(0xFFBBF7D0)),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.01),
                  blurRadius: 8,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Icon
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(Icons.water_drop_outlined, color: Color(0xFF16A34A), size: 24),
                ),
                const SizedBox(height: 12),
                Text(
                  _t('blood_donation', provider.selectedLanguage),
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: AppTheme.textPrimary),
                ),
                const SizedBox(height: 4),
                Text(
                  _t('blood_donation_desc', provider.selectedLanguage),
                  style: const TextStyle(color: AppTheme.textSecondary, fontSize: 9.5, height: 1.3),
                ),
                const SizedBox(height: 14),
                // Button
                GestureDetector(
                  onTap: () {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text(_t('blood_donor_success', provider.selectedLanguage)),
                        backgroundColor: AppTheme.accentTeal,
                      ),
                    );
                  },
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          _t('register_now', provider.selectedLanguage),
                          style: const TextStyle(color: Color(0xFF0F766E), fontSize: 11, fontWeight: FontWeight.bold),
                        ),
                        const SizedBox(width: 4),
                        const Icon(Icons.chevron_right_rounded, size: 14, color: Color(0xFF0F766E)),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  // ─── 2. Scan Tab (Real Camera Scan Screen) ────────────────────────
  Widget _buildScanTab(BuildContext context, SwasthyaTapProvider provider, citizen) {
    return Container(
      width: double.infinity,
      height: double.infinity,
      color: Colors.black, // Dark container background
      child: Stack(
        children: [
          // 1. Live Camera Stream using mobile_scanner (only built when this tab is selected)
          Positioned.fill(
            child: _currentIndex == 1
                ? MobileScanner(
                    controller: _cameraController,
                    onDetect: (BarcodeCapture capture) {
                      final List<Barcode> barcodes = capture.barcodes;
                      if (barcodes.isNotEmpty && barcodes.first.rawValue != null) {
                        final String rawValue = barcodes.first.rawValue!;
                        _processScannedData(rawValue, provider);
                      }
                    },
                    errorBuilder: (context, error) {
                      // Return a dark background when no camera/webcam is active
                      return Container(
                        color: Colors.black87,
                        alignment: Alignment.center,
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Icon(Icons.videocam_off_rounded, color: Colors.white38, size: 48),
                            const SizedBox(height: 12),
                            Text(
                              TranslationService.t(context, 'no_camera'),
                              style: const TextStyle(color: Colors.white70, fontSize: 14),
                            ),
                          ],
                        ),
                      );
                    },
                  )
                : const SizedBox.shrink(),
          ),
          
          // 2. Dark Overlay with Transparent Center Cutout Frame (using BlendMode.srcOut trick)
          Positioned.fill(
            child: ColorFiltered(
              colorFilter: ColorFilter.mode(
                Colors.black.withOpacity(0.55),
                BlendMode.srcOut,
              ),
              child: Stack(
                children: [
                  Container(
                    decoration: const BoxDecoration(
                      color: Colors.black,
                      backgroundBlendMode: BlendMode.dstOut,
                    ),
                  ),
                  Align(
                    alignment: Alignment.center,
                    child: Container(
                      width: 240,
                      height: 240,
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(24),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),

          // 3. Central Viewfinder Corners + Sliding Laser Line (Perfectly Centered)
          Center(
            child: GestureDetector(
              onTap: () {
                // Simulate scanning Rajesh's card on tap for testing/debugging
                _processScannedData('x7k9m2', provider);
              },
              child: Stack(
                alignment: Alignment.center,
                children: [
                  // Viewfinder Cutout Spacer matches the transparent cutout size
                  SizedBox(
                    width: 240,
                    height: 240,
                    child: Stack(
                      children: [
                        // Animated vertical sliding scanning laser line
                        AnimatedBuilder(
                          animation: _scannerController,
                          builder: (context, child) {
                            return Align(
                              alignment: Alignment(0, -0.8 + (_scannerController.value * 1.6)),
                              child: child,
                            );
                          },
                          child: Container(
                            height: 3.5,
                            width: double.infinity,
                            decoration: BoxDecoration(
                              color: const Color(0xFF2DD4BF),
                              boxShadow: [
                                BoxShadow(
                                  color: const Color(0xFF2DD4BF).withOpacity(0.85),
                                  blurRadius: 8,
                                  spreadRadius: 2.5,
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  
                  // Viewfinder corners painter (slightly larger than cutout to wrap it)
                  SizedBox(
                    width: 252,
                    height: 252,
                    child: CustomPaint(
                      painter: ScannerFramePainter(),
                    ),
                  ),
                ],
              ),
            ),
          ),
          
          // 4. Header buttons overlayed (Back button, Help button)
          Positioned(
            top: 24,
            left: 20,
            right: 20,
            child: Row(
              children: [
                IconButton(
                  onPressed: () => _onTabSelected(0),
                  icon: const Icon(Icons.arrow_back_rounded, color: Colors.white, size: 24),
                  style: IconButton.styleFrom(
                    backgroundColor: Colors.black.withOpacity(0.5),
                    padding: const EdgeInsets.all(12),
                  ),
                ),
                const Spacer(),
                GestureDetector(
                  onTap: () {
                    showDialog(
                      context: context,
                      builder: (context) => AlertDialog(
                        backgroundColor: Colors.white,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                        title: Text(TranslationService.t(context, 'scanning_help'), style: const TextStyle(fontWeight: FontWeight.bold)),
                        content: Text(
                          TranslationService.t(context, 'scanning_help_content'),
                        ),
                        actions: [
                          TextButton(
                            onPressed: () => Navigator.pop(context),
                            child: Text(TranslationService.t(context, 'got_it'), style: const TextStyle(color: AppTheme.accentTeal)),
                          ),
                        ],
                      ),
                    );
                  },
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                    decoration: BoxDecoration(
                      color: Colors.black.withOpacity(0.5),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.info_outline_rounded, color: Colors.white, size: 16),
                        const SizedBox(width: 6),
                        Text(
                          TranslationService.t(context, 'need_help'),
                          style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w600),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),

          // 5. Instruction Banner positioned above the viewfinder
          Positioned(
            top: 100,
            left: 30,
            right: 30,
            child: Container(
              padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 20),
              decoration: BoxDecoration(
                color: Colors.black.withOpacity(0.65),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: Colors.white.withOpacity(0.1)),
              ),
              child: Column(
                children: [
                  Text(
                    TranslationService.t(context, 'scan_st_qr'),
                    style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 17),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    TranslationService.t(context, 'align_qr_frame'),
                    style: const TextStyle(color: Colors.white70, fontSize: 11.5),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            ),
          ),

          // 6. Simulation Helper Badge (Placed in the gap below the viewfinder)
          Positioned(
            bottom: 245,
            left: 20,
            right: 20,
            child: Center(
              child: GestureDetector(
                onTap: () => _processScannedData('x7k9m2', provider),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.12),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    TranslationService.t(context, 'tap_viewfinder_simulate'),
                    style: TextStyle(color: Colors.white.withOpacity(0.65), fontSize: 10, fontWeight: FontWeight.bold),
                  ),
                ),
              ),
            ),
          ),
          
          // 7. Bottom Action Controls & Security Disclaimer (Positioned above the bottom navigation bar)
          Positioned(
            left: 20,
            right: 20,
            bottom: 96,
            child: Column(
              children: [
                // Flash and Gallery buttons
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    // Toggle Flash
                    GestureDetector(
                      onTap: () async {
                        setState(() {
                          _flashOn = !_flashOn;
                        });
                        try {
                          await _cameraController.toggleTorch();
                        } catch (e) {
                          debugPrint('Torch not supported: $e');
                        }
                      },
                      child: Column(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: _flashOn ? const Color(0xFF2DD4BF).withOpacity(0.12) : Colors.black.withOpacity(0.4),
                              shape: BoxShape.circle,
                              border: Border.all(color: _flashOn ? const Color(0xFF2DD4BF) : Colors.white, width: 1.5),
                            ),
                            child: Icon(
                              _flashOn ? Icons.flashlight_on_rounded : Icons.flashlight_off_rounded,
                              color: _flashOn ? const Color(0xFF2DD4BF) : Colors.white,
                              size: 20,
                            ),
                          ),
                          const SizedBox(height: 6),
                          Text(TranslationService.t(context, 'flash'), style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w600)),
                        ],
                      ),
                    ),
                    const SizedBox(width: 32),
                    // Choose from Gallery
                    GestureDetector(
                      onTap: () async {
                        try {
                          final picker = ImagePicker();
                          final XFile? image = await picker.pickImage(source: ImageSource.gallery);
                          if (image != null) {
                            if (kIsWeb) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                  content: Text('Processing selected image (Web Simulation)...'),
                                  duration: Duration(seconds: 1),
                                ),
                              );
                              await Future.delayed(const Duration(milliseconds: 800));
                              _processScannedData('x7k9m2', provider);
                            } else {
                              final BarcodeCapture? capture = await _cameraController.analyzeImage(image.path);
                              if (capture != null && capture.barcodes.isNotEmpty) {
                                final String? rawValue = capture.barcodes.first.rawValue;
                                if (rawValue != null) {
                                  _processScannedData(rawValue, provider);
                                } else {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(content: Text('No QR code text detected in this image.')),
                                  );
                                }
                              } else {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(content: Text('No QR code detected in this image.')),
                                );
                              }
                            }
                          }
                        } catch (e) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(content: Text('Error choosing/scanning image: $e')),
                          );
                        }
                      },
                      child: Column(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: Colors.black.withOpacity(0.4),
                              shape: BoxShape.circle,
                              border: Border.all(color: Colors.white, width: 1.5),
                            ),
                            child: const Icon(Icons.image_outlined, color: Colors.white, size: 20),
                          ),
                          const SizedBox(height: 6),
                          Text(TranslationService.t(context, 'gallery'), style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w600)),
                        ],
                      ),
                    ),
                    const SizedBox(width: 32),
                    // Temp Profile Button
                    GestureDetector(
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => const ScannedProfileScreen(),
                          ),
                        );
                      },
                      child: Column(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: Colors.black.withOpacity(0.4),
                              shape: BoxShape.circle,
                              border: Border.all(color: Colors.white, width: 1.5),
                            ),
                            child: const Icon(Icons.person_pin_rounded, color: Colors.white, size: 20),
                          ),
                          const SizedBox(height: 6),
                          Text(TranslationService.t(context, 'temp_profile'), style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w600)),
                        ],
                      ),
                    ),
                  ],
                ),
                
                const SizedBox(height: 16),
                
                // Privacy disclaimer
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                  decoration: BoxDecoration(
                    color: Colors.black.withOpacity(0.65),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: Colors.white.withOpacity(0.1)),
                  ),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(6),
                        decoration: BoxDecoration(
                          color: const Color(0xFF10B981).withOpacity(0.15),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(Icons.verified_user_rounded, color: Color(0xFF10B981), size: 16),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              TranslationService.t(context, 'data_secure'),
                              style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 12.5),
                            ),
                            const SizedBox(height: 1),
                            Text(
                              TranslationService.t(context, 'no_store_scanned_info'),
                              style: const TextStyle(color: Colors.white70, fontSize: 10.5),
                            ),
                          ],
                        ),
                      ),
                      const Icon(Icons.chevron_right_rounded, color: Colors.white70, size: 16),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // Decodes the raw text from camera and routes appropriately
  void _processScannedData(String rawValue, SwasthyaTapProvider provider) {
    ScaffoldMessenger.of(context).clearSnackBars();
    
    try {
      final String trimmed = rawValue.trim();
      
      // 1. Try JSON parsing
      if (trimmed.startsWith('{')) {
        final Map<String, dynamic> data = jsonDecode(trimmed);
        if (data.containsKey('fullName')) {
          final id = data['id'] ?? 'scanned_${DateTime.now().millisecondsSinceEpoch}';
          final newCitizen = MedicalProfile(
            id: id,
            fullName: data['fullName'] ?? 'Scanned User',
            bloodGroup: data['bloodGroup'] ?? 'O+',
            allergies: data['allergies'] ?? 'None',
            medications: data['medications'] ?? 'None',
            isDnr: data['isDnr'] ?? false,
            emergencyContacts: [],
            isBloodDonor: data['isBloodDonor'] ?? false,
            donorRadiusKm: 5.0,
            lifeCredits: 0,
            specialInstructions: data['specialInstructions'] ?? 'None',
            phoneNumber: data['phoneNumber'] ?? '9876543210',
          );
          
          // Add to local profile list and set active
          provider.profiles.removeWhere((p) => p.id == id);
          provider.profiles.add(newCitizen);
          provider.setCurrentCitizen(id);
          
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Successfully Scanned Profile: ${newCitizen.fullName}!'),
              backgroundColor: AppTheme.accentGreen,
            ),
          );
        }
      } 
      // 2. Try URL / ID parsing
      else {
        String extractedId = trimmed;
        bool isCardUrl = false;

        if (trimmed.contains('/card/')) {
          extractedId = trimmed.split('/card/').last;
          if (extractedId.contains('/')) {
            extractedId = extractedId.split('/').first;
          }
          if (RegExp(r'^[a-fA-F0-9]{64}$').hasMatch(extractedId) || RegExp(r'^[a-zA-Z0-9]{6}$').hasMatch(extractedId)) {
            isCardUrl = true;
          }
        } else if (RegExp(r'^[a-fA-F0-9]{64}$').hasMatch(trimmed) || RegExp(r'^[a-zA-Z0-9]{6}$').hasMatch(trimmed)) {
          isCardUrl = true;
        }

        if (isCardUrl) {
          // Stop camera scanning session before navigating
          try {
            _cameraController.stop();
          } catch (_) {}

          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => ScannedProfileScreen(profileId: extractedId),
            ),
          ).then((_) {
            // Restart camera scanning when coming back
            try {
              _cameraController.start();
            } catch (_) {}
          });
          return;
        }

        // Fallback for non-card values:
        if (trimmed.contains('/')) {
          extractedId = trimmed.split('/').last;
        }
        
        bool found = false;
        for (var p in provider.profiles) {
          if (p.id.toLowerCase() == extractedId.toLowerCase()) {
            provider.setCurrentCitizen(p.id);
            found = true;
            break;
          }
        }
        
        if (found) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Successfully Decoded Card ID: $extractedId!'),
              backgroundColor: AppTheme.accentGreen,
            ),
          );
        } else {
          // If profile ID is not found, dynamically seed a mockup profile so the scanner still works fully!
          final mockCitizen = MedicalProfile(
            id: extractedId,
            fullName: 'Scanned Card User',
            bloodGroup: 'B+ Group',
            allergies: 'Penicillin, Dust',
            medications: 'Metformin 500mg, Atorvastatin',
            isDnr: false,
            emergencyContacts: [
              EmergencyContact(name: 'Aditi Sharma', relation: 'Spouse', phone: '9876543210'),
            ],
            isBloodDonor: true,
            donorRadiusKm: 4.5,
            lifeCredits: 12,
            specialInstructions: 'Patient suffers from Type-2 diabetes.',
            phoneNumber: '9876543210',
          );
          provider.profiles.add(mockCitizen);
          provider.setCurrentCitizen(mockCitizen.id);
          
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Scanned new card. Created profile for: ${mockCitizen.fullName}!'),
              backgroundColor: AppTheme.accentGreen,
            ),
          );
        }
        // Successfully scanned, jump to the Profile Tab
        _onTabSelected(2);
      }
      
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Scanned Raw Text: $rawValue'),
          backgroundColor: AppTheme.accentTeal,
        ),
      );
    }
  }

  Widget _buildHealthProfileTab(BuildContext context, SwasthyaTapProvider provider, citizen) {
    _initProfileFields(citizen);

    return Container(
      color: const Color(0xFFF8FAFC),
      child: Column(
        children: [
          // Custom Header
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                // Back Button
                GestureDetector(
                  onTap: () {
                    _onTabSelected(0);
                  },
                  child: const Icon(
                    Icons.arrow_back_ios_new_rounded,
                    color: Color(0xFF64748B),
                    size: 20,
                  ),
                ),
                // Logo in the center
                _buildLogoHeader(),
                // Actions: Save button + three dots menu
                Row(
                  children: [
                    ElevatedButton.icon(
                      onPressed: () => _saveProfileFromTab(provider),
                      icon: const Icon(Icons.save_rounded, size: 14, color: Colors.white),
                      label: const Text('Save', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.white)),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppTheme.accentTeal,
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                        minimumSize: Size.zero,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                        elevation: 2,
                      ),
                    ),
                    const SizedBox(width: 12),
                    const Icon(
                      Icons.more_vert_rounded,
                      color: Color(0xFF0F172A),
                      size: 24,
                    ),
                  ],
                ),
              ],
            ),
          ),
          // Scrollable Body
          Expanded(
            child: Form(
              key: _profileFormKey,
              child: SingleChildScrollView(
                physics: const BouncingScrollPhysics(),
                padding: const EdgeInsets.fromLTRB(16, 4, 16, 100),
                child: Column(
                  children: [
                    // Profile details card (no longer animated to avoid distortion/blurriness)
                    _buildProfileDetailsCard(context, provider, citizen),
                    const SizedBox(height: 14),

                    // ── SwasthyaTap ID Card ─────────────────────────────
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          colors: [Color(0xFF0D3B36), Color(0xFF063028)],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(color: const Color(0xFF00C896).withOpacity(0.35)),
                        boxShadow: [BoxShadow(color: const Color(0xFF00C896).withOpacity(0.08), blurRadius: 12, offset: const Offset(0, 4))],
                      ),
                      child: Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(10),
                            decoration: BoxDecoration(
                              color: const Color(0xFF00C896).withOpacity(0.15),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: const Icon(Icons.contactless_rounded, color: Color(0xFF00C896), size: 22),
                          ),
                          const SizedBox(width: 14),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text('SwasthyaTap ID', style: TextStyle(color: Color(0xFF00C896), fontSize: 10, fontWeight: FontWeight.bold, letterSpacing: 1.2)),
                                const SizedBox(height: 4),
                                Text(
                                  citizen.id.toUpperCase(),
                                  style: GoogleFonts.robotoMono(
                                    color: Colors.white,
                                    fontSize: 20,
                                    fontWeight: FontWeight.bold,
                                    letterSpacing: 4,
                                  ),
                                ),
                                const SizedBox(height: 3),
                                const Text('Share with hospital to write your NFC card', style: TextStyle(color: Color(0xFF64748B), fontSize: 10)),
                              ],
                            ),
                          ),
                          IconButton(
                            icon: const Icon(Icons.copy_rounded, color: Color(0xFF00C896), size: 18),
                            onPressed: () {
                              Clipboard.setData(ClipboardData(text: citizen.id));
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                  content: Text('SwasthyaTap ID copied!'),
                                  backgroundColor: Color(0xFF00C896),
                                  behavior: SnackBarBehavior.floating,
                                ),
                              );
                            },
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 18),

                  // 11 Expandable Item Cards
                  Column(
                    children: [
                      // 1. Personal Information
                      _ProfileSectionTile(
                        number: 1,
                        title: _t('personal_info', provider.selectedLanguage),
                        subtitle: _t('personal_info_sub', provider.selectedLanguage),
                        icon: Icons.person_rounded,
                        iconColor: const Color(0xFF0F766E),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            TextFormField(
                              controller: _fullNameController,
                              style: const TextStyle(fontSize: 13, color: Color(0xFF0F172A)),
                              decoration: AppTheme.premiumInputDecoration(
                                label: _t('full_name', provider.selectedLanguage),
                                icon: Icons.person,
                              ),
                              validator: (val) => val == null || val.trim().isEmpty ? 'Full name required' : null,
                            ),
                            const SizedBox(height: 12),
                            TextFormField(
                              controller: _ageController,
                              keyboardType: TextInputType.number,
                              style: const TextStyle(fontSize: 13, color: Color(0xFF0F172A)),
                              decoration: AppTheme.premiumInputDecoration(
                                label: _t('label_age', provider.selectedLanguage),
                                icon: Icons.calendar_today,
                              ),
                              validator: (val) {
                                if (val == null || val.trim().isEmpty) return 'Age required';
                                final age = int.tryParse(val);
                                if (age == null || age <= 0 || age > 120) return 'Invalid age';
                                return null;
                              },
                            ),
                            const SizedBox(height: 12),
                            TextFormField(
                              controller: _addressController,
                              maxLines: 2,
                              style: const TextStyle(fontSize: 13, color: Color(0xFF0F172A)),
                              decoration: AppTheme.premiumInputDecoration(
                                label: _t('label_address', provider.selectedLanguage),
                                icon: Icons.home,
                              ),
                              validator: (val) => val == null || val.trim().isEmpty ? 'Address required' : null,
                            ),
                            const SizedBox(height: 12),
                            TextFormField(
                              controller: _phoneController,
                              keyboardType: TextInputType.phone,
                              style: const TextStyle(fontSize: 13, color: Color(0xFF0F172A)),
                              decoration: AppTheme.premiumInputDecoration(
                                label: _t('phone_number', provider.selectedLanguage),
                                icon: Icons.phone_android,
                              ),
                              validator: (val) => val == null || val.trim().isEmpty ? 'Mobile required' : null,
                            ),
                            const SizedBox(height: 12),
                            TextFormField(
                              controller: _emailController,
                              enabled: false,
                              style: const TextStyle(fontSize: 13, color: Color(0xFF64748B)),
                              decoration: AppTheme.premiumInputDecoration(
                                label: _t('email_id', provider.selectedLanguage),
                                icon: Icons.email,
                              ),
                            ),
                          ],
                        ),
                      ),

                      // 2. Blood Group
                      _ProfileSectionTile(
                        number: 2,
                        title: _t('blood_group', provider.selectedLanguage),
                        subtitle: _t('blood_group_sub', provider.selectedLanguage),
                        icon: Icons.water_drop_rounded,
                        iconColor: const Color(0xFFEF4444),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            DropdownButtonFormField<String>(
                              value: _bloodGroup,
                              dropdownColor: Colors.white,
                              style: const TextStyle(fontSize: 13, color: Color(0xFF0F172A)),
                              decoration: AppTheme.premiumInputDecoration(
                                label: _t('blood_group', provider.selectedLanguage),
                                icon: Icons.bloodtype,
                              ),
                              items: ['O+', 'O-', 'A+', 'A-', 'B+', 'B-', 'AB+', 'AB-'].map((bg) {
                                return DropdownMenuItem(value: bg, child: Text(bg));
                              }).toList(),
                              onChanged: (val) {
                                if (val != null) {
                                  setState(() {
                                    _bloodGroup = val;
                                  });
                                }
                              },
                            ),
                          ],
                        ),
                      ),

                      // 3. Allergies
                      _ProfileSectionTile(
                        number: 3,
                        title: _t('allergies', provider.selectedLanguage),
                        subtitle: _t('allergies_sub', provider.selectedLanguage),
                        icon: Icons.warning_amber_rounded,
                        iconColor: const Color(0xFFF97316),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            TextFormField(
                              controller: _allergiesController,
                              maxLines: 2,
                              style: const TextStyle(fontSize: 13, color: Color(0xFF0F172A)),
                              decoration: AppTheme.premiumInputDecoration(
                                label: 'Allergies Details',
                                icon: Icons.warning,
                              ),
                            ),
                          ],
                        ),
                      ),

                      // 4. Current Medications
                      _ProfileSectionTile(
                        number: 4,
                        title: _t('current_medications', provider.selectedLanguage),
                        subtitle: _t('current_medications_sub', provider.selectedLanguage),
                        icon: Icons.medical_services_rounded,
                        iconColor: const Color(0xFF3B82F6),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            TextFormField(
                              controller: _medicationsController,
                              maxLines: 2,
                              style: const TextStyle(fontSize: 13, color: Color(0xFF0F172A)),
                              decoration: AppTheme.premiumInputDecoration(
                                label: 'Current Medications',
                                icon: Icons.medication,
                              ),
                            ),
                          ],
                        ),
                      ),

                      // 5. Medical Conditions
                      _ProfileSectionTile(
                        number: 5,
                        title: _t('medical_conditions', provider.selectedLanguage),
                        subtitle: _t('medical_conditions_sub', provider.selectedLanguage),
                        icon: Icons.monitor_heart_rounded,
                        iconColor: const Color(0xFF8B5CF6),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            TextFormField(
                              controller: _chronicConditionsController,
                              maxLines: 2,
                              style: const TextStyle(fontSize: 13, color: Color(0xFF0F172A)),
                              decoration: AppTheme.premiumInputDecoration(
                                label: 'Chronic Conditions',
                                icon: Icons.monitor_heart,
                              ),
                            ),
                          ],
                        ),
                      ),

                      // 6. Emergency Contacts
                      _ProfileSectionTile(
                        number: 6,
                        title: _t('emergency_contacts', provider.selectedLanguage),
                        subtitle: _t('emergency_contacts_sub', provider.selectedLanguage),
                        icon: Icons.people_alt_rounded,
                        iconColor: const Color(0xFF10B981),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Primary Emergency Contact',
                              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Color(0xFF0F766E)),
                            ),
                            const SizedBox(height: 8),
                            TextFormField(
                              controller: _contact1NameController,
                              style: const TextStyle(fontSize: 13, color: Color(0xFF0F172A)),
                              decoration: AppTheme.premiumInputDecoration(
                                label: 'Contact Name',
                                icon: Icons.person,
                              ),
                              validator: (val) => val == null || val.trim().isEmpty ? 'Primary Contact Name required' : null,
                            ),
                            const SizedBox(height: 8),
                            Row(
                              children: [
                                Expanded(
                                  child: TextFormField(
                                    controller: _contact1RelationController,
                                    style: const TextStyle(fontSize: 13, color: Color(0xFF0F172A)),
                                    decoration: AppTheme.premiumInputDecoration(
                                      label: 'Relation',
                                      icon: Icons.family_restroom,
                                    ),
                                    validator: (val) => val == null || val.trim().isEmpty ? 'Relation required' : null,
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: TextFormField(
                                    controller: _contact1PhoneController,
                                    keyboardType: TextInputType.phone,
                                    style: const TextStyle(fontSize: 13, color: Color(0xFF0F172A)),
                                    decoration: AppTheme.premiumInputDecoration(
                                      label: 'Phone Number',
                                      icon: Icons.phone,
                                    ),
                                    validator: (val) => val == null || val.trim().isEmpty ? 'Phone required' : null,
                                  ),
                                ),
                              ],
                            ),
                            const Divider(height: 24),
                            const Text(
                              'Secondary Emergency Contact (Optional)',
                              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Color(0xFF0F766E)),
                            ),
                            const SizedBox(height: 8),
                            TextFormField(
                              controller: _contact2NameController,
                              style: const TextStyle(fontSize: 13, color: Color(0xFF0F172A)),
                              decoration: AppTheme.premiumInputDecoration(
                                label: 'Contact Name',
                                icon: Icons.person,
                              ),
                            ),
                            const SizedBox(height: 8),
                            Row(
                              children: [
                                Expanded(
                                  child: TextFormField(
                                    controller: _contact2RelationController,
                                    style: const TextStyle(fontSize: 13, color: Color(0xFF0F172A)),
                                    decoration: AppTheme.premiumInputDecoration(
                                      label: 'Relation',
                                      icon: Icons.family_restroom,
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: TextFormField(
                                    controller: _contact2PhoneController,
                                    keyboardType: TextInputType.phone,
                                    style: const TextStyle(fontSize: 13, color: Color(0xFF0F172A)),
                                    decoration: AppTheme.premiumInputDecoration(
                                      label: 'Phone Number',
                                      icon: Icons.phone,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),

                      // 7. Special Medical Instructions
                      _ProfileSectionTile(
                        number: 7,
                        title: 'Special Instructions',
                        subtitle: 'Critical information for first responders',
                        icon: Icons.health_and_safety_rounded,
                        iconColor: const Color(0xFF10B981),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            TextFormField(
                              controller: _specialInstructionsController,
                              maxLines: 3,
                              style: const TextStyle(fontSize: 13, color: Color(0xFF0F172A)),
                              decoration: AppTheme.premiumInputDecoration(
                                label: 'Special Medical Instructions',
                                icon: Icons.description,
                              ),
                            ),
                          ],
                        ),
                      ),

                      // 8. Insurance Details
                      _ProfileSectionTile(
                        number: 8,
                        title: _t('insurance_schemes', provider.selectedLanguage),
                        subtitle: _t('insurance_schemes_sub', provider.selectedLanguage),
                        icon: Icons.umbrella_rounded,
                        iconColor: const Color(0xFF3B82F6),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            TextFormField(
                              controller: _insuranceCompanyController,
                              style: const TextStyle(fontSize: 13, color: Color(0xFF0F172A)),
                              decoration: AppTheme.premiumInputDecoration(
                                label: 'Insurer Company Name',
                                icon: Icons.business,
                              ),
                            ),
                            const SizedBox(height: 12),
                            TextFormField(
                              controller: _insurancePolicyNumberController,
                              style: const TextStyle(fontSize: 13, color: Color(0xFF0F172A)),
                              decoration: AppTheme.premiumInputDecoration(
                                label: 'Policy Number',
                                icon: Icons.description,
                              ),
                            ),
                          ],
                        ),
                      ),

                      // 9. Medical Reports
                      _ProfileSectionTile(
                        number: 9,
                        title: _t('medical_reports', provider.selectedLanguage),
                        subtitle: _t('medical_reports_sub', provider.selectedLanguage),
                        icon: Icons.description_rounded,
                        iconColor: const Color(0xFF8B5CF6),
                        trailing: GestureDetector(
                          onTap: () {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(content: Text('Upload new report flow...')),
                            );
                          },
                          child: const Icon(Icons.add_rounded, color: Color(0xFF0F766E), size: 18),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'No medical reports uploaded yet.',
                              style: TextStyle(fontSize: 12.5, color: Color(0xFF64748B), fontStyle: FontStyle.italic),
                            ),
                            const SizedBox(height: 8),
                            OutlinedButton.icon(
                              onPressed: () {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(content: Text('Select PDF or Image from device...')),
                                );
                              },
                              icon: const Icon(Icons.upload_file, size: 14),
                              label: const Text('Upload Report', style: TextStyle(fontSize: 11)),
                              style: OutlinedButton.styleFrom(
                                foregroundColor: const Color(0xFF0F766E),
                                side: const BorderSide(color: Color(0xFF0F766E)),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                              ),
                            ),
                          ],
                        ),
                      ),

                      // 10. Organ Donation
                      _ProfileSectionTile(
                        number: 10,
                        title: _t('organ_donation', provider.selectedLanguage),
                        subtitle: _t('organ_donation_sub', provider.selectedLanguage),
                        icon: Icons.favorite_rounded,
                        iconColor: const Color(0xFFF43F5E),
                        trailing: GestureDetector(
                          onTap: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(builder: (_) => const OrganDonationPledgeScreen()),
                            );
                          },
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(color: const Color(0xFF0F766E), width: 1),
                            ),
                            child: Text(
                              citizen.organPledge != null ? _t('manage', provider.selectedLanguage) : 'Pledge',
                              style: const TextStyle(
                                color: Color(0xFF0F766E),
                                fontSize: 9,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ),
                        child: citizen.organPledge != null
                            ? Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  _buildDetailRow(_t('notto_id', provider.selectedLanguage), citizen.organPledge!.pledgeId),
                                  _buildDetailRow(_t('pledged_organs', provider.selectedLanguage), citizen.organPledge!.pledgedOrgans.join(', ')),
                                  _buildDetailRow(_t('signed_date', provider.selectedLanguage), citizen.organPledge!.signedDate),
                                ],
                              )
                            : Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Text(
                                    'No Organ Donation Pledge registered yet.',
                                    style: TextStyle(fontSize: 12.5, color: Color(0xFF64748B), fontStyle: FontStyle.italic),
                                  ),
                                  const SizedBox(height: 8),
                                  ElevatedButton(
                                    onPressed: () {
                                      Navigator.push(
                                        context,
                                        MaterialPageRoute(builder: (_) => const OrganDonationPledgeScreen()),
                                      );
                                    },
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: const Color(0xFFF43F5E),
                                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                                    ),
                                    child: const Text('Register Pledge Now', style: TextStyle(fontSize: 11, color: Colors.white)),
                                  ),
                                ],
                              ),
                      ),

                      // 11. Privacy Settings
                      _ProfileSectionTile(
                        number: 11,
                        title: _t('privacy_settings', provider.selectedLanguage),
                        subtitle: _t('privacy_settings_sub', provider.selectedLanguage),
                        icon: Icons.lock_outline_rounded,
                        iconColor: const Color(0xFF0F766E),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            _buildDetailRow(_t('access_pin', provider.selectedLanguage), _t('pin_enabled', provider.selectedLanguage)),
                            const Divider(height: 16),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                const Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        'Emergency Bypass PIN',
                                        style: TextStyle(fontSize: 12.5, color: Color(0xFF0F172A), fontWeight: FontWeight.bold),
                                      ),
                                      Text(
                                        'Allow responders to bypass PIN in emergency',
                                        style: TextStyle(fontSize: 10.5, color: Color(0xFF64748B)),
                                      ),
                                    ],
                                  ),
                                ),
                                Switch(
                                  value: true,
                                  onChanged: (val) {
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      const SnackBar(content: Text('Bypass PIN option updated locally.')),
                                    );
                                  },
                                  activeColor: const Color(0xFF0F766E),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),

                  // Footer security badges
                  _buildFooterSecurityBadges(),
                  const SizedBox(height: 20),

                  // Bottom Action Buttons
                  _buildBottomActions(context),
                ],
              ),
            ),
          ),
          ),
        ],
      ),
    );
  }

  Widget _buildLogoHeader() {
    return Row(
      mainAxisSize: MainAxisSize.min,
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Stack(
          alignment: Alignment.center,
          clipBehavior: Clip.none,
          children: [
            const Icon(
              Icons.health_and_safety_rounded,
              color: Color(0xFF0F766E),
              size: 26,
            ),
            Positioned(
              top: -8,
              child: const Icon(
                Icons.wifi_rounded,
                color: Color(0xFF0F766E),
                size: 14,
              ),
            ),
          ],
        ),
        const SizedBox(width: 8),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'SwasthyaTap',
              style: GoogleFonts.inter(
                fontSize: 16,
                fontWeight: FontWeight.w800,
                color: const Color(0xFF0F172A),
                letterSpacing: -0.3,
              ),
            ),
            Text(
              'One Tap Can Save Your Life',
              style: GoogleFonts.inter(
                fontSize: 8.5,
                fontWeight: FontWeight.w500,
                color: const Color(0xFF64748B),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildProfileDetailsCard(BuildContext context, SwasthyaTapProvider provider, MedicalProfile citizen) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFFF1F5F9), width: 1.5),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.02),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Left: Avatar with Edit Icon
          GestureDetector(
            onTap: () async {
              try {
                final picker = ImagePicker();
                final XFile? image = await picker.pickImage(source: ImageSource.gallery);
                if (image != null) {
                  final updatedProfile = citizen.copyWith(profileImage: image.path);
                  await provider.updateProfile(updatedProfile);
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Profile image updated successfully!'),
                        backgroundColor: AppTheme.accentTeal,
                        behavior: SnackBarBehavior.floating,
                      ),
                    );
                  }
                }
              } catch (e) {
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('Error choosing image: $e'),
                      backgroundColor: AppTheme.accentRed,
                      behavior: SnackBarBehavior.floating,
                    ),
                  );
                }
              }
            },
            child: Stack(
              children: [
                Container(
                  width: 76,
                  height: 76,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(color: const Color(0xFF0F766E), width: 2),
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(38),
                    child: _buildAvatarImage(citizen, fontSize: 24),
                  ),
                ),
                Positioned(
                  bottom: 0,
                  right: 0,
                  child: Container(
                    padding: const EdgeInsets.all(4),
                    decoration: const BoxDecoration(
                      color: Color(0xFF0F766E),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.camera_alt,
                      color: Colors.white,
                      size: 12,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 14),
          // Middle: Text details
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        citizen.fullName,
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF0F172A),
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                // SwasthyaTap UID Badge
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(
                    color: const Color(0xFFE6F4F1),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    TranslationService.t(context, 'st_uid'),
                    style: const TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF0F766E),
                    ),
                  ),
                ),
                const SizedBox(height: 4),
                // STUID
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        'STUID: ST91-XXXX-XXXX-${citizen.id.toUpperCase()}',
                        style: const TextStyle(
                          fontSize: 10.5,
                          fontWeight: FontWeight.w500,
                          color: Color(0xFF64748B),
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    const SizedBox(width: 4),
                    const Icon(
                      Icons.copy_rounded,
                      color: Color(0xFF94A3B8),
                      size: 11,
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                // Badges Row
                Wrap(
                  spacing: 6,
                  runSpacing: 4,
                  children: [
                    // ABHA Linked Badge
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: const Color(0xFFDCFCE7),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.link, color: Color(0xFF15803D), size: 10),
                          const SizedBox(width: 2),
                          Text(
                            TranslationService.t(context, 'abha_linked'),
                            style: const TextStyle(
                              fontSize: 9,
                              fontWeight: FontWeight.bold,
                              color: Color(0xFF15803D),
                            ),
                          ),
                        ],
                      ),
                    ),
                    // Aadhaar badge
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF1F5F9),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.fingerprint_rounded, color: Color(0xFF64748B), size: 10),
                          const SizedBox(width: 2),
                          Text(
                            TranslationService.t(context, 'aadhaar_badge'),
                            style: const TextStyle(
                              fontSize: 9,
                              fontWeight: FontWeight.bold,
                              color: Color(0xFF64748B),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          // Right: Radial Complete Progress
          const SizedBox(width: 8),
          Column(
            children: [
              Stack(
                alignment: Alignment.center,
                children: [
                  SizedBox(
                    width: 58,
                    height: 58,
                    child: CircularProgressIndicator(
                      value: citizen.profileCompleteness,
                      strokeWidth: 5,
                      backgroundColor: const Color(0xFFF1F5F9),
                      valueColor: const AlwaysStoppedAnimation<Color>(Color(0xFF0F766E)),
                    ),
                  ),
                  Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        '${(citizen.profileCompleteness * 100).toInt()}%',
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w800,
                          color: Color(0xFF0F172A),
                        ),
                      ),
                      const SizedBox(height: 1),
                      Text(
                        TranslationService.t(context, 'complete'),
                        style: const TextStyle(
                          fontSize: 6,
                          fontWeight: FontWeight.w500,
                          color: Color(0xFF64748B),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 6),
              Text(
                TranslationService.t(context, 'profile_complete'),
                style: const TextStyle(
                  fontSize: 7.5,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF64748B),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildAvatarImage(MedicalProfile citizen, {double fontSize = 24}) {
    if (citizen.profileImage != null && citizen.profileImage!.isNotEmpty) {
      if (kIsWeb || citizen.profileImage!.startsWith('http') || citizen.profileImage!.startsWith('blob:')) {
        return Image.network(
          citizen.profileImage!,
          fit: BoxFit.cover,
          errorBuilder: (context, error, stackTrace) {
            return _buildInitialsPlaceholder(citizen, fontSize: fontSize);
          },
        );
      } else {
        return Image.file(
          io.File(citizen.profileImage!),
          fit: BoxFit.cover,
          errorBuilder: (context, error, stackTrace) {
            return _buildInitialsPlaceholder(citizen, fontSize: fontSize);
          },
        );
      }
    }
    
    return _buildInitialsPlaceholder(citizen, fontSize: fontSize);
  }

  Widget _buildInitialsPlaceholder(MedicalProfile citizen, {double fontSize = 24}) {
    String initials = '';
    if (citizen.fullName.trim().isNotEmpty) {
      final parts = citizen.fullName.trim().split(' ');
      if (parts.length >= 2) {
        initials = (parts[0][0] + parts[1][0]).toUpperCase();
      } else if (parts[0].isNotEmpty) {
        initials = parts[0][0].toUpperCase();
      }
    }
    if (initials.isEmpty) {
      initials = 'ST';
    }
    return Container(
      color: const Color(0xFF0F766E),
      alignment: Alignment.center,
      child: Text(
        initials,
        style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: fontSize),
      ),
    );
  }

  Widget _buildDetailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            flex: 2,
            child: Text(
              label,
              style: const TextStyle(fontSize: 12.5, color: Color(0xFF64748B), fontWeight: FontWeight.w500),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            flex: 3,
            child: Text(
              value,
              textAlign: TextAlign.right,
              style: const TextStyle(fontSize: 12.5, color: Color(0xFF0F172A), fontWeight: FontWeight.bold),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFooterSecurityBadges() {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          _buildSecurityBadge(Icons.shield_outlined, TranslationService.t(context, 'data_encrypted_secure')),
          _buildSecurityBadge(Icons.lock_outline_rounded, TranslationService.t(context, 'pin_protected_badge')),
          _buildSecurityBadge(Icons.nfc_outlined, TranslationService.t(context, 'share_nfc_only')),
          _buildSecurityBadge(Icons.verified_user_outlined, TranslationService.t(context, 'hipaa_dpdp_compliant')),
        ],
      ),
    );
  }

  Widget _buildSecurityBadge(IconData icon, String text) {
    return Expanded(
      child: Column(
        children: [
          Icon(icon, color: const Color(0xFF0F766E), size: 18),
          const SizedBox(height: 4),
          Text(
            text,
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontSize: 8.5,
              fontWeight: FontWeight.bold,
              color: Color(0xFF64748B),
              height: 1.2,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBottomActions(BuildContext context) {
    return Column(
      children: [
        // Download My Data
        Material(
          color: const Color(0xFF0F766E),
          borderRadius: BorderRadius.circular(12),
          clipBehavior: Clip.antiAlias,
          child: InkWell(
            onTap: () {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Downloading health report (PDF)...')),
              );
            },
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(6),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.15),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Icon(Icons.download_rounded, color: Colors.white, size: 20),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Download My Data',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          'Export your health data (PDF)',
                          style: TextStyle(
                            fontSize: 11,
                            color: Colors.white.withOpacity(0.8),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const Icon(Icons.chevron_right_rounded, color: Colors.white, size: 20),
                ],
              ),
            ),
          ),
        ),
        const SizedBox(height: 12),
        // Delete Account
        Material(
          color: const Color(0xFFFEE2E2),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
            side: const BorderSide(color: Color(0xFFFCA5A5), width: 1),
          ),
          clipBehavior: Clip.antiAlias,
          child: InkWell(
            onTap: () {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Delete account flow initiated...')),
              );
            },
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(6),
                    decoration: const BoxDecoration(
                      color: Color(0xFFEF4444),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.delete_outline_rounded, color: Colors.white, size: 18),
                  ),
                  const SizedBox(width: 14),
                  const Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Delete Account',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF991B1B),
                          ),
                        ),
                        SizedBox(height: 2),
                        Text(
                          'Permanently delete your data & account',
                          style: TextStyle(
                            fontSize: 11,
                            color: Color(0xFFEF4444),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const Icon(Icons.chevron_right_rounded, color: Color(0xFF991B1B), size: 20),
                ],
              ),
            ),
          ),
        ),
        const SizedBox(height: 8),
        // Info text
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.verified_user_rounded, color: Color(0xFF64748B), size: 12),
            const SizedBox(width: 4),
            Text(
              'You will be asked to confirm with your PIN before deleting your account.',
              style: GoogleFonts.inter(
                fontSize: 9,
                fontWeight: FontWeight.w500,
                color: const Color(0xFF64748B),
              ),
            ),
          ],
        ),
      ],
    );
  }


  // ─── 5. More Tab (Settings Screen) ─────────────────────────────────────────
  Widget _buildMoreTab(BuildContext context, SwasthyaTapProvider provider, citizen) {
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 100),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            TranslationService.t(context, 'settings_title'),
            style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: AppTheme.textPrimary),
          ),
          const SizedBox(height: 18),

          // User info header
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: AppTheme.borderColor),
            ),
            child: Row(
              children: [
                Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(color: Colors.white, width: 2),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.08),
                        blurRadius: 10,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(24),
                    child: _buildAvatarImage(citizen, fontSize: 16),
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        citizen.fullName,
                        style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: AppTheme.textPrimary),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'UID: ST-${citizen.id.toUpperCase()}',
                        style: const TextStyle(color: AppTheme.textSecondary, fontSize: 11),
                      ),
                    ],
                  ),
                ),
                OutlinedButton(
                  onPressed: () {
                    setState(() {
                      _currentIndex = 2; // Switch to profile tab
                    });
                  },
                  style: OutlinedButton.styleFrom(
                    side: const BorderSide(color: AppTheme.accentTeal),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  child: Text(TranslationService.t(context, 'edit_btn'), style: const TextStyle(color: AppTheme.accentTeal, fontSize: 12)),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),

          // Settings List
          _buildSettingsGroup(TranslationService.t(context, 'account_section'), [
            _buildSettingsItem(
              Icons.verified_user_rounded,
              TranslationService.t(context, 'privacy_security'),
              TranslationService.t(context, 'privacy_security_sub'),
              onTap: () => _showPrivacySecurity(context, provider),
            ),
            _buildSettingsItem(
              Icons.language_rounded,
              TranslationService.t(context, 'app_language'),
              _getLanguageNativeName(provider.selectedLanguage),
              trailingIcon: Icons.swap_horiz_rounded,
              onTap: () {
                _showLanguageSwitcher(context, provider);
              },
            ),
            _buildSettingsItem(
              Icons.notifications_none_rounded,
              TranslationService.t(context, 'emergency_alerts_setting'),
              provider.emergencyAlertsEnabled ? TranslationService.t(context, 'enabled') : 'Disabled',
              onTap: () => _showEmergencyAlerts(context, provider),
            ),
          ]),
          const SizedBox(height: 20),

          _buildSettingsGroup(TranslationService.t(context, 'my_health_cards_section'), [
            _buildSettingsItem(
              Icons.contactless_rounded,
              TranslationService.t(context, 'linked_nfc_cards'),
              '1 Active Card',
              onTap: () => _showLinkedNfcCards(context, provider),
            ),
            _buildSettingsItem(
              Icons.assignment_rounded,
              'My Medical Reports',
              'Manage your clinical documents & tests',
              onTap: () => _showPreviousReportsSheet(context, provider),
            ),
            _buildSettingsItem(
              Icons.description_rounded,
              'My Digital Prescriptions',
              'View secure digital prescriptions & schedules',
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => PrescriptionsDashboardScreen(
                      onTabSelected: (idx) {
                        setState(() {
                          _currentIndex = idx;
                        });
                      },
                    ),
                  ),
                );
              },
            ),
            _buildSettingsItem(
              Icons.people_outline_rounded,
              TranslationService.t(context, 'family_profiles'),
              provider.familyCount == 0 ? 'No family members' : '${provider.familyCount} members added',
              onTap: () => _showFamilyProfiles(context, provider),
            ),
          ]),
          const SizedBox(height: 20),

          _buildSettingsGroup(TranslationService.t(context, 'help_legal_section'), [
            _buildSettingsItem(
              Icons.help_outline_rounded,
              TranslationService.t(context, 'support_faq'),
              TranslationService.t(context, 'support_faq_sub'),
              onTap: () => _showSupportFaq(context),
            ),
            _buildSettingsItem(
              Icons.description_outlined,
              TranslationService.t(context, 'dpdp_consent'),
              TranslationService.t(context, 'view_legal_terms'),
              onTap: () => _showDpdpConsent(context),
            ),
          ]),
          const SizedBox(height: 32),

          // Logout Button
          SizedBox(
            width: double.infinity,
            child: TextButton(
              onPressed: () async {
                // Show confirmation dialog
                final confirmed = await showDialog<bool>(
                  context: context,
                  builder: (ctx) => AlertDialog(
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                    title: const Text(
                      'Sign Out?',
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                    content: const Text(
                      'You will need to verify your phone number again to log back in.',
                    ),
                    actions: [
                      TextButton(
                        onPressed: () => Navigator.pop(ctx, false),
                        child: const Text('Cancel', style: TextStyle(color: Colors.black54)),
                      ),
                      TextButton(
                        onPressed: () => Navigator.pop(ctx, true),
                        child: const Text(
                          'Sign Out',
                          style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold),
                        ),
                      ),
                    ],
                  ),
                );
                if (confirmed == true && mounted) {
                  // Clear JWT from memory + disk
                  ApiService.clearToken();
                  // Navigate to onboarding (full screen replacement, clears nav stack)
                  Navigator.of(context).pushAndRemoveUntil(
                    PageRouteBuilder(
                      transitionDuration: const Duration(milliseconds: 500),
                      pageBuilder: (context, animation, _) => const OnboardingScreen(),
                      transitionsBuilder: (context, animation, _, child) =>
                          FadeTransition(opacity: animation, child: child),
                    ),
                    (route) => false,
                  );
                }
              },
              style: TextButton.styleFrom(
                foregroundColor: AppTheme.accentRed,
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                  side: const BorderSide(color: Color(0xFFFECACA)),
                ),
                backgroundColor: const Color(0xFFFEF2F2),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.logout_rounded, size: 18),
                  const SizedBox(width: 8),
                  Text(
                    TranslationService.t(context, 'logout'),
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  String _getLanguageNativeName(String name) {
    switch (name) {
      case 'English': return 'English';
      case 'Hindi': return 'हिंदी';
      case 'Bengali': return 'বাংলা';
      case 'Telugu': return 'తెలుగు';
      case 'Tamil': return 'தமிழ்';
      case 'Marathi': return 'मराठी';
      case 'Gujarati': return 'ગુજરાતી';
      case 'Kannada': return 'ಕನ್ನಡ';
      case 'Malayalam': return 'മലയാളം';
      case 'Punjabi': return 'ਪੰਜਾਬੀ';
      case 'Odia': return 'ଓଡ଼ିଆ';
      case 'Urdu': return 'اردو';
      default: return name;
    }
  }

  void _showPrivacySecurity(BuildContext context, SwasthyaTapProvider provider) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            return Padding(
              padding: EdgeInsets.fromLTRB(24, 24, 24, MediaQuery.of(context).viewInsets.bottom + 24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Center(
                    child: Container(
                      width: 40,
                      height: 4,
                      decoration: BoxDecoration(
                        color: Colors.grey[300],
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),
                  Text(
                    TranslationService.t(context, 'privacy_security'),
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18, color: AppTheme.textPrimary),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    TranslationService.t(context, 'privacy_security_sub'),
                    style: const TextStyle(color: AppTheme.textSecondary, fontSize: 12),
                  ),
                  const SizedBox(height: 24),
                  
                  // Biometric Toggle
                  SwitchListTile.adaptive(
                    activeColor: AppTheme.accentTeal,
                    title: const Text('Biometric Authentication', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                    subtitle: const Text('Require fingerprint/face lock to view health profile', style: TextStyle(fontSize: 11)),
                    value: provider.isBiometricLockEnabled,
                    onChanged: (val) {
                      provider.toggleBiometricLock(val);
                      setModalState(() {});
                    },
                  ),
                  const Divider(),
                  
                  // PIN Protected Toggle
                  SwitchListTile.adaptive(
                    activeColor: AppTheme.accentTeal,
                    title: const Text('4-Digit PIN Security', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                    subtitle: const Text('Protect card updates and downloads with PIN', style: TextStyle(fontSize: 11)),
                    value: provider.isPinProtected,
                    onChanged: (val) {
                      provider.togglePinProtected(val);
                      setModalState(() {});
                    },
                  ),
                  
                  if (provider.isPinProtected) ...[
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text('Current PIN: **** (${provider.pinCode})', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w500)),
                          TextButton(
                            onPressed: () {
                              _showChangePinDialog(context, provider);
                            },
                            child: const Text('Change PIN', style: TextStyle(color: AppTheme.accentTeal, fontWeight: FontWeight.bold)),
                          ),
                        ],
                      ),
                    ),
                  ],
                  
                  const Divider(),
                  const SizedBox(height: 12),
                  
                  // Access Log History
                  const Text(
                    'Card Access Log History',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: AppTheme.textPrimary),
                  ),
                  const SizedBox(height: 12),
                  
                  // Simulated logs
                  _buildLogItem('AIIMS Emergency Room', 'Scanned Card & Profile', '10 minutes ago', isEmergency: true),
                  _buildLogItem('Apollo First Responder', 'NFC Tag Read', 'Yesterday', isEmergency: true),
                  _buildLogItem('Self Scan (Offline)', 'NFC Tag Verification', '3 days ago', isEmergency: false),
                  
                  const SizedBox(height: 16),
                ],
              ),
            );
          }
        );
      },
    );
  }

  Widget _buildLogItem(String title, String action, String time, {required bool isEmergency}) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: isEmergency ? const Color(0xFFFEF2F2) : const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: isEmergency ? const Color(0xFFFCA5A5) : const Color(0xFFE2E8F0)),
      ),
      child: Row(
        children: [
          Icon(
            isEmergency ? Icons.warning_amber_rounded : Icons.history_rounded,
            color: isEmergency ? AppTheme.accentRed : AppTheme.textSecondary,
            size: 20,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: AppTheme.textPrimary)),
                const SizedBox(height: 2),
                Text(action, style: const TextStyle(fontSize: 10, color: AppTheme.textSecondary)),
              ],
            ),
          ),
          Text(time, style: const TextStyle(fontSize: 10, color: AppTheme.textSecondary, fontWeight: FontWeight.w500)),
        ],
      ),
    );
  }

  void _showChangePinDialog(BuildContext context, SwasthyaTapProvider provider) {
    final controller = TextEditingController(text: provider.pinCode);
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Change Security PIN', style: TextStyle(fontWeight: FontWeight.bold)),
        content: TextField(
          controller: controller,
          keyboardType: TextInputType.number,
          maxLength: 4,
          obscureText: true,
          decoration: const InputDecoration(
            hintText: 'Enter 4 digit PIN',
            border: OutlineInputBorder(),
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          TextButton(
            onPressed: () {
              if (controller.text.length == 4) {
                provider.setPinCode(controller.text);
                Navigator.pop(ctx);
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('PIN updated successfully!'), backgroundColor: AppTheme.accentTeal),
                );
              }
            },
            child: const Text('Save', style: TextStyle(fontWeight: FontWeight.bold, color: AppTheme.accentTeal)),
          ),
        ],
      ),
    );
  }

  void _showEmergencyAlerts(BuildContext context, SwasthyaTapProvider provider) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            return Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Center(
                    child: Container(
                      width: 40,
                      height: 4,
                      decoration: BoxDecoration(color: Colors.grey[300], borderRadius: BorderRadius.circular(2)),
                    ),
                  ),
                  const SizedBox(height: 20),
                  Text(
                    TranslationService.t(context, 'emergency_alerts_setting'),
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18, color: AppTheme.textPrimary),
                  ),
                  const SizedBox(height: 24),
                  SwitchListTile.adaptive(
                    activeColor: AppTheme.accentTeal,
                    title: const Text('Emergency SMS Alerts', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                    subtitle: const Text('Receive notifications when first responders access your profile', style: TextStyle(fontSize: 11)),
                    value: provider.emergencyAlertsEnabled,
                    onChanged: (val) {
                      provider.toggleEmergencyAlerts(val);
                      setModalState(() {});
                    },
                  ),
                  const Divider(),
                  SwitchListTile.adaptive(
                    activeColor: AppTheme.accentTeal,
                    title: const Text('Blood Donation Broadcasts', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                    subtitle: const Text('Get notified of critical blood requests near your area', style: TextStyle(fontSize: 11)),
                    value: provider.bloodAlertsEnabled,
                    onChanged: (val) {
                      provider.toggleBloodAlerts(val);
                      setModalState(() {});
                    },
                  ),
                  const SizedBox(height: 24),
                ],
              ),
            );
          }
        );
      },
    );
  }

  void _showLinkedNfcCards(BuildContext context, SwasthyaTapProvider provider) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) {
        return Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(color: Colors.grey[300], borderRadius: BorderRadius.circular(2)),
                ),
              ),
              const SizedBox(height: 20),
              Text(
                TranslationService.t(context, 'linked_nfc_cards'),
                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18, color: AppTheme.textPrimary),
              ),
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: const Color(0xFFF1F5F9),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: const Color(0xFFCBD5E1)),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.contactless_rounded, color: AppTheme.accentTeal, size: 28),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('Primary Health Tag', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                          const SizedBox(height: 2),
                          Text('Linked on 15 May 2026 | Active', style: TextStyle(color: Colors.grey[600], fontSize: 11)),
                        ],
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(color: const Color(0xFFDCFCE7), borderRadius: BorderRadius.circular(8)),
                      child: const Text('ACTIVE', style: TextStyle(color: Color(0xFF15803D), fontSize: 10, fontWeight: FontWeight.bold)),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: () {
                    // Simulate scanning
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('SwasthyaTap NFC Card linking sequence started. Hold tag near phone back.'), backgroundColor: AppTheme.accentTeal),
                    );
                  },
                  icon: const Icon(Icons.add_circle_outline, color: Colors.white),
                  label: const Text('Link New NFC Card / Ring', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.white)),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.accentTeal,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  void _showFamilyProfiles(BuildContext context, SwasthyaTapProvider provider) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            return Padding(
              padding: EdgeInsets.fromLTRB(24, 24, 24, MediaQuery.of(context).viewInsets.bottom + 24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Center(
                    child: Container(
                      width: 40,
                      height: 4,
                      decoration: BoxDecoration(color: Colors.grey[300], borderRadius: BorderRadius.circular(2)),
                    ),
                  ),
                  const SizedBox(height: 20),
                  Text(
                    TranslationService.t(context, 'family_profiles'),
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18, color: AppTheme.textPrimary),
                  ),
                  const SizedBox(height: 16),
                  
                  _buildFamilyMemberRow('Sneha Kumar', 'Spouse', 'B+', 'Active'),
                  _buildFamilyMemberRow('Anil Kumar', 'Father', 'O+', 'Active'),
                  
                  if (provider.familyCount > 0) ...List.generate(provider.familyCount, (index) {
                    return _buildFamilyMemberRow('Family Member ${index + 1}', 'Dependent', 'A+', 'Active');
                  }),
                  
                  const SizedBox(height: 24),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      onPressed: () {
                        final nameController = TextEditingController();
                        final relationController = TextEditingController();
                        showDialog(
                          context: context,
                          builder: (ctx) => AlertDialog(
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                            title: const Text('Add Family Profile', style: TextStyle(fontWeight: FontWeight.bold)),
                            content: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                TextField(
                                  controller: nameController,
                                  decoration: const InputDecoration(labelText: 'Full Name', border: OutlineInputBorder()),
                                ),
                                const SizedBox(height: 12),
                                TextField(
                                  controller: relationController,
                                  decoration: const InputDecoration(labelText: 'Relation (e.g. Son, Daughter)', border: OutlineInputBorder()),
                                ),
                              ],
                            ),
                            actions: [
                              TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
                              TextButton(
                                onPressed: () {
                                  if (nameController.text.isNotEmpty && relationController.text.isNotEmpty) {
                                    provider.incrementFamilyCount();
                                    Navigator.pop(ctx);
                                    setModalState(() {});
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      SnackBar(content: Text('${nameController.text} added successfully!'), backgroundColor: AppTheme.accentTeal),
                                    );
                                  }
                                },
                                child: const Text('Add', style: TextStyle(fontWeight: FontWeight.bold, color: AppTheme.accentTeal)),
                              ),
                            ],
                          ),
                        );
                      },
                      icon: const Icon(Icons.person_add_alt_1_rounded, color: Colors.white),
                      label: const Text('Add Family Member', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.white)),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppTheme.accentTeal,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                    ),
                  ),
                ],
              ),
            );
          }
        );
      },
    );
  }

  Widget _buildFamilyMemberRow(String name, String relation, String bloodGroup, String status) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Row(
        children: [
          CircleAvatar(
            backgroundColor: AppTheme.accentTeal.withOpacity(0.1),
            child: const Icon(Icons.person_rounded, color: AppTheme.accentTeal),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(name, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: AppTheme.textPrimary)),
                const SizedBox(height: 2),
                Text('$relation | Blood Group: $bloodGroup', style: TextStyle(color: Colors.grey[600], fontSize: 11)),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(color: const Color(0xFFDCFCE7), borderRadius: BorderRadius.circular(8)),
            child: Text(status.toUpperCase(), style: const TextStyle(color: Color(0xFF15803D), fontSize: 9, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  void _showSupportFaq(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) {
        return DraggableScrollableSheet(
          initialChildSize: 0.7,
          minChildSize: 0.5,
          maxChildSize: 0.9,
          expand: false,
          builder: (context, scrollController) {
            return SingleChildScrollView(
              controller: scrollController,
              padding: const EdgeInsets.all(24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Center(
                    child: Container(
                      width: 40,
                      height: 4,
                      decoration: BoxDecoration(color: Colors.grey[300], borderRadius: BorderRadius.circular(2)),
                    ),
                  ),
                  const SizedBox(height: 20),
                  Text(
                    TranslationService.t(context, 'support_faq'),
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18, color: AppTheme.textPrimary),
                  ),
                  const SizedBox(height: 20),
                  
                  _buildFaqItem(
                    'How does offline scanning work?',
                    'Your critical medical information (allergies, emergency contacts, blood group) is compiled into a highly compressed, encrypted NDEF byte payload and written directly to the NFC card chip. Verified first responders can read this offline even without internet connectivity using our offline-decrypt scheme.',
                  ),
                  const Divider(),
                  _buildFaqItem(
                    'Who can access my health records?',
                    'Only verified medical professionals and official government first responders who physically scan your NFC card can view your emergency profile. In addition, you receive real-time SMS alerts (if enabled) whenever your card is accessed.',
                  ),
                  const Divider(),
                  _buildFaqItem(
                    'Is my data safe and compliant?',
                    'Yes, SwasthyaTap is fully compliant with the Digital Personal Data Protection (DPDP) Act of India. Your health data is securely encrypted at rest and in transit. You hold complete ownership and can edit or revoke consent at any time.',
                  ),
                  const Divider(),
                  _buildFaqItem(
                    'How can I update my details?',
                    'Navigate to your Health Profile tab in the citizen portal and tap the edit icons. Once updated, tap "Save" to push changes. To sync these changes to your physical card chip, use the NFC update feature.',
                  ),
                  
                  const SizedBox(height: 32),
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: AppTheme.accentTeal.withOpacity(0.08),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: AppTheme.accentTeal.withOpacity(0.3)),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.chat_bubble_outline_rounded, color: AppTheme.accentTeal, size: 24),
                        const SizedBox(width: 16),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text('Still need help?', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                              const SizedBox(height: 2),
                              Text('Chat with our 24/7 Swasthya support assistant', style: TextStyle(color: Colors.grey[600], fontSize: 10.5)),
                            ],
                          ),
                        ),
                        ElevatedButton(
                          onPressed: () {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(content: Text('Redirecting to SwasthyaTap Helpdesk...'), backgroundColor: AppTheme.accentTeal),
                            );
                          },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppTheme.accentTeal,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                          ),
                          child: const Text('Chat', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11, color: Colors.white)),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            );
          }
        );
      },
    );
  }

  Widget _buildFaqItem(String question, String answer) {
    return Theme(
      data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
      child: ExpansionTile(
        tilePadding: EdgeInsets.zero,
        title: Text(question, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: AppTheme.textPrimary)),
        children: [
          Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: Text(answer, style: const TextStyle(color: AppTheme.textSecondary, fontSize: 11.5, height: 1.5)),
          ),
        ],
      ),
    );
  }

  void _showDpdpConsent(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) {
        return DraggableScrollableSheet(
          initialChildSize: 0.7,
          minChildSize: 0.5,
          maxChildSize: 0.9,
          expand: false,
          builder: (context, scrollController) {
            return SingleChildScrollView(
              controller: scrollController,
              padding: const EdgeInsets.all(24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Center(
                    child: Container(
                      width: 40,
                      height: 4,
                      decoration: BoxDecoration(color: Colors.grey[300], borderRadius: BorderRadius.circular(2)),
                    ),
                  ),
                  const SizedBox(height: 20),
                  Text(
                    TranslationService.t(context, 'dpdp_consent'),
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18, color: AppTheme.textPrimary),
                  ),
                  const SizedBox(height: 16),
                  const Text(
                    'Digital Personal Data Protection (DPDP) Act Consent Agreement',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: AppTheme.accentTeal),
                  ),
                  const SizedBox(height: 12),
                  const Text(
                    'Pursuant to the DPDP Act of India, SwasthyaTap informs you of the following terms regarding your digital medical data processing:',
                    style: TextStyle(fontSize: 11.5, color: AppTheme.textPrimary, height: 1.4),
                  ),
                  const SizedBox(height: 12),
                  _buildConsentBullet('1. Specific Purpose', 'Your data is processed solely for providing real-time, life-saving emergency medical details to responders.'),
                  _buildConsentBullet('2. Data Minimization', 'Only essential information (blood group, allergies, medications, emergency contacts) is shared via the NFC chip.'),
                  _buildConsentBullet('3. Access & Correction', 'You retain full rights to inspect, update, correct, or request deletion of your health records via this portal.'),
                  _buildConsentBullet('4. Right to Withdraw', 'You may revoke consent at any time. Revoking consent will disable the SwasthyaTap emergency card scanning features.'),
                  const SizedBox(height: 24),
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton(
                          onPressed: () {
                            Navigator.pop(context);
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(content: Text('DPDP Consent revoked. Card access features suspended.'), backgroundColor: AppTheme.accentRed),
                            );
                          },
                          style: OutlinedButton.styleFrom(
                            side: const BorderSide(color: AppTheme.accentRed),
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          ),
                          child: const Text('Revoke Consent', style: TextStyle(color: AppTheme.accentRed, fontWeight: FontWeight.bold, fontSize: 12)),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: ElevatedButton(
                          onPressed: () {
                            Navigator.pop(context);
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(content: Text('Consent updated and signed successfully!'), backgroundColor: AppTheme.accentTeal),
                            );
                          },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppTheme.accentTeal,
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          ),
                          child: const Text('Accept & Sign', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 12)),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            );
          }
        );
      },
    );
  }

  Widget _buildConsentBullet(String title, String desc) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 11.5, color: AppTheme.textPrimary)),
          const SizedBox(height: 2),
          Text(desc, style: const TextStyle(fontSize: 11, color: AppTheme.textSecondary, height: 1.4)),
        ],
      ),
    );
  }

  void _showLanguageSwitcher(BuildContext context, SwasthyaTapProvider provider) {
    final List<Map<String, String>> languages = [
      {"name": "English", "native": "English"},
      {"name": "Hindi", "native": "हिंदी"},
      {"name": "Bengali", "native": "বাংলা"},
      {"name": "Telugu", "native": "తెలుగు"},
      {"name": "Tamil", "native": "தமிழ்"},
      {"name": "Marathi", "native": "मराठी"},
      {"name": "Gujarati", "native": "ગુજરાતી"},
      {"name": "Kannada", "native": "ಕನ್ನಡ"},
      {"name": "Malayalam", "native": "മലയാളം"},
      {"name": "Punjabi", "native": "ਪੰਜਾਬੀ"},
      {"name": "Odia", "native": "ଓଡ଼ିଆ"},
      {"name": "Urdu", "native": "اردو"},
    ];

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) {
        return DraggableScrollableSheet(
          initialChildSize: 0.6,
          minChildSize: 0.4,
          maxChildSize: 0.8,
          expand: false,
          builder: (context, scrollController) {
            return Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Center(
                    child: Container(
                      width: 40,
                      height: 4,
                      decoration: BoxDecoration(color: Colors.grey[300], borderRadius: BorderRadius.circular(2)),
                    ),
                  ),
                  const SizedBox(height: 20),
                  Text(
                    TranslationService.t(context, 'switch_language'),
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18, color: AppTheme.textPrimary),
                  ),
                  const SizedBox(height: 16),
                  Expanded(
                    child: ListView.separated(
                      controller: scrollController,
                      itemCount: languages.length,
                      separatorBuilder: (context, index) => const Divider(height: 1),
                      itemBuilder: (context, index) {
                        final lang = languages[index];
                        final isSelected = provider.selectedLanguage == lang['name'];
                        return ListTile(
                          contentPadding: EdgeInsets.zero,
                          title: Text(
                            '${lang['native']} (${lang['name']})',
                            style: TextStyle(
                              fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                              color: isSelected ? AppTheme.accentTeal : AppTheme.textPrimary,
                            ),
                          ),
                          trailing: isSelected ? const Icon(Icons.check_circle_rounded, color: AppTheme.accentTeal) : null,
                          onTap: () {
                            provider.setSelectedLanguage(lang['name']!);
                            Navigator.pop(context);
                            // Show nice toast notification
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text(
                                  provider.selectedLanguage == 'Hindi' ? 'भाषा बदलकर हिंदी कर दी गई है।' : 'Language changed to ${lang['name']}.'
                                ),
                                backgroundColor: AppTheme.accentTeal,
                              ),
                            );
                          },
                        );
                      },
                    ),
                  ),
                ],
              ),
            );
          }
        );
      },
    );
  }

  Widget _buildSettingsGroup(String title, List<Widget> items) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(left: 4, bottom: 8),
          child: Text(
            title,
            style: const TextStyle(fontSize: 10.5, fontWeight: FontWeight.bold, color: AppTheme.textSecondary, letterSpacing: 0.8),
          ),
        ),
        Container(
          clipBehavior: Clip.antiAlias, // CLIPPING TO AVOID FLICKER
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: AppTheme.borderColor),
          ),
          child: Column(
            children: List.generate(items.length, (index) {
              if (index == items.length - 1) return items[index];
              return Column(
                children: [
                  items[index],
                  const Divider(height: 1, indent: 50),
                ],
              );
            }),
          ),
        ),
      ],
    );
  }

  Widget _buildSettingsItem(IconData icon, String title, String subtitle, {IconData? trailingIcon, VoidCallback? onTap}) {
    return Material(
      color: Colors.transparent,
      clipBehavior: Clip.antiAlias, // CLIPPING TO AVOID FLICKER
      child: ListTile(
        leading: Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: AppTheme.accentTeal.withOpacity(0.08),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(icon, color: AppTheme.accentTeal, size: 18),
        ),
        title: Text(
          title,
          style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: AppTheme.textPrimary),
        ),
        subtitle: Text(
          subtitle,
          style: const TextStyle(fontSize: 11, color: AppTheme.textSecondary),
        ),
        trailing: Icon(trailingIcon ?? Icons.chevron_right_rounded, color: AppTheme.textSecondary, size: 16),
        onTap: onTap,
      ),
    );
  }

  // ─── Bottom Navigation Bar ───────────────────────────────────────────────
  Widget _buildBottomNavigationBar(SwasthyaTapProvider provider) {
    final tabs = [
      {'icon': Icons.home_filled, 'label': _t('nav_home', provider.selectedLanguage)},
      {'icon': Icons.qr_code_scanner_rounded, 'label': _t('nav_scan', provider.selectedLanguage)},
      {'icon': Icons.person_rounded, 'label': _t('nav_profile', provider.selectedLanguage)},
      {'icon': Icons.more_horiz_rounded, 'label': _t('nav_more', provider.selectedLanguage)},
    ];

    return Container(
      margin: const EdgeInsets.fromLTRB(16, 0, 16, 20),
      height: 74,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: const Color(0xFFE2E8F0), width: 1.5),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.06),
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(24),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: List.generate(tabs.length, (index) {
            final tab = tabs[index];
            final isSelected = _currentIndex == index;
            return Expanded(
              child: GestureDetector(
                onTap: () => _onTabSelected(index),
                behavior: HitTestBehavior.opaque,
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    // Active indicator/pill and icon
                    AnimatedContainer(
                      duration: const Duration(milliseconds: 200),
                      padding: EdgeInsets.symmetric(horizontal: isSelected ? 16 : 8, vertical: 6),
                      decoration: BoxDecoration(
                        color: isSelected ? AppTheme.accentTeal.withOpacity(0.12) : Colors.transparent,
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: Icon(
                        tab['icon'] as IconData,
                        color: isSelected ? AppTheme.accentTeal : AppTheme.textSecondary.withOpacity(0.7),
                        size: 24,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 4.0),
                      child: Text(
                        tab['label'] as String,
                        style: GoogleFonts.poppins(
                          fontSize: 10.5,
                          fontWeight: isSelected ? FontWeight.bold : FontWeight.w600,
                          color: isSelected ? AppTheme.accentTeal : AppTheme.textSecondary.withOpacity(0.8),
                          letterSpacing: -0.2,
                        ),
                        textAlign: TextAlign.center,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ),
            );
          }),
        ),
      ),
    );
  }

  // ─── Health Report Options and Submission ───────────────────────────────────────
  void _showHealthReportOptions(BuildContext context, SwasthyaTapProvider provider) {
    showDialog(
      context: context,
      builder: (context) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        elevation: 16,
        backgroundColor: Colors.white,
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const SizedBox(width: 24),
                  Expanded(
                    child: Text(
                      _t('report_health_issue', provider.selectedLanguage),
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: AppTheme.textPrimary,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close_rounded, size: 20),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              const Text(
                'Select an option below to submit a new report or view past submissions.',
                style: TextStyle(
                  fontSize: 13,
                  color: AppTheme.textSecondary,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 24),
              _buildOptionCard(
                context: context,
                icon: Icons.add_moderator_rounded,
                title: 'Submit New Report',
                subtitle: 'Report symptoms of Dengue, Malaria, or other diseases.',
                color: const Color(0xFFF97316),
                onTap: () {
                  Navigator.pop(context);
                  _showSubmitReportSheet(context, provider);
                },
              ),
              const SizedBox(height: 12),
              _buildOptionCard(
                context: context,
                icon: Icons.history_rounded,
                title: 'Previous Reports',
                subtitle: 'View and track your submitted health issue reports.',
                color: AppTheme.accentTeal,
                onTap: () {
                  Navigator.pop(context);
                  _showPreviousReportsSheet(context, provider);
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildOptionCard({
    required BuildContext context,
    required IconData icon,
    required String title,
    required String subtitle,
    required Color color,
    required VoidCallback onTap,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppTheme.borderColor),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.02),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(16),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: color.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(icon, color: color, size: 24),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                          color: AppTheme.textPrimary,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        subtitle,
                        style: const TextStyle(
                          fontSize: 11,
                          color: AppTheme.textSecondary,
                        ),
                      ),
                    ],
                  ),
                ),
                Icon(Icons.chevron_right_rounded, color: Colors.grey[400]),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _showSubmitReportSheet(BuildContext context, SwasthyaTapProvider provider) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => const SubmitReportScreen(),
      ),
    );
  }

  void _showPreviousReportsSheet(BuildContext context, SwasthyaTapProvider provider) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => MyReportsScreen(
          onTabSelected: (idx) {
            setState(() {
              _currentIndex = idx;
            });
          },
        ),
      ),
    );
  }
}

// ─── Custom Viewfinder Corners Painter ──────────────────────────────────────────
class ScannerFramePainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = const Color(0xFF2DD4BF)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 4.5
      ..strokeCap = StrokeCap.round;
    
    final radius = 24.0;
    final lineLength = 32.0;
    
    // Top-left corner
    final pathTopLeft = Path()
      ..moveTo(0, lineLength)
      ..lineTo(0, radius)
      ..quadraticBezierTo(0, 0, radius, 0)
      ..lineTo(lineLength, 0);
    canvas.drawPath(pathTopLeft, paint);
    
    // Top-right corner
    final pathTopRight = Path()
      ..moveTo(size.width - lineLength, 0)
      ..lineTo(size.width - radius, 0)
      ..quadraticBezierTo(size.width, 0, size.width, radius)
      ..lineTo(size.width, lineLength);
    canvas.drawPath(pathTopRight, paint);
    
    // Bottom-left corner
    final pathBottomLeft = Path()
      ..moveTo(0, size.height - lineLength)
      ..lineTo(0, size.height - radius)
      ..quadraticBezierTo(0, size.height, radius, size.height)
      ..lineTo(lineLength, size.height);
    canvas.drawPath(pathBottomLeft, paint);
    
    // Bottom-right corner
    final pathBottomRight = Path()
      ..moveTo(size.width - lineLength, size.height)
      ..lineTo(size.width - radius, size.height)
      ..quadraticBezierTo(size.width, size.height, size.width, size.height - radius)
      ..lineTo(size.width, size.height - lineLength);
    canvas.drawPath(pathBottomRight, paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class _ProfileSectionTile extends StatefulWidget {
  final int number;
  final String title;
  final String subtitle;
  final IconData icon;
  final Color iconColor;
  final Widget? trailing;
  final Widget child;

  const _ProfileSectionTile({
    Key? key,
    required this.number,
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.iconColor,
    this.trailing,
    required this.child,
  }) : super(key: key);

  @override
  State<_ProfileSectionTile> createState() => _ProfileSectionTileState();
}

class _ProfileSectionTileState extends State<_ProfileSectionTile> {
  bool _isExpanded = false;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFF1F5F9), width: 1.5),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.02),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: Column(
          children: [
            // Header Row (has its own Material for localized ripple)
            Material(
              color: Colors.white,
              child: InkWell(
                onTap: () {
                  setState(() {
                    _isExpanded = !_isExpanded;
                  });
                },
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                  child: Row(
                    children: [
                      // Icon container
                      Container(
                        width: 40,
                        height: 40,
                        decoration: BoxDecoration(
                          color: widget.iconColor.withOpacity(0.08),
                          shape: BoxShape.circle,
                        ),
                        child: Icon(widget.icon, color: widget.iconColor, size: 20),
                      ),
                      const SizedBox(width: 14),
                      // Title + Subtitle
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              '${widget.number}. ${widget.title}',
                              style: const TextStyle(
                                  fontSize: 14.5,
                                  fontWeight: FontWeight.bold,
                                  color: Color(0xFF0F172A)),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              widget.subtitle,
                              style: const TextStyle(
                                fontSize: 11.5,
                                color: Color(0xFF64748B),
                                fontWeight: FontWeight.w400,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 8),
                      // Trailing (Status/Buttons)
                      if (widget.trailing != null) ...[
                        widget.trailing!,
                        const SizedBox(width: 8),
                      ],
                      // Expand arrow
                      AnimatedRotation(
                        turns: _isExpanded ? 0.5 : 0.0,
                        duration: const Duration(milliseconds: 200),
                        child: const Icon(
                          Icons.keyboard_arrow_down_rounded,
                          color: Color(0xFF64748B),
                          size: 20,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            // Expanded Content (outside the header Material)
            if (_isExpanded) ...[
              const Divider(height: 1, color: Color(0xFFF1F5F9)),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(16),
                color: const Color(0xFFFAFAFA),
                child: widget.child,
              ),
            ],
          ],
        ),
      ),
    );
  }
}

// Custom Painter to draw a professional graduation cap logo with ECG heartbeat signal overlay
class HealthEducationLogoPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = const Color(0xFF0D9488)
      ..style = PaintingStyle.fill;

    // Draw diamond shape for graduation cap top
    final pathCap = Path();
    pathCap.moveTo(size.width * 0.5, size.height * 0.1);
    pathCap.lineTo(size.width * 0.95, size.height * 0.35);
    pathCap.lineTo(size.width * 0.5, size.height * 0.6);
    pathCap.lineTo(size.width * 0.05, size.height * 0.35);
    pathCap.close();
    canvas.drawPath(pathCap, paint);

    // Draw cap base bottom cap
    final paintBase = Paint()
      ..color = const Color(0xFF0B7A70)
      ..style = PaintingStyle.fill;
    final pathBase = Path();
    pathBase.moveTo(size.width * 0.28, size.height * 0.48);
    pathBase.lineTo(size.width * 0.28, size.height * 0.68);
    pathBase.quadraticBezierTo(size.width * 0.5, size.height * 0.82, size.width * 0.72, size.height * 0.68);
    pathBase.lineTo(size.width * 0.72, size.height * 0.48);
    pathBase.quadraticBezierTo(size.width * 0.5, size.height * 0.62, size.width * 0.28, size.height * 0.48);
    pathBase.close();
    canvas.drawPath(pathBase, paintBase);

    // Draw tassel hanging off the side
    final paintTassel = Paint()
      ..color = const Color(0xFF0F766E)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.0
      ..strokeCap = StrokeCap.round;
    canvas.drawLine(Offset(size.width * 0.95, size.height * 0.35), Offset(size.width * 0.97, size.height * 0.55), paintTassel);
    
    // Draw tassel end dot
    final paintTasselDot = Paint()
      ..color = const Color(0xFF0D9488)
      ..style = PaintingStyle.fill;
    canvas.drawCircle(Offset(size.width * 0.97, size.height * 0.58), 2.5, paintTasselDot);

    // Draw ECG heart/plus overlay or details inside cap
    final paintEcg = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.8
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;

    final ecgPath = Path()
      ..moveTo(size.width * 0.33, size.height * 0.35)
      ..lineTo(size.width * 0.42, size.height * 0.35)
      ..lineTo(size.width * 0.45, size.height * 0.25)
      ..lineTo(size.width * 0.49, size.height * 0.45)
      ..lineTo(size.width * 0.53, size.height * 0.20)
      ..lineTo(size.width * 0.56, size.height * 0.38)
      ..lineTo(size.width * 0.59, size.height * 0.35)
      ..lineTo(size.width * 0.67, size.height * 0.35);

    canvas.drawPath(ecgPath, paintEcg);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class _SimulatedMapPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paintBg = Paint()..color = const Color(0xFFF3F4F6);
    canvas.drawRect(Rect.fromLTWH(0, 0, size.width, size.height), paintBg);

    final paintRoad = Paint()
      ..color = Colors.white
      ..strokeWidth = 6
      ..style = PaintingStyle.stroke;

    final paintRiver = Paint()
      ..color = const Color(0xFFE0F2FE)
      ..strokeWidth = 12
      ..style = PaintingStyle.stroke;

    // Draw some roads
    canvas.drawLine(const Offset(0, 40), Offset(size.width, 60), paintRoad);
    canvas.drawLine(const Offset(80, 0), Offset(100, size.height), paintRoad);
    canvas.drawLine(Offset(0, size.height * 0.7), Offset(size.width, size.height * 0.6), paintRoad);

    // Draw river
    final riverPath = Path()
      ..moveTo(0, size.height * 0.2)
      ..quadraticBezierTo(size.width * 0.4, size.height * 0.1, size.width * 0.6, size.height * 0.8)
      ..lineTo(size.width, size.height * 0.9);
    canvas.drawPath(riverPath, paintRiver);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
