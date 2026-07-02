import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:swasthya_tap/theme/app_theme.dart';
import 'package:swasthya_tap/providers/swasthya_tap_provider.dart';
import 'package:swasthya_tap/services/api_service.dart';
import 'package:swasthya_tap/utils/translation_service.dart';
import 'package:swasthya_tap/screens/citizen_portal/previous_reports_screen.dart';

class SubmitReportScreen extends StatefulWidget {
  const SubmitReportScreen({Key? key}) : super(key: key);

  @override
  State<SubmitReportScreen> createState() => _SubmitReportScreenState();
}

class _SubmitReportScreenState extends State<SubmitReportScreen> {
  int currentStep = 1; // 1: Condition, 2: Symptoms, 3: Location, 4: Success

  // Step 1: Condition
  String selectedDisease = 'Dengue';
  String customDisease = '';
  String reportingFor = 'self';

  // Step 2: Symptoms
  final List<String> selectedSymptoms = [];
  String selectedDuration = '3-5 days';
  double severityVal = 1.0; // 0.0 -> mild, 1.0 -> moderate, 2.0 -> severe
  String? uploadedPhotoPath;

  // Step 3: Location
  String locationText = 'Udaipur, Rajasthan, India';
  String nearestPhcText = 'Primary Health Centre\nSector 14, Udaipur\n2.4 km away';
  final TextEditingController notesController = TextEditingController();
  bool submitAnonymously = true;

  bool isSubmitting = false;

  String _t(BuildContext context, String key) {
    return TranslationService.t(context, key);
  }

