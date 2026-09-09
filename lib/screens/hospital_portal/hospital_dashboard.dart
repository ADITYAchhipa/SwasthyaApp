import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../../providers/swasthya_tap_provider.dart';
import '../../theme/app_theme.dart';
import '../../widgets/glass_card.dart';
import '../../models/models.dart';
import 'declare_blood_emergency.dart';
import 'emergency_blood_map.dart';
import 'nfc_writer_screen.dart';
import 'add_prescription_screen.dart';
import 'upload_report_screen.dart';
import '../../services/api_service.dart';
import '../onboarding_screen.dart';
import '../../utils/translation_service.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../services/medical_data_gateway.dart';
import '../../services/offline_mesh/offline_mesh_manager.dart';
import '../../widgets/offline_relay_progress.dart';
import '../settings/mesh_settings_tile.dart';

class HospitalDashboard extends StatefulWidget {
  const HospitalDashboard({Key? key}) : super(key: key);

  @override
  _HospitalDashboardState createState() => _HospitalDashboardState();
}

class _HospitalDashboardState extends State<HospitalDashboard> {
  String _t(String key) => TranslationService.t(context, key);

  final _searchController = TextEditingController();
  MedicalProfile? _searchedProfile;
  bool _hasSearched = false;
  bool _isVerifyingOrganConsent = false;
  bool _organConsentVerified = false;

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  bool _isLoadingPatient = false;

  void _searchPatient(SwasthyaTapProvider provider) async {
    final slug = _searchController.text.trim().toLowerCase();
    if (slug.isEmpty) return;

    setState(() {
      _isLoadingPatient = true;
      _hasSearched = false;
      _searchedProfile = null;
    });

    try {
      final uiStateNotifier = ValueNotifier<MeshUiState>(MeshUiState.searching);
      bool isSheetShown = false;

      final result = await MedicalDataGateway.fetchCitizen(
        slug,
        onProgress: (state) {
          uiStateNotifier.value = state;
          if (!isSheetShown && state != MeshUiState.received && state != MeshUiState.failed) {
            isSheetShown = true;
            showMeshProgressSheet(context, uiStateNotifier);
          }
        },
      );

      final profile = result.profile;
      if (profile != null) {
        // Also update local cache in provider if present
        final idx = provider.profiles.indexWhere((p) => p.id == profile.id);
        if (idx != -1) {
          provider.profiles[idx] = profile;
        } else {
          provider.profiles.add(profile);
        }
        setState(() {
          _searchedProfile = profile;
          _hasSearched = true;
          _organConsentVerified = false;
          _isLoadingPatient = false;
        });
        return;
      }
    } catch (e) {
      debugPrint('Error fetching patient from backend: $e');
    }

    // Local fallback
    try {
      final profile = provider.profiles.firstWhere((p) => p.id.toLowerCase() == slug);
      setState(() {
        _searchedProfile = profile;
        _hasSearched = true;
        _organConsentVerified = false;
        _isLoadingPatient = false;
      });
    } catch (_) {
      setState(() {
        _searchedProfile = null;
        _hasSearched = true;
        _isLoadingPatient = false;
      });
    }
  }

