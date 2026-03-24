import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../widgets/safe_network_image.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import '../../theme/app_theme.dart';
import '../../widgets/premium_widgets.dart';
import '../../widgets/auth_prompt_dialog.dart';
import 'section_impact.dart';
import 'section_testimonials.dart';
import 'section_advantages.dart';
import '../client/feed_tab.dart';
import '../client/rewards_tab.dart';
import '../client/map_tab.dart';
import '../client/multimedia_tab.dart';

class MarketingLandingScreen extends StatefulWidget {
  const MarketingLandingScreen({Key? key}) : super(key: key);

  @override
  State<MarketingLandingScreen> createState() => _MarketingLandingScreenState();
}

class _MarketingLandingScreenState extends State<MarketingLandingScreen> with TickerProviderStateMixin {
  final ScrollController _scrollController = ScrollController();
  late AnimationController _floatingController;
  late AnimationController _counterController;
  double _scrollOffset = 0;

  // Animated counters
  int _animCO2 = 0;
  int _animUsers = 0;
  int _animCenters = 0;

  @override
  void initState() {
    super.initState();
    _floatingController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 4),
    )..repeat(reverse: true);

    _counterController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2000),
    );

    _scrollController.addListener(() {
      setState(() => _scrollOffset = _scrollController.offset);
    });
  }

  @override
  void dispose() {
    _floatingController.dispose();
    _counterController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _startCounterAnimation() {
    if (_counterController.isCompleted || _counterController.isAnimating) return;
    _counterController.forward();
    _counterController.addListener(() {
      if (mounted) {
        setState(() {
          _animCO2 = (1200 * _counterController.value).toInt();
          _animUsers = (850 * _counterController.value).toInt();
          _animCenters = (15 * _counterController.value).toInt();
        });
      }
    });
  }

  void _navigateTo(Widget page) {
    Navigator.push(
      context,
      PageRouteBuilder(
        pageBuilder: (context, animation, secondaryAnimation) =>
            AuthPromptWrapper(child: page),
        transitionsBuilder: (context, animation, secondaryAnimation, child) {
          return FadeTransition(
            opacity: CurvedAnimation(parent: animation, curve: Curves.easeOut),
            child: SlideTransition(
              position: Tween<Offset>(
                begin: const Offset(0, 0.03),
                end: Offset.zero,
              ).animate(CurvedAnimation(parent: animation, curve: Curves.easeOutCubic)),
              child: child,
            ),
          );
        },
        transitionDuration: const Duration(milliseconds: 400),
      ),
    );
  }

  void _showAuthDialog(String feature) {
    showGeneralDialog(
      context: context,
      barrierDismissible: true,
      barrierLabel: '',
      barrierColor: Colors.black54,
      transitionDuration: const Duration(milliseconds: 400),
      transitionBuilder: (context, a1, a2, widget) {
        return Transform.scale(
          scale: a1.value,
          child: Opacity(opacity: a1.value, child: widget),
        );
      },
      pageBuilder: (context, a1, a2) => Dialog(
        backgroundColor: Colors.transparent,
        elevation: 0,
        insetPadding: const EdgeInsets.symmetric(horizontal: 24),
        child: Container(
          constraints: const BoxConstraints(maxWidth: 400),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(32),
            boxShadow: [
              BoxShadow(
                color: AppTheme.primaryGreen.withOpacity(0.2),
                blurRadius: 40,
                offset: const Offset(0, 20),
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Top gradient strip
              Container(
                height: 6,
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    colors: [AppTheme.primaryGreen, AppTheme.accentTeal],
                  ),
                  borderRadius: BorderRadius.vertical(
                    top: Radius.circular(32),
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(32, 40, 32, 32),
                child: Column(
                  children: [
                    // Animated Icon
                    TweenAnimationBuilder<double>(
                      tween: Tween(begin: 0, end: 1),
                      duration: const Duration(milliseconds: 600),
                      curve: Curves.elasticOut,
                      builder: (context, value, child) => Transform.scale(
                        scale: value,
                        child: child,
                      ),
                      child: Container(
                        width: 80,
                        height: 80,
                        decoration: BoxDecoration(
                          gradient: const LinearGradient(
                            colors: [AppTheme.primaryGreen, AppTheme.accentTeal],
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                          ),
                          shape: BoxShape.circle,
                          boxShadow: [
                            BoxShadow(
                              color: AppTheme.primaryGreen.withOpacity(0.3),
                              blurRadius: 20,
                              offset: const Offset(0, 8),
                            ),
                          ],
                        ),
                        child: const Icon(
                          Icons.rocket_launch_rounded,
                          color: Colors.white,
                          size: 36,
                        ),
                      ),
                    ),
                    const SizedBox(height: 28),
                    Text(
                      'Débloquez "$feature"',
                      textAlign: TextAlign.center,
                      style: GoogleFonts.spaceGrotesk(
                        fontSize: 24,
                        fontWeight: FontWeight.w900,
                        color: AppTheme.deepNavy,
                        height: 1.2,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      'Créez votre compte gratuitement pour accéder à toutes les fonctionnalités et commencer votre impact écologique.',
                      textAlign: TextAlign.center,
                      style: GoogleFonts.inter(
                        color: AppTheme.textMuted,
                        fontSize: 14,
                        height: 1.6,
                      ),
                    ),
                    const SizedBox(height: 8),
                    // Benefits list
                    ...['✅ 100% gratuit', '🎁 Bonus de bienvenue', '🏆 Classements & récompenses'].map(
                      (benefit) => Padding(
                        padding: const EdgeInsets.symmetric(vertical: 4),
                        child: Text(
                          benefit,
                          style: GoogleFonts.inter(
                            fontSize: 13,
                            color: AppTheme.deepNavy,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 28),
                    PremiumButton(
                      text: 'CRÉER MON COMPTE',
                      icon: Icons.arrow_forward_rounded,
                      onPressed: () {
                        Navigator.pop(context);
                        Navigator.pushNamed(context, '/signup');
                      },
                    ),
                    const SizedBox(height: 12),
                    TextButton(
                      onPressed: () {
                        Navigator.pop(context);
                        Navigator.pushNamed(context, '/login');
                      },
                      child: RichText(
                        text: TextSpan(
                          text: 'Déjà membre ? ',
                          style: GoogleFonts.inter(
                            color: AppTheme.textMuted,
                            fontSize: 14,
                          ),
                          children: [
                            TextSpan(
                              text: 'Se connecter',
                              style: GoogleFonts.inter(
                                color: AppTheme.primaryGreen,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: Stack(
        children: [
          CustomScrollView(
            controller: _scrollController,
            physics: const BouncingScrollPhysics(),
            slivers: [
              // 1. Immersive Hero Section
              SliverToBoxAdapter(child: _buildHeroSection()),

              // 2. Section Hub — Explorez (Pinterest cards)
              SliverToBoxAdapter(child: _buildSectionHub()),

              // 3. How It Works — 3 Steps
              SliverToBoxAdapter(child: _buildHowItWorks()),

              // 4. Feature Showcase (Interactive Cards)
              SliverToBoxAdapter(child: _buildFeatureShowcase()),

              // 5. Impact Counter Banner
              SliverToBoxAdapter(child: _buildImpactCounterBanner()),

              // 6. Final CTA
              SliverToBoxAdapter(child: _buildFinalCTA()),

              const SliverToBoxAdapter(child: SizedBox(height: 32)),
            ],
          ),

          // Floating Top Bar
          _buildFloatingTopBar(),
        ],
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════
  // 2. SECTION HUB — Pinterest-style masonry cards
  // ═══════════════════════════════════════════════════════════
  Widget _buildSectionHub() {
    final sections = [
      _SectionCard(
        title: 'Notre Impact',
        subtitle: '1200 kg CO₂ évités',
        icon: Icons.public_rounded,
        color: const Color(0xFF3B82F6),
        gradient: [const Color(0xFF1E40AF), const Color(0xFF3B82F6)],
        page: const SectionImpact(),
        imageUrl: 'https://images.unsplash.com/photo-1532996122724-e3c354a0b15b?w=400&q=80',
        height: 220.0,
      ),
      _SectionCard(
        title: 'Témoignages',
        subtitle: 'Ils nous font confiance',
        icon: Icons.groups_rounded,
        color: const Color(0xFF8B5CF6),
        gradient: [const Color(0xFF6D28D9), const Color(0xFF8B5CF6)],
        page: const SectionTestimonials(),
        imageUrl: 'https://images.unsplash.com/photo-1529156069898-49953e39b3ac?w=400&q=80',
        height: 260.0,
      ),
      _SectionCard(
        title: 'Nos Avantages',
        subtitle: 'Pourquoi nous choisir',
        icon: Icons.diamond_rounded,
        color: const Color(0xFFF59E0B),
        gradient: [const Color(0xFFB45309), const Color(0xFFF59E0B)],
        page: const SectionAdvantages(),
        imageUrl: 'https://images.unsplash.com/photo-1542601906990-b4d3fb778b09?w=400&q=80',
        height: 200.0,
      ),
    ];

    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 40, 20, 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4),
            child: Row(
              children: [
                Container(
                  width: 4,
                  height: 36,
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [Color(0xFF3B82F6), Color(0xFF8B5CF6)],
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                    ),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                const SizedBox(width: 14),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Explorez',
                      style: GoogleFonts.spaceGrotesk(
                        fontSize: 28,
                        fontWeight: FontWeight.w900,
                        color: AppTheme.deepNavy,
                      ),
                    ),
                    Text(
                      'Découvrez tout ce que TriDéchet peut vous offrir',
                      style: GoogleFonts.inter(fontSize: 13, color: AppTheme.textMuted),
                    ),
                  ],
                ),
              ],
            ),
          ).animate().fadeIn(duration: 500.ms).slideX(begin: -0.05, end: 0),
          const SizedBox(height: 24),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  children: [
                    _buildPinterestCard(sections[0], 0),
                    const SizedBox(height: 14),
                    _buildPinterestCard(sections[2], 2),
                  ],
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  children: [
                    const SizedBox(height: 36),
                    _buildPinterestCard(sections[1], 1),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildPinterestCard(_SectionCard s, int index) {
    return GestureDetector(
      onTap: () => _navigateTo(s.page),
      child: Container(
        height: s.height,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(24),
          boxShadow: [
            BoxShadow(
              color: s.color.withOpacity(0.2),
              blurRadius: 20,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(24),
          child: Stack(
            fit: StackFit.expand,
            children: [
              Image.network(
                s.imageUrl,
                fit: BoxFit.cover,
                errorBuilder: (c, e, st) => Container(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: s.gradient,
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                  ),
                  child: Center(
                    child: Icon(s.icon, color: Colors.white.withOpacity(0.3), size: 48),
                  ),
                ),
              ),
              Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      Colors.black.withOpacity(0.05),
                      Colors.black.withOpacity(0.15),
                      Colors.black.withOpacity(0.65),
                    ],
                    stops: const [0.0, 0.4, 1.0],
                  ),
                ),
              ),
              Positioned(
                right: -20, top: -20,
                child: Container(
                  width: 70, height: 70,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: s.color.withOpacity(0.25),
                  ),
                ),
              ),
              Positioned(
                left: 16, right: 16, bottom: 16,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.2),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: Colors.white.withOpacity(0.25)),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(s.icon, color: Colors.white, size: 14),
                          const SizedBox(width: 6),
                          Text(s.subtitle, style: GoogleFonts.inter(
                            color: Colors.white.withOpacity(0.9), fontSize: 10, fontWeight: FontWeight.w600,
                          )),
                        ],
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(s.title, style: GoogleFonts.spaceGrotesk(
                      fontSize: 18, fontWeight: FontWeight.w900, color: Colors.white, height: 1.1,
                    )),
                    const SizedBox(height: 6),
                    Row(children: [
                      Text('Découvrir', style: GoogleFonts.inter(
                        color: Colors.white.withOpacity(0.8), fontSize: 12, fontWeight: FontWeight.w600,
                      )),
                      const SizedBox(width: 4),
                      Icon(Icons.arrow_forward_rounded, color: Colors.white.withOpacity(0.8), size: 14),
                    ]),
                  ],
                ),
              ),
              Positioned(
                top: 12, right: 12,
                child: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.9),
                    shape: BoxShape.circle,
                    boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.1), blurRadius: 8)],
                  ),
                  child: Icon(Icons.bookmark_outline_rounded, size: 16, color: s.color),
                ),
              ),
            ],
          ),
        ),
      ),
    )
        .animate()
        .fadeIn(delay: (150 + index * 150).ms, duration: 600.ms)
        .scale(
          begin: const Offset(0.92, 0.92), end: const Offset(1, 1),
          delay: (150 + index * 150).ms, duration: 700.ms, curve: Curves.easeOutBack,
        );
  }

  // ===========================================================
  // FLOATING TOP BAR
  // ===========================================================
  Widget _buildFloatingTopBar() {
    final isScrolled = _scrollOffset > 50;
    return Positioned(
      top: 0,
      left: 0,
      right: 0,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 300),
        padding: EdgeInsets.only(
          top: MediaQuery.of(context).padding.top + 8,
          left: 20,
          right: 20,
          bottom: 12,
        ),
        decoration: BoxDecoration(
          color: isScrolled ? Colors.white.withOpacity(0.95) : Colors.transparent,
          boxShadow: isScrolled ? [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 20)] : [],
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [AppTheme.primaryGreen, AppTheme.accentTeal],
                ),
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Icon(Icons.eco_rounded, color: Colors.white, size: 20),
            ),
            const SizedBox(width: 10),
            Text(
              'TriDéchet',
              style: GoogleFonts.spaceGrotesk(
                fontSize: 20,
                fontWeight: FontWeight.w900,
                color: isScrolled ? AppTheme.deepNavy : Colors.white,
              ),
            ),
            const Spacer(),
            GestureDetector(
              onTap: () => Navigator.pushNamed(context, '/login'),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                decoration: BoxDecoration(
                  color: isScrolled ? AppTheme.primaryGreen.withOpacity(0.1) : Colors.white.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: isScrolled ? AppTheme.primaryGreen.withOpacity(0.3) : Colors.white.withOpacity(0.3),
                  ),
                ),
                child: Text(
                  'Connexion',
                  style: GoogleFonts.inter(
                    color: isScrolled ? AppTheme.primaryGreen : Colors.white,
                    fontWeight: FontWeight.w700,
                    fontSize: 13,
                  ),
                ),
              ),
            ),
            const SizedBox(width: 8),
            GestureDetector(
              onTap: () => Navigator.pushNamed(context, '/signup'),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [AppTheme.primaryGreen, AppTheme.accentTeal],
                  ),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  'S\'inscrire',
                  style: GoogleFonts.inter(
                    color: Colors.white,
                    fontWeight: FontWeight.w700,
                    fontSize: 13,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ===========================================================
  // 1. HERO SECTION
  // ===========================================================
  Widget _buildHeroSection() {
    return SizedBox(
      height: 680,
      width: double.infinity,
      child: Stack(
        children: [
          // Background gradient
          Container(
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                colors: [Color(0xFF0A3D2E), Color(0xFF0F172A)],
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
              ),
            ),
          ),

          // Animated orbs
          ...List.generate(3, (index) {
            return AnimatedBuilder(
              animation: _floatingController,
              builder: (context, child) {
                final offset = _floatingController.value * 30;
                return Positioned(
                  right: -60 + (index * 80),
                  top: 80 + (index * 120) + (index.isEven ? offset : -offset),
                  child: Container(
                    width: 200 + (index * 60),
                    height: 200 + (index * 60),
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: RadialGradient(
                        colors: [
                          [AppTheme.primaryGreen, AppTheme.accentTeal, AppTheme.secondaryGold][index].withOpacity(0.15),
                          Colors.transparent,
                        ],
                      ),
                    ),
                  ),
                );
              },
            );
          }),

          // Content
          Padding(
            padding: const EdgeInsets.fromLTRB(28, 120, 28, 60),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                const SizedBox.shrink(),

                const SizedBox(height: 24),

                // Main Title
                Text(
                  'Triez. Gagnez.\nChangez le monde.',
                  style: GoogleFonts.spaceGrotesk(
                    color: Colors.white,
                    fontSize: 44,
                    fontWeight: FontWeight.w900,
                    height: 1.05,
                    letterSpacing: -1.5,
                  ),
                ).animate().fadeIn(delay: 200.ms, duration: 700.ms).slideY(begin: 0.2, end: 0),

                const SizedBox(height: 20),

                // Subtitle
                Text(
                  'La première application tunisienne qui transforme chaque geste de tri en récompenses réelles. Scanner IA, points fidélité et impact mesurable.',
                  style: GoogleFonts.inter(
                    color: Colors.white.withOpacity(0.75),
                    fontSize: 16,
                    height: 1.6,
                  ),
                ).animate().fadeIn(delay: 400.ms, duration: 600.ms),

                const SizedBox(height: 36),

                // CTA Buttons
                Row(
                  children: [
                    Expanded(
                      flex: 3,
                      child: PremiumButton(
                        text: 'COMMENCER GRATUITEMENT',
                        icon: Icons.arrow_forward_rounded,
                        onPressed: () => Navigator.pushNamed(context, '/signup'),
                        height: 56,
                        borderRadius: 16,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      flex: 2,
                      child: GestureDetector(
                        onTap: () {
                          _scrollController.animateTo(
                            700,
                            duration: const Duration(milliseconds: 800),
                            curve: Curves.easeInOut,
                          );
                        },
                        child: Container(
                          height: 56,
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(
                              color: Colors.white.withOpacity(0.3),
                              width: 1.5,
                            ),
                          ),
                          child: Center(
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(Icons.play_circle_outline_rounded, color: Colors.white.withOpacity(0.9), size: 20),
                                const SizedBox(width: 6),
                                Text(
                                  'Découvrir',
                                  style: GoogleFonts.inter(
                                    color: Colors.white,
                                    fontWeight: FontWeight.w700,
                                    fontSize: 14,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ).animate().fadeIn(delay: 600.ms).slideY(begin: 0.2, end: 0),

                const SizedBox(height: 28),

                // Social proof
                Row(
                  children: [
                    // Avatars stack
                    SizedBox(
                      width: 80,
                      height: 32,
                      child: Stack(
                        children: List.generate(3, (index) {
                          return Positioned(
                            left: index * 22.0,
                            child: Container(
                              width: 32,
                              height: 32,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                border: Border.all(color: Colors.white, width: 2),
                              ),
                              child: ClipOval(
                                child: SizedBox(
                                  width: 32,
                                  height: 32,
                                  child: SafeNetworkImage('https://i.pravatar.cc/150?u=user${index + 10}',
                                      fit: BoxFit.cover, placeholder: Container(color: Colors.grey.shade200)),
                                ),
                              ),
                            ),
                          );
                        }),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        '+850 citoyens nous ont déjà rejoints',
                        style: GoogleFonts.inter(
                          color: Colors.white.withOpacity(0.6),
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                ).animate().fadeIn(delay: 800.ms),
              ],
            ),
          ),

          // Bottom wave
          Positioned(
            bottom: -2,
            left: 0,
            right: 0,
            child: CustomPaint(
              size: Size(MediaQuery.of(context).size.width, 40),
              painter: _WavePainter(),
            ),
          ),
        ],
      ),
    );
  }

  // ===========================================================
  // 2. TRUSTED BY
  // ===========================================================
  Widget _buildTrustedBy() {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 32, horizontal: 24),
      child: Column(
        children: [
          Text(
            'SOUTENU PAR',
            style: GoogleFonts.inter(
              color: AppTheme.textMuted.withOpacity(0.5),
              fontSize: 11,
              fontWeight: FontWeight.w900,
              letterSpacing: 3,
            ),
          ),
          const SizedBox(height: 20),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              _buildPartnerLogo('Assurances\nMaghrebia', Icons.shield_rounded),
              _buildPartnerLogo('Municipalité\nde Tunis', Icons.location_city_rounded),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildPartnerLogo(String name, IconData icon) {
    return Column(
      children: [
        Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: AppTheme.backgroundSoft,
            borderRadius: BorderRadius.circular(16),
          ),
          child: Icon(icon, color: AppTheme.textMuted.withOpacity(0.4), size: 24),
        ),
        const SizedBox(height: 8),
        Text(
          name,
          textAlign: TextAlign.center,
          style: GoogleFonts.inter(
            color: AppTheme.textMuted.withOpacity(0.5),
            fontSize: 10,
            fontWeight: FontWeight.w700,
          ),
        ),
      ],
    );
  }

  // ===========================================================
  // 3. HOW IT WORKS
  // ===========================================================
  Widget _buildHowItWorks() {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 48, horizontal: 28),
      child: Column(
        children: [
          Text(
            'Comment ça marche ?',
            style: GoogleFonts.spaceGrotesk(
              fontSize: 32,
              fontWeight: FontWeight.w900,
              color: AppTheme.deepNavy,
              letterSpacing: -0.5,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            '3 étapes simples pour devenir éco-citoyen',
            style: GoogleFonts.inter(
              fontSize: 14,
              color: AppTheme.textMuted,
            ),
          ),
          const SizedBox(height: 40),
          _buildStep(
            number: '01',
            title: 'Scannez vos déchets',
            description: 'Notre IA identifie automatiquement le type de déchet grâce à la caméra de votre téléphone.',
            icon: Icons.document_scanner_rounded,
            color: const Color(0xFF6366F1),
            delay: 0,
          ),
          const SizedBox(height: 20),
          _buildStep(
            number: '02',
            title: 'Déposez aux bornes',
            description: 'Utilisez votre badge QR pour ouvrir les bornes de tri intelligentes près de chez vous.',
            icon: Icons.qr_code_2_rounded,
            color: AppTheme.primaryGreen,
            delay: 100,
          ),
          const SizedBox(height: 20),
          _buildStep(
            number: '03',
            title: 'Gagnez des points',
            description:
                'Accumulez des éco-points et échangez-les contre des réductions et cadeaux chez nos partenaires.',
            icon: Icons.card_giftcard_rounded,
            color: const Color(0xFFF59E0B),
            delay: 200,
          ),
        ],
      ),
    );
  }

  Widget _buildStep({
    required String number,
    required String title,
    required String description,
    required IconData icon,
    required Color color,
    required int delay,
  }) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: Colors.grey.shade100, width: 1.5),
        boxShadow: [
          BoxShadow(
            color: color.withOpacity(0.06),
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            width: 56,
            height: 56,
            decoration: BoxDecoration(
              color: color.withOpacity(0.1),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Stack(
              alignment: Alignment.center,
              children: [
                Icon(icon, color: color, size: 28),
                Positioned(
                  top: 2,
                  right: 4,
                  child: Text(
                    number,
                    style: GoogleFonts.outfit(
                      fontSize: 10,
                      fontWeight: FontWeight.w900,
                      color: color.withOpacity(0.4),
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 20),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: GoogleFonts.spaceGrotesk(
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                    color: AppTheme.deepNavy,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  description,
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
    ).animate().fadeIn(delay: delay.ms, duration: 500.ms).slideX(begin: 0.1, end: 0);
  }

  // ===========================================================
  // 4. FEATURE SHOWCASE
  // ===========================================================
  Widget _buildFeatureShowcase() {
    final features = [
      _FeatureData(
        'Scanner IA',
        'Identification instantanée des déchets par intelligence artificielle',
        FontAwesomeIcons.camera,
        const Color(0xFF8B5CF6),
        'https://images.unsplash.com/photo-1611532736597-de2d4265fba3?w=400&q=80',
      ),
      _FeatureData(
        'Fil Communautaire',
        'Partagez vos actions éco et inspirez votre entourage',
        FontAwesomeIcons.users,
        const Color(0xFF3B82F6),
        'https://images.unsplash.com/photo-1542601906990-b4d3fb778b09?w=400&q=80',
      ),
      _FeatureData(
        'Récompenses',
        'Échangez vos points contre des cadeaux réels et des réductions',
        FontAwesomeIcons.trophy,
        const Color(0xFFF59E0B),
        'https://images.unsplash.com/photo-1532996122724-e3c354a0b15b?w=400&q=80',
      ),
      _FeatureData(
        'Carte Interactive',
        'Localisez les bornes de tri les plus proches en temps réel',
        FontAwesomeIcons.mapLocationDot,
        const Color(0xFF10B981),
        'https://images.unsplash.com/photo-1595278069441-2cf29f8005a4?w=400&q=80',
      ),
    ];

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
      child: Column(
        children: [
          Text(
            'Fonctionnalités',
            style: GoogleFonts.spaceGrotesk(
              fontSize: 32,
              fontWeight: FontWeight.w900,
              color: AppTheme.deepNavy,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Tout ce dont vous avez besoin',
            style: GoogleFonts.inter(
              fontSize: 14,
              color: AppTheme.textMuted,
            ),
          ),
          const SizedBox(height: 28),
          ...features.asMap().entries.map((entry) {
            final i = entry.key;
            final f = entry.value;
            return Padding(
              padding: const EdgeInsets.only(bottom: 16),
              child: _buildFeatureCard(f, i),
            );
          }),
        ],
      ),
    );
  }

  Widget _buildFeatureCard(_FeatureData f, int index) {
    return GestureDetector(
      onTap: () => _navigateTo(_buildFeaturePage(f)),
      child: Container(
        height: 140,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(28),
          boxShadow: [
            BoxShadow(
              color: f.color.withOpacity(0.08),
              blurRadius: 24,
              offset: const Offset(0, 12),
            ),
          ],
          border: Border.all(color: Colors.grey.shade100, width: 1.5),
        ),
        child: Row(
          children: [
            // Image preview
            ClipRRect(
              borderRadius: const BorderRadius.horizontal(left: Radius.circular(28)),
              child: SizedBox(
                width: 120,
                height: double.infinity,
                child: Stack(
                  children: [
                    Image.network(
                      f.imageUrl,
                      fit: BoxFit.cover,
                      width: double.infinity,
                      height: double.infinity,
                      errorBuilder: (c, e, s) => Container(
                        color: f.color.withOpacity(0.1),
                        child: Icon(f.icon, color: f.color, size: 32),
                      ),
                    ),
                    Container(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.centerLeft,
                          end: Alignment.centerRight,
                          colors: [
                            Colors.transparent,
                            Colors.white.withOpacity(0.8),
                          ],
                        ),
                      ),
                    ),
                    // Lock badge
                    Positioned(
                      top: 10,
                      left: 10,
                      child: Container(
                        padding: const EdgeInsets.all(6),
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.9),
                          shape: BoxShape.circle,
                        ),
                        child: Icon(Icons.lock_rounded, size: 12, color: f.color),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            // Text content
            Expanded(
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: f.color.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Icon(f.icon, color: f.color, size: 16),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            f.title,
                            style: GoogleFonts.spaceGrotesk(
                              fontSize: 17,
                              fontWeight: FontWeight.w800,
                              color: AppTheme.deepNavy,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Text(
                      f.description,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: GoogleFonts.inter(
                        fontSize: 12,
                        color: AppTheme.textMuted,
                        height: 1.4,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            // Arrow
            Padding(
              padding: const EdgeInsets.only(right: 16),
              child: Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: f.color.withOpacity(0.08),
                  shape: BoxShape.circle,
                ),
                child: Icon(Icons.arrow_forward_rounded, color: f.color, size: 16),
              ),
            ),
          ],
        ),
      ),
    ).animate().fadeIn(delay: (index * 80).ms, duration: 500.ms).slideX(begin: 0.05, end: 0);
  }

  Widget _buildFeaturePage(_FeatureData f) {
    Widget content;
    switch (f.title) {
      case 'Fil Communautaire':
        content = const FeedTab();
        break;
      case 'Récompenses':
        content = const RewardsTab();
        break;
      case 'Carte Interactive':
        content = const MapTab();
        break;
      case 'Éducation':
        content = const MultimediaTab();
        break;
      default:
        content = const FeedTab();
    }

    return Scaffold(
      backgroundColor: Colors.grey.shade50,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        surfaceTintColor: Colors.transparent,
        leading: GestureDetector(
          onTap: () => Navigator.pop(context),
          child: Container(
            margin: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: f.color.withOpacity(0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(Icons.arrow_back_rounded, color: f.color, size: 22),
          ),
        ),
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: f.color.withOpacity(0.1),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(f.icon, color: f.color, size: 16),
            ),
            const SizedBox(width: 12),
            Text(
              f.title,
              style: GoogleFonts.spaceGrotesk(
                fontSize: 18,
                fontWeight: FontWeight.w800,
                color: AppTheme.deepNavy,
              ),
            ),
          ],
        ),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1),
          child: Container(
            height: 1,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [f.color.withOpacity(0.3), Colors.transparent],
              ),
            ),
          ),
        ),
      ),
      body: content,
    );
  }

  // ===========================================================
  // 5. IMPACT COUNTER BANNER
  // ===========================================================
  Widget _buildImpactCounterBanner() {
    // Start counter animation when this becomes visible
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollOffset > 800) {
        _startCounterAnimation();
      }
    });

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
      padding: const EdgeInsets.symmetric(vertical: 40, horizontal: 24),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF0F172A), Color(0xFF1E293B)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(32),
        boxShadow: [
          BoxShadow(
            color: AppTheme.deepNavy.withOpacity(0.3),
            blurRadius: 30,
            offset: const Offset(0, 15),
          ),
        ],
      ),
      child: Column(
        children: [
          Text(
            'NOTRE IMPACT COLLECTIF',
            style: GoogleFonts.inter(
              color: AppTheme.accentTeal,
              fontSize: 11,
              fontWeight: FontWeight.w900,
              letterSpacing: 3,
            ),
          ),
          const SizedBox(height: 28),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              _buildCounterStat(
                _animCO2 > 0 ? '$_animCO2' : '1,200',
                'KG CO₂ ÉVITÉS',
                Icons.cloud_done_rounded,
              ),
              Container(
                width: 1,
                height: 50,
                color: Colors.white.withOpacity(0.1),
              ),
              _buildCounterStat(
                _animUsers > 0 ? '$_animUsers' : '850',
                'CITOYENS ACTIFS',
                Icons.people_alt_rounded,
              ),
              Container(
                width: 1,
                height: 50,
                color: Colors.white.withOpacity(0.1),
              ),
              _buildCounterStat(
                _animCenters > 0 ? '$_animCenters' : '15',
                'CENTRES DE TRI',
                Icons.location_on_rounded,
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildCounterStat(String value, String label, IconData icon) {
    return Column(
      children: [
        Icon(icon, color: AppTheme.primaryGreen, size: 24),
        const SizedBox(height: 12),
        Text(
          value,
          style: GoogleFonts.outfit(
            color: Colors.white,
            fontSize: 28,
            fontWeight: FontWeight.w900,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          label,
          textAlign: TextAlign.center,
          style: GoogleFonts.inter(
            color: Colors.white.withOpacity(0.45),
            fontSize: 9,
            fontWeight: FontWeight.w700,
            letterSpacing: 0.5,
          ),
        ),
      ],
    );
  }

  // ===========================================================
  // 6. TESTIMONIALS
  // ===========================================================
  Widget _buildTestimonials() {
    final testimonials = [
      _Testimonial(
        'Samir B.',
        'Citoyen, Tunis',
        'J\'ai accumulé 2000 points en 2 semaines ! TriDéchet a changé ma façon de voir le recyclage.',
        'https://i.pravatar.cc/150?u=samir',
      ),
      _Testimonial(
        'Leila M.',
        'Étudiante, Sousse',
        'L\'appli est tellement intuitive. Le scanner IA est bluffant, il reconnaît tout !',
        'https://i.pravatar.cc/150?u=leila',
      ),
      _Testimonial(
        'Youssef K.',
        'Entrepreneur, Sfax',
        'Grâce à l\'aspect communautaire, mes voisins sont désormais engagés. C\'est motivant.',
        'https://i.pravatar.cc/150?u=youssef',
      ),
    ];

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 32),
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 28),
            child: Column(
              children: [
                Text(
                  'Ils nous font confiance',
                  style: GoogleFonts.spaceGrotesk(
                    fontSize: 28,
                    fontWeight: FontWeight.w900,
                    color: AppTheme.deepNavy,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Témoignages de nos éco-citoyens',
                  style: GoogleFonts.inter(
                    fontSize: 14,
                    color: AppTheme.textMuted,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),
          SizedBox(
            height: 220,
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 20),
              physics: const BouncingScrollPhysics(),
              itemCount: testimonials.length,
              itemBuilder: (context, index) {
                final t = testimonials[index];
                return Container(
                  width: 300,
                  margin: const EdgeInsets.only(right: 16),
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
                      Row(
                        children: [
                          // Stars
                          ...List.generate(
                              5,
                              (_) => const Icon(
                                    Icons.star_rounded,
                                    color: Color(0xFFFBBF24),
                                    size: 16,
                                  )),
                        ],
                      ),
                      const SizedBox(height: 16),
                      Expanded(
                        child: Text(
                          '"${t.quote}"',
                          style: GoogleFonts.inter(
                            color: AppTheme.deepNavy,
                            fontSize: 14,
                            fontStyle: FontStyle.italic,
                            height: 1.5,
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),
                      Row(
                        children: [
                          SafeNetworkCircleAvatar(url: t.avatarUrl, radius: 18),
                          const SizedBox(width: 12),
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                t.name,
                                style: GoogleFonts.manrope(
                                  fontWeight: FontWeight.w800,
                                  fontSize: 13,
                                  color: AppTheme.deepNavy,
                                ),
                              ),
                              Text(
                                t.role,
                                style: GoogleFonts.inter(
                                  fontSize: 11,
                                  color: AppTheme.textMuted,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ],
                  ),
                ).animate().fadeIn(delay: (index * 100).ms).slideX(begin: 0.1, end: 0);
              },
            ),
          ),
        ],
      ),
    );
  }

  // ===========================================================
  // 7. ADVANTAGES
  // ===========================================================
  Widget _buildAdvantagesSection() {
    final advantages = [
      _Advantage(Icons.bolt_rounded, 'Ultra Rapide', 'Scanner en moins de 2 secondes', const Color(0xFF6366F1)),
      _Advantage(
          Icons.verified_user_rounded, '100% Sécurisé', 'Données protégées et cryptées', const Color(0xFF10B981)),
      _Advantage(Icons.card_giftcard_rounded, 'Récompenses', 'Cadeaux réels et réductions', const Color(0xFFF59E0B)),
      _Advantage(Icons.groups_rounded, 'Communauté', 'Réseau d\'éco-citoyens engagés', const Color(0xFF3B82F6)),
    ];

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
      child: Column(
        children: [
          Text(
            'Pourquoi TriDéchet ?',
            style: GoogleFonts.spaceGrotesk(
              fontSize: 28,
              fontWeight: FontWeight.w900,
              color: AppTheme.deepNavy,
            ),
          ),
          const SizedBox(height: 24),
          GridView.count(
            crossAxisCount: 2,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            mainAxisSpacing: 12,
            crossAxisSpacing: 12,
            childAspectRatio: 1.0,
            children: advantages.asMap().entries.map((entry) {
              final i = entry.key;
              final a = entry.value;
              return Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: a.color.withOpacity(0.04),
                  borderRadius: BorderRadius.circular(24),
                  border: Border.all(color: a.color.withOpacity(0.1)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: a.color.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Icon(a.icon, color: a.color, size: 22),
                    ),
                    const SizedBox(height: 14),
                    Text(
                      a.title,
                      style: GoogleFonts.spaceGrotesk(
                        fontSize: 16,
                        fontWeight: FontWeight.w800,
                        color: AppTheme.deepNavy,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      a.description,
                      style: GoogleFonts.inter(
                        fontSize: 12,
                        color: AppTheme.textMuted,
                        height: 1.3,
                      ),
                    ),
                  ],
                ),
              ).animate().fadeIn(delay: (i * 80).ms).scale(begin: const Offset(0.9, 0.9));
            }).toList(),
          ),
        ],
      ),
    );
  }

  // ===========================================================
  // 8. FINAL CTA
  // ===========================================================
  Widget _buildFinalCTA() {
    return Container(
      margin: const EdgeInsets.all(24),
      padding: const EdgeInsets.symmetric(vertical: 56, horizontal: 32),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF006D5B), Color(0xFF2DD4BF)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(36),
        boxShadow: [
          BoxShadow(
            color: AppTheme.primaryGreen.withOpacity(0.3),
            blurRadius: 40,
            offset: const Offset(0, 20),
          ),
        ],
      ),
      child: Column(
        children: [
          const Icon(
            Icons.eco_rounded,
            color: Colors.white,
            size: 48,
          ),
          const SizedBox(height: 20),
          Text(
            'Prêt à faire\nla différence ?',
            textAlign: TextAlign.center,
            style: GoogleFonts.spaceGrotesk(
              color: Colors.white,
              fontSize: 34,
              fontWeight: FontWeight.w900,
              height: 1.1,
            ),
          ),
          const SizedBox(height: 16),
          Text(
            'Inscrivez-vous gratuitement en 30 secondes.\nBonus de bienvenue : 200 éco-points offerts. 🎁',
            textAlign: TextAlign.center,
            style: GoogleFonts.inter(
              color: Colors.white.withOpacity(0.85),
              fontSize: 15,
              height: 1.6,
            ),
          ),
          const SizedBox(height: 36),
          ElevatedButton(
            onPressed: () => Navigator.pushNamed(context, '/signup'),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.white,
              foregroundColor: AppTheme.primaryGreen,
              padding: const EdgeInsets.symmetric(horizontal: 48, vertical: 18),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(20),
              ),
              elevation: 8,
              shadowColor: Colors.black.withOpacity(0.2),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'REJOINDRE MAINTENANT',
                  style: GoogleFonts.spaceGrotesk(
                    fontWeight: FontWeight.w900,
                    fontSize: 15,
                    letterSpacing: 0.5,
                  ),
                ),
                const SizedBox(width: 8),
                const Icon(Icons.arrow_forward_rounded, size: 20),
              ],
            ),
          ).animate(onPlay: (c) => c.repeat()).shimmer(duration: 2.seconds, color: Colors.white.withOpacity(0.3)),
          const SizedBox(height: 20),
          TextButton(
            onPressed: () => Navigator.pushNamed(context, '/login'),
            child: Text(
              'J\'ai déjà un compte',
              style: GoogleFonts.inter(
                color: Colors.white.withOpacity(0.7),
                fontWeight: FontWeight.w600,
                decoration: TextDecoration.underline,
                decorationColor: Colors.white.withOpacity(0.3),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ===========================================================
// DATA MODELS & PAINTERS
// ===========================================================

class _FeatureData {
  final String title;
  final String description;
  final IconData icon;
  final Color color;
  final String imageUrl;

  _FeatureData(this.title, this.description, this.icon, this.color, this.imageUrl);
}

class _SectionCard {
  final String title;
  final String subtitle;
  final IconData icon;
  final Color color;
  final List<Color> gradient;
  final Widget page;
  final String imageUrl;
  final double height;

  const _SectionCard({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.color,
    required this.gradient,
    required this.page,
    this.imageUrl = '',
    this.height = 200.0,
  });
}

class _Testimonial {
  final String name;
  final String role;
  final String quote;
  final String avatarUrl;

  _Testimonial(this.name, this.role, this.quote, this.avatarUrl);
}

class _Advantage {
  final IconData icon;
  final String title;
  final String description;
  final Color color;

  _Advantage(this.icon, this.title, this.description, this.color);
}

class _WavePainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.fill;

    final path = Path()
      ..moveTo(0, size.height)
      ..lineTo(0, size.height * 0.5)
      ..quadraticBezierTo(size.width * 0.25, 0, size.width * 0.5, size.height * 0.3)
      ..quadraticBezierTo(size.width * 0.75, size.height * 0.6, size.width, size.height * 0.2)
      ..lineTo(size.width, size.height)
      ..close();

    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