  @override
  void dispose() {
    notesController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final provider = Provider.of<SwasthyaTapProvider>(context);
    Widget stepContent;

    if (currentStep == 1) {
      stepContent = _buildStep1Content(
        context,
        selectedDisease,
        customDisease,
        reportingFor,
        (val) => setState(() => selectedDisease = val),
        (val) => setState(() => customDisease = val),
        (val) => setState(() => reportingFor = val),
      );
    } else if (currentStep == 2) {
      stepContent = _buildStep2Content(
        context,
        selectedSymptoms,
        selectedDuration,
        severityVal,
        uploadedPhotoPath,
        (symptom, isSelected) {
          setState(() {
            if (isSelected) {
              selectedSymptoms.add(symptom);
            } else {
              selectedSymptoms.remove(symptom);
            }
          });
        },
        (val) => setState(() => selectedDuration = val),
        (val) => setState(() => severityVal = val),
        () {
          setState(() => uploadedPhotoPath = '/mock/photo_${DateTime.now().millisecondsSinceEpoch}.jpg');
        },
      );
    } else if (currentStep == 3) {
      stepContent = _buildStep3Content(
        context,
        locationText,
        nearestPhcText,
        notesController,
        submitAnonymously,
        (val) => setState(() => submitAnonymously = val),
        () {
          setState(() => locationText = 'Udaipur City Center, Rajasthan, India');
        },
      );
    } else {
      // Success Screen
      return Scaffold(
        backgroundColor: Colors.white,
        body: SafeArea(
          child: SingleChildScrollView(
            child: _buildStep4Content(
              context,
              provider,
              () {
                Navigator.pop(context);
              },
              () {
                Navigator.pop(context);
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => const PreviousReportsScreen()),
                );
              },
            ),
          ),
        ),
      );
    }

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: Text(
          _t(context, 'report_health_issue'),
          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
        ),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded),
          onPressed: () {
            if (currentStep > 1) {
              setState(() => currentStep--);
            } else {
              Navigator.pop(context);
            }
          },
        ),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 12.0),
            child: TextButton.icon(
              onPressed: () {},
              icon: const Icon(Icons.language_rounded, size: 16, color: AppTheme.textSecondary),
              label: Text(
                TranslationService.t(context, 'languages_btn'),
                style: const TextStyle(fontSize: 12, color: AppTheme.textSecondary, fontWeight: FontWeight.bold),
              ),
              style: TextButton.styleFrom(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                backgroundColor: AppTheme.lightBg,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
              ),
            ),
          ),
        ],
        elevation: 0,
        backgroundColor: Colors.white,
        foregroundColor: AppTheme.textPrimary,
      ),
      body: SafeArea(
        child: Column(
          children: [
            // Warning Banner & Step indicator
            _buildHeader(context, currentStep),
            
            // Content
            Expanded(
              child: SingleChildScrollView(
                child: stepContent,
              ),
            ),

            // Bottom Buttons
            _buildBottomNavigation(
              currentStep: currentStep,
              onBackOrSkip: () {
                if (currentStep > 1) {
                  setState(() => currentStep--);
                } else {
                  Navigator.pop(context);
                }
              },
              onNextOrSubmit: () async {
                if (currentStep < 3) {
                  setState(() => currentStep++);
                } else {
                  setState(() => isSubmitting = true);
                  final severityLevel = severityVal == 0.0
                      ? 'mild'
                      : (severityVal == 1.0 ? 'moderate' : 'severe');
                  
                  final diseaseToSubmit = selectedDisease == 'Other' ? customDisease : selectedDisease;

                  final success = await ApiService.submitHealthReport(
                    disease: diseaseToSubmit.isNotEmpty ? diseaseToSubmit : 'Other',
                    symptoms: selectedSymptoms,
                    severityLevel: severityLevel,
                    locationDescription: locationText,
                    additionalNotes: notesController.text,
                    reportingFor: reportingFor,
                    duration: selectedDuration,
                    submitAnonymously: submitAnonymously,
                  );
                  
                  setState(() => isSubmitting = false);
                  
                  if (success) {
                    setState(() => currentStep = 4);
                  } else {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Failed to submit report. Please check connection.'),
                        backgroundColor: AppTheme.accentRed,
                      ),
                    );
                  }
                }
              },
              isSubmitting: isSubmitting,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader(BuildContext context, int currentStep) {
    return Column(
      children: [
        // Warning Banner
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 10),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: const Color(0xFFFEF3C7),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(Icons.warning_amber_rounded, color: Color(0xFFD97706), size: 28),
              ),
              const SizedBox(width: 16),
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Report Health Concern',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: AppTheme.textPrimary,
                      ),
                    ),
                    SizedBox(height: 4),
                    Text(
                      'Help your community stay safe. Reports are anonymous unless you opt-in.',
                      style: TextStyle(
                        fontSize: 11,
                        color: AppTheme.textSecondary,
                        height: 1.3,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        
        const SizedBox(height: 12),

        // Step indicator (only show for steps 1, 2, 3)
        if (currentStep <= 3) ...[
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                _buildStepItem(1, 'Condition', currentStep >= 1),
                _buildStepLine(currentStep >= 2),
                _buildStepItem(2, 'Symptoms', currentStep >= 2),
                _buildStepLine(currentStep >= 3),
                _buildStepItem(3, 'Location', currentStep >= 3),
              ],
            ),
          ),
          const SizedBox(height: 16),
          const Divider(height: 1, color: AppTheme.borderColor),
        ],
      ],
    );
  }

  Widget _buildStepItem(int stepNum, String title, bool isActive) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 32,
          height: 32,
          decoration: BoxDecoration(
            color: isActive ? const Color(0xFF0D9488) : Colors.white,
            shape: BoxShape.circle,
            border: Border.all(
              color: isActive ? const Color(0xFF0D9488) : Colors.grey[300]!,
              width: 2,
            ),
          ),
          alignment: Alignment.center,
          child: Text(
            stepNum.toString(),
            style: TextStyle(
              color: isActive ? Colors.white : Colors.grey[600],
              fontSize: 13,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
        const SizedBox(height: 6),
        Text(
          title,
          style: TextStyle(
            color: isActive ? AppTheme.textPrimary : Colors.grey[500],
            fontSize: 11,
            fontWeight: isActive ? FontWeight.bold : FontWeight.normal,
          ),
        ),
      ],
    );
  }

  Widget _buildStepLine(bool isActive) {
    return Expanded(
      child: Padding(
        padding: const EdgeInsets.only(bottom: 18),
        child: Container(
          height: 2,
          color: isActive ? const Color(0xFF0D9488) : Colors.grey[300],
        ),
      ),
    );
  }

  Widget _buildStep1Content(
    BuildContext context,
    String selectedDisease,
    String customDisease,
    String reportingFor,
    Function(String) onSelectDisease,
    Function(String) onChangeCustomDisease,
    Function(String) onSelectReportingFor,
  ) {
    final List<Map<String, dynamic>> diseases = [
      {'name': 'Dengue', 'icon': Icons.bug_report_outlined},
      {'name': 'Malaria', 'icon': Icons.bug_report_outlined},
      {'name': 'COVID-19', 'icon': Icons.coronavirus_outlined},
      {'name': 'Chikungunya', 'icon': Icons.accessibility_new_rounded},
      {'name': 'Typhoid', 'icon': Icons.biotech_outlined},
      {'name': 'Cholera', 'icon': Icons.water_drop_outlined},
      {'name': 'Unknown Fever', 'icon': Icons.thermostat_outlined},
      {'name': 'Other', 'icon': Icons.more_horiz_outlined},
    ];

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            '1. What are you reporting?',
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.bold,
              color: AppTheme.textPrimary,
            ),
          ),
          const SizedBox(height: 12),
          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 2,
              childAspectRatio: 2.2,
              crossAxisSpacing: 12,
              mainAxisSpacing: 12,
            ),
            itemCount: diseases.length,
            itemBuilder: (context, index) {
              final item = diseases[index];
              final name = item['name'] as String;
              final icon = item['icon'] as IconData;
              final isSelected = selectedDisease == name;

              return GestureDetector(
                onTap: () => onSelectDisease(name),
                child: Container(
                  decoration: BoxDecoration(
                    color: isSelected ? const Color(0xFF0D9488) : Colors.white,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: isSelected ? const Color(0xFF0D9488) : Colors.grey[200]!,
                      width: 1.5,
                    ),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        icon,
                        color: isSelected ? Colors.white : AppTheme.textPrimary,
                        size: 20,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        name,
                        style: TextStyle(
                          color: isSelected ? Colors.white : AppTheme.textPrimary,
                          fontSize: 13,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
          
          const SizedBox(height: 16),
          
          const Text(
            'Please specify (Other)',
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.bold,
              color: AppTheme.textPrimary,
            ),
          ),
          const SizedBox(height: 8),
          TextField(
            onChanged: onChangeCustomDisease,
            enabled: selectedDisease == 'Other',
            decoration: InputDecoration(
              hintText: 'Enter condition',
              hintStyle: TextStyle(color: Colors.grey[400], fontSize: 13),
              fillColor: selectedDisease == 'Other' ? Colors.white : AppTheme.lightBg,
              filled: true,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(color: Colors.grey[200]!),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(color: Colors.grey[200]!),
              ),
              contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            ),
          ),

          const SizedBox(height: 24),

          const Text(
            '2. Reporting for?',
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.bold,
              color: AppTheme.textPrimary,
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(child: _buildReportingForCard('Self', Icons.person_outline_rounded, reportingFor == 'self', () => onSelectReportingFor('self'))),
              const SizedBox(width: 8),
              Expanded(child: _buildReportingForCard('Family Member', Icons.group_outlined, reportingFor == 'family', () => onSelectReportingFor('family'))),
              const SizedBox(width: 8),
              Expanded(child: _buildReportingForCard('Community Observation', Icons.groups_outlined, reportingFor == 'community', () => onSelectReportingFor('community'))),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildReportingForCard(String title, IconData icon, bool isSelected, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Stack(
        children: [
          Container(
            height: 90,
            decoration: BoxDecoration(
              color: isSelected ? const Color(0xFFF0FDFA) : Colors.white,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: isSelected ? const Color(0xFF0D9488) : Colors.grey[200]!,
                width: 1.5,
              ),
            ),
            padding: const EdgeInsets.all(8),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Icon(
                  icon,
                  color: isSelected ? const Color(0xFF0D9488) : Colors.grey[600],
                  size: 24,
                ),
                const SizedBox(height: 8),
                Text(
                  title,
                  style: TextStyle(
                    color: isSelected ? const Color(0xFF0D9488) : Colors.grey[600],
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                  ),
                  textAlign: TextAlign.center,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          if (isSelected)
            Positioned(
              top: 6,
              right: 6,
              child: Container(
                padding: const EdgeInsets.all(1.5),
                decoration: const BoxDecoration(
                  color: Color(0xFF0D9488),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.check, color: Colors.white, size: 10),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildStep2Content(
    BuildContext context,
    List<String> selectedSymptoms,
    String selectedDuration,
    double severityVal,
    String? photoPath,
    Function(String, bool) onToggleSymptom,
    Function(String) onChangeDuration,
    Function(double) onChangeSeverity,
    VoidCallback onAddPhoto,
  ) {
    final List<Map<String, dynamic>> symptoms = [
      {'name': 'High Fever', 'icon': Icons.thermostat_outlined},
      {'name': 'Body Pain', 'icon': Icons.accessibility_outlined},
      {'name': 'Headache', 'icon': Icons.face_retouching_natural_outlined},
      {'name': 'Rash', 'icon': Icons.grain_outlined},
      {'name': 'Vomiting', 'icon': Icons.sick_outlined},
      {'name': 'Bleeding', 'icon': Icons.water_drop_outlined},
      {'name': 'Breathlessness', 'icon': Icons.air_outlined},
      {'name': 'Cough', 'icon': Icons.record_voice_over_outlined},
      {'name': 'Diarrhea', 'icon': Icons.accessible_forward_outlined},
      {'name': 'Eye Pain', 'icon': Icons.visibility_outlined},
      {'name': 'Joint Pain', 'icon': Icons.join_left_outlined},
    ];

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            '1. Select Symptoms (Select all that apply)',
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.bold,
              color: AppTheme.textPrimary,
            ),
          ),
          const SizedBox(height: 12),
          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 2,
              childAspectRatio: 2.8,
              crossAxisSpacing: 10,
              mainAxisSpacing: 10,
            ),
            itemCount: symptoms.length,
            itemBuilder: (context, index) {
              final item = symptoms[index];
              final name = item['name'] as String;
              final icon = item['icon'] as IconData;
              final isSelected = selectedSymptoms.contains(name);

              return GestureDetector(
                onTap: () => onToggleSymptom(name, !isSelected),
                child: Container(
                  decoration: BoxDecoration(
                    color: isSelected ? const Color(0xFFF0FDFA) : Colors.white,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                      color: isSelected ? const Color(0xFF0D9488) : Colors.grey[200]!,
                      width: 1.5,
                    ),
                  ),
                  padding: const EdgeInsets.symmetric(horizontal: 10),
                  child: Row(
                    children: [
                      Icon(
                        icon,
                        color: isSelected ? const Color(0xFF0D9488) : Colors.grey[600],
                        size: 18,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          name,
                          style: TextStyle(
                            color: AppTheme.textPrimary,
                            fontSize: 11.5,
                            fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      if (isSelected)
                        const Icon(
                          Icons.check_circle_rounded,
                          color: Color(0xFF0D9488),
                          size: 16,
                        ),
                    ],
                  ),
                ),
              );
            },
          ),

          const SizedBox(height: 24),

          const Text(
            '2. Duration',
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.bold,
              color: AppTheme.textPrimary,
            ),
          ),
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: Colors.grey[200]!),
            ),
            child: DropdownButtonHideUnderline(
              child: DropdownButton<String>(
                value: selectedDuration,
                isExpanded: true,
                icon: Icon(Icons.keyboard_arrow_down_rounded, color: Colors.grey[600]),
                items: ['1-2 days', '3-5 days', 'More than 5 days']
                    .map((dur) => DropdownMenuItem(
                          value: dur,
                          child: Text(dur, style: const TextStyle(fontSize: 13, color: AppTheme.textPrimary)),
                        ))
                    .toList(),
                onChanged: (val) {
                  if (val != null) onChangeDuration(val);
                },
              ),
            ),
          ),

          const SizedBox(height: 24),

          const Text(
            '3. Severity',
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.bold,
              color: AppTheme.textPrimary,
            ),
          ),
          const SizedBox(height: 8),
          SliderTheme(
            data: SliderTheme.of(context).copyWith(
              activeTrackColor: const Color(0xFFF97316),
              inactiveTrackColor: Colors.grey[200],
              thumbColor: const Color(0xFFF97316),
              overlayColor: const Color(0xFFF97316).withOpacity(0.12),
              valueIndicatorColor: const Color(0xFFF97316),
              tickMarkShape: const RoundSliderTickMarkShape(),
              activeTickMarkColor: const Color(0xFFF97316),
              inactiveTickMarkColor: Colors.grey[300],
            ),
            child: Slider(
              value: severityVal,
              min: 0,
              max: 2,
              divisions: 2,
              onChanged: onChangeSeverity,
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Mild',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: severityVal == 0 ? FontWeight.bold : FontWeight.normal,
                    color: severityVal == 0 ? const Color(0xFFF97316) : Colors.grey[500],
                  ),
                ),
                Text(
                  'Moderate',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: severityVal == 1 ? FontWeight.bold : FontWeight.normal,
                    color: severityVal == 1 ? const Color(0xFFF97316) : Colors.grey[500],
                  ),
                ),
                Text(
                  'Severe',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: severityVal == 2 ? FontWeight.bold : FontWeight.normal,
                    color: severityVal == 2 ? const Color(0xFFF97316) : Colors.grey[500],
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 24),

          const Text(
            '4. Photo Upload (Optional)',
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.bold,
              color: AppTheme.textPrimary,
            ),
          ),
          const SizedBox(height: 10),
          GestureDetector(
            onTap: onAddPhoto,
            child: Container(
              height: 100,
              decoration: BoxDecoration(
                color: Colors.grey[50],
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.grey[300]!, style: BorderStyle.solid),
              ),
              alignment: Alignment.center,
              child: photoPath == null
                  ? Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.camera_alt_outlined, color: Colors.grey[400], size: 28),
                        const SizedBox(height: 6),
                        const Text(
                          'Add Photo',
                          style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: AppTheme.textPrimary),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          'Rashes, breeding grounds, etc.',
                          style: TextStyle(fontSize: 10, color: Colors.grey[500]),
                        ),
                      ],
                    )
                  : Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(Icons.check_circle, color: Color(0xFF0D9488), size: 20),
                        const SizedBox(width: 8),
                        Text(
                          'Photo added: ${photoPath.split('/').last}',
                          style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: AppTheme.textPrimary),
                        ),
                      ],
                    ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStep3Content(
    BuildContext context,
    String locationText,
    String nearestPhcText,
    TextEditingController notesController,
    bool submitAnonymously,
    Function(bool) onToggleAnonymously,
    VoidCallback onEditLocation,
  ) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            '1. Location',
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.bold,
              color: AppTheme.textPrimary,
            ),
          ),
          const SizedBox(height: 10),
          
          Container(
            height: 150,
            decoration: BoxDecoration(
              color: const Color(0xFFF3F4F6),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: Colors.grey[200]!),
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(16),
              child: Stack(
                children: [
                  Positioned.fill(
                    child: CustomPaint(
                      painter: _SimulatedMapPainter(),
                    ),
                  ),
                  const Center(
                    child: Icon(Icons.location_on, color: Colors.red, size: 40),
                  ),
                  Positioned(
                    bottom: 12,
                    right: 12,
                    child: Container(
                      padding: const EdgeInsets.all(8),
                      decoration: const BoxDecoration(
                        color: Colors.white,
                        shape: BoxShape.circle,
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black12,
                            blurRadius: 4,
                            offset: Offset(0, 2),
                          ),
                        ],
                      ),
                      child: const Icon(Icons.my_location, color: AppTheme.textPrimary, size: 20),
                    ),
                  ),
                ],
              ),
            ),
          ),
          
          const SizedBox(height: 8),

          Row(
            children: [
              const Icon(Icons.location_on_outlined, color: AppTheme.textSecondary, size: 18),
              const SizedBox(width: 6),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Location captured', style: TextStyle(fontSize: 10, color: Colors.grey)),
                    Text(
                      locationText,
                      style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: AppTheme.textPrimary),
                    ),
                  ],
                ),
              ),
              TextButton(
                onPressed: onEditLocation,
                child: const Text('Edit', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Color(0xFF0D9488))),
              ),
            ],
          ),

          const SizedBox(height: 20),

          const Text(
            '2. Nearest PHC (Auto-detected)',
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.bold,
              color: AppTheme.textPrimary,
            ),
          ),
          const SizedBox(height: 10),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.grey[200]!),
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.grey[100],
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(Icons.local_hospital_outlined, color: Color(0xFF0D9488), size: 24),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Primary Health Centre',
                        style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: AppTheme.textPrimary),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        nearestPhcText.split('\n')[1],
                        style: const TextStyle(fontSize: 11, color: AppTheme.textSecondary),
                      ),
                    ],
                  ),
                ),
                Text(
                  nearestPhcText.split('\n')[2],
                  style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: AppTheme.textSecondary),
                ),
              ],
            ),
          ),

          const SizedBox(height: 20),

          const Text(
            '3. Additional Notes (Optional)',
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.bold,
              color: AppTheme.textPrimary,
            ),
          ),
          const SizedBox(height: 8),
          Stack(
            children: [
              TextField(
                controller: notesController,
                maxLines: 4,
                maxLength: 500,
                style: const TextStyle(fontSize: 13),
                decoration: InputDecoration(
                  hintText: 'Write additional details...',
                  hintStyle: TextStyle(color: Colors.grey[400], fontSize: 13),
                  fillColor: Colors.white,
                  filled: true,
                  counterText: '',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(color: Colors.grey[200]!),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(color: Colors.grey[200]!),
                  ),
                  contentPadding: const EdgeInsets.all(14),
                ),
              ),
              Positioned(
                bottom: 12,
                right: 12,
                child: ValueListenableBuilder<TextEditingValue>(
                  valueListenable: notesController,
                  builder: (context, value, child) {
                    return Text(
                      '${value.text.length}/500',
                      style: TextStyle(fontSize: 10, color: Colors.grey[400]),
                    );
                  },
                ),
              ),
            ],
          ),

          const SizedBox(height: 20),

          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '4. Submit Anonymously',
                      style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: AppTheme.textPrimary),
                    ),
                    SizedBox(height: 2),
                    Text(
                      'Your identity will not be shared',
                      style: TextStyle(fontSize: 11, color: AppTheme.textSecondary),
                    ),
                  ],
                ),
              ),
              Switch(
                value: submitAnonymously,
                onChanged: onToggleAnonymously,
                activeColor: const Color(0xFF0D9488),
              ),
            ],
          ),
          
          const SizedBox(height: 10),

          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: const Color(0xFFFFFBEB),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: const Color(0xFFFDE68A)),
            ),
            child: const Row(
              children: [
                Icon(Icons.lock_outline, color: Color(0xFFD97706), size: 16),
                SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'You can opt-in to share contact details later if required.',
                    style: TextStyle(fontSize: 11, color: Color(0xFFB45309)),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStep4Content(
    BuildContext context,
    SwasthyaTapProvider provider,
    VoidCallback onDone,
    VoidCallback onViewMyReports,
  ) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 40),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Center(
            child: AnimatedCheckmark(),
          ),
          
          const SizedBox(height: 24),
          
          const Text(
            'Thank You!',
            style: TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.bold,
              color: AppTheme.textPrimary,
            ),
            textAlign: TextAlign.center,
          ),
          
          const SizedBox(height: 8),
          
          const Text(
            'Your report helps protect your community.',
            style: TextStyle(
              fontSize: 13,
              color: AppTheme.textSecondary,
            ),
            textAlign: TextAlign.center,
          ),
          
          const SizedBox(height: 32),
          
          _buildSuccessNotificationItem(Icons.notifications_outlined, 'Local PHC has been notified'),
          const SizedBox(height: 12),
          _buildSuccessNotificationItem(Icons.people_outline, 'Health officials may take necessary action'),
          const SizedBox(height: 12),
          _buildSuccessNotificationItem(Icons.verified_user_outlined, 'Together, we keep everyone safe'),
          
          const SizedBox(height: 40),
          
          ElevatedButton(
            onPressed: onDone,
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFEA580C),
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 14),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
              elevation: 0,
            ),
            child: const Text('Done', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
          ),
          
          const SizedBox(height: 12),
          
          TextButton(
            onPressed: onViewMyReports,
            child: const Text(
              'View My Reports',
              style: TextStyle(color: Color(0xFF0D9488), fontWeight: FontWeight.bold, fontSize: 13),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSuccessNotificationItem(IconData icon, String text) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFF3F4F6)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.01),
            blurRadius: 4,
            offset: const Offset(0, 1),
          ),
        ],
      ),
      child: Row(
        children: [
          Icon(icon, color: Colors.grey[500], size: 20),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              text,
              style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: AppTheme.textPrimary),
            ),
          ),
          const Icon(Icons.check_circle, color: Color(0xFF10B981), size: 16),
        ],
      ),
    );
  }

  Widget _buildBottomNavigation({
    required int currentStep,
    required VoidCallback onBackOrSkip,
    required VoidCallback onNextOrSubmit,
    required bool isSubmitting,
  }) {
    final leftText = currentStep == 1 ? 'Skip' : 'Back';
    final rightText = currentStep == 3 ? 'Submit Report' : 'Next';
    final isSubmit = currentStep == 3;
    final rightColor = isSubmit ? const Color(0xFFEA580C) : const Color(0xFF0D9488);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(top: BorderSide(color: AppTheme.borderColor)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          TextButton(
            onPressed: onBackOrSkip,
            child: Row(
              children: [
                if (currentStep > 1) ...[
                  const Icon(Icons.arrow_back_ios_new_rounded, size: 12, color: Color(0xFF0D9488)),
                  const SizedBox(width: 6),
                ],
                Text(
                  leftText,
                  style: const TextStyle(
                    color: Color(0xFF0D9488),
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ),
          
          ElevatedButton(
            onPressed: isSubmitting ? null : onNextOrSubmit,
            style: ElevatedButton.styleFrom(
              backgroundColor: rightColor,
              foregroundColor: Colors.white,
              elevation: 0,
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(20),
              ),
            ),
            child: isSubmitting
                ? const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                  )
                : Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        rightText,
                        style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(width: 8),
                      Icon(
                        isSubmit ? Icons.send_rounded : Icons.arrow_forward_rounded,
                        size: 14,
                      ),
                    ],
                  ),
          ),
        ],
      ),
    );
  }
}

