import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../providers/swasthya_tap_provider.dart';
import '../../../models/models.dart';
import '../../../theme/app_theme.dart';

class MedicineScheduleScreen extends StatefulWidget {
  final Function(int)? onTabSelected;
  const MedicineScheduleScreen({Key? key, this.onTabSelected}) : super(key: key);

  @override
  State<MedicineScheduleScreen> createState() => _MedicineScheduleScreenState();
}

class _MedicineScheduleScreenState extends State<MedicineScheduleScreen> {
  @override
  Widget build(BuildContext context) {
    final provider = Provider.of<SwasthyaTapProvider>(context);
    final activePrescriptions = provider.prescriptions.where((p) => p.status == 'Active').toList();

    // Group active medicines by time of day
    final List<Map<String, dynamic>> morningMeds = [];
    final List<Map<String, dynamic>> afternoonMeds = [];
    final List<Map<String, dynamic>> nightMeds = [];

    for (var rx in activePrescriptions) {
      for (var med in rx.medicines) {
        final medItem = {'rxId': rx.id, 'doctor': rx.doctorName, 'med': med};
        if (med.morning) morningMeds.add(medItem);
        if (med.afternoon) afternoonMeds.add(medItem);
        if (med.night) nightMeds.add(medItem);
      }
    }

    // Completion percentage logic
    int totalMedsCount = morningMeds.length + afternoonMeds.length + nightMeds.length;
    int takenMedsCount = 0;

    for (var item in morningMeds) {
      if ((item['med'] as PrescriptionMedicine).isTakenToday) takenMedsCount++;
    }
    for (var item in afternoonMeds) {
      if ((item['med'] as PrescriptionMedicine).isTakenToday) takenMedsCount++;
    }
    for (var item in nightMeds) {
      if ((item['med'] as PrescriptionMedicine).isTakenToday) takenMedsCount++;
    }

    final double completionPercent = totalMedsCount > 0 ? (takenMedsCount / totalMedsCount) : 0.0;

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
          "Today's Medicines",
          style: GoogleFonts.poppins(fontWeight: FontWeight.bold, fontSize: 16, color: AppTheme.textPrimary),
        ),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Progress header card
              _buildProgressCard(completionPercent, takenMedsCount, totalMedsCount),
              const SizedBox(height: 20),

              // Next Dose Banner
              _buildNextDoseBanner(),
              const SizedBox(height: 24),

              // Timeline Sections
              _buildTimelineSection("Morning Dose", morningMeds, Colors.amber, Icons.wb_sunny_rounded, provider),
              const SizedBox(height: 20),

              _buildTimelineSection("Afternoon Dose", afternoonMeds, Colors.orange, Icons.wb_cloudy_rounded, provider),
              const SizedBox(height: 20),

