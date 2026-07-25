file_path = '/home/aditya/clones/Card/lib/screens/citizen_portal/scanned_profile_screen.dart'

with open(file_path, 'r', encoding='utf-8') as f:
    lines = f.readlines()

# 1. Add translation_service import
new_lines = []
for line in lines:
    new_lines.append(line)
    if "import '../../theme/app_theme.dart';" in line:
        new_lines.append("import '../../utils/translation_service.dart';\n")

# Re-join to search and replace text blocks
content = "".join(new_lines)

# 2. Remove _abhaExpanded state variable
content = content.replace("  bool _abhaExpanded = true;\n", "")

# 3. Remove ABHA ID Block and ABHA Linked Badge from profile card:
# Let's locate the block in details Column:
# We find:
#                                   const SizedBox(height: 6),
#                                   // ABHA ID Block
#                                   Wrap(
# ...
#                                   ),
#
# Let's search for this block and replace it:
abha_card_block = """                                  // ABHA ID Block
                                  Wrap(
                                    crossAxisAlignment: WrapCrossAlignment.center,
                                    spacing: 4,
                                    children: [
                                      Text(
                                        'ABHA ID: 91-XXXXIXXXX-1234',
                                        style: GoogleFonts.inter(
                                          fontSize: 11.5,
                                          color: const Color(0xFF334155),
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                      const Icon(Icons.copy_rounded, size: 12, color: Color(0xFF64748B)),
                                    ],
                                  ),
                                  const SizedBox(height: 8),
                                  // ABHA Linked Badge
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                    decoration: BoxDecoration(
                                      color: const Color(0xFFDCFCE7),
                                      borderRadius: BorderRadius.circular(100),
                                      border: Border.all(color: const Color(0xFFBBF7D0)),
                                    ),
                                    child: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        const Icon(Icons.link_rounded, size: 10, color: Color(0xFF15803D)),
                                        const SizedBox(width: 4),
                                        Text(
                                          'ABHA Linked',
                                          style: GoogleFonts.inter(
                                            color: const Color(0xFF15803D),
                                            fontSize: 9.5,
                                            fontWeight: FontWeight.w800,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),"""

content = content.replace(abha_card_block, "")

# 4. Remove the ABHA Connection Status Accordion:
# Let's find:
#                   // Section 5: ABHA ID Status
#                   _buildAccordionTile(
#                     title: '5. ABHA Connection Status',
# ...
#                   ).animate().fade(delay: 350.ms, duration: 400.ms).slideY(begin: 0.05, end: 0, duration: 400.ms),
#                   const SizedBox(height: 24),

abha_accordion_block = """                  // Section 5: ABHA ID Status
                  _buildAccordionTile(
                    title: '5. ABHA Connection Status',
                    icon: Icons.badge_outlined,
                    accentColor: const Color(0xFF7C3AED),
                    isExpanded: _abhaExpanded,
                    onToggle: () => setState(() => _abhaExpanded = !_abhaExpanded),
                    content: Container(
                      padding: const EdgeInsets.all(14),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'ABHA HEALTH ID',
                                  style: GoogleFonts.inter(
                                    fontSize: 9.5,
                                    color: const Color(0xFF94A3B8),
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  '91-XXXXIXXXX-1234',
                                  style: GoogleFonts.inter(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 13,
                                    color: const Color(0xFF334155),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                            decoration: BoxDecoration(
                              color: const Color(0xFFDCFCE7),
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(color: const Color(0xFFBBF7D0)),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Icon(Icons.check_circle_rounded, color: Color(0xFF16A34A), size: 12),
                                const SizedBox(width: 4),
                                Text(
                                  'Verified & Linked',
                                  style: GoogleFonts.inter(
                                    color: const Color(0xFF15803D),
                                    fontSize: 10.5,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ).animate().fade(delay: 350.ms, duration: 400.ms).slideY(begin: 0.05, end: 0, duration: 400.ms),
                  const SizedBox(height: 24),"""

content = content.replace(abha_accordion_block, "")

# 5. Let's make sure all hardcoded labels are translated
# Let's replace title strings in accordions:
content = content.replace("title: '1. Active Medications',", "title: _t('active_medications_sec'),")
content = content.replace("title: '2. Medical Conditions',", "title: _t('medical_conditions_sec'),")
content = content.replace("title: '3. Emergency Contacts',", "title: _t('emergency_contacts_sec'),")
content = content.replace("title: '4. Insurance',", "title: _t('insurance_sec'),")

