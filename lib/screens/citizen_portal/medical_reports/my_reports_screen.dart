import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../../../providers/swasthya_tap_provider.dart';
import '../../../models/models.dart';
import '../../../theme/app_theme.dart';
import 'filter_reports_screen.dart';
import 'report_details_screen.dart';
import 'report_categories_screen.dart';
import 'reports_timeline_screen.dart';
import 'search_reports_screen.dart';

class MyReportsScreen extends StatefulWidget {
  final Function(int)? onTabSelected;
  const MyReportsScreen({Key? key, this.onTabSelected}) : super(key: key);

  @override
  State<MyReportsScreen> createState() => _MyReportsScreenState();
}

class _MyReportsScreenState extends State<MyReportsScreen> {
  String _selectedCategory = 'All';
  String _searchQuery = '';
  Map<String, dynamic> _activeFilters = {};

  @override
  void initState() {
    super.initState();
    // Refresh reports from backend (MongoDB) so web-app-uploaded reports are shown
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final provider = Provider.of<SwasthyaTapProvider>(context, listen: false);
      provider.refreshCurrentCitizen();
    });
  }

  final List<String> _categories = [
    'All',
    'Blood Tests',
    'Radiology',
    'MRI',
    'CT Scan',
    'Prescription',
    'Discharge Summary',
    'ECG',
    'Others'
  ];

  @override
  Widget build(BuildContext context) {
    final provider = Provider.of<SwasthyaTapProvider>(context);
    List<HealthReport> reports = provider.healthReports;

    // Apply category filter
    if (_selectedCategory != 'All') {
      reports = reports.where((r) => r.category == _selectedCategory).toList();
    }

    // Apply search query
    if (_searchQuery.isNotEmpty) {
      final query = _searchQuery.toLowerCase();
      reports = reports.where((r) =>
          r.reportName.toLowerCase().contains(query) ||
          r.hospitalName.toLowerCase().contains(query) ||
          r.doctorName.toLowerCase().contains(query) ||
          r.department.toLowerCase().contains(query)).toList();
    }

    // Apply advanced filters if any
    if (_activeFilters.isNotEmpty) {
      if (_activeFilters['category'] != null && _activeFilters['category'] != 'All') {
        reports = reports.where((r) => r.category == _activeFilters['category']).toList();
      }
      if (_activeFilters['hospital'] != null && _activeFilters['hospital'] != 'All') {
        reports = reports.where((r) => r.hospitalName == _activeFilters['hospital']).toList();
      }
      if (_activeFilters['department'] != null && _activeFilters['department'] != 'All') {
        reports = reports.where((r) => r.department == _activeFilters['department']).toList();
      }
      if (_activeFilters['doctor'] != null && _activeFilters['doctor'] != 'All') {
        reports = reports.where((r) => r.doctorName == _activeFilters['doctor']).toList();
      }
      if (_activeFilters['showAbnormalOnly'] == true) {
        reports = reports.where((r) => r.isAbnormal).toList();
      }
      // Date range filter
      final dateRangeType = _activeFilters['dateRangeType'];
      if (dateRangeType != null && dateRangeType != 'All Time') {
        final now = DateTime.now();
        reports = reports.where((r) {
          // Parse report date (realistic date formatting like '12 May 2026')
          final parsedDate = _parseReportDate(r.reportDate);
          if (parsedDate == null) return true;
          
          if (dateRangeType == 'Last 7 Days') {
            return now.difference(parsedDate).inDays <= 7;
          } else if (dateRangeType == 'Last 30 Days') {
            return now.difference(parsedDate).inDays <= 30;
          } else if (dateRangeType == 'Last 3 Months') {
            return now.difference(parsedDate).inDays <= 90;
          } else if (dateRangeType == 'Last 6 Months') {
            return now.difference(parsedDate).inDays <= 180;
          } else if (dateRangeType == 'Custom Range') {
            final fromDate = _activeFilters['fromDate'] as DateTime?;
            final toDate = _activeFilters['toDate'] as DateTime?;
            if (fromDate != null && toDate != null) {
              return parsedDate.isAfter(fromDate.subtract(const Duration(days: 1))) &&
                     parsedDate.isBefore(toDate.add(const Duration(days: 1)));
            }
          }
          return true;
        }).toList();
      }

      // Sort reports
      final sortBy = _activeFilters['sortBy'] ?? 'Newest';
      if (sortBy == 'Newest') {
        reports.sort((a, b) => _parseReportDate(b.reportDate)?.compareTo(_parseReportDate(a.reportDate) ?? DateTime(2000)) ?? 0);
      } else if (sortBy == 'Oldest') {
        reports.sort((a, b) => _parseReportDate(a.reportDate)?.compareTo(_parseReportDate(b.reportDate) ?? DateTime(2000)) ?? 0);
      } else if (sortBy == 'Hospital') {
        reports.sort((a, b) => a.hospitalName.compareTo(b.hospitalName));
      } else if (sortBy == 'Report Name') {
        reports.sort((a, b) => a.reportName.compareTo(b.reportName));
      }
    } else {
      // Default sort by Newest
      reports.sort((a, b) => _parseReportDate(b.reportDate)?.compareTo(_parseReportDate(a.reportDate) ?? DateTime(2000)) ?? 0);
    }

    return Scaffold(
      backgroundColor: AppTheme.lightBg,
      appBar: AppBar(
        title: Text(
          'My Reports',
          style: GoogleFonts.poppins(fontWeight: FontWeight.bold, fontSize: 18, color: AppTheme.textPrimary),
        ),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded, color: AppTheme.textPrimary),
          onPressed: () => Navigator.pop(context),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.category_outlined, color: AppTheme.accentTeal),
            tooltip: 'Reports by Type',
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => ReportCategoriesScreen(onTabSelected: widget.onTabSelected),
                ),
              );
            },
          ),
          IconButton(
            icon: const Icon(Icons.timeline_rounded, color: AppTheme.accentTeal),
            tooltip: 'Timeline',
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => ReportsTimelineScreen(onTabSelected: widget.onTabSelected),
                ),
              );
            },
          ),
          const SizedBox(width: 8),
        ],
        elevation: 0,
        backgroundColor: Colors.white,
      ),
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 1. Search Bar
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
              child: Row(
                children: [
                  Expanded(
                    child: GestureDetector(
                      onTap: () async {
                        final result = await Navigator.push(
                          context,
                          MaterialPageRoute(builder: (_) => const SearchReportsScreen()),
                        );
                        if (result != null && result is String) {
                          setState(() {
                            _searchQuery = result;
                          });
                        }
                      },
                      child: Container(
                        height: 48,
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(color: AppTheme.borderColor),
                        ),
                        child: Row(
                          children: [
                            const Icon(Icons.search_rounded, color: AppTheme.textSecondary, size: 20),
                            const SizedBox(width: 12),
                            Text(
                              _searchQuery.isNotEmpty ? _searchQuery : 'Search reports, tests, hospitals...',
                              style: GoogleFonts.poppins(
                                color: _searchQuery.isNotEmpty ? AppTheme.textPrimary : AppTheme.textSecondary.withOpacity(0.8),
                                fontSize: 13,
                              ),
                            ),
                            if (_searchQuery.isNotEmpty) ...[
                              const Spacer(),
                              GestureDetector(
                                onTap: () {
                                  setState(() {
                                    _searchQuery = '';
                                  });
                                },
                                child: const Icon(Icons.clear_rounded, color: AppTheme.textSecondary, size: 18),
                              ),
                            ],
                          ],
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  GestureDetector(
                    onTap: () async {
                      final filters = await Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => FilterReportsScreen(initialFilters: _activeFilters),
                        ),
                      );
                      if (filters != null && filters is Map<String, dynamic>) {
                        setState(() {
                          _activeFilters = filters;
                        });
                      }
                    },
                    child: Container(
                      height: 48,
                      width: 48,
                      decoration: BoxDecoration(
                        color: _activeFilters.isNotEmpty ? AppTheme.accentTeal : Colors.white,
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(color: _activeFilters.isNotEmpty ? AppTheme.accentTeal : AppTheme.borderColor),
                      ),
                      child: Icon(
                        Icons.tune_rounded,
                        color: _activeFilters.isNotEmpty ? Colors.white : AppTheme.accentTeal,
                        size: 20,
                      ),
                    ),
                  ),
                ],
              ),
            ),

            // 2. Horizontal Filter Chips
            SizedBox(
              height: 50,
              child: ListView.builder(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                itemCount: _categories.length,
                itemBuilder: (context, index) {
                  final cat = _categories[index];
                  final isSelected = _selectedCategory == cat;
                  return Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 4),
                    child: ChoiceChip(
                      label: Text(
                        cat,
                        style: GoogleFonts.poppins(
                          fontSize: 12.5,
                          fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                          color: isSelected ? Colors.white : AppTheme.textPrimary,
                        ),
                      ),
                      selected: isSelected,
                      onSelected: (selected) {
                        setState(() {
                          _selectedCategory = cat;
                        });
                      },
                      selectedColor: AppTheme.accentTeal,
                      backgroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                        side: BorderSide(color: isSelected ? AppTheme.accentTeal : AppTheme.borderColor),
                      ),
                      elevation: 0,
                      pressElevation: 0,
                    ),
                  );
                },
              ),
            ),

            // 3. Reports count & sorting indicators
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    '${reports.length} Reports Found',
                    style: GoogleFonts.poppins(
                      fontSize: 13,
                      fontWeight: FontWeight.bold,
                      color: AppTheme.textSecondary,
                    ),
                  ),
                  if (_activeFilters.isNotEmpty)
                    TextButton.icon(
                      onPressed: () {
                        setState(() {
                          _activeFilters = {};
                        });
                      },
                      icon: const Icon(Icons.refresh_rounded, size: 14, color: AppTheme.accentRed),
                      label: Text(
                        'Reset Filters',
                        style: GoogleFonts.poppins(fontSize: 11, color: AppTheme.accentRed, fontWeight: FontWeight.bold),
                      ),
                      style: TextButton.styleFrom(padding: EdgeInsets.zero, minimumSize: Size.zero),
                    ),
                ],
              ),
            ),

            // 4. Reports List
            Expanded(
              child: reports.isEmpty
                  ? _buildEmptyState()
                  : ListView.builder(
                      padding: const EdgeInsets.fromLTRB(16, 4, 16, 16),
                      itemCount: reports.length,
                      itemBuilder: (context, index) {
                        final report = reports[index];
                        return _buildReportCard(report);
                      },
                    ),
            ),
          ],
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
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: AppTheme.accentTeal.withOpacity(0.05),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.assignment_late_outlined,
                size: 64,
                color: AppTheme.accentTeal,
              ),
            ),
            const SizedBox(height: 20),
            Text(
              'No Reports Found',
              style: GoogleFonts.poppins(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: AppTheme.textPrimary,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              'Try adjusting your search keywords or filters to find what you are looking for.',
              style: GoogleFonts.poppins(
                fontSize: 12,
                color: AppTheme.textSecondary,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    ).animate().fade();
  }

  Widget _buildReportCard(HealthReport report) {
    // Determine icon and color based on category
    IconData icon = Icons.description_rounded;
    Color iconColor = AppTheme.accentTeal;
    Color bgLight = AppTheme.accentTeal.withOpacity(0.08);

    if (report.category == 'Blood Tests') {
      icon = Icons.biotech_rounded;
      iconColor = AppTheme.accentRed;
      bgLight = AppTheme.accentRed.withOpacity(0.08);
    } else if (report.category == 'MRI') {
      icon = Icons.blur_circular_rounded;
      iconColor = Colors.purple;
      bgLight = Colors.purple.withOpacity(0.08);
    } else if (report.category == 'CT Scan') {
      icon = Icons.album_rounded;
      iconColor = Colors.blue;
      bgLight = Colors.blue.withOpacity(0.08);
    } else if (report.category == 'Radiology') {
      icon = Icons.broken_image_rounded;
      iconColor = Colors.teal;
      bgLight = Colors.teal.withOpacity(0.08);
    } else if (report.category == 'ECG') {
      icon = Icons.show_chart_rounded;
      iconColor = Colors.orange;
      bgLight = Colors.orange.withOpacity(0.08);
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppTheme.borderColor),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.015),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
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
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Row(
            children: [
              // Left: Icon Badge
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: bgLight,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(icon, color: iconColor, size: 24),
              ),
              const SizedBox(width: 14),

              // Center: Content
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            report.reportName,
                            style: GoogleFonts.poppins(
                              fontSize: 14,
                              fontWeight: FontWeight.bold,
                              color: AppTheme.textPrimary,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        if (report.isAbnormal) ...[
                          const SizedBox(width: 6),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: AppTheme.accentRed.withOpacity(0.1),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(
                              'Abnormal',
                              style: GoogleFonts.poppins(
                                fontSize: 9,
                                fontWeight: FontWeight.bold,
                                color: AppTheme.accentRed,
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                    const SizedBox(height: 3),
                    Text(
                      report.hospitalName,
                      style: GoogleFonts.poppins(
                        fontSize: 11.5,
                        color: AppTheme.textSecondary,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Row(
                      children: [
                        Text(
                          report.doctorName,
                          style: GoogleFonts.poppins(
                            fontSize: 10.5,
                            color: AppTheme.textSecondary.withOpacity(0.8),
                          ),
                        ),
                        const SizedBox(width: 6),
                        Container(
                          width: 3,
                          height: 3,
                          decoration: BoxDecoration(
                            color: AppTheme.textSecondary.withOpacity(0.5),
                            shape: BoxShape.circle,
                          ),
                        ),
                        const SizedBox(width: 6),
                        Text(
                          report.reportDate,
                          style: GoogleFonts.poppins(
                            fontSize: 10.5,
                            color: AppTheme.textSecondary.withOpacity(0.8),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),

              // Right: PDF tag & Chevron
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: AppTheme.accentRed.withOpacity(0.08),
                      borderRadius: BorderRadius.circular(4),
                      border: Border.all(color: AppTheme.accentRed.withOpacity(0.15)),
                    ),
                    child: Text(
                      report.fileType,
                      style: GoogleFonts.poppins(
                        fontSize: 9,
                        fontWeight: FontWeight.bold,
                        color: AppTheme.accentRed,
                      ),
                    ),
                  ),
                  const SizedBox(width: 6),
                  const Icon(
                    Icons.chevron_right_rounded,
                    color: AppTheme.textSecondary,
                    size: 18,
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    ).animate().fade().slideY(begin: 0.05, duration: 250.ms);
  }

  // Parse report dates like '12 May 2026' into DateTime
  DateTime? _parseReportDate(String dateStr) {
    try {
      final parts = dateStr.split(' ');
      if (parts.length < 3) return null;
      final day = int.tryParse(parts[0]) ?? 1;
      final monthStr = parts[1].toLowerCase();
      final year = int.tryParse(parts[2]) ?? 2026;

      int month = 5;
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
}
