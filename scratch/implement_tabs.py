file_path = '/home/aditya/clones/Card/lib/screens/citizen_portal/scanned_profile_screen.dart'

with open(file_path, 'r', encoding='utf-8') as f:
    lines = f.readlines()

# 1. Insert mock JSON lists before '@override\n' (around line 24)
insert_json_idx = -1
for idx, line in enumerate(lines):
    if '@override' in line:
        insert_json_idx = idx
        break

mock_json_code = """  // Mock JSON representing what will come from the backend for receipts
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

if insert_json_idx != -1:
    lines.insert(insert_json_idx, mock_json_code)

# Let's write the modified file to temporary variable/list
# Now we need to update build method to wrap in DefaultTabController and use TabBarView.
# Let's search again in the newly adjusted lines.
# We find where build(BuildContext context) starts.
# We can rebuild lines list.
with open(file_path, 'w', encoding='utf-8') as f:
    f.writelines(lines)

with open(file_path, 'r', encoding='utf-8') as f:
    content = f.read()

# Let's find the start of the build method:
build_start_str = '@override\n  Widget build(BuildContext context) {'
build_start_idx = content.find(build_start_str)

# We want to replace from 'return Scaffold(' down to the closing return statement of the build method (which is right before '// Allergy Badge builder - nice red style')
# Let's find the index of 'return Scaffold('
scaffold_start_idx = content.find('return Scaffold(', build_start_idx)

# The end of the Scaffold is just before '// Allergy Badge builder - nice red style'
allergy_comment_idx = content.find('// Allergy Badge builder - nice red style')

# Let's find the closing statement of build method before allergy_comment_idx
# The closing statement of build method is:
#     );
#   }
# Let's find the last occurrence of '}' before allergy_comment_idx
end_build_idx = content.rfind('}', 0, allergy_comment_idx)
# Let's adjust end_build_idx to include the closing brace
end_build_idx += 1

original_scaffold_body = content[scaffold_start_idx:end_build_idx]

# We want to transform the scaffold body so that:
# 1. return Scaffold( ... ) is changed to return DefaultTabController( length: 3, child: Scaffold( ... appBar: AppBar( ... bottom: TabBar(...), ), body: TabBarView( children: [ _buildProfileTab(), _buildReportsTab(), _buildReceiptsTab() ] ) ) );
# 2. We extract the original body (SingleChildScrollView) into _buildProfileTab()

# Let's find where the body parameter starts in original_scaffold_body
body_param_str = 'body: SingleChildScrollView('
body_param_idx = original_scaffold_body.find(body_param_str)

# The body parameter starts at body_param_idx + len('body: ')
# It goes until the closing parameter of the body, which ends before the closing of Scaffold.
# In original_scaffold_body, the closing of Scaffold is at the end:
#     );
#   }
# Let's find the closing of SingleChildScrollView. Since we know SingleChildScrollView ends with:
#         ),
#       ),
#     );
# Let's search from the end.
# We know the original Scaffold statement ends with:
#     );
# Let's trace back.
# Let's extract the SingleChildScrollView content:
body_content = original_scaffold_body[body_param_idx + len('body: '):]
# Remove the trailing ); and indentation/spaces at the end of body_content to get the clean SingleChildScrollView
# Let's strip trailing whitespace, then remove trailing );
body_content = body_content.rstrip()
if body_content.endswith('}'):
    # The build method ends with:
    #     );
    #   }
    # So body_content ends with:
    #       ),
    #     );
    #   }
    # Let's strip the closing brace of build method, and the trailing );
    # Let's find the closing ); of Scaffold
    scaffold_end_idx = body_content.rfind(');')
    body_content = body_content[:scaffold_end_idx].strip()

# Now let's construct the new build method and helper methods:
new_build_and_tabs = """  @override
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
    return """ + body_content + """;
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
                  content: Text('Viewing Report: $title...'),
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
                  content: Text('Viewing Receipt for $title...'),
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

new_content = content[:build_start_idx] + new_build_and_tabs + content[allergy_comment_idx:]

with open(file_path, 'w', encoding='utf-8') as f:
    f.write(new_content)

print("Scanned Profile Screen modified successfully with TabBar interface!")
