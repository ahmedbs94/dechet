/// lib/models/bin_model.dart
///
/// Modèle de données pour une poubelle intelligente lue depuis
/// Firebase Realtime Database — nœud : /poubelles/{bin_id}
///
/// LECTURE SEULE côté Flutter. Seul le backend FastAPI (Admin SDK)
/// écrit dans ce nœud via update_bin_status().

/// États possibles d'une poubelle intelligente.
enum BinEtat {
  vide,
  miPlein,
  plein,
  enMaintenance,
  inconnu,
}

extension BinEtatExtension on BinEtat {
  String get label {
    switch (this) {
      case BinEtat.vide:
        return 'Vide';
      case BinEtat.miPlein:
        return 'Mi-plein';
      case BinEtat.plein:
        return 'Plein';
      case BinEtat.enMaintenance:
        return 'En maintenance';
      case BinEtat.inconnu:
        return 'Inconnu';
    }
  }

  /// Couleur associée à l'état (code hex pour référence UI)
  String get colorHex {
    switch (this) {
      case BinEtat.vide:
        return '#22C55E'; // vert
      case BinEtat.miPlein:
        return '#F59E0B'; // orange
      case BinEtat.plein:
        return '#EF4444'; // rouge
      case BinEtat.enMaintenance:
        return '#8B5CF6'; // violet
      case BinEtat.inconnu:
        return '#6B7280'; // gris
    }
  }
}

/// Snapshot des données d'une poubelle intelligente depuis Firebase RTDB.
class BinSnapshot {
  /// Poids actuel du contenu de la poubelle, en kilogrammes.
  final double poids;

  /// État actuel de la poubelle.
  final BinEtat etat;

  /// Horodatage de la dernière mise à jour (ISO 8601 UTC), peut être vide.
  final String derniereMiseAJour;

  const BinSnapshot({
    required this.poids,
    required this.etat,
    this.derniereMiseAJour = '',
  });

  /// Construit un BinSnapshot depuis les données brutes Firebase.
  factory BinSnapshot.fromMap(Map<dynamic, dynamic> map) {
    return BinSnapshot(
      poids: (map['poids'] as num?)?.toDouble() ?? 0.0,
      etat: _parseEtat(map['etat']?.toString() ?? ''),
      derniereMiseAJour: map['derniere_mise_a_jour']?.toString() ?? '',
    );
  }

  /// Snapshot vide par défaut (poubelle inconnue ou hors ligne).
  factory BinSnapshot.empty() => const BinSnapshot(
        poids: 0.0,
        etat: BinEtat.inconnu,
        derniereMiseAJour: '',
      );

  static BinEtat _parseEtat(String raw) {
    switch (raw) {
      case 'vide':
        return BinEtat.vide;
      case 'mi-plein':
        return BinEtat.miPlein;
      case 'plein':
        return BinEtat.plein;
      case 'en_maintenance':
        return BinEtat.enMaintenance;
      default:
        return BinEtat.inconnu;
    }
  }

  /// Pourcentage de remplissage estimé selon l'état (0.0 à 1.0).
  double get remplissageEstime {
    switch (etat) {
      case BinEtat.vide:
        return 0.05;
      case BinEtat.miPlein:
        return 0.50;
      case BinEtat.plein:
        return 0.95;
      case BinEtat.enMaintenance:
        return 0.0;
      case BinEtat.inconnu:
        return 0.0;
    }
  }

  /// True si la poubelle nécessite une collecte urgente.
  bool get needsCollection => etat == BinEtat.plein;

  @override
  String toString() =>
      'BinSnapshot(poids=${poids}kg, etat=${etat.label}, maj=$derniereMiseAJour)';
}

/// Snapshot des données d'identification d'un utilisateur depuis Firebase RTDB.
/// Nœud : /utilisateurs/{user_id}
class UtilisateurSnapshot {
  /// Rôle de l'utilisateur (ex: "user", "admin", "collector"...)
  final String role;

  /// QR code unique de la carte de l'utilisateur.
  final String qrCode;

  const UtilisateurSnapshot({
    required this.role,
    required this.qrCode,
  });

  factory UtilisateurSnapshot.fromMap(Map<dynamic, dynamic> map) {
    return UtilisateurSnapshot(
      role: map['role']?.toString() ?? 'user',
      qrCode: map['qr_code']?.toString() ?? '',
    );
  }

  factory UtilisateurSnapshot.empty() => const UtilisateurSnapshot(
        role: 'user',
        qrCode: '',
      );
}
