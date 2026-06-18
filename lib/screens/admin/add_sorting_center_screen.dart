import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_map_cancellable_tile_provider/flutter_map_cancellable_tile_provider.dart';
import 'package:latlong2/latlong.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:geolocator/geolocator.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'dart:async';
import 'dart:ui';
import '../../theme/app_theme.dart';
import '../../widgets/premium_widgets.dart';
import '../../widgets/web_back_button.dart';
import '../../services/auth_service.dart';

class AddSortingCenterScreen extends StatefulWidget {
  final Map<String, dynamic>? existingCenter;
  const AddSortingCenterScreen({Key? key, this.existingCenter}) : super(key: key);

  @override
  State<AddSortingCenterScreen> createState() => _AddSortingCenterScreenState();
}

class _AddSortingCenterScreenState extends State<AddSortingCenterScreen> {
  final MapController _mapController = MapController();
  late LatLng _selectedLocation;
  late TextEditingController _nameController;
  late TextEditingController _hoursController;
  final TextEditingController _searchController = TextEditingController();
  late String _selectedStatus;
  bool _isFetchingLocation = false;
  bool _isSearching = false;
  List<dynamic> _searchResults = [];
  Timer? _debounce;

  List<String> _availableTypes = [];
  final Map<String, List<String>> _categorizedTypes = {
    "disponible": [],
    "sature": [],
    "maintenance": []
  };
  bool _isLoadingTypes = true;

  @override
  void initState() {
    super.initState();
    final existing = widget.existingCenter;
    
    _selectedLocation = existing != null && existing['lat'] != null && existing['lng'] != null
        ? LatLng(double.tryParse(existing['lat'].toString()) ?? 36.8065, double.tryParse(existing['lng'].toString()) ?? 10.1815) 
        : const LatLng(36.8065, 10.1815);
        
    _nameController = TextEditingController(text: existing?['name'] ?? '');
    _hoursController = TextEditingController(text: existing?['hours'] ?? '');
    
    String rawStatus = existing?['status']?.toString().toLowerCase() ?? 'disponible';
    if (rawStatus == 'disponible') {
      _selectedStatus = 'Disponible';
    } else if (rawStatus == 'saturé') {
      _selectedStatus = 'Saturé';
    } else if (rawStatus == 'maintenance') {
      _selectedStatus = 'Maintenance';
    } else {
      _selectedStatus = 'Disponible';
    }
    
    if (existing != null && existing['types_detail'] != null && existing['types_detail'] is Map) {
      final detail = existing['types_detail'] as Map<String, dynamic>;
      _categorizedTypes["disponible"] = (detail["disponible"] as List?)?.map((e) => e.toString()).toList() ?? [];
      _categorizedTypes["sature"] = (detail["sature"] as List?)?.map((e) => e.toString()).toList() ?? [];
      _categorizedTypes["maintenance"] = (detail["maintenance"] as List?)?.map((e) => e.toString()).toList() ?? [];
    } else if (existing != null && existing['types'] is List) {
      _categorizedTypes["disponible"] = (existing['types'] as List).map((e) => e.toString()).toList();
    }

    if (existing == null) {
      _fetchExactLocation();
    } else {
      Future.delayed(const Duration(milliseconds: 200), () {
        if (mounted) _mapController.move(_selectedLocation, 16);
      });
    }
    
    _fetchWasteTypes();
  }

  Future<void> _fetchWasteTypes() async {
    try {
      final response = await http.get(Uri.parse('${AuthService.baseUrl}/collection-points/waste-types'));
      if (response.statusCode == 200) {
        final List<dynamic> data = json.decode(utf8.decode(response.bodyBytes));
        if (mounted) {
          setState(() {
            _availableTypes = data.map((e) => e.toString()).toList();
            _isLoadingTypes = false;
          });
        }
      } else {
        if (mounted) setState(() => _isLoadingTypes = false);
      }
    } catch (e) {
      if (mounted) setState(() => _isLoadingTypes = false);
    }
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _nameController.dispose();
    _hoursController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _fetchExactLocation() async {
    setState(() => _isFetchingLocation = true);

    try {
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        throw 'Le service de localisation est désactivé.';
      }

      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) {
          throw 'Permissions de localisation refusées.';
        }
      }

