import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../providers/swasthya_tap_provider.dart';
import '../theme/app_theme.dart';
import 'citizen_portal/registration_screen.dart';
import 'hospital_portal/hospital_login_screen.dart';
import 'onboarding_screen.dart';

import '../utils/translation_service.dart';

class RoleSelectionScreen extends StatefulWidget {
  const RoleSelectionScreen({Key? key}) : super(key: key);

  @override
  State<RoleSelectionScreen> createState() => _RoleSelectionScreenState();
}

class _RoleSelectionScreenState extends State<RoleSelectionScreen> {
  String _selectedLanguage = "English";
  final List<Map<String, String>> _languages = [
    {"name": "English", "native": "English"},
    {"name": "Hindi", "native": "हिंदी"},
    {"name": "Bengali", "native": "বাংলা"},
    {"name": "Telugu", "native": "తెలుగు"},
    {"name": "Tamil", "native": "தமிழ்"},
    {"name": "Marathi", "native": "मराठी"},
    {"name": "Gujarati", "native": "ગુજરાતી"},
    {"name": "Kannada", "native": "ಕನ್ನಡ"},
    {"name": "Malayalam", "native": "മലയാളം"},
    {"name": "Punjabi", "native": "ਪੰਜਾਬੀ"},
    {"name": "Odia", "native": "ଓଡ଼ିଆ"},
    {"name": "Urdu", "native": "اردو"},
    {"name": "Assamese", "native": "অসমীয়া"},
  ];

  String _t(String key) {
    return TranslationService.t(context, key);
  }

