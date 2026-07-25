import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../../providers/swasthya_tap_provider.dart';
import '../../theme/app_theme.dart';
import '../../widgets/glass_card.dart';
import '../../models/models.dart';
import 'declare_blood_emergency.dart';
import 'emergency_blood_map.dart';
import '../../services/api_service.dart';
import '../onboarding_screen.dart';
import '../../utils/translation_service.dart';

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

  void _searchPatient(SwasthyaTapProvider provider) {
    final slug = _searchController.text.trim().toLowerCase();
    if (slug.isEmpty) return;
    try {
      final profile = provider.profiles.firstWhere((p) => p.id.toLowerCase() == slug);
      setState(() { _searchedProfile = profile; _hasSearched = true; _organConsentVerified = false; });
    } catch (_) {
      setState(() { _searchedProfile = null; _hasSearched = true; });
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

            // Results
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
}
