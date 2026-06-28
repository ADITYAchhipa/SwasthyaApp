import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../providers/swasthya_tap_provider.dart';
import '../theme/app_theme.dart';
import '../widgets/mock_sms_center.dart';
import 'nfc_simulator_screen.dart';
import 'citizen_portal/citizen_dashboard.dart';
import 'hospital_portal/hospital_dashboard.dart';
import '../utils/translation_service.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final provider = Provider.of<SwasthyaTapProvider>(context);
    final unreplied = provider.mockSmsInbox.where((s) => !s['replied']).length;

    return Scaffold(
      backgroundColor: AppTheme.lightBg,
      appBar: _appBar(context, provider),
      body: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 100),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Live status banner
            _statusBanner(context, provider).animate().fade(),
            const SizedBox(height: 20),

            // Hero card
            _heroCard(context).animate().fade().slideY(begin: 0.05, duration: 400.ms),
            const SizedBox(height: 28),

            // Section label
            Text(TranslationService.t(context, 'portal_modules'), style: Theme.of(context).textTheme.titleLarge?.copyWith(fontSize: 17))
                .animate().fade(delay: 80.ms),
            const SizedBox(height: 4),
            Text(TranslationService.t(context, 'select_role_continue'), style: const TextStyle(color: AppTheme.textSecondary, fontSize: 13))
                .animate().fade(delay: 100.ms),
            const SizedBox(height: 16),

            // Portal cards
            _portalCard(
              context,
              icon: Icons.person_rounded,
              title: TranslationService.t(context, 'citizen_title'),
              subtitle: TranslationService.t(context, 'citizen_portal_subtitle'),
              desc: TranslationService.t(context, 'citizen_portal_desc'),
              color: AppTheme.accentTeal,
              gradient: AppTheme.tealGradient,
              tag: 'CITIZEN',
              onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const CitizenDashboard())),
            ).animate().fade(delay: 150.ms).slideY(begin: 0.08),
            const SizedBox(height: 12),

            _portalCard(
              context,
              icon: Icons.local_hospital_rounded,
              title: TranslationService.t(context, 'hospital_portal_title'),
              subtitle: TranslationService.t(context, 'hospital_portal_subtitle'),
              desc: TranslationService.t(context, 'hospital_portal_desc'),
              color: AppTheme.accentRed,
              gradient: AppTheme.redGradient,
              tag: 'HOSPITAL',
              onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const HospitalDashboard())),
            ).animate().fade(delay: 230.ms).slideY(begin: 0.08),
            const SizedBox(height: 12),

            _portalCard(
              context,
              icon: Icons.nfc_rounded,
              title: TranslationService.t(context, 'nfc_simulator_title'),
              subtitle: TranslationService.t(context, 'nfc_simulator_subtitle'),
              desc: TranslationService.t(context, 'nfc_simulator_desc'),
              color: AppTheme.accentAmber,
              gradient: AppTheme.goldGradient,
              tag: 'PLAYGROUND',
              onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const NfcSimulatorScreen())),
            ).animate().fade(delay: 310.ms).slideY(begin: 0.08),
            const SizedBox(height: 28),

            // Bottom quick stats
            _statsRow(context).animate().fade(delay: 400.ms),
          ],
        ),
      ),
      floatingActionButton: _fab(context, unreplied).animate().scale(delay: 500.ms),
    );
  }

  PreferredSizeWidget _appBar(BuildContext context, SwasthyaTapProvider provider) {
    return PreferredSize(
      preferredSize: const Size.fromHeight(56),
      child: Container(
        decoration: const BoxDecoration(
          color: AppTheme.cardBg,
          border: Border(bottom: BorderSide(color: AppTheme.borderColor)),
        ),
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(7),
                  decoration: BoxDecoration(
                    gradient: AppTheme.tealGradient,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(Icons.bolt, color: Colors.white, size: 16),
                ),
                const SizedBox(width: 10),
                Text(TranslationService.t(context, 'swasthya_tap_title'),
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(fontSize: 17, fontWeight: FontWeight.bold)),
                const SizedBox(width: 6),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: AppTheme.accentTeal.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: const Text('INDIA',
                      style: TextStyle(color: AppTheme.accentTeal, fontSize: 9, fontWeight: FontWeight.bold, letterSpacing: 1)),
                ),
                const Spacer(),
                // Connectivity pill
                GestureDetector(
                  onTap: () => provider.setInternetAvailability(!provider.isInternetAvailable),
                  child: AnimatedContainer(
                    duration: 300.ms,
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                    decoration: BoxDecoration(
                      color: (provider.isInternetAvailable ? AppTheme.accentGreen : AppTheme.accentRed).withOpacity(0.1),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                        color: (provider.isInternetAvailable ? AppTheme.accentGreen : AppTheme.accentRed).withOpacity(0.3),
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(
                          width: 6,
                          height: 6,
                          decoration: BoxDecoration(
                            color: provider.isInternetAvailable ? AppTheme.accentGreen : AppTheme.accentRed,
                            shape: BoxShape.circle,
                          ),
                        ),
                        const SizedBox(width: 5),
                        Text(
                          provider.isInternetAvailable ? TranslationService.t(context, 'online') : TranslationService.t(context, 'offline'),
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                            color: provider.isInternetAvailable ? AppTheme.accentGreen : AppTheme.accentRed,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _statusBanner(BuildContext context, SwasthyaTapProvider provider) {
    final active = provider.bloodRequests.length;
    final isAlert = active > 0;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
      decoration: BoxDecoration(
        color: isAlert ? AppTheme.accentRed.withOpacity(0.06) : AppTheme.surfaceColor,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isAlert ? AppTheme.accentRed.withOpacity(0.2) : AppTheme.borderColor,
        ),
      ),
      child: Row(
        children: [
          Container(
            width: 7, height: 7,
            decoration: BoxDecoration(
              color: isAlert ? AppTheme.accentRed : AppTheme.accentGreen,
              shape: BoxShape.circle,
            ),
          ).animate(onPlay: (c) => c.repeat()).fade(begin: 0.4, end: 1.0, duration: 900.ms),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              isAlert
                  ? '$active ${TranslationService.t(context, 'active_blood_alerts')}'
                  : TranslationService.t(context, 'no_blood_emergencies'),
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: isAlert ? AppTheme.accentRed : AppTheme.textSecondary,
              ),
            ),
          ),
          Icon(Icons.chevron_right, size: 16, color: AppTheme.textSecondary),
        ],
      ),
    );
  }

  Widget _heroCard(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        gradient: AppTheme.tealGradient,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(color: AppTheme.accentTeal.withOpacity(0.25), blurRadius: 20, offset: const Offset(0, 8)),
        ],
      ),
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(Icons.health_and_safety_rounded, color: Colors.white, size: 22),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(TranslationService.t(context, 'universal_emergency_title'),
                        style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16)),
                    Text(TranslationService.t(context, 'nfc_medical_network_india'),
                        style: const TextStyle(color: Colors.white70, fontSize: 12)),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Text(
            TranslationService.t(context, 'swasthya_tap_hero_desc'),
            style: const TextStyle(color: Colors.white70, fontSize: 12, height: 1.5),
          ),
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _heroStat('1.5L', TranslationService.t(context, 'deaths_per_year_stat')),
              _divider(),
              _heroStat('₹20', TranslationService.t(context, 'nfc_tag_stat')),
              _divider(),
              _heroStat('1 sec', TranslationService.t(context, 'read_time_stat')),
              _divider(),
              _heroStat('5L+', TranslationService.t(context, 'organ_queue_stat')),
            ],
          ),
        ],
      ),
    );
  }

  Widget _heroStat(String val, String label) {
    return Column(
      children: [
        Text(val, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 15)),
        const SizedBox(height: 2),
        Text(label, style: const TextStyle(color: Colors.white60, fontSize: 10)),
      ],
    );
  }

  Widget _divider() => Container(width: 1, height: 28, color: Colors.white24);

  Widget _portalCard(
    BuildContext context, {
    required IconData icon,
    required String title,
    required String subtitle,
    required String desc,
    required Color color,
    required Gradient gradient,
    required String tag,
    required VoidCallback onTap,
  }) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Container(
          decoration: BoxDecoration(
            color: AppTheme.cardBg,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: AppTheme.borderColor),
            boxShadow: const [
              BoxShadow(color: Color(0x08000000), blurRadius: 10, offset: Offset(0, 3)),
            ],
          ),
          child: Row(
            children: [
              // Left accent bar + icon
              Container(
                width: 5,
                height: 90,
                decoration: BoxDecoration(
                  gradient: gradient,
                  borderRadius: const BorderRadius.only(
                    topLeft: Radius.circular(16),
                    bottomLeft: Radius.circular(16),
                  ),
                ),
              ),
              const SizedBox(width: 14),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: color.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(icon, color: color, size: 24),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 4),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Text(title,
                              style: const TextStyle(
                                  fontWeight: FontWeight.bold, fontSize: 14, color: AppTheme.textPrimary)),
                          const Spacer(),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                            decoration: BoxDecoration(
                              color: color.withOpacity(0.1),
                              borderRadius: BorderRadius.circular(5),
                            ),
                            child: Text(tag,
                                style: TextStyle(
                                    color: color, fontSize: 8, fontWeight: FontWeight.bold, letterSpacing: 0.8)),
                          ),
                          const SizedBox(width: 12),
                        ],
                      ),
                      const SizedBox(height: 3),
                      Text(subtitle,
                          style: TextStyle(color: color, fontSize: 11, fontWeight: FontWeight.w600)),
                      const SizedBox(height: 5),
                      Text(desc,
                          style: const TextStyle(color: AppTheme.textSecondary, fontSize: 11, height: 1.4),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _statsRow(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 8),
      decoration: BoxDecoration(
        color: AppTheme.cardBg,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppTheme.borderColor),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          _stat(Icons.person_outline, '3', TranslationService.t(context, 'profiles_stat'), AppTheme.accentTeal),
          Container(width: 1, height: 32, color: AppTheme.borderColor),
          _stat(Icons.nfc, '₹20', TranslationService.t(context, 'nfc_tag_stat'), AppTheme.accentAmber),
          Container(width: 1, height: 32, color: AppTheme.borderColor),
          _stat(Icons.offline_bolt_outlined, '100%', TranslationService.t(context, 'offline_first_stat'), AppTheme.accentGreen),
        ],
      ),
    );
  }

  Widget _stat(IconData icon, String val, String label, Color color) {
    return Column(
      children: [
        Icon(icon, size: 18, color: color),
        const SizedBox(height: 4),
        Text(val, style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: color)),
        Text(label, style: const TextStyle(color: AppTheme.textSecondary, fontSize: 10)),
      ],
    );
  }

  Widget _fab(BuildContext context, int count) {
    return FloatingActionButton.extended(
      onPressed: () {
        showModalBottomSheet(
          context: context,
          isScrollControlled: true,
          backgroundColor: Colors.transparent,
          builder: (_) => const FractionallySizedBox(heightFactor: 0.85, child: MockSmsCenter()),
        );
      },
      backgroundColor: count > 0 ? AppTheme.accentRed : AppTheme.accentTeal,
      foregroundColor: Colors.white,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      label: Row(
        children: [
          Icon(count > 0 ? Icons.sms_failed_rounded : Icons.sms_rounded, size: 18),
          const SizedBox(width: 8),
          Text(count > 0 ? '${TranslationService.t(context, 'sms_alerts_count')} ($count)' : TranslationService.t(context, 'sms_center_btn'),
              style: const TextStyle(fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }
}
