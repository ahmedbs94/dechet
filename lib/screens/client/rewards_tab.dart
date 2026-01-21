import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:lottie/lottie.dart';
import '../../theme/app_theme.dart';
import '../../widgets/glass_card.dart';
import 'waste_scanner_screen.dart';
import 'track_records_screen.dart';
import 'badge_screen.dart';

class RewardsTab extends StatelessWidget {
  const RewardsTab({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      physics: const BouncingScrollPhysics(),
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Section d'en-tête
          Animate(
            effects: [FadeEffect(), SlideEffect(begin: const Offset(-0.1, 0))],
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Votre Impact', style: GoogleFonts.outfit(fontSize: 32, fontWeight: FontWeight.bold, color: AppTheme.deepSlate)),
                    Text('Mise à jour en temps réel', style: GoogleFonts.inter(color: AppTheme.textMuted, fontSize: 13)),
                  ],
                ),
                Animate(
                  onPlay: (c) => c.repeat(),
                  effects: [
                    ScaleEffect(begin: const Offset(1, 1), end: const Offset(1.1, 1.1), duration: 2.seconds),
                    FadeEffect(begin: 1, end: 0.8),
                  ],
                  child: Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: AppTheme.primaryGreen.withOpacity(0.1),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.flash_on_rounded, color: AppTheme.primaryGreen, size: 28),
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 48),

