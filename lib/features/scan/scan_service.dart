/// lib/features/scan/scan_service.dart
///
/// Responsabilité unique : appels HTTP vers les endpoints /qr/* de FastAPI.
///
/// Ce service NE contient pas de logique métier — il traduit des appels
/// Dart en requêtes HTTP et retourne des données brutes ou typées.
/// La logique de validation (bin actif, anti double-scan) reste dans FastAPI.
library scan_service;

import 'dart:convert';
import 'package:http/http.dart' as http;
import '../../constants.dart';
import '../../models/user_model.dart';

/// Résultat d'un scan QR renvoyé par FastAPI.
class ScanResult {
  final bool success;
  final int? userId;
  final String? userName;
  final String? binCode;
  final String? binType;
  final int? collectionPointId;
  final double pointsEarned;
  final double scoreBefore;
  final double scoreAfter;
  final bool firebaseSynced;
  final String message;
  final String? error;

  const ScanResult({
    required this.success,
    this.userId,
    this.userName,
    this.binCode,
    this.binType,
    this.collectionPointId,
    this.pointsEarned = 0,
    this.scoreBefore = 0,
    this.scoreAfter = 0,
    this.firebaseSynced = false,
    required this.message,
    this.error,
  });

  factory ScanResult.fromMap(Map<String, dynamic> m) => ScanResult(
        success:            m['success'] as bool? ?? false,
        userId:             m['user_id'] as int?,
        userName:           m['user_name'] as String?,
        binCode:            m['bin_code'] as String?,
        binType:            m['bin_type'] as String?,
        collectionPointId:  m['collection_point_id'] as int?,
        pointsEarned:       (m['points_earned'] as num?)?.toDouble() ?? 0,
        scoreBefore:        (m['score_before'] as num?)?.toDouble() ?? 0,
        scoreAfter:         (m['score_after'] as num?)?.toDouble() ?? 0,
        firebaseSynced:     m['firebase_synced'] as bool? ?? false,
        message:            m['message'] as String? ?? '',
      );

  factory ScanResult.error(String msg) =>
      ScanResult(success: false, message: msg, error: msg);
}

class ScanService {
  // Singleton
  static final ScanService _instance = ScanService._();
  factory ScanService() => _instance;
  ScanService._();

  static String get _base => ApiConstants.baseUrl;

  Map<String, String> get _headers => {
        'Content-Type': 'application/json',
        if (AuthState.authToken != null)
          'Authorization': 'Bearer ${AuthState.authToken}',
      };

  // ── POST /qr/scan-bin ───────────────────────────────────────────────────────

  /// Scanne une poubelle intelligente.
  ///
  /// [binCode]  : code unique inscrit sur le QR de la poubelle (ex: "BIN-PLASTIQUE-001").
  /// [qrCode]   : QR code personnel du citoyen (stocké dans users.qr_code).
  /// [weightKg] : poids optionnel si la poubelle dispose d'un capteur.
  ///
  /// FastAPI valide :
  ///   1. bin_code existe dans smart_bins
  ///   2. smart_bins.status == "active"
  ///   3. qr_code correspond à un citoyen actif
  ///   4. Anti double-scan (60 s)
  Future<ScanResult> scanBin({
    required String binCode,
    required String qrCode,
    double? weightKg,
  }) async {
    try {
      final body = <String, dynamic>{
        'bin_code': binCode.trim(),
        'qr_code':  qrCode.trim(),
        if (weightKg != null) 'weight_kg': weightKg,
      };
      final response = await http
          .post(
            Uri.parse('$_base/qr/scan-bin'),
            headers: _headers,
            body: jsonEncode(body),
          )
          .timeout(const Duration(seconds: 15));

      final data = jsonDecode(utf8.decode(response.bodyBytes)) as Map<String, dynamic>;

      if (response.statusCode == 200) return ScanResult.fromMap(data);

      // Erreurs métier : 404 bin inconnu, 409 hors service, 429 double-scan
      final detail = data['detail'] as String? ?? 'Erreur ${response.statusCode}';
      return ScanResult.error(detail);
    } catch (e) {
      return ScanResult.error('Erreur réseau : $e');
    }
  }

  // ── GET /qr/scan-history ────────────────────────────────────────────────────

  /// Historique des scans du citoyen connecté.
  Future<Map<String, dynamic>> getScanHistory({int limit = 20}) async {
    try {
      final response = await http
          .get(
            Uri.parse('$_base/qr/scan-history?limit=$limit'),
            headers: _headers,
          )
          .timeout(const Duration(seconds: 10));
      if (response.statusCode == 200) {
        return Map<String, dynamic>.from(
            jsonDecode(utf8.decode(response.bodyBytes)) as Map);
      }
      return {'total_scans': 0, 'scans': []};
    } catch (_) {
      return {'total_scans': 0, 'scans': []};
    }
  }

  // ── GET /qr/leaderboard ─────────────────────────────────────────────────────

  /// Classement public des citoyens par score.
  Future<List<Map<String, dynamic>>> getLeaderboard({int limit = 10}) async {
    try {
      final response = await http
          .get(Uri.parse('$_base/qr/leaderboard?limit=$limit'))
          .timeout(const Duration(seconds: 10));
      if (response.statusCode == 200) {
        final data = jsonDecode(utf8.decode(response.bodyBytes)) as Map;
        final list = data['leaderboard'] as List? ?? [];
        return list.cast<Map<String, dynamic>>();
      }
      return [];
    } catch (_) {
      return [];
    }
  }
}
