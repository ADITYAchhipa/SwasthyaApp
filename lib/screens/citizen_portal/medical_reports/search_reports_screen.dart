import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../providers/swasthya_tap_provider.dart';
import '../../../models/models.dart';
import '../../../theme/app_theme.dart';
import 'report_details_screen.dart';

class SearchReportsScreen extends StatefulWidget {
  const SearchReportsScreen({Key? key}) : super(key: key);

  @override
  State<SearchReportsScreen> createState() => _SearchReportsScreenState();
}

class _SearchReportsScreenState extends State<SearchReportsScreen> {
  final _searchController = TextEditingController();
  final FocusNode _focusNode = FocusNode();
  
  List<String> _recentSearches = ['CBC', 'MRI Brain', 'Liver Function Test'];
  
  final List<String> _suggestedSearches = [
    'Blood Test Reports',
    'Radiology Reports',
    'MRI / CT Scan',
    'ECG Reports',
    'Thyroid Profile',
    'Urine Test Reports',
    'Sugar (HbA1c) Reports'
  ];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _focusNode.requestFocus();
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final provider = Provider.of<SwasthyaTapProvider>(context);
    final reports = provider.healthReports;
    final query = _searchController.text.trim().toLowerCase();

    // Filter results instantly
    final List<HealthReport> filteredReports = query.isEmpty
        ? []
        : reports.where((r) =>
            r.reportName.toLowerCase().contains(query) ||
            r.hospitalName.toLowerCase().contains(query) ||
            r.doctorName.toLowerCase().contains(query) ||
            r.category.toLowerCase().contains(query) ||
            r.department.toLowerCase().contains(query)).toList();

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        elevation: 0,
        backgroundColor: Colors.white,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded, color: AppTheme.textPrimary),
          onPressed: () => Navigator.pop(context),
        ),
        title: Container(
          height: 44,
          decoration: BoxDecoration(
            color: AppTheme.lightBg,
            borderRadius: BorderRadius.circular(12),
          ),
          child: TextField(
            controller: _searchController,
            focusNode: _focusNode,
            style: GoogleFonts.poppins(fontSize: 13.5, color: AppTheme.textPrimary),
            onChanged: (val) {
              setState(() {});
            },
            onSubmitted: (val) {
              if (val.trim().isNotEmpty && !_recentSearches.contains(val.trim())) {
                setState(() {
                  _recentSearches.insert(0, val.trim());
                });
              }
              Navigator.pop(context, val.trim());
            },
            decoration: InputDecoration(
              hintText: 'Search by report name, test, hospital...',
              hintStyle: GoogleFonts.poppins(fontSize: 12.5, color: AppTheme.textSecondary.withOpacity(0.7)),
              border: InputBorder.none,
              prefixIcon: const Icon(Icons.search_rounded, color: AppTheme.textSecondary, size: 18),
              suffixIcon: query.isNotEmpty
                  ? GestureDetector(
                      onTap: () {
                        setState(() {
                          _searchController.clear();
                        });
                      },
                      child: const Icon(Icons.clear_rounded, color: AppTheme.textSecondary, size: 18),
                    )
                  : null,
              contentPadding: const EdgeInsets.symmetric(vertical: 12),
            ),
          ),
        ),
      ),
      body: SafeArea(
        child: query.isEmpty
            ? SingleChildScrollView(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Recent Searches
                    if (_recentSearches.isNotEmpty) ...[
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            'Recent Searches',
                            style: GoogleFonts.poppins(fontSize: 13.5, fontWeight: FontWeight.bold, color: AppTheme.textPrimary),
                          ),
                          TextButton(
                            onPressed: () {
                              setState(() {
                                _recentSearches = [];
                              });
                            },
                            child: Text(
                              'Clear All',
                              style: GoogleFonts.poppins(fontSize: 12, color: AppTheme.textSecondary, fontWeight: FontWeight.w600),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: _recentSearches.map((search) {
                          return GestureDetector(
                            onTap: () {
                              setState(() {
                                _searchController.text = search;
                              });
                            },
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                              decoration: BoxDecoration(
                                color: AppTheme.lightBg,
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(color: AppTheme.borderColor),
                              ),
                              child: Text(
                                search,
                                style: GoogleFonts.poppins(fontSize: 12, color: AppTheme.textPrimary, fontWeight: FontWeight.w500),
                              ),
                            ),
                          );
                        }).toList(),
                      ),
                      const SizedBox(height: 24),
                    ],

                    // Suggested Searches
                    Text(
                      'Suggested Searches',
                      style: GoogleFonts.poppins(fontSize: 13.5, fontWeight: FontWeight.bold, color: AppTheme.textPrimary),
                    ),
                    const SizedBox(height: 12),
                    ListView.builder(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      itemCount: _suggestedSearches.length,
                      itemBuilder: (context, index) {
                        final suggestion = _suggestedSearches[index];
                        return ListTile(
                          contentPadding: EdgeInsets.zero,
                          leading: const Icon(Icons.search_rounded, size: 18, color: AppTheme.textSecondary),
                          title: Text(
                            suggestion,
                            style: GoogleFonts.poppins(fontSize: 13, color: AppTheme.textPrimary, fontWeight: FontWeight.w500),
                          ),
                          trailing: const Icon(Icons.north_west_rounded, size: 14, color: AppTheme.textSecondary),
                          onTap: () {
                            // Strip " Reports" or " Test Reports" to search cleaner
                            final term = suggestion.replaceAll(' Reports', '').replaceAll(' Test Reports', '');
                            setState(() {
                              _searchController.text = term;
                            });
                          },
                        );
                      },
                    ),
                  ],
                ),
              )
            : filteredReports.isEmpty
                ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(Icons.search_off_rounded, size: 48, color: AppTheme.textSecondary),
                        const SizedBox(height: 12),
                        Text(
                          'No matching reports found.',
                          style: GoogleFonts.poppins(fontSize: 13, color: AppTheme.textSecondary, fontWeight: FontWeight.w500),
                        ),
                      ],
                    ),
                  )
                : ListView.builder(
                    padding: const EdgeInsets.all(16),
                    itemCount: filteredReports.length,
                    itemBuilder: (context, index) {
                      final r = filteredReports[index];
                      return ListTile(
                        leading: Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: AppTheme.accentTeal.withOpacity(0.08),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: const Icon(Icons.description_rounded, color: AppTheme.accentTeal, size: 18),
                        ),
                        title: Text(
                          r.reportName,
                          style: GoogleFonts.poppins(fontSize: 13, fontWeight: FontWeight.bold, color: AppTheme.textPrimary),
                        ),
                        subtitle: Text(
                          '${r.hospitalName} • ${r.reportDate}',
                          style: GoogleFonts.poppins(fontSize: 11, color: AppTheme.textSecondary),
                        ),
                        trailing: const Icon(Icons.chevron_right_rounded, size: 18, color: AppTheme.textSecondary),
                        onTap: () {
                          // Save to history
                          if (!_recentSearches.contains(_searchController.text.trim())) {
                            _recentSearches.insert(0, _searchController.text.trim());
                          }
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => ReportDetailsScreen(reportId: r.id),
                            ),
                          );
                        },
                      );
                    },
                  ),
      ),
    );
  }
}
