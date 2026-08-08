import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:geolocator/geolocator.dart';
import 'package:geolocator_android/geolocator_android.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:http/http.dart' as http;
import 'package:latlong2/latlong.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:provider/provider.dart';
import '../../providers/swasthya_tap_provider.dart';
import '../../services/api_service.dart';
import '../../services/geolocation/geolocation_service.dart';
import '../../theme/app_theme.dart';

class HealthCenter {
  final String id;
  final String name;
  final String category; // 'Hospital', 'PHC', 'Blood Bank'
  final double rating;
  final int reviews;
  final String address;
  final double distance;
  final String status; // 'Open Now', 'Closed'
  final String statusDetails;
  final List<String> badges;
  final LatLng latLng; // Real GPS coordinates
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
    required this.latLng,
    required this.phone,
  });

  String formatDistance(LatLng from) {
    final km = const Distance().as(LengthUnit.Kilometer, from, latLng);
    if (km < 1.0) {
      final meters = (km * 1000).round();
      return '$meters m';
    }
    return '${km.toStringAsFixed(1)} km';
  }

  double rawDistanceInKm(LatLng from) {
    return const Distance().as(LengthUnit.Kilometer, from, latLng);
  }
}

class NearbyHealthCentersScreen extends StatefulWidget {
  final String? initialFilter;

  const NearbyHealthCentersScreen({
    Key? key,
    this.initialFilter = '',
  }) : super(key: key);

  @override
  State<NearbyHealthCentersScreen> createState() => _NearbyHealthCentersScreenState();
}

class _NearbyHealthCentersScreenState extends State<NearbyHealthCentersScreen> {
  String _selectedCategory = 'All';
  String _searchQuery = '';
  HealthCenter? _selectedCenter;
  bool _isShowingDirections = false;
  final TextEditingController _searchController = TextEditingController();
  final ScrollController _scrollController = ScrollController();

  final MapController _mapController = MapController();
  StreamSubscription? _positionSubscription;

  // Default to central India/Patna; updated once GPS resolves
  LatLng _userLocation = const LatLng(25.6133, 85.1331);
  bool _locationLoaded = false;
  bool _mapReady = false;
  bool _locationManuallySet = false; // user tapped to override GPS
  bool _isSettingLocation = false;   // tap-to-set mode active

  // Dynamic backend data state
  bool _isLoadingCenters = true;
  List<HealthCenter> _allCenters = [];

  // Road Routing & Turn-by-Turn Directions state
  bool _isLoadingRoute = false;
  List<LatLng> _routePoints = [];
  String _routeDistanceText = '';
  String _routeDurationText = '';

  // ValueNotifier for 60fps lag-free dragging without rebuilding the map
  ValueNotifier<double>? _panelRatioNotifierInstance;
  ValueNotifier<double> get _panelRatioNotifier =>
      _panelRatioNotifierInstance ??= ValueNotifier<double>(0.45);

  double _dragStartY = 0.0;
  double _startPanelRatio = 0.45;
  bool get _isFullScreenMap => _panelRatioNotifier.value <= 0.12;