  @override
  Widget build(BuildContext context) {
    final provider = Provider.of<SwasthyaTapProvider>(context);
    _selectedLanguage = provider.selectedLanguage;

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC), // sleek light grey background matching the mockup
      body: Stack(
        children: [
          // 1. Indian Tricolor Accent Line at the Top
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

          SafeArea(
            child: Column(
              children: [
                // 2. Top Header Toolbar (Logo + Language Picker)
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      // Mini Brand Logo (SwasthyaTap.in with heart/ECG logo)
                      Row(
                        children: [
                          IconButton(
                            onPressed: () {
                              if (Navigator.canPop(context)) {
                                Navigator.pop(context);
                              } else {
                                Navigator.pushReplacement(
                                  context,
                                  MaterialPageRoute(builder: (_) => const OnboardingScreen()),
                                );
                              }
                            },
                            icon: const Icon(Icons.arrow_back_rounded, color: Color(0xFF0F766E), size: 22),
                            padding: EdgeInsets.zero,
                            constraints: const BoxConstraints(),
                          ),
                          Stack(
                            alignment: Alignment.center,
                            children: [
                              const Icon(
                                Icons.favorite_outline_rounded,
                                color: Color(0xFF0F766E),
                                size: 24,
                              ),
                              Positioned(
                                right: -2,
                                top: -2,
                                child: Icon(
                                  Icons.wifi,
                                  color: const Color(0xFF0F766E).withOpacity(0.5),
                                  size: 10,
                                ),
                              )
                            ],
                          ),
                          const SizedBox(width: 8),
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: const [
                              Text(
                                "SwasthyaTap.in",
                                style: TextStyle(
                                  fontWeight: FontWeight.w900,
                                  fontSize: 15,
                                  color: Color(0xFF0F766E),
                                  letterSpacing: 0.2,
                                ),
                              ),
                              Text(
                                "One Tap Can Save Your Life",
                                style: TextStyle(
                                  fontSize: 8,
                                  fontWeight: FontWeight.w700,
                                  color: Colors.black38,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),

                      // Language Switcher Dropdown
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(color: Colors.grey.shade200),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.04),
                              blurRadius: 6,
                              offset: const Offset(0, 2),
                            ),
                          ],
                        ),
                        child: DropdownButtonHideUnderline(
                          child: DropdownButton<String>(
                            value: _selectedLanguage,
                            icon: const Icon(
                              Icons.keyboard_arrow_down_rounded,
                              size: 16,
                              color: Colors.black54,
                            ),
                            dropdownColor: Colors.white,
                            style: const TextStyle(
                              color: Colors.black87,
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                            ),
                            selectedItemBuilder: (BuildContext context) {
                              return _languages.map<Widget>((lang) {
                                return Row(
                                  children: [
                                    const Icon(
                                      Icons.language_outlined,
                                      size: 14,
                                      color: Colors.black54,
                                    ),
                                    const SizedBox(width: 4),
                                    Text(lang["name"]!),
                                  ],
                                );
                              }).toList();
                            },
                            onChanged: (String? newValue) {
                              if (newValue != null) {
                                provider.setSelectedLanguage(newValue);
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                    content: Text(
                                      _getLanguageToast(newValue),
                                      style: const TextStyle(fontWeight: FontWeight.bold),
                                    ),
                                    backgroundColor: const Color(0xFF0F766E),
                                    behavior: SnackBarBehavior.floating,
                                    duration: const Duration(seconds: 2),
                                  ),
                                );
                              }
                            },
                            items: _languages.map<DropdownMenuItem<String>>((lang) {
                              return DropdownMenuItem<String>(
                                value: lang["name"],
                                child: Row(
                                  children: [
                                    Text(lang["native"]!),
                                    const SizedBox(width: 6),
                                    if (lang["name"] != lang["native"])
                                      Text(
                                        "(${lang["name"]})",
                                        style: const TextStyle(color: Colors.black38, fontSize: 10),
                                      ),
                                  ],
                                ),
                              );
                            }).toList(),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 8),

                // 3. Central Titles
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 24),
                  child: Column(
                    children: [
                      RichText(
                        textAlign: TextAlign.center,
                        text: TextSpan(
                          style: GoogleFonts.poppins(
                            fontSize: 25,
                            fontWeight: FontWeight.w800,
                            height: 1.3,
                            color: const Color(0xFF1E293B),
                          ),
                          children: [
                            TextSpan(text: _t('how_to_use')),
                            const TextSpan(
                              text: "SwasthyaTap",
                              style: TextStyle(color: Color(0xFF0F766E)),
                            ),
                            const TextSpan(text: "?"),
                          ],
                        ),
                      )
                          .animate()
                          .fade(duration: 500.ms)
                          .slideY(begin: 0.1, end: 0, duration: 500.ms),
                      const SizedBox(height: 8),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Container(width: 40, height: 1, color: Colors.grey.shade300),
                          const Padding(
                            padding: EdgeInsets.symmetric(horizontal: 8),
                            child: Icon(
                              Icons.favorite_rounded,
                              color: Color(0xFF0F766E),
                              size: 14,
                            ),
                          ),
                          Container(width: 40, height: 1, color: Colors.grey.shade300),
                        ],
                      )
                          .animate()
                          .fade(delay: 150.ms, duration: 500.ms),
                      const SizedBox(height: 6),
                      Text(
                        _t('choose_role'),
                        style: GoogleFonts.poppins(
                          color: Colors.black54,
                          fontSize: 12.5,
                          fontWeight: FontWeight.w500,
                        ),
                      )
                          .animate()
                          .fade(delay: 200.ms, duration: 500.ms),
                    ],
                  ),
                ),

                const Spacer(),

