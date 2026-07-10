// lib/services/messaging_service.dart
// Service Flutter pour la messagerie inter-rôles EcoRewind

import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import '../constants.dart';

class MessagingService {
  static final String _base = ApiConstants.baseUrl;

  // ── Helpers ────────────────────────────────────────────────────────────────

  static Future<Map<String, String>> _headers() async {
    final prefs = await SharedPreferences.getInstance();
    final jwt = prefs.getString('jwt_token') ?? '';
    return {
      'Content-Type': 'application/json',
      'Authorization': 'Bearer $jwt',
    };
  }

  static Map<String, dynamic> _decode(http.Response r) {
    return json.decode(utf8.decode(r.bodyBytes));
  }

  static List<dynamic> _decodeList(http.Response r) {
    return json.decode(utf8.decode(r.bodyBytes)) as List;
  }

  // ── Destinataires éligibles ────────────────────────────────────────────────

  /// Retourne la liste des utilisateurs à qui on peut écrire (filtrée par rôle)
  static Future<List<Map<String, dynamic>>> getEligibleRecipients() async {
    final h = await _headers();
    final r = await http.get(
      Uri.parse('$_base/messages/eligible-recipients'),
      headers: h,
    );
    if (r.statusCode == 200) {
      return _decodeList(r).cast<Map<String, dynamic>>();
    }
    return [];
  }

  // ── Groupes accessibles ───────────────────────────────────────────────────

  /// Groupes de citoyens (éducateur) ou vide pour les autres
  static Future<List<Map<String, dynamic>>> getAccessibleGroups() async {
    final h = await _headers();
    final r = await http.get(
      Uri.parse('$_base/messages/groups'),
      headers: h,
    );
    if (r.statusCode == 200) {
      return _decodeList(r).cast<Map<String, dynamic>>();
    }
    return [];
  }

  // ── Envoyer un message 1-à-1 ─────────────────────────────────────────────

  static Future<Map<String, dynamic>?> sendMessage({
    required int receiverId,
    required String content,
    int? parentId,
  }) async {
    final h = await _headers();
    final r = await http.post(
      Uri.parse('$_base/messages'),
      headers: h,
      body: json.encode({
        'receiver_id': receiverId,
        'content': content,
        if (parentId != null) 'parent_id': parentId,
      }),
    );
    if (r.statusCode == 201) return _decode(r);
    return null;
  }

  // ── Envoyer à un groupe de citoyens ──────────────────────────────────────

  static Future<Map<String, dynamic>?> sendGroupMessage({
    required int groupId,
    required String content,
    int? parentId,
  }) async {
    final h = await _headers();
    final r = await http.post(
      Uri.parse('$_base/messages/group'),
      headers: h,
      body: json.encode({
        'group_id': groupId,
        'content': content,
        if (parentId != null) 'parent_id': parentId,
      }),
    );
    if (r.statusCode == 201) return _decode(r);
    return null;
  }

  // ── Broadcast collecteurs ─────────────────────────────────────────────────

  static Future<Map<String, dynamic>?> broadcastToCollectors({
    required List<int> receiverIds,
    required String content,
    String? collectorGroupLabel,
    int? parentId,
  }) async {
    final h = await _headers();
    final r = await http.post(
      Uri.parse('$_base/messages/broadcast'),
      headers: h,
      body: json.encode({
        'receiver_ids': receiverIds,
        'content': content,
        if (collectorGroupLabel != null)
          'collector_group_label': collectorGroupLabel,
        if (parentId != null) 'parent_id': parentId,
      }),
    );
    if (r.statusCode == 201) return _decode(r);
    return null;
  }

  // ── Conversations ─────────────────────────────────────────────────────────

  static Future<List<Map<String, dynamic>>> getConversations() async {
    final h = await _headers();
    final r = await http.get(
      Uri.parse('$_base/messages/conversations'),
      headers: h,
    );
    if (r.statusCode == 200) {
      return _decodeList(r).cast<Map<String, dynamic>>();
    }
    return [];
  }

  // ── Messages d'une conversation 1-à-1 ────────────────────────────────────

  static Future<Map<String, dynamic>?> getConversation(
    int userId, {
    int skip = 0,
    int limit = 50,
  }) async {
    final h = await _headers();
    final r = await http.get(
      Uri.parse('$_base/messages/conversation/$userId?skip=$skip&limit=$limit'),
      headers: h,
    );
    if (r.statusCode == 200) return _decode(r);
    return null;
  }

  // ── Messages d'un groupe de citoyens ─────────────────────────────────────

  static Future<Map<String, dynamic>?> getGroupConversation(
    int groupId, {
    int skip = 0,
    int limit = 50,
  }) async {
    final h = await _headers();
    final r = await http.get(
      Uri.parse(
          '$_base/messages/group-conversation/$groupId?skip=$skip&limit=$limit'),
      headers: h,
    );
    if (r.statusCode == 200) return _decode(r);
    return null;
  }

  // ── Répondre ─────────────────────────────────────────────────────────────

  static Future<Map<String, dynamic>?> replyToMessage({
    required int messageId,
    required String content,
  }) async {
    final h = await _headers();
    final r = await http.post(
      Uri.parse('$_base/messages/$messageId/reply'),
      headers: h,
      body: json.encode({'content': content}),
    );
    if (r.statusCode == 201) return _decode(r);
    return null;
  }

  // ── Marquer comme lu ─────────────────────────────────────────────────────

  static Future<void> markAsRead(int messageId) async {
    final h = await _headers();
    await http.put(
      Uri.parse('$_base/messages/$messageId/read'),
      headers: h,
    );
  }

  /// Marque TOUS les messages d'une conversation comme lus en un seul appel.
  /// À appeler dès l'ouverture de la conversation pour déclencher les coches bleues.
  static Future<void> markConversationAsRead(int partnerId) async {
    final h = await _headers();
    await http.post(
      Uri.parse('$_base/messages/conversation/$partnerId/read-all'),
      headers: h,
    );
  }

  // ── Compteur non lus ─────────────────────────────────────────────────────

  static Future<int> getUnreadCount() async {
    final h = await _headers();
    final r = await http.get(
      Uri.parse('$_base/messages/unread-count'),
      headers: h,
    );
    if (r.statusCode == 200) {
      return _decode(r)['count'] as int? ?? 0;
    }
    return 0;
  }
}
