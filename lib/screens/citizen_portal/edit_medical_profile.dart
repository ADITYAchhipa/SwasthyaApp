import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/swasthya_tap_provider.dart';
import '../../theme/app_theme.dart';
import '../../widgets/glass_card.dart';
import '../../models/models.dart';

class EditMedicalProfile extends StatefulWidget {
  const EditMedicalProfile({Key? key}) : super(key: key);

  @override
  _EditMedicalProfileState createState() => _EditMedicalProfileState();
}

class _EditMedicalProfileState extends State<EditMedicalProfile> {
  final _formKey = GlobalKey<FormState>();
  
  late String _fullName;
  late String _bloodGroup;
  late String _allergies;
  late String _medications;
  late bool _isDnr;
  late String _specialInstructions;
  late String _insuranceCompany;
  late String _insurancePolicyNumber;
  late String _chronicConditions;
  
  // Emergency contacts
  late String _contact1Name;
  late String _contact1Relation;
  late String _contact1Phone;
  
  late String _contact2Name;
  late String _contact2Relation;
  late String _contact2Phone;

  final List<String> _bloodGroups = ['O+', 'O-', 'A+', 'A-', 'B+', 'B-', 'AB+', 'AB-'];

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final citizen = Provider.of<SwasthyaTapProvider>(context, listen: false).currentCitizen;
    
    _fullName = citizen.fullName;
    _bloodGroup = citizen.bloodGroup;
    _allergies = citizen.allergies;
    _medications = citizen.medications;
    _isDnr = citizen.isDnr;
    _specialInstructions = citizen.specialInstructions;
    _insuranceCompany = citizen.insuranceCompany;
    _insurancePolicyNumber = citizen.insurancePolicyNumber;
    _chronicConditions = citizen.chronicConditions;

    // Load contacts
    if (citizen.emergencyContacts.isNotEmpty) {
      _contact1Name = citizen.emergencyContacts[0].name;
      _contact1Relation = citizen.emergencyContacts[0].relation;
      _contact1Phone = citizen.emergencyContacts[0].phone;
    } else {
      _contact1Name = '';
      _contact1Relation = '';
      _contact1Phone = '';
    }