      final position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
      );

      if (mounted) {
        setState(() {
          _selectedLocation = LatLng(position.latitude, position.longitude);
          _isFetchingLocation = false;
        });
        _mapController.move(_selectedLocation, 16);
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isFetchingLocation = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(e.toString()), backgroundColor: AppTheme.errorRed),
        );
      }
    }
  }

  void _onSearchChanged(String query) {
    if (_debounce?.isActive ?? false) _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 500), () {
      if (query.isNotEmpty) {
        _searchLocation(query);
      } else {
        setState(() {
          _searchResults = [];
        });
      }
    });
  }

  Future<void> _searchLocation(String query) async {
    setState(() => _isSearching = true);
    try {
      final response = await http.get(
        Uri.parse('https://nominatim.openstreetmap.org/search?format=json&q=$query&limit=5&countrycodes=tn'),
        headers: {'User-Agent': 'EcoRewindApp/1.0'},
      );

      if (response.statusCode == 200) {
        setState(() {
          _searchResults = json.decode(response.body);
          _isSearching = false;
        });
      } else {
        setState(() => _isSearching = false);
      }
    } catch (e) {
      setState(() => _isSearching = false);
    }
  }

  void _selectSearchResult(dynamic result) {
    final lat = double.parse(result['lat']);
    final lon = double.parse(result['lon']);
    final newLocation = LatLng(lat, lon);

    setState(() {
      _selectedLocation = newLocation;
      _searchResults = [];
      _searchController.clear();
      FocusScope.of(context).unfocus();
    });

    _mapController.move(newLocation, 16);
  }

  void _onMapTap(TapPosition tapPosition, LatLng point) {
    setState(() {
      _selectedLocation = point;
    });
  }

  void _saveNewCenter() {
    if (_nameController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Veuillez entrer un nom')),
      );
      return;
    }

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Nouveau centre "${_nameController.text}" ajouté avec succès !'),
        backgroundColor: Colors.green,
      ),
    );
    Navigator.pop(context, {
      'name': _nameController.text,
      'types': jsonEncode(_categorizedTypes),
      'hours': _hoursController.text,
      'status': _selectedStatus.toLowerCase(),
      'location': _selectedLocation,
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: webLeading(IconButton(
          icon: Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.surface,
              borderRadius: BorderRadius.circular(12),
              boxShadow: const [BoxShadow(color: Colors.black12, blurRadius: 10)],
            ),
            child: Icon(Icons.arrow_back_ios_new_rounded, color: Theme.of(context).brightness == Brightness.dark ? Colors.white : AppTheme.deepNavy, size: 20),
          ),
          onPressed: () => Navigator.pop(context),
        )),
        title: Text(
          widget.existingCenter == null ? 'Ajouter un Point' : 'Modifier le Point',
          style: GoogleFonts.outfit(
            color: AppTheme.deepNavy,
            fontWeight: FontWeight.bold,
          ),
        ),
        actions: [
          if (_isFetchingLocation)
            const Padding(
              padding: EdgeInsets.only(right: 16.0),
              child: SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(strokeWidth: 2, color: AppTheme.primaryGreen),
              ),
            )
          else
            IconButton(
              icon: const Icon(Icons.my_location_rounded, color: AppTheme.primaryGreen),
              onPressed: _fetchExactLocation,
            ),
        ],
      ),
      body: Stack(
        children: [
          FlutterMap(
            mapController: _mapController,
            options: MapOptions(
              initialCenter: _selectedLocation,
              initialZoom: 13,
              minZoom: 5,
              cameraConstraint: CameraConstraint.containCenter(
                bounds: LatLngBounds(const LatLng(28.5, 5.5), const LatLng(38.5, 13.0)),
              ),
              onTap: _onMapTap,
            ),
            children: [
              TileLayer(
                urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                tileProvider: CancellableNetworkTileProvider(),
              ),
              MarkerLayer(
                markers: [
                  Marker(
                    point: _selectedLocation,
                    width: 60,
                    height: 60,
                    child: const Icon(
                      Icons.location_on_rounded,
                      color: Colors.red,
                      size: 45,
                    ).animate(onPlay: (c) => c.repeat(reverse: true)).scale(
                          begin: const Offset(1, 1),
                          end: const Offset(1.2, 1.2),
                          duration: 1.seconds,
                        ),
                  ),
                ],
              ),
            ],
          ),
          // Search Bar Overlay
          SafeArea(
            child: Container(
              padding: const EdgeInsets.fromLTRB(16, 70, 16, 0),
              child: Column(
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(20),
                    child: BackdropFilter(
                      filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
                      child: Container(
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.85),
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(color: Colors.white.withOpacity(0.5)),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.08),
                              blurRadius: 24,
                              offset: const Offset(0, 8),
                            ),
                          ],
                        ),
                        child: TextField(
                          controller: _searchController,
                          onChanged: _onSearchChanged,
                          decoration: InputDecoration(
                            hintText: 'Rechercher une adresse...',
                            prefixIcon: const Icon(Icons.search_rounded, color: AppTheme.primaryGreen),
                            suffixIcon: _isSearching
                                ? const Padding(
                                    padding: EdgeInsets.all(12.0),
                                    child: CircularProgressIndicator(strokeWidth: 2, color: AppTheme.primaryGreen),
                                  )
                                : null,
                            border: InputBorder.none,
                            filled: false,
                            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                          ),
                        ),
                      ),
                    ),
                  ),
                  if (_searchResults.isNotEmpty)
                    ClipRRect(
                      borderRadius: BorderRadius.circular(20),
                      child: BackdropFilter(
                        filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
                        child: Container(
                          margin: const EdgeInsets.only(top: 8),
                          constraints: const BoxConstraints(maxHeight: 250),
                          decoration: BoxDecoration(
                            color: Colors.white.withOpacity(0.9),
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(color: Colors.white.withOpacity(0.5)),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withOpacity(0.08),
                                blurRadius: 24,
                                offset: const Offset(0, 8),
                              ),
                            ],
                          ),
                          child: ListView.separated(
                            shrinkWrap: true,
                            itemCount: _searchResults.length,
                            separatorBuilder: (context, index) => const Divider(height: 1),
                            itemBuilder: (context, index) {
                              final result = _searchResults[index];
                              return ListTile(
                                leading: const Icon(Icons.location_on_outlined, color: AppTheme.textMuted),
                                title: Text(
                                  result['display_name'],
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                  style: GoogleFonts.inter(fontSize: 13),
                                ),
                                onTap: () => _selectSearchResult(result),
                              );
                            },
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),
          Positioned(
            bottom: 0,
            left: 0,
            right: 0,
            child: ClipRRect(
              borderRadius: const BorderRadius.only(topLeft: Radius.circular(36), topRight: Radius.circular(36)),
              child: BackdropFilter(
                filter: ImageFilter.blur(sigmaX: 15, sigmaY: 15),
                child: Container(
                  padding: const EdgeInsets.all(28),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.85),
                    borderRadius: const BorderRadius.only(
                      topLeft: Radius.circular(36),
                      topRight: Radius.circular(36),
                    ),
                    border: Border(top: BorderSide(color: Colors.white.withOpacity(0.6), width: 1.5)),
                    boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 30, offset: const Offset(0, -10))],
                  ),
                  child: SafeArea(
                    top: false,
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Text(
                          'DÉTAILS DU CENTRE',
                          style: GoogleFonts.outfit(
                            fontWeight: FontWeight.w900,
                            letterSpacing: 1.5,
                            fontSize: 11,
                            color: AppTheme.textMuted,
                          ),
                        ),
                        const SizedBox(height: 16),
                        TextField(
                          controller: _nameController,
                          decoration: InputDecoration(
                            hintText: 'Nom du centre (ex: Tunis Nord)',
                            prefixIcon: const Icon(Icons.edit_note_rounded, color: AppTheme.primaryGreen),
                            filled: true,
                            fillColor: Colors.grey.shade50,
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(16),
                              borderSide: BorderSide.none,
                            ),
                          ),
                        ),
                        const SizedBox(height: 12),
                        TextField(
                          controller: _hoursController,
                          decoration: InputDecoration(
                            hintText: 'Horaires (ex: 8h-18h)',
                            prefixIcon: const Icon(Icons.access_time_rounded, color: AppTheme.primaryGreen),
                            filled: true,
                            fillColor: Colors.grey.shade50,
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(16),
                              borderSide: BorderSide.none,
                            ),
                          ),
                        ),
                        const SizedBox(height: 16),
                        Wrap(
                          alignment: WrapAlignment.spaceBetween,
                          crossAxisAlignment: WrapCrossAlignment.center,
                          children: [
                            Text('CLASSIFICATION DES DÉCHETS', style: GoogleFonts.outfit(fontWeight: FontWeight.w900, letterSpacing: 1.5, fontSize: 11, color: AppTheme.textMuted)),
                            Text('(Cliquez pour changer l\'état)', style: GoogleFonts.inter(fontSize: 10, color: AppTheme.textMuted, fontStyle: FontStyle.italic)),
                          ],
                        ),
                        const SizedBox(height: 12),
                        if (_isLoadingTypes)
                          const Center(child: CircularProgressIndicator(strokeWidth: 2, color: AppTheme.primaryGreen))
                        else
                          Wrap(
                            spacing: 8,
                            runSpacing: 8,
                            children: _availableTypes.map((type) {
                              String state = "none";
                              if (_categorizedTypes["disponible"]!.contains(type)) { state = "disponible"; }
                              else if (_categorizedTypes["sature"]!.contains(type)) { state = "sature"; }
                              else if (_categorizedTypes["maintenance"]!.contains(type)) { state = "maintenance"; }

                              Color color = Colors.grey.shade400;
                              Color bgColor = Colors.transparent;
                              IconData? icon;
                              
                              if (state == "disponible") {
                                color = Colors.green;
                                bgColor = Colors.green.withOpacity(0.15);
                                icon = Icons.check_circle;
                              } else if (state == "sature") {
                                color = Colors.red;
                                bgColor = Colors.red.withOpacity(0.15);
                                icon = Icons.warning_rounded;
                              } else if (state == "maintenance") {
                                color = Colors.orange;
                                bgColor = Colors.orange.withOpacity(0.15);
                                icon = Icons.build_circle;
                              }

                              return InkWell(
                                onTap: () {
                                  setState(() {
                                    _categorizedTypes["disponible"]!.remove(type);
                                    _categorizedTypes["sature"]!.remove(type);
                                    _categorizedTypes["maintenance"]!.remove(type);
                                    
                                    if (state == "none") {
                                      _categorizedTypes["disponible"]!.add(type);
                                    } else if (state == "disponible") {
                                      _categorizedTypes["sature"]!.add(type);
                                    } else if (state == "sature") {
                                      _categorizedTypes["maintenance"]!.add(type);
                                    }
                                    // state == "maintenance" stays removed
                                  });
                                },
                                borderRadius: BorderRadius.circular(20),
                                child: Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                                  decoration: BoxDecoration(
                                    color: bgColor,
                                    border: Border.all(color: state == "none" ? Colors.grey.shade300 : color, width: 1.5),
                                    borderRadius: BorderRadius.circular(20),
                                  ),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      if (icon != null) ...[Icon(icon, size: 14, color: color), const SizedBox(width: 4)],
                                      Text(type, style: GoogleFonts.inter(fontSize: 12, color: state == "none" ? Colors.grey.shade600 : color, fontWeight: state != "none" ? FontWeight.bold : FontWeight.w500)),
                                    ],
                                  ),
                                ),
                              );
                            }).toList(),
                          ),
                        const SizedBox(height: 16),
                        Row(
                          children: [
                            Expanded(child: _buildStatusChip('Disponible', Colors.green)),
                            const SizedBox(width: 8),
                            Expanded(child: _buildStatusChip('Saturé', Colors.red)),
                            const SizedBox(width: 8),
                            Expanded(child: _buildStatusChip('Maintenance', Colors.orange)),
                          ],
                        ),
                        const SizedBox(height: 24),
                        PremiumButton(
                          text: widget.existingCenter == null ? 'CONFIRMER L\'AJOUT' : 'ENREGISTRER',
                          onPressed: _saveNewCenter,
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ).animate().slideY(begin: 1, end: 0, duration: 500.ms, curve: Curves.easeOutCubic),
        ],
      ),
    );
  }

  Widget _buildStatusChip(String status, Color color) {
    final isSelected = _selectedStatus == status;
    return InkWell(
      onTap: () => setState(() => _selectedStatus = status),
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12),
        decoration: BoxDecoration(
          color: isSelected ? color : color.withOpacity(0.05),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: isSelected ? Colors.transparent : color.withOpacity(0.2)),
        ),
        child: Text(
          status,
          textAlign: TextAlign.center,
          style: GoogleFonts.inter(
            fontSize: 12,
            fontWeight: FontWeight.bold,
            color: isSelected ? Colors.white : color,
          ),
        ),
      ),
    );
  }
}
