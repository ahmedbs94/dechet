import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../theme/app_theme.dart';

class SectionHowItWorks extends StatelessWidget {
  const SectionHowItWorks({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.backgroundLight,
      body: CustomScrollView(
        physics: const BouncingScrollPhysics(),
        slivers: [
          // ── Header ──
          SliverToBoxAdapter(child: _buildHeader(context)),

          // ── Steps ──
          SliverToBoxAdapter(child: _buildSteps()),

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
          colors: [Color(0xFF0A3D2E), Color(0xFF0F172A)],
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
              // Back button
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

              // Visual icon
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [AppTheme.primaryGreen, AppTheme.accentTeal],
                  ),
                  borderRadius: BorderRadius.circular(20),
                  boxShadow: [
                    BoxShadow(
                      color: AppTheme.primaryGreen.withOpacity(0.4),
                      blurRadius: 20,
                      offset: const Offset(0, 8),
                    ),
                  ],
                ),
                child: const Icon(Icons.route_rounded, color: Colors.white, size: 28),
              ).animate().fadeIn(delay: 150.ms).scale(
                    begin: const Offset(0.8, 0.8),
                    curve: Curves.easeOutBack,
                  ),

              const SizedBox(height: 20),

              Text(
                'Comment\nça marche ?',
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
                '2 étapes simples pour devenir éco-citoyen et gagner des récompenses.',
                style: GoogleFonts.inter(
                  color: Colors.white.withOpacity(0.65),
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

  Widget _buildSteps() {
    final steps = [
      _StepData(
        number: '01',
        title: 'Déposez aux bornes',
        description:
            'Utilisez votre badge QR pour ouvrir les bornes de tri intelligentes. La borne mesure automatiquement vos points.',
        icon: Icons.qr_code_2_rounded,
        color: AppTheme.primaryGreen,
        tips: [
          'Présentez votre QR code à la borne',
          'La borne détecte et pèse vos déchets',
          'Vos points sont crédités instantanément',
        ],
      ),
      _StepData(
        number: '02',
        title: 'Gagnez des points',
        description:
            'Accumulez des éco-points et échangez-les contre des réductions et cadeaux chez nos partenaires.',
        icon: Icons.card_giftcard_rounded,
        color: const Color(0xFFF59E0B),
        tips: [
          'Consultez le catalogue de récompenses',
          'Échangez vos points quand vous le souhaitez',
          'Profitez de réductions exclusives',
        ],
      ),
    ];

    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 32, 20, 0),
      child: Column(
        children: steps.asMap().entries.map((entry) {
          final i = entry.key;
          final step = entry.value;

          return Container(
            margin: const EdgeInsets.only(bottom: 20),
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(28),
              border: Border.all(color: Colors.grey.shade100, width: 1.5),
              boxShadow: [
                BoxShadow(
                  color: step.color.withOpacity(0.07),
                  blurRadius: 24,
                  offset: const Offset(0, 10),
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Top row
                Row(
                  children: [
                    Container(
                      width: 60,
                      height: 60,
                      decoration: BoxDecoration(
                        color: step.color.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(18),
                      ),
                      child: Stack(
                        alignment: Alignment.center,
                        children: [
                          Icon(step.icon, color: step.color, size: 28),
                          Positioned(
                            top: 4,
                            right: 6,
                            child: Text(
                              step.number,
                              style: GoogleFonts.outfit(
                                fontSize: 10,
                                fontWeight: FontWeight.w900,
                                color: step.color.withOpacity(0.4),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 18),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'ÉTAPE ${step.number}',
                            style: GoogleFonts.inter(
                              fontSize: 10,
                              fontWeight: FontWeight.w900,
                              color: step.color,
                              letterSpacing: 2,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            step.title,
                            style: GoogleFonts.spaceGrotesk(
                              fontSize: 20,
                              fontWeight: FontWeight.w800,
                              color: AppTheme.deepNavy,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 16),

                Text(
                  step.description,
                  style: GoogleFonts.inter(
                    fontSize: 14,
                    color: AppTheme.textMuted,
                    height: 1.6,
                  ),
                ),

                const SizedBox(height: 18),

                // Tips
                ...step.tips.map((tip) => Padding(
                      padding: const EdgeInsets.only(bottom: 10),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Container(
                            margin: const EdgeInsets.only(top: 4),
                            width: 20,
                            height: 20,
                            decoration: BoxDecoration(
                              color: step.color.withOpacity(0.12),
                              shape: BoxShape.circle,
                            ),
                            child: Icon(
                              Icons.check_rounded,
                              size: 12,
                              color: step.color,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              tip,
                              style: GoogleFonts.inter(
                                fontSize: 13,
                                color: AppTheme.deepNavy,
                                height: 1.4,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ),
                        ],
                      ),
                    )),
              ],
            ),
          ).animate().fadeIn(delay: (400 + i * 150).ms, duration: 500.ms).slideY(
                begin: 0.08,
                end: 0,
              );
        }).toList(),
      ),
    );
  }
}

class _StepData {
  final String number;
  final String title;
  final String description;
  final IconData icon;
  final Color color;
  final List<String> tips;

  _StepData({
    required this.number,
    required this.title,
    required this.description,
    required this.icon,
    required this.color,
    required this.tips,
  });
}
