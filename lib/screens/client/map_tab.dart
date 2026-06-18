import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_map_cancellable_tile_provider/flutter_map_cancellable_tile_provider.dart';
import 'package:latlong2/latlong.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:geolocator/geolocator.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';
import '../../theme/app_theme.dart';
import '../../widgets/glass_card.dart';
import '../../services/auth_service.dart';
import '../../models/user_model.dart';
import '../../widgets/auth_prompt_dialog.dart';
import '../../constants.dart';
import '../../services/l10n_service.dart';

class MapTab extends StatefulWidget {
  const MapTab({Key? key}) : super(key: key);

  @override
  State<MapTab> createState() => _MapTabState();
}

// Vehicle mode model
enum VehicleMode { foot, moto, car }

extension VehicleModeExtension on VehicleMode {
  /// Mode de transport pour OSRM routing API
  String get osrmProfile {
    switch (this) {
      case VehicleMode.foot: return 'foot';
      case VehicleMode.moto: return 'car'; // moto uses car profile
      case VehicleMode.car:  return 'car';
    }
  }

  String get label {
    switch (this) {
      case VehicleMode.foot: return L10n.isArabic ? 'مشياً' : 'À pied';
      case VehicleMode.moto: return L10n.isArabic ? 'دراجة نارية' : 'Moto';
      case VehicleMode.car:  return L10n.isArabic ? 'سيارة' : 'Voiture';
    }
  }

  IconData get icon {
    switch (this) {
      case VehicleMode.foot: return Icons.directions_walk_rounded;
      case VehicleMode.moto: return Icons.two_wheeler_rounded;
      case VehicleMode.car:  return Icons.directions_car_rounded;
    }
  }

  Color get color {
    switch (this) {
      case VehicleMode.foot: return const Color(0xFF4CAF50);
      case VehicleMode.moto: return const Color(0xFFFF9800);
      case VehicleMode.car:  return const Color(0xFF2196F3);
    }
  }
}

class _MapTabState extends State<MapTab> {
  final AuthService _authService = AuthService();
  final MapController _mapController = MapController();
  final TextEditingController _searchController = TextEditingController();
  List<Map<String, dynamic>> _points = [];
  List<Map<String, dynamic>> _allPoints = [];
  bool _isLoading = true;
  String? _activeFilter;
  String _searchQuery = '';
  LatLng? _currentLocation;
  VehicleMode _selectedVehicle = VehicleMode.car;

  // ── Routing state ──────────────────────────────────────────────────────────
  List<LatLng> _routePoints = [];
  bool _isRouting = false;
  Map<String, dynamic>? _activeDestination; // le point vers lequel on navigue
  double? _routeDistanceKm;
  int? _routeDurationMin;

  // ── Dictionnaire bilingue FR / AR ─────────────────────────────────────────
  static const List<Map<String, String>> _typeMap = [
    {'key': 'tous',         'fr': 'Tous',         'ar': 'الكل'},
    {'key': 'plastique',    'fr': 'Plastique',    'ar': 'بلاستيك'},
    {'key': 'verre',        'fr': 'Verre',        'ar': 'زجاج'},
    {'key': 'papier',       'fr': 'Papier',       'ar': 'ورق'},
    {'key': 'carton',       'fr': 'Carton',       'ar': 'كرتون'},
    {'key': 'metal',        'fr': 'Métal',        'ar': 'معدن'},
    {'key': 'electronique', 'fr': 'Électronique', 'ar': 'إلكترونيات'},
    {'key': 'batteries',    'fr': 'Batteries',    'ar': 'بطاريات'},
    {'key': 'compost',      'fr': 'Compost',      'ar': 'سماد'},
    {'key': 'vetements',    'fr': 'Vêtements',    'ar': 'ملابس'},
    {'key': 'general',      'fr': 'Général',      'ar': 'عام'},
  ];

  String _norm(String s) => s.toLowerCase()
    .replaceAll(RegExp(r'[éèêë]'), 'e')
    .replaceAll(RegExp(r'[àâä]'), 'a')
    .replaceAll(RegExp(r'[îï]'), 'i')
    .replaceAll(RegExp(r'[ôö]'), 'o')
    .replaceAll(RegExp(r'[ùûü]'), 'u')
    .trim();

  List<String> _bilingualTerms(String key) {
    final e = _typeMap.firstWhere((m) => m['key'] == key, orElse: () => {});
    if (e.isEmpty) return [];
    return [_norm(e['fr']!), e['ar']!];
  }