    if (citizen.emergencyContacts.length > 1) {
      _contact2Name = citizen.emergencyContacts[1].name;
      _contact2Relation = citizen.emergencyContacts[1].relation;
      _contact2Phone = citizen.emergencyContacts[1].phone;
    } else {
      _contact2Name = '';
      _contact2Relation = '';
      _contact2Phone = '';
    }
  }

  void _saveForm(SwasthyaTapProvider provider) {
    if (_formKey.currentState!.validate()) {
      _formKey.currentState!.save();
      
      final List<EmergencyContact> contacts = [
        EmergencyContact(name: _contact1Name, relation: _contact1Relation, phone: _contact1Phone),
      ];

      if (_contact2Name.isNotEmpty && _contact2Phone.isNotEmpty) {
        contacts.add(EmergencyContact(name: _contact2Name, relation: _contact2Relation, phone: _contact2Phone));
      }

      final updatedProfile = provider.currentCitizen.copyWith(
        fullName: _fullName,
        bloodGroup: _bloodGroup,
        allergies: _allergies,
        medications: _medications,
        emergencyContacts: contacts,
        isDnr: _isDnr,
        specialInstructions: _specialInstructions,
        insuranceCompany: _insuranceCompany,
        insurancePolicyNumber: _insurancePolicyNumber,
        chronicConditions: _chronicConditions,
      );

      provider.updateProfile(updatedProfile);

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Medical profile updated! Write to NFC card to sync offline data.'),
          backgroundColor: AppTheme.accentTeal,
          behavior: SnackBarBehavior.floating,
        ),
      );
      Navigator.pop(context);
    }
  }

  @override
  Widget build(BuildContext context) {
    final provider = Provider.of<SwasthyaTapProvider>(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Edit Vitals & Identity'),
        backgroundColor: Colors.transparent,
        elevation: 0,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Section 1: Basic Identity
              _buildSectionTitle('1. Basic Demographics'),
              const SizedBox(height: 12),
              GlassCard(
                child: Column(
                  children: [
                    TextFormField(
                      initialValue: _fullName,
                      decoration: AppTheme.premiumInputDecoration(
                        label: 'Full Name (Legal)',
                        icon: Icons.person,
                      ),
                      validator: (value) => value == null || value.isEmpty ? 'Name required' : null,
                      onSaved: (val) => _fullName = val ?? '',
                    ),
                    const SizedBox(height: 16),
                    DropdownButtonFormField<String>(
                      value: _bloodGroup,
                      dropdownColor: AppTheme.cardBg,
                      decoration: AppTheme.premiumInputDecoration(
                        label: 'Blood Group',
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
                  ],
                ),
              ),
              const SizedBox(height: 24),

              // Section 2: Vitals & Resuscitation
              _buildSectionTitle('2. Critical Vitals & DNR'),
              const SizedBox(height: 12),
              GlassCard(
                child: Column(
                  children: [
                    TextFormField(
                      initialValue: _allergies,
                      maxLines: 2,
                      decoration: AppTheme.premiumInputDecoration(
                        label: 'Drug / Food Allergies',
                        hint: 'e.g. Penicillin, Peanuts, Latex',
                        icon: Icons.warning,
                      ),
                      onSaved: (val) => _allergies = val ?? '',
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      initialValue: _medications,
                      maxLines: 2,
                      decoration: AppTheme.premiumInputDecoration(
                        label: 'Current Medications',
                        hint: 'e.g. Amlodipine 5mg, Metformin 500mg',
                        icon: Icons.medication,
                      ),
                      onSaved: (val) => _medications = val ?? '',
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      initialValue: _specialInstructions,
                      maxLines: 2,
                      decoration: AppTheme.premiumInputDecoration(
                        label: 'Special Medical Instructions',
                        hint: 'e.g. Diabetic, Carries Epipen',
                        icon: Icons.info,
                      ),
                      onSaved: (val) => _specialInstructions = val ?? '',
                    ),
                    const SizedBox(height: 16),
                    SwitchListTile(
                      title: const Text('Do Not Resuscitate (DNR) Order', style: TextStyle(fontWeight: FontWeight.bold, color: AppTheme.accentRed)),
                      subtitle: const Text('Instructs doctors not to perform CPR if breathing/heart stops. Requires legal directive.', style: TextStyle(fontSize: 11, color: AppTheme.textSecondary)),
                      value: _isDnr,
                      onChanged: (val) {
                        setState(() {
                          _isDnr = val;
                        });
                      },
                      activeColor: Colors.white,
                      activeTrackColor: AppTheme.accentRed,
                      inactiveThumbColor: Colors.white,
                      inactiveTrackColor: const Color(0xFFCBD5E1),
                      trackOutlineColor: MaterialStateProperty.all(Colors.transparent),
                      contentPadding: EdgeInsets.zero,
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),

              // Section 3: Next of Kin
              _buildSectionTitle('3. Emergency Contacts (Next of Kin)'),
              const SizedBox(height: 12),
              GlassCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Contact 1 (Primary)', style: TextStyle(fontWeight: FontWeight.bold, color: AppTheme.accentTeal, fontSize: 13)),
                    const SizedBox(height: 12),
                    TextFormField(
                      initialValue: _contact1Name,
                      decoration: AppTheme.premiumInputDecoration(
                        label: 'Contact Name',
                        icon: Icons.person,
                      ),
                      validator: (value) => value == null || value.isEmpty ? 'Contact name required' : null,
                      onSaved: (val) => _contact1Name = val ?? '',
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          child: TextFormField(
                            initialValue: _contact1Relation,
                            decoration: AppTheme.premiumInputDecoration(
                              label: 'Relation',
                              icon: Icons.family_restroom,
                            ),
                            validator: (value) => value == null || value.isEmpty ? 'Relation required' : null,
                            onSaved: (val) => _contact1Relation = val ?? '',
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: TextFormField(
                            initialValue: _contact1Phone,
                            decoration: AppTheme.premiumInputDecoration(
                              label: 'Phone',
                              icon: Icons.phone,
                            ),
                            validator: (value) => value == null || value.isEmpty ? 'Phone required' : null,
                            onSaved: (val) => _contact1Phone = val ?? '',
                          ),
                        ),
                      ],
                    ),
                    const Divider(height: 32),
                    const Text('Contact 2 (Secondary - Optional)', style: TextStyle(fontWeight: FontWeight.bold, color: AppTheme.accentTeal, fontSize: 13)),
                    const SizedBox(height: 12),
                    TextFormField(
                      initialValue: _contact2Name,
                      decoration: AppTheme.premiumInputDecoration(
                        label: 'Contact Name',
                        icon: Icons.person,
                      ),
                      onSaved: (val) => _contact2Name = val ?? '',
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          child: TextFormField(
                            initialValue: _contact2Relation,
                            decoration: AppTheme.premiumInputDecoration(
                              label: 'Relation',
                              icon: Icons.family_restroom,
                            ),
                            onSaved: (val) => _contact2Relation = val ?? '',
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: TextFormField(
                            initialValue: _contact2Phone,
                            decoration: AppTheme.premiumInputDecoration(
                              label: 'Phone',
                              icon: Icons.phone,
                            ),
                            onSaved: (val) => _contact2Phone = val ?? '',
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),

              // Section 4: Online Records
              _buildSectionTitle('4. Cloud Sync Health Records (Online Only)'),
              const SizedBox(height: 12),
              GlassCard(
                child: Column(
                  children: [
                    TextFormField(
                      initialValue: _chronicConditions,
                      decoration: AppTheme.premiumInputDecoration(
                        label: 'Chronic Conditions',
                        hint: 'e.g. Hypertension, Hypothyroidism',
                        icon: Icons.medical_services,
                      ),
                      onSaved: (val) => _chronicConditions = val ?? '',
                    ),
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        Expanded(
                          child: TextFormField(
                            initialValue: _insuranceCompany,
                            decoration: AppTheme.premiumInputDecoration(
                              label: 'Provider',
                              icon: Icons.security,
                            ),
                            onSaved: (val) => _insuranceCompany = val ?? '',
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: TextFormField(
                            initialValue: _insurancePolicyNumber,
                            decoration: AppTheme.premiumInputDecoration(
                              label: 'Policy Number',
                              icon: Icons.numbers,
                            ),
                            onSaved: (val) => _insurancePolicyNumber = val ?? '',
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 32),

              // Save Button
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () => _saveForm(provider),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.accentTeal,
                    foregroundColor: Colors.black,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                    elevation: 8,
                    shadowColor: AppTheme.accentTeal.withOpacity(0.3),
                  ),
                  child: const Text('Save Profile Changes', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                ),
              ),
              const SizedBox(height: 40),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSectionTitle(String title) {
    return Padding(
      padding: const EdgeInsets.only(left: 4.0),
      child: Text(
        title,
        style: const TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.bold,
          letterSpacing: 0.5,
          color: AppTheme.textSecondary,
        ),
      ),
    );
  }
}