          // Hub central de visualisation (Premium & Dynamique)
          Center(
            child: Stack(
              alignment: Alignment.center,
              children: [
                // Anneaux d'arrière-plan animés
                Animate(
                  onPlay: (c) => c.repeat(),
                  effects: [RotateEffect(duration: 30.seconds)],
                  child: Container(
                    width: 340,
                    height: 340,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(color: AppTheme.primaryGreen.withOpacity(0.05), width: 1.5),
                    ),
                  ),
                ),
                
                // Lueur de l'anneau extérieur
                Container(
                  width: 260,
                  height: 260,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: AppTheme.primaryGreen.withOpacity(0.1),
                        blurRadius: 60,
                        spreadRadius: 10,
                      )
                    ],
                  ),
                ),

                // Barres de progression circulaires
                _buildCircularProgress(250, 0.75, AppTheme.primaryGreen, 14),
                _buildCircularProgress(210, 0.45, AppTheme.accentMint, 8),
                
                // Hub de texte central
                Container(
                  width: 170,
                  height: 170,
                  decoration: BoxDecoration(
                    color: Colors.white,
                    shape: BoxShape.circle,
                    boxShadow: AppTheme.premiumShadow,
                  ),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Animate(
                        onPlay: (c) => c.repeat(reverse: true),
                        effects: [MoveEffect(begin: const Offset(0, -2), end: const Offset(0, 2), duration: 2.seconds)],
                        child: const Icon(Icons.stars_rounded, color: AppTheme.primaryGreen, size: 28),
                      ),
                      const SizedBox(height: 8),
                      Animate(
                        effects: [ScaleEffect(delay: 400.ms, duration: 600.ms, curve: Curves.elasticOut)],
                        child: Text(
                          '1,250',
                          style: GoogleFonts.outfit(
                            fontSize: 42,
                            fontWeight: FontWeight.bold,
                            color: AppTheme.deepSlate,
                            letterSpacing: -1,
                          ),
                        ),
                      ),
                      Text('POINTS ÉCO', style: GoogleFonts.inter(fontWeight: FontWeight.w900, letterSpacing: 2, fontSize: 10, color: AppTheme.textMuted)),
                    ],
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 64),

          _buildSectionHeader('ACTIONS STRATÉGIQUES'),
          const SizedBox(height: 20),
          _buildActionCard(
            context,
            'ANALYSER UN DÉCHET',
            'IA de reconnaissance instantanée',
            Icons.auto_awesome_rounded,
            AppTheme.primaryGreen,
            () => Navigator.push(context, MaterialPageRoute(builder: (context) => const WasteScannerScreen())),
          ),
          const SizedBox(height: 12),
          _buildActionCard(
            context,
            'HISTORIQUE DE TRI',
            'Consultez vos déchets recyclés',
            Icons.history_rounded,
            const Color(0xFFFBBF24),
            () => Navigator.push(context, MaterialPageRoute(builder: (context) => const TrackRecordsScreen())),
          ),
          const SizedBox(height: 12),
          _buildActionCard(
            context,
            'MON BADGE DÉCHETTERIE',
            'QR Code d\'accès aux centres',
            Icons.qr_code_2_rounded,
            const Color(0xFFFF6B35),
            () => Navigator.push(context, MaterialPageRoute(builder: (context) => const BadgeScreen())),
          ),

          const SizedBox(height: 48),

          _buildSectionHeader('VOS RÉCOMPENSES & BADGES'),
          const SizedBox(height: 20),
          SizedBox(
            height: 140, // Increased height for subtitle
            child: ListView(
              scrollDirection: Axis.horizontal,
              physics: const BouncingScrollPhysics(),
              children: [
                _buildPremiumBadge('Élite 1%', 'Top utilisateur', Icons.workspace_premium_rounded, Colors.amber),
                _buildPremiumBadge('Expert Tri', 'Score parfait', Icons.recycling_rounded, Colors.blue),
                _buildPremiumBadge('Sentinelle', 'Citoyen actif', Icons.security_rounded, Colors.deepPurple),
                _buildPremiumBadge('Zéro Carbone', 'Planète protégée', Icons.eco_rounded, Colors.green),
              ],
            ),
          ),

          const SizedBox(height: 48),

          _buildSectionHeader('ANALYSE DE PERFORMANCE'),
          const SizedBox(height: 20),
          _buildPerformanceBar('Plastiques & Polymères', 0.85, Colors.blue),
          _buildPerformanceBar('Cellulose & Fibres', 0.60, Colors.orange),
          _buildPerformanceBar('Verre & Minéraux', 0.35, Colors.teal),
          
          const SizedBox(height: 120),
        ],
      ),
    );
  }

  Widget _buildCircularProgress(double size, double value, Color color, double stroke) {
    return Animate(
      onPlay: (c) => c.repeat(reverse: true),
      effects: [RotateEffect(duration: 5.seconds, begin: -0.1, end: 0.1)],
      child: SizedBox(
        width: size,
        height: size,
        child: CircularProgressIndicator(
          value: value,
          strokeWidth: stroke,
          backgroundColor: color.withOpacity(0.1),
          color: color,
          strokeCap: StrokeCap.round,
        ),
      ),
    );
  }

  Widget _buildSectionHeader(String title) {
    return Text(
      title,
      style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w900, letterSpacing: 1.5, color: AppTheme.textMuted),
    );
  }

  Widget _buildActionCard(BuildContext context, String title, String sub, IconData icon, Color color, VoidCallback onTap) {
    return Animate(
      effects: [FadeEffect(), SlideEffect(begin: const Offset(0, 0.1))],
      child: GestureDetector(
        onTap: onTap,
        child: GlassCard(
          padding: const EdgeInsets.all(24),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(18),
                decoration: BoxDecoration(
                  gradient: LinearGradient(colors: [color.withOpacity(0.2), color.withOpacity(0.05)]),
                  shape: BoxShape.circle,
                ),
                child: Icon(icon, color: color, size: 34),
              ),
              const SizedBox(width: 24),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title, style: GoogleFonts.outfit(fontWeight: FontWeight.bold, fontSize: 17, color: AppTheme.deepSlate)),
                    const SizedBox(height: 4),
                    Text(sub, style: GoogleFonts.inter(fontSize: 13, color: AppTheme.textMuted)),
                  ],
                ),
              ),
              const Icon(Icons.arrow_forward_ios_rounded, color: AppTheme.textMuted, size: 16),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildPremiumBadge(String label, String subtitle, IconData icon, Color color) {
    return Container(
      width: 110, // Slightly wider to fit subtitle text
      margin: const EdgeInsets.only(right: 20),
      child: Column(
        children: [
          Animate(
            onPlay: (c) => c.repeat(reverse: true),
            effects: [MoveEffect(begin: const Offset(0, -2), end: const Offset(0, 2), duration: 2.seconds)],
            child: Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: color.withOpacity(0.1),
                shape: BoxShape.circle,
                border: Border.all(color: color.withOpacity(0.2), width: 2),
              ),
              child: Icon(icon, color: color, size: 36),
            ),
          ),
          const SizedBox(height: 12),
          Text(label, style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.bold, color: AppTheme.deepSlate), textAlign: TextAlign.center),
          const SizedBox(height: 4),
          Text(subtitle, style: GoogleFonts.inter(fontSize: 9, color: AppTheme.textMuted, fontWeight: FontWeight.w500), textAlign: TextAlign.center),
        ],
      ),
    );
  }

  Widget _buildPerformanceBar(String label, double value, Color color) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(label, style: GoogleFonts.inter(fontWeight: FontWeight.w600, fontSize: 14, color: AppTheme.deepSlate)),
              Text('${(value * 100).toInt()}%', style: GoogleFonts.outfit(fontWeight: FontWeight.bold, color: color)),
            ],
          ),
          const SizedBox(height: 10),
          ClipRRect(
            borderRadius: BorderRadius.circular(20),
            child: Stack(
              children: [
                LinearProgressIndicator(
                  value: value,
                  minHeight: 12,
                  backgroundColor: color.withOpacity(0.1),
                  color: color,
                ),
                Animate(
                  onPlay: (c) => c.repeat(),
                  effects: [ShimmerEffect(duration: 2.seconds, color: Colors.white30, blendMode: BlendMode.srcOver)],
                  child: Container(height: 12, width: double.infinity, color: Colors.transparent),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