  static const List<List<String>> _cityTranslations = [
    ['nabeul', 'نابل', 'hammamet', 'حمامت', 'kelibia', 'قليبية', 'beni khiar', 'بني خيار', 'la jarre'],
    ['tunis', 'تونس', 'bardo', 'باردو', 'carthage', 'قرطاج'],
    ['sousse', 'سوسة', 'hammam sousse', 'حمام سوسة', 'msaken', 'مساكن'],
    ['sfax', 'صفاقس'],
    ['bizerte', 'بنزرت', 'menzel bourguiba', 'منزل بورقيبة'],
    ['ariana', 'أريانة', 'raoued', 'راوض', 'ennasr', 'النصر'],
    ['ben arous', 'بن عروس', 'rades', 'رادس', 'megrine', 'مقرين', 'ezzahra', 'الزهراء'],
    ['manouba', 'منوبة', 'oued ellil', 'وادي الليل', 'douar hicher', 'دوار هيشر'],
    ['monastir', 'المنستير', 'skanes', 'سكانس'],
    ['mahdia', 'المهدية'],
    ['kairouan', 'القيروان'],
    ['kasserine', 'القصرين'],
    ['gabes', 'قابس', 'gabès'],
    ['gafsa', 'قفصة'],
    ['medenine', 'مدنين', 'médenine', 'djerba', 'جربة', 'houmt souk', 'حومة السوق'],
    ['tozeur', 'توزر'],
    ['tataouine', 'تطاوين'],
    ['zaghouan', 'زغوان'],
    ['siliana', 'سليانة'],
    ['jendouba', 'جندوبة'],
    ['kef', 'الكاف', 'le kef'],
    ['sidi bouzid', 'سيدي بوزيد'],
    ['beja', 'باجة', 'béja'],
  ];

  List<String> _expandQuery(String query) {
    final q = query.trim();
    if (q.isEmpty) return [];
    final normalized = _norm(q);
    for (final group in _cityTranslations) {
      final normGroup = group.map(_norm).toList();
      if (normGroup.any((t) => t.contains(normalized) || normalized.contains(t)) ||
          group.any((t) => t.contains(q) || q.contains(t))) {
        return group;
      }
    }
    return [q];
  }

  static const _kCachePoints   = 'map_points_cache_v2';
  static const _kCacheVersion  = 'map_points_version_v2';
  bool _isRefreshing = false;

  @override
  void initState() {
    super.initState();
    L10n.addListener(_onLocaleChange);
    _loadFromCache();
    _checkAndRefreshCache();
  }

