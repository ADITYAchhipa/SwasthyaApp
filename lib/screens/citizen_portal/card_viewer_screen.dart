import 'dart:math';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:printing/printing.dart';
import 'package:pdf/pdf.dart';
import '../../providers/swasthya_tap_provider.dart';
import '../../models/models.dart';
import '../../theme/app_theme.dart';
import 'package:flutter/services.dart';
import '../../utils/card_pdf_generator.dart';
import '../../utils/pdf_downloader.dart';
import 'order_card_screen.dart';
import '../../utils/translation_service.dart';

class CardViewerScreen extends StatefulWidget {
  const CardViewerScreen({Key? key}) : super(key: key);

  @override
  State<CardViewerScreen> createState() => _CardViewerScreenState();
}

class _CardViewerScreenState extends State<CardViewerScreen> with SingleTickerProviderStateMixin {
  // 3D Card Rotation State
  double _rotationX = 0.15; // default angle tilted forward
  double _rotationY = 0.0;
  
  // Animation for tap-to-flip
  late AnimationController _flipController;
  late Animation<double> _flipAnimation;
  bool _isFlipped = false;
  
  // Card Customization State
  String _selectedVariant = 'Standard';
  String _selectedLanguage = 'English';
  
  // Toggle Visibility State
  bool _showBloodGroup = true;
  bool _showEmergencyContacts = true;
  bool _showAllergies = false;
  bool _showMedicalConditions = false;

  // PDF Caching State to bypass pop-up blockers
  Uint8List? _cachedPdfBytes;
  bool _isGenerating = false;
  bool _needsRegeneration = true;

  void _updateState(VoidCallback callback) {
    setState(() {
      callback();
      _needsRegeneration = true;
    });
  }

  Future<void> _pregeneratePdf(MedicalProfile citizen) async {
    try {
      final bytes = await generateCardPdfBytes(
        citizen: citizen,
        selectedVariant: _selectedVariant,
        selectedLanguage: _selectedLanguage,
        showBloodGroup: _showBloodGroup,
        showEmergencyContacts: _showEmergencyContacts,
        showAllergies: _showAllergies,
        showMedicalConditions: _showMedicalConditions,
      );
      _cachedPdfBytes = bytes;
      _needsRegeneration = false;
      _isGenerating = false;
    } catch (e) {
      _isGenerating = false;
      debugPrint('Error pre-generating PDF: $e');
    }
  }

  @override
  void initState() {
    super.initState();
    _flipController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );
    