class _SimulatedMapPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paintBg = Paint()..color = const Color(0xFFF3F4F6);
    canvas.drawRect(Rect.fromLTWH(0, 0, size.width, size.height), paintBg);

    final paintRoad = Paint()
      ..color = Colors.white
      ..strokeWidth = 6
      ..style = PaintingStyle.stroke;

    final paintRiver = Paint()
      ..color = const Color(0xFFE0F2FE)
      ..strokeWidth = 12
      ..style = PaintingStyle.stroke;

    canvas.drawLine(const Offset(0, 40), Offset(size.width, 60), paintRoad);
    canvas.drawLine(const Offset(80, 0), Offset(100, size.height), paintRoad);
    canvas.drawLine(Offset(0, size.height * 0.7), Offset(size.width, size.height * 0.6), paintRoad);

    final riverPath = Path()
      ..moveTo(0, size.height * 0.2)
      ..quadraticBezierTo(size.width * 0.4, size.height * 0.1, size.width * 0.6, size.height * 0.8)
      ..lineTo(size.width, size.height * 0.9);
    canvas.drawPath(riverPath, paintRiver);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class AnimatedCheckmark extends StatefulWidget {
  final double size;
  const AnimatedCheckmark({Key? key, this.size = 90}) : super(key: key);

  @override
  State<AnimatedCheckmark> createState() => _AnimatedCheckmarkState();
}

