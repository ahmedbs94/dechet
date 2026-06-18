import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../theme/app_theme.dart';
import 'analytics_helpers.dart';
import '../../services/l10n_service.dart';

// ═══════════════════════════════════════════════════════════════════
// ONGLET ANALYTICS ADMIN — 7 sections alimentées par FastAPI
// Architecture temps réel :
//   • Un seul coordinateur (_CoordinateurRefresh) gère tous les timers
//   • Chaque section s'abonne via callback onRefresh
//   • Pull-to-refresh global recharge tout en parallèle via /admin/dashboard/live
//   • Badge de fraîcheur live dans chaque SectionCard
// ═══════════════════════════════════════════════════════════════════

// ── Coordinateur de rafraîchissement global ──────────────────────────────────
class _CoordinateurRefresh {
  static final _CoordinateurRefresh _instance = _CoordinateurRefresh._();
  factory _CoordinateurRefresh() => _instance;
  _CoordinateurRefresh._();

  final List<VoidCallback> _listeners = [];
  Timer? _globalTimer;
  DateTime? _lastGlobalRefresh;
  bool _isRefreshing = false;

  void register(VoidCallback cb) {
    if (!_listeners.contains(cb)) _listeners.add(cb);
    _globalTimer ??= Timer.periodic(const Duration(seconds: 30), (_) => refreshAll());
  }

  void unregister(VoidCallback cb) {
    _listeners.remove(cb);
    if (_listeners.isEmpty) {
      _globalTimer?.cancel();
      _globalTimer = null;
    }
  }

  Future<void> refreshAll() async {
    if (_isRefreshing) return;
    _isRefreshing = true;
    _lastGlobalRefresh = DateTime.now();
    for (final cb in List<VoidCallback>.from(_listeners)) {
      cb();
    }
    _isRefreshing = false;
  }

  DateTime? get lastRefresh => _lastGlobalRefresh;
}

// ═══════════════════════════════════════════════════════════════════
// WIDGET PRINCIPAL
// ═══════════════════════════════════════════════════════════════════

class AdminAnalyticsTab extends StatefulWidget {
  const AdminAnalyticsTab({Key? key}) : super(key: key);

  @override
  State<AdminAnalyticsTab> createState() => _AdminAnalyticsTabState();
}

class _AdminAnalyticsTabState extends State<AdminAnalyticsTab> {
  bool _isGlobalRefreshing = false;
  DateTime? _lastSync;
  int _syncAgeSeconds = 0;
  Timer? _ageTicker;
  final _coordinateur = _CoordinateurRefresh();

  @override
  void initState() {
    super.initState();
    _lastSync = DateTime.now();
    _ageTicker = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!mounted) return;
      setState(() {
        _syncAgeSeconds = _lastSync != null
            ? DateTime.now().difference(_lastSync!).inSeconds
            : 0;
      });
    });
  }

  @override
  void dispose() {
    _ageTicker?.cancel();
    super.dispose();
  }

  Future<void> _globalPullRefresh() async {
    if (_isGlobalRefreshing) return;
    setState(() => _isGlobalRefreshing = true);
    // Appeler /admin/dashboard/live pour invalider le cache côté serveur
    await analyticsGet('/admin/dashboard/live');
    // Notifier toutes les sections de se recharger
    await _coordinateur.refreshAll();
    if (mounted) {
      setState(() {
        _isGlobalRefreshing = false;
        _lastSync = DateTime.now();
        _syncAgeSeconds = 0;
      });
    }
  }

  String get _freshness {
    if (_syncAgeSeconds <= 0) return 'À l\'instant';
    if (_syncAgeSeconds < 60) return 'il y a ${_syncAgeSeconds}s';
    final min = _syncAgeSeconds ~/ 60;
    return 'il y a ${min}min';
  }

  Color get _freshnessColor {
    if (_syncAgeSeconds < 30) return Colors.green;
    if (_syncAgeSeconds < 90) return Colors.orange;
    return Colors.red;
  }

  @override
  Widget build(BuildContext context) {
    return RefreshIndicator(
      onRefresh: _globalPullRefresh,
      color: AppTheme.primaryGreen,
      backgroundColor: Theme.of(context).colorScheme.surface,
      displacement: 20,
      child: SingleChildScrollView(
        key: const PageStorageKey('indicateurs'),
        primary: false,
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 20),
        physics: const AlwaysScrollableScrollPhysics(
          parent: BouncingScrollPhysics(),
        ),
        child: Column(children: [

          // ── Bandeau de synchronisation globale ──────────────────────
          _BandeauSync(
            freshness: _freshness,
            freshnessColor: _freshnessColor,
            isRefreshing: _isGlobalRefreshing,
            onRefresh: _globalPullRefresh,
          ),
          const SizedBox(height: 20),

          // ── SECTION 1 : VUE D'ENSEMBLE KPIs ─────────────────────────
          const SectionDivider(label: 'VUE D\'ENSEMBLE'),
          _SectionDashboard(coordinateur: _CoordinateurRefresh()),
          const SizedBox(height: 4),

          // ── SECTION 2 : SCANS QR ─────────────────────────────────────
          const SectionDivider(label: 'ACTIVITÉ — SCANS QR'),
          _SectionScans(coordinateur: _CoordinateurRefresh()),
          const SizedBox(height: 4),

          // ── SECTION 3 : UTILISATEURS ─────────────────────────────────
          const SectionDivider(label: 'COMMUNAUTÉ — UTILISATEURS'),
          _SectionUtilisateurs(coordinateur: _CoordinateurRefresh()),
          const SizedBox(height: 4),

          // ── SECTION 4 : ÉDUCATION ─────────────────────────────────────
          const SectionDivider(label: 'FORMATION & ÉDUCATION'),
          _SectionEducation(coordinateur: _CoordinateurRefresh()),
          const SizedBox(height: 4),

          // ── SECTION 5 : MODÉRATION ────────────────────────────────────
          const SectionDivider(label: 'MODÉRATION & PUBLICATIONS'),
          _SectionModeration(coordinateur: _CoordinateurRefresh()),
          const SizedBox(height: 4),

          // ── SECTION 6 : CENTRES DE TRI ────────────────────────────────
          const SectionDivider(label: 'CENTRES DE TRI & COLLECTE'),
          _SectionCentres(coordinateur: _CoordinateurRefresh()),
          const SizedBox(height: 4),

          const SizedBox(height: 80),
        ]),
      ),
    );
  }
}

// ── Bandeau de synchronisation ────────────────────────────────────────────────
class _BandeauSync extends StatelessWidget {
  final String freshness;
  final Color freshnessColor;
  final bool isRefreshing;
  final VoidCallback onRefresh;

