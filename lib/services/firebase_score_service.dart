/// lib/services/firebase_score_service.dart
///
/// ╔══════════════════════════════════════════════════════════════════╗
/// ║  RÈGLE ARCHITECTURALE — LECTURE SEULE                           ║
/// ║                                                                  ║
/// ║  Ce service est STRICTEMENT en lecture.                          ║
/// ║  Flutter n'écrit JAMAIS dans Firebase Realtime Database.         ║
/// ║                                                                  ║
/// ║  Seul FastAPI (Admin SDK) peut écrire via :                      ║
/// ║    services/firebase_service.py → update_user_score()            ║
/// ║                                                                  ║
/// ║  Les règles Firebase (.write: false côté client) renforcent       ║
/// ║  cette contrainte au niveau infrastructure.                      ║
/// ╚══════════════════════════════════════════════════════════════════╝
///
/// Prérequis : FirebaseAuth.instance.signInWithCustomToken(firebaseToken)
/// doit avoir été appelé lors du login (dans auth_service.dart) avant
/// toute lecture. Sans cela, les Security Rules rejettent la requête.

import 'dart:async';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:eco_rewind/models/bin_model.dart';

class ScoreSnapshot {
  final double total;
  final double lastPoints;
  final String lastBinType;
  final String lastScan;
  final String lastBinId;

  const ScoreSnapshot({
    required this.total,
    required this.lastPoints,
    required this.lastBinType,
    required this.lastScan,
    required this.lastBinId,
  });

  factory ScoreSnapshot.fromMap(Map<dynamic, dynamic> map) {
    return ScoreSnapshot(
      total: (map['total'] as num?)?.toDouble() ?? 0.0,
      lastPoints: (map['last_points'] as num?)?.toDouble() ?? 0.0,
      lastBinType: map['last_bin_type']?.toString() ?? 'general',
      lastScan: map['last_scan']?.toString() ?? '',
      lastBinId: map['last_bin_id']?.toString() ?? 'unknown',
    );
  }

  factory ScoreSnapshot.empty() => const ScoreSnapshot(
    total: 0.0,
    lastPoints: 0.0,
    lastBinType: 'general',
    lastScan: '',
    lastBinId: 'unknown',
  );
}

class FirebaseScoreService {
  static final FirebaseScoreService _instance = FirebaseScoreService._();
  factory FirebaseScoreService() => _instance;
  FirebaseScoreService._();

  final FirebaseDatabase _db = FirebaseDatabase.instance;
  StreamSubscription? _subscription;

  /// Vérifie que l'utilisateur est bien authentifié dans Firebase.
  /// Sans cela, les Security Rules (.read: auth != null) bloquent la requête.
  bool get _isFirebaseAuthenticated =>
      FirebaseAuth.instance.currentUser != null;

  /// Écoute les mises à jour du score d'un citoyen en temps réel.
  ///
  /// LECTURE SEULE — ne pas appeler de méthode .set() / .update() / .remove()
  /// sur cette référence. Les Security Rules Firebase rejettent toute écriture
  /// côté client (.write: false sur tous les nœuds).
  ///
  /// Retourne un Stream<ScoreSnapshot> mis à jour par push Firebase.
  /// Retourne ScoreSnapshot.empty() si l'utilisateur n'est pas authentifié Firebase.
  Stream<ScoreSnapshot> watchScore(int userId) {
    if (!_isFirebaseAuthenticated) {
      // L'utilisateur n'est pas encore connecté à Firebase.
      // auth_service.dart doit appeler signInWithCustomToken() après le login.
      return Stream.value(ScoreSnapshot.empty());
    }
    final ref = _db.ref('scores/$userId');
    return ref.onValue.map((event) {
      final data = event.snapshot.value;
      if (data == null) return ScoreSnapshot.empty();
      if (data is Map) {
        return ScoreSnapshot.fromMap(data);
      }
      return ScoreSnapshot.empty();
    });
  }

