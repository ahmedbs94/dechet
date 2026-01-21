enum UserRole {
  user,
  admin,
  educator,
  intercommunality,
  pointManager,
  collector
}

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
}

// Global state simulation for the demo
class AuthState {
  static User? currentUser;

  static void login(UserRole role) {
    currentUser = User(
      id: '1',
      name: _getNameForRole(role),
      email: '${role.name}@tridechet.com',
      role: role,
      points: role == UserRole.user ? 1250 : 0,
    );
  }

  static String _getNameForRole(UserRole role) {
    switch (role) {
      case UserRole.admin: return 'Directeur Technique';
      case UserRole.educator: return 'Mme. Amel (Éducatrice)';
      case UserRole.intercommunality: return 'Grand Tunis';
      case UserRole.pointManager: return 'Sami (Gestionnaire)';
      case UserRole.collector: return 'Eco-Collecte TN';
      default: return 'Amine T.';
    }
  }
}
