import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../theme/app_theme.dart';
import 'analytics_helpers.dart';
import '../../services/l10n_service.dart';
import '../../core/firebase/firebase_admin_stats_service.dart';

// ═══════════════════════════════════════════════════════════════════
// ONGLET ANALYTICS ADMIN — Architecture hybride Firebase + FastAPI
//
// Sources de données :
//   🔥 Firebase RTDB (push temps réel, pas de polling) :
//       Section 1 — KPIs Vue d'ensemble   → /admin_stats/
//       Section 2 — Scans QR              → /admin_stats/ + /leaderboard/
//       Section 3 — Utilisateurs          → /admin_stats/ + /leaderboard/
//       Section 7 — Poubelles             → /poubelles/
//
//   🌐 FastAPI HTTP (polling 30s via _CoordinateurRefresh) :
//       Section 4 — Formation & Quiz      → /admin/analytics/education
//       Section 5 — Modération            → /admin/analytics/community
//       Section 6 — Centres de tri        → /admin/analytics/centers/*
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

          // ── SECTION 1 : VUE D'ENSEMBLE KPIs 🔥 Firebase RTDB ────────
          const SectionDivider(label: 'VUE D\'ENSEMBLE'),
          const _SectionDashboardFirebase(),
          const SizedBox(height: 4),

          // ── SECTION 2 : SCANS QR 🔥 Firebase RTDB ───────────────────
          const SectionDivider(label: 'ACTIVITÉ — SCANS QR'),
          _SectionScansFirebase(coordinateur: _CoordinateurRefresh()),
          const SizedBox(height: 4),

          // ── SECTION 3 : UTILISATEURS 🔥 Firebase RTDB ───────────────
          const SectionDivider(label: 'COMMUNAUTÉ — UTILISATEURS'),
          const _SectionUtilisateursFirebase(),
          const SizedBox(height: 4),

          // ── SECTION 4 : ÉDUCATION 🌐 FastAPI ─────────────────────────
          const SectionDivider(label: 'FORMATION & ÉDUCATION'),
          _SectionEducation(coordinateur: _CoordinateurRefresh()),
          const SizedBox(height: 4),

          // ── SECTION 5 : MODÉRATION 🌐 FastAPI ────────────────────────
          const SectionDivider(label: 'MODÉRATION & PUBLICATIONS'),
          _SectionModeration(coordinateur: _CoordinateurRefresh()),
          const SizedBox(height: 4),

          // ── SECTION 6 : CENTRES DE TRI 🌐 FastAPI ────────────────────
          const SectionDivider(label: 'CENTRES DE TRI & COLLECTE'),
          _SectionCentres(coordinateur: _CoordinateurRefresh()),
          const SizedBox(height: 4),

          // ── SECTION 7 : POUBELLES INTELLIGENTES 🔥 Firebase RTDB ─────
          const SectionDivider(label: 'POUBELLES INTELLIGENTES — TEMPS RÉEL'),
          const _SectionPoubelles(),
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
                ? const SizedBox(width: 14, height: 14,
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
// SECTION 1 — DASHBOARD KPI 🔥 Firebase RTDB /admin_stats/
// Données poussées par le backend après chaque scan QR.
// StreamBuilder = zéro polling, mise à jour instantanée.
// ═══════════════════════════════════════════════════════════════════

class _SectionDashboardFirebase extends StatelessWidget {
  const _SectionDashboardFirebase({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<AdminStatsSnapshot>(
      stream: FirebaseAdminStatsService().watchAdminStats(),
      builder: (context, snapshot) {
        final s = snapshot.data ?? AdminStatsSnapshot.empty();
        final isLoading = snapshot.connectionState == ConnectionState.waiting
            && !snapshot.hasData;

        // Badge Firebase live
        final lastUpdStr = s.lastUpdated != null
            ? _formatAgo(s.lastUpdated!)
            : 'En attente…';

        return SectionCard(
          titre: L10n.tr('admin_kpi_overview'),
          icone: Icons.dashboard_rounded,
          couleur: AppTheme.primaryGreen,
          chargement: isLoading,
          onActualiser: () {},  // pas de polling — Firebase push
          lastUpdated: s.lastUpdated,
          cacheAge: 0,
          filtres: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: Colors.green.withOpacity(0.12),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.green.withOpacity(0.3)),
              ),
              child: Row(mainAxisSize: MainAxisSize.min, children: [
                Container(width: 6, height: 6,
                  decoration: const BoxDecoration(
                    color: Colors.green, shape: BoxShape.circle)),
                const SizedBox(width: 5),
                Text('Firebase · $lastUpdStr',
                  style: GoogleFonts.inter(
                    fontSize: 9, fontWeight: FontWeight.w700, color: Colors.green.shade700)),
              ]),
            ),
          ],
          contenu: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [

            // ── Bloc 1 : Utilisateurs ──────────────────────────────────
            Text('👥 Utilisateurs', style: GoogleFonts.inter(
              fontSize: 11, fontWeight: FontWeight.w800, color: AppTheme.textMuted)),
            const SizedBox(height: 10),
            LayoutBuilder(builder: (_, c) {
              final w = (c.maxWidth - 12) / 2;
              return Column(children: [
                Row(children: [
                  SizedBox(width: w, child: IndicateurPrincipal(
                    valeur: '${s.totalUsers}', etiquette: L10n.tr('admin_kpi_users'),
                    sousTitre: 'Comptes actifs',
                    icone: Icons.people_rounded, couleur: Colors.blue)),
                  const SizedBox(width: 12),
                  SizedBox(width: w, child: IndicateurPrincipal(
                    valeur: s.averageScore.toStringAsFixed(1),
                    etiquette: L10n.tr('admin_kpi_avg_score'),
                    sousTitre: 'Score global moyen',
                    icone: Icons.emoji_events_rounded, couleur: Colors.purple)),
                ]),
                const SizedBox(height: 10),
                Row(children: [
                  Expanded(child: IndicateurCompact(
                    valeur: '+${s.newUsersMonth}', etiquette: 'Nouveaux / mois',
                    icone: Icons.person_add_rounded, couleur: Colors.indigo)),
                  const SizedBox(width: 8),
                  Expanded(child: IndicateurCompact(
                    valeur: '${s.activeUsersWeek}', etiquette: 'Actifs / semaine',
                    icone: Icons.trending_up_rounded, couleur: Colors.teal)),
                ]),
              ]);
            }),

            const SizedBox(height: 20),

            // ── Bloc 2 : Scans QR ──────────────────────────────────────
            Text('📦 Scans QR & Points', style: GoogleFonts.inter(
              fontSize: 11, fontWeight: FontWeight.w800, color: AppTheme.textMuted)),
            const SizedBox(height: 10),
            LayoutBuilder(builder: (_, c) {
              final w = (c.maxWidth - 12) / 2;
              return Column(children: [
                Row(children: [
                  SizedBox(width: w, child: IndicateurPrincipal(
                    valeur: '${s.totalScans}',
                    etiquette: L10n.tr('admin_kpi_scans'),
                    sousTitre: 'Total historique',
                    icone: Icons.qr_code_scanner_rounded, couleur: AppTheme.primaryGreen)),
                  const SizedBox(width: 12),
                  SizedBox(width: w, child: IndicateurPrincipal(
                    valeur: s.pointsDistributed.toStringAsFixed(0),
                    etiquette: L10n.tr('admin_kpi_points'),
                    sousTitre: 'Points distribués',
                    icone: Icons.stars_rounded, couleur: Colors.amber)),
                ]),
                const SizedBox(height: 10),
                Row(children: [
                  Expanded(child: IndicateurCompact(
                    valeur: '${s.scansToday}', etiquette: 'Scans aujourd\'hui',
                    icone: Icons.today_rounded, couleur: Colors.green)),
                  const SizedBox(width: 8),
                  Expanded(child: IndicateurCompact(
                    valeur: '${s.scansWeek}', etiquette: 'Scans 7 jours',
                    icone: Icons.date_range_rounded, couleur: Colors.cyan)),
                ]),
              ]);
            }),

            const SizedBox(height: 20),

            // ── Bloc 2b : Collecteurs ──────────────────────────────────
            Text('🚛 Collectes (Collecteurs)', style: GoogleFonts.inter(
              fontSize: 11, fontWeight: FontWeight.w800, color: AppTheme.textMuted)),
            const SizedBox(height: 10),
            Row(children: [
              Expanded(child: IndicateurCompact(
                valeur: '${s.totalCollections}', etiquette: 'Total collectes',
                icone: Icons.local_shipping_rounded, couleur: Colors.indigo)),
              const SizedBox(width: 8),
              Expanded(child: IndicateurCompact(
                valeur: '${s.collectionsWeek}', etiquette: 'Collectes 7j',
                icone: Icons.recycling_rounded, couleur: Colors.teal)),
            ]),

            const SizedBox(height: 20),

            // ── Bloc 3 : Centres ───────────────────────────────────────
            Text('🏭 Centres de collecte', style: GoogleFonts.inter(
              fontSize: 11, fontWeight: FontWeight.w800, color: AppTheme.textMuted)),
            const SizedBox(height: 10),
            LayoutBuilder(builder: (_, c) {
              final w = (c.maxWidth - 12) / 2;
              return Row(children: [
                SizedBox(width: w, child: IndicateurPrincipal(
                  valeur: '${s.activeCenters}/${s.totalCenters}',
                  etiquette: L10n.tr('admin_kpi_centers'),
                  sousTitre: 'Disponibles / Total',
                  icone: Icons.location_on_rounded, couleur: const Color(0xFFF59E0B))),
                const SizedBox(width: 12),
                SizedBox(width: w, child: IndicateurPrincipal(
                  valeur: s.averageScore.toStringAsFixed(1),
                  etiquette: 'Score moyen',
                  sousTitre: 'Citoyens actifs',
                  icone: Icons.school_rounded, couleur: Colors.teal)),
              ]);
            }),

            const SizedBox(height: 20),

            // ── Bloc 4 : Alertes en attente ────────────────────────────
            Text('⚠️ Alertes en attente', style: GoogleFonts.inter(
              fontSize: 11, fontWeight: FontWeight.w800, color: AppTheme.textMuted)),
            const SizedBox(height: 10),
            Row(children: [
              Expanded(child: IndicateurCompact(
                valeur: '${s.pendingModeration}', etiquette: 'Modération',
                icone: Icons.pending_actions_rounded,
                couleur: s.pendingModeration > 0 ? Colors.orange : Colors.green,
                alerte: s.pendingModeration > 0)),
              const SizedBox(width: 8),
              Expanded(child: IndicateurCompact(
                valeur: '${s.pendingTestimonials}', etiquette: 'Témoignages',
                icone: Icons.star_rounded,
                couleur: s.pendingTestimonials > 0 ? Colors.orange : Colors.green,
                alerte: s.pendingTestimonials > 0)),
              const SizedBox(width: 8),
              Expanded(child: IndicateurCompact(
                valeur: '${s.pendingProposals}', etiquette: 'Propositions',
                icone: Icons.add_location_rounded,
                couleur: s.pendingProposals > 0 ? Colors.orange : Colors.green,
                alerte: s.pendingProposals > 0)),
            ]),
          ]),
        );
      },
    );
  }
}

