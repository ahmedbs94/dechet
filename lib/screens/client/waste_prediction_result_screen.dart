import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../theme/app_theme.dart';
import '../../widgets/glass_card.dart';
import '../../models/waste_record_model.dart';
import '../../models/user_model.dart';

class WastePredictionResultScreen extends StatelessWidget {
  final WasteType predictedType;
  final double confidenceScore;
  final String? imageUrl;

  const WastePredictionResultScreen({
    Key? key,
    required this.predictedType,
    required this.confidenceScore,
    this.imageUrl,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          onPressed: () => Navigator.pop(context),
          icon: const Icon(Icons.close, color: AppTheme.deepSlate, size: 28),
        ),
        title: Text(
          'Prédiction IA',
          style: GoogleFonts.outfit(
            fontSize: 20,
            fontWeight: FontWeight.bold,
            color: AppTheme.deepSlate,
          ),
        ),
      ),
      body: SingleChildScrollView(
        physics: const BouncingScrollPhysics(),
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Prediction Result Card
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(24),
                boxShadow: AppTheme.premiumShadow,
              ),
              child: Column(
                children: [
                  // Scanned Image Placeholder
                  Container(
                    height: 200,
                    decoration: BoxDecoration(
                      color: Colors.grey[200],
                      borderRadius: BorderRadius.circular(16),
                      image: imageUrl != null
                          ? DecorationImage(
                              image: NetworkImage(imageUrl!),
                              fit: BoxFit.cover,
                            )
                          : null,
                    ),
                    child: imageUrl == null
                        ? Center(
                            child: Icon(
                              predictedType.icon,
                              size: 80,
                              color: predictedType.color.withOpacity(0.5),
                            ),
                          )
                        : null,
                  ).animate().fadeIn().scale(curve: Curves.easeOutCubic),

                  const SizedBox(height: 24),

                  // Confidence Badge
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [
                          predictedType.color.withOpacity(0.2),
                          predictedType.color.withOpacity(0.1),
                        ],
                      ),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      '${predictedType.displayName.toLowerCase()} ${(confidenceScore * 100).toInt()}%',
                      style: GoogleFonts.outfit(
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
                        color: predictedType.color,
                      ),
                    ),
                  ).animate(delay: 200.ms).fadeIn().scale(curve: Curves.elasticOut),
                ],
              ),
            ),

            const SizedBox(height: 24),

            // Waste Info Card
            GlassCard(
              padding: const EdgeInsets.all(24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: predictedType.color.withOpacity(0.15),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Icon(
                          predictedType.icon,
                          color: predictedType.color,
                          size: 28,
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              predictedType.frenchName,
                              style: GoogleFonts.outfit(
                                fontSize: 20,
                                fontWeight: FontWeight.bold,
                                color: AppTheme.deepSlate,
                              ),
                            ),
                            Text(
                              predictedType.binColor,
                              style: GoogleFonts.inter(
                                fontSize: 13,
                                color: predictedType.color,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 20),

                  Text(
                    _getWasteInfo(),
                    style: GoogleFonts.inter(
                      fontSize: 14,
                      color: AppTheme.textMuted,
                      height: 1.6,
                    ),
                  ),

                  const SizedBox(height: 24),

                  // Add to Bin Button
                  ElevatedButton(
                    onPressed: () => _addToBin(context),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppTheme.deepSlate,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      elevation: 0,
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(Icons.add_circle_outline_rounded),
                        const SizedBox(width: 8),
                        Text(
                          'Ajouter au bac',
                          style: GoogleFonts.outfit(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ).animate(delay: 100.ms).fadeIn().slideY(begin: 0.1, curve: Curves.easeOutCubic),

            const SizedBox(height: 24),

            // Nearby Centers
            Text(
              'CENTRES PROCHES QUI ACCEPTENT ${predictedType.displayName.toUpperCase()}',
              style: GoogleFonts.inter(
                fontSize: 11,
                fontWeight: FontWeight.w900,
                letterSpacing: 1,
                color: AppTheme.textMuted,
              ),
            ),

            const SizedBox(height: 16),

            _buildCenterCard('Centre de Tri Écologique', '0.8 km', Icons.verified_rounded),
            _buildCenterCard('Déchetterie Municipale', '1.2 km', Icons.check_circle_rounded),
            _buildCenterCard('Point de Collecte Nord', '1.5 km', Icons.location_on_rounded),

            const SizedBox(height: 100),
          ],
        ),
      ),
    );
  }

  Widget _buildCenterCard(String name, String distance, IconData icon) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      child: GlassCard(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                color: AppTheme.primaryGreen.withOpacity(0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(icon, color: AppTheme.primaryGreen, size: 24),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    name,
                    style: GoogleFonts.outfit(
                      fontSize: 15,
                      fontWeight: FontWeight.bold,
                      color: AppTheme.deepSlate,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Row(
                    children: [
                      Icon(Icons.navigation_rounded, size: 14, color: AppTheme.textMuted),
                      const SizedBox(width: 4),
                      Text(
                        distance,
                        style: GoogleFonts.inter(
                          fontSize: 13,
                          color: AppTheme.textMuted,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const Icon(Icons.arrow_forward_ios_rounded, size: 16, color: AppTheme.textMuted),
          ],
        ),
      ),
    ).animate(delay: 200.ms).fadeIn().slideX(begin: 0.1, curve: Curves.easeOutCubic);
  }

  String _getWasteInfo() {
    switch (predictedType) {
      case WasteType.metal:
        return 'Le métal est recyclable à 100% et indéfiniment. Pensez à vider le contenu de la boîte de conserve ou de la canette.';
      case WasteType.plastic:
        return 'Les plastiques doivent être vidés avant le tri. Assurez-vous de retirer les bouchons et de rincer les contenants.';
      case WasteType.paper:
        return 'Le papier doit être propre et sec. Évitez de mélanger avec du papier gras ou souillé.';
      case WasteType.glass:
        return 'Le verre est recyclable à l\'infini. Retirez les bouchons et couvercles avant le tri.';
      default:
        return 'Consultez le guide de tri pour plus d\'informations sur ce type de déchet.';
    }
  }

  void _addToBin(BuildContext context) {
    // Add record to history
    final userId = AuthState.currentUser?.id ?? '1';
    final record = WasteRecord(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      userId: userId,
      type: predictedType,
      scannedAt: DateTime.now(),
      pointsEarned: _calculatePoints(),
      confidenceScore: confidenceScore,
      imageUrl: imageUrl,
    );

    WasteRecordService.addRecord(record);

    // Show success message
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(Icons.check_circle, color: Colors.white),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                '+${record.pointsEarned} points ajoutés !',
                style: GoogleFonts.outfit(fontWeight: FontWeight.bold),
              ),
            ),
          ],
        ),
        backgroundColor: AppTheme.primaryGreen,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        margin: const EdgeInsets.all(16),
      ),
    );

    // Navigate back
    Future.delayed(const Duration(milliseconds: 1500), () {
      Navigator.pop(context);
    });
  }

  int _calculatePoints() {
    // Base points by type
    int basePoints = switch (predictedType) {
      WasteType.metal => 40,
      WasteType.glass => 30,
      WasteType.plastic => 25,
      WasteType.paper => 15,
      WasteType.organic => 20,
      WasteType.trash => 10,
    };

    // Bonus for high confidence
    if (confidenceScore >= 0.90) {
      basePoints = (basePoints * 1.2).round();
    }

    return basePoints;
  }
}
