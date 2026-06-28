import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../../providers/swasthya_tap_provider.dart';
import '../../theme/app_theme.dart';
import '../../widgets/glass_card.dart';
import '../../models/models.dart';

class NfcSimulatorScreen extends StatefulWidget {
  const NfcSimulatorScreen({Key? key}) : super(key: key);

  @override
  _NfcSimulatorScreenState createState() => _NfcSimulatorScreenState();
}

class _NfcSimulatorScreenState extends State<NfcSimulatorScreen> with SingleTickerProviderStateMixin {
  String _selectedProfileId = 'x7k9m2';
  bool _isTapping = false;
  bool _hasTapped = false;
  bool _showSuccessAlert = false;
  bool _isWriting = false;
  bool _hasWritten = false;

  late AnimationController _pulseController;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    );
  }

  @override
  void dispose() {
    _pulseController.dispose();
    super.dispose();
  }

  void _triggerTap(SwasthyaTapProvider provider) async {
    if (_isTapping) return;
    setState(() {
      _isTapping = true;
      _hasTapped = false;
      _showSuccessAlert = false;
    });
    
    _pulseController.repeat();

    // Find the profile we want to simulate tapping
    final targetProfile = provider.profiles.firstWhere((p) => p.id == _selectedProfileId);
    final ndefPayload = targetProfile.toNdefPayload();

    // Animate tap
    await Future.delayed(const Duration(milliseconds: 1200));

    if (!mounted) return;

    provider.simulateNfcTap(ndefPayload, provider.isInternetAvailable);
    
    setState(() {
      _isTapping = false;
      _hasTapped = true;
      _showSuccessAlert = true;
      _pulseController.stop();
    });

    // Reset the success alert bounce after 2 seconds
    await Future.delayed(const Duration(seconds: 3));
    if (mounted) {
      setState(() {
        _showSuccessAlert = false;
      });
    }
  }

  void _triggerWrite(SwasthyaTapProvider provider) async {
    if (_isWriting) return;
    setState(() {
      _isWriting = true;
      _hasWritten = false;
    });

    await Future.delayed(const Duration(seconds: 2));

    if (!mounted) return;

    setState(() {
      _isWriting = false;
      _hasWritten = true;
    });

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(Icons.check_circle, color: Colors.black),
            const SizedBox(width: 8),
            Text(
              'Successfully wrote encrypted NDEF data to NFC Tag! (Size: ${(provider.currentCitizen.toNdefPayload().length)} bytes)',
              style: const TextStyle(color: Colors.black, fontWeight: FontWeight.bold),
            ),
          ],
        ),
        backgroundColor: AppTheme.accentTeal,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final provider = Provider.of<SwasthyaTapProvider>(context);
    final targetProfile = provider.profiles.firstWhere((p) => p.id == _selectedProfileId);
    final scannedProfile = provider.scannedProfile;
    final isOffline = provider.scannedOfflineOnly;

    return Scaffold(
      appBar: AppBar(
        title: const Text('NFC Sandbox Simulator'),
        backgroundColor: Colors.transparent,
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () {
              provider.clearScannedData();
              setState(() {
                _hasTapped = false;
                _hasWritten = false;
              });
            },
            tooltip: 'Reset NFC State',
          )
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Virtual Hardware Playground',
              style: Theme.of(context).textTheme.displayMedium?.copyWith(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                  ),
            ),
            const Text(
              'Test the NFC sensor workflow by tapping mock active cards against a simulated phone reader.',
              style: TextStyle(color: AppTheme.textSecondary, fontSize: 13),
            ),
            const SizedBox(height: 20),

            // Top Simulator settings selector
            GlassCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    '1. Choose Card to Tap/Write',
                    style: TextStyle(fontWeight: FontWeight.bold, color: AppTheme.accentTeal),
                  ),
                  const SizedBox(height: 12),
                  DropdownButtonFormField<String>(
                    value: _selectedProfileId,
                    dropdownColor: AppTheme.cardBg,
                    decoration: AppTheme.premiumInputDecoration(
                      label: 'Choose Card Profile',
                      icon: Icons.contactless,
                    ),
                    items: provider.profiles.map((p) {
                      return DropdownMenuItem<String>(
                        value: p.id,
                        child: Text('${p.fullName} (${p.bloodGroup}) - ID: ${p.id}'),
                      );
                    }).toList(),
                    onChanged: (val) {
                      if (val != null) {
                        setState(() {
                          _selectedProfileId = val;
                          _hasTapped = false;
                        });
                      }
                    },
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),

            // Middle: Interactive Simulator Animation Canvas
            _buildInteractiveCanvas(provider),
            const SizedBox(height: 24),

            // Bottom: NFC Scanning Results Rendering
            if (_hasTapped && scannedProfile != null) ...[
              _buildNfcReadHeader(isOffline),
              const SizedBox(height: 16),
              _buildPatientEmergencyCard(scannedProfile, isOffline),
            ] else if (!_isTapping) ...[
              Center(
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 40.0),
                  child: Column(
                    children: [
                      Icon(Icons.nfc_outlined, size: 64, color: Colors.white24),
                      const SizedBox(height: 12),
                      const Text(
                        'Awaiting NFC Sensor Tap Event...',
                        style: TextStyle(color: AppTheme.textSecondary, fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 4),
                      const Text(
                        'Select a card above and click "Simulate NFC Tap"',
                        style: TextStyle(color: Colors.white24, fontSize: 12),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildInteractiveCanvas(SwasthyaTapProvider provider) {
    return GlassCard(
      height: 260,
      child: Stack(
        alignment: Alignment.center,
        children: [
          // Radial Radar Pulse Rings (simulates NFC field)
          if (_isTapping)
            AnimatedBuilder(
              animation: _pulseController,
              builder: (context, child) {
                return Stack(
                  alignment: Alignment.center,
                  children: [
                    Container(
                      width: 140 * _pulseController.value + 40,
                      height: 140 * _pulseController.value + 40,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: AppTheme.accentTeal.withOpacity(1 - _pulseController.value),
                          width: 2,
                        ),
                      ),
                    ),
                    Container(
                      width: 220 * _pulseController.value + 40,
                      height: 220 * _pulseController.value + 40,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: AppTheme.accentTeal.withOpacity(0.5 * (1 - _pulseController.value)),
                          width: 1.5,
                        ),
                      ),
                    ),
                  ],
                );
              },
            ),

          // Side-by-Side: The Phone and the NFC Tag
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              // Virtual Phone Reader
              Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Container(
                    width: 70,
                    height: 120,
                    decoration: BoxDecoration(
                      color: Colors.black,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.white24, width: 2),
                      boxShadow: [
                        BoxShadow(
                          color: _isTapping ? AppTheme.accentTeal.withOpacity(0.4) : Colors.black45,
                          blurRadius: _isTapping ? 20 : 8,
                        ),
                      ],
                    ),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                      children: [
                        Container(width: 24, height: 4, decoration: BoxDecoration(color: Colors.white24, borderRadius: BorderRadius.circular(2))),
                        const Icon(Icons.contactless_outlined, color: AppTheme.accentTeal, size: 28),
                        Text(
                          provider.isInternetAvailable ? 'ONLINE' : 'OFFLINE',
                          style: TextStyle(
                            fontSize: 8,
                            fontWeight: FontWeight.bold,
                            color: provider.isInternetAvailable ? AppTheme.accentGreen : AppTheme.accentRed,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 8),
                  const Text('Phone Reader', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
                ],
              ),

              // The Tapping/Writing action triggers
              Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  ElevatedButton(
                    onPressed: () => _triggerTap(provider),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppTheme.accentTeal,
                      foregroundColor: Colors.black,
                      elevation: 8,
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    child: _isTapping
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(color: Colors.black, strokeWidth: 2.5),
                          )
                        : const Row(
                            children: [
                              Icon(Icons.nfc, size: 16),
                              SizedBox(width: 8),
                              Text('Simulate NFC Tap', style: TextStyle(fontWeight: FontWeight.bold)),
                            ],
                          ),
                  ),
                  const SizedBox(height: 10),
                  ElevatedButton(
                    onPressed: () => _triggerWrite(provider),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.transparent,
                      foregroundColor: Colors.white,
                      elevation: 0,
                      side: const BorderSide(color: Colors.white24),
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    child: _isWriting
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                          )
                        : const Row(
                            children: [
                              Icon(Icons.edit_note, size: 16),
                              SizedBox(width: 8),
                              Text('Write Profile to Chip'),
                            ],
                          ),
                  ),
                ],
              ),

              // Virtual Card Tag
              Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  // This card moves towards the phone if tapping
                  Transform.translate(
                    offset: Offset(_isTapping ? -45.0 : 0.0, 0.0),
                    child: Container(
                      width: 90,
                      height: 55,
                      decoration: BoxDecoration(
                        gradient: AppTheme.tealGradient,
                        borderRadius: BorderRadius.circular(6),
                        boxShadow: const [BoxShadow(color: Colors.black45, blurRadius: 6)],
                      ),
                      child: Stack(
                        children: [
                          Positioned(
                            top: 8,
                            left: 8,
                            child: Icon(Icons.medical_services_outlined, size: 16, color: Colors.black.withOpacity(0.8)),
                          ),
                          Positioned(
                            bottom: 8,
                            right: 8,
                            child: Icon(Icons.nfc, size: 14, color: Colors.black.withOpacity(0.8)),
                          ),
                          const Center(
                            child: Text(
                              'Swasthya Tap Card',
                              style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold, fontSize: 9),
                            ),
                          )
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),
                  const Text('NFC Smart Card', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
                ],
              ),
            ],
          ),
          
          if (_showSuccessAlert)
            Positioned(
              bottom: 12,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: AppTheme.accentGreen,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: const Row(
                  children: [
                    Icon(Icons.check, size: 14, color: Colors.black),
                    SizedBox(width: 4),
                    Text(
                      'CARD TAP DETECTED',
                      style: TextStyle(color: Colors.black, fontSize: 10, fontWeight: FontWeight.bold, letterSpacing: 0.5),
                    )
                  ],
                ),
              ).animate().shake(duration: 500.ms),
            )
        ],
      ),
    );
  }

  Widget _buildNfcReadHeader(bool isOffline) {
    final alertColor = isOffline ? AppTheme.accentAmber : AppTheme.accentTeal;
    final icon = isOffline ? Icons.warning_amber_rounded : Icons.lock_open;
    final modeTitle = isOffline ? 'PASSIVE OFFLINE NDEF READ' : 'ONLINE SECURE PROFILE LOADED';
    final modeDesc = isOffline
        ? 'Reading 8KB raw chip memory. No internet connection was used.'
        : 'Authenticated tag successfully. Synchronized secure health record.';

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: alertColor.withOpacity(0.12),
        border: Border.all(color: alertColor.withOpacity(0.3)),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Icon(icon, color: alertColor, size: 24),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  modeTitle,
                  style: TextStyle(color: alertColor, fontWeight: FontWeight.bold, fontSize: 13, letterSpacing: 0.5),
                ),
                const SizedBox(height: 2),
                Text(
                  modeDesc,
                  style: const TextStyle(color: AppTheme.textSecondary, fontSize: 11),
                ),
              ],
            ),
          ),
        ],
      ),
    ).animate().fade().slideY(begin: 0.1);
  }

  Widget _buildPatientEmergencyCard(MedicalProfile profile, bool isOffline) {
    final hasOrganPledge = profile.organPledge != null;
    final isDnr = profile.isDnr;

    return GlassCard(
      borderColor: isDnr ? AppTheme.accentRed.withOpacity(0.3) : Colors.white12,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Top row: Name & Blood Group
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Text(
                          profile.fullName,
                          style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
                        ),
                        if (isDnr)
                          Container(
                            margin: const EdgeInsets.only(left: 8),
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: AppTheme.accentRed.withOpacity(0.2),
                              borderRadius: BorderRadius.circular(4),
                              border: Border.all(color: AppTheme.accentRed, width: 0.5),
                            ),
                            child: const Text(
                              'DNR ACTIVE',
                              style: TextStyle(color: AppTheme.accentRed, fontSize: 9, fontWeight: FontWeight.bold),
                            ),
                          ),
                      ],
                    ),
                    Text(
                      'Unique medical code: swasthyatap.in/${profile.id}',
                      style: const TextStyle(color: AppTheme.textSecondary, fontSize: 12),
                    ),
                  ],
                ),
              ),
              // Large Blood Badge
              Container(
                width: 60,
                height: 60,
                decoration: BoxDecoration(
                  gradient: AppTheme.redGradient,
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: AppTheme.accentRed.withOpacity(0.3),
                      blurRadius: 10,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Center(
                  child: Text(
                    profile.bloodGroup,
                    style: const TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                ),
              ),
            ],
          ),
          const Divider(height: 24),

          // Offline Details (Vitals & Critical Warnings)
          _buildDetailRow(Icons.warning_outlined, 'Critical Allergies', profile.allergies, AppTheme.accentRed),
          _buildDetailRow(Icons.medication_outlined, 'Current Medications', profile.medications, AppTheme.accentAmber),
          _buildDetailRow(Icons.notes, 'Special Instructions', profile.specialInstructions, Colors.white),

          const Divider(height: 24),
          
          // Emergency Contacts
          const Text(
            'Emergency Contacts (2 Next of Kin)',
            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: AppTheme.accentTeal),
          ),
          const SizedBox(height: 10),
          ...profile.emergencyContacts.map((contact) {
            return Padding(
              padding: const EdgeInsets.symmetric(vertical: 4.0),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      const Icon(Icons.phone_in_talk, size: 14, color: AppTheme.textSecondary),
                      const SizedBox(width: 8),
                      Text('${contact.name} (${contact.relation})', style: const TextStyle(fontSize: 13)),
                    ],
                  ),
                  Text(
                    contact.phone,
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Colors.white),
                  ),
                ],
              ),
            );
          }).toList(),

          const Divider(height: 24),

          // Organ Donation Legal Pledge Status
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Organ Donation Consent',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Colors.white),
                  ),
                  Text(
                    hasOrganPledge
                        ? 'Legally Verifiable Pledge Found'
                        : 'No active pledge recorded',
                    style: TextStyle(
                      color: hasOrganPledge ? AppTheme.accentGreen : AppTheme.textSecondary,
                      fontSize: 11,
                    ),
                  ),
                ],
              ),
              if (hasOrganPledge)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: AppTheme.accentGreen.withOpacity(0.15),
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(color: AppTheme.accentGreen.withOpacity(0.4)),
                  ),
                  child: const Row(
                    children: [
                      Icon(Icons.verified, size: 14, color: AppTheme.accentGreen),
                      SizedBox(width: 4),
                      Text(
                        'PLEDGED',
                        style: TextStyle(color: AppTheme.accentGreen, fontSize: 10, fontWeight: FontWeight.bold),
                      )
                    ],
                  ),
                )
            ],
          ),

          // Online-Only Premium Medical Details
          if (!isOffline) ...[
            const Divider(height: 24),
            Row(
              children: [
                const Icon(Icons.cloud_done, size: 14, color: AppTheme.accentTeal),
                const SizedBox(width: 6),
                const Text(
                  'Cloud Sync Records (Online Mode Only)',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: AppTheme.accentTeal),
                ),
              ],
            ),
            const SizedBox(height: 12),
            _buildDetailRow(Icons.health_and_safety_outlined, 'Chronic Conditions', profile.chronicConditions, Colors.white),
            _buildDetailRow(
              Icons.shield_outlined,
              'Health Insurance Info',
              '${profile.insuranceCompany}\nPolicy ID: ${profile.insurancePolicyNumber}',
              Colors.white,
            ),
            
            // Simulating GPS location sending
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: AppTheme.accentTeal.withOpacity(0.08),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: AppTheme.accentTeal.withOpacity(0.15)),
              ),
              child: const Row(
                children: [
                  Icon(Icons.location_on, size: 16, color: AppTheme.accentTeal),
                  SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Emergency alert sent! Police GPS ping dispatched to kin contacts automatically.',
                      style: TextStyle(color: AppTheme.accentTeal, fontSize: 11, fontWeight: FontWeight.bold),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    ).animate().fade(duration: 400.ms).slideY(begin: 0.1);
  }

  Widget _buildDetailRow(IconData icon, String title, String value, Color valueColor) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 18, color: AppTheme.textSecondary),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(color: AppTheme.textSecondary, fontSize: 11),
                ),
                const SizedBox(height: 2),
                Text(
                  value.isEmpty ? 'None' : value,
                  style: TextStyle(color: valueColor, fontSize: 14, fontWeight: FontWeight.w500),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