# Let's replace status and action button texts:
content = content.replace("'Verified'", "_t('verified')")
content = content.replace("'Card Read Successfully'", "_t('card_read_success')")
content = content.replace("'CRITICAL ALLERGIES DETECTED'", "_t('critical_allergies_detected')")
content = content.replace("'Alert Family'", "_t('alert_family')")
content = content.replace("'Send SMS + Location to emergency contacts'", "_t('alert_family_sub')")
content = content.replace("'Call 108'", "_t('call_108')")
content = content.replace("'Ambulance'", "_t('ambulance')")
content = content.replace("'Share Data'", "_t('share_data')")
content = content.replace("'Telemetry'", "_t('with_hospital')")

# Let's find build(BuildContext context) to wrap the scaffold and split it
pos_state_class = content.find("class _ScannedProfileScreenState extends State<ScannedProfileScreen> {")
pos_build = content.find("Widget build(BuildContext context) {")

state_fields = """class _ScannedProfileScreenState extends State<ScannedProfileScreen> {
  String _t(String key) => TranslationService.t(context, key);

  // Expansion states for the sections
  bool _medsExpanded = true;
  bool _conditionsExpanded = true;
  bool _contactsExpanded = true;
  bool _insuranceExpanded = true;

  // Mock JSON representing what will come from the backend for receipts
  final List<Map<String, dynamic>> _receiptsJson = [
    {
      'title_key': 'opd_consultation_receipt',
      'issuer_key': 'dr_amit_shah',
      'date': '20 Jun 2026',
      'amount': '₹500',
      'status_key': 'paid',
    },
    {
      'title_key': 'pharmacy_billing_rx',
      'issuer_key': 'apollo_pharmacy',
      'date': '21 Jun 2026',
      'amount': '₹1,240',
      'status_key': 'paid',
    },
    {
      'title_key': 'diagnostics_invoice',
      'issuer_key': 'city_labs',
      'date': '12 May 2026',
      'amount': '₹1,500',
      'status_key': 'paid',
    }
  ];

  // Mock JSON representing what will come from the backend for medical reports
  final List<Map<String, dynamic>> _reportsJson = [
    {
      'title_key': 'cbc_report',
      'issuer_key': 'lab_name_city',
      'date': '18 Jun 2026',
      'status_key': 'verified_report',
      'doctor_key': 'dr_amit_shah',
    },
    {
      'title_key': 'lipid_profile',
      'issuer_key': 'lab_name_apollo',
      'date': '10 May 2026',
      'status_key': 'verified_report',
      'doctor_key': 'dr_patel',
    },
    {
      'title_key': 'thyroid_report',
      'issuer_key': 'lab_name_city',
      'date': '24 Apr 2026',
      'status_key': 'verified_report',
      'doctor_key': 'dr_singh',
    },
    {
      'title_key': 'chest_xray',
      'issuer_key': 'lab_name_apollo',
      'date': '15 Feb 2026',
      'status_key': 'verified_report',
      'doctor_key': 'dr_amit_shah',
    }
  ];
"""

# Now we need to modify build method.
# We replacepos_state_class to pos_build with state_fields
content_with_fields = content[:pos_state_class] + state_fields + content[pos_build:]

# Let's locate the build method in content_with_fields
pos_build_new = content_with_fields.find("Widget build(BuildContext context) {")
pos_scaffold = content_with_fields.find("return Scaffold(", pos_build_new)
pos_allergy = content_with_fields.find("// Allergy Badge builder - nice red style")

# Let's find the closing of build method before pos_allergy
pos_end_build = content_with_fields.rfind("}", 0, pos_allergy)
# Let's find the last occurrence of '}' before that
pos_end_build_scaffold = content_with_fields.rfind(";", 0, pos_end_build)
pos_end_build_scaffold_brace = content_with_fields.rfind("}", 0, pos_end_build_scaffold)

# Let's extract original Scaffold return statement
original_scaffold_return = content_with_fields[pos_scaffold:pos_end_build_scaffold+1]

# Let's locate the body parameter
body_pos = original_scaffold_return.find("body: SingleChildScrollView(")
# body content is from SingleChildScrollView to the end of scaffold return (excluding trailing );)
body_content = original_scaffold_return[body_pos + len("body: "):]
body_content = body_content.rstrip()
if body_content.endswith(";"):
    body_content = body_content[:-1]
if body_content.endswith(")"):
    body_content = body_content[:-1]

