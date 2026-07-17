import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import '../constants.dart';

/// Modèle d'un palier de niveau
class LevelInfo {
  final int rank;
  final String name;
  final String icon;
  final String color;
  final List<String> gradient;
  final double minPoints;
  final List<Map<String, dynamic>> advantages;
  final List<Map<String, dynamic>> exclusiveRewards;

  const LevelInfo({
    required this.rank,
    required this.name,
    required this.icon,
    required this.color,
    required this.gradient,
    required this.minPoints,
    required this.advantages,
    required this.exclusiveRewards,
  });

  factory LevelInfo.fromJson(Map<String, dynamic> j) => LevelInfo(
        rank: (j['rank'] as num).toInt(),
        name: j['name'] as String,
        icon: j['icon'] as String? ?? '🌱',
        color: j['color'] as String? ?? '#4CAF50',
        gradient: (j['gradient'] as List?)?.map((e) => e.toString()).toList() ?? [],
        minPoints: (j['min_points'] as num).toDouble(),
        advantages: (j['advantages'] as List?)
                ?.map((e) => Map<String, dynamic>.from(e as Map))
                .toList() ??
            [],
        exclusiveRewards: (j['exclusive_rewards'] as List?)
                ?.map((e) => Map<String, dynamic>.from(e as Map))
                .toList() ??
            [],
      );
}

/// Modèle de la réponse GET /users/me/level
class UserLevelData {
  final double score;
  final LevelInfo currentLevel;
  final LevelInfo? nextLevel;
  final double progressPercent;
  final double pointsToNext;
  final double scanMultiplier;
  final double quizMultiplier;
  final List<Map<String, dynamic>> advantages;
  final List<Map<String, dynamic>> unlockedRewards;
  final List<Map<String, dynamic>> newlyUnlocked;

  const UserLevelData({
    required this.score,
    required this.currentLevel,
    this.nextLevel,
    required this.progressPercent,
    required this.pointsToNext,
    required this.scanMultiplier,
    required this.quizMultiplier,
    required this.advantages,
    required this.unlockedRewards,
    required this.newlyUnlocked,
  });

  factory UserLevelData.fromJson(Map<String, dynamic> j) => UserLevelData(
        score: (j['score'] as num).toDouble(),
        currentLevel: LevelInfo.fromJson(j['current_level'] as Map<String, dynamic>),
        nextLevel: j['next_level'] != null
            ? LevelInfo.fromJson(j['next_level'] as Map<String, dynamic>)
            : null,
        progressPercent: (j['progress_percent'] as num).toDouble(),
        pointsToNext: (j['points_to_next'] as num).toDouble(),
        scanMultiplier: (j['scan_multiplier'] as num?)?.toDouble() ?? 1.0,
        quizMultiplier: (j['quiz_multiplier'] as num?)?.toDouble() ?? 1.0,
        advantages: (j['advantages'] as List?)
                ?.map((e) => Map<String, dynamic>.from(e as Map))
                .toList() ??
            [],
        unlockedRewards: (j['unlocked_rewards'] as List?)
                ?.map((e) => Map<String, dynamic>.from(e as Map))
                .toList() ??
            [],
        newlyUnlocked: (j['newly_unlocked'] as List?)
                ?.map((e) => Map<String, dynamic>.from(e as Map))
                .toList() ??
            [],
      );
}

/// Service pour les niveaux et récompenses
class LevelsService {
  static final String _base = ApiConstants.baseUrl;

  static final LevelsService _instance = LevelsService._internal();
  factory LevelsService() => _instance;
  LevelsService._internal();

  Future<String?> _getToken() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString('auth_token');
  }

  Map<String, String> _authHeaders(String token) => {
        'Authorization': 'Bearer $token',
        'Content-Type': 'application/json',
      };

  // ── GET /users/me/level ───────────────────────────────────────────────────

  /// Charge le niveau actuel de l'utilisateur connecté depuis le backend.
  /// Déclenche aussi le déblocage automatique des récompenses non encore acquises.
  Future<UserLevelData?> fetchMyLevel() async {
    try {
      final token = await _getToken();
      if (token == null) return null;

      final response = await http
          .get(
            Uri.parse('$_base/users/me/level'),
            headers: _authHeaders(token),
          )
          .timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        final data = json.decode(response.body) as Map<String, dynamic>;
        return UserLevelData.fromJson(data);
      }
    } catch (_) {}
    return null;
  }

  // ── GET /levels/all ──────────────────────────────────────────────────────

  /// Référentiel public de tous les paliers (pas de token requis).
  Future<List<LevelInfo>> fetchAllLevels() async {
    try {
      final response = await http
          .get(Uri.parse('$_base/levels/all'))
          .timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        final data = json.decode(response.body) as Map<String, dynamic>;
        final list = data['levels'] as List;
        return list
            .map((e) => LevelInfo.fromJson(e as Map<String, dynamic>))
            .toList();
      }
    } catch (_) {}
    return [];
  }

  // ── GET /users/me/rewards ────────────────────────────────────────────────

  /// Historique complet des récompenses débloquées de l'utilisateur.
  Future<List<Map<String, dynamic>>> fetchMyRewards() async {
    try {
      final token = await _getToken();
      if (token == null) return [];

      final response = await http
          .get(
            Uri.parse('$_base/users/me/rewards'),
            headers: _authHeaders(token),
          )
          .timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        final data = json.decode(response.body) as Map<String, dynamic>;
        return (data['rewards'] as List)
            .map((e) => Map<String, dynamic>.from(e as Map))
            .toList();
      }
    } catch (_) {}
    return [];
  }
}
