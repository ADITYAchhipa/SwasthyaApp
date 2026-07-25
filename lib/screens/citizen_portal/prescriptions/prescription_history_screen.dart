import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../providers/swasthya_tap_provider.dart';
import '../../../models/models.dart';
import '../../../theme/app_theme.dart';
import 'prescription_details_screen.dart';

class PrescriptionHistoryScreen extends StatelessWidget {
  const PrescriptionHistoryScreen({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final provider = Provider.of<SwasthyaTapProvider>(context);
    final prescriptions = provider.prescriptions;

    // Hardcoded grouped month-year timeline elements matching user screenshot mockups
    final List<Map<String, dynamic>> timelineData = [
      {
        'year': '2026',
        'month': 'Jul',
        'rx': prescriptions.isNotEmpty ? prescriptions[0] : null,
      },
      {
        'year': '2026',
        'month': 'Jul',
        'rx': prescriptions.length > 1 ? prescriptions[1] : null,
      },
      {
        'year': '2026',
        'month': 'Jun',
        'rx': prescriptions.length > 2 ? prescriptions[2] : null,
      },
      {
        'year': '2026',
        'month': 'Jun',
        'rx': prescriptions.length > 3 ? prescriptions[3] : null,
      },
      {
        'year': '2026',
        'month': 'May',
        'rx': prescriptions.length > 4 ? prescriptions[4] : null,
      },
    ];

    // Filter out null prescriptions
    final validTimeline = timelineData.where((item) => item['rx'] != null).toList();

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        elevation: 0,
        backgroundColor: Colors.white,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded, color: AppTheme.textPrimary),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          'Prescription Timeline',
          style: GoogleFonts.poppins(fontWeight: FontWeight.bold, fontSize: 16, color: AppTheme.textPrimary),
        ),
      ),
      body: validTimeline.isEmpty
          ? _buildEmptyState()
          : ListView.builder(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
              itemCount: validTimeline.length,
              itemBuilder: (context, index) {
                final item = validTimeline[index];
                final Prescription rx = item['rx'] as Prescription;
                final String month = item['month'] as String;
                final String year = item['year'] as String;

                // Determine if we should show a year header
                bool showYearHeader = index == 0 || validTimeline[index - 1]['year'] != year;

                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (showYearHeader) ...[
                      Padding(
                        padding: const EdgeInsets.only(top: 8.0, bottom: 16.0),
                        child: Text(
                          year,
                          style: GoogleFonts.poppins(fontSize: 18, fontWeight: FontWeight.bold, color: AppTheme.textPrimary),
                        ),
                      ),
                    ],
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Left Column: Month badge
                        SizedBox(
                          width: 40,
                          child: Column(
                            children: [
                              Text(
                                month,
                                style: GoogleFonts.poppins(
                                  fontSize: 13.5,
                                  fontWeight: FontWeight.bold,
                                  color: rx.status == 'Active' ? AppTheme.accentTeal : AppTheme.textSecondary,
                                ),
                              ),
                              const SizedBox(height: 4),
                              // Vertical connecting line
                              Container(
                                width: 2,
                                height: 110,
                                color: AppTheme.borderColor,
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 12),

                        // Right Column: Timeline Card
                        Expanded(
                          child: GestureDetector(
                            onTap: () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (_) => PrescriptionDetailsScreen(prescriptionId: rx.id),
                                ),
                              );
                            },
                            child: Container(
                              margin: const EdgeInsets.only(bottom: 24),
                              padding: const EdgeInsets.all(16),
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(16),
                                border: Border.all(color: AppTheme.borderColor),
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.black.withOpacity(0.01),
                                    blurRadius: 10,
                                    offset: const Offset(0, 4),
                                  ),
                                ],
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                    children: [
                                      Expanded(
                                        child: Text(
                                          rx.doctorName,
                                          style: GoogleFonts.poppins(fontSize: 13, fontWeight: FontWeight.bold, color: AppTheme.textPrimary),
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      ),
                                      _buildStatusBadge(rx.status),
                                    ],
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    rx.hospitalName,
                                    style: GoogleFonts.poppins(fontSize: 11, color: AppTheme.textSecondary),
                                  ),
                                  const SizedBox(height: 12),
                                  Row(
                                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                    children: [
                                      Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            'Diagnosis',
                                            style: GoogleFonts.poppins(fontSize: 9.5, color: AppTheme.textSecondary),
                                          ),
                                          Text(
                                            rx.diagnosis,
                                            style: GoogleFonts.poppins(fontSize: 12, fontWeight: FontWeight.bold, color: AppTheme.textPrimary),
                                          ),
                                        ],
                                      ),
                                      Column(
                                        crossAxisAlignment: CrossAxisAlignment.end,
                                        children: [
                                          Text(
                                            'Medicines',
                                            style: GoogleFonts.poppins(fontSize: 9.5, color: AppTheme.textSecondary),
                                          ),
                                          Text(
                                            '${rx.medicines.length} Medicines',
                                            style: GoogleFonts.poppins(fontSize: 12, fontWeight: FontWeight.bold, color: AppTheme.textPrimary),
                                          ),
                                        ],
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                );
              },
            ),
    );
  }

  Widget _buildStatusBadge(String status) {
    Color badgeColor = AppTheme.accentTeal;
    if (status == 'Expired') badgeColor = AppTheme.textSecondary;
    if (status == 'Completed') badgeColor = Colors.green;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: badgeColor.withOpacity(0.08),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        status,
        style: GoogleFonts.poppins(fontSize: 9, fontWeight: FontWeight.bold, color: badgeColor),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.history_toggle_off_rounded, size: 48, color: AppTheme.textSecondary),
          const SizedBox(height: 12),
          Text(
            'Timeline is empty.',
            style: GoogleFonts.poppins(fontSize: 13, color: AppTheme.textSecondary, fontWeight: FontWeight.bold),
          ),
        ],
      ),
    );
  }
}