  /// Lit le score une seule fois (sans abonnement continu).
  ///
  /// LECTURE SEULE — voir watchScore() pour les détails de sécurité.
  Future<ScoreSnapshot> getScoreOnce(int userId) async {
    if (!_isFirebaseAuthenticated) {
      return ScoreSnapshot.empty();
    }
    try {
      final ref = _db.ref('scores/$userId');
      final snapshot = await ref.get();
      if (!snapshot.exists || snapshot.value == null) return ScoreSnapshot.empty();
      return ScoreSnapshot.fromMap(snapshot.value as Map<dynamic, dynamic>);
    } catch (_) {
      return ScoreSnapshot.empty();
    }
  }

  void dispose() {
    _subscription?.cancel();
    _subscription = null;
  }
}


// ─────────────────────────────────────────────────────────────────────────────
// Lecture de /utilisateurs/{user_id}
// ─────────────────────────────────────────────────────────────────────────────

extension FirebaseUtilisateurReader on FirebaseScoreService {
  /// Lit le profil Firebase d'un utilisateur UNE seule fois.
  ///
  /// Nœud lu : /utilisateurs/{userId}
  /// Retourne UtilisateurSnapshot.empty() si non authentifié ou absent.
  Future<UtilisateurSnapshot> getUtilisateur(int userId) async {
    if (!_isFirebaseAuthenticated) return UtilisateurSnapshot.empty();
    try {
      final ref = _db.ref('utilisateurs/$userId');
      final snapshot = await ref.get();
      if (!snapshot.exists || snapshot.value == null) {
        return UtilisateurSnapshot.empty();
      }
      return UtilisateurSnapshot.fromMap(
          snapshot.value as Map<dynamic, dynamic>);
    } catch (_) {
      return UtilisateurSnapshot.empty();
    }
  }

  /// Écoute les changements du profil d'un utilisateur en temps réel.
  ///
  /// Nœud écouté : /utilisateurs/{userId}
  Stream<UtilisateurSnapshot> watchUtilisateur(int userId) {
    if (!_isFirebaseAuthenticated) {
      return Stream.value(UtilisateurSnapshot.empty());
    }
    final ref = _db.ref('utilisateurs/$userId');
    return ref.onValue.map((event) {
      final data = event.snapshot.value;
      if (data == null) return UtilisateurSnapshot.empty();
      if (data is Map) return UtilisateurSnapshot.fromMap(data);
      return UtilisateurSnapshot.empty();
    });
  }
}


// ─────────────────────────────────────────────────────────────────────────────
// Lecture de /poubelles/{bin_id}
// ─────────────────────────────────────────────────────────────────────────────

extension FirebaseBinReader on FirebaseScoreService {
  /// Écoute l'état d'une poubelle en temps réel.
  ///
  /// Nœud écouté : /poubelles/{binId}
  /// binId = bin_code de la poubelle (ex: "BIN-PLASTIC-A3F2")
  ///
  /// LECTURE SEULE — seul le backend FastAPI écrit dans ce nœud.
  Stream<BinSnapshot> watchBin(String binId) {
    if (!_isFirebaseAuthenticated) {
      return Stream.value(BinSnapshot.empty());
    }
    final ref = _db.ref('poubelles/$binId');
    return ref.onValue.map((event) {
      final data = event.snapshot.value;
      if (data == null) return BinSnapshot.empty();
      if (data is Map) return BinSnapshot.fromMap(data);
      return BinSnapshot.empty();
    });
  }

  /// Lit l'état d'une poubelle UNE seule fois (sans abonnement continu).
  ///
  /// Retourne BinSnapshot.empty() si la poubelle est absente ou non authentifié.
  Future<BinSnapshot> getBinOnce(String binId) async {
    if (!_isFirebaseAuthenticated) return BinSnapshot.empty();
    try {
      final ref = _db.ref('poubelles/$binId');
      final snapshot = await ref.get();
      if (!snapshot.exists || snapshot.value == null) return BinSnapshot.empty();
      return BinSnapshot.fromMap(snapshot.value as Map<dynamic, dynamic>);
    } catch (_) {
      return BinSnapshot.empty();
    }
  }
}