  void _onLocaleChange() {
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    L10n.removeListener(_onLocaleChange);
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadFromCache() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_kCachePoints);
      if (raw != null && raw.isNotEmpty) {
        final List<dynamic> decoded = json.decode(raw);
        if (decoded.isNotEmpty && mounted) {
          _allPoints = decoded.cast<Map<String, dynamic>>();
          _applyFilters();
          setState(() => _isLoading = false);
          return;
        }
      }
      await _fetchAndCachePoints();
    } catch (_) {
      await _fetchAndCachePoints();
    }
  }

  Future<void> _checkAndRefreshCache() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final cachedVersion = prefs.getDouble(_kCacheVersion) ?? 0.0;
      final uri = Uri.parse('${ApiConstants.baseUrl}/collection-points/version');
      final resp = await http.get(uri).timeout(const Duration(seconds: 5));
      if (resp.statusCode != 200) return;
      final serverVersion = (json.decode(resp.body)['version'] as num).toDouble();
      if (serverVersion > cachedVersion) {
        if (mounted) setState(() => _isRefreshing = true);
        await _fetchAndCachePoints(newVersion: serverVersion);
        if (mounted) setState(() => _isRefreshing = false);
      }
    } catch (_) {}
  }

  Future<void> _fetchAndCachePoints({double? newVersion}) async {
    if (_allPoints.isEmpty && mounted) setState(() => _isLoading = true);
    try {
      final points = await _authService.fetchCollectionPoints();
      if (!mounted) return;
      if (points.isNotEmpty) {
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString(_kCachePoints, json.encode(points));
        if (newVersion != null) await prefs.setDouble(_kCacheVersion, newVersion);
        _allPoints = points;
        _applyFilters();
      }
      if (mounted) setState(() => _isLoading = false);
    } catch (e) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _applyFilters() {
    final rawQuery = _searchQuery.trim();
    final key = _activeFilter;
    final terms = key != null && key != 'tous' ? _bilingualTerms(key) : <String>[];
    final expandedTerms = rawQuery.isEmpty ? <String>[] : _expandQuery(rawQuery);

    final filtered = _allPoints.where((p) {
      final name    = (p['name']    ?? '').toString();
      final address = (p['address'] ?? '').toString();
      final nameN    = _norm(name);
      final addressN = _norm(address);

      bool matchSearch = rawQuery.isEmpty;
      if (!matchSearch) {
        matchSearch = expandedTerms.any((term) {
          final termN = _norm(term);
          return nameN.contains(termN) || addressN.contains(termN) ||
                 name.toLowerCase().contains(term.toLowerCase()) ||
                 address.toLowerCase().contains(term.toLowerCase());
        });
      }

      bool matchType = terms.isEmpty;
      if (!matchType) {
        final rawTypes = p['types'];
        final typeList = rawTypes is List
            ? rawTypes.map((t) => t.toString()).toList()
            : <String>[];
        matchType = typeList.any((t) {
          final tn = _norm(t);
          final tar = t.trim();
          return terms.any((term) => tn.contains(term) || tar.contains(term));
        });
      }

      return matchSearch && matchType;
    }).toList();

    setState(() => _points = filtered);
  }

  Future<void> _fetchCurrentLocation() async {
    try {
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) throw 'Service de localisation désactivé';

      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) throw 'Permission refusée';
      }

      final pos = await Geolocator.getCurrentPosition(desiredAccuracy: LocationAccuracy.high);
      if (mounted) {
        setState(() => _currentLocation = LatLng(pos.latitude, pos.longitude));
        _mapController.move(_currentLocation!, 14);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(e.toString()),
            backgroundColor: Colors.red,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          ),
        );
      }
    }
  }

  // ──────────────────────────────────────────────────────────────────────────
  // Navigation intégrée via OSRM (Open Source Routing Machine — pas Google Maps)
  // ──────────────────────────────────────────────────────────────────────────
  Future<void> _navigateInApp(
    double destLat,
    double destLng,
    Map<String, dynamic> point,
  ) async {
    // Fermer la bottom sheet si elle est ouverte
    if (mounted && Navigator.canPop(context)) Navigator.pop(context);

    // Obtenir la position si pas encore connue
    if (_currentLocation == null) {
      await _fetchCurrentLocation();
      if (_currentLocation == null) return;
    }

    setState(() {
      _isRouting = true;
      _routePoints = [];
      _routeDistanceKm = null;
      _routeDurationMin = null;
      _activeDestination = point;
    });

    try {
      final start = _currentLocation!;
      final profile = _selectedVehicle.osrmProfile;

      // Appel à l'API OSRM publique (OpenStreetMap, gratuit, sans Google Maps)
      final url =
          'https://routing.openstreetmap.de/routed-$profile/route/v1/driving/'
          '${start.longitude},${start.latitude};'
          '$destLng,$destLat'
          '?overview=full&geometries=geojson&steps=false';

      final response = await http
          .get(Uri.parse(url))
          .timeout(const Duration(seconds: 10));

      if (response.statusCode != 200) throw 'Erreur réseau OSRM';

      final data = json.decode(response.body);
      if (data['code'] != 'Ok' || (data['routes'] as List).isEmpty) {
        throw 'Aucun itinéraire trouvé';
      }

      final route = data['routes'][0];
      final double distanceM = (route['distance'] as num).toDouble();
      final double durationS = (route['duration'] as num).toDouble();

      final List<dynamic> coords = route['geometry']['coordinates'];
      final List<LatLng> routeLatLngs =
          coords.map((c) => LatLng((c[1] as num).toDouble(), (c[0] as num).toDouble())).toList();

      if (mounted) {
        setState(() {
          _routePoints = routeLatLngs;
          _routeDistanceKm = distanceM / 1000;
          _routeDurationMin = (durationS / 60).ceil();
          _isRouting = false;
        });

        // Centrer la carte pour afficher tout l'itinéraire
        if (routeLatLngs.isNotEmpty) {
          final bounds = LatLngBounds.fromPoints(routeLatLngs);
          _mapController.fitCamera(
            CameraFit.bounds(
              bounds: bounds,
              padding: const EdgeInsets.fromLTRB(40, 120, 40, 240),
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isRouting = false;
          _activeDestination = null;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Impossible de calculer l\'itinéraire : $e'),
            backgroundColor: Colors.red,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          ),
        );
      }
    }
  }

  void _clearRoute() {
    setState(() {
      _routePoints = [];
      _activeDestination = null;
      _routeDistanceKm = null;
      _routeDurationMin = null;
    });
  }

  // ──────────────────────────────────────────────────────────────────────────
  // Trouver le point de tri le plus proche et naviguer vers lui (sans Google Maps)
  // ──────────────────────────────────────────────────────────────────────────
  bool _isFindingNearest = false;

  Future<void> _findAndNavigateToNearestPoint() async {
    if (_isFindingNearest || _isRouting) return;

    if (_allPoints.isEmpty) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Aucun point de tri chargé. Veuillez vérifier votre connexion.',
              style: GoogleFonts.inter(fontSize: 13),
            ),
            backgroundColor: Colors.orange.shade700,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          ),
        );
      }
      return;
    }

    if (mounted) setState(() => _isFindingNearest = true);

    try {
      // 1. Obtenir la position actuelle
      await _fetchCurrentLocation();
      if (_currentLocation == null || !mounted) {
        setState(() => _isFindingNearest = false);
        return;
      }

      // 2. Calculer la distance vers chaque point et trouver le plus proche
      Map<String, dynamic>? nearest;
      double minDistM = double.infinity;

      for (final p in _allPoints) {
        final lat = (p['lat'] as num?)?.toDouble();
        final lng = (p['lng'] as num?)?.toDouble();
        if (lat == null || lng == null) continue;
        final dist = Geolocator.distanceBetween(
          _currentLocation!.latitude,
          _currentLocation!.longitude,
          lat,
          lng,
        );
        if (dist < minDistM) {
          minDistM = dist;
          nearest = p;
        }
      }

      if (nearest == null || !mounted) {
        setState(() => _isFindingNearest = false);
        return;
      }

      // 3. Confirmer à l'utilisateur
      final distStr = minDistM < 1000
          ? '${minDistM.round()} m'
          : '${(minDistM / 1000).toStringAsFixed(1)} km';

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              const Icon(Icons.location_on_rounded, color: Colors.white, size: 18),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  '${nearest['name']} · $distStr',
                  style: GoogleFonts.inter(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: Colors.white,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          backgroundColor: AppTheme.primaryGreen,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          duration: const Duration(seconds: 3),
        ),
      );

      if (mounted) setState(() => _isFindingNearest = false);

      // 4. Lancer la navigation intégrée (OSRM — pas Google Maps)
      await _navigateInApp(
        (nearest['lat'] as num).toDouble(),
        (nearest['lng'] as num).toDouble(),
        nearest,
      );
    } catch (e) {
      if (mounted) {
        setState(() => _isFindingNearest = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Erreur : $e', style: GoogleFonts.inter(fontSize: 13)),
            backgroundColor: Colors.red,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          ),
        );
      }
    }
  }

  void _onFilterTap(String key) {
    setState(() => _activeFilter = (key == 'tous') ? null : key);
    _applyFilters();
  }

  void _onSearch(String query) {
    _searchQuery = query;
    _applyFilters();
  }

  void _showPointDetails(BuildContext context, Map<String, dynamic> point) {
    if (!AuthState.isLoggedIn) {
      AuthPromptDialog.show(context: context);
      return;
    }
    final types = (point['types'] as List<dynamic>?)?.join(', ') ?? '';
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (ctx) => _PointDetailSheet(
        point: point,
        types: types,
        selectedVehicle: _selectedVehicle,
        onVehicleChanged: (mode) => setState(() => _selectedVehicle = mode),
        onNavigate: () => _navigateInApp(
          (point['lat'] as num).toDouble(),
          (point['lng'] as num).toDouble(),
          point,
        ),
      ),
    );
  }


  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          // ── Carte flutter_map ────────────────────────────────────────────
          FlutterMap(
            mapController: _mapController,
            options: const MapOptions(
              initialCenter: LatLng(36.8065, 10.1815),
              initialZoom: 11.5,
              minZoom: 5,
            ),
            children: [
              TileLayer(
                urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                userAgentPackageName: 'com.ecorewind.app',
                tileProvider: CancellableNetworkTileProvider(),
                errorTileCallback: (tile, error, stackTrace) {
                  // Tuiles inaccessibles (pas de réseau) → échec silencieux
                },
              ),

              // ── Tracé de l'itinéraire ────────────────────────────────
              if (_routePoints.isNotEmpty)
                PolylineLayer(
                  polylines: [
                    // Halo blanc derrière pour la lisibilité
                    Polyline(
                      points: _routePoints,
                      strokeWidth: 8.0,
                      color: Colors.white.withOpacity(0.7),
                    ),
                    // Trait coloré selon le mode de transport
                    Polyline(
                      points: _routePoints,
                      strokeWidth: 5.0,
                      color: _selectedVehicle.color,
                      strokeCap: StrokeCap.round,
                      strokeJoin: StrokeJoin.round,
                    ),
                  ],
                ),

              MarkerLayer(
                markers: [
                  ..._points.map((p) => _buildMapMarker(
                    context,
                    LatLng((p['lat'] as num).toDouble(), (p['lng'] as num).toDouble()),
                    p['name'] ?? '',
                    p['is_verified'] == true,
                    p,
                  )),
                  if (_currentLocation != null)
                    Marker(
                      point: _currentLocation!,
                      width: 50,
                      height: 50,
                      child: const Icon(Icons.my_location_rounded, color: Colors.blue, size: 30)
                          .animate(onPlay: (c) => c.repeat(reverse: true))
                          .scale(begin: const Offset(1, 1), end: const Offset(1.2, 1.2), duration: 1.seconds),
                    ),
                  // Marqueur de destination de l'itinéraire actif
                  if (_activeDestination != null)
                    Marker(
                      point: LatLng(
                        (_activeDestination!['lat'] as num).toDouble(),
                        (_activeDestination!['lng'] as num).toDouble(),
                      ),
                      width: 60,
                      height: 60,
                      child: Column(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(10),
                            decoration: BoxDecoration(
                              color: _selectedVehicle.color,
                              shape: BoxShape.circle,
                              border: Border.all(color: Theme.of(context).colorScheme.surface, width: 3),
                              boxShadow: [
                                BoxShadow(
                                  color: _selectedVehicle.color.withOpacity(0.5),
                                  blurRadius: 15,
                                  spreadRadius: 3,
                                ),
                              ],
                            ),
                            child: Icon(_selectedVehicle.icon, color: Colors.white, size: 18),
                          ),
                        ],
                      ).animate(onPlay: (c) => c.repeat(reverse: true))
                          .scale(begin: const Offset(1, 1), end: const Offset(1.1, 1.1), duration: 1.seconds),
                    ),
                ],
              ),
            ],
          ),

          // ── Overlay de chargement initial ────────────────────────────────
          if (_isLoading)
            Positioned(
              top: 140, left: 0, right: 0,
              child: Center(
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.surface, borderRadius: BorderRadius.circular(20),
                    boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.1), blurRadius: 10)],
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: AppTheme.primaryGreen)),
                      const SizedBox(width: 10),
                      Text('Chargement des points...', style: GoogleFonts.inter(fontSize: 12, color: Theme.of(context).colorScheme.onSurface.withOpacity(0.6))),
                    ],
                  ),
                ),
              ),
            ),

          // ── Indicateur de calcul d'itinéraire ────────────────────────────
          if (_isRouting)
            Positioned(
              top: 140, left: 0, right: 0,
              child: Center(
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.surface,
                    borderRadius: BorderRadius.circular(20),
                    boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.12), blurRadius: 12)],
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      SizedBox(
                        width: 16, height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2.5, color: _selectedVehicle.color),
                      ),
                      const SizedBox(width: 12),
                      Text(
                        'Calcul de l\'itinéraire...',
                        style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w600, color: Theme.of(context).colorScheme.onSurface),
                      ),
                    ],
                  ),
                ),
              ).animate().fadeIn(duration: 200.ms),
            ),

          // ── Indicateur de mise à jour silencieuse ──────────────────────
          if (_isRefreshing && !_isLoading)
            Positioned(
              top: 100, right: 16,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: AppTheme.primaryGreen,
                  borderRadius: BorderRadius.circular(20),
                  boxShadow: [BoxShadow(color: AppTheme.primaryGreen.withOpacity(0.3), blurRadius: 8)],
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const SizedBox(width: 12, height: 12, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white)),
                    const SizedBox(width: 8),
                    Text('Mise à jour...', style: GoogleFonts.inter(fontSize: 11, color: Colors.white, fontWeight: FontWeight.w600)),
                  ],
                ),
              ).animate().fadeIn(duration: 300.ms),
            ),

          // ── Gradient top/bottom ──────────────────────────────────────────
          IgnorePointer(
            child: Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [Colors.white.withOpacity(0.9), Colors.transparent, Colors.transparent, Colors.white.withOpacity(0.8)],
                  stops: const [0.0, 0.15, 0.85, 1.0],
                ),
              ),
            ),
          ),

          // ── Barre de recherche + filtres ─────────────────────────────────
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  GlassCard(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    child: Row(
                      children: [
                        const Icon(Icons.search, color: AppTheme.primaryGreen, size: 20),
                        const SizedBox(width: 10),
                        Expanded(
                          child: TextField(
                            controller: _searchController,
                            onChanged: _onSearch,
                            onSubmitted: _onSearch,
                            style: GoogleFonts.inter(fontSize: 14),
                            decoration: const InputDecoration(
                              hintText: 'بحث / Rechercher un point de tri...',
                              hintStyle: TextStyle(color: AppTheme.textMuted, fontSize: 13),
                              border: InputBorder.none,
                              enabledBorder: InputBorder.none,
                              focusedBorder: InputBorder.none,
                              fillColor: Colors.transparent,
                              filled: false,
                              isDense: true,
                              contentPadding: EdgeInsets.zero,
                            ),
                          ),
                        ),
                        const Icon(Icons.tune_rounded, color: AppTheme.textMuted, size: 18),
                      ],
                    ),
                  ).animate().fadeIn().slideY(begin: -0.2),
                  const SizedBox(height: 10),
                  _buildCategories().animate().fadeIn(delay: 400.ms),
                ],
              ),
            ),
          ),

          // ── Panneau d'itinéraire actif ────────────────────────────────────
          if (_activeDestination != null && _routePoints.isNotEmpty)
            Positioned(
              bottom: 0, left: 0, right: 0,
              child: _RouteInfoPanel(
                destination: _activeDestination!,
                distanceKm: _routeDistanceKm,
                durationMin: _routeDurationMin,
                vehicle: _selectedVehicle,
                onClose: _clearRoute,
              ).animate().slideY(begin: 1, end: 0, duration: 400.ms, curve: Curves.easeOutCubic),
            ),

          // ── Bouton « Point le plus proche » ──────────────────────────────
          if (!_isLoading && _activeDestination == null)
            Positioned(
              bottom: 192,
              left: 0,
              right: 0,
              child: Center(
                child: GestureDetector(
                  onTap: _isFindingNearest ? null : _findAndNavigateToNearestPoint,
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 13),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: _isFindingNearest
                            ? [Colors.grey.shade400, Colors.grey.shade500]
                            : [AppTheme.primaryGreen, const Color(0xFF059669)],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      borderRadius: BorderRadius.circular(32),
                      boxShadow: [
                        BoxShadow(
                          color: AppTheme.primaryGreen.withOpacity(_isFindingNearest ? 0.1 : 0.45),
                          blurRadius: 20,
                          spreadRadius: 2,
                          offset: const Offset(0, 6),
                        ),
                      ],
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        if (_isFindingNearest)
                          const SizedBox(
                            width: 16, height: 16,
                            child: CircularProgressIndicator(
                              strokeWidth: 2.5, color: Colors.white,
                            ),
                          )
                        else
                          const Icon(Icons.near_me_rounded, color: Colors.white, size: 18),
                        const SizedBox(width: 10),
                        Text(
                          _isFindingNearest
                              ? 'Recherche en cours...'
                              : 'Point le plus proche',
                          style: GoogleFonts.outfit(
                            color: Colors.white,
                            fontWeight: FontWeight.w800,
                            fontSize: 14,
                            letterSpacing: 0.2,
                          ),
                        ),
                      ],
                    ),
                  ),
                ).animate().fadeIn(delay: 700.ms).scale(
                  begin: const Offset(0.85, 0.85),
                  end: const Offset(1, 1),
                  duration: 400.ms,
                  curve: Curves.easeOutBack,
                ),
              ),
            ),

          // ── Compteur de points ────────────────────────────────────────────
          if (!_isLoading && _activeDestination == null)
            Positioned(
              bottom: 148, left: 24,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.surface, borderRadius: BorderRadius.circular(20),
                  boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.1), blurRadius: 10)],
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (_isRefreshing)
                      const Padding(
                        padding: EdgeInsets.only(right: 6),
                        child: SizedBox(
                          width: 10, height: 10,
                          child: CircularProgressIndicator(strokeWidth: 1.5, color: AppTheme.primaryGreen),
                        ),
                      ),
                    Text(
                      '${_points.length} point${_points.length != 1 ? 's' : ''} de tri',
                      style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w700, color: Theme.of(context).colorScheme.onSurface),
                    ),
                  ],
                ),
              ),
            ),

          // ── Bouton ma position & contrôles de zoom ────────────────────────
          Positioned(
            bottom: _activeDestination != null && _routePoints.isNotEmpty ? 220 : 140,
            right: 24,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                FloatingActionButton.small(
                  heroTag: 'fab_map_zoom_in',
                  onPressed: () {
                    final currentZoom = _mapController.camera.zoom;
                    _mapController.move(_mapController.camera.center, currentZoom + 1);
                  },
                  backgroundColor: Theme.of(context).colorScheme.surface,
                  child: const Icon(Icons.add, color: AppTheme.primaryGreen),
                ),
                const SizedBox(height: 8),
                FloatingActionButton.small(
                  heroTag: 'fab_map_zoom_out',
                  onPressed: () {
                    final currentZoom = _mapController.camera.zoom;
                    _mapController.move(_mapController.camera.center, currentZoom - 1);
                  },
                  backgroundColor: Theme.of(context).colorScheme.surface,
                  child: const Icon(Icons.remove, color: AppTheme.primaryGreen),
                ),
                const SizedBox(height: 8),
                FloatingActionButton(
                  heroTag: 'fab_map_location',
                  onPressed: _fetchCurrentLocation,
                  backgroundColor: Theme.of(context).colorScheme.surface,
                  child: const Icon(Icons.my_location, color: AppTheme.primaryGreen),
                ),
              ],
            ).animate().scale(delay: 1.seconds),
          ),

          // ── Bouton rafraîchir ─────────────────────────────────────────────
          if (_activeDestination == null)
            Positioned(
              bottom: 140, left: 24 + 120,
              child: FloatingActionButton.small(
                heroTag: 'fab_map_refresh',
                onPressed: _isRefreshing ? null : () async {
                  final prefs = await SharedPreferences.getInstance();
                  await prefs.setDouble(_kCacheVersion, 0.0);
                  if (mounted) setState(() => _isRefreshing = true);
                  await _fetchAndCachePoints();
                  if (mounted) setState(() => _isRefreshing = false);
                },
                backgroundColor: Theme.of(context).colorScheme.surface,
                child: _isRefreshing
                    ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: AppTheme.primaryGreen))
                    : const Icon(Icons.refresh_rounded, color: AppTheme.primaryGreen, size: 20),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildCategories() {
    return SizedBox(
      height: 44,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        itemCount: _typeMap.length,
        itemBuilder: (context, index) {
          final entry = _typeMap[index];
          final key = entry['key']!;
          final isActive = (key == 'tous' && _activeFilter == null) ||
              (_activeFilter == key);
          return GestureDetector(
            onTap: () => _onFilterTap(key),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              margin: const EdgeInsets.only(right: 10),
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
              decoration: BoxDecoration(
                color: isActive ? AppTheme.primaryGreen : Colors.white,
                borderRadius: BorderRadius.circular(22),
                boxShadow: isActive
                    ? [BoxShadow(
                        color: AppTheme.primaryGreen.withOpacity(0.35),
                        blurRadius: 10, offset: const Offset(0, 4))]
                    : AppTheme.premiumShadow,
                border: Border.all(
                  color: isActive ? AppTheme.primaryGreen : Colors.transparent,
                  width: 1.5,
                ),
              ),
              child: Row(mainAxisSize: MainAxisSize.min, children: [
                Text(
                  entry['fr']!,
                  style: TextStyle(
                    color: isActive ? Colors.white : AppTheme.textMuted,
                    fontWeight: FontWeight.w700,
                    fontSize: 11,
                  ),
                ),
                if (key != 'tous') ...[
                  Container(
                    margin: const EdgeInsets.symmetric(horizontal: 5),
                    width: 1, height: 12,
                    color: isActive
                        ? Colors.white.withOpacity(0.4)
                        : Colors.grey.shade300,
                  ),
                  Text(
                    entry['ar']!,
                    style: TextStyle(
                      color: isActive
                          ? Colors.white.withOpacity(0.9)
                          : AppTheme.textMuted,
                      fontWeight: FontWeight.w600,
                      fontSize: 11,
                    ),
                  ),
                ],
              ]),
            ),
          );
        },
      ),
    );
  }

  Marker _buildMapMarker(BuildContext context, LatLng point, String name, bool isVerified, Map<String, dynamic> data) {
    final bool isActiveRoute = _activeDestination != null &&
        _activeDestination!['lat'] == data['lat'] &&
        _activeDestination!['lng'] == data['lng'];

    return Marker(
      point: point,
      width: 100,
      height: 100,
      child: GestureDetector(
        onTap: () => _showPointDetails(context, data),
        child: Column(
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: isActiveRoute ? _selectedVehicle.color : AppTheme.primaryGreen,
                shape: BoxShape.circle,
                boxShadow: [BoxShadow(
                  color: (isActiveRoute ? _selectedVehicle.color : AppTheme.primaryGreen).withOpacity(0.4),
                  blurRadius: 15,
                  spreadRadius: 5,
                )],
                border: Border.all(color: Colors.white, width: 3),
              ),
              child: Icon(
                isActiveRoute ? _selectedVehicle.icon : Icons.recycling,
                color: Colors.white,
                size: 20,
              ),
            ),
            const SizedBox(height: 4),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.9),
                borderRadius: BorderRadius.circular(12),
                boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.1), blurRadius: 4, offset: const Offset(0, 2))],
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Flexible(child: Text(name, style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: AppTheme.deepSlate), overflow: TextOverflow.ellipsis)),
                  if (isVerified) const SizedBox(width: 4),
                  if (isVerified) const Icon(Icons.verified, color: AppTheme.primaryGreen, size: 10),
                ],
              ),
            ),
          ],
        ),
      ).animate(onPlay: (c) => c.repeat(reverse: true)).slideY(begin: 0, end: -0.1, duration: 2.seconds),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Bottom sheet des détails d'un point
