import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../../../providers/swasthya_tap_provider.dart';
import '../../../models/models.dart';
import '../../../theme/app_theme.dart';
import 'prescription_details_screen.dart';
import 'prescription_share_screen.dart';
import 'prescription_history_screen.dart';
import 'medicine_schedule_screen.dart';

class PrescriptionsDashboardScreen extends StatefulWidget {
  final Function(int)? onTabSelected;
  const PrescriptionsDashboardScreen({Key? key, this.onTabSelected}) : super(key: key);

  @override
  State<PrescriptionsDashboardScreen> createState() => _PrescriptionsDashboardScreenState();
}

class _PrescriptionsDashboardScreenState extends State<PrescriptionsDashboardScreen> {
  String _searchQuery = '';
  String _selectedFilter = 'All'; // 'All', 'Active', 'Completed', 'Expired', 'Draft'
  bool _isSearching = false;
  final TextEditingController _searchController = TextEditingController();

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final provider = Provider.of<SwasthyaTapProvider>(context);
    final allPrescriptions = provider.prescriptions;

    // Filter prescriptions
    final filteredPrescriptions = allPrescriptions.where((p) {
      final matchesSearch = p.doctorName.toLowerCase().contains(_searchQuery.toLowerCase()) ||
          p.hospitalName.toLowerCase().contains(_searchQuery.toLowerCase()) ||
          p.diagnosis.toLowerCase().contains(_searchQuery.toLowerCase()) ||
          p.medicines.any((m) => m.name.toLowerCase().contains(_searchQuery.toLowerCase()));

      final matchesFilter = _selectedFilter == 'All' || p.status == _selectedFilter;

      return matchesSearch && matchesFilter;
    }).toList();

