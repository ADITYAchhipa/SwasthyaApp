import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../providers/swasthya_tap_provider.dart';
import '../theme/app_theme.dart';
import 'glass_card.dart';

class MockSmsCenter extends StatelessWidget {
  const MockSmsCenter({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final provider = Provider.of<SwasthyaTapProvider>(context);
    final smsList = provider.mockSmsInbox;

    return Container(
      decoration: const BoxDecoration(
        color: AppTheme.darkBg,
        borderRadius: BorderRadius.only(
          topLeft: Radius.circular(24),
          topRight: Radius.circular(24),
        ),
      ),
      child: Column(
        children: [
          // Header handle
          Container(
            margin: const EdgeInsets.symmetric(vertical: 12),
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: Colors.white24,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 8.0),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    const Icon(Icons.sms, color: AppTheme.accentTeal),
                    const SizedBox(width: 8),
                    Text(
                      'Simulated SMS Network',
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                    ),
                  ],
                ),
                if (smsList.isNotEmpty)
                  TextButton(
                    onPressed: () {
                      provider.clearSmsInbox();
                    },
                    child: const Text('Clear All', style: TextStyle(color: AppTheme.accentRed)),
                  ),
              ],
            ),
          ),
          const Divider(),
          Expanded(
            child: smsList.isEmpty
                ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.sms_outlined,
                          size: 48,
                          color: AppTheme.textSecondary.withOpacity(0.4),
                        ),
                        const SizedBox(height: 12),
                        Text(
                          'No messages received yet',
                          style: TextStyle(color: AppTheme.textSecondary, fontSize: 15),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'SMS alerts will appear when hospitals declare a need',
                          style: TextStyle(color: AppTheme.textSecondary.withOpacity(0.6), fontSize: 12),
                        ),
                      ],
                    ),
                  )
                : ListView.builder(
                    padding: const EdgeInsets.all(16),
                    itemCount: smsList.length,
                    itemBuilder: (context, index) {
                      final sms = smsList[index];
                      final isReplied = sms['replied'] as bool;
                      final replyText = sms['replyText'] as String;
                      final isCurrentCitizen = sms['donorId'] == provider.currentCitizenProfileId;
                      final senderName = provider.profiles.firstWhere((p) => p.id == sms['donorId']).fullName;

                      return Container(
                        margin: const EdgeInsets.only(bottom: 12),
                        child: GlassCard(
                          padding: const EdgeInsets.all(12),
                          borderColor: isCurrentCitizen
                              ? AppTheme.accentTeal.withOpacity(0.3)
                              : Colors.white10,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Row(
                                    children: [
                                      Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                        decoration: BoxDecoration(
                                          color: isCurrentCitizen
                                              ? AppTheme.accentTeal.withOpacity(0.15)
                                              : Colors.white.withOpacity(0.05),
                                          borderRadius: BorderRadius.circular(6),
                                        ),
                                        child: Text(
                                          'To: $senderName (${sms['phone']})',
                                          style: TextStyle(
                                            color: isCurrentCitizen ? AppTheme.accentTeal : AppTheme.textPrimary,
                                            fontWeight: FontWeight.bold,
                                            fontSize: 12,
                                          ),
                                        ),
                                      ),
                                      if (isCurrentCitizen)
                                        Container(
                                          margin: const EdgeInsets.only(left: 8),
                                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                          decoration: BoxDecoration(
                                            color: AppTheme.accentAmber.withOpacity(0.15),
                                            borderRadius: BorderRadius.circular(4),
                                          ),
                                          child: const Text(
                                            'YOU',
                                            style: TextStyle(
                                              color: AppTheme.accentAmber,
                                              fontSize: 9,
                                              fontWeight: FontWeight.bold,
                                            ),
                                          ),
                                        ),
                                    ],
                                  ),
                                  Text(
                                    _formatTime(sms['timestamp']),
                                    style: const TextStyle(color: AppTheme.textSecondary, fontSize: 11),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 10),
                              Text(
                                sms['message'],
                                style: const TextStyle(fontSize: 13, height: 1.3),
                              ),
                              const SizedBox(height: 12),
                              if (!isReplied)
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.end,
                                  children: [
                                    ElevatedButton.icon(
                                      onPressed: () {
                                        provider.simulateSmsReply(sms['id'], '2');
                                      },
                                      icon: const Icon(Icons.close, size: 14),
                                      label: const Text('Decline (2)'),
                                      style: ElevatedButton.styleFrom(
                                        backgroundColor: Colors.transparent,
                                        foregroundColor: AppTheme.accentRed,
                                        elevation: 0,
                                        side: const BorderSide(color: AppTheme.accentRed, width: 0.8),
                                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    ElevatedButton.icon(
                                      onPressed: () {
                                        provider.simulateSmsReply(sms['id'], '1');
                                      },
                                      icon: const Icon(Icons.check, size: 14),
                                      label: const Text('Accept (1)'),
                                      style: ElevatedButton.styleFrom(
                                        backgroundColor: AppTheme.accentTeal,
                                        foregroundColor: Colors.black,
                                        elevation: 0,
                                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                                      ),
                                    ),
                                  ],
                                )
                              else
                                Align(
                                  alignment: Alignment.centerRight,
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Icon(
                                        replyText == '1' ? Icons.check_circle : Icons.cancel,
                                        color: replyText == '1' ? AppTheme.accentGreen : AppTheme.accentRed,
                                        size: 16,
                                      ),
                                      const SizedBox(width: 4),
                                      Text(
                                        replyText == '1'
                                            ? 'Replied: 1 (Accepted - ETA Sent)'
                                            : 'Replied: 2 (Declined)',
                                        style: TextStyle(
                                          color: replyText == '1' ? AppTheme.accentGreen : AppTheme.accentRed,
                                          fontWeight: FontWeight.bold,
                                          fontSize: 12,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                            ],
                          ),
                        ),
                      ).animate().fade().slideY(begin: 0.1, duration: 250.ms);
                    },
                  ),
          ),
        ],
      ),
    );
  }

  String _formatTime(DateTime dt) {
    return '${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
  }
}
