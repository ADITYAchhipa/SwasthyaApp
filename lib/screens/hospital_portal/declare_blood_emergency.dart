import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/swasthya_tap_provider.dart';
import '../../theme/app_theme.dart';
import '../../widgets/glass_card.dart';

class DeclareBloodEmergencyScreen extends StatefulWidget {
  const DeclareBloodEmergencyScreen({Key? key}) : super(key: key);

  @override
  _DeclareBloodEmergencyScreenState createState() => _DeclareBloodEmergencyScreenState();
}

class _DeclareBloodEmergencyScreenState extends State<DeclareBloodEmergencyScreen> {
  final _formKey = GlobalKey<FormState>();

  String _hospitalName = 'Apollo Hospitals, Richmond Town';
  String _hospitalAddress = 'Richmond Rd, Richmond Town, Bengaluru, Karnataka 560025';
  String _bloodGroup = 'O+';
  int _unitsNeeded = 3;
  double _radiusKm = 5.0;

  // Mock list of hospitals
  final List<Map<String, String>> _hospitals = [
    {
      'name': 'Apollo Hospitals, Richmond Town',
      'address': 'Richmond Rd, Richmond Town, Bengaluru, Karnataka 560025',
      'lat': '12.9622',
      'lng': '77.5978'
    },
    {
      'name': 'Fortis Hospital, Cunningham Road',
      'address': 'Cunningham Rd, Vasanth Nagar, Bengaluru, Karnataka 560052',
      'lat': '12.9882',
      'lng': '77.5942'
    },
    {
      'name': 'St. John\'s Medical College Hospital',
      'address': 'Sarjapur Main Rd, Koramangala, Bengaluru, Karnataka 560034',
      'lat': '12.9328',
      'lng': '77.6225'
    }
  ];

  final List<String> _bloodGroups = ['O+', 'O-', 'A+', 'A-', 'B+', 'B-', 'AB+', 'AB-'];

  void _submitRequest(SwasthyaTapProvider provider) {
    if (_formKey.currentState!.validate()) {
      _formKey.currentState!.save();

      // Find selected hospital coordinates
      final hospitalData = _hospitals.firstWhere((h) => h['name'] == _hospitalName);
      final lat = double.parse(hospitalData['lat']!);
      final lng = double.parse(hospitalData['lng']!);

      provider.declareBloodEmergency(
        hospitalName: _hospitalName,
        hospitalAddress: _hospitalAddress,
        bloodGroup: _bloodGroup,
        unitsNeeded: _unitsNeeded,
        lat: lat,
        lng: lng,
        radiusKm: _radiusKm,
      );

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              const Icon(Icons.flash_on, color: Colors.white),
              const SizedBox(width: 8),
              const Text(
                'Emergency Broadcast Dispatched! Matching donors are receiving SMS alerts.',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
            ],
          ),
          backgroundColor: AppTheme.accentRed,
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
        title: const Text('Declare Blood Emergency'),
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
              const Text(
                'Smart Donor Broadcast System',
                style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: AppTheme.accentRed),
              ),
              const Text(
                'Declares real-time location-aware shortages, paging donors instantly.',
                style: TextStyle(color: AppTheme.textSecondary, fontSize: 12),
              ),
              const SizedBox(height: 20),

              // Hospital Selection Card
              _buildSectionLabel('1. Requesting Facility'),
              const SizedBox(height: 10),
              GlassCard(
                child: Column(
                  children: [
                    DropdownButtonFormField<String>(
                      value: _hospitalName,
                      dropdownColor: AppTheme.cardBg,
                      decoration: AppTheme.premiumInputDecoration(
                        label: 'Select Hospital',
                        icon: Icons.local_hospital,
                      ),
                      items: _hospitals.map((h) {
                        return DropdownMenuItem<String>(value: h['name']!, child: Text(h['name']!, style: const TextStyle(fontSize: 13)));
                      }).toList(),
                      onChanged: (val) {
                        if (val != null) {
                          setState(() {
                            _hospitalName = val;
                            _hospitalAddress = _hospitals.firstWhere((h) => h['name'] == val)['address']!;
                          });
                        }
                      },
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      key: ValueKey(_hospitalAddress),
                      initialValue: _hospitalAddress,
                      maxLines: 2,
                      enabled: false,
                      decoration: AppTheme.premiumInputDecoration(
                        label: 'Facility Address',
                        icon: Icons.location_on,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),

              // Blood Parameters Card
              _buildSectionLabel('2. Blood Requirements'),
              const SizedBox(height: 10),
              GlassCard(
                child: Column(
                  children: [
                    DropdownButtonFormField<String>(
                      value: _bloodGroup,
                      dropdownColor: AppTheme.cardBg,
                      decoration: AppTheme.premiumInputDecoration(
                        label: 'Required Blood Group',
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
                    const SizedBox(height: 16),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            const Text('Units Needed', style: TextStyle(fontSize: 13, color: AppTheme.textSecondary)),
                            Text('$_unitsNeeded Units', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: AppTheme.accentRed)),
                          ],
                        ),
                        Slider(
                          value: _unitsNeeded.toDouble(),
                          min: 1.0,
                          max: 10.0,
                          divisions: 9,
                          activeColor: AppTheme.accentRed,
                          inactiveColor: Colors.white12,
                          onChanged: (val) {
                            setState(() {
                              _unitsNeeded = val.round();
                            });
                          },
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),

              // Radius Selection Card
              _buildSectionLabel('3. Broadcast Distance'),
              const SizedBox(height: 10),
              GlassCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text('Search Radius Limit', style: TextStyle(fontSize: 13, color: AppTheme.textSecondary)),
                        Text('${_radiusKm.toStringAsFixed(1)} km', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: AppTheme.accentTeal)),
                      ],
                    ),
                    Slider(
                      value: _radiusKm,
                      min: 1.0,
                      max: 10.0,
                      divisions: 18,
                      activeColor: AppTheme.accentTeal,
                      inactiveColor: Colors.white12,
                      onChanged: (val) {
                        setState(() {
                          _radiusKm = val;
                        });
                      },
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        const Icon(Icons.info_outline, size: 14, color: AppTheme.textSecondary),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            'Alerts will be broadcasted via instant SMS to compatible donors living within this radius.',
                            style: TextStyle(color: AppTheme.textSecondary.withOpacity(0.8), fontSize: 11),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 32),

              // Dispatch Button
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: () => _submitRequest(provider),
                  icon: const Icon(Icons.flash_on, size: 18, color: Colors.black),
                  label: const Text('DISPATCH EMERGENCY BROADCAST', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: Colors.black)),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.accentRed,
                    foregroundColor: Colors.black,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                    shadowColor: AppTheme.accentRed.withOpacity(0.4),
                    elevation: 10,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSectionLabel(String text) {
    return Padding(
      padding: const EdgeInsets.only(left: 4.0),
      child: Text(
        text,
        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: AppTheme.textSecondary),
      ),
    );
  }
}