String _formatAgo(DateTime dt) {
  final diff = DateTime.now().difference(dt);
  if (diff.inSeconds < 5)  return 'À l\'instant';
  if (diff.inSeconds < 60) return 'il y a ${diff.inSeconds}s';
  if (diff.inMinutes < 60) return 'il y a ${diff.inMinutes}min';
  return 'il y a ${diff.inHours}h';
}

// ═══════════════════════════════════════════════════════════════════
// SECTION 2 — SCANS QR 🔥 Firebase RTDB /admin_stats/ + courbe FastAPI
// KPIs en temps réel via Firebase, courbe de tendance via FastAPI.
// ═══════════════════════════════════════════════════════════════════

class _SectionScansFirebase extends StatefulWidget {
  final _CoordinateurRefresh coordinateur;
  const _SectionScansFirebase({Key? key, required this.coordinateur}) : super(key: key);
  @override State<_SectionScansFirebase> createState() => _EtatScansFirebase();
}

class _EtatScansFirebase extends State<_SectionScansFirebase> {
  String _period = 'last_7_days';
  bool _chargementCourbe = false;
  List<Map<String, dynamic>> _courbe = [];

  @override
  void initState() {
    super.initState();
    widget.coordinateur.register(_chargerCourbe);
    _chargerCourbe();
  }

