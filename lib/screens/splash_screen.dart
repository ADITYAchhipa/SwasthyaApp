import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../theme/app_theme.dart';
import '../services/api_service.dart';
import 'onboarding_screen.dart';
import 'citizen_portal/citizen_dashboard.dart';
import 'hospital_portal/hospital_dashboard.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({Key? key}) : super(key: key);

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  @override
  void initState() {
    super.initState();
    _initAndNavigate();
  }

  Future<void> _initAndNavigate() async {
    // Run splash animation for at least 2.5s while we check auth state
    await Future.wait([
      Future.delayed(const Duration(milliseconds: 2800)),
      _checkSession(),
    ]);
  }

  Future<void> _checkSession() async {
    try {
      // Restore JWT from disk into ApiService memory
      final session = await ApiService.init();

      if (!mounted) return;

      if (session != null) {
        // ✅ Returning user — skip registration entirely
        if (session.isCitizen) {
          Navigator.of(context).pushReplacement(
            PageRouteBuilder(
              transitionDuration: const Duration(milliseconds: 800),
              pageBuilder: (context, animation, _) => const CitizenDashboard(),
              transitionsBuilder: (context, animation, _, child) =>
                  FadeTransition(opacity: animation, child: child),
            ),
          );
        } else {
          // Hospital session
          Navigator.of(context).pushReplacement(
            PageRouteBuilder(
              transitionDuration: const Duration(milliseconds: 800),
              pageBuilder: (context, animation, _) => const HospitalDashboard(),
              transitionsBuilder: (context, animation, _, child) =>
                  FadeTransition(opacity: animation, child: child),
            ),
          );
        }
      } else {
        // 🆕 First-time user — show onboarding
        _goToOnboarding();
      }
    } catch (e, stack) {
      debugPrint('Error restoring session: $e\n$stack');
      if (mounted) {
        _goToOnboarding();
      }
    }
  }

  void _goToOnboarding() {
    Navigator.of(context).pushReplacement(
      PageRouteBuilder(
        transitionDuration: const Duration(milliseconds: 800),
        pageBuilder: (context, animation, _) => const OnboardingScreen(),
        transitionsBuilder: (context, animation, _, child) =>
            FadeTransition(opacity: animation, child: child),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          // 1. Subtle Background Gradient
          Container(
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                colors: [Colors.white, Color(0xFFF0FDFA)], // White to light teal
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
              ),
            ),
          ),

          // 2. Indian Tricolor Accent Line at the Top
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            child: SizedBox(
              height: 5,
              child: Row(
                children: [
                  Expanded(child: Container(color: const Color(0xFFFF9933))), // Saffron
                  Expanded(child: Container(color: Colors.white)),            // White
                  Expanded(child: Container(color: const Color(0xFF128807))), // Green
                ],
              ),
            ),
          ),

          // 3. Center Content (Logo, Brand Name, Tagline)
          Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                // Stylized heart + ECG + pulsing NFC wave logo
                Stack(
                  alignment: Alignment.center,
                  children: [
                    // Outer pulsing NFC ripples
                    ...List.generate(3, (index) {
                      return Container(
                        width: 140,
                        height: 140,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: AppTheme.accentTeal.withOpacity(0.2),
                            width: 2,
                          ),
                        ),
                      )
                          .animate(
                            onPlay: (controller) => controller.repeat(),
                          )
                          .scale(
                            begin: const Offset(0.8, 0.8),
                            end: const Offset(1.6, 1.6),
                            duration: 2000.ms,
                            delay: (index * 600).ms,
                            curve: Curves.easeOut,
                          )
                          .fade(
                            begin: 0.6,
                            end: 0.0,
                            duration: 2000.ms,
                            delay: (index * 600).ms,
                            curve: Curves.easeOut,
                          );
                    }),

                    // Central Logo
                    Container(
                      width: 110,
                      height: 110,
                      decoration: BoxDecoration(
                        color: Colors.white,
                        shape: BoxShape.circle,
                        boxShadow: [
                          BoxShadow(
                            color: AppTheme.accentTeal.withOpacity(0.15),
                            blurRadius: 24,
                            offset: const Offset(0, 8),
                          ),
                        ],
                      ),
                      padding: const EdgeInsets.all(20),
                      child: CustomPaint(
                        painter: HeartEcgLogoPainter(color: AppTheme.accentTeal),
                      ),
                    )
                        .animate()
                        .fade(duration: 800.ms)
                        .scale(
                          begin: const Offset(0.7, 0.7),
                          end: const Offset(1.0, 1.0),
                          duration: 800.ms,
                          curve: Curves.easeOutBack,
                        ),
                  ],
                ),
                const SizedBox(height: 24),

                // Brand Name
                Text(
                  'SwasthyaTap',
                  style: Theme.of(context).textTheme.displayLarge?.copyWith(
                        fontSize: 34,
                        fontWeight: FontWeight.bold,
                        color: AppTheme.accentTeal,
                        letterSpacing: -0.5,
                      ),
                )
                    .animate()
                    .fade(delay: 200.ms, duration: 600.ms)
                    .slideY(begin: 0.1, end: 0, duration: 600.ms),

                // Hindi Subtitle
                Text(
                  'आपकी स्वास्थ्य पहचान',
                  style: TextStyle(
                    fontFamily: 'NotoSans',
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                    color: AppTheme.textSecondary.withOpacity(0.8),
                    letterSpacing: 0.5,
                  ),
                )
                    .animate()
                    .fade(delay: 350.ms, duration: 600.ms)
                    .slideY(begin: 0.1, end: 0, duration: 600.ms),

                const SizedBox(height: 16),

                // Tagline
                Text(
                  'One Tap Can Save Your Life',
                  style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                        color: AppTheme.textSecondary,
                        fontSize: 15,
                        fontWeight: FontWeight.w500,
                      ),
                )
                    .animate()
                    .fade(delay: 500.ms, duration: 600.ms)
                    .slideY(begin: 0.1, end: 0, duration: 600.ms),
              ],
            ),
          ),

          // 4. Bottom Watermark
          Positioned(
            bottom: 30,
            left: 0,
            right: 0,
            child: Center(
              child: Column(
                children: [
                  Text(
                    'By SwasthyaTap',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: AppTheme.textSecondary.withOpacity(0.6),
                      letterSpacing: 0.8,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.favorite_rounded, size: 10, color: AppTheme.accentRed),
                      const SizedBox(width: 4),
                      Text(
                        'Made in India, For India',
                        style: TextStyle(
                          fontSize: 9,
                          fontWeight: FontWeight.bold,
                          color: AppTheme.textSecondary.withOpacity(0.4),
                          letterSpacing: 0.5,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            )
                .animate()
                .fade(delay: 800.ms, duration: 600.ms),
          ),
        ],
      ),
    );
  }
}

