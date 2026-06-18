import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../theme/app_theme.dart';
import '../../widgets/glass_card.dart';
import '../../widgets/web_back_button.dart';
import '../../features/scan/scan_service.dart';

/// Types de déchets et leurs métadonnées d'affichage
const Map<String, Map<String, dynamic>> _wasteInfo = {
  'plastique':    {'label': 'Plastique',     'icon': Icons.local_drink_rounded,   'color': Color(0xFF3B82F6)},
  'verre':        {'label': 'Verre',         'icon': Icons.wine_bar_rounded,       'color': Color(0xFF10B981)},
  'papier':       {'label': 'Papier',        'icon': Icons.article_rounded,        'color': Color(0xFF8B5CF6)},
  'carton':       {'label': 'Carton',        'icon': Icons.inventory_2_rounded,    'color': Color(0xFF92400E)},
  'metal':        {'label': 'Métal',         'icon': Icons.hardware_rounded,       'color': Color(0xFFF59E0B)},
  'organique':    {'label': 'Organique',     'icon': Icons.eco_rounded,            'color': Color(0xFF22C55E)},
  'electronique': {'label': 'Électronique',  'icon': Icons.devices_rounded,        'color': Color(0xFFEF4444)},
  'textile':      {'label': 'Textile',       'icon': Icons.checkroom_rounded,      'color': Color(0xFFF97316)},
  'general':      {'label': 'Général',       'icon': Icons.delete_rounded,         'color': Color(0xFF6B7280)},
};

Map<String, dynamic> _getWasteInfo(String? type) =>
    _wasteInfo[type?.toLowerCase()] ?? _wasteInfo['general']!;

class TrackRecordsScreen extends StatefulWidget {
  const TrackRecordsScreen({Key? key}) : super(key: key);

  @override
  State<TrackRecordsScreen> createState() => _TrackRecordsScreenState();
}

class _TrackRecordsScreenState extends State<TrackRecordsScreen> {
  final ScanService _service = ScanService();

  bool _loading = true;
  String? _error;

  // Données récupérées depuis le backend
  List<Map<String, dynamic>> _scans = [];
  double _totalPoints = 0;
  int    _totalScans  = 0;

  // Agrégats par type de déchet
  Map<String, _WasteAggregate> _aggregates = {};

  @override
  void initState() {
    super.initState();
    _loadHistory();
  }

  Future<void> _loadHistory() async {
    setState(() { _loading = true; _error = null; });
    try {
      final data = await _service.getScanHistory(limit: 200);
      final scans = (data['scans'] as List? ?? []).cast<Map<String, dynamic>>();

      // Calcul des totaux et agrégats par type
      double pts = 0;
      final agg = <String, _WasteAggregate>{};

      for (final s in scans) {
        final type    = (s['waste_type'] as String? ?? 'general').toLowerCase();
        final points  = (s['points_earned'] as num?)?.toDouble() ?? 0.0;
        final weightKg = (s['weight_kg'] as num?)?.toDouble() ?? 0.0;
        pts += points;
        agg.putIfAbsent(type, () => _WasteAggregate(type: type));
        agg[type]!.addScan(points: points, weightKg: weightKg);
      }

      if (mounted) {
        setState(() {
          _scans       = scans;
          _totalScans  = data['total_scans'] as int? ?? scans.length;
          _totalPoints = pts;
          _aggregates  = agg;
          _loading     = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error   = 'Impossible de charger l\'historique : $e';
          _loading = false;
        });
      }
    }
  }

