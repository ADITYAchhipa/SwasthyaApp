import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/swasthya_tap_provider.dart';
import '../../theme/app_theme.dart';
import '../../widgets/glass_card.dart';
import '../../models/models.dart';
import '../../utils/translation_service.dart';
import 'language_selection_screen.dart';

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
    _nameController = TextEditingController(text: widget.citizen.fullName);
    _ageController = TextEditingController(text: widget.citizen.age?.toString() ?? '');
    _addressController = TextEditingController(text: widget.citizen.address);
    _phoneController = TextEditingController(text: widget.citizen.phoneNumber);
    
    if (widget.citizen.emergencyContacts.isNotEmpty) {
      _emergencyNameController = TextEditingController(text: widget.citizen.emergencyContacts[0].name);
      _emergencyPhoneController = TextEditingController(text: widget.citizen.emergencyContacts[0].phone);
    } else {
      _emergencyNameController = TextEditingController();
      _emergencyPhoneController = TextEditingController();
    }

    // Default blood group if not valid
    if (_bloodGroups.contains(widget.citizen.bloodGroup)) {
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
    if (!_formKey.currentState!.validate()) return;

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
          MaterialPageRoute(builder: (_) => const LanguageSelectionScreen()),
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
                    const Icon(Icons.favorite_rounded, color: AppTheme.accentTeal, size: 24),
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
                                decoration: AppTheme.premiumInputDecoration(
                                  label: TranslationService.t(context, 'full_name'),
                                  icon: Icons.person,
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
                                      decoration: AppTheme.premiumInputDecoration(
                                        label: TranslationService.t(context, 'label_age'),
                                        icon: Icons.calendar_today,
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
                                decoration: AppTheme.premiumInputDecoration(
                                  label: TranslationService.t(context, 'phone_number'),
                                  icon: Icons.phone_android,
                                ),
                                validator: (value) =>
                                    value == null || value.trim().isEmpty ? 'Mobile number required' : null,
                              ),
                              const SizedBox(height: 16),
                              TextFormField(
                                controller: _addressController,
                                maxLines: 2,
                                decoration: AppTheme.premiumInputDecoration(
                                  label: TranslationService.t(context, 'label_address'),
                                  icon: Icons.home,
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
                                decoration: AppTheme.premiumInputDecoration(
                                  label: TranslationService.t(context, 'label_emergency_name'),
                                  icon: Icons.contact_phone,
                                ),
                                validator: (value) =>
                                    value == null || value.trim().isEmpty ? 'Contact name required' : null,
                              ),
                              const SizedBox(height: 16),
                              TextFormField(
                                controller: _emergencyPhoneController,
                                keyboardType: TextInputType.phone,
                                decoration: AppTheme.premiumInputDecoration(
                                  label: TranslationService.t(context, 'label_emergency_phone'),
                                  icon: Icons.phone,
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
