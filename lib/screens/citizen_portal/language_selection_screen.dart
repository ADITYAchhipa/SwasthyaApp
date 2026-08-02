import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../../providers/swasthya_tap_provider.dart';
import '../../utils/translation_service.dart';
import '../../theme/app_theme.dart';
import 'citizen_dashboard.dart';

class LanguageSelectionScreen extends StatefulWidget {
  const LanguageSelectionScreen({Key? key}) : super(key: key);

  @override
  State<LanguageSelectionScreen> createState() => _LanguageSelectionScreenState();
}

class _LanguageSelectionScreenState extends State<LanguageSelectionScreen> {
  String _selectedLang = 'Hindi'; // Hindi is selected by default in mockup

  final List<Map<String, String>> _languages = [
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

  void _onConfirm(SwasthyaTapProvider provider) {
    provider.setSelectedLanguage(_selectedLang);
    
    // Show a Toast confirmation
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          _selectedLang == 'Hindi'
              ? 'भाषा बदलकर हिन्दी कर दी गई है!'
              : 'Language changed to $_selectedLang!',
        ),
        backgroundColor: AppTheme.accentTeal,
      ),
    );

    Navigator.pushReplacement(
      context,
      MaterialPageRoute(builder: (_) => const CitizenDashboard()),
    );
  }

  @override
  Widget build(BuildContext context) {
    final provider = Provider.of<SwasthyaTapProvider>(context, listen: false);

    return Scaffold(
      backgroundColor: AppTheme.lightBg,
      body: Stack(
        children: [
          SafeArea(
            child: Column(
              children: [
                // Top Header (Back + Logo)
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  child: Row(
                    children: [
                      IconButton(
                        onPressed: () => Navigator.pop(context),
                        icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 16, color: AppTheme.textPrimary),
                        style: IconButton.styleFrom(
                          backgroundColor: Colors.white,
                          elevation: 1,
                          padding: const EdgeInsets.all(12),
                        ),
                      ),
                      Expanded(
                        child: Center(
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Row(
                                mainAxisSize: MainAxisSize.min,
                                children: const [
                                  Icon(Icons.favorite_rounded, color: AppTheme.accentTeal, size: 18),
                                  SizedBox(width: 4),
                                  Text(
                                    'SwasthyaTap.in',
                                    style: TextStyle(
                                      color: AppTheme.textPrimary,
                                      fontWeight: FontWeight.bold,
                                      fontSize: 15,
                                    ),
                                  ),
                                ],
                              ),
                              const Text(
                                'One Tap Can Save Your Life',
                                style: TextStyle(color: AppTheme.textSecondary, fontSize: 8, fontWeight: FontWeight.bold),
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(width: 44), // balance back button space
                    ],
                  ),
                ),
                
                Expanded(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    child: Column(
                      children: [
                        const SizedBox(height: 16),
                        
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
                          'Choose Your Language',
                          style: Theme.of(context).textTheme.displayMedium?.copyWith(
                            fontSize: 24,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 4),
                        const Text(
                          'You can change this anytime in settings.',
                          style: TextStyle(color: AppTheme.textSecondary, fontSize: 13.5),
                        ),
                        
                        const SizedBox(height: 18),
                        
                        // Heart rate ECG divider
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
                        
                        const SizedBox(height: 24),
                        
                        // Languages Grid
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
                            final isSelected = _selectedLang == lang['code'];
                            
                            return GestureDetector(
                              onTap: () {
                                setState(() {
                                  _selectedLang = lang['code']!;
                                });
                              },
                              child: AnimatedContainer(
                                duration: const Duration(milliseconds: 200),
                                decoration: BoxDecoration(
                                  color: isSelected ? AppTheme.accentTeal.withOpacity(0.05) : Colors.white,
                                  borderRadius: BorderRadius.circular(16),
                                  border: Border.all(
                                    color: isSelected ? AppTheme.accentTeal : AppTheme.borderColor,
                                    width: isSelected ? 1.5 : 1.0,
                                  ),
                                  boxShadow: [
                                    BoxShadow(
                                      color: isSelected
                                          ? AppTheme.accentTeal.withOpacity(0.04)
                                          : Colors.black.withOpacity(0.01),
                                      blurRadius: 8,
                                      offset: const Offset(0, 4),
                                    ),
                                  ],
                                ),
                                child: Stack(
                                  children: [
                                    // Checkmark for selected item
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
                                    // Center content
                                    Center(
                                      child: Column(
                                        mainAxisAlignment: MainAxisAlignment.center,
                                        children: [
                                          Text(
                                            lang['native']!,
                                            style: TextStyle(
                                              color: isSelected ? AppTheme.accentTeal : AppTheme.textPrimary,
                                              fontWeight: FontWeight.bold,
                                              fontSize: 16,
                                            ),
                                          ),
                                          const SizedBox(height: 4),
                                          Text(
                                            lang['english']!,
                                            style: const TextStyle(
                                              color: AppTheme.textSecondary,
                                              fontSize: 10.5,
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
                        
                        // Supports 12+ banner
                        Container(
                          padding: const EdgeInsets.all(14),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(color: AppTheme.borderColor),
                          ),
                          child: Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.all(8),
                                decoration: BoxDecoration(
                                  color: AppTheme.accentTeal.withOpacity(0.08),
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                child: const Icon(Icons.language_rounded, color: AppTheme.accentTeal, size: 20),
                              ),
                              const SizedBox(width: 14),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: const [
                                    Text(
                                      'SwasthyaTap supports 12+ Indian languages',
                                      style: TextStyle(
                                        fontWeight: FontWeight.bold,
                                        fontSize: 11.5,
                                        color: AppTheme.textPrimary,
                                      ),
                                    ),
                                    SizedBox(height: 2),
                                    Text(
                                      'More languages coming soon...',
                                      style: TextStyle(
                                        fontSize: 10,
                                        color: AppTheme.textSecondary,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 120), // spacer for bottom confirm button
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
          
          // Confirm Button fixed at bottom
          Positioned(
            left: 20,
            right: 20,
            bottom: 20,
            child: SizedBox(
              width: double.infinity,
              height: 54,
              child: ElevatedButton(
                onPressed: () => _onConfirm(provider),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.accentTeal,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                  elevation: 5,
                  shadowColor: AppTheme.accentTeal.withOpacity(0.2),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      TranslationService.tLang(_selectedLang, 'confirm_language'),
                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                    ),
                    const SizedBox(width: 8),
                    const Icon(Icons.arrow_forward_rounded, size: 18),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