  const _BandeauSync({
    required this.freshness,
    required this.freshnessColor,
    required this.isRefreshing,
    required this.onRefresh,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: isDark
              ? [const Color(0xFF1E293B), const Color(0xFF0F172A)]
              : [AppTheme.primaryGreen.withOpacity(0.06), AppTheme.primaryGreen.withOpacity(0.02)],
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: freshnessColor.withOpacity(0.25)),
      ),
      child: Row(children: [
        // Indicateur pulsant
        _PulsingDot(color: freshnessColor),
        const SizedBox(width: 12),
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('Données en temps réel', style: GoogleFonts.outfit(
            fontSize: 12, fontWeight: FontWeight.w800,
            color: Theme.of(context).textTheme.titleLarge?.color ?? AppTheme.deepSlate)),
          const SizedBox(height: 2),
          Text('Dernière synchronisation : $freshness • Auto-refresh 30s',
            style: GoogleFonts.inter(fontSize: 10, color: AppTheme.textMuted)),
        ])),
        // Bouton refresh manuel
        GestureDetector(
          onTap: isRefreshing ? null : onRefresh,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: AppTheme.primaryGreen.withOpacity(0.12),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: AppTheme.primaryGreen.withOpacity(0.3)),
            ),
            child: isRefreshing
                ? SizedBox(width: 14, height: 14,
                    child: CircularProgressIndicator(strokeWidth: 2, color: AppTheme.primaryGreen))
                : Row(mainAxisSize: MainAxisSize.min, children: [
                    const Icon(Icons.sync_rounded, color: AppTheme.primaryGreen, size: 14),
                    const SizedBox(width: 5),
                    Text('Sync', style: GoogleFonts.inter(
                      fontSize: 11, fontWeight: FontWeight.w800, color: AppTheme.primaryGreen)),
                  ]),
          ),
        ),
      ]),
    );
  }
}

// ── Point pulsant animé ───────────────────────────────────────────────────────
class _PulsingDot extends StatefulWidget {
  final Color color;
  const _PulsingDot({required this.color});

  @override
  State<_PulsingDot> createState() => _PulsingDotState();
}