  void _verifyOrganConsent(SwasthyaTapProvider provider, String hash) async {
    setState(() { _isVerifyingOrganConsent = true; });
    final verified = await provider.verifyOrganConsentWithNOTTO(hash);
    setState(() { _isVerifyingOrganConsent = false; _organConsentVerified = verified; });
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(
        verified ? 'NOTTO Registry matches hash. Legal consent approved.' : 'Verification failed — hash mismatch.',
        style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
      ),
      backgroundColor: verified ? AppTheme.accentGreen : AppTheme.accentRed,
      behavior: SnackBarBehavior.floating,
    ));
  }

  @override
  Widget build(BuildContext context) {
    final provider = Provider.of<SwasthyaTapProvider>(context);

    return Scaffold(
      backgroundColor: AppTheme.lightBg,
      appBar: AppBar(
        title: Text(_t('hospital_er_portal')),
        leading: IconButton(
          icon: const Icon(Icons.logout_rounded, color: AppTheme.accentRed),
          tooltip: 'Sign Out',
          onPressed: () async {
            final confirmed = await showDialog<bool>(
              context: context,
              builder: (ctx) => AlertDialog(
                title: const Text('Sign Out'),
                content: const Text('Are you sure you want to sign out from the hospital portal?'),
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
              ApiService.clearToken();
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
        ),
        actions: [
          // Mesh Settings button
          IconButton(
            icon: const Icon(Icons.settings_outlined, color: AppTheme.accentTeal),
            tooltip: 'Mesh Settings',
            onPressed: () {
              showDialog(
                context: context,
                builder: (ctx) => AlertDialog(
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  title: const Text("Mesh Settings"),
                  content: const SizedBox(
                    width: 300,
                    child: MeshSettingsTile(),
                  ),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.pop(ctx),
                      child: const Text("Close"),
                    ),
                  ],
                ),
              );
            },
          ),
          // NFC Writer button
          IconButton(
            icon: const Icon(Icons.nfc_rounded, color: AppTheme.accentTeal),
            tooltip: 'NFC Card Writer',
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => NfcWriterScreen(
                  prefillSwasthyaId: _searchedProfile?.id,
                ),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.only(right: 12),
            child: ElevatedButton.icon(
              onPressed: () => Navigator.push(
                  context, MaterialPageRoute(builder: (_) => const DeclareBloodEmergencyScreen())),
              icon: const Icon(Icons.add_rounded, size: 16, color: Colors.white),
              label: Text(_t('declare_alert'), style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.white)),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.accentRed,
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                elevation: 0,
              ),
            ),
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Search section
            Text(_t('patient_lookup'), style: Theme.of(context).textTheme.titleLarge?.copyWith(fontSize: 16, fontWeight: FontWeight.bold)),
            const SizedBox(height: 4),
            Text(_t('scan_or_enter_code'),
                style: const TextStyle(color: AppTheme.textSecondary, fontSize: 12)),
            const SizedBox(height: 12),
            _searchBox(provider),
            const SizedBox(height: 20),

            // Clinical Operations Shortcuts
            Text(
              'Clinical Operations', 
              style: Theme.of(context).textTheme.titleLarge?.copyWith(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 4),
            const Text(
              'Quickly write a prescription or upload a medical report', 
              style: TextStyle(color: AppTheme.textSecondary, fontSize: 12),
            ),
            const SizedBox(height: 12),
            _buildClinicalShortcuts(provider),
            const SizedBox(height: 24),

            // Results
            if (_isLoadingPatient)
              const Center(
                child: Padding(
                  padding: EdgeInsets.symmetric(vertical: 24.0),
                  child: CircularProgressIndicator(color: AppTheme.accentTeal),
                ),
              ),
            if (_hasSearched) ...[
              if (_searchedProfile != null) ...[
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(_t('emergency_record'), style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: AppTheme.accentTeal)),
                    TextButton.icon(
                      onPressed: () => setState(() { _searchedProfile = null; _hasSearched = false; _searchController.clear(); }),
                      icon: const Icon(Icons.close, size: 14, color: AppTheme.accentRed),
                      label: Text(_t('close'), style: const TextStyle(color: AppTheme.accentRed, fontSize: 13)),
                    ),
                  ],
                ).animate().fade(),
                const SizedBox(height: 10),
                _patientRecordCard(provider, _searchedProfile!).animate().fade().slideY(begin: 0.05),
              ] else
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: AppTheme.accentRed.withOpacity(0.06),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: AppTheme.accentRed.withOpacity(0.2)),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.search_off_rounded, color: AppTheme.accentRed, size: 18),
                      const SizedBox(width: 10),
                      Text(_t('no_patient_found'), style: const TextStyle(color: AppTheme.accentRed, fontWeight: FontWeight.w600)),
                    ],
                  ),
                ).animate().fade(),
              const SizedBox(height: 22),
            ],

            // Blood alerts section
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(_t('active_blood_alerts'), style: Theme.of(context).textTheme.titleLarge?.copyWith(fontSize: 16, fontWeight: FontWeight.bold)),
                    Text('${provider.bloodRequests.length} active broadcasts', style: const TextStyle(color: AppTheme.textSecondary, fontSize: 12)),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 12),
            _buildBloodRequests(provider),
          ],
        ),
      ),
    );
  }

  Widget _searchBox(SwasthyaTapProvider provider) {
    return Container(
      decoration: BoxDecoration(
        color: AppTheme.cardBg,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppTheme.borderColor),
        boxShadow: const [BoxShadow(color: Color(0x06000000), blurRadius: 8, offset: Offset(0, 2))],
      ),
      child: Row(
        children: [
          Expanded(
            child: TextField(
              controller: _searchController,
              style: const TextStyle(fontSize: 14, color: AppTheme.textPrimary),
              decoration: const InputDecoration(
                hintText: 'Enter code e.g. x7k9m2',
                hintStyle: TextStyle(color: AppTheme.textSecondary, fontSize: 13),
                border: InputBorder.none,
                contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                prefixIcon: Icon(Icons.search_rounded, color: AppTheme.accentTeal, size: 20),
              ),
              onSubmitted: (_) => _searchPatient(provider),
            ),
          ),
          Padding(
            padding: const EdgeInsets.only(right: 8),
            child: ElevatedButton(
              onPressed: () => _searchPatient(provider),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.accentTeal,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                elevation: 0,
              ),
              child: Text(_t('search'), style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
            ),
          ),
        ],
      ),
    );
  }

  Widget _patientRecordCard(SwasthyaTapProvider provider, MedicalProfile profile) {
    final isDnr = profile.isDnr;
    final hasOrganPledge = profile.organPledge != null;

    return GlassCard(
      borderColor: isDnr ? AppTheme.accentRed.withOpacity(0.3) : AppTheme.borderColor,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(profile.fullName, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: AppTheme.textPrimary)),
                    Text('swasthyatap.in/${profile.id}', style: const TextStyle(color: AppTheme.textSecondary, fontSize: 12)),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                decoration: BoxDecoration(
                  color: AppTheme.accentRed,
                  borderRadius: BorderRadius.circular(12),
                  boxShadow: [BoxShadow(color: AppTheme.accentRed.withOpacity(0.3), blurRadius: 10)],
                ),
                child: Text(profile.bloodGroup, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 22)),
              ),
            ],
          ),

          // DNR Banner
          if (isDnr) ...[
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: AppTheme.accentRed.withOpacity(0.07),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: AppTheme.accentRed.withOpacity(0.25)),
              ),
              child: const Row(
                children: [
                  Icon(Icons.gavel_rounded, color: AppTheme.accentRed, size: 16),
                  SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'DO NOT RESUSCITATE — Do not perform CPR or intubation.',
                      style: TextStyle(color: AppTheme.accentRed, fontSize: 11, fontWeight: FontWeight.bold),
                    ),
                  ),
                ],
              ),
            ),
          ],

          const Divider(height: 24),
          _detailRow(Icons.warning_amber_rounded, 'Allergies', profile.allergies, AppTheme.accentRed),
          _detailRow(Icons.medication_outlined, 'Medications', profile.medications, AppTheme.accentAmber),
          _detailRow(Icons.notes_rounded, 'Special Instructions', profile.specialInstructions, AppTheme.textPrimary),

          const Divider(height: 24),
          const Text('Emergency Contacts', style: TextStyle(fontWeight: FontWeight.bold, color: AppTheme.accentTeal, fontSize: 13)),
          const SizedBox(height: 8),
          ...profile.emergencyContacts.map((c) => Padding(
            padding: const EdgeInsets.symmetric(vertical: 4),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('${c.name} (${c.relation})', style: const TextStyle(fontSize: 13, color: AppTheme.textPrimary)),
                Text(c.phone, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: AppTheme.accentTeal)),
              ],
            ),
          )).toList(),

          if (hasOrganPledge) ...[
            const Divider(height: 24),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('Organ Donor Pledge Found', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: AppTheme.accentGreen)),
                      Text('Organs: ${profile.organPledge!.pledgedOrgans.join(", ")}',
                          style: const TextStyle(color: AppTheme.textSecondary, fontSize: 11)),
                    ],
                  ),
                ),
                if (!_organConsentVerified)
                  ElevatedButton(
                    onPressed: _isVerifyingOrganConsent ? null : () => _verifyOrganConsent(provider, profile.organPledge!.signatureHash),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppTheme.accentGreen,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                      elevation: 0,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                    ),
                    child: _isVerifyingOrganConsent
                        ? const SizedBox(width: 14, height: 14, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 1.5))
                        : const Text('Verify', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                  )
                else
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                    decoration: BoxDecoration(
                      color: AppTheme.accentGreen.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: AppTheme.accentGreen.withOpacity(0.3)),
                    ),
                    child: const Row(
                      children: [
                        Icon(Icons.verified_rounded, size: 13, color: AppTheme.accentGreen),
                        SizedBox(width: 4),
                        Text('VERIFIED', style: TextStyle(color: AppTheme.accentGreen, fontSize: 10, fontWeight: FontWeight.bold)),
                      ],
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(color: AppTheme.surfaceColor, borderRadius: BorderRadius.circular(8), border: Border.all(color: AppTheme.borderColor)),
              child: Text(
                'Hash: ${profile.organPledge!.signatureHash}',
                style: const TextStyle(fontFamily: 'monospace', fontSize: 9, color: AppTheme.textSecondary),
              ),
            ),
          ],
          
          // ── Clinical Actions ────────────────────────────────────────
          const Divider(height: 24),
          const Text('Clinical Actions', style: TextStyle(fontWeight: FontWeight.bold, color: AppTheme.accentTeal, fontSize: 13)),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: () => Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => AddPrescriptionScreen(
                        profile: profile,
                        onProfileUpdated: (updatedProfile) {
                          setState(() {
                            _searchedProfile = updatedProfile;
                          });
                        },
                      ),
                    ),
                  ),
                  icon: const Icon(Icons.note_add_rounded, size: 16, color: Colors.white),
                  label: const Text(
                    'Add Prescription',
                    style: TextStyle(fontWeight: FontWeight.bold, color: Colors.white, fontSize: 11),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.accentTeal,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    elevation: 0,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: () => Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => UploadReportScreen(
                        profile: profile,
                        onProfileUpdated: (updatedProfile) {
                          setState(() {
                            _searchedProfile = updatedProfile;
                          });
                        },
                      ),
                    ),
                  ),
                  icon: const Icon(Icons.upload_file_rounded, size: 16, color: Colors.white),
                  label: const Text(
                    'Upload Report',
                    style: TextStyle(fontWeight: FontWeight.bold, color: Colors.white, fontSize: 11),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.accentAmber,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    elevation: 0,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                ),
              ),
            ],
          ),
          
          // ── NFC Card Writer CTA ──────────────────────────────────────
          const Divider(height: 24),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: () => Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => NfcWriterScreen(
                    prefillSwasthyaId: profile.id,
                  ),
                ),
              ),
              icon: const Icon(Icons.nfc_rounded, size: 16, color: Colors.white),
              label: const Text(
                'Write NFC Card for This Patient',
                style: TextStyle(fontWeight: FontWeight.bold, color: Colors.white, fontSize: 13),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.accentTeal.withOpacity(0.15),
                foregroundColor: AppTheme.accentTeal,
                padding: const EdgeInsets.symmetric(vertical: 12),
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                  side: const BorderSide(color: AppTheme.accentTeal, width: 1.5),
                ),
              ),
            ),
          ),
        ],
      ),
    );

  }

  Widget _detailRow(IconData icon, String title, String value, Color valueColor) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(6),
            decoration: BoxDecoration(color: valueColor.withOpacity(0.08), borderRadius: BorderRadius.circular(7)),
            child: Icon(icon, color: valueColor, size: 14),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: const TextStyle(color: AppTheme.textSecondary, fontSize: 11)),
                Text(value.isEmpty ? 'None' : value,
                    style: TextStyle(color: valueColor, fontSize: 13, fontWeight: FontWeight.w500)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBloodRequests(SwasthyaTapProvider provider) {
    final requests = provider.bloodRequests;
    if (requests.isEmpty) {
      return Container(
        padding: const EdgeInsets.symmetric(vertical: 40),
        alignment: Alignment.center,
        child: Column(
          children: [
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(color: AppTheme.surfaceColor, shape: BoxShape.circle),
              child: const Icon(Icons.bloodtype_outlined, size: 36, color: AppTheme.textSecondary),
            ),
            const SizedBox(height: 14),
            const Text('No active blood shortages', style: TextStyle(color: AppTheme.textPrimary, fontWeight: FontWeight.bold)),
            const SizedBox(height: 4),
            const Text('Tap "Declare Alert" to simulate a real-time shortage',
                style: TextStyle(color: AppTheme.textSecondary, fontSize: 12)),
          ],
        ),
      );
    }

    return ListView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: requests.length,
      itemBuilder: (context, index) {
        final req = requests[index];
        final total = req.responses.length;
        final accepted = req.responses.where((r) => r.status == DonorResponseStatus.accepted).length;
        final pending = req.responses.where((r) => r.status == DonorResponseStatus.pending).length;
        final fraction = total > 0 ? accepted / total : 0.0;

        return GestureDetector(
          onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => EmergencyBloodMapScreen(request: req))),
          child: Container(
            margin: const EdgeInsets.only(bottom: 12),
            decoration: BoxDecoration(
              color: AppTheme.cardBg,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: AppTheme.borderColor),
              boxShadow: const [BoxShadow(color: Color(0x07000000), blurRadius: 8, offset: Offset(0, 2))],
            ),
            child: Column(
              children: [
                // Top red strip
                Container(
                  height: 3,
                  decoration: BoxDecoration(
                    gradient: AppTheme.redGradient,
                    borderRadius: const BorderRadius.only(topLeft: Radius.circular(16), topRight: Radius.circular(16)),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.all(14),
                  child: Column(
                    children: [
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(color: AppTheme.accentRed.withOpacity(0.08), shape: BoxShape.circle),
                            child: const Icon(Icons.local_hospital_rounded, color: AppTheme.accentRed, size: 16),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(req.hospitalName, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: AppTheme.textPrimary)),
                                Text(req.hospitalAddress, style: const TextStyle(color: AppTheme.textSecondary, fontSize: 11), maxLines: 1, overflow: TextOverflow.ellipsis),
                              ],
                            ),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                            decoration: BoxDecoration(
                              color: AppTheme.accentRed,
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Text(req.bloodGroup, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 18)),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text('$accepted / $total donors accepted', style: const TextStyle(color: AppTheme.textSecondary, fontSize: 11)),
                          if (pending > 0)
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                              decoration: BoxDecoration(color: AppTheme.accentAmber.withOpacity(0.1), borderRadius: BorderRadius.circular(4), border: Border.all(color: AppTheme.accentAmber.withOpacity(0.3))),
                              child: Text('$pending Pending', style: const TextStyle(color: AppTheme.accentAmber, fontSize: 9, fontWeight: FontWeight.bold)),
                            ),
                        ],
                      ),
                      const SizedBox(height: 5),
                      ClipRRect(
                        borderRadius: BorderRadius.circular(4),
                        child: LinearProgressIndicator(
                          value: fraction, backgroundColor: AppTheme.surfaceColor, color: AppTheme.accentTeal, minHeight: 5,
                        ),
                      ),
                      const SizedBox(height: 10),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Row(children: [
                            const Icon(Icons.radar_rounded, size: 13, color: AppTheme.textSecondary),
                            const SizedBox(width: 4),
                            Text('${req.radiusKm.toStringAsFixed(1)} km radius', style: const TextStyle(color: AppTheme.textSecondary, fontSize: 11)),
                          ]),
                          Row(children: [
                            Text(_t('view_radar_map'), style: const TextStyle(color: AppTheme.accentTeal, fontWeight: FontWeight.bold, fontSize: 12)),
                            const SizedBox(width: 3),
                            const Icon(Icons.arrow_forward_ios, size: 10, color: AppTheme.accentTeal),
                          ]),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ).animate().fade(delay: (index * 80).ms).slideY(begin: 0.05);
      },
    );
  }

  Widget _buildClinicalShortcuts(SwasthyaTapProvider provider) {
    return Row(
      children: [
        Expanded(
          child: GestureDetector(
            onTap: () => _promptSwasthyaIdAndNavigate(provider, true),
            child: Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: AppTheme.borderColor),
                boxShadow: const [BoxShadow(color: Color(0x05000000), blurRadius: 4, offset: Offset(0, 2))],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: AppTheme.accentTeal.withOpacity(0.08),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.note_add_rounded, color: AppTheme.accentTeal, size: 24),
                  ),
                  const SizedBox(height: 12),
                  const Text(
                    'Add Prescription',
                    style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: AppTheme.textPrimary),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    _searchedProfile != null 
                        ? 'For ${_searchedProfile!.fullName}'
                        : 'Select or write prescription details',
                    style: const TextStyle(fontSize: 11, color: AppTheme.textSecondary),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: GestureDetector(
            onTap: () => _promptSwasthyaIdAndNavigate(provider, false),
            child: Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: AppTheme.borderColor),
                boxShadow: const [BoxShadow(color: Color(0x05000000), blurRadius: 4, offset: Offset(0, 2))],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: AppTheme.accentAmber.withOpacity(0.08),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.upload_file_rounded, color: AppTheme.accentAmber, size: 24),
                  ),
                  const SizedBox(height: 12),
                  const Text(
                    'Upload Report',
                    style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: AppTheme.textPrimary),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    _searchedProfile != null 
                        ? 'For ${_searchedProfile!.fullName}'
                        : 'Upload patient blood/imaging scans',
                    style: const TextStyle(fontSize: 11, color: AppTheme.textSecondary),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }

  void _promptSwasthyaIdAndNavigate(SwasthyaTapProvider provider, bool isPrescription) {
    if (_searchedProfile != null) {
      _navigateToScreen(_searchedProfile!, isPrescription);
      return;
    }

    final idController = TextEditingController();
    bool isSearching = false;
    String? errorMessage;

    showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              backgroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              title: Text(
                'Enter Swasthya ID',
                style: GoogleFonts.poppins(fontSize: 18, fontWeight: FontWeight.bold, color: const Color(0xFF0F172A)),
              ),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Please enter the patient\'s 6-digit Swasthya ID to retrieve their medical record.',
                    style: GoogleFonts.inter(fontSize: 12, color: const Color(0xFF64748B)),
                  ),
                  const SizedBox(height: 14),
                  TextField(
                    controller: idController,
                    style: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.bold, color: const Color(0xFF0F172A)),
                    decoration: InputDecoration(
                      hintText: 'e.g. x7k9m2',
                      hintStyle: GoogleFonts.inter(fontSize: 13, color: const Color(0xFF94A3B8)),
                      fillColor: const Color(0xFFF8FAFC),
                      filled: true,
                      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: const BorderSide(color: Color(0xFF0F766E), width: 1.5),
                      ),
                    ),
                  ),
                  if (errorMessage != null) ...[
                    const SizedBox(height: 8),
                    Text(
                      errorMessage!,
                      style: GoogleFonts.inter(fontSize: 11, color: const Color(0xFFF43F5E), fontWeight: FontWeight.bold),
                    ),
                  ],
                  if (isSearching) ...[
                    const SizedBox(height: 14),
                    const Center(
                      child: SizedBox(
                        width: 24,
                        height: 24,
                        child: CircularProgressIndicator(color: AppTheme.accentTeal, strokeWidth: 2),
                      ),
                    ),
                  ],
                ],
              ),
              actions: [
                TextButton(
                  onPressed: isSearching ? null : () => Navigator.pop(context),
                  child: Text(
                    'Cancel',
                    style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.bold, color: const Color(0xFF64748B)),
                  ),
                ),
                ElevatedButton(
                  onPressed: isSearching
                      ? null
                      : () async {
                          final slug = idController.text.trim().toLowerCase();
                          if (slug.isEmpty) return;

                          setDialogState(() {
                            isSearching = true;
                            errorMessage = null;
                          });

                          try {
                             // 1. Fetch from backend
                             final uiStateNotifier = ValueNotifier<MeshUiState>(MeshUiState.searching);
                             bool isSheetShown = false;

                             final result = await MedicalDataGateway.fetchCitizen(
                               slug,
                               onProgress: (state) {
                                 uiStateNotifier.value = state;
                                 if (!isSheetShown && state != MeshUiState.received && state != MeshUiState.failed) {
                                   isSheetShown = true;
                                   showMeshProgressSheet(context, uiStateNotifier);
                                 }
                               },
                             );

                             final profile = result.profile;
                             if (profile != null) {
                               // Cache in provider
                               final idx = provider.profiles.indexWhere((p) => p.id == profile.id);
                               if (idx != -1) {
                                 provider.profiles[idx] = profile;
                               } else {
                                 provider.profiles.add(profile);
                               }

                               if (context.mounted) {
                                 Navigator.pop(context); // Close dialog
                                 _navigateToScreen(profile, isPrescription);
                               }
                               return;
                             }
                           } catch (e) {
                             debugPrint('Error loading patient: $e');
                           }

                          // 2. Local Fallback
                          try {
                            final profile = provider.profiles.firstWhere((p) => p.id.toLowerCase() == slug);
                            if (context.mounted) {
                              Navigator.pop(context); // Close dialog
                              _navigateToScreen(profile, isPrescription);
                            }
                          } catch (_) {
                            setDialogState(() {
                              isSearching = false;
                              errorMessage = 'Patient profile not found. Please verify the ID.';
                            });
                          }
                        },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF0F766E),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    elevation: 0,
                  ),
                  child: Text(
                    'Retrieve',
                    style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.bold, color: Colors.white),
                  ),
                ),
              ],
            );
          },
        );
      },
    );
  }

  void _navigateToScreen(MedicalProfile profile, bool isPrescription) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => isPrescription
            ? AddPrescriptionScreen(
                profile: profile,
                onProfileUpdated: (updatedProfile) {
                  setState(() {
                    if (_searchedProfile != null && _searchedProfile!.id == updatedProfile.id) {
                      _searchedProfile = updatedProfile;
                    }
                  });
                },
              )
            : UploadReportScreen(
                profile: profile,
                onProfileUpdated: (updatedProfile) {
                  setState(() {
                    if (_searchedProfile != null && _searchedProfile!.id == updatedProfile.id) {
                      _searchedProfile = updatedProfile;
                    }
                  });
                },
              ),
      ),
    );
  }
}
