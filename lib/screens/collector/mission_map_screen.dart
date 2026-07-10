import 'dart:convert';
import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_map_cancellable_tile_provider/flutter_map_cancellable_tile_provider.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:latlong2/latlong.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import '../../constants.dart';

/// Écran carte mission pour le collecteur.
/// Accessible via notification push de type "assignment".
/// Affiche les centres de tri assignés sur une carte OSM et permet
/// de naviguer vers chaque centre et de marquer la mission terminée.
class MissionMapScreen extends StatefulWidget {
  final int assignmentId;

  const MissionMapScreen({super.key, required this.assignmentId});

  @override
  State<MissionMapScreen> createState() => _MissionMapScreenState();
}

class _MissionMapScreenState extends State<MissionMapScreen> {
  final MapController _mapController = MapController();

  Map<String, dynamic>? _assignment;
  List<Map<String, dynamic>> _points = [];
  bool _loading = true;
  String? _error;
  bool _mapOnline = false;

  // Status local pour chaque centre (non persisté, juste visuel)
  final Set<int> _visitedPointIds = {};

  static const _primaryColor = Color(0xFF2E7D32);
  static const _urgentColor = Color(0xFFE53935);

  @override
  void initState() {
    super.initState();
    _loadAssignment();
    _checkMapConnectivity();
  }

  Future<void> _checkMapConnectivity() async {
    try {
      final socket = await Socket.connect('tile.openstreetmap.org', 80, timeout: const Duration(seconds: 3));
      socket.destroy();
      if (mounted) {
        setState(() => _mapOnline = true);
        // Si les données sont déjà chargées, centrer la carte maintenant
        if (_points.isNotEmpty) {
          WidgetsBinding.instance.addPostFrameCallback((_) => _fitMap());
        }
      }
    } catch (_) {}
  }

  Future<void> _loadAssignment() async {
    setState(() { _loading = true; _error = null; });
    try {
      final prefs = await SharedPreferences.getInstance();
      final jwt = prefs.getString('jwt_token');
      final resp = await http.get(
        Uri.parse('${ApiConstants.baseUrl}/intercommunality/assignments/${widget.assignmentId}'),
        headers: {'Authorization': 'Bearer $jwt'},
      );
      if (resp.statusCode == 200) {
        final data = json.decode(utf8.decode(resp.bodyBytes)) as Map<String, dynamic>;
        setState(() {
          _assignment = data;
          _points = List<Map<String, dynamic>>.from(
            data['collection_points_data'] ?? [],
          );
          _loading = false;
        });
        // Centrer la carte sur les points (seulement si la carte est déjà en ligne)
        if (_points.isNotEmpty && _mapOnline) {
          WidgetsBinding.instance.addPostFrameCallback((_) => _fitMap());
        }
      } else {
        setState(() { _error = 'Erreur ${resp.statusCode}'; _loading = false; });
      }
    } catch (e) {
      setState(() { _error = e.toString(); _loading = false; });
    }
  }

  void _fitMap() {
    // Guard : ne pas appeler le controller si la carte n'est pas rendue
    if (!_mapOnline || _points.isEmpty) return;
    final latlngs = _points
        .where((p) => p['lat'] != null && p['lng'] != null)
        .map((p) => LatLng(
              double.tryParse(p['lat'].toString()) ?? 0,
              double.tryParse(p['lng'].toString()) ?? 0,
            ))
        .toList();
    if (latlngs.isEmpty) return;
    if (latlngs.length == 1) {
      _mapController.move(latlngs.first, 15);
      return;
    }
    final bounds = LatLngBounds.fromPoints(latlngs);
    _mapController.fitCamera(
      CameraFit.bounds(bounds: bounds, padding: const EdgeInsets.all(60)),
    );
  }

