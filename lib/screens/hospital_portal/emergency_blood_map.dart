import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../../providers/swasthya_tap_provider.dart';
import '../../theme/app_theme.dart';
import '../../widgets/glass_card.dart';
import '../../models/models.dart';

class EmergencyBloodMapScreen extends StatefulWidget {
  final BloodRequest request;

  const EmergencyBloodMapScreen({Key? key, required this.request}) : super(key: key);

  @override
  _EmergencyBloodMapScreenState createState() => _EmergencyBloodMapScreenState();
}

class _EmergencyBloodMapScreenState extends State<EmergencyBloodMapScreen> with SingleTickerProviderStateMixin {
  late AnimationController _radarController;

  @override
  void initState() {
    super.initState();
    _radarController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 4),
    )..repeat();
  }

  @override
  void dispose() {
    _radarController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final provider = Provider.of<SwasthyaTapProvider>(context);
    
    // Find the latest state of this request from the provider
    final request = provider.bloodRequests.firstWhere(
      (r) => r.requestId == widget.request.requestId,
      orElse: () => widget.request,
    );

    final acceptedList = request.responses.where((r) => r.status == DonorResponseStatus.accepted).toList();
    final pendingList = request.responses.where((r) => r.status == DonorResponseStatus.pending).toList();

    return Scaffold(
      appBar: AppBar(
        title: Text('${request.bloodGroup} Network Radar'),
        backgroundColor: Colors.transparent,
        elevation: 0,
      ),
      body: Column(
        children: [
          // Radar Screen Header
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20.0),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      request.hospitalName,
                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                    ),
                    Row(
                      children: [
                        const Icon(Icons.emergency, color: AppTheme.accentRed, size: 14),
                        const SizedBox(width: 4),
                        Text(
                          'Units requested: ${request.unitsNeeded} | Broadcast radius: ${request.radiusKm.toStringAsFixed(1)}km',
                          style: const TextStyle(color: AppTheme.textSecondary, fontSize: 12),
                        ),
                      ],
                    ),
                  ],
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: AppTheme.accentTeal.withOpacity(0.12),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: AppTheme.accentTeal.withOpacity(0.3)),
                  ),
                  child: Row(
                    children: [
                      Container(
                        width: 8,
                        height: 8,
                        decoration: const BoxDecoration(color: AppTheme.accentGreen, shape: BoxShape.circle),
                      ).animate(onPlay: (controller) => controller.repeat()).fade(duration: 500.ms),
                      const SizedBox(width: 6),
                      const Text(
                        'LIVE RADAR',
                        style: TextStyle(color: AppTheme.accentTeal, fontSize: 10, fontWeight: FontWeight.bold, letterSpacing: 0.5),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),

          // Cyberpunk Holographic Radar Map View
          Expanded(
            flex: 4,
            child: Stack(
              alignment: Alignment.center,
              children: [
                // Radar sweep background painter
                AnimatedBuilder(
                  animation: _radarController,
                  builder: (context, child) {
                    return CustomPaint(
                      size: const Size(double.infinity, double.infinity),
                      painter: RadarPainter(
                        sweepAngle: _radarController.value * 2 * math.pi,
                        radiusKm: request.radiusKm,
                      ),
                    );
                  },
                ),

                // Center node representing the hospital
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: AppTheme.accentRed,
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(color: AppTheme.accentRed.withOpacity(0.5), blurRadius: 15, spreadRadius: 4),
                    ],
                  ),
                  child: const Icon(Icons.local_hospital, color: Colors.white, size: 20),
                ).animate(onPlay: (c) => c.repeat()).scale(
                      begin: const Offset(1, 1),
                      end: const Offset(1.15, 1.15),
                      duration: 1.seconds,
                      curve: Curves.easeInOut,
                    ),

                // Plotting Donor Nodes Relative to Hospital Center
                ..._buildDonorNodes(context, request, provider),
              ],
            ),
          ),

          // Bottom List of matched responses
          Expanded(
            flex: 3,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
              decoration: const BoxDecoration(
                color: AppTheme.cardBg,
                borderRadius: BorderRadius.only(topLeft: Radius.circular(24), topRight: Radius.circular(24)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Matching Donors Map (${request.responses.length})',
                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: Colors.white),
                      ),
                      Text(
                        '${acceptedList.length} Accepted | ${pendingList.length} Pending',
                        style: const TextStyle(color: AppTheme.textSecondary, fontSize: 12),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  Expanded(
                    child: request.responses.isEmpty
                        ? const Center(
                            child: Text(
                              'No matching donors found within radius.',
                              style: TextStyle(color: AppTheme.textSecondary, fontSize: 13),
                            ),
                          )
                        : ListView.builder(
                            itemCount: request.responses.length,
                            itemBuilder: (context, index) {
                              final resp = request.responses[index];
                              final distance = _calculateDistance(request.lat, request.lng, resp.lat, resp.lng);
                              final isCurrentCitizen = resp.donorId == provider.currentCitizenProfileId;

                              return Container(
                                margin: const EdgeInsets.only(bottom: 8),
                                padding: const EdgeInsets.all(10),
                                decoration: BoxDecoration(
                                  color: Colors.black38,
                                  borderRadius: BorderRadius.circular(10),
                                  border: Border.all(
                                    color: isCurrentCitizen ? AppTheme.accentTeal.withOpacity(0.3) : Colors.white.withOpacity(0.05),
                                    width: 1,
                                  ),
                                ),
                                child: Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  children: [
                                    Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Row(
                                          children: [
                                            Text(
                                              resp.donorName,
                                              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                                            ),
                                            if (isCurrentCitizen)
                                              Container(
                                                margin: const EdgeInsets.only(left: 6),
                                                padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                                                decoration: BoxDecoration(color: AppTheme.accentTeal.withOpacity(0.15), borderRadius: BorderRadius.circular(4)),
                                                child: const Text('YOU', style: TextStyle(color: AppTheme.accentTeal, fontSize: 8, fontWeight: FontWeight.bold)),
                                              ),
                                          ],
                                        ),
                                        Text(
                                          'Distance: ${distance.toStringAsFixed(1)}km | Phone: ${resp.phone}',
                                          style: const TextStyle(color: AppTheme.textSecondary, fontSize: 11),
                                        ),
                                      ],
                                    ),
                                    _buildStatusBadge(resp, request.requestId, provider),
                                  ],
                                ),
                              );
                            },
                          ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  // Generate widget list of Positioned donor icons on the radar map
  List<Widget> _buildDonorNodes(BuildContext context, BloodRequest request, SwasthyaTapProvider provider) {
    final List<Widget> nodes = [];
    final size = MediaQuery.of(context).size;
    final width = size.width;
    // We restrict the drawing area to about 320x320
    final double mapRadius = math.min(width, 320.0) / 2;

    for (var resp in request.responses) {
      // Delta mapping
      // Hospital coordinates are request.lat, request.lng
      final double dLat = resp.lat - request.lat;
      final double dLng = resp.lng - request.lng;

      // Coordinate scaling (since Bangalore coordinates are tight, 0.01 deg is ~1.1km)
      // Represent max radius (request.radiusKm) at the boundary (mapRadius px)
      // scale = px / deg
      // 1 deg ~ 111km -> request.radiusKm in deg is request.radiusKm / 111
      final double maxDeg = request.radiusKm / 111.0;
      
      // Calculate pixel offset from center
      double offsetX = (dLng / maxDeg) * mapRadius;
      double offsetY = -(dLat / maxDeg) * mapRadius; // y-axis inversion

      // Clamp coordinates inside map limits to prevent overflowing
      final double dist = math.sqrt(offsetX * offsetX + offsetY * offsetY);
      if (dist > mapRadius) {
        final double angle = math.atan2(offsetY, offsetX);
        offsetX = math.cos(angle) * mapRadius;
        offsetY = math.sin(angle) * mapRadius;
      }

      Color nodeColor = AppTheme.accentAmber;
      IconData nodeIcon = Icons.pending_outlined;

      if (resp.status == DonorResponseStatus.accepted) {
        nodeColor = AppTheme.accentGreen;
        nodeIcon = Icons.check_circle;
      } else if (resp.status == DonorResponseStatus.declined) {
        nodeColor = AppTheme.accentRed;
        nodeIcon = Icons.cancel;
      }

      nodes.add(
        Positioned(
          left: (width / 2) + offsetX - 18,
          top: (MediaQuery.of(context).size.height * 0.4 / 2) + offsetY - 18,
          child: Tooltip(
            message: '${resp.donorName} (${resp.status == DonorResponseStatus.accepted ? "${resp.etaMinutes}m ETA" : "Pending"})',
            child: Column(
              children: [
                Container(
                  padding: const EdgeInsets.all(4),
                  decoration: BoxDecoration(
                    color: AppTheme.darkBg,
                    shape: BoxShape.circle,
                    border: Border.all(color: nodeColor, width: 1.5),
                    boxShadow: [
                      BoxShadow(color: nodeColor.withOpacity(0.3), blurRadius: 8, spreadRadius: 1),
                    ],
                  ),
                  child: Icon(nodeIcon, color: nodeColor, size: 14),
                ).animate(
                  onPlay: (controller) {
                    if (resp.status == DonorResponseStatus.pending) {
                      controller.repeat();
                    }
                  },
                ).fade(begin: 0.5, end: 1, duration: 800.ms),
                const SizedBox(height: 2),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                  decoration: BoxDecoration(color: Colors.black.withOpacity(0.7), borderRadius: BorderRadius.circular(4)),
                  child: Text(
                    resp.status == DonorResponseStatus.accepted ? '${resp.etaMinutes}m' : resp.donorName.split(' ')[0],
                    style: TextStyle(color: nodeColor, fontSize: 8, fontWeight: FontWeight.bold),
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    }

    return nodes;
  }

  Widget _buildStatusBadge(DonorResponse resp, String requestId, SwasthyaTapProvider provider) {
    final isCurrentCitizen = resp.donorId == provider.currentCitizenProfileId;

    if (resp.status == DonorResponseStatus.accepted) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        decoration: BoxDecoration(color: AppTheme.accentGreen.withOpacity(0.15), borderRadius: BorderRadius.circular(8)),
        child: Text(
          'ETA: ${resp.etaMinutes} mins',
          style: const TextStyle(color: AppTheme.accentGreen, fontWeight: FontWeight.bold, fontSize: 11),
        ),
      );
    } else if (resp.status == DonorResponseStatus.declined) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        decoration: BoxDecoration(color: AppTheme.accentRed.withOpacity(0.15), borderRadius: BorderRadius.circular(8)),
        child: const Text(
          'Declined',
          style: TextStyle(color: AppTheme.accentRed, fontWeight: FontWeight.bold, fontSize: 11),
        ),
      );
    } else {
      // Pending
      if (isCurrentCitizen) {
        // If it is the current user, let them reply immediately from this screen!
        return Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            IconButton(
              icon: const Icon(Icons.cancel, color: AppTheme.accentRed, size: 22),
              onPressed: () {
                provider.respondToBloodRequest(requestId, resp.donorId, DonorResponseStatus.declined);
              },
              tooltip: 'Decline Request',
            ),
            IconButton(
              icon: const Icon(Icons.check_circle, color: AppTheme.accentGreen, size: 22),
              onPressed: () {
                provider.respondToBloodRequest(requestId, resp.donorId, DonorResponseStatus.accepted);
              },
              tooltip: 'Accept & Rush to ER',
            ),
          ],
        );
      }

      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        decoration: BoxDecoration(color: AppTheme.accentAmber.withOpacity(0.12), borderRadius: BorderRadius.circular(8)),
        child: const Text(
          'Paging...',
          style: TextStyle(color: AppTheme.accentAmber, fontWeight: FontWeight.bold, fontSize: 11),
        ),
      );
    }
  }

  double _calculateDistance(double lat1, double lng1, double lat2, double lng2) {
    final dy = (lat1 - lat2) * 111.0;
    final dx = (lng1 - lng2) * 111.0 * 0.98;
    return math.sqrt(dy * dy + dx * dx);
  }
}

