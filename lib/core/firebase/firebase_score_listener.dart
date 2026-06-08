/// lib/core/firebase/firebase_score_listener.dart
///
/// ╔══════════════════════════════════════════════════════════════════╗
/// ║  RÈGLE ARCHITECTURALE — LECTURE SEULE                           ║
/// ║                                                                  ║
/// ║  Ce listener est STRICTEMENT en lecture.                         ║
/// ║  Flutter n'écrit JAMAIS dans Firebase Realtime Database.         ║
/// ║                                                                  ║
/// ║  Seul FastAPI (Admin SDK) peut écrire via :                      ║
/// ║    backend/services/firebase_service.py → update_user_score()   ║
/// ║                                                                  ║
/// ║  Les règles Firebase (.write: false côté client) renforcent      ║
/// ║  cette contrainte au niveau infrastructure.                      ║
/// ╚══════════════════════════════════════════════════════════════════╝
///
/// Remplace : lib/services/firebase_score_service.dart (conservé pour
/// compatibilité — il re-exporte ce fichier).
library firebase_score_listener;

import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_database/firebase_database.dart';
import '../../services/firebase_score_service.dart' show ScoreSnapshot;

/// Listener Firebase RTDB pour les scores citoyens en temps réel.
///
/// • Écoute /scores/{userId} en lecture seule.
/// • Authentification requise : AuthService doit avoir appelé
///   FirebaseAuth.instance.signInWithCustomToken() avant toute lecture.
/// • Retourne ScoreSnapshot.empty() si non authentifié (mode dégradé).
class FirebaseScoreListener {
  // Singleton
  static final FirebaseScoreListener _instance = FirebaseScoreListener._();
  factory FirebaseScoreListener() => _instance;
  FirebaseScoreListener._();

  final FirebaseDatabase _db = FirebaseDatabase.instance;

  bool get _isAuth => FirebaseAuth.instance.currentUser != null;

  /// Stream temps réel du score d'un citoyen.
  ///
  /// Exemple d'utilisation :
  /// ```dart
  /// StreamBuilder<ScoreSnapshot>(
  ///   stream: FirebaseScoreListener().watchScore(userId),
  ///   builder: (ctx, snap) { ... }
  /// )
  /// ```
  Stream<ScoreSnapshot> watchScore(int userId) {
    if (!_isAuth) return Stream.value(ScoreSnapshot.empty());
    return _db.ref('scores/$userId').onValue.map((event) {
      final data = event.snapshot.value;
      if (data == null) return ScoreSnapshot.empty();
      if (data is Map) return ScoreSnapshot.fromMap(data);
      return ScoreSnapshot.empty();
    });
  }

  /// Lecture unique (pas de stream continu).
  Future<ScoreSnapshot> getScoreOnce(int userId) async {
    if (!_isAuth) return ScoreSnapshot.empty();
    try {
      final snapshot = await _db.ref('scores/$userId').get();
      if (!snapshot.exists || snapshot.value == null) return ScoreSnapshot.empty();
      return ScoreSnapshot.fromMap(snapshot.value as Map<dynamic, dynamic>);
    } catch (_) {
      return ScoreSnapshot.empty();
    }
  }
}
