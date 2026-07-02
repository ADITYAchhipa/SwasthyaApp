import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:swasthya_tap/theme/app_theme.dart';
import 'package:swasthya_tap/providers/swasthya_tap_provider.dart';
import 'package:swasthya_tap/services/api_service.dart';
import 'package:swasthya_tap/utils/translation_service.dart';

class PreviousReportsScreen extends StatelessWidget {
  const PreviousReportsScreen({Key? key}) : super(key: key);

  String _t(BuildContext context, String key) {
    return TranslationService.t(context, key);
  }

  @override
  Widget build(BuildContext context) {
    final provider = Provider.of<SwasthyaTapProvider>(context);

    return Scaffold(
      backgroundColor: AppTheme.lightBg,
      appBar: AppBar(
        title: const Text(
          'Previous Reports',
          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
        ),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded),
          onPressed: () => Navigator.pop(context),
        ),
        elevation: 0,
        backgroundColor: Colors.white,
        foregroundColor: AppTheme.textPrimary,
      ),
      body: SafeArea(
        child: FutureBuilder<List<dynamic>>(
          future: ApiService.getHealthReports(),
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(
                child: CircularProgressIndicator(color: AppTheme.accentTeal),
              );
            }
            if (snapshot.hasError) {
              return Center(
                child: Text(
                  'Failed to load previous reports',
                  style: TextStyle(color: AppTheme.accentRed, fontSize: 13),
                ),
              );
            }
            final reports = snapshot.data ?? [];
            if (reports.isEmpty) {
              return Center(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 32),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.assignment_turned_in_rounded, size: 54, color: Colors.grey[300]),
                      const SizedBox(height: 16),
                      const Text(
                        'No previous health reports found.',
                        style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: AppTheme.textPrimary),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 6),
                      Text(
                        'Your submitted health reports will show up here.',
                        style: TextStyle(fontSize: 12, color: AppTheme.textSecondary),
                        textAlign: TextAlign.center,
                      ),
                    ],
                  ),
                ),
              );
            }

            return ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: reports.length,
              itemBuilder: (context, index) {
                final report = reports[index] as Map<String, dynamic>;
                final disease = report['disease'] as String? ?? 'Unknown';
                final severity = report['severityLevel'] as String? ?? 'mild';
                final status = report['status'] as String? ?? 'submitted';
                final symptoms = (report['symptoms'] as List<dynamic>?) ?? [];
                final location = report['locationDescription'] as String? ?? '';
                final notes = report['additionalNotes'] as String? ?? '';
                final dateStr = report['createdAt'] as String? ?? '';
                final reportingFor = report['reportingFor'] as String? ?? 'self';
                final duration = report['duration'] as String? ?? '';
                final isAnonymous = report['submitAnonymously'] as bool? ?? false;

                DateTime? parsedDate;
                if (dateStr.isNotEmpty) {
                  parsedDate = DateTime.tryParse(dateStr);
                }
                final formattedDate = parsedDate != null
                    ? '${parsedDate.day}/${parsedDate.month}/${parsedDate.year} at ${parsedDate.hour.toString().padLeft(2, "0")}:${parsedDate.minute.toString().padLeft(2, "0")}'
                    : 'Recent';

                // Severity colors
                Color severityColor = AppTheme.accentGreen;
                if (severity == 'moderate') severityColor = AppTheme.accentAmber;
                if (severity == 'severe') severityColor = AppTheme.accentRed;

                // Status colors
                Color statusBg = Colors.grey[100]!;
                Color statusText = AppTheme.textSecondary;
                if (status == 'reviewed') {
                  statusBg = const Color(0xFFECFDF5);
                  statusText = const Color(0xFF059669);
                } else if (status == 'resolved') {
                  statusBg = const Color(0xFFEFF6FF);
                  statusText = const Color(0xFF2563EB);
                }

                return Container(
                  margin: const EdgeInsets.only(bottom: 14),
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: AppTheme.borderColor),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.01),
                        blurRadius: 8,
                        offset: const Offset(0, 2),
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
                              disease,
                              style: const TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                                color: AppTheme.textPrimary,
                              ),
                            ),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                            decoration: BoxDecoration(
                              color: statusBg,
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: Text(
                              status.toUpperCase(),
                              style: TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.bold,
                                color: statusText,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Text(
                        formattedDate,
                        style: TextStyle(fontSize: 11, color: AppTheme.textSecondary),
                      ),
                      const Divider(height: 24, color: AppTheme.borderColor),
                      
                      // Report Details
                      Row(
                        children: [
                          _buildDetailBadge('For: ${reportingFor.toUpperCase()}', Colors.blue[50]!, Colors.blue[800]!),
                          const SizedBox(width: 8),
                          _buildDetailBadge('Severity: ${severity.toUpperCase()}', severityColor.withOpacity(0.1), severityColor),
                          if (duration.isNotEmpty) ...[
                            const SizedBox(width: 8),
                            _buildDetailBadge('Duration: $duration', Colors.purple[50]!, Colors.purple[800]!),
                          ],
                        ],
                      ),
                      const SizedBox(height: 12),

                      if (symptoms.isNotEmpty) ...[
                        Text(
                          'Symptoms: ${symptoms.join(", ")}',
                          style: const TextStyle(fontSize: 12, color: AppTheme.textPrimary),
                        ),
                        const SizedBox(height: 8),
                      ],
                      if (location.isNotEmpty) ...[
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Icon(Icons.location_on_outlined, color: Colors.grey[500], size: 14),
                            const SizedBox(width: 4),
                            Expanded(
                              child: Text(
                                location,
                                style: TextStyle(fontSize: 11, color: AppTheme.textSecondary),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                      ],
                      if (notes.isNotEmpty) ...[
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: Colors.grey[50],
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: Colors.grey[200]!),
                          ),
                          child: Text(
                            notes,
                            style: TextStyle(fontSize: 11.5, fontStyle: FontStyle.italic, color: Colors.grey[700]),
                          ),
                        ),
                      ],
                      if (isAnonymous) ...[
                        const SizedBox(height: 8),
                        Row(
                          children: [
                            Icon(Icons.visibility_off_outlined, color: Colors.teal[600], size: 14),
                            const SizedBox(width: 4),
                            Text(
                              'Submitted Anonymously',
                              style: TextStyle(fontSize: 11, color: Colors.teal[700], fontWeight: FontWeight.bold),
                            ),
                          ],
                        ),
                      ],
                    ],
                  ),
                );
              },
            );
          },
        ),
      ),
    );
  }

  Widget _buildDetailBadge(String label, Color bg, Color text) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 10,
          fontWeight: FontWeight.bold,
          color: text,
        ),
      ),
    );
  }
}