                // 4. Role Selection Cards Side-by-Side in Row
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: Row(
                    children: [
                      Expanded(child: _buildCitizenCard(context)),
                      const SizedBox(width: 14),
                      Expanded(child: _buildHospitalCard(context)),
                    ],
                  ),
                ),

                const Spacer(),

                // 5. Secure Trust Badge
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 24),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: Colors.grey.shade100),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.02),
                          blurRadius: 10,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: Row(
                      children: [
                        const Icon(
                          Icons.verified_user_rounded,
                          color: Color(0xFF0F766E),
                          size: 24,
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                _t('secure_title'),
                                style: GoogleFonts.poppins(
                                  color: const Color(0xFF1E293B),
                                  fontSize: 11,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                _t('secure_sub'),
                                style: GoogleFonts.poppins(
                                  color: Colors.black45,
                                  fontSize: 9.5,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  )
                      .animate()
                      .fade(delay: 500.ms, duration: 500.ms)
                      .slideY(begin: 0.1, end: 0, duration: 500.ms),
                ),

                const SizedBox(height: 20),

                // 6. Footer section (Tricolor + brand logo)
                Stack(
                  alignment: Alignment.center,
                  clipBehavior: Clip.none,
                  children: [
                    // Bottom-left tricolor accent curve simulation
                    Positioned(
                      left: -20,
                      bottom: -20,
                      child: Opacity(
                        opacity: 0.85,
                        child: CustomPaint(
                          size: const Size(120, 60),
                          painter: TricolorWavePainter(),
                        ),
                      ),
                    ),
                    
                    Column(
                      children: [
                        const Icon(
                          Icons.favorite_outline_rounded,
                          color: Color(0xFF0F766E),
                          size: 22,
                        ),
                        const SizedBox(height: 4),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text(
                              _t('made_in_india'),
                              style: const TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.w700,
                                color: Colors.black45,
                              ),
                            ),
                            Text("🇮🇳", style: TextStyle(fontSize: 11)),
                          ],
                        ),
                      ],
                    )
                        .animate()
                        .fade(delay: 600.ms, duration: 500.ms),
                  ],
                ),

                const SizedBox(height: 12),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCitizenCard(BuildContext context) {
    return _InteractiveRoleCard(
      imageUrl: 'assets/citizen_card.webp',
      title: _t('citizen_title'),
      description: _t('citizen_desc'),
      onTap: () {
        Navigator.push(
          context,
          PageRouteBuilder(
            transitionDuration: const Duration(milliseconds: 500),
            pageBuilder: (context, animation, secondaryAnimation) => const RegistrationScreen(),
            transitionsBuilder: (context, animation, secondaryAnimation, child) {
              return SlideTransition(
                position: Tween<Offset>(
                  begin: const Offset(1, 0),
                  end: Offset.zero,
                ).animate(CurvedAnimation(parent: animation, curve: Curves.easeOutCubic)),
                child: child,
              );
            },
          ),
        );
      },
    )
        .animate()
        .fade(delay: 300.ms, duration: 600.ms)
        .slideY(begin: 0.1, end: 0, duration: 600.ms);
  }

  Widget _buildHospitalCard(BuildContext context) {
    return _InteractiveRoleCard(
      imageUrl: 'assets/hospital_card.webp',
      title: _t('hospital_title'),
      description: _t('hospital_desc'),
      onTap: () {
        Navigator.push(
          context,
          PageRouteBuilder(
            transitionDuration: const Duration(milliseconds: 500),
            pageBuilder: (context, animation, secondaryAnimation) => HospitalLoginScreen(),
            transitionsBuilder: (context, animation, secondaryAnimation, child) {
              return SlideTransition(
                position: Tween<Offset>(
                  begin: const Offset(1, 0),
                  end: Offset.zero,
                ).animate(CurvedAnimation(parent: animation, curve: Curves.easeOutCubic)),
                child: child,
              );
            },
          ),
        );
      },
    )
        .animate()
        .fade(delay: 400.ms, duration: 600.ms)
        .slideY(begin: 0.1, end: 0, duration: 600.ms);
  }

  String _getLanguageToast(String lang) {
    switch (lang) {
      case "Hindi":
        return "भाषा हिंदी में सेट की गई";
      case "Bengali":
        return "ভাষা বাংলায় সেট করা হয়েছে";
      case "Tamil":
        return "மொழி தமிழில் அமைக்கப்பட்டுள்ளது";
      case "Telugu":
        return "భాష తెలుగులో సెట్ చేయబడింది";
      case "Marathi":
        return "भाषा मराठीमध्ये सेट केली आहे";
      case "Gujarati":
        return "ભાષા ગુજરાતીમાં સેટ કરેલી છે";
      case "Kannada":
        return "ಭಾಷೆಯನ್ನು ಕನ್ನಡಕ್ಕೆ ಹೊಂದಿಸಲಾಗಿದೆ";
      case "Malayalam":
        return "ഭാഷ മലയാളത്തിലേക്ക് സജ്ജമാക്കി";
      case "Punjabi":
        return "ਭਾਸ਼ਾ ਪੰਜਾਬੀ ਵਿੱਚ ਸੈੱਟ ਕੀਤੀ ਗਈ ਹੈ";
      case "Odia":
        return "ଭାଷା ଓଡ଼ିଆରେ ସେଟ୍ ହୋଇଛି";
      case "Urdu":
        return "زبان اردو میں سیٹ کی گئی ہے";
      default:
        return "Language set to English";
    }
  }
}

