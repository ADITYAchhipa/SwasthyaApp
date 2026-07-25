file_path = '/home/aditya/clones/Card/lib/screens/citizen_portal/scanned_profile_screen.dart'

with open(file_path, 'r', encoding='utf-8') as f:
    content = f.read()

# 1. Remove the mock JSON lists from ScannedProfileScreen definition
# Let's find the start of ScannedProfileScreen and State classes
pos_sps = content.find('class ScannedProfileScreen extends StatefulWidget {')
pos_state = content.find('class _ScannedProfileScreenState extends State<ScannedProfileScreen> {')

# Let's reconstruct the file:
# Keep header up to pos_sps + len('class ScannedProfileScreen extends StatefulWidget {\n  const ScannedProfileScreen({Key? key}) : super(key: key);\n')
# Then @override State<ScannedProfileScreen> ...
# Then class _ScannedProfileScreenState ... {
# Then insert the mock JSON lists inside _ScannedProfileScreenState

header = content[:pos_sps]
sps_class = """class ScannedProfileScreen extends StatefulWidget {
  const ScannedProfileScreen({Key? key}) : super(key: key);

  @override
  State<ScannedProfileScreen> createState() => _ScannedProfileScreenState();
}
"""

state_start = """class _ScannedProfileScreenState extends State<ScannedProfileScreen> {
  String _t(String key) => TranslationService.t(context, key);

  // Expansion states for the 5 sections
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

# Rest of the file starts after state class fields (e.g. after the build method start)
# Let's find `@override\n  Widget build(BuildContext context) {` in the original content
build_pos = content.find('Widget build(BuildContext context) {')
rest_of_file = content[build_pos:]

# Now let's combine:
new_content = header + sps_class + "\n" + state_start + "\n  @override\n  " + rest_of_file

# Also fix the stray ',;' in new_content
new_content = new_content.replace('      ),;', '    );\n  }')

with open(file_path, 'w', encoding='utf-8') as f:
    f.write(new_content)

print("Scanned Profile Screen fixed successfully!")