    // Summary stats
    final activeCount = allPrescriptions.where((p) => p.status == 'Active').length;
    final totalCount = allPrescriptions.length;
    final medicinesToday = allPrescriptions
        .where((p) => p.status == 'Active')
        .fold<int>(0, (sum, p) => sum + p.medicines.length);

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded, color: AppTheme.textPrimary),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          'My Prescriptions',
          style: GoogleFonts.poppins(fontWeight: FontWeight.bold, fontSize: 18, color: AppTheme.textPrimary),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.history_rounded, color: AppTheme.textPrimary),
            tooltip: 'Timeline History',
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const PrescriptionHistoryScreen()),
              );
            },
          ),
          IconButton(
            icon: const Icon(Icons.qr_code_scanner_rounded, color: AppTheme.textPrimary),
            tooltip: 'Scan Prescription QR',
            onPressed: () => _showScanMockDialog(),
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Greeting & Search Toggle
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Hi Rajesh 👋',
                        style: GoogleFonts.poppins(fontSize: 20, fontWeight: FontWeight.bold, color: AppTheme.textPrimary),
                      ),
                      Text(
                        'Stay healthy, Stay safe',
                        style: GoogleFonts.poppins(fontSize: 12.5, color: AppTheme.textSecondary),
                      ),
                    ],
                  ),
                  IconButton(
                    icon: Icon(_isSearching ? Icons.close_rounded : Icons.search_rounded, color: AppTheme.accentTeal),
                    onPressed: () {
                      setState(() {
                        _isSearching = !_isSearching;
                        if (!_isSearching) {
                          _searchQuery = '';
                          _searchController.clear();
                        }
                      });
                    },
                  ),
                ],
              ),
              const SizedBox(height: 16),

              // Animated Search Bar
              if (_isSearching)
                Container(
                  height: 48,
                  margin: const EdgeInsets.only(bottom: 16),
                  decoration: BoxDecoration(
                    color: AppTheme.lightBg,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: AppTheme.borderColor),
                  ),
                  child: TextField(
                    controller: _searchController,
                    style: GoogleFonts.poppins(fontSize: 13.5, color: AppTheme.textPrimary),
                    onChanged: (val) {
                      setState(() {
                        _searchQuery = val;
                      });
                    },
                    decoration: InputDecoration(
                      hintText: 'Search doctor, medicine or diagnosis...',
                      hintStyle: GoogleFonts.poppins(fontSize: 12.5, color: AppTheme.textSecondary.withOpacity(0.7)),
                      border: InputBorder.none,
                      prefixIcon: const Icon(Icons.search_rounded, color: AppTheme.textSecondary, size: 18),
                      contentPadding: const EdgeInsets.symmetric(vertical: 12),
                    ),
                  ),
                ).animate().fadeIn(duration: 200.ms).slideY(begin: -0.1, end: 0),

              // Dashboard Summary Card (Glassmorphism + soft teal gradient)
              if (!_isSearching && _selectedFilter == 'All')
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [Color(0xFF0F8B8D), Color(0xFF14B8A6)],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.circular(20),
                    boxShadow: [
                      BoxShadow(
                        color: const Color(0xFF0F8B8D).withOpacity(0.2),
                        blurRadius: 15,
                        offset: const Offset(0, 8),
                      ),
                    ],
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            'Prescription Summary',
                            style: GoogleFonts.poppins(fontSize: 14, fontWeight: FontWeight.w600, color: Colors.white.withOpacity(0.9)),
                          ),
                          const Icon(Icons.assignment_turned_in_rounded, color: Colors.white, size: 20),
                        ],
                      ),
                      const SizedBox(height: 16),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          _buildStatItem('Active', '$activeCount'),
                          _buildStatItem('Total', '$totalCount'),
                          _buildStatItem('Daily Meds', '$medicinesToday'),
                          _buildStatItem('Next Visit', '27 Jul'),
                        ],
                      ),
                    ],
                  ),
                ).animate().scale(delay: 50.ms, duration: 250.ms),

              const SizedBox(height: 20),

              // Filter horizontal chips
              SizedBox(
                height: 38,
                child: ListView(
                  scrollDirection: Axis.horizontal,
                  children: ['All', 'Active', 'Completed', 'Expired'].map((filter) {
                    final isSelected = _selectedFilter == filter;
                    return Padding(
                      padding: const EdgeInsets.only(right: 8),
                      child: ChoiceChip(
                        label: Text(
                          filter,
                          style: GoogleFonts.poppins(
                            fontSize: 12,
                            fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                            color: isSelected ? Colors.white : AppTheme.textSecondary,
                          ),
                        ),
                        selected: isSelected,
                        selectedColor: AppTheme.accentTeal,
                        backgroundColor: AppTheme.lightBg,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                        onSelected: (selected) {
                          setState(() {
                            _selectedFilter = filter;
                          });
                        },
                      ),
                    );
                  }).toList(),
                ),
              ),

              const SizedBox(height: 16),

              // Section Title
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    _selectedFilter == 'All' ? 'Recent Prescriptions' : '$_selectedFilter Prescriptions',
                    style: GoogleFonts.poppins(fontSize: 14, fontWeight: FontWeight.bold, color: AppTheme.textPrimary),
                  ),
                  if (allPrescriptions.length > 3 && _selectedFilter == 'All')
                    GestureDetector(
                      onTap: () {
                        setState(() {
                          _selectedFilter = 'Active';
                        });
                      },
                      child: Text(
                        'View All',
                        style: GoogleFonts.poppins(fontSize: 12, fontWeight: FontWeight.bold, color: AppTheme.accentTeal),
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 12),

              // Prescription Cards
              filteredPrescriptions.isEmpty
                  ? _buildEmptyState()
                  : ListView.separated(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      itemCount: filteredPrescriptions.length,
                      separatorBuilder: (_, __) => const SizedBox(height: 12),
                      itemBuilder: (context, index) {
                        final rx = filteredPrescriptions[index];
                        return _buildPrescriptionCard(context, rx);
                      },
                    ),

              const SizedBox(height: 24),

              // Medicine Reminder Card
              if (!_isSearching && _selectedFilter == 'All')
                _buildUpcomingReminderCard(context),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildStatItem(String label, String value) {
    return Column(
      children: [
        Text(
          value,
          style: GoogleFonts.poppins(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.white),
        ),
        const SizedBox(height: 2),
        Text(
          label,
          style: GoogleFonts.poppins(fontSize: 10.5, color: Colors.white.withOpacity(0.8), fontWeight: FontWeight.w500),
        ),
      ],
    );
  }

  Widget _buildEmptyState() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 40),
      alignment: Alignment.center,
      child: Column(
        children: [
          const Icon(Icons.assignment_late_outlined, size: 48, color: AppTheme.textSecondary),
          const SizedBox(height: 12),
          Text(
            'No matching prescriptions found.',
            style: GoogleFonts.poppins(fontSize: 13, color: AppTheme.textSecondary, fontWeight: FontWeight.w500),
          ),
        ],
      ),
    );
  }

  Widget _buildPrescriptionCard(BuildContext context, Prescription rx) {
    Color badgeColor = AppTheme.accentTeal;
    if (rx.status == 'Expired') badgeColor = AppTheme.textSecondary;
    if (rx.status == 'Completed') badgeColor = Colors.green;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppTheme.borderColor),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.015),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Doctor & Hospital Header
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Doctor photo avatar
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: AppTheme.accentTeal.withOpacity(0.08),
                  image: DecorationImage(
                    image: NetworkImage(rx.doctorPhoto),
                    fit: BoxFit.cover,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      rx.doctorName,
                      style: GoogleFonts.poppins(fontSize: 13.5, fontWeight: FontWeight.bold, color: AppTheme.textPrimary),
                    ),
                    Text(
                      rx.hospitalName,
                      style: GoogleFonts.poppins(fontSize: 11, color: AppTheme.textSecondary),
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: badgeColor.withOpacity(0.08),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  rx.status,
                  style: GoogleFonts.poppins(fontSize: 9.5, fontWeight: FontWeight.bold, color: badgeColor),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),

          // Diagnosis & Timing details
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Diagnosis',
                    style: GoogleFonts.poppins(fontSize: 10, color: AppTheme.textSecondary, fontWeight: FontWeight.w500),
                  ),
                  Text(
                    rx.diagnosis,
                    style: GoogleFonts.poppins(fontSize: 12.5, fontWeight: FontWeight.bold, color: AppTheme.textPrimary),
                  ),
                ],
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    'Prescribed On',
                    style: GoogleFonts.poppins(fontSize: 10, color: AppTheme.textSecondary, fontWeight: FontWeight.w500),
                  ),
                  Text(
                    rx.prescriptionDate,
                    style: GoogleFonts.poppins(fontSize: 12, fontWeight: FontWeight.bold, color: AppTheme.textPrimary),
                  ),
                ],
              ),
            ],
          ),

          const Divider(height: 24, color: AppTheme.borderColor),

          // Quick Action buttons
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => PrescriptionDetailsScreen(
                          prescriptionId: rx.id,
                          onTabSelected: widget.onTabSelected,
                        ),
                      ),
                    );
                  },
                  icon: const Icon(Icons.remove_red_eye_outlined, size: 14),
                  label: const Text('View'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppTheme.textPrimary,
                    side: const BorderSide(color: AppTheme.borderColor),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    textStyle: GoogleFonts.poppins(fontSize: 11, fontWeight: FontWeight.bold),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => PrescriptionDetailsScreen(
                          prescriptionId: rx.id,
                          initialOpenTranslation: true,
                          onTabSelected: widget.onTabSelected,
                        ),
                      ),
                    );
                  },
                  icon: const Icon(Icons.g_translate_rounded, size: 14),
                  label: const Text('Translate'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppTheme.accentTeal,
                    side: const BorderSide(color: AppTheme.borderColor),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    textStyle: GoogleFonts.poppins(fontSize: 11, fontWeight: FontWeight.bold),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              IconButton(
                icon: const Icon(Icons.qr_code_2_rounded, color: AppTheme.accentTeal),
                style: IconButton.styleFrom(
                  backgroundColor: AppTheme.accentTeal.withOpacity(0.08),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  padding: const EdgeInsets.all(8),
                ),
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => PrescriptionShareScreen(prescriptionId: rx.id),
                    ),
                  );
                },
              ),
            ],
          ),
        ],
      ).animate().fadeIn(duration: 200.ms).slideY(begin: 0.05, end: 0),
    );
  }

  Widget _buildUpcomingReminderCard(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'Upcoming Dose Reminder',
              style: GoogleFonts.poppins(fontSize: 14, fontWeight: FontWeight.bold, color: AppTheme.textPrimary),
            ),
            GestureDetector(
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => MedicineScheduleScreen(onTabSelected: widget.onTabSelected),
                  ),
                );
              },
              child: Text(
                'Full Schedule',
                style: GoogleFonts.poppins(fontSize: 12, fontWeight: FontWeight.bold, color: AppTheme.accentTeal),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: const Color(0xFFFFF7ED), // Soft orange background
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: const Color(0xFFFFEDD5)),
          ),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: const BoxDecoration(
                  color: Color(0xFFFFEDD5),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.notifications_active_rounded, color: Color(0xFFEA580C), size: 20),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Paracetamol 650mg',
                      style: GoogleFonts.poppins(fontSize: 13.5, fontWeight: FontWeight.bold, color: AppTheme.textPrimary),
                    ),
                    Text(
                      'After Dinner • 8:00 PM',
                      style: GoogleFonts.poppins(fontSize: 11, color: AppTheme.textSecondary),
                    ),
                  ],
                ),
              ),
              ElevatedButton(
                onPressed: () {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Dose marked as taken!'),
                      behavior: SnackBarBehavior.floating,
                    ),
                  );
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFFEA580C),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                  elevation: 0,
                ),
                child: Text(
                  'Take',
                  style: GoogleFonts.poppins(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.white),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  void _showScanMockDialog() {
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: Text(
            'Scan Prescription QR',
            style: GoogleFonts.poppins(fontWeight: FontWeight.bold, fontSize: 16),
          ),
          content: Text(
            'Simulate scanning a digital prescription QR code from the Hospital Portal?',
            style: GoogleFonts.poppins(fontSize: 13, color: AppTheme.textSecondary),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text(
                'Cancel',
                style: GoogleFonts.poppins(fontWeight: FontWeight.bold, color: AppTheme.textSecondary),
              ),
            ),
            ElevatedButton(
              onPressed: () {
                Navigator.pop(context);
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Prescription QR verified successfully! Added to your account.'),
                    backgroundColor: Colors.green,
                    behavior: SnackBarBehavior.floating,
                  ),
                );
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.accentTeal,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              ),
              child: Text(
                'Verify & Add',
                style: GoogleFonts.poppins(fontWeight: FontWeight.bold, color: Colors.white),
              ),
            ),
          ],
        );
      },
    );
  }
}