// Custom Painter to render glowing cyber radar sweeps and circles
class RadarPainter extends CustomPainter {
  final double sweepAngle;
  final double radiusKm;

  RadarPainter({required this.sweepAngle, required this.radiusKm});

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final width = size.width;
    final double maxRadarRadius = math.min(width, 320.0) / 2;

    final paintCircle = Paint()
      ..color = AppTheme.accentTeal.withOpacity(0.06)
      ..style = PaintingStyle.fill;

    final paintStroke = Paint()
      ..color = Colors.white.withOpacity(0.05)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.0;

    final paintTealStroke = Paint()
      ..color = AppTheme.accentTeal.withOpacity(0.2)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.0;

    // Draw background filled circle
    canvas.drawCircle(center, maxRadarRadius, paintCircle);

    // Draw concentric circles (representing distances)
    canvas.drawCircle(center, maxRadarRadius, paintTealStroke);
    canvas.drawCircle(center, maxRadarRadius * 0.66, paintStroke);
    canvas.drawCircle(center, maxRadarRadius * 0.33, paintStroke);

    // Draw crosshair axes lines
    canvas.drawLine(Offset(center.dx - maxRadarRadius, center.dy), Offset(center.dx + maxRadarRadius, center.dy), paintStroke);
    canvas.drawLine(Offset(center.dx, center.dy - maxRadarRadius), Offset(center.dx, center.dy + maxRadarRadius), paintStroke);

