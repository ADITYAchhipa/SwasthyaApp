import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../models/models.dart';
import '../../services/api_service.dart';
import '../../theme/app_theme.dart';
import '../citizen_portal/scanned_profile_screen.dart';
import '../../utils/prescription_pdf_generator.dart';
import '../../utils/pdf_downloader.dart';

class AddPrescriptionScreen extends StatefulWidget {
  final MedicalProfile profile;
  final Function(MedicalProfile) onProfileUpdated;

  const AddPrescriptionScreen({
    Key? key,
    required this.profile,
    required this.onProfileUpdated,
  }) : super(key: key);

  @override
  State<AddPrescriptionScreen> createState() => _AddPrescriptionScreenState();
}

class _MedicineControllers {
  String id;
  String name;
  String dosage;
  String frequency;
  String duration;
  String instructions;

  _MedicineControllers({
    required this.id,
    this.name = 'Telmisartan 40mg',
    this.dosage = '1 Tablet',
    this.frequency = 'Once Daily (Morning)',
    this.duration = '30 Days',
    this.instructions = 'After breakfast',
  });

  Map<String, dynamic> toJson() {
    final freq = frequency.toLowerCase();
    final inst = instructions.toLowerCase();

    final morning = freq.contains('morning') || freq.contains('1-') || freq.contains('1-0-1') || freq.contains('1-1-1') || freq.contains('daily');
    final afternoon = freq.contains('afternoon') || freq.contains('-1-') || freq.contains('1-1-1') || freq.contains('daily');
    final night = freq.contains('night') || freq.contains('-1') || freq.contains('1-0-1') || freq.contains('1-1-1') || freq.contains('daily');

    final beforeFood = inst.contains('before') || inst.contains('empty');
    final afterFood = !beforeFood;

    return {
      'medicineName': name,
      'dosage': dosage,
      'frequency': frequency,
      'duration': duration,
      'instructions': instructions,
      'morning': morning,
      'afternoon': afternoon,
      'night': night,
      'beforeFood': beforeFood,
      'afterFood': afterFood,
      'quantity': dosage.toLowerCase().contains('tablet') ? '30 Tablets' : '10 Units',
      'purpose': 'Treatment',
      'sideEffects': 'None reported',
      'storage': 'Store in a cool dry place',
      'alternatives': 'N/A',
      'isTakenToday': false,
    };
  }
}

class _AddPrescriptionScreenState extends State<AddPrescriptionScreen> {
  final _formKey = GlobalKey<FormState>();
  
  String _rxId = 'RX-2026-891';
  String _dateStr = '24 Jun 2026';
  String _hospitalName = 'Apollo Speciality Hospital';
  String _doctorName = 'Dr. Amit Shah';
  final _qualificationController = TextEditingController(text: 'MD (Cardiology), FACC');
  String _status = 'Active';
  
  final _diagnosisController = TextEditingController(text: 'Mild Hypertension & Preventive Checkup');
  final _notesController = TextEditingController(text: 'Low sodium diet, Regular exercise. Next follow up after 30 days.');
  
  bool _isSaving = false;

  final List<_MedicineControllers> _medicines = [
    _MedicineControllers(
      id: '1',
      name: 'Telmisartan 40mg',
      dosage: '1 Tablet',
      frequency: 'Once Daily (Morning)',
      duration: '30 Days',
      instructions: 'After breakfast',
    ),
    _MedicineControllers(
      id: '2',
      name: 'Amlodipine 5mg',
      dosage: '1 Tablet',
      frequency: 'Once Daily (Night)',
      duration: '30 Days',
      instructions: 'After dinner',
    ),
    _MedicineControllers(
      id: '3',
      name: 'Multivitamin Complex',
      dosage: '1 Capsule',
      frequency: 'Once Daily',
      duration: '15 Days',
      instructions: 'After meal',
    ),
  ];