    _flipAnimation = Tween<double>(begin: 0, end: pi).animate(
      CurvedAnimation(parent: _flipController, curve: Curves.easeOutBack),
    )..addListener(() {
        setState(() {
          _rotationY = _flipAnimation.value + (_isFlipped ? pi : 0);
        });
      });
  }

  @override
  void dispose() {
    _flipController.dispose();
    super.dispose();
  }

  void _triggerFlip() {
    if (_flipController.isAnimating) return;
    
    if (_isFlipped) {
      _flipController.reverse().then((_) {
        _isFlipped = false;
      });
    } else {
      _flipController.forward().then((_) {
        _isFlipped = true;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final provider = Provider.of<SwasthyaTapProvider>(context);
    final citizen = provider.currentCitizen;

    if (_needsRegeneration && !_isGenerating) {
      _isGenerating = true;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _pregeneratePdf(citizen);
      });
    }

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded, color: Color(0xFF0F172A)),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '3D Card Viewer',
              style: GoogleFonts.outfit(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: const Color(0xFF0F172A),
              ),
            ),
            Text(
              'Drag to rotate • Tap to flip',
              style: GoogleFonts.inter(
                fontSize: 11,
                color: const Color(0xFF64748B),
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
        actions: [
          Container(
            margin: const EdgeInsets.only(right: 16, top: 10, bottom: 10),
            child: OutlinedButton.icon(
              onPressed: () {
                // Toggle simple fullscreen dialog/snackbar
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Fullscreen Mode Enabled')),
                );
              },
              icon: const Icon(Icons.fullscreen_rounded, size: 16, color: Color(0xFF0F172A)),
              label: Text(
                'Fullscreen',
                style: GoogleFonts.inter(
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                  color: const Color(0xFF0F172A),
                ),
              ),
              style: OutlinedButton.styleFrom(
                side: const BorderSide(color: Color(0xFFE2E8F0)),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                padding: const EdgeInsets.symmetric(horizontal: 14),
              ),
            ),
          ),
        ],
      ),
      body: SingleChildScrollView(
        physics: const BouncingScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 40),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 1. Interactive 3D Card Area
            Center(
              child: GestureDetector(
                onPanUpdate: (details) {
                  setState(() {
                    _rotationY -= details.delta.dx * 0.01;
                  });
                },
                onTap: _triggerFlip,
                child: Container(
                  height: 280,
                  width: double.infinity,
                  color: Colors.transparent,
                  child: Center(
                    child: Transform(
                      transform: Matrix4.identity()
                        ..setEntry(3, 2, 0.0012) // perspective
                        ..rotateX(_rotationX)
                        ..rotateY(_rotationY),
                      alignment: Alignment.center,
                      child: _buildCardFace(citizen),
                    ),
                  ),
                ),
              ),
            ),
            
            // Dot Indicator
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  width: 8,
                  height: 8,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: !_isFlipped ? const Color(0xFF0D9488) : const Color(0xFFCBD5E1),
                  ),
                ),
                const SizedBox(width: 6),
                Container(
                  width: 8,
                  height: 8,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: _isFlipped ? const Color(0xFF0D9488) : const Color(0xFFCBD5E1),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 24),

            // 2. Row of Action Cards (Download PDF, Print Card, Order Card, Share Preview)
            IntrinsicHeight(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Expanded(
                    child: _buildActionCard(
                      'Download PDF',
                      Icons.picture_as_pdf_rounded,
                      const Color(0xFF0D9488),
                      'Download as PDF',
                      onTap: () => _downloadCardPdf(citizen),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: _buildActionCard(
                      'Print Card',
                      Icons.print_rounded,
                      const Color(0xFFF97316),
                      'Print as PDF',
                      onTap: () => _printCardPdf(citizen),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: _buildActionCard(
                      'Order Card',
                      Icons.shopping_cart_rounded,
                      const Color(0xFF0D9488),
                      'Get physical card',
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => OrderCardScreen(citizen: citizen),
                          ),
                        );
                      },
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: _buildActionCard(
                      'Share Preview',
                      Icons.share_rounded,
                      const Color(0xFF8B5CF6),
                      'Share digital card',
                      onTap: () => _showShareDialog(citizen),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 28),

            // 3. Card Customization Section
            Text(
              'Card Customization',
              style: GoogleFonts.outfit(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: const Color(0xFF0F172A),
              ),
            ),
            const SizedBox(height: 16),

            // Language on Card Dropdown
            Text(
              'Language on Card',
              style: GoogleFonts.inter(
                fontSize: 12,
                fontWeight: FontWeight.bold,
                color: const Color(0xFF64748B),
              ),
            ),
            const SizedBox(height: 10),
            
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: const Color(0xFFE2E8F0)),
              ),
              child: DropdownButtonHideUnderline(
                child: DropdownButton<String>(
                  value: _selectedLanguage,
                  isExpanded: true,
                  icon: const Icon(Icons.arrow_drop_down, color: Color(0xFF0F172A)),
                  items: <String>[
                    'English', 'Hindi', 'Bengali', 'Telugu', 'Tamil', 'Marathi',
                    'Gujarati', 'Kannada', 'Malayalam', 'Punjabi', 'Odia', 'Urdu'
                  ]
                      .map<DropdownMenuItem<String>>((String value) {
                    return DropdownMenuItem<String>(
                      value: value,
                      child: Text(
                        value,
                        style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.bold, color: const Color(0xFF0F172A)),
                      ),
                    );
                  }).toList(),
                  onChanged: (String? newValue) {
                    if (newValue != null) {
                      _updateState(() {
                        _selectedLanguage = newValue;
                      });
                    }
                  },
                ),
              ),
            ),
            const SizedBox(height: 20),

            // Show on Card Toggles
            Text(
              'Show on Card',
              style: GoogleFonts.inter(
                fontSize: 12,
                fontWeight: FontWeight.bold,
                color: const Color(0xFF64748B),
              ),
            ),
            const SizedBox(height: 10),
            
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                _buildToggleChip('Blood Group', _showBloodGroup, (val) => _updateState(() => _showBloodGroup = val)),
                _buildToggleChip('Emergency Contacts', _showEmergencyContacts, (val) => _updateState(() => _showEmergencyContacts = val)),
                _buildToggleChip('Allergies', _showAllergies, (val) => _updateState(() => _showAllergies = val)),
                _buildToggleChip('Medical Conditions', _showMedicalConditions, (val) => _updateState(() => _showMedicalConditions = val)),
              ],
            ),
            const SizedBox(height: 32),

            // Footer Privacy Banner
            Center(
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.lock_outline_rounded, size: 14, color: Color(0xFF64748B)),
                  const SizedBox(width: 6),
                  Text(
                    'All data is encrypted and secure • You\'re in control',
                    style: GoogleFonts.inter(
                      fontSize: 10.5,
                      fontWeight: FontWeight.w500,
                      color: const Color(0xFF64748B),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _downloadCardPdf(MedicalProfile citizen) async {
    final filename = 'SwasthTap_Card_${citizen.fullName.replaceAll(' ', '_')}.pdf';
    
    // If cached, trigger download instantly in the same event loop to bypass pop-up blockers
    if (_cachedPdfBytes != null && !_needsRegeneration) {
      downloadPdfFile(_cachedPdfBytes!, filename);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('PDF downloaded successfully!'),
          backgroundColor: Color(0xFF0D9488),
        ),
      );
      return;
    }

    // Fallback if not pre-generated yet
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return Center(
          child: Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
            ),
            child: const Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                CircularProgressIndicator(
                  valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF0D9488)),
                ),
                SizedBox(height: 16),
                Text(
                  'Generating PDF...',
                  style: TextStyle(
                    fontFamily: 'Inter',
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF0F172A),
                    decoration: TextDecoration.none,
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );

    try {
      final pdfBytes = await generateCardPdfBytes(
        citizen: citizen,
        selectedVariant: _selectedVariant,
        selectedLanguage: _selectedLanguage,
        showBloodGroup: _showBloodGroup,
        showEmergencyContacts: _showEmergencyContacts,
        showAllergies: _showAllergies,
        showMedicalConditions: _showMedicalConditions,
      );

      if (!mounted) return;
      Navigator.pop(context);

      downloadPdfFile(pdfBytes, filename);

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('PDF downloaded successfully!'),
          backgroundColor: Color(0xFF0D9488),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error generating PDF: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Future<void> _printCardPdf(MedicalProfile citizen) async {
    try {
      await Printing.layoutPdf(
        onLayout: (PdfPageFormat format) async {
          if (_cachedPdfBytes != null && !_needsRegeneration) {
            return _cachedPdfBytes!;
          }
          return await generateCardPdfBytes(
            citizen: citizen,
            selectedVariant: _selectedVariant,
            selectedLanguage: _selectedLanguage,
            showBloodGroup: _showBloodGroup,
            showEmergencyContacts: _showEmergencyContacts,
            showAllergies: _showAllergies,
            showMedicalConditions: _showMedicalConditions,
          );
        },
        name: 'SwasthTap_Card_${citizen.fullName.replaceAll(' ', '_')}.pdf',
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error printing PDF: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  void _showShareDialog(MedicalProfile citizen) {
    final profileUrl = 'https://swasthtap.in/citizen/${citizen.id}';
    final shareText = 'Check out my SwasthTap Emergency Medical Profile: $profileUrl';
    
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (BuildContext context) {
        return Container(
          padding: const EdgeInsets.all(24),
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Share Profile Card',
                    style: GoogleFonts.outfit(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: const Color(0xFF0F172A),
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close_rounded, color: Color(0xFF64748B)),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                'Share your secure digital medical profile link with others.',
                style: GoogleFonts.inter(
                  fontSize: 12,
                  color: const Color(0xFF64748B),
                ),
              ),
              const SizedBox(height: 24),
              
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  _buildShareOptionItem(
                    icon: Icons.chat_bubble_outline_rounded,
                    color: const Color(0xFF25D366),
                    label: 'WhatsApp',
                    onTap: () {
                      Navigator.pop(context);
                      final url = 'https://api.whatsapp.com/send?text=${Uri.encodeComponent(shareText)}';
                      launchShareUrl(url);
                    },
                  ),
                  _buildShareOptionItem(
                    icon: Icons.mail_outline_rounded,
                    color: const Color(0xFFEA4335),
                    label: 'Email',
                    onTap: () {
                      Navigator.pop(context);
                      final url = 'mailto:?subject=${Uri.encodeComponent("SwasthTap Emergency Medical Card")}&body=${Uri.encodeComponent(shareText)}';
                      launchShareUrl(url);
                    },
                  ),
                  _buildShareOptionItem(
                    icon: Icons.copy_rounded,
                    color: const Color(0xFF0F766E),
                    label: 'Copy Link',
                    onTap: () {
                      Navigator.pop(context);
                      Clipboard.setData(ClipboardData(text: profileUrl));
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('Profile link copied to clipboard!'),
                          backgroundColor: Color(0xFF0F766E),
                        ),
                      );
                    },
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildShareOptionItem({
    required IconData icon,
    required Color color,
    required String label,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        width: 80,
        padding: const EdgeInsets.symmetric(vertical: 12),
        child: Column(
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: color.withOpacity(0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(icon, color: color, size: 28),
            ),
            const SizedBox(height: 8),
            Text(
              label,
              style: GoogleFonts.inter(
                fontSize: 12,
                fontWeight: FontWeight.bold,
                color: const Color(0xFF0F172A),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // Helper to build action card buttons
  Widget _buildActionCard(String title, IconData icon, Color color, String desc, {required VoidCallback onTap}) {
    return InkWell(
      onTap: onTap,
      child: Container(
        height: double.infinity,
        padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 8),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: const Color(0xFFE2E8F0)),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.02),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, color: color, size: 24),
            const SizedBox(height: 8),
            Text(
              title,
              textAlign: TextAlign.center,
              style: GoogleFonts.inter(
                fontSize: 11,
                fontWeight: FontWeight.bold,
                color: const Color(0xFF0F172A),
              ),
            ),
            const SizedBox(height: 4),
            Text(
              desc,
              textAlign: TextAlign.center,
              style: GoogleFonts.inter(
                fontSize: 8.5,
                color: const Color(0xFF64748B),
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // Helper to build Variant Item Card selector
  Widget _buildVariantItem(String name, Color primaryColor, String label) {
    final isSelected = _selectedVariant == name;
    
    // Draw miniature previews of variants
    Gradient miniGrad;
    Color textColor = Colors.white;
    
    switch (name) {
      case 'Worker':
        miniGrad = const LinearGradient(colors: [Color(0xFFEA580C), Color(0xFFF97316)]);
        break;
      case 'Senior':
        miniGrad = const LinearGradient(colors: [Color(0xFF047857), Color(0xFF065F46)]);
        break;
      case 'Child':
        miniGrad = const LinearGradient(colors: [Color(0xFFFBBF24), Color(0xFFF59E0B)]);
        textColor = const Color(0xFF78350F);
        break;
      case 'Premium':
        miniGrad = const LinearGradient(colors: [Color(0xFF1E1B4B), Color(0xFF0F172A)]);
        break;
      default:
        miniGrad = const LinearGradient(colors: [Color(0xFF018086), Color(0xFF011E30)]);
    }

    return GestureDetector(
      onTap: () {
        _updateState(() {
          _selectedVariant = name;
        });
      },
      child: Container(
        width: 100,
        margin: const EdgeInsets.only(right: 12),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isSelected ? const Color(0xFF0D9488) : const Color(0xFFE2E8F0),
            width: isSelected ? 2 : 1,
          ),
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(10),
          child: Stack(
            children: [
              // Card representation
              Container(
                decoration: BoxDecoration(gradient: miniGrad),
                child: Center(
                  child: Text(
                    label,
                    style: GoogleFonts.outfit(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      color: textColor,
                    ),
                  ),
                ),
              ),
              
              // Top-right check circle
              if (isSelected)
                Positioned(
                  top: 4,
                  right: 4,
                  child: Container(
                    decoration: const BoxDecoration(
                      color: Colors.white,
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.check_circle_rounded,
                      color: Color(0xFF0D9488),
                      size: 14,
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  // Toggle Chip Builder
  Widget _buildToggleChip(String label, bool value, ValueChanged<bool> onChanged) {
    return GestureDetector(
      onTap: () => onChanged(!value),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: value ? const Color(0xFFE6F4F1) : Colors.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: value ? const Color(0xFF0D9488) : const Color(0xFFE2E8F0),
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              label,
              style: GoogleFonts.inter(
                fontSize: 11.5,
                fontWeight: FontWeight.bold,
                color: value ? const Color(0xFF0D9488) : const Color(0xFF64748B),
              ),
            ),
            if (value) ...[
              const SizedBox(width: 4),
              const Icon(Icons.check_rounded, size: 12, color: Color(0xFF0D9488)),
            ],
          ],
        ),
      ),
    );
  }

  // 3D Card Face Selector (displays front or mirrored back depending on rotation)
  Widget _buildCardFace(MedicalProfile citizen) {
    // Normalize rotation angle
    final normalizedY = _rotationY % (2 * pi);
    
    // Front side condition
    final isFront = cos(normalizedY) >= 0;
    
    if (isFront) {
      return _buildCardFront(citizen);
    } else {
      // Counter-rotate the back side on Y-axis by pi so it displays non-mirrored/correctly oriented
      return Transform(
        transform: Matrix4.identity()..rotateY(pi),
        alignment: Alignment.center,
        child: _buildCardBack(citizen),
      );
    }
  }

  // Card Theme Parameters based on Customization selection
  LinearGradient _getCardGradient() {
    switch (_selectedVariant) {
      case 'Worker':
        return const LinearGradient(
          colors: [Color(0xFFEA580C), Color(0xFFD84A06), Color(0xFF9A3412)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        );
      case 'Senior':
        return const LinearGradient(
          colors: [Color(0xFF065F46), Color(0xFF047857), Color(0xFF064E3B)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        );
      case 'Child':
        return const LinearGradient(
          colors: [Color(0xFFFBBF24), Color(0xFFF59E0B), Color(0xFFD97706)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        );
      case 'Premium':
        return const LinearGradient(
          colors: [Color(0xFF1E1B4B), Color(0xFF0F172A), Color(0xFF030712)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        );
      default: // Standard
        return const LinearGradient(
          colors: [
            Color(0xFF018086), // Vibrant Teal-Cyan (exact match)
            Color(0xFF014757), // Smooth transition teal-navy
            Color(0xFF011E30), // Deep Navy Blue (exact match)
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        );
    }
  }

  Color _getCardTextColor() {
    return Colors.white;
  }

  // FRONT Card Face (Standard Clean Mockup Style - logo, QR, NFC, Tricolor only)
  Widget _buildCardFront(MedicalProfile citizen) {
    final gradient = _getCardGradient();

    return Container(
      width: 335,
      height: 210,
      decoration: BoxDecoration(
        gradient: gradient,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: Colors.white.withOpacity(0.18),
          width: 1.2,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.3),
            blurRadius: 18,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: Stack(
          children: [
            // Custom drawn tricolor curve details at bottom right
            Positioned(
              bottom: 0,
              right: 0,
              left: 120,
              height: 35,
              child: CustomPaint(
                painter: CardTricolorWavePainter(variant: _selectedVariant),
              ),
            ),
            
            // Top Right: Contactless waves NFC symbol
            Positioned(
              top: 18,
              right: 18,
              child: CustomPaint(
                size: const Size(18, 20),
                painter: ContactlessWavesPainter(color: Colors.white.withOpacity(0.9)),
              ),
            ),

            // Bottom Left: QR Code (white box with QR)
            Positioned(
              bottom: 14,
              left: 14,
              child: Container(
                padding: const EdgeInsets.all(3.5),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Image.network(
                  'https://api.qrserver.com/v1/create-qr-code/?size=150x150&data=https://swasthtap.in/citizen/${citizen.id}',
                  width: 46,
                  height: 46,
                  fit: BoxFit.contain,
                  gaplessPlayback: true,
                ),
              ),
            ),

            // Center: SwasthTap Logo (Heart-ECG) & taglines
            Center(
              child: Row(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  CustomPaint(
                    size: const Size(40, 40),
                    painter: HeartEcgPainter(color: Colors.white),
                  ),
                  const SizedBox(width: 12),
                  Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'SwasthTap',
                        style: GoogleFonts.outfit(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: 28,
                          letterSpacing: -0.4,
                        ),
                      ),
                      Text(
                        'आपकी स्वास्थ्य पहचान',
                        style: GoogleFonts.inter(
                          color: Colors.white.withOpacity(0.85),
                          fontSize: 10,
                          fontWeight: FontWeight.w600,
                          letterSpacing: 0.5,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // BACK Card Face (Contains aligned details & security bullets)
  Widget _buildCardBack(MedicalProfile citizen) {
    final textColor = Colors.white;
    final gradient = _getCardGradient();

    return Container(
      width: 335,
      height: 210,
      decoration: BoxDecoration(
        gradient: gradient,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: Colors.white.withOpacity(0.18),
          width: 1.2,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.3),
            blurRadius: 18,
            offset: const Offset(0, -8),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14.0, vertical: 12.0),
        child: Row(
          children: [
            // Left Half: ID details & NFC pill
            Expanded(
              flex: 5,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  // Logo Block
                  Row(
                    children: [
                      CustomPaint(
                        size: const Size(18, 18),
                        painter: HeartEcgPainter(color: Colors.white),
                      ),
                      const SizedBox(width: 6),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'SwasthTap',
                            style: GoogleFonts.outfit(
                              fontSize: 13,
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                              letterSpacing: -0.2,
                            ),
                          ),
                          Text(
                            TranslationService.tLang(_selectedLanguage, 'card_tagline'),
                            style: GoogleFonts.inter(
                              fontSize: 6.0,
                              color: Colors.white.withOpacity(0.85),
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                  
                  // Text fields (aligned with columns)
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildAlignedDetailRow(TranslationService.tLang(_selectedLanguage, 'st_uid'), 'STP 1234 5678 9012', textColor),
                      _buildAlignedDetailRow(TranslationService.tLang(_selectedLanguage, 'full_name'), citizen.fullName, textColor),
                      _buildAlignedDetailRow(TranslationService.tLang(_selectedLanguage, 'dob'), '15/08/1990', textColor),
                      if (_showBloodGroup)
                        _buildAlignedDetailRow(TranslationService.tLang(_selectedLanguage, 'blood_group'), citizen.bloodGroup, textColor),
                      if (_showEmergencyContacts && citizen.emergencyContacts.isNotEmpty)
                        _buildAlignedDetailRow(TranslationService.tLang(_selectedLanguage, 'emergency_contacts'), citizen.emergencyContacts[0].phone, textColor),
                      if (_showAllergies)
                        _buildAlignedDetailRow(TranslationService.tLang(_selectedLanguage, 'allergies'), citizen.allergies.isNotEmpty ? citizen.allergies : 'None', textColor),
                      if (_showMedicalConditions)
                        _buildAlignedDetailRow(TranslationService.tLang(_selectedLanguage, 'medical_conditions'), citizen.specialInstructions.isNotEmpty ? citizen.specialInstructions : 'None', textColor),
                    ],
                  ),
                  
                  // Bottom Tap Card Pill
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
                    decoration: BoxDecoration(
                      color: const Color(0xFF0F766E).withOpacity(0.35),
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(color: Colors.white.withOpacity(0.1), width: 0.8),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.wifi_tethering_rounded, size: 8, color: Colors.white),
                        const SizedBox(width: 4),
                        Expanded(
                          child: Text(
                            TranslationService.tLang(_selectedLanguage, 'card_tap_desc'),
                            style: GoogleFonts.inter(
                              fontSize: 6.0,
                              fontWeight: FontWeight.w600,
                              color: Colors.white,
                            ),
                            maxLines: 2,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            
            // Thin Divider
            VerticalDivider(color: Colors.white.withOpacity(0.18), width: 14, thickness: 0.8),
            
            // Right Half: Bullet list & Help contacts
            Expanded(
              flex: 5,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  // Features list
                  Column(
                    children: [
                      const SizedBox(height: 2),
                      _buildFeatureRowBack(
                        Icons.security_rounded,
                        TranslationService.tLang(_selectedLanguage, 'card_secure_title'),
                        TranslationService.tLang(_selectedLanguage, 'card_secure_desc'),
                        textColor,
                      ),
                      const SizedBox(height: 8),
                      _buildFeatureRowBack(
                        Icons.lock_outline_rounded,
                        TranslationService.tLang(_selectedLanguage, 'card_private_title'),
                        TranslationService.tLang(_selectedLanguage, 'card_private_desc'),
                        textColor,
                      ),
                      const SizedBox(height: 8),
                      _buildFeatureRowBack(
                        Icons.add_box_outlined,
                        TranslationService.tLang(_selectedLanguage, 'card_portable_title'),
                        TranslationService.tLang(_selectedLanguage, 'card_portable_desc'),
                        textColor,
                      ),
                    ],
                  ),
                  
                  // Help contact info at bottom
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      Icon(Icons.headset_mic_rounded, size: 13, color: Colors.white.withOpacity(0.9)),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              TranslationService.tLang(_selectedLanguage, 'need_help'),
                              style: GoogleFonts.inter(fontSize: 7.5, fontWeight: FontWeight.bold, color: textColor),
                            ),
                            Text(
                              'support@swasthtap.in | 1800-121-4536',
                              style: GoogleFonts.inter(fontSize: 6.2, color: textColor.withOpacity(0.75), fontWeight: FontWeight.w500),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // Aligned Detail Row builder
  Widget _buildAlignedDetailRow(String label, String value, Color textColor) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 1.5),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 76,
            child: Text(
              label,
              style: GoogleFonts.inter(
                fontSize: 7.8,
                fontWeight: FontWeight.w600,
                color: textColor.withOpacity(0.85),
              ),
            ),
          ),
          Text(
            ' :   ',
            style: GoogleFonts.inter(
              fontSize: 7.8,
              fontWeight: FontWeight.w600,
              color: textColor.withOpacity(0.85),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: GoogleFonts.inter(
                fontSize: 7.8,
                fontWeight: FontWeight.bold,
                color: textColor,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }

  // Row helper for privacy features on back
  Widget _buildFeatureRowBack(IconData icon, String title, String desc, Color textColor) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          padding: const EdgeInsets.all(3.5),
          decoration: BoxDecoration(
            color: const Color(0xFF0F766E).withOpacity(0.4),
            shape: BoxShape.circle,
            border: Border.all(color: Colors.white.withOpacity(0.15), width: 0.8),
          ),
          child: Icon(icon, size: 9, color: Colors.white),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: GoogleFonts.inter(fontSize: 8.2, fontWeight: FontWeight.bold, color: textColor),
              ),
              const SizedBox(height: 1),
              Text(
                desc,
                style: GoogleFonts.inter(fontSize: 6.8, color: textColor.withOpacity(0.78), height: 1.15, fontWeight: FontWeight.w500),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

// Custom painter to draw the brand Heart + ECG logo exactly as requested
class HeartEcgPainter extends CustomPainter {
  final Color color;
  HeartEcgPainter({required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final paintOutline = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.4
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round
      ..isAntiAlias = true;

    final width = size.width;
    final height = size.height;

    // Heart Outline Path
    final heartPath = Path();
    heartPath.moveTo(width * 0.5, height * 0.85);
    // Left Curve
    heartPath.cubicTo(
      width * 0.1, height * 0.55,
      width * 0.05, height * 0.25,
      width * 0.28, height * 0.15
    );
    heartPath.cubicTo(
      width * 0.42, height * 0.1,
      width * 0.5, height * 0.26,
      width * 0.5, height * 0.26
    );
    // Right Curve
    heartPath.cubicTo(
      width * 0.5, height * 0.26,
      width * 0.58, height * 0.1,
      width * 0.72, height * 0.15
    );
    heartPath.cubicTo(
      width * 0.9, height * 0.25,
      width * 0.9, height * 0.55,
      width * 0.5, height * 0.85
    );
    canvas.drawPath(heartPath, paintOutline);

    // ECG heartbeat line inside
    final paintEcg = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.8
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round
      ..isAntiAlias = true;

    final ecgPath = Path();
    ecgPath.moveTo(width * 0.25, height * 0.45); // Left start
    ecgPath.lineTo(width * 0.38, height * 0.45); // Flat line
    ecgPath.lineTo(width * 0.42, height * 0.52); // Downward pulse
    ecgPath.lineTo(width * 0.47, height * 0.30); // Upward spike
    ecgPath.lineTo(width * 0.53, height * 0.60); // Downward spike
    ecgPath.lineTo(width * 0.57, height * 0.45); // Return
    ecgPath.lineTo(width * 0.75, height * 0.45); // Right end
    canvas.drawPath(ecgPath, paintEcg);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

// Tricolor curve painter at the bottom front card
class CardTricolorWavePainter extends CustomPainter {
  final String variant;

  CardTricolorWavePainter({required this.variant});

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;

    final strokeW = 4.0;
    final offset = 4.0;

    // Saffron Orange Wave (India Saffron: #FF9933)
    final paintOrange = Paint()
      ..color = const Color(0xFFFF9933)
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeW
      ..strokeCap = StrokeCap.round
      ..isAntiAlias = true;

    // White Wave (#FFFFFF)
    final paintWhite = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeW
      ..strokeCap = StrokeCap.round
      ..isAntiAlias = true;

    // Green Wave (India Green: #128807)
    final paintGreen = Paint()
      ..color = const Color(0xFF128807)
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeW
      ..strokeCap = StrokeCap.round
      ..isAntiAlias = true;

    // We offset the curves slightly to keep them parallel, crossing the edge to clip cleanly
    final pathOrange = Path()
      ..moveTo(w * 0.1, h + 10 - offset)
      ..cubicTo(w * 0.45, h * 0.1 - offset, w * 0.75, h * 0.3 - offset, w + 10, h * 0.7 - offset);

    final pathWhite = Path()
      ..moveTo(w * 0.1, h + 10)
      ..cubicTo(w * 0.45, h * 0.1, w * 0.75, h * 0.3, w + 10, h * 0.7);

    final pathGreen = Path()
      ..moveTo(w * 0.1, h + 10 + offset)
      ..cubicTo(w * 0.45, h * 0.1 + offset, w * 0.75, h * 0.3 + offset, w + 10, h * 0.7 + offset);

    canvas.drawPath(pathOrange, paintOrange);
    canvas.drawPath(pathWhite, paintWhite);
    canvas.drawPath(pathGreen, paintGreen);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

// Custom painter to draw the contactless NFC waves exactly as shown in the card image
class ContactlessWavesPainter extends CustomPainter {
  final Color color;
  ContactlessWavesPainter({required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.0
      ..strokeCap = StrokeCap.round
      ..isAntiAlias = true;

    final w = size.width;
    final h = size.height;

    // 4 concentric arcs curving to the right. Center is offset to the left.
    final center = Offset(-w * 0.15, h / 2);
    final radii = [w * 0.35, w * 0.65, w * 0.95, w * 1.25];

    for (var radius in radii) {
      canvas.drawArc(
        Rect.fromCircle(center: center, radius: radius),
        -pi / 4, // start angle
        pi / 2,  // sweep angle
        false,
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(covariant ContactlessWavesPainter oldDelegate) => false;
}
