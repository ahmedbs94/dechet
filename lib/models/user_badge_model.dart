import '../models/user_model.dart';

/// User badge with QR code for waste facility access
class UserBadge {
  final String badgeId;
  final String userId;
  final String firstName;
  final String lastName;
  final String address;
  final String city;
  final String postalCode;
  final UserBadgeType badgeType;
  final DateTime createdAt;
  final DateTime expiresAt;
  final bool isActive;

  UserBadge({
    required this.badgeId,
    required this.userId,
    required this.firstName,
    required this.lastName,
    required this.address,
    required this.city,
    required this.postalCode,
    required this.badgeType,
    required this.createdAt,
    required this.expiresAt,
    this.isActive = true,
  });

  /// Generate QR code data
  String get qrCodeData {
    return 'TRIDECHET:$badgeId:$userId:${badgeType.name}';
  }

  /// Full name
  String get fullName => '$firstName $lastName';

  /// Full address
  String get fullAddress => '$address\n$postalCode $city';
}

enum UserBadgeType {
  particulier,
  professionnel,
  entreprise,
}

extension UserBadgeTypeExtension on UserBadgeType {
  String get displayName {
    switch (this) {
      case UserBadgeType.particulier:
        return 'PARTICULIER';
      case UserBadgeType.professionnel:
        return 'PROFESSIONNEL';
      case UserBadgeType.entreprise:
        return 'ENTREPRISE';
    }
  }
}

/// Service for managing user badges
class UserBadgeService {
  static UserBadge? getUserBadge(String userId) {
    // Mock data based on current user
    if (AuthState.currentUser != null) {
      return UserBadge(
        badgeId: 'BD${userId.padLeft(8, '0')}',
        userId: userId,
        firstName: AuthState.currentUser!.name.split(' ').first,
        lastName: AuthState.currentUser!.name.split(' ').length > 1 
            ? AuthState.currentUser!.name.split(' ').last 
            : 'T.',
        address: '41 rue de la vie',
        city: 'BREUIL',
        postalCode: '80400',
        badgeType: UserBadgeType.particulier,
        createdAt: DateTime.now().subtract(const Duration(days: 30)),
        expiresAt: DateTime.now().add(const Duration(days: 335)),
        isActive: true,
      );
    }
    return null;
  }
}