  @override
  void dispose() {
    _qualificationController.dispose();
    _diagnosisController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  void _generateNewRxId() {
    final rand = 100 + (DateTime.now().millisecondsSinceEpoch % 900);
    setState(() {
      _rxId = 'RX-2026-$rand';
    });
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Generated new Prescription ID: $_rxId'),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  void _addMedicineRow() {
    setState(() {
      _medicines.add(_MedicineControllers(
        id: DateTime.now().millisecondsSinceEpoch.toString(),
        name: 'Paracetamol 650mg',
        dosage: '1 Tablet',
        frequency: 'Twice Daily',
        duration: '5 Days',
        instructions: 'After meal',
      ));
    });
  }

  void _removeMedicineRow(int index) {
    if (_medicines.length <= 1) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('At least one medicine is required.'),
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }
    setState(() {
      _medicines.removeAt(index);
    });
  }

  void _savePrescription() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _isSaving = true;
    });

    List<int>? fileBytes;
    try {
      fileBytes = await generatePrescriptionPdfBytes(
        profile: widget.profile,
        rxId: _rxId,
        date: _dateStr,
        hospitalName: _hospitalName,
        doctorName: _doctorName,
        qualification: _qualificationController.text.trim(),
        diagnosis: _diagnosisController.text.trim(),
        doctorNotes: _notesController.text.trim(),
        medicines: _medicines,
      );
    } catch (e) {
      debugPrint('PDF pre-generation failed: $e');
    }

    final prescriptionData = {
      'prescriptionId': _rxId,
      'doctorName': _doctorName,
      'qualification': _qualificationController.text.trim(),
      'hospitalName': _hospitalName,
      'date': _dateStr,
      'diagnosis': _diagnosisController.text.trim(),
      'rxList': _medicines.map((m) => m.toJson()).toList(),
      'doctorNotes': _notesController.text.trim(),
      'status': _status,
    };

    final updatedProfile = await ApiService.addPrescription(
      widget.profile.id,
      prescriptionData,
      fileBytes: fileBytes,
      filename: 'prescription_$_rxId.pdf',
    );

    setState(() {
      _isSaving = false;
    });

    if (updatedProfile != null) {
      widget.onProfileUpdated(updatedProfile);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Row(
            children: [
              Icon(Icons.check_circle_rounded, color: Colors.white),
              SizedBox(width: 8),
              Text('Prescription created & saved successfully!', style: TextStyle(fontWeight: FontWeight.bold)),
            ],
          ),
          backgroundColor: AppTheme.accentGreen,
          behavior: SnackBarBehavior.floating,
        ),
      );
      Navigator.pop(context);
    } else {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Failed to save prescription. Please check connection.'),
          backgroundColor: AppTheme.accentRed,
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Prescriptions > Create Prescription',
              style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w600, color: const Color(0xFF64748B)),
            ),
            Text(
              'Create Prescription',
              style: GoogleFonts.poppins(fontSize: 18, fontWeight: FontWeight.bold, color: const Color(0xFF0F172A)),
            ),
          ],
        ),
        backgroundColor: Colors.white,
        elevation: 0,
        iconTheme: const IconThemeData(color: Color(0xFF1E293B)),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildPatientCard(),
                const SizedBox(height: 20),
                _buildPrescriptionDetailsCard(),
                const SizedBox(height: 20),
                _buildMedicationsSection(),
                const SizedBox(height: 24),
                _buildBottomActions(),
                const SizedBox(height: 24),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildPatientCard() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE2E8F0)),
        boxShadow: const [BoxShadow(color: Color(0x05000000), blurRadius: 4, offset: Offset(0, 2))],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: Image.network(
                  'https://images.unsplash.com/photo-1507003211169-0a1dd7228f2d?fit=crop&w=120&h=120&q=80',
                  width: 54,
                  height: 54,
                  fit: BoxFit.cover,
                  errorBuilder: (_, __, ___) => Container(
                    width: 54,
                    height: 54,
                    color: AppTheme.accentTeal,
                    child: const Icon(Icons.person_rounded, color: Colors.white, size: 28),
                  ),
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      widget.profile.fullName.isEmpty ? 'Rajesh Kumar' : widget.profile.fullName,
                      style: GoogleFonts.poppins(fontSize: 18, fontWeight: FontWeight.bold, color: const Color(0xFF0F172A)),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'SWA123456  •  45 Y / Male  •  ${widget.profile.bloodGroup.isEmpty ? "B+" : widget.profile.bloodGroup}',
                      style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w600, color: const Color(0xFF475569)),
                    ),
                    Text(
                      '9876543210',
                      style: GoogleFonts.inter(fontSize: 12, color: const Color(0xFF64748B)),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 12),
            child: Divider(height: 1, color: Color(0xFFE2E8F0)),
          ),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'ADDRESS',
                    style: GoogleFonts.inter(fontSize: 10, fontWeight: FontWeight.bold, color: const Color(0xFF94A3B8)),
                  ),
                  Text(
                    '123, Green Park, New Delhi - 110016',
                    style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w600, color: const Color(0xFF1E293B)),
                  ),
                ],
              ),
              OutlinedButton.icon(
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => ScannedProfileScreen(profileId: widget.profile.id),
                    ),
                  );
                },
                icon: const Icon(Icons.remove_red_eye_outlined, size: 14, color: Color(0xFF475569)),
                label: Text(
                  'View Profile',
                  style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.bold, color: const Color(0xFF1E293B)),
                ),
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  side: const BorderSide(color: Color(0xFFCBD5E1)),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildPrescriptionDetailsCard() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Prescription Details',
            style: GoogleFonts.poppins(fontSize: 16, fontWeight: FontWeight.bold, color: const Color(0xFF0F172A)),
          ),
          const SizedBox(height: 14),

          Text('Prescription ID *', style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.bold, color: const Color(0xFF334155))),
          const SizedBox(height: 6),
          Row(
            children: [
              Expanded(
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF8FAFC),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: const Color(0xFFE2E8F0)),
                  ),
                  child: Text(_rxId, style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.bold, color: const Color(0xFF0F172A))),
                ),
              ),
              const SizedBox(width: 8),
              IconButton(
                onPressed: _generateNewRxId,
                icon: const Icon(Icons.refresh_rounded, color: AppTheme.accentTeal),
                tooltip: 'Regenerate ID',
              ),
            ],
          ),
          const SizedBox(height: 14),

          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Date *', style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.bold, color: const Color(0xFF334155))),
                    const SizedBox(height: 6),
                    InkWell(
                      onTap: () async {
                        final picked = await showDatePicker(
                          context: context,
                          initialDate: DateTime.now(),
                          firstDate: DateTime(2020),
                          lastDate: DateTime(2030),
                        );
                        if (picked != null) {
                          final months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
                          setState(() {
                            _dateStr = '${picked.day} ${months[picked.month - 1]} ${picked.year}';
                          });
                        }
                      },
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF8FAFC),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: const Color(0xFFE2E8F0)),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(_dateStr, style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.bold, color: const Color(0xFF0F172A))),
                            const Icon(Icons.calendar_today_rounded, size: 16, color: Color(0xFF64748B)),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Hospital Name *', style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.bold, color: const Color(0xFF334155))),
                    const SizedBox(height: 6),
                    DropdownButtonFormField<String>(
                      value: _hospitalName,
                      decoration: _inputDecoration(),
                      style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.bold, color: const Color(0xFF0F172A)),
                      items: const [
                        DropdownMenuItem(value: 'Apollo Speciality Hospital', child: Text('Apollo Speciality')),
                        DropdownMenuItem(value: 'CityCare Hospital', child: Text('CityCare Hospital')),
                        DropdownMenuItem(value: 'Fortis Healthcare', child: Text('Fortis Healthcare')),
                      ],
                      onChanged: (val) => setState(() => _hospitalName = val!),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),

          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Doctor Name *', style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.bold, color: const Color(0xFF334155))),
                    const SizedBox(height: 6),
                    DropdownButtonFormField<String>(
                      value: _doctorName,
                      decoration: _inputDecoration(),
                      style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.bold, color: const Color(0xFF0F172A)),
                      items: const [
                        DropdownMenuItem(value: 'Dr. Amit Shah', child: Text('Dr. Amit Shah')),
                        DropdownMenuItem(value: 'Dr. Vikram Roy', child: Text('Dr. Vikram Roy')),
                      ],
                      onChanged: (val) => setState(() => _doctorName = val!),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Status *', style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.bold, color: const Color(0xFF334155))),
                    const SizedBox(height: 6),
                    DropdownButtonFormField<String>(
                      value: _status,
                      decoration: _inputDecoration(),
                      style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.bold, color: const Color(0xFF0F172A)),
                      items: const [
                        DropdownMenuItem(
                          value: 'Active',
                          child: Row(
                            children: [
                              Icon(Icons.circle, size: 8, color: Color(0xFF10B981)),
                              SizedBox(width: 6),
                              Text('Active'),
                            ],
                          ),
                        ),
                        DropdownMenuItem(value: 'Draft', child: Text('Draft')),
                        DropdownMenuItem(value: 'Completed', child: Text('Completed')),
                      ],
                      onChanged: (val) => setState(() => _status = val!),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),

          Text('Qualification *', style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.bold, color: const Color(0xFF334155))),
          const SizedBox(height: 6),
          TextFormField(
            controller: _qualificationController,
            decoration: _inputDecoration(),
            style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w600, color: const Color(0xFF0F172A)),
          ),
          const SizedBox(height: 14),

          Text('Diagnosis *', style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.bold, color: const Color(0xFF334155))),
          const SizedBox(height: 6),
          TextFormField(
            controller: _diagnosisController,
            maxLines: 2,
            maxLength: 200,
            decoration: _inputDecoration(hint: 'Enter diagnosis'),
            style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w600, color: const Color(0xFF0F172A)),
          ),
          const SizedBox(height: 10),

          Text('Doctor Notes', style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.bold, color: const Color(0xFF334155))),
          const SizedBox(height: 6),
          TextFormField(
            controller: _notesController,
            maxLines: 3,
            maxLength: 200,
            decoration: _inputDecoration(hint: 'Low sodium diet, Regular exercise...'),
            style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w600, color: const Color(0xFF0F172A)),
          ),
        ],
      ),
    );
  }

  Widget _buildMedicationsSection() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Medications',
                style: GoogleFonts.poppins(fontSize: 16, fontWeight: FontWeight.bold, color: const Color(0xFF0F172A)),
              ),
              Text(
                '${_medicines.length} Items',
                style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.bold, color: AppTheme.accentTeal),
              ),
            ],
          ),
          const SizedBox(height: 14),

          ListView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: _medicines.length,
            itemBuilder: (context, index) {
              final med = _medicines[index];
              return Container(
                margin: const EdgeInsets.only(bottom: 12),
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: const Color(0xFFF8FAFC),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: const Color(0xFFE2E8F0)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          '#${index + 1}  ${med.name}',
                          style: GoogleFonts.poppins(fontSize: 14, fontWeight: FontWeight.bold, color: const Color(0xFF0F172A)),
                        ),
                        IconButton(
                          onPressed: () => _removeMedicineRow(index),
                          icon: const Icon(Icons.delete_outline_rounded, color: Color(0xFFF43F5E), size: 20),
                          constraints: const BoxConstraints(),
                          padding: EdgeInsets.zero,
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Expanded(
                          child: DropdownButtonFormField<String>(
                            value: med.dosage,
                            decoration: _inputDecoration(label: 'Dosage'),
                            items: const [
                              DropdownMenuItem(value: '1 Tablet', child: Text('1 Tablet')),
                              DropdownMenuItem(value: '1 Capsule', child: Text('1 Capsule')),
                              DropdownMenuItem(value: '2 Tablets', child: Text('2 Tablets')),
                            ],
                            onChanged: (val) => setState(() => med.dosage = val!),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: DropdownButtonFormField<String>(
                            value: med.frequency,
                            decoration: _inputDecoration(label: 'Frequency'),
                            items: const [
                              DropdownMenuItem(value: 'Once Daily (Morning)', child: Text('Once Daily (M)')),
                              DropdownMenuItem(value: 'Once Daily (Night)', child: Text('Once Daily (N)')),
                              DropdownMenuItem(value: 'Once Daily', child: Text('Once Daily')),
                              DropdownMenuItem(value: 'Twice Daily', child: Text('Twice Daily')),
                            ],
                            onChanged: (val) => setState(() => med.frequency = val!),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Expanded(
                          child: TextFormField(
                            initialValue: med.duration,
                            decoration: _inputDecoration(label: 'Duration'),
                            onChanged: (val) => med.duration = val,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: TextFormField(
                            initialValue: med.instructions,
                            decoration: _inputDecoration(label: 'Instructions'),
                            onChanged: (val) => med.instructions = val,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              );
            },
          ),
          const SizedBox(height: 8),

          OutlinedButton.icon(
            onPressed: _addMedicineRow,
            icon: const Icon(Icons.add_rounded, color: AppTheme.accentTeal, size: 18),
            label: Text(
              '+ Add Medicine',
              style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.bold, color: AppTheme.accentTeal),
            ),
            style: OutlinedButton.styleFrom(
              minimumSize: const Size(double.infinity, 44),
              side: const BorderSide(color: AppTheme.accentTeal),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBottomActions() {
    return Column(
      children: [
        Row(
          children: [
            Expanded(
              child: OutlinedButton(
                onPressed: () {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Prescription Draft Saved')),
                  );
                },
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  side: const BorderSide(color: Color(0xFFCBD5E1)),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                child: Text(
                  'Save Draft',
                  style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.bold, color: const Color(0xFF1E293B)),
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: OutlinedButton.icon(
                onPressed: () async {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Row(
                        children: [
                          SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                          ),
                          SizedBox(width: 12),
                          Text('Generating Prescription PDF...'),
                        ],
                      ),
                    ),
                  );
                  try {
                    final bytes = await generatePrescriptionPdfBytes(
                      profile: widget.profile,
                      rxId: _rxId,
                      date: _dateStr,
                      hospitalName: _hospitalName,
                      doctorName: _doctorName,
                      qualification: _qualificationController.text.trim(),
                      diagnosis: _diagnosisController.text.trim(),
                      doctorNotes: _notesController.text.trim(),
                      medicines: _medicines,
                    );
                    printPdfFile(bytes, 'prescription_$_rxId.pdf');
                  } catch (e) {
                    if (mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text('Failed to generate PDF: $e'), backgroundColor: Colors.red),
                      );
                    }
                  }
                },
                icon: const Icon(Icons.picture_as_pdf_outlined, size: 16, color: Color(0xFF475569)),
                label: Text(
                  'Generate PDF',
                  style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.bold, color: const Color(0xFF1E293B)),
                ),
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  side: const BorderSide(color: Color(0xFFCBD5E1)),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        SizedBox(
          width: double.infinity,
          height: 50,
          child: ElevatedButton.icon(
            onPressed: _isSaving ? null : _savePrescription,
            icon: _isSaving
                ? const SizedBox.shrink()
                : const Icon(Icons.arrow_forward_rounded, color: Colors.white, size: 18),
            label: _isSaving
                ? const CircularProgressIndicator(color: Colors.white)
                : Text(
                    'Preview & Save Prescription',
                    style: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.bold, color: Colors.white),
                  ),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF0F766E),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
              elevation: 0,
            ),
          ),
        ),
      ],
    );
  }

  InputDecoration _inputDecoration({String? label, String? hint}) {
    return InputDecoration(
      labelText: label,
      hintText: hint,
      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      fillColor: const Color(0xFFF8FAFC),
      filled: true,
      labelStyle: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.bold, color: const Color(0xFF64748B)),
      hintStyle: GoogleFonts.inter(fontSize: 12, color: const Color(0xFF94A3B8)),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: Color(0xFF0F766E), width: 1.5),
      ),
    );
  }
}
