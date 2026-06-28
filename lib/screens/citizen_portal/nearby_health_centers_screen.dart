import 'dart:math';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../../providers/swasthya_tap_provider.dart';
import '../../theme/app_theme.dart';

class HealthCenter {
  final String id;
  final String name;
  final String category; // 'Hospital', 'PHC', 'Blood Bank', 'Pharmacy'
  final double rating;
  final int reviews;
  final String address;
  final double distance;
  final String status; // 'Open Now', 'Closed'
  final String statusDetails;
  final List<String> badges;
  final Offset mapCoords; // Offset relative to map size (0.0 to 1.0)
  final String phone;

  HealthCenter({
    required this.id,
    required this.name,
    required this.category,
    required this.rating,
    required this.reviews,
    required this.address,
    required this.distance,
    required this.status,
    this.statusDetails = '',
    required this.badges,
    required this.mapCoords,
    required this.phone,
  });
}

class NearbyHealthCentersScreen extends StatefulWidget {
  final String initialFilter;

  const NearbyHealthCentersScreen({
    Key? key,
    this.initialFilter = '',
  }) : super(key: key);

  @override
  State<NearbyHealthCentersScreen> createState() => _NearbyHealthCentersScreenState();
}

class _NearbyHealthCentersScreenState extends State<NearbyHealthCentersScreen>
    with TickerProviderStateMixin {
  late AnimationController _pulseController;
  late AnimationController _routeController;
  
  String _selectedCategory = 'All';
  String _searchQuery = '';
  HealthCenter? _selectedCenter;
  bool _isShowingDirections = false;
  final TextEditingController _searchController = TextEditingController();
  final ScrollController _scrollController = ScrollController();

  final List<HealthCenter> _allCenters = [
    HealthCenter(
      id: 'pmch',
      name: 'Patna Medical College & Hospital',
      category: 'Hospital',
      rating: 4.6,
      reviews: 1256,
      address: 'Kankarbagh, Patna, Bihar 800020',
      distance: 0.8,
      status: 'Open Now',
      badges: ['Emergency', 'Blood Bank', 'ICU', 'NFC Cards'],
      mapCoords: const Offset(0.72, 0.28),
      phone: '+91 612 230 0341',
    ),
    HealthCenter(
      id: 'phc_k',
      name: 'PHC Kankarbagh',
      category: 'PHC',
      rating: 4.2,
      reviews: 312,
      address: 'Kankarbagh, Near Govt. School, Patna',
      distance: 1.2,
      status: 'Open Now',
      badges: ['General OPD', 'Maternal Care', 'NFC Cards'],
      mapCoords: const Offset(0.32, 0.68),
      phone: '+91 612 235 1290',
    ),
    HealthCenter(
      id: 'red_cross',
      name: 'Red Cross Blood Bank',
      category: 'Blood Bank',
      rating: 4.7,
      reviews: 892,
      address: 'Fraser Road Area, Patna, Bihar 800001',
      distance: 1.5,
      status: 'Open Now',
      badges: ['Blood Collection', 'Component Separation', '24x7 Support'],
      mapCoords: const Offset(0.24, 0.22),
      phone: '+91 612 222 3198',
    ),
    HealthCenter(
      id: 'wellcare',
      name: 'WellCare Pharmacy',
      category: 'Pharmacy',
      rating: 4.1,
      reviews: 245,
      address: 'Exhibition Road, Patna, Bihar 800001',
      distance: 1.7,
      status: 'Closed',
      statusDetails: 'Opens 8:00 AM',
      badges: ['Medicines', '24x7', 'Home Delivery'],
      mapCoords: const Offset(0.44, 0.62),
      phone: '+91 98765 43210',
    ),
    HealthCenter(
      id: 'patna_blood',
      name: 'Patna Blood Center',
      category: 'Blood Bank',
      rating: 4.5,
      reviews: 142,
      address: 'Bari Path, Near Patna College, Patna 800004',
      distance: 2.1,
      status: 'Open Now',
      badges: ['Single Donor Platelet', 'A+ / B+ Available'],
      mapCoords: const Offset(0.85, 0.58),
      phone: '+91 612 267 0909',
    ),
    HealthCenter(
      id: 'city_medico',
      name: 'City Medico Pharmacy',
      category: 'Pharmacy',
      rating: 4.3,
      reviews: 189,
      address: 'Ashok Rajpath, Near PMCH, Patna',
      distance: 2.3,
      status: 'Open Now',
      badges: ['Emergency Drugs', 'NFC Cards Supported'],
      mapCoords: const Offset(0.88, 0.32),
      phone: '+91 94310 12345',
    ),
  ];

  @override
  void initState() {
    super.initState();
    
    // Set initial filter from quick action if provided
    if (widget.initialFilter.isNotEmpty) {
      _selectedCategory = widget.initialFilter;
    }

    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2000),
    )..repeat();

    _routeController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 3000),
    );
  }

  @override
  void dispose() {
    _pulseController.dispose();
    _routeController.dispose();
    _searchController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  // Filter logic
  List<HealthCenter> get _filteredCenters {
    return _allCenters.where((center) {
      // Category filter match
      bool matchesCategory = true;
      if (_selectedCategory == 'Hospitals') {
        matchesCategory = center.category == 'Hospital';
      } else if (_selectedCategory == 'PHC') {
        matchesCategory = center.category == 'PHC';
      } else if (_selectedCategory == 'Blood Banks') {
        matchesCategory = center.category == 'Blood Bank';
      } else if (_selectedCategory == 'Pharmacy') {
        matchesCategory = center.category == 'Pharmacy';
      } else if (_selectedCategory == 'Emergency') {
        matchesCategory = center.badges.contains('Emergency');
      } else if (_selectedCategory == 'Programs NFC Cards') {
        matchesCategory = center.badges.contains('NFC Cards');
      }

      // Search query match
      bool matchesSearch = true;
      if (_searchQuery.isNotEmpty) {
        final query = _searchQuery.toLowerCase();
        matchesSearch = center.name.toLowerCase().contains(query) ||
            center.address.toLowerCase().contains(query) ||
            center.category.toLowerCase().contains(query);
      }

      return matchesCategory && matchesSearch;
    }).toList();
  }

  void _scrollToCenter(HealthCenter center) {
    setState(() {
      _selectedCenter = center;
      _isShowingDirections = false;
      _routeController.reset();
    });

    final index = _filteredCenters.indexWhere((c) => c.id == center.id);
    if (index != -1) {
      _scrollController.animateTo(
        index * 160.0, // estimated card height + margins
        duration: const Duration(milliseconds: 500),
        curve: Curves.easeInOut,
      );
    }
  }

  void _triggerDirections(HealthCenter center) {
    setState(() {
      _selectedCenter = center;
      _isShowingDirections = true;
    });
    _routeController.reset();
    _routeController.forward();
  }

  // Multi-language translation helper
  String _t(String key, String lang) {
    final translations = {
      'en': {
        'nearby_title': 'Nearby Health Centers',
        'nearby_sub': 'Find hospitals, PHCs, blood banks & pharmacies near you',
        'search_hint': 'Search hospitals, PHCs, blood banks...',
        'all': 'All',
        'hospitals': 'Hospitals',
        'phc': 'PHC',
        'blood_banks': 'Blood Banks',
        'emergency': 'Emergency',
        'nfc_prog': 'Programs NFC Cards',
        'open_now': 'Open Now',
        'closed': 'Closed',
        'call': 'Call',
        'directions': 'Directions',
        'nfc_points_title': 'Looking for NFC Card Distribution Points?',
        'nfc_points_desc': 'Find centers where you can get your SwasthyaTap card.',
        'view_centers': 'View Centers',
        'showing_results': 'Showing results within 10 km of your location',
        'change_loc': 'Change',
        'legend_hospital': 'Hospital',
        'legend_phc': 'PHC',
        'legend_blood': 'Blood Bank',
        'legend_pharmacy': 'Pharmacy',
      },
      'hi': {
        'nearby_title': 'नजदीकी स्वास्थ्य केंद्र',
        'nearby_sub': 'अपने आस-पास के अस्पताल, पीएचसी, ब्लड बैंक और फार्मेसी खोजें',
        'search_hint': 'अस्पताल, पीएचसी, ब्लड बैंक खोजें...',
        'all': 'सभी',
        'hospitals': 'अस्पताल',
        'phc': 'पीएचसी',
        'blood_banks': 'ब्लड बैंक',
        'emergency': 'आपातकाल',
        'nfc_prog': 'एनएफसी कार्ड प्रोग्राम',
        'open_now': 'अभी खुला है',
        'closed': 'बंद है',
        'call': 'कॉल करें',
        'directions': 'दिशा-निर्देश',
        'nfc_points_title': 'NFC कार्ड वितरण केंद्र ढूंढ रहे हैं?',
        'nfc_points_desc': 'वे केंद्र खोजें जहां आप अपना स्वास्य टैप कार्ड प्राप्त कर सकते हैं।',
        'view_centers': 'केंद्र देखें',
        'showing_results': 'आपके स्थान के 10 किमी के भीतर परिणाम दिखाए जा रहे हैं',
        'change_loc': 'बदलें',
        'legend_hospital': 'अस्पताल',
        'legend_phc': 'पीएचसी',
        'legend_blood': 'ब्लड बैंक',
        'legend_pharmacy': 'फार्मेसी',
      }
    };
    return translations[lang]?[key] ?? key;
  }

  Widget _buildVerticalActionButton({
    required IconData icon,
    required String label,
    required VoidCallback onTap,
    bool isPrimary = false,
    Color? activeColor,
  }) {
    final color = activeColor ?? const Color(0xFF475569);
    return Container(
      width: 48,
      height: 48,
      decoration: BoxDecoration(
        color: isPrimary ? color : Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isPrimary ? color : const Color(0xFFE2E8F0),
          width: 1.2,
        ),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(12),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                icon,
                color: isPrimary ? Colors.white : color,
                size: 16,
              ),
              const SizedBox(height: 2),
              Text(
                label,
                style: TextStyle(
                  fontSize: 8,
                  fontWeight: FontWeight.bold,
                  color: isPrimary ? Colors.white : color,
                  height: 1.1,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final provider = Provider.of<SwasthyaTapProvider>(context);
    final lang = provider.selectedLanguage;
    final filtered = _filteredCenters;

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded, color: Color(0xFF0F172A)),
          onPressed: () => Navigator.pop(context),
        ),
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              _t('nearby_title', lang),
              style: GoogleFonts.outfit(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: const Color(0xFF0F172A),
              ),
            ),
            Text(
              _t('nearby_sub', lang),
              style: GoogleFonts.inter(
                fontSize: 11,
                color: const Color(0xFF64748B),
                fontWeight: FontWeight.w400,
              ),
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: Container(
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                color: const Color(0xFFF1F5F9),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.tune_rounded, color: Color(0xFF64748B), size: 18),
            ),
            onPressed: () {},
          ),
          IconButton(
            icon: Container(
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                color: const Color(0xFFF1F5F9),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.format_list_bulleted_rounded, color: Color(0xFF64748B), size: 18),
            ),
            onPressed: () {},
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: Column(
        children: [
          // 1. Search Bar
          Container(
            color: Colors.white,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            child: Container(
              height: 48,
              decoration: BoxDecoration(
                color: const Color(0xFFF1F5F9),
                borderRadius: BorderRadius.circular(24),
              ),
              child: Row(
                children: [
                  const SizedBox(width: 14),
                  const Icon(Icons.search_rounded, color: Color(0xFF64748B), size: 20),
                  const SizedBox(width: 10),
                  Expanded(
                    child: TextField(
                      controller: _searchController,
                      onChanged: (val) {
                        setState(() {
                          _searchQuery = val;
                        });
                      },
                      style: GoogleFonts.inter(fontSize: 14, color: const Color(0xFF0F172A)),
                      decoration: InputDecoration(
                        hintText: _t('search_hint', lang),
                        hintStyle: GoogleFonts.inter(fontSize: 13, color: const Color(0xFF94A3B8)),
                        border: InputBorder.none,
                        isDense: true,
                      ),
                    ),
                  ),
                  if (_searchQuery.isNotEmpty)
                    IconButton(
                      icon: const Icon(Icons.clear_rounded, color: Color(0xFF64748B), size: 18),
                      onPressed: () {
                        setState(() {
                          _searchController.clear();
                          _searchQuery = '';
                        });
                      },
                    ),
                  const Icon(Icons.mic_rounded, color: Color(0xFF64748B), size: 20),
                  const SizedBox(width: 14),
                ],
              ),
            ),
          ),

          // 2. Map Area (occupies standard height)
          Expanded(
            flex: 4,
            child: Stack(
              children: [
                // Simulated Vector Map
                AnimatedBuilder(
                  animation: Listenable.merge([_pulseController, _routeController]),
                  builder: (context, child) {
                    return CustomPaint(
                      painter: PatnaMapPainter(
                        pulseValue: _pulseController.value,
                        routeValue: _routeController.value,
                        selectedCenter: _selectedCenter,
                        isShowingDirections: _isShowingDirections,
                      ),
                      size: Size.infinite,
                    );
                  },
                ),

                // Interactive Pin Markers
                ...filtered.map((center) {
                  final isCenterSelected = _selectedCenter?.id == center.id;
                  
                  // Pin theme values
                  Color pinColor;
                  IconData pinIcon;
                  switch (center.category) {
                    case 'Hospital':
                      pinColor = const Color(0xFF1E40AF); // Blue
                      pinIcon = Icons.local_hospital_rounded;
                      break;
                    case 'PHC':
                      pinColor = const Color(0xFF15803D); // Green
                      pinIcon = Icons.health_and_safety_rounded;
                      break;
                    case 'Blood Bank':
                      pinColor = const Color(0xFFDC2626); // Red
                      pinIcon = Icons.bloodtype_rounded;
                      break;
                    default:
                      pinColor = const Color(0xFFEA580C); // Orange
                      pinIcon = Icons.medication_rounded;
                  }

                  return LayoutBuilder(
                    builder: (context, constraints) {
                      final leftPos = center.mapCoords.dx * constraints.maxWidth - 20;
                      final topPos = center.mapCoords.dy * constraints.maxHeight - 40;

                      return Positioned(
                        left: leftPos,
                        top: topPos,
                        child: GestureDetector(
                          onTap: () => _scrollToCenter(center),
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 250),
                            width: isCenterSelected ? 48 : 38,
                            height: isCenterSelected ? 56 : 46,
                            child: Stack(
                              alignment: Alignment.topCenter,
                              children: [
                                // Marker pin shape
                                Icon(
                                  Icons.location_on_sharp,
                                  color: pinColor,
                                  size: isCenterSelected ? 48 : 38,
                                ),
                                // Inner icon
                                Positioned(
                                  top: isCenterSelected ? 8 : 6,
                                  child: Container(
                                    padding: const EdgeInsets.all(2),
                                    decoration: const BoxDecoration(
                                      color: Colors.white,
                                      shape: BoxShape.circle,
                                    ),
                                    child: Icon(
                                      pinIcon,
                                      color: pinColor,
                                      size: isCenterSelected ? 18 : 14,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      );
                    },
                  );
                }),

                // Map Legend Overlay
                Positioned(
                  bottom: 12,
                  left: 12,
                  right: 12,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.95),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: const Color(0xFFF1F5F9), width: 1.5),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.06),
                          blurRadius: 10,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: Wrap(
                      alignment: WrapAlignment.spaceEvenly,
                      spacing: 10,
                      runSpacing: 4,
                      children: [
                        _buildLegendItem(const Color(0xFF1E40AF), _t('legend_hospital', lang)),
                        _buildLegendItem(const Color(0xFF15803D), _t('legend_phc', lang)),
                        _buildLegendItem(const Color(0xFFDC2626), _t('legend_blood', lang)),
                        _buildLegendItem(const Color(0xFFEA580C), _t('legend_pharmacy', lang)),
                      ],
                    ),
                  ),
                ),

                // Re-locate current position button
                Positioned(
                  bottom: 60,
                  left: 16,
                  child: GestureDetector(
                    onTap: () {
                      setState(() {
                        _selectedCenter = null;
                        _isShowingDirections = false;
                        _routeController.reset();
                      });
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Centered to your location (Civil Lines, Patna)')),
                      );
                    },
                    child: Container(
                      width: 42,
                      height: 42,
                      decoration: BoxDecoration(
                        color: Colors.white,
                        shape: BoxShape.circle,
                        border: Border.all(color: const Color(0xFFF1F5F9), width: 1.5),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.06),
                            blurRadius: 8,
                            offset: const Offset(0, 3),
                          ),
                        ],
                      ),
                      child: const Icon(
                        Icons.my_location_rounded,
                        color: Color(0xFF0F766E),
                        size: 20,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),

          // 3. Category Selector Slider (Sticky header)
          Container(
            color: Colors.white,
            padding: const EdgeInsets.symmetric(vertical: 12),
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Row(
                children: [
                  _buildCategoryChip('All', Icons.grid_view_rounded, Colors.teal),
                  const SizedBox(width: 8),
                  _buildCategoryChip('Hospitals', Icons.local_hospital_rounded, const Color(0xFF1E40AF)),
                  const SizedBox(width: 8),
                  _buildCategoryChip('PHC', Icons.health_and_safety_rounded, const Color(0xFF15803D)),
                  const SizedBox(width: 8),
                  _buildCategoryChip('Blood Banks', Icons.bloodtype_rounded, const Color(0xFFDC2626)),
                  const SizedBox(width: 8),
                  _buildCategoryChip('Emergency', Icons.emergency_rounded, const Color(0xFFEF4444)),
                  const SizedBox(width: 8),
                  _buildCategoryChip('Programs NFC Cards', Icons.nfc_rounded, const Color(0xFF8B5CF6)),
                ],
              ),
            ),
          ),

          // 4. Scrollable List of Cards (occupies bottom portion)
          Expanded(
            flex: 5,
            child: ListView.builder(
              controller: _scrollController,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              itemCount: filtered.length + 1,
              itemBuilder: (context, index) {
                // Return bottom banner at the very end
                if (index == filtered.length) {
                  return Column(
                    children: [
                      _buildNfcBanner(lang),
                      const SizedBox(height: 12),
                      _buildFooterLocation(lang),
                      const SizedBox(height: 24),
                    ],
                  );
                }

                final center = filtered[index];
                final isSelected = _selectedCenter?.id == center.id;

                Color categoryColor;
                IconData categoryIcon;
                switch (center.category) {
                  case 'Hospital':
                    categoryColor = const Color(0xFF1E40AF);
                    categoryIcon = Icons.local_hospital_rounded;
                    break;
                  case 'PHC':
                    categoryColor = const Color(0xFF15803D);
                    categoryIcon = Icons.health_and_safety_rounded;
                    break;
                  case 'Blood Bank':
                    categoryColor = const Color(0xFFDC2626);
                    categoryIcon = Icons.bloodtype_rounded;
                    break;
                  default:
                    categoryColor = const Color(0xFFEA580C);
                    categoryIcon = Icons.medication_rounded;
                }

                return AnimatedContainer(
                  duration: const Duration(milliseconds: 250),
                  margin: const EdgeInsets.only(bottom: 12),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: isSelected ? categoryColor : const Color(0xFFF1F5F9),
                      width: isSelected ? 2 : 1.5,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: isSelected 
                            ? categoryColor.withOpacity(0.04) 
                            : Colors.black.withOpacity(0.02),
                        blurRadius: 10,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(14),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Left: Icon Block
                        Container(
                          width: 48,
                          height: 48,
                          decoration: BoxDecoration(
                            color: categoryColor.withOpacity(0.08),
                            borderRadius: BorderRadius.circular(16),
                          ),
                          child: Icon(categoryIcon, color: categoryColor, size: 24),
                        ),
                        const SizedBox(width: 14),

                        // Middle: Text & Badges
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              // Title and Category Badge (wrapped beautifully)
                              Wrap(
                                crossAxisAlignment: WrapCrossAlignment.center,
                                spacing: 6,
                                runSpacing: 4,
                                children: [
                                  Text(
                                    center.name,
                                    style: GoogleFonts.inter(
                                      fontSize: 14.5,
                                      fontWeight: FontWeight.bold,
                                      color: const Color(0xFF0F172A),
                                    ),
                                  ),
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                    decoration: BoxDecoration(
                                      color: categoryColor.withOpacity(0.08),
                                      borderRadius: BorderRadius.circular(4),
                                    ),
                                    child: Text(
                                      center.category,
                                      style: TextStyle(
                                        fontSize: 9,
                                        fontWeight: FontWeight.bold,
                                        color: categoryColor,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 6),

                              // Rating and reviews
                              Row(
                                children: [
                                  const Icon(Icons.star_rounded, color: Color(0xFFF59E0B), size: 14),
                                  const SizedBox(width: 2),
                                  Text(
                                    '${center.rating}',
                                    style: GoogleFonts.inter(
                                      fontSize: 11.5,
                                      fontWeight: FontWeight.bold,
                                      color: const Color(0xFF0F172A),
                                    ),
                                  ),
                                  const SizedBox(width: 4),
                                  Text(
                                    '(${center.reviews})',
                                    style: GoogleFonts.inter(
                                      fontSize: 11.5,
                                      color: const Color(0xFF64748B),
                                      fontWeight: FontWeight.w400,
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 6),

                              // Address
                              Text(
                                center.address,
                                style: GoogleFonts.inter(
                                  fontSize: 11.5,
                                  color: const Color(0xFF64748B),
                                  height: 1.3,
                                ),
                              ),
                              const SizedBox(height: 10),

                              // Badges Wrap
                              Wrap(
                                spacing: 4,
                                runSpacing: 4,
                                children: [
                                  ...center.badges.map((badge) {
                                    Color badgeBg;
                                    Color badgeText;
                                    IconData? badgeIcon;
                                    
                                    if (badge == 'Emergency') {
                                      badgeBg = const Color(0xFFFEE2E2);
                                      badgeText = const Color(0xFFDC2626);
                                      badgeIcon = Icons.emergency_rounded;
                                    } else if (badge == 'Blood Bank' || badge == 'Blood Collection') {
                                      badgeBg = const Color(0xFFFEE2E2);
                                      badgeText = const Color(0xFFDC2626);
                                      badgeIcon = Icons.bloodtype_rounded;
                                    } else if (badge == 'NFC Cards') {
                                      badgeBg = const Color(0xFFF3E8FF);
                                      badgeText = const Color(0xFF7C3AED);
                                      badgeIcon = Icons.nfc_rounded;
                                    } else {
                                      badgeBg = const Color(0xFFF1F5F9);
                                      badgeText = const Color(0xFF475569);
                                    }

                                    return Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                      decoration: BoxDecoration(
                                        color: badgeBg,
                                        borderRadius: BorderRadius.circular(6),
                                      ),
                                      child: Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          if (badgeIcon != null) ...[
                                            Icon(badgeIcon, color: badgeText, size: 9),
                                            const SizedBox(width: 2),
                                          ],
                                          Text(
                                            badge,
                                            style: TextStyle(
                                              fontSize: 9,
                                              fontWeight: FontWeight.bold,
                                              color: badgeText,
                                            ),
                                          ),
                                        ],
                                      ),
                                    );
                                  }),
                                ],
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 14),

                        // Right: Distance, Status & Quick Action Buttons
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text(
                                  '${center.distance} km',
                                  style: GoogleFonts.outfit(
                                    fontSize: 13,
                                    fontWeight: FontWeight.bold,
                                    color: const Color(0xFF0F172A),
                                  ),
                                ),
                                const SizedBox(width: 6),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2.5),
                                  decoration: BoxDecoration(
                                    color: center.status == 'Open Now'
                                        ? const Color(0xFFDCFCE7)
                                        : const Color(0xFFFEE2E2),
                                    borderRadius: BorderRadius.circular(6),
                                  ),
                                  child: Text(
                                    center.status == 'Open Now'
                                        ? _t('open_now', lang)
                                        : _t('closed', lang),
                                    style: TextStyle(
                                      fontSize: 8.5,
                                      fontWeight: FontWeight.bold,
                                      color: center.status == 'Open Now'
                                          ? const Color(0xFF15803D)
                                          : const Color(0xFFDC2626),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            if (center.statusDetails.isNotEmpty) ...[
                              const SizedBox(height: 2),
                              Text(
                                center.statusDetails,
                                style: GoogleFonts.inter(
                                  fontSize: 8.5,
                                  color: const Color(0xFFDC2626),
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ],
                            const SizedBox(height: 12),

                            // Actions buttons (Call / Directions)
                            Row(
                              children: [
                                _buildVerticalActionButton(
                                  icon: Icons.phone_rounded,
                                  label: _t('call', lang),
                                  onTap: () {
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      SnackBar(content: Text('Calling ${center.name}: ${center.phone}')),
                                    );
                                  },
                                  activeColor: const Color(0xFF0F766E),
                                ),
                                const SizedBox(width: 8),
                                _buildVerticalActionButton(
                                  icon: Icons.navigation_rounded,
                                  label: _t('directions', lang),
                                  onTap: () => _triggerDirections(center),
                                  isPrimary: isSelected,
                                  activeColor: categoryColor,
                                ),
                              ],
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLegendItem(Color color, String label) {
    return Row(
      children: [
        Container(
          width: 8,
          height: 8,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(width: 6),
        Text(
          label,
          style: GoogleFonts.inter(
            fontSize: 10,
            color: const Color(0xFF475569),
            fontWeight: FontWeight.bold,
          ),
        ),
      ],
    );
  }

  Widget _buildCategoryChip(String label, IconData icon, Color color) {
    final isSelected = _selectedCategory == label;
    return GestureDetector(
      onTap: () {
        setState(() {
          _selectedCategory = label;
          _selectedCenter = null;
          _isShowingDirections = false;
          _routeController.reset();
        });
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected ? color : Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isSelected ? color : const Color(0xFFE2E8F0),
            width: 1.2,
          ),
          boxShadow: isSelected
              ? [
                  BoxShadow(
                    color: color.withOpacity(0.2),
                    blurRadius: 8,
                    offset: const Offset(0, 3),
                  ),
                ]
              : null,
        ),
        child: Row(
          children: [
            Icon(
              icon,
              color: isSelected ? Colors.white : const Color(0xFF64748B),
              size: 14,
            ),
            const SizedBox(width: 6),
            Text(
              label,
              style: GoogleFonts.inter(
                fontSize: 12,
                fontWeight: FontWeight.bold,
                color: isSelected ? Colors.white : const Color(0xFF475569),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildNfcBanner(String lang) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFFF3E8FF),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE9D5FF), width: 1),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: const Color(0xFFC084FC).withOpacity(0.2),
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.nfc_rounded, color: Color(0xFF7C3AED), size: 22),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _t('nfc_points_title', lang),
                  style: GoogleFonts.inter(
                    fontSize: 13,
                    fontWeight: FontWeight.bold,
                    color: const Color(0xFF581C87),
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  _t('nfc_points_desc', lang),
                  style: GoogleFonts.inter(
                    fontSize: 11,
                    color: const Color(0xFF7E22CE),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          ElevatedButton(
            onPressed: () {
              setState(() {
                _selectedCategory = 'Programs NFC Cards';
              });
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF7C3AED),
              elevation: 0,
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
            child: Text(
              _t('view_centers', lang),
              style: const TextStyle(fontSize: 11, color: Colors.white, fontWeight: FontWeight.bold),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFooterLocation(String lang) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        const Icon(Icons.location_on_rounded, color: Color(0xFF64748B), size: 13),
        const SizedBox(width: 4),
        Text(
          _t('showing_results', lang),
          style: GoogleFonts.inter(
            fontSize: 10.5,
            color: const Color(0xFF64748B),
            fontWeight: FontWeight.w500,
          ),
        ),
        const SizedBox(width: 6),
        GestureDetector(
          onTap: () {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Location options screen coming soon')),
            );
          },
          child: Text(
            _t('change_loc', lang),
            style: GoogleFonts.inter(
              fontSize: 10.5,
              color: const Color(0xFF0F766E),
              fontWeight: FontWeight.bold,
              decoration: TextDecoration.underline,
            ),
          ),
        ),
      ],
    );
  }
}

// Custom Painter to draw stylized map of Patna
class PatnaMapPainter extends CustomPainter {
  final double pulseValue;
  final double routeValue;
  final HealthCenter? selectedCenter;
  final bool isShowingDirections;

  PatnaMapPainter({
    required this.pulseValue,
    required this.routeValue,
    required this.selectedCenter,
    required this.isShowingDirections,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final width = size.width;
    final height = size.height;

    // 1. Draw Land Background (soft off-white)
    final bgPaint = Paint()..color = const Color(0xFFF1F5F9);
    canvas.drawRect(Rect.fromLTWH(0, 0, width, height), bgPaint);

    // 2. Draw Ganga River (sky blue curve at top-right)
    final riverPaint = Paint()
      ..color = const Color(0xFFE0F2FE)
      ..style = PaintingStyle.fill;

    final riverPath = Path()
      ..moveTo(width * 0.40, 0)
      ..cubicTo(
        width * 0.55, height * 0.15,
        width * 0.70, height * 0.20,
        width, height * 0.45,
      )
      ..lineTo(width, 0)
      ..close();

    canvas.drawPath(riverPath, riverPaint);

    // River wave borders
    final riverBorderPaint = Paint()
      ..color = const Color(0xFFBAE6FD)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.0;

    final riverBorderPath = Path()
      ..moveTo(width * 0.40, 0)
      ..cubicTo(
        width * 0.55, height * 0.15,
        width * 0.70, height * 0.20,
        width, height * 0.45,
      );
    canvas.drawPath(riverBorderPath, riverBorderPaint);

    // 3. Draw Green Spaces (Gandhi Maidan & Parks)
    final parkPaint = Paint()
      ..color = const Color(0xFFDCFCE7)
      ..style = PaintingStyle.fill;
    
    final parkBorderPaint = Paint()
      ..color = const Color(0xFFBBF7D0)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.0;

    // Gandhi Maidan (Large green oval/capsule center-left)
    final maidanRect = Rect.fromLTWH(width * 0.28, height * 0.38, width * 0.15, height * 0.16);
    canvas.drawOval(maidanRect, parkPaint);
    canvas.drawOval(maidanRect, parkBorderPaint);

    // Patna University Park
    final univParkRect = Rect.fromLTWH(width * 0.65, height * 0.25, width * 0.10, height * 0.08);
    canvas.drawRect(univParkRect, parkPaint);
    canvas.drawRect(univParkRect, parkBorderPaint);

    // Shastri Nagar Park
    final shastriParkRect = Rect.fromLTWH(width * 0.12, height * 0.15, width * 0.08, height * 0.08);
    canvas.drawRect(shastriParkRect, parkPaint);
    canvas.drawRect(shastriParkRect, parkBorderPaint);

    // 4. Draw Primary Roads
    final roadCasingPaint = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeWidth = 7.0;

    final roadCorePaint = Paint()
      ..color = const Color(0xFFE2E8F0)
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeWidth = 4.0;

    // Draw main streets paths
    final roadsPath = Path();
    
    // Ashok Rajpath (running along the river)
    roadsPath.moveTo(width * 0.35, height * 0.05);
    roadsPath.cubicTo(
      width * 0.50, height * 0.20,
      width * 0.65, height * 0.25,
      width * 0.95, height * 0.40,
    );

    // Bypass/Main Road (bottom diagonal)
    roadsPath.moveTo(0, height * 0.85);
    roadsPath.lineTo(width, height * 0.70);

    // Civil Lines Road (vertical-ish connecting Shastri Nagar to Gandhi Maidan)
    roadsPath.moveTo(width * 0.15, height * 0.10);
    roadsPath.lineTo(width * 0.35, height * 0.45);
    roadsPath.lineTo(width * 0.45, height * 0.45);

    // Kankarbagh Road (connecting Gandhi Maidan down to Kankarbagh/Bypass)
    roadsPath.moveTo(width * 0.38, height * 0.48);
    roadsPath.quadraticBezierTo(width * 0.42, height * 0.60, width * 0.30, height * 0.80);

    canvas.drawPath(roadsPath, roadCasingPaint);
    canvas.drawPath(roadsPath, roadCorePaint);

    // 5. Text labels (Styled softly)
    _drawMapText(canvas, width * 0.80, height * 0.10, 'Ganga River', Colors.blue.shade600, 11, true);
    _drawMapText(canvas, width * 0.15, height * 0.12, 'Shastri Nagar', const Color(0xFF64748B), 9.5, false);
    _drawMapText(canvas, width * 0.30, height * 0.28, 'Civil Lines', const Color(0xFF64748B), 9.5, false);
    _drawMapText(canvas, width * 0.75, height * 0.18, 'Treatment Nagar', const Color(0xFF64748B), 9.5, false);
    _drawMapText(canvas, width * 0.28, height * 0.56, 'Gandhi Maidan', const Color(0xFF15803D), 10, true);
    _drawMapText(canvas, width * 0.63, height * 0.34, 'Patna University', const Color(0xFF64748B), 9.5, false);
    _drawMapText(canvas, width * 0.10, height * 0.75, 'Kankarbagh', const Color(0xFF64748B), 9.5, false);

    // 6. User Current Location (Civil Lines: 0.48, 0.40)
    final userX = 0.48 * width;
    final userY = 0.40 * height;

    // Pulsing aura
    final auraPaint = Paint()
      ..color = const Color(0xFF2563EB).withOpacity(0.15 * (1.0 - pulseValue))
      ..style = PaintingStyle.fill;
    canvas.drawCircle(Offset(userX, userY), 8 + 24 * pulseValue, auraPaint);

    // Outer ring
    final outerRingPaint = Paint()
      ..color = const Color(0xFF2563EB).withOpacity(0.6)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5;
    canvas.drawCircle(Offset(userX, userY), 8, outerRingPaint);

    // Inner Solid Blue Dot
    final userDotPaint = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.fill;
    canvas.drawCircle(Offset(userX, userY), 6.5, userDotPaint);

    final userCorePaint = Paint()
      ..color = const Color(0xFF2563EB)
      ..style = PaintingStyle.fill;
    canvas.drawCircle(Offset(userX, userY), 4.5, userCorePaint);

    // 7. Route Path Rendering
    if (isShowingDirections && selectedCenter != null) {
      final start = Offset(userX, userY);
      final dest = Offset(selectedCenter!.mapCoords.dx * width, selectedCenter!.mapCoords.dy * height);

      // Create Route Segments (city grids routing mockup)
      final mid1 = Offset(start.dx + (dest.dx - start.dx) * 0.4, start.dy);
      final mid2 = Offset(start.dx + (dest.dx - start.dx) * 0.7, start.dy + (dest.dy - start.dy) * 0.6);
      
      final routePath = Path()
        ..moveTo(start.dx, start.dy)
        ..lineTo(mid1.dx, mid1.dy)
        ..lineTo(mid2.dx, mid2.dy)
        ..lineTo(dest.dx, dest.dy);

      // Draw Path Shadow / Background Glow
      final routeGlowPaint = Paint()
        ..color = const Color(0xFF0F766E).withOpacity(0.2)
        ..style = PaintingStyle.stroke
        ..strokeCap = StrokeCap.round
        ..strokeWidth = 6.0;
      canvas.drawPath(routePath, routeGlowPaint);

      // Draw Path Casing / Line
      final routePaint = Paint()
        ..color = const Color(0xFF0F766E)
        ..style = PaintingStyle.stroke
        ..strokeCap = StrokeCap.round
        ..strokeWidth = 3.0;

      // Make it dashed
      _drawDashedPath(canvas, routePath, routePaint, 5.0, 4.0);

      // Draw Animated Pulse indicator moving along the path
      final pathMetrics = routePath.computeMetrics();
      for (final metric in pathMetrics) {
        final length = metric.length;
        final currentPos = metric.getTangentForOffset(length * routeValue);
        if (currentPos != null) {
          final runnerPaint = Paint()
            ..color = Colors.white
            ..style = PaintingStyle.fill;
          canvas.drawCircle(currentPos.position, 6, runnerPaint);

          final runnerCorePaint = Paint()
            ..color = const Color(0xFF0D9488)
            ..style = PaintingStyle.fill;
          canvas.drawCircle(currentPos.position, 4, runnerCorePaint);
        }
      }
    }
  }

  void _drawDashedPath(Canvas canvas, Path path, Paint paint, double dashWidth, double dashSpace) {
    final pathMetrics = path.computeMetrics();
    for (final metric in pathMetrics) {
      double distance = 0.0;
      while (distance < metric.length) {
        final dashPath = metric.extractPath(distance, min(distance + dashWidth, metric.length));
        canvas.drawPath(dashPath, paint);
        distance += dashWidth + dashSpace;
      }
    }
  }

  void _drawMapText(Canvas canvas, double x, double y, String text, Color color, double size, bool isBold) {
    final textPainter = TextPainter(
      text: TextSpan(
        text: text,
        style: GoogleFonts.inter(
          fontSize: size,
          fontWeight: isBold ? FontWeight.bold : FontWeight.w500,
          color: color.withOpacity(0.85),
          shadows: const [
            Shadow(
              color: Colors.white,
              offset: Offset(0, 1),
              blurRadius: 2.0,
            ),
          ],
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();

    textPainter.paint(canvas, Offset(x - textPainter.width / 2, y - textPainter.height / 2));
  }

  @override
  bool shouldRepaint(covariant PatnaMapPainter oldDelegate) {
    return oldDelegate.pulseValue != pulseValue ||
        oldDelegate.routeValue != routeValue ||
        oldDelegate.selectedCenter != selectedCenter ||
        oldDelegate.isShowingDirections != isShowingDirections;
  }
}
