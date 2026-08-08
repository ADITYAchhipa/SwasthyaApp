import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/swasthya_tap_provider.dart';
import '../../theme/app_theme.dart';
import '../../widgets/glass_card.dart';
import '../../models/models.dart';
import '../../utils/translation_service.dart';
import 'language_selection_screen.dart';
import 'citizen_dashboard.dart';

class ProfileSetupScreen extends StatefulWidget {
  final MedicalProfile citizen;

  const ProfileSetupScreen({Key? key, required this.citizen}) : super(key: key);

  @override
  _ProfileSetupScreenState createState() => _ProfileSetupScreenState();
}

class _ProfileSetupScreenState extends State<ProfileSetupScreen> {
  final _formKey = GlobalKey<FormState>();
  
  late TextEditingController _nameController;
  late TextEditingController _ageController;
  late TextEditingController _addressController;
  late TextEditingController _phoneController;
  late TextEditingController _emergencyNameController;
  late TextEditingController _emergencyPhoneController;
  
  late String _bloodGroup;
  bool _isLoading = false;

  final List<String> _bloodGroups = ['O+', 'O-', 'A+', 'A-', 'B+', 'B-', 'AB+', 'AB-'];

  @override
  void initState() {
    super.initState();
    // Check if it's a mock user or default new user to avoid prefilling with dummy data
    final isMockOrNew = widget.citizen.id == 'x7k9m2' || 
                        widget.citizen.fullName == 'Rajesh Kumar' || 
                        widget.citizen.fullName == 'SwasthyaTap User';

    _nameController = TextEditingController(
      text: isMockOrNew ? '' : widget.citizen.fullName,
    );
    
    _ageController = TextEditingController(
      text: (isMockOrNew || widget.citizen.age == null) 
          ? '' 
          : widget.citizen.age.toString(),
    );
    
    _addressController = TextEditingController(
      text: isMockOrNew ? '' : widget.citizen.address,
    );
    
    _phoneController = TextEditingController(
      text: (isMockOrNew && widget.citizen.phoneNumber == '9900112233') 
          ? '' 
          : widget.citizen.phoneNumber,
    );
    
    if (widget.citizen.emergencyContacts.isNotEmpty && !isMockOrNew) {
      _emergencyNameController = TextEditingController(text: widget.citizen.emergencyContacts[0].name);
      _emergencyPhoneController = TextEditingController(text: widget.citizen.emergencyContacts[0].phone);
    } else {
      _emergencyNameController = TextEditingController();
      _emergencyPhoneController = TextEditingController();
    }

    // Default blood group if not valid or if it is mock
    if (!isMockOrNew && _bloodGroups.contains(widget.citizen.bloodGroup)) {
      _bloodGroup = widget.citizen.bloodGroup;
    } else {
      _bloodGroup = 'O+';
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _ageController.dispose();
    _addressController.dispose();
    _phoneController.dispose();
    _emergencyNameController.dispose();
    _emergencyPhoneController.dispose();
    super.dispose();
  }

  Future<void> _saveProfile(SwasthyaTapProvider provider) async {
    if (!_formKey.currentState!.validate()) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please fill all required fields'),
          backgroundColor: AppTheme.accentRed,
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      final List<EmergencyContact> contacts = [
        EmergencyContact(
          name: _emergencyNameController.text.trim(),
          relation: 'Family',
          phone: _emergencyPhoneController.text.trim(),
        ),
      ];

      // Retain secondary contact if present
      if (widget.citizen.emergencyContacts.length > 1) {
        contacts.add(widget.citizen.emergencyContacts[1]);
      }

      final updatedProfile = widget.citizen.copyWith(
        fullName: _nameController.text.trim(),
        bloodGroup: _bloodGroup,
        age: int.tryParse(_ageController.text.trim()),
        address: _addressController.text.trim(),
        phoneNumber: _phoneController.text.trim(),
        emergencyContacts: contacts,
      );

      await provider.updateProfile(updatedProfile);
      
      // Update provider with updated logged-in citizen
      provider.loginCitizen(updatedProfile);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(TranslationService.t(context, 'reg_success')),
            backgroundColor: AppTheme.accentGreen,
            behavior: SnackBarBehavior.floating,
          ),
        );

        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (_) => const CitizenDashboard()),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to update profile: $e'),
            backgroundColor: AppTheme.accentRed,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final provider = Provider.of<SwasthyaTapProvider>(context, listen: false);

    return Scaffold(
      backgroundColor: AppTheme.lightBg,
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              AppTheme.accentTeal.withOpacity(0.08),
              AppTheme.lightBg,
            ],
          ),
        ),
        child: SafeArea(
          child: Column(
            children: [
              // Top Bar
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Stack(
                      alignment: Alignment.center,
                      children: [
                        const Icon(
                          Icons.favorite_outline_rounded,
                          color: AppTheme.accentTeal,
                          size: 24,
                        ),
                        Positioned(
                          right: -2,
                          top: -2,
                          child: Icon(
                            Icons.wifi,
                            color: AppTheme.accentTeal.withOpacity(0.5),
                            size: 10,
                          ),
                        )
                      ],
                    ),
                    Column(
                      children: const [
                        Text(
                          'SwasthyaTap.in',
                          style: TextStyle(
                            color: AppTheme.textPrimary,
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                          ),
                        ),
                        Text(
                          'One Tap Can Save Your Life',
                          style: TextStyle(color: AppTheme.textSecondary, fontSize: 9, fontWeight: FontWeight.bold),
                        ),
                      ],
                    ),
                    const SizedBox(width: 24),
                  ],
                ),
              ),
              
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                  child: Form(
                    key: _formKey,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const SizedBox(height: 10),
                        Center(
                          child: Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: AppTheme.accentTeal.withOpacity(0.1),
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(
                              Icons.assignment_ind_rounded,
                              color: AppTheme.accentTeal,
                              size: 40,
                            ),
                          ),
                        ),
                        const SizedBox(height: 16),
                        Center(
                          child: Text(
                            TranslationService.t(context, 'profile_setup_title'),
                            style: const TextStyle(
                              fontSize: 24,
                              fontWeight: FontWeight.bold,
                              color: AppTheme.textPrimary,
                            ),
                          ),
                        ),
                        const SizedBox(height: 6),
                        Center(
                          child: Text(
                            TranslationService.t(context, 'profile_setup_sub'),
                            textAlign: TextAlign.center,
                            style: const TextStyle(
                              fontSize: 12.5,
                              color: AppTheme.textSecondary,
                            ),
                          ),
                        ),
                        const SizedBox(height: 24),

                        // Section Title: Personal Details
                        const Text(
                          'Personal Details',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.bold,
                            color: AppTheme.textSecondary,
                            letterSpacing: 0.5,
                          ),
                        ),
                        const SizedBox(height: 8),

                        GlassCard(
                          child: Column(
                            children: [
                              TextFormField(
                                controller: _nameController,
                                enableSuggestions: false,
                                autocorrect: false,
                                autofillHints: const [],
                                decoration: AppTheme.premiumInputDecoration(
                                  label: TranslationService.t(context, 'full_name'),
                                  icon: Icons.person,
                                  isRequired: true,
                                ),
                                validator: (value) =>
                                    value == null || value.trim().isEmpty ? 'Full name required' : null,
                              ),
                              const SizedBox(height: 16),
                              Row(
                                children: [
                                  Expanded(
                                    child: TextFormField(
                                      controller: _ageController,
                                      keyboardType: TextInputType.number,
                                      enableSuggestions: false,
                                      autocorrect: false,
                                      autofillHints: const [],
                                      decoration: AppTheme.premiumInputDecoration(
                                        label: TranslationService.t(context, 'label_age'),
                                        icon: Icons.calendar_today,
                                        isRequired: true,
                                      ),
                                      validator: (value) {
                                        if (value == null || value.trim().isEmpty) return 'Age required';
                                        final age = int.tryParse(value);
                                        if (age == null || age <= 0 || age > 120) return 'Invalid age';
                                        return null;
                                      },
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: DropdownButtonFormField<String>(
                                      value: _bloodGroup,
                                      dropdownColor: AppTheme.cardBg,
                                      decoration: AppTheme.premiumInputDecoration(
                                        label: TranslationService.t(context, 'blood_group'),
                                        icon: Icons.bloodtype,
                                        isRequired: true,
                                      ),
                                      items: _bloodGroups.map((bg) {
                                        return DropdownMenuItem(value: bg, child: Text(bg));
                                      }).toList(),
                                      onChanged: (val) {
                                        if (val != null) {
                                          setState(() {
                                            _bloodGroup = val;
                                          });
                                        }
                                      },
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 16),
                              TextFormField(
                                controller: _phoneController,
                                keyboardType: TextInputType.phone,
                                enableSuggestions: false,
                                autocorrect: false,
                                autofillHints: const [],
                                decoration: AppTheme.premiumInputDecoration(
                                  label: TranslationService.t(context, 'phone_number'),
                                  icon: Icons.phone_android,
                                  isRequired: true,
                                ),
                                validator: (value) =>
                                    value == null || value.trim().isEmpty ? 'Mobile number required' : null,
                              ),
                              const SizedBox(height: 16),
                              TextFormField(
                                controller: _addressController,
                                maxLines: 2,
                                enableSuggestions: false,
                                autocorrect: false,
                                autofillHints: const [],
                                decoration: AppTheme.premiumInputDecoration(
                                  label: TranslationService.t(context, 'label_address'),
                                  icon: Icons.home,
                                  isRequired: true,
                                ),
                                validator: (value) =>
                                    value == null || value.trim().isEmpty ? 'Address required' : null,
                              ),
                            ],
                          ),
                        ),

                        const SizedBox(height: 24),

                        // Section Title: Emergency Contacts
                        const Text(
                          'Primary Emergency Contact',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.bold,
                            color: AppTheme.textSecondary,
                            letterSpacing: 0.5,
                          ),
                        ),
                        const SizedBox(height: 8),

                        GlassCard(
                          child: Column(
                            children: [
                              TextFormField(
                                controller: _emergencyNameController,
                                enableSuggestions: false,
                                autocorrect: false,
                                autofillHints: const [],
                                decoration: AppTheme.premiumInputDecoration(
                                  label: TranslationService.t(context, 'label_emergency_name'),
                                  icon: Icons.contact_phone,
                                  isRequired: true,
                                ),
                                validator: (value) =>
                                    value == null || value.trim().isEmpty ? 'Contact name required' : null,
                              ),
                              const SizedBox(height: 16),
                              TextFormField(
                                controller: _emergencyPhoneController,
                                keyboardType: TextInputType.phone,
                                enableSuggestions: false,
                                autocorrect: false,
                                autofillHints: const [],
                                decoration: AppTheme.premiumInputDecoration(
                                  label: TranslationService.t(context, 'label_emergency_phone'),
                                  icon: Icons.phone,
                                  isRequired: true,
                                ),
                                validator: (value) =>
                                    value == null || value.trim().isEmpty ? 'Contact phone required' : null,
                              ),
                            ],
                          ),
                        ),

                        const SizedBox(height: 32),

                        // Save Button
                        SizedBox(
                          width: double.infinity,
                          height: 54,
                          child: ElevatedButton(
                            onPressed: _isLoading ? null : () => _saveProfile(provider),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AppTheme.accentTeal,
                              foregroundColor: Colors.white,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(16),
                              ),
                              elevation: 5,
                              shadowColor: AppTheme.accentTeal.withOpacity(0.2),
                            ),
                            child: _isLoading
                                ? const CircularProgressIndicator(color: Colors.white)
                                : Row(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      Text(
                                        TranslationService.t(context, 'save_profile'),
                                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                                      ),
                                      const SizedBox(width: 8),
                                      const Icon(Icons.arrow_forward_rounded, size: 18),
                                    ],
                                  ),
                          ),
                        ),
                        const SizedBox(height: 40),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

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

