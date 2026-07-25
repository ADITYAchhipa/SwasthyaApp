import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../../../theme/app_theme.dart';

class PdfViewerScreen extends StatefulWidget {
  final String reportName;
  const PdfViewerScreen({Key? key, required this.reportName}) : super(key: key);

  @override
  State<PdfViewerScreen> createState() => _PdfViewerScreenState();
}

class _PdfViewerScreenState extends State<PdfViewerScreen> {
  int _currentPage = 1;
  final int _totalPages = 2;
  double _zoomScale = 1.0;
  bool _isFavorite = false;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF1E293B), // Dark background for PDF previewer
      appBar: AppBar(
        backgroundColor: const Color(0xFF0F172A),
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              widget.reportName,
              style: GoogleFonts.poppins(fontSize: 14, fontWeight: FontWeight.bold, color: Colors.white),
            ),
            Text(
              'Page $_currentPage of $_totalPages',
              style: GoogleFonts.poppins(fontSize: 11, color: Colors.grey[400]),
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.zoom_in_rounded, color: Colors.white),
            onPressed: () {
              setState(() {
                if (_zoomScale < 2.0) _zoomScale += 0.25;
              });
            },
          ),
          IconButton(
            icon: const Icon(Icons.zoom_out_rounded, color: Colors.white),
            onPressed: () {
              setState(() {
                if (_zoomScale > 0.75) _zoomScale -= 0.25;
              });
            },
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: Column(
        children: [
          // PDF Canvas area
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
              child: Center(
                child: Transform.scale(
                  scale: _zoomScale,
                  child: Container(
                    width: double.infinity,
                    constraints: const BoxConstraints(maxWidth: 420),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(4),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.3),
                          blurRadius: 15,
                          offset: const Offset(0, 8),
                        ),
                      ],
                    ),
                    padding: const EdgeInsets.all(24),
                    child: _currentPage == 1 
                        ? _buildReportDocumentPage1() 
                        : _buildReportDocumentPage2(),
                  ),
                ),
              ),
            ),
          ),

          // Bottom toolbar
          Container(
            height: 64,
            color: const Color(0xFF0F172A),
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    IconButton(
                      icon: const Icon(Icons.navigate_before_rounded, color: Colors.white),
                      onPressed: _currentPage > 1
                          ? () {
                              setState(() {
                                _currentPage = 1;
                              });
                            }
                          : null,
                    ),
                    Text(
                      '$_currentPage / $_totalPages',
                      style: GoogleFonts.poppins(color: Colors.white, fontSize: 13, fontWeight: FontWeight.bold),
                    ),
                    IconButton(
                      icon: const Icon(Icons.navigate_next_rounded, color: Colors.white),
                      onPressed: _currentPage < _totalPages
                          ? () {
                              setState(() {
                                _currentPage = 2;
                              });
                            }
                          : null,
                    ),
                  ],
                ),
                Row(
                  children: [
                    IconButton(
                      icon: const Icon(Icons.download_rounded, color: Colors.white),
                      tooltip: 'Download PDF',
                      onPressed: () {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('Downloading PDF file...'),
                            behavior: SnackBarBehavior.floating,
                          ),
                        );
                      },
                    ),
                    IconButton(
                      icon: const Icon(Icons.share_rounded, color: Colors.white),
                      tooltip: 'Share PDF',
                      onPressed: () {},
                    ),
                    IconButton(
                      icon: Icon(
                        _isFavorite ? Icons.favorite_rounded : Icons.favorite_border_rounded, 
                        color: _isFavorite ? AppTheme.accentRed : Colors.white,
                      ),
                      tooltip: 'Mark Favorite',
                      onPressed: () {
                        setState(() {
                          _isFavorite = !_isFavorite;
                        });
                      },
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildReportDocumentPage1() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // 1. Hospital Header
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'CityCare Hospital',
                  style: GoogleFonts.poppins(fontSize: 16, fontWeight: FontWeight.bold, color: AppTheme.accentTeal),
                ),
                Text(
                  'Ongoing Care, Integrated Support',
                  style: GoogleFonts.poppins(fontSize: 9, color: AppTheme.textSecondary, fontWeight: FontWeight.w500),
                ),
              ],
            ),
            const Icon(Icons.health_and_safety_rounded, color: AppTheme.accentTeal, size: 28),
          ],
        ),
        const SizedBox(height: 10),
        Container(height: 1.5, color: AppTheme.accentTeal),
        const SizedBox(height: 14),

        // Title
        Center(
          child: Text(
            'LABORATORY REPORT',
            style: GoogleFonts.poppins(fontSize: 12, fontWeight: FontWeight.bold, color: AppTheme.textPrimary, letterSpacing: 1),
          ),
        ),
        const SizedBox(height: 14),

        // 2. Patient details section
        _buildDocRow('Patient Name:', 'Rajesh Kumar', 'Age / Gender:', '29 Y / Male'),
        _buildDocRow('Report Date:', '12 May 2026', 'Reference ID:', 'CBC1205250001'),
        _buildDocRow('Sample ID:', 'SAMP-992384', 'Blood Group:', 'B+'),
        const SizedBox(height: 16),
        Container(height: 1, color: AppTheme.borderColor),
        const SizedBox(height: 12),

        // 3. Test values table
        Table(
          columnWidths: const {
            0: FlexColumnWidth(2.5),
            1: FlexColumnWidth(1.2),
            2: FlexColumnWidth(1.0),
            3: FlexColumnWidth(1.8),
          },
          children: [
            TableRow(
              decoration: const BoxDecoration(color: Color(0xFFF1F5F9)),
              children: [
                _buildTableCell('Test Name', isHeader: true),
                _buildTableCell('Result', isHeader: true),
                _buildTableCell('Unit', isHeader: true),
                _buildTableCell('Ref. Range', isHeader: true),
              ],
            ),
            TableRow(children: [
              _buildTableCell('Hemoglobin (Hb)'),
              _buildTableCell('14.2'),
              _buildTableCell('g/dL'),
              _buildTableCell('13.0 - 17.0'),
            ]),
            TableRow(children: [
              _buildTableCell('Total RBC Count'),
              _buildTableCell('5.10'),
              _buildTableCell('M/cumm'),
              _buildTableCell('4.50 - 5.50'),
            ]),
            TableRow(children: [
              _buildTableCell('Total WBC Count'),
              _buildTableCell('6,200'),
              _buildTableCell('/cumm'),
              _buildTableCell('4,000-11,000'),
            ]),
            TableRow(children: [
              _buildTableCell('Platelet Count'),
              _buildTableCell('1.42', isBold: true, isRed: true), // Low
              _buildTableCell('Lakh/cumm'),
              _buildTableCell('1.50 - 4.50'),
            ]),
            TableRow(children: [
              _buildTableCell('Hematocrit (HCT)'),
              _buildTableCell('42.1'),
              _buildTableCell('%'),
              _buildTableCell('40.0 - 50.0'),
            ]),
            TableRow(children: [
              _buildTableCell('MCH'),
              _buildTableCell('28.5'),
              _buildTableCell('pg'),
              _buildTableCell('27.0 - 32.0'),
            ]),
            TableRow(children: [
              _buildTableCell('MCHC'),
              _buildTableCell('33.1'),
              _buildTableCell('g/dL'),
              _buildTableCell('32.0 - 36.0'),
            ]),
          ],
        ),
        const SizedBox(height: 24),

        // End of page indicator line
        const Center(
          child: Text(
            '--- Page 1 / 2 ---',
            style: TextStyle(fontSize: 10, color: AppTheme.textSecondary),
          ),
        ),
      ],
    );
  }

  Widget _buildReportDocumentPage2() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // 1. Hospital Header
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'CityCare Hospital',
                  style: GoogleFonts.poppins(fontSize: 16, fontWeight: FontWeight.bold, color: AppTheme.accentTeal),
                ),
                Text(
                  'Ongoing Care, Integrated Support',
                  style: GoogleFonts.poppins(fontSize: 9, color: AppTheme.textSecondary, fontWeight: FontWeight.w500),
                ),
              ],
            ),
            const Icon(Icons.health_and_safety_rounded, color: AppTheme.accentTeal, size: 28),
          ],
        ),
        const SizedBox(height: 10),
        Container(height: 1.5, color: AppTheme.accentTeal),
        const SizedBox(height: 14),

        // Table continued
        Text(
          'DIFFERENTIAL LEUKOCYTE COUNT (DLC):',
          style: GoogleFonts.poppins(fontSize: 10.5, fontWeight: FontWeight.bold, color: AppTheme.textPrimary),
        ),
        const SizedBox(height: 10),
        Table(
          columnWidths: const {
            0: FlexColumnWidth(2.5),
            1: FlexColumnWidth(1.2),
            2: FlexColumnWidth(1.0),
            3: FlexColumnWidth(1.8),
          },
          children: [
            TableRow(
              decoration: const BoxDecoration(color: Color(0xFFF1F5F9)),
              children: [
                _buildTableCell('Test Name', isHeader: true),
                _buildTableCell('Result', isHeader: true),
                _buildTableCell('Unit', isHeader: true),
                _buildTableCell('Ref. Range', isHeader: true),
              ],
            ),
            TableRow(children: [
              _buildTableCell('Neutrophils'),
              _buildTableCell('62'),
              _buildTableCell('%'),
              _buildTableCell('40 - 80'),
            ]),
            TableRow(children: [
              _buildTableCell('Lymphocytes'),
              _buildTableCell('30'),
              _buildTableCell('%'),
              _buildTableCell('20 - 40'),
            ]),
            TableRow(children: [
              _buildTableCell('Eosinophils'),
              _buildTableCell('04'),
              _buildTableCell('%'),
              _buildTableCell('01 - 06'),
            ]),
            TableRow(children: [
              _buildTableCell('Monocytes'),
              _buildTableCell('03'),
              _buildTableCell('%'),
              _buildTableCell('02 - 10'),
            ]),
            TableRow(children: [
              _buildTableCell('Basophils'),
              _buildTableCell('01'),
              _buildTableCell('%'),
              _buildTableCell('< 02'),
            ]),
          ],
        ),
        const SizedBox(height: 24),

        // Doctor's Interpretation note
        Text(
          'INTERPRETATION:',
          style: GoogleFonts.poppins(fontSize: 10.5, fontWeight: FontWeight.bold, color: AppTheme.textPrimary),
        ),
        const SizedBox(height: 6),
        Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: Colors.amber[50],
            borderRadius: BorderRadius.circular(6),
            border: Border.all(color: Colors.amber[200]!),
          ),
          child: Text(
            'Borderline low platelet count noted (1.42 Lakh/cumm). Suggest clinical correlation and review with clinical symptoms. Avoid self-medication.',
            style: GoogleFonts.poppins(fontSize: 9.5, color: Colors.amber[900], fontStyle: FontStyle.italic, height: 1.35),
          ),
        ),
        const Spacer(),

        // Signature block
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Reported By:',
                  style: GoogleFonts.poppins(fontSize: 9.5, color: AppTheme.textSecondary),
                ),
                const SizedBox(height: 4),
                Text(
                  'Dr. Rahul Sharma',
                  style: GoogleFonts.poppins(fontSize: 11, fontWeight: FontWeight.bold, color: AppTheme.textPrimary),
                ),
                Text(
                  'MD, Pathology',
                  style: GoogleFonts.poppins(fontSize: 9, color: AppTheme.textSecondary),
                ),
              ],
            ),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Container(
                  width: 50,
                  height: 30,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    border: Border.all(color: Colors.grey[300]!),
                  ),
                  child: const Text('SIGN', style: TextStyle(fontSize: 9, color: Colors.grey, fontWeight: FontWeight.bold)),
                ),
                const SizedBox(height: 4),
                Text(
                  'Authorized Signatory',
                  style: GoogleFonts.poppins(fontSize: 9, color: AppTheme.textSecondary),
                ),
              ],
            ),
          ],
        ),
        const SizedBox(height: 20),

        // End of report text
        Center(
          child: Text(
            '*** End of Report ***',
            style: GoogleFonts.poppins(fontSize: 10, fontWeight: FontWeight.bold, color: AppTheme.textSecondary),
          ),
        ),
        const SizedBox(height: 10),
      ],
    );
  }

  Widget _buildDocRow(String label1, String value1, String label2, String value2) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2.0),
      child: Row(
        children: [
          SizedBox(
            width: 80,
            child: Text(
              label1,
              style: GoogleFonts.poppins(fontSize: 10, color: AppTheme.textSecondary, fontWeight: FontWeight.w600),
            ),
          ),
          Expanded(
            child: Text(
              value1,
              style: GoogleFonts.poppins(fontSize: 10, color: AppTheme.textPrimary, fontWeight: FontWeight.bold),
            ),
          ),
          SizedBox(
            width: 80,
            child: Text(
              label2,
              style: GoogleFonts.poppins(fontSize: 10, color: AppTheme.textSecondary, fontWeight: FontWeight.w600),
            ),
          ),
          Expanded(
            child: Text(
              value2,
              style: GoogleFonts.poppins(fontSize: 10, color: AppTheme.textPrimary, fontWeight: FontWeight.bold),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTableCell(String text, {bool isHeader = false, bool isBold = false, bool isRed = false}) {
    return Padding(
      padding: const EdgeInsets.all(6.0),
      child: Text(
        text,
        style: GoogleFonts.poppins(
          fontSize: isHeader ? 10 : 9.5,
          fontWeight: (isHeader || isBold) ? FontWeight.bold : FontWeight.normal,
          color: isHeader 
              ? AppTheme.textPrimary 
              : isRed 
                  ? AppTheme.accentRed 
                  : AppTheme.textPrimary,
        ),
      ),
    );
  }
}
