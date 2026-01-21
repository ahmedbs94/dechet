import 'package:flutter/material.dart';

/// Model for tracking recycled waste items
class WasteRecord {
  final String id;
  final String userId;
  final WasteType type;
  final DateTime scannedAt;
  final int pointsEarned;
  final double confidenceScore; // AI prediction confidence (0.0 - 1.0)
  final String? imageUrl;

  WasteRecord({
    required this.id,
    required this.userId,
    required this.type,
    required this.scannedAt,
    required this.pointsEarned,
    required this.confidenceScore,
    this.imageUrl,
  });
}

/// Different waste categories with their properties
enum WasteType {
  paper,
  glass,
  metal,
  plastic,
  trash,
  organic,
}

extension WasteTypeExtension on WasteType {
  String get displayName {
    switch (this) {
      case WasteType.paper:
        return 'Paper';
      case WasteType.glass:
        return 'Glass';
      case WasteType.metal:
        return 'Metal';
      case WasteType.plastic:
        return 'Plastic';
      case WasteType.trash:
        return 'Trash';
      case WasteType.organic:
        return 'Organic';
    }
  }

  String get frenchName {
    switch (this) {
      case WasteType.paper:
        return 'Papier';
      case WasteType.glass:
        return 'Verre';
      case WasteType.metal:
        return 'Métal';
      case WasteType.plastic:
        return 'Plastique';
      case WasteType.trash:
        return 'Ordures';
      case WasteType.organic:
        return 'Organique';
    }
  }

  IconData get icon {
    switch (this) {
      case WasteType.paper:
        return Icons.description_rounded;
      case WasteType.glass:
        return Icons.local_drink_rounded;
      case WasteType.metal:
        return Icons.water_drop_rounded;
      case WasteType.plastic:
        return Icons.water_rounded;
      case WasteType.trash:
        return Icons.delete_rounded;
      case WasteType.organic:
        return Icons.eco_rounded;
    }
  }

  Color get color {
    switch (this) {
      case WasteType.paper:
        return const Color(0xFF3B82F6); // Blue
      case WasteType.glass:
        return const Color(0xFF06B6D4); // Cyan
      case WasteType.metal:
        return const Color(0xFF8B5CF6); // Purple
      case WasteType.plastic:
        return const Color(0xFFF59E0B); // Amber
      case WasteType.trash:
        return const Color(0xFF6B7280); // Gray
      case WasteType.organic:
        return const Color(0xFF10B981); // Green
    }
  }

  String get binColor {
    switch (this) {
      case WasteType.paper:
        return 'POUBELLE BLEUE';
      case WasteType.glass:
        return 'POUBELLE VERTE';
      case WasteType.metal:
        return 'POUBELLE JAUNE';
      case WasteType.plastic:
        return 'POUBELLE JAUNE';
      case WasteType.trash:
        return 'POUBELLE GRISE';
      case WasteType.organic:
        return 'COMPOST';
    }
  }

  double get co2SavedPerItem {
    switch (this) {
      case WasteType.paper: return 0.2;
      case WasteType.glass: return 0.5;
      case WasteType.metal: return 1.2;
      case WasteType.plastic: return 0.6;
      case WasteType.organic: return 0.3;
      case WasteType.trash: return 0.05;
    }
  }
}

/// Category statistics for tracking user's recycling performance
class WasteCategoryStats {
  final WasteType type;
  int totalItems;
  int totalPoints;

  WasteCategoryStats({
    required this.type,
    this.totalItems = 0,
    this.totalPoints = 0,
  });

  void addRecord(WasteRecord record) {
    totalItems++;
    totalPoints += record.pointsEarned;
  }
}

/// Service for managing waste records (demo/mock data)
class WasteRecordService {
  static final List<WasteRecord> _records = [
    WasteRecord(
      id: '1',
      userId: '1',
      type: WasteType.paper,
      scannedAt: DateTime.now().subtract(const Duration(hours: 2)),
      pointsEarned: 15,
      confidenceScore: 0.92,
    ),
    WasteRecord(
      id: '2',
      userId: '1',
      type: WasteType.plastic,
      scannedAt: DateTime.now().subtract(const Duration(hours: 5)),
      pointsEarned: 25,
      confidenceScore: 0.88,
    ),
    WasteRecord(
      id: '3',
      userId: '1',
      type: WasteType.glass,
      scannedAt: DateTime.now().subtract(const Duration(days: 1)),
      pointsEarned: 30,
      confidenceScore: 0.95,
    ),
    WasteRecord(
      id: '4',
      userId: '1',
      type: WasteType.metal,
      scannedAt: DateTime.now().subtract(const Duration(days: 1, hours: 3)),
      pointsEarned: 40,
      confidenceScore: 0.89,
    ),
    WasteRecord(
      id: '5',
      userId: '1',
      type: WasteType.plastic,
      scannedAt: DateTime.now().subtract(const Duration(days: 2)),
      pointsEarned: 20,
      confidenceScore: 0.91,
    ),
    WasteRecord(
      id: '6',
      userId: '1',
      type: WasteType.trash,
      scannedAt: DateTime.now().subtract(const Duration(days: 3)),
      pointsEarned: 10,
      confidenceScore: 0.87,
    ),
  ];

  static List<WasteRecord> getUserRecords(String userId) {
    return _records.where((r) => r.userId == userId).toList()
      ..sort((a, b) => b.scannedAt.compareTo(a.scannedAt));
  }

  static Map<WasteType, WasteCategoryStats> getCategoryStats(String userId) {
    final stats = <WasteType, WasteCategoryStats>{};
    
    for (var type in WasteType.values) {
      stats[type] = WasteCategoryStats(type: type);
    }

    for (var record in getUserRecords(userId)) {
      stats[record.type]?.addRecord(record);
    }

    return stats;
  }

  static void addRecord(WasteRecord record) {
    _records.add(record);
  }

  static int getTotalPoints(String userId) {
    return getUserRecords(userId)
        .fold(0, (sum, record) => sum + record.pointsEarned);
  }

  static double getTotalCO2Saved(String userId) {
    return getUserRecords(userId)
        .fold(0.0, (sum, record) => sum + record.type.co2SavedPerItem);
  }
}
