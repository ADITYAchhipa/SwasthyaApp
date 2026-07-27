import 'dart:typed_data';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import '../models/models.dart';

bool _containsHindi(String text) {
  for (int i = 0; i < text.length; i++) {
    int code = text.codeUnitAt(i);
    if (code >= 0x0900 && code <= 0x097F) {
      return true;
    }
  }
  return false;
}

Future<Uint8List> generateCitizenDataPdfBytes({
  required MedicalProfile citizen,
  required List<Prescription> prescriptions,
  required List<HealthReport> healthReports,
}) async {
  final doc = pw.Document();

  // Load Google Fonts dynamically via printing package
  final outfitBold = await PdfGoogleFonts.outfitBold();
  final interRegular = await PdfGoogleFonts.interRegular();
  final interBold = await PdfGoogleFonts.interBold();
  final notoHindi = await PdfGoogleFonts.notoSansDevanagariRegular();

  // Font selector based on language content
  pw.Font getFont(String text, {bool isBold = false}) {
    if (_containsHindi(text)) {
      return notoHindi;
    }
    return isBold ? interBold : interRegular;
  }

  // Header & Footer configurations for MultiPage
  doc.addPage(
    pw.MultiPage(
      pageFormat: PdfPageFormat.a4,
      margin: const pw.EdgeInsets.all(36),
      header: (pw.Context context) {
        return pw.Column(
          children: [
            pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
              children: [
                pw.Row(
                  children: [
                    pw.SizedBox(
                      width: 24,
                      height: 24,
                      child: pw.CustomPaint(
                        painter: (PdfGraphics canvas, PdfPoint size) {
                          final w = size.x;
                          final h = size.y;
                          canvas.setStrokeColor(PdfColor.fromHex('#0f766e'));
                          canvas.setLineWidth(2.4);
                          canvas.setLineCap(PdfLineCap.round);
                          canvas.setLineJoin(PdfLineJoin.round);
                          canvas.moveTo(w * 0.5, h * 0.15);
                          canvas.curveTo(w * 0.1, h * 0.45, w * 0.05, h * 0.75, w * 0.28, h * 0.85);
                          canvas.curveTo(w * 0.42, h * 0.90, w * 0.5, h * 0.74, w * 0.5, h * 0.74);
                          canvas.curveTo(w * 0.5, h * 0.74, w * 0.58, h * 0.90, w * 0.72, h * 0.85);
                          canvas.curveTo(w * 0.9, h * 0.75, w * 0.9, h * 0.45, w * 0.5, h * 0.15);
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
                    pw.SizedBox(width: 8),
                    pw.Text(
                      'SwasthyaTap',
                      style: pw.TextStyle(
                        font: outfitBold,
                        fontSize: 16,
                        color: PdfColor.fromHex('#0f766e'),
                      ),
                    ),
                  ],
                ),
                pw.Text(
                  'SECURE CITIZEN HEALTH DATA REPORT',
                  style: pw.TextStyle(
                    font: interBold,
                    fontSize: 8.5,
                    color: PdfColor.fromHex('#64748b'),
                  ),
                ),
              ],
            ),
            pw.SizedBox(height: 6),
            pw.Container(
              height: 1,
              color: PdfColor.fromHex('#cbd5e1'),
            ),
            pw.SizedBox(height: 12),
          ],
        );
      },
      footer: (pw.Context context) {
        return pw.Column(
          children: [
            pw.SizedBox(height: 12),
            pw.Container(
              height: 0.8,
              color: PdfColor.fromHex('#cbd5e1'),
            ),
            pw.SizedBox(height: 6),
            pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
              children: [
                pw.Text(
                  'SwasthyaTap Citizen Portal • Secure & Encrypted',
                  style: pw.TextStyle(
                    font: interRegular,
                    fontSize: 7.5,
                    color: PdfColor.fromHex('#94a3b8'),
                  ),
                ),
                pw.Text(
                  'Page ${context.pageNumber} of ${context.pagesCount}',
                  style: pw.TextStyle(
                    font: interRegular,
                    fontSize: 7.5,
                    color: PdfColor.fromHex('#94a3b8'),
                  ),
                ),
              ],
            ),
          ],
        );
      },
      build: (pw.Context context) {
        return [
          // Title Banner
          pw.Container(
            width: double.infinity,
            padding: const pw.EdgeInsets.all(12),
            decoration: pw.BoxDecoration(
              color: PdfColor.fromHex('#f0fdfa'),
              borderRadius: const pw.BorderRadius.all(pw.Radius.circular(8)),
              border: pw.Border.all(color: PdfColor.fromHex('#99f6e4'), width: 1),
            ),
            child: pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
              children: [
                pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    pw.Text(
                      citizen.fullName.toUpperCase(),
                      style: pw.TextStyle(
                        font: getFont(citizen.fullName, isBold: true),
                        fontSize: 16,
                        color: PdfColor.fromHex('#0f766e'),
                      ),
                    ),
                    pw.SizedBox(height: 2),
                    pw.Text(
                      'SwasthyaTap ID: ${citizen.id.toUpperCase()}',
                      style: pw.TextStyle(
                        font: interBold,
                        fontSize: 10,
                        color: PdfColor.fromHex('#0d9488'),
                      ),
                    ),
                  ],
                ),
                pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.end,
                  children: [
                    pw.Text(
                      'Report Date: ${DateTime.now().day}/${DateTime.now().month}/${DateTime.now().year}',
                      style: pw.TextStyle(
                        font: interRegular,
                        fontSize: 9.5,
                        color: PdfColor.fromHex('#334155'),
                      ),
                    ),
                    pw.SizedBox(height: 2),
                    pw.Text(
                      'Status: Active Profile',
                      style: pw.TextStyle(
                        font: interBold,
                        fontSize: 9.5,
                        color: PdfColor.fromHex('#059669'),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          pw.SizedBox(height: 16),

          // 2. Personal Information Grid
          pw.Text(
            'PERSONAL & PROFILE DETAILS',
            style: pw.TextStyle(
              font: interBold,
              fontSize: 10,
              color: PdfColor.fromHex('#1e293b'),
            ),
          ),
          pw.SizedBox(height: 6),
          pw.Row(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Expanded(
                flex: 1,
                child: pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    _buildTextDetailRow('Full Name', citizen.fullName, getFont),
                    _buildTextDetailRow('Age', citizen.age != null ? '${citizen.age} Years' : 'Not Specified', getFont),
                    _buildTextDetailRow('Blood Group', citizen.bloodGroup, getFont),
                    _buildTextDetailRow('Phone Number', citizen.phoneNumber, getFont),
                    _buildTextDetailRow('Email Address', citizen.email.isNotEmpty ? citizen.email : 'Not Specified', getFont),
                  ],
                ),
              ),
              pw.SizedBox(width: 24),
              pw.Expanded(
                flex: 1,
                child: pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    _buildTextDetailRow('Address', citizen.address.isNotEmpty ? citizen.address : 'Not Specified', getFont),
                    _buildTextDetailRow('Insurance Provider', citizen.insuranceCompany.isNotEmpty ? citizen.insuranceCompany : 'Not Specified', getFont),
                    _buildTextDetailRow('Policy Number', citizen.insurancePolicyNumber.isNotEmpty ? citizen.insurancePolicyNumber : 'Not Specified', getFont),
                    _buildTextDetailRow('DNR (Do Not Resuscitate)', citizen.isDnr ? 'YES' : 'NO', getFont),
                    _buildTextDetailRow('Blood Donor Status', citizen.isBloodDonor ? 'Active (Radius: ${citizen.donorRadiusKm}km)' : 'Inactive', getFont),
                  ],
                ),
              ),
            ],
          ),
          pw.SizedBox(height: 16),

          // 3. Clinical Alerts Box (Allergies, Chronic Conditions)
          pw.Text(
            'EMERGENCY MEDICAL ALERTS & NOTES',
            style: pw.TextStyle(
              font: interBold,
              fontSize: 10,
              color: PdfColor.fromHex('#1e293b'),
            ),
          ),
          pw.SizedBox(height: 6),
          pw.Container(
            padding: const pw.EdgeInsets.all(10),
            decoration: pw.BoxDecoration(
              color: PdfColor.fromHex('#fff7ed'),
              borderRadius: const pw.BorderRadius.all(pw.Radius.circular(8)),
              border: pw.Border.all(color: PdfColor.fromHex('#ffedd5'), width: 1),
            ),
            child: pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Row(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    pw.Expanded(
                      child: pw.Column(
                        crossAxisAlignment: pw.CrossAxisAlignment.start,
                        children: [
                          pw.Text(
                            'KNOWN ALLERGIES',
                            style: pw.TextStyle(font: interBold, fontSize: 8, color: PdfColor.fromHex('#c2410c')),
                          ),
                          pw.SizedBox(height: 2),
                          pw.Text(
                            citizen.allergies.isNotEmpty ? citizen.allergies : 'No known allergies reported.',
                            style: pw.TextStyle(font: getFont(citizen.allergies), fontSize: 10, color: PdfColor.fromHex('#451a03')),
                          ),
                        ],
                      ),
                    ),
                    pw.SizedBox(width: 16),
                    pw.Expanded(
                      child: pw.Column(
                        crossAxisAlignment: pw.CrossAxisAlignment.start,
                        children: [
                          pw.Text(
                            'CHRONIC CONDITIONS',
                            style: pw.TextStyle(font: interBold, fontSize: 8, color: PdfColor.fromHex('#c2410c')),
                          ),
                          pw.SizedBox(height: 2),
                          pw.Text(
                            citizen.chronicConditions.isNotEmpty ? citizen.chronicConditions : 'No chronic conditions reported.',
                            style: pw.TextStyle(font: getFont(citizen.chronicConditions), fontSize: 10, color: PdfColor.fromHex('#451a03')),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                pw.SizedBox(height: 8),
                pw.Divider(color: PdfColor.fromHex('#ffedd5')),
                pw.SizedBox(height: 4),
                pw.Text(
                  'SPECIAL INSTRUCTIONS / EMERGENCY NOTES',
                  style: pw.TextStyle(font: interBold, fontSize: 8, color: PdfColor.fromHex('#c2410c')),
                ),
                pw.SizedBox(height: 2),
                pw.Text(
                  citizen.specialInstructions.isNotEmpty ? citizen.specialInstructions : 'No special instructions provided.',
                  style: pw.TextStyle(font: getFont(citizen.specialInstructions), fontSize: 10, color: PdfColor.fromHex('#451a03')),
                ),
              ],
            ),
          ),
          pw.SizedBox(height: 16),

          // 4. Emergency Contacts Table
          pw.Text(
            'EMERGENCY CONTACTS',
            style: pw.TextStyle(
              font: interBold,
              fontSize: 10,
              color: PdfColor.fromHex('#1e293b'),
            ),
          ),
          pw.SizedBox(height: 6),
          if (citizen.emergencyContacts.isEmpty)
            pw.Text(
              'No emergency contacts registered.',
              style: pw.TextStyle(font: interRegular, fontSize: 10, color: PdfColor.fromHex('#64748b')),
            )
          else
            pw.Table(
              border: pw.TableBorder.all(color: PdfColor.fromHex('#cbd5e1'), width: 0.8),
              children: [
                pw.TableRow(
                  decoration: pw.BoxDecoration(color: PdfColor.fromHex('#f8fafc')),
                  children: [
                    pw.Padding(
                      padding: const pw.EdgeInsets.all(6),
                      child: pw.Text('Contact Name', style: pw.TextStyle(font: interBold, fontSize: 9)),
                    ),
                    pw.Padding(
                      padding: const pw.EdgeInsets.all(6),
                      child: pw.Text('Relationship', style: pw.TextStyle(font: interBold, fontSize: 9)),
                    ),
                    pw.Padding(
                      padding: const pw.EdgeInsets.all(6),
                      child: pw.Text('Phone Number', style: pw.TextStyle(font: interBold, fontSize: 9)),
                    ),
                  ],
                ),
                ...citizen.emergencyContacts.map((contact) {
                  return pw.TableRow(
                    children: [
                      pw.Padding(
                        padding: const pw.EdgeInsets.all(6),
                        child: pw.Text(contact.name, style: pw.TextStyle(font: getFont(contact.name), fontSize: 9.5)),
                      ),
                      pw.Padding(
                        padding: const pw.EdgeInsets.all(6),
                        child: pw.Text(contact.relation, style: pw.TextStyle(font: getFont(contact.relation), fontSize: 9.5)),
                      ),
                      pw.Padding(
                        padding: const pw.EdgeInsets.all(6),
                        child: pw.Text(contact.phone, style: pw.TextStyle(font: interRegular, fontSize: 9.5)),
                      ),
                    ],
                  );
                }).toList(),
              ],
            ),
          pw.SizedBox(height: 16),

          // 5. Organ Donation Pledge
          if (citizen.organPledge != null) ...[
            pw.Text(
              'ORGAN DONATION CONSENT PLEDGE',
              style: pw.TextStyle(
                font: interBold,
                fontSize: 10,
                color: PdfColor.fromHex('#1e293b'),
              ),
            ),
            pw.SizedBox(height: 6),
            pw.Container(
              padding: const pw.EdgeInsets.all(10),
              decoration: pw.BoxDecoration(
                color: PdfColor.fromHex('#fff1f2'),
                borderRadius: const pw.BorderRadius.all(pw.Radius.circular(8)),
                border: pw.Border.all(color: PdfColor.fromHex('#fecdd3'), width: 1),
              ),
              child: pw.Row(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  pw.Expanded(
                    child: pw.Column(
                      crossAxisAlignment: pw.CrossAxisAlignment.start,
                      children: [
                        pw.Text(
                          'Pledge Status: REGISTERED & VERIFIED WITH NOTTO',
                          style: pw.TextStyle(font: interBold, fontSize: 9, color: PdfColor.fromHex('#be123c')),
                        ),
                        pw.SizedBox(height: 4),
                        pw.Text(
                          'Pledge ID: ${citizen.organPledge!.pledgeId}',
                          style: pw.TextStyle(font: interBold, fontSize: 9.5, color: PdfColor.fromHex('#0f172a')),
                        ),
                        pw.SizedBox(height: 2),
                        pw.Text(
                          'Pledged Organs: ${citizen.organPledge!.pledgedOrgans.join(', ')}',
                          style: pw.TextStyle(font: interRegular, fontSize: 9.5, color: PdfColor.fromHex('#334155')),
                        ),
                        pw.SizedBox(height: 2),
                        pw.Text(
                          'Signed Date: ${citizen.organPledge!.signedDate}',
                          style: pw.TextStyle(font: interRegular, fontSize: 9.5, color: PdfColor.fromHex('#334155')),
                        ),
                      ],
                    ),
                  ),
                  pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.end,
                    children: [
                      pw.Container(
                        padding: const pw.EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: pw.BoxDecoration(
                          color: PdfColor.fromHex('#e11d48'),
                          borderRadius: const pw.BorderRadius.all(pw.Radius.circular(4)),
                        ),
                        child: pw.Text(
                          'DONOR',
                          style: pw.TextStyle(font: interBold, fontSize: 10, color: PdfColors.white),
                        ),
                      ),
                      pw.SizedBox(height: 8),
                      pw.Text(
                        'Pledge Hash: ${citizen.organPledge!.signatureHash.substring(0, 16)}...',
                        style: pw.TextStyle(font: interRegular, fontSize: 7, color: PdfColor.fromHex('#94a3b8')),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            pw.SizedBox(height: 20),
          ],

          // 6. Clinical Prescriptions
          pw.Text(
            'CLINICAL PRESCRIPTIONS & RX HISTORY',
            style: pw.TextStyle(
              font: interBold,
              fontSize: 10,
              color: PdfColor.fromHex('#1e293b'),
            ),
          ),
          pw.SizedBox(height: 6),
          if (prescriptions.isEmpty)
            pw.Text(
              'No electronic prescriptions on file.',
              style: pw.TextStyle(font: interRegular, fontSize: 10, color: PdfColor.fromHex('#64748b')),
            )
          else
            ...prescriptions.map((rx) {
              return pw.Container(
                margin: const pw.EdgeInsets.only(bottom: 14),
                padding: const pw.EdgeInsets.all(10),
                decoration: pw.BoxDecoration(
                  color: PdfColors.white,
                  borderRadius: const pw.BorderRadius.all(pw.Radius.circular(8)),
                  border: pw.Border.all(color: PdfColor.fromHex('#e2e8f0'), width: 1),
                ),
                child: pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    pw.Row(
                      mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                      children: [
                        pw.Text(
                          '${rx.hospitalName.toUpperCase()} - ${rx.doctorName}',
                          style: pw.TextStyle(font: getFont(rx.doctorName, isBold: true), fontSize: 10.5, color: PdfColor.fromHex('#0f766e')),
                        ),
                        pw.Text(
                          'Date: ${rx.prescriptionDate}',
                          style: pw.TextStyle(font: interBold, fontSize: 9.5, color: PdfColor.fromHex('#64748b')),
                        ),
                      ],
                    ),
                    pw.SizedBox(height: 2),
                    pw.Text(
                      'Diagnosis: ${rx.diagnosis.isNotEmpty ? rx.diagnosis : "General Care"}',
                      style: pw.TextStyle(font: getFont(rx.diagnosis), fontSize: 9.5, color: PdfColor.fromHex('#0f172a')),
                    ),
                    if (rx.doctorNotes.isNotEmpty) ...[
                      pw.SizedBox(height: 4),
                      pw.Text(
                        'Doctor Notes: ${rx.doctorNotes}',
                        style: pw.TextStyle(font: getFont(rx.doctorNotes), fontSize: 9, color: PdfColor.fromHex('#64748b'), fontStyle: pw.FontStyle.italic),
                      ),
                    ],
                    pw.SizedBox(height: 6),
                    pw.Table(
                      border: pw.TableBorder.all(color: PdfColor.fromHex('#f1f5f9'), width: 0.5),
                      children: [
                        pw.TableRow(
                          decoration: pw.BoxDecoration(color: PdfColor.fromHex('#f1f5f9')),
                          children: [
                            pw.Padding(
                              padding: const pw.EdgeInsets.all(4),
                              child: pw.Text('Medicine', style: pw.TextStyle(font: interBold, fontSize: 8.5)),
                            ),
                            pw.Padding(
                              padding: const pw.EdgeInsets.all(4),
                              child: pw.Text('Dosage/Sched', style: pw.TextStyle(font: interBold, fontSize: 8.5)),
                            ),
                            pw.Padding(
                              padding: const pw.EdgeInsets.all(4),
                              child: pw.Text('Food Relation', style: pw.TextStyle(font: interBold, fontSize: 8.5)),
                            ),
                            pw.Padding(
                              padding: const pw.EdgeInsets.all(4),
                              child: pw.Text('Duration', style: pw.TextStyle(font: interBold, fontSize: 8.5)),
                            ),
                          ],
                        ),
                        ...rx.medicines.map((med) {
                          final timing = [
                            if (med.morning) 'M',
                            if (med.afternoon) 'A',
                            if (med.night) 'N',
                          ].join('-');
                          final food = med.beforeFood ? 'Before Food' : (med.afterFood ? 'After Food' : 'As Directed');
                          return pw.TableRow(
                            children: [
                              pw.Padding(
                                padding: const pw.EdgeInsets.all(4),
                                child: pw.Text('${med.name} ${med.strength}', style: pw.TextStyle(font: getFont(med.name), fontSize: 8.5)),
                              ),
                              pw.Padding(
                                padding: const pw.EdgeInsets.all(4),
                                child: pw.Text('$timing (${med.quantity})', style: pw.TextStyle(font: interRegular, fontSize: 8.5)),
                              ),
                              pw.Padding(
                                padding: const pw.EdgeInsets.all(4),
                                child: pw.Text(food, style: pw.TextStyle(font: interRegular, fontSize: 8.5)),
                              ),
                              pw.Padding(
                                padding: const pw.EdgeInsets.all(4),
                                child: pw.Text(med.duration, style: pw.TextStyle(font: getFont(med.duration), fontSize: 8.5)),
                              ),
                            ],
                          );
                        }).toList(),
                      ],
                    ),
                  ],
                ),
              );
            }).toList(),
          pw.SizedBox(height: 16),

          // 7. Medical Reports
          pw.Text(
            'LABORATORY & IMAGING REPORTS',
            style: pw.TextStyle(
              font: interBold,
              fontSize: 10,
              color: PdfColor.fromHex('#1e293b'),
            ),
          ),
          pw.SizedBox(height: 6),
          if (healthReports.isEmpty)
            pw.Text(
              'No diagnostic reports uploaded.',
              style: pw.TextStyle(font: interRegular, fontSize: 10, color: PdfColor.fromHex('#64748b')),
            )
          else
            pw.Table(
              border: pw.TableBorder.all(color: PdfColor.fromHex('#e2e8f0'), width: 0.8),
              children: [
                pw.TableRow(
                  decoration: pw.BoxDecoration(color: PdfColor.fromHex('#f8fafc')),
                  children: [
                    pw.Padding(
                      padding: const pw.EdgeInsets.all(5),
                      child: pw.Text('Report Name', style: pw.TextStyle(font: interBold, fontSize: 8.5)),
                    ),
                    pw.Padding(
                      padding: const pw.EdgeInsets.all(5),
                      child: pw.Text('Date', style: pw.TextStyle(font: interBold, fontSize: 8.5)),
                    ),
                    pw.Padding(
                      padding: const pw.EdgeInsets.all(5),
                      child: pw.Text('Lab / Doctor', style: pw.TextStyle(font: interBold, fontSize: 8.5)),
                    ),
                    pw.Padding(
                      padding: const pw.EdgeInsets.all(5),
                      child: pw.Text('Category', style: pw.TextStyle(font: interBold, fontSize: 8.5)),
                    ),
                    pw.Padding(
                      padding: const pw.EdgeInsets.all(5),
                      child: pw.Text('Notes', style: pw.TextStyle(font: interBold, fontSize: 8.5)),
                    ),
                  ],
                ),
                ...healthReports.map((report) {
                  return pw.TableRow(
                    children: [
                      pw.Padding(
                        padding: const pw.EdgeInsets.all(5),
                        child: pw.Text(report.reportName, style: pw.TextStyle(font: getFont(report.reportName), fontSize: 8.5, color: report.isAbnormal ? PdfColor.fromHex('#b91c1c') : PdfColor.fromHex('#0f172a'))),
                      ),
                      pw.Padding(
                        padding: const pw.EdgeInsets.all(5),
                        child: pw.Text(report.reportDate, style: pw.TextStyle(font: interRegular, fontSize: 8.5)),
                      ),
                      pw.Padding(
                        padding: const pw.EdgeInsets.all(5),
                        child: pw.Text('${report.hospitalName}\n${report.doctorName}', style: pw.TextStyle(font: getFont(report.hospitalName), fontSize: 8.0)),
                      ),
                      pw.Padding(
                        padding: const pw.EdgeInsets.all(5),
                        child: pw.Text(report.category, style: pw.TextStyle(font: interRegular, fontSize: 8.5)),
                      ),
                      pw.Padding(
                        padding: const pw.EdgeInsets.all(5),
                        child: pw.Text(report.notes, style: pw.TextStyle(font: getFont(report.notes), fontSize: 8.0, color: PdfColor.fromHex('#475569'))),
                      ),
                    ],
                  );
                }).toList(),
              ],
            ),
        ];
      },
    ),
  );

  return doc.save();
}

pw.Widget _buildTextDetailRow(String label, String value, pw.Font Function(String text, {bool isBold}) getFont) {
  return pw.Padding(
    padding: const pw.EdgeInsets.symmetric(vertical: 2.5),
    child: pw.RichText(
      text: pw.TextSpan(
        children: [
          pw.TextSpan(
            text: '$label: ',
            style: pw.TextStyle(font: getFont(label, isBold: true), fontSize: 9.5, color: PdfColor.fromHex('#64748b')),
          ),
          pw.TextSpan(
            text: value,
            style: pw.TextStyle(font: getFont(value, isBold: false), fontSize: 9.5, color: PdfColor.fromHex('#0f172a')),
          ),
        ],
      ),
    ),
  );
}
