import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:google_fonts/google_fonts.dart';
import 'dart:ui';
import 'dart:async';
import '../../theme/app_theme.dart';
import '../../widgets/safe_network_image.dart';
import '../../widgets/auth_prompt_dialog.dart';
import 'section_impact.dart';
import '../client/feed_tab.dart';
import '../client/rewards_tab.dart';
import '../client/map_tab.dart';
import '../../services/auth_service.dart';

class MobileMarketingLandingScreen extends StatefulWidget {
  const MobileMarketingLandingScreen({Key? key}) : super(key: key);

  @override
  State<MobileMarketingLandingScreen> createState() => _MobileMarketingLandingScreenState();
}

class _MobileMarketingLandingScreenState extends State<MobileMarketingLandingScreen> with TickerProviderStateMixin {
  final ScrollController _scrollController = ScrollController();
  late AnimationController _bgAnimationController;
  
  String _impactSubtitle = '...';

  @override
  void initState() {
    super.initState();
    // Animation controller for the scroll down indicator
    _bgAnimationController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    )..repeat(reverse: true);
    
    _loadStats();
  }

  void _loadStats() async {
    try {
      final stats = await AuthService().fetchPlatformStats();
      if (mounted && stats.isNotEmpty) {
        setState(() {
          final members = (stats['total_users'] ?? 0).toInt();
          _impactSubtitle = '$members membres actifs';
        });
      }
    } catch (e) {
      debugPrint('Error loading stats: $e');
    }
  }

  @override
  void dispose() {
    _bgAnimationController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _navigateTo(Widget page, {bool requiresAuth = false}) {
    Navigator.push(
      context,
      PageRouteBuilder(
        pageBuilder: (context, animation, secondaryAnimation) =>
            requiresAuth ? AuthPromptWrapper(child: page) : page,
        transitionsBuilder: (context, animation, secondaryAnimation, child) {
          return FadeTransition(
            opacity: CurvedAnimation(parent: animation, curve: Curves.easeOut),
            child: SlideTransition(
              position: Tween<Offset>(
                begin: const Offset(0, 0.05),
                end: Offset.zero,
              ).animate(CurvedAnimation(parent: animation, curve: Curves.easeOutCubic)),
              child: child,
            ),
          );
        },
        transitionDuration: const Duration(milliseconds: 500),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: Stack(
        children: [
          // Main Scrollable Content
          CustomScrollView(
            controller: _scrollController,
            physics: const BouncingScrollPhysics(),
            slivers: [
              SliverToBoxAdapter(child: _buildMobileHero()),
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.only(top: 40, bottom: 20, left: 24, right: 24),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Explorez',
                        style: GoogleFonts.spaceGrotesk(
                          fontSize: 36,
                          fontWeight: FontWeight.w900,
                          color: AppTheme.deepNavy,
                          letterSpacing: -1,
                        ),
                      ).animate().fadeIn(duration: 600.ms).slideX(begin: -0.1),
                      const SizedBox(height: 8),
                      Text(
                        'Découvrez tout l\'univers EcoRewind inspiré par vous.',
                        style: GoogleFonts.inter(
                          fontSize: 15,
                          color: AppTheme.textMuted,
                          height: 1.4,
                        ),
                      ).animate().fadeIn(delay: 200.ms).slideX(begin: -0.1),
                    ],
                  ),
                ),
              ),
              SliverToBoxAdapter(child: _buildPinterestGrid()),
              const SliverToBoxAdapter(child: SizedBox(height: 140)), // Padding for bottom bar
            ],
          ),

          // Sticky Bottom Actions
          Positioned(
            bottom: 0,
            left: 0,
            right: 0,
            child: _buildStickyBottomBar(),
          ),
        ],
      ),
    );
  }

  Widget _buildMobileHero() {
    final height = MediaQuery.of(context).size.height; // Full height hero
    return SizedBox(
      height: height,
      width: double.infinity,
      child: Stack(
        fit: StackFit.expand,
        children: [
          // Fond avec image illustrative login_hero_new.png et zoom lent
          AnimatedBuilder(
            animation: _bgAnimationController,
            builder: (context, child) {
              return Transform.scale(
                scale: 1.0 + (_bgAnimationController.value * 0.04),
                child: child,
              );
            },
            child: Image.asset(
              'assets/images/login_hero_new.png',
              fit: BoxFit.cover,
              errorBuilder: (context, error, stackTrace) => Container(
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      Color(0xFF0F2D1F),
                      Color(0xFF0A1628),
                    ],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                ),
              ),
            ),
          ),
          
          // Gradient Overlay
          Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  Colors.black.withOpacity(0.1),
                  Colors.black.withOpacity(0.4),
                  const Color(0xFF0F172A).withOpacity(1.0),
                ],
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                stops: const [0.0, 0.6, 1.0],
              ),
            ),
          ),

          // Content
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
              child: SingleChildScrollView(
                physics: const BouncingScrollPhysics(),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    // Title
                    Text(
                      'Triez.\nGagnez.\nChangez le monde.',
                      style: GoogleFonts.spaceGrotesk(
                        color: Colors.white,
                        fontSize: 52,
                        fontWeight: FontWeight.w900,
                        height: 1.05,
                        letterSpacing: -1.5,
                      ),
                    ).animate().fadeIn(delay: 400.ms).slideY(begin: 0.2),

                    const SizedBox(height: 20),

                    // Description
                    Text(
                      'Transformez chaque geste de tri en récompenses réelles. Rejoignez la communauté.',
                      style: GoogleFonts.inter(
                        color: Colors.white.withOpacity(0.8),
                        fontSize: 16,
                        height: 1.5,
                      ),
                    ).animate().fadeIn(delay: 600.ms).slideY(begin: 0.2),
                    
                    const SizedBox(height: 30),

                    // Scroll Down Indicator
                    Center(
                      child: AnimatedBuilder(
                        animation: _bgAnimationController,
                        builder: (context, child) {
                          return Transform.translate(
                            offset: Offset(0, _bgAnimationController.value * 15),
                            child: child,
                          );
                        },
                        child: Column(
                          children: [
                            Text('Découvrir', style: GoogleFonts.inter(color: Colors.white54, fontSize: 12, fontWeight: FontWeight.w600, letterSpacing: 1.5)),
                            const SizedBox(height: 8),
                            const Icon(Icons.keyboard_arrow_down_rounded, color: Colors.white54, size: 28),
                          ],
                        ),
                      ),
                    ).animate().fadeIn(delay: 1000.ms),
                    
                    SizedBox(height: MediaQuery.of(context).size.height < 600 ? 20 : (MediaQuery.of(context).size.height < 700 ? 50 : 100)), // Space for bottom bar
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPinterestGrid() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Column(
              children: [
                _buildPinCard(
                  title: 'Impact Reel',
                  subtitle: _impactSubtitle,
                  assetImage: 'assets/images/card_impact.png',
                  fallbackGrad: const [Color(0xFF064E3B), Color(0xFF0D9488)],
                  fallbackIcon: Icons.bar_chart_rounded,
                  height: 260,
                  page: const SectionImpact(),
                  isAuthRequired: true,
                  delay: 100,
                ),
                const SizedBox(height: 16),
                _buildPinCard(
                  title: 'Recompenses',
                  subtitle: 'Cadeaux exclusifs',
                  assetImage: 'assets/images/card_rewards.png',
                  fallbackGrad: const [Color(0xFF3B0764), Color(0xFF7C3AED)],
                  fallbackIcon: Icons.card_giftcard_rounded,
                  height: 320,
                  page: const RewardsTab(),
                  isAuthRequired: true,
                  delay: 200,
                ),
              ],
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              children: [
                const SizedBox(height: 40),
                _buildPinCard(
                  title: 'Communaute',
                  subtitle: "Rejoignez le mouv'",
                  assetImage: 'assets/images/card_community.png',
                  fallbackGrad: const [Color(0xFF1E1B4B), Color(0xFF2563EB)],
                  fallbackIcon: Icons.groups_rounded,
                  height: 300,
                  page: const FeedTab(),
                  isAuthRequired: true,
                  delay: 300,
                ),
                const SizedBox(height: 16),
                _buildPinCard(
                  title: 'Carte',
                  subtitle: 'Trouvez les bornes',
                  assetImage: 'assets/images/card_map.png',
                  fallbackGrad: const [Color(0xFF052E16), Color(0xFF059669)],
                  fallbackIcon: Icons.map_rounded,
                  height: 240,
                  page: const MapTab(),
                  isAuthRequired: true,
                  delay: 400,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPinCard({
    required String title,
    required String subtitle,
    required String assetImage,
    required List<Color> fallbackGrad,
    required IconData fallbackIcon,
    required double height,
    required Widget page,
    bool isAuthRequired = false,
    required int delay,
  }) {
    return GestureDetector(
      onTap: () => _navigateTo(page, requiresAuth: isAuthRequired),
      child: Container(
        height: height,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(24),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.18),
              blurRadius: 20,
              offset: const Offset(0, 10),
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(24),
          child: Stack(
            fit: StackFit.expand,
            children: [
              // Image illustrative de la fonctionnalite
              Image.asset(
                assetImage,
                fit: BoxFit.cover,
                errorBuilder: (c, e, s) => Container(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: fallbackGrad,
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                  ),
                  child: Center(child: Icon(fallbackIcon, color: Colors.white54, size: 48)),
                ),
              ),
              // Overlay sombre pour lisibilite
              Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      Colors.transparent,
                      Colors.black.withOpacity(0.75),
                    ],
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    stops: const [0.4, 1.0],
                  ),
                ),
              ),
              Positioned(
                left: 16, right: 16, bottom: 16,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.18),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        subtitle,
                        style: GoogleFonts.inter(
                          color: Colors.white,
                          fontSize: 10,
                          fontWeight: FontWeight.w700,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      title,
                      style: GoogleFonts.spaceGrotesk(
                        color: Colors.white,
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        height: 1.1,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ).animate().fadeIn(delay: delay.ms, duration: 600.ms).slideY(begin: 0.1, end: 0),
    );
  }

  Widget _buildStickyBottomBar() {
    return ClipRRect(
      borderRadius: const BorderRadius.only(
        topLeft: Radius.circular(32),
        topRight: Radius.circular(32),
      ),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 15, sigmaY: 15),
        child: Container(
          padding: EdgeInsets.only(
            left: 24,
            right: 24,
            top: 24,
            bottom: MediaQuery.of(context).padding.bottom + 24,
          ),
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.9),
            border: Border(
              top: BorderSide(color: Colors.white.withOpacity(0.5), width: 1.5),
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.05),
                blurRadius: 20,
                offset: const Offset(0, -5),
              ),
            ],
          ),
          child: Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: () => Navigator.pushNamed(context, '/login'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppTheme.deepNavy,
                    padding: const EdgeInsets.symmetric(vertical: 18),
                    side: BorderSide(color: Colors.grey.shade300, width: 1.5),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(20),
                    ),
                  ),
                  child: Text(
                    'CONNEXION',
                    style: GoogleFonts.spaceGrotesk(
                      fontWeight: FontWeight.w800,
                      fontSize: 14,
                      letterSpacing: 0.5,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: ElevatedButton(
                  onPressed: () => Navigator.pushNamed(context, '/signup'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.primaryGreen,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 18),
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(20),
                    ),
                  ),
                  child: Text(
                    'S\'INSCRIRE',
                    style: GoogleFonts.spaceGrotesk(
                      fontWeight: FontWeight.w800,
                      fontSize: 14,
                      letterSpacing: 0.5,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    ).animate().fadeIn(delay: 800.ms).slideY(begin: 1.0, end: 0);
  }
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
            scale: 1.0 + (_scaleController.value * 0.15),
            child: child,
          );
        },
        child: SafeNetworkImage(
          widget.imageUrls[_index],
          fit: BoxFit.cover,
          width: double.infinity,
          height: double.infinity,
        ),
      ),
    );
  }
}
