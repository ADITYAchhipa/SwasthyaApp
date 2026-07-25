import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../providers/swasthya_tap_provider.dart';
import '../../../models/models.dart';
import '../../../theme/app_theme.dart';
import 'report_details_screen.dart';

class ReportsTimelineScreen extends StatefulWidget {
  final Function(int)? onTabSelected;
  const ReportsTimelineScreen({Key? key, this.onTabSelected}) : super(key: key);

  @override
  State<ReportsTimelineScreen> createState() => _ReportsTimelineScreenState();
}

class _ReportsTimelineScreenState extends State<ReportsTimelineScreen> {
  @override
  Widget build(BuildContext context) {
    final provider = Provider.of<SwasthyaTapProvider>(context);
    final reports = List<HealthReport>.from(provider.healthReports);

    // Sort reports by date (Newest first)
    reports.sort((a, b) => _parseReportDate(b.reportDate)?.compareTo(_parseReportDate(a.reportDate) ?? DateTime(2000)) ?? 0);

    // Group reports by Year and Month
    final Map<String, Map<String, List<HealthReport>>> groupedReports = {};
    for (var r in reports) {
      final parsedDate = _parseReportDate(r.reportDate) ?? DateTime.now();
      final yearStr = parsedDate.year.toString();
      final monthStr = _getMonthName(parsedDate.month);

      if (!groupedReports.containsKey(yearStr)) {
        groupedReports[yearStr] = {};
      }
      if (!groupedReports[yearStr]!.containsKey(monthStr)) {
        groupedReports[yearStr]![monthStr] = [];
      }
      groupedReports[yearStr]![monthStr]!.add(r);
    }

    return Scaffold(
      backgroundColor: AppTheme.lightBg,
      appBar: AppBar(
        title: Text(
          'Reports Timeline',
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
        child: reports.isEmpty
            ? _buildEmptyState()
            : ListView.builder(
                padding: const EdgeInsets.fromLTRB(16, 20, 16, 16),
                itemCount: groupedReports.length,
                itemBuilder: (context, yearIndex) {
                  final year = groupedReports.keys.elementAt(yearIndex);
                  final monthsMap = groupedReports[year]!;

                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Year header
                      Padding(
                        padding: const EdgeInsets.only(left: 8, bottom: 12),
                        child: Text(
                          year,
                          style: GoogleFonts.poppins(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: AppTheme.accentTeal,
                          ),
                        ),
                      ),
                      ...monthsMap.keys.map((month) {
                        final monthReports = monthsMap[month]!;
                        return _buildMonthTimeline(month, monthReports);
                      }).toList(),
                      const SizedBox(height: 16),
                    ],
                  );
                },
              ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.timeline_rounded, size: 64, color: AppTheme.textSecondary),
            const SizedBox(height: 16),
            Text(
              'No reports available for timeline.',
              style: GoogleFonts.poppins(fontSize: 14, fontWeight: FontWeight.bold, color: AppTheme.textPrimary),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMonthTimeline(String month, List<HealthReport> monthReports) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Month Column (Left)
        SizedBox(
          width: 55,
          child: Padding(
            padding: const EdgeInsets.only(top: 14),
            child: Text(
              month,
              style: GoogleFonts.poppins(
                fontSize: 13,
                fontWeight: FontWeight.bold,
                color: AppTheme.textSecondary,
              ),
              textAlign: TextAlign.end,
            ),
          ),
        ),
        const SizedBox(width: 14),

        // Timeline separator + cards (Right)
        Expanded(
          child: Column(
            children: List.generate(monthReports.length, (index) {
              final r = monthReports[index];
              return Stack(
                children: [
                  // Vertical Line
                  Positioned(
                    top: 0,
                    bottom: 0,
                    left: 15,
                    child: Container(
                      width: 2,
                      color: AppTheme.borderColor,
                    ),
                  ),

                  // Node Circle
                  Positioned(
                    top: 18,
                    left: 7,
                    child: Container(
                      width: 18,
                      height: 18,
                      decoration: BoxDecoration(
                        color: Colors.white,
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: r.isAbnormal ? AppTheme.accentRed : AppTheme.accentTeal,
                          width: 3.5,
                        ),
                      ),
                    ),
                  ),

                  // Report Card Content
                  Padding(
                    padding: const EdgeInsets.only(left: 36, bottom: 16),
                    child: Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: AppTheme.borderColor),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.01),
                            blurRadius: 4,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                      child: InkWell(
                        onTap: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => ReportDetailsScreen(
                                reportId: r.id,
                                onTabSelected: widget.onTabSelected,
                              ),
                            ),
                          );
                        },
                        child: Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(6),
                              decoration: BoxDecoration(
                                color: (r.category == 'Blood Tests' ? AppTheme.accentRed : AppTheme.accentTeal).withOpacity(0.08),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Icon(
                                r.category == 'Blood Tests' ? Icons.biotech_rounded : Icons.description_rounded,
                                color: r.category == 'Blood Tests' ? AppTheme.accentRed : AppTheme.accentTeal,
                                size: 16,
                              ),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    r.reportName,
                                    style: GoogleFonts.poppins(
                                      fontSize: 12.5,
                                      fontWeight: FontWeight.bold,
                                      color: AppTheme.textPrimary,
                                    ),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    r.reportDate,
                                    style: GoogleFonts.poppins(fontSize: 10, color: AppTheme.textSecondary),
                                  ),
                                ],
                              ),
                            ),
                            const Icon(Icons.chevron_right_rounded, color: AppTheme.textSecondary, size: 16),
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
              );
            }),
          ),
        ),
      ],
    );
  }

  // Parse report dates like '12 May 2026' into DateTime
  DateTime? _parseReportDate(String dateStr) {
    try {
      final parts = dateStr.split(' ');
      if (parts.length < 3) return null;
      final day = int.tryParse(parts[0]) ?? 1;
      final monthStr = parts[1].toLowerCase();
      final year = int.tryParse(parts[2]) ?? 2026;

      int month = 1;
      if (monthStr.startsWith('jan')) month = 1;
      else if (monthStr.startsWith('feb')) month = 2;
      else if (monthStr.startsWith('mar')) month = 3;
      else if (monthStr.startsWith('apr')) month = 4;
      else if (monthStr.startsWith('may')) month = 5;
      else if (monthStr.startsWith('jun')) month = 6;
      else if (monthStr.startsWith('jul')) month = 7;
      else if (monthStr.startsWith('aug')) month = 8;
      else if (monthStr.startsWith('sep')) month = 9;
      else if (monthStr.startsWith('oct')) month = 10;
      else if (monthStr.startsWith('nov')) month = 11;
      else if (monthStr.startsWith('dec')) month = 12;

      return DateTime(year, month, day);
    } catch (_) {
      return null;
    }
  }

  String _getMonthName(int month) {
    switch (month) {
      case 1: return 'Jan';
      case 2: return 'Feb';
      case 3: return 'Mar';
      case 4: return 'Apr';
      case 5: return 'May';
      case 6: return 'June';
      case 7: return 'July';
      case 8: return 'Aug';
      case 9: return 'Sept';
      case 10: return 'Oct';
      case 11: return 'Nov';
      case 12: return 'Dec';
      default: return 'May';
    }
  }
}
