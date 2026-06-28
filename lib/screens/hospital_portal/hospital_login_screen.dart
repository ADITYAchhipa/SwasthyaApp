import 'dart:async';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'hospital_dashboard.dart';
import '../../services/api_service.dart';

class HospitalLoginScreen extends StatefulWidget {
  const HospitalLoginScreen({Key? key}) : super(key: key);

  @override
  State<HospitalLoginScreen> createState() => _HospitalLoginScreenState();
}

class _HospitalLoginScreenState extends State<HospitalLoginScreen> {
  final _formKey = GlobalKey<FormState>();
  
  // Controllers
  final TextEditingController _hospitalIdController = TextEditingController();
  final TextEditingController _personnelIdController = TextEditingController();
  final TextEditingController _phoneController = TextEditingController();
  
  // OTP controllers and FocusNodes
  final List<TextEditingController> _otpControllers = List.generate(4, (_) => TextEditingController());
  final List<FocusNode> _otpFocusNodes = List.generate(4, (_) => FocusNode());
  
  bool _isSendingOtp = false;
  bool _isOtpSent = false;
  int _otpCountdown = 0;
  Timer? _countdownTimer;
  bool _isVerifying = false;
  bool _isVerifiedSuccess = false;

  @override
  void dispose() {
    _hospitalIdController.dispose();
    _personnelIdController.dispose();
    _phoneController.dispose();
    _countdownTimer?.cancel();
    for (var controller in _otpControllers) {
      controller.dispose();
    }
    for (var node in _otpFocusNodes) {
      node.dispose();
    }
    super.dispose();
  }

