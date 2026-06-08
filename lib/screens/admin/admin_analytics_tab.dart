import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../theme/app_theme.dart';
import 'analytics_helpers.dart';

// ═══════════════════════════════════════════════════════════════════
// ONGLET ANALYTICS ADMIN — 7 sections alimentées par FastAPI
// Principe : Flutter affiche, FastAPI agrège et sécurise.
// Chaque section appelle son endpoint dédié.
// ═══════════════════════════════════════════════════════════════════

class AdminAnalyticsTab extends StatelessWidget {
  const AdminAnalyticsTab({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return const SingleChildScrollView(
      key: PageStorageKey('indicateurs'),
      primary: false,
      padding: EdgeInsets.all(20),
      physics: BouncingScrollPhysics(),
      child: Column(children: [
        _SectionDashboard(),
        _SectionScans(),
        _SectionUtilisateurs(),
        _SectionEducation(),
        _SectionModeration(),
        _SectionCentres(),
        _SectionAnomalies(),
        SizedBox(height: 80),
      ]),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════
// SECTION 1 — DASHBOARD KPI (GET /admin/dashboard)
// Un seul appel au chargement — 8 cartes KPI
// ═══════════════════════════════════════════════════════════════════

class _SectionDashboard extends StatefulWidget {
  const _SectionDashboard({Key? key}) : super(key: key);
  @override State<_SectionDashboard> createState() => _EtatDashboard();
}

class _EtatDashboard extends State<_SectionDashboard> {
  bool _chargement = false;
  Map<String, dynamic> _data = {};
  Timer? _timer;

  @override void initState() { super.initState(); _charger(); _timer = Timer.periodic(const Duration(seconds: 60), (_) => _charger()); }
  @override void dispose() { _timer?.cancel(); super.dispose(); }

  Future<void> _charger() async {
    if (!mounted) return;
    setState(() => _chargement = true);
    final r = await analyticsGet('/admin/dashboard');
    if (!mounted) return;
    setState(() {
      _data = (r?['data'] as Map<String, dynamic>?) ?? {};
      _chargement = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final total      = (_data['total_users'] as num?)?.toInt() ?? 0;
    final scans      = (_data['total_bin_scans'] as num?)?.toInt() ?? 0;
    final points     = (_data['points_distributed'] as num?)?.toDouble() ?? 0.0;
    final centres    = (_data['total_collection_points'] as num?)?.toInt() ?? 0;
    final actifs     = (_data['active_collection_points'] as num?)?.toInt() ?? 0;
    final score      = (_data['average_global_score'] as num?)?.toDouble() ?? 0.0;
    final quiz       = (_data['total_quiz_submissions'] as num?)?.toInt() ?? 0;
    final modPending = (_data['pending_moderation'] as num?)?.toInt() ?? 0;
    final firebase   = (_data['firebase_unsynced_scans'] as num?)?.toInt() ?? 0;
    final anomalies  = (_data['anomalies_count'] as num?)?.toInt() ?? 0;

    return SectionCard(
      titre: 'Vue d\'ensemble',
      icone: Icons.dashboard_rounded,
      couleur: AppTheme.primaryGreen,
      chargement: _chargement,
      onActualiser: _charger,
      filtres: const [],
      contenu: Column(children: [
        // KPI Dashboard 2x2
        LayoutBuilder(builder: (_, c) {
          final w = (c.maxWidth - 12) / 2;
          return Column(children: [
            Row(children: [
              SizedBox(width: w, child: IndicateurPrincipal(valeur: '$total', etiquette: 'Utilisateurs', sousTitre: 'Comptes actifs', icone: Icons.people_rounded, couleur: Colors.blue)),
              const SizedBox(width: 12),
              SizedBox(width: w, child: IndicateurPrincipal(valeur: '$scans', etiquette: 'Scans QR', sousTitre: 'Total historique', icone: Icons.qr_code_scanner_rounded, couleur: AppTheme.primaryGreen)),
            ]),
            const SizedBox(height: 12),
            Row(children: [
              SizedBox(width: w, child: IndicateurPrincipal(valeur: '${points.toStringAsFixed(0)} pts', etiquette: 'Points', sousTitre: 'Distribués', icone: Icons.stars_rounded, couleur: Colors.amber)),
              const SizedBox(width: 12),
              SizedBox(width: w, child: IndicateurPrincipal(valeur: '$actifs/$centres', etiquette: 'Centres', sousTitre: 'Actifs / Total', icone: Icons.location_on_rounded, couleur: const Color(0xFFF59E0B))),
            ]),
            const SizedBox(height: 12),
            Row(children: [
              SizedBox(width: w, child: IndicateurPrincipal(valeur: score.toStringAsFixed(1), etiquette: 'Score moyen', sousTitre: 'Moyenne citoyens', icone: Icons.emoji_events_rounded, couleur: Colors.purple)),
              const SizedBox(width: 12),
              SizedBox(width: w, child: IndicateurPrincipal(valeur: '$quiz', etiquette: 'Quiz faits', sousTitre: 'Soumissions totales', icone: Icons.school_rounded, couleur: Colors.teal)),
            ]),
            const SizedBox(height: 12),
            Row(children: [
              SizedBox(width: w, child: IndicateurPrincipal(valeur: '$modPending', etiquette: 'Modération', sousTitre: modPending > 0 ? '⚠️ À traiter' : '✅ File vide', icone: Icons.pending_actions_rounded, couleur: modPending > 0 ? Colors.orange : Colors.green, alerte: modPending > 0)),
              const SizedBox(width: 12),
              SizedBox(width: w, child: IndicateurPrincipal(valeur: '$firebase', etiquette: 'Firebase', sousTitre: 'Non synchronisés', icone: Icons.sync_problem_rounded, couleur: firebase > 0 ? Colors.red : Colors.green, alerte: firebase > 0)),
            ]),
          ]);
        }),
        // Badge anomalies si présentes
        if (anomalies > 0) ...[
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(color: Colors.red.shade50, borderRadius: BorderRadius.circular(12), border: Border.all(color: Colors.red.shade200)),
            child: Row(children: [
              const Icon(Icons.warning_amber_rounded, color: Colors.red, size: 18),
              const SizedBox(width: 10),
              Expanded(child: Text('$anomalies anomalie(s) détectée(s) — voir la section Anomalies ci-dessous.', style: GoogleFonts.inter(fontSize: 12, color: Colors.red.shade800, fontWeight: FontWeight.w600))),
            ]),
          ),
        ],
      ]),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════
// SECTION 2 — SCANS QR (GET /admin/analytics/scans + /scans/by-day)
// ═══════════════════════════════════════════════════════════════════

class _SectionScans extends StatefulWidget {
  const _SectionScans({Key? key}) : super(key: key);
  @override State<_SectionScans> createState() => _EtatScans();
}

class _EtatScans extends State<_SectionScans> {
  String _period = 'last_7_days';
  bool _chargement = false;
  Map<String, dynamic> _stats = {};
  List<Map<String, dynamic>> _courbe = [];
  Timer? _timer;

  @override void initState() { super.initState(); _charger(); _timer = Timer.periodic(const Duration(seconds: 30), (_) => _charger()); }
  @override void dispose() { _timer?.cancel(); super.dispose(); }

  Future<void> _charger() async {
    if (!mounted) return;
    setState(() => _chargement = true);
    final days = _period == 'today' ? 1 : _period == 'last_7_days' ? 7 : 30;
    final r = await Future.wait([
      analyticsGet('/admin/analytics/scans?period=$_period'),
      analyticsGet('/admin/analytics/scans/by-day?days=$days'),
    ]);
    if (!mounted) return;
    setState(() {
      _stats  = (r[0] as Map<String, dynamic>?) ?? {};
      _courbe = ((r[1] as List?)?.cast<Map<String, dynamic>>()) ?? [];
      _chargement = false;
    });
  }

  // Types de déchets → icône + couleur
  static const _wasteColors = {
    'plastic':  Colors.blue,
    'glass':    Colors.teal,
    'metal':    Colors.blueGrey,
    'paper':    Colors.brown,
    'organic':  Colors.green,
  };
  static const _wasteIcons = {
    'plastic': '🧴', 'glass': '🍶', 'metal': '🔩', 'paper': '📄', 'organic': '🌿',
  };

  @override
  Widget build(BuildContext context) {
    final total    = (_stats['total'] as num?)?.toInt() ?? 0;
    final periode  = (_stats['this_period'] as num?)?.toInt() ?? 0;
    final points   = (_stats['points_distributed'] as num?)?.toDouble() ?? 0.0;
    final firebase = (_stats['firebase_unsynced'] as num?)?.toInt() ?? 0;
    final avgPts   = (_stats['average_points_per_scan'] as num?)?.toDouble() ?? 0.0;
    final wasteRaw = (_stats['by_waste_type'] as List?)?.cast<Map>() ?? [];
    final topBins  = (_stats['top_bins'] as List?)?.cast<Map>() ?? [];
    final maxW     = wasteRaw.isEmpty ? 1.0 : wasteRaw.map((w) => (w['count'] as num).toDouble()).reduce(math.max);

    return SectionCard(
      titre: 'Scans QR / Smart Bins',
      icone: Icons.qr_code_scanner_rounded,
      couleur: AppTheme.primaryGreen,
      chargement: _chargement,
      onActualiser: _charger,
      filtres: [
        FiltrePeriodeString(valeur: _period, couleur: AppTheme.primaryGreen, onChangement: (v) { setState(() => _period = v); _charger(); }),
      ],
      contenu: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        // KPI 4 cartes (2x2)
        LayoutBuilder(builder: (_, c) {
          final w = (c.maxWidth - 12) / 2;
          return Column(children: [
            Row(children: [
              SizedBox(width: w, child: IndicateurPrincipal(valeur: '$total', etiquette: 'Total scans', sousTitre: 'Historique complet', icone: Icons.qr_code_rounded, couleur: AppTheme.primaryGreen)),
              const SizedBox(width: 12),
              SizedBox(width: w, child: IndicateurPrincipal(valeur: '$periode', etiquette: 'Cette période', sousTitre: _period.replaceAll('_', ' '), icone: Icons.timelapse_rounded, couleur: Colors.teal)),
            ]),
            const SizedBox(height: 12),
            Row(children: [
              SizedBox(width: w, child: IndicateurPrincipal(valeur: points.toStringAsFixed(0), etiquette: 'Points', sousTitre: '~${avgPts.toStringAsFixed(1)} pts/scan', icone: Icons.stars_rounded, couleur: Colors.amber)),
              const SizedBox(width: 12),
              SizedBox(width: w, child: IndicateurPrincipal(valeur: '$firebase', etiquette: 'Non sync', sousTitre: 'Firebase', icone: Icons.sync_problem_rounded, couleur: firebase > 0 ? Colors.red : Colors.green, alerte: firebase > 0)),
            ]),
          ]);
        }),
        // Courbe temporelle
        if (_courbe.isNotEmpty) ...[
          const SizedBox(height: 20),
          Text('Tendance des scans', style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w800, color: AppTheme.textMuted)),
          const SizedBox(height: 8),
          GraphiqueLigne(donnees: _courbe, couleur: AppTheme.primaryGreen),
        ],
        // Types de déchets
        if (wasteRaw.isNotEmpty) ...[
          const SizedBox(height: 20),
          Text('Types de déchets scannés', style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w800, color: AppTheme.textMuted)),
          const SizedBox(height: 8),
          ...wasteRaw.map((w) {
            final type = (w['waste_type'] as String? ?? 'autre').toLowerCase();
            final color = (_wasteColors[type] ?? Colors.grey) as Color;
            final emoji = _wasteIcons[type] ?? '♻️';
            return BarreProgression(
              etiquette: '$emoji ${w['waste_type']}',
              valeurTexte: '${w['count']} (${w['points']?.toStringAsFixed(0) ?? 0} pts)',
              valeur: (w['count'] as num).toDouble(),
              max: maxW,
              couleur: color,
            );
          }),
        ],
        // Top smart bins
        if (topBins.isNotEmpty) ...[
          const SizedBox(height: 20),
          Text('Top Smart Bins', style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w800, color: AppTheme.textMuted)),
          const SizedBox(height: 8),
          ...topBins.take(5).toList().asMap().entries.map((e) => Padding(
            padding: const EdgeInsets.symmetric(vertical: 4),
            child: Row(children: [
              Container(
                width: 26, height: 26,
                decoration: BoxDecoration(color: AppTheme.primaryGreen.withOpacity(0.1), shape: BoxShape.circle),
                child: Center(child: Text('${e.key + 1}', style: GoogleFonts.outfit(fontSize: 11, fontWeight: FontWeight.w900, color: AppTheme.primaryGreen))),
              ),
              const SizedBox(width: 10),
              Expanded(child: Text('Bin #${e.value['smart_bin_id']}', style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w700, color: AppTheme.deepSlate))),
              Text('${e.value['scans_count']} scans', style: GoogleFonts.outfit(fontSize: 12, fontWeight: FontWeight.w800, color: Colors.teal)),
              const SizedBox(width: 8),
              Text('${(e.value['points_earned'] as num?)?.toStringAsFixed(0) ?? 0} pts', style: GoogleFonts.outfit(fontSize: 11, color: Colors.amber.shade700)),
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
  const _SectionUtilisateurs({Key? key}) : super(key: key);
  @override State<_SectionUtilisateurs> createState() => _EtatUtilisateurs();
}

class _EtatUtilisateurs extends State<_SectionUtilisateurs> {
  String _period = 'last_30_days';
  bool _chargement = false;
  Map<String, dynamic> _stats = {};
  Timer? _timer;

  @override void initState() { super.initState(); _charger(); _timer = Timer.periodic(const Duration(seconds: 30), (_) => _charger()); }
  @override void dispose() { _timer?.cancel(); super.dispose(); }

  Future<void> _charger() async {
    if (!mounted) return;
    setState(() => _chargement = true);
    final r = await analyticsGet('/admin/analytics/users?period=$_period');
    if (!mounted) return;
    setState(() {
      _stats = (r as Map<String, dynamic>?) ?? {};
      _chargement = false;
    });
  }

  static const _libelles = {'user': 'Citoyen', 'educator': 'Éducateur', 'admin': 'Admin', 'collector': 'Collecteur', 'point_manager': 'Gestionnaire'};
  static const _couleurs = <String, Color>{'user': Colors.blue, 'educator': Colors.purple, 'admin': Colors.red, 'collector': Colors.orange, 'point_manager': Colors.teal};

  @override
  Widget build(BuildContext context) {
    final total    = (_stats['total'] as num?)?.toInt() ?? 0;
    final moy      = (_stats['average_global_score'] as num?)?.toDouble() ?? 0.0;
    final newPer   = (_stats['new_this_period'] as num?)?.toInt() ?? 0;
    final actifs   = (_stats['active_this_period'] as num?)?.toInt() ?? 0;
    final byRoleRaw= (_stats['by_role'] as Map<String, dynamic>?) ?? {};
    final top      = (_stats['top_scorers'] as List?)?.cast<Map>() ?? [];

    // Construire liste pour barres
    final rolesData = byRoleRaw.entries
        .where((e) => (e.value as num? ?? 0) > 0)
        .toList();
    final maxCount = rolesData.isEmpty ? 1.0 : rolesData.map((e) => (e.value as num).toDouble()).reduce(math.max);

    return SectionCard(
      titre: 'Utilisateurs & Communauté',
      icone: Icons.people_alt_rounded,
      couleur: Colors.blue,
      chargement: _chargement,
      onActualiser: _charger,
      filtres: [
        FiltrePeriodeString(valeur: _period, couleur: Colors.blue, onChangement: (v) { setState(() => _period = v); _charger(); }),
      ],
      contenu: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        // 4 KPI (2x2)
        LayoutBuilder(builder: (_, c) {
          final w = (c.maxWidth - 12) / 2;
          return Column(children: [
            Row(children: [
              SizedBox(width: w, child: IndicateurPrincipal(valeur: '$total', etiquette: 'Total inscrits', sousTitre: 'Comptes actifs', icone: Icons.person_rounded, couleur: Colors.blue)),
              const SizedBox(width: 12),
              SizedBox(width: w, child: IndicateurPrincipal(valeur: '$newPer', etiquette: 'Nouveaux', sousTitre: 'Cette période', icone: Icons.person_add_rounded, couleur: Colors.indigo)),
            ]),
            const SizedBox(height: 12),
            Row(children: [
              SizedBox(width: w, child: IndicateurPrincipal(valeur: '$actifs', etiquette: 'Actifs', sousTitre: 'Ont scanné', icone: Icons.trending_up_rounded, couleur: Colors.green)),
              const SizedBox(width: 12),
              SizedBox(width: w, child: IndicateurPrincipal(valeur: moy.toStringAsFixed(1), etiquette: 'Score moy.', sousTitre: 'Moyenne globale', icone: Icons.stars_rounded, couleur: Colors.amber)),
            ]),
          ]);
        }),
        // Répartition par rôle
        if (rolesData.isNotEmpty) ...[
          const SizedBox(height: 20),
          Text('Répartition par rôle', style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w800, color: AppTheme.textMuted)),
          const SizedBox(height: 10),
          ...rolesData.map((e) => BarreProgression(
            etiquette: _libelles[e.key] ?? e.key,
            valeurTexte: '${e.value} utilisateurs',
            valeur: (e.value as num).toDouble(),
            max: maxCount,
            couleur: _couleurs[e.key] ?? Colors.grey,
          )),
        ],
        // Top scoreurs
        if (top.isNotEmpty) ...[
          const SizedBox(height: 20),
          Text('Meilleurs citoyens', style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w800, color: AppTheme.textMuted)),
          const SizedBox(height: 10),
          ...top.take(3).toList().asMap().entries.map((e) => Padding(
            padding: const EdgeInsets.symmetric(vertical: 5),
            child: Row(children: [
              Container(
                width: 28, height: 28,
                decoration: BoxDecoration(
                  color: [Colors.amber, Colors.grey.shade400, Colors.brown.shade300][e.key].withOpacity(0.15),
                  shape: BoxShape.circle),
                child: Center(child: Text('${e.key + 1}', style: GoogleFonts.outfit(fontSize: 12, fontWeight: FontWeight.w900, color: AppTheme.deepSlate))),
              ),
              const SizedBox(width: 10),
              Expanded(child: Text('${e.value['name']}', style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w700, color: AppTheme.deepSlate))),
              BadgeStatut(label: '${e.value['role'] ?? 'user'}', couleur: _couleurs[e.value['role']] ?? Colors.grey),
              const SizedBox(width: 8),
              Text('${e.value['score']} pts', style: GoogleFonts.outfit(fontSize: 14, fontWeight: FontWeight.w900, color: Colors.amber.shade700)),
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
  const _SectionEducation({Key? key}) : super(key: key);
  @override State<_SectionEducation> createState() => _EtatEducation();
}

class _EtatEducation extends State<_SectionEducation> {
  String _period = 'last_30_days';
  bool _chargement = false;
  Map<String, dynamic> _stats = {};
  Timer? _timer;

  @override void initState() { super.initState(); _charger(); _timer = Timer.periodic(const Duration(seconds: 30), (_) => _charger()); }
  @override void dispose() { _timer?.cancel(); super.dispose(); }

  Future<void> _charger() async {
    if (!mounted) return;
    setState(() => _chargement = true);
    final r = await analyticsGet('/admin/analytics/education?period=$_period');
    if (!mounted) return;
    setState(() {
      _stats = (r as Map<String, dynamic>?) ?? {};
      _chargement = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final totalQuiz = (_stats['total_quizzes'] as num?)?.toInt() ?? 0;
    final totalSub  = (_stats['total_submissions'] as num?)?.toInt() ?? 0;
    final avgScore  = (_stats['average_quiz_score'] as num?)?.toDouble() ?? 0.0;
    final successRt = (_stats['success_rate'] as num?)?.toDouble() ?? 0.0;
    final topQuiz   = (_stats['most_attempted'] as List?)?.cast<Map>() ?? [];

    return SectionCard(
      titre: 'Formation & Quiz',
      icone: Icons.school_rounded,
      couleur: Colors.teal,
      chargement: _chargement,
      onActualiser: _charger,
      filtres: [
        FiltrePeriodeString(valeur: _period, couleur: Colors.teal, onChangement: (v) { setState(() => _period = v); _charger(); }),
      ],
      contenu: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        // 4 KPI (2x2)
        LayoutBuilder(builder: (_, c) {
          final w = (c.maxWidth - 12) / 2;
          return Column(children: [
            Row(children: [
              SizedBox(width: w, child: IndicateurPrincipal(valeur: '$totalQuiz', etiquette: 'Quiz créés', sousTitre: 'Total plateforme', icone: Icons.quiz_rounded, couleur: Colors.teal)),
              const SizedBox(width: 12),
              SizedBox(width: w, child: IndicateurPrincipal(valeur: '$totalSub', etiquette: 'Soumissions', sousTitre: 'Cette période', icone: Icons.assignment_turned_in_rounded, couleur: Colors.indigo)),
            ]),
            const SizedBox(height: 12),
            Row(children: [
              SizedBox(width: w, child: IndicateurPrincipal(valeur: '${avgScore.toStringAsFixed(1)}/10', etiquette: 'Score moyen', sousTitre: 'Moyenne globale', icone: Icons.analytics_rounded, couleur: Colors.orange)),
              const SizedBox(width: 12),
              SizedBox(width: w, child: IndicateurPrincipal(valeur: '${successRt.toStringAsFixed(0)}%', etiquette: 'Réussite', sousTitre: 'Score ≥ 5/10', icone: Icons.emoji_events_rounded, couleur: successRt >= 60 ? Colors.green : Colors.orange, alerte: successRt < 40)),
            ]),
          ]);
        }),
        // Barre réussite
        const SizedBox(height: 16),
        Text('Taux de réussite global', style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w800, color: AppTheme.textMuted)),
        const SizedBox(height: 8),
        ClipRRect(
          borderRadius: BorderRadius.circular(8),
          child: LinearProgressIndicator(
            value: successRt / 100,
            minHeight: 12,
            backgroundColor: Colors.grey.shade100,
            valueColor: AlwaysStoppedAnimation(successRt >= 60 ? Colors.green : Colors.orange),
          ),
        ),
        const SizedBox(height: 4),
        Text('${successRt.toStringAsFixed(1)}% des participants réussissent (seuil : 5/10)',
          style: GoogleFonts.inter(fontSize: 10, color: AppTheme.textMuted)),
        // Top quiz
        if (topQuiz.isNotEmpty) ...[
          const SizedBox(height: 20),
          Text('Quiz les plus tentés', style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w800, color: AppTheme.textMuted)),
          const SizedBox(height: 10),
          ...topQuiz.take(5).toList().asMap().entries.map((e) => Padding(
            padding: const EdgeInsets.symmetric(vertical: 5),
            child: Row(children: [
              Container(
                width: 26, height: 26,
                decoration: BoxDecoration(color: Colors.teal.withOpacity(0.1), borderRadius: BorderRadius.circular(6)),
                child: Center(child: Text('${e.key + 1}', style: GoogleFonts.outfit(fontSize: 11, fontWeight: FontWeight.w900, color: Colors.teal))),
              ),
              const SizedBox(width: 10),
              Expanded(child: Text('${e.value['title'] ?? '—'}', style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w600, color: AppTheme.deepSlate), overflow: TextOverflow.ellipsis)),
              Text('${e.value['submissions']} tentatives', style: GoogleFonts.outfit(fontSize: 11, fontWeight: FontWeight.w800, color: Colors.teal)),
              if (e.value['avg_score'] != null) ...[
                const SizedBox(width: 8),
                BadgeStatut(label: '${(e.value['avg_score'] as num).toStringAsFixed(1)}/10', couleur: Colors.orange),
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
  const _SectionModeration({Key? key}) : super(key: key);
  @override State<_SectionModeration> createState() => _EtatModeration();
}

class _EtatModeration extends State<_SectionModeration> {
  bool _chargement = false;
  Map<String, dynamic> _stats = {};
  Timer? _timer;

  @override void initState() { super.initState(); _charger(); _timer = Timer.periodic(const Duration(seconds: 30), (_) => _charger()); }
  @override void dispose() { _timer?.cancel(); super.dispose(); }

  Future<void> _charger() async {
    if (!mounted) return;
    setState(() => _chargement = true);
    final r = await analyticsGet('/admin/analytics/community');
    if (!mounted) return;
    setState(() {
      _stats = (r as Map<String, dynamic>?) ?? {};
      _chargement = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final pendAI   = (_stats['pending_ai'] as num?)?.toInt() ?? 0;
    final pendRev  = (_stats['pending_review'] as num?)?.toInt() ?? 0;
    final published= (_stats['published'] as num?)?.toInt() ?? 0;
    final rejected = (_stats['rejected'] as num?)?.toInt() ?? 0;
    final totalPosts = (_stats['total_posts'] as num?)?.toInt() ?? 0;
    final pendTest = (_stats['pending_testimonials'] as num?)?.toInt() ?? 0;
    final pendProp = (_stats['pending_center_proposals'] as num?)?.toInt() ?? 0;
    final autoRate = (_stats['auto_approve_rate'] as num?)?.toDouble() ?? 0.0;
    final health   = (_stats['worker_health'] as String?) ?? 'ok';

    final totalPending = pendAI + pendRev;
    final workerColor = health == 'ok' ? Colors.green : health == 'warning' ? Colors.orange : Colors.red;

    return SectionCard(
      titre: 'Publications & Modération',
      icone: Icons.library_books_rounded,
      couleur: Colors.purple,
      chargement: _chargement,
      onActualiser: _charger,
      filtres: const [],
      contenu: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        // KPI 4 cartes (2x2)
        LayoutBuilder(builder: (_, c) {
          final w = (c.maxWidth - 12) / 2;
          return Column(children: [
            Row(children: [
              SizedBox(width: w, child: IndicateurPrincipal(valeur: '$totalPosts', etiquette: 'Total posts', sousTitre: 'Toutes plateformes', icone: Icons.article_rounded, couleur: Colors.purple)),
              const SizedBox(width: 12),
              SizedBox(width: w, child: IndicateurPrincipal(valeur: '$published', etiquette: 'Approuvés', sousTitre: '${totalPosts > 0 ? (published / totalPosts * 100).toStringAsFixed(0) : 0}% du total', icone: Icons.check_circle_rounded, couleur: Colors.green)),
            ]),
            const SizedBox(height: 12),
            Row(children: [
              SizedBox(width: w, child: IndicateurPrincipal(valeur: '$totalPending', etiquette: 'En attente', sousTitre: '$pendAI IA · $pendRev review', icone: Icons.pending_actions_rounded, couleur: totalPending > 0 ? Colors.orange : Colors.green, alerte: totalPending > 0)),
              const SizedBox(width: 12),
              SizedBox(width: w, child: IndicateurPrincipal(valeur: '$rejected', etiquette: 'Rejetés', sousTitre: 'Par IA ou admin', icone: Icons.cancel_rounded, couleur: Colors.red)),
            ]),
          ]);
        }),
        // Anneau répartition
        if (totalPosts > 0) ...[
          const SizedBox(height: 20),
          Text('Répartition des publications', style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w800, color: AppTheme.textMuted)),
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
        // Autres contenus en attente
        const SizedBox(height: 20),
        Text('Contenus en attente de validation', style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w800, color: AppTheme.textMuted)),
        const SizedBox(height: 10),
        _ligneInfo(Icons.star_rounded, 'Témoignages en attente', '$pendTest', pendTest > 0 ? Colors.orange : Colors.green),
        const SizedBox(height: 8),
        _ligneInfo(Icons.add_location_rounded, 'Propositions de centres', '$pendProp', pendProp > 0 ? Colors.orange : Colors.green),
        const SizedBox(height: 8),
        _ligneInfo(Icons.auto_awesome_rounded, 'Taux d\'auto-approbation IA', '${autoRate.toStringAsFixed(1)}%', Colors.blue),
        const SizedBox(height: 8),
        _ligneInfo(Icons.smart_toy_rounded, 'Worker IA', health.toUpperCase(), workerColor),
      ]),
    );
  }

  Widget _ligneInfo(IconData icon, String label, String valeur, Color couleur) => Row(children: [
    Container(padding: const EdgeInsets.all(7), decoration: BoxDecoration(color: couleur.withOpacity(0.1), borderRadius: BorderRadius.circular(8)),
      child: Icon(icon, size: 14, color: couleur)),
    const SizedBox(width: 10),
    Expanded(child: Text(label, style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w600, color: AppTheme.deepSlate))),
    BadgeStatut(label: valeur, couleur: couleur),
  ]);
}

// ═══════════════════════════════════════════════════════════════════
// SECTION 6 — CENTRES DE TRI (GET /admin/analytics/centers/*)
// ═══════════════════════════════════════════════════════════════════

class _SectionCentres extends StatefulWidget {
  const _SectionCentres({Key? key}) : super(key: key);
  @override State<_SectionCentres> createState() => _EtatCentres();
}

class _EtatCentres extends State<_SectionCentres> {
  String _ville = 'Toutes';
  bool _chargement = false;
  List<Map> _parVille = [];
  List<Map> _parStatut = [];
  Timer? _timer;

  static const _villes = ['Toutes', 'Tunis', 'Nabeul', 'Sousse', 'Sfax', 'Bizerte', 'Hammamet', 'Monastir', 'Ariana', 'Ben Arous'];

  @override void initState() { super.initState(); _charger(); _timer = Timer.periodic(const Duration(seconds: 30), (_) => _charger()); }
  @override void dispose() { _timer?.cancel(); super.dispose(); }

  Future<void> _charger() async {
    if (!mounted) return;
    setState(() => _chargement = true);
    final ville = _ville == 'Toutes' ? '' : _ville;
    final r = await Future.wait([
      analyticsGet('/admin/analytics/centers/by-city'),
      analyticsGet('/admin/analytics/centers/by-status?city=$ville'),
    ]);
    if (!mounted) return;
    final toutesVilles = (r[0] as List?)?.cast<Map>() ?? [];
    setState(() {
      _parVille  = _ville == 'Toutes' ? toutesVilles : toutesVilles.where((c) => c['city'] == _ville).toList();
      _parStatut = (r[1] as List?)?.cast<Map>() ?? [];
      _chargement = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    int statCount(String label) =>
        (_parStatut.firstWhere((r) => (r['status'] as String?) == label, orElse: () => {'count': 0})['count'] as num?)?.toInt() ?? 0;
    final dispo  = statCount('Disponible');
    final sat    = statCount('Saturé');
    final maint  = statCount('Maintenance');
    final total  = dispo + sat + maint;
    final maxT   = _parVille.isEmpty ? 1.0 : _parVille.map((c) => (c['total'] as num).toDouble()).reduce(math.max);

    return SectionCard(
      titre: 'Centres de Tri & Collecte',
      icone: Icons.location_on_rounded,
      couleur: const Color(0xFFF59E0B),
      chargement: _chargement,
      onActualiser: _charger,
      filtres: [
        FiltreDeroulant(etiquette: 'Ville', valeur: _ville, options: _villes, couleur: const Color(0xFFF59E0B),
          onChangement: (v) { setState(() => _ville = v); _charger(); }),
      ],
      contenu: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        // 4 KPI (2x2)
        LayoutBuilder(builder: (_, c) {
          final w = (c.maxWidth - 12) / 2;
          return Column(children: [
            Row(children: [
              SizedBox(width: w, child: IndicateurPrincipal(valeur: '$total', etiquette: 'Total centres', sousTitre: _ville == 'Toutes' ? 'Toutes villes' : _ville, icone: Icons.location_on_rounded, couleur: const Color(0xFFF59E0B))),
              const SizedBox(width: 12),
              SizedBox(width: w, child: IndicateurPrincipal(valeur: '$dispo', etiquette: 'Disponible', sousTitre: total > 0 ? '${(dispo / total * 100).toStringAsFixed(0)}% opérationnels' : '—', icone: Icons.check_circle_outline_rounded, couleur: Colors.green)),
            ]),
            const SizedBox(height: 12),
            Row(children: [
              SizedBox(width: w, child: IndicateurPrincipal(valeur: '$sat', etiquette: 'Saturés', sousTitre: sat > 0 ? '⚠️ Intervention requise' : '✅ Aucun saturé', icone: Icons.warning_amber_rounded, couleur: sat > 0 ? Colors.red : Colors.green, alerte: sat > 0)),
              const SizedBox(width: 12),
              SizedBox(width: w, child: IndicateurPrincipal(valeur: '$maint', etiquette: 'Maintenance', sousTitre: maint > 0 ? '🔧 $maint hors service' : '✅ Aucun', icone: Icons.build_circle_outlined, couleur: maint > 0 ? Colors.orange : Colors.green, alerte: maint > 0)),
            ]),
          ]);
        }),
        // Barres par ville
        if (_parVille.isNotEmpty) ...[
          const SizedBox(height: 20),
          Text('Centres par ville', style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w800, color: AppTheme.textMuted)),
          const SizedBox(height: 10),
          ..._parVille.take(8).map((c) {
            final hasSat   = (c['saturated']   as int? ?? 0) > 0;
            final hasMaint = (c['maintenance'] as int? ?? 0) > 0;
            final barColor = hasSat ? Colors.red : hasMaint ? Colors.orange : const Color(0xFFF59E0B);
            final detail   = '${c['available']} dispo${hasSat ? ' · ${c['saturated']} sat' : ''}${hasMaint ? ' · ${c['maintenance']} maint' : ''}';
            return BarreProgression(
              etiquette: '${c['city']}',
              valeurTexte: '${c['total']} ($detail)',
              valeur: (c['total'] as num).toDouble(),
              max: maxT,
              couleur: barColor,
            );
          }),
        ],
        // Anneau statuts
        if (_parStatut.isNotEmpty && total > 0) ...[
          const SizedBox(height: 20),
          Text('État des centres', style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w800, color: AppTheme.textMuted)),
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
  const _SectionAnomalies({Key? key}) : super(key: key);
  @override State<_SectionAnomalies> createState() => _EtatAnomalies();
}

class _EtatAnomalies extends State<_SectionAnomalies> {
  bool _chargement = false;
  int _count = 0;
  List<Map> _anomalies = [];
  Timer? _timer;

  @override void initState() { super.initState(); _charger(); _timer = Timer.periodic(const Duration(seconds: 30), (_) => _charger()); }
  @override void dispose() { _timer?.cancel(); super.dispose(); }

  Future<void> _charger() async {
    if (!mounted) return;
    setState(() => _chargement = true);
    final r = await analyticsGet('/admin/analytics/anomalies');
    if (!mounted) return;
    setState(() {
      _count     = (r?['count'] as num?)?.toInt() ?? 0;
      _anomalies = (r?['anomalies'] as List?)?.cast<Map>() ?? [];
      _chargement = false;
    });
  }

  static Color _severityColor(String? s) {
    switch (s) { case 'high': return Colors.red; case 'medium': return Colors.orange; default: return Colors.blue; }
  }
  static IconData _anomalyIcon(String? type) {
    switch (type) {
      case 'SCAN_RATE_LIMIT':   return Icons.speed_rounded;
      case 'REPEATED_BIN_SCAN': return Icons.repeat_rounded;
      case 'FIREBASE_UNSYNCED': return Icons.sync_problem_rounded;
      default: return Icons.warning_amber_rounded;
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
      filtres: const [],
      contenu: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        // Compteur
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
                    style: GoogleFonts.outfit(fontSize: 14, fontWeight: FontWeight.w900, color: _count > 0 ? Colors.red.shade800 : Colors.green.shade800)),
                  Text(_count > 0 ? 'Actions recommandées ci-dessous' : 'Système normal',
                    style: GoogleFonts.inter(fontSize: 11, color: AppTheme.textMuted)),
                ]),
              ]),
            ),
          ),
        ]),
        if (_anomalies.isNotEmpty) ...[
          const SizedBox(height: 16),
          Text('Détail des anomalies', style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w800, color: AppTheme.textMuted)),
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
                Container(padding: const EdgeInsets.all(8), decoration: BoxDecoration(color: color.withOpacity(0.15), borderRadius: BorderRadius.circular(10)),
                  child: Icon(_anomalyIcon(type), color: color, size: 18)),
                const SizedBox(width: 12),
                Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Row(children: [
                    Expanded(child: Text(type.replaceAll('_', ' '), style: GoogleFonts.outfit(fontSize: 12, fontWeight: FontWeight.w900, color: color))),
                    BadgeStatut(label: severity.toUpperCase(), couleur: color),
                  ]),
                  const SizedBox(height: 4),
                  Text('${a['message']}', style: GoogleFonts.inter(fontSize: 11, color: AppTheme.deepSlate, height: 1.4)),
                  if (a['user_id'] != null) ...[
                    const SizedBox(height: 4),
                    Text('Utilisateur ID : ${a['user_id']}', style: GoogleFonts.inter(fontSize: 10, color: AppTheme.textMuted)),
                  ],
                ])),
              ]),
            );
          }),
        ] else if (!_chargement)
          Padding(
            padding: const EdgeInsets.only(top: 12),
            child: Center(child: Text('✅ Aucun comportement suspect détecté', style: GoogleFonts.inter(color: AppTheme.textMuted, fontSize: 12))),
          ),
      ]),
    );
  }
}
