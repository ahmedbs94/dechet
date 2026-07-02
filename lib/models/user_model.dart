enum UserRole { user, admin, superadmin, educator, intercommunality, pointManager, collector }

class User {
  final String id;
  final String name;
  final String email;
  final UserRole role;
  final int points;
  final double globalScore;
  final String avatarUrl;
  final String qrCode;
  final bool mfaEnabled;

  User({
    required this.id,
    required this.name,
    required this.email,
    required this.role,
    this.points = 0,
    this.globalScore = 0.0,
    this.avatarUrl = '',
    this.qrCode = '',
    this.mfaEnabled = false,
  });

  /// Crée un User depuis la réponse du backend
  factory User.fromBackend(Map<String, dynamic> data) {
    return User(
      id: (data['id'] ?? 0).toString(),
      name: data['full_name'] ?? 'Utilisateur',
      email: data['email'] ?? '',
      role: _parseRole(data['role'] ?? 'user'),
      points: data['points'] ?? 0,
      globalScore: (data['global_score'] ?? 0.0).toDouble(),
      avatarUrl: data['avatar_url'] ?? '',
      qrCode: data['qr_code'] ?? '',
      mfaEnabled: data['mfa_enabled'] ?? false,
    );
  }

  static UserRole _parseRole(String role) {
    switch (role) {
      case 'superadmin':
        return UserRole.superadmin;
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
      case UserRole.superadmin:
        return 'Super Administrateur';
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

  User copyWithScore(double newScore) => User(
    id: id, name: name, email: email, role: role,
    points: points, globalScore: newScore,
    avatarUrl: avatarUrl, qrCode: qrCode,
    mfaEnabled: mfaEnabled,
  );
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

  /// Token JWT stoké après login
  static String? authToken;

  /// Header Authorization prêt à l'emploi
  static Map<String, String> get authHeader =>
      authToken != null ? {'Authorization': 'Bearer $authToken'} : {};

  static bool get isLoggedIn => currentUser != null;
  static bool get isAdmin => currentUser?.role == UserRole.admin || currentUser?.role == UserRole.superadmin;
}