class _InteractiveRoleCard extends StatefulWidget {
  final String imageUrl;
  final String title;
  final String description;
  final VoidCallback onTap;

  const _InteractiveRoleCard({
    Key? key,
    required this.imageUrl,
    required this.title,
    required this.description,
    required this.onTap,
  }) : super(key: key);

  @override
  State<_InteractiveRoleCard> createState() => _InteractiveRoleCardState();
}

class _InteractiveRoleCardState extends State<_InteractiveRoleCard> {
  bool _isPressed = false;

  @override
  Widget build(BuildContext context) {
    final isCitizen = widget.imageUrl.contains('citizen_card');
    final primaryColor = isCitizen ? const Color(0xFF0F766E) : const Color(0xFF1E40AF);

    return GestureDetector(
      onTapDown: (_) => setState(() => _isPressed = true),
      onTapUp: (_) => setState(() => _isPressed = false),
      onTapCancel: () => setState(() => _isPressed = false),
      onTap: widget.onTap,
      child: AnimatedScale(
        scale: _isPressed ? 0.96 : 1.0,
        duration: const Duration(milliseconds: 150),
        child: Container(
          height: 380,
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(24),
            border: Border.all(color: const Color(0xFFF1F5F9), width: 1.5),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.04),
                blurRadius: 16,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(24),
            child: Stack(
              children: [
                // 1. Background Gradient (Top portion of the card is colorful, fading to white at the bottom)
                Positioned.fill(
                  child: Container(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: isCitizen
                            ? [
                                const Color(0xFFCCFBF1).withOpacity(0.85), // Teal-tinted top
                                Colors.white,
                              ]
                            : [
                                const Color(0xFFDBEAFE).withOpacity(0.85), // Blue-tinted top
                                Colors.white,
                              ],
                        stops: const [0.35, 0.75],
                      ),
                    ),
                  ),
                ),

                // 2. Main content column
                Positioned.fill(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        const SizedBox(height: 28), // spacer for the badge at top left

                        // Illustration Image — bigger, no padding
                        Expanded(
                          flex: 4,
                          child: Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 4),
                            child: Image.asset(
                              widget.imageUrl,
                              fit: BoxFit.contain,
                              width: double.infinity,
                              errorBuilder: (context, error, stackTrace) {
                                return Icon(
                                  isCitizen ? Icons.people_outline_rounded : Icons.local_hospital_rounded,
                                  size: 80,
                                  color: primaryColor.withOpacity(0.2),
                                );
                              },
                            ),
                          ),
                        ),
                        
                        const SizedBox(height: 12),

                        // Title Text
                        Text(
                          widget.title,
                          textAlign: TextAlign.center,
                          style: GoogleFonts.poppins(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: primaryColor,
                          ),
                        ),
                        
                        const SizedBox(height: 8),

                        // Description Text
                        Text(
                          widget.description,
                          textAlign: TextAlign.center,
                          maxLines: 4,
                          style: GoogleFonts.poppins(
                            fontSize: 10.5,
                            fontWeight: FontWeight.w500,
                            color: const Color(0xFF64748B),
                            height: 1.35,
                          ),
                        ),
                        
                        const SizedBox(height: 16),

                        // Circular Arrow Button
                        Container(
                          width: 36,
                          height: 36,
                          decoration: BoxDecoration(
                            color: primaryColor,
                            shape: BoxShape.circle,
                            boxShadow: [
                              BoxShadow(
                                color: primaryColor.withOpacity(0.25),
                                blurRadius: 8,
                                offset: const Offset(0, 4),
                              ),
                            ],
                          ),
                          child: const Icon(
                            Icons.chevron_right_rounded,
                            color: Colors.white,
                            size: 20,
                          ),
                        ),
                        const SizedBox(height: 4),
                      ],
                    ),
                  ),
                ),

                // 3. Top-Left Floating Circle Badge
                Positioned(
                  top: 12,
                  left: 12,
                  child: Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.06),
                          blurRadius: 8,
                          offset: const Offset(0, 3),
                        ),
                      ],
                    ),
                    child: Icon(
                      isCitizen ? Icons.verified_user_rounded : Icons.domain_rounded,
                      color: primaryColor,
                      size: 20,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class RoleTricolorWavesPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    double w = size.width;
    double h = size.height;

    // Indian Flag Colors
    const saffron = Color(0xFFFF671F);
    const white = Colors.white;
    const green = Color(0xFF046A38);

    final saffronPath = Path()
      ..moveTo(w * 0.45, h)
      ..quadraticBezierTo(w * 0.72, h - 36, w, h - 23)
      ..lineTo(w, h - 31.5)
      ..quadraticBezierTo(w * 0.72, h - 44.5, w * 0.45, h)
      ..close();

    final whitePath = Path()
      ..moveTo(w * 0.47, h)
      ..quadraticBezierTo(w * 0.73, h - 28, w, h - 15)
      ..lineTo(w, h - 23)
      ..quadraticBezierTo(w * 0.72, h - 36, w * 0.45, h)
      ..close();

    final greenPath = Path()
      ..moveTo(w * 0.50, h)
      ..quadraticBezierTo(w * 0.74, h - 20, w, h - 6.5)
      ..lineTo(w, h - 15)
      ..quadraticBezierTo(w * 0.73, h - 28, w * 0.47, h)
      ..close();

    canvas.drawPath(saffronPath, Paint()..color = saffron..style = PaintingStyle.fill);
    canvas.drawPath(whitePath, Paint()..color = white..style = PaintingStyle.fill);
    canvas.drawPath(greenPath, Paint()..color = green..style = PaintingStyle.fill);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class RoleNfcWavePainter extends CustomPainter {
  final Color color;
  RoleNfcWavePainter({required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.0
      ..strokeCap = StrokeCap.round;

    final rect1 = Rect.fromCircle(center: Offset(size.width, size.height / 2), radius: 12);
    canvas.drawArc(rect1, 2.3, 1.68, false, paint);

    final rect2 = Rect.fromCircle(center: Offset(size.width, size.height / 2), radius: 20);
    canvas.drawArc(rect2, 2.3, 1.68, false, paint);

    final rect3 = Rect.fromCircle(center: Offset(size.width, size.height / 2), radius: 28);
    canvas.drawArc(rect3, 2.3, 1.68, false, paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class RoleHeartEcgPainter extends CustomPainter {
  final Color color;
  RoleHeartEcgPainter({required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.5
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;

    final w = size.width;
    final h = size.height;

    final ecgPath = Path()
      ..moveTo(w * 0.15, h * 0.5)
      ..lineTo(w * 0.35, h * 0.5)
      ..lineTo(w * 0.42, h * 0.35)
      ..lineTo(w * 0.50, h * 0.70)
      ..lineTo(w * 0.58, h * 0.20)
      ..lineTo(w * 0.65, h * 0.55)
      ..lineTo(w * 0.72, h * 0.5)
      ..lineTo(w * 0.85, h * 0.5);

    final heartPath = Path()
      ..moveTo(w * 0.5, h * 0.25)
      ..cubicTo(w * 0.2, h * 0.05, 0, h * 0.3, w * 0.5, h * 0.85)
      ..cubicTo(w, h * 0.3, w * 0.8, h * 0.05, w * 0.5, h * 0.25);

    canvas.drawPath(heartPath, paint);
    canvas.drawPath(ecgPath, paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class RoleQrPainter extends CustomPainter {
  final Color color;
  RoleQrPainter({required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.fill;

    double u = size.width / 8;

    canvas.drawRect(Rect.fromLTWH(0, 0, 3 * u, u), paint);
    canvas.drawRect(Rect.fromLTWH(0, 0, u, 3 * u), paint);
    canvas.drawRect(Rect.fromLTWH(2 * u, 0, u, 3 * u), paint);
    canvas.drawRect(Rect.fromLTWH(0, 2 * u, 3 * u, u), paint);

    canvas.drawRect(Rect.fromLTWH(5 * u, 0, 3 * u, u), paint);
    canvas.drawRect(Rect.fromLTWH(5 * u, 0, u, 3 * u), paint);
    canvas.drawRect(Rect.fromLTWH(7 * u, 0, u, 3 * u), paint);
    canvas.drawRect(Rect.fromLTWH(5 * u, 2 * u, 3 * u, u), paint);

    canvas.drawRect(Rect.fromLTWH(0, 5 * u, 3 * u, u), paint);
    canvas.drawRect(Rect.fromLTWH(0, 5 * u, u, 3 * u), paint);
    canvas.drawRect(Rect.fromLTWH(2 * u, 5 * u, u, 3 * u), paint);
    canvas.drawRect(Rect.fromLTWH(0, 7 * u, 3 * u, u), paint);

    canvas.drawRect(Rect.fromLTWH(4 * u, 1 * u, u, u), paint);
    canvas.drawRect(Rect.fromLTWH(1 * u, 4 * u, u, u), paint);
    canvas.drawRect(Rect.fromLTWH(4 * u, 4 * u, 2 * u, u), paint);
    canvas.drawRect(Rect.fromLTWH(6 * u, 5 * u, u, 2 * u), paint);
    canvas.drawRect(Rect.fromLTWH(4 * u, 7 * u, 2 * u, u), paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

// Custom Painter for the tricolor swoop wave at the bottom left
class TricolorWavePainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..style = PaintingStyle.fill;

    // Saffron path
    final pathSaffron = Path()
      ..moveTo(0, size.height)
      ..quadraticBezierTo(size.width * 0.4, size.height * 0.9, size.width * 0.6, size.height * 0.3)
      ..quadraticBezierTo(size.width * 0.75, size.height * 0.05, size.width, 0)
      ..lineTo(0, 0)
      ..close();
    paint.color = const Color(0xFFFF9933).withOpacity(0.2);
    canvas.drawPath(pathSaffron, paint);

    // Green path
    final pathGreen = Path()
      ..moveTo(0, size.height)
      ..quadraticBezierTo(size.width * 0.5, size.height * 0.95, size.width * 0.8, size.height * 0.5)
      ..quadraticBezierTo(size.width * 0.9, size.height * 0.2, size.width, 0.1)
      ..lineTo(0, 0)
      ..close();
    paint.color = const Color(0xFF128807).withOpacity(0.2);
    canvas.drawPath(pathGreen, paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