  @override
  void dispose() {
    widget.coordinateur.unregister(_chargerCourbe);
    super.dispose();
  }

  Future<void> _chargerCourbe() async {
    if (!mounted) return;
    setState(() => _chargementCourbe = true);
    final days = _period == 'today' ? 1 : _period == 'last_7_days' ? 7 : 30;
    final result = await analyticsGetFull('/admin/analytics/scans/by-day?days=$days');
    if (!mounted) return;
    setState(() {
      _courbe = ((result?.data as List?)?.cast<Map<String, dynamic>>()) ?? [];
      _chargementCourbe = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<AdminStatsSnapshot>(
      stream: FirebaseAdminStatsService().watchAdminStats(),
      builder: (context, snapshot) {
        final s = snapshot.data ?? AdminStatsSnapshot.empty();
        final isLoading = snapshot.connectionState == ConnectionState.waiting
            && !snapshot.hasData;

        final scansForPeriod = _period == 'today'
            ? s.scansToday
            : _period == 'last_7_days'
                ? s.scansWeek
                : s.totalScans;

        final lastUpdStr = s.lastUpdated != null ? _formatAgo(s.lastUpdated!) : '…';

        return SectionCard(
          titre: 'Scans QR / Smart Bins',
          icone: Icons.qr_code_scanner_rounded,
          couleur: AppTheme.primaryGreen,
          chargement: isLoading,
          onActualiser: _chargerCourbe,
          lastUpdated: s.lastUpdated,
          cacheAge: 0,
          filtres: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: Colors.green.withOpacity(0.12),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.green.withOpacity(0.3)),
              ),
              child: Row(mainAxisSize: MainAxisSize.min, children: [
                Container(width: 6, height: 6,
                  decoration: const BoxDecoration(color: Colors.green, shape: BoxShape.circle)),
                const SizedBox(width: 5),
                Text('Firebase · $lastUpdStr',
                  style: GoogleFonts.inter(fontSize: 9, fontWeight: FontWeight.w700, color: Colors.green.shade700)),
              ]),
            ),
            const SizedBox(width: 8),
            FiltrePeriodeString(valeur: _period, couleur: AppTheme.primaryGreen,
              onChangement: (v) { setState(() => _period = v); _chargerCourbe(); }),
          ],
          contenu: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            LayoutBuilder(builder: (_, c) {
              final w = (c.maxWidth - 12) / 2;
              return Column(children: [
                Row(children: [
                  SizedBox(width: w, child: IndicateurPrincipal(
                    valeur: '${s.totalScans}', etiquette: 'Total scans',
                    sousTitre: 'Historique complet',
                    icone: Icons.qr_code_rounded, couleur: AppTheme.primaryGreen)),
                  const SizedBox(width: 12),
                  SizedBox(width: w, child: IndicateurPrincipal(
                    valeur: '$scansForPeriod', etiquette: 'Cette période',
                    sousTitre: _period.replaceAll('_', ' '),
                    icone: Icons.timelapse_rounded, couleur: Colors.teal)),
                ]),
                const SizedBox(height: 12),
                Row(children: [
                  SizedBox(width: w, child: IndicateurPrincipal(
                    valeur: s.pointsDistributed.toStringAsFixed(0),
                    etiquette: 'Points distribués', sousTitre: 'Total cumulé',
                    icone: Icons.stars_rounded, couleur: Colors.amber)),
                  const SizedBox(width: 12),
                  SizedBox(width: w, child: IndicateurPrincipal(
                    valeur: s.totalScans > 0
                        ? (s.pointsDistributed / s.totalScans).toStringAsFixed(1)
                        : '0',
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
            ] else if (_chargementCourbe)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 16),
                child: Center(child: SizedBox(width: 20, height: 20,
                  child: CircularProgressIndicator(strokeWidth: 2, color: AppTheme.primaryGreen))),
              ),
          ]),
        );
      },
    );
  }
}

// ═══════════════════════════════════════════════════════════════════
// SECTION 3 — UTILISATEURS 🔥 Firebase RTDB /admin_stats/ + /leaderboard/
// Compteurs temps réel + top scorers depuis le leaderboard Firebase.
// ═══════════════════════════════════════════════════════════════════

class _SectionUtilisateursFirebase extends StatelessWidget {
  const _SectionUtilisateursFirebase({Key? key}) : super(key: key);

