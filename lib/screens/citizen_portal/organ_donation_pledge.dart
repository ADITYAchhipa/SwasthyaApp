import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../../providers/swasthya_tap_provider.dart';
import '../../theme/app_theme.dart';
import '../../widgets/glass_card.dart';

class OrganDonationPledgeScreen extends StatefulWidget {
  const OrganDonationPledgeScreen({Key? key}) : super(key: key);

  @override
  _OrganDonationPledgeScreenState createState() => _OrganDonationPledgeScreenState();
}

class _OrganDonationPledgeScreenState extends State<OrganDonationPledgeScreen> {
  final _signatureController = TextEditingController();
  final _formKey = GlobalKey<FormState>();

  bool _allOrgans = true;
  final Map<String, bool> _organs = {
    'Kidneys': false,
    'Liver': false,
    'Heart': false,
    'Lungs': false,
    'Pancreas': false,
    'Corneas (Eyes)': false,
    'Skin': false,
  };

  bool _termsAccepted = false;
  bool _isSigning = false;
  String _signingStep = '';

  @override
  void dispose() {
    _signatureController.dispose();
    super.dispose();
  }

  void _submitPledge(SwasthyaTapProvider provider) async {
    if (!_formKey.currentState!.validate() || !_termsAccepted) {
      if (!_termsAccepted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Please accept the legal terms and consent declaration.'),
            backgroundColor: AppTheme.accentRed,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
      return;
    }

    setState(() {
      _isSigning = true;
      _signingStep = 'Generating SHA-256 Consent Hash...';
    });

    await Future.delayed(const Duration(milliseconds: 1200));

    if (!mounted) return;
    setState(() {
      _signingStep = 'Registering Signature Chain with NOTTO...';
    });

    await Future.delayed(const Duration(milliseconds: 1200));

    if (!mounted) return;
    setState(() {
      _signingStep = 'Locking Pledge Keys onto Card Config...';
    });

    await Future.delayed(const Duration(milliseconds: 1000));

    if (!mounted) return;

    // Compile organ list
    List<String> pledgedList = [];
    if (_allOrgans) {
      pledgedList.add('All Organs & Tissues');
    } else {
      _organs.forEach((organ, checked) {
        if (checked) pledgedList.add(organ);
      });
    }

    if (pledgedList.isEmpty) {
      setState(() {
        _isSigning = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please select at least one organ to pledge.'),
          backgroundColor: AppTheme.accentRed,
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    provider.signOrganPledge(provider.currentCitizenProfileId, pledgedList);

    setState(() {
      _isSigning = false;
    });

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(Icons.verified, color: Colors.black),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                'Organ pledge locked successfully! Hash: ${provider.currentCitizen.organPledge?.signatureHash.substring(0, 16)}...',
                style: const TextStyle(color: Colors.black, fontWeight: FontWeight.bold),
              ),
            ),
          ],
        ),
        backgroundColor: AppTheme.accentGreen,
        behavior: SnackBarBehavior.floating,
      ),
    );

    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final provider = Provider.of<SwasthyaTapProvider>(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('NOTTO Donor Pledge'),
        backgroundColor: Colors.transparent,
        elevation: 0,
      ),
      body: Stack(
        children: [
          SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(20, 10, 20, 40),
            child: Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'National Organ Pledge Form',
                    style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
                  ),
                  const Text(
                    'trans transplantation of human organs act, 1994',
                    style: TextStyle(color: AppTheme.textSecondary, fontSize: 11, letterSpacing: 0.5),
                  ),
                  const SizedBox(height: 20),

                  // Info card about NOTTO backend
                  GlassCard(
                    borderColor: AppTheme.accentGreen.withOpacity(0.2),
                    gradient: LinearGradient(
                      colors: [AppTheme.accentGreen.withOpacity(0.05), Colors.transparent],
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Icon(Icons.shield_outlined, color: AppTheme.accentGreen, size: 24),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                'Legal Digital Verification',
                                style: TextStyle(color: AppTheme.accentGreen, fontWeight: FontWeight.bold, fontSize: 14),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                'By signing this pledge, a unique cryptographic hash is generated locally. In the event of brain death at a registered hospital, the ICU staff can verify consent immediately by tapping your card, bypassing communication bottlenecks.',
                                style: TextStyle(color: AppTheme.textSecondary.withOpacity(0.9), fontSize: 12, height: 1.4),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 24),

                  // Step 1: Select Organs
                  _buildLabel('1. Selection of Organs for Pledge'),
                  const SizedBox(height: 12),
                  GlassCard(
                    child: Column(
                      children: [
                        CheckboxListTile(
                          title: const Text('All Organs & Tissues (Recommended)', style: TextStyle(fontWeight: FontWeight.bold)),
                          subtitle: const Text('Includes kidneys, liver, heart, lungs, pancreas, corneas, skin, bones.', style: TextStyle(fontSize: 11)),
                          value: _allOrgans,
                          onChanged: (val) {
                            setState(() {
                              _allOrgans = val ?? false;
                            });
                          },
                          activeColor: AppTheme.accentGreen,
                          contentPadding: EdgeInsets.zero,
                        ),
                        if (!_allOrgans) ...[
                          const Divider(),
                          const SizedBox(height: 8),
                          ..._organs.keys.map((organName) {
                            return CheckboxListTile(
                              title: Text(organName),
                              value: _organs[organName],
                              onChanged: (val) {
                                setState(() {
                                  _organs[organName] = val ?? false;
                                });
                              },
                              activeColor: AppTheme.accentGreen,
                              contentPadding: EdgeInsets.zero,
                            );
                          }).toList(),
                        ],
                      ],
                    ),
                  ),
                  const SizedBox(height: 24),

                  // Step 2: Legal declaration terms
                  _buildLabel('2. Legal Declaration & Consent'),
                  const SizedBox(height: 12),
                  GlassCard(
                    child: Column(
                      children: [
                        CheckboxListTile(
                          title: const Text('Consent Declaration', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                          subtitle: const Text(
                            'I hereby authorize the removal of my pledged organs/tissues for therapeutic purposes after my death (specifically brain stem death). I confirm my immediate family supports this decision.',
                            style: TextStyle(fontSize: 11, height: 1.3),
                          ),
                          value: _termsAccepted,
                          onChanged: (val) {
                            setState(() {
                              _termsAccepted = val ?? false;
                            });
                          },
                          activeColor: AppTheme.accentGreen,
                          contentPadding: EdgeInsets.zero,
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 24),

                  // Step 3: Signature
                  _buildLabel('3. Digital Signature (Type Full Name)'),
                  const SizedBox(height: 12),
                  GlassCard(
                    child: Column(
                      children: [
                        TextFormField(
                          controller: _signatureController,
                          decoration: AppTheme.premiumInputDecoration(
                            label: 'E-Signature (Must match ${provider.currentCitizen.fullName})',
                            icon: Icons.draw,
                          ),
                          validator: (value) {
                            if (value == null || value.isEmpty) {
                              return 'Signature required';
                            }
                            if (value.toLowerCase().trim() != provider.currentCitizen.fullName.toLowerCase().trim()) {
                              return 'Signature must match your registered name exactly';
                            }
                            return null;
                          },
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 32),

                  // Sign button
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: () => _submitPledge(provider),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppTheme.accentGreen,
                        foregroundColor: Colors.black,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                        elevation: 10,
                        shadowColor: AppTheme.accentGreen.withOpacity(0.3),
                      ),
                      child: const Text('Lock Cryptographic Pledge', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                    ),
                  ),
                ],
              ),
            ),
          ),
          
          // Signing Progress Overlay
          if (_isSigning)
            Container(
              color: Colors.black87,
              child: Center(
                child: GlassCard(
                  width: 280,
                  height: 180,
                  borderColor: AppTheme.accentTeal.withOpacity(0.3),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const CircularProgressIndicator(color: AppTheme.accentTeal),
                      const SizedBox(height: 20),
                      Text(
                        _signingStep,
                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 6),
                      const Text(
                        'Securing keys. Please wait.',
                        style: TextStyle(color: AppTheme.textSecondary, fontSize: 11),
                      )
                    ],
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildLabel(String text) {
    return Padding(
      padding: const EdgeInsets.only(left: 4.0),
      child: Text(
        text,
        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: AppTheme.textSecondary),
      ),
    );
  }
}
