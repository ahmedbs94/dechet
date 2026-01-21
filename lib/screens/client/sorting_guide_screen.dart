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
      backgroundColor: AppTheme.backgroundLight,
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
                    effects: [FadeEffect(), ScaleEffect(begin: const Offset(0.9, 0.9))],
                    child: Container(
                      width: double.infinity,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(32),
                        boxShadow: AppTheme.premiumShadow,
                      ),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(32),
                        child: Container(
                          color: Colors.white,
                          child: Image.network(
                            'https://www.cy-clope.com/wp-content/uploads/2024/06/Tri-selectif-1.png.webp',
                            fit: BoxFit.contain,
                            height: 300,
                            width: double.infinity,
                            loadingBuilder: (context, child, loadingProgress) {
                              if (loadingProgress == null) return child;
                              return Container(
                                height: 300,
                                color: Colors.grey.shade100,
                                child: const Center(child: CircularProgressIndicator(color: AppTheme.primaryGreen)),
                              );
                            },
                            errorBuilder: (context, error, stackTrace) => Container(
                              height: 300,
                              color: Colors.white,
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  const Icon(Icons.image_outlined, size: 60, color: AppTheme.textMuted),
                                  const SizedBox(height: 16),
                                  Text('Erreur de chargement', style: GoogleFonts.inter(color: AppTheme.textMuted)),
                                ],
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
                    Icons.water_drop_outlined, 
                    'Videz et rincez', 
                    'Pas besoin de laver à fond, mais les contenants doivent être vides de restes alimentaires.'
                  ),
                  const SizedBox(height: 16),
                  _buildRuleCard(
                    Icons.unfold_less_rounded, 
                    'Ne pas emboîter', 
                    'Laissez les déchets séparés pour qu\'ils puissent être reconnus par les machines de tri.'
                  ),
                  const SizedBox(height: 16),
                  _buildRuleCard(
                    Icons.check_circle_outline_rounded, 
                    'En vrac', 
                    'Déposez vos déchets directement dans le bac, pas dans des sacs fermés (sauf avis contraire).'
                  ),
                  const SizedBox(height: 48),
                  Text('POUR LES PLUS JEUNES', style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w900, letterSpacing: 2, color: AppTheme.primaryGreen)),
                  const SizedBox(height: 16),
                  Container(
                    width: double.infinity,
                    height: 200,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(24),
                      image: DecorationImage(
                        image: NetworkImage('https://png.pngtree.com/thumb_back/fw800/background/20251102/pngtree-recycling-concept-with-cute-cartoon-characters-and-colorful-bins-promoting-environmental-image_20141563.webp'),
                        fit: BoxFit.cover,
                      ),
                    ),
                  ),
                  const SizedBox(height: 48),
                  GlassCard(
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      children: [
                        const Icon(Icons.info_outline_rounded, color: AppTheme.primaryGreen),
                        const SizedBox(height: 12),
                        const Text(
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
  Widget _buildRuleCard(IconData icon, String title, String desc) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: Colors.grey.shade100),
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
