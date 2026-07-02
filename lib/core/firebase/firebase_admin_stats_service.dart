/// lib/core/firebase/firebase_admin_stats_service.dart
///
/// ╔══════════════════════════════════════════════════════════════════╗
/// ║  SERVICE FIREBASE RTDB — DASHBOARD ADMIN TEMPS RÉEL             ║
/// ║                                                                  ║
/// ║  Sources Firebase utilisées :                                    ║
/// ║    /admin_stats/         → KPIs agrégés (mise à jour par backend)║
/// ║    /leaderboard/         → Top citoyens par score                ║
/// ║    /poubelles/           → État temps réel de chaque poubelle    ║
/// ║    /utilisateurs/        → Profils utilisateurs                  ║
/// ║                                                                  ║
/// ║  LECTURE SEULE — Firebase Admin SDK écrit, Flutter lit.          ║
/// ╚══════════════════════════════════════════════════════════════════╝
library firebase_admin_stats_service;

import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_database/firebase_database.dart';

// ── Modèles de données ────────────────────────────────────────────────────────

/// Snapshot des statistiques globales admin depuis /admin_stats/
class AdminStatsSnapshot {
  final int totalUsers;
  final int activeUsersWeek;
  final int newUsersMonth;
  final double averageScore;
  final int totalScans;
  final int scansToday;
  final int scansWeek;
  final double pointsDistributed;
  final int pendingModeration;
  final int pendingTestimonials;
  final int pendingProposals;
  final int totalCenters;
  final int activeCenters;
  final int totalCollections;
  final int collectionsWeek;
  final DateTime? lastUpdated;

  const AdminStatsSnapshot({
    this.totalUsers = 0,
    this.activeUsersWeek = 0,
    this.newUsersMonth = 0,
    this.averageScore = 0.0,
    this.totalScans = 0,
    this.scansToday = 0,
    this.scansWeek = 0,
    this.pointsDistributed = 0.0,
    this.pendingModeration = 0,
    this.pendingTestimonials = 0,
    this.pendingProposals = 0,
    this.totalCenters = 0,
    this.activeCenters = 0,
    this.totalCollections = 0,
    this.collectionsWeek = 0,
    this.lastUpdated,
  });

  factory AdminStatsSnapshot.empty() => const AdminStatsSnapshot();

  factory AdminStatsSnapshot.fromMap(Map<dynamic, dynamic> map) {
    DateTime? lastUpdated;
    try {
      final raw = map['last_updated'];
      if (raw != null) lastUpdated = DateTime.parse(raw.toString()).toLocal();
    } catch (_) {}

    return AdminStatsSnapshot(
      totalUsers:          _int(map['total_users']),
      activeUsersWeek:     _int(map['active_users_week']),
      newUsersMonth:       _int(map['new_users_month']),
      averageScore:        _double(map['average_score']),
      totalScans:          _int(map['total_scans']),
      scansToday:          _int(map['scans_today']),
      scansWeek:           _int(map['scans_week']),
      pointsDistributed:   _double(map['points_distributed']),
      pendingModeration:   _int(map['pending_moderation']),
      pendingTestimonials: _int(map['pending_testimonials']),
      pendingProposals:    _int(map['pending_proposals']),
      totalCenters:        _int(map['total_centers']),
      activeCenters:       _int(map['active_centers']),
      totalCollections:    _int(map['total_collections']),
      collectionsWeek:     _int(map['collections_week']),
      lastUpdated:         lastUpdated,
    );
  }

  static int    _int(dynamic v)    => (v as num?)?.toInt()    ?? 0;
  static double _double(dynamic v) => (v as num?)?.toDouble() ?? 0.0;
}

/// Snapshot d'une entrée du leaderboard depuis /leaderboard/
class LeaderboardEntry {
  final String name;
  final double score;
  final String role;
  final int? userId;

  const LeaderboardEntry({
    required this.name,
    required this.score,
    this.role = 'user',
    this.userId,
  });

  factory LeaderboardEntry.fromMap(Map<dynamic, dynamic> map) {
    return LeaderboardEntry(
      name:   map['full_name']?.toString() ?? map['name']?.toString() ?? 'Anonyme',
      score:  (map['score'] as num?)?.toDouble() ?? 0.0,
      role:   map['role']?.toString() ?? 'user',
      userId: (map['id'] as num?)?.toInt(),
    );
  }
}

/// Snapshot d'une poubelle depuis /poubelles/{bin_id}/
class PoubelleSnapshot {
  final String binId;
  final double poids;
  final String etat;
  final DateTime? derniereMaj;

  const PoubelleSnapshot({
    required this.binId,
    this.poids = 0.0,
    this.etat = 'vide',
    this.derniereMaj,
  });

  factory PoubelleSnapshot.fromMap(String binId, Map<dynamic, dynamic> map) {
    DateTime? maj;
    try {
      final raw = map['derniere_mise_a_jour'];
      if (raw != null) maj = DateTime.parse(raw.toString()).toLocal();
    } catch (_) {}

    return PoubelleSnapshot(
      binId:       binId,
      poids:       (map['poids'] as num?)?.toDouble() ?? 0.0,
      etat:        map['etat']?.toString() ?? 'vide',
      derniereMaj: maj,
    );
  }

