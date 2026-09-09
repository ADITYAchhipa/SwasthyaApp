import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../../../providers/swasthya_tap_provider.dart';
import '../../../models/models.dart';
import '../../../theme/app_theme.dart';

class ReportInfoScreen extends StatefulWidget {
  final String reportId;
  final Function(int)? onTabSelected;

  const ReportInfoScreen({
    Key? key,
    required this.reportId,
    this.onTabSelected,
  }) : super(key: key);

  @override
  State<ReportInfoScreen> createState() => _ReportInfoScreenState();
}

class _ReportInfoScreenState extends State<ReportInfoScreen> {
  bool _reminderEnabled = false;

  @override
  Widget build(BuildContext context) {
    final provider = Provider.of<SwasthyaTapProvider>(context);
    
    HealthReport? report;
    try {
      report = provider.healthReports.firstWhere((r) => r.id == widget.reportId);
    } catch (_) {
      report = null;
    }

    if (report == null) {
      return Scaffold(
        appBar: AppBar(),
        body: const Center(child: Text('Report not found.')),
      );
    }

    return Scaffold(
      backgroundColor: AppTheme.lightBg,
      appBar: AppBar(
        title: Text(
          'More Options',
          style: GoogleFonts.poppins(fontWeight: FontWeight.bold, fontSize: 18, color: AppTheme.textPrimary),
        ),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded, color: AppTheme.textPrimary),
          onPressed: () => Navigator.pop(context),
        ),
        elevation: 0,
        backgroundColor: Colors.white,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 1. Hospital Information Section
            _buildSectionHeader('Hospital Information'),
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: AppTheme.borderColor),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Icon(Icons.local_hospital_rounded, color: AppTheme.accentTeal, size: 20),
                      const SizedBox(width: 10),
                      Text(
                        report.hospitalName,
                        style: GoogleFonts.poppins(fontSize: 14, fontWeight: FontWeight.bold, color: AppTheme.textPrimary),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Address: 12, Richmond Road, Bangalore - 560025\nPhone: +91 80 4991 2200\nEmail: contact@citycarehospital.in',
                    style: GoogleFonts.poppins(fontSize: 12, color: AppTheme.textSecondary, height: 1.4),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),

