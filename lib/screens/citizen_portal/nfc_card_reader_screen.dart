import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:nfc_manager/nfc_manager.dart';
import 'package:google_fonts/google_fonts.dart';
import 'scanned_profile_screen.dart';

class NfcCardReaderScreen extends StatefulWidget {
  const NfcCardReaderScreen({super.key});

  @override
  State<NfcCardReaderScreen> createState() => _NfcCardReaderScreenState();
}

class _NfcCardReaderScreenState extends State<NfcCardReaderScreen> with SingleTickerProviderStateMixin {
  bool _isScanning = false;
  String _statusMessage = 'Align card with device back';
  late AnimationController _pulseController;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2000),
    );
    // Start pulsing immediately and keep repeating
    _pulseController.repeat();
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
              ? 'Ready to scan. Align card with device back.'
              : 'NFC hardware not detected. Enable NFC in settings.';
        });
        if (available) {
          _startNfcSession();
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _statusMessage = 'NFC sensor initialization error.';
        });
      }
    }
  }

  void _startNfcSession() {
    setState(() {
      _isScanning = true;
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
            _updateStatus('Valid SwasthyaTap payload not detected.');
          } catch (e) {
            _updateStatus('Error reading card: $e');
          }
        },
      );
    } catch (e) {
      _updateStatus('NFC session start failed.');
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      // High-end, premium dark medical aesthetic
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [Color(0xFF0F172A), Color(0xFF020617)],
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
          ),
        ),
        child: SafeArea(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              // Custom Clean Navigation Bar
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    IconButton(
                      icon: const Icon(Icons.arrow_back_ios_new_rounded, color: Colors.white70),
                      onPressed: () => Navigator.pop(context),
                    ),
                    Text(
                      'CARD READER',
                      style: GoogleFonts.outfit(
                        color: Colors.white70,
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 1.5,
                      ),
                    ),
                    const SizedBox(width: 48), // Symmetrical spacer
                  ],
                ),
              ),

              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.symmetric(horizontal: 28.0),
                  child: Column(
                    children: [
                      const SizedBox(height: 30),
                      // High-end Typography
                      Text(
                        'SwasthyaTap NFC',
                        style: GoogleFonts.outfit(
                          fontSize: 28,
                          fontWeight: FontWeight.w800,
                          color: Colors.white,
                          letterSpacing: -0.5,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        'Tap a card to retrieve patient records',
                        style: GoogleFonts.inter(
                          fontSize: 14,
                          fontWeight: FontWeight.w500,
                          color: const Color(0xFF94A3B8),
                        ),
                      ),
                      const SizedBox(height: 80),

                      // Premium pulsing radar animation (always moving)
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
                                    // Outer ring
                                    Container(
                                      width: 140 + (120 * val),
                                      height: 140 + (120 * val),
                                      decoration: BoxDecoration(
                                        shape: BoxShape.circle,
                                        border: Border.all(
                                          color: const Color(0xFF0D9488).withValues(alpha: 1.0 - val),
                                          width: 1.5,
                                        ),
                                      ),
                                    ),
                                    // Middle ring
                                    Container(
                                      width: 180 + (90 * val),
                                      height: 180 + (90 * val),
                                      decoration: BoxDecoration(
                                        shape: BoxShape.circle,
                                        border: Border.all(
                                          color: const Color(0xFF0D9488).withValues(alpha: 0.5 * (1.0 - val)),
                                          width: 1.0,
                                        ),
                                      ),
                                    ),
                                  ],
                                );
                              },
                            ),
                            // Central scanning hub
                            Container(
                              width: 150,
                              height: 150,
                              decoration: BoxDecoration(
                                color: const Color(0xFF1E293B).withValues(alpha: 0.7),
                                shape: BoxShape.circle,
                                border: Border.all(
                                  color: const Color(0xFF0D9488).withValues(alpha: 0.4),
                                  width: 2.0,
                                ),
                                boxShadow: [
                                  BoxShadow(
                                    color: const Color(0xFF0D9488).withValues(alpha: 0.15),
                                    blurRadius: 30,
                                    spreadRadius: 5,
                                  ),
                                ],
                              ),
                              child: const Icon(
                                Icons.contactless_rounded,
                                color: Color(0xFF2DD4BF),
                                size: 68,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 70),

                      // Glassmorphism status indicator
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.03),
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Container(
                              width: 8,
                              height: 8,
                              decoration: const BoxDecoration(
                                color: Color(0xFF2DD4BF),
                                shape: BoxShape.circle,
                                boxShadow: [
                                  BoxShadow(
                                    color: Color(0xFF2DD4BF),
                                    blurRadius: 8,
                                    spreadRadius: 1,
                                  ),
                                ],
                              ),
                            ).animate(onPlay: (controller) => controller.repeat())
                             .fade(duration: 800.ms),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Text(
                                _statusMessage,
                                textAlign: TextAlign.start,
                                style: GoogleFonts.inter(
                                  color: Colors.white.withValues(alpha: 0.9),
                                  fontSize: 13.5,
                                  fontWeight: FontWeight.w600,
                                  height: 1.4,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ).animate().fade(duration: 400.ms).slideY(begin: 0.1),

                      const SizedBox(height: 40),

                      // Premium instructions cards
                      Container(
                        padding: const EdgeInsets.all(20),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.02),
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(color: Colors.white.withValues(alpha: 0.04)),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'How to scan card:',
                              style: GoogleFonts.outfit(
                                color: Colors.white.withValues(alpha: 0.8),
                                fontSize: 13,
                                fontWeight: FontWeight.bold,
                                letterSpacing: 0.5,
                              ),
                            ),
                            const SizedBox(height: 12),
                            _buildInstructionStep(
                              Icons.nfc_rounded,
                              'Ensure NFC is enabled in system settings.',
                            ),
                            const SizedBox(height: 10),
                            _buildInstructionStep(
                              Icons.tap_and_play_rounded,
                              'Place the card near the top-back region of your device.',
                            ),
                            const SizedBox(height: 10),
                            _buildInstructionStep(
                              Icons.timer_outlined,
                              'Keep the card steady for 1-2 seconds until read completes.',
                            ),
                          ],
                        ),
                      ).animate().fade(delay: 200.ms, duration: 400.ms).slideY(begin: 0.1),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildInstructionStep(IconData icon, String text) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 16, color: const Color(0xFF2DD4BF)),
        const SizedBox(width: 10),
        Expanded(
          child: Text(
            text,
            style: GoogleFonts.inter(
              color: const Color(0xFF94A3B8),
              fontSize: 12,
              height: 1.4,
              fontWeight: FontWeight.w500,
            ),
          ),
        ),
      ],
    );
  }
}
