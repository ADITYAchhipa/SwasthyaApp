import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../../../providers/swasthya_tap_provider.dart';
import '../../../models/models.dart';
import '../../../theme/app_theme.dart';
import 'my_reports_screen.dart';
import 'report_details_screen.dart';

class ReportCategoriesScreen extends StatefulWidget {
  final Function(int)? onTabSelected;
  const ReportCategoriesScreen({Key? key, this.onTabSelected}) : super(key: key);

  @override
  State<ReportCategoriesScreen> createState() => _ReportCategoriesScreenState();
}

class _ReportCategoriesScreenState extends State<ReportCategoriesScreen> {
  @override
  Widget build(BuildContext context) {
    final provider = Provider.of<SwasthyaTapProvider>(context);
    final reports = provider.healthReports;

    // Helper to count category reports
    int countCategory(String category) {
      return reports.where((r) => r.category == category).length;
    }

    final categories = [
      {
        'title': 'Blood Tests',
        'icon': Icons.biotech_rounded,
        'color': AppTheme.accentRed,
        'count': countCategory('Blood Tests'),
      },
      {
        'title': 'Radiology',
        'icon': Icons.broken_image_rounded,
        'color': Colors.teal,
        'count': countCategory('Radiology'),
      },
      {
        'title': 'Prescriptions',
        'icon': Icons.description_rounded,
        'color': Colors.indigo,
        'count': countCategory('Prescription'),
      },
      {
        'title': 'MRI',
        'icon': Icons.blur_circular_rounded,
        'color': Colors.purple,
        'count': countCategory('MRI'),
      },
      {
        'title': 'CT Scan',
        'icon': Icons.album_rounded,
        'color': Colors.blue,
        'count': countCategory('CT Scan'),
      },
      {
        'title': 'Discharge Summary',
        'icon': Icons.assignment_turned_in_rounded,
        'color': Colors.green,
        'count': countCategory('Discharge Summary'),
      },
      {
        'title': 'Others',
        'icon': Icons.folder_open_rounded,
        'color': Colors.orange,
        'count': countCategory('Others'),
      },
    ];

    // Filter recent lab reports
    final recentLabReports = reports
        .where((r) => r.category == 'Blood Tests')
        .take(3)
        .toList();

    return Scaffold(
      backgroundColor: AppTheme.lightBg,
      appBar: AppBar(
        title: Text(
          'Reports by Type',
          style: GoogleFonts.poppins(fontWeight: FontWeight.bold, fontSize: 18, color: AppTheme.textPrimary),
        ),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded, color: AppTheme.textPrimary),
          onPressed: () => Navigator.pop(context),
        ),
        elevation: 0,
        backgroundColor: Colors.white,
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // 1. Grid of categories
              GridView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 2,
                  crossAxisSpacing: 16,
                  mainAxisSpacing: 16,
                  childAspectRatio: 1.45,
                ),
                itemCount: categories.length,
                itemBuilder: (context, index) {
                  final cat = categories[index];
                  final title = cat['title'] as String;
                  final icon = cat['icon'] as IconData;
                  final color = cat['color'] as Color;
                  final count = cat['count'] as int;

                  return _buildCategoryCard(title, icon, color, count);
                },
              ),
              const SizedBox(height: 28),

              // 2. Recent Lab Reports section
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Recent Lab Reports',
                    style: GoogleFonts.poppins(
                      fontSize: 15,
                      fontWeight: FontWeight.bold,
                      color: AppTheme.textPrimary,
                    ),
                  ),
                  TextButton(
                    onPressed: () {
                      // Jump to My Reports with Blood Tests selected
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => MyReportsScreen(onTabSelected: widget.onTabSelected),
                        ),
                      );
                    },
                    child: Text(
                      'View All',
                      style: GoogleFonts.poppins(fontSize: 12, fontWeight: FontWeight.bold, color: AppTheme.accentTeal),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              ...recentLabReports.map((report) => _buildRecentReportCard(report)).toList(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildCategoryCard(String title, IconData icon, Color color, int count) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppTheme.borderColor),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.01),
            blurRadius: 8,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: InkWell(
        onTap: () {
          // Go to reports filtered by category
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => MyReportsScreen(onTabSelected: widget.onTabSelected),
            ),
          );
        },
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: color.withOpacity(0.08),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(icon, color: color, size: 22),
              ),
              const Spacer(),
              Text(
                title,
                style: GoogleFonts.poppins(
                  fontSize: 13,
                  fontWeight: FontWeight.bold,
                  color: AppTheme.textPrimary,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 2),
              Text(
                '$count Reports',
                style: GoogleFonts.poppins(
                  fontSize: 11,
                  color: AppTheme.textSecondary,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
      ),
    ).animate().fade().scale(duration: 200.ms);
  }

  Widget _buildRecentReportCard(HealthReport report) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppTheme.borderColor),
      ),
      child: InkWell(
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => ReportDetailsScreen(
                reportId: report.id,
                onTabSelected: widget.onTabSelected,
              ),
            ),
          );
        },
        borderRadius: BorderRadius.circular(14),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          child: Row(
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: AppTheme.accentRed.withOpacity(0.08),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(Icons.biotech_rounded, color: AppTheme.accentRed, size: 18),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      report.reportName,
                      style: GoogleFonts.poppins(
                        fontSize: 13,
                        fontWeight: FontWeight.bold,
                        color: AppTheme.textPrimary,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 2),
                    Text(
                      report.reportDate,
                      style: GoogleFonts.poppins(fontSize: 10.5, color: AppTheme.textSecondary),
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: AppTheme.accentRed.withOpacity(0.08),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(
                  report.fileType,
                  style: GoogleFonts.poppins(
                    fontSize: 8.5,
                    fontWeight: FontWeight.bold,
                    color: AppTheme.accentRed,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              const Icon(Icons.chevron_right_rounded, color: AppTheme.textSecondary, size: 16),
            ],
          ),
        ),
      ),
    );
  }
}