  static const _medalColors = [Colors.amber, Colors.blueGrey, Colors.brown];
  static const _roleColors  = <String, Color>{
    'user': Colors.blue, 'educator': Colors.purple, 'admin': Colors.red,
    'collector': Colors.orange, 'point_manager': Colors.teal,
  };
  static const _roleLabels = {
    'user': 'Citoyen', 'educator': 'Éducateur', 'admin': 'Admin',
    'collector': 'Collecteur', 'point_manager': 'Gestionnaire',
  };

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<AdminStatsSnapshot>(
      stream: FirebaseAdminStatsService().watchAdminStats(),
      builder: (ctx, statsSnap) {
        final s = statsSnap.data ?? AdminStatsSnapshot.empty();
        final isLoading = statsSnap.connectionState == ConnectionState.waiting
            && !statsSnap.hasData;

        return StreamBuilder<List<LeaderboardEntry>>(
          stream: FirebaseAdminStatsService().watchLeaderboard(),
          builder: (ctx2, lbSnap) {
            final leaderboard = lbSnap.data ?? [];
            final lastUpdStr = s.lastUpdated != null ? _formatAgo(s.lastUpdated!) : '…';

            return SectionCard(
              titre: 'Utilisateurs & Communauté',
              icone: Icons.people_alt_rounded,
              couleur: Colors.blue,
              chargement: isLoading,
              onActualiser: () {},
              lastUpdated: s.lastUpdated,
              cacheAge: 0,
              filtres: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.blue.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.blue.withOpacity(0.3)),
                  ),
                  child: Row(mainAxisSize: MainAxisSize.min, children: [
                    Container(width: 6, height: 6,
                      decoration: const BoxDecoration(color: Colors.blue, shape: BoxShape.circle)),
                    const SizedBox(width: 5),
                    Text('Firebase · $lastUpdStr',
                      style: GoogleFonts.inter(fontSize: 9, fontWeight: FontWeight.w700, color: Colors.blue.shade700)),
                  ]),
                ),
              ],
              contenu: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                LayoutBuilder(builder: (_, c) {
                  final w = (c.maxWidth - 12) / 2;
                  return Column(children: [
                    Row(children: [
                      SizedBox(width: w, child: IndicateurPrincipal(
                        valeur: '${s.totalUsers}',
                        etiquette: 'Total inscrits', sousTitre: 'Comptes enregistrés',
                        icone: Icons.person_rounded, couleur: Colors.blue)),
                      const SizedBox(width: 12),
                      SizedBox(width: w, child: IndicateurPrincipal(
                        valeur: '+${s.newUsersMonth}',
                        etiquette: 'Nouveaux', sousTitre: 'Ce mois',
                        icone: Icons.person_add_rounded, couleur: Colors.indigo)),
                    ]),
                    const SizedBox(height: 12),
                    Row(children: [
                      SizedBox(width: w, child: IndicateurPrincipal(
                        valeur: '${s.activeUsersWeek}',
                        etiquette: 'Actifs', sousTitre: 'Cette semaine',
                        icone: Icons.trending_up_rounded, couleur: Colors.green)),
                      const SizedBox(width: 12),
                      SizedBox(width: w, child: IndicateurPrincipal(
                        valeur: s.averageScore.toStringAsFixed(1),
                        etiquette: 'Score moyen', sousTitre: 'Moyenne globale',
                        icone: Icons.stars_rounded, couleur: Colors.amber)),
                    ]),
                  ]);
                }),

                // ── Leaderboard depuis Firebase /leaderboard/ ──────────
                if (leaderboard.isNotEmpty) ...[
                  const SizedBox(height: 20),
                  Text('🏆 Meilleurs citoyens (Leaderboard Firebase)',
                    style: GoogleFonts.inter(
                      fontSize: 12, fontWeight: FontWeight.w800, color: AppTheme.textMuted)),
                  const SizedBox(height: 10),
                  ...leaderboard.take(5).toList().asMap().entries.map((e) {
                    final entry = e.value;
                    final medalColor = e.key < 3 ? _medalColors[e.key] : Colors.blueGrey;
                    return Padding(
                      padding: const EdgeInsets.symmetric(vertical: 5),
                      child: Row(children: [
                        Container(
                          width: 28, height: 28,
                          decoration: BoxDecoration(
                            color: medalColor.withOpacity(0.15),
                            shape: BoxShape.circle),
                          child: Center(child: Text('${e.key + 1}',
                            style: GoogleFonts.outfit(
                              fontSize: 12, fontWeight: FontWeight.w900,
                              color: AppTheme.deepSlate)))),
                        const SizedBox(width: 10),
                        Expanded(child: Text(entry.name,
                          style: GoogleFonts.inter(
                            fontSize: 12, fontWeight: FontWeight.w700,
                            color: AppTheme.deepSlate))),
                        BadgeStatut(
                          label: _roleLabels[entry.role] ?? entry.role,
                          couleur: _roleColors[entry.role] ?? Colors.grey),
                        const SizedBox(width: 8),
                        Text('${entry.score.toStringAsFixed(0)} pts',
                          style: GoogleFonts.outfit(
                            fontSize: 14, fontWeight: FontWeight.w900,
                            color: Colors.amber.shade700)),
                      ]),
                    );
                  }),
                ],
              ]),
            );
          },
        );
      },
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
        const SizedBox(height: 16),
        const Divider(height: 1),
        const SizedBox(height: 12),
        Row(children: [
          Icon(Icons.auto_awesome_rounded, size: 12, color: Colors.purple.shade300),
          const SizedBox(width: 6),
          Text(
            "Auto-approbation IA : ${(autoRate * 100).toStringAsFixed(0)}%",
            style: GoogleFonts.inter(fontSize: 10, color: AppTheme.textMuted, fontWeight: FontWeight.w600),
          ),
          const Spacer(),
          Container(
            width: 6, height: 6,
            decoration: BoxDecoration(color: workerColor, shape: BoxShape.circle),
          ),
          const SizedBox(width: 6),
          Text(
            "Modérateur IA : ${health.toUpperCase()}",
            style: GoogleFonts.inter(fontSize: 10, color: AppTheme.textMuted, fontWeight: FontWeight.w600),
          ),
        ]),
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
// SECTION POUBELLES 🔥 Firebase RTDB /poubelles/
// État temps réel de chaque Smart Bin mis à jour après chaque scan.
// ═══════════════════════════════════════════════════════════════════

