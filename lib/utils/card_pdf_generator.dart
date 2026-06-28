import 'dart:typed_data';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import '../../models/models.dart';

pw.Gradient _getPdfGradient(String variant) {
  List<PdfColor> colors;
  switch (variant) {
    case 'Worker':
      colors = [PdfColor.fromInt(0xFFEA580C), PdfColor.fromInt(0xFFD84A06), PdfColor.fromInt(0xFF9A3412)];
      break;
    case 'Senior':
      colors = [PdfColor.fromInt(0xFF065F46), PdfColor.fromInt(0xFF047857), PdfColor.fromInt(0xFF064E3B)];
      break;
    case 'Child':
      colors = [PdfColor.fromInt(0xFFFBBF24), PdfColor.fromInt(0xFFF59E0B), PdfColor.fromInt(0xFFD97706)];
      break;
    case 'Premium':
      colors = [PdfColor.fromInt(0xFF1E1B4B), PdfColor.fromInt(0xFF0F172A), PdfColor.fromInt(0xFF030712)];
      break;
    default: // Standard
      colors = [PdfColor.fromInt(0xFF018086), PdfColor.fromInt(0xFF011E30)];
  }
  return pw.LinearGradient(
    colors: colors,
    begin: pw.Alignment.topLeft,
    end: pw.Alignment.bottomRight,
  );
}

