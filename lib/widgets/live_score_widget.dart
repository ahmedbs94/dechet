/// lib/widgets/live_score_widget.dart
///
/// Widget Score Temps Réel — affiché dans le profil/dashboard du citoyen.
/// S'abonne à Firebase RTDB et affiche une animation lors de chaque gain de points.

import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../services/firebase_score_service.dart';

/// Icônes par type de déchet
const Map<String, IconData> _wasteIcons = {
  'plastique':    Icons.water_drop_outlined,
  'verre':        Icons.wine_bar_outlined,
  'papier':       Icons.description_outlined,
  'carton':       Icons.inventory_2_outlined,
  'metal':        Icons.hardware_outlined,
  'organique':    Icons.eco_outlined,
  'electronique': Icons.devices_outlined,
  'textile':      Icons.checkroom_outlined,
  'general':      Icons.delete_outline,
};

/// Couleurs par type de déchet
const Map<String, Color> _wasteColors = {
  'plastique':    Color(0xFF29B6F6),
  'verre':        Color(0xFF66BB6A),
  'papier':       Color(0xFFFFCA28),
  'carton':       Color(0xFFFF8A65),
  'metal':        Color(0xFF90A4AE),
  'organique':    Color(0xFF8D6E63),
  'electronique': Color(0xFFAB47BC),
  'textile':      Color(0xFFEC407A),
  'general':      Color(0xFF78909C),
};

class LiveScoreWidget extends StatelessWidget {
  final int userId;
  final double fallbackScore;

  const LiveScoreWidget({
    super.key,
    required this.userId,
    this.fallbackScore = 0.0,
  });

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<ScoreSnapshot>(
      stream: FirebaseScoreService().watchScore(userId),
      builder: (context, snapshot) {
        final data = snapshot.data ?? ScoreSnapshot.empty();
        final score = data.total > 0 ? data.total : fallbackScore;
        final hasNewPoints = data.lastPoints > 0;

        return _ScoreCard(
          score: score,
          lastPoints: data.lastPoints,
          lastBinType: data.lastBinType,
          hasNewPoints: hasNewPoints,
          isLoading: snapshot.connectionState == ConnectionState.waiting,
        );
      },
    );
  }
}

class _ScoreCard extends StatelessWidget {
  final double score;
  final double lastPoints;
  final String lastBinType;
  final bool hasNewPoints;
  final bool isLoading;

  const _ScoreCard({
    required this.score,
    required this.lastPoints,
    required this.lastBinType,
    required this.hasNewPoints,
    required this.isLoading,
  });

  @override
  Widget build(BuildContext context) {
    final accentColor = _wasteColors[lastBinType] ?? const Color(0xFF00BFA6);

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Color(0xFF0F2027),
            Color(0xFF1A3A2A),
          ],
        ),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
          color: accentColor.withOpacity(0.4),
          width: 1.5,
        ),
        boxShadow: [
          BoxShadow(
            color: accentColor.withOpacity(0.2),
            blurRadius: 24,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // En-tête
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: accentColor.withOpacity(0.15),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Icon(
                    Icons.stars_rounded,
                    color: accentColor,
                    size: 24,
                  ),
                ),
                const SizedBox(width: 12),
                const Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Score Global',
                      style: TextStyle(
                        color: Color(0xFF94A3B8),
                        fontSize: 13,
                        letterSpacing: 0.5,
                      ),
                    ),
                    Text(
                      'EcoRewind',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 11,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
                const Spacer(),
                // Indicateur temps réel
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                  decoration: BoxDecoration(
                    color: const Color(0xFF00BFA6).withOpacity(0.15),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                      color: const Color(0xFF00BFA6).withOpacity(0.3),
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        width: 6,
                        height: 6,
                        decoration: const BoxDecoration(
                          color: Color(0xFF00BFA6),
                          shape: BoxShape.circle,
                        ),
                      ).animate(onPlay: (c) => c.repeat())
                          .fadeIn(duration: 800.ms)
                          .then()
                          .fadeOut(duration: 800.ms),
                      const SizedBox(width: 6),
                      const Text(
                        'LIVE',
                        style: TextStyle(
                          color: Color(0xFF00BFA6),
                          fontSize: 10,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 1,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),

            // Score principal
            isLoading
                ? _LoadingScore()
                : Text(
                    '${score.toStringAsFixed(0)} pts',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 42,
                      fontWeight: FontWeight.w900,
                      letterSpacing: -1,
                      height: 1,
                    ),
                  ).animate(key: ValueKey(score))
                    .fadeIn(duration: 300.ms)
                    .slideY(begin: 0.3, end: 0, duration: 400.ms, curve: Curves.easeOut),

            const SizedBox(height: 12),

            // Dernier scan
            if (hasNewPoints) ...[
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                decoration: BoxDecoration(
                  color: accentColor.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: accentColor.withOpacity(0.25)),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      _wasteIcons[lastBinType] ?? Icons.delete_outline,
                      color: accentColor,
                      size: 16,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      '+${lastPoints.toStringAsFixed(0)} pts',
                      style: TextStyle(
                        color: accentColor,
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(width: 6),
                    Text(
                      '· ${lastBinType[0].toUpperCase()}${lastBinType.substring(1)}',
                      style: TextStyle(
                        color: accentColor.withOpacity(0.7),
                        fontSize: 13,
                      ),
                    ),
                  ],
                ),
              ).animate()
                  .fadeIn(duration: 400.ms)
                  .slideX(begin: -0.2, end: 0, duration: 400.ms, curve: Curves.easeOut),
            ],
          ],
        ),
      ),
    );
  }
}

class _LoadingScore extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      width: 120,
      height: 42,
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.08),
        borderRadius: BorderRadius.circular(8),
      ),
    ).animate(onPlay: (c) => c.repeat())
        .shimmer(duration: 1200.ms, color: Colors.white12);
  }
}