  void _startCountdown() {
    setState(() {
      _otpCountdown = 30;
    });
    _countdownTimer?.cancel();
    _countdownTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (_otpCountdown > 0) {
        setState(() {
          _otpCountdown--;
        });
      } else {
        _countdownTimer?.cancel();
      }
    });
  }

  void _sendOtp() async {
    if (_phoneController.text.trim().length < 10) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please enter a valid 10-digit mobile number'),
          backgroundColor: Colors.redAccent,
        ),
      );
      return;
    }

    setState(() => _isSendingOtp = true);

    try {
      final hospitalId = _hospitalIdController.text.trim();
      final result = await ApiService.sendHospitalOtp(
        _phoneController.text.trim(),
        hospitalId.isEmpty ? 'HOSP-001' : hospitalId,
      );

      if (!mounted) return;
      setState(() {
        _isSendingOtp = false;
        _isOtpSent = true;
      });
      _startCountdown();

      // Auto-fill OTP in dev mode
      final devOtp = result['devOtp'] as String?;
      if (devOtp != null) {
        for (int i = 0; i < 4 && i < devOtp.length; i++) {
          _otpControllers[i].text = devOtp[i];
        }
      } else {
        // Fallback auto-fill for offline mode
        _otpControllers[0].text = '1';
        _otpControllers[1].text = '2';
        _otpControllers[2].text = '3';
        _otpControllers[3].text = '4';
      }

      final isOffline = result['offline'] == true;
      final msg = isOffline
          ? 'Server offline — use OTP: ${devOtp ?? "1234"}'
          : (devOtp != null
              ? 'OTP sent! (Dev mode — OTP: $devOtp)'
              : 'OTP sent to registered number');

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(children: [
            const Icon(Icons.check_circle_outline, color: Colors.white, size: 20),
            const SizedBox(width: 10),
            Expanded(child: Text(msg)),
          ]),
          backgroundColor: const Color(0xFF0F766E),
          behavior: SnackBarBehavior.floating,
          duration: const Duration(seconds: 6),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      setState(() => _isSendingOtp = false);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Failed to send OTP. Check your Hospital ID and try again.'),
          backgroundColor: Colors.redAccent,
        ),
      );
    }
  }

  void _verifyHospital() async {
    if (!_formKey.currentState!.validate()) return;

    String otp = _otpControllers.map((c) => c.text).join();
    if (otp.length < 4) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please enter the 4-digit OTP code'),
          backgroundColor: Colors.redAccent,
        ),
      );
      return;
    }

    setState(() => _isVerifying = true);

    try {
      final result = await ApiService.verifyHospital(
        _hospitalIdController.text.trim(),
        _personnelIdController.text.trim(),
        _phoneController.text.trim(),
        otp,
      );

      if (!mounted) return;

      if (result['success'] == true) {
        // Persist hospital session to disk
        final hospitalData = result['hospital'] as Map<String, dynamic>?;
        final hId = hospitalData?['hospitalId'] as String? ?? _hospitalIdController.text.trim();
        final hName = hospitalData?['name'] as String? ?? 'Hospital';
        ApiService.setHospitalToken(result['token'] as String, hId, hName);

        setState(() {
          _isVerifying = false;
          _isVerifiedSuccess = true;
        });

        Future.delayed(const Duration(milliseconds: 1000), () {
          if (!mounted) return;
          Navigator.pushReplacement(
            context,
            PageRouteBuilder(
              transitionDuration: const Duration(milliseconds: 600),
              pageBuilder: (context, animation, secondaryAnimation) => const HospitalDashboard(),
              transitionsBuilder: (context, animation, secondaryAnimation, child) =>
                  FadeTransition(opacity: animation, child: child),
            ),
          );
        });
      } else {
        setState(() => _isVerifying = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(result['message'] as String? ?? 'Verification failed'),
            backgroundColor: Colors.redAccent,
          ),
        );
      }
    } catch (e) {
      if (!mounted) return;
      setState(() => _isVerifying = false);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Connection failed. Please check your internet and try again.'),
          backgroundColor: Colors.redAccent,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF1F5F9),
      body: Stack(
        children: [
          // 1. Stylized Background: Light blue-grey gradient + hospital building vector silhouette
          Positioned.fill(
            child: Container(
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Color(0xFFE2E8F0),
                    Color(0xFFF8FAFC),
                  ],
                ),
              ),
            ),
          ),
          
          Positioned.fill(
            child: Opacity(
              opacity: 0.08,
              child: CustomPaint(
                painter: HospitalSilhouettePainter(),
              ),
            ),
          ),

          SafeArea(
            child: SingleChildScrollView(
              physics: const BouncingScrollPhysics(),
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    // Top Bar: Help Link
                    Row(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        GestureDetector(
                          onTap: () {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(content: Text('Help desk & documentation coming soon.')),
                            );
                          },
                          child: Row(
                            children: [
                              const Icon(Icons.help_outline_rounded, size: 16, color: Color(0xFF0F766E)),
                              const SizedBox(width: 4),
                              Text(
                                'Help',
                                style: GoogleFonts.inter(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w600,
                                  color: const Color(0xFF0F766E),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),

                    // Government of India Emblem (Custom vector)
                    CustomPaint(
                      size: const Size(60, 60),
                      painter: IndiaEmblemPainter(),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      'Government of India',
                      style: GoogleFonts.outfit(
                        fontSize: 10.5,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 0.5,
                        color: const Color(0xFF334155),
                      ),
                    ),
                    const SizedBox(height: 20),

                    // SwasthyaTap Hospital Logo
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        CustomPaint(
                          size: const Size(36, 36),
                          painter: SwasthyaTapLogoPainter(),
                        ),
                        const SizedBox(width: 10),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'SwasthyaTap',
                              style: GoogleFonts.outfit(
                                fontSize: 24,
                                fontWeight: FontWeight.w900,
                                color: const Color(0xFF0D9488),
                                letterSpacing: -0.5,
                              ),
                            ),
                            Row(
                              children: [
                                Container(
                                  width: 20,
                                  height: 1,
                                  color: const Color(0xFF0F172A).withOpacity(0.3),
                                ),
                                Padding(
                                  padding: const EdgeInsets.symmetric(horizontal: 4),
                                  child: Text(
                                    'HOSPITAL',
                                    style: GoogleFonts.inter(
                                      fontSize: 9,
                                      fontWeight: FontWeight.w800,
                                      letterSpacing: 3.5,
                                      color: const Color(0xFF0F766E),
                                    ),
                                  ),
                                ),
                                Container(
                                  width: 20,
                                  height: 1,
                                  color: const Color(0xFF0F172A).withOpacity(0.3),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'NFC Emergency Health Identity Platform',
                      style: GoogleFonts.inter(
                        fontSize: 10.5,
                        fontWeight: FontWeight.w500,
                        color: const Color(0xFF64748B),
                      ),
                    ),
                    const SizedBox(height: 28),

                    // Lock Icon Badge
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        shape: BoxShape.circle,
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.04),
                            blurRadius: 10,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      child: const Icon(
                        Icons.lock_rounded,
                        color: Color(0xFF1E40AF),
                        size: 22,
                      ),
                    ).animate().scale(delay: 100.ms, duration: 400.ms, curve: Curves.easeOutBack),
                    const SizedBox(height: 12),

                    // Form Header Text
                    Text(
                      'Government Hospital Login',
                      style: GoogleFonts.outfit(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: const Color(0xFF0F172A),
                      ),
                    ),
                    const SizedBox(height: 6),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 24),
                      child: Text(
                        'Only registered government hospitals can access patient data via NFC scan.',
                        textAlign: TextAlign.center,
                        style: GoogleFonts.inter(
                          fontSize: 12,
                          color: const Color(0xFF64748B),
                          height: 1.4,
                        ),
                      ),
                    ),
                    const SizedBox(height: 24),

                    // White Form Card
                    Container(
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(24),
                        border: Border.all(color: const Color(0xFFE2E8F0), width: 1),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.03),
                            blurRadius: 20,
                            offset: const Offset(0, 8),
                          ),
                        ],
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Field 1: Hospital Registration ID
                          _buildFieldLabel('Hospital Registration ID'),
                          const SizedBox(height: 6),
                          TextFormField(
                            controller: _hospitalIdController,
                            style: GoogleFonts.inter(fontSize: 14, color: const Color(0xFF0F172A)),
                            decoration: _buildInputDecoration(
                              hintText: 'Enter Hospital Registration ID',
                              prefixIcon: Icons.domain_rounded,
                              suffixIcon: Icons.badge_outlined,
                            ),
                            validator: (val) {
                              if (val == null || val.trim().isEmpty) {
                                return 'Hospital Registration ID is required';
                              }
                              return null;
                            },
                          ),
                          const SizedBox(height: 16),

                          // Field 2: Authorized Personnel ID
                          _buildFieldLabel('Authorized Personnel ID'),
                          const SizedBox(height: 6),
                          TextFormField(
                            controller: _personnelIdController,
                            style: GoogleFonts.inter(fontSize: 14, color: const Color(0xFF0F172A)),
                            decoration: _buildInputDecoration(
                              hintText: 'Enter Authorized Personnel ID',
                              prefixIcon: Icons.person_rounded,
                              suffixIcon: Icons.perm_identity_rounded,
                            ),
                            validator: (val) {
                              if (val == null || val.trim().isEmpty) {
                                return 'Personnel ID is required';
                              }
                              return null;
                            },
                          ),
                          const SizedBox(height: 16),

                          // Field 3: Registered Phone Number
                          _buildFieldLabel('Registered Phone Number'),
                          const SizedBox(height: 6),
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              // Country selector card
                              Container(
                                height: 48,
                                padding: const EdgeInsets.symmetric(horizontal: 10),
                                decoration: BoxDecoration(
                                  color: const Color(0xFFF8FAFC),
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(color: const Color(0xFFE2E8F0)),
                                ),
                                child: Row(
                                  children: [
                                    const Text('🇮🇳', style: TextStyle(fontSize: 18)),
                                    const SizedBox(width: 4),
                                    Text(
                                      '+91',
                                      style: GoogleFonts.inter(
                                        fontSize: 13.5,
                                        fontWeight: FontWeight.bold,
                                        color: const Color(0xFF0F172A),
                                      ),
                                    ),
                                    const SizedBox(width: 2),
                                    const Icon(Icons.keyboard_arrow_down_rounded, size: 14, color: Colors.black54),
                                  ],
                                ),
                              ),
                              const SizedBox(width: 8),
                              
                              // Mobile number input field
                              Expanded(
                                child: TextFormField(
                                  controller: _phoneController,
                                  keyboardType: TextInputType.phone,
                                  style: GoogleFonts.inter(fontSize: 14, color: const Color(0xFF0F172A)),
                                  decoration: _buildInputDecoration(
                                    hintText: 'Enter Registered Mobile Number',
                                    prefixIcon: Icons.phone_outlined,
                                  ),
                                  validator: (val) {
                                    if (val == null || val.trim().isEmpty) {
                                      return 'Phone number is required';
                                    }
                                    if (val.trim().length < 10) {
                                      return 'Enter valid 10-digit number';
                                    }
                                    return null;
                                  },
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 16),

                          // Field 4: OTP Input Segment
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              _buildFieldLabel('Enter OTP'),
                              GestureDetector(
                                onTap: (_isSendingOtp || _otpCountdown > 0) ? null : _sendOtp,
                                child: _isSendingOtp
                                    ? const SizedBox(
                                        width: 14,
                                        height: 14,
                                        child: CircularProgressIndicator(
                                          strokeWidth: 2,
                                          valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF1D4ED8)),
                                        ),
                                      )
                                    : Text(
                                        _otpCountdown > 0 
                                            ? 'Resend in ${_otpCountdown}s' 
                                            : 'Send OTP',
                                        style: GoogleFonts.inter(
                                          fontSize: 12.5,
                                          fontWeight: FontWeight.bold,
                                          color: _otpCountdown > 0 
                                              ? const Color(0xFF94A3B8)
                                              : const Color(0xFF1D4ED8),
                                        ),
                                      ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          
                          // OTP 4 boxes input row
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: List.generate(4, (index) {
                              return Container(
                                width: 56,
                                height: 48,
                                decoration: BoxDecoration(
                                  color: const Color(0xFFF8FAFC),
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(color: const Color(0xFFE2E8F0)),
                                ),
                                child: TextField(
                                  controller: _otpControllers[index],
                                  focusNode: _otpFocusNodes[index],
                                  keyboardType: TextInputType.number,
                                  textAlign: TextAlign.center,
                                  style: GoogleFonts.outfit(
                                    fontSize: 18,
                                    fontWeight: FontWeight.bold,
                                    color: const Color(0xFF0F172A),
                                  ),
                                  decoration: const InputDecoration(
                                    hintText: '-',
                                    hintStyle: TextStyle(color: Colors.black26),
                                    border: InputBorder.none,
                                    contentPadding: EdgeInsets.zero,
                                  ),
                                  onChanged: (val) {
                                    if (val.isNotEmpty && index < 3) {
                                      _otpFocusNodes[index + 1].requestFocus();
                                    } else if (val.isEmpty && index > 0) {
                                      _otpFocusNodes[index - 1].requestFocus();
                                    }
                                  },
                                ),
                              );
                            }),
                          ),
                          const SizedBox(height: 12),

                          // Helper Note
                          Row(
                            children: [
                              const Icon(Icons.shield_outlined, color: Color(0xFF10B981), size: 14),
                              const SizedBox(width: 6),
                              Expanded(
                                child: Text(
                                  'OTP will be sent to the registered mobile number',
                                  style: GoogleFonts.inter(
                                    fontSize: 10.5,
                                    color: const Color(0xFF10B981),
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 20),

                          // Verify Button
                          SizedBox(
                            width: double.infinity,
                            height: 48,
                            child: ElevatedButton(
                              onPressed: (_isVerifying || _isVerifiedSuccess) ? null : _verifyHospital,
                              style: ElevatedButton.styleFrom(
                                backgroundColor: const Color(0xFF1E40AF),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                elevation: 0,
                              ),
                              child: _isVerifying
                                  ? const SizedBox(
                                      width: 20,
                                      height: 20,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2.5,
                                        valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                                      ),
                                    )
                                  : _isVerifiedSuccess
                                      ? const Icon(Icons.check_circle_rounded, color: Colors.white, size: 24)
                                      : Row(
                                          mainAxisAlignment: MainAxisAlignment.center,
                                          children: [
                                            const Icon(Icons.verified_user_outlined, size: 18, color: Colors.white),
                                            const SizedBox(width: 8),
                                            Text(
                                              'Verify Hospital',
                                              style: GoogleFonts.inter(
                                                fontSize: 14,
                                                fontWeight: FontWeight.bold,
                                                color: Colors.white,
                                              ),
                                            ),
                                          ],
                                        ),
                            ),
                          ),
                        ],
                      ),
                    ).animate().fade(delay: 200.ms, duration: 600.ms),
                    const SizedBox(height: 20),

                    // Trust Badges Grid
                    Container(
                      padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 10),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: const Color(0xFFE2E8F0)),
                      ),
                      child: Row(
                        children: [
                          Expanded(
                            child: _buildTrustBadge(
                              icon: Icons.verified_rounded,
                              iconColor: const Color(0xFF10B981),
                              title: 'Verified by',
                              subtitle: 'NHA',
                            ),
                          ),
                          Container(width: 1, height: 28, color: const Color(0xFFE2E8F0)),
                          Expanded(
                            child: _buildTrustBadge(
                              icon: Icons.hub_rounded,
                              iconColor: const Color(0xFF0D9488),
                              title: 'ABDM',
                              subtitle: 'Integrated',
                            ),
                          ),
                          Container(width: 1, height: 28, color: const Color(0xFFE2E8F0)),
                          Expanded(
                            child: _buildTrustBadge(
                              icon: Icons.security_rounded,
                              iconColor: const Color(0xFF1E40AF),
                              title: 'HIPAA + DPDP',
                              subtitle: 'Compliant',
                            ),
                          ),
                        ],
                      ),
                    ).animate().fade(delay: 350.ms, duration: 600.ms),
                    const SizedBox(height: 14),

                    // Encryption Blue Banner
                    Container(
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: const Color(0xFFEFF6FF),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: const Color(0xFFDBEAFE)),
                      ),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Icon(Icons.verified_user_rounded, color: Color(0xFF1E40AF), size: 20),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              'SwasthyaTap ensures secure, encrypted and authorized access to patient data.',
                              style: GoogleFonts.inter(
                                fontSize: 11,
                                height: 1.4,
                                color: const Color(0xFF1E40AF),
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ).animate().fade(delay: 450.ms, duration: 600.ms),
                    const SizedBox(height: 24),

                    // Footer Link: Need help? Contact Admin
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          'Need help? ',
                          style: GoogleFonts.inter(
                            fontSize: 12.5,
                            color: const Color(0xFF64748B),
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        GestureDetector(
                          onTap: () {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(content: Text('Contact details: support@swasthyatap.in')),
                            );
                          },
                          child: Text(
                            'Contact Admin >',
                            style: GoogleFonts.inter(
                              fontSize: 12.5,
                              color: const Color(0xFF1D4ED8),
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 20),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFieldLabel(String label) {
    return RichText(
      text: TextSpan(
        text: label,
        style: GoogleFonts.inter(
          fontSize: 12,
          fontWeight: FontWeight.bold,
          color: const Color(0xFF475569),
        ),
        children: const [
          TextSpan(
            text: ' *',
            style: TextStyle(color: Colors.redAccent, fontWeight: FontWeight.bold),
          ),
        ],
      ),
    );
  }

  InputDecoration _buildInputDecoration({
    required String hintText,
    required IconData prefixIcon,
    IconData? suffixIcon,
  }) {
    return InputDecoration(
      hintText: hintText,
      hintStyle: GoogleFonts.inter(fontSize: 13, color: const Color(0xFF94A3B8)),
      prefixIcon: Icon(prefixIcon, color: const Color(0xFF64748B), size: 18),
      suffixIcon: suffixIcon != null ? Icon(suffixIcon, color: const Color(0xFF94A3B8), size: 18) : null,
      filled: true,
      fillColor: const Color(0xFFF8FAFC),
      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      isDense: true,
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
        borderSide: const BorderSide(color: Color(0xFF1E40AF), width: 1.5),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: Colors.redAccent),
      ),
      focusedErrorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: Colors.redAccent, width: 1.5),
      ),
    );
  }

  Widget _buildTrustBadge({
    required IconData icon,
    required Color iconColor,
    required String title,
    required String subtitle,
  }) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, color: iconColor, size: 18),
        const SizedBox(height: 4),
        Text(
          title,
          style: GoogleFonts.inter(
            fontSize: 9.5,
            color: const Color(0xFF64748B),
            fontWeight: FontWeight.w500,
          ),
        ),
        Text(
          subtitle,
          style: GoogleFonts.inter(
            fontSize: 9.5,
            color: const Color(0xFF0F172A),
            fontWeight: FontWeight.bold,
          ),
        ),
      ],
    );
  }
}

