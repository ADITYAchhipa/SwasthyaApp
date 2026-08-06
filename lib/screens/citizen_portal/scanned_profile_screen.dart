import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../../theme/app_theme.dart';
import '../../utils/translation_service.dart';
import '../../utils/medical_translation_service.dart';
import '../../models/models.dart';
import '../../services/api_service.dart';
import '../../utils/pdf_downloader.dart';
import 'card_viewer_screen.dart'; // To reuse HeartEcgPainter

class ScannedProfileScreen extends StatefulWidget {
  final String profileId;
  final MedicalProfile? preloadedProfile;
  const ScannedProfileScreen({Key? key, this.profileId = 'x7k9m2', this.preloadedProfile}) : super(key: key);

  @override
  State<ScannedProfileScreen> createState() => _ScannedProfileScreenState();
}

class _ScannedProfileScreenState extends State<ScannedProfileScreen> {
  String _t(String key) => TranslationService.t(context, key);
  String _tm(String value) => MedicalTranslationService.translate(context, value);

  late Future<MedicalProfile?> _profileFuture;

  @override
  void initState() {
    super.initState();
    if (widget.preloadedProfile != null) {
      _profileFuture = Future.value(widget.preloadedProfile);
    } else {
      _profileFuture = ApiService.getCitizen(widget.profileId);
    }
  }

  // Expansion states for the sections
  bool _medsExpanded = true;
  bool _conditionsExpanded = true;
  bool _contactsExpanded = true;
  bool _insuranceExpanded = true;

  // Prescriptions Search and Filter state
  String _rxSearchQuery = '';
  String _rxStatusFilter = 'All';

