import 'dart:math';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../../models/models.dart';
import '../../providers/swasthya_tap_provider.dart';
import '../../utils/card_pdf_generator.dart';
import '../../utils/pdf_downloader.dart';
import '../../services/api_service.dart';

class CardOption {
  final String id;
  final String title;
  final String description;
  final String priceLabel;
  final int price;
  final Color themeColor;
  final String badgeText;
  final bool isSpecial;

  CardOption({
    required this.id,
    required this.title,
    required this.description,
    required this.priceLabel,
    required this.price,
    required this.themeColor,
    this.badgeText = '',
    this.isSpecial = false,
  });
}

class OrderCardScreen extends StatefulWidget {
  final MedicalProfile citizen;

  const OrderCardScreen({Key? key, required this.citizen}) : super(key: key);

  @override
  State<OrderCardScreen> createState() => _OrderCardScreenState();
}

class _OrderCardScreenState extends State<OrderCardScreen> {
  final _formKey = GlobalKey<FormState>();

  late TextEditingController _nameController;
  late TextEditingController _phoneController;
  late TextEditingController _addressController;
  late TextEditingController _pincodeController;
  late TextEditingController _cityController;
  String _selectedState = 'Bihar';
  String _selectedOptionId = 'free';

  // Simulated Order State
  bool _orderPlaced = false;
  String _orderId = 'STAP12345678';
  String _orderDate = '26 Jun 2025, 09:41 AM';
  int _currentStep = 0; // 0: Ordered, 1: Programmed, 2: Shipped, 3: Delivered

  final List<String> _states = [
    'Bihar',
    'Delhi',
    'Maharashtra',
    'Karnataka',
    'Uttar Pradesh',
    'Tamil Nadu',
    'West Bengal',
    'Rajasthan'
  ];

