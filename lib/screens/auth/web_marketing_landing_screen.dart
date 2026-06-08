import 'package:flutter/material.dart';
import 'dart:ui';
import 'dart:async';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import '../../theme/app_theme.dart';
import '../../widgets/premium_widgets.dart';
import '../../widgets/auth_prompt_dialog.dart';
import '../../services/auth_service.dart';
import 'section_impact.dart';
import 'section_testimonials.dart';
import 'section_advantages.dart';
import '../client/feed_tab.dart';
import '../client/rewards_tab.dart';
import '../client/map_tab.dart';
import '../client/multimedia_tab.dart';

class WebMarketingLandingScreen extends StatefulWidget {
  const WebMarketingLandingScreen({Key? key}) : super(key: key);

  @override
  State<WebMarketingLandingScreen> createState() => _WebMarketingLandingScreenState();
}

class _WebMarketingLandingScreenState extends State<WebMarketingLandingScreen> with TickerProviderStateMixin {
  final ScrollController _scrollController = ScrollController();
  late AnimationController _floatingController;
  late AnimationController _counterController;
  double _scrollOffset = 0;

  // Animated counters
  int _animCO2 = 0;
  int _animUsers = 0;
  int _animCenters = 0;

  int _targetCO2 = 0;
  int _targetUsers = 0;
  int _targetCenters = 0;
  String _heroMembers = '...';
  String _heroKilos = '...';
  String _heroCenters = '...';