    // Draw distance labels
    final textPainter1 = TextPainter(
      text: TextSpan(text: '${radiusKm.toStringAsFixed(1)}km', style: TextStyle(color: AppTheme.accentTeal.withOpacity(0.4), fontSize: 8)),
      textDirection: TextDirection.ltr,
    )..layout();
    textPainter1.paint(canvas, Offset(center.dx + maxRadarRadius - 28, center.dy + 4));

    final textPainter2 = TextPainter(
      text: TextSpan(text: '${(radiusKm * 0.66).toStringAsFixed(1)}km', style: TextStyle(color: Colors.white24, fontSize: 8)),
      textDirection: TextDirection.ltr,
    )..layout();
    textPainter2.paint(canvas, Offset(center.dx + maxRadarRadius * 0.66 - 28, center.dy + 4));

    // Draw rotating radar sweep gradient
    final sweepPaint = Paint()
      ..shader = SweepGradient(
        colors: [AppTheme.accentTeal.withOpacity(0.15), Colors.transparent],
        stops: const [0.0, 0.25],
        transform: GradientRotation(sweepAngle),
      ).createShader(Rect.fromCircle(center: center, radius: maxRadarRadius))
      ..style = PaintingStyle.fill;

    canvas.drawCircle(center, maxRadarRadius, sweepPaint);
  }

  @override
  bool shouldRepaint(covariant RadarPainter oldDelegate) {
    return oldDelegate.sweepAngle != sweepAngle || oldDelegate.radiusKm != radiusKm;
  }
}
