import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../../../providers/swasthya_tap_provider.dart';
import '../../../models/models.dart';
import '../../../theme/app_theme.dart';
import '../../../utils/prescription_translation_helper.dart';
import 'prescription_share_screen.dart';

class PrescriptionDetailsScreen extends StatefulWidget {
  final String prescriptionId;
  final bool initialOpenTranslation;
  final Function(int)? onTabSelected;

  const PrescriptionDetailsScreen({
    Key? key,
    required this.prescriptionId,
    this.initialOpenTranslation = false,
    this.onTabSelected,
  }) : super(key: key);

  @override
  State<PrescriptionDetailsScreen> createState() => _PrescriptionDetailsScreenState();
}

class _PrescriptionDetailsScreenState extends State<PrescriptionDetailsScreen> {
  String _selectedLanguage = 'English';
  bool _showLanguageDropdown = false;
  bool _animateTransition = false;

  final List<String> _languages = [
    'English',
    'Hindi',
    'Bengali',
    'Telugu',
    'Tamil',
    'Marathi',
    'Gujarati',
    'Kannada',
    'Malayalam',
    'Punjabi',
    'Odia',
    'Urdu',
    'Assamese',
  ];

  @override
  void initState() {
    super.initState();
    if (widget.initialOpenTranslation) {
      _showLanguageDropdown = true;
    }
  }

  void _changeLanguage(String lang) {
    if (lang == _selectedLanguage) return;
    setState(() {
      _animateTransition = true;
    });
    Future.delayed(const Duration(milliseconds: 150), () {
      setState(() {
        _selectedLanguage = lang;
        _animateTransition = false;
      });
    });
  }

