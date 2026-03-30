import 'dart:async';
import 'dart:convert';
import 'dart:developer' as developer;
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:flutter_facebook_auth/flutter_facebook_auth.dart';
import '../constants.dart';

/// Service d'authentification
/// Gere la connexion, l'inscription et la gestion des utilisateurs
class AuthService {
  static final String baseUrl = ApiConstants.baseUrl;

  // Singleton pattern
  static final AuthService _instance = AuthService._internal();
  factory AuthService() => _instance;
  AuthService._internal();

  static const String _googleClientId = "686199052163-tvieiu6db5vlstcnnsr5tp7q0eh6oi99.apps.googleusercontent.com";

  final GoogleSignIn _googleSignIn = GoogleSignIn(
    // Sur le web, clientId est requis. Sur Android, serverClientId permet d'obtenir un idToken.
    clientId: kIsWeb ? _googleClientId : null,
    serverClientId: kIsWeb ? null : _googleClientId,
    scopes: ['email', 'profile', 'openid'],
  );

  // ===========================================
  // AUTHENTIFICATION
  // ===========================================

  /// Connexion avec email et mot de passe
  Future<Map<String, dynamic>> login(String email, String password) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/token'),
        headers: {'Content-Type': 'application/x-www-form-urlencoded'},
        body: {
          'username': email,
          'password': password,
        },
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        await _saveToken(data['access_token']);
        return {
          'success': true,
          'token': data['access_token'],
          'role': data['role'],
          'id': data['id'],
          'full_name': data['full_name'],
          'email': data['email'],
        };
      } else {
        final error = json.decode(response.body);
        return {'success': false, 'message': error['detail'] ?? 'Erreur de connexion'};
      }
    } catch (e) {
      return {'success': false, 'message': 'Erreur réseau : $e'};
    }
  }

  /// Inscription d'un nouvel utilisateur
  Future<Map<String, dynamic>> register(String email, String fullName, String password) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/register'),
        headers: {'Content-Type': 'application/json'},
        body: json.encode({
          'email': email,
          'full_name': fullName,
          'password': password,
          'role': 'user',
        }),
      );

      if (response.statusCode == 200) {
        return {'success': true, 'data': json.decode(response.body)};
      } else {
        final error = json.decode(response.body);
        return {'success': false, 'message': error['detail'] ?? 'Erreur d\'inscription'};
      }
    } catch (e) {
      return {'success': false, 'message': 'Erreur réseau : $e'};
    }
  }

  /// Envoie un code OTP par email ou SMS
  Future<Map<String, dynamic>> sendOTP(String identifier, {String method = 'email'}) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/otp/send'),
        headers: {'Content-Type': 'application/json'},
        body: json.encode({'identifier': identifier, 'method': method}),
      );
      if (response.statusCode == 200) {
        return json.decode(utf8.decode(response.bodyBytes));
      }
      final error = json.decode(response.body);
      return {'success': false, 'message': error['detail'] ?? 'Erreur d\'envoi OTP'};
    } catch (e) {
      return {'success': false, 'message': 'Erreur réseau : $e'};
    }
  }

  /// Vérifie un code OTP et retourne un token si succès
  Future<Map<String, dynamic>> verifyOTP(String identifier, String code) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/otp/verify'),
        headers: {'Content-Type': 'application/json'},
        body: json.encode({'identifier': identifier, 'code': code}),
      );
      if (response.statusCode == 200) {
        return json.decode(utf8.decode(response.bodyBytes));
      }
      final error = json.decode(response.body);
      return {'success': false, 'message': error['detail'] ?? 'Code invalide'};
    } catch (e) {
      return {'success': false, 'message': 'Erreur réseau : $e'};
    }
  }


  bool _isGoogleSignInInProgress = false;

  /// Connexion avec Google
  Future<Map<String, dynamic>> signInWithGoogle() async {
    if (_isGoogleSignInInProgress) return {'success': false, 'message': 'Opération déjà en cours'};
    _isGoogleSignInInProgress = true;
    try {
      final GoogleSignInAccount? googleUser = await _googleSignIn.signIn();
      if (googleUser == null) {
        return {'success': false, 'message': 'Connexion annulée'};
      }

      final GoogleSignInAuthentication googleAuth = await googleUser.authentication;
      final String? idToken = googleAuth.idToken;
      final String? accessToken = googleAuth.accessToken;
      final String? tokenToSend = idToken ?? accessToken;

      if (tokenToSend == null) {
        return {'success': false, 'message': 'Erreur Google Token'};
      }

      final response = await http.post(
        Uri.parse('$baseUrl/auth/google'),
        headers: {'Content-Type': 'application/json'},
        body: json.encode({'token': tokenToSend}),
      );

      if (response.statusCode == 200) {
        final data = json.decode(utf8.decode(response.bodyBytes));
        await _saveToken(data['access_token']);
        return {
          'success': true,
          'token': data['access_token'],
          'role': data['role'],
          'id': data['id'],
          'full_name': data['full_name'],
          'email': data['email'],
        };
      } else {
        final errorData = json.decode(utf8.decode(response.bodyBytes));
        return {'success': false, 'message': errorData['detail'] ?? 'Erreur Google Auth'};
      }
    } catch (e) {
      return {'success': false, 'message': 'Erreur Google Sign In : $e'};
    } finally {
      _isGoogleSignInInProgress = false;
    }
  }

  bool _isFacebookSignInInProgress = false;

  /// Connexion avec Facebook
  Future<Map<String, dynamic>> signInWithFacebook() async {
    if (_isFacebookSignInInProgress) {
      return {'success': false, 'message': 'Opération déjà en cours'};
    }
    _isFacebookSignInInProgress = true;
    try {
      developer.log('[FB-AUTH] Début connexion Facebook...', name: 'FacebookAuth');

      // Sur Android/iOS, déconnecter la session précédente
      // Sur web, on skip le logOut car il peut bloquer
      if (!kIsWeb) {
        try {
          await FacebookAuth.instance.logOut();
          developer.log('[FB-AUTH] Session précédente déconnectée', name: 'FacebookAuth');
        } catch (e) {
          developer.log('[FB-AUTH] logOut ignoré: $e', name: 'FacebookAuth');
        }
      }

      developer.log('[FB-AUTH] Ouverture dialog de connexion Facebook...', name: 'FacebookAuth');

      // Déclencher la boîte de dialogue de connexion Facebook avec timeout
      final LoginResult loginResult = await FacebookAuth.instance.login(
        permissions: ['email', 'public_profile'],
      ).timeout(
        const Duration(seconds: 60),
        onTimeout: () {
          developer.log('[FB-AUTH] Timeout - la connexion a pris trop de temps', name: 'FacebookAuth');
          return LoginResult(status: LoginStatus.failed, message: 'Timeout: la connexion Facebook a pris trop de temps');
        },
      );

      developer.log('[FB-AUTH] Status login: ${loginResult.status}', name: 'FacebookAuth');

      // Cas 1 : L'utilisateur a annulé
      if (loginResult.status == LoginStatus.cancelled) {
        developer.log('[FB-AUTH] Connexion annulée par l\'utilisateur', name: 'FacebookAuth');
        return {'success': false, 'message': 'Connexion annulée'};
      }

      // Cas 2 : Erreur retournée par le SDK Facebook
      if (loginResult.status == LoginStatus.failed) {
        final fbError = loginResult.message ?? 'Erreur inconnue';
        developer.log('[FB-AUTH] Erreur SDK Facebook: $fbError', name: 'FacebookAuth');
        return {
          'success': false,
          'message': 'Erreur Facebook SDK : $fbError',
          'is_fb_sdk_error': true,
        };
      }

      // Cas 3 : Succès - récupération du token
      if (loginResult.status != LoginStatus.success) {
        developer.log('[FB-AUTH] Statut inattendu: ${loginResult.status}', name: 'FacebookAuth');
        return {
          'success': false,
          'message': 'Statut Facebook inattendu : ${loginResult.status}',
        };
      }

      final AccessToken? accessToken = loginResult.accessToken;
      if (accessToken == null) {
        developer.log('[FB-AUTH] accessToken est null!', name: 'FacebookAuth');
        return {'success': false, 'message': 'Token Facebook introuvable'};
      }

      developer.log('[FB-AUTH] Token Facebook obtenu. Envoi au backend...', name: 'FacebookAuth');
      developer.log('[FB-AUTH] URL backend: $baseUrl/auth/facebook', name: 'FacebookAuth');

      // Essayer l'URL principale (émulateur ou localhost)
      http.Response? response;
      String? networkError;

      try {
        response = await http
            .post(
              Uri.parse('$baseUrl/auth/facebook'),
              headers: {'Content-Type': 'application/json'},
              body: json.encode({'access_token': accessToken.tokenString}),
            )
            .timeout(const Duration(seconds: 15));
        developer.log('[FB-AUTH] Réponse backend: ${response.statusCode}', name: 'FacebookAuth');
      } catch (e) {
        networkError = e.toString();
        developer.log('[FB-AUTH] Échec URL principale ($baseUrl): $networkError', name: 'FacebookAuth');

        // Fallback: essayer l'IP de l'appareil physique
        final fallbackUrl = ApiConstants.physicalDeviceUrl;
        developer.log('[FB-AUTH] Tentative fallback: $fallbackUrl/auth/facebook', name: 'FacebookAuth');
        try {
          response = await http
              .post(
                Uri.parse('$fallbackUrl/auth/facebook'),
                headers: {'Content-Type': 'application/json'},
                body: json.encode({'access_token': accessToken.tokenString}),
              )
              .timeout(const Duration(seconds: 15));
          developer.log('[FB-AUTH] Fallback réussi! Réponse: ${response.statusCode}', name: 'FacebookAuth');
        } catch (e2) {
          developer.log('[FB-AUTH] Fallback échoué aussi: $e2', name: 'FacebookAuth');
          return {
            'success': false,
            'message': 'Serveur inaccessible. Vérifiez que le backend est démarré.',
            'is_network_error': true,
          };
        }
      }

      if (response.statusCode == 200) {
        final data = json.decode(utf8.decode(response.bodyBytes));
        await _saveToken(data['access_token']);
        developer.log('[FB-AUTH] ✅ Connexion Facebook réussie pour ${data["email"]}', name: 'FacebookAuth');
        return {
          'success': true,
          'token': data['access_token'],
          'role': data['role'],
          'id': data['id'],
          'full_name': data['full_name'],
          'email': data['email'],
        };
      } else {
        final errorData = json.decode(utf8.decode(response.bodyBytes));
        final detail = errorData['detail'] ?? 'Erreur du serveur Facebook Auth';
        developer.log('[FB-AUTH] ❌ Erreur backend (${response.statusCode}): $detail', name: 'FacebookAuth');
        return {
          'success': false,
          'message': detail,
          'is_backend_error': true,
          'status_code': response.statusCode,
        };
      }
    } on Exception catch (e) {
      final errStr = e.toString();
      developer.log('[FB-AUTH] Exception inattendue: $errStr', name: 'FacebookAuth');
      return {
        'success': false,
        'message': 'Erreur réseau Facebook : $errStr',
        'is_network_error': true,
      };
    } finally {
      _isFacebookSignInInProgress = false;
    }
  }

  // ===========================================
  // MOT DE PASSE
  // ===========================================

  /// Demande de reinitialisation du mot de passe
  Future<Map<String, dynamic>> forgotPassword(String email) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/forgot-password'),
        headers: {'Content-Type': 'application/json'},
        body: json.encode({'email': email}),
      );
      final data = json.decode(utf8.decode(response.bodyBytes));
      return {
        'success': response.statusCode == 200,
        'message': data['message'] ?? data['detail'] ?? 'Succès',
      };
    } catch (e) {
      return {'success': false, 'message': 'Erreur réseau : $e'};
    }
  }

  /// Reinitialisation du mot de passe avec le token
  Future<Map<String, dynamic>> resetPassword(String token, String newPassword) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/reset-password'),
        headers: {'Content-Type': 'application/json'},
        body: json.encode({
          'token': token,
          'new_password': newPassword,
        }),
      );
      final data = json.decode(utf8.decode(response.bodyBytes));
      return {
        'success': response.statusCode == 200,
        'message': data['message'] ?? data['detail'] ?? 'Succès',
      };
    } catch (e) {
      return {'success': false, 'message': 'Erreur réseau : $e'};
    }
  }

  /// Change le mot de passe de l'utilisateur connecte
  Future<Map<String, dynamic>> changePassword(String oldPassword, String newPassword) async {
    try {
      final token = await _getToken();
      final response = await http.post(
        Uri.parse('$baseUrl/users/me/change-password'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
        body: json.encode({
          'old_password': oldPassword,
          'new_password': newPassword,
        }),
      );
      final data = json.decode(utf8.decode(response.bodyBytes));
      return {
        'success': response.statusCode == 200,
        'message': data['message'] ?? data['detail'] ?? 'Erreur lors du changement de mot de passe',
      };
    } catch (e) {
      return {'success': false, 'message': 'Erreur réseau : $e'};
    }
  }

  // ===========================================
  // STOCKAGE DU TOKEN
  // ===========================================

  /// Sauvegarde le token JWT
  Future<void> _saveToken(String token) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('jwt_token', token);
  }

  /// Public alias for saving token (used by OTP verification)
  Future<void> saveToken(String token) => _saveToken(token);

  /// Recupere le token stocke
  Future<String?> _getToken() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString('jwt_token');
  }

  /// Recupere les details de l'utilisateur actuel depuis le backend
  Future<Map<String, dynamic>> getCurrentUserDetails() async {
    try {
      final token = await _getToken();
      if (token == null) return {'success': false, 'message': 'Aucun token'};

      // Note: On pourrait ajouter un endpoint /users/me au backend
      // Pour l'instant on va lister tous les utilisateurs et filtrer (ou on peut modifier le backend)
      // Mais attendons, le backend a déjà un système de token qui contient le sub (email)

      final response = await http.get(
        Uri.parse('$baseUrl/users/me'), // On va supposer qu'on a un endpoint /users/me ou l'ajouter
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
      );

      if (response.statusCode == 200) {
        final data = json.decode(utf8.decode(response.bodyBytes));
        return {
          'success': true,
          'user': data,
        };
      } else {
        // Si le token est invalide/expiré, on le supprime
        final prefs = await SharedPreferences.getInstance();
        await prefs.remove('jwt_token');
        return {'success': false, 'message': 'Session expirée'};
      }
    } catch (e) {
      return {'success': false, 'message': 'Erreur réseau : $e'};
    }
  }

  // ===========================================
  // SYNCHRONISATION DES PUBLICATIONS
  // ===========================================

  /// Recupere toutes les publications (avec etat liked/saved si connecte)
  Future<List<dynamic>> fetchAllPosts() async {
    try {
      final token = await _getToken();
      final headers = <String, String>{'Content-Type': 'application/json'};
      
      // Use /posts/feed when authenticated (returns is_liked/is_saved)
      String endpoint = '$baseUrl/posts';
      if (token != null) {
        headers['Authorization'] = 'Bearer $token';
        endpoint = '$baseUrl/posts/feed';
      }
      
      final response = await http.get(Uri.parse(endpoint), headers: headers);
      if (response.statusCode == 200) {
        return json.decode(utf8.decode(response.bodyBytes));
      }
      // If /posts/feed fails (401), fallback to /posts
      if (token != null && response.statusCode == 401) {
        final fallback = await http.get(Uri.parse('$baseUrl/posts'));
        if (fallback.statusCode == 200) {
          return json.decode(utf8.decode(fallback.bodyBytes));
        }
      }
      return [];
    } catch (e) {
      return [];
    }
  }

  // ===========================================
  // NOTIFICATIONS
  // ===========================================

  /// Récupère les notifications de l'utilisateur
  Future<List<dynamic>> fetchNotifications() async {
    try {
      final token = await _getToken();
      if (token == null) return [];
      final response = await http.get(
        Uri.parse('$baseUrl/notifications'),
        headers: {'Authorization': 'Bearer $token'},
      );
      if (response.statusCode == 200) {
        return json.decode(utf8.decode(response.bodyBytes));
      }
      return [];
    } catch (e) {
      return [];
    }
  }

  /// Récupère le nombre de notifications non lues
  Future<int> fetchUnreadCount() async {
    try {
      final token = await _getToken();
      if (token == null) return 0;
      final response = await http.get(
        Uri.parse('$baseUrl/notifications/unread-count'),
        headers: {'Authorization': 'Bearer $token'},
      );
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        return data['count'] ?? 0;
      }
      return 0;
    } catch (e) {
      return 0;
    }
  }

  /// Marque une notification comme lue
  Future<bool> markNotificationRead(int notifId) async {
    try {
      final token = await _getToken();
      if (token == null) return false;
      final response = await http.put(
        Uri.parse('$baseUrl/notifications/$notifId/read'),
        headers: {'Authorization': 'Bearer $token'},
      );
      return response.statusCode == 200;
    } catch (e) {
      return false;
    }
  }

  /// Marque toutes les notifications comme lues
  Future<bool> markAllNotificationsRead() async {
    try {
      final token = await _getToken();
      if (token == null) return false;
      final response = await http.put(
        Uri.parse('$baseUrl/notifications/read-all'),
        headers: {'Authorization': 'Bearer $token'},
      );
      return response.statusCode == 200;
    } catch (e) {
      return false;
    }
  }

  /// Upload une image et retourne l'URL
  Future<String?> uploadImage(String filePath) async {
    try {
      final token = await _getToken();
      if (token == null) return null;
      final uri = Uri.parse('$baseUrl/upload');
      final request = http.MultipartRequest('POST', uri)
        ..headers['Authorization'] = 'Bearer $token'
        ..files.add(await http.MultipartFile.fromPath('file', filePath));
      final streamedResponse = await request.send();
      if (streamedResponse.statusCode == 200) {
        final respStr = await streamedResponse.stream.bytesToString();
        final data = json.decode(respStr);
        return data['url'] ?? data['image_url'];
      }
      return null;
    } catch (e) {
      return null;
    }
  }

  /// Cree une nouvelle publication
  Future<Map<String, dynamic>> createPost({
    required String userName,
    required String userAvatarUrl,
    required String imageUrl,
    required String description,
  }) async {
    try {
      final token = await _getToken();
      if (token == null) return {'success': false, 'message': 'Non authentifié'};

      final response = await http.post(
        Uri.parse('$baseUrl/posts'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
        body: json.encode({
          'user_name': userName,
          'user_avatar_url': userAvatarUrl,
          'image_url': imageUrl,
          'description': description,
        }),
      );

      if (response.statusCode == 200) {
        return {'success': true, 'data': json.decode(utf8.decode(response.bodyBytes))};
      }
      return {'success': false, 'message': 'Erreur backend creation post'};
    } catch (e) {
      return {'success': false, 'message': 'Erreur réseau : $e'};
    }
  }

  /// Met a jour une publication
  Future<bool> updatePost(String postId, String description) async {
    try {
      final token = await _getToken();
      final response = await http.put(
        Uri.parse('$baseUrl/posts/$postId'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
        body: json.encode({'description': description}),
      );
      return response.statusCode == 200;
    } catch (e) {
      return false;
    }
  }

  /// Supprime une publication
  Future<bool> deletePost(String postId) async {
    try {
      final token = await _getToken();
      final response = await http.delete(
        Uri.parse('$baseUrl/posts/$postId'),
        headers: {'Authorization': 'Bearer $token'},
      );
      return response.statusCode == 200;
    } catch (e) {
      return false;
    }
  }

  /// Bascule l'etat de like d'une publication
  Future<Map<String, dynamic>> toggleLikePost(String postId) async {
    try {
      final token = await _getToken();
      if (token == null) return {'success': false, 'message': 'Non authentifié'};

      final response = await http.post(
        Uri.parse('$baseUrl/posts/$postId/like'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
      );

      if (response.statusCode == 200) {
        final data = json.decode(utf8.decode(response.bodyBytes));
        data['success'] = true;
        return data;
      }
      return {'success': false};
    } catch (e) {
      return {'success': false};
    }
  }

  /// Bascule l'etat d'enregistrement d'une publication sur le serveur
  Future<Map<String, dynamic>> toggleSavePost(String postId) async {
    try {
      final token = await _getToken();
      if (token == null) return {'success': false, 'message': 'Non authentifié'};

      final response = await http.post(
        Uri.parse('$baseUrl/posts/$postId/save'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
      );

      if (response.statusCode == 200) {
        final data = json.decode(utf8.decode(response.bodyBytes));
        data['success'] = true;
        return data;
      }
      return {'success': false, 'message': 'Erreur de synchronisation'};
    } catch (e) {
      return {'success': false, 'message': 'Erreur réseau : $e'};
    }
  }

  /// Ajoute un commentaire a une publication
  Future<Map<String, dynamic>> addComment(String postId, String userName, String? userAvatarUrl, String content) async {
    try {
      final token = await _getToken();
      if (token == null) return {'success': false, 'message': 'Non authentifié'};

      final response = await http.post(
        Uri.parse('$baseUrl/posts/$postId/comments'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
        body: json.encode({
          'user_name': userName,
          'user_avatar_url': userAvatarUrl,
          'content': content,
        }),
      );

      if (response.statusCode == 200) {
        return {'success': true, 'data': json.decode(utf8.decode(response.bodyBytes))};
      }
      return {'success': false, 'message': 'Erreur serveur lors de l\'ajout du commentaire'};
    } catch (e) {
      return {'success': false, 'message': 'Erreur réseau : $e'};
    }
  }

  /// Modifie un commentaire
  Future<Map<String, dynamic>> updateComment(int commentId, String content) async {
    try {
      final token = await _getToken();
      if (token == null) return {'success': false, 'message': 'Non authentifié'};

      final response = await http.put(
        Uri.parse('$baseUrl/comments/$commentId'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
        body: json.encode({'content': content}),
      );

      if (response.statusCode == 200) {
        return {'success': true, 'data': json.decode(utf8.decode(response.bodyBytes))};
      }
      return {'success': false, 'message': 'Erreur lors de la modification du commentaire'};
    } catch (e) {
      return {'success': false, 'message': 'Erreur réseau : $e'};
    }
  }

  /// Supprime un commentaire
  Future<bool> deleteComment(int commentId) async {
    try {
      final token = await _getToken();
      if (token == null) return false;

      final response = await http.delete(
        Uri.parse('$baseUrl/comments/$commentId'),
        headers: {'Authorization': 'Bearer $token'},
      );
      return response.statusCode == 200;
    } catch (e) {
      return false;
    }
  }

  /// Recupere les publications enregistrees depuis le serveur
  Future<List<dynamic>?> fetchSavedPosts() async {
    try {
      final token = await _getToken();
      if (token == null) return null;

      final response = await http.get(
        Uri.parse('$baseUrl/users/me/saved-posts'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
      );

      if (response.statusCode == 200) {
        return json.decode(utf8.decode(response.bodyBytes));
      } else {
        return null;
      }
    } catch (e) {
      return null;
    }
  }

  // ===========================================
  // ADMINISTRATION DES UTILISATEURS
  // ===========================================

  /// Liste tous les utilisateurs
  Future<List<dynamic>> getAllUsers() async {
    try {
      final token = await _getToken();
      final response = await http.get(
        Uri.parse('$baseUrl/users'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
      );

      if (response.statusCode == 200) {
        return json.decode(utf8.decode(response.bodyBytes));
      } else {
        throw Exception('Erreur de chargement des utilisateurs');
      }
    } catch (e) {
      rethrow;
    }
  }

  /// Cree un nouvel utilisateur (Admin seulement)
  Future<Map<String, dynamic>> createUserAdmin({
    required String email,
    required String fullName,
    required String password,
    required String role,
  }) async {
    try {
      final token = await _getToken();
      final response = await http.post(
        Uri.parse('$baseUrl/admin/users'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
        body: json.encode({
          'email': email,
          'full_name': fullName,
          'password': password,
          'role': role,
        }),
      );

      if (response.statusCode == 200) {
        return {'success': true, 'data': json.decode(utf8.decode(response.bodyBytes))};
      } else {
        final error = json.decode(utf8.decode(response.bodyBytes));
        return {'success': false, 'message': error['detail'] ?? 'Erreur de création'};
      }
    } catch (e) {
      return {'success': false, 'message': 'Erreur réseau : $e'};
    }
  }

  /// Modifie un utilisateur (Admin seulement)
  Future<Map<String, dynamic>> updateUserAdmin({
    required int userId,
    String? fullName,
    String? role,
    String? password,
  }) async {
    try {
      final token = await _getToken();
      final Map<String, dynamic> data = {};
      if (fullName != null) data['full_name'] = fullName;
      if (role != null) data['role'] = role;
      if (password != null && password.isNotEmpty) data['password'] = password;

      final response = await http.put(
        Uri.parse('$baseUrl/admin/users/$userId'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
        body: json.encode(data),
      );

      if (response.statusCode == 200) {
        return {'success': true, 'data': json.decode(utf8.decode(response.bodyBytes))};
      } else {
        return {'success': false, 'message': 'Erreur de modification'};
      }
    } catch (e) {
      return {'success': false, 'message': 'Erreur réseau : $e'};
    }
  }

  /// Supprime un utilisateur
  Future<bool> deleteUserAdmin(int userId) async {
    try {
      final token = await _getToken();
      final response = await http.delete(
        Uri.parse('$baseUrl/admin/users/$userId'),
        headers: {
          'Authorization': 'Bearer $token',
        },
      );
      return response.statusCode == 200;
    } catch (e) {
      return false;
    }
  }

  /// Deconnexion complète (JWT + Google + Facebook)
  Future<void> logout() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('jwt_token');
    // Déconnexion Google
    try {
      await _googleSignIn.signOut();
    } catch (_) {}
    // Déconnexion Facebook
    try {
      await FacebookAuth.instance.logOut();
    } catch (_) {}
  }
}
