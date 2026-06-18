import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../theme/app_theme.dart';
import '../../widgets/glass_card.dart';

// Écran affichant le guide complet du tri avec règles et conseils
class SortingGuideScreen extends StatelessWidget {
  const SortingGuideScreen({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      body: CustomScrollView(
        physics: const BouncingScrollPhysics(),
        // Utilisation d'un CustomScrollView pour l'effet de parallaxe sur l'AppBar
        slivers: [
          SliverAppBar(
            expandedHeight: 250,
            pinned: true,
            backgroundColor: AppTheme.primaryGreen,
            flexibleSpace: FlexibleSpaceBar(
              title: Text('Guide du Tri', style: GoogleFonts.outfit(fontWeight: FontWeight.bold, color: Colors.white)),
              background: Container(
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [AppTheme.primaryGreen, AppTheme.accentMint],
                  ),
                ),
                child: Center(
                  child: Icon(Icons.auto_awesome_rounded, size: 80, color: Colors.white.withOpacity(0.3)),
                ),
              ),
            ),
          ),
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.all(24.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Image principale du guide
                  Animate(
                    effects: const [FadeEffect(), ScaleEffect(begin: Offset(0.9, 0.9))],
                    child: Container(
                      width: double.infinity,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(32),
                        boxShadow: AppTheme.premiumShadow,
                      ),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(32),
                        child: Container(
                          color: Theme.of(context).colorScheme.surface,
                          child: Image.asset(
                            'assets/images/onboarding.png',
                            fit: BoxFit.contain,
                            height: 300,
                            width: double.infinity,
                            errorBuilder: (context, error, stackTrace) => Container(
                              height: 300,
                              decoration: const BoxDecoration(
                                gradient: LinearGradient(
                                  colors: [Color(0xFF0F172A), Color(0xFF0F2D24)],
                                  begin: Alignment.topLeft,
                                  end: Alignment.bottomRight,
                                ),
                              ),
                              child: Center(
                                child: Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Container(
                                      padding: const EdgeInsets.all(16),
                                      decoration: BoxDecoration(
                                        color: AppTheme.primaryGreen.withOpacity(0.15),
                                        shape: BoxShape.circle,
                                      ),
                                      child: const Icon(Icons.auto_awesome_rounded, size: 48, color: AppTheme.accentTeal),
                                    ),
                                    const SizedBox(height: 16),
                                    Text(
                                      'Guide du Tri Écologique',
                                      style: GoogleFonts.spaceGrotesk(
                                        color: Colors.white,
                                        fontSize: 18,
                                        fontWeight: FontWeight.w800,
                                      ),
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      'Suivez les règles ci-dessous pour trier vos déchets',
                                      style: GoogleFonts.inter(
                                        color: Colors.white.withOpacity(0.5),
                                        fontSize: 12,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 40),
                  Text('LES 3 RÈGLES D\'OR', style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w900, letterSpacing: 2, color: AppTheme.primaryGreen)),
                  const SizedBox(height: 24),
                  // Cartes des règles d'or
                  _buildRuleCard(
                    context,
                    Icons.water_drop_outlined, 
                    'Videz et rincez', 
                    'Pas besoin de laver à fond, mais les contenants doivent être vides de restes alimentaires.'
                  ),
                  const SizedBox(height: 16),
                  _buildRuleCard(
                    context,
                    Icons.unfold_less_rounded, 
                    'Ne pas emboîter', 
                    'Laissez les déchets séparés pour qu\'ils puissent être reconnus par les machines de tri.'
                  ),
                  const SizedBox(height: 16),
                  _buildRuleCard(
                    context,
                    Icons.check_circle_outline_rounded, 
                    'En vrac', 
                    'Déposez vos déchets directement dans le bac, pas dans des sacs fermés (sauf avis contraire).'
                  ),
                  const SizedBox(height: 48),
                  Text('POUR LES PLUS JEUNES', style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w900, letterSpacing: 2, color: AppTheme.primaryGreen)),
                  const SizedBox(height: 16),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(24),
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [Color(0xFFFEF3C7), Color(0xFFFDE68A)],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      borderRadius: BorderRadius.circular(24),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.amber.withOpacity(0.1),
                          blurRadius: 15,
                          offset: const Offset(0, 8),
                        ),
                      ],
                    ),
                    child: Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Text(
                                'Apprendre en s\'amusant ! 🎮',
                                style: GoogleFonts.outfit(
                                  color: const Color(0xFF92400E),
                                  fontSize: 18,
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                              const SizedBox(height: 8),
                              Text(
                                'Découvre nos quiz interactifs pour devenir un super-héros de la planète.',
                                style: GoogleFonts.inter(
                                  color: const Color(0xFFB45309),
                                  fontSize: 13,
                                  height: 1.4,
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 16),
                        Container(
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: Colors.white.withOpacity(0.3),
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(
                            Icons.videogame_asset_rounded,
                            size: 40,
                            color: Color(0xFFD97706),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 48),
                  const GlassCard(
                    padding: EdgeInsets.all(24),
                    child: Column(
                      children: [
                        Icon(Icons.info_outline_rounded, color: AppTheme.primaryGreen),
                        SizedBox(height: 12),
                        Text(
                          'En cas de doute, jetez-le dans le bac des ordures ménagères pour éviter de polluer le recyclage.',
                          textAlign: TextAlign.center,
                          style: TextStyle(fontStyle: FontStyle.italic, color: AppTheme.textMuted),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 100),
                ],
              ),
            ),
          )
        ],
      ),
    );
  }

  // Widget utilitaire pour créer une carte de règle uniformisée
  Widget _buildRuleCard(BuildContext context, IconData icon, String title, String desc) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: Theme.of(context).dividerColor, width: 1.5),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(isDark ? 0.2 : 0.02),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(color: AppTheme.primaryGreen.withOpacity(0.1), borderRadius: BorderRadius.circular(16)),
            child: Icon(icon, color: AppTheme.primaryGreen, size: 24),
          ),
          const SizedBox(width: 20),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: GoogleFonts.outfit(fontWeight: FontWeight.bold, fontSize: 18)),
                const SizedBox(height: 4),
                Text(desc, style: const TextStyle(color: AppTheme.textMuted, fontSize: 14)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