  @override
  Widget build(BuildContext context) {
    final provider = Provider.of<SwasthyaTapProvider>(context);
    
    Prescription? rx;
    try {
      rx = provider.prescriptions.firstWhere((p) => p.id == widget.prescriptionId);
    } catch (_) {
      rx = null;
    }

    if (rx == null) {
      return Scaffold(
        appBar: AppBar(),
        body: const Center(child: Text('Prescription not found.')),
      );
    }

    return Scaffold(
      backgroundColor: AppTheme.lightBg,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded, color: AppTheme.textPrimary),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          'Prescription Details',
          style: GoogleFonts.poppins(fontWeight: FontWeight.bold, fontSize: 16, color: AppTheme.textPrimary),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.share_rounded, color: AppTheme.textPrimary),
            onPressed: () => _showShareDialog(),
          ),
          IconButton(
            icon: const Icon(Icons.verified_user_rounded, color: Colors.green),
            tooltip: 'Verify Prescription',
            onPressed: () => _showVerificationSuccessDialog(rx!),
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Language selector bar
            _buildLanguageSelector(),
            const SizedBox(height: 16),

            // Animated Prescription Content Wrapper
            AnimatedOpacity(
              opacity: _animateTransition ? 0.0 : 1.0,
              duration: const Duration(milliseconds: 150),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Doctor Profile Card
                  _buildDoctorProfileCard(rx),
                  const SizedBox(height: 16),

                  // Dates Card
                  _buildDatesCard(rx),
                  const SizedBox(height: 16),

                  // Diagnosis Block
                  _buildDiagnosisBlock(rx),
                  const SizedBox(height: 16),

                  // Medicines Section
                  _buildMedicinesSection(rx),
                  const SizedBox(height: 16),

                  // Recommended Tests Section
                  if (rx.testsRecommended.isNotEmpty) ...[
                    _buildTestsSection(rx),
                    const SizedBox(height: 16),
                  ],

                  // Doctor Notes Section
                  _buildDoctorNotesSection(rx),
                  const SizedBox(height: 24),
                ],
              ),
            ),

            // Bottom Buttons
            _buildActionButtons(rx),
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }

  Widget _buildLanguageSelector() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppTheme.borderColor),
      ),
      child: Column(
        children: [
          GestureDetector(
            onTap: () {
              setState(() {
                _showLanguageDropdown = !_showLanguageDropdown;
              });
            },
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 8.0),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      const Icon(Icons.g_translate_rounded, color: AppTheme.accentTeal, size: 18),
                      const SizedBox(width: 10),
                      Text(
                        'Prescription Language',
                        style: GoogleFonts.poppins(fontSize: 13, fontWeight: FontWeight.w600, color: AppTheme.textPrimary),
                      ),
                    ],
                  ),
                  Row(
                    children: [
                      Text(
                        _selectedLanguage,
                        style: GoogleFonts.poppins(fontSize: 13, fontWeight: FontWeight.bold, color: AppTheme.accentTeal),
                      ),
                      const SizedBox(width: 4),
                      Icon(
                        _showLanguageDropdown ? Icons.keyboard_arrow_up_rounded : Icons.keyboard_arrow_down_rounded,
                        color: AppTheme.accentTeal,
                        size: 20,
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
          if (_showLanguageDropdown)
            Column(
              children: [
                const Divider(height: 1, color: AppTheme.borderColor),
                const SizedBox(height: 8),
                GridView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 2,
                    mainAxisSpacing: 8,
                    crossAxisSpacing: 8,
                    childAspectRatio: 3.5,
                  ),
                  itemCount: _languages.length,
                  itemBuilder: (context, index) {
                    final lang = _languages[index];
                    final isSelected = lang == _selectedLanguage;
                    return GestureDetector(
                      onTap: () => _changeLanguage(lang),
                      child: Container(
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          color: isSelected ? AppTheme.accentTeal.withOpacity(0.08) : AppTheme.lightBg,
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(
                            color: isSelected ? AppTheme.accentTeal : AppTheme.borderColor,
                          ),
                        ),
                        child: Text(
                          lang,
                          style: GoogleFonts.poppins(
                            fontSize: 12,
                            fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                            color: isSelected ? AppTheme.accentTeal : AppTheme.textPrimary,
                          ),
                        ),
                      ),
                    );
                  },
                ),
                const SizedBox(height: 8),
              ],
            ),
        ],
      ),
    );
  }

  Widget _buildDoctorProfileCard(Prescription rx) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppTheme.borderColor),
      ),
      child: Row(
        children: [
          Container(
            width: 50,
            height: 50,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: AppTheme.accentTeal.withOpacity(0.08),
              image: DecorationImage(
                image: NetworkImage(rx.doctorPhoto),
                fit: BoxFit.cover,
              ),
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  rx.doctorName,
                  style: GoogleFonts.poppins(fontSize: 14, fontWeight: FontWeight.bold, color: AppTheme.textPrimary),
                ),
                Text(
                  rx.qualification,
                  style: GoogleFonts.poppins(fontSize: 11.5, color: AppTheme.textSecondary),
                ),
                Text(
                  rx.hospitalName,
                  style: GoogleFonts.poppins(fontSize: 11.5, color: AppTheme.textSecondary),
                ),
              ],
            ),
          ),
          IconButton(
            icon: const Icon(Icons.phone_rounded, color: AppTheme.accentTeal, size: 20),
            style: IconButton.styleFrom(
              backgroundColor: AppTheme.accentTeal.withOpacity(0.08),
              shape: const CircleBorder(),
            ),
            onPressed: () {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text('Calling clinic of ${rx.doctorName}...'),
                  behavior: SnackBarBehavior.floating,
                ),
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildDatesCard(Prescription rx) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppTheme.borderColor),
      ),
      child: Row(
        children: [
          Expanded(
            child: Row(
              children: [
                const Icon(Icons.calendar_today_rounded, size: 16, color: AppTheme.textSecondary),
                const SizedBox(width: 8),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Prescribed Date',
                      style: GoogleFonts.poppins(fontSize: 10, color: AppTheme.textSecondary),
                    ),
                    Text(
                      rx.prescriptionDate,
                      style: GoogleFonts.poppins(fontSize: 12, fontWeight: FontWeight.bold, color: AppTheme.textPrimary),
                    ),
                  ],
                ),
              ],
            ),
          ),
          Container(width: 1, height: 30, color: AppTheme.borderColor),
          const SizedBox(width: 12),
          Expanded(
            child: Row(
              children: [
                const Icon(Icons.event_busy_rounded, size: 16, color: AppTheme.textSecondary),
                const SizedBox(width: 8),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Valid Until',
                      style: GoogleFonts.poppins(fontSize: 10, color: AppTheme.textSecondary),
                    ),
                    Text(
                      rx.validUntil,
                      style: GoogleFonts.poppins(fontSize: 12, fontWeight: FontWeight.bold, color: AppTheme.textPrimary),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDiagnosisBlock(Prescription rx) {
    final translatedDiagnosis = PrescriptionTranslationHelper.get(rx.diagnosis, _selectedLanguage);
    final diagnosisLabel = PrescriptionTranslationHelper.get('Diagnosis', _selectedLanguage);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          diagnosisLabel,
          style: GoogleFonts.poppins(fontSize: 11, fontWeight: FontWeight.w600, color: AppTheme.textSecondary),
        ),
        const SizedBox(height: 4),
        Text(
          translatedDiagnosis,
          style: GoogleFonts.poppins(fontSize: 16, fontWeight: FontWeight.bold, color: AppTheme.textPrimary),
        ),
      ],
    );
  }

  Widget _buildMedicinesSection(Prescription rx) {
    final medicinesLabel = PrescriptionTranslationHelper.get('Medicines', _selectedLanguage);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              '$medicinesLabel (${rx.medicines.length})',
              style: GoogleFonts.poppins(fontSize: 13, fontWeight: FontWeight.bold, color: AppTheme.textPrimary),
            ),
            Text(
              'Show Instructions',
              style: GoogleFonts.poppins(fontSize: 11.5, fontWeight: FontWeight.bold, color: AppTheme.accentTeal),
            ),
          ],
        ),
        const SizedBox(height: 8),
        ListView.separated(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: rx.medicines.length,
          separatorBuilder: (_, __) => const SizedBox(height: 10),
          itemBuilder: (context, index) {
            final med = rx.medicines[index];
            return _buildMedicineCard(med);
          },
        ),
      ],
    );
  }

  Widget _buildMedicineCard(PrescriptionMedicine med) {
    final translatedName = PrescriptionTranslationHelper.get(med.name, _selectedLanguage);
    final translatedQty = PrescriptionTranslationHelper.get(med.quantity, _selectedLanguage);
    final translatedDuration = PrescriptionTranslationHelper.get(med.duration, _selectedLanguage);
    
    String timingStr = '';
    if (med.morning) timingStr += 'Morning ';
    if (med.afternoon) timingStr += 'Afternoon ';
    if (med.night) timingStr += 'Night ';
    timingStr = timingStr.trim().replaceAll(' ', ' • ');
    final translatedTiming = PrescriptionTranslationHelper.get(timingStr, _selectedLanguage);

    final foodStr = med.beforeFood ? 'Before Breakfast' : 'After Food';
    final translatedFood = PrescriptionTranslationHelper.get(foodStr, _selectedLanguage);

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppTheme.borderColor),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Text(
                  translatedName,
                  style: GoogleFonts.poppins(fontSize: 13.5, fontWeight: FontWeight.bold, color: AppTheme.textPrimary),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: AppTheme.accentTeal.withOpacity(0.08),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  translatedDuration,
                  style: GoogleFonts.poppins(fontSize: 9.5, fontWeight: FontWeight.bold, color: AppTheme.accentTeal),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            '$translatedQty • $translatedFood',
            style: GoogleFonts.poppins(fontSize: 11.5, color: AppTheme.textSecondary),
          ),
          const SizedBox(height: 10),

          // Dose time indicator icons
          Row(
            children: [
              if (med.morning)
                _buildDoseIconTag(Icons.wb_sunny_outlined, 'Morning', Colors.amber),
              if (med.afternoon)
                _buildDoseIconTag(Icons.wb_cloudy_outlined, 'Afternoon', Colors.orange),
              if (med.night)
                _buildDoseIconTag(Icons.nightlight_outlined, 'Night', Colors.indigo),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildDoseIconTag(IconData icon, String label, Color color) {
    final translatedLabel = PrescriptionTranslationHelper.get(label, _selectedLanguage);
    return Container(
      margin: const EdgeInsets.only(right: 8),
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withOpacity(0.08),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Row(
        children: [
          Icon(icon, size: 12, color: color),
          const SizedBox(width: 4),
          Text(
            translatedLabel,
            style: GoogleFonts.poppins(fontSize: 9, fontWeight: FontWeight.bold, color: color),
          ),
        ],
      ),
    );
  }

  Widget _buildTestsSection(Prescription rx) {
    final testsLabel = PrescriptionTranslationHelper.get('Tests Recommended', _selectedLanguage);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          testsLabel,
          style: GoogleFonts.poppins(fontSize: 12, fontWeight: FontWeight.bold, color: AppTheme.textPrimary),
        ),
        const SizedBox(height: 6),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: AppTheme.borderColor),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: rx.testsRecommended.map((test) {
              return Padding(
                padding: const EdgeInsets.symmetric(vertical: 4),
                child: Row(
                  children: [
                    const Icon(Icons.check_circle_outline_rounded, size: 14, color: AppTheme.accentTeal),
                    const SizedBox(width: 8),
                    Text(
                      test,
                      style: GoogleFonts.poppins(fontSize: 12.5, color: AppTheme.textPrimary, fontWeight: FontWeight.w500),
                    ),
                  ],
                ),
              );
            }).toList(),
          ),
        ),
      ],
    );
  }

  Widget _buildDoctorNotesSection(Prescription rx) {
    final notesLabel = PrescriptionTranslationHelper.get('Doctor Notes', _selectedLanguage);
    final translatedNotes = PrescriptionTranslationHelper.get(rx.doctorNotes, _selectedLanguage);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          notesLabel,
          style: GoogleFonts.poppins(fontSize: 12, fontWeight: FontWeight.bold, color: AppTheme.textPrimary),
        ),
        const SizedBox(height: 6),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: const Color(0xFFF0FDFA), // Teal tint
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: const Color(0xFFCCFBF1)),
          ),
          child: Text(
            translatedNotes,
            style: GoogleFonts.poppins(fontSize: 12, color: const Color(0xFF0F766E), height: 1.4, fontWeight: FontWeight.w500),
          ),
        ),
      ],
    );
  }

  Widget _buildActionButtons(Prescription rx) {
    return Column(
      children: [
        Row(
          children: [
            Expanded(
              child: ElevatedButton.icon(
                onPressed: () {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Downloading prescription PDF...'),
                      behavior: SnackBarBehavior.floating,
                    ),
                  );
                },
                icon: const Icon(Icons.picture_as_pdf_rounded, size: 16, color: Colors.white),
                label: const Text('Save PDF'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.textPrimary,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  elevation: 0,
                  textStyle: GoogleFonts.poppins(fontSize: 13, fontWeight: FontWeight.bold),
                ),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: ElevatedButton.icon(
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => PrescriptionShareScreen(prescriptionId: rx.id),
                    ),
                  );
                },
                icon: const Icon(Icons.qr_code_2_rounded, size: 16, color: Colors.white),
                label: const Text('Generate QR'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.accentTeal,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  elevation: 0,
                  textStyle: GoogleFonts.poppins(fontSize: 13, fontWeight: FontWeight.bold),
                ),
              ),
            ),
          ],
        ),
        if (_selectedLanguage == 'English') ...[
          const SizedBox(height: 10),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton(
              onPressed: () => _changeLanguage('Hindi'),
              style: OutlinedButton.styleFrom(
                side: const BorderSide(color: AppTheme.accentTeal),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                padding: const EdgeInsets.symmetric(vertical: 12),
              ),
              child: Text(
                'View in Hindi (हिंदी)',
                style: GoogleFonts.poppins(fontSize: 13, fontWeight: FontWeight.bold, color: AppTheme.accentTeal),
              ),
            ),
          ),
        ],
      ],
    );
  }

  void _showShareDialog() {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (context) {
        return Container(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'Share Prescription',
                style: GoogleFonts.poppins(fontSize: 15, fontWeight: FontWeight.bold, color: AppTheme.textPrimary),
              ),
              const SizedBox(height: 20),
              ListTile(
                leading: const Icon(Icons.copy_rounded, color: AppTheme.accentTeal),
                title: const Text('Copy Secure Link'),
                onTap: () {
                  Navigator.pop(context);
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Secure sharing link copied to clipboard.'),
                      behavior: SnackBarBehavior.floating,
                    ),
                  );
                },
              ),
              ListTile(
                leading: const Icon(Icons.message_rounded, color: AppTheme.accentTeal),
                title: const Text('Share via SMS/WhatsApp'),
                onTap: () {
                  Navigator.pop(context);
                },
              ),
            ],
          ),
        );
      },
    );
  }

  void _showVerificationSuccessDialog(Prescription rx) {
    showDialog(
      context: context,
      builder: (context) {
        return Dialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          child: Padding(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // 1. Success Mark
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: const BoxDecoration(
                    color: Color(0xFFDCFCE7),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.check_circle_rounded, color: Colors.green, size: 50),
                ),
                const SizedBox(height: 16),

                // Title
                Text(
                  'Verified Digital Prescription',
                  style: GoogleFonts.poppins(fontSize: 15, fontWeight: FontWeight.bold, color: AppTheme.textPrimary),
                ),
                const SizedBox(height: 6),
                Text(
                  'This prescription has been digitally verified and can be used at any connected pharmacy.',
                  style: GoogleFonts.poppins(fontSize: 11.5, color: AppTheme.textSecondary),
                  textAlign: TextAlign.center,
                ),

                const SizedBox(height: 20),
                const Divider(height: 1, color: AppTheme.borderColor),
                const SizedBox(height: 16),

                // Prescription Details
                _buildVerificationRow('Doctor', rx.doctorName),
                _buildVerificationRow('Hospital', rx.hospitalName),
                _buildVerificationRow('Date', rx.prescriptionDate),
                _buildVerificationRow('Valid Until', rx.validUntil),
                _buildVerificationRow('Prescription ID', rx.id, isCode: true),

                const SizedBox(height: 24),

                // Button row
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: () => Navigator.pop(context),
                        style: OutlinedButton.styleFrom(
                          side: const BorderSide(color: AppTheme.borderColor),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                        ),
                        child: Text(
                          'Close',
                          style: GoogleFonts.poppins(fontWeight: FontWeight.bold, fontSize: 13, color: AppTheme.textSecondary),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: ElevatedButton(
                        onPressed: () => Navigator.pop(context),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.green,
                          elevation: 0,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                        ),
                        child: Text(
                          'Done',
                          style: GoogleFonts.poppins(fontWeight: FontWeight.bold, fontSize: 13, color: Colors.white),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildVerificationRow(String label, String value, {bool isCode = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: GoogleFonts.poppins(fontSize: 11, color: AppTheme.textSecondary, fontWeight: FontWeight.w500),
          ),
          Text(
            value,
            style: isCode
                ? const TextStyle(
                    fontFamily: 'Courier',
                    fontSize: 11.5,
                    fontWeight: FontWeight.bold,
                    color: AppTheme.accentTeal,
                  )
                : GoogleFonts.poppins(
                    fontSize: 11.5,
                    fontWeight: FontWeight.bold,
                    color: AppTheme.textPrimary,
                  ),
          ),
        ],
      ),
    );
  }
}
