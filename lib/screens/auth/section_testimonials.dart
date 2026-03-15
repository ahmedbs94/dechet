import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../theme/app_theme.dart';
import '../../widgets/safe_network_image.dart';

class SectionTestimonials extends StatelessWidget {
  const SectionTestimonials({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.backgroundLight,
      body: CustomScrollView(
        physics: const BouncingScrollPhysics(),
        slivers: [
          SliverToBoxAdapter(child: _buildHeader(context)),
          SliverToBoxAdapter(child: _buildTestimonialsList()),
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
          colors: [Color(0xFF6366F1), Color(0xFF8B5CF6)],
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
                    color: Colors.white.withOpacity(0.12),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: Colors.white.withOpacity(0.15)),
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
                child: const Icon(Icons.format_quote_rounded,
                    color: Colors.white, size: 28),
              ).animate().fadeIn(delay: 150.ms).scale(
                    begin: const Offset(0.8, 0.8),
                    curve: Curves.easeOutBack,
                  ),
              const SizedBox(height: 20),
              Text(
                'Ils nous font\nconfiance',
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
                'Découvrez les témoignages de nos éco-citoyens qui transforment leur quotidien.',
                style: GoogleFonts.inter(
                  color: Colors.white.withOpacity(0.7),
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

  Widget _buildTestimonialsList() {
    final testimonials = [
      _TestimonialData(
        name: 'Samir B.',
        role: 'Citoyen, Tunis',
        quote:
            'J\'ai accumulé 2000 points en 2 semaines ! EcoRewind a changé ma façon de voir le recyclage. C\'est motivant de voir son impact grandir chaque jour.',
        avatarUrl: 'https://i.pravatar.cc/150?u=samir',
        rating: 5,
      ),
      _TestimonialData(
        name: 'Leila M.',
        role: 'Étudiante, Sousse',
        quote:
            'L\'appli est tellement intuitive. Les vidéos éducatives m\'ont appris beaucoup sur le tri. Maintenant j\'enseigne les bonnes pratiques à ma famille.',
        avatarUrl: 'https://i.pravatar.cc/150?u=leila',
        rating: 5,
      ),
      _TestimonialData(
        name: 'Youssef K.',
        role: 'Entrepreneur, Sfax',
        quote:
            'Grâce à l\'aspect communautaire, mes voisins sont désormais engagés. On partage nos progrès et c\'est devenu un vrai mouvement dans notre quartier.',
        avatarUrl: 'https://i.pravatar.cc/150?u=youssef',
        rating: 5,
      ),
      _TestimonialData(
        name: 'Amira D.',
        role: 'Enseignante, Bizerte',
        quote:
            'J\'utilise EcoRewind avec mes élèves pour les sensibiliser au recyclage. Les quiz interactifs sont parfaits pour les enfants.',
        avatarUrl: 'https://i.pravatar.cc/150?u=amira',
        rating: 5,
      ),
      _TestimonialData(
        name: 'Mehdi R.',
        role: 'Ingénieur, Tunis',
        quote:
            'La carte interactive est vraiment pratique. Je trouve toujours une borne de tri proche de chez moi ou de mon bureau.',
        avatarUrl: 'https://i.pravatar.cc/150?u=mehdi',
        rating: 4,
      ),
    ];

    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 28, 20, 0),
      child: Column(
        children: testimonials.asMap().entries.map((entry) {
          final i = entry.key;
          final t = entry.value;

          return Container(
            margin: const EdgeInsets.only(bottom: 16),
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(24),
              border: Border.all(color: Colors.grey.shade100),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.03),
                  blurRadius: 15,
                  offset: const Offset(0, 6),
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Stars
                Row(
                  children: List.generate(
                    5,
                    (starIdx) => Icon(
                      starIdx < t.rating
                          ? Icons.star_rounded
                          : Icons.star_outline_rounded,
                      color: const Color(0xFFFBBF24),
                      size: 18,
                    ),
                  ),
                ),
                const SizedBox(height: 16),

                // Quote
                Text(
                  '"${t.quote}"',
                  style: GoogleFonts.inter(
                    color: AppTheme.deepNavy,
                    fontSize: 14,
                    fontStyle: FontStyle.italic,
                    height: 1.6,
                  ),
                ),
                const SizedBox(height: 20),

                // Avatar + Info
                Row(
                  children: [
                    SafeNetworkCircleAvatar(url: t.avatarUrl, radius: 22),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            t.name,
                            style: GoogleFonts.spaceGrotesk(
                              fontWeight: FontWeight.w800,
                              fontSize: 14,
                              color: AppTheme.deepNavy,
                            ),
                          ),
                          Text(
                            t.role,
                            style: GoogleFonts.inter(
                              fontSize: 12,
                              color: AppTheme.textMuted,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: const Color(0xFF6366F1).withOpacity(0.08),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: const Icon(
                        Icons.verified_rounded,
                        color: Color(0xFF6366F1),
                        size: 18,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ).animate().fadeIn(delay: (400 + i * 100).ms).slideY(begin: 0.06, end: 0);
        }).toList(),
      ),
    );
  }
}

class _TestimonialData {
  final String name;
  final String role;
  final String quote;
  final String avatarUrl;
  final int rating;

  _TestimonialData({
    required this.name,
    required this.role,
    required this.quote,
    required this.avatarUrl,
    required this.rating,
  });
}
