import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:provider/provider.dart';
import '../../providers/swasthya_tap_provider.dart';
import '../../models/models.dart';
import '../../theme/app_theme.dart';
import 'citizen_dashboard.dart';
import 'profile_setup_screen.dart';
import '../../utils/translation_service.dart';
import '../../services/api_service.dart';

class RegistrationScreen extends StatefulWidget {
  const RegistrationScreen({Key? key}) : super(key: key);

  @override
  State<RegistrationScreen> createState() => _RegistrationScreenState();
}

class _RegistrationScreenState extends State<RegistrationScreen> {
  final _phoneController = TextEditingController();
  final List<TextEditingController> _otpControllers = List.generate(4, (_) => TextEditingController());
  final List<FocusNode> _otpFocusNodes = List.generate(4, (_) => FocusNode());
  
  bool _otpSent = false;
  bool _isLoading = false;
  int _secondsRemaining = 30;
  Timer? _timer;

  String _selectedLanguage = 'English';

  static const Map<String, Map<String, String>> _localizations = {
    'English': {
      'welcome': 'Welcome to SwasthyaTap',
      'verification_sub': 'Your health card is just one verification away',
      'mobile_number': 'Mobile Number',
      'enter_hint': 'Enter 10-digit number',
      'send_otp': 'Send OTP',
      'login_abha': 'Login with ABHA ID',
      'enter_otp': 'Enter OTP',
      'sent_to': 'Sent to +91',
      'resend_in': 'Resend OTP in 0:',
      'didnt_receive': 'Didn\'t receive OTP?',
      'resend_btn': 'Resend OTP',
      'verify_register': 'Verify & Register',
      'change_mobile': 'Change Mobile Number',
      'secure_header': '100% SECURE & ENCRYPTED',
      'agree_terms': 'By continuing, you agree to our Terms of Service & Privacy Policy',
      'error_10digit': 'Please enter a valid 10-digit mobile number',
      'otp_sent_msg': 'OTP sent successfully (Simulated: 1234)',
      'enter_4digit': 'Please enter the 4-digit OTP',
    },
    'Hindi': {
      'welcome': 'स्वस्थटैप में आपका स्वागत है',
      'verification_sub': 'आपका स्वास्थ्य कार्ड केवल एक सत्यापन दूर है',
      'mobile_number': 'मोबाइल नंबर',
      'enter_hint': '10-अंकों का नंबर दर्ज करें',
      'send_otp': 'ओटीपी भेजें',
      'login_abha': 'ABHA आईडी के साथ लॉगिन करें',
      'enter_otp': 'ओटीपी दर्ज करें',
      'sent_to': 'भेजा गया +91',
      'resend_in': 'ओटीपी पुनः भेजें 0:',
      'didnt_receive': 'ओटीपी प्राप्त नहीं हुआ?',
      'resend_btn': 'ओटीपी पुनः भेजें',
      'verify_register': 'सत्यापित करें और पंजीकरण करें',
      'change_mobile': 'मोबाइल नंबर बदलें',
      'secure_header': '100% सुरक्षित और एन्क्रिप्टेड',
      'agree_terms': 'जारी रखने से, आप हमारी सेवा की शर्तों और गोपनीयता नीति से सहमत होते हैं',
      'error_10digit': 'कृपया एक वैध 10-अंकों का मोबाइल नंबर दर्ज करें',
      'otp_sent_msg': 'ओटीपी सफलतापूर्वक भेजा गया (सिम्युलेटेड: 1234)',
      'enter_4digit': 'कृपया 4-अंकों का ओटीपी दर्ज करें',
    },
    'Bengali': {
      'welcome': 'SwasthyaTap-এ আপনাকে স্বাগতম',
      'verification_sub': 'আপনার স্বাস্থ্য কার্ড মাত্র একটি যাচাইকরণ দূরে',
      'mobile_number': 'মোবাইল নম্বর',
      'enter_hint': '১০-ডিজিটের নম্বর লিখুন',
      'send_otp': 'ওটিপি পাঠান',
      'login_abha': 'ABHA আইডি দিয়ে লগইন করুন',
      'enter_otp': 'ওটিপি লিখুন',
      'sent_to': '+91 নম্বরে পাঠানো হয়েছে',
      'resend_in': 'ওটিপি পুনরায় পাঠান ০:',
      'didnt_receive': 'ওটিপি পাননি?',
      'resend_btn': 'ওটিপি পুনরায় পাঠান',
      'verify_register': 'যাচাই করুন এবং নিবন্ধন করুন',
      'change_mobile': 'মোবাইল নম্বর পরিবর্তন করুন',
      'secure_header': '১০০% নিরাপদ এবং এনক্রিপ্ট করা',
      'agree_terms': 'অব্যাহত রেখে, আপনি আমাদের পরিষেবার শর্তাবলী এবং গোপনীয়তা নীতিতে সম্মত হন',
      'error_10digit': 'অনুগ্রহ করে একটি সঠিক ১০-ডিজিটের মোবাইল নম্বর লিখুন',
      'otp_sent_msg': 'ওটিপি সফলভাবে পাঠানো হয়েছে (সিমুলেটেড: 1234)',
      'enter_4digit': 'অনুগ্রহ করে ৪-ডিজিটের ওটিপি লিখুন',
    },
    'Tamil': {
      'welcome': 'SwasthyaTap-க்கு உங்களை வரவேற்கிறோம்',
      'verification_sub': 'உங்கள் சுகாதார அட்டை ஒரு சரிபார்ப்பு தொலைவில் உள்ளது',
      'mobile_number': 'கைபேசி எண்',
      'enter_hint': '10 இலக்க எண்ணை உள்ளிடவும்',
      'send_otp': 'OTP அனுப்பவும்',
      'login_abha': 'ABHA ஐடி மூலம் உள்நுழைக',
      'enter_otp': 'OTP ஐ உள்ளிடவும்',
      'sent_to': '+91-க்கு அனுப்பப்பட்டது',
      'resend_in': 'OTP-ஐ மீண்டும் அனுப்பவும் 0:',
      'didnt_receive': 'OTP வரவில்லையா?',
      'resend_btn': 'OTP-ஐ மீண்டும் அனுப்பவும்',
      'verify_register': 'சரிபார்த்து பதிவு செய்யவும்',
      'change_mobile': 'கைபேசி எண்ணை மாற்றவும்',
      'secure_header': '100% பாதுகாப்பானது & குறியாக்கம் செய்யப்பட்டது',
      'agree_terms': 'தொடர்வதன் மூலம், எங்கள் சேவை விதிமுறைகள் & தனியுரிமைக் கொள்கையை ஏற்கிறீர்கள்',
      'error_10digit': 'தயவுசெய்து செல்லுபடியாகும் 10 இலக்க மொபைல் எண்ணை உள்ளிடவும்',
      'otp_sent_msg': 'OTP வெற்றிகரமாக அனுப்பப்பட்டது (உருவகப்படுத்தப்பட்டது: 1234)',
      'enter_4digit': 'தயவுசெய்து 4 இலக்க OTP ஐ உள்ளிடவும்',
    },
    'Telugu': {
      'welcome': 'SwasthyaTap కి స్వాగతం',
      'verification_sub': 'మీ ఆరోగ్య కార్డ్ కేవలం ఒక ధృవీకరణ దూరంలో ఉంది',
      'mobile_number': 'మొబైల్ సంఖ్య',
      'enter_hint': '10-అంకెల సంఖ్యను నమోదు చేయండి',
      'send_otp': 'OTP పంపండి',
      'login_abha': 'ABHA ID తో లాగిన్ అవ్వండి',
      'enter_otp': 'OTP ని నమోదు చేయండి',
      'sent_to': '+91 కి పంపబడింది',
      'resend_in': 'OTP ని మళ్లీ పంపండి 0:',
      'didnt_receive': 'OTP రాలేదా?',
      'resend_btn': 'OTP ని మళ్లీ పంపండి',
      'verify_register': 'ధృవీకరించి నమోదు చేసుకోండి',
      'change_mobile': 'మొబైల్ సంఖ్యను మార్చండి',
      'secure_header': '100% సురక్షితం & ఎన్‌క్రిప్ట్ చేయబడింది',
      'agree_terms': 'కొనసాగడం ద్వారా, మీరు మా సేవా నిబంధనలు & గోప్యతా విధానానికి అంగీకరిస్తున్నారు',
      'error_10digit': 'దయచేసి సరైన 10-అంకెల మొபைల్ సంఖ్యను నమోదు చేయండి',
      'otp_sent_msg': 'OTP విజయవంతంగా పంపబడింది (సిమ్యులేటెడ్: 1234)',
      'enter_4digit': 'దయచేసి 4-అంకెల OTP ని నమోదు చేయండి',
    }
  };