              _buildTimelineSection("Night Dose", nightMeds, Colors.indigo, Icons.nightlight_round_rounded, provider),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildProgressCard(double completionPercent, int taken, int total) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: AppTheme.lightBg,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppTheme.borderColor),
      ),
      child: Row(
        children: [
          // Circular Progress Ring
          Stack(
            alignment: Alignment.center,
            children: [
              SizedBox(
                width: 60,
                height: 60,
                child: CircularProgressIndicator(
                  value: completionPercent,
                  strokeWidth: 6,
                  backgroundColor: AppTheme.borderColor,
                  valueColor: const AlwaysStoppedAnimation<Color>(AppTheme.accentTeal),
                ),
              ),
              Text(
                "${(completionPercent * 100).toInt()}%",
                style: GoogleFonts.poppins(fontSize: 12.5, fontWeight: FontWeight.bold, color: AppTheme.textPrimary),
              ),
            ],
          ),
          const SizedBox(width: 20),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  "Today's Completion",
                  style: GoogleFonts.poppins(fontSize: 13.5, fontWeight: FontWeight.bold, color: AppTheme.textPrimary),
                ),
                Text(
                  "$taken of $total medicines taken today",
                  style: GoogleFonts.poppins(fontSize: 11.5, color: AppTheme.textSecondary),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildNextDoseBanner() {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFFF0FDF4),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFDCFCE7)),
      ),
      child: Row(
        children: [
          const Icon(Icons.alarm_on_rounded, color: Colors.green, size: 20),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              "Next Dose: Vitamin C 500mg (Lunch • 12:30 PM)",
              style: GoogleFonts.poppins(fontSize: 11.5, color: const Color(0xFF166534), fontWeight: FontWeight.w600),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTimelineSection(
    String title,
    List<Map<String, dynamic>> list,
    Color color,
    IconData icon,
    SwasthyaTapProvider provider,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(icon, color: color, size: 16),
            const SizedBox(width: 6),
            Text(
              title,
              style: GoogleFonts.poppins(fontSize: 13, fontWeight: FontWeight.bold, color: AppTheme.textPrimary),
            ),
            const Spacer(),
            Text(
              list.isEmpty ? 'None' : '${list.length} Meds',
              style: GoogleFonts.poppins(fontSize: 11.5, color: AppTheme.textSecondary),
            ),
          ],
        ),
        const SizedBox(height: 8),
        list.isEmpty
            ? Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: AppTheme.borderColor.withOpacity(0.5)),
                ),
                child: Text(
                  'No medicines scheduled for this time slot.',
                  style: GoogleFonts.poppins(fontSize: 11.5, color: AppTheme.textSecondary),
                ),
              )
            : ListView.separated(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: list.length,
                separatorBuilder: (_, __) => const SizedBox(height: 8),
                itemBuilder: (context, index) {
                  final rxId = list[index]['rxId'] as String;
                  final doctor = list[index]['doctor'] as String;
                  final med = list[index]['med'] as PrescriptionMedicine;

                  return Container(
                    decoration: BoxDecoration(
                      color: med.isTakenToday ? const Color(0xFFF0FDF4) : Colors.white,
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(
                        color: med.isTakenToday ? const Color(0xFFDCFCE7) : AppTheme.borderColor,
                      ),
                    ),
                    child: ListTile(
                      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
                      title: Text(
                        med.name,
                        style: GoogleFonts.poppins(
                          fontSize: 13.5,
                          fontWeight: FontWeight.bold,
                          color: med.isTakenToday ? const Color(0xFF166534) : AppTheme.textPrimary,
                        ),
                      ),
                      subtitle: Text(
                        '${med.strength} • ${med.duration} • Dr. $doctor',
                        style: GoogleFonts.poppins(fontSize: 11, color: AppTheme.textSecondary),
                      ),
                      leading: Checkbox(
                        value: med.isTakenToday,
                        activeColor: Colors.green,
                        onChanged: (val) {
                          provider.toggleMedicineTakenToday(rxId, med.id);
                        },
                      ),
                      trailing: IconButton(
                        icon: const Icon(Icons.info_outline_rounded, color: AppTheme.accentTeal),
                        onPressed: () => _showMedicineDetailsSheet(med),
                      ),
                    ),
                  );
                },
              ),
      ],
    );
  }

  void _showMedicineDetailsSheet(PrescriptionMedicine med) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (context) {
        return Padding(
          padding: const EdgeInsets.fromLTRB(20, 20, 20, 30),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header title
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  margin: const EdgeInsets.only(bottom: 16),
                  decoration: BoxDecoration(color: AppTheme.borderColor, borderRadius: BorderRadius.circular(2)),
                ),
              ),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          med.name,
                          style: GoogleFonts.poppins(fontSize: 18, fontWeight: FontWeight.bold, color: AppTheme.textPrimary),
                        ),
                        Text(
                          'Dosage Strength: ${med.strength}',
                          style: GoogleFonts.poppins(fontSize: 12.5, color: AppTheme.textSecondary),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.star_outline_rounded, color: AppTheme.accentTeal),
                    onPressed: () {},
                  ),
                ],
              ),
              const Divider(height: 24, color: AppTheme.borderColor),

              // Purpose / info rows
              _buildDetailRow("Purpose", med.purpose, Icons.medical_services_outlined),
              _buildDetailRow("How to Take", med.beforeFood ? "Take on empty stomach, before meals" : "Take after meals with water", Icons.restaurant_menu_outlined),
              _buildDetailRow("Duration", "${med.duration} (Qty: ${med.quantity})", Icons.calendar_today_outlined),
              _buildDetailRow("Side Effects", med.sideEffects, Icons.warning_amber_rounded),
              _buildDetailRow("Storage", med.storage, Icons.thermostat_outlined),
              _buildDetailRow("Alternatives", med.alternatives, Icons.swap_horiz_rounded),

              const SizedBox(height: 24),

              // Action Buttons
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () {
                        Navigator.pop(context);
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('Medicine reminder notifications activated.'),
                            behavior: SnackBarBehavior.floating,
                          ),
                        );
                      },
                      icon: const Icon(Icons.alarm_add_rounded, size: 16),
                      label: const Text('Set Reminder'),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: AppTheme.accentTeal,
                        side: const BorderSide(color: AppTheme.accentTeal),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        padding: const EdgeInsets.symmetric(vertical: 14),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: () => Navigator.pop(context),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppTheme.accentTeal,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        elevation: 0,
                      ),
                      child: Text(
                        'Close Details',
                        style: GoogleFonts.poppins(fontSize: 13, fontWeight: FontWeight.bold, color: Colors.white),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildDetailRow(String label, String val, IconData icon) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 16, color: AppTheme.accentTeal),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: GoogleFonts.poppins(fontSize: 10, color: AppTheme.textSecondary, fontWeight: FontWeight.w600),
                ),
                Text(
                  val.isEmpty ? 'None' : val,
                  style: GoogleFonts.poppins(fontSize: 12, color: AppTheme.textPrimary, fontWeight: FontWeight.w500),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
