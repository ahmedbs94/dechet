enum UserRole { user, admin, educator, intercommunality, pointManager, collector }

class User {
  final String id;
  final String name;
  final String email;
  final UserRole role;
  final int points;
  final String avatarUrl;

  User({
    required this.id,
    required this.name,
    required this.email,
    required this.role,
    this.points = 0,
    this.avatarUrl = '',
  });

  /// Crée un User depuis la réponse du backend
  factory User.fromBackend(Map<String, dynamic> data) {
    return User(
      id: (data['id'] ?? 0).toString(),
      name: data['full_name'] ?? 'Utilisateur',
      email: data['email'] ?? '',
      role: _parseRole(data['role'] ?? 'user'),
      points: data['points'] ?? 0,
      avatarUrl: data['avatar_url'] ?? '',
    );
  }

  static UserRole _parseRole(String role) {
    switch (role) {
      case 'admin':
        return UserRole.admin;
      case 'educator':
        return UserRole.educator;
      case 'intercommunality':
        return UserRole.intercommunality;
      case 'pointManager':
        return UserRole.pointManager;
      case 'collector':
        return UserRole.collector;
      default:
        return UserRole.user;
    }
  }

  String get roleDisplayName {
    switch (role) {
      case UserRole.admin:
        return 'Administrateur';
      case UserRole.educator:
        return 'Éducateur';
      case UserRole.intercommunality:
        return 'Intercommunalité';
      case UserRole.pointManager:
        return 'Gestionnaire';
      case UserRole.collector:
        return 'Collecteur';
      default:
        return 'Citoyen';
    }
  }
}

// État d'authentification global
class AuthState {
  static User? currentUser;

  /// Connexion depuis les données du backend (rôle automatique)
  static void loginFromBackend(Map<String, dynamic> data) {
    currentUser = User.fromBackend(data);
  }

  /// Déconnexion
  static void logout() {
    currentUser = null;
  }

  static bool get isLoggedIn => currentUser != null;
  static bool get isAdmin => currentUser?.role == UserRole.admin;
}
