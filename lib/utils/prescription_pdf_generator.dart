import 'dart:typed_data';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import '../models/models.dart';

Future<Uint8List> generatePrescriptionPdfBytes({
  required MedicalProfile profile,
  required String rxId,
  required String date,
  required String hospitalName,
  required String doctorName,
  required String qualification,
  required String diagnosis,
  required String doctorNotes,
  required List<dynamic> medicines, // Can handle map or _MedicineControllers
}) async {
  final doc = pw.Document();

  // Load premium Google Fonts dynamically
  final outfitBold = await PdfGoogleFonts.outfitBold();
  final interRegular = await PdfGoogleFonts.interRegular();
  final interBold = await PdfGoogleFonts.interBold();

  doc.addPage(
    pw.Page(
      pageFormat: PdfPageFormat.a4,
      margin: const pw.EdgeInsets.all(32),
      build: (pw.Context context) {
        return pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            // 1. HOSPITAL & CLINICAL HEADER
            pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    pw.Text(
                      hospitalName.toUpperCase(),
                      style: pw.TextStyle(
                        font: outfitBold,
                        fontSize: 18,
                        color: PdfColor.fromHex('#0f766e'),
                      ),
                    ),
                    pw.SizedBox(height: 2),
                    pw.Text(
                      'Clinical Care Department',
                      style: pw.TextStyle(
                        font: interRegular,
                        fontSize: 9,
                        color: PdfColor.fromHex('#64748b'),
                      ),
                    ),
                  ],
                ),
                pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.end,
                  children: [
                    pw.Text(
                      doctorName,
                      style: pw.TextStyle(
                        font: interBold,
                        fontSize: 14,
                        color: PdfColor.fromHex('#0f172a'),
                      ),
                    ),
                    pw.Text(
                      qualification,
                      style: pw.TextStyle(
                        font: interRegular,
                        fontSize: 9.5,
                        color: PdfColor.fromHex('#475569'),
                      ),
                    ),
                  ],
                ),
              ],
            ),
            pw.SizedBox(height: 12),
            pw.Container(
              height: 1.5,
              color: PdfColor.fromHex('#0f766e'),
            ),
            pw.SizedBox(height: 14),

            // 2. PATIENT INFO BLOCK
            pw.Container(
              padding: const pw.EdgeInsets.all(12),
              decoration: pw.BoxDecoration(
                color: PdfColor.fromHex('#f8fafc'),
                borderRadius: const pw.BorderRadius.all(pw.Radius.circular(8)),
                border: pw.Border.all(color: PdfColor.fromHex('#e2e8f0')),
              ),
              child: pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  pw.Row(
                    mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                    children: [
                      pw.Text(
                        'PATIENT INFORMATION',
                        style: pw.TextStyle(
                          font: interBold,
                          fontSize: 9,
                          color: PdfColor.fromHex('#475569'),
                        ),
                      ),
                      pw.Text(
                        'Date: $date',
                        style: pw.TextStyle(
                          font: interBold,
                          fontSize: 9,
                          color: PdfColor.fromHex('#475569'),
                        ),
                      ),
                    ],
                  ),
                  pw.SizedBox(height: 8),
                  pw.Row(
                    mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                    children: [
                      pw.Column(
                        crossAxisAlignment: pw.CrossAxisAlignment.start,
                        children: [
                          pw.Text(
                            'Name: ${profile.fullName}',
                            style: pw.TextStyle(
                              font: interBold,
                              fontSize: 11,
                              color: PdfColor.fromHex('#0f172a'),
                            ),
                          ),
                          pw.SizedBox(height: 4),
                          pw.Text(
                            'Swasthya ID: ${profile.id}',
                            style: pw.TextStyle(
                              font: interRegular,
                              fontSize: 9.5,
                              color: PdfColor.fromHex('#475569'),
                            ),
                          ),
                        ],
                      ),
                      pw.Column(
                        crossAxisAlignment: pw.CrossAxisAlignment.end,
                        children: [
                          pw.Text(
                            'Age/Gender: ${profile.age ?? "N/A"} Y',
                            style: pw.TextStyle(
                              font: interRegular,
                              fontSize: 10,
                              color: PdfColor.fromHex('#0f172a'),
                            ),
                          ),
                          pw.SizedBox(height: 4),
                          pw.Text(
                            'Blood Group: ${profile.bloodGroup}',
                            style: pw.TextStyle(
                              font: interBold,
                              fontSize: 10,
                              color: PdfColor.fromHex('#dc2626'),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ],
              ),
            ),
            pw.SizedBox(height: 20),

            // 3. DIAGNOSIS
            pw.Text(
              'DIAGNOSIS & CLINICAL OBSERVATIONS',
              style: pw.TextStyle(
                font: interBold,
                fontSize: 10,
                color: PdfColor.fromHex('#0f766e'),
              ),
            ),
            pw.SizedBox(height: 4),
            pw.Text(
              diagnosis.isNotEmpty ? diagnosis : 'General checkup & clinical follow up',
              style: pw.TextStyle(
                font: interRegular,
                fontSize: 11,
                color: PdfColor.fromHex('#334155'),
              ),
            ),
            pw.SizedBox(height: 20),

            // 4. Rx SIGN (THE PRESCRIPTION SYMBOL)
            pw.Row(
              crossAxisAlignment: pw.CrossAxisAlignment.center,
              children: [
                pw.Text(
                  'Rx',
                  style: pw.TextStyle(
                    font: outfitBold,
                    fontSize: 24,
                    color: PdfColor.fromHex('#0f766e'),
                  ),
                ),
                pw.SizedBox(width: 8),
                pw.Text(
                  '(Prescribed Medications)',
                  style: pw.TextStyle(
                    font: interRegular,
                    fontSize: 9.5,
                    color: PdfColor.fromHex('#64748b'),
                  ),
                ),
              ],
            ),
            pw.SizedBox(height: 8),

            // 5. MEDICINES TABLE
            pw.Table(
              border: pw.TableBorder.all(color: PdfColor.fromHex('#e2e8f0'), width: 0.8),
              children: [
                // Table Header
                pw.TableRow(
                  decoration: pw.BoxDecoration(
                    color: PdfColor.fromHex('#f1f5f9'),
                  ),
                  children: [
                    _tableHeaderCell('S.No', interBold),
                    _tableHeaderCell('Medicine Name', interBold),
                    _tableHeaderCell('Dosage', interBold),
                    _tableHeaderCell('Frequency', interBold),
                    _tableHeaderCell('Duration', interBold),
                    _tableHeaderCell('Instructions', interBold),
                  ],
                ),
                // Table Rows
                ...List.generate(medicines.length, (index) {
                  final med = medicines[index];
                  // Can support Map or object
                  final String name = med is Map ? (med['medicineName'] ?? '') : (med.name ?? '');
                  final String dosage = med is Map ? (med['dosage'] ?? '') : (med.dosage ?? '');
                  final String frequency = med is Map ? (med['frequency'] ?? '') : (med.frequency ?? '');
                  final String duration = med is Map ? (med['duration'] ?? '') : (med.duration ?? '');
                  final String instructions = med is Map ? (med['instructions'] ?? '') : (med.instructions ?? '');

                  return pw.TableRow(
                    children: [
                      _tableBodyCell('${index + 1}', interRegular),
                      _tableBodyCell(name, interBold),
                      _tableBodyCell(dosage, interRegular),
                      _tableBodyCell(frequency, interRegular),
                      _tableBodyCell(duration, interRegular),
                      _tableBodyCell(instructions, interRegular),
                    ],
                  );
                }),
              ],
            ),
            pw.SizedBox(height: 24),

            // 6. SPECIAL INSTRUCTIONS / NOTES
            if (doctorNotes.isNotEmpty) ...[
              pw.Text(
                'DOCTOR\'S REMARKS / INSTRUCTIONS',
                style: pw.TextStyle(
                  font: interBold,
                  fontSize: 10,
                  color: PdfColor.fromHex('#0f766e'),
                ),
              ),
              pw.SizedBox(height: 4),
              pw.Text(
                doctorNotes,
                style: pw.TextStyle(
                  font: interRegular,
                  fontSize: 10.5,
                  color: PdfColor.fromHex('#334155'),
                ),
              ),
              pw.SizedBox(height: 30),
            ],

            pw.Spacer(),

            // 7. FOOTER
            pw.Container(
              height: 0.8,
              color: PdfColor.fromHex('#e2e8f0'),
            ),
            pw.SizedBox(height: 6),
            pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
              children: [
                pw.Text(
                  'Rx ID: $rxId',
                  style: pw.TextStyle(
                    font: interRegular,
                    fontSize: 8.5,
                    color: PdfColor.fromHex('#94a3b8'),
                  ),
                ),
                pw.Text(
                  'Generated via SwasthyaTap Hospital Portal',
                  style: pw.TextStyle(
                    font: interRegular,
                    fontSize: 8.5,
                    color: PdfColor.fromHex('#94a3b8'),
                  ),
                ),
              ],
            ),
          ],
        );
      },
    ),
  );

  return doc.save();
}

pw.Widget _tableHeaderCell(String label, pw.Font font) {
  return pw.Padding(
    padding: const pw.EdgeInsets.all(6),
    child: pw.Text(
      label,
      style: pw.TextStyle(
        font: font,
        fontSize: 9.5,
        color: PdfColor.fromHex('#0f172a'),
      ),
    ),
  );
}

pw.Widget _tableBodyCell(String text, pw.Font font) {
  return pw.Padding(
    padding: const pw.EdgeInsets.all(6),
    child: pw.Text(
      text,
      style: pw.TextStyle(
        font: font,
        fontSize: 9.0,
        color: PdfColor.fromHex('#334155'),
      ),
    ),
  );
}