class HeartEcgLogoPainter extends CustomPainter {
  final Color color;

  HeartEcgLogoPainter({required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 4.0
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;

    final width = size.width;
    final height = size.height;

    // Draw outline heart path
    final heartPath = Path();
    heartPath.moveTo(width / 2, height * 0.85);
    // Left side of the heart
    heartPath.cubicTo(
      width * 0.05, height * 0.55,
      width * 0.02, height * 0.18,
      width * 0.3, height * 0.14
    );
    heartPath.cubicTo(
      width * 0.45, height * 0.12,
      width / 2, height * 0.32,
      width / 2, height * 0.32
    );
    // Right side of the heart
    heartPath.cubicTo(
      width / 2, height * 0.32,
      width * 0.55, height * 0.12,
      width * 0.7, height * 0.14
    );
    heartPath.cubicTo(
      width * 0.98, height * 0.18,
      width * 0.95, height * 0.55,
      width / 2, height * 0.85
    );
    canvas.drawPath(heartPath, paint);

    // Draw ECG heartbeat spike in the center of the heart
    final ecgPath = Path();
    ecgPath.moveTo(width * 0.22, height * 0.48);
    ecgPath.lineTo(width * 0.38, height * 0.48);
    ecgPath.lineTo(width * 0.42, height * 0.32); // small up
    ecgPath.lineTo(width * 0.47, height * 0.65); // down spike
    ecgPath.lineTo(width * 0.52, height * 0.22); // main up spike
    ecgPath.lineTo(width * 0.57, height * 0.54); // down
    ecgPath.lineTo(width * 0.61, height * 0.48); // return
    ecgPath.lineTo(width * 0.78, height * 0.48);
    canvas.drawPath(ecgPath, paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
