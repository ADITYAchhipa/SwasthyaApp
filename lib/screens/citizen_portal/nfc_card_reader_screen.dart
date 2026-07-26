import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:nfc_manager/nfc_manager.dart';
import 'package:crypto/crypto.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../providers/swasthya_tap_provider.dart';
import '../../theme/app_theme.dart';
import '../../widgets/glass_card.dart';
import 'scanned_profile_screen.dart';

class NfcCardReaderScreen extends StatefulWidget {
  const NfcCardReaderScreen({super.key});

  @override
  State<NfcCardReaderScreen> createState() => _NfcCardReaderScreenState();
}

class _NfcCardReaderScreenState extends State<NfcCardReaderScreen> with SingleTickerProviderStateMixin {
  bool _isScanning = false;
  String _statusMessage = 'Initializing NFC...';
  String _selectedProfileId = 'x7k9m2';
  bool _isSimulating = false;
  late AnimationController _pulseController;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    );
    _checkNfcAvailability();
  }

  @override
  void dispose() {
    _pulseController.dispose();
    if (_isScanning) {
      try {
        NfcManager.instance.stopSession();
      } catch (_) {}
    }
    super.dispose();
  }

  Future<void> _checkNfcAvailability() async {
    try {
      final available = await NfcManager.instance.isAvailable();
      if (mounted) {
        setState(() {
          _statusMessage = available
              ? 'Hold your SwasthyaTap Card near the back of your device'
              : 'NFC reader is not supported on this device. Use simulator below.';
        });
        if (available) {
          _startNfcSession();
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _statusMessage = 'NFC Initialization failed. Use simulator below.';
        });
      }
    }
  }

  void _startNfcSession() {
    setState(() {
      _isScanning = true;
      _pulseController.repeat();
    });

    try {
      NfcManager.instance.startSession(
        onDiscovered: (NfcTag tag) async {
          try {
            final ndef = Ndef.from(tag);
            if (ndef == null) {
              _updateStatus('Unsupported NFC tag type.');
              return;
            }

            final message = ndef.cachedMessage;
            if (message == null || message.records.isEmpty) {
              _updateStatus('No NDEF data found on card.');
              return;
            }

            for (var record in message.records) {
              final payload = record.payload;
              if (payload.isNotEmpty) {
                final recordText = utf8.decode(payload.sublist(1), allowMalformed: true);
                if (recordText.contains('/card/')) {
                  final parts = recordText.split('/card/');
                  if (parts.length > 1) {
                    final extractedId = parts[1].split('?').first.trim();
                    _handleSuccess(extractedId);
                    return;
                  }
                }
              }
            }
            _updateStatus('Valid SwasthyaTap Card payload not detected.');
          } catch (e) {
            _updateStatus('Error reading card: $e');
          }
        },
      );
    } catch (e) {
      _updateStatus('Failed to start NFC reader session: $e');
    }
  }

  void _updateStatus(String message) {
    if (!mounted) return;
    setState(() {
      _statusMessage = message;
    });
  }

  void _handleSuccess(String profileId) {
    HapticFeedback.heavyImpact();
    NfcManager.instance.stopSession();
    if (mounted) {
      setState(() {
        _isScanning = false;
        _pulseController.stop();
        _statusMessage = 'Card successfully read!';
      });
      
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (context) => ScannedProfileScreen(profileId: profileId),
        ),
      );
    }
  }

  void _simulateTap(SwasthyaTapProvider provider) async {
    if (_isSimulating) return;
    setState(() {
      _isSimulating = true;
      _pulseController.repeat();
      _statusMessage = 'Reading Card NDEF memory...';
    });

    await Future.delayed(const Duration(milliseconds: 1500));

    if (!mounted) return;

    final targetProfile = provider.profiles.firstWhere((p) => p.id == _selectedProfileId);
    final String fallbackHash = sha256.convert(utf8.encode(targetProfile.id)).toString();

    HapticFeedback.mediumImpact();
    setState(() {
      _isSimulating = false;
      _pulseController.stop();
      _statusMessage = 'Card tapped!';
    });

    Navigator.pushReplacement(
      context,
      MaterialPageRoute(
        builder: (context) => ScannedProfileScreen(profileId: fallbackHash),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final provider = Provider.of<SwasthyaTapProvider>(context);

    return Scaffold(
      backgroundColor: AppTheme.lightBg,
      appBar: AppBar(
        title: const Text('NFC Card Reader'),
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            const SizedBox(height: 20),
            Text(
              'SwasthyaTap Health ID',
              style: GoogleFonts.inter(
                fontSize: 22,
                fontWeight: FontWeight.w800,
                color: AppTheme.textPrimary,
                letterSpacing: -0.5,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Scan medical cards or rings to instantly view profile',
              style: GoogleFonts.inter(
                fontSize: 13,
                fontWeight: FontWeight.w500,
                color: AppTheme.textSecondary,
              ),
            ),
            const SizedBox(height: 50),

            // Pulsing scanner graphic
            Center(
              child: Stack(
                alignment: Alignment.center,
                children: [
                  AnimatedBuilder(
                    animation: _pulseController,
                    builder: (context, child) {
                      final val = _pulseController.value;
                      return Stack(
                        alignment: Alignment.center,
                        children: [
                          Container(
                            width: 120 + (80 * val),
                            height: 120 + (80 * val),
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              border: Border.all(
                                color: AppTheme.accentTeal.withValues(alpha: 1.0 - val),
                                width: 2,
                              ),
                            ),
                          ),
                          Container(
                            width: 160 + (100 * val),
                            height: 160 + (100 * val),
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              border: Border.all(
                                color: AppTheme.accentTeal.withValues(alpha: 0.5 * (1.0 - val)),
                                width: 1.5,
                              ),
                            ),
                          ),
                        ],
                      );
                    },
                  ),
                  Container(
                    width: 140,
                    height: 140,
                    decoration: BoxDecoration(
                      color: AppTheme.cardBg,
                      shape: BoxShape.circle,
                      border: Border.all(color: AppTheme.accentTeal.withValues(alpha: 0.5), width: 2),
                      boxShadow: [
                        BoxShadow(
                          color: AppTheme.accentTeal.withValues(alpha: 0.2),
                          blurRadius: 20,
                          spreadRadius: 2,
                        ),
                      ],
                    ),
                    child: const Icon(
                      Icons.contactless_rounded,
                      color: AppTheme.accentTeal,
                      size: 56,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 60),

            // Status message
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
              decoration: BoxDecoration(
                color: AppTheme.cardBg,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: AppTheme.borderColor),
                boxShadow: const [
                  BoxShadow(
                    color: Color(0x05000000),
                    blurRadius: 10,
                    offset: Offset(0, 4),
                  )
                ],
              ),
              child: Text(
                _statusMessage,
                textAlign: TextAlign.center,
                style: GoogleFonts.inter(
                  color: AppTheme.textPrimary,
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  height: 1.4,
                ),
              ),
            ).animate().fade(duration: 400.ms).slideY(begin: 0.1),

            const SizedBox(height: 50),

            // Card Tap Simulator for fallback
            GlassCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Icon(Icons.settings_suggest_rounded, color: AppTheme.accentTeal, size: 20),
                      const SizedBox(width: 8),
                      Text(
                        'NFC Card Simulator',
                        style: GoogleFonts.inter(
                          fontWeight: FontWeight.bold,
                          color: AppTheme.accentTeal,
                          fontSize: 14,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),
                  DropdownButtonFormField<String>(
                    value: _selectedProfileId,
                    dropdownColor: AppTheme.cardBg,
                    style: GoogleFonts.inter(color: AppTheme.textPrimary, fontSize: 13),
                    decoration: AppTheme.premiumInputDecoration(
                      label: 'Select Profile to Tap',
                      icon: Icons.contactless,
                    ),
                    items: provider.profiles.map((p) {
                      return DropdownMenuItem<String>(
                        value: p.id,
                        child: Text('${p.fullName} (${p.bloodGroup})'),
                      );
                    }).toList(),
                    onChanged: (val) {
                      if (val != null) {
                        setState(() {
                          _selectedProfileId = val;
                        });
                      }
                    },
                  ),
                  const SizedBox(height: 16),
                  SizedBox(
                    width: double.infinity,
                    height: 48,
                    child: ElevatedButton(
                      onPressed: () => _simulateTap(provider),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppTheme.accentTeal,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        elevation: 4,
                      ),
                      child: _isSimulating
                          ? const SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2.5),
                            )
                          : Text(
                              'Simulate NFC Card Tap',
                              style: GoogleFonts.inter(fontWeight: FontWeight.bold, fontSize: 14),
                            ),
                    ),
                  ),
                ],
              ),
            ).animate().fade(delay: 200.ms, duration: 400.ms).slideY(begin: 0.1),
          ],
        ),
      ),
    );
  }
}