            // 2. Doctor Information Section
            _buildSectionHeader('Doctor Information'),
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: AppTheme.borderColor),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Icon(Icons.person_rounded, color: AppTheme.accentTeal, size: 20),
                      const SizedBox(width: 10),
                      Text(
                        report.doctorName,
                        style: GoogleFonts.poppins(fontSize: 14, fontWeight: FontWeight.bold, color: AppTheme.textPrimary),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Department: ${report.department}\nSpecialization: MD, DNB in Pathology\nRegistration No: KMC-883492',
                    style: GoogleFonts.poppins(fontSize: 12, color: AppTheme.textSecondary, height: 1.4),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),

            // 3. File Details / Metadata Section
            _buildSectionHeader('File Information'),
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: AppTheme.borderColor),
              ),
              child: Column(
                children: [
                  _buildMetaRow('File Size', report.fileSize),
                  const Divider(height: 20, color: AppTheme.borderColor),
                  _buildMetaRow('Upload Date', report.reportDate),
                  const Divider(height: 20, color: AppTheme.borderColor),
                  _buildMetaRow('Version', report.version),
                  const Divider(height: 20, color: AppTheme.borderColor),
                  _buildMetaRow('File Type', report.fileType),
                ],
              ),
            ),
            const SizedBox(height: 20),

            // 4. Options List
            _buildSectionHeader('Actions'),
            const SizedBox(height: 8),
            Container(
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: AppTheme.borderColor),
              ),
              child: Column(
                children: [
                  // Mark Favourite
                  ListTile(
                    leading: Icon(
                      report.isFavorite ? Icons.favorite_rounded : Icons.favorite_border_rounded,
                      color: report.isFavorite ? AppTheme.accentRed : AppTheme.textSecondary,
                    ),
                    title: Text(
                      'Add to Favorites',
                      style: GoogleFonts.poppins(fontSize: 13.5, fontWeight: FontWeight.bold, color: AppTheme.textPrimary),
                    ),
                    trailing: Switch.adaptive(
                      value: report.isFavorite,
                      activeColor: Colors.white,
                      activeTrackColor: AppTheme.accentTeal,
                      inactiveThumbColor: Colors.white,
                      inactiveTrackColor: const Color(0xFFCBD5E1),
                      trackOutlineColor: MaterialStateProperty.all(Colors.transparent),
                      onChanged: (value) {
                        provider.toggleReportFavorite(widget.reportId);
                      },
                    ),
                  ),
                  const Divider(height: 1, color: AppTheme.borderColor),

                  // Reminders option
                  ListTile(
                    leading: const Icon(Icons.notifications_none_rounded, color: AppTheme.textSecondary),
                    title: Text(
                      'Set Reminders',
                      style: GoogleFonts.poppins(fontSize: 13.5, fontWeight: FontWeight.bold, color: AppTheme.textPrimary),
                    ),
                    subtitle: Text(
                      'Remind me to repeat this test in 2 weeks',
                      style: GoogleFonts.poppins(fontSize: 11, color: AppTheme.textSecondary),
                    ),
                    trailing: Switch.adaptive(
                      value: _reminderEnabled,
                      activeColor: Colors.white,
                      activeTrackColor: AppTheme.accentTeal,
                      inactiveThumbColor: Colors.white,
                      inactiveTrackColor: const Color(0xFFCBD5E1),
                      trackOutlineColor: MaterialStateProperty.all(Colors.transparent),
                      onChanged: (value) {
                        setState(() {
                          _reminderEnabled = value;
                        });
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text(value ? 'Reminder set for repeat test' : 'Reminder disabled'),
                            behavior: SnackBarBehavior.floating,
                          ),
                        );
                      },
                    ),
                  ),
                  const Divider(height: 1, color: AppTheme.borderColor),

                  // Track Trends
                  ListTile(
                    leading: const Icon(Icons.trending_up_rounded, color: AppTheme.textSecondary),
                    title: Text(
                      'Track Trends',
                      style: GoogleFonts.poppins(fontSize: 13.5, fontWeight: FontWeight.bold, color: AppTheme.textPrimary),
                    ),
                    subtitle: Text(
                      'View changes over time for Hemoglobin, Platelets etc.',
                      style: GoogleFonts.poppins(fontSize: 11, color: AppTheme.textSecondary),
                    ),
                    trailing: const Icon(Icons.chevron_right_rounded, color: AppTheme.textSecondary),
                    onTap: () {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('Trend analysis is coming soon!'),
                          behavior: SnackBarBehavior.floating,
                        ),
                      );
                    },
                  ),
                  const Divider(height: 1, color: AppTheme.borderColor),

                  // Export PDF
                  ListTile(
                    leading: const Icon(Icons.print_outlined, color: AppTheme.textSecondary),
                    title: Text(
                      'Export Report',
                      style: GoogleFonts.poppins(fontSize: 13.5, fontWeight: FontWeight.bold, color: AppTheme.textPrimary),
                    ),
                    subtitle: Text(
                      'Save as PDF or print report',
                      style: GoogleFonts.poppins(fontSize: 11, color: AppTheme.textSecondary),
                    ),
                    trailing: const Icon(Icons.chevron_right_rounded, color: AppTheme.textSecondary),
                    onTap: () {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('Exporting report as PDF...'),
                          behavior: SnackBarBehavior.floating,
                        ),
                      );
                    },
                  ),
                  const Divider(height: 1, color: AppTheme.borderColor),

                  // Delete from personal account
                  ListTile(
                    leading: const Icon(Icons.delete_outline_rounded, color: AppTheme.accentRed),
                    title: Text(
                      'Delete Report',
                      style: GoogleFonts.poppins(fontSize: 13.5, fontWeight: FontWeight.bold, color: AppTheme.accentRed),
                    ),
                    subtitle: Text(
                      'Remove from personal records',
                      style: GoogleFonts.poppins(fontSize: 11, color: AppTheme.accentRed.withOpacity(0.8)),
                    ),
                    trailing: const Icon(Icons.chevron_right_rounded, color: AppTheme.accentRed),
                    onTap: () {
                      _showDeleteConfirmationDialog(context, provider, report!);
                    },
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSectionHeader(String title) {
    return Padding(
      padding: const EdgeInsets.only(left: 4),
      child: Text(
        title,
        style: GoogleFonts.poppins(
          fontSize: 14,
          fontWeight: FontWeight.bold,
          color: AppTheme.textPrimary,
        ),
      ),
    );
  }

  Widget _buildMetaRow(String label, String value) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: GoogleFonts.poppins(fontSize: 12.5, color: AppTheme.textSecondary, fontWeight: FontWeight.w500),
        ),
        Text(
          value,
          style: GoogleFonts.poppins(fontSize: 13, color: AppTheme.textPrimary, fontWeight: FontWeight.bold),
        ),
      ],
    );
  }

  void _showDeleteConfirmationDialog(BuildContext context, SwasthyaTapProvider provider, HealthReport report) {
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: Text(
            'Delete Report?',
            style: GoogleFonts.poppins(fontWeight: FontWeight.bold, fontSize: 16),
          ),
          content: Text(
            'Are you sure you want to delete "${report.reportName}"? This action will remove it from your personal account and cannot be undone.',
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
                // Delete report
                provider.deleteReport(report.id);
                // Pop dialog
                Navigator.pop(context);
                // Pop report details / info screen
                Navigator.pop(context);
                Navigator.pop(context);
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text('"${report.reportName}" deleted successfully.'),
                    backgroundColor: AppTheme.accentRed,
                    behavior: SnackBarBehavior.floating,
                  ),
                );
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.accentRed,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              ),
              child: Text(
                'Delete',
                style: GoogleFonts.poppins(fontWeight: FontWeight.bold, color: Colors.white),
              ),
            ),
          ],
        );
      },
    );
  }
}
