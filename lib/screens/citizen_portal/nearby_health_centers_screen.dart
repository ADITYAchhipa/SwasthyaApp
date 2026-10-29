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
import '../../services/medical_data_gateway.dart';
import '../../services/offline_map_cache_service.dart';
import '../../services/offline_mesh/network_manager.dart';
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

  // Default to Udaipur; updated once GPS resolves
  LatLng _userLocation = const LatLng(24.5854, 73.7125);
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
            phone: (h['phone'] ?? '+91 80 2699 5000').toString(),
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
        // ── Udaipur Hospitals ──
        HealthCenter(
          id: 'gbh_american',
          name: 'GBH American Hospital',
          category: 'Hospital',
          rating: 4.7,
          reviews: 1680,
          address: '101, Kothi Bagh, Bhatt Ji Ki Bari, Meera Girls College Road, Udaipur 313001',
          distance: 1.2,
          status: 'Open Now',
          statusDetails: '24x7 Emergency & Trauma, Cardiology, ICU, Blood Bank',
          badges: ['Emergency 24x7', 'ICU', 'Blood Bank', 'NFC Supported'],
          latLng: const LatLng(24.591547, 73.696385),
          phone: '0294-3535000',
        ),
        HealthCenter(
          id: 'geetanjali',
          name: 'Geetanjali Medical College & Hospital',
          category: 'Hospital',
          rating: 4.8,
          reviews: 2950,
          address: 'Hiranmagri Extension, Manwakhera NH-8 Bypass, Udaipur 313002',
          distance: 4.5,
          status: 'Open Now',
          statusDetails: 'Tertiary Care, Multi-Specialty, Emergency/Trauma, Cardiac Unit',
          badges: ['Tertiary Care', '24x7 Emergency', 'Ayushman Bharat', 'NFC Supported'],
          latLng: const LatLng(24.5537, 73.7316),
          phone: '0294-2500000',
        ),
        HealthCenter(
          id: 'pacific_med',
          name: 'Pacific Medical College & Hospital',
          category: 'Hospital',
          rating: 4.6,
          reviews: 1820,
          address: 'Bhilon ka Bedla, Pratappura, NH-27, Udaipur 313024',
          distance: 7.8,
          status: 'Open Now',
          statusDetails: 'Multi-Specialty Hospital, Medical & Surgical Care, 24x7 Emergency',
          badges: ['Multi-Specialty', '24x7 Emergency', 'Blood Bank', 'NFC Supported'],
          latLng: const LatLng(24.668883, 73.702761),
          phone: '0294-3920000',
        ),
        HealthCenter(
          id: 'mb_hospital',
          name: 'Maharana Bhupal Government Hospital (MB Hospital)',
          category: 'Hospital',
          rating: 4.5,
          reviews: 3400,
          address: 'RNT Medical College Campus, Court Chowk, Hospital Road, Udaipur 313001',
          distance: 0.9,
          status: 'Open Now',
          statusDetails: 'Apex Government Medical College & Super Specialty Hospital',
          badges: ['Government Apex', 'Free Diagnostics', 'Trauma Centre', 'NFC Supported'],
          latLng: const LatLng(24.5886, 73.6953),
          phone: '0294-2528811',
        ),

        // ── Udaipur PHCs ──
        HealthCenter(
          id: 'phc_badi',
          name: 'Badi AAM-PHC',
          category: 'PHC',
          rating: 4.5,
          reviews: 210,
          address: 'Near Badi Lake, Bargaon Block, Udaipur 313011',
          distance: 6.2,
          status: 'Open Now',
          statusDetails: 'Ayushman Arogya Mandir - Comprehensive Primary Health Care & Wellness',
          badges: ['AAM-PHC', 'Ayushman Arogya Mandir', 'Wellness & OPD'],
          latLng: const LatLng(24.6289, 73.6394),
          phone: '0294-240109',
        ),
        HealthCenter(
          id: 'phc_khatar',
          name: 'Khatar PHC',
          category: 'PHC',
          rating: 4.4,
          reviews: 145,
          address: 'Khatar, Bargaon Block, Udaipur District 313011',
          distance: 5.4,
          status: 'Open Now',
          statusDetails: 'General OPD, NCD Screening, Free Essential Drugs',
          badges: ['Bargaon Block', 'General OPD', 'NCD Screening'],
          latLng: const LatLng(24.6420, 73.6780),
          phone: '0294-240105',
        ),
        HealthCenter(
          id: 'phc_palana',
          name: 'Palana Kala PHC',
          category: 'PHC',
          rating: 4.2,
          reviews: 95,
          address: 'Palana Kala, Mavli Block, Udaipur District 313203',
          distance: 22.0,
          status: 'Open Now',
          statusDetails: 'General OPD, Maternal & Child Immunization',
          badges: ['Mavli Block', 'General OPD', 'Vaccination Center'],
          latLng: const LatLng(24.7821, 73.9645),
          phone: '0294-240101',
        ),
        HealthCenter(
          id: 'phc_chandesra',
          name: 'Chandesra PHC',
          category: 'PHC',
          rating: 4.1,
          reviews: 80,
          address: 'Chandesra, Mavli Block, Udaipur District 313204',
          distance: 18.5,
          status: 'Open Now',
          statusDetails: 'Primary Health Care, Free Medicines & Diagnostics',
          badges: ['Mavli Block', 'Primary Health', 'Free Medicines'],
          latLng: const LatLng(24.7214, 73.8921),
          phone: '0294-240102',
        ),
        HealthCenter(
          id: 'phc_mamer',
          name: 'Mamer PHC',
          category: 'PHC',
          rating: 4.3,
          reviews: 110,
          address: 'Mamer, Kotra Block, Udaipur District 307025',
          distance: 45.0,
          status: 'Open Now',
          statusDetails: 'Tribal Health Care, Emergency First Aid, OPD & Immunization',
          badges: ['Kotra Block', '24x7 Delivery', 'Tribal Healthcare'],
          latLng: const LatLng(24.3850, 73.2104),
          phone: '0294-240103',
        ),
        HealthCenter(
          id: 'phc_padawali',
          name: 'Padawali PHC',
          category: 'PHC',
          rating: 4.2,
          reviews: 120,
          address: 'Padawali, Gogunda Block, Udaipur District 313705',
          distance: 26.0,
          status: 'Open Now',
          statusDetails: 'General Medicine, Antenatal Care, Nutrition Support',
          badges: ['Gogunda Block', 'Maternity Care', 'Vaccination Center'],
          latLng: const LatLng(24.7540, 73.5230),
          phone: '0294-240104',
        ),
        HealthCenter(
          id: 'phc_neemri',
          name: 'Neemri PHC',
          category: 'PHC',
          rating: 4.1,
          reviews: 75,
          address: 'Neemri, Bhinder Block, Udaipur District 313603',
          distance: 38.0,
          status: 'Open Now',
          statusDetails: 'Primary OPD, Maternal Health & Child Immunization',
          badges: ['Bhinder Block', 'Child Immunization', 'Free Medicines'],
          latLng: const LatLng(24.5020, 74.1250),
          phone: '0294-240106',
        ),
        HealthCenter(
          id: 'phc_gadoli',
          name: 'Gadoli PHC',
          category: 'PHC',
          rating: 4.2,
          reviews: 88,
          address: 'Gadoli, Mavli Block, Udaipur District 313204',
          distance: 24.0,
          status: 'Open Now',
          statusDetails: 'General OPD, Preventive Health Services',
          badges: ['Mavli Block', 'General OPD', 'Govt Scheme'],
          latLng: const LatLng(24.7510, 73.9450),
          phone: '0294-240107',
        ),
        HealthCenter(
          id: 'phc_javar',
          name: 'Javar PHC',
          category: 'PHC',
          rating: 4.3,
          reviews: 130,
          address: 'Javar Mines Area / Mavli, Udaipur District 313901',
          distance: 32.0,
          status: 'Open Now',
          statusDetails: 'Occupational & Community Healthcare, OPD & First Aid',
          badges: ['Community OPD', 'First Aid Center', 'Emergency Care'],
          latLng: const LatLng(24.3540, 73.7120),
          phone: '0294-240108',
        ),

        // ── Udaipur Blood Banks ──
        HealthCenter(
          id: 'bb_gbh',
          name: 'GBH American Hospital Blood Bank',
          category: 'Blood Bank',
          rating: 4.8,
          reviews: 450,
          address: 'GBH American Hospital, 101 Kothi Bagh, Bhatt Ji Ki Bari, Udaipur 313001',
          distance: 1.2,
          status: 'Open Now',
          statusDetails: '24x7 Blood Bank - Whole Blood, PRBC, Platelets (SDP), FFP',
          badges: ['Whole Blood', 'PRBC', 'Platelets', 'FFP', '24x7 Support'],
          latLng: const LatLng(24.591547, 73.696385),
          phone: '0294-3535000',
        ),
        HealthCenter(
          id: 'bb_pacific',
          name: 'Pacific Medical College & Hospital Blood Bank',
          category: 'Blood Bank',
          rating: 4.7,
          reviews: 380,
          address: 'Pacific Medical College Campus, Bhilon ka Bedla, Pratappura, Udaipur 313024',
          distance: 7.8,
          status: 'Open Now',
          statusDetails: '24x7 Institutional Blood Bank & Component Separation Unit',
          badges: ['Component Separation', 'Institutional', '24x7 Open'],
          latLng: const LatLng(24.668883, 73.702761),
          phone: '0294-3920000',
        ),
        HealthCenter(
          id: 'bb_mb_hospital',
          name: 'MB Hospital Blood Centre (RNT Medical College)',
          category: 'Blood Bank',
          rating: 4.9,
          reviews: 1200,
          address: 'Maharana Bhupal Government Hospital / RNT Medical College Campus, Court Chowk, Udaipur 313001',
          distance: 0.9,
          status: 'Open Now',
          statusDetails: 'Government Regional Blood Transfusion Centre - All Blood Components 24x7',
          badges: ['Government Regional Centre', 'Platelets Apheresis', 'Emergency Supply', '24x7 Service'],
          latLng: const LatLng(24.5886, 73.6953),
          phone: '0294-2528811',
        ),

        // ── Hubballi Hospitals ──
        HealthCenter(
          id: 'hubballi_secure',
          name: 'SeCURE Hospital',
          category: 'Hospital',
          rating: 4.6,
          reviews: 480,
          address: 'Gokul Road, beside New Bus Stand, Dollars Colony, Chaitanya Nagar, Hubballi – 580030',
          distance: 1.5,
          status: 'Open Now',
          statusDetails: '24x7 Emergency Services, Multi-specialty care, emergency, ICU, surgery, diagnostics',
          badges: ['Multi-specialty', 'Emergency', 'ICU', 'Surgery', 'Diagnostics'],
          latLng: const LatLng(15.3665, 75.0975),
          phone: '+91 836 425 2020',
        ),
        HealthCenter(
          id: 'hubballi_suchirayu',
          name: 'HCG Suchirayu Hospital - Hubli',
          category: 'Hospital',
          rating: 4.7,
          reviews: 980,
          address: 'Gokul Road, opposite KSRTC Bus Depot, Kallur Layout, Hubballi – 580030',
          distance: 2.1,
          status: 'Open Now',
          statusDetails: '24x7 Cancer care, surgery, medical oncology, radiation oncology, diagnostics, ICU',
          badges: ['Cancer Care', 'Surgery', 'Oncology', 'Diagnostics', 'ICU'],
          latLng: const LatLng(15.3525, 75.1241),
          phone: '+91 804 293 0913',
        ),
        HealthCenter(
          id: 'hubballi_sushruta',
          name: 'Sushruta Multispeciality Hospital',
          category: 'Hospital',
          rating: 4.5,
          reviews: 620,
          address: 'PB Road, Prabhat Colony, Vidya Nagar, Hubballi – 580021',
          distance: 1.8,
          status: 'Open Now',
          statusDetails: '24x7 Multi-specialty, ICU, emergency, surgery, critical care',
          badges: ['Multi-specialty', 'ICU', 'Emergency', 'Surgery', 'Critical Care'],
          latLng: const LatLng(15.3575, 75.1325),
          phone: '+91 94498 64820',
        ),
        HealthCenter(
          id: 'hubballi_balaji',
          name: 'Balaji Hospitals',
          category: 'Hospital',
          rating: 4.6,
          reviews: 510,
          address: 'KSRTC Depot / Hosur–Unkal Bypass Road, Vidya Nagar, Hubballi – 580021',
          distance: 1.9,
          status: 'Open Now',
          statusDetails: '24x7 Multi-specialty, emergency, surgery, critical care',
          badges: ['Multi-specialty', 'Emergency', 'Surgery', 'Critical Care'],
          latLng: const LatLng(15.3610, 75.1220),
          phone: '+91 98862 29701',
        ),
        HealthCenter(
          id: 'hubballi_lifeline',
          name: 'Shri Bhanji D Khimji Lifeline Hospital Hubballi',
          category: 'Hospital',
          rating: 4.4,
          reviews: 320,
          address: 'Airport Road, opposite New Bus Stand, Industrial Estate, Hubballi – 580030',
          distance: 2.2,
          status: 'Open Now',
          statusDetails: '24x7 Multi-specialty, emergency, inpatient care',
          badges: ['Multi-specialty', 'Emergency', 'Inpatient Care'],
          latLng: const LatLng(15.3640, 75.1270),
          phone: '+91 836 426 0353',
        ),
        HealthCenter(
          id: 'hubballi_superspeciality',
          name: 'Hubli Super Speciality Hospital',
          category: 'Hospital',
          rating: 4.5,
          reviews: 290,
          address: 'Kalyana Mantap Road, behind Hans Hotel Rambhapuri, Kalyan Nagar, Vidya Nagar, Hubballi – 580031',
          distance: 1.7,
          status: 'Open Now',
          statusDetails: '24x7 Super-specialty / multi-specialty care, emergency',
          badges: ['Super-specialty', 'Multi-specialty', 'Emergency'],
          latLng: const LatLng(15.3530, 75.1310),
          phone: '+91 99899 66980',
        ),
        HealthCenter(
          id: 'hubballi_jayapriya',
          name: 'Jayapriya Hospital',
          category: 'Hospital',
          rating: 4.3,
          reviews: 180,
          address: 'Deshpande Nagar Road, near Canara Bank Circle Office, Bailappanavar Nagar, Vidya Nagar, Hubballi – 580029',
          distance: 1.3,
          status: 'Open Now',
          statusDetails: 'OPD: 9 AM–8 PM Multi-specialty medical care',
          badges: ['Multi-specialty', 'Ophthalmology'],
          latLng: const LatLng(15.3515, 75.1275),
          phone: '+91 836 225 1767',
        ),

        // ── Hubballi PHCs ──
        HealthCenter(
          id: 'hubballi_phc_heggeri',
          name: 'Primary Health Centre Heggeri',
          category: 'PHC',
          rating: 4.1,
          reviews: 35,
          address: 'Heggeri Colony, Old Hubli, Hubballi – 580024',
          distance: 3.4,
          status: 'Open Now',
          statusDetails: 'General OPD, primary healthcare, maternal/child care, immunization',
          badges: ['General OPD', 'Primary Care', 'Maternal Care', 'Immunization'],
          latLng: const LatLng(15.3381, 75.1247),
          phone: 'Not verified',
        ),
        HealthCenter(
          id: 'hubballi_phc_banatikatta',
          name: 'Urban Primary Health Center, Banatikatta',
          category: 'PHC',
          rating: 4.2,
          reviews: 42,
          address: 'Kolekar Plot, Old Hubli, Hubballi – 580024',
          distance: 3.1,
          status: 'Open Now',
          statusDetails: 'General OPD, maternal care, child health, immunization',
          badges: ['General OPD', 'Maternal Care', 'Child Health', 'Immunization'],
          latLng: const LatLng(15.3370, 75.1350),
          phone: 'Not verified',
        ),
        HealthCenter(
          id: 'hubballi_phc_navanagar',
          name: 'Urban Primary Health Centre, Navanagar',
          category: 'PHC',
          rating: 4.3,
          reviews: 58,
          address: 'Navanagar, Hubballi – 580025',
          distance: 6.8,
          status: 'Open Now',
          statusDetails: 'General OPD, primary care, maternal/child health, immunization',
          badges: ['General OPD', 'Primary Care', 'Maternal Care', 'Immunization'],
          latLng: const LatLng(15.3951, 75.0821),
          phone: 'Not verified',
        ),
        HealthCenter(
          id: 'hubballi_phc_durgadbail',
          name: 'Urban Primary Health Centre, Durgad Bail',
          category: 'PHC',
          rating: 4.0,
          reviews: 24,
          address: 'Durgad Bail, New Hubli, Hubballi – 580020',
          distance: 2.7,
          status: 'Open Now',
          statusDetails: 'General OPD, primary healthcare',
          badges: ['General OPD', 'Primary Healthcare'],
          latLng: const LatLng(15.3432, 75.1428),
          phone: 'Not verified',
        ),
        HealthCenter(
          id: 'hubballi_phc_chalukyanagar',
          name: 'Primary Healthcare, Chalukya Nagar',
          category: 'PHC',
          rating: 4.1,
          reviews: 19,
          address: 'Chalukya Nagar, Hubballi – 580020',
          distance: 4.2,
          status: 'Open Now',
          statusDetails: 'Primary healthcare services',
          badges: ['Primary Healthcare'],
          latLng: const LatLng(15.3577, 75.1597),
          phone: 'Not verified',
        ),

        // ── Hubballi Blood Banks ──
        HealthCenter(
          id: 'hubballi_bb_rashtrotthana',
          name: 'Rashtrotthana Blood Centre',
          category: 'Blood Bank',
          rating: 4.9,
          reviews: 140,
          address: '2nd Floor, Dee Jay Building, Neeligin Road, Deshpande Nagar, Hubballi – 580029',
          distance: 1.1,
          status: 'Open Now',
          statusDetails: '24x7 NGO / Charitable Blood Bank',
          badges: ['NGO', 'Charitable', 'Whole Blood', 'PRBC', 'Platelets'],
          latLng: const LatLng(15.3520, 75.1320),
          phone: '+91 836 235 8838',
        ),
        HealthCenter(
          id: 'hubballi_bb_premabindu',
          name: 'PREMA BINDU BLOOD CENTRE',
          category: 'Blood Bank',
          rating: 4.8,
          reviews: 95,
          address: 'Opp. BVB College, Prashant Colony, Vidya Nagar, Hubballi – 580031',
          distance: 1.9,
          status: 'Open Now',
          statusDetails: '24x7 Private / Charitable Blood Bank',
          badges: ['Private', 'Charitable', 'Whole Blood', 'PRBC'],
          latLng: const LatLng(15.3638, 75.1275),
          phone: '+91 72044 11222',
        ),
        HealthCenter(
          id: 'hubballi_bb_kims',
          name: 'Karnataka Medical College Hospital Blood Bank',
          category: 'Blood Bank',
          rating: 4.7,
          reviews: 210,
          address: 'KIMS OPD, Casualty & Emergency, Bhavani Nagar, Vidya Nagar, Hubballi – 580021',
          distance: 1.6,
          status: 'Open Now',
          statusDetails: '24x7 Government / Institutional Blood Bank (KIMS)',
          badges: ['Government', 'Institutional', 'Whole Blood', 'Platelets'],
          latLng: const LatLng(15.3577, 75.1160),
          phone: '+91 80227 29080',
        ),
        HealthCenter(
          id: 'hubballi_bb_kctri',
          name: 'KCTRI Blood Center - Smt Valbai N Dharamsey Blood Center',
          category: 'Blood Bank',
          rating: 4.6,
          reviews: 75,
          address: 'KCTRI Main Road, Navanagar, Hubballi – 580025',
          distance: 6.9,
          status: 'Open Now',
          statusDetails: '24x7 Institutional / Charitable Blood Bank',
          badges: ['Institutional', 'Charitable', 'Whole Blood'],
          latLng: const LatLng(15.3940, 75.0800),
          phone: '+91 93806 26370',
        ),
        HealthCenter(
          id: 'hubballi_bb_jeevannavars',
          name: 'Dr.Jeevannavars Blood Bank',
          category: 'Blood Bank',
          rating: 4.5,
          reviews: 62,
          address: 'Gokul Road, Sadashiv Nagar, Hubballi – 580021',
          distance: 2.0,
          status: 'Open Now',
          statusDetails: 'Private Blood Bank',
          badges: ['Private', 'Whole Blood'],
          latLng: const LatLng(15.3505, 75.1329),
          phone: '+91 836 227 8320',
        ),
        HealthCenter(
          id: 'hubballi_bb_lions',
          name: 'Hubli Lions Blood Bank',
          category: 'Blood Bank',
          rating: 4.8,
          reviews: 130,
          address: 'Vivekanand General Hospital Compound, Deshpande Nagar, Hubballi – 580029',
          distance: 1.2,
          status: 'Open Now',
          statusDetails: '24x7 NGO / Charitable Blood Bank',
          badges: ['NGO', 'Charitable', 'Whole Blood', 'PRBC'],
          latLng: const LatLng(15.3520, 75.1320),
          phone: '+91 836 225 8080',
        ),
        HealthCenter(
          id: 'hubballi_bb_myblood',
          name: 'MyBlood Charitable Blood Center, Hubballi',
          category: 'Blood Bank',
          rating: 4.4,
          reviews: 48,
          address: 'Vidya Nagar, Hubballi – 580021',
          distance: 1.8,
          status: 'Open Now',
          statusDetails: 'Charitable Blood Bank',
          badges: ['Charitable', 'Whole Blood'],
          latLng: const LatLng(15.3639, 75.1145),
          phone: 'Not verified',
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
        _routeDurationText = 'Direct Heading (Offline)';
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
              tileProvider: OfflineMapTileProvider(),
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
              const SizedBox(height: 6),
              // Offline Map Cache Button
              _buildMapButton(
                icon: Icons.offline_pin_rounded,
                tooltip: 'Offline Map Cache',
                color: const Color(0xFF0284C7),
                onTap: _showOfflineMapDialog,
              ),
            ],
          ),
        ),
      ],
    );
  }

  void _showOfflineMapDialog() async {
    final count = await OfflineMapCacheManager.getCachedTilesCount();
    final sizeBytes = await OfflineMapCacheManager.getCacheSizeBytes();
    final sizeMb = (sizeBytes / (1024 * 1024)).toStringAsFixed(1);

    if (!mounted) return;

    showDialog(
      context: context,
      builder: (ctx) {
        bool isDownloading = false;
        int currentProgress = 0;
        int totalProgress = 0;

        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              title: Row(
                children: const [
                  Icon(Icons.offline_pin_rounded, color: Color(0xFF0284C7)),
                  SizedBox(width: 8),
                  Text('Offline Map Storage', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                ],
              ),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Map tiles are automatically saved as you view them so you can navigate and locate hospitals when offline.',
                    style: TextStyle(fontSize: 13, color: Colors.black87),
                  ),
                  const SizedBox(height: 12),
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF1F5F9),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text('Saved Tiles:', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
                        Text('$count tiles (~$sizeMb MB)', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Color(0xFF0284C7))),
                      ],
                    ),
                  ),
                  if (isDownloading) ...[
                    const SizedBox(height: 16),
                    LinearProgressIndicator(
                      value: totalProgress > 0 ? currentProgress / totalProgress : null,
                      color: const Color(0xFF0284C7),
                      backgroundColor: const Color(0xFFE2E8F0),
                    ),
                    const SizedBox(height: 6),
                    Center(
                      child: Text(
                        'Downloading emergency map... $currentProgress / $totalProgress tiles',
                        style: const TextStyle(fontSize: 11, color: Colors.black54),
                      ),
                    ),
                  ],
                ],
              ),
              actions: [
                if (!isDownloading && count > 0)
                  TextButton(
                    onPressed: () async {
                      await OfflineMapCacheManager.clearCache();
                      if (context.mounted) Navigator.pop(context);
                      ScaffoldMessenger.of(this.context).showSnackBar(
                        const SnackBar(content: Text('Offline map cache cleared')),
                      );
                    },
                    child: const Text('Clear Cache', style: TextStyle(color: Colors.red)),
                  ),
                if (!isDownloading)
                  ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF0284C7),
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                    ),
                    icon: const Icon(Icons.download_rounded, size: 16),
                    label: const Text('Pre-download Area (4km)'),
                    onPressed: () async {
                      setDialogState(() {
                        isDownloading = true;
                        currentProgress = 0;
                        totalProgress = 0;
                      });

                      final downloaded = await OfflineMapCacheManager.precacheArea(
                        _userLocation,
                        minZoom: 13,
                        maxZoom: 15,
                        radiusKm: 4.0,
                        onProgress: (cur, tot) {
                          setDialogState(() {
                            currentProgress = cur;
                            totalProgress = tot;
                          });
                        },
                      );

                      if (context.mounted) Navigator.pop(context);
                      ScaffoldMessenger.of(this.context).showSnackBar(
                        SnackBar(content: Text('Successfully downloaded $downloaded tiles for offline emergency use!')),
                      );
                    },
                  ),
              ],
            );
          },
        );
      },
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

                  if (center.category == 'Hospital') ...[
                    GestureDetector(
                      onTap: () => _showHospitalDetailsSheet(center),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                        margin: const EdgeInsets.only(right: 6),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF0FDF4),
                          border: Border.all(color: const Color(0xFFBBF7D0)),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(Icons.info_outline_rounded, color: Color(0xFF16A34A), size: 18),
                            const SizedBox(height: 3),
                            Text(
                              'Details',
                              style: GoogleFonts.inter(
                                fontSize: 9.5,
                                fontWeight: FontWeight.w700,
                                color: const Color(0xFF16A34A),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],

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

  void _showHospitalDetailsSheet(HealthCenter center) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => _HospitalDetailModal(hospitalId: center.id, fallbackCenter: center),
    );
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

class _HospitalDetailModal extends StatefulWidget {
  final String hospitalId;
  final HealthCenter fallbackCenter;

  const _HospitalDetailModal({
    Key? key,
    required this.hospitalId,
    required this.fallbackCenter,
  }) : super(key: key);

  @override
  State<_HospitalDetailModal> createState() => _HospitalDetailModalState();
}

class _HospitalDetailModalState extends State<_HospitalDetailModal> {
  bool _isLoading = true;
  Map<String, dynamic>? _data;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _fetchDetails();
  }

  Future<void> _fetchDetails() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final res = await MedicalDataGateway.fetchHospital(widget.hospitalId);
      if (mounted) {
        setState(() {
          _isLoading = false;
          _data = res;
          if (res == null || res['ok'] != true) {
            _errorMessage = 'Hospital directory information is unavailable offline.';
          }
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          _isLoading = false;
          _errorMessage = 'Failed to load hospital directory data.';
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.only(
          topLeft: Radius.circular(24),
          topRight: Radius.circular(24),
        ),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Center(
            child: Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: const Color(0xFFE2E8F0),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: const Color(0xFFEFF6FF),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(Icons.local_hospital_rounded, color: Color(0xFF1E40AF), size: 24),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Hospital Directory Information',
                      style: GoogleFonts.inter(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: const Color(0xFF64748B),
                        letterSpacing: 0.5,
                      ),
                    ),
                    Text(
                      widget.fallbackCenter.name,
                      style: GoogleFonts.inter(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                        color: const Color(0xFF0F172A),
                      ),
                    ),
                  ],
                ),
              ),
              IconButton(
                icon: const Icon(Icons.close_rounded, size: 20),
                onPressed: () => Navigator.pop(context),
              ),
            ],
          ),
          const SizedBox(height: 16),
          if (_isLoading)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 36),
              child: Center(
                child: Column(
                  children: [
                    const CircularProgressIndicator(),
                    const SizedBox(height: 12),
                    Text(
                      'Retrieving hospital directory data...',
                      style: GoogleFonts.inter(fontSize: 13, color: const Color(0xFF64748B)),
                    ),
                  ],
                ),
              ),
            )
          else if (_errorMessage != null || _data == null)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 24),
              child: Column(
                children: [
                  const Icon(Icons.cloud_off_rounded, size: 40, color: Color(0xFF94A3B8)),
                  const SizedBox(height: 8),
                  Text(
                    _errorMessage ?? 'Information unavailable.',
                    textAlign: TextAlign.center,
                    style: GoogleFonts.inter(fontSize: 13, color: const Color(0xFF64748B)),
                  ),
                  const SizedBox(height: 12),
                  OutlinedButton(
                    onPressed: _fetchDetails,
                    child: const Text('Retry'),
                  ),
                ],
              ),
            )
          else ...[
            _buildProvenanceBanner(_data!),
            const SizedBox(height: 14),
            _buildHospitalContent(_data!['hospital'] as Map<String, dynamic>? ?? {}),
          ],
        ],
      ),
    );
  }

  Widget _buildProvenanceBanner(Map<String, dynamic> data) {
    final source = data['source'] as String? ?? 'online';
    final isMesh = source == 'mesh';
    final snapshotAt = data['snapshotAt']?.toString() ?? 'N/A';
    final deliveredAt = data['deliveredAt']?.toString() ?? 'N/A';

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: isMesh ? const Color(0xFFF0FDF4) : const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isMesh ? const Color(0xFFBBF7D0) : const Color(0xFFE2E8F0),
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            isMesh ? Icons.cell_tower_rounded : Icons.cloud_done_rounded,
            size: 20,
            color: isMesh ? const Color(0xFF15803D) : const Color(0xFF0F766E),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  isMesh ? 'Verified Offline Mesh Snapshot' : 'Live Online Directory Data',
                  style: GoogleFonts.inter(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: isMesh ? const Color(0xFF15803D) : const Color(0xFF0F766E),
                  ),
                ),
                if (isMesh) ...[
                  const SizedBox(height: 2),
                  Text(
                    'Snapshot: $snapshotAt\nDelivered: $deliveredAt',
                    style: GoogleFonts.inter(fontSize: 10.5, color: const Color(0xFF475569)),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    'Note: This is a point-in-time snapshot. Real-world status may change.',
                    style: GoogleFonts.inter(fontSize: 10, fontStyle: FontStyle.italic, color: const Color(0xFF64748B)),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHospitalContent(Map<String, dynamic> hospital) {
    final name = hospital['name']?.toString() ?? widget.fallbackCenter.name;
    final address = hospital['address']?.toString() ?? widget.fallbackCenter.address;
    final phone = hospital['phone']?.toString() ?? widget.fallbackCenter.phone;
    final status = hospital['status']?.toString() ?? widget.fallbackCenter.status;
    final bedCount = hospital['bedCount']?.toString() ?? '0';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          name,
          style: GoogleFonts.inter(fontSize: 15, fontWeight: FontWeight.w700, color: const Color(0xFF0F172A)),
        ),
        const SizedBox(height: 4),
        Text(
          address,
          style: GoogleFonts.inter(fontSize: 12, color: const Color(0xFF475569)),
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            const Icon(Icons.phone_outlined, size: 14, color: Color(0xFF2563EB)),
            const SizedBox(width: 4),
            Text(
              phone,
              style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w600, color: const Color(0xFF2563EB)),
            ),
            const SizedBox(width: 14),
            const Icon(Icons.king_bed_outlined, size: 14, color: Color(0xFF0F766E)),
            const SizedBox(width: 4),
            Text(
              'Beds: $bedCount',
              style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w600, color: const Color(0xFF0F766E)),
            ),
            const SizedBox(width: 14),
            Text(
              status,
              style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w600, color: const Color(0xFF15803D)),
            ),
          ],
        ),
      ],
    );
  }
}
