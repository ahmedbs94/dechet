/// lib/core/api/auth_interceptor.dart
///
/// Intercepteur d'authentification — utilitaires partagés.
///
/// Centralise la logique de token pour éviter la duplication entre services.
library auth_interceptor;

import 'api_client.dart';
import '../../models/user_model.dart';

/// Attache le token en mémoire (AuthState) dès qu'il est sauvegardé,
/// évitant un accès SharedPreferences à chaque requête.
///
/// Usage : appelé par AuthService après chaque login/refresh.
void syncTokenToMemory(String token) {
  AuthState.authToken = token;
}

/// Vide le token en mémoire lors du logout.
void clearTokenFromMemory() {
  AuthState.authToken = null;
}

/// Retourne les headers Bearer depuis la mémoire (sync, sans await).
/// Fallback : null si non connecté.
Map<String, String> bearerHeaders({bool withJson = true}) {
  return {
    if (withJson) 'Content-Type': 'application/json',
    if (AuthState.authToken != null)
      'Authorization': 'Bearer ${AuthState.authToken}',
  };
}

/// Vérifie si l'utilisateur est actuellement authentifié.
bool get isAuthenticated => AuthState.authToken != null;

/// ApiClient global — accessible depuis tous les services feature-based.
final api = ApiClient();
