import 'dart:async';
import 'dart:convert';
import 'dart:io' as io;
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:nfc_manager/nfc_manager.dart';
import '../../services/api_service.dart';
import '../../theme/app_theme.dart';
import '../../utils/translation_service.dart';
import '../../models/models.dart';

enum _WriterStep { enterSwasthyaId, patientProfileForm, writing, success, error }

class NfcWriterScreen extends StatefulWidget {
  final String? prefillSwasthyaId;
  const NfcWriterScreen({super.key, this.prefillSwasthyaId});

  @override
  State<NfcWriterScreen> createState() => _NfcWriterScreenState();
}

class _NfcWriterScreenState extends State<NfcWriterScreen>
    with SingleTickerProviderStateMixin {
  final _idController = TextEditingController();
  final _formKey = GlobalKey<FormState>();

  late AnimationController _pulseController;
  late Animation<double> _pulseAnim;

  _WriterStep _step = _WriterStep.enterSwasthyaId;
  bool _isFetching = false;
  bool _isSaving = false;
  bool _nfcAvailable = false;
  bool _controllersInitialized = false;

  // Patient data
  MedicalProfile? _citizen;
  String? _nfcUrl;
  String? _errorMessage;

  // Form Controllers for Patient Profile
  late TextEditingController _fullNameController;
  late TextEditingController _ageController;
  late TextEditingController _addressController;
  late TextEditingController _phoneController;
  late TextEditingController _emailController;
  late TextEditingController _allergiesController;
  late TextEditingController _medicationsController;
  late TextEditingController _chronicConditionsController;
  late TextEditingController _specialInstructionsController;
  late TextEditingController _contact1NameController;
  late TextEditingController _contact1RelationController;
  late TextEditingController _contact1PhoneController;
  late TextEditingController _contact2NameController;
  late TextEditingController _contact2RelationController;
  late TextEditingController _contact2PhoneController;
  late TextEditingController _insuranceCompanyController;
  late TextEditingController _insurancePolicyNumberController;

  String _bloodGroup = 'O+';
  bool _isDnr = false;

  String _t(String key) {
    return TranslationService.t(context, key);
  }

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1400),
    )..repeat(reverse: true);
    _pulseAnim = Tween<double>(begin: 0.92, end: 1.08).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );
    if (widget.prefillSwasthyaId != null) {
      _idController.text = widget.prefillSwasthyaId!;
    }
    _checkNfc();
  }

  @override
  void dispose() {
    _idController.dispose();
    _pulseController.dispose();
    _disposeFormControllers();
    try {
      NfcManager.instance.stopSession();
    } catch (_) {}
    super.dispose();
  }

  void _disposeFormControllers() {
    if (_controllersInitialized) {
      _fullNameController.dispose();
      _ageController.dispose();
      _addressController.dispose();
      _phoneController.dispose();
      _emailController.dispose();
      _allergiesController.dispose();
      _medicationsController.dispose();
      _chronicConditionsController.dispose();
      _specialInstructionsController.dispose();
      _contact1NameController.dispose();
      _contact1RelationController.dispose();
      _contact1PhoneController.dispose();
      _contact2NameController.dispose();
      _contact2RelationController.dispose();
      _contact2PhoneController.dispose();
      _insuranceCompanyController.dispose();
      _insurancePolicyNumberController.dispose();
      _controllersInitialized = false;
    }
  }

  Future<void> _checkNfc() async {
    try {
      final available = await NfcManager.instance.isAvailable();
      if (mounted) setState(() => _nfcAvailable = available);
    } catch (_) {
      if (mounted) setState(() => _nfcAvailable = false);
    }
  }

  void _initOrUpdateFormControllers(MedicalProfile c) {
    if (!_controllersInitialized) {
      _fullNameController = TextEditingController(text: c.fullName);
      _ageController = TextEditingController(text: c.age?.toString() ?? '');
      _addressController = TextEditingController(text: c.address);
      _phoneController = TextEditingController(text: c.phoneNumber);
      _emailController = TextEditingController(text: c.email);
      _allergiesController = TextEditingController(text: c.allergies);
      _medicationsController = TextEditingController(text: c.medications);
      _chronicConditionsController = TextEditingController(text: c.chronicConditions);
      _specialInstructionsController = TextEditingController(text: c.specialInstructions);

      if (c.emergencyContacts.isNotEmpty) {
        final c1 = c.emergencyContacts[0];
        _contact1NameController = TextEditingController(text: c1.name);
        _contact1RelationController = TextEditingController(text: c1.relation);
        _contact1PhoneController = TextEditingController(text: c1.phone);
      } else {
        _contact1NameController = TextEditingController();
        _contact1RelationController = TextEditingController();
        _contact1PhoneController = TextEditingController();
      }

      if (c.emergencyContacts.length > 1) {
        final c2 = c.emergencyContacts[1];
        _contact2NameController = TextEditingController(text: c2.name);
        _contact2RelationController = TextEditingController(text: c2.relation);
        _contact2PhoneController = TextEditingController(text: c2.phone);
      } else {
        _contact2NameController = TextEditingController();
        _contact2RelationController = TextEditingController();
        _contact2PhoneController = TextEditingController();
      }

      _insuranceCompanyController = TextEditingController(text: c.insuranceCompany);
      _insurancePolicyNumberController = TextEditingController(text: c.insurancePolicyNumber);
      _controllersInitialized = true;
    } else {
      _fullNameController.text = c.fullName;
      _ageController.text = c.age?.toString() ?? '';
      _addressController.text = c.address;
      _phoneController.text = c.phoneNumber;
      _emailController.text = c.email;
      _allergiesController.text = c.allergies;
      _medicationsController.text = c.medications;
      _chronicConditionsController.text = c.chronicConditions;
      _specialInstructionsController.text = c.specialInstructions;

      if (c.emergencyContacts.isNotEmpty) {
        final c1 = c.emergencyContacts[0];
        _contact1NameController.text = c1.name;
        _contact1RelationController.text = c1.relation;
        _contact1PhoneController.text = c1.phone;
      } else {
        _contact1NameController.clear();
        _contact1RelationController.clear();
        _contact1PhoneController.clear();
      }

      if (c.emergencyContacts.length > 1) {
        final c2 = c.emergencyContacts[1];
        _contact2NameController.text = c2.name;
        _contact2RelationController.text = c2.relation;
        _contact2PhoneController.text = c2.phone;
      } else {
        _contact2NameController.clear();
        _contact2RelationController.clear();
        _contact2PhoneController.clear();
      }

      _insuranceCompanyController.text = c.insuranceCompany;
      _insurancePolicyNumberController.text = c.insurancePolicyNumber;
    }

    final bg = c.bloodGroup;
    _bloodGroup = ['O+', 'O-', 'A+', 'A-', 'B+', 'B-', 'AB+', 'AB-'].contains(bg) ? bg : 'O+';
    _isDnr = c.isDnr;
  }

  void debugTransitionToStep2(MedicalProfile c) {
    _initOrUpdateFormControllers(c);
    setState(() {
      _citizen = c;
      _step = _WriterStep.patientProfileForm;
    });
  }


  Future<void> _fetchPatient() async {
    final id = _idController.text.trim();
    if (id.isEmpty) return;
    setState(() {
      _isFetching = true;
      _errorMessage = null;
    });

    final result = await ApiService.fetchCitizenPreview(id);
    if (!mounted) return;
    if (result['success'] == true && result['citizen'] != null) {
      final citizen = ApiService.parseCitizen(result['citizen'] as Map<String, dynamic>);
      _initOrUpdateFormControllers(citizen);
      setState(() {
        _citizen = citizen;
        _step = _WriterStep.patientProfileForm;
        _isFetching = false;
      });
    } else {
      setState(() {
        _errorMessage = result['message'] as String? ?? 'Patient not found';
        _isFetching = false;
      });
    }
  }

  Future<void> _saveAndProceed() async {
    if (_citizen == null) return;
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _isSaving = true;
      _errorMessage = null;
    });

    // Save only medical details
    final updates = {
      'bloodGroup': _bloodGroup,
      'allergies': _allergiesController.text.trim(),
      'medications': _medicationsController.text.trim(),
      'chronicConditions': _chronicConditionsController.text.trim(),
      'specialInstructions': _specialInstructionsController.text.trim(),
      'isDnr': _isDnr,
    };

    final swasthyaId = _citizen!.id;
    final saveResult = await ApiService.updateCitizen(swasthyaId, updates);
    if (!mounted) return;

    if (saveResult == null) {
      setState(() {
        _isSaving = false;
        _errorMessage = 'Failed to update patient profile on backend.';
      });
      return;
    }

    setState(() {
      _citizen = saveResult;
      _isSaving = false;
    });
    _fetchUrlAndWrite();
  }

  Future<void> _fetchUrlAndWrite() async {
    if (_citizen == null) return;
    final swasthyaId = _citizen!.id;

    setState(() {
      _step = _WriterStep.writing;
      _errorMessage = null;
    });

    // Get URL from backend
    final tokenResult = await ApiService.fetchNfcWriteUrl(swasthyaId);
    if (!mounted) return;

    if (tokenResult['success'] != true) {
      setState(() {
        _step = _WriterStep.error;
        _errorMessage = tokenResult['message'] as String? ?? 'Failed to get NFC token';
      });
      return;
    }

    _nfcUrl = tokenResult['nfcUrl'] as String;

    if (!_nfcAvailable) {
      // Simulate for web/emulator
      await Future.delayed(const Duration(seconds: 2));
      if (mounted) setState(() => _step = _WriterStep.success);
      return;
    }

    // Write to NFC tag
    try {
      await NfcManager.instance.startSession(
        onDiscovered: (NfcTag tag) async {
          try {
            final ndef = Ndef.from(tag);
            if (ndef == null || !ndef.isWritable) {
              await NfcManager.instance.stopSession(errorMessage: 'Tag not writable');
              if (mounted) {
                setState(() {
                  _step = _WriterStep.error;
                  _errorMessage = 'NFC tag is not writable.';
                });
              }
              return;
            }

            final uri = Uri.parse(_nfcUrl!);
            final record = NdefRecord.createUri(uri);
            final message = NdefMessage([record]);

            if (message.byteLength > ndef.maxSize) {
              await NfcManager.instance.stopSession(errorMessage: 'URL too long');
              if (mounted) {
                setState(() {
                  _step = _WriterStep.error;
                  _errorMessage = 'URL too long for this tag.';
                });
              }
              return;
            }

            await ndef.write(message);
            await NfcManager.instance.stopSession();
            HapticFeedback.heavyImpact();
            if (mounted) setState(() => _step = _WriterStep.success);
          } catch (e) {
            await NfcManager.instance.stopSession(errorMessage: 'Write failed');
            if (mounted) {
              setState(() {
                _step = _WriterStep.error;
                _errorMessage = 'Write failed: $e';
              });
            }
          }
        },
      );
    } catch (e) {
      if (mounted) {
        setState(() {
          _step = _WriterStep.error;
          _errorMessage = 'NFC session error: $e';
        });
      }
    }
  }

  void _reset() {
    setState(() {
      _step = _WriterStep.enterSwasthyaId;
      _citizen = null;
      _nfcUrl = null;
      _errorMessage = null;
      _idController.clear();
    });
  }

  @override
  Widget build(BuildContext context) {
    // If in profile form step, match user page background. Otherwise, match hospital portal styling.
    final bool isProfileStep = _step == _WriterStep.patientProfileForm;
    return Scaffold(
      backgroundColor: isProfileStep ? const Color(0xFFF8FAFC) : const Color(0xFF0A0E1A),
      appBar: isProfileStep
          ? AppBar(
              backgroundColor: const Color(0xFFF8FAFC),
              elevation: 0,
              centerTitle: true,
              leading: IconButton(
                icon: const Icon(Icons.arrow_back_ios_new_rounded, color: Color(0xFF64748B), size: 20),
                onPressed: _reset,
              ),
              title: _buildLogoHeader(),
              actions: [
                Container(
                  margin: const EdgeInsets.only(right: 12),
                  alignment: Alignment.center,
                  child: ElevatedButton.icon(
                    onPressed: _isSaving ? null : _saveAndProceed,
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
                ),
              ],
            )
          : AppBar(
              backgroundColor: Colors.transparent,
              elevation: 0,
              leading: IconButton(
                icon: const Icon(Icons.arrow_back_ios_new_rounded, color: Colors.white70, size: 20),
                onPressed: () => Navigator.pop(context),
              ),
              title: Text('NFC Card Writer', style: GoogleFonts.poppins(color: Colors.white, fontWeight: FontWeight.w600, fontSize: 17)),
              actions: [
                if (_nfcAvailable)
                  Container(
                    margin: const EdgeInsets.only(right: 16),
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: AppTheme.accentGreen.withOpacity(0.15),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: AppTheme.accentGreen.withOpacity(0.4)),
                    ),
                    child: Row(children: [
                      Container(width: 6, height: 6, decoration: const BoxDecoration(color: AppTheme.accentGreen, shape: BoxShape.circle)),
                      const SizedBox(width: 5),
                      Text('NFC Ready', style: TextStyle(color: AppTheme.accentGreen, fontSize: 10, fontWeight: FontWeight.bold)),
                    ]),
                  ),
              ],
            ),
      body: AnimatedSwitcher(
        duration: const Duration(milliseconds: 350),
        child: _buildBody(),
      ),
    );
  }

  Widget _buildBody() {
    switch (_step) {
      case _WriterStep.enterSwasthyaId:
        return _buildStep1();
      case _WriterStep.patientProfileForm:
        return _buildStep2();
      case _WriterStep.writing:
        return _buildWritingState();
      case _WriterStep.success:
        return _buildSuccessState();
      case _WriterStep.error:
        return _buildErrorState();
    }
  }

  // ── STEP 1: Enter SwasthyaTap ID ─────────────────────────────────────────
  Widget _buildStep1() {
    return SingleChildScrollView(
      key: const ValueKey('step1'),
      padding: const EdgeInsets.fromLTRB(24, 8, 24, 40),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Center(
            child: ScaleTransition(
              scale: _pulseAnim,
              child: Container(
                width: 130,
                height: 130,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: RadialGradient(colors: [
                    const Color(0xFF00C896).withOpacity(0.35),
                    const Color(0xFF004D40).withOpacity(0.15),
                    Colors.transparent,
                  ]),
                  border: Border.all(color: const Color(0xFF00C896).withOpacity(0.4), width: 1.5),
                ),
                child: const Icon(Icons.contactless_rounded, color: Color(0xFF00C896), size: 60),
              ),
            ),
          ),
          const SizedBox(height: 28),
          Text('Enter Patient SwasthyaTap ID', style: GoogleFonts.poppins(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold)),
          const SizedBox(height: 6),
          Text('The patient\'s unique SwasthyaTap ID is found in their Health Profile tab.', style: TextStyle(color: Colors.white54, fontSize: 13, height: 1.5)),
          const SizedBox(height: 28),

          Container(
            decoration: BoxDecoration(
              color: const Color(0xFF1A2035),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: const Color(0xFF00C896).withOpacity(0.3)),
            ),
            child: TextField(
              controller: _idController,
              style: GoogleFonts.robotoMono(color: Colors.white, fontSize: 18, letterSpacing: 4, fontWeight: FontWeight.bold),
              textCapitalization: TextCapitalization.none,
              decoration: InputDecoration(
                hintText: 'e.g. x7k9m2',
                hintStyle: GoogleFonts.robotoMono(color: Colors.white24, fontSize: 16, letterSpacing: 4),
                prefixIcon: const Icon(Icons.badge_outlined, color: Color(0xFF00C896), size: 22),
                border: InputBorder.none,
                contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 18),
              ),
              onSubmitted: (_) => _fetchPatient(),
            ),
          ),

          if (_errorMessage != null) ...[
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.red.withOpacity(0.1),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: Colors.red.withOpacity(0.3)),
              ),
              child: Row(children: [
                const Icon(Icons.error_outline, color: Colors.redAccent, size: 16),
                const SizedBox(width: 8),
                Expanded(child: Text(_errorMessage!, style: const TextStyle(color: Colors.redAccent, fontSize: 12))),
              ]),
            ),
          ],
          const SizedBox(height: 24),

          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: _isFetching ? null : _fetchPatient,
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF00C896),
                foregroundColor: Colors.black,
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                elevation: 0,
              ),
              child: _isFetching
                  ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.black))
                  : Text('Fetch Patient →', style: GoogleFonts.poppins(fontWeight: FontWeight.bold, fontSize: 15)),
            ),
          ),
        ],
      ),
    );
  }

  // ── STEP 2: Profile Page Exact Copy (Medical is Editable, Rest is Read-Only) ──
  Widget _buildStep2() {
    final citizen = _citizen!;
    return Form(
      key: _formKey,
      child: SingleChildScrollView(
        key: const ValueKey('step2'),
        physics: const BouncingScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(16, 4, 16, 100),
        child: Column(
          children: [
            // Profile details card (Exact Copy)
            _buildProfileDetailsCard(context, citizen),
            const SizedBox(height: 14),

            // SwasthyaTap ID Card (Exact Copy)
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
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFF00C896).withOpacity(0.08),
                    blurRadius: 12,
                    offset: const Offset(0, 4),
                  )
                ],
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
                        const Text('SwasthyaTap ID',
                            style: TextStyle(
                                color: Color(0xFF00C896),
                                fontSize: 10,
                                fontWeight: FontWeight.bold,
                                letterSpacing: 1.2)),
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
                        const Text('Authenticated profile connected to this Swasthya ID',
                            style: TextStyle(color: Color(0xFF64748B), fontSize: 10)),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 18),

            // 11 Expandable Item Cards
            Column(
              children: [
                // 1. Personal Information (READ-ONLY)
                _ProfileSectionTile(
                  number: 1,
                  title: _t('personal_info'),
                  subtitle: _t('personal_info_sub'),
                  icon: Icons.person_rounded,
                  iconColor: const Color(0xFF0F766E),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildDisabledField(_fullNameController, _t('full_name'), Icons.person),
                      const SizedBox(height: 12),
                      _buildDisabledField(_ageController, _t('label_age'), Icons.calendar_today),
                      const SizedBox(height: 12),
                      _buildDisabledField(_addressController, _t('label_address'), Icons.home, maxLines: 2),
                      const SizedBox(height: 12),
                      _buildDisabledField(_phoneController, _t('phone_number'), Icons.phone_android),
                      const SizedBox(height: 12),
                      _buildDisabledField(_emailController, _t('email_id'), Icons.email),
                    ],
                  ),
                ),

                // 2. Blood Group (EDITABLE)
                _ProfileSectionTile(
                  number: 2,
                  title: _t('blood_group'),
                  subtitle: _t('blood_group_sub'),
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
                          label: _t('blood_group'),
                          icon: Icons.bloodtype,
                        ),
                        items: ['O+', 'O-', 'A+', 'A-', 'B+', 'B-', 'AB+', 'AB-'].map((bg) {
                          return DropdownMenuItem(value: bg, child: Text(bg));
                        }).toList(),
                        onChanged: (val) {
                          if (val != null) {
                            setState(() => _bloodGroup = val);
                          }
                        },
                      ),
                    ],
                  ),
                ),

                // 3. Allergies (EDITABLE)
                _ProfileSectionTile(
                  number: 3,
                  title: _t('allergies'),
                  subtitle: _t('allergies_sub'),
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

                // 4. Current Medications (EDITABLE)
                _ProfileSectionTile(
                  number: 4,
                  title: _t('current_medications'),
                  subtitle: _t('current_medications_sub'),
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

                // 5. Medical Conditions (EDITABLE)
                _ProfileSectionTile(
                  number: 5,
                  title: _t('medical_conditions'),
                  subtitle: _t('medical_conditions_sub'),
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

                // 6. Emergency Contacts (READ-ONLY)
                _ProfileSectionTile(
                  number: 6,
                  title: _t('emergency_contacts'),
                  subtitle: _t('emergency_contacts_sub'),
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
                      _buildDisabledField(_contact1NameController, 'Contact Name', Icons.person),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          Expanded(child: _buildDisabledField(_contact1RelationController, 'Relation', Icons.family_restroom)),
                          const SizedBox(width: 8),
                          Expanded(child: _buildDisabledField(_contact1PhoneController, 'Phone Number', Icons.phone)),
                        ],
                      ),
                      const Divider(height: 24),
                      const Text(
                        'Secondary Emergency Contact (Optional)',
                        style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Color(0xFF0F766E)),
                      ),
                      const SizedBox(height: 8),
                      _buildDisabledField(_contact2NameController, 'Contact Name', Icons.person),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          Expanded(child: _buildDisabledField(_contact2RelationController, 'Relation', Icons.family_restroom)),
                          const SizedBox(width: 8),
                          Expanded(child: _buildDisabledField(_contact2PhoneController, 'Phone Number', Icons.phone)),
                        ],
                      ),
                    ],
                  ),
                ),

                // 7. Special Instructions (EDITABLE)
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

                // 8. Insurance Details (READ-ONLY)
                _ProfileSectionTile(
                  number: 8,
                  title: _t('insurance_schemes'),
                  subtitle: _t('insurance_schemes_sub'),
                  icon: Icons.umbrella_rounded,
                  iconColor: const Color(0xFF3B82F6),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildDisabledField(_insuranceCompanyController, 'Insurer Company Name', Icons.business),
                      const SizedBox(height: 12),
                      _buildDisabledField(_insurancePolicyNumberController, 'Policy Number', Icons.description),
                    ],
                  ),
                ),

                // 9. Medical Reports (READ-ONLY)
                _ProfileSectionTile(
                  number: 9,
                  title: _t('medical_reports'),
                  subtitle: _t('medical_reports_sub'),
                  icon: Icons.description_rounded,
                  iconColor: const Color(0xFF8B5CF6),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        citizen.medicalReports.isEmpty
                            ? 'No medical reports uploaded yet.'
                            : '${citizen.medicalReports.length} medical reports available.',
                        style: const TextStyle(fontSize: 12.5, color: Color(0xFF64748B), fontStyle: FontStyle.italic),
                      ),
                    ],
                  ),
                ),

                // 10. Organ Donation (READ-ONLY)
                _ProfileSectionTile(
                  number: 10,
                  title: _t('organ_donation'),
                  subtitle: _t('organ_donation_sub'),
                  icon: Icons.favorite_rounded,
                  iconColor: const Color(0xFFF43F5E),
                  child: citizen.organPledge != null
                      ? Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            _buildDetailRow(_t('notto_id'), citizen.organPledge!.pledgeId),
                            _buildDetailRow(_t('pledged_organs'), citizen.organPledge!.pledgedOrgans.join(', ')),
                            _buildDetailRow(_t('signed_date'), citizen.organPledge!.signedDate),
                          ],
                        )
                      : const Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'No Organ Donation Pledge registered yet.',
                              style: TextStyle(fontSize: 12.5, color: Color(0xFF64748B), fontStyle: FontStyle.italic),
                            ),
                          ],
                        ),
                ),

                // 11. Privacy Settings (READ-ONLY)
                _ProfileSectionTile(
                  number: 11,
                  title: _t('privacy_settings'),
                  subtitle: _t('privacy_settings_sub'),
                  icon: Icons.lock_outline_rounded,
                  iconColor: const Color(0xFF0F766E),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildDetailRow(_t('access_pin'), _t('pin_enabled')),
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
                            onChanged: null, // Read-only for hospital
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
            const SizedBox(height: 24),

            if (_errorMessage != null) ...[
              Container(
                margin: const EdgeInsets.only(bottom: 16),
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.red.withOpacity(0.08),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: Colors.red.withOpacity(0.2)),
                ),
                child: Row(children: [
                  const Icon(Icons.error_outline, color: Colors.redAccent, size: 16),
                  const SizedBox(width: 8),
                  Expanded(child: Text(_errorMessage!, style: const TextStyle(color: Colors.redAccent, fontSize: 12))),
                ]),
              ),
            ],

            if (!_nfcAvailable)
              Container(
                margin: const EdgeInsets.only(bottom: 16),
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.orange.withOpacity(0.08),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: Colors.orange.withOpacity(0.2)),
                ),
                child: Row(children: [
                  const Icon(Icons.warning_rounded, color: Colors.orange, size: 16),
                  const SizedBox(width: 8),
                  const Expanded(child: Text('NFC not available on this device. Click Save to proceed with simulator.', style: TextStyle(color: Colors.orange, fontSize: 12))),
                ]),
              ),

            // Bottom Save & Write Button
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: _isSaving ? null : _saveAndProceed,
                icon: _isSaving
                    ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                    : const Icon(Icons.save_rounded, size: 20, color: Colors.white),
                label: Text(_isSaving ? 'Saving Profile...' : 'Save & Write NFC Card', style: GoogleFonts.poppins(fontWeight: FontWeight.bold, fontSize: 15, color: Colors.white)),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF0F766E),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                  elevation: 2,
                ),
              ),
            ),
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: TextButton(
                onPressed: _reset,
                child: const Text('Cancel & Enter Different ID', style: TextStyle(color: Color(0xFF64748B), fontSize: 13)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ── Writing State ─────────────────────────────────────────────────────────
  Widget _buildWritingState() {
    return Center(
      key: const ValueKey('writing'),
      child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
        ScaleTransition(
          scale: _pulseAnim,
          child: Container(
            width: 150,
            height: 150,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: RadialGradient(colors: [
                const Color(0xFF00C896).withOpacity(0.3),
                const Color(0xFF004D40).withOpacity(0.1),
                Colors.transparent,
              ]),
              border: Border.all(color: const Color(0xFF00C896).withOpacity(0.5), width: 2),
            ),
            child: const Icon(Icons.contactless_rounded, color: Color(0xFF00C896), size: 72),
          ),
        ),
        const SizedBox(height: 32),
        Text('Hold NFC Tag to Phone', style: GoogleFonts.poppins(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold)),
        const SizedBox(height: 10),
        Text('Place an empty NFC tag\nagainst the back of your phone', textAlign: TextAlign.center, style: const TextStyle(color: Colors.white54, fontSize: 14, height: 1.6)),
        const SizedBox(height: 32),
        const CircularProgressIndicator(color: Color(0xFF00C896), strokeWidth: 2),
      ]),
    );
  }

  // ── Success State ─────────────────────────────────────────────────────────
  Widget _buildSuccessState() {
    return Center(
      key: const ValueKey('success'),
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
          Container(
            width: 120,
            height: 120,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: const Color(0xFF00C896).withOpacity(0.15),
              border: Border.all(color: const Color(0xFF00C896).withOpacity(0.5), width: 2),
            ),
            child: const Icon(Icons.check_circle_rounded, color: Color(0xFF00C896), size: 64),
          ),
          const SizedBox(height: 28),
          Text('Card Written!', style: GoogleFonts.poppins(color: Colors.white, fontSize: 24, fontWeight: FontWeight.bold)),
          const SizedBox(height: 10),
          Text(
            'NFC card for ${_citizen?.fullName ?? 'Patient'} has been programmed successfully.',
            textAlign: TextAlign.center,
            style: const TextStyle(color: Colors.white54, fontSize: 14, height: 1.6),
          ),
          if (_nfcUrl != null) ...[
            const SizedBox(height: 20),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color(0xFF1A2035),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: Colors.white12),
              ),
              child: Row(children: [
                Expanded(child: Text(_nfcUrl!, style: GoogleFonts.robotoMono(color: Colors.white54, fontSize: 9), maxLines: 2, overflow: TextOverflow.ellipsis)),
                IconButton(
                  icon: const Icon(Icons.copy_rounded, color: Color(0xFF00C896), size: 16),
                  onPressed: () {
                    Clipboard.setData(ClipboardData(text: _nfcUrl!));
                    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('URL copied'), backgroundColor: Color(0xFF00C896)));
                  },
                ),
              ]),
            ),
          ],
          const SizedBox(height: 32),
          ElevatedButton(
            onPressed: _reset,
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF00C896),
              foregroundColor: Colors.black,
              padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 14),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
            ),
            child: Text('Write Another Card', style: GoogleFonts.poppins(fontWeight: FontWeight.bold)),
          ),
        ]),
      ),
    );
  }

  // ── Error State ───────────────────────────────────────────────────────────
  Widget _buildErrorState() {
    return Center(
      key: const ValueKey('error'),
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
          Container(
            width: 120,
            height: 120,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: Colors.redAccent.withOpacity(0.1),
              border: Border.all(color: Colors.redAccent.withOpacity(0.4), width: 2),
            ),
            child: const Icon(Icons.error_outline_rounded, color: Colors.redAccent, size: 60),
          ),
          const SizedBox(height: 28),
          Text('Write Failed', style: GoogleFonts.poppins(color: Colors.white, fontSize: 22, fontWeight: FontWeight.bold)),
          const SizedBox(height: 10),
          Text(_errorMessage ?? 'An unexpected error occurred.', textAlign: TextAlign.center, style: const TextStyle(color: Colors.white54, fontSize: 14, height: 1.6)),
          const SizedBox(height: 32),
          ElevatedButton(
            onPressed: () => setState(() {
              _step = _WriterStep.patientProfileForm;
              _errorMessage = null;
            }),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF1A2035),
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 14),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
            ),
            child: const Text('Try Again'),
          ),
        ]),
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

  Widget _buildProfileDetailsCard(BuildContext context, MedicalProfile citizen) {
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
          // Left: Avatar (Read-only for hospital writer)
          Stack(
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
            ],
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
                    _t('st_uid'),
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
                            _t('abha_linked'),
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
                            _t('aadhaar_badge'),
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
                        _t('complete'),
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
                _t('profile_complete'),
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
    return Container(
      color: const Color(0xFFE6F4F1),
      alignment: Alignment.center,
      child: Text(
        initials,
        style: TextStyle(
          fontSize: fontSize,
          fontWeight: FontWeight.bold,
          color: const Color(0xFF0F766E),
        ),
      ),
    );
  }

  Widget _buildDisabledField(TextEditingController controller, String label, IconData icon, {int maxLines = 1}) {
    return TextFormField(
      controller: controller,
      enabled: false,
      maxLines: maxLines,
      style: const TextStyle(fontSize: 13, color: Color(0xFF64748B)),
      decoration: AppTheme.premiumInputDecoration(
        label: label,
        icon: icon,
      ),
    );
  }

  Widget _buildDetailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('$label: ', style: const TextStyle(color: Color(0xFF64748B), fontSize: 12, fontWeight: FontWeight.bold)),
          Expanded(child: Text(value, style: const TextStyle(color: Color(0xFF0F172A), fontSize: 12))),
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
          _buildSecurityBadge(Icons.shield_outlined, _t('data_encrypted_secure')),
          _buildSecurityBadge(Icons.lock_outline_rounded, _t('pin_protected_badge')),
          _buildSecurityBadge(Icons.nfc_outlined, _t('share_nfc_only')),
          _buildSecurityBadge(Icons.verified_user_outlined, _t('hipaa_dpdp_compliant')),
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
}

// ── Collapsible Section Tile (Exact copy from citizen_dashboard.dart) ──
class _ProfileSectionTile extends StatefulWidget {
  final int number;
  final String title;
  final String subtitle;
  final IconData icon;
  final Color iconColor;
  final Widget? trailing;
  final Widget child;

  const _ProfileSectionTile({
    required this.number,
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.iconColor,
    this.trailing,
    required this.child,
  });

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
                      if (widget.trailing != null) ...[
                        widget.trailing!,
                        const SizedBox(width: 8),
                      ],
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