class _SectionPoubelles extends StatelessWidget {
  const _SectionPoubelles({Key? key}) : super(key: key);

  Color _etatColor(String etat) {
    switch (etat) {
      case 'plein':          return Colors.red;
      case 'mi-plein':       return Colors.orange;
      case 'en_maintenance': return Colors.purple;
      default:               return Colors.green; // vide
    }
  }

  IconData _etatIcon(String etat) {
    switch (etat) {
      case 'plein':          return Icons.error_rounded;
      case 'mi-plein':       return Icons.warning_amber_rounded;
      case 'en_maintenance': return Icons.build_circle_rounded;
      default:               return Icons.check_circle_rounded;
    }
  }

  String _etatLabel(String etat) {
    switch (etat) {
      case 'plein':          return 'Plein';
      case 'mi-plein':       return 'Mi-plein';
      case 'en_maintenance': return 'Maintenance';
      default:               return 'Vide';
    }
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<PoubelleSnapshot>>(
      stream: FirebaseAdminStatsService().watchPoubelles(),
      builder: (context, snapshot) {
        final poubelles = snapshot.data ?? [];
        final isLoading = snapshot.connectionState == ConnectionState.waiting
            && !snapshot.hasData;

        // Compteurs par état
        final nbPlein  = poubelles.where((p) => p.isPlein).length;
        final nbMiPl   = poubelles.where((p) => p.isMiPlein).length;
        final nbMaint  = poubelles.where((p) => p.isMaintenance).length;
        final nbVide   = poubelles.where((p) => p.isVide).length;
        final total    = poubelles.length;

        return SectionCard(
          titre: 'Poubelles Intelligentes',
          icone: Icons.delete_rounded,
          couleur: Colors.green,
          chargement: isLoading,
          onActualiser: () {},  // Firebase push — pas de polling
          lastUpdated: null,
          cacheAge: 0,
          filtres: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: Colors.green.withOpacity(0.12),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.green.withOpacity(0.3)),
              ),
              child: Row(mainAxisSize: MainAxisSize.min, children: [
                Container(width: 6, height: 6,
                  decoration: const BoxDecoration(color: Colors.green, shape: BoxShape.circle)),
                const SizedBox(width: 5),
                Text('Firebase RTDB · Temps réel',
                  style: GoogleFonts.inter(
                    fontSize: 9, fontWeight: FontWeight.w700, color: Colors.green.shade700)),
              ]),
            ),
          ],
          contenu: poubelles.isEmpty && !isLoading
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 32),
                    child: Column(children: [
                      const Icon(Icons.delete_outline_rounded,
                        size: 40, color: AppTheme.textMuted),
                      const SizedBox(height: 12),
                      Text('Aucune poubelle connectée',
                        style: GoogleFonts.inter(
                          fontSize: 13, color: AppTheme.textMuted, fontWeight: FontWeight.w600)),
                      const SizedBox(height: 4),
                      Text('Les données apparaîtront après le premier scan QR',
                        style: GoogleFonts.inter(fontSize: 11, color: AppTheme.textMuted)),
                    ]),
                  ),
                )
              : Column(crossAxisAlignment: CrossAxisAlignment.start, children: [

                  // ── Résumé compteurs ───────────────────────────────────
                  LayoutBuilder(builder: (_, c) {
                    final w = (c.maxWidth - 24) / 4;
                    return Row(children: [
                      SizedBox(width: w, child: _compteurBin('$total', 'Total', Colors.blueGrey, Icons.delete_rounded)),
                      const SizedBox(width: 8),
                      SizedBox(width: w, child: _compteurBin('$nbPlein', 'Pleins', Colors.red, Icons.error_rounded,
                        alerte: nbPlein > 0)),
                      const SizedBox(width: 8),
                      SizedBox(width: w, child: _compteurBin('$nbMiPl', 'Mi-pleins', Colors.orange, Icons.warning_amber_rounded)),
                      const SizedBox(width: 8),
                      SizedBox(width: w, child: _compteurBin('$nbVide', 'Vides', Colors.green, Icons.check_circle_rounded)),
                    ]);
                  }),

                  if (nbMaint > 0) ...[
                    const SizedBox(height: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      decoration: BoxDecoration(
                        color: Colors.purple.withOpacity(0.08),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: Colors.purple.withOpacity(0.2)),
                      ),
                      child: Row(children: [
                        const Icon(Icons.build_circle_rounded, color: Colors.purple, size: 16),
                        const SizedBox(width: 8),
                        Text('$nbMaint poubelle(s) en maintenance',
                          style: GoogleFonts.inter(
                            fontSize: 11, fontWeight: FontWeight.w700, color: Colors.purple.shade700)),
                      ]),
                    ),
                  ],

                  // ── Liste des poubelles triées (pleines en premier) ────
                  if (poubelles.isNotEmpty) ...[
                    const SizedBox(height: 20),
                    Text('État détaillé par poubelle',
                      style: GoogleFonts.inter(
                        fontSize: 12, fontWeight: FontWeight.w800, color: AppTheme.textMuted)),
                    const SizedBox(height: 10),
                    ...poubelles.take(20).map((p) {
                      final color    = _etatColor(p.etat);
                      final icon     = _etatIcon(p.etat);
                      final label    = _etatLabel(p.etat);
                      final majStr   = p.derniereMaj != null ? _formatAgo(p.derniereMaj!) : '—';
                      return Container(
                        margin: const EdgeInsets.only(bottom: 8),
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                        decoration: BoxDecoration(
                          color: color.withOpacity(0.04),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: color.withOpacity(0.15)),
                        ),
                        child: Row(children: [
                          // Icône état
                          Container(
                            padding: const EdgeInsets.all(7),
                            decoration: BoxDecoration(
                              color: color.withOpacity(0.12),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Icon(icon, color: color, size: 16),
                          ),
                          const SizedBox(width: 10),
                          // Infos poubelle
                          Expanded(child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text('Bin ${p.binId}',
                                style: GoogleFonts.outfit(
                                  fontSize: 12, fontWeight: FontWeight.w800,
                                  color: AppTheme.deepSlate),
                                overflow: TextOverflow.ellipsis),
                              Text('MàJ : $majStr',
                                style: GoogleFonts.inter(
                                  fontSize: 10, color: AppTheme.textMuted)),
                            ],
                          )),
                          // Poids
                          if (p.poids > 0) ...[
                            Text('${p.poids.toStringAsFixed(1)} kg',
                              style: GoogleFonts.outfit(
                                fontSize: 12, fontWeight: FontWeight.w700,
                                color: AppTheme.deepSlate)),
                            const SizedBox(width: 8),
                          ],
                          // Badge état
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                            decoration: BoxDecoration(
                              color: color.withOpacity(0.12),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Text(label,
                              style: GoogleFonts.inter(
                                fontSize: 10, fontWeight: FontWeight.w800, color: color)),
                          ),
                          // Barre de remplissage
                          const SizedBox(width: 8),
                          SizedBox(
                            width: 40,
                            child: ClipRRect(
                              borderRadius: BorderRadius.circular(4),
                              child: LinearProgressIndicator(
                                value: p.tauxEstime,
                                minHeight: 6,
                                backgroundColor: color.withOpacity(0.1),
                                valueColor: AlwaysStoppedAnimation(color),
                              ),
                            ),
                          ),
                        ]),
                      );
                    }),
                  ],
                ]),
        );
      },
    );
  }

  Widget _compteurBin(String valeur, String label, Color color, IconData icon, {bool alerte = false}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
      decoration: BoxDecoration(
        color: color.withOpacity(0.08),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withOpacity(alerte ? 0.5 : 0.2), width: alerte ? 1.5 : 1),
      ),
      child: Column(children: [
        Icon(icon, color: color, size: 16),
        const SizedBox(height: 4),
        Text(valeur, style: GoogleFonts.outfit(
          fontSize: 16, fontWeight: FontWeight.w900, color: color)),
        Text(label, style: GoogleFonts.inter(
          fontSize: 9, color: AppTheme.textMuted, fontWeight: FontWeight.w600),
          textAlign: TextAlign.center),
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