  @override
  void initState() {
    super.initState();
    _panelRatioNotifierInstance = ValueNotifier<double>(0.45);
    if (widget.initialFilter != null && widget.initialFilter!.trim().isNotEmpty) {
      _selectedCategory = widget.initialFilter!;
    }

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _fetchLocation();
      _fetchBackendCenters();
    });
  }

  void _toggleFullScreen() {
    if (_panelRatioNotifier.value > 0.12) {
      _panelRatioNotifier.value = 0.08;
    } else {
      _panelRatioNotifier.value = 0.45;
    }
  }



  Future<void> _fetchLocation() async {
    try {
      final location = await getUserLocation();
      if (!mounted) return;
      if (location != null) {
        debugPrint('GPS initial fix: ${location.lat}, ${location.lng}');
        setState(() {
          _userLocation = LatLng(location.lat, location.lng);
          _locationLoaded = true;
          _isSettingLocation = false;
        });
        if (_mapReady && !_locationManuallySet) {
          _mapController.move(_userLocation, 15.0);
        }
      }
      // Start live high-precision stream for meter-level accuracy
      _startLocationUpdates();
    } catch (e) {
      debugPrint('Geolocation error: $e');
    }
  }

  void _startLocationUpdates() {
    try {
      _positionSubscription?.cancel();
      _positionSubscription = watchUserLocation().listen((loc) {
        if (!mounted || _locationManuallySet) return;
        debugPrint('NearbyHealthCenters Live GPS -> ${loc.lat}, ${loc.lng}');
        setState(() {
          _userLocation = LatLng(loc.lat, loc.lng);
          _locationLoaded = true;
        });
        if (_mapReady && !_locationManuallySet) {
          _mapController.move(_userLocation, _mapController.camera.zoom);
        }
      });
    } catch (e) {
      debugPrint('Location stream error: $e');
    }
  }

  /// Fetches real health centers from the backend database for Hospitals, PHCs, and Blood Banks
  Future<void> _fetchBackendCenters() async {
    setState(() => _isLoadingCenters = true);
    try {
      final results = await Future.wait([
        ApiService.getHospitals(),
        ApiService.getPhcs(),
        ApiService.getBloodBanks(),
      ]);

      final List<HealthCenter> centers = [];

      // 1. Process Hospitals from Backend Table
      final hospitals = results[0];
      for (final h in hospitals) {
        final lat = (h['lat'] as num?)?.toDouble() ?? 25.6188;
        final lng = (h['lng'] as num?)?.toDouble() ?? 85.1532;
        final latLng = LatLng(lat, lng);
        final dist = const Distance().as(LengthUnit.Kilometer, _userLocation, latLng);

        final badgesList = <String>[];
        if (h['badges'] is List) {
          for (final b in (h['badges'] as List)) {
            if (b != null) badgesList.add(b.toString());
          }
        } else if (h['specialties'] is List) {
          for (final b in (h['specialties'] as List).take(3)) {
            if (b != null) badgesList.add(b.toString());
          }
        }

        centers.add(
          HealthCenter(
            id: (h['hospitalId'] ?? h['_id'] ?? 'HOSP-${centers.length + 1}').toString(),
            name: (h['name'] ?? 'Hospital').toString(),
            category: 'Hospital',
            rating: (h['rating'] as num?)?.toDouble() ?? 4.6,
            reviews: (h['reviews'] as num?)?.toInt() ?? 1200,
            address: (h['address'] ?? 'City Medical Center').toString(),
            distance: dist,
            status: (h['status'] ?? 'Open Now').toString(),
            statusDetails: (h['statusDetails'] ?? '24x7 Emergency Services').toString(),
            badges: badgesList.isNotEmpty ? badgesList : ['Emergency', 'ICU', 'NFC Cards'],
            latLng: latLng,
            phone: (h['phone'] ?? h['registeredPhone'] ?? '+91 80 2699 5000').toString(),
          ),
        );
      }

      // 2. Process PHCs from Backend Table
      final phcs = results[1];
      for (final p in phcs) {
        final lat = (p['lat'] as num?)?.toDouble() ?? 25.5987;
        final lng = (p['lng'] as num?)?.toDouble() ?? 85.1356;
        final latLng = LatLng(lat, lng);
        final dist = const Distance().as(LengthUnit.Kilometer, _userLocation, latLng);

        final badgesList = <String>[];
        if (p['badges'] is List) {
          for (final b in (p['badges'] as List)) {
            if (b != null) badgesList.add(b.toString());
          }
        }

        centers.add(
          HealthCenter(
            id: (p['phcId'] ?? p['_id'] ?? 'PHC-${centers.length + 1}').toString(),
            name: (p['name'] ?? 'Primary Health Centre').toString(),
            category: 'PHC',
            rating: (p['rating'] as num?)?.toDouble() ?? 4.3,
            reviews: (p['reviews'] as num?)?.toInt() ?? 250,
            address: (p['address'] ?? 'Primary Health Center').toString(),
            distance: dist,
            status: (p['status'] ?? 'Open Now').toString(),
            statusDetails: (p['statusDetails'] ?? 'General OPD, Immunization').toString(),
            badges: badgesList.isNotEmpty ? badgesList : ['General OPD', 'Vaccination Center'],
            latLng: latLng,
            phone: (p['phone'] ?? '+91 612 235 1290').toString(),
          ),
        );
      }

      // 3. Process Blood Banks from Backend Table
      final bloodBanks = results[2];
      for (final b in bloodBanks) {
        final lat = (b['lat'] as num?)?.toDouble() ?? 25.6165;
        final lng = (b['lng'] as num?)?.toDouble() ?? 85.1426;
        final latLng = LatLng(lat, lng);
        final dist = const Distance().as(LengthUnit.Kilometer, _userLocation, latLng);

        final badgesList = <String>[];
        if (b['badges'] is List) {
          for (final bg in (b['badges'] as List)) {
            if (bg != null) badgesList.add(bg.toString());
          }
        } else if (b['availableGroups'] is List) {
          for (final g in (b['availableGroups'] as List).take(3)) {
            if (g != null) badgesList.add('$g Available');
          }
        }

        centers.add(
          HealthCenter(
            id: (b['bloodBankId'] ?? b['_id'] ?? 'BB-${centers.length + 1}').toString(),
            name: (b['name'] ?? 'Blood Bank').toString(),
            category: 'Blood Bank',
            rating: (b['rating'] as num?)?.toDouble() ?? 4.7,
            reviews: (b['reviews'] as num?)?.toInt() ?? 890,
            address: (b['address'] ?? 'Blood Transfusion Center').toString(),
            distance: dist,
            status: (b['status'] ?? 'Open Now').toString(),
            statusDetails: (b['statusDetails'] ?? '24x7 Emergency Blood Supply').toString(),
            badges: badgesList.isNotEmpty ? badgesList : ['Platelets Apheresis', '24x7 Support'],
            latLng: latLng,
            phone: (b['phone'] ?? '+91 612 222 3198').toString(),
          ),
        );
      }

      // If backend returned items, update state; otherwise use default fallback centers
      if (centers.isNotEmpty) {
        setState(() {
          _allCenters = centers;
          _isLoadingCenters = false;
        });
      } else {
        _loadFallbackCenters();
      }
    } catch (e) {
      debugPrint('Error fetching backend centers: $e');
      _loadFallbackCenters();
    }
  }

  void _loadFallbackCenters() {
    setState(() {
      _allCenters = [
        HealthCenter(
          id: 'pmch',
          name: 'Patna Medical College & Hospital (PMCH)',
          category: 'Hospital',
          rating: 4.6,
          reviews: 1256,
          address: 'Ashok Rajpath, Near PMCH Campus, Patna',
          distance: 0.8,
          status: 'Open Now',
          statusDetails: '24x7 Emergency, Trauma Care & ICU',
          badges: ['Emergency', 'ICU', 'NFC Cards'],
          latLng: const LatLng(25.6188, 85.1532),
          phone: '+91 612 230 0341',
        ),
        HealthCenter(
          id: 'aiims_p',
          name: 'AIIMS Patna',
          category: 'Hospital',
          rating: 4.8,
          reviews: 2430,
          address: 'Phulwari Sharif, Patna, Bihar 801507',
          distance: 4.5,
          status: 'Open Now',
          statusDetails: 'Super Specialty, Trauma, Organ Transplant',
          badges: ['Super Specialty', '24x7 Emergency', 'NFC Supported'],
          latLng: const LatLng(25.5615, 85.0442),
          phone: '+91 612 245 1070',
        ),
        HealthCenter(
          id: 'phc_k',
          name: 'PHC Kankarbagh',
          category: 'PHC',
          rating: 4.2,
          reviews: 312,
          address: 'Near Govt High School, Kankarbagh, Patna, Bihar 800020',
          distance: 1.2,
          status: 'Open Now',
          statusDetails: 'General OPD, Immunization, Maternal Health',
          badges: ['General OPD', 'Vaccination Center', 'Ayushman Bharat'],
          latLng: const LatLng(25.5987, 85.1356),
          phone: '+91 612 235 1290',
        ),
        HealthCenter(
          id: 'phc_r',
          name: 'PHC Rajendra Nagar',
          category: 'PHC',
          rating: 4.3,
          reviews: 245,
          address: 'Road No. 12, Rajendra Nagar, Patna, Bihar 800016',
          distance: 1.8,
          status: 'Open Now',
          statusDetails: 'Primary Healthcare, Essential Drugs, Lab Tests',
          badges: ['Free Medicines', 'Maternity Care'],
          latLng: const LatLng(25.6042, 85.1585),
          phone: '+91 612 268 4410',
        ),
        HealthCenter(
          id: 'red_cross',
          name: 'Red Cross Society Blood Bank Patna',
          category: 'Blood Bank',
          rating: 4.7,
          reviews: 892,
          address: 'Gandhi Maidan North, Fraser Road, Patna, Bihar 800001',
          distance: 1.5,
          status: 'Open Now',
          statusDetails: '24x7 Voluntary Blood Bank & Component Separation',
          badges: ['Platelets Apheresis', '24x7 Support', 'Voluntary Donor Registry'],
          latLng: const LatLng(25.6165, 85.1426),
          phone: '+91 612 222 3198',
        ),
        HealthCenter(
          id: 'pmch_bb',
          name: 'PMCH Model Blood Bank',
          category: 'Blood Bank',
          rating: 4.5,
          reviews: 650,
          address: 'PMCH Campus, Ashok Rajpath, Patna 800004',
          distance: 2.1,
          status: 'Open Now',
          statusDetails: 'Government Central Blood Transfusion Centre',
          badges: ['Government Central', 'Component Facility'],
          latLng: const LatLng(25.6192, 85.1540),
          phone: '+91 612 230 0345',
        ),
      ];
      _isLoadingCenters = false;
    });
  }

  @override
  void dispose() {
    _positionSubscription?.cancel();
    _mapController.dispose();
    _searchController.dispose();
    _scrollController.dispose();
    _panelRatioNotifierInstance?.dispose();
    super.dispose();
  }

  // Filter & Sort logic (Ascending order according to distance)
  List<HealthCenter> get _filteredCenters {
    final list = _allCenters.where((center) {
      // Category filter match
      bool matchesCategory = true;
      if (_selectedCategory == 'Hospitals') {
        matchesCategory = center.category == 'Hospital';
      } else if (_selectedCategory == 'PHC') {
        matchesCategory = center.category == 'PHC';
      } else if (_selectedCategory == 'Blood Banks') {
        matchesCategory = center.category == 'Blood Bank';
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

    // Sort ascending by real distance from user's live GPS location
    list.sort((a, b) {
      final distA = const Distance().as(LengthUnit.Meter, _userLocation, a.latLng);
      final distB = const Distance().as(LengthUnit.Meter, _userLocation, b.latLng);
      return distA.compareTo(distB);
    });

    return list;
  }

  void _scrollToCenter(HealthCenter center) {
    setState(() => _selectedCenter = center);
    _mapController.move(center.latLng, 15.0);
    final index = _filteredCenters.indexWhere((c) => c.id == center.id);
    if (index != -1) {
      _scrollController.animateTo(
        index * 160.0,
        duration: const Duration(milliseconds: 500),
        curve: Curves.easeInOut,
      );
    }
  }

  Future<void> _triggerDirections(HealthCenter center) async {
    setState(() {
      _selectedCenter = center;
      _isShowingDirections = true;
      _isLoadingRoute = true;
      _routePoints = [];
      _routeDistanceText = '';
      _routeDurationText = '';
    });

    try {
      final origin = _userLocation;
      final dest = center.latLng;
      final url = Uri.parse(
        'https://router.project-osrm.org/route/v1/driving/${origin.longitude},${origin.latitude};${dest.longitude},${dest.latitude}?overview=full&geometries=geojson',
      );

      final response = await http.get(url).timeout(const Duration(seconds: 8));
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data['code'] == 'Ok' && data['routes'] is List && (data['routes'] as List).isNotEmpty) {
          final route = data['routes'][0];
          final geometry = route['geometry'];
          final coordinates = geometry['coordinates'] as List;

          final points = coordinates.map<LatLng>((c) {
            final lng = (c[0] as num).toDouble();
            final lat = (c[1] as num).toDouble();
            return LatLng(lat, lng);
          }).toList();

          final double distMeters = (route['distance'] as num?)?.toDouble() ?? 0;
          final double durSeconds = (route['duration'] as num?)?.toDouble() ?? 0;

          final distText = distMeters >= 1000
              ? '${(distMeters / 1000).toStringAsFixed(1)} km'
              : '${distMeters.round()} m';
          final int mins = (durSeconds / 60).round();
          final durText = mins >= 60
              ? '${(mins / 60).floor()} hr ${mins % 60} min'
              : '$mins min';

          if (mounted) {
            setState(() {
              _routePoints = points;
              _routeDistanceText = distText;
              _routeDurationText = durText;
              _isLoadingRoute = false;
            });

            // Calculate bounding box to fit the entire route
            final allPoints = [_userLocation, center.latLng, ...points];
            final minLat = allPoints.map((p) => p.latitude).reduce((a, b) => a < b ? a : b);
            final maxLat = allPoints.map((p) => p.latitude).reduce((a, b) => a > b ? a : b);
            final minLng = allPoints.map((p) => p.longitude).reduce((a, b) => a < b ? a : b);
            final maxLng = allPoints.map((p) => p.longitude).reduce((a, b) => a > b ? a : b);

            _mapController.fitCamera(
              CameraFit.bounds(
                bounds: LatLngBounds(
                  LatLng(minLat, minLng),
                  LatLng(maxLat, maxLng),
                ),
                padding: const EdgeInsets.only(top: 60, bottom: 40, left: 30, right: 30),
              ),
            );
            return;
          }
        }
      }
    } catch (e) {
      debugPrint('OSRM road routing error: $e');
    }

    if (mounted) {
      setState(() {
        _routePoints = [_userLocation, center.latLng];
        _isLoadingRoute = false;
        _routeDistanceText = center.formatDistance(_userLocation);
      });
      _mapController.move(center.latLng, 15.0);
    }
  }

  // Multi-language translation helper
  String _t(String key, String lang) {
    final translations = {
      'en': {
        'nearby_title': 'Nearby Health Centers',
        'nearby_sub': 'Find hospitals, PHCs & blood banks near you',
        'search_hint': 'Search hospitals, PHCs, blood banks...',
        'all': 'All',
        'hospitals': 'Hospitals',
        'phc': 'PHC',
        'blood_banks': 'Blood Banks',
        'open_now': 'Open Now',
        'closed': 'Closed',
        'call': 'Call',
        'directions': 'Directions',
        'showing_results': 'Showing nearest health centers sorted by distance',
        'change_loc': 'Change',
        'legend_hospital': 'Hospital',
        'legend_phc': 'PHC',
        'legend_blood': 'Blood Bank',
        'top_5_label': 'Showing Top 5 Nearest Centers',
        'show_more': 'Show More Centers',
        'show_less': 'Show Top 5 Only',
        'view_all': 'View All',
      },
      'hi': {
        'nearby_title': 'नजदीकी स्वास्थ्य केंद्र',
        'nearby_sub': 'अपने आस-पास के अस्पताल, पीएचसी और ब्लड बैंक खोजें',
        'search_hint': 'अस्पताल, पीएचसी, ब्लड बैंक खोजें...',
        'all': 'सभी',
        'hospitals': 'अस्पताल',
        'phc': 'पीएचसी',
        'blood_banks': 'ब्लड बैंक',
        'open_now': 'अभी खुला है',
        'closed': 'बंद है',
        'call': 'कॉल',
        'directions': 'दिशा-निर्देश',
        'showing_results': 'दूरी के अनुसार क्रमबद्ध नजदीकी स्वास्थ्य केंद्र',
        'change_loc': 'बदलें',
        'legend_hospital': 'अस्पताल',
        'legend_phc': 'पीएचसी',
        'legend_blood': 'ब्लड बैंक',
        'top_5_label': 'शीर्ष 5 निकटतम केंद्र दिखाए जा रहे हैं',
        'show_more': 'और केंद्र देखें',
        'show_less': 'केवल शीर्ष 5 देखें',
        'view_all': 'सभी देखें',
      },
    };

    return translations[lang]?[key] ?? translations['en']![key] ?? key;
  }

  @override
  Widget build(BuildContext context) {
    final provider = Provider.of<SwasthyaTapProvider>(context);
    final lang = provider.selectedLanguage.isNotEmpty ? provider.selectedLanguage : 'en';
    final allFiltered = _filteredCenters;
    final screenH = MediaQuery.of(context).size.height;

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0.5,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Color(0xFF0F172A)),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              _t('nearby_title', lang),
              style: GoogleFonts.inter(
                fontSize: 17,
                fontWeight: FontWeight.w700,
                color: const Color(0xFF0F172A),
              ),
            ),
            ValueListenableBuilder<double>(
              valueListenable: _panelRatioNotifier,
              builder: (context, ratio, _) {
                final isFullScreen = ratio <= 0.12;
                return Text(
                  isFullScreen
                      ? 'Full Screen Map Navigation'
                      : _t('nearby_sub', lang),
                  style: GoogleFonts.inter(
                    fontSize: 11,
                    fontWeight: FontWeight.w400,
                    color: const Color(0xFF64748B),
                  ),
                );
              },
            ),
          ],
        ),
        actions: [
          ValueListenableBuilder<double>(
            valueListenable: _panelRatioNotifier,
            builder: (context, ratio, _) {
              final isFullScreen = ratio <= 0.12;
              return IconButton(
                icon: Icon(
                  isFullScreen ? Icons.fullscreen_exit_rounded : Icons.fullscreen_rounded,
                  color: const Color(0xFF0F766E),
                  size: 24,
                ),
                tooltip: isFullScreen ? 'Exit Full Screen' : 'Full Screen Map',
                onPressed: _toggleFullScreen,
              );
            },
          ),
          IconButton(
            icon: const Icon(Icons.refresh_rounded, color: Color(0xFF0F766E)),
            tooltip: 'Refresh Centers',
            onPressed: () {
              _fetchLocation();
              _fetchBackendCenters();
            },
          ),
        ],
      ),
      body: Stack(
        children: [
          // 1. Full Viewport Interactive Map Background
          Positioned.fill(
            child: _buildMapSection(lang, allFiltered),
          ),

          // 2. Top Floating Search Bar (Clean & Compact)
          Positioned(
            top: 12,
            left: 14,
            right: 14,
            child: Container(
              height: 44,
              padding: const EdgeInsets.symmetric(horizontal: 10),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(14),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.1),
                    blurRadius: 10,
                    offset: const Offset(0, 3),
                  ),
                ],
              ),
              child: TextField(
                controller: _searchController,
                onChanged: (val) => setState(() => _searchQuery = val),
                decoration: InputDecoration(
                  hintText: _t('search_hint', lang),
                  hintStyle: GoogleFonts.inter(fontSize: 13, color: const Color(0xFF94A3B8)),
                  prefixIcon: const Icon(Icons.search, color: Color(0xFF64748B), size: 20),
                  suffixIcon: _searchQuery.isNotEmpty
                      ? IconButton(
                          icon: const Icon(Icons.clear, size: 16, color: Color(0xFF64748B)),
                          onPressed: () {
                            _searchController.clear();
                            setState(() => _searchQuery = '');
                          },
                        )
                      : null,
                  border: InputBorder.none,
                  contentPadding: const EdgeInsets.symmetric(vertical: 12),
                ),
              ),
            ),
          ),

          // 3. Smooth Resizable / Draggable Bottom Panel displaying all Hospitals
          ValueListenableBuilder<double>(
            valueListenable: _panelRatioNotifier,
            builder: (context, panelRatio, _) {
              final isFullScreen = panelRatio <= 0.12;
              return Positioned(
                left: 0,
                right: 0,
                bottom: 0,
                height: (screenH * panelRatio).clamp(56.0, screenH * 0.90),
                child: Container(
                  decoration: BoxDecoration(
                    color: const Color(0xFFF8FAFC),
                    borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.12),
                        blurRadius: 16,
                        offset: const Offset(0, -4),
                      ),
                    ],
                  ),
                  child: Column(
                    children: [
                      // Draggable Handle bar: --------
                      MouseRegion(
                        cursor: SystemMouseCursors.resizeUpDown,
                        child: GestureDetector(
                          behavior: HitTestBehavior.opaque,
                          onVerticalDragStart: (details) {
                            _dragStartY = details.globalPosition.dy;
                            _startPanelRatio = _panelRatioNotifier.value;
                          },
                          onVerticalDragUpdate: (details) {
                            final delta = _dragStartY - details.globalPosition.dy;
                            if (screenH > 0) {
                              _panelRatioNotifier.value = (_startPanelRatio + (delta / screenH)).clamp(0.08, 0.88);
                            }
                          },
                          onVerticalDragEnd: (details) {
                            if (_panelRatioNotifier.value < 0.16) {
                              _panelRatioNotifier.value = 0.08;
                            } else if (_panelRatioNotifier.value > 0.80) {
                              _panelRatioNotifier.value = 0.88;
                            }
                          },
                          onTap: _toggleFullScreen,
                          child: Container(
                            width: double.infinity,
                            padding: const EdgeInsets.only(top: 10, bottom: 8),
                            decoration: const BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
                            ),
                            child: Column(
                              children: [
                                // Resizable drag handle line: --------
                                Container(
                                  width: 54,
                                  height: 5.5,
                                  decoration: BoxDecoration(
                                    color: const Color(0xFF94A3B8),
                                    borderRadius: BorderRadius.circular(10),
                                  ),
                                ),
                                const SizedBox(height: 6),
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Icon(
                                      isFullScreen ? Icons.keyboard_arrow_up_rounded : Icons.keyboard_arrow_down_rounded,
                                      size: 16,
                                      color: const Color(0xFF64748B),
                                    ),
                                    const SizedBox(width: 4),
                                    Text(
                                      '${_selectedCategory} (${allFiltered.length}) • ${isFullScreen ? "Lift up to view list" : "Drag up/down to resize"}',
                                      style: GoogleFonts.inter(
                                        fontSize: 11.5,
                                        fontWeight: FontWeight.w600,
                                        color: const Color(0xFF475569),
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                      const Divider(height: 1, thickness: 1, color: Color(0xFFE2E8F0)),

                      // Category Filter Chips relocated back inside Hospital section preview
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                        color: Colors.white,
                        child: SingleChildScrollView(
                          scrollDirection: Axis.horizontal,
                          child: Row(
                            children: [
                              _buildCategoryChip('All', Icons.grid_view_rounded, Colors.teal),
                              const SizedBox(width: 6),
                              _buildCategoryChip('Hospitals', Icons.local_hospital_rounded, const Color(0xFF1E40AF)),
                              const SizedBox(width: 6),
                              _buildCategoryChip('PHC', Icons.health_and_safety_rounded, const Color(0xFF15803D)),
                              const SizedBox(width: 6),
                              _buildCategoryChip('Blood Banks', Icons.bloodtype_rounded, const Color(0xFFDC2626)),
                            ],
                          ),
                        ),
                      ),
                      const Divider(height: 1, thickness: 1, color: Color(0xFFE2E8F0)),

                      // Scrollable List of Normal Sized Hospital Cards
                      Expanded(
                        child: _isLoadingCenters
                            ? const Center(
                                child: CircularProgressIndicator(color: Color(0xFF0F766E)),
                              )
                            : allFiltered.isEmpty
                                ? Center(
                                    child: Column(
                                      mainAxisAlignment: MainAxisAlignment.center,
                                      children: [
                                        const Icon(Icons.location_off_rounded, size: 40, color: Color(0xFF94A3B8)),
                                        const SizedBox(height: 8),
                                        Text(
                                          'No health centers found',
                                          style: GoogleFonts.inter(
                                            fontSize: 14,
                                            fontWeight: FontWeight.w600,
                                            color: const Color(0xFF475569),
                                          ),
                                        ),
                                      ],
                                    ),
                                  )
                                : ListView.builder(
                                    controller: _scrollController,
                                    padding: const EdgeInsets.fromLTRB(14, 10, 14, 24),
                                    itemCount: allFiltered.length,
                                    itemBuilder: (context, index) {
                                      return _buildNormalCenterCard(allFiltered[index], lang);
                                    },
                                  ),
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildMapSection(String lang, List<HealthCenter> allFiltered) {
    return Stack(
      children: [
        FlutterMap(
          mapController: _mapController,
          options: MapOptions(
            initialCenter: _userLocation,
            initialZoom: 14.5,
            onMapReady: () => setState(() => _mapReady = true),
            onTap: (tapPosition, point) {
              if (_isSettingLocation) {
                setState(() {
                  _userLocation = point;
                  _locationManuallySet = true;
                  _isSettingLocation = false;
                });
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(
                      'Location set to (${point.latitude.toStringAsFixed(4)}, ${point.longitude.toStringAsFixed(4)})',
                    ),
                    duration: const Duration(seconds: 2),
                  ),
                );
              } else {
                setState(() {
                  _selectedCenter = null;
                  _isShowingDirections = false;
                  _routePoints = [];
                });
              }
            },
          ),
          children: [
            TileLayer(
              urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
              userAgentPackageName: 'com.swasthyatap.app',
            ),

            // Real turn-by-turn road route polyline
            if (_isShowingDirections && _routePoints.isNotEmpty)
              PolylineLayer(
                polylines: [
                  // Outer casing for Google Maps styled route depth
                  Polyline(
                    points: _routePoints,
                    strokeWidth: 8.0,
                    color: const Color(0xFF1D4ED8).withOpacity(0.35),
                  ),
                  // Inner vibrant solid road polyline
                  Polyline(
                    points: _routePoints,
                    strokeWidth: 4.8,
                    color: const Color(0xFF2563EB),
                  ),
                ],
              ),

            // Markers
            MarkerLayer(
              markers: [
                // User location marker
                Marker(
                  point: _userLocation,
                  width: 44,
                  height: 44,
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      Container(
                        width: 36,
                        height: 36,
                        decoration: BoxDecoration(
                          color: const Color(0xFF2563EB).withOpacity(0.2),
                          shape: BoxShape.circle,
                        ),
                      ),
                      Container(
                        width: 18,
                        height: 18,
                        decoration: BoxDecoration(
                          color: const Color(0xFF2563EB),
                          shape: BoxShape.circle,
                          border: Border.all(color: Colors.white, width: 3),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.2),
                              blurRadius: 4,
                              offset: const Offset(0, 2),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),

                // Center markers
                ...allFiltered.map((center) {
                  final isSelected = _selectedCenter?.id == center.id;
                  Color markerColor;
                  switch (center.category) {
                    case 'Hospital':
                      markerColor = const Color(0xFF1E40AF);
                      break;
                    case 'PHC':
                      markerColor = const Color(0xFF15803D);
                      break;
                    case 'Blood Bank':
                      markerColor = const Color(0xFFDC2626);
                      break;
                    default:
                      markerColor = const Color(0xFF1E40AF);
                  }

                  return Marker(
                    point: center.latLng,
                    width: isSelected ? 48 : 36,
                    height: isSelected ? 48 : 36,
                    child: GestureDetector(
                      onTap: () => _scrollToCenter(center),
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 200),
                        decoration: BoxDecoration(
                          color: markerColor,
                          shape: BoxShape.circle,
                          border: Border.all(color: Colors.white, width: isSelected ? 3 : 2),
                          boxShadow: [
                            BoxShadow(
                              color: markerColor.withOpacity(0.4),
                              blurRadius: isSelected ? 8 : 4,
                              offset: const Offset(0, 2),
                            ),
                          ],
                        ),
                        child: Icon(
                          center.category == 'Hospital'
                              ? Icons.local_hospital_rounded
                              : center.category == 'PHC'
                                  ? Icons.health_and_safety_rounded
                                  : Icons.bloodtype_rounded,
                          color: Colors.white,
                          size: isSelected ? 24 : 18,
                        ),
                      ),
                    ),
                  );
                }).toList(),
              ],
            ),
          ],
        ),

        // Map Category Legend (Bottom center above collapsed drag bar)
        Positioned(
          bottom: 64,
          left: 10,
          right: 10,
          child: Center(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.92),
                borderRadius: BorderRadius.circular(20),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.06),
                    blurRadius: 10,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Wrap(
                alignment: WrapAlignment.center,
                spacing: 14,
                runSpacing: 4,
                children: [
                  _buildLegendItem(const Color(0xFF1E40AF), _t('legend_hospital', lang)),
                  _buildLegendItem(const Color(0xFF15803D), _t('legend_phc', lang)),
                  _buildLegendItem(const Color(0xFFDC2626), _t('legend_blood', lang)),
                ],
              ),
            ),
          ),
        ),

        // Floating Turn-by-Turn Route Details Card
        if (_isShowingDirections && _selectedCenter != null && !_isSettingLocation)
          Positioned(
            top: 104,
            left: 12,
            right: 64,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: const Color(0xFF2563EB).withOpacity(0.3)),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.12),
                    blurRadius: 10,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(6),
                    decoration: BoxDecoration(
                      color: const Color(0xFF2563EB),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: _isLoadingRoute
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                          )
                        : const Icon(Icons.navigation_rounded, color: Colors.white, size: 16),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Row(
                          children: [
                            Text(
                              _isLoadingRoute
                                  ? 'Finding road route...'
                                  : (_routeDurationText.isNotEmpty ? _routeDurationText : 'Route'),
                              style: GoogleFonts.inter(
                                fontSize: 13,
                                fontWeight: FontWeight.w700,
                                color: const Color(0xFF15803D),
                              ),
                            ),
                            if (!_isLoadingRoute && _routeDistanceText.isNotEmpty) ...[
                              const SizedBox(width: 6),
                              Text(
                                '($_routeDistanceText)',
                                style: GoogleFonts.inter(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w500,
                                  color: const Color(0xFF64748B),
                                ),
                              ),
                            ],
                          ],
                        ),
                        Text(
                          _selectedCenter!.name,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: GoogleFonts.inter(
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                            color: const Color(0xFF0F172A),
                          ),
                        ),
                      ],
                    ),
                  ),
                  GestureDetector(
                    onTap: () {
                      setState(() {
                        _isShowingDirections = false;
                        _routePoints = [];
                      });
                    },
                    child: Container(
                      padding: const EdgeInsets.all(4),
                      decoration: const BoxDecoration(
                        color: Color(0xFFF1F5F9),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(Icons.close_rounded, size: 16, color: Color(0xFF64748B)),
                    ),
                  ),
                ],
              ),
            ),
          ),

        // Tap-to-set banner
        if (_isSettingLocation)
          Positioned(
            top: 104,
            left: 12,
            right: 62,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: BoxDecoration(
                color: const Color(0xFF1E40AF),
                borderRadius: BorderRadius.circular(12),
                boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.15), blurRadius: 8)],
              ),
              child: Row(
                children: [
                  const Icon(Icons.touch_app_rounded, color: Colors.white, size: 18),
                  const SizedBox(width: 8),
                  const Expanded(
                    child: Text(
                      'Tap anywhere on the map to set your location',
                      style: TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w600),
                    ),
                  ),
                  GestureDetector(
                    onTap: () => setState(() => _isSettingLocation = false),
                    child: const Icon(Icons.close_rounded, color: Colors.white70, size: 18),
                  ),
                ],
              ),
            ),
          ),

        // Map Control Buttons (Right stack: Zoom In/Out, Fullscreen, Re-center, Location Pin)
        Positioned(
          top: 104,
          right: 12,
          child: Column(
            children: [
              _buildMapButton(
                icon: Icons.add,
                tooltip: 'Zoom In',
                onTap: () {
                  final currentZoom = _mapController.camera.zoom;
                  _mapController.move(_mapController.camera.center, (currentZoom + 1).clamp(1.0, 19.0));
                },
              ),
              const SizedBox(height: 6),
              _buildMapButton(
                icon: Icons.remove,
                tooltip: 'Zoom Out',
                onTap: () {
                  final currentZoom = _mapController.camera.zoom;
                  _mapController.move(_mapController.camera.center, (currentZoom - 1).clamp(1.0, 19.0));
                },
              ),
              const SizedBox(height: 6),
              // Full Screen Toggle Button
              _buildMapButton(
                icon: _isFullScreenMap ? Icons.fullscreen_exit_rounded : Icons.fullscreen_rounded,
                tooltip: _isFullScreenMap ? 'Exit Full Screen' : 'Full Screen Map',
                color: const Color(0xFF2563EB),
                onTap: _toggleFullScreen,
              ),
              const SizedBox(height: 6),
              // Re-center to GPS
              _buildMapButton(
                icon: Icons.my_location_rounded,
                tooltip: 'Re-center to my location',
                color: const Color(0xFF0F766E),
                onTap: () async {
                  setState(() {
                    _selectedCenter = null;
                    _locationManuallySet = false;
                  });
                  _mapController.move(_userLocation, 15.0);
                  await _fetchLocation();
                },
              ),
              const SizedBox(height: 6),
              // Manual Pin override
              _buildMapButton(
                icon: Icons.edit_location_alt_rounded,
                tooltip: 'Set location manually',
                color: _isSettingLocation ? Colors.white : const Color(0xFF1E40AF),
                backgroundColor: _isSettingLocation ? const Color(0xFF1E40AF) : Colors.white,
                onTap: () {
                  setState(() => _isSettingLocation = !_isSettingLocation);
                  if (_isSettingLocation) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Tap anywhere on the map to set your location'),
                        duration: Duration(seconds: 2),
                      ),
                    );
                  }
                },
              ),
            ],
          ),
        ),
      ],
    );
  }

  // Normal-sized rich Health Center card
  Widget _buildNormalCenterCard(HealthCenter center, String lang) {
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
        categoryColor = const Color(0xFF1E40AF);
        categoryIcon = Icons.local_hospital_rounded;
    }

    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
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
            color: isSelected ? categoryColor.withOpacity(0.08) : Colors.black.withOpacity(0.04),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: () => _scrollToCenter(center),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Icon
                  Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      color: categoryColor.withOpacity(0.08),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(categoryIcon, color: categoryColor, size: 22),
                  ),
                  const SizedBox(width: 12),

                  // Name + Category + Distance
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          center.name,
                          style: GoogleFonts.inter(
                            fontSize: 14.5,
                            fontWeight: FontWeight.w700,
                            color: const Color(0xFF0F172A),
                          ),
                        ),
                        const SizedBox(height: 4),
                        Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                              decoration: BoxDecoration(
                                color: categoryColor.withOpacity(0.08),
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: Text(
                                center.category,
                                style: TextStyle(
                                  fontSize: 10,
                                  fontWeight: FontWeight.w600,
                                  color: categoryColor,
                                ),
                              ),
                            ),
                            const SizedBox(width: 8),
                            const Icon(Icons.near_me_outlined, size: 12, color: Color(0xFF0F766E)),
                            const SizedBox(width: 2),
                            Text(
                              center.formatDistance(_userLocation),
                              style: GoogleFonts.inter(
                                fontSize: 11,
                                fontWeight: FontWeight.w700,
                                color: const Color(0xFF0F766E),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),

                  // Directions Action Button
                  GestureDetector(
                    onTap: () => _triggerDirections(center),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                      decoration: BoxDecoration(
                        color: const Color(0xFFEFF6FF),
                        border: Border.all(color: const Color(0xFFBFDBFE)),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.navigation_rounded, color: Color(0xFF2563EB), size: 18),
                          const SizedBox(height: 3),
                          Text(
                            _t('directions', lang),
                            style: GoogleFonts.inter(
                              fontSize: 9.5,
                              fontWeight: FontWeight.w700,
                              color: const Color(0xFF2563EB),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 10),

              // Rating & Status Row
              Row(
                children: [
                  const Icon(Icons.star_rounded, color: Colors.amber, size: 16),
                  const SizedBox(width: 4),
                  Text(
                    center.rating.toString(),
                    style: GoogleFonts.inter(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: const Color(0xFF0F172A),
                    ),
                  ),
                  if (center.reviews > 0) ...[
                    const SizedBox(width: 3),
                    Text(
                      '(${center.reviews})',
                      style: GoogleFonts.inter(fontSize: 11, color: const Color(0xFF94A3B8)),
                    ),
                  ],
                  const SizedBox(width: 10),
                  const Text('•', style: TextStyle(fontSize: 11, color: Color(0xFFCBD5E1))),
                  const SizedBox(width: 10),
                  Text(
                    center.status,
                    style: GoogleFonts.inter(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: center.status.toLowerCase().contains('open')
                          ? const Color(0xFF15803D)
                          : const Color(0xFFDC2626),
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
                ),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),

              if (center.badges.isNotEmpty) ...[
                const SizedBox(height: 8),
                Wrap(
                  spacing: 6,
                  runSpacing: 4,
                  children: center.badges.map((badge) {
                    return Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF1F5F9),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        badge,
                        style: GoogleFonts.inter(
                          fontSize: 9.5,
                          fontWeight: FontWeight.w500,
                          color: const Color(0xFF475569),
                        ),
                      ),
                    );
                  }).toList(),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildLegendItem(Color color, String label) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 8,
          height: 8,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(width: 4),
        Text(
          label,
          style: GoogleFonts.inter(
            fontSize: 10,
            fontWeight: FontWeight.w600,
            color: const Color(0xFF334155),
          ),
        ),
      ],
    );
  }

  Widget _buildMapButton({
    required IconData icon,
    required VoidCallback onTap,
    String? tooltip,
    Color? color,
    Color? backgroundColor,
  }) {
    final btn = GestureDetector(
      onTap: onTap,
      child: Container(
        width: 34,
        height: 34,
        decoration: BoxDecoration(
          color: backgroundColor ?? Colors.white,
          shape: BoxShape.circle,
          border: Border.all(
            color: backgroundColor != null ? backgroundColor : const Color(0xFFF1F5F9),
            width: 1.5,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.08),
              blurRadius: 6,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Icon(icon, color: color ?? const Color(0xFF475569), size: 18),
      ),
    );

    if (tooltip != null) {
      return Tooltip(message: tooltip, child: btn);
    }
    return btn;
  }

  Widget _buildCategoryChip(String label, IconData icon, Color color) {
    final isSelected = _selectedCategory == label;
    return GestureDetector(
      onTap: () {
        setState(() {
          _selectedCategory = label;
        });
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: isSelected ? color : Colors.white,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: isSelected ? color : const Color(0xFFE2E8F0),
            width: 1.2,
          ),
          boxShadow: isSelected
              ? [BoxShadow(color: color.withOpacity(0.25), blurRadius: 6, offset: const Offset(0, 2))]
              : [],
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              size: 15,
              color: isSelected ? Colors.white : const Color(0xFF64748B),
            ),
            const SizedBox(width: 5),
            Text(
              label,
              style: GoogleFonts.inter(
                fontSize: 11.5,
                fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                color: isSelected ? Colors.white : const Color(0xFF334155),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