  // ── Build ──────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: webLeading(IconButton(
          onPressed: () => Navigator.pop(context),
          icon: const Icon(Icons.arrow_back_ios_new_rounded, color: AppTheme.deepSlate),
        )),
        title: Text(
          'Historique de Tri',
          style: GoogleFonts.outfit(
            fontSize: 24,
            fontWeight: FontWeight.bold,
            color: AppTheme.deepSlate,
          ),
        ),
        actions: [
          // Bouton refresh
          IconButton(
            icon: const Icon(Icons.refresh_rounded, color: AppTheme.deepSlate),
            onPressed: _loadHistory,
            tooltip: 'Actualiser',
          ),
        ],
      ),
      body: _loading
          ? _buildLoader()
          : _error != null
              ? _buildError()
              : _scans.isEmpty
                  ? _buildEmpty()
                  : _buildContent(),
    );
  }

  // ── États UI ───────────────────────────────────────────────────────────────

  Widget _buildLoader() {
    return const Center(
      child: CircularProgressIndicator(color: AppTheme.primaryGreen),
    );
  }

  Widget _buildError() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.wifi_off_rounded, size: 56, color: AppTheme.textMuted),
            const SizedBox(height: 16),
            Text(
              _error!,
              textAlign: TextAlign.center,
              style: GoogleFonts.inter(color: AppTheme.textMuted, fontSize: 14),
            ),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              onPressed: _loadHistory,
              icon: const Icon(Icons.refresh_rounded),
              label: Text('Réessayer', style: GoogleFonts.outfit(fontWeight: FontWeight.w700)),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.primaryGreen,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 14),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmpty() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(40),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: AppTheme.primaryGreen.withOpacity(0.08),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.recycling_rounded, size: 56, color: AppTheme.primaryGreen),
            ),
            const SizedBox(height: 24),
            Text(
              'Aucun recyclage encore',
              style: GoogleFonts.outfit(
                fontSize: 20, fontWeight: FontWeight.bold, color: AppTheme.deepSlate,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Scannez une poubelle intelligente\npour commencer à gagner des points !',
              textAlign: TextAlign.center,
              style: GoogleFonts.inter(fontSize: 14, color: AppTheme.textMuted, height: 1.5),
            ),
          ],
        ),
      ).animate().fadeIn(delay: 200.ms).scale(begin: const Offset(0.9, 0.9)),
    );
  }

  Widget _buildContent() {
    final sortedAgg = _aggregates.values.toList()
      ..sort((a, b) => b.totalPoints.compareTo(a.totalPoints));

    return RefreshIndicator(
      color: AppTheme.primaryGreen,
      onRefresh: _loadHistory,
      child: ListView(
        physics: const BouncingScrollPhysics(),
        children: [
          // ── Bannière récapitulative ──────────────────────────────────────
          Container(
            width: double.infinity,
            margin: const EdgeInsets.all(24),
            padding: const EdgeInsets.all(28),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFF059669), Color(0xFF10B981)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(28),
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFF059669).withOpacity(0.3),
                  blurRadius: 20,
                  offset: const Offset(0, 10),
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Vos Statistiques',
                  style: GoogleFonts.outfit(
                    fontSize: 24, fontWeight: FontWeight.bold, color: Colors.white,
                  ),
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    _statBadge(
                      icon: Icons.qr_code_scanner_rounded,
                      label: 'Scans',
                      value: '$_totalScans',
                    ),
                    const SizedBox(width: 12),
                    _statBadge(
                      icon: Icons.stars_rounded,
                      label: 'Points gagnés',
                      value: '+${_totalPoints.toStringAsFixed(0)}',
                    ),
                    const SizedBox(width: 12),
                    _statBadge(
                      icon: Icons.category_rounded,
                      label: 'Catégories',
                      value: '${_aggregates.length}',
                    ),
                  ],
                ),
              ],
            ),
          ).animate().fadeIn().slideY(begin: -0.2, curve: Curves.easeOutCubic),

          // ── Titre section agrégats ──────────────────────────────────────
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: Text(
              'Par catégorie',
              style: GoogleFonts.inter(
                fontSize: 14,
                fontWeight: FontWeight.w700,
                color: AppTheme.textMuted,
                letterSpacing: 0.5,
              ),
            ),
          ),
          const SizedBox(height: 12),

          // ── Agrégats par type de déchet ─────────────────────────────────
          ...sortedAgg.asMap().entries.map((entry) {
            final idx  = entry.key;
            final agg  = entry.value;
            final info = _getWasteInfo(agg.type);
            return _buildCategoryCard(agg, info, idx);
          }),

          const SizedBox(height: 12),

          // ── Titre section historique détaillé ───────────────────────────
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: Text(
              'Historique détaillé (${_scans.length})',
              style: GoogleFonts.inter(
                fontSize: 14,
                fontWeight: FontWeight.w700,
                color: AppTheme.textMuted,
                letterSpacing: 0.5,
              ),
            ),
          ),
          const SizedBox(height: 12),

          // ── Entrées individuelles ───────────────────────────────────────
          ..._scans.asMap().entries.map((entry) {
            final idx  = entry.key;
            final scan = entry.value;
            return _buildScanRow(scan, idx);
          }),

          const SizedBox(height: 32),
        ],
      ),
    );
  }

  // ── Widgets de construction ────────────────────────────────────────────────

  Widget _statBadge({
    required IconData icon,
    required String label,
    required String value,
  }) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.2),
          borderRadius: BorderRadius.circular(14),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, color: Colors.white70, size: 18),
            const SizedBox(height: 4),
            Text(
              value,
              style: GoogleFonts.outfit(
                color: Colors.white, fontSize: 18, fontWeight: FontWeight.w900,
              ),
            ),
            Text(
              label,
              style: GoogleFonts.inter(color: Colors.white70, fontSize: 10),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCategoryCard(_WasteAggregate agg, Map<String, dynamic> info, int idx) {
    final color = info['color'] as Color;
    return Container(
      margin: const EdgeInsets.fromLTRB(24, 0, 24, 12),
      child: GlassCard(
        padding: const EdgeInsets.all(20),
        child: Row(
          children: [
            // Icône
            Container(
              width: 52,
              height: 52,
              decoration: BoxDecoration(
                color: color.withOpacity(0.12),
                borderRadius: BorderRadius.circular(14),
              ),
              child: Icon(info['icon'] as IconData, color: color, size: 26),
            ),
            const SizedBox(width: 16),

            // Nom + stats
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    info['label'] as String,
                    style: GoogleFonts.outfit(
                      fontSize: 15, fontWeight: FontWeight.bold, color: AppTheme.deepSlate,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    '${agg.totalScans} scan${agg.totalScans > 1 ? 's' : ''}'
                    '${agg.totalWeightKg > 0 ? '  ·  ${agg.totalWeightKg.toStringAsFixed(1)} kg' : ''}',
                    style: GoogleFonts.inter(fontSize: 12, color: AppTheme.textMuted),
                  ),
                ],
              ),
            ),

            // Points
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
              decoration: BoxDecoration(
                color: color.withOpacity(0.1),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Text(
                '+${agg.totalPoints.toStringAsFixed(0)} pts',
                style: GoogleFonts.outfit(
                  fontSize: 13, fontWeight: FontWeight.bold, color: color,
                ),
              ),
            ),
          ],
        ),
      ),
    ).animate(delay: (idx * 80).ms).fadeIn().slideX(begin: 0.15, curve: Curves.easeOutCubic);
  }

  Widget _buildScanRow(Map<String, dynamic> scan, int idx) {
    final type   = (scan['waste_type'] as String? ?? 'general').toLowerCase();
    final info   = _getWasteInfo(type);
    final color  = info['color'] as Color;
    final points = (scan['points_earned'] as num?)?.toDouble() ?? 0.0;
    final weight = (scan['weight_kg'] as num?)?.toDouble();
    final binCode = scan['bin_code'] as String? ?? '';
    final rawDate = scan['scanned_at'] as String?;
    final dateStr = rawDate != null ? _formatDate(rawDate) : '—';

    return Container(
      margin: const EdgeInsets.fromLTRB(24, 0, 24, 8),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.black.withOpacity(0.05)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          // Icône type déchet
          Container(
            width: 40, height: 40,
            decoration: BoxDecoration(
              color: color.withOpacity(0.10),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(info['icon'] as IconData, color: color, size: 20),
          ),
          const SizedBox(width: 12),

          // Détails
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  info['label'] as String,
                  style: GoogleFonts.outfit(
                    fontSize: 14, fontWeight: FontWeight.w700, color: AppTheme.deepSlate,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  [
                    if (binCode.isNotEmpty) binCode,
                    if (weight != null) '${weight.toStringAsFixed(1)} kg',
                    dateStr,
                  ].join('  ·  '),
                  style: GoogleFonts.inter(fontSize: 11, color: AppTheme.textMuted),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),

          // Points
          Text(
            '+${points.toStringAsFixed(0)}',
            style: GoogleFonts.outfit(
              fontSize: 15, fontWeight: FontWeight.w900, color: color,
            ),
          ),
        ],
      ),
    ).animate(delay: (idx * 30).ms).fadeIn().slideX(begin: 0.08);
  }

  String _formatDate(String iso) {
    try {
      final dt   = DateTime.parse(iso).toLocal();
      final now  = DateTime.now();
      final diff = now.difference(dt);
      if (diff.inMinutes < 60) return 'il y a ${diff.inMinutes} min';
      if (diff.inHours  < 24) return 'il y a ${diff.inHours}h';
      if (diff.inDays   == 1) return 'hier';
      if (diff.inDays   <  7) return 'il y a ${diff.inDays}j';
      return '${dt.day.toString().padLeft(2,'0')}/${dt.month.toString().padLeft(2,'0')}/${dt.year}';
    } catch (_) {
      return iso;
    }
  }
}

// ── Agrégat par type de déchet ─────────────────────────────────────────────

class _WasteAggregate {
  final String type;
  int    totalScans    = 0;
  double totalPoints   = 0.0;
  double totalWeightKg = 0.0;

  _WasteAggregate({required this.type});

  void addScan({required double points, required double weightKg}) {
    totalScans++;
    totalPoints   += points;
    totalWeightKg += weightKg;
  }
}