// Custom Painter to draw SwasthyaTap heart-plus-wifi logo
class SwasthyaTapLogoPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = const Color(0xFF0D9488)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.5
      ..strokeCap = StrokeCap.round;

    // Draw Heart shape
    final heartPath = Path();
    heartPath.moveTo(size.width / 2, size.height * 0.90);
    heartPath.cubicTo(
      size.width * 0.1, size.height * 0.55,
      size.width * 0.05, size.height * 0.22,
      size.width * 0.5, size.height * 0.28,
    );
    heartPath.cubicTo(
      size.width * 0.95, size.height * 0.28,
      size.width * 0.9, size.height * 0.55,
      size.width / 2, size.height * 0.90,
    );
    canvas.drawPath(heartPath, paint);

    // Draw Cross inside
    final fillPaint = Paint()
      ..color = const Color(0xFF1E40AF)
      ..style = PaintingStyle.fill;
    
    // Vertical bar of cross
    canvas.drawRect(
      Rect.fromCenter(
        center: Offset(size.width / 2, size.height * 0.55),
        width: 4.5,
        height: 14,
      ),
      fillPaint,
    );
    // Horizontal bar of cross
    canvas.drawRect(
      Rect.fromCenter(
        center: Offset(size.width / 2, size.height * 0.55),
        width: 14,
        height: 4.5,
      ),
      fillPaint,
    );

    // Draw concentric wifi arcs at the top of the heart
    final wifiPaint = Paint()
      ..color = const Color(0xFF0D9488)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.0
      ..strokeCap = StrokeCap.round;

    final rectArc1 = Rect.fromCircle(center: Offset(size.width / 2, size.height * 0.28), radius: 10);
    canvas.drawArc(rectArc1, 3.14159 * 1.25, 3.14159 * 0.5, false, wifiPaint);

    final rectArc2 = Rect.fromCircle(center: Offset(size.width / 2, size.height * 0.28), radius: 15);
    canvas.drawArc(rectArc2, 3.14159 * 1.25, 3.14159 * 0.5, false, wifiPaint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

// Custom Painter to draw stylized hospital building vector silhouette background
class HospitalSilhouettePainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = const Color(0xFF1E40AF).withOpacity(0.06)
      ..style = PaintingStyle.fill;

    // Draw multiple overlapping building block contours
    
    // Main building
    canvas.drawRect(
      Rect.fromLTWH(size.width * 0.05, size.height * 0.1, size.width * 0.5, size.height * 0.8),
      paint,
    );
    // Building wings
    canvas.drawRect(
      Rect.fromLTWH(size.width * 0.55, size.height * 0.25, size.width * 0.4, size.height * 0.65),
      paint,
    );
    // Roof access block
    canvas.drawRect(
      Rect.fromLTWH(size.width * 0.18, size.height * 0.04, size.width * 0.2, size.height * 0.06),
      paint,
    );

    // Draw a big medical cross outline on the building facade
    final crossPaint = Paint()
      ..color = const Color(0xFFEFF6FF).withOpacity(0.3)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2;
      
    final crossCenter = Offset(size.width * 0.3, size.height * 0.3);
    canvas.drawLine(Offset(crossCenter.dx - 15, crossCenter.dy), Offset(crossCenter.dx + 15, crossCenter.dy), crossPaint);
    canvas.drawLine(Offset(crossCenter.dx, crossCenter.dy - 15), Offset(crossCenter.dx, crossCenter.dy + 15), crossPaint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

// Custom Painter to draw stylized national emblem representation
class IndiaEmblemPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = const Color(0xFF475569)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.2;

    final fillPaint = Paint()
      ..color = const Color(0xFF475569)
      ..style = PaintingStyle.fill;

    // Draw central pillar cap circle
    final center = Offset(size.width / 2, size.height * 0.72);
    canvas.drawCircle(center, 7, paint);

    // Draw spokes in wheel
    for (int i = 0; i < 24; i += 4) {
      double angle = i * 3.14159 / 12;
      canvas.drawLine(
        center,
        Offset(center.dx + 7 * (angle).hashCode.toDouble().clamp(-1.0, 1.0), 
               center.dy + 7 * (angle).hashCode.toDouble().clamp(-1.0, 1.0)),
        paint,
      );
    }

    // Draw central lion torso silhouette
    final pathCenterLion = Path()
      ..moveTo(size.width * 0.44, size.height * 0.65)
      ..lineTo(size.width * 0.40, size.height * 0.25)
      ..cubicTo(size.width * 0.42, size.height * 0.15, size.width * 0.58, size.height * 0.15, size.width * 0.60, size.height * 0.25)
      ..lineTo(size.width * 0.56, size.height * 0.65)
      ..close();
    canvas.drawPath(pathCenterLion, paint);

    // Draw left lion silhouette
    final pathLeftLion = Path()
      ..moveTo(size.width * 0.42, size.height * 0.62)
      ..cubicTo(size.width * 0.25, size.height * 0.58, size.width * 0.20, size.height * 0.35, size.width * 0.35, size.height * 0.30)
      ..lineTo(size.width * 0.41, size.height * 0.45)
      ..close();
    canvas.drawPath(pathLeftLion, paint);

    // Draw right lion silhouette
    final pathRightLion = Path()
      ..moveTo(size.width * 0.58, size.height * 0.62)
      ..cubicTo(size.width * 0.75, size.height * 0.58, size.width * 0.80, size.height * 0.35, size.width * 0.65, size.height * 0.30)
      ..lineTo(size.width * 0.59, size.height * 0.45)
      ..close();
    canvas.drawPath(pathRightLion, paint);

    // Draw base rectangular block
    final baseRect = Rect.fromLTRB(size.width * 0.22, size.height * 0.80, size.width * 0.78, size.height * 0.88);
    canvas.drawRRect(RRect.fromRectAndRadius(baseRect, const Radius.circular(2)), fillPaint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