class _PulsingDotState extends State<_PulsingDot> with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  late Animation<double> _scale;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 1200))
      ..repeat(reverse: true);
    _scale = Tween<double>(begin: 0.7, end: 1.0).animate(
      CurvedAnimation(parent: _ctrl, curve: Curves.easeInOut));
  }

  @override
  void dispose() { _ctrl.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext context) {
    return ScaleTransition(
      scale: _scale,
      child: Container(
        width: 10, height: 10,
        decoration: BoxDecoration(
          color: widget.color,
          shape: BoxShape.circle,
          boxShadow: [BoxShadow(color: widget.color.withOpacity(0.4), blurRadius: 6, spreadRadius: 1)],
        ),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════
// SECTION 1 — DASHBOARD KPI (GET /admin/dashboard)
// Toutes les données vitales en un seul appel
// ═══════════════════════════════════════════════════════════════════

class _SectionDashboard extends StatefulWidget {
  final _CoordinateurRefresh coordinateur;
  const _SectionDashboard({Key? key, required this.coordinateur}) : super(key: key);
  @override State<_SectionDashboard> createState() => _EtatDashboard();
}

class _EtatDashboard extends State<_SectionDashboard> {
  bool _chargement = false;
  Map<String, dynamic> _data = {};
  DateTime? _lastUpdated;
  int _cacheAge = 0;

  @override
  void initState() {
    super.initState();
    widget.coordinateur.register(_chargerViaCoordinateur);
    _charger();
  }

  @override
  void dispose() {
    widget.coordinateur.unregister(_chargerViaCoordinateur);
    super.dispose();
  }

  void _chargerViaCoordinateur() { if (mounted) _charger(); }

  Future<void> _charger() async {
    if (!mounted) return;
    setState(() => _chargement = true);
    final result = await analyticsGetFull('/admin/dashboard');
    if (!mounted) return;
    setState(() {
      _data = ((result?.data as Map<String, dynamic>?)?['data'] as Map<String, dynamic>?) ?? {};
      _lastUpdated = result?.fetchedAt;
      _cacheAge = result?.cacheAge ?? 0;
      _chargement = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    // Utilisateurs
    final totalUsers     = (_data['total_users']           as num?)?.toInt() ?? 0;
    final newUsersMonth  = (_data['new_users_this_month']  as num?)?.toInt() ?? 0;
    final activeUsersWk  = (_data['active_users_this_week'] as num?)?.toInt() ?? 0;
    final avgScore       = (_data['average_global_score']  as num?)?.toDouble() ?? 0.0;
    // Scans
    final totalScans     = (_data['total_bin_scans']       as num?)?.toInt() ?? 0;
    final scansToday     = (_data['scans_today']           as num?)?.toInt() ?? 0;
    final scansWeek      = (_data['scans_this_week']       as num?)?.toInt() ?? 0;
    final points         = (_data['points_distributed']    as num?)?.toDouble() ?? 0.0;
    // Centres
    final totalCentres   = (_data['total_collection_points']  as num?)?.toInt() ?? 0;
    final activeCentres  = (_data['active_collection_points'] as num?)?.toInt() ?? 0;
    // Éducation
    final quiz           = (_data['total_quiz_submissions'] as num?)?.toInt() ?? 0;
    final avgQuizScore   = (_data['average_quiz_score']    as num?)?.toDouble() ?? 0.0;
    // Modération
    final modPending     = (_data['pending_moderation']    as num?)?.toInt() ?? 0;
    final pendingTests   = (_data['pending_testimonials']  as num?)?.toInt() ?? 0;
    final pendingProps   = (_data['pending_center_proposals'] as num?)?.toInt() ?? 0;

    return SectionCard(
      titre: L10n.tr('admin_kpi_overview'),
      icone: Icons.dashboard_rounded,
      couleur: AppTheme.primaryGreen,
      chargement: _chargement,
      onActualiser: _charger,
      lastUpdated: _lastUpdated,
      cacheAge: _cacheAge,
      filtres: const [],
      contenu: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [

        // ── Bloc 1 : Utilisateurs (2 grandes + 2 compactes) ──────────
        Text('👥 Utilisateurs', style: GoogleFonts.inter(
          fontSize: 11, fontWeight: FontWeight.w800, color: AppTheme.textMuted)),
        const SizedBox(height: 10),
        LayoutBuilder(builder: (_, c) {
          final w = (c.maxWidth - 12) / 2;
          return Column(children: [
            Row(children: [
              SizedBox(width: w, child: IndicateurPrincipal(
                valeur: '$totalUsers', etiquette: L10n.tr('admin_kpi_users'),
                sousTitre: 'Comptes actifs',
                icone: Icons.people_rounded, couleur: Colors.blue)),
              const SizedBox(width: 12),
              SizedBox(width: w, child: IndicateurPrincipal(
                valeur: avgScore.toStringAsFixed(1), etiquette: L10n.tr('admin_kpi_avg_score'),
                sousTitre: 'Score global moyen',
                icone: Icons.emoji_events_rounded, couleur: Colors.purple)),
            ]),
            const SizedBox(height: 10),
            Row(children: [
              Expanded(child: IndicateurCompact(
                valeur: '+$newUsersMonth', etiquette: 'Nouveaux / mois',
                icone: Icons.person_add_rounded, couleur: Colors.indigo)),
              const SizedBox(width: 8),
              Expanded(child: IndicateurCompact(
                valeur: '$activeUsersWk', etiquette: 'Actifs / semaine',
                icone: Icons.trending_up_rounded, couleur: Colors.teal)),
            ]),
          ]);
        }),

        const SizedBox(height: 20),

        // ── Bloc 2 : Scans QR ────────────────────────────────────────
        Text('📦 Scans QR & Points', style: GoogleFonts.inter(
          fontSize: 11, fontWeight: FontWeight.w800, color: AppTheme.textMuted)),
        const SizedBox(height: 10),
        LayoutBuilder(builder: (_, c) {
          final w = (c.maxWidth - 12) / 2;
          return Column(children: [
            Row(children: [
              SizedBox(width: w, child: IndicateurPrincipal(
                valeur: '$totalScans', etiquette: L10n.tr('admin_kpi_scans'),
                sousTitre: 'Total historique',
                icone: Icons.qr_code_scanner_rounded, couleur: AppTheme.primaryGreen)),
              const SizedBox(width: 12),
              SizedBox(width: w, child: IndicateurPrincipal(
                valeur: points.toStringAsFixed(0), etiquette: L10n.tr('admin_kpi_points'),
                sousTitre: 'Points distribués',
                icone: Icons.stars_rounded, couleur: Colors.amber)),
            ]),
            const SizedBox(height: 10),
            Row(children: [
              Expanded(child: IndicateurCompact(
                valeur: '$scansToday', etiquette: 'Scans aujourd\'hui',
                icone: Icons.today_rounded, couleur: Colors.green)),
              const SizedBox(width: 8),
              Expanded(child: IndicateurCompact(
                valeur: '$scansWeek', etiquette: 'Scans 7 jours',
                icone: Icons.date_range_rounded, couleur: Colors.cyan)),
            ]),
          ]);
        }),

        const SizedBox(height: 20),

        // ── Bloc 3 : Centres & Éducation ─────────────────────────────
        Text('🏭 Centres & Formation', style: GoogleFonts.inter(
          fontSize: 11, fontWeight: FontWeight.w800, color: AppTheme.textMuted)),
        const SizedBox(height: 10),
        LayoutBuilder(builder: (_, c) {
          final w = (c.maxWidth - 12) / 2;
          return Column(children: [
            Row(children: [
              SizedBox(width: w, child: IndicateurPrincipal(
                valeur: '$activeCentres/$totalCentres',
                etiquette: L10n.tr('admin_kpi_centers'),
                sousTitre: 'Disponibles / Total',
                icone: Icons.location_on_rounded, couleur: const Color(0xFFF59E0B))),
              const SizedBox(width: 12),
              SizedBox(width: w, child: IndicateurPrincipal(
                valeur: '$quiz', etiquette: L10n.tr('admin_kpi_quiz'),
                sousTitre: '∅ ${avgQuizScore.toStringAsFixed(1)}/10',
                icone: Icons.school_rounded, couleur: Colors.teal)),
            ]),
          ]);
        }),

        const SizedBox(height: 20),

        // ── Bloc 4 : Alertes à traiter ────────────────────────────────
        Text('⚠️ Alertes en attente', style: GoogleFonts.inter(
          fontSize: 11, fontWeight: FontWeight.w800, color: AppTheme.textMuted)),
        const SizedBox(height: 10),
        Row(children: [
          Expanded(child: IndicateurCompact(
            valeur: '$modPending', etiquette: 'Modération',
            icone: Icons.pending_actions_rounded,
            couleur: modPending > 0 ? Colors.orange : Colors.green,
            alerte: modPending > 0)),
          const SizedBox(width: 8),
          Expanded(child: IndicateurCompact(
            valeur: '$pendingTests', etiquette: 'Témoignages',
            icone: Icons.star_rounded,
            couleur: pendingTests > 0 ? Colors.orange : Colors.green,
            alerte: pendingTests > 0)),
          const SizedBox(width: 8),
          Expanded(child: IndicateurCompact(
            valeur: '$pendingProps', etiquette: 'Propositions',
            icone: Icons.add_location_rounded,
            couleur: pendingProps > 0 ? Colors.orange : Colors.green,
            alerte: pendingProps > 0)),
        ]),
      ]),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════
// SECTION 2 — SCANS QR (GET /admin/analytics/scans + /scans/by-day)
// ═══════════════════════════════════════════════════════════════════

class _SectionScans extends StatefulWidget {
  final _CoordinateurRefresh coordinateur;
  const _SectionScans({Key? key, required this.coordinateur}) : super(key: key);
  @override State<_SectionScans> createState() => _EtatScans();
}

class _EtatScans extends State<_SectionScans> {
  String _period = 'last_7_days';
  bool _chargement = false;
  Map<String, dynamic> _stats = {};
  List<Map<String, dynamic>> _courbe = [];
  DateTime? _lastUpdated;
  int _cacheAge = 0;

  @override
  void initState() {
    super.initState();
    widget.coordinateur.register(_chargerViaCoordinateur);
    _charger();
  }

  @override
  void dispose() {
    widget.coordinateur.unregister(_chargerViaCoordinateur);
    super.dispose();
  }

  void _chargerViaCoordinateur() { if (mounted) _charger(); }

  Future<void> _charger() async {
    if (!mounted) return;
    setState(() => _chargement = true);
    final days = _period == 'today' ? 1 : _period == 'last_7_days' ? 7 : 30;
    final results = await Future.wait([
      analyticsGetFull('/admin/analytics/scans?period=$_period'),
      analyticsGetFull('/admin/analytics/scans/by-day?days=$days'),
    ]);
    if (!mounted) return;
    setState(() {
      _stats    = (results[0]?.data as Map<String, dynamic>?) ?? {};
      _courbe   = ((results[1]?.data as List?)?.cast<Map<String, dynamic>>()) ?? [];
      _lastUpdated = results[0]?.fetchedAt;
      _cacheAge = results[0]?.cacheAge ?? 0;
      _chargement = false;
    });
  }

  static const _wasteColors = {
    'plastic': Colors.blue, 'glass': Colors.teal, 'metal': Colors.blueGrey,
    'paper': Colors.brown, 'organic': Colors.green,
  };
  static const _wasteIcons = {
    'plastic': '🧴', 'glass': '🍶', 'metal': '🔩', 'paper': '📄', 'organic': '🌿',
  };

  @override
  Widget build(BuildContext context) {
    final total    = (_stats['total']        as num?)?.toInt() ?? 0;
    final periode  = (_stats['this_period']  as num?)?.toInt() ?? 0;
    final points   = (_stats['points_distributed'] as num?)?.toDouble() ?? 0.0;
    final avgPts   = (_stats['average_points_per_scan'] as num?)?.toDouble() ?? 0.0;
    final wasteRaw = (_stats['by_waste_type'] as List?)?.cast<Map>() ?? [];
    final topBins  = (_stats['top_bins']     as List?)?.cast<Map>() ?? [];
    final maxW     = wasteRaw.isEmpty ? 1.0 : wasteRaw.map((w) => (w['count'] as num).toDouble()).reduce(math.max);

    return SectionCard(
      titre: 'Scans QR / Smart Bins',
      icone: Icons.qr_code_scanner_rounded,
      couleur: AppTheme.primaryGreen,
      chargement: _chargement,
      onActualiser: _charger,
      lastUpdated: _lastUpdated,
      cacheAge: _cacheAge,
      filtres: [
        FiltrePeriodeString(valeur: _period, couleur: AppTheme.primaryGreen,
          onChangement: (v) { setState(() => _period = v); _charger(); }),
      ],
      contenu: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        LayoutBuilder(builder: (_, c) {
          final w = (c.maxWidth - 12) / 2;
          return Column(children: [
            Row(children: [
              SizedBox(width: w, child: IndicateurPrincipal(valeur: '$total', etiquette: 'Total scans',
                sousTitre: 'Historique complet', icone: Icons.qr_code_rounded, couleur: AppTheme.primaryGreen)),
              const SizedBox(width: 12),
              SizedBox(width: w, child: IndicateurPrincipal(valeur: '$periode', etiquette: 'Cette période',
                sousTitre: _period.replaceAll('_', ' '), icone: Icons.timelapse_rounded, couleur: Colors.teal)),
            ]),
            const SizedBox(height: 12),
            Row(children: [
              SizedBox(width: w, child: IndicateurPrincipal(valeur: points.toStringAsFixed(0),
                etiquette: 'Points distribués', sousTitre: '~${avgPts.toStringAsFixed(1)} pts/scan',
                icone: Icons.stars_rounded, couleur: Colors.amber)),
              const SizedBox(width: 12),
              SizedBox(width: w, child: IndicateurPrincipal(valeur: avgPts.toStringAsFixed(1),
                etiquette: 'Moy. pts/scan', sousTitre: 'Rendement moyen',
                icone: Icons.speed_rounded, couleur: Colors.teal)),
            ]),
          ]);
        }),

        if (_courbe.isNotEmpty) ...[
          const SizedBox(height: 20),
          Text('Tendance des scans', style: GoogleFonts.inter(
            fontSize: 12, fontWeight: FontWeight.w800, color: AppTheme.textMuted)),
          const SizedBox(height: 8),
          GraphiqueLigne(donnees: _courbe, couleur: AppTheme.primaryGreen),
        ],
        if (wasteRaw.isNotEmpty) ...[
          const SizedBox(height: 20),
          Text('Types de déchets scannés', style: GoogleFonts.inter(
            fontSize: 12, fontWeight: FontWeight.w800, color: AppTheme.textMuted)),
          const SizedBox(height: 8),
          ...wasteRaw.map((w) {
            final type  = (w['waste_type'] as String? ?? 'autre').toLowerCase();
            final color = (_wasteColors[type] ?? Colors.grey) as Color;
            final emoji = _wasteIcons[type] ?? '♻️';
            return BarreProgression(
              etiquette: '$emoji ${w['waste_type']}',
              valeurTexte: '${w['count']} (${w['points']?.toStringAsFixed(0) ?? 0} pts)',
              valeur: (w['count'] as num).toDouble(),
              max: maxW, couleur: color,
            );
          }),
        ],
        if (topBins.isNotEmpty) ...[
          const SizedBox(height: 20),
          Text('Top Smart Bins', style: GoogleFonts.inter(
            fontSize: 12, fontWeight: FontWeight.w800, color: AppTheme.textMuted)),
          const SizedBox(height: 8),
          ...topBins.take(5).toList().asMap().entries.map((e) => Padding(
            padding: const EdgeInsets.symmetric(vertical: 4),
            child: Row(children: [
              Container(width: 26, height: 26,
                decoration: BoxDecoration(color: AppTheme.primaryGreen.withOpacity(0.1), shape: BoxShape.circle),
                child: Center(child: Text('${e.key + 1}', style: GoogleFonts.outfit(
                  fontSize: 11, fontWeight: FontWeight.w900, color: AppTheme.primaryGreen)))),
              const SizedBox(width: 10),
              Expanded(child: Text('Bin #${e.value['smart_bin_id']}', style: GoogleFonts.inter(
                fontSize: 12, fontWeight: FontWeight.w700, color: AppTheme.deepSlate))),
              Text('${e.value['scans_count']} scans', style: GoogleFonts.outfit(
                fontSize: 12, fontWeight: FontWeight.w800, color: Colors.teal)),
              const SizedBox(width: 8),
              Text('${(e.value['points_earned'] as num?)?.toStringAsFixed(0) ?? 0} pts',
                style: GoogleFonts.outfit(fontSize: 11, color: Colors.amber.shade700)),
            ]),
          )),
        ],
      ]),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════
// SECTION 3 — UTILISATEURS (GET /admin/analytics/users)
// ═══════════════════════════════════════════════════════════════════

class _SectionUtilisateurs extends StatefulWidget {
  final _CoordinateurRefresh coordinateur;
  const _SectionUtilisateurs({Key? key, required this.coordinateur}) : super(key: key);
  @override State<_SectionUtilisateurs> createState() => _EtatUtilisateurs();
}

class _EtatUtilisateurs extends State<_SectionUtilisateurs> {
  String _period = 'last_30_days';
  bool _chargement = false;
  Map<String, dynamic> _stats = {};
  DateTime? _lastUpdated;
  int _cacheAge = 0;

  @override
  void initState() {
    super.initState();
    widget.coordinateur.register(_chargerViaCoordinateur);
    _charger();
  }

  @override
  void dispose() {
    widget.coordinateur.unregister(_chargerViaCoordinateur);
    super.dispose();
  }

  void _chargerViaCoordinateur() { if (mounted) _charger(); }

  Future<void> _charger() async {
    if (!mounted) return;
    setState(() => _chargement = true);
    final result = await analyticsGetFull('/admin/analytics/users?period=$_period');
    if (!mounted) return;
    setState(() {
      _stats = (result?.data as Map<String, dynamic>?) ?? {};
      _lastUpdated = result?.fetchedAt;
      _cacheAge = result?.cacheAge ?? 0;
      _chargement = false;
    });
  }

  static const _libelles = {
    'user': 'Citoyen', 'educator': 'Éducateur', 'admin': 'Admin',
    'collector': 'Collecteur', 'point_manager': 'Gestionnaire'
  };
  static const _couleurs = <String, Color>{
    'user': Colors.blue, 'educator': Colors.purple, 'admin': Colors.red,
    'collector': Colors.orange, 'point_manager': Colors.teal
  };

  @override
  Widget build(BuildContext context) {
    final total   = (_stats['total']              as num?)?.toInt() ?? 0;
    final moy     = (_stats['average_global_score'] as num?)?.toDouble() ?? 0.0;
    final newPer  = (_stats['new_this_period']    as num?)?.toInt() ?? 0;
    final actifs  = (_stats['active_this_period'] as num?)?.toInt() ?? 0;
    final byRoleRaw = (_stats['by_role'] as Map<String, dynamic>?) ?? {};
    final top     = (_stats['top_scorers'] as List?)?.cast<Map>() ?? [];

    final rolesData = byRoleRaw.entries
        .where((e) => (e.value as num? ?? 0) > 0).toList();
    final maxCount = rolesData.isEmpty ? 1.0
        : rolesData.map((e) => (e.value as num).toDouble()).reduce(math.max);

    return SectionCard(
      titre: 'Utilisateurs & Communauté',
      icone: Icons.people_alt_rounded,
      couleur: Colors.blue,
      chargement: _chargement,
      onActualiser: _charger,
      lastUpdated: _lastUpdated,
      cacheAge: _cacheAge,
      filtres: [
        FiltrePeriodeString(valeur: _period, couleur: Colors.blue,
          onChangement: (v) { setState(() => _period = v); _charger(); }),
      ],
      contenu: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        LayoutBuilder(builder: (_, c) {
          final w = (c.maxWidth - 12) / 2;
          return Column(children: [
            Row(children: [
              SizedBox(width: w, child: IndicateurPrincipal(valeur: '$total',
                etiquette: 'Total inscrits', sousTitre: 'Comptes actifs',
                icone: Icons.person_rounded, couleur: Colors.blue)),
              const SizedBox(width: 12),
              SizedBox(width: w, child: IndicateurPrincipal(valeur: '$newPer',
                etiquette: 'Nouveaux', sousTitre: 'Cette période',
                icone: Icons.person_add_rounded, couleur: Colors.indigo)),
            ]),
            const SizedBox(height: 12),
            Row(children: [
              SizedBox(width: w, child: IndicateurPrincipal(valeur: '$actifs',
                etiquette: 'Actifs (ont scanné)', sousTitre: 'Cette période',
                icone: Icons.trending_up_rounded, couleur: Colors.green)),
              const SizedBox(width: 12),
              SizedBox(width: w, child: IndicateurPrincipal(valeur: moy.toStringAsFixed(1),
                etiquette: 'Score moyen', sousTitre: 'Moyenne globale',
                icone: Icons.stars_rounded, couleur: Colors.amber)),
            ]),
          ]);
        }),
        if (rolesData.isNotEmpty) ...[
          const SizedBox(height: 20),
          Text('Répartition par rôle', style: GoogleFonts.inter(
            fontSize: 12, fontWeight: FontWeight.w800, color: AppTheme.textMuted)),
          const SizedBox(height: 10),
          ...rolesData.map((e) => BarreProgression(
            etiquette: _libelles[e.key] ?? e.key,
            valeurTexte: '${e.value} utilisateurs',
            valeur: (e.value as num).toDouble(),
            max: maxCount, couleur: _couleurs[e.key] ?? Colors.grey,
          )),
        ],
        if (top.isNotEmpty) ...[
          const SizedBox(height: 20),
          Text('🏆 Meilleurs citoyens', style: GoogleFonts.inter(
            fontSize: 12, fontWeight: FontWeight.w800, color: AppTheme.textMuted)),
          const SizedBox(height: 10),
          ...top.take(3).toList().asMap().entries.map((e) => Padding(
            padding: const EdgeInsets.symmetric(vertical: 5),
            child: Row(children: [
              Container(
                width: 28, height: 28,
                decoration: BoxDecoration(
                  color: [Colors.amber, Colors.grey.shade400, Colors.brown.shade300][e.key].withOpacity(0.15),
                  shape: BoxShape.circle),
                child: Center(child: Text('${e.key + 1}', style: GoogleFonts.outfit(
                  fontSize: 12, fontWeight: FontWeight.w900, color: AppTheme.deepSlate)))),
              const SizedBox(width: 10),
              Expanded(child: Text('${e.value['name']}', style: GoogleFonts.inter(
                fontSize: 12, fontWeight: FontWeight.w700, color: AppTheme.deepSlate))),
              BadgeStatut(label: '${e.value['role'] ?? 'user'}',
                couleur: _couleurs[e.value['role']] ?? Colors.grey),
              const SizedBox(width: 8),
              Text('${e.value['score']} pts', style: GoogleFonts.outfit(
                fontSize: 14, fontWeight: FontWeight.w900, color: Colors.amber.shade700)),
            ]),
          )),
        ],
      ]),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════
// SECTION 4 — ÉDUCATION (GET /admin/analytics/education)
// ═══════════════════════════════════════════════════════════════════

class _SectionEducation extends StatefulWidget {
  final _CoordinateurRefresh coordinateur;
  const _SectionEducation({Key? key, required this.coordinateur}) : super(key: key);
  @override State<_SectionEducation> createState() => _EtatEducation();
}

class _EtatEducation extends State<_SectionEducation> {
  String _period = 'last_30_days';
  bool _chargement = false;
  Map<String, dynamic> _stats = {};
  DateTime? _lastUpdated;
  int _cacheAge = 0;

  @override
  void initState() {
    super.initState();
    widget.coordinateur.register(_chargerViaCoordinateur);
    _charger();
  }

  @override
  void dispose() {
    widget.coordinateur.unregister(_chargerViaCoordinateur);
    super.dispose();
  }

  void _chargerViaCoordinateur() { if (mounted) _charger(); }

  Future<void> _charger() async {
    if (!mounted) return;
    setState(() => _chargement = true);
    final result = await analyticsGetFull('/admin/analytics/education?period=$_period');
    if (!mounted) return;
    setState(() {
      _stats = (result?.data as Map<String, dynamic>?) ?? {};
      _lastUpdated = result?.fetchedAt;
      _cacheAge = result?.cacheAge ?? 0;
      _chargement = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final totalQuiz = (_stats['total_quizzes']    as num?)?.toInt() ?? 0;
    final totalSub  = (_stats['total_submissions'] as num?)?.toInt() ?? 0;
    final avgScore  = (_stats['average_quiz_score'] as num?)?.toDouble() ?? 0.0;
    final successRt = (_stats['success_rate']     as num?)?.toDouble() ?? 0.0;
    final topQuiz   = (_stats['most_attempted']   as List?)?.cast<Map>() ?? [];

    return SectionCard(
      titre: 'Formation & Quiz',
      icone: Icons.school_rounded,
      couleur: Colors.teal,
      chargement: _chargement,
      onActualiser: _charger,
      lastUpdated: _lastUpdated,
      cacheAge: _cacheAge,
      filtres: [
        FiltrePeriodeString(valeur: _period, couleur: Colors.teal,
          onChangement: (v) { setState(() => _period = v); _charger(); }),
      ],
      contenu: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        LayoutBuilder(builder: (_, c) {
          final w = (c.maxWidth - 12) / 2;
          return Column(children: [
            Row(children: [
              SizedBox(width: w, child: IndicateurPrincipal(valeur: '$totalQuiz', etiquette: 'Quiz créés',
                sousTitre: 'Total plateforme', icone: Icons.quiz_rounded, couleur: Colors.teal)),
              const SizedBox(width: 12),
              SizedBox(width: w, child: IndicateurPrincipal(valeur: '$totalSub', etiquette: 'Soumissions',
                sousTitre: 'Cette période', icone: Icons.assignment_turned_in_rounded, couleur: Colors.indigo)),
            ]),
            const SizedBox(height: 12),
            Row(children: [
              SizedBox(width: w, child: IndicateurPrincipal(valeur: '${avgScore.toStringAsFixed(1)}/10',
                etiquette: 'Score moyen', sousTitre: 'Moyenne globale',
                icone: Icons.analytics_rounded, couleur: Colors.orange)),
              const SizedBox(width: 12),
              SizedBox(width: w, child: IndicateurPrincipal(valeur: '${successRt.toStringAsFixed(0)}%',
                etiquette: 'Taux réussite', sousTitre: 'Score ≥ 5/10',
                icone: Icons.emoji_events_rounded,
                couleur: successRt >= 60 ? Colors.green : Colors.orange,
                alerte: successRt < 40)),
            ]),
          ]);
        }),
        const SizedBox(height: 16),
        Text('Taux de réussite global', style: GoogleFonts.inter(
          fontSize: 12, fontWeight: FontWeight.w800, color: AppTheme.textMuted)),
        const SizedBox(height: 8),
        ClipRRect(
          borderRadius: BorderRadius.circular(8),
          child: LinearProgressIndicator(
            value: successRt / 100, minHeight: 12,
            backgroundColor: Theme.of(context).brightness == Brightness.dark
                ? const Color(0xFF1E293B)
                : Colors.grey.shade100,
            valueColor: AlwaysStoppedAnimation(successRt >= 60 ? Colors.green : Colors.orange),
          ),
        ),
        const SizedBox(height: 4),
        Text('${successRt.toStringAsFixed(1)}% des participants réussissent (seuil : 5/10)',
          style: GoogleFonts.inter(fontSize: 10, color: AppTheme.textMuted)),
        if (topQuiz.isNotEmpty) ...[
          const SizedBox(height: 20),
          Text('Quiz les plus tentés', style: GoogleFonts.inter(
            fontSize: 12, fontWeight: FontWeight.w800, color: AppTheme.textMuted)),
          const SizedBox(height: 10),
          ...topQuiz.take(5).toList().asMap().entries.map((e) => Padding(
            padding: const EdgeInsets.symmetric(vertical: 5),
            child: Row(children: [
              Container(width: 26, height: 26,
                decoration: BoxDecoration(color: Colors.teal.withOpacity(0.1), borderRadius: BorderRadius.circular(6)),
                child: Center(child: Text('${e.key + 1}', style: GoogleFonts.outfit(
                  fontSize: 11, fontWeight: FontWeight.w900, color: Colors.teal)))),
              const SizedBox(width: 10),
              Expanded(child: Text('${e.value['title'] ?? '—'}', style: GoogleFonts.inter(
                fontSize: 12, fontWeight: FontWeight.w600, color: AppTheme.deepSlate),
                overflow: TextOverflow.ellipsis)),
              Text('${e.value['submissions']} tentatives', style: GoogleFonts.outfit(
                fontSize: 11, fontWeight: FontWeight.w800, color: Colors.teal)),
              if (e.value['avg_score'] != null) ...[
                const SizedBox(width: 8),
                BadgeStatut(label: '${(e.value['avg_score'] as num).toStringAsFixed(1)}/10',
                  couleur: Colors.orange),
              ],
            ]),
          )),
        ],
      ]),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════
// SECTION 5 — MODÉRATION (GET /admin/analytics/community)
// ═══════════════════════════════════════════════════════════════════

class _SectionModeration extends StatefulWidget {
  final _CoordinateurRefresh coordinateur;
  const _SectionModeration({Key? key, required this.coordinateur}) : super(key: key);
  @override State<_SectionModeration> createState() => _EtatModeration();
}

class _EtatModeration extends State<_SectionModeration> {
  bool _chargement = false;
  Map<String, dynamic> _stats = {};
  DateTime? _lastUpdated;
  int _cacheAge = 0;

  @override
  void initState() {
    super.initState();
    widget.coordinateur.register(_chargerViaCoordinateur);
    _charger();
  }

  @override
  void dispose() {
    widget.coordinateur.unregister(_chargerViaCoordinateur);
    super.dispose();
  }

  void _chargerViaCoordinateur() { if (mounted) _charger(); }

  Future<void> _charger() async {
    if (!mounted) return;
    setState(() => _chargement = true);
    final result = await analyticsGetFull('/admin/analytics/community');
    if (!mounted) return;
    setState(() {
      _stats = (result?.data as Map<String, dynamic>?) ?? {};
      _lastUpdated = result?.fetchedAt;
      _cacheAge = result?.cacheAge ?? 0;
      _chargement = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final pendAI    = (_stats['pending_ai']              as num?)?.toInt() ?? 0;
    final pendRev   = (_stats['pending_review']          as num?)?.toInt() ?? 0;
    final published = (_stats['published']               as num?)?.toInt() ?? 0;
    final rejected  = (_stats['rejected']                as num?)?.toInt() ?? 0;
    final totalPosts = (_stats['total_posts']            as num?)?.toInt() ?? 0;
    final pendTest  = (_stats['pending_testimonials']    as num?)?.toInt() ?? 0;
    final pendProp  = (_stats['pending_center_proposals'] as num?)?.toInt() ?? 0;
    final autoRate  = (_stats['auto_approve_rate']       as num?)?.toDouble() ?? 0.0;
    final health    = (_stats['worker_health']           as String?) ?? 'ok';
    final totalPending = pendAI + pendRev;
    final workerColor = health == 'ok' ? Colors.green : health == 'warning' ? Colors.orange : Colors.red;

    return SectionCard(
      titre: 'Publications & Modération',
      icone: Icons.library_books_rounded,
      couleur: Colors.purple,
      chargement: _chargement,
      onActualiser: _charger,
      lastUpdated: _lastUpdated,
      cacheAge: _cacheAge,
      filtres: const [],
      contenu: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        LayoutBuilder(builder: (_, c) {
          final w = (c.maxWidth - 12) / 2;
          return Column(children: [
            Row(children: [
              SizedBox(width: w, child: IndicateurPrincipal(valeur: '$totalPosts',
                etiquette: 'Total posts', sousTitre: 'Toutes plateformes',
                icone: Icons.article_rounded, couleur: Colors.purple)),
              const SizedBox(width: 12),
              SizedBox(width: w, child: IndicateurPrincipal(valeur: '$published',
                etiquette: 'Approuvés',
                sousTitre: '${totalPosts > 0 ? (published / totalPosts * 100).toStringAsFixed(0) : 0}% du total',
                icone: Icons.check_circle_rounded, couleur: Colors.green)),
            ]),
            const SizedBox(height: 12),
            Row(children: [
              SizedBox(width: w, child: IndicateurPrincipal(valeur: '$totalPending',
                etiquette: 'En attente',
                sousTitre: '$pendAI IA · $pendRev review',
                icone: Icons.pending_actions_rounded,
                couleur: totalPending > 0 ? Colors.orange : Colors.green,
                alerte: totalPending > 0)),
              const SizedBox(width: 12),
              SizedBox(width: w, child: IndicateurPrincipal(valeur: '$rejected',
                etiquette: 'Rejetés', sousTitre: 'Par IA ou admin',
                icone: Icons.cancel_rounded, couleur: Colors.red)),
            ]),
          ]);
        }),
        if (totalPosts > 0) ...[
          const SizedBox(height: 20),
          Text('Répartition des publications', style: GoogleFonts.inter(
            fontSize: 12, fontWeight: FontWeight.w800, color: AppTheme.textMuted)),
          const SizedBox(height: 12),
          GraphiqueAnneau(
            tranches: [
              MapEntry('Approuvés', published.toDouble()),
              if (pendAI > 0) MapEntry('En attente IA', pendAI.toDouble()),
              if (pendRev > 0) MapEntry('À réviser', pendRev.toDouble()),
              if (rejected > 0) MapEntry('Rejetés', rejected.toDouble()),
            ],
            couleurs: [Colors.green, Colors.orange.shade300, Colors.orange, Colors.red],
            etiquettes: const ['Approuvés', 'En attente IA', 'À réviser', 'Rejetés'],
          ),
        ],
        const SizedBox(height: 20),
        Text('Contenus en attente de validation', style: GoogleFonts.inter(
          fontSize: 12, fontWeight: FontWeight.w800, color: AppTheme.textMuted)),
        const SizedBox(height: 10),
        _ligneInfo(Icons.star_rounded, 'Témoignages en attente', '$pendTest',
          pendTest > 0 ? Colors.orange : Colors.green),
        const SizedBox(height: 8),
        _ligneInfo(Icons.add_location_rounded, 'Propositions de centres', '$pendProp',
          pendProp > 0 ? Colors.orange : Colors.green),
      ]),
    );
  }

  Widget _ligneInfo(IconData icon, String label, String valeur, Color couleur) =>
    Row(children: [
      Container(padding: const EdgeInsets.all(7),
        decoration: BoxDecoration(color: couleur.withOpacity(0.1), borderRadius: BorderRadius.circular(8)),
        child: Icon(icon, size: 14, color: couleur)),
      const SizedBox(width: 10),
      Expanded(child: Text(label, style: GoogleFonts.inter(
        fontSize: 12, fontWeight: FontWeight.w600, color: AppTheme.deepSlate))),
      BadgeStatut(label: valeur, couleur: couleur),
    ]);
}

// ═══════════════════════════════════════════════════════════════════
// SECTION 6 — CENTRES DE TRI (GET /admin/analytics/centers/*)
// ═══════════════════════════════════════════════════════════════════

class _SectionCentres extends StatefulWidget {
  final _CoordinateurRefresh coordinateur;
  const _SectionCentres({Key? key, required this.coordinateur}) : super(key: key);
  @override State<_SectionCentres> createState() => _EtatCentres();
}

class _EtatCentres extends State<_SectionCentres> {
  String _ville = 'Toutes';
  bool _chargement = false;
  List<Map> _parVille = [];
  List<Map> _parStatut = [];
  DateTime? _lastUpdated;
  int _cacheAge = 0;

  static const _villes = [
    'Toutes', 'Tunis', 'Nabeul', 'Sousse', 'Sfax',
    'Bizerte', 'Hammamet', 'Monastir', 'Ariana', 'Ben Arous'
  ];

  @override
  void initState() {
    super.initState();
    widget.coordinateur.register(_chargerViaCoordinateur);
    _charger();
  }

  @override
  void dispose() {
    widget.coordinateur.unregister(_chargerViaCoordinateur);
    super.dispose();
  }

  void _chargerViaCoordinateur() { if (mounted) _charger(); }

  Future<void> _charger() async {
    if (!mounted) return;
    setState(() => _chargement = true);
    final ville = _ville == 'Toutes' ? '' : _ville;
    final results = await Future.wait([
      analyticsGetFull('/admin/analytics/centers/by-city'),
      analyticsGetFull('/admin/analytics/centers/by-status?city=$ville'),
    ]);
    if (!mounted) return;
    final toutesVilles = (results[0]?.data as List?)?.cast<Map>() ?? [];
    setState(() {
      _parVille  = _ville == 'Toutes' ? toutesVilles
          : toutesVilles.where((c) => c['city'] == _ville).toList();
      _parStatut = (results[1]?.data as List?)?.cast<Map>() ?? [];
      _lastUpdated = results[0]?.fetchedAt;
      _cacheAge = results[0]?.cacheAge ?? 0;
      _chargement = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    int statCount(String label) =>
        (_parStatut.firstWhere((r) => (r['status'] as String?) == label,
          orElse: () => {'count': 0})['count'] as num?)?.toInt() ?? 0;
    final dispo = statCount('Disponible');
    final sat   = statCount('Saturé');
    final maint = statCount('Maintenance');
    final total = dispo + sat + maint;
    final maxT  = _parVille.isEmpty ? 1.0
        : _parVille.map((c) => (c['total'] as num).toDouble()).reduce(math.max);

    return SectionCard(
      titre: 'Centres de Tri & Collecte',
      icone: Icons.location_on_rounded,
      couleur: const Color(0xFFF59E0B),
      chargement: _chargement,
      onActualiser: _charger,
      lastUpdated: _lastUpdated,
      cacheAge: _cacheAge,
      filtres: [
        FiltreDeroulant(etiquette: 'Ville', valeur: _ville, options: _villes,
          couleur: const Color(0xFFF59E0B),
          onChangement: (v) { setState(() => _ville = v); _charger(); }),
      ],
      contenu: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        LayoutBuilder(builder: (_, c) {
          final w = (c.maxWidth - 12) / 2;
          return Column(children: [
            Row(children: [
              SizedBox(width: w, child: IndicateurPrincipal(valeur: '$total',
                etiquette: 'Total centres',
                sousTitre: _ville == 'Toutes' ? 'Toutes villes' : _ville,
                icone: Icons.location_on_rounded, couleur: const Color(0xFFF59E0B))),
              const SizedBox(width: 12),
              SizedBox(width: w, child: IndicateurPrincipal(valeur: '$dispo',
                etiquette: 'Disponible',
                sousTitre: total > 0 ? '${(dispo / total * 100).toStringAsFixed(0)}% opérationnels' : '—',
                icone: Icons.check_circle_outline_rounded, couleur: Colors.green)),
            ]),
            const SizedBox(height: 12),
            Row(children: [
              SizedBox(width: w, child: IndicateurPrincipal(valeur: '$sat',
                etiquette: 'Saturés',
                sousTitre: sat > 0 ? '⚠️ Intervention requise' : '✅ Aucun saturé',
                icone: Icons.warning_amber_rounded,
                couleur: sat > 0 ? Colors.red : Colors.green,
                alerte: sat > 0)),
              const SizedBox(width: 12),
              SizedBox(width: w, child: IndicateurPrincipal(valeur: '$maint',
                etiquette: 'Maintenance',
                sousTitre: maint > 0 ? '🔧 $maint hors service' : '✅ Aucun',
                icone: Icons.build_circle_outlined,
                couleur: maint > 0 ? Colors.orange : Colors.green,
                alerte: maint > 0)),
            ]),
          ]);
        }),
        if (_parVille.isNotEmpty) ...[
          const SizedBox(height: 20),
          Text('Centres par ville', style: GoogleFonts.inter(
            fontSize: 12, fontWeight: FontWeight.w800, color: AppTheme.textMuted)),
          const SizedBox(height: 10),
          ..._parVille.take(8).map((c) {
            final hasSat   = (c['saturated']  as int? ?? 0) > 0;
            final hasMaint = (c['maintenance'] as int? ?? 0) > 0;
            final barColor = hasSat ? Colors.red : hasMaint ? Colors.orange : const Color(0xFFF59E0B);
            final detail = '${c['available']} dispo${hasSat ? ' · ${c['saturated']} sat' : ''}${hasMaint ? ' · ${c['maintenance']} maint' : ''}';
            return BarreProgression(
              etiquette: '${c['city']}',
              valeurTexte: '${c['total']} ($detail)',
              valeur: (c['total'] as num).toDouble(),
              max: maxT, couleur: barColor,
            );
          }),
        ],
        if (_parStatut.isNotEmpty && total > 0) ...[
          const SizedBox(height: 20),
          Text('État des centres', style: GoogleFonts.inter(
            fontSize: 12, fontWeight: FontWeight.w800, color: AppTheme.textMuted)),
          const SizedBox(height: 12),
          GraphiqueAnneau(
            tranches: [
              if (dispo  > 0) MapEntry('Disponible', dispo.toDouble()),
              if (sat    > 0) MapEntry('Saturé', sat.toDouble()),
              if (maint  > 0) MapEntry('Maintenance', maint.toDouble()),
            ],
            couleurs: const [Colors.green, Colors.red, Colors.orange],
            etiquettes: const ['Disponible', 'Saturé', 'Maintenance'],
          ),
        ],
      ]),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════
// SECTION 7 — ANOMALIES (GET /admin/analytics/anomalies)
// ═══════════════════════════════════════════════════════════════════

class _SectionAnomalies extends StatefulWidget {
  final _CoordinateurRefresh coordinateur;
  const _SectionAnomalies({Key? key, required this.coordinateur}) : super(key: key);
  @override State<_SectionAnomalies> createState() => _EtatAnomalies();
}

class _EtatAnomalies extends State<_SectionAnomalies> {
  bool _chargement = false;
  int _count = 0;
  List<Map> _anomalies = [];
  DateTime? _lastUpdated;
  int _cacheAge = 0;

  @override
  void initState() {
    super.initState();
    widget.coordinateur.register(_chargerViaCoordinateur);
    _charger();
  }

  @override
  void dispose() {
    widget.coordinateur.unregister(_chargerViaCoordinateur);
    super.dispose();
  }

  void _chargerViaCoordinateur() { if (mounted) _charger(); }

  Future<void> _charger() async {
    if (!mounted) return;
    setState(() => _chargement = true);
    final result = await analyticsGetFull('/admin/analytics/anomalies');
    if (!mounted) return;
    setState(() {
      final raw  = result?.data as Map<String, dynamic>?;
      _count     = (raw?['count']     as num?)?.toInt() ?? 0;
      _anomalies = (raw?['anomalies'] as List?)?.cast<Map>() ?? [];
      _lastUpdated = result?.fetchedAt;
      _cacheAge = result?.cacheAge ?? 0;
      _chargement = false;
    });
  }

  static Color _severityColor(String? s) {
    switch (s) {
      case 'high':   return Colors.red;
      case 'medium': return Colors.orange;
      default:       return Colors.blue;
    }
  }

  static IconData _anomalyIcon(String? type) {
    switch (type) {
      case 'SCAN_RATE_LIMIT':   return Icons.speed_rounded;
      case 'REPEATED_BIN_SCAN': return Icons.repeat_rounded;
      case 'FIREBASE_UNSYNCED': return Icons.sync_problem_rounded;
      default:                  return Icons.warning_amber_rounded;
    }
  }

  @override
  Widget build(BuildContext context) {
    return SectionCard(
      titre: 'Anomalies & Comportements Suspects',
      icone: Icons.security_rounded,
      couleur: Colors.red,
      chargement: _chargement,
      onActualiser: _charger,
      lastUpdated: _lastUpdated,
      cacheAge: _cacheAge,
      filtres: const [],
      contenu: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Expanded(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                color: _count > 0 ? Colors.red.shade50 : Colors.green.shade50,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: _count > 0 ? Colors.red.shade200 : Colors.green.shade200),
              ),
              child: Row(children: [
                Icon(_count > 0 ? Icons.gpp_bad_rounded : Icons.gpp_good_rounded,
                  color: _count > 0 ? Colors.red : Colors.green, size: 22),
                const SizedBox(width: 12),
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(_count > 0 ? '$_count anomalie(s) détectée(s)' : 'Aucune anomalie',
                    style: GoogleFonts.outfit(fontSize: 14, fontWeight: FontWeight.w900,
                      color: _count > 0 ? Colors.red.shade800 : Colors.green.shade800)),
                  Text(_count > 0 ? 'Actions recommandées ci-dessous' : 'Système normal',
                    style: GoogleFonts.inter(fontSize: 11, color: AppTheme.textMuted)),
                ]),
              ]),
            ),
          ),
        ]),
        if (_anomalies.isNotEmpty) ...[
          const SizedBox(height: 16),
          Text('Détail des anomalies', style: GoogleFonts.inter(
            fontSize: 12, fontWeight: FontWeight.w800, color: AppTheme.textMuted)),
          const SizedBox(height: 10),
          ..._anomalies.map((a) {
            final severity = a['severity'] as String? ?? 'low';
            final type     = a['type']     as String? ?? '';
            final color    = _severityColor(severity);
            return Container(
              margin: const EdgeInsets.only(bottom: 10),
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: color.withOpacity(0.05),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: color.withOpacity(0.25)),
              ),
              child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Container(padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(color: color.withOpacity(0.15), borderRadius: BorderRadius.circular(10)),
                  child: Icon(_anomalyIcon(type), color: color, size: 18)),
                const SizedBox(width: 12),
                Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Row(children: [
                    Expanded(child: Text(type.replaceAll('_', ' '), style: GoogleFonts.outfit(
                      fontSize: 12, fontWeight: FontWeight.w900, color: color))),
                    BadgeStatut(label: severity.toUpperCase(), couleur: color),
                  ]),
                  const SizedBox(height: 4),
                  Text('${a['message']}', style: GoogleFonts.inter(
                    fontSize: 11, color: AppTheme.deepSlate, height: 1.4)),
                  if (a['user_id'] != null) ...[
                    const SizedBox(height: 4),
                    Text('Utilisateur ID : ${a['user_id']}',
                      style: GoogleFonts.inter(fontSize: 10, color: AppTheme.textMuted)),
                  ],
                ])),
              ]),
            );
          }),
        ] else if (!_chargement)
          Padding(
            padding: const EdgeInsets.only(top: 12),
            child: Center(child: Text('✅ Aucun comportement suspect détecté',
              style: GoogleFonts.inter(color: AppTheme.textMuted, fontSize: 12))),
          ),
      ]),
    );
  }
}