Future<Uint8List> generateCardPdfBytes({
  required MedicalProfile citizen,
  required String selectedVariant,
  required String selectedLanguage,
  required bool showBloodGroup,
  required bool showEmergencyContacts,
  required bool showAllergies,
  required bool showMedicalConditions,
}) async {
  final doc = pw.Document();

  // Load Google Fonts dynamically via printing package
  final outfitBold = await PdfGoogleFonts.outfitBold();
  final interRegular = await PdfGoogleFonts.interRegular();
  final interBold = await PdfGoogleFonts.interBold();
  final notoHindi = await PdfGoogleFonts.notoSansDevanagariRegular();

  final cardWidth = 335.0;
  final cardHeight = 210.0;

  // 1. Front Card Widget
  final frontCard = pw.Container(
    width: cardWidth,
    height: cardHeight,
    decoration: pw.BoxDecoration(
      gradient: _getPdfGradient(selectedVariant),
      borderRadius: const pw.BorderRadius.all(pw.Radius.circular(16)),
      border: pw.Border.all(
        color: PdfColor.fromHex('#ffffff').withAlpha(0.20),
        width: 1.2,
      ),
    ),
    child: pw.ClipRRect(
      horizontalRadius: 16,
      verticalRadius: 16,
      child: pw.Stack(
        children: [
          // Tricolor wave
          pw.Positioned(
            bottom: 0,
            right: 0,
            left: 120,
            child: pw.SizedBox(
              height: 35,
              child: pw.CustomPaint(
                painter: (PdfGraphics canvas, PdfPoint size) {
                  final w = size.x;
                  final h = size.y;

                  final strokeW = 4.0;
                  final offset = 4.0;

                  canvas.setLineCap(PdfLineCap.round);

                  // Saffron paint (India Saffron: #FF9933)
                  canvas.setStrokeColor(PdfColor.fromInt(0xFFFF9933));
                  canvas.setLineWidth(strokeW);
                  canvas.moveTo(w * 0.1, -10 + offset);
                  canvas.curveTo(w * 0.45, h * 0.9 + offset, w * 0.75, h * 0.7 + offset, w + 10, h * 0.3 + offset);
                  canvas.strokePath();

                  // White paint (#FFFFFF)
                  canvas.setStrokeColor(PdfColor.fromInt(0xFFFFFFFF));
                  canvas.setLineWidth(strokeW);
                  canvas.moveTo(w * 0.1, -10);
                  canvas.curveTo(w * 0.45, h * 0.9, w * 0.75, h * 0.7, w + 10, h * 0.3);
                  canvas.strokePath();

                  // Green paint (India Green: #128807)
                  canvas.setStrokeColor(PdfColor.fromInt(0xFF128807));
                  canvas.setLineWidth(strokeW);
                  canvas.moveTo(w * 0.1, -10 - offset);
                  canvas.curveTo(w * 0.45, h * 0.9 - offset, w * 0.75, h * 0.7 - offset, w + 10, h * 0.3 - offset);
                  canvas.strokePath();
                },
              ),
            ),
          ),
          // Contactless Waves symbol
          pw.Positioned(
            top: 18,
            right: 18,
            child: pw.SizedBox(
              width: 18,
              height: 20,
              child: pw.CustomPaint(
                painter: (PdfGraphics canvas, PdfPoint size) {
                  final w = size.x;
                  final h = size.y;

                  canvas.setStrokeColor(PdfColors.white);
                  canvas.setLineWidth(2.0);
                  canvas.setLineCap(PdfLineCap.round);

                  final cx = -w * 0.15;
                  final cy = h / 2;
                  final radii = [w * 0.35, w * 0.65, w * 0.95, w * 1.25];

                  for (var r in radii) {
                    final startX = cx + r * 0.7071;
                    final startY = cy - r * 0.7071;
                    final endX = cx + r * 0.7071;
                    final endY = cy + r * 0.7071;

                    final cp1x = cx + r * 0.95;
                    final cp1y = cy - r * 0.35;
                    final cp2x = cx + r * 0.95;
                    final cp2y = cy + r * 0.35;

                    canvas.moveTo(startX, startY);
                    canvas.curveTo(cp1x, cp1y, cp2x, cp2y, endX, endY);
                    canvas.strokePath();
                  }
                },
              ),
            ),
          ),
          // QR Code
          pw.Positioned(
            bottom: 14,
            left: 14,
            child: pw.Container(
              padding: const pw.EdgeInsets.all(3.5),
              decoration: const pw.BoxDecoration(
                color: PdfColors.white,
                borderRadius: pw.BorderRadius.all(pw.Radius.circular(4)),
              ),
              child: pw.BarcodeWidget(
                barcode: pw.Barcode.qrCode(),
                data: 'https://swasthtap.in/citizen/${citizen.id}',
                width: 39,
                height: 39,
                drawText: false,
              ),
            ),
          ),
          // Center: SwasthTap Logo (Heart-ECG) & taglines
          pw.Center(
            child: pw.Row(
              mainAxisSize: pw.MainAxisSize.min,
              crossAxisAlignment: pw.CrossAxisAlignment.center,
              children: [
                pw.SizedBox(
                  width: 40,
                  height: 40,
                  child: pw.CustomPaint(
                    painter: (PdfGraphics canvas, PdfPoint size) {
                      final w = size.x;
                      final h = size.y;
                      
                      canvas.setStrokeColor(PdfColors.white);
                      canvas.setLineWidth(2.4);
                      canvas.setLineCap(PdfLineCap.round);
                      canvas.setLineJoin(PdfLineJoin.round);
                      
                      canvas.moveTo(w * 0.5, h * 0.15); // bottom point
                      
                      canvas.curveTo(
                        w * 0.1, h * 0.45,
                        w * 0.05, h * 0.75,
                        w * 0.28, h * 0.85,
                      );
                      canvas.curveTo(
                        w * 0.42, h * 0.90,
                        w * 0.5, h * 0.74,
                        w * 0.5, h * 0.74,
                      );
                      canvas.curveTo(
                        w * 0.5, h * 0.74,
                        w * 0.58, h * 0.90,
                        w * 0.72, h * 0.85,
                      );
                      canvas.curveTo(
                        w * 0.9, h * 0.75,
                        w * 0.9, h * 0.45,
                        w * 0.5, h * 0.15,
                      );
                      canvas.strokePath();

                      canvas.setLineWidth(1.8);
                      canvas.moveTo(w * 0.25, h * 0.55);
                      canvas.lineTo(w * 0.38, h * 0.55);
                      canvas.lineTo(w * 0.42, h * 0.48);
                      canvas.lineTo(w * 0.47, h * 0.70);
                      canvas.lineTo(w * 0.53, h * 0.40);
                      canvas.lineTo(w * 0.57, h * 0.55);
                      canvas.lineTo(w * 0.75, h * 0.55);
                      canvas.strokePath();
                    },
                  ),
                ),
                pw.SizedBox(width: 12),
                pw.Column(
                  mainAxisSize: pw.MainAxisSize.min,
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    pw.Text(
                      'SwasthTap',
                      style: pw.TextStyle(
                        font: outfitBold,
                        color: PdfColors.white,
                        fontSize: 28,
                      ),
                    ),
                    pw.Text(
                      'आपकी स्वास्थ्य पहचान',
                      style: pw.TextStyle(
                        font: notoHindi,
                        color: PdfColors.white.withAlpha(0.85),
                        fontSize: 10,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    ),
  );

  // 2. Back Card Widget
  final backCard = pw.Container(
    width: cardWidth,
    height: cardHeight,
    decoration: pw.BoxDecoration(
      gradient: _getPdfGradient(selectedVariant),
      borderRadius: const pw.BorderRadius.all(pw.Radius.circular(16)),
      border: pw.Border.all(
        color: PdfColor.fromHex('#ffffff').withAlpha(0.20),
        width: 1.2,
      ),
    ),
    child: pw.Padding(
      padding: const pw.EdgeInsets.symmetric(horizontal: 14.0, vertical: 12.0),
      child: pw.Row(
        children: [
          // Left Half: ID details & NFC pill
          pw.Expanded(
            flex: 5,
            child: pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
              children: [
                // Logo Block
                pw.Row(
                  children: [
                    pw.SizedBox(
                      width: 18,
                      height: 18,
                      child: pw.CustomPaint(
                        painter: (PdfGraphics canvas, PdfPoint size) {
                          final w = size.x;
                          final h = size.y;
                          
                          canvas.setStrokeColor(PdfColors.white);
                          canvas.setLineWidth(2.4);
                          canvas.setLineCap(PdfLineCap.round);
                          canvas.setLineJoin(PdfLineJoin.round);
                          
                          canvas.moveTo(w * 0.5, h * 0.15); // bottom point
                          
                          canvas.curveTo(
                            w * 0.1, h * 0.45,
                            w * 0.05, h * 0.75,
                            w * 0.28, h * 0.85,
                          );
                          canvas.curveTo(
                            w * 0.42, h * 0.90,
                            w * 0.5, h * 0.74,
                            w * 0.5, h * 0.74,
                          );
                          canvas.curveTo(
                            w * 0.5, h * 0.74,
                            w * 0.58, h * 0.90,
                            w * 0.72, h * 0.85,
                          );
                          canvas.curveTo(
                            w * 0.9, h * 0.75,
                            w * 0.9, h * 0.45,
                            w * 0.5, h * 0.15,
                          );
                          canvas.strokePath();

                          canvas.setLineWidth(1.8);
                          canvas.moveTo(w * 0.25, h * 0.55);
                          canvas.lineTo(w * 0.38, h * 0.55);
                          canvas.lineTo(w * 0.42, h * 0.48);
                          canvas.lineTo(w * 0.47, h * 0.70);
                          canvas.lineTo(w * 0.53, h * 0.40);
                          canvas.lineTo(w * 0.57, h * 0.55);
                          canvas.lineTo(w * 0.75, h * 0.55);
                          canvas.strokePath();
                        },
                      ),
                    ),
                    pw.SizedBox(width: 6),
                    pw.Column(
                      crossAxisAlignment: pw.CrossAxisAlignment.start,
                      children: [
                        pw.Text(
                          'SwasthTap',
                          style: pw.TextStyle(
                            font: outfitBold,
                            fontSize: 13,
                            color: PdfColors.white,
                          ),
                        ),
                        pw.Text(
                          selectedLanguage == 'Hindi' ? 'आपकी स्वास्थ्य पहचान' : 'Your Health Identity',
                          style: pw.TextStyle(
                            font: selectedLanguage == 'Hindi' ? notoHindi : interBold,
                            fontSize: 6.0,
                            color: PdfColors.white.withAlpha(0.85),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
                
                // Text fields
                pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    _buildPdfDetailRow(interRegular, notoHindi, selectedLanguage == 'Hindi' ? 'स्वस्थटैप आईडी' : 'SwasthTap ID', 'STP 1234 5678 9012', selectedLanguage),
                    _buildPdfDetailRow(interRegular, notoHindi, selectedLanguage == 'Hindi' ? 'नाम' : 'Name', citizen.fullName, selectedLanguage),
                    _buildPdfDetailRow(interRegular, notoHindi, selectedLanguage == 'Hindi' ? 'जन्म तिथि' : 'Date of Birth', '15/08/1990', selectedLanguage),
                    if (showBloodGroup)
                      _buildPdfDetailRow(interRegular, notoHindi, selectedLanguage == 'Hindi' ? 'रक्त समूह' : 'Blood Group', citizen.bloodGroup, selectedLanguage),
                    if (showEmergencyContacts && citizen.emergencyContacts.isNotEmpty)
                      _buildPdfDetailRow(interRegular, notoHindi, selectedLanguage == 'Hindi' ? 'आपातकालीन' : 'Emergency Contact', citizen.emergencyContacts[0].phone, selectedLanguage),
                    if (showAllergies)
                      _buildPdfDetailRow(interRegular, notoHindi, selectedLanguage == 'Hindi' ? 'एलर्जी' : 'Allergies', citizen.allergies.isNotEmpty ? citizen.allergies : 'None', selectedLanguage),
                    if (showMedicalConditions)
                      _buildPdfDetailRow(interRegular, notoHindi, selectedLanguage == 'Hindi' ? 'चिकित्सा स्थिति' : 'Conditions', citizen.specialInstructions.isNotEmpty ? citizen.specialInstructions : 'None', selectedLanguage),
                  ],
                ),
                
                // Bottom Tap Card Pill
                pw.Container(
                  padding: const pw.EdgeInsets.symmetric(horizontal: 6, vertical: 4),
                  decoration: pw.BoxDecoration(
                    color: PdfColor.fromHex('#0f766e').withAlpha(0.35),
                    borderRadius: const pw.BorderRadius.all(pw.Radius.circular(6)),
                    border: pw.Border.all(color: PdfColors.white.withAlpha(0.10), width: 0.8),
                  ),
                  child: pw.Row(
                    children: [
                      pw.Text(
                        '(((i))) ',
                        style: pw.TextStyle(font: interBold, fontSize: 6.5, color: PdfColors.white),
                      ),
                      pw.Expanded(
                        child: pw.Text(
                          selectedLanguage == 'Hindi' 
                              ? 'प्रोफ़ाइल देखने के लिए फ़ोन पर कार्ड टैप करें'
                              : 'Tap this card on NFC enabled phone to access health profile',
                          style: pw.TextStyle(
                            font: selectedLanguage == 'Hindi' ? notoHindi : interRegular,
                            fontSize: 5.5,
                            color: PdfColors.white,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          
          // Vertical Divider
          pw.Container(
            width: 1,
            height: double.infinity,
            color: PdfColors.white.withAlpha(0.20),
            margin: const pw.EdgeInsets.symmetric(horizontal: 7),
          ),
          
          // Right Half: Bullet list & Help contacts
          pw.Expanded(
            flex: 5,
            child: pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
              children: [
                // Features list
                pw.Column(
                  children: [
                    _buildPdfFeatureRow(interBold, interRegular, notoHindi, selectedLanguage == 'Hindi' ? 'सुरक्षित' : 'Secure', selectedLanguage == 'Hindi' ? 'डेटा पूरी तरह एन्क्रिप्टेड है' : 'Your data is encrypted and protected', selectedLanguage),
                    pw.SizedBox(height: 6),
                    _buildPdfFeatureRow(interBold, interRegular, notoHindi, selectedLanguage == 'Hindi' ? 'निजी' : 'Private', selectedLanguage == 'Hindi' ? 'अनुमति-आधारित पहुंच' : 'Access your health data with your permission', selectedLanguage),
                    pw.SizedBox(height: 6),
                    _buildPdfFeatureRow(interBold, interRegular, notoHindi, selectedLanguage == 'Hindi' ? 'पोर्टेबल' : 'Portable', selectedLanguage == 'Hindi' ? 'ले जाने में आसान। एनएफसी सक्षम' : 'Easy to carry. Always with you.', selectedLanguage),
                  ],
                ),
                
                // Help contact info at bottom
                pw.Row(
                  crossAxisAlignment: pw.CrossAxisAlignment.center,
                  children: [
                    pw.Text(
                      'HELP: ',
                      style: pw.TextStyle(font: interBold, fontSize: 6.5, color: PdfColors.white),
                    ),
                    pw.Expanded(
                      child: pw.Column(
                        crossAxisAlignment: pw.CrossAxisAlignment.start,
                        children: [
                          pw.Text(
                            selectedLanguage == 'Hindi' ? 'सहायता चाहिए?' : 'Need Help?',
                            style: pw.TextStyle(font: selectedLanguage == 'Hindi' ? notoHindi : interBold, fontSize: 7.5, color: PdfColors.white),
                          ),
                          pw.Text(
                            'support@swasthtap.in | 1800-121-4536',
                            style: pw.TextStyle(font: interRegular, fontSize: 6.0, color: PdfColors.white.withAlpha(0.80)),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    ),
  );

  doc.addPage(
    pw.Page(
      pageFormat: PdfPageFormat.a4,
      margin: const pw.EdgeInsets.all(32),
      build: (pw.Context context) {
        return pw.Center(
          child: pw.Column(
            mainAxisAlignment: pw.MainAxisAlignment.center,
            children: [
              pw.Text(
                'SwasthTap Emergency Medical Card',
                style: pw.TextStyle(font: outfitBold, fontSize: 18, color: PdfColor.fromHex('#0f766e')),
              ),
              pw.SizedBox(height: 6),
              pw.Text(
                'Print, cut out, fold in half, and laminate your emergency card.',
                style: pw.TextStyle(font: interRegular, fontSize: 10, color: PdfColor.fromHex('#64748b')),
              ),
              pw.SizedBox(height: 35),
              
              // Front Card
              frontCard,
              
              // Dotted fold line
              pw.Container(
                width: cardWidth,
                margin: const pw.EdgeInsets.symmetric(vertical: 20),
                child: pw.Row(
                  mainAxisAlignment: pw.MainAxisAlignment.center,
                  children: List.generate(
                    25,
                    (index) => pw.Container(
                      width: 4,
                      height: 1,
                      color: PdfColor.fromHex('#cbd5e1'),
                      margin: const pw.EdgeInsets.symmetric(horizontal: 2),
                    ),
                  ),
                ),
              ),
              
              // Back Card
              backCard,
              
              pw.SizedBox(height: 40),
              pw.Text(
                'Generated via SwasthTap Citizen Portal • Secure & Encrypted',
                style: pw.TextStyle(font: interRegular, fontSize: 8, color: PdfColor.fromHex('#94a3b8')),
              ),
            ],
          ),
        );
      },
    ),
  );

  return doc.save();
}

pw.Widget _buildPdfDetailRow(
  pw.Font interRegular,
  pw.Font notoHindi,
  String label,
  String value,
  String selectedLanguage,
) {
  final font = selectedLanguage == 'Hindi' ? notoHindi : interRegular;
  return pw.Padding(
    padding: const pw.EdgeInsets.symmetric(vertical: 1.2),
    child: pw.Row(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.SizedBox(
          width: 54,
          child: pw.Text(
            label,
            style: pw.TextStyle(
              font: font,
              fontSize: 7.0,
              color: PdfColors.white.withAlpha(0.80),
            ),
          ),
        ),
        pw.Text(
          ' :  ',
          style: pw.TextStyle(
            font: interRegular,
            fontSize: 7.0,
            color: PdfColors.white.withAlpha(0.80),
          ),
        ),
        pw.Expanded(
          child: pw.Text(
            value,
            style: pw.TextStyle(
              font: font,
              fontSize: 7.0,
              color: PdfColors.white,
            ),
          ),
        ),
      ],
    ),
  );
}

pw.Widget _buildPdfFeatureRow(
  pw.Font interBold,
  pw.Font interRegular,
  pw.Font notoHindi,
  String title,
  String desc,
  String selectedLanguage,
) {
  final fontTitle = selectedLanguage == 'Hindi' ? notoHindi : interBold;
  final fontDesc = selectedLanguage == 'Hindi' ? notoHindi : interRegular;
  return pw.Row(
    crossAxisAlignment: pw.CrossAxisAlignment.start,
    children: [
      pw.Padding(
        padding: const pw.EdgeInsets.only(top: 2.5),
        child: pw.Container(
          width: 3.5,
          height: 3.5,
          decoration: const pw.BoxDecoration(
            color: PdfColors.white,
            shape: pw.BoxShape.circle,
          ),
        ),
      ),
      pw.SizedBox(width: 6),
      pw.Expanded(
        child: pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            pw.Text(
              title,
              style: pw.TextStyle(font: fontTitle, fontSize: 8.0, color: PdfColors.white),
            ),
            pw.Text(
              desc,
              style: pw.TextStyle(font: fontDesc, fontSize: 6.0, color: PdfColors.white.withAlpha(0.80)),
            ),
          ],
        ),
      ),
    ],
  );
}
