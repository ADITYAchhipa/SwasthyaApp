import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../../../providers/swasthya_tap_provider.dart';
import '../../../models/models.dart';
import '../../../theme/app_theme.dart';
import '../../../utils/translation_service.dart';
import '../../../utils/medical_translation_service.dart';
import 'pdf_viewer_screen.dart';
import 'report_info_screen.dart';

class ReportDetailsScreen extends StatefulWidget {
  final String reportId;
  final Function(int)? onTabSelected;
  
  const ReportDetailsScreen({
    Key? key,
    required this.reportId,
    this.onTabSelected,
  }) : super(key: key);

  @override
  State<ReportDetailsScreen> createState() => _ReportDetailsScreenState();
}

class _ReportDetailsScreenState extends State<ReportDetailsScreen> {
  final _notesController = TextEditingController();
  bool _isEditingNotes = false;

  String _t(String key) => TranslationService.t(context, key);
  String _tm(String value) => MedicalTranslationService.translate(context, value);

  @override
  void dispose() {
    _notesController.dispose();
    super.dispose();
  }

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
        appBar: AppBar(
          elevation: 0,
          backgroundColor: Colors.white,
          leading: IconButton(
            icon: const Icon(Icons.arrow_back_rounded, color: AppTheme.textPrimary),
            onPressed: () => Navigator.pop(context),
          ),
        ),
        body: Center(
          child: Text(_t('report_not_found')),
        ),
      );
    }

    _notesController.text = report.notes;

    int totalParams = 23;
    int normalParams = 20;
    int highParams = 2;
    int lowParams = 1;

    if (report.category == 'MRI' || report.category == 'CT Scan' || report.category == 'Radiology') {
      totalParams = 1;
      normalParams = report.isAbnormal ? 0 : 1;
      highParams = report.isAbnormal ? 1 : 0;
      lowParams = 0;
    }

    return Scaffold(
      backgroundColor: AppTheme.lightBg,
      appBar: AppBar(
        title: Text(
          _t('report_details'),
          style: GoogleFonts.poppins(fontWeight: FontWeight.bold, fontSize: 18, color: AppTheme.textPrimary),
        ),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded, color: AppTheme.textPrimary),
          onPressed: () => Navigator.pop(context),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.more_vert_rounded, color: AppTheme.textPrimary),
            tooltip: _t('options'),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => ReportInfoScreen(
                    reportId: widget.reportId,
                    onTabSelected: widget.onTabSelected,
                  ),
                ),
              );
            },
          ),
        ],
        elevation: 0,
        backgroundColor: Colors.white,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 40),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 1. Report Header Card
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
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: report.isAbnormal 
                              ? AppTheme.accentRed.withOpacity(0.08) 
                              : AppTheme.accentTeal.withOpacity(0.08),
                          shape: BoxShape.circle,
                        ),
                        child: Icon(
                          report.category == 'Blood Tests' ? Icons.biotech_rounded : Icons.assignment_outlined, 
                          color: report.isAbnormal ? AppTheme.accentRed : AppTheme.accentTeal,
                          size: 28,
                        ),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              _tm(report.reportName),
                              style: GoogleFonts.poppins(
                                fontSize: 15.5,
                                fontWeight: FontWeight.bold,
                                color: AppTheme.textPrimary,
                              ),
                            ),
                            const SizedBox(height: 3),
                            Text(
                              report.reportDate,
                              style: GoogleFonts.poppins(
                                fontSize: 12,
                                color: AppTheme.textSecondary,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ],
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: report.isAbnormal 
                              ? AppTheme.accentRed.withOpacity(0.1) 
                              : AppTheme.accentGreen.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Text(
                          report.isAbnormal ? _t('abnormal') : _t('normal'),
                          style: GoogleFonts.poppins(
                            fontSize: 10.5,
                            fontWeight: FontWeight.bold,
                            color: report.isAbnormal ? AppTheme.accentRed : AppTheme.accentGreen,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const Divider(height: 24, color: AppTheme.borderColor),
                  Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              _t('hospital_lab_label'),
                              style: GoogleFonts.poppins(fontSize: 11, color: AppTheme.textSecondary),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              _tm(report.hospitalName),
                              style: GoogleFonts.poppins(fontSize: 12.5, fontWeight: FontWeight.bold, color: AppTheme.textPrimary),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ],
                        ),
                      ),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              _t('doctor_label'),
                              style: GoogleFonts.poppins(fontSize: 11, color: AppTheme.textSecondary),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              _tm(report.doctorName),
                              style: GoogleFonts.poppins(fontSize: 12.5, fontWeight: FontWeight.bold, color: AppTheme.textPrimary),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              _t('record_id'),
                              style: GoogleFonts.poppins(fontSize: 11, color: AppTheme.textSecondary),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              report.referenceId,
                              style: GoogleFonts.poppins(fontSize: 12.5, fontWeight: FontWeight.bold, color: AppTheme.textPrimary),
                            ),
                          ],
                        ),
                      ),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              _t('uploaded_on'),
                              style: GoogleFonts.poppins(fontSize: 11, color: AppTheme.textSecondary),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              report.reportDate,
                              style: GoogleFonts.poppins(fontSize: 12.5, fontWeight: FontWeight.bold, color: AppTheme.textPrimary),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),

            // 2. Report Files / Attachments
            Text(
              _t('report_files'),
              style: GoogleFonts.poppins(fontWeight: FontWeight.bold, fontSize: 14, color: AppTheme.textPrimary),
            ),
            const SizedBox(height: 10),
            _buildFileCard('${report.reportName.replaceAll(' ', '_')}_Report.pdf', report.fileSize, true, report),
            if (report.category == 'Blood Tests' || report.category == 'MRI' || report.category == 'CT Scan') ...[
              const SizedBox(height: 8),
              _buildFileCard('${report.reportName.replaceAll(' ', '_')}_Visual.jpg', '1.2 MB', false, report),
            ],
            const SizedBox(height: 20),

            // 3. Parameter Summary Card
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  _t('report_summary'),
                  style: GoogleFonts.poppins(fontWeight: FontWeight.bold, fontSize: 14, color: AppTheme.textPrimary),
                ),
                TextButton(
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => PdfViewerScreen(reportName: report!.reportName),
                      ),
                    );
                  },
                  child: Text(
                    _t('view_full_report'),
                    style: GoogleFonts.poppins(fontSize: 12, fontWeight: FontWeight.bold, color: AppTheme.accentTeal),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: AppTheme.borderColor),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: [
                  _buildSummaryItem(_t('total_parameters'), totalParams.toString(), AppTheme.textPrimary),
                  _buildSummaryItem(_t('normal_summary'), normalParams.toString(), AppTheme.accentGreen),
                  _buildSummaryItem(_t('high_summary'), highParams.toString(), AppTheme.accentRed),
                  _buildSummaryItem(_t('low_summary'), lowParams.toString(), Colors.orange),
                ],
              ),
            ),
            const SizedBox(height: 20),

            // 4. Report Tags
            Text(
              _t('report_tags'),
              style: GoogleFonts.poppins(fontWeight: FontWeight.bold, fontSize: 14, color: AppTheme.textPrimary),
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              children: report.tags.map((tag) {
                return Chip(
                  label: Text(_tm(tag), style: GoogleFonts.poppins(fontSize: 11, fontWeight: FontWeight.bold, color: AppTheme.accentTeal)),
                  backgroundColor: AppTheme.accentTeal.withOpacity(0.06),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                    side: const BorderSide(color: Colors.transparent),
                  ),
                  materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                );
              }).toList(),
            ),
            const SizedBox(height: 20),

            // 5. Patient Notes / Comments Card
            Container(
              width: double.infinity,
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
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        _t('patient_notes'),
                        style: GoogleFonts.poppins(fontWeight: FontWeight.bold, fontSize: 14, color: AppTheme.textPrimary),
                      ),
                      IconButton(
                        icon: Icon(_isEditingNotes ? Icons.check_circle_outline_rounded : Icons.edit_note_rounded, color: AppTheme.accentTeal),
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints(),
                        onPressed: () {
                          if (_isEditingNotes) {
                            provider.updateReportNotes(widget.reportId, _notesController.text.trim());
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text(_t('notes_updated_msg')),
                                backgroundColor: AppTheme.accentTeal,
                                behavior: SnackBarBehavior.floating,
                              ),
                            );
                          }
                          setState(() {
                            _isEditingNotes = !_isEditingNotes;
                          });
                        },
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  _isEditingNotes
                      ? TextField(
                          controller: _notesController,
                          style: GoogleFonts.poppins(fontSize: 12.5, color: AppTheme.textPrimary),
                          maxLines: 4,
                          decoration: InputDecoration(
                            hintText: _t('add_notes_hint'),
                            hintStyle: GoogleFonts.poppins(fontSize: 12, color: AppTheme.textSecondary.withOpacity(0.6)),
                            contentPadding: const EdgeInsets.all(12),
                            fillColor: AppTheme.lightBg,
                            filled: true,
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(10),
                              borderSide: const BorderSide(color: AppTheme.borderColor),
                            ),
                          ),
                        )
                      : Text(
                          report.notes.isNotEmpty ? report.notes : _t('no_personal_notes'),
                          style: GoogleFonts.poppins(
                            fontSize: 12.5,
                            color: report.notes.isNotEmpty ? AppTheme.textPrimary : AppTheme.textSecondary,
                            fontStyle: report.notes.isNotEmpty ? FontStyle.normal : FontStyle.italic,
                            height: 1.4,
                          ),
                        ),
                ],
              ),
            ),
            const SizedBox(height: 24),

            // 6. Action Buttons
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text(_t('downloading_report')),
                          behavior: SnackBarBehavior.floating,
                        ),
                      );
                    },
                    icon: const Icon(Icons.download_rounded, color: AppTheme.accentTeal),
                    label: Text(
                      _t('download_label'),
                      style: GoogleFonts.poppins(fontWeight: FontWeight.bold, fontSize: 13, color: AppTheme.accentTeal),
                    ),
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      side: const BorderSide(color: AppTheme.accentTeal),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text(_t('preparing_sharing')),
                          behavior: SnackBarBehavior.floating,
                        ),
                      );
                    },
                    icon: const Icon(Icons.share_rounded, color: AppTheme.accentTeal),
                    label: Text(
                      _t('share_label'),
                      style: GoogleFonts.poppins(fontWeight: FontWeight.bold, fontSize: 13, color: AppTheme.accentTeal),
                    ),
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      side: const BorderSide(color: AppTheme.accentTeal),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                GestureDetector(
                  onTap: () {
                    provider.toggleReportFavorite(widget.reportId);
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text(report!.isFavorite ? _t('removed_from_favorites') : _t('added_favorites')),
                        backgroundColor: AppTheme.accentTeal,
                        behavior: SnackBarBehavior.floating,
                      ),
                    );
                  },
                  child: Container(
                    height: 48,
                    width: 48,
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: AppTheme.borderColor),
                    ),
                    child: Icon(
                      report.isFavorite ? Icons.favorite_rounded : Icons.favorite_border_rounded,
                      color: report.isFavorite ? AppTheme.accentRed : AppTheme.textSecondary,
                      size: 20,
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    ).animate().fade();
  }

  Widget _buildFileCard(String fileName, String fileSize, bool isPdf, HealthReport report) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppTheme.borderColor),
      ),
      child: Row(
        children: [
          Icon(
            isPdf ? Icons.picture_as_pdf_rounded : Icons.image_outlined, 
            color: isPdf ? AppTheme.accentRed : Colors.blue, 
            size: 28,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  fileName,
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
                  fileSize,
                  style: GoogleFonts.poppins(fontSize: 11, color: AppTheme.textSecondary),
                ),
              ],
            ),
          ),
          IconButton(
            icon: const Icon(Icons.download_for_offline_rounded, color: AppTheme.accentTeal),
            onPressed: () {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text('${_t('downloading_file').replaceAll('{}', fileName)}'),
                  behavior: SnackBarBehavior.floating,
                ),
              );
            },
          ),
          IconButton(
            icon: const Icon(Icons.visibility_rounded, color: AppTheme.textSecondary),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => PdfViewerScreen(reportName: report.reportName),
                ),
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildSummaryItem(String label, String value, Color color) {
    return Column(
      children: [
        Text(
          value,
          style: GoogleFonts.poppins(
            fontSize: 20,
            fontWeight: FontWeight.bold,
            color: color,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          label,
          style: GoogleFonts.poppins(
            fontSize: 11,
            color: AppTheme.textSecondary,
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
  }
}
