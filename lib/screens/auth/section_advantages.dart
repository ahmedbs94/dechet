import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../theme/app_theme.dart';

class SectionAdvantages extends StatelessWidget {
  const SectionAdvantages({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.backgroundLight,
      body: CustomScrollView(
        physics: const BouncingScrollPhysics(),
        slivers: [
          SliverToBoxAdapter(child: _buildHeader(context)),
          SliverToBoxAdapter(child: _buildAdvantagesList()),
          SliverToBoxAdapter(child: _buildPromoCard()),
          const SliverToBoxAdapter(child: SizedBox(height: 60)),
        ],
      ),
    );
  }

  Widget _buildHeader(BuildContext context) {
    return Container(
      width: double.infinity,
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [Color(0xFFF59E0B), Color(0xFFF97316)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.vertical(bottom: Radius.circular(36)),
      ),
      child: SafeArea(
        bottom: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 40),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              GestureDetector(
                onTap: () => Navigator.pop(context),
                child: Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: Colors.white.withOpacity(0.25)),
                  ),
                  child: const Icon(Icons.arrow_back_ios_new_rounded,
                      color: Colors.white, size: 18),
                ),
              ).animate().fadeIn(duration: 300.ms).slideX(begin: -0.15, end: 0),
              const SizedBox(height: 28),
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: const Icon(Icons.diamond_rounded,
                    color: Colors.white, size: 28),
              ).animate().fadeIn(delay: 150.ms).scale(
                    begin: const Offset(0.8, 0.8),
                    curve: Curves.easeOutBack,
                  ),
              const SizedBox(height: 20),
              Text(
                'Pourquoi\nEcoRewind ?',
                style: GoogleFonts.spaceGrotesk(
                  color: Colors.white,
                  fontSize: 34,
                  fontWeight: FontWeight.w900,
                  height: 1.1,
                  letterSpacing: -1,
                ),
              ).animate().fadeIn(delay: 250.ms).slideY(begin: 0.15, end: 0),
              const SizedBox(height: 12),
              Text(
                'Découvrez tous les avantages qui font d\'EcoRewind la meilleure application de tri en Tunisie.',
                style: GoogleFonts.inter(
                  color: Colors.white.withOpacity(0.85),
                  fontSize: 15,
                  height: 1.5,
                ),
              ).animate().fadeIn(delay: 350.ms),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildAdvantagesList() {
    final advantages = [
      _AdvantageData(
        icon: Icons.bolt_rounded,
        title: 'Ultra Rapide',
        description:
            'Scanner vos déchets en moins de 2 secondes grâce à notre technologie de pointe. Pas de délai, pas d\'attente.',
        color: const Color(0xFF6366F1),
      ),
      _AdvantageData(
        icon: Icons.verified_user_rounded,
        title: '100% Sécurisé',
        description:
            'Vos données sont protégées et cryptées selon les normes internationales. Votre vie privée est notre priorité.',
        color: const Color(0xFF10B981),
      ),
      _AdvantageData(
        icon: Icons.card_giftcard_rounded,
        title: 'Récompenses Réelles',
        description:
            'Échangez vos éco-points contre des cadeaux réels, des réductions et des avantages chez nos partenaires locaux.',
        color: const Color(0xFFF59E0B),
      ),
      _AdvantageData(
        icon: Icons.groups_rounded,
        title: 'Communauté Active',
        description:
            'Rejoignez un réseau d\'éco-citoyens engagés. Partagez, apprenez et grandissez ensemble pour un avenir meilleur.',
        color: const Color(0xFF3B82F6),
      ),
      _AdvantageData(
        icon: Icons.school_rounded,
        title: 'Éducation Continue',
        description:
            'Accédez à des centaines de vidéos, quiz et articles pour maîtriser les meilleures pratiques de tri.',
        color: const Color(0xFF8B5CF6),
      ),
      _AdvantageData(
        icon: Icons.map_rounded,
        title: 'Carte Interactive',
        description:
            'Localisez les bornes de tri les plus proches en temps réel avec horaires et types de déchets acceptés.',
        color: const Color(0xFF10B981),
      ),
    ];

    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 28, 20, 0),
      child: Column(
        children: advantages.asMap().entries.map((entry) {
          final i = entry.key;
          final a = entry.value;

          return Container(
            margin: const EdgeInsets.only(bottom: 14),
            padding: const EdgeInsets.all(22),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(24),
              border: Border.all(color: a.color.withOpacity(0.1)),
              boxShadow: [
                BoxShadow(
                  color: a.color.withOpacity(0.05),
                  blurRadius: 20,
                  offset: const Offset(0, 8),
                ),
              ],
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: a.color.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Icon(a.icon, color: a.color, size: 24),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        a.title,
                        style: GoogleFonts.spaceGrotesk(
                          fontSize: 17,
                          fontWeight: FontWeight.w800,
                          color: AppTheme.deepNavy,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        a.description,
                        style: GoogleFonts.inter(
                          fontSize: 13,
                          color: AppTheme.textMuted,
                          height: 1.5,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ).animate().fadeIn(delay: (400 + i * 80).ms).slideX(begin: 0.05, end: 0);
        }).toList(),
      ),
    );
  }

  Widget _buildPromoCard() {
    return Container(
      margin: const EdgeInsets.all(20),
      padding: const EdgeInsets.all(28),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF006D5B), Color(0xFF2DD4BF)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(28),
        boxShadow: [
          BoxShadow(
            color: AppTheme.primaryGreen.withOpacity(0.3),
            blurRadius: 30,
            offset: const Offset(0, 15),
          ),
        ],
      ),
      child: Column(
        children: [
          const Icon(Icons.eco_rounded, color: Colors.white, size: 40),
          const SizedBox(height: 16),
          Text(
            'Rejoignez le mouvement',
            textAlign: TextAlign.center,
            style: GoogleFonts.spaceGrotesk(
              color: Colors.white,
              fontSize: 22,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 10),
          Text(
            'Inscrivez-vous gratuitement et recevez 200 éco-points de bienvenue.',
            textAlign: TextAlign.center,
            style: GoogleFonts.inter(
              color: Colors.white.withOpacity(0.85),
              fontSize: 14,
              height: 1.5,
            ),
          ),
        ],
      ),
    ).animate().fadeIn(delay: 800.ms).slideY(begin: 0.1, end: 0);
  }
}

class _AdvantageData {
  final IconData icon;
  final String title;
  final String description;
  final Color color;

  _AdvantageData({
    required this.icon,
    required this.title,
    required this.description,
    required this.color,
  });
}