# Let's build the tabbed Scaffold structure:
tabbed_build = """  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 3,
      child: Scaffold(
        backgroundColor: const Color(0xFFF1F5F9), // Sleek, modern background
        appBar: AppBar(
          backgroundColor: Colors.white,
          elevation: 0,
          centerTitle: true,
          leading: IconButton(
            icon: const Icon(Icons.arrow_back_ios_new_rounded, color: Color(0xFF0F172A), size: 20),
            onPressed: () => Navigator.pop(context),
          ),
          title: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              CustomPaint(
                size: const Size(22, 22),
                painter: HeartEcgPainter(color: const Color(0xFF018086)),
              ),
              const SizedBox(width: 8),
              Text(
                'SwasthyaTap',
                style: GoogleFonts.outfit(
                  color: const Color(0xFF0F172A),
                  fontWeight: FontWeight.bold,
                  fontSize: 20,
                  letterSpacing: -0.5,
                ),
              ),
            ],
          ),
          actions: [
            Container(
              margin: const EdgeInsets.only(right: 14),
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
              decoration: BoxDecoration(
                color: const Color(0xFFF0FDF4),
                borderRadius: BorderRadius.circular(100),
                border: Border.all(color: const Color(0xFFDCFCE7), width: 1.5),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.verified_rounded, color: Color(0xFF16A34A), size: 14),
                  const SizedBox(width: 4),
                  Text(
                    _t('verified'),
                    style: GoogleFonts.inter(
                      color: const Color(0xFF15803D),
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ),
          ],
          bottom: TabBar(
            labelColor: const Color(0xFF0F766E),
            unselectedLabelColor: const Color(0xFF64748B),
            indicatorColor: const Color(0xFF0F766E),
            indicatorSize: TabBarIndicatorSize.tab,
            labelStyle: GoogleFonts.inter(fontWeight: FontWeight.bold, fontSize: 13),
            unselectedLabelStyle: GoogleFonts.inter(fontWeight: FontWeight.w600, fontSize: 13),
            tabs: [
              Tab(text: _t('nav_profile')),
              Tab(text: _t('reports_label')),
              Tab(text: _t('receipts_label')),
            ],
          ),
        ),
        body: TabBarView(
          children: [
            _buildProfileTab(),
            _buildReportsTab(),
            _buildReceiptsTab(),
          ],
        ),
      ),
    );
  }

  Widget _buildProfileTab() {
    return """ + body_content.strip() + """;
  }

  Widget _buildReportsTab() {
    return SingleChildScrollView(
      physics: const BouncingScrollPhysics(),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Header Stats card for medical reports
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(0xFF0F766E), Color(0xFF0D9488)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(20),
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFF0D9488).withOpacity(0.2),
                    blurRadius: 12,
                    offset: const Offset(0, 6),
                  ),
                ],
              ),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.2),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.assignment_rounded, color: Colors.white, size: 24),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          _t('medical_reports'),
                          style: GoogleFonts.inter(
                            color: Colors.white,
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          _t('medical_reports_sub'),
                          style: GoogleFonts.inter(
                            color: Colors.white.withOpacity(0.9),
                            fontSize: 12,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ).animate().fade(duration: 400.ms).slideY(begin: 0.1, end: 0, duration: 400.ms),
            const SizedBox(height: 16),

            // Reports List Container
            Container(
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(20),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.02),
                    blurRadius: 10,
                    offset: const Offset(0, 4),
                  ),
                ],
                border: Border.all(color: const Color(0xFFE2E8F0)),
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(20),
                child: Column(
                  children: _reportsJson.map((report) {
                    final isLast = _reportsJson.indexOf(report) == _reportsJson.length - 1;
                    return Column(
                      children: [
                        _buildReportRow(
                          context: context,
                          title: _t(report['title_key']),
                          subtitle: '${_t(report['issuer_key'])}  •  ${report['date']}',
                          status: _t(report['status_key']),
                          doctor: _t(report['doctor_key']),
                        ),
                        if (!isLast) const Divider(height: 1, color: Color(0xFFF1F5F9)),
                      ],
                    );
                  }).toList(),
                ),
              ),
            ).animate().fade(delay: 100.ms, duration: 400.ms).slideY(begin: 0.05, end: 0, duration: 400.ms),
          ],
        ),
      ),
    );
  }

  Widget _buildReportRow({
    required BuildContext context,
    required String title,
    required String subtitle,
    required String status,
    required String doctor,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(
                      title,
                      style: GoogleFonts.inter(
                        fontSize: 13.5,
                        fontWeight: FontWeight.bold,
                        color: const Color(0xFF1E293B),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1.5),
                      decoration: BoxDecoration(
                        color: const Color(0xFFDCFCE7),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        status,
                        style: GoogleFonts.inter(
                          color: const Color(0xFF15803D),
                          fontSize: 8.5,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  subtitle,
                  style: GoogleFonts.inter(
                    fontSize: 11,
                    color: const Color(0xFF64748B),
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  doctor,
                  style: GoogleFonts.inter(
                    fontSize: 11,
                    color: const Color(0xFF0F766E),
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          IconButton(
            onPressed: () {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text('Viewing Report: ' + title + '...'),
                  duration: const Duration(seconds: 1),
                ),
              );
            },
            icon: const Icon(Icons.visibility_outlined, size: 18, color: Color(0xFF0F766E)),
            style: IconButton.styleFrom(
              padding: const EdgeInsets.all(8),
              backgroundColor: const Color(0xFFF0FDF4),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildReceiptsTab() {
    return SingleChildScrollView(
      physics: const BouncingScrollPhysics(),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Header Stats card for receipts
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(0xFFEA580C), Color(0xFFF97316)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(20),
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFFF97316).withOpacity(0.2),
                    blurRadius: 12,
                    offset: const Offset(0, 6),
                  ),
                ],
              ),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.2),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.receipt_long_rounded, color: Colors.white, size: 24),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          _t('billing_history_title'),
                          style: GoogleFonts.inter(
                            color: Colors.white,
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          _t('invoices_paid_offline'),
                          style: GoogleFonts.inter(
                            color: Colors.white.withOpacity(0.9),
                            fontSize: 12,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ).animate().fade(duration: 400.ms).slideY(begin: 0.1, end: 0, duration: 400.ms),
            const SizedBox(height: 16),

            // Receipts List Container
            Container(
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(20),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.02),
                    blurRadius: 10,
                    offset: const Offset(0, 4),
                  ),
                ],
                border: Border.all(color: const Color(0xFFE2E8F0)),
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(20),
                child: Column(
                  children: _receiptsJson.map((receipt) {
                    final isLast = _receiptsJson.indexOf(receipt) == _receiptsJson.length - 1;
                    return Column(
                      children: [
                        _buildReceiptRow(
                          context: context,
                          title: _t(receipt['title_key']),
                          subtitle: '${_t(receipt['issuer_key'])}  •  ${receipt['date']}',
                          amount: receipt['amount'],
                          status: _t(receipt['status_key']),
                          statusColor: const Color(0xFF16A34A),
                        ),
                        if (!isLast) const Divider(height: 1, color: Color(0xFFF1F5F9)),
                      ],
                    );
                  }).toList(),
                ),
              ),
            ).animate().fade(delay: 100.ms, duration: 400.ms).slideY(begin: 0.05, end: 0, duration: 400.ms),
          ],
        ),
      ),
    );
  }

  Widget _buildReceiptRow({
    required BuildContext context,
    required String title,
    required String subtitle,
    required String amount,
    required String status,
    required Color statusColor,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: GoogleFonts.inter(
                    fontSize: 13.5,
                    fontWeight: FontWeight.bold,
                    color: const Color(0xFF1E293B),
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  subtitle,
                  style: GoogleFonts.inter(
                    fontSize: 11,
                    color: const Color(0xFF64748B),
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                amount,
                style: GoogleFonts.inter(
                  fontSize: 13.5,
                  fontWeight: FontWeight.bold,
                  color: const Color(0xFF1E293B),
                ),
              ),
              const SizedBox(height: 2),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1.5),
                decoration: BoxDecoration(
                  color: statusColor.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(
                  status,
                  style: GoogleFonts.inter(
                    color: statusColor,
                    fontSize: 9,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(width: 12),
          IconButton(
            onPressed: () {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text('Viewing Receipt for ' + title + '...'),
                  duration: const Duration(seconds: 1),
                ),
              );
            },
            icon: const Icon(Icons.receipt_long_outlined, size: 18, color: Color(0xFFF97316)),
            style: IconButton.styleFrom(
              padding: const EdgeInsets.all(8),
              backgroundColor: const Color(0xFFFFF7ED),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
          ),
        ],
      ),
    );
  }
"""

final_content = content_with_fields[:pos_build_new] + tabbed_build + content_with_fields[pos_end_build_scaffold+1:]

with open(file_path, 'w', encoding='utf-8') as f:
    f.write(final_content)

print("Scanned Profile Screen refactored successfully!")