  /// Couleur associée à l'état
  bool get isPlein       => etat == 'plein';
  bool get isMiPlein     => etat == 'mi-plein';
  bool get isMaintenance => etat == 'en_maintenance';
  bool get isVide        => etat == 'vide';

  /// Taux de remplissage estimé (0.0 à 1.0)
  double get tauxEstime {
    switch (etat) {
      case 'plein':       return 1.0;
      case 'mi-plein':    return 0.55;
      case 'vide':        return 0.1;
      default:            return 0.0;
    }
  }
}

// ── Service principal ─────────────────────────────────────────────────────────

/// Service singleton pour écouter les données admin depuis Firebase RTDB.
///
/// Pré-requis : FirebaseAuth doit être authentifié (via custom token) avant
/// d'appeler ces méthodes. En mode dégradé (non authentifié), les streams
/// retournent des valeurs vides silencieusement.
///
/// Usage :
/// ```dart
/// StreamBuilder<AdminStatsSnapshot>(
///   stream: FirebaseAdminStatsService().watchAdminStats(),
///   builder: (context, snap) {
///     final stats = snap.data ?? AdminStatsSnapshot.empty();
///     ...
///   },
/// )
/// ```
class FirebaseAdminStatsService {
  static final FirebaseAdminStatsService _instance = FirebaseAdminStatsService._();
  factory FirebaseAdminStatsService() => _instance;
  FirebaseAdminStatsService._();

  final FirebaseDatabase _db = FirebaseDatabase.instance;

  bool get _isAuth => FirebaseAuth.instance.currentUser != null;

  // ── Streams ────────────────────────────────────────────────────────────────

  /// Stream temps réel des statistiques agrégées admin depuis /admin_stats/
  /// Mis à jour par le backend FastAPI à chaque scan QR.
  Stream<AdminStatsSnapshot> watchAdminStats() {
    if (!_isAuth) return Stream.value(AdminStatsSnapshot.empty());
    return _db.ref('admin_stats').onValue.map((event) {
      final data = event.snapshot.value;
      if (data == null) return AdminStatsSnapshot.empty();
      if (data is Map) return AdminStatsSnapshot.fromMap(data);
      return AdminStatsSnapshot.empty();
    }).handleError((_) => AdminStatsSnapshot.empty());
  }

  /// Stream temps réel du leaderboard depuis /leaderboard/
  Stream<List<LeaderboardEntry>> watchLeaderboard() {
    if (!_isAuth) return Stream.value([]);
    return _db.ref('leaderboard').onValue.map((event) {
      final data = event.snapshot.value;
      if (data == null) return <LeaderboardEntry>[];
      if (data is Map) {
        return data.entries
            .map((e) {
              if (e.value is Map) {
                return LeaderboardEntry.fromMap(e.value as Map);
              }
              return null;
            })
            .whereType<LeaderboardEntry>()
            .toList()
          ..sort((a, b) => b.score.compareTo(a.score));
      }
      if (data is List) {
        return data
            .whereType<Map>()
            .map((m) => LeaderboardEntry.fromMap(m))
            .toList()
          ..sort((a, b) => b.score.compareTo(a.score));
      }
      return <LeaderboardEntry>[];
    }).handleError((_) => <LeaderboardEntry>[]);
  }

  /// Stream temps réel de l'état de toutes les poubelles depuis /poubelles/
  Stream<List<PoubelleSnapshot>> watchPoubelles() {
    if (!_isAuth) return Stream.value([]);
    return _db.ref('poubelles').onValue.map((event) {
      final data = event.snapshot.value;
      if (data == null) return <PoubelleSnapshot>[];
      if (data is Map) {
        return data.entries
            .map((e) {
              if (e.value is Map) {
                return PoubelleSnapshot.fromMap(
                  e.key.toString(),
                  e.value as Map,
                );
              }
              return null;
            })
            .whereType<PoubelleSnapshot>()
            .toList()
          ..sort((a, b) => b.poids.compareTo(a.poids));
      }
      return <PoubelleSnapshot>[];
    }).handleError((_) => <PoubelleSnapshot>[]);
  }

  // ── Lectures ponctuelles ──────────────────────────────────────────────────

  /// Lecture unique des stats admin (sans stream continu).
  Future<AdminStatsSnapshot> getAdminStatsOnce() async {
    if (!_isAuth) return AdminStatsSnapshot.empty();
    try {
      final snap = await _db.ref('admin_stats').get();
      if (!snap.exists || snap.value == null) return AdminStatsSnapshot.empty();
      return AdminStatsSnapshot.fromMap(snap.value as Map<dynamic, dynamic>);
    } catch (_) {
      return AdminStatsSnapshot.empty();
    }
  }

  /// Lecture unique du leaderboard.
  Future<List<LeaderboardEntry>> getLeaderboardOnce() async {
    if (!_isAuth) return [];
    try {
      final snap = await _db.ref('leaderboard').get();
      if (!snap.exists || snap.value == null) return [];
      final data = snap.value;
      if (data is Map) {
        return data.entries
            .map((e) => e.value is Map
                ? LeaderboardEntry.fromMap(e.value as Map)
                : null)
            .whereType<LeaderboardEntry>()
            .toList()
          ..sort((a, b) => b.score.compareTo(a.score));
      }
      return [];
    } catch (_) {
      return [];
    }
  }
}