  Future<void> _markDone() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text('Terminer la mission ?', style: GoogleFonts.outfit(fontWeight: FontWeight.w800)),
        content: Text('Cette action est irréversible.', style: GoogleFonts.outfit()),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Annuler')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: _primaryColor),
            onPressed: () => Navigator.pop(context, true),
            child: Text('Confirmer', style: GoogleFonts.outfit(color: Colors.white)),
          ),
        ],
      ),
    );
    if (confirm != true) return;
    try {
      final prefs = await SharedPreferences.getInstance();
      final jwt = prefs.getString('jwt_token');
      final resp = await http.patch(
        Uri.parse('${ApiConstants.baseUrl}/intercommunality/assignments/${widget.assignmentId}/status'),
        headers: {'Authorization': 'Bearer $jwt', 'Content-Type': 'application/json'},
        body: json.encode({'status': 'done'}),
      );
      if (resp.statusCode == 200) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('✅ Mission terminée !', style: GoogleFonts.outfit()), backgroundColor: _primaryColor),
          );
          Navigator.pop(context);
        }
      }
    } catch (_) {}
  }

  Future<void> _navigateTo(Map<String, dynamic> point) async {
    final lat = point['lat'];
    final lng = point['lng'];
    if (lat == null || lng == null) return;
    final uri = Uri.parse('https://www.google.com/maps/dir/?api=1&destination=$lat,$lng&travelmode=driving');
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isUrgent = _assignment?['priority'] == 'urgent';
    final status   = _assignment?['status'] ?? 'pending';
    final label    = _assignment?['target_label'] ?? _assignment?['zone_name'] ?? 'Mission';

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      body: _loading
          ? const Center(child: CircularProgressIndicator(color: _primaryColor))
          : _error != null
              ? _buildError()
              : Stack(children: [
                  // ── Carte OSM (uniquement si réseau disponible) ───────────
                  if (_mapOnline)
                    FlutterMap(
                      mapController: _mapController,
                      options: const MapOptions(
                        initialCenter: LatLng(36.8, 10.18),
                        initialZoom: 12,
                      ),
                      children: [
                        TileLayer(
                          urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                          tileProvider: CancellableNetworkTileProvider(),
                          userAgentPackageName: 'com.example.eco_rewind',
                          errorTileCallback: (tile, error, stackTrace) {},
                        ),
                        // Marqueurs des centres de tri
                        MarkerLayer(
                          markers: _points
                              .where((p) => p['lat'] != null && p['lng'] != null)
                              .map((p) {
                            final lat = double.tryParse(p['lat'].toString()) ?? 0;
                            final lng = double.tryParse(p['lng'].toString()) ?? 0;
                            final visited = _visitedPointIds.contains(p['id']);
                            return Marker(
                              point: LatLng(lat, lng),
                              width: 48,
                              height: 56,
                              child: GestureDetector(
                                onTap: () => _showPointSheet(p),
                                child: Column(
                                  children: [
                                    Container(
                                      width: 36,
                                      height: 36,
                                      decoration: BoxDecoration(
                                        color: visited ? Colors.green : (isUrgent ? _urgentColor : _primaryColor),
                                        shape: BoxShape.circle,
                                        border: Border.all(color: Colors.white, width: 2.5),
                                        boxShadow: const [BoxShadow(color: Colors.black26, blurRadius: 6, offset: Offset(0, 3))],
                                      ),
                                      child: Icon(
                                        visited ? Icons.check : Icons.delete_outline_rounded,
                                        color: Colors.white, size: 18,
                                      ),
                                    ),
                                    CustomPaint(
                                      painter: _TrianglePainter(
                                        visited ? Colors.green : (isUrgent ? _urgentColor : _primaryColor),
                                      ),
                                      size: const Size(12, 8),
                                    ),
                                  ],
                                ),
                              ),
                            );
                          }).toList(),
                        ),
                      ],
                    )
                  else
                    // Placeholder hors-ligne
                    Container(
                      decoration: const BoxDecoration(
                        gradient: LinearGradient(
                          colors: [Color(0xFF1B5E20), Color(0xFF2E7D32), Color(0xFF1A3A2A)],
                          begin: Alignment.topLeft, end: Alignment.bottomRight,
                        ),
                      ),
                      child: Center(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(Icons.map_outlined, color: Colors.white54, size: 56),
                            const SizedBox(height: 16),
                            Text('Carte indisponible hors-ligne',
                                style: GoogleFonts.outfit(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w700)),
                            const SizedBox(height: 8),
                            Text('${_points.length} point(s) assigné(s)',
                                style: GoogleFonts.outfit(color: Colors.white54, fontSize: 13)),
                            const SizedBox(height: 20),
                            TextButton.icon(
                              onPressed: _checkMapConnectivity,
                              icon: const Icon(Icons.refresh_rounded, color: Colors.white38, size: 16),
                              label: Text('Réessayer', style: GoogleFonts.outfit(color: Colors.white38)),
                            ),
                          ],
                        ),
                      ),
                    ),

                  // ── AppBar custom ──────────────────────────────────────
                  Positioned(
                    top: 0, left: 0, right: 0,
                    child: Container(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: isUrgent
                              ? [_urgentColor, const Color(0xFFB71C1C)]
                              : [_primaryColor, const Color(0xFF1B5E20)],
                          begin: Alignment.topLeft, end: Alignment.bottomRight,
                        ),
                      ),
                      child: SafeArea(
                        bottom: false,
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                          child: Row(children: [
                            IconButton(
                              icon: const Icon(Icons.arrow_back, color: Colors.white),
                              onPressed: () => Navigator.pop(context),
                            ),
                            const SizedBox(width: 4),
                            Expanded(
                              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                                Text(
                                  isUrgent ? '🚨 MISSION URGENTE' : '📋 Mission',
                                  style: GoogleFonts.outfit(color: Colors.white70, fontSize: 11, fontWeight: FontWeight.w600),
                                ),
                                Text(
                                  label,
                                  style: GoogleFonts.outfit(color: Colors.white, fontSize: 15, fontWeight: FontWeight.w800),
                                  maxLines: 1, overflow: TextOverflow.ellipsis,
                                ),
                              ]),
                            ),
                            if (status == 'pending' || status == 'in_progress')
                              TextButton.icon(
                                onPressed: _markDone,
                                icon: const Icon(Icons.check_circle_outline, color: Colors.white, size: 18),
                                label: Text('Terminé', style: GoogleFonts.outfit(color: Colors.white, fontWeight: FontWeight.w700)),
                              ),
                          ]),
                        ),
                      ),
                    ),
                  ),

                  // ── Panneau bas : liste des centres ───────────────────
                  Positioned(
                    bottom: 0, left: 0, right: 0,
                    child: _buildBottomPanel(label, status),
                  ),
                ]),
    );
  }

  Widget _buildBottomPanel(String label, String status) {
    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        boxShadow: [BoxShadow(color: Colors.black12, blurRadius: 12, offset: Offset(0, -4))],
      ),
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        const SizedBox(height: 8),
        Container(width: 40, height: 4, decoration: BoxDecoration(color: Colors.grey.shade300, borderRadius: BorderRadius.circular(2))),
        const SizedBox(height: 12),

        // Info mission
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Row(children: [
            Expanded(
              child: Text(
                _assignment?['mission_message'] ?? 'Aucune instruction spécifique.',
                style: GoogleFonts.outfit(fontSize: 13, color: Colors.grey.shade700),
                maxLines: 2, overflow: TextOverflow.ellipsis,
              ),
            ),
            _StatusBadge(status),
          ]),
        ),
        const SizedBox(height: 10),
        const Divider(height: 1),

        // Liste des centres
        if (_points.isEmpty)
          Padding(
            padding: const EdgeInsets.all(16),
            child: Text('Aucun centre de tri associé.', style: GoogleFonts.outfit(color: Colors.grey)),
          )
        else
          ConstrainedBox(
            constraints: const BoxConstraints(maxHeight: 220),
            child: ListView.separated(
              padding: const EdgeInsets.symmetric(vertical: 8),
              shrinkWrap: true,
              itemCount: _points.length,
              separatorBuilder: (_, __) => const Divider(height: 1, indent: 60),
              itemBuilder: (_, i) {
                final p = _points[i];
                final visited = _visitedPointIds.contains(p['id'] as int);
                return ListTile(
                  dense: true,
                  leading: CircleAvatar(
                    radius: 18,
                    backgroundColor: visited
                        ? Colors.green.withOpacity(0.15)
                        : _primaryColor.withOpacity(0.1),
                    child: Text(
                      '${i + 1}',
                      style: GoogleFonts.outfit(
                        fontWeight: FontWeight.w800,
                        color: visited ? Colors.green : _primaryColor,
                        fontSize: 13,
                      ),
                    ),
                  ),
                  title: Text(
                    p['name'] ?? '',
                    style: GoogleFonts.outfit(
                      fontWeight: FontWeight.w700, fontSize: 13,
                      color: visited ? Colors.grey : const Color(0xFF1E293B),
                      decoration: visited ? TextDecoration.lineThrough : null,
                    ),
                  ),
                  subtitle: p['address'] != null
                      ? Text(p['address'], style: GoogleFonts.outfit(fontSize: 11, color: Colors.grey.shade500), maxLines: 1, overflow: TextOverflow.ellipsis)
                      : null,
                  trailing: Row(mainAxisSize: MainAxisSize.min, children: [
                    // Marquer visité
                    GestureDetector(
                      onTap: () => setState(() {
                        if (visited) {
                          _visitedPointIds.remove(p['id'] as int);
                        } else {
                          _visitedPointIds.add(p['id'] as int);
                          // Centrer sur ce point
                          final lat = double.tryParse(p['lat']?.toString() ?? '');
                          final lng = double.tryParse(p['lng']?.toString() ?? '');
                          if (lat != null && lng != null) _mapController.move(LatLng(lat, lng), 16);
                        }
                      }),
                      child: Container(
                        padding: const EdgeInsets.all(6),
                        decoration: BoxDecoration(
                          color: visited ? Colors.green.withOpacity(0.1) : Colors.grey.shade100,
                          shape: BoxShape.circle,
                        ),
                        child: Icon(
                          visited ? Icons.check_circle : Icons.radio_button_unchecked,
                          size: 18,
                          color: visited ? Colors.green : Colors.grey,
                        ),
                      ),
                    ),
                    const SizedBox(width: 6),
                    // Naviguer
                    GestureDetector(
                      onTap: () => _navigateTo(p),
                      child: Container(
                        padding: const EdgeInsets.all(6),
                        decoration: BoxDecoration(
                          color: _primaryColor.withOpacity(0.1),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(Icons.navigation_rounded, size: 18, color: _primaryColor),
                      ),
                    ),
                  ]),
                );
              },
            ),
          ),
        SizedBox(height: MediaQuery.of(context).padding.bottom + 8),
      ]),
    ).animate().slideY(begin: 1, end: 0, duration: 300.ms, curve: Curves.easeOut);
  }

  void _showPointSheet(Map<String, dynamic> point) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (_) => Padding(
        padding: const EdgeInsets.all(20),
        child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(point['name'] ?? '', style: GoogleFonts.outfit(fontSize: 18, fontWeight: FontWeight.w800)),
          if (point['address'] != null) ...[
            const SizedBox(height: 4),
            Text(point['address'], style: GoogleFonts.outfit(fontSize: 13, color: Colors.grey.shade600)),
          ],
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                backgroundColor: _primaryColor,
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
              ),
              onPressed: () { Navigator.pop(context); _navigateTo(point); },
              icon: const Icon(Icons.navigation_rounded, color: Colors.white),
              label: Text('Naviguer vers ce centre', style: GoogleFonts.outfit(color: Colors.white, fontWeight: FontWeight.w700)),
            ),
          ),
          SizedBox(height: MediaQuery.of(context).padding.bottom),
        ]),
      ),
    );
  }

  Widget _buildError() {
    return Center(
      child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
        const Icon(Icons.error_outline, size: 64, color: Colors.red),
        const SizedBox(height: 16),
        Text('Impossible de charger la mission', style: GoogleFonts.outfit(fontSize: 16, fontWeight: FontWeight.w700)),
        const SizedBox(height: 8),
        Text(_error ?? '', style: GoogleFonts.outfit(color: Colors.grey)),
        const SizedBox(height: 20),
        ElevatedButton(onPressed: _loadAssignment, child: const Text('Réessayer')),
      ]),
    );
  }
}

class _StatusBadge extends StatelessWidget {
  final String status;
  const _StatusBadge(this.status);

  @override
  Widget build(BuildContext context) {
    final (label, color) = switch (status) {
      'pending'     => ('En attente', Colors.orange),
      'in_progress' => ('En cours',   Colors.blue),
      'done'        => ('Terminée',   Colors.green),
      'cancelled'   => ('Annulée',    Colors.grey),
      _             => (status,       Colors.grey),
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withOpacity(0.4)),
      ),
      child: Text(label, style: GoogleFonts.outfit(fontSize: 11, fontWeight: FontWeight.w700, color: color)),
    );
  }
}

/// Peint un triangle pointant vers le bas sous le marqueur.
class _TrianglePainter extends CustomPainter {
  final Color color;
  const _TrianglePainter(this.color);

  @override
  void paint(Canvas canvas, Size size) {
    final paint = ui.Paint()..color = color;
    final path = ui.Path()
      ..moveTo(0, 0)
      ..lineTo(size.width, 0)
      ..lineTo(size.width / 2, size.height)
      ..close();
    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(_TrianglePainter old) => old.color != color;
}