  // Mock JSON representing what will come from the backend for receipts
  final List<Map<String, dynamic>> _receiptsJson = [
    {
      'title_key': 'opd_consultation_receipt',
      'issuer_key': 'dr_amit_shah',
      'date': '20 Jun 2026',
      'amount': '₹500',
      'status_key': 'paid',
    },
    {
      'title_key': 'pharmacy_billing_rx',
      'issuer_key': 'apollo_pharmacy',
      'date': '21 Jun 2026',
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
  ];

  // Mock JSON representing what will come from the backend for medical reports
  final List<Map<String, dynamic>> _reportsJson = [
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
  ];
  @override
  Widget build(BuildContext context) {
    return FutureBuilder<MedicalProfile?>(
      future: _profileFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(
            backgroundColor: Color(0xFFF1F5F9),
            body: Center(
              child: CircularProgressIndicator(
                valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF018086)),
              ),
            ),
          );
        }
        if (snapshot.hasError || !snapshot.hasData || snapshot.data == null) {
          return Scaffold(
            backgroundColor: const Color(0xFFF1F5F9),
            appBar: AppBar(
              backgroundColor: Colors.white,
              elevation: 0,
              leading: IconButton(
                icon: const Icon(Icons.arrow_back_ios_new_rounded, color: Color(0xFF0F172A), size: 20),
                onPressed: () => Navigator.pop(context),
              ),
              title: Text(
                'Error',
                style: GoogleFonts.outfit(
                  color: const Color(0xFF0F172A),
                  fontWeight: FontWeight.bold,
                  fontSize: 20,
                ),
              ),
            ),
            body: Center(
              child: Text(
                _t('profile_not_found'),
                style: GoogleFonts.inter(
                  color: const Color(0xFF64748B),
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          );
        }

        final profile = snapshot.data!;

        return DefaultTabController(
          length: 3,
          child: Scaffold(
            backgroundColor: const Color(0xFFF1F5F9), // Sleek, modern background
            appBar: AppBar(
              backgroundColor: Colors.white,
              elevation: 0,
              centerTitle: true,
              leading: IconButton(
                icon: const Icon(Icons.arrow_back_ios_new_rounded, color: Color(0xFF0F172A), size: 20),
                onPressed: () => Navigator.pop(context),
              ),
              title: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  CustomPaint(
                    size: const Size(22, 22),
                    painter: HeartEcgPainter(color: const Color(0xFF018086)),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    'SwasthyaTap',
                    style: GoogleFonts.outfit(
                      color: const Color(0xFF0F172A),
                      fontWeight: FontWeight.bold,
                      fontSize: 20,
                      letterSpacing: -0.5,
                    ),
                  ),
                ],
              ),
              actions: [
                Container(
                  margin: const EdgeInsets.only(right: 14),
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF0FDF4),
                    borderRadius: BorderRadius.circular(100),
                    border: Border.all(color: const Color(0xFFDCFCE7), width: 1.5),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.verified_rounded, color: Color(0xFF16A34A), size: 14),
                      const SizedBox(width: 4),
                      Text(
                        _t('verified'),
                        style: GoogleFonts.inter(
                          color: const Color(0xFF15803D),
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
              bottom: TabBar(
                labelColor: const Color(0xFF0F766E),
                unselectedLabelColor: const Color(0xFF64748B),
                indicatorColor: const Color(0xFF0F766E),
                indicatorSize: TabBarIndicatorSize.tab,
                labelStyle: GoogleFonts.inter(fontWeight: FontWeight.bold, fontSize: 13),
                unselectedLabelStyle: GoogleFonts.inter(fontWeight: FontWeight.w600, fontSize: 13),
                tabs: [
                  Tab(text: _t('nav_profile')),
                  Tab(text: _t('reports_label')),
                  Tab(text: _tm('prescriptions_label')),
                ],
              ),
            ),
            body: TabBarView(
              children: [
                _buildProfileTab(profile),
                _buildReportsTab(profile),
                _buildPrescriptionsTab(profile),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildProfileTab(MedicalProfile profile) {
    return SingleChildScrollView(
        physics: const BouncingScrollPhysics(),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // 1. Card Read Successfully Banner - High-fidelity Teal/Green Gradient
            Container(
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  colors: [Color(0xFF059669), Color(0xFF10B981)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                boxShadow: [
                  BoxShadow(
                    color: Color(0x20059669),
                    blurRadius: 10,
                    offset: Offset(0, 4),
                  ),
                ],
              ),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              child: SafeArea(
                bottom: false,
                top: false,
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(4),
                      decoration: const BoxDecoration(
                        color: Colors.white24,
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(Icons.check_rounded, color: Colors.white, size: 16),
                    ).animate(onPlay: (controller) => controller.repeat(reverse: true))
                     .scale(begin: const Offset(0.9, 0.9), end: const Offset(1.1, 1.1), duration: 800.ms),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        _t('card_read_success'),
                        style: GoogleFonts.inter(
                          color: Colors.white,
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 0.2,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      '26 Jun 2025, 09:41 AM',
                      style: GoogleFonts.inter(
                        color: Colors.white.withOpacity(0.9),
                        fontSize: 11.5,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
            ),

            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // 2. Personal Profile Card with Premium Glassmorphism styling
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(20),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.04),
                          blurRadius: 16,
                          offset: const Offset(0, 8),
                        ),
                      ],
                      border: Border.all(color: const Color(0xFFE2E8F0)),
                    ),
                    child: Column(
                      children: [
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // Avatar with custom status indicator
                            Stack(
                              clipBehavior: Clip.none,
                              children: [
                                Container(
                                  width: 84,
                                  height: 84,
                                  decoration: BoxDecoration(
                                    shape: BoxShape.circle,
                                    boxShadow: [
                                      BoxShadow(
                                        color: const Color(0xFF0F766E).withOpacity(0.15),
                                        blurRadius: 10,
                                        spreadRadius: 2,
                                      ),
                                    ],
                                    image: const DecorationImage(
                                      image: NetworkImage('https://images.unsplash.com/photo-1507003211169-0a1dd7228f2d?fit=crop&w=150&h=150&q=80'),
                                      fit: BoxFit.cover,
                                    ),
                                    border: Border.all(color: const Color(0xFF0F766E), width: 2),
                                  ),
                                ),
                                Positioned(
                                  bottom: -2,
                                  right: -2,
                                  child: Container(
                                    padding: const EdgeInsets.all(4),
                                    decoration: const BoxDecoration(
                                      color: Color(0xFF0F766E),
                                      shape: BoxShape.circle,
                                    ),
                                    child: const Icon(
                                      Icons.security_rounded,
                                      color: Colors.white,
                                      size: 13,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(width: 14),
                            // Details - Fully Expanded & safe from overflow
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    profile.fullName,
                                    style: GoogleFonts.outfit(
                                      fontSize: 22,
                                      fontWeight: FontWeight.bold,
                                      color: const Color(0xFF0F172A),
                                      letterSpacing: -0.5,
                                    ),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    profile.age != null ? '${profile.age} ${_t('years')}' : _tm('unknown_age'),
                                    style: GoogleFonts.inter(
                                      fontSize: 13.5,
                                      color: const Color(0xFF475569),
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                  const SizedBox(height: 6),

                                ],
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 16),
                        const Divider(height: 1, color: Color(0xFFE2E8F0)),
                        const SizedBox(height: 12),
                        // Blood group indicator - horizontal layout to prevent side-overflow
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Row(
                              children: [
                                const Icon(Icons.water_drop_rounded, color: Color(0xFFDC2626), size: 20),
                                const SizedBox(width: 6),
                                Text(
                                  _t('blood_group'),
                                  style: GoogleFonts.inter(
                                    fontSize: 11,
                                    fontWeight: FontWeight.w800,
                                    color: const Color(0xFF64748B),
                                    letterSpacing: 0.5,
                                  ),
                                ),
                              ],
                            ),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                              decoration: BoxDecoration(
                                color: const Color(0xFFFEF2F2),
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(color: const Color(0xFFFCA5A5), width: 1.5),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Text(
                                    profile.bloodGroup,
                                    style: GoogleFonts.outfit(
                                      fontSize: 16,
                                      fontWeight: FontWeight.bold,
                                      color: const Color(0xFFDC2626),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ).animate().fade(duration: 400.ms).slideY(begin: 0.1, end: 0, duration: 400.ms),
                  const SizedBox(height: 12),

                  // 3. Critical Allergies - Wrap Layout (Zero Overflows!)
                  Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [Color(0xFFFFF1F2), Color(0xFFFFE4E6)],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: const Color(0xFFFECDD3)),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Row(
                          children: [
                            const Icon(Icons.warning_amber_rounded, color: Color(0xFFE11D48), size: 18),
                            const SizedBox(width: 6),
                            Text(
                              _t('critical_allergies_detected'),
                              style: GoogleFonts.inter(
                                color: const Color(0xFF9F1239),
                                fontSize: 11,
                                fontWeight: FontWeight.w800,
                                letterSpacing: 0.5,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 10),
                        Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: profile.allergies.toLowerCase() == 'none' || profile.allergies.trim().isEmpty
                              ? [
                                  Padding(
                                    padding: const EdgeInsets.symmetric(vertical: 4),
                                    child: Text(
                                      _tm('none'),
                                      style: GoogleFonts.inter(
                                        color: const Color(0xFF64748B),
                                        fontSize: 13,
                                        fontWeight: FontWeight.w500,
                                      ),
                                    ),
                                  )
                                ]
                              : profile.allergies
                                  .split(',')
                                  .map((a) => a.trim())
                                  .where((a) => a.isNotEmpty)
                                  .map((a) => _buildAllergyPill(a))
                                  .toList(),
                        ),
                      ],
                    ),
                  ).animate().fade(delay: 100.ms, duration: 400.ms).slideY(begin: 0.1, end: 0, duration: 400.ms),
                  const SizedBox(height: 16),

                  // 4. Expandable items with Accent strips and gorgeous design
                  // Section 1: Active Medications
                  _buildAccordionTile(
                    title: _t('active_medications_sec'),
                    icon: Icons.medical_services_outlined,
                    accentColor: const Color(0xFF0F766E),
                    isExpanded: _medsExpanded,
                    onToggle: () => setState(() => _medsExpanded = !_medsExpanded),
                    content: Column(
                      children: profile.medications.toLowerCase() == 'none' || profile.medications.trim().isEmpty
                          ? [
                              Padding(
                                padding: const EdgeInsets.all(12.0),
                                child: Text(_tm('none'), style: GoogleFonts.inter(color: Colors.grey)),
                              )
                            ]
                          : profile.medications
                              .split(',')
                              .map((m) => m.trim())
                              .where((m) => m.isNotEmpty)
                              .map((m) => _buildMedicationRow(_tm(m), _tm('As Prescribed'), _tm('Daily')))
                              .toList(),
                    ),
                  ).animate().fade(delay: 150.ms, duration: 400.ms).slideY(begin: 0.05, end: 0, duration: 400.ms),
                  const SizedBox(height: 12),

                  // Section 2: Medical Conditions
                  _buildAccordionTile(
                    title: _t('medical_conditions_sec'),
                    icon: Icons.favorite_border_rounded,
                    accentColor: const Color(0xFFDC2626),
                    isExpanded: _conditionsExpanded,
                    onToggle: () => setState(() => _conditionsExpanded = !_conditionsExpanded),
                    content: Column(
                      children: profile.chronicConditions.toLowerCase() == 'none' || profile.chronicConditions.trim().isEmpty
                          ? [
                              Padding(
                                padding: const EdgeInsets.all(12.0),
                                child: Text(_tm('none'), style: GoogleFonts.inter(color: Colors.grey)),
                              )
                            ]
                          : profile.chronicConditions
                              .split(',')
                              .map((c) => c.trim())
                              .where((c) => c.isNotEmpty)
                              .map((c) => _buildConditionRow(_tm(c), _tm('Monitored'), const Color(0xFFF97316)))
                              .toList(),
                    ),
                  ).animate().fade(delay: 200.ms, duration: 400.ms).slideY(begin: 0.05, end: 0, duration: 400.ms),
                  const SizedBox(height: 12),

                  // Section 3: Emergency Contacts
                  _buildAccordionTile(
                    title: _t('emergency_contacts_sec'),
                    icon: Icons.phone_outlined,
                    accentColor: const Color(0xFF16A34A),
                    isExpanded: _contactsExpanded,
                    onToggle: () => setState(() => _contactsExpanded = !_contactsExpanded),
                    content: Column(
                      children: profile.emergencyContacts.isEmpty
                          ? [
                              Padding(
                                padding: const EdgeInsets.all(12.0),
                                child: Text(_tm('none'), style: GoogleFonts.inter(color: Colors.grey)),
                              )
                            ]
                          : profile.emergencyContacts
                              .map((c) => Column(
                                    children: [
                                      _buildContactRow(c.name, _tm(c.relation), c.phone),
                                      const Divider(height: 1, color: Color(0xFFF1F5F9)),
                                    ],
                                  ))
                              .toList(),
                    ),
                  ).animate().fade(delay: 250.ms, duration: 400.ms).slideY(begin: 0.05, end: 0, duration: 400.ms),
                  const SizedBox(height: 12),

                  // Section 4: Insurance
                  _buildAccordionTile(
                    title: _t('insurance_sec'),
                    icon: Icons.shield_outlined,
                    accentColor: const Color(0xFF2563EB),
                    isExpanded: _insuranceExpanded,
                    onToggle: () => setState(() => _insuranceExpanded = !_insuranceExpanded),
                    content: Container(
                      padding: const EdgeInsets.all(14),
                      child: Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: const Color(0xFFEFF6FF),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: const Icon(Icons.shield_rounded, color: Color(0xFF2563EB), size: 24),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  profile.insuranceCompany.isNotEmpty ? _tm(profile.insuranceCompany) : _tm('none'),
                                  style: GoogleFonts.inter(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 13,
                                    color: const Color(0xFF1E293B),
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                  decoration: BoxDecoration(
                                    color: profile.insuranceCompany.isNotEmpty ? const Color(0xFFE0F2FE) : const Color(0xFFF1F5F9),
                                    borderRadius: BorderRadius.circular(4),
                                  ),
                                  child: Text(
                                    profile.insuranceCompany.isNotEmpty ? _tm('active') : _tm('inactive'),
                                    style: GoogleFonts.inter(
                                      color: profile.insuranceCompany.isNotEmpty ? const Color(0xFF0369A1) : const Color(0xFF64748B),
                                      fontWeight: FontWeight.bold,
                                      fontSize: 9,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 8),
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.end,
                            children: [
                              Text(
                                _tm('POLICY NO'),
                                style: GoogleFonts.inter(
                                  fontSize: 9.5,
                                  color: const Color(0xFF94A3B8),
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                profile.insurancePolicyNumber.isNotEmpty ? profile.insurancePolicyNumber : 'N/A',
                                style: GoogleFonts.inter(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 12,
                                  color: const Color(0xFF334155),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ).animate().fade(delay: 300.ms, duration: 400.ms).slideY(begin: 0.05, end: 0, duration: 400.ms),
                  const SizedBox(height: 24),

                  // 7. HIPAA Footer Disclaimer
                  Container(
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(Icons.lock_rounded, color: Color(0xFF64748B), size: 12),
                        const SizedBox(width: 6),
                        Expanded(
                          child: Text(
                            _tm('telemetry_disclaimer'),
                            style: GoogleFonts.inter(
                              color: const Color(0xFF64748B),
                              fontSize: 9.5,
                              fontWeight: FontWeight.w600,
                            ),
                            textAlign: TextAlign.center,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 20),
                ],
              ),
            ),
          ],
        ),
      );
  }

  Widget _buildReportsTab(MedicalProfile profile) {
    return SingleChildScrollView(
      physics: const BouncingScrollPhysics(),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Header Stats card for medical reports
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(0xFF0F766E), Color(0xFF0D9488)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(20),
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFF0D9488).withOpacity(0.2),
                    blurRadius: 12,
                    offset: const Offset(0, 6),
                  ),
                ],
              ),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.2),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.assignment_rounded, color: Colors.white, size: 24),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          _t('medical_reports'),
                          style: GoogleFonts.inter(
                            color: Colors.white,
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          _t('medical_reports_sub'),
                          style: GoogleFonts.inter(
                            color: Colors.white.withOpacity(0.9),
                            fontSize: 12,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ).animate().fade(duration: 400.ms).slideY(begin: 0.1, end: 0, duration: 400.ms),
            const SizedBox(height: 16),

            // Reports List Container
            Container(
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(20),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.02),
                    blurRadius: 10,
                    offset: const Offset(0, 4),
                  ),
                ],
                border: Border.all(color: const Color(0xFFE2E8F0)),
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(20),
                child: profile.medicalReports.isEmpty
                    ? Padding(
                        padding: const EdgeInsets.all(20.0),
                        child: Center(
                          child: Text(
                            _tm('none'),
                            style: GoogleFonts.inter(
                              color: const Color(0xFF64748B),
                              fontSize: 14,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ),
                      )
                    : Column(
                        children: profile.medicalReports.map((report) {
                          final isLast = profile.medicalReports.indexOf(report) == profile.medicalReports.length - 1;
                          return Column(
                            children: [
                              _buildReportRow(
                                context: context,
                                title: _tm(report['title_key'] ?? ''),
                                subtitle: '${_tm(report['issuer_key'] ?? '')}  •  ${report['date'] ?? ''}',
                                status: _tm(report['status_key'] ?? ''),
                                doctor: _tm(report['doctor_key'] ?? ''),
                                url: report['url'] ?? report['fileUrl'] ?? report['pdfUrl'],
                              ),
                              if (!isLast) const Divider(height: 1, color: Color(0xFFF1F5F9)),
                            ],
                          );
                        }).toList(),
                      ),
              ),
            ).animate().fade(delay: 100.ms, duration: 400.ms).slideY(begin: 0.05, end: 0, duration: 400.ms),
          ],
        ),
      ),
    );
  }

  Widget _buildReportRow({
    required BuildContext context,
    required String title,
    required String subtitle,
    required String status,
    required String doctor,
    String? url,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(
                      title,
                      style: GoogleFonts.inter(
                        fontSize: 13.5,
                        fontWeight: FontWeight.bold,
                        color: const Color(0xFF1E293B),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1.5),
                      decoration: BoxDecoration(
                        color: const Color(0xFFDCFCE7),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        status,
                        style: GoogleFonts.inter(
                          color: const Color(0xFF15803D),
                          fontSize: 8.5,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  subtitle,
                  style: GoogleFonts.inter(
                    fontSize: 11,
                    color: const Color(0xFF64748B),
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  doctor,
                  style: GoogleFonts.inter(
                    fontSize: 11,
                    color: const Color(0xFF0F766E),
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          if (url != null && url.isNotEmpty) ...[
            IconButton(
              onPressed: () async {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Downloading medical report...')),
                );
                try {
                  await downloadPdfFromUrl(url, '${title.replaceAll(" ", "_")}.pdf');
                } catch (e) {
                  if (!context.mounted) return;
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Error downloading report: $e'), backgroundColor: Colors.red),
                  );
                }
              },
              icon: const Icon(Icons.download_rounded, size: 18, color: Color(0xFF0D9488)),
              style: IconButton.styleFrom(
                padding: const EdgeInsets.all(8),
                backgroundColor: const Color(0xFFF0FDF4),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              ),
            ),
            const SizedBox(width: 8),
          ],
          IconButton(
            onPressed: () {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text(_tm('viewing_report_snack').replaceFirst('{}', title)),
                  duration: const Duration(seconds: 1),
                ),
              );
            },
            icon: const Icon(Icons.visibility_outlined, size: 18, color: Color(0xFF0F766E)),
            style: IconButton.styleFrom(
              padding: const EdgeInsets.all(8),
              backgroundColor: const Color(0xFFF0FDF4),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPrescriptionsTab(MedicalProfile profile) {
    final rawList = profile.prescriptions.isNotEmpty
        ? profile.prescriptions
        : [
            {
              'prescriptionId': 'RX-2026-891',
              'doctorName': 'Dr. Amit Shah',
              'qualification': 'MD (Cardiology), FACC',
              'hospitalName': 'Apollo Speciality Hospital',
              'date': '20 Jun 2026',
              'diagnosis': 'Mild Hypertension & Preventive Checkup',
              'rxList': [
                {'medicineName': 'Telmisartan 40mg', 'dosage': '1 Tablet', 'frequency': 'Once Daily (Morning)', 'duration': '30 Days', 'instructions': 'Take after breakfast'},
                {'medicineName': 'Amlodipine 5mg', 'dosage': '1 Tablet', 'frequency': 'Once Daily (Night)', 'duration': '30 Days', 'instructions': 'Take before sleep'},
                {'medicineName': 'Multivitamin Complex', 'dosage': '1 Capsule', 'frequency': 'Once Daily', 'duration': '15 Days', 'instructions': 'Take after meal'}
              ],
              'doctorNotes': 'Maintain low sodium diet, 30 mins morning walk recommended. Follow up after 1 month with BP log.',
              'status': 'Active'
            },
            {
              'prescriptionId': 'RX-2026-442',
              'doctorName': 'Dr. Patel',
              'qualification': 'MBBS, MD (General Medicine)',
              'hospitalName': 'City Care Clinic',
              'date': '10 May 2026',
              'diagnosis': 'Acute Upper Respiratory Tract Infection',
              'rxList': [
                {'medicineName': 'Amoxicillin 500mg', 'dosage': '1 Capsule', 'frequency': 'Thrice Daily', 'duration': '5 Days', 'instructions': 'Complete full course'},
                {'medicineName': 'Paracetamol 650mg', 'dosage': '1 Tablet', 'frequency': 'As needed for fever', 'duration': '5 Days', 'instructions': 'Max 3 tablets daily'}
              ],
              'doctorNotes': 'Drink warm water and steam inhalation twice daily.',
              'status': 'Completed'
            }
          ];

    final filteredList = rawList.where((rx) {
      final rxMap = Map<String, dynamic>.from(rx as Map);
      final docName = (rxMap['doctorName'] ?? '').toString().toLowerCase();
      final hospName = (rxMap['hospitalName'] ?? '').toString().toLowerCase();
      final diag = (rxMap['diagnosis'] ?? '').toString().toLowerCase();
      final query = _rxSearchQuery.toLowerCase();

      final matchesSearch = docName.contains(query) || hospName.contains(query) || diag.contains(query);
      final matchesStatus = _rxStatusFilter == 'All' || (rxMap['status'] ?? 'Active') == _rxStatusFilter;

      return matchesSearch && matchesStatus;
    }).toList();

    return SingleChildScrollView(
      physics: const BouncingScrollPhysics(),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Header Stats card for prescriptions
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(0xFF0284C7), Color(0xFF0369A1)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(20),
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFF0284C7).withOpacity(0.2),
                    blurRadius: 12,
                    offset: const Offset(0, 6),
                  ),
                ],
              ),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.2),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.medication_rounded, color: Colors.white, size: 24),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          _tm('digital_prescriptions'),
                          style: GoogleFonts.inter(
                            color: Colors.white,
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          '${filteredList.length} ' + _tm('verified_rx_records'),
                          style: GoogleFonts.inter(
                            color: Colors.white.withOpacity(0.9),
                            fontSize: 12,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ).animate().fade(duration: 400.ms).slideY(begin: 0.1, end: 0, duration: 400.ms),
            const SizedBox(height: 16),

            // Search Bar Input
            Container(
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: const Color(0xFFE2E8F0)),
              ),
              child: TextField(
                onChanged: (val) {
                  setState(() {
                    _rxSearchQuery = val;
                  });
                },
                decoration: InputDecoration(
                  hintText: _tm('search_placeholder'),
                  hintStyle: GoogleFonts.inter(fontSize: 13, color: const Color(0xFF94A3B8)),
                  prefixIcon: const Icon(Icons.search_rounded, color: Color(0xFF64748B), size: 20),
                  border: InputBorder.none,
                  contentPadding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
                ),
              ),
            ),
            const SizedBox(height: 12),

            // Status Filter Choice Chips
            Row(
              children: ['All', 'Active', 'Completed'].map((statusOption) {
                final isSelected = _rxStatusFilter == statusOption;
                final displayLabel = statusOption == 'All' ? _t('all') : (statusOption == 'Active' ? _tm('active') : _tm('completed'));
                return Padding(
                  padding: const EdgeInsets.only(right: 8.0),
                  child: FilterChip(
                    label: Text(
                      displayLabel,
                      style: GoogleFonts.inter(
                        fontSize: 12,
                        fontWeight: isSelected ? FontWeight.bold : FontWeight.w600,
                        color: isSelected ? Colors.white : const Color(0xFF475569),
                      ),
                    ),
                    selected: isSelected,
                    selectedColor: const Color(0xFF0284C7),
                    backgroundColor: Colors.white,
                    side: BorderSide(
                      color: isSelected ? const Color(0xFF0284C7) : const Color(0xFFCBD5E1),
                    ),
                    onSelected: (selected) {
                      if (selected) {
                        setState(() {
                          _rxStatusFilter = statusOption;
                        });
                      }
                    },
                  ),
                );
              }).toList(),
            ),
            const SizedBox(height: 16),

            // Individual Prescription Cards List
            filteredList.isEmpty
                ? Container(
                    padding: const EdgeInsets.all(30.0),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: const Color(0xFFE2E8F0)),
                    ),
                    child: Center(
                      child: Text(
                        _tm('no_matching_prescriptions'),
                        style: GoogleFonts.inter(
                          color: const Color(0xFF64748B),
                          fontSize: 14,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                  )
                : Column(
                    children: filteredList.map((rx) {
                      final rxMap = Map<String, dynamic>.from(rx as Map);
                      return _buildPrescriptionCard(context: context, rxData: rxMap);
                    }).toList(),
                  ).animate().fade(delay: 100.ms, duration: 400.ms).slideY(begin: 0.05, end: 0, duration: 400.ms),
          ],
        ),
      ),
    );
  }

  Widget _buildPrescriptionCard({
    required BuildContext context,
    required Map<String, dynamic> rxData,
  }) {
    final String doctorName = rxData['doctorName'] ?? 'Doctor Prescription';
    final String qualification = rxData['qualification'] ?? '';
    final String hospitalName = rxData['hospitalName'] ?? '';
    final String date = rxData['date'] ?? '';
    final String diagnosis = rxData['diagnosis'] ?? 'General Consultation';
    final String status = rxData['status'] ?? 'Active';
    final List rxList = (rxData['rxList'] as List<dynamic>?) ?? [];

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFFE2E8F0)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.03),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Rx Header Letterhead Accent
          Container(
            padding: const EdgeInsets.all(16),
            decoration: const BoxDecoration(
              color: Color(0xFFF8FAFC),
              borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
              border: Border(bottom: BorderSide(color: Color(0xFFF1F5F9))),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _tm('rx'),
                  style: GoogleFonts.outfit(
                    fontSize: 28,
                    fontWeight: FontWeight.w900,
                    color: const Color(0xFF0284C7),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        _tm(doctorName),
                        style: GoogleFonts.inter(
                          fontSize: 15,
                          fontWeight: FontWeight.bold,
                          color: const Color(0xFF0F172A),
                        ),
                      ),
                      if (qualification.isNotEmpty)
                        Text(
                          _tm(qualification),
                          style: GoogleFonts.inter(fontSize: 11, color: const Color(0xFF64748B)),
                        ),
                      const SizedBox(height: 4),
                      Text(
                        '🏥 ${_tm(hospitalName)}  •  📅 $date',
                        style: GoogleFonts.inter(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: const Color(0xFF0F766E),
                        ),
                      ),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: status == 'Active' ? const Color(0xFFE0F2FE) : const Color(0xFFF1F5F9),
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(
                      color: status == 'Active' ? const Color(0xFFBAE6FD) : const Color(0xFFE2E8F0),
                    ),
                  ),
                  child: Text(
                    _tm(status),
                    style: GoogleFonts.inter(
                      color: status == 'Active' ? const Color(0xFF0369A1) : const Color(0xFF64748B),
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
          ),

          // Card Content Body
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Diagnosis Banner
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF0F9FF),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: const Color(0xFFBAE6FD)),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        _tm('clinical_diagnosis'),
                        style: GoogleFonts.inter(
                          fontSize: 9.5,
                          fontWeight: FontWeight.w800,
                          color: const Color(0xFF0369A1),
                          letterSpacing: 0.5,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        _tm(diagnosis),
                        style: GoogleFonts.inter(
                          fontSize: 13,
                          fontWeight: FontWeight.bold,
                          color: const Color(0xFF0F172A),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 14),

                // Medicines Summary
                Text(
                  _tm('prescribed_medicines') + ' (${rxList.length})',
                  style: GoogleFonts.inter(
                    fontSize: 10,
                    fontWeight: FontWeight.w800,
                    color: const Color(0xFF64748B),
                    letterSpacing: 0.5,
                  ),
                ),
                const SizedBox(height: 8),
                ...rxList.map((item) {
                  final itemMap = Map<String, dynamic>.from(item as Map);
                  return Container(
                    margin: const EdgeInsets.only(bottom: 6),
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF8FAFC),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: const Color(0xFFF1F5F9)),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                _tm(itemMap['medicineName'] ?? ''),
                                style: GoogleFonts.inter(
                                  fontSize: 12,
                                  fontWeight: FontWeight.bold,
                                  color: const Color(0xFF0F172A),
                                ),
                              ),
                              if (itemMap['instructions'] != null)
                                Text(
                                  _tm(itemMap['instructions']),
                                  style: GoogleFonts.inter(fontSize: 10, color: const Color(0xFF64748B)),
                                ),
                            ],
                          ),
                        ),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            Text(
                              _tm(itemMap['dosage'] ?? ''),
                              style: GoogleFonts.inter(
                                  fontSize: 11,
                                  fontWeight: FontWeight.bold,
                                  color: const Color(0xFF0284C7),
                                ),
                            ),
                            Text(
                              _tm(itemMap['frequency'] ?? ''),
                              style: GoogleFonts.inter(fontSize: 9.5, color: const Color(0xFF64748B)),
                            ),
                          ],
                        )
                      ],
                    ),
                  );
                }).toList(),

                const SizedBox(height: 14),

                // Button to view full Rx Sheet
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: () => _showPrescriptionModal(context, rxData),
                    icon: const Icon(Icons.description_outlined, size: 18),
                    label: Text(
                      _tm('view_prescription_sheet'),
                      style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.bold),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF0284C7),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      elevation: 0,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  void _showPrescriptionModal(BuildContext context, Map<String, dynamic> rx) {
    final rxList = (rx['rxList'] as List<dynamic>?) ?? [];
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        padding: const EdgeInsets.all(20),
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: const Color(0xFFCBD5E1),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      Text(_tm('rx'), style: GoogleFonts.outfit(fontSize: 26, fontWeight: FontWeight.w900, color: const Color(0xFF0284C7))),
                      const SizedBox(width: 10),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(_tm(rx['doctorName'] ?? ''), style: GoogleFonts.inter(fontSize: 16, fontWeight: FontWeight.bold, color: const Color(0xFF0F172A))),
                          Text(_tm(rx['qualification'] ?? ''), style: GoogleFonts.inter(fontSize: 11, color: const Color(0xFF64748B))),
                        ],
                      ),
                    ],
                  ),
                  Row(
                    children: [
                      if (rx['pdfUrl'] != null && rx['pdfUrl'].toString().isNotEmpty)
                        IconButton(
                          icon: const Icon(Icons.download_rounded, color: Color(0xFF0284C7)),
                          tooltip: 'Download PDF',
                          onPressed: () async {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(content: Text('Downloading prescription PDF...')),
                            );
                            try {
                              await downloadPdfFromUrl(
                                rx['pdfUrl'],
                                'prescription_${rx['prescriptionId'] ?? 'doc'}.pdf',
                              );
                            } catch (e) {
                              if (!context.mounted) return;
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(content: Text('Error downloading PDF: $e'), backgroundColor: Colors.red),
                              );
                            }
                          },
                        ),
                      IconButton(
                        onPressed: () => Navigator.pop(context),
                        icon: const Icon(Icons.close_rounded),
                      ),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Text(_tm(rx['hospitalName'] ?? ''), style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w600, color: const Color(0xFF0F766E))),
              Text(_t('date') + ': ${rx['date'] ?? ''}', style: GoogleFonts.inter(fontSize: 11, color: const Color(0xFF64748B))),
              const Divider(height: 24, color: Color(0xFFE2E8F0)),
              Text(_tm('clinical_diagnosis') + ':', style: GoogleFonts.inter(fontSize: 10, fontWeight: FontWeight.w800, color: const Color(0xFF0369A1), letterSpacing: 0.5)),
              const SizedBox(height: 4),
              Text(_tm(rx['diagnosis'] ?? 'N/A'), style: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.bold, color: const Color(0xFF0F172A))),
              const SizedBox(height: 16),
              Text(_tm('prescribed_medicines') + ':', style: GoogleFonts.inter(fontSize: 10, fontWeight: FontWeight.w800, color: const Color(0xFF64748B), letterSpacing: 0.5)),
              const SizedBox(height: 8),
              ...rxList.map((item) {
                final itemMap = Map<String, dynamic>.from(item as Map);
                return Container(
                  margin: const EdgeInsets.only(bottom: 8),
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF8FAFC),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: const Color(0xFFE2E8F0)),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(_tm(itemMap['medicineName'] ?? ''), style: GoogleFonts.inter(fontSize: 12.5, fontWeight: FontWeight.bold, color: const Color(0xFF0F172A))),
                            if (itemMap['instructions'] != null)
                              Text(_tm(itemMap['instructions']), style: GoogleFonts.inter(fontSize: 10.5, color: const Color(0xFF64748B))),
                          ],
                        ),
                      ),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Text(_tm(itemMap['dosage'] ?? ''), style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.bold, color: const Color(0xFF0284C7))),
                          Text(_tm(itemMap['frequency'] ?? ''), style: GoogleFonts.inter(fontSize: 10, color: const Color(0xFF64748B))),
                        ],
                      )
                    ],
                  ),
                );
              }).toList(),
              if (rx['doctorNotes'] != null) ...[
                const SizedBox(height: 12),
                Text(_tm('doctor_notes_caps') + ':', style: GoogleFonts.inter(fontSize: 10, fontWeight: FontWeight.w800, color: const Color(0xFFB45309), letterSpacing: 0.5)),
                const SizedBox(height: 4),
                Text(_tm(rx['doctorNotes']), style: GoogleFonts.inter(fontSize: 12, color: const Color(0xFF334155))),
              ],
              const SizedBox(height: 20),
            ],
          ),
        ),
      ),
    );
  }

  // Allergy Badge builder - nice red style
  Widget _buildAllergyPill(String name) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(100),
        border: Border.all(color: const Color(0xFFFDA4AF)),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFFE11D48).withOpacity(0.04),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.circle, color: Color(0xFFE11D48), size: 6),
          const SizedBox(width: 6),
          Text(
            _tm(name),
            style: GoogleFonts.inter(
              color: const Color(0xFF9F1239),
              fontWeight: FontWeight.bold,
              fontSize: 11,
            ),
          ),
        ],
      ),
    );
  }

  // Accordion Tile builder with Accent strip
  Widget _buildAccordionTile({
    required String title,
    required IconData icon,
    required Color accentColor,
    required bool isExpanded,
    required VoidCallback onToggle,
    required Widget content,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.02),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Accent color side strip
              Container(
                width: 6,
                color: accentColor,
              ),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // Header Row
                    InkWell(
                      onTap: onToggle,
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 14.0, vertical: 14.0),
                        child: Row(
                          children: [
                            Icon(icon, color: accentColor, size: 20),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Text(
                                title,
                                style: GoogleFonts.inter(
                                  fontSize: 14,
                                  fontWeight: FontWeight.bold,
                                  color: const Color(0xFF0F172A),
                                ),
                              ),
                            ),
                            Icon(
                              isExpanded ? Icons.keyboard_arrow_up_rounded : Icons.keyboard_arrow_down_rounded,
                              color: const Color(0xFF64748B),
                              size: 20,
                            ),
                          ],
                        ),
                      ),
                    ),
                    if (isExpanded) ...[
                      const Divider(height: 1, color: Color(0xFFF1F5F9)),
                      content,
                    ]
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // Medication row builder
  Widget _buildMedicationRow(String name, String dosage, String timing) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      child: Row(
        children: [
          const Icon(Icons.circle, color: Color(0xFF0F766E), size: 6),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              name,
              style: GoogleFonts.inter(
                fontSize: 13,
                fontWeight: FontWeight.w700,
                color: const Color(0xFF1E293B),
              ),
            ),
          ),
          const SizedBox(width: 6),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
            decoration: BoxDecoration(
              color: const Color(0xFFE0F2FE),
              borderRadius: BorderRadius.circular(6),
            ),
            child: Text(
              dosage,
              style: GoogleFonts.inter(
                color: const Color(0xFF0369A1),
                fontWeight: FontWeight.bold,
                fontSize: 10.5,
              ),
            ),
          ),
          const SizedBox(width: 12),
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.access_time_rounded, size: 12, color: Color(0xFF64748B)),
              const SizedBox(width: 4),
              Text(
                timing,
                style: GoogleFonts.inter(
                  fontSize: 11.5,
                  color: const Color(0xFF64748B),
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // Condition row builder
  Widget _buildConditionRow(String name, String status, Color statusColor) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            children: [
              Icon(Icons.lens, color: statusColor.withOpacity(0.2), size: 12),
              const SizedBox(width: 8),
              Text(
                name,
                style: GoogleFonts.inter(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: const Color(0xFF1E293B),
                ),
              ),
            ],
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
            decoration: BoxDecoration(
              color: statusColor.withOpacity(0.1),
              borderRadius: BorderRadius.circular(6),
            ),
            child: Text(
              status,
              style: GoogleFonts.inter(
                fontSize: 11,
                fontWeight: FontWeight.w800,
                color: statusColor,
              ),
            ),
          ),
        ],
      ),
    );
  }

  // Contact row builder with safe layout
  Widget _buildContactRow(String name, String relation, String phone) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  children: [
                    const Icon(Icons.person_outline_rounded, color: Color(0xFF64748B), size: 14),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        '$name ($relation)',
                        style: GoogleFonts.inter(
                          fontSize: 13,
                          fontWeight: FontWeight.bold,
                          color: const Color(0xFF1E293B),
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 3),
                Padding(
                  padding: const EdgeInsets.only(left: 20.0),
                  child: Text(
                    phone,
                    style: GoogleFonts.inter(
                      fontSize: 12,
                      color: const Color(0xFF64748B),
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          OutlinedButton.icon(
            onPressed: () {},
            icon: const Icon(Icons.phone_enabled_rounded, size: 12, color: Color(0xFF16A34A)),
            label: Text(
              _t('call').toUpperCase(),
              style: GoogleFonts.inter(
                fontSize: 11,
                fontWeight: FontWeight.w800,
                color: const Color(0xFF16A34A),
              ),
            ),
            style: OutlinedButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              side: const BorderSide(color: Color(0xFF86EFAC), width: 1.5),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              backgroundColor: const Color(0xFFF0FDF4),
            ),
          ),
        ],
      ),
    );
  }
}
