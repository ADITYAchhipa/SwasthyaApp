import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:provider/provider.dart';
import '../providers/swasthya_tap_provider.dart';
import '../theme/app_theme.dart';
import '../utils/translation_service.dart';
import '../widgets/glass_card.dart';
import 'role_selection_screen.dart';

class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({Key? key}) : super(key: key);

  @override
  _OnboardingScreenState createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  final PageController _pageController = PageController();
  int _currentPage = 0; // 0: Select Language Screen, 1-3: 3 Info Screens

  final List<Map<String, String>> _languages = const [
    {'code': 'Hindi', 'native': 'हिन्दी', 'english': 'Hindi'},
    {'code': 'English', 'native': 'English', 'english': 'English'},
    {'code': 'Tamil', 'native': 'தமிழ்', 'english': 'Tamil'},
    {'code': 'Telugu', 'native': 'తెలుగు', 'english': 'Telugu'},
    {'code': 'Bengali', 'native': 'বাংলা', 'english': 'Bengali'},
    {'code': 'Marathi', 'native': 'मराठी', 'english': 'Marathi'},
    {'code': 'Gujarati', 'native': 'ગુજરાતી', 'english': 'Gujarati'},
    {'code': 'Kannada', 'native': 'ಕನ್ನಡ', 'english': 'Kannada'},
    {'code': 'Malayalam', 'native': 'മലയാളം', 'english': 'Malayalam'},
    {'code': 'Odia', 'native': 'ଓଡ଼ିଆ', 'english': 'Odia'},
    {'code': 'Punjabi', 'native': 'ਪੰਜਾਬੀ', 'english': 'Punjabi'},
    {'code': 'Urdu', 'native': 'اردو', 'english': 'Urdu'},
    {'code': 'Assamese', 'native': 'অসমীয়া', 'english': 'Assamese'},
  ];

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  void _onPageChanged(int index) {
    setState(() {
      _currentPage = index;
    });
  }

  void _finishOnboarding() {
    Navigator.push(
      context,
      PageRouteBuilder(
        transitionDuration: const Duration(milliseconds: 600),
        pageBuilder: (context, animation, secondaryAnimation) =>
            const RoleSelectionScreen(),
        transitionsBuilder: (context, animation, secondaryAnimation, child) {
          return FadeTransition(opacity: animation, child: child);
        },
      ),
    );
  }

  void _showLanguageSelectorSheet(BuildContext context, SwasthyaTapProvider provider) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) {
        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.grey.shade300,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(height: 16),
              Row(
                children: const [
                  Icon(Icons.translate_rounded, color: AppTheme.accentTeal, size: 22),
                  SizedBox(width: 8),
                  Text(
                    'Select Language / भाषा चुनें',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: AppTheme.textPrimary),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Flexible(
                child: SingleChildScrollView(
                  child: GridView.builder(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: 3,
                      crossAxisSpacing: 10,
                      mainAxisSpacing: 10,
                      childAspectRatio: 1.15,
                    ),
                    itemCount: _languages.length,
                    itemBuilder: (context, index) {
                      final lang = _languages[index];
                      final isSelected = provider.selectedLanguage == lang['code'];

                      return GestureDetector(
                        onTap: () {
                          provider.setSelectedLanguage(lang['code']!);
                          Navigator.pop(context);
                          setState(() {});
                        },
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 200),
                          decoration: BoxDecoration(
                            color: isSelected ? AppTheme.accentTeal.withOpacity(0.08) : Colors.white,
                            borderRadius: BorderRadius.circular(14),
                            border: Border.all(
                              color: isSelected ? AppTheme.accentTeal : AppTheme.borderColor,
                              width: isSelected ? 2.0 : 1.0,
                            ),
                          ),
                          child: Center(
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Text(
                                  lang['native']!,
                                  style: TextStyle(
                                    color: isSelected ? AppTheme.accentTeal : AppTheme.textPrimary,
                                    fontWeight: FontWeight.bold,
                                    fontSize: 15,
                                  ),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  lang['english']!,
                                  style: TextStyle(
                                    color: isSelected ? AppTheme.accentTeal : AppTheme.textSecondary,
                                    fontSize: 10,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      );
                    },
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Color _getAccentColorForPage(int index) {
    switch (index) {
      case 0:
        return AppTheme.accentTeal;
      case 1:
        return AppTheme.accentTeal;
      case 2:
        return const Color(0xFFF97316);
      case 3:
        return AppTheme.accentGreen;
      default:
        return AppTheme.accentTeal;
    }
  }

  Widget _buildBloodNetworkCustomContent(BuildContext context) {
    return Column(
      children: [
        const SizedBox(height: 8),
        Container(
          width: 42,
          height: 3,
          decoration: BoxDecoration(
            color: const Color(0xFFF97316),
            borderRadius: BorderRadius.circular(1.5),
          ),
        ),
        const SizedBox(height: 20),
        _buildStepRow(
          icon: Icons.domain_rounded,
          text: TranslationService.t(context, 'ob_step_1'),
          showArrow: true,
        ),
        const SizedBox(height: 12),
        _buildStepRow(
          icon: Icons.near_me_rounded,
          text: TranslationService.t(context, 'ob_step_2_pre'),
          boldText: TranslationService.t(context, 'ob_step_2_bold'),
          postText: TranslationService.t(context, 'ob_step_2_post'),
          showArrow: true,
        ),
        const SizedBox(height: 12),
        _buildStepRow(
          icon: Icons.check_circle_outline_rounded,
          text: TranslationService.t(context, 'ob_step_3'),
          showArrow: true,
        ),
        const SizedBox(height: 12),
        _buildStepRow(
          icon: Icons.local_shipping_outlined,
          text: TranslationService.t(context, 'ob_step_4_pre'),
          boldText: TranslationService.t(context, 'ob_step_4_bold'),
          postText: TranslationService.t(context, 'ob_step_4_post'),
          showArrow: false,
        ),
        const SizedBox(height: 20),
        Text(
          TranslationService.t(context, 'ob_blood_footer'),
          style: TextStyle(
            color: AppTheme.textSecondary.withOpacity(0.7),
            fontSize: 13,
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
  }

  Widget _buildStepRow({
    required IconData icon,
    required String text,
    String? boldText,
    String? postText,
    required bool showArrow,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Row(
        children: [
          Icon(icon, color: const Color(0xFFF97316), size: 18),
          const SizedBox(width: 12),
          Expanded(
            child: RichText(
              text: TextSpan(
                style: const TextStyle(
                  color: AppTheme.textPrimary,
                  fontSize: 13,
                  fontFamily: 'Outfit',
                  fontWeight: FontWeight.w500,
                ),
                children: [
                  TextSpan(text: text),
                  if (boldText != null)
                    TextSpan(
                      text: boldText,
                      style: const TextStyle(
                        color: Color(0xFFF97316),
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  if (postText != null) TextSpan(text: postText),
                ],
              ),
            ),
          ),
          if (showArrow)
            const Padding(
              padding: EdgeInsets.only(left: 8),
              child: Icon(
                Icons.arrow_forward_rounded,
                color: Color(0xFFF97316),
                size: 14,
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildLanguageSelectionPage(BuildContext context, SwasthyaTapProvider provider) {
    final currentLang = provider.selectedLanguage;

    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
      child: Column(
        children: [
          const SizedBox(height: 8),
          
          // Translation Circle Icon
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppTheme.accentTeal.withOpacity(0.08),
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.translate_rounded,
              color: AppTheme.accentTeal,
              size: 32,
            ),
          ).animate().scale(duration: 400.ms, curve: Curves.easeOutBack),

          const SizedBox(height: 16),

          Text(
            TranslationService.t(context, 'ob_lang_title'),
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.displayMedium?.copyWith(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  letterSpacing: -0.5,
                ),
          ).animate().fade(duration: 300.ms).slideY(begin: 0.05),

          const SizedBox(height: 6),

          Text(
            TranslationService.t(context, 'ob_lang_sub'),
            textAlign: TextAlign.center,
            style: const TextStyle(color: AppTheme.textSecondary, fontSize: 13, height: 1.4),
          ).animate().fade(delay: 100.ms, duration: 300.ms),

          const SizedBox(height: 18),

          // Heartbeat divider
          Row(
            children: [
              Expanded(child: Container(height: 1, color: AppTheme.borderColor)),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 10),
                child: Container(
                  padding: const EdgeInsets.all(6),
                  decoration: const BoxDecoration(
                    color: AppTheme.accentTeal,
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.favorite_rounded, color: Colors.white, size: 10),
                ),
              ),
              Expanded(child: Container(height: 1, color: AppTheme.borderColor)),
            ],
          ),

          const SizedBox(height: 20),

          // 13 Indian Languages Grid
          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 3,
              crossAxisSpacing: 10,
              mainAxisSpacing: 10,
              childAspectRatio: 1.15,
            ),
            itemCount: _languages.length,
            itemBuilder: (context, index) {
              final lang = _languages[index];
              final isSelected = currentLang == lang['code'];

              return GestureDetector(
                onTap: () {
                  provider.setSelectedLanguage(lang['code']!);
                },
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: isSelected ? AppTheme.accentTeal : AppTheme.borderColor,
                      width: isSelected ? 2.0 : 1.0,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: isSelected
                            ? AppTheme.accentTeal.withOpacity(0.12)
                            : Colors.black.withOpacity(0.02),
                        blurRadius: isSelected ? 8 : 4,
                        offset: const Offset(0, 3),
                      ),
                    ],
                  ),
                  child: Stack(
                    children: [
                      if (isSelected)
                        Positioned(
                          top: 8,
                          right: 8,
                          child: Container(
                            padding: const EdgeInsets.all(2),
                            decoration: const BoxDecoration(
                              color: AppTheme.accentTeal,
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(Icons.check, color: Colors.white, size: 10),
                          ),
                        ),
                      Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text(
                              lang['native']!,
                              style: TextStyle(
                                color: isSelected ? AppTheme.accentTeal : AppTheme.textPrimary,
                                fontWeight: isSelected ? FontWeight.bold : FontWeight.w600,
                                fontSize: 16,
                              ),
                            ),
                            const SizedBox(height: 3),
                            Text(
                              lang['english']!,
                              style: TextStyle(
                                color: isSelected ? AppTheme.accentTeal : AppTheme.textSecondary,
                                fontSize: 10.5,
                                fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              );
            },
          ),

          const SizedBox(height: 24),

          // Confirm Language Button
          SizedBox(
            width: double.infinity,
            height: 52,
            child: ElevatedButton(
              onPressed: () {
                _pageController.nextPage(
                  duration: const Duration(milliseconds: 400),
                  curve: Curves.easeInOutCubic,
                );
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.accentTeal,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
                elevation: 4,
                shadowColor: AppTheme.accentTeal.withOpacity(0.3),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    TranslationService.tLang(currentLang, 'confirm_language'),
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                  ),
                  const SizedBox(width: 8),
                  const Icon(Icons.arrow_forward_rounded, size: 18),
                ],
              ),
            ),
          ),

          const SizedBox(height: 20),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final provider = Provider.of<SwasthyaTapProvider>(context);
    final accentColor = _getAccentColorForPage(_currentPage);
    final isLangPage = _currentPage == 0;

    // Build page data dynamically with translation service
    final pagesData = [
      // Page 1 (Index 1)
      OnboardingPageData(
        title: TranslationService.t(context, 'ob_title_1'),
        subtitle: TranslationService.t(context, 'ob_subtitle_1'),
        description: TranslationService.t(context, 'ob_desc_1'),
        icon: Icons.contactless_rounded,
        accentColor: AppTheme.accentTeal,
        illustrationBuilder: (context) => const OnboardingNfcCardWidget(),
      ),
      // Page 2 (Index 2)
      OnboardingPageData(
        title: TranslationService.t(context, 'ob_title_2'),
        subtitle: TranslationService.t(context, 'ob_subtitle_2'),
        description: "",
        icon: Icons.bloodtype_rounded,
        accentColor: const Color(0xFFF97316),
        illustrationBuilder: (context) => const OnboardingBloodNetworkWidget(),
        customContentBuilder: (context) => _buildBloodNetworkCustomContent(context),
      ),
      // Page 3 (Index 3)
      OnboardingPageData(
        title: TranslationService.t(context, 'ob_title_3'),
        subtitle: TranslationService.t(context, 'ob_subtitle_3'),
        description: TranslationService.t(context, 'ob_desc_3'),
        icon: Icons.offline_bolt_rounded,
        accentColor: AppTheme.accentGreen,
        illustrationBuilder: (context) => const OnboardingOfflineWidget(),
      ),
    ];

    return Scaffold(
      backgroundColor: AppTheme.lightBg,
      body: Stack(
        children: [
          // Tricolor Top Line
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            child: Row(
              children: [
                Expanded(child: Container(height: 3, color: const Color(0xFFFF9933))), // Saffron
                Expanded(child: Container(height: 3, color: Colors.white)),            // White
                Expanded(child: Container(height: 3, color: const Color(0xFF138808))), // Green
              ],
            ),
          ),
          // Subtle radial background glow (hidden on step 0 to keep background clean white)
          if (!isLangPage) ...[
            Positioned(
              top: -120,
              right: -120,
              child: AnimatedContainer(
                duration: 600.ms,
                curve: Curves.easeInOut,
                width: 320,
                height: 320,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: RadialGradient(
                    colors: [
                      accentColor.withOpacity(0.12),
                      Colors.transparent,
                    ],
                  ),
                ),
              ),
            ),
            Positioned(
              bottom: -140,
              left: -140,
              child: AnimatedContainer(
                duration: 600.ms,
                curve: Curves.easeInOut,
                width: 340,
                height: 340,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: RadialGradient(
                    colors: [
                      accentColor.withOpacity(0.08),
                      Colors.transparent,
                    ],
                  ),
                ),
              ),
            ),
          ],

          SafeArea(
            child: Column(
              children: [
                // Top Header Bar
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(7),
                              decoration: BoxDecoration(
                                color: accentColor.withOpacity(0.1),
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: Icon(
                                Icons.healing_rounded,
                                color: accentColor,
                                size: 18,
                              ),
                            ),
                            const SizedBox(width: 8),
                            const Expanded(
                              child: Text(
                                "SwasthyaTap",
                                style: TextStyle(
                                  fontFamily: 'Outfit',
                                  fontWeight: FontWeight.bold,
                                  fontSize: 18,
                                  color: AppTheme.textPrimary,
                                  letterSpacing: 0.5,
                                ),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 12),
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          // Language Switcher Pill (always visible on info pages)
                          if (_currentPage > 0)
                            InkWell(
                              onTap: () => _showLanguageSelectorSheet(context, provider),
                              borderRadius: BorderRadius.circular(20),
                              child: Container(
                                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                                decoration: BoxDecoration(
                                  color: AppTheme.accentTeal.withOpacity(0.08),
                                  borderRadius: BorderRadius.circular(20),
                                  border: Border.all(color: AppTheme.accentTeal.withOpacity(0.3)),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    const Icon(Icons.language_rounded, size: 14, color: AppTheme.accentTeal),
                                    const SizedBox(width: 4),
                                    Text(
                                      provider.selectedLanguage,
                                      style: const TextStyle(
                                        color: AppTheme.accentTeal,
                                        fontWeight: FontWeight.bold,
                                        fontSize: 11.5,
                                      ),
                                    ),
                                    const Icon(Icons.arrow_drop_down, size: 16, color: AppTheme.accentTeal),
                                  ],
                                ),
                              ),
                            ),
                          if (_currentPage > 0 && _currentPage < 3) ...[
                            const SizedBox(width: 8),
                            OutlinedButton(
                              onPressed: _finishOnboarding,
                              style: OutlinedButton.styleFrom(
                                side: BorderSide(color: Colors.grey.shade200, width: 1),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(20),
                                ),
                                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                                backgroundColor: Colors.white.withOpacity(0.95),
                                minimumSize: Size.zero,
                                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                              ),
                              child: Text(
                                TranslationService.t(context, 'btn_skip'),
                                style: const TextStyle(
                                  color: Colors.grey,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 12,
                                ),
                              ),
                            ),
                          ],
                        ],
                      ),
                    ],
                  ),
                ),

                // PageView content
                Expanded(
                  child: PageView.builder(
                    controller: _pageController,
                    onPageChanged: _onPageChanged,
                    itemCount: 4, // 0: Select Language, 1-3: Info screens
                    itemBuilder: (context, index) {
                      if (index == 0) {
                        return _buildLanguageSelectionPage(context, provider);
                      }

                      final infoIndex = index - 1;
                      final pData = pagesData[infoIndex];

                      return SingleChildScrollView(
                        padding: const EdgeInsets.symmetric(horizontal: 24),
                        child: Column(
                          children: [
                            const SizedBox(height: 12),
                            // Illustration Container
                            Container(
                              height: 240,
                              width: double.infinity,
                              decoration: infoIndex == 1
                                  ? null
                                  : BoxDecoration(
                                      color: Colors.white.withOpacity(0.55),
                                      borderRadius: BorderRadius.circular(24),
                                      boxShadow: [
                                        BoxShadow(
                                          color: Colors.black.withOpacity(0.02),
                                          blurRadius: 20,
                                          offset: const Offset(0, 8),
                                        ),
                                        BoxShadow(
                                          color: pData.accentColor.withOpacity(0.04),
                                          blurRadius: 10,
                                          offset: const Offset(0, 4),
                                        ),
                                      ],
                                      border: Border.all(
                                        color: Colors.white.withOpacity(0.85),
                                        width: 1.5,
                                      ),
                                    ),
                              child: infoIndex == 1
                                  ? pData.illustrationBuilder(context)
                                  : ClipRRect(
                                      borderRadius: BorderRadius.circular(24),
                                      child: pData.illustrationBuilder(context),
                                    ),
                            ).animate(key: ValueKey('illustration_$index')).fade(duration: 400.ms).scale(begin: const Offset(0.96, 0.96), curve: Curves.easeOutBack),

                            if (infoIndex != 1) ...[
                              const SizedBox(height: 28),
                              // Subtitle Badge
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                                decoration: BoxDecoration(
                                  color: pData.accentColor.withOpacity(0.12),
                                  borderRadius: BorderRadius.circular(20),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(pData.icon, color: pData.accentColor, size: 12),
                                    const SizedBox(width: 6),
                                    Text(
                                      pData.subtitle,
                                      style: TextStyle(
                                        color: pData.accentColor,
                                        fontSize: 9,
                                        fontWeight: FontWeight.bold,
                                        letterSpacing: 0.8,
                                      ),
                                    ),
                                  ],
                                ),
                              ).animate(key: ValueKey('badge_$index')).fade(delay: 100.ms).slideY(begin: 0.04, duration: 400.ms),
                            ],

                            const SizedBox(height: 18),

                            // Headline Title
                            Text(
                              pData.title,
                              textAlign: TextAlign.center,
                              style: Theme.of(context).textTheme.displayMedium?.copyWith(
                                    fontSize: 24,
                                    height: 1.25,
                                    letterSpacing: -0.5,
                                    color: infoIndex == 1 ? const Color(0xFF0F766E) : AppTheme.textPrimary,
                                  ),
                            ).animate(key: ValueKey('title_$index')).fade(delay: 150.ms).slideY(begin: 0.04, duration: 400.ms),

                            const SizedBox(height: 12),

                            // Description or Custom Content
                            Container(
                              child: pData.customContentBuilder != null
                                  ? pData.customContentBuilder!(context)
                                  : Text(
                                      pData.description,
                                      textAlign: TextAlign.center,
                                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                                            fontSize: 13,
                                            height: 1.5,
                                            color: AppTheme.textSecondary,
                                          ),
                                    ),
                            ).animate(key: ValueKey('desc_$index')).fade(delay: 200.ms).slideY(begin: 0.04, duration: 400.ms),
                          ],
                        ),
                      );
                    },
                  ),
                ),

                // Bottom Navigation controls (Pages 1, 2, 3)
                if (_currentPage > 0)
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 18),
                    child: AnimatedSwitcher(
                      duration: const Duration(milliseconds: 300),
                      child: _currentPage == 3
                          ? // Slide 3: Full Width Get Started Button
                          SizedBox(
                              key: const ValueKey("get_started_bar"),
                              width: double.infinity,
                              child: Container(
                                decoration: BoxDecoration(
                                  borderRadius: BorderRadius.circular(16),
                                  boxShadow: [
                                    BoxShadow(
                                      color: AppTheme.accentGreen.withOpacity(0.35),
                                      blurRadius: 15,
                                      offset: const Offset(0, 5),
                                    ),
                                  ],
                                ),
                                child: ElevatedButton(
                                  onPressed: _finishOnboarding,
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: AppTheme.accentGreen,
                                    foregroundColor: Colors.white,
                                    padding: const EdgeInsets.symmetric(vertical: 16),
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(16),
                                    ),
                                  ),
                                  child: Row(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      Text(
                                        TranslationService.t(context, 'btn_get_started'),
                                        style: const TextStyle(
                                          fontWeight: FontWeight.bold,
                                          fontSize: 15,
                                          letterSpacing: 0.5,
                                        ),
                                      ),
                                      const SizedBox(width: 8),
                                      const Icon(Icons.arrow_forward_rounded, size: 18),
                                    ],
                                  ),
                                ),
                              ),
                            )
                          : // Slide 1 & 2: Dot indicator + Back & Next buttons
                          Row(
                              key: const ValueKey("nav_bar"),
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                // Left: Back Button
                                SizedBox(
                                  width: 100,
                                  child: Align(
                                    alignment: Alignment.centerLeft,
                                    child: OutlinedButton(
                                      onPressed: () {
                                        _pageController.previousPage(
                                          duration: 400.ms,
                                          curve: Curves.easeInOutCubic,
                                        );
                                      },
                                      style: OutlinedButton.styleFrom(
                                        side: const BorderSide(color: AppTheme.borderColor, width: 1.2),
                                        shape: RoundedRectangleBorder(
                                          borderRadius: BorderRadius.circular(20),
                                        ),
                                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                                      ),
                                      child: Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          const Icon(Icons.arrow_back, size: 14, color: AppTheme.textSecondary),
                                          const SizedBox(width: 4),
                                          Text(
                                            TranslationService.t(context, 'btn_back'),
                                            style: const TextStyle(
                                              color: AppTheme.textSecondary,
                                              fontWeight: FontWeight.bold,
                                              fontSize: 12.5,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                ),

                                // Center: 3 Page Indicators (For Info Pages 1, 2, 3)
                                Row(
                                  children: List.generate(3, (index) {
                                    final infoIndex = _currentPage - 1;
                                    final isSelected = infoIndex == index;
                                    return AnimatedContainer(
                                      duration: 300.ms,
                                      margin: const EdgeInsets.only(right: 6),
                                      width: isSelected ? 18 : 8,
                                      height: 8,
                                      decoration: BoxDecoration(
                                        color: isSelected
                                            ? accentColor
                                            : AppTheme.borderColor,
                                        borderRadius: BorderRadius.circular(4),
                                      ),
                                    );
                                  }),
                                ),

                                // Right: Next Button
                                SizedBox(
                                  width: 100,
                                  child: Align(
                                    alignment: Alignment.centerRight,
                                    child: ElevatedButton(
                                      onPressed: () {
                                        _pageController.nextPage(
                                          duration: 400.ms,
                                          curve: Curves.easeInOutCubic,
                                        );
                                      },
                                      style: ElevatedButton.styleFrom(
                                        backgroundColor: accentColor,
                                        foregroundColor: Colors.white,
                                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                                        shape: RoundedRectangleBorder(
                                          borderRadius: BorderRadius.circular(20),
                                        ),
                                        elevation: 2,
                                      ),
                                      child: Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          Text(
                                            TranslationService.t(context, 'btn_next'),
                                            style: const TextStyle(
                                              fontWeight: FontWeight.bold,
                                              fontSize: 12.5,
                                              letterSpacing: 0.5,
                                            ),
                                          ),
                                          const SizedBox(width: 4),
                                          const Icon(Icons.arrow_forward_rounded, size: 14),
                                        ],
                                      ),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class OnboardingPageData {
  final String title;
  final String subtitle;
  final String description;
  final IconData icon;
  final Color accentColor;
  final Widget Function(BuildContext) illustrationBuilder;
  final Widget Function(BuildContext)? customContentBuilder;

  OnboardingPageData({
    required this.title,
    required this.subtitle,
    required this.description,
    required this.icon,
    required this.accentColor,
    required this.illustrationBuilder,
    this.customContentBuilder,
  });
}

// ─── Slide 1 Illustration: Card Scan Wallet Phone Hologram ─────────────────────────────
class OnboardingNfcCardWidget extends StatefulWidget {
  const OnboardingNfcCardWidget({Key? key}) : super(key: key);

  @override
  _OnboardingNfcCardWidgetState createState() => _OnboardingNfcCardWidgetState();
}

class _OnboardingNfcCardWidgetState extends State<OnboardingNfcCardWidget>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _phoneY;
  late Animation<double> _pulseScale;
  late Animation<double> _hologramOpacity;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 6),
    )..repeat();

    _phoneY = TweenSequence<double>([
      // Stay up (0.0 to 0.20 -> 20%)
      TweenSequenceItem(tween: ConstantTween<double>(-60), weight: 20),
      // Move down to tap (0.20 to 0.35 -> 15%)
      TweenSequenceItem(
          tween: Tween<double>(begin: -60, end: -2)
              .chain(CurveTween(curve: Curves.easeInOutCubic)),
          weight: 15),
      // Stay down during NFC tap (0.35 to 0.65 -> 30%)
      TweenSequenceItem(tween: ConstantTween<double>(-2), weight: 30),
      // Move back up (0.65 to 0.80 -> 15%)
      TweenSequenceItem(
          tween: Tween<double>(begin: -2, end: -60)
              .chain(CurveTween(curve: Curves.easeInOutCubic)),
          weight: 15),
      // Delay (0.80 to 1.0 -> 20%)
      TweenSequenceItem(tween: ConstantTween<double>(-60), weight: 20),
    ]).animate(_controller);

    _pulseScale = TweenSequence<double>([
      TweenSequenceItem(tween: ConstantTween<double>(0.0), weight: 25),
      TweenSequenceItem(
          tween: Tween<double>(begin: 0.0, end: 1.0)
              .chain(CurveTween(curve: Curves.easeOut)),
          weight: 20),
      TweenSequenceItem(tween: ConstantTween<double>(0.0), weight: 55),
    ]).animate(_controller);

    _hologramOpacity = TweenSequence<double>([
      TweenSequenceItem(tween: ConstantTween<double>(0.0), weight: 35),
      TweenSequenceItem(
          tween: Tween<double>(begin: 0.0, end: 1.0)
              .chain(CurveTween(curve: Curves.easeOut)),
          weight: 15),
      TweenSequenceItem(tween: ConstantTween<double>(1.0), weight: 20),
      TweenSequenceItem(
          tween: Tween<double>(begin: 1.0, end: 0.0)
              .chain(CurveTween(curve: Curves.easeIn)),
          weight: 15),
      TweenSequenceItem(tween: ConstantTween<double>(0.0), weight: 15),
    ]).animate(_controller);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        double progress = _controller.value;
        Widget phoneScreen;

        // Animate screen contents based on scan progress
        if (progress >= 0.35 && progress < 0.80) {
          phoneScreen = Container(
            color: const Color(0xFF0F172A),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.check_circle_rounded, color: AppTheme.accentGreen, size: 24)
                    .animate()
                    .scale(duration: 300.ms, curve: Curves.easeOutBack),
                const SizedBox(height: 4),
                const Text(
                  "CARD DETECTED",
                  style: TextStyle(
                    color: AppTheme.accentGreen,
                    fontSize: 7,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 0.8,
                  ),
                ),
                const SizedBox(height: 2),
                const Text("SwasthyaTap Active", style: TextStyle(color: Colors.white38, fontSize: 5)),
              ],
            ),
          );
        } else {
          phoneScreen = Container(
            color: const Color(0xFF0F172A),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.nfc_rounded, color: AppTheme.accentTeal.withOpacity(0.5), size: 24)
                    .animate(onPlay: (c) => c.repeat(reverse: true))
                    .fade(begin: 0.3, end: 0.8, duration: 800.ms),
                const SizedBox(height: 4),
                const Text(
                  "Ready to Tap",
                  style: TextStyle(
                    color: Colors.white30,
                    fontSize: 7,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          );
        }

        return Stack(
          alignment: Alignment.center,
          children: [
            // 1. Wallet Graphic (at the bottom)
            Positioned(
              bottom: 12,
              child: Container(
                width: 140,
                height: 85,
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFF5C4033), Color(0xFF4A3329)],
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                  ),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: const Color(0xFF3E2B22), width: 1.5),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.25),
                      blurRadius: 12,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Stack(
                  children: [
                    // Leather Slot stitching effect
                    Positioned(
                      top: 15,
                      left: 10,
                      right: 10,
                      child: Container(
                        height: 25,
                        decoration: BoxDecoration(
                          color: const Color(0xFF3E2B22).withOpacity(0.6),
                          borderRadius: BorderRadius.circular(4),
                          border: Border.all(
                            color: const Color(0xFF7A5848).withOpacity(0.2),
                            width: 0.8,
                          ),
                        ),
                      ),
                    ),
                    // Wallet Badge/Logo
                    Positioned(
                      bottom: 8,
                      right: 10,
                      child: Icon(
                        Icons.credit_card_rounded,
                        color: const Color(0xFF8B6C5C).withOpacity(0.3),
                        size: 14,
                      ),
                    ),
                  ],
                ),
              ),
            ),

            // 2. SwasthyaTap NFC Card sticking out of the wallet
            Positioned(
              bottom: 42,
              child: Transform.rotate(
                angle: -0.06,
                child: Container(
                  width: 110,
                  height: 68,
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [Color(0xFF0F766E), Color(0xFF032239)],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.circular(6),
                    boxShadow: [
                      BoxShadow(
                        color: const Color(0xFF0F766E).withOpacity(0.4),
                        blurRadius: 8,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: Stack(
                    children: [
                      Positioned.fill(
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(6),
                          child: CustomPaint(painter: TricolorWavesPainter()),
                        ),
                      ),
                      Positioned(
                        top: 6,
                        right: 8,
                        child: CustomPaint(
                          size: const Size(9, 10),
                          painter: NfcWavePainter(color: Colors.white),
                        ),
                      ),
                      Positioned(
                        top: 12,
                        left: 8,
                        child: Row(
                          children: [
                            CustomPaint(
                              size: const Size(10, 10),
                              painter: HeartEcgPainter(color: Colors.white),
                            ),
                            const SizedBox(width: 4),
                            const Text(
                              "SwasthTap",
                              style: TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                                fontSize: 9,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const Positioned(
                        top: 24,
                        left: 22,
                        child: Text(
                          "आपकी स्वास्थ्य पहचान",
                          style: TextStyle(
                            color: Colors.white70,
                            fontSize: 4.2,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                      Positioned(
                        bottom: 6,
                        left: 8,
                        child: Container(
                          padding: const EdgeInsets.all(0.8),
                          color: Colors.white,
                          child: CustomPaint(
                            size: const Size(10, 10),
                            painter: QrPainter(color: const Color(0xFF032239)),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),

            // 3. NFC Wireless pulse waves radiating from phone to card
            Positioned(
              bottom: 95,
              child: Opacity(
                opacity: _pulseScale.value,
                child: Stack(
                  alignment: Alignment.center,
                  children: List.generate(3, (index) {
                    double radius = 30 + (index * 25) * _pulseScale.value;
                    return Container(
                      width: radius,
                      height: radius,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: AppTheme.accentTeal.withOpacity(
                            0.6 * (1.0 - (radius / 95)),
                          ),
                          width: 1.5,
                        ),
                      ),
                    );
                  }),
                ),
              ),
            ),

            // 4. Smartphone Mockup tapping the card
            Transform.translate(
              offset: Offset(0, _phoneY.value),
              child: Container(
                width: 90,
                height: 125,
                decoration: BoxDecoration(
                  color: const Color(0xFF1E293B),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: Colors.white30, width: 1.5),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.3),
                      blurRadius: 15,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Column(
                  children: [
                    const SizedBox(height: 5),
                    // Speaker notch
                    Container(
                      width: 25,
                      height: 4,
                      decoration: BoxDecoration(
                        color: Colors.black,
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                    const SizedBox(height: 5),
                    // Mobile Screen
                    Expanded(
                      child: ClipRRect(
                        borderRadius: const BorderRadius.only(
                          bottomLeft: Radius.circular(14),
                          bottomRight: Radius.circular(14),
                        ),
                        child: phoneScreen,
                      ),
                    ),
                  ],
                ),
              ),
            ),

            // 5. Floating Hologram Capsules (appear in semi-circle)
            if (_hologramOpacity.value > 0.01)
              Positioned.fill(
                child: Opacity(
                  opacity: _hologramOpacity.value,
                  child: Stack(
                    children: [
                      // Capsule 1: Blood Group (top-left)
                      _hologramCapsule(
                        left: 10,
                        top: 25,
                        label: "Blood Group: B+",
                        color: AppTheme.accentRed,
                        icon: Icons.bloodtype,
                      ),
                      // Capsule 2: Allergies (top-right)
                      _hologramCapsule(
                        right: 10,
                        top: 20,
                        label: "Allergies: None",
                        color: AppTheme.accentGreen,
                        icon: Icons.check_circle_rounded,
                      ),
                      // Capsule 3: Emergency Contact (mid-left)
                      _hologramCapsule(
                        left: 8,
                        top: 75,
                        label: "Emergency Alert Sent",
                        color: AppTheme.accentTeal,
                        icon: Icons.sos,
                      ),
                      // Capsule 4: Medications (mid-right)
                      _hologramCapsule(
                        right: 8,
                        top: 80,
                        label: "Meds: Crocin",
                        color: AppTheme.accentAmber,
                        icon: Icons.medication,
                      ),
                      // Capsule 5: Organ Pledge (center-top)
                      _hologramCapsule(
                        left: 58,
                        top: 5,
                        label: "Organ Pledge: Verified",
                        color: AppTheme.accentGreen,
                        icon: Icons.verified_user,
                      ),
                    ],
                  ),
                ),
              ),
          ],
        );
      },
    );
  }

  Widget _hologramCapsule({
    double? left,
    double? right,
    required double top,
    required String label,
    required Color color,
    required IconData icon,
  }) {
    return Positioned(
      left: left,
      right: right,
      top: top,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 4),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: color.withOpacity(0.3), width: 1),
          boxShadow: [
            BoxShadow(
              color: color.withOpacity(0.12),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, color: color, size: 9),
            const SizedBox(width: 3),
            Text(
              label,
              style: TextStyle(
                color: AppTheme.textPrimary,
                fontSize: 7,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─── Slide 2 Illustration: India map radar with sliding SMS notification ─────────────────────────────
// ─── Slide 2 Illustration: India map radar with sliding SMS notification ─────────────────────────────
class OnboardingBloodNetworkWidget extends StatelessWidget {
  const OnboardingBloodNetworkWidget({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Image.asset(
        'assets/india_map_cropped.webp',
        fit: BoxFit.contain,
      ),
    );
  }
}

class _TeardropBadge extends StatelessWidget {
  final String label;
  final Color dropColor;

  const _TeardropBadge({
    Key? key,
    required this.label,
    required this.dropColor,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Transform.rotate(
      angle: 0.785,
      child: Container(
        width: 18,
        height: 18,
        decoration: BoxDecoration(
          color: dropColor,
          borderRadius: const BorderRadius.only(
            topLeft: Radius.circular(9),
            topRight: Radius.circular(9),
            bottomLeft: Radius.circular(9),
            bottomRight: Radius.circular(1),
          ),
          boxShadow: [
            BoxShadow(
              color: dropColor.withOpacity(0.35),
              blurRadius: 4,
              offset: const Offset(1, 1),
            ),
          ],
        ),
        child: Transform.rotate(
          angle: -0.785,
          child: Center(
            child: Text(
              label,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 7,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class ConnectionLinesPainter extends CustomPainter {
  final Offset hospital;
  final List<Map<String, dynamic>> nodes;
  final double progress;

  ConnectionLinesPainter({
    required this.hospital,
    required this.nodes,
    required this.progress,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final linePaint = Paint()
      ..color = const Color(0xFFF97316).withOpacity(0.3)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.2;

    final pulsePaint = Paint()
      ..color = const Color(0xFFF97316)
      ..style = PaintingStyle.fill;

    for (var node in nodes) {
      Offset target = Offset(node["x"], node["y"]);
      canvas.drawLine(hospital, target, linePaint);

      Offset pulsePos = hospital + (target - hospital) * progress;
      canvas.drawCircle(pulsePos, 3.0, pulsePaint);
      canvas.drawCircle(
        pulsePos,
        6.0,
        Paint()
          ..color = const Color(0xFFF97316).withOpacity(0.4 * (1.0 - progress))
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.0,
      );
    }
  }

  @override
  bool shouldRepaint(covariant ConnectionLinesPainter oldDelegate) => true;
}

class IndiaMapPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final path = Path();
    double w = size.width;
    double h = size.height;

    path.moveTo(w * 0.46, h * 0.10);
    path.quadraticBezierTo(w * 0.52, h * 0.16, w * 0.50, h * 0.22);
    path.quadraticBezierTo(w * 0.65, h * 0.24, w * 0.72, h * 0.22);
    path.quadraticBezierTo(w * 0.88, h * 0.24, w * 0.90, h * 0.32);
    path.quadraticBezierTo(w * 0.94, h * 0.44, w * 0.84, h * 0.46);
    path.quadraticBezierTo(w * 0.76, h * 0.44, w * 0.68, h * 0.42);
    path.quadraticBezierTo(w * 0.66, h * 0.62, w * 0.58, h * 0.86);
    path.quadraticBezierTo(w * 0.55, h * 0.92, w * 0.54, h * 0.92);
    path.quadraticBezierTo(w * 0.44, h * 0.70, w * 0.34, h * 0.56);
    path.quadraticBezierTo(w * 0.16, h * 0.52, w * 0.18, h * 0.40);
    path.quadraticBezierTo(w * 0.26, h * 0.28, w * 0.30, h * 0.24);
    path.quadraticBezierTo(w * 0.36, h * 0.16, w * 0.46, h * 0.10);
    path.close();

    final shadowPath = path.shift(const Offset(3, 4));
    final shadowPaint = Paint()
      ..color = Colors.black.withOpacity(0.06)
      ..style = PaintingStyle.fill;
    canvas.drawPath(shadowPath, shadowPaint);

    final fillPaint = Paint()
      ..color = const Color(0xFFF6F5EF)
      ..style = PaintingStyle.fill;
    canvas.drawPath(path, fillPaint);

    final strokePaint = Paint()
      ..color = const Color(0xFFE2E0D5)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5;
    canvas.drawPath(path, strokePaint);
  }

  @override
  bool shouldRepaint(covariant IndiaMapPainter oldDelegate) => false;
}

// ─── Slide 3 Illustration: 3 Mini scenes connected by a bezier wave ribbon ─────────────────────────────
class OnboardingOfflineWidget extends StatelessWidget {
  const OnboardingOfflineWidget({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        // 1. Bezier Wave Ribbon in background
        Positioned.fill(
          child: CustomPaint(
            painter: RibbonPainter(),
          ),
        ),

        // 2. Three cards in Row
        Center(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 10),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                // Scene 1: Rural Setting
                _sceneCard(
                  title: "Rural Area",
                  icon: Icons.cloud_off_rounded,
                  badgeText: "No Internet",
                  badgeColor: AppTheme.accentAmber,
                  delay: 0,
                ),
                // Scene 2: Hospital ER
                _sceneCard(
                  title: "Hospital ER",
                  icon: Icons.medical_services_outlined,
                  badgeText: "No App",
                  badgeColor: AppTheme.accentTeal,
                  delay: 200,
                ),
                // Scene 3: Family SMS
                _sceneCard(
                  title: "Family SMS",
                  icon: Icons.contact_phone_outlined,
                  badgeText: "<1 Second",
                  badgeColor: AppTheme.accentGreen,
                  delay: 400,
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _sceneCard({
    required String title,
    required IconData icon,
    required String badgeText,
    required Color badgeColor,
    required int delay,
  }) {
    return Container(
      width: 66,
      height: 120,
      padding: const EdgeInsets.all(6),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppTheme.borderColor),
        boxShadow: const [
          BoxShadow(color: Colors.black12, blurRadius: 6, offset: Offset(0, 2)),
        ],
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          // Scene Icon
          Container(
            padding: const EdgeInsets.all(6),
            decoration: BoxDecoration(
              color: badgeColor.withOpacity(0.08),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, color: badgeColor, size: 16),
          ),
          const SizedBox(height: 6),

          // Scene Title
          Text(
            title,
            style: const TextStyle(
              color: AppTheme.textPrimary,
              fontSize: 8,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 12),

          // Floating Badge
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 3),
            decoration: BoxDecoration(
              color: badgeColor,
              borderRadius: BorderRadius.circular(6),
            ),
            child: Text(
              badgeText,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 6,
                fontWeight: FontWeight.bold,
              ),
              textAlign: TextAlign.center,
            ),
          )
              .animate(onPlay: (c) => c.repeat(reverse: true))
              .scale(begin: const Offset(1.0, 1.0), end: const Offset(1.08, 1.08), duration: 800.ms, delay: delay.ms),
        ],
      ),
    );
  }
}

class RibbonPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..shader = LinearGradient(
        colors: [
          AppTheme.accentTeal.withOpacity(0.25),
          AppTheme.accentGreen.withOpacity(0.25),
        ],
      ).createShader(Rect.fromLTWH(0, 0, size.width, size.height))
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3.5
      ..strokeCap = StrokeCap.round;

    final path = Path();
    double w = size.width;
    double h = size.height;

    // Bezier path waving through the 3 scenes
    path.moveTo(0, h * 0.45);
    path.cubicTo(w * 0.25, h * 0.2, w * 0.45, h * 0.7, w * 0.75, h * 0.35);
    path.quadraticBezierTo(w * 0.9, h * 0.25, w, h * 0.5);

    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant RibbonPainter oldDelegate) => false;
}

class TricolorWavesPainter extends CustomPainter {
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
      ..quadraticBezierTo(w * 0.72, h - 22, w, h - 14)
      ..lineTo(w, h - 19)
      ..quadraticBezierTo(w * 0.72, h - 27, w * 0.45, h)
      ..close();

    final whitePath = Path()
      ..moveTo(w * 0.47, h)
      ..quadraticBezierTo(w * 0.73, h - 17, w, h - 9)
      ..lineTo(w, h - 14)
      ..quadraticBezierTo(w * 0.72, h - 22, w * 0.45, h)
      ..close();

    final greenPath = Path()
      ..moveTo(w * 0.50, h)
      ..quadraticBezierTo(w * 0.74, h - 12, w, h - 4)
      ..lineTo(w, h - 9)
      ..quadraticBezierTo(w * 0.73, h - 17, w * 0.47, h)
      ..close();

    canvas.drawPath(saffronPath, Paint()..color = saffron..style = PaintingStyle.fill);
    canvas.drawPath(whitePath, Paint()..color = white..style = PaintingStyle.fill);
    canvas.drawPath(greenPath, Paint()..color = green..style = PaintingStyle.fill);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class NfcWavePainter extends CustomPainter {
  final Color color;
  NfcWavePainter({required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.2
      ..strokeCap = StrokeCap.round;

    double w = size.width;
    double h = size.height;

    canvas.drawArc(
      Rect.fromCircle(center: Offset(w * 0.2, h / 2), radius: w * 0.2),
      -0.78, 1.56, false, paint,
    );
    canvas.drawArc(
      Rect.fromCircle(center: Offset(w * 0.2, h / 2), radius: w * 0.45),
      -0.78, 1.56, false, paint,
    );
    canvas.drawArc(
      Rect.fromCircle(center: Offset(w * 0.2, h / 2), radius: w * 0.7),
      -0.78, 1.56, false, paint,
    );
    canvas.drawArc(
      Rect.fromCircle(center: Offset(w * 0.2, h / 2), radius: w * 0.95),
      -0.78, 1.56, false, paint,
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class HeartEcgPainter extends CustomPainter {
  final Color color;
  HeartEcgPainter({required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.2
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;

    final path = Path();
    double w = size.width;
    double h = size.height;

    path.moveTo(w / 2, h * 0.25);
    path.cubicTo(w * 0.15, h * 0.05, w * 0.05, h * 0.5, w / 2, h * 0.9);
    path.cubicTo(w * 0.95, h * 0.5, w * 0.85, h * 0.05, w / 2, h * 0.25);
    
    canvas.drawPath(path, paint);

    final ecgPath = Path();
    double midY = h * 0.48;
    ecgPath.moveTo(w * 0.22, midY);
    ecgPath.lineTo(w * 0.40, midY);
    ecgPath.lineTo(w * 0.44, midY - 3);
    ecgPath.lineTo(w * 0.48, midY + 4);
    ecgPath.lineTo(w * 0.52, midY - 6);
    ecgPath.lineTo(w * 0.56, midY + 2);
    ecgPath.lineTo(w * 0.60, midY);
    ecgPath.lineTo(w * 0.78, midY);

    canvas.drawPath(ecgPath, paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class QrPainter extends CustomPainter {
  final Color color;
  QrPainter({required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.fill;

    double w = size.width;
    double h = size.height;
    double anchorSize = w * 0.3;
    
    canvas.drawRect(Rect.fromLTWH(0, 0, anchorSize, anchorSize), paint);
    canvas.drawRect(Rect.fromLTWH(w * 0.06, w * 0.06, anchorSize - w * 0.12, anchorSize - w * 0.12), Paint()..color = Colors.white);
    canvas.drawRect(Rect.fromLTWH(w * 0.10, w * 0.10, anchorSize - w * 0.20, anchorSize - w * 0.20), paint);

    canvas.drawRect(Rect.fromLTWH(w - anchorSize, 0, anchorSize, anchorSize), paint);
    canvas.drawRect(Rect.fromLTWH(w - anchorSize + w * 0.06, w * 0.06, anchorSize - w * 0.12, anchorSize - w * 0.12), Paint()..color = Colors.white);
    canvas.drawRect(Rect.fromLTWH(w - anchorSize + w * 0.10, w * 0.10, anchorSize - w * 0.20, anchorSize - w * 0.20), paint);

    canvas.drawRect(Rect.fromLTWH(0, h - anchorSize, anchorSize, anchorSize), paint);
    canvas.drawRect(Rect.fromLTWH(w * 0.06, h - anchorSize + w * 0.06, anchorSize - w * 0.12, anchorSize - w * 0.12), Paint()..color = Colors.white);
    canvas.drawRect(Rect.fromLTWH(w * 0.10, h - anchorSize + w * 0.10, anchorSize - w * 0.20, anchorSize - w * 0.20), paint);

    double stepX = w / 10;
    double stepY = h / 10;
    final points = [
      const Offset(4, 0), const Offset(5, 0),
      const Offset(0, 4), const Offset(4, 4), const Offset(5, 4), const Offset(6, 4),
      const Offset(4, 5), const Offset(8, 5),
      const Offset(0, 6), const Offset(2, 6), const Offset(5, 6), const Offset(9, 6),
      const Offset(4, 7), const Offset(5, 7), const Offset(6, 7), const Offset(7, 7),
      const Offset(5, 8), const Offset(8, 8), const Offset(9, 8),
      const Offset(4, 9), const Offset(6, 9), const Offset(8, 9),
    ];
    for (var p in points) {
      canvas.drawRect(Rect.fromLTWH(p.dx * stepX, p.dy * stepY, stepX, stepY), paint);
    }
  }

  @override
  bool shouldRepaint(covariant QrPainter oldDelegate) => false;
}