class _AnimatedCheckmarkState extends State<AnimatedCheckmark> with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _circleScale;
  late Animation<double> _checkProgress;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1000),
    );

    _circleScale = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _controller,
        curve: const Interval(0.0, 0.4, curve: Curves.easeOutBack),
      ),
    );

    _checkProgress = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _controller,
        curve: const Interval(0.4, 1.0, curve: Curves.easeInOut),
      ),
    );

    _controller.forward();
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
        return Stack(
          alignment: Alignment.center,
          children: [
            // Outer light green circle
            Transform.scale(
              scale: _circleScale.value,
              child: Container(
                width: widget.size,
                height: widget.size,
                decoration: const BoxDecoration(
                  color: Color(0xFFD1FAE5),
                  shape: BoxShape.circle,
                ),
              ),
            ),
            // Inner green circle
            Transform.scale(
              scale: _circleScale.value,
              child: Container(
                width: widget.size * (70 / 90),
                height: widget.size * (70 / 90),
                decoration: const BoxDecoration(
                  color: Color(0xFF10B981),
                  shape: BoxShape.circle,
                ),
                alignment: Alignment.center,
                child: CustomPaint(
                  size: Size(widget.size * (40 / 90), widget.size * (40 / 90)),
                  painter: _CheckmarkPainter(_checkProgress.value),
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}

class _CheckmarkPainter extends CustomPainter {
  final double progress;
  _CheckmarkPainter(this.progress);

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.stroke
      ..strokeWidth = size.width * 0.15
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;

    final path = Path();
    
    // Starting point
    final startX = size.width * 0.22;
    final startY = size.height * 0.52;
    
    // Mid point (vertex of the tick)
    final midX = size.width * 0.44;
    final midY = size.height * 0.72;
    
    // End point
    final endX = size.width * 0.78;
    final endY = size.height * 0.32;

    path.moveTo(startX, startY);
    path.lineTo(midX, midY);
    path.lineTo(endX, endY);

    final pathMetrics = path.computeMetrics().toList();
    if (pathMetrics.isNotEmpty) {
      final metric = pathMetrics.first;
      final extractPath = metric.extractPath(0.0, metric.length * progress);
      canvas.drawPath(extractPath, paint);
    }
  }

  @override
  bool shouldRepaint(covariant _CheckmarkPainter oldDelegate) {
    return oldDelegate.progress != progress;
  }
}