// ─────────────────────────────────────────────────────────────────────────────
class _PointDetailSheet extends StatefulWidget {
  final Map<String, dynamic> point;
  final String types;
  final VehicleMode selectedVehicle;
  final void Function(VehicleMode) onVehicleChanged;
  final VoidCallback onNavigate;

  const _PointDetailSheet({
    required this.point,
    required this.types,
    required this.selectedVehicle,
    required this.onVehicleChanged,
    required this.onNavigate,
  });

  @override
  State<_PointDetailSheet> createState() => _PointDetailSheetState();
}

class _PointDetailSheetState extends State<_PointDetailSheet> {
  late VehicleMode _vehicle;

  @override
  void initState() {
    super.initState();
    _vehicle = widget.selectedVehicle;
  }

  @override
  Widget build(BuildContext context) {
    final point = widget.point;
    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      padding: EdgeInsets.only(
        left: 24,
        right: 24,
        top: 24,
        bottom: MediaQuery.of(context).viewInsets.bottom + 24,
      ),
      constraints: BoxConstraints(
        maxHeight: MediaQuery.of(context).size.height * 0.85,
      ),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 40, height: 4,
                decoration: BoxDecoration(color: Colors.grey.shade300, borderRadius: BorderRadius.circular(2)),
              ),
            ),
            const SizedBox(height: 20),
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: AppTheme.primaryGreen.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: const Icon(Icons.recycling, color: AppTheme.primaryGreen, size: 24),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Flexible(
                            child: Text(
                              point['name'] ?? '',
                              style: GoogleFonts.outfit(fontSize: 20, fontWeight: FontWeight.w800, color: AppTheme.deepNavy),
                            ),
                          ),
                          if (point['is_verified'] == true) ...[
                            const SizedBox(width: 6),
                            const Icon(Icons.verified, color: AppTheme.primaryGreen, size: 18),
                          ],
                        ],
                      ),
                      if (point['address'] != null)
                        Text(point['address'], style: GoogleFonts.inter(fontSize: 13, color: AppTheme.textMuted)),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),
            _infoRow(Icons.access_time_rounded, 'Horaires', point['hours'] ?? 'Non spécifié'),
            const SizedBox(height: 10),
            _infoRow(Icons.delete_outline_rounded, 'Déchets acceptés', widget.types.isEmpty ? 'Non spécifié' : widget.types),
            const SizedBox(height: 20),

            // Sélecteur de mode de transport
            Text(
              'Mode de transport',
              style: GoogleFonts.outfit(fontWeight: FontWeight.w700, fontSize: 13, color: AppTheme.deepNavy),
            ),
            const SizedBox(height: 12),
            Row(
              children: VehicleMode.values.map((mode) {
                final selected = _vehicle == mode;
                return Expanded(
                  child: GestureDetector(
                    onTap: () {
                      setState(() => _vehicle = mode);
                      widget.onVehicleChanged(mode);
                    },
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 200),
                      margin: const EdgeInsets.only(right: 8),
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 12),
                      decoration: BoxDecoration(
                        color: selected ? mode.color.withOpacity(0.12) : (Theme.of(context).brightness == Brightness.dark ? const Color(0xFF1E293B) : Colors.grey.shade100),
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(
                          color: selected ? mode.color : Colors.transparent,
                          width: 2,
                        ),
                      ),
                      child: Column(
                        children: [
                          Icon(mode.icon, color: selected ? mode.color : Colors.grey.shade400, size: 26),
                          const SizedBox(height: 6),
                          Text(
                            mode.label,
                            style: GoogleFonts.inter(
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                              color: selected ? mode.color : Colors.grey.shade500,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                );
              }).toList(),
            ),
            const SizedBox(height: 20),

            // Bouton naviguer (intégré dans l'app, pas Google Maps)
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: widget.onNavigate,
                icon: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.navigation_rounded, color: Colors.white, size: 20),
                    const SizedBox(width: 4),
                    Icon(_vehicle.icon, color: Colors.white, size: 18),
                  ],
                ),
                label: Text(
                  'ITINÉRAIRE INTÉGRÉ',
                  style: GoogleFonts.outfit(
                    fontWeight: FontWeight.w800,
                    fontSize: 13,
                    letterSpacing: 0.5,
                    color: Colors.white,
                  ),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: _vehicle.color,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                ),
              ),
            ),
            const SizedBox(height: 8),
            // Note explicative
            Center(
              child: Text(
                '🗺️ Navigation intégrée — fonctionne sans Google Maps',
                style: GoogleFonts.inter(
                  fontSize: 11,
                  color: AppTheme.textMuted,
                  fontStyle: FontStyle.italic,
                ),
              ),
            ),
            const SizedBox(height: 12),
          ],
        ),
      ),
    );
  }

  Widget _infoRow(IconData icon, String label, String value) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 18, color: AppTheme.primaryGreen),
        const SizedBox(width: 10),
        Flexible(
          child: RichText(
            text: TextSpan(
              children: [
                TextSpan(
                  text: '$label : ',
                  style: GoogleFonts.inter(fontWeight: FontWeight.w700, fontSize: 13, color: AppTheme.deepNavy),
                ),
                TextSpan(
                  text: value,
                  style: GoogleFonts.inter(fontSize: 13, color: AppTheme.textMuted),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Panneau d'itinéraire actif (bas de l'écran)
// ─────────────────────────────────────────────────────────────────────────────
class _RouteInfoPanel extends StatelessWidget {
  final Map<String, dynamic> destination;
  final double? distanceKm;
  final int? durationMin;
  final VehicleMode vehicle;
  final VoidCallback onClose;

  const _RouteInfoPanel({
    required this.destination,
    required this.distanceKm,
    required this.durationMin,
    required this.vehicle,
    required this.onClose,
  });

  @override
  Widget build(BuildContext context) {
    final distStr = distanceKm != null
        ? distanceKm! < 1
            ? '${(distanceKm! * 1000).round()} m'
            : '${distanceKm!.toStringAsFixed(1)} km'
        : '—';
    final durStr = durationMin != null
        ? durationMin! < 60
            ? '$durationMin min'
            : '${durationMin! ~/ 60}h ${durationMin! % 60}min'
        : '—';

    return Container(
      margin: const EdgeInsets.fromLTRB(12, 0, 12, 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(color: Colors.black.withOpacity(0.15), blurRadius: 20, offset: const Offset(0, -4)),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: vehicle.color.withOpacity(0.12),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Icon(vehicle.icon, color: vehicle.color, size: 24),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        destination['name'] ?? 'Destination',
                        style: GoogleFonts.outfit(
                          fontSize: 16,
                          fontWeight: FontWeight.w800,
                          color: AppTheme.deepNavy,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      Text(
                        destination['address'] ?? '',
                        style: GoogleFonts.inter(fontSize: 12, color: AppTheme.textMuted),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
                GestureDetector(
                  onTap: onClose,
                  child: Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Theme.of(context).brightness == Brightness.dark ? const Color(0xFF1E293B) : Colors.grey.shade100,
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.close_rounded, size: 18, color: AppTheme.textMuted),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: _StatChip(
                    icon: Icons.straighten_rounded,
                    label: 'Distance',
                    value: distStr,
                    color: vehicle.color,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _StatChip(
                    icon: Icons.timer_outlined,
                    label: 'Durée estimée',
                    value: durStr,
                    color: vehicle.color,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _StatChip(
                    icon: Icons.route_rounded,
                    label: 'Mode',
                    value: vehicle.label,
                    color: vehicle.color,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.symmetric(vertical: 10),
              decoration: BoxDecoration(
                color: vehicle.color.withOpacity(0.05),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: vehicle.color.withOpacity(0.15)),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.check_circle_rounded, color: vehicle.color, size: 16),
                  const SizedBox(width: 8),
                  Text(
                    'Itinéraire tracé sur la carte • Navigation intégrée',
                    style: GoogleFonts.inter(
                      fontSize: 11,
                      color: vehicle.color,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _StatChip extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final Color color;

  const _StatChip({
    required this.icon,
    required this.label,
    required this.value,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: color.withOpacity(0.07),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: color, size: 16),
          const SizedBox(height: 4),
          Text(
            value,
            style: GoogleFonts.spaceGrotesk(
              fontSize: 14,
              fontWeight: FontWeight.w800,
              color: AppTheme.deepNavy,
            ),
          ),
          Text(
            label,
            style: GoogleFonts.inter(
              fontSize: 10,
              color: AppTheme.textMuted,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }
}