  String _t(String key) {
    if (_localizations.containsKey(_selectedLanguage) &&
        _localizations[_selectedLanguage]!.containsKey(key)) {
      return _localizations[_selectedLanguage]![key]!;
    }
    return TranslationService.t(context, key);
  }

  @override
  void dispose() {
    _phoneController.dispose();
    for (var c in _otpControllers) {
      c.dispose();
    }
    for (var f in _otpFocusNodes) {
      f.dispose();
    }
    _timer?.cancel();
    super.dispose();
  }

  void _startTimer() {
    _secondsRemaining = 30;
    _timer?.cancel();
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      setState(() {
        if (_secondsRemaining > 0) {
          _secondsRemaining--;
        } else {
          _timer?.cancel();
        }
      });
    });
  }

  void _sendOtp() async {
    final phone = _phoneController.text.trim();
    final phoneRegex = RegExp(r'^[0-9]{10}$');
    if (!phoneRegex.hasMatch(phone)) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(_t('error_10digit')),
          backgroundColor: AppTheme.accentRed,
        ),
      );
      return;
    }
    setState(() => _isLoading = true);

    try {
      final result = await ApiService.sendOtp(phone);
      if (!mounted) return;
      setState(() {
        _isLoading = false;
        _otpSent = true;
      });
      _startTimer();
      FocusScope.of(context).requestFocus(_otpFocusNodes[0]);

      // Show OTP in snackbar during development
      final devOtp = result['devOtp'] as String?;
      final isOffline = result['offline'] == true;
      final msg = isOffline
          ? 'Server offline — use OTP: ${devOtp ?? "1234"}'
          : (devOtp != null
              ? 'OTP sent! (Dev mode — OTP: $devOtp)'
              : _t('otp_sent_msg'));

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(msg),
          backgroundColor: AppTheme.accentTeal,
          duration: const Duration(seconds: 5),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      setState(() => _isLoading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to send OTP. Please try again.'),
          backgroundColor: AppTheme.accentRed,
        ),
      );
    }
  }

  void _verifyOtp() async {
    String otp = _otpControllers.map((c) => c.text).join();
    if (otp.length < 4) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(_t('enter_4digit')),
          backgroundColor: AppTheme.accentRed,
        ),
      );
      return;
    }

    setState(() => _isLoading = true);

    try {
      final result = await ApiService.verifyOtp(
        _phoneController.text.trim(),
        otp,
      );

      if (!mounted) return;
      setState(() => _isLoading = false);

      if (result['success'] == true) {
        final citizen = result['citizen'] as MedicalProfile;
        
        // Seed the provider
        final provider = Provider.of<SwasthyaTapProvider>(context, listen: false);
        provider.loginCitizen(citizen);

        final isNewUser = result['isNewUser'] == true;
        if (isNewUser) {
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(builder: (_) => ProfileSetupScreen(citizen: citizen)),
          );
        } else {
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(builder: (_) => const CitizenDashboard()),
          );
        }
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(result['message'] as String? ?? 'Verification failed'),
            backgroundColor: AppTheme.accentRed,
          ),
        );
      }
    } catch (e) {
      if (!mounted) return;
      setState(() => _isLoading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Verification failed. Please try again.'),
          backgroundColor: AppTheme.accentRed,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final provider = Provider.of<SwasthyaTapProvider>(context);
    _selectedLanguage = provider.selectedLanguage;

    return Scaffold(
      backgroundColor: AppTheme.lightBg,
      body: Stack(
        children: [
          // Tricolor Line at Top
          Positioned(
            top: 0, left: 0, right: 0,
            child: SizedBox(
              height: 5,
              child: Row(
                children: [
                  Expanded(child: Container(color: const Color(0xFFFF9933))),
                  Expanded(child: Container(color: Colors.white)),
                  Expanded(child: Container(color: const Color(0xFF128807))),
                ],
              ),
            ),
          ),

          SafeArea(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const SizedBox(height: 16),
                  // Back button
                  IconButton(
                    onPressed: () => Navigator.pop(context),
                    icon: const Icon(Icons.arrow_back_rounded, color: AppTheme.textPrimary),
                    style: IconButton.styleFrom(
                      backgroundColor: Colors.white,
                      elevation: 1,
                    ),
                  ),
                  
                  const SizedBox(height: 30),
                  
                  // Logo + Heading
                  Center(
                    child: Column(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            shape: BoxShape.circle,
                            boxShadow: [
                              BoxShadow(
                                color: AppTheme.accentTeal.withOpacity(0.1),
                                blurRadius: 20,
                                offset: const Offset(0, 8),
                              ),
                            ],
                          ),
                          child: const Icon(
                            Icons.favorite_rounded,
                            color: AppTheme.accentTeal,
                            size: 40,
                          ),
                        ).animate().scale(duration: 400.ms, curve: Curves.easeOutBack),
                        const SizedBox(height: 18),
                        Text(
                          _t('welcome'),
                          style: Theme.of(context).textTheme.displayMedium?.copyWith(
                            fontSize: 24,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          _t('verification_sub'),
                          style: const TextStyle(color: AppTheme.textSecondary, fontSize: 13),
                        ),
                      ],
                    ),
                  ),
                  
                  const SizedBox(height: 48),

                  AnimatedCrossFade(
                    duration: const Duration(milliseconds: 300),
                    crossFadeState: _otpSent ? CrossFadeState.showSecond : CrossFadeState.showFirst,
                    firstChild: _buildEmailInputSection(),
                    secondChild: _buildOtpInputSection(),
                  ),
                  
                  const SizedBox(height: 60),
                  
                  // Trust Badges
                  _buildTrustBadgesSection(),
                ],
              ),
            ),
          ),
          
          if (_isLoading)
            Container(
              color: Colors.black.withOpacity(0.3),
              child: const Center(
                child: CircularProgressIndicator(color: AppTheme.accentTeal),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildEmailInputSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          _t('mobile_number'),
          style: const TextStyle(
            color: AppTheme.textPrimary,
            fontWeight: FontWeight.bold,
            fontSize: 14,
          ),
        ),
        const SizedBox(height: 10),
        TextField(
          controller: _phoneController,
          keyboardType: TextInputType.phone,
          maxLength: 10,
          inputFormatters: [
            FilteringTextInputFormatter.digitsOnly,
            LengthLimitingTextInputFormatter(10),
          ],
          style: const TextStyle(
            color: AppTheme.textPrimary,
            fontWeight: FontWeight.bold,
            fontSize: 15,
          ),
          decoration: InputDecoration(
            counterText: '',
            prefixIcon: const Icon(Icons.phone_android_rounded, color: AppTheme.textSecondary, size: 20),
            hintText: _t('enter_hint'),
            hintStyle: const TextStyle(color: AppTheme.textSecondary, fontSize: 14),
            fillColor: Colors.white,
            filled: true,
            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: AppTheme.borderColor),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: AppTheme.accentTeal, width: 1.5),
            ),
          ),
        ),
        const SizedBox(height: 24),
        ElevatedButton(
          onPressed: _sendOtp,
          style: ElevatedButton.styleFrom(
            backgroundColor: AppTheme.accentTeal,
            foregroundColor: Colors.white,
            padding: const EdgeInsets.symmetric(vertical: 16),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ),
          child: Text(
            _t('send_otp'),
            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
          ),
        ),
      ],
    ).animate().fade().slideY(begin: 0.1, duration: 400.ms);
  }

  Widget _buildOtpInputSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              _t('enter_otp'),
              style: const TextStyle(
                color: AppTheme.textPrimary,
                fontWeight: FontWeight.bold,
                fontSize: 14,
              ),
            ),
            Text(
              '${_t('sent_to')}${_phoneController.text}',
              style: const TextStyle(color: AppTheme.textSecondary, fontSize: 12),
            ),
          ],
        ),
        const SizedBox(height: 18),
        
        // 4 OTP Boxes
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: List.generate(4, (index) {
            return SizedBox(
              width: 58,
              height: 58,
              child: TextField(
                controller: _otpControllers[index],
                focusNode: _otpFocusNodes[index],
                keyboardType: TextInputType.number,
                textAlign: TextAlign.center,
                maxLength: 1,
                inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                style: const TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: AppTheme.accentTeal,
                ),
                decoration: InputDecoration(
                  counterText: '',
                  fillColor: Colors.white,
                  filled: true,
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(color: AppTheme.borderColor),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(color: AppTheme.accentTeal, width: 1.8),
                  ),
                ),
                onChanged: (value) {
                  if (value.isNotEmpty) {
                    if (index < 3) {
                      FocusScope.of(context).requestFocus(_otpFocusNodes[index + 1]);
                    } else {
                      FocusScope.of(context).unfocus();
                    }
                  } else {
                    if (index > 0) {
                      FocusScope.of(context).requestFocus(_otpFocusNodes[index - 1]);
                    }
                  }
                },
              ),
            );
          }),
        ),
        
        const SizedBox(height: 24),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              _secondsRemaining > 0 
                ? '${_t('resend_in')} 0:${_secondsRemaining.toString().padLeft(2, '0')}' 
                : _t('didnt_receive'),
              style: const TextStyle(color: AppTheme.textSecondary, fontSize: 13),
            ),
            if (_secondsRemaining == 0)
              TextButton(
                onPressed: _startTimer,
                child: Text(
                  _t('resend_btn'),
                  style: const TextStyle(
                    color: AppTheme.accentTeal,
                    fontWeight: FontWeight.bold,
                    fontSize: 13,
                  ),
                ),
              ),
          ],
        ),
        const SizedBox(height: 24),
        ElevatedButton(
          onPressed: _verifyOtp,
          style: ElevatedButton.styleFrom(
            backgroundColor: AppTheme.accentTeal,
            foregroundColor: Colors.white,
            padding: const EdgeInsets.symmetric(vertical: 16),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ),
          child: Text(
            _t('verify_register'),
            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
          ),
        ),
        const SizedBox(height: 12),
        Center(
          child: TextButton(
            onPressed: () {
              setState(() {
                _otpSent = false;
              });
            },
            child: Text(
              _t('change_mobile'),
              style: const TextStyle(
                color: AppTheme.textSecondary,
                fontSize: 13,
              ),
            ),
          ),
        ),
      ],
    ).animate().fade().slideY(begin: 0.1, duration: 400.ms);
  }

  Widget _buildTrustBadgesSection() {
    return Column(
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(width: 40, height: 1, color: AppTheme.borderColor),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 10),
              child: Text(
                _t('secure_header'),
                style: const TextStyle(
                  color: AppTheme.textSecondary,
                  fontSize: 9,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 0.8,
                ),
              ),
            ),
            Container(width: 40, height: 1, color: AppTheme.borderColor),
          ],
        ),
        const SizedBox(height: 20),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: [
            _buildBadgeItem(Icons.verified_user_rounded, 'DPDP Compliant'),
            _buildBadgeItem(Icons.location_on_rounded, 'Data Stays in India'),
            _buildBadgeItem(Icons.lock_rounded, '256-bit Encrypted'),
          ],
        ),
        const SizedBox(height: 32),
        Center(
          child: Text(
            _t('agree_terms'),
            style: const TextStyle(color: AppTheme.textSecondary, fontSize: 9.5),
            textAlign: TextAlign.center,
          ),
        ),
      ],
    );
  }

  Widget _buildBadgeItem(IconData icon, String title) {
    return Column(
      children: [
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: Colors.white,
            shape: BoxShape.circle,
            border: Border.all(color: AppTheme.borderColor),
          ),
          child: Icon(icon, color: AppTheme.accentTeal, size: 18),
        ),
        const SizedBox(height: 6),
        Text(
          title,
          style: const TextStyle(
            color: AppTheme.textPrimary,
            fontSize: 10,
            fontWeight: FontWeight.bold,
          ),
        ),
      ],
    );
  }
}