  @override
  void initState() {
    super.initState();
    _loadStats();
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

  void _loadStats() async {
    try {
      final stats = await AuthService().fetchPlatformStats();
      if (mounted && stats.isNotEmpty) {
        setState(() {
          _targetCO2 = (stats['co2_saved_kg'] ?? 0).toInt();
          _targetUsers = (stats['total_users'] ?? 0).toInt();
          _targetCenters = (stats['total_collection_points'] ?? 0).toInt();
          
          _heroMembers = '$_targetUsers';
          if (_targetUsers >= 1000) {
            _heroMembers = '${(_targetUsers / 1000).toStringAsFixed(1)}K+';
          }
          
          final waste = (stats['waste_sorted_kg'] ?? 0).toInt();
          _heroKilos = '$waste';
          if (waste >= 1000) {
            _heroKilos = '${(waste / 1000).toStringAsFixed(1)}K+';
          }
          
          _heroCenters = '$_targetCenters';
        });
        _startCounterAnimation();
      }
    } catch (e) {
      debugPrint('Error loading stats: $e');
    }
  }

  void _startCounterAnimation() {
    if (_counterController.isCompleted || _counterController.isAnimating) return;
    _counterController.forward();
    _counterController.addListener(() {
      if (mounted) {
        setState(() {
          _animCO2 = (_targetCO2 * _counterController.value).toInt();
          _animUsers = (_targetUsers * _counterController.value).toInt();
          _animCenters = (_targetCenters * _counterController.value).toInt();
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

  /// Petit avatar circulaire avec initiale — pas de réseau, pas de CORS
  Widget _miniAvatar(String initial, Color color) {
    return Container(
      width: 32, height: 32,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: color,
        border: Border.all(color: Colors.white, width: 2),
      ),
      child: Center(
        child: Text(
          initial,
          style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w800),
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

              // 2. Section Hub - Explorez (Pinterest cards)
              SliverToBoxAdapter(child: _buildSectionHub()),

              // 3. How It Works - 3 Steps
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

  // ÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉ
  // 2. SECTION HUB - Pinterest-style masonry cards
  // ÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉ
  Widget _buildSectionHub() {
    final sections = [
      _SectionCard(
        title: 'Notre Impact',
        subtitle: '$_targetCO2 points distribués',
        icon: Icons.public_rounded,
        color: const Color(0xFF3B82F6),
        gradient: [const Color(0xFF1E40AF), const Color(0xFF3B82F6)],
        page: const SectionImpact(),
        imageUrl: 'https://images.unsplash.com/photo-1532996122724-e3c354a0b15b?w=400&q=80',
        height: 220.0,
      ),
      const _SectionCard(
        title: 'Témoignages',
        subtitle: 'Ils nous font confiance',
        icon: Icons.groups_rounded,
        color: Color(0xFF8B5CF6),
        gradient: [Color(0xFF6D28D9), Color(0xFF8B5CF6)],
        page: SectionTestimonials(),
        imageUrl: 'https://images.unsplash.com/photo-1529156069898-49953e39b3ac?w=400&q=80',
        height: 260.0,
      ),
      const _SectionCard(
        title: 'Nos Avantages',
        subtitle: 'Pourquoi nous choisir',
        icon: Icons.diamond_rounded,
        color: Color(0xFFF59E0B),
        gradient: [Color(0xFFB45309), Color(0xFFF59E0B)],
        page: SectionAdvantages(),
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
                      'Découvrez tout ce que EcoRewind peut vous offrir',
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
              child: ClipOval(
                child: Image.asset(
                  'assets/images/ecorewind_logo.png',
                  width: 20,
                  height: 20,
                  fit: BoxFit.cover,
                ),
              ),
            ),
            const SizedBox(width: 10),
            Text(
              'EcoRewind',
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
      height: 720,
      width: double.infinity,
      child: Stack(
        children: [
          // Animated Ken Burns Background
          const Positioned.fill(
            child: _ContinuousKenBurns(
              imageUrls: [
                'https://images.unsplash.com/photo-1542601906990-b4d3fb778b09?w=1600&q=80',
                'https://images.unsplash.com/photo-1472214103451-9374bd1c798e?w=1600&q=80',
                'https://images.unsplash.com/photo-1518173946687-a4c8892bbd9f?w=1600&q=80',
              ],
            ),
          ),
          // Dark gradient overlay
          Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [const Color(0xFF0A3D2E).withOpacity(0.85), const Color(0xFF0F172A).withOpacity(0.92)],
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
                          [AppTheme.primaryGreen, AppTheme.accentTeal, AppTheme.secondaryGold][index].withOpacity(0.2),
                          Colors.transparent,
                        ],
                      ),
                    ),
                  ),
                );
              },
            );
          }),

          // Subtle texture
          Positioned.fill(
            child: Opacity(opacity: 0.04, child: Container(
              decoration: const BoxDecoration(image: DecorationImage(
                image: NetworkImage('https://images.unsplash.com/photo-1557683316-973673baf926?w=400&q=20'),
                fit: BoxFit.cover,
              )),
            )),
          ),

          // Content
          Padding(
            padding: const EdgeInsets.fromLTRB(28, 120, 28, 60),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                const SizedBox(height: 24),

                // Gradient title
                ShaderMask(
                  shaderCallback: (bounds) => const LinearGradient(
                    colors: [Colors.white, Color(0xFF86EFAC)],
                    begin: Alignment.topLeft, end: Alignment.bottomRight,
                  ).createShader(bounds),
                  child: Text(
                    'Triez. Gagnez.\nChangez le monde.',
                    style: GoogleFonts.spaceGrotesk(
                      color: Colors.white,
                      fontSize: 44,
                      fontWeight: FontWeight.w900,
                      height: 1.05,
                      letterSpacing: -1.5,
                    ),
                  ),
                ).animate().fadeIn(delay: 200.ms, duration: 700.ms).slideY(begin: 0.2, end: 0),

                const SizedBox(height: 20),

                Text(
                  'Transformez chaque geste de tri en récompenses réelles. Quiz, communauté, points fidélité et impact mesurable.',
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
                        icon: Icons.rocket_launch_rounded,
                        onPressed: () => Navigator.pushNamed(context, '/signup'),
                        height: 60,
                        borderRadius: 16,
                      ).animate(onPlay: (controller) => controller.repeat()).shimmer(duration: 3000.ms, color: Colors.white.withOpacity(0.4)),
                    ),
                    const SizedBox(width: 16),
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
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(16),
                          child: BackdropFilter(
                            filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
                            child: Container(
                              height: 60,
                              decoration: BoxDecoration(
                                color: Colors.white.withOpacity(0.1),
                                borderRadius: BorderRadius.circular(16),
                                border: Border.all(
                                  color: Colors.white.withOpacity(0.3),
                                  width: 1.5,
                                ),
                                boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.1), blurRadius: 10)],
                              ),
                              child: Center(
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Container(
                                      padding: const EdgeInsets.all(6),
                                      decoration: BoxDecoration(
                                        color: Colors.white.withOpacity(0.2),
                                        shape: BoxShape.circle,
                                      ),
                                      child: const Icon(Icons.play_arrow_rounded, color: Colors.white, size: 18),
                                    ),
                                    const SizedBox(width: 10),
                                    Text(
                                      'Découvrir',
                                      style: GoogleFonts.inter(
                                        color: Colors.white,
                                        fontWeight: FontWeight.w700,
                                        fontSize: 15,
                                        letterSpacing: 0.5,
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
                  ],
                ).animate().fadeIn(delay: 600.ms).slideY(begin: 0.2, end: 0),

                const SizedBox(height: 28),

                // Glassmorphism stats and social proof
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.08),
                    borderRadius: BorderRadius.circular(24),
                    border: Border.all(color: Colors.white.withOpacity(0.15)),
                    boxShadow: [
                      BoxShadow(color: Colors.black.withOpacity(0.1), blurRadius: 24, offset: const Offset(0, 8)),
                    ],
                  ),
                  child: Column(
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceAround,
                        children: [
                          _buildHeroStat(_heroMembers, 'Membres', AppTheme.primaryGreen),
                          Container(width: 1, height: 40, color: Colors.white.withOpacity(0.2)),
                          _buildHeroStat(_heroKilos, 'Kilos Triés', AppTheme.accentTeal),
                          Container(width: 1, height: 40, color: Colors.white.withOpacity(0.2)),
                          _buildHeroStat(_heroCenters, 'Centres de Tri', AppTheme.secondaryGold),
                        ],
                      ),
                      const SizedBox(height: 16),
                      Container(height: 1, color: Colors.white.withOpacity(0.1)),
                      const SizedBox(height: 16),
                      Row(children: [
                        SizedBox(width: 80, height: 32, child: Stack(
                          children: [
                            Positioned(left: 0, child: _miniAvatar('S', const Color(0xFF10B981))),
                            Positioned(left: 22, child: _miniAvatar('L', const Color(0xFF3B82F6))),
                            Positioned(left: 44, child: _miniAvatar('Y', const Color(0xFFF59E0B))),
                          ],
                        )),
                        const SizedBox(width: 12),
                        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                          Text('+$_heroMembers éco-citoyens actifs', style: GoogleFonts.inter(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w700)),
                          Row(children: [
                            ...List.generate(5, (i) => const Icon(Icons.star_rounded, color: Color(0xFFFBBF24), size: 14)),
                            const SizedBox(width: 6),
                            Text('4.9/5', style: GoogleFonts.inter(color: Colors.white.withOpacity(0.6), fontSize: 11)),
                          ]),
                        ])),
                      ]),
                    ],
                  ),
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

  Widget _buildHeroStat(String value, String label, Color color) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          value,
          style: GoogleFonts.outfit(
            color: color,
            fontSize: 22,
            fontWeight: FontWeight.w900,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          label,
          style: GoogleFonts.inter(
            color: Colors.white.withOpacity(0.8),
            fontSize: 12,
            fontWeight: FontWeight.w600,
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
            title: 'Utilisez votre badge QR',
            description: 'Présentez votre QR code unique aux bornes de tri intelligentes pour enregistrer vos dépôts.',
            icon: Icons.qr_code_rounded,
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
        'Fil Communautaire',
        'Partagez vos actions éco et inspirez votre entourage',
        FontAwesomeIcons.users,
        const Color(0xFF3B82F6),
        'https://images.unsplash.com/photo-1542601906990-b4d3fb778b09?w=400&q=80',
      ),
      _FeatureData(
        'Éducation',
        'Quiz interactifs, vidéos éducatives et articles sur le tri et le recyclage',
        FontAwesomeIcons.graduationCap,
        const Color(0xFF8B5CF6),
        'https://images.unsplash.com/photo-1503676260728-1c00da094a0b?w=400&q=80',
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
                '$_animCO2',
                'KG CO2 ÉVITÉS',
                Icons.cloud_done_rounded,
              ),
              Container(
                width: 1,
                height: 50,
                color: Colors.white.withOpacity(0.1),
              ),
              _buildCounterStat(
                '$_animUsers',
                'CITOYENS ACTIFS',
                Icons.people_alt_rounded,
              ),
              Container(
                width: 1,
                height: 50,
                color: Colors.white.withOpacity(0.1),
              ),
              _buildCounterStat(
                '$_animCenters',
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
            'Inscrivez-vous gratuitement en 30 secondes.\nBonus de bienvenue : 10 éco-points offerts. 🎁',
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

class _ContinuousKenBurns extends StatefulWidget {
  final List<String> imageUrls;
  const _ContinuousKenBurns({Key? key, required this.imageUrls}) : super(key: key);

  @override
  State<_ContinuousKenBurns> createState() => _ContinuousKenBurnsState();
}

class _ContinuousKenBurnsState extends State<_ContinuousKenBurns> with TickerProviderStateMixin {
  int _index = 0;
  late Timer _timer;
  late AnimationController _scaleController;

  @override
  void initState() {
    super.initState();
    _scaleController = AnimationController(vsync: this, duration: const Duration(seconds: 10))..forward();
    _timer = Timer.periodic(const Duration(seconds: 5), (timer) {
      if (mounted) {
        setState(() {
          _index = (_index + 1) % widget.imageUrls.length;
        });
        _scaleController.forward(from: 0);
      }
    });
  }

  @override
  void dispose() {
    _timer.cancel();
    _scaleController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 1500),
      transitionBuilder: (Widget child, Animation<double> animation) {
        return FadeTransition(opacity: animation, child: child);
      },
      child: AnimatedBuilder(
        key: ValueKey<int>(_index),
        animation: _scaleController,
        builder: (context, child) {
          return Transform.scale(
            scale: 1.0 + (_scaleController.value * 0.15), // Scale from 1.0 to 1.15
            child: child,
          );
        },
        child: Image.network(
          widget.imageUrls[_index],
          fit: BoxFit.cover,
          width: double.infinity,
          height: double.infinity,
        ),
      ),
    );
  }
}