  final List<CardOption> cardOptions = [
    CardOption(
      id: 'free',
      title: 'Free Basic PVC',
      description: 'Standard White PVC Card',
      priceLabel: '₹0',
      price: 0,
      themeColor: Colors.white,
      badgeText: 'FREE',
    ),
    CardOption(
      id: 'standard',
      title: 'Standard PVC',
      description: 'Custom Color PVC Card',
      priceLabel: '₹99',
      price: 99,
      themeColor: const Color(0xFF018086),
    ),
    CardOption(
      id: 'wristband',
      title: 'Wristband',
      description: 'Silicone Wristband (NFC Enabled)',
      priceLabel: '₹299',
      price: 299,
      themeColor: const Color(0xFF0D9488),
    ),
    CardOption(
      id: 'premium',
      title: 'Premium Metal',
      description: 'Stainless Steel Laser Engraved',
      priceLabel: '₹499',
      price: 499,
      themeColor: const Color(0xFF1E1B4B),
      badgeText: 'BEST QUALITY',
      isSpecial: true,
    ),
  ];

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.citizen.fullName);
    _phoneController = TextEditingController(text: '+91 98765 43210');
    _addressController = TextEditingController(
      text: '123, Gandhi Nagar, Near Civil Lines, Patna',
    );
    _pincodeController = TextEditingController(text: '800001');
    _cityController = TextEditingController(text: 'Patna');
  }

  @override
  void dispose() {
    _nameController.dispose();
    _phoneController.dispose();
    _addressController.dispose();
    _pincodeController.dispose();
    _cityController.dispose();
    super.dispose();
  }

  Future<void> _downloadCardPdf(MedicalProfile citizen) async {
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
                  'Generating PDF Document...',
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
        selectedVariant: 'Standard',
        selectedLanguage: 'English',
        showBloodGroup: true,
        showEmergencyContacts: true,
        showAllergies: true,
        showMedicalConditions: true,
      );

      if (!mounted) return;
      Navigator.pop(context);

      final filename = 'SwasthTap_Card_${citizen.fullName.replaceAll(' ', '_')}.pdf';
      downloadPdfFile(pdfBytes, filename);

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Card PDF Downloaded successfully!'),
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

  void _placeOrder() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _orderPlaced = false);

    // Show loading state
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => Center(
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
                'Placing your order...',
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
      ),
    );

    try {
      final selectedOption = cardOptions.firstWhere((o) => o.id == _selectedOptionId);

      final result = await ApiService.placeOrder(
        cardType: _selectedOptionId,
        price: selectedOption.price,
        citizenName: _nameController.text.trim(),
        phone: _phoneController.text.trim(),
        deliveryAddress: _addressController.text.trim(),
        city: _cityController.text.trim(),
        state: _selectedState,
        pincode: _pincodeController.text.trim(),
      );

      if (!mounted) return;
      Navigator.pop(context); // Dismiss loading dialog

      if (result['success'] == true) {
        final months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
                        'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
        final now = DateTime.now();
        final hour = now.hour > 12 ? now.hour - 12 : (now.hour == 0 ? 12 : now.hour);
        final ampm = now.hour >= 12 ? 'PM' : 'AM';
        final minute = now.minute.toString().padLeft(2, '0');

        setState(() {
          _orderPlaced = true;
          _orderId = result['orderId'] as String? ?? 'STAP${Random().nextInt(90000000) + 10000000}';
          _orderDate = '${now.day} ${months[now.month - 1]} ${now.year}, $hour:$minute $ampm';
          _currentStep = 0;
        });

        final isOffline = result['offline'] == true;
        showDialog(
          context: context,
          builder: (context) => AlertDialog(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            title: Row(children: [
              const Icon(Icons.check_circle_rounded, color: Color(0xFF0D9488), size: 28),
              const SizedBox(width: 8),
              Text('Order Placed!', style: GoogleFonts.outfit(fontWeight: FontWeight.bold)),
            ]),
            content: Text(
              '${isOffline ? '(Offline mode — will sync when connected)\n\n' : ''}Your SwasthyaTap NFC Card order has been placed successfully.\n\nOrder ID: $_orderId\nExpected Delivery: 5-7 working days.',
              style: GoogleFonts.inter(fontSize: 14),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: Text('OK', style: GoogleFonts.inter(color: const Color(0xFF0D9488), fontWeight: FontWeight.bold)),
              ),
            ],
          ),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(result['message'] as String? ?? 'Order failed. Please try again.'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } catch (e) {
      if (!mounted) return;
      Navigator.pop(context); // Dismiss loading dialog
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error placing order: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final selectedOption = cardOptions.firstWhere((o) => o.id == _selectedOptionId);

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded, color: Color(0xFF0F172A)),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Stack(
              alignment: Alignment.center,
              children: [
                const Icon(
                  Icons.favorite_outline_rounded,
                  color: Color(0xFF0D9488),
                  size: 18,
                ),
                Positioned(
                  right: -2,
                  top: -2,
                  child: Icon(
                    Icons.wifi,
                    color: const Color(0xFF0D9488).withOpacity(0.5),
                    size: 8,
                  ),
                )
              ],
            ),
            const SizedBox(width: 6),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'SwasthyaTap',
                  style: GoogleFonts.outfit(
                    color: const Color(0xFF0F172A),
                    fontWeight: FontWeight.bold,
                    fontSize: 15,
                  ),
                ),
                Text(
                  'One Tap Can Save Your Life',
                  style: GoogleFonts.inter(
                    color: const Color(0xFF64748B),
                    fontSize: 7.5,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ],
        ),
        centerTitle: true,
        actions: [
          TextButton.icon(
            icon: const Icon(Icons.help_outline_rounded, color: Color(0xFF0D9488), size: 16),
            label: Text(
              'Help',
              style: GoogleFonts.inter(
                color: const Color(0xFF0D9488),
                fontSize: 13,
                fontWeight: FontWeight.bold,
              ),
            ),
            onPressed: () {
              showDialog(
                context: context,
                builder: (context) => AlertDialog(
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  title: Text('Need Help?', style: GoogleFonts.outfit(fontWeight: FontWeight.bold)),
                  content: Text(
                    'For support regarding card orders, PDF downloads, or custom configurations, please reach out to us:\n\nEmail: support@swasthtap.in\nToll-Free: 1800-121-4536',
                    style: GoogleFonts.inter(fontSize: 14, height: 1.4),
                  ),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.pop(context),
                      child: Text(
                        'Close',
                        style: GoogleFonts.inter(
                          color: const Color(0xFF0D9488),
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
        ],
      ),
      body: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 20.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              // Screen Header
              Text(
                'Get Your SwasthyaTap Card',
                style: GoogleFonts.outfit(
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                  color: const Color(0xFF0F172A),
                ),
              ),
              const SizedBox(height: 6),
              Text(
                'Choose how you want to get your health identity card',
                style: GoogleFonts.inter(
                  fontSize: 13,
                  color: const Color(0xFF64748B),
                  fontWeight: FontWeight.w500,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 24),

              // SECTION 1: Print at Home (Free)
              _buildPrintAtHomeSection(),
              const SizedBox(height: 20),

              // SECTION 2: Order NFC Card
              _buildOrderNfcSection(selectedOption),
              const SizedBox(height: 20),

              // SECTION 3: My Order Status
              _buildOrderStatusSection(),
              const SizedBox(height: 24),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildPrintAtHomeSection() {
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE2E8F0)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.015),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Stack(
        children: [
          // FREE Badge on top right corner
          Positioned(
            top: 0,
            right: 0,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
              decoration: const BoxDecoration(
                color: Color(0xFF0D9488),
                borderRadius: BorderRadius.only(
                  topRight: Radius.circular(15),
                  bottomLeft: Radius.circular(15),
                ),
              ),
              child: Text(
                'FREE',
                style: GoogleFonts.inter(
                  color: Colors.white,
                  fontSize: 9,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 0.5,
                ),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(18.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Header Info - Wrapped in Expanded to avoid title/subtitle horizontal overflow
                Row(
                  children: [
                    Container(
                      width: 24,
                      height: 24,
                      decoration: const BoxDecoration(
                        color: Color(0xFF0D9488),
                        shape: BoxShape.circle,
                      ),
                      alignment: Alignment.center,
                      child: Text(
                        '1',
                        style: GoogleFonts.outfit(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: 13,
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Print at Home (Free)',
                            style: GoogleFonts.inter(
                              fontSize: 15,
                              fontWeight: FontWeight.bold,
                              color: const Color(0xFF0F172A),
                            ),
                          ),
                          Text(
                            'Get your card as PDF and print at home',
                            style: GoogleFonts.inter(
                              fontSize: 11,
                              color: const Color(0xFF64748B),
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 18),

                // High Fidelity Card previews front/back
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Column(
                      children: [
                        Text(
                          'FRONT',
                          style: GoogleFonts.inter(
                            fontSize: 8.5,
                            fontWeight: FontWeight.bold,
                            color: const Color(0xFF64748B),
                            letterSpacing: 0.5,
                          ),
                        ),
                        const SizedBox(height: 4),
                        _buildMiniCardFront(),
                      ],
                    ),
                    const SizedBox(width: 12),
                    Column(
                      children: [
                        Text(
                          'BACK',
                          style: GoogleFonts.inter(
                            fontSize: 8.5,
                            fontWeight: FontWeight.bold,
                            color: const Color(0xFF64748B),
                            letterSpacing: 0.5,
                          ),
                        ),
                        const SizedBox(height: 4),
                        _buildMiniCardBack(),
                      ],
                    ),
                  ],
                ),
                const SizedBox(height: 18),

                // Features bullet points
                _buildBulletPoint('High-resolution PDF (Print Front & Back)'),
                _buildBulletPoint('Print on thick paper (300gsm)'),
                _buildBulletPoint('Laminate for durability'),
                const SizedBox(height: 12),

                // Warning message
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFFFBEB),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: const Color(0xFFFDE68A)),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.warning_amber_rounded, color: Color(0xFFD97706), size: 16),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'Note: This will NOT have NFC chip — only QR code will work.',
                          style: GoogleFonts.inter(
                            fontSize: 10,
                            color: const Color(0xFF92400E),
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),

                // Action Button
                SizedBox(
                  width: double.infinity,
                  height: 42,
                  child: ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF0F766E),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      elevation: 0,
                    ),
                    icon: const Icon(Icons.download_rounded, color: Colors.white, size: 18),
                    label: Text(
                      'Download PDF',
                      style: GoogleFonts.inter(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 14,
                      ),
                    ),
                    onPressed: () => _downloadCardPdf(widget.citizen),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBulletPoint(String text) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3.5),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(2),
            decoration: const BoxDecoration(
              color: Color(0xFFF0FDFA),
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.check_rounded, color: Color(0xFF0D9488), size: 12),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              text,
              style: GoogleFonts.inter(
                fontSize: 11.5,
                color: const Color(0xFF334155),
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildOrderNfcSection(CardOption selectedOption) {
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE2E8F0)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.015),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      padding: const EdgeInsets.all(18.0),
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header Info - Wrapped in Expanded to avoid title/subtitle horizontal overflow
            Row(
              children: [
                Container(
                  width: 24,
                  height: 24,
                  decoration: const BoxDecoration(
                    color: Color(0xFFEA580C),
                    shape: BoxShape.circle,
                  ),
                  alignment: Alignment.center,
                  child: Text(
                    '2',
                    style: GoogleFonts.outfit(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 13,
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Order NFC Card (₹0 - ₹499)',
                        style: GoogleFonts.inter(
                          fontSize: 15,
                          fontWeight: FontWeight.bold,
                          color: const Color(0xFF0F172A),
                        ),
                      ),
                      Text(
                        'Get a pre-programmed NFC card delivered to your address',
                        style: GoogleFonts.inter(
                          fontSize: 11,
                          color: const Color(0xFF64748B),
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 18),

            // Horizontal Select list - Contained inside viewport to avoid scrolling out of the box boundaries
            SizedBox(
              height: 170,
              child: ListView.builder(
                scrollDirection: Axis.horizontal,
                itemCount: cardOptions.length,
                padding: const EdgeInsets.symmetric(vertical: 4),
                itemBuilder: (context, index) {
                  final option = cardOptions[index];
                  return Padding(
                    padding: const EdgeInsets.only(right: 12),
                    child: _buildOptionSelector(option),
                  );
                },
              ),
            ),
            const SizedBox(height: 22),

            // Delivery Address header
            Row(
              children: [
                const Icon(Icons.location_on_outlined, color: Color(0xFF64748B), size: 18),
                const SizedBox(width: 6),
                Text(
                  'Delivery Address',
                  style: GoogleFonts.inter(
                    fontSize: 13.5,
                    fontWeight: FontWeight.bold,
                    color: const Color(0xFF334155),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),

            // Form inputs
            Row(
              children: [
                Expanded(
                  child: _buildTextField(
                    label: 'Full Name',
                    controller: _nameController,
                    validator: (v) => v!.isEmpty ? 'Enter name' : null,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _buildTextField(
                    label: 'Mobile Number',
                    controller: _phoneController,
                    keyboardType: TextInputType.phone,
                    validator: (v) => v!.isEmpty ? 'Enter phone' : null,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            _buildTextField(
              label: 'Address',
              controller: _addressController,
              maxLines: 2,
              validator: (v) => v!.isEmpty ? 'Enter address' : null,
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: _buildTextField(
                    label: 'Pincode',
                    controller: _pincodeController,
                    keyboardType: TextInputType.number,
                    validator: (v) => v!.isEmpty ? 'Enter pincode' : null,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _buildTextField(
                    label: 'City',
                    controller: _cityController,
                    validator: (v) => v!.isEmpty ? 'Enter city' : null,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'State',
                        style: GoogleFonts.inter(
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                          color: const Color(0xFF64748B),
                        ),
                      ),
                      const SizedBox(height: 6),
                      Container(
                        height: 40,
                        padding: const EdgeInsets.symmetric(horizontal: 10),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF8FAFC),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: const Color(0xFFE2E8F0)),
                        ),
                        child: DropdownButtonHideUnderline(
                          child: DropdownButton<String>(
                            value: _selectedState,
                            icon: const Icon(Icons.keyboard_arrow_down_rounded, size: 18),
                            isExpanded: true,
                            style: GoogleFonts.inter(
                              color: const Color(0xFF0F172A),
                              fontSize: 13,
                              fontWeight: FontWeight.w500,
                            ),
                            onChanged: (String? newValue) {
                              setState(() {
                                _selectedState = newValue!;
                              });
                            },
                            items: _states.map<DropdownMenuItem<String>>((String value) {
                              return DropdownMenuItem<String>(
                                value: value,
                                child: Text(value),
                              );
                            }).toList(),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),

            // Expected delivery and security badges
            Row(
              children: [
                Expanded(
                  child: Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF0FDF4),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.local_shipping_outlined, color: Color(0xFF16A34A), size: 16),
                        const SizedBox(width: 6),
                        Expanded(
                          child: Text(
                            'Expected Delivery: 5 - 7 Working Days',
                            style: GoogleFonts.inter(
                              fontSize: 9.5,
                              color: const Color(0xFF15803D),
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF0FDF4),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.shield_outlined, color: Color(0xFF16A34A), size: 16),
                        const SizedBox(width: 6),
                        Expanded(
                          child: Text(
                            'Pre-programmed with health data',
                            style: GoogleFonts.inter(
                              fontSize: 9.5,
                              color: const Color(0xFF15803D),
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),

            // Price Summary and Place Order stacked vertically in Column to prevent horizontal/vertical overflows on mobile screens
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: const Color(0xFFF8FAFC),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: const Color(0xFFE2E8F0)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      // Total price label
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Total Amount',
                            style: GoogleFonts.inter(
                              fontSize: 11,
                              fontWeight: FontWeight.bold,
                              color: const Color(0xFF64748B),
                            ),
                          ),
                          const SizedBox(height: 2),
                          Row(
                            children: [
                              Text(
                                selectedOption.priceLabel,
                                style: GoogleFonts.outfit(
                                  fontSize: 22,
                                  fontWeight: FontWeight.bold,
                                  color: const Color(0xFF16A34A),
                                ),
                              ),
                              const SizedBox(width: 6),
                              Text(
                                '(${selectedOption.title})',
                                style: GoogleFonts.inter(
                                  fontSize: 10,
                                  color: const Color(0xFF64748B),
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                      // Secure payment label
                      Row(
                        children: [
                          const Icon(Icons.lock_outline_rounded, color: Color(0xFF475569), size: 16),
                          const SizedBox(width: 6),
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Secure Payment',
                                style: GoogleFonts.inter(
                                  fontSize: 10,
                                  fontWeight: FontWeight.bold,
                                  color: const Color(0xFF475569),
                                ),
                              ),
                              Text(
                                'UPI • Cards • NetBanking',
                                style: GoogleFonts.inter(
                                  fontSize: 8.5,
                                  color: const Color(0xFF94A3B8),
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  // Full width Place Order button
                  SizedBox(
                    width: double.infinity,
                    height: 46,
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFFEA580C),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                        elevation: 0,
                      ),
                      onPressed: _placeOrder,
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              const Icon(Icons.shopping_cart_outlined, color: Colors.white, size: 16),
                              const SizedBox(width: 6),
                              Text(
                                'Place Order',
                                style: GoogleFonts.inter(
                                  color: Colors.white,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 13.5,
                                ),
                              ),
                            ],
                          ),
                          Text(
                            'Pay & Confirm Order',
                            style: GoogleFonts.inter(
                              color: Colors.white70,
                              fontSize: 9,
                              fontWeight: FontWeight.w500,
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
      ),
    );
  }

  Widget _buildTextField({
    required String label,
    required TextEditingController controller,
    int maxLines = 1,
    TextInputType keyboardType = TextInputType.text,
    String? Function(String?)? validator,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: GoogleFonts.inter(
            fontSize: 11,
            fontWeight: FontWeight.bold,
            color: const Color(0xFF64748B),
          ),
        ),
        const SizedBox(height: 6),
        TextFormField(
          controller: controller,
          maxLines: maxLines,
          keyboardType: keyboardType,
          validator: validator,
          style: GoogleFonts.inter(
            color: const Color(0xFF0F172A),
            fontSize: 13,
            fontWeight: FontWeight.w500,
          ),
          decoration: InputDecoration(
            isDense: true,
            contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
            fillColor: const Color(0xFFF8FAFC),
            filled: true,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: const BorderSide(color: Color(0xFF0D9488)),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildOptionSelector(CardOption option) {
    final isSelected = _selectedOptionId == option.id;
    return GestureDetector(
      onTap: () {
        setState(() {
          _selectedOptionId = option.id;
        });
      },
      child: Container(
        width: 140,
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: isSelected ? const Color(0xFFF0FDFA) : Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isSelected ? const Color(0xFF0D9488) : const Color(0xFFE2E8F0),
            width: isSelected ? 1.8 : 1,
          ),
          boxShadow: [
            if (isSelected)
              BoxShadow(
                color: const Color(0xFF0D9488).withOpacity(0.04),
                blurRadius: 8,
                offset: const Offset(0, 4),
              ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Radio indicator
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Container(
                  width: 14,
                  height: 14,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: isSelected ? const Color(0xFF0D9488) : const Color(0xFFCBD5E1),
                      width: 1.5,
                    ),
                  ),
                  child: isSelected
                      ? Center(
                          child: Container(
                            width: 7,
                            height: 7,
                            decoration: const BoxDecoration(
                              color: Color(0xFF0D9488),
                              shape: BoxShape.circle,
                            ),
                          ),
                        )
                      : null,
                ),
                if (option.badgeText.isNotEmpty)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1.5),
                    decoration: BoxDecoration(
                      color: option.isSpecial ? const Color(0xFFD97706) : const Color(0xFF10B981),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Text(
                      option.badgeText,
                      style: GoogleFonts.inter(
                        fontSize: 6.5,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 10),
            // Representative Graphic (Custom card/wristband image)
            Center(
              child: _buildMiniGraphicForOption(option),
            ),
            const SizedBox(height: 10),
            Text(
              option.title,
              style: GoogleFonts.inter(
                fontSize: 11,
                fontWeight: FontWeight.bold,
                color: const Color(0xFF0F172A),
              ),
            ),
            const SizedBox(height: 2),
            Expanded(
              child: Text(
                option.description,
                style: GoogleFonts.inter(
                  fontSize: 8.5,
                  color: const Color(0xFF64748B),
                  fontWeight: FontWeight.w500,
                ),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            Text(
              option.priceLabel,
              style: GoogleFonts.outfit(
                fontSize: 15,
                fontWeight: FontWeight.bold,
                color: const Color(0xFF0D9488),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMiniGraphicForOption(CardOption option) {
    if (option.id == 'wristband') {
      return ClipRRect(
        borderRadius: BorderRadius.circular(6),
        child: Image.network(
          'https://images.unsplash.com/photo-1617038260897-41a1f14a8ca0?fit=crop&w=120&h=80&q=80',
          width: 58,
          height: 32,
          fit: BoxFit.cover,
          errorBuilder: (context, error, stackTrace) {
            return Container(
              width: 58,
              height: 32,
              color: const Color(0xFF0D9488),
              alignment: Alignment.center,
              child: const Icon(Icons.watch_rounded, color: Colors.white, size: 16),
            );
          },
        ),
      );
    }

    return Container(
      width: 58,
      height: 32,
      decoration: BoxDecoration(
        gradient: option.id == 'free'
            ? null
            : LinearGradient(
                colors: option.id == 'standard'
                    ? [const Color(0xFF018086), const Color(0xFF014757), const Color(0xFF011E30)]
                    : [const Color(0xFF374151), const Color(0xFF111827)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
        color: option.id == 'free' ? Colors.white : null,
        borderRadius: BorderRadius.circular(4),
        border: Border.all(
          color: option.id == 'free' ? const Color(0xFFE2E8F0) : Colors.white.withOpacity(0.15),
        ),
      ),
      padding: const EdgeInsets.all(3),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Icon(
                Icons.favorite_rounded,
                color: option.id == 'free' ? const Color(0xFF0D9488) : Colors.white,
                size: 4,
              ),
              Icon(
                Icons.wifi_tethering_rounded,
                color: option.id == 'free' ? const Color(0xFF64748B) : Colors.white70,
                size: 4,
              ),
            ],
          ),
          const Spacer(),
          Text(
            'SwasthyaTap',
            style: GoogleFonts.outfit(
              fontSize: 3.5,
              fontWeight: FontWeight.bold,
              color: option.id == 'free' ? const Color(0xFF0F172A) : Colors.white,
            ),
          ),
        ],
      ),
    );
  }

  // Mini representation of OUR CARD (matching high-fidelity 3D Card Viewer page)
  Widget _buildMiniCardFront() {
    return Container(
      width: 140,
      height: 85,
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [
            Color(0xFF018086),
            Color(0xFF014757),
            Color(0xFF011E30),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: Colors.white.withOpacity(0.18),
          width: 0.8,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(8),
        child: Stack(
          children: [
            // Tricolor curve details at bottom right
            Positioned(
              bottom: 0,
              right: 0,
              left: 45,
              height: 18,
              child: CustomPaint(
                painter: CardTricolorWavePainter(variant: 'Standard'),
              ),
            ),
            
            // Top Right: Contactless waves NFC symbol
            Positioned(
              top: 8,
              right: 8,
              child: CustomPaint(
                size: const Size(10, 11),
                painter: ContactlessWavesPainter(color: Colors.white.withOpacity(0.9)),
              ),
            ),

            // Bottom Left: QR Code
            Positioned(
              bottom: 6,
              left: 6,
              child: Container(
                padding: const EdgeInsets.all(1.5),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(2),
                ),
                child: Image.network(
                  'https://api.qrserver.com/v1/create-qr-code/?size=150x150&data=https://swasthtap.in/citizen/${widget.citizen.id}',
                  width: 22,
                  height: 22,
                  fit: BoxFit.contain,
                ),
              ),
            ),

            // Center: SwasthTap Logo & taglines
            Center(
              child: Row(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  CustomPaint(
                    size: const Size(20, 20),
                    painter: HeartEcgPainter(color: Colors.white),
                  ),
                  const SizedBox(width: 5),
                  Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'SwasthTap',
                        style: GoogleFonts.outfit(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: 13,
                          letterSpacing: -0.2,
                        ),
                      ),
                      Text(
                        'आपकी स्वास्थ्य पहचान',
                        style: GoogleFonts.inter(
                          color: Colors.white.withOpacity(0.85),
                          fontSize: 4.5,
                          fontWeight: FontWeight.w600,
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

  // Mini representation of OUR CARD Back (matching back details view)
  Widget _buildMiniCardBack() {
    final textColor = Colors.white;
    return Container(
      width: 140,
      height: 85,
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [
            Color(0xFF018086),
            Color(0xFF014757),
            Color(0xFF011E30),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: Colors.white.withOpacity(0.18),
          width: 0.8,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      padding: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 6.0),
      child: Row(
        children: [
          // Left Half: logo & personal details
          Expanded(
            flex: 6,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    CustomPaint(
                      size: const Size(10, 10),
                      painter: HeartEcgPainter(color: Colors.white),
                    ),
                    const SizedBox(width: 3),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'SwasthTap',
                          style: GoogleFonts.outfit(
                            fontSize: 7.5,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        ),
                        Text(
                          'Your Health Identity',
                          style: GoogleFonts.inter(
                            fontSize: 3.5,
                            color: Colors.white.withOpacity(0.85),
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildMiniDetailRow('SwasthTap ID', 'STP 1234 5678', textColor),
                    _buildMiniDetailRow('Name', widget.citizen.fullName, textColor),
                    _buildMiniDetailRow('Blood', widget.citizen.bloodGroup, textColor),
                  ],
                ),
              ],
            ),
          ),
          // Right Half: Contact info
          Expanded(
            flex: 5,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1.5),
                  decoration: BoxDecoration(
                    color: const Color(0xFFEF4444),
                    borderRadius: BorderRadius.circular(3),
                  ),
                  alignment: Alignment.center,
                  child: Text(
                    'EMERGENCY CARD',
                    style: GoogleFonts.inter(
                      fontSize: 4.5,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                ),
                const SizedBox(height: 2),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Contacts:',
                        style: GoogleFonts.inter(fontSize: 4.2, fontWeight: FontWeight.bold, color: Colors.white.withOpacity(0.9)),
                      ),
                      const SizedBox(height: 1),
                      Text(
                        'Sneha Kumar (Spouse)',
                        style: GoogleFonts.inter(fontSize: 3.8, color: Colors.white),
                        overflow: TextOverflow.ellipsis,
                      ),
                      Text(
                        '+91 98765 43210',
                        style: GoogleFonts.inter(fontSize: 3.8, color: Colors.white70),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMiniDetailRow(String label, String value, Color color) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 0.5),
      child: Row(
        children: [
          Text(
            '$label: ',
            style: GoogleFonts.inter(
              fontSize: 4.5,
              fontWeight: FontWeight.bold,
              color: color.withOpacity(0.7),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: GoogleFonts.inter(
                fontSize: 4.5,
                fontWeight: FontWeight.bold,
                color: color,
              ),
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildOrderStatusSection() {
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE2E8F0)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.015),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      padding: const EdgeInsets.all(18.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header info
          Row(
            children: [
              const Icon(Icons.local_mall_outlined, color: Color(0xFF64748B), size: 18),
              const SizedBox(width: 8),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'My Order Status',
                    style: GoogleFonts.inter(
                      fontSize: 15,
                      fontWeight: FontWeight.bold,
                      color: const Color(0xFF0F172A),
                    ),
                  ),
                  Text(
                    'Track your card order in real-time',
                    style: GoogleFonts.inter(
                      fontSize: 11,
                      color: const Color(0xFF64748B),
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 18),

          // Order Summary banner
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: const Color(0xFFF8FAFC),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Order ID: $_orderId',
                      style: GoogleFonts.inter(
                        fontSize: 12.5,
                        fontWeight: FontWeight.bold,
                        color: const Color(0xFF0F172A),
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'Ordered on: $_orderDate',
                      style: GoogleFonts.inter(
                        fontSize: 9.5,
                        color: const Color(0xFF64748B),
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF0FDF4),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    'In Progress',
                    style: GoogleFonts.inter(
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                      color: const Color(0xFF16A34A),
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),

          // Horizontal Stepper timeline
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              _buildStepTimelineItem(0, 'Ordered', _orderPlaced ? 'Today' : '26 Jun 2025'),
              _buildStepDivider(0),
              _buildStepTimelineItem(1, 'Programmed', 'Pending'),
              _buildStepDivider(1),
              _buildStepTimelineItem(2, 'Shipped', 'Pending'),
              _buildStepDivider(2),
              _buildStepTimelineItem(3, 'Delivered', 'Pending'),
            ],
          ),
          const SizedBox(height: 18),

          // Info bar
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            decoration: BoxDecoration(
              color: const Color(0xFFEFF6FF),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Row(
              children: [
                const Icon(Icons.info_outline_rounded, color: Color(0xFF1D4ED8), size: 16),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'You will receive SMS & email updates at every step of your order.',
                    style: GoogleFonts.inter(
                      fontSize: 10.5,
                      color: const Color(0xFF1E40AF),
                      fontWeight: FontWeight.w600,
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

  Widget _buildStepTimelineItem(int stepIndex, String label, String dateText) {
    final isDone = _currentStep >= stepIndex;
    final color = isDone ? const Color(0xFF0D9488) : const Color(0xFFCBD5E1);

    return Expanded(
      child: Column(
        children: [
          Container(
            width: 24,
            height: 24,
            decoration: BoxDecoration(
              color: isDone ? const Color(0xFF0D9488) : Colors.white,
              shape: BoxShape.circle,
              border: Border.all(color: color, width: 2),
            ),
            child: isDone
                ? const Icon(Icons.check_rounded, color: Colors.white, size: 12)
                : Center(
                    child: Container(
                      width: 6,
                      height: 6,
                      decoration: const BoxDecoration(
                        color: Color(0xFFCBD5E1),
                        shape: BoxShape.circle,
                      ),
                    ),
                  ),
          ),
          const SizedBox(height: 6),
          Text(
            label,
            style: GoogleFonts.inter(
              fontSize: 10,
              fontWeight: FontWeight.bold,
              color: isDone ? const Color(0xFF0F172A) : const Color(0xFF64748B),
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 2),
          Text(
            dateText,
            style: GoogleFonts.inter(
              fontSize: 8.5,
              color: isDone ? const Color(0xFF0D9488) : const Color(0xFF94A3B8),
              fontWeight: FontWeight.w500,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildStepDivider(int afterStepIndex) {
    final isDone = _currentStep > afterStepIndex;
    final color = isDone ? const Color(0xFF0D9488) : const Color(0xFFE2E8F0);

    return Container(
      width: 24,
      height: 2,
      color: color,
      margin: const EdgeInsets.only(bottom: 24),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// CUSTOM PAINTERS REPLICATING MAIN CARD DESIGN FOR PREVIEWS
// ─────────────────────────────────────────────────────────────────────────────

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

    final heartPath = Path();
    heartPath.moveTo(width * 0.5, height * 0.85);
    heartPath.cubicTo(width * 0.1, height * 0.55, width * 0.05, height * 0.25, width * 0.28, height * 0.15);
    heartPath.cubicTo(width * 0.42, height * 0.1, width * 0.5, height * 0.26, width * 0.5, height * 0.26);
    heartPath.cubicTo(width * 0.5, height * 0.26, width * 0.58, height * 0.1, width * 0.72, height * 0.15);
    heartPath.cubicTo(width * 0.9, height * 0.25, width * 0.9, height * 0.55, width * 0.5, height * 0.85);
    canvas.drawPath(heartPath, paintOutline);

    final paintEcg = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.8
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round
      ..isAntiAlias = true;

    final ecgPath = Path();
    ecgPath.moveTo(width * 0.25, height * 0.45);
    ecgPath.lineTo(width * 0.38, height * 0.45);
    ecgPath.lineTo(width * 0.42, height * 0.52);
    ecgPath.lineTo(width * 0.47, height * 0.30);
    ecgPath.lineTo(width * 0.53, height * 0.60);
    ecgPath.lineTo(width * 0.57, height * 0.45);
    ecgPath.lineTo(width * 0.75, height * 0.45);
    canvas.drawPath(ecgPath, paintEcg);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class CardTricolorWavePainter extends CustomPainter {
  final String variant;
  CardTricolorWavePainter({required this.variant});

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;

    final strokeW = 2.0;
    final offset = 2.0;

    final paintOrange = Paint()
      ..color = const Color(0xFFFF9933)
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeW
      ..strokeCap = StrokeCap.round
      ..isAntiAlias = true;

    final paintWhite = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeW
      ..strokeCap = StrokeCap.round
      ..isAntiAlias = true;

    final paintGreen = Paint()
      ..color = const Color(0xFF128807)
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeW
      ..strokeCap = StrokeCap.round
      ..isAntiAlias = true;

    final pathOrange = Path()
      ..moveTo(w * 0.1, h + 5 - offset)
      ..cubicTo(w * 0.45, h * 0.1 - offset, w * 0.75, h * 0.3 - offset, w + 5, h * 0.7 - offset);

    final pathWhite = Path()
      ..moveTo(w * 0.1, h + 5)
      ..cubicTo(w * 0.45, h * 0.1, w * 0.75, h * 0.3, w + 5, h * 0.7);

    final pathGreen = Path()
      ..moveTo(w * 0.1, h + 5 + offset)
      ..cubicTo(w * 0.45, h * 0.1 + offset, w * 0.75, h * 0.3 + offset, w + 5, h * 0.7 + offset);

    canvas.drawPath(pathOrange, paintOrange);
    canvas.drawPath(pathWhite, paintWhite);
    canvas.drawPath(pathGreen, paintGreen);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class ContactlessWavesPainter extends CustomPainter {
  final Color color;
  ContactlessWavesPainter({required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.2
      ..strokeCap = StrokeCap.round
      ..isAntiAlias = true;

    final w = size.width;
    final h = size.height;

    final center = Offset(-w * 0.15, h / 2);
    final radii = [w * 0.35, w * 0.65, w * 0.95, w * 1.25];

    for (var radius in radii) {
      canvas.drawArc(
        Rect.fromCircle(center: center, radius: radius),
        -pi / 4,
        pi / 2,
        false,
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
