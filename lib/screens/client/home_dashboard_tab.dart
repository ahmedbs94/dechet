import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:http/http.dart' as http;
import '../../theme/app_theme.dart';
import '../../models/user_model.dart';
import '../../models/post_model.dart';
import '../../services/auth_service.dart';
import '../../constants.dart';
import '../../widgets/auth_prompt_dialog.dart';
import '../../screens/client/notifications_screen.dart';
import '../../screens/client/bin_scanner_screen.dart';
import '../../features/scan/scan_history_screen.dart';

class HomeDashboardTab extends StatefulWidget {
  final Function(int) onNavigate;

  const HomeDashboardTab({Key? key, required this.onNavigate}) : super(key: key);

  @override
  State<HomeDashboardTab> createState() => _HomeDashboardTabState();
}

class _HomeDashboardTabState extends State<HomeDashboardTab> with SingleTickerProviderStateMixin {
  late AnimationController _counterCtrl;
  final AuthService _authService = AuthService();

  // Stats dynamiques
  double _co2 = 0;
  double _waste = 0;
  int _trees = 0;
  bool _statsLoaded = false;

  @override
  void initState() {
    super.initState();
    _counterCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1800),
    );
    _counterCtrl.addListener(() {
      if (mounted) setState(() {});
    });
    _fetchStats();
    _refreshUserScore();
  }

  /// Synchronise le globalScore depuis le backend
  Future<void> _refreshUserScore() async {
    if (!AuthState.isLoggedIn) return;
    try {
      final userData = await _authService.fetchUserProfile();
      if (userData != null && mounted) {
        final u = AuthState.currentUser;
        if (u != null) {
          final newScore = (userData['global_score'] as num?)?.toDouble() ?? u.globalScore;
          if (newScore != u.globalScore) {
            AuthState.currentUser = User(
              id: u.id,
              name: u.name,
              email: u.email,
              role: u.role,
              points: u.points,
              globalScore: newScore,
              avatarUrl: u.avatarUrl,
              qrCode: u.qrCode,
            );
            setState(() {});
          }
        }
      }
    } catch (_) {}
  }

  Future<void> _fetchStats() async {
    try {
      final res = await http
          .get(Uri.parse('${ApiConstants.baseUrl}/stats'))
          .timeout(const Duration(seconds: 8));
      if (res.statusCode == 200) {
        final data = json.decode(res.body);
        if (mounted) {
          setState(() {
            _co2 = (data['co2_saved_kg'] as num?)?.toDouble() ?? 0;
            _waste = (data['waste_sorted_kg'] as num?)?.toDouble() ?? 0;
            _trees = (data['trees_equivalent'] as num?)?.toInt() ?? 0;
            _statsLoaded = true;
          });
          _counterCtrl.forward();
        }
      }
    } catch (_) {
      if (mounted) {
        setState(() { _co2 = 0; _waste = 0; _trees = 0; _statsLoaded = true; });
        _counterCtrl.forward();
      }
    }
  }

  String _fmt(double v, {bool kg = false}) {
    if (v >= 1000000) return '${(v / 1000000).toStringAsFixed(1)}M${kg ? ' T' : ''}';
    if (v >= 1000) return '${(v / 1000).toStringAsFixed(1)}k${kg ? ' T' : ''}';
    return '${v.toInt()}${kg ? ' kg' : ''}';
  }

  String _getLevelBadge(double score) {
    if (score >= 5000) return 'Légende Éco 👑';
    if (score >= 2000) return 'Champion Vert 🏆';
    return 'Éco-Citoyen 🪙';
  }


  @override
  void dispose() {
    _counterCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final user = AuthState.currentUser;

    return Scaffold(
      backgroundColor: AppTheme.backgroundSoft,
      body: CustomScrollView(
        physics: const BouncingScrollPhysics(),
        slivers: [
          _buildSliverAppBar(user),
          SliverToBoxAdapter(child: _buildWelcomeHero(user)),
          SliverToBoxAdapter(child: _buildTipOfTheDay()),
          SliverToBoxAdapter(child: _buildQuickActionsGrid()),
          SliverToBoxAdapter(child: _buildVlogSpotlight()),
          SliverToBoxAdapter(child: _buildGlobalImpact()),
          SliverToBoxAdapter(child: _buildFeedTeaser()),
          const SliverToBoxAdapter(child: SizedBox(height: 100)),
        ],
      ),
    );
  }

  Widget _buildSliverAppBar(User? user) {
    return SliverAppBar(
      expandedHeight: 0,
      floating: true,
      pinned: true,
      backgroundColor: Colors.white,
      surfaceTintColor: Colors.transparent,
      elevation: 0,
      shadowColor: Colors.black.withOpacity(0.06),
      forceElevated: true,
      centerTitle: false,
      automaticallyImplyLeading: false,
      titleSpacing: 0,
      title: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        child: Row(children: [
          // Logo pill
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [AppTheme.primaryGreen, AppTheme.accentTeal],
                begin: Alignment.topLeft, end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(10),
              boxShadow: [BoxShadow(
                color: AppTheme.primaryGreen.withOpacity(0.3),
                blurRadius: 8, offset: const Offset(0, 3),
              )],
            ),
            child: Row(mainAxisSize: MainAxisSize.min, children: [
              const Icon(Icons.eco_rounded, color: Colors.white, size: 15),
              const SizedBox(width: 5),
              Text('EcoRewind', style: GoogleFonts.outfit(
                fontWeight: FontWeight.w900, fontSize: 14, color: Colors.white,
                letterSpacing: -0.2)),
            ]),
          ),
        ]),
      ),
      actions: [
        // Notification bell
        Padding(
          padding: const EdgeInsets.only(right: 4),
          child: IconButton(
            onPressed: () => Navigator.push(context,
              MaterialPageRoute(builder: (_) => const NotificationsScreen())),
            icon: Stack(clipBehavior: Clip.none, children: [
              const Icon(Icons.notifications_outlined, color: Color(0xFF475569), size: 24),
              Positioned(top: -2, right: -2, child: Container(
                width: 8, height: 8,
                decoration: const BoxDecoration(
                  color: AppTheme.primaryGreen, shape: BoxShape.circle),
              )),
            ]),
            tooltip: 'Notifications',
          ),
        ),
        // Avatar
        Padding(
          padding: const EdgeInsets.only(right: 16),
          child: GestureDetector(
            onTap: () => widget.onNavigate(4),
            child: Hero(
              tag: 'profile_avatar',
              child: Container(
                width: 36, height: 36,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: const LinearGradient(
                    colors: [AppTheme.primaryGreen, AppTheme.accentTeal],
                    begin: Alignment.topLeft, end: Alignment.bottomRight,
                  ),
                  boxShadow: [BoxShadow(
                    color: AppTheme.primaryGreen.withOpacity(0.35),
                    blurRadius: 8, offset: const Offset(0, 2),
                  )],
                ),
                child: ClipOval(
                  child: (user?.avatarUrl != null && user!.avatarUrl.isNotEmpty)
                      ? Image.network(user.avatarUrl, fit: BoxFit.cover,
                          errorBuilder: (_, __, ___) => _avatarFallback(user.name))
                      : _avatarFallback(user?.name ?? 'E'),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _avatarFallback(String name) => Center(
    child: Text(name[0].toUpperCase(), style: GoogleFonts.outfit(
      color: Colors.white, fontWeight: FontWeight.w800, fontSize: 15)),
  );

  Widget _buildWelcomeHero(User? user) {
    final name = user?.name ?? 'Éco-Citoyen';
    return Container(
      margin: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(28),
        gradient: const LinearGradient(
          colors: [Color(0xFF052E24), AppTheme.deepNavy],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        boxShadow: [
          BoxShadow(
            color: AppTheme.deepNavy.withOpacity(0.3),
            blurRadius: 30,
            offset: const Offset(0, 15),
          ),
        ],
      ),
      child: Stack(
        children: [
          // Decorative circles
          Positioned(
            top: -30,
            right: -20,
            child: Container(
              width: 120,
              height: 120,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: AppTheme.primaryGreen.withOpacity(0.15),
              ),
            ),
          ),
          Positioned(
            bottom: -20,
            left: -15,
            child: Container(
              width: 80,
              height: 80,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: AppTheme.accentTeal.withOpacity(0.1),
              ),
            ),
          ),

          Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Bonjour 👋',
                            style: GoogleFonts.inter(
                              color: Colors.white.withOpacity(0.6),
                              fontSize: 13,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            name,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: GoogleFonts.spaceGrotesk(
                              color: Colors.white,
                              fontSize: 24,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            _getLevelBadge(user?.globalScore ?? 0.0),
                            style: GoogleFonts.inter(
                              color: AppTheme.accentMint,
                              fontSize: 12,
                              fontWeight: FontWeight.w800,
                              letterSpacing: 0.2,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          colors: [AppTheme.primaryGreen, AppTheme.accentTeal],
                        ),
                        shape: BoxShape.circle,
                        boxShadow: [
                          BoxShadow(
                            color: AppTheme.primaryGreen.withOpacity(0.4),
                            blurRadius: 16,
                            offset: const Offset(0, 6),
                          ),
                        ],
                      ),
                      child: const Icon(FontAwesomeIcons.leaf, color: Colors.white, size: 20),
                    ),
                  ],
                ),
                const SizedBox(height: 24),

                // Score card
                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.08),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                      color: Colors.white.withOpacity(0.1),
                    ),
                  ),
                  child: Row(
                    children: [
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'SCORE ÉCO ACTUEL',
                            style: GoogleFonts.inter(
                              color: AppTheme.accentTeal,
                              fontSize: 10,
                              fontWeight: FontWeight.w900,
                              letterSpacing: 1.5,
                            ),
                          ),
                          const SizedBox(height: 6),
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.end,
                            children: [
                              Text(
                                user?.globalScore.toStringAsFixed(1) ?? '0.0',
                                style: GoogleFonts.outfit(
                                  color: Colors.white,
                                  fontSize: 32,
                                  fontWeight: FontWeight.w900,
                                ),
                              ),
                              Padding(
                                padding: const EdgeInsets.only(bottom: 5, left: 4),
                                child: Text(
                                  'pts',
                                  style: GoogleFonts.inter(
                                    color: Colors.white.withOpacity(0.5),
                                    fontSize: 14,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                      const Spacer(),
                      GestureDetector(
                        onTap: () => Navigator.pushNamed(context, '/rewards'),
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                          decoration: BoxDecoration(
                            gradient: const LinearGradient(
                              colors: [AppTheme.primaryGreen, AppTheme.accentTeal],
                            ),
                            borderRadius: BorderRadius.circular(14),
                            boxShadow: [
                              BoxShadow(
                                color: AppTheme.primaryGreen.withOpacity(0.3),
                                blurRadius: 12,
                                offset: const Offset(0, 4),
                              ),
                            ],
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                'Détails',
                                style: GoogleFonts.inter(
                                  color: Colors.white,
                                  fontWeight: FontWeight.w700,
                                  fontSize: 13,
                                ),
                              ),
                              const SizedBox(width: 4),
                              const Icon(Icons.arrow_forward_rounded, color: Colors.white, size: 16),
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
        ],
      ),
    ).animate().fadeIn(duration: 600.ms).slideY(begin: 0.1, end: 0);
  }

  Widget _buildTipOfTheDay() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 20),
      decoration: BoxDecoration(
        color: Colors.amber.shade50.withOpacity(0.4),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.amber.shade200.withOpacity(0.5), width: 1.5),
        boxShadow: [
          BoxShadow(
            color: Colors.amber.shade500.withOpacity(0.03),
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(20),
        child: Padding(
          padding: const EdgeInsets.all(18),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: Colors.amber.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(Icons.lightbulb_rounded, color: Color(0xFFD97706), size: 20),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Conseil du jour 💡',
                      style: GoogleFonts.outfit(
                        fontWeight: FontWeight.w800,
                        fontSize: 14,
                        color: const Color(0xFF92400E),
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'Rincez vos contenants en plastique avant de les jeter pour un meilleur recyclage.',
                      style: GoogleFonts.inter(
                        fontSize: 12,
                        color: const Color(0xFFB45309),
                        height: 1.4,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    ).animate().fadeIn(delay: 300.ms).slideX(begin: -0.05, end: 0);
  }

  Widget _buildQuickActionsGrid() {
    return Padding(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Services Rapides',
            style: GoogleFonts.spaceGrotesk(
              fontSize: 20,
              fontWeight: FontWeight.w800,
              color: AppTheme.deepNavy,
            ),
          ),
          const SizedBox(height: 16),
          // Bouton Scanner en vedette (pleine largeur)
          _buildScannerBanner(),
          const SizedBox(height: 12),
          GridView.count(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            crossAxisCount: 2,
            mainAxisSpacing: 12,
            crossAxisSpacing: 12,
            childAspectRatio: 1.45,
            children: [
              _buildActionCard(
                'Centres de Tri',
                Icons.location_on_rounded,
                const Color(0xFFF59E0B),
                3,
              ),
              _buildActionCard(
                'Quiz & Apprendre',
                Icons.school_rounded,
                const Color(0xFF3B82F6),
                1,
              ),
              _buildActionCard(
                'Fil Citoyen',
                Icons.people_alt_rounded,
                const Color(0xFF8B5CF6),
                0,
              ),
              _buildActionCard(
                'Boutique',
                Icons.shopping_bag_rounded,
                const Color(0xFFEF4444),
                2,
              ),
            ],
          ),
        ],
      ),
    );
  }

  /// Bannière Scanner QR pleine largeur avec animation pulse
  Widget _buildScannerBanner() {
    return GestureDetector(
      onTap: () {
        if (!AuthState.isLoggedIn) {
          AuthPromptDialog.show(context: context);
          return;
        }
        Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => const BinScannerScreen()),
        );
      },
      child: Container(
        height: 76,
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            colors: [Color(0xFF052E24), AppTheme.deepNavy],
            begin: Alignment.centerLeft,
            end: Alignment.centerRight,
          ),
          borderRadius: BorderRadius.circular(22),
          boxShadow: [
            BoxShadow(
              color: AppTheme.primaryGreen.withOpacity(0.22),
              blurRadius: 18,
              offset: const Offset(0, 6),
            ),
          ],
        ),
        child: Row(
          children: [
            const SizedBox(width: 18),
            // Icône animée
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [AppTheme.primaryGreen, AppTheme.accentTeal],
                ),
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: AppTheme.primaryGreen.withOpacity(0.4),
                    blurRadius: 12,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: const Icon(
                Icons.qr_code_scanner_rounded,
                color: Colors.white,
                size: 24,
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Scanner une Poubelle',
                    style: GoogleFonts.outfit(
                      color: Colors.white,
                      fontWeight: FontWeight.w900,
                      fontSize: 15,
                    ),
                  ),
                  Text(
                    'Gagnez des points éco instantanément',
                    style: GoogleFonts.inter(
                      color: AppTheme.accentMint.withOpacity(0.8),
                      fontSize: 11,
                    ),
                  ),
                ],
              ),
            ),
            // Bouton historique
            GestureDetector(
              onTap: () {
                if (!AuthState.isLoggedIn) {
                  AuthPromptDialog.show(context: context);
                  return;
                }
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const ScanHistoryScreen()),
                );
              },
              child: Container(
                margin: const EdgeInsets.only(right: 14),
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.08),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.white.withOpacity(0.15)),
                ),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(Icons.history_rounded, color: Colors.white70, size: 16),
                    const SizedBox(height: 2),
                    Text(
                      'Historique',
                      style: GoogleFonts.inter(
                        color: Colors.white54,
                        fontSize: 9,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    ).animate().fadeIn(delay: 150.ms).slideY(begin: 0.1, end: 0);
  }

  Widget _buildActionCard(
    String title,
    IconData icon,
    Color color,
    int targetTab, {
    bool isSpecial = false,
  }) {
    return GestureDetector(
      onTap: () {
        // Garde d'authentification : les visiteurs non connectés voient le dialogue
        if (!AuthState.isLoggedIn) {
          AuthPromptDialog.show(context: context);
          return;
        }
        if (title.contains('Apprendre')) {
          Navigator.pushNamed(context, '/multimedia');
        }
        widget.onNavigate(targetTab);
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: isSpecial ? color.withOpacity(0.06) : Colors.white,
          borderRadius: BorderRadius.circular(22),
          border: Border.all(
            color: isSpecial ? color.withOpacity(0.15) : Colors.grey.shade100,
            width: 1.5,
          ),
          boxShadow: isSpecial
              ? [
                  BoxShadow(
                    color: color.withOpacity(0.08),
                    blurRadius: 15,
                    offset: const Offset(0, 6),
                  ),
                ]
              : [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.02),
                    blurRadius: 8,
                    offset: const Offset(0, 4),
                  )
                ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: color.withOpacity(0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(icon, color: color, size: 20),
            ),
            const SizedBox(height: 8),
            Expanded(
              child: Align(
                alignment: Alignment.bottomLeft,
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  alignment: Alignment.centerLeft,
                  child: Text(
                    title,
                    style: GoogleFonts.outfit(
                      fontSize: 14,
                      fontWeight: FontWeight.w800,
                      color: AppTheme.deepNavy,
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    ).animate().scale(delay: (200 + targetTab * 60).ms, duration: 400.ms, curve: Curves.easeOutBack);
  }

  Widget _buildVlogSpotlight() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Espace Éducation',
                style: GoogleFonts.spaceGrotesk(
                  fontSize: 20,
                  fontWeight: FontWeight.w800,
                  color: AppTheme.deepNavy,
                ),
              ),
              GestureDetector(
                onTap: () => Navigator.pushNamed(context, '/multimedia'),
                child: Row(
                  children: [
                    Text(
                      'Voir tout',
                      style: GoogleFonts.inter(
                        fontWeight: FontWeight.w700,
                        color: AppTheme.primaryGreen,
                        fontSize: 13,
                      ),
                    ),
                    const Icon(Icons.chevron_right_rounded, size: 18, color: AppTheme.primaryGreen),
                  ],
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        SizedBox(
          height: 200,
          child: ListView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 12),
            physics: const BouncingScrollPhysics(),
            children: [
              _buildVlogCard(
                'Le Futur du Recyclage',
                'https://images.unsplash.com/photo-1532996122724-e3c354a0b15b?w=400&q=80',
                'Vidéo • 4 min',
              ),
              _buildVlogCard(
                'L\'Essentiel du Tri',
                'https://images.unsplash.com/photo-1542601906990-b4d3fb778b09?w=400&q=80',
                'Article • 3 min',
              ),
              _buildVlogCard(
                'Quiz Hebdo',
                'https://images.unsplash.com/photo-1595278069441-2cf29f8005a4?w=400&q=80',
                'Quiz • +100 pts',
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildVlogCard(String title, String image, String meta) {
    return Container(
      width: 260,
      margin: const EdgeInsets.symmetric(horizontal: 8),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.08),
            blurRadius: 15,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(24),
        child: Stack(
          children: [
            Image.network(
              image,
              fit: BoxFit.cover,
              width: double.infinity,
              height: double.infinity,
              errorBuilder: (c, e, s) => Container(
                color: AppTheme.primaryGreen.withOpacity(0.1),
                child: const Center(
                  child: Icon(Icons.play_circle_fill_rounded, color: AppTheme.primaryGreen, size: 40),
                ),
              ),
            ),
            Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [Colors.transparent, Colors.black.withOpacity(0.85)],
                ),
              ),
            ),
            Positioned(
              bottom: 16,
              left: 16,
              right: 16,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: AppTheme.primaryGreen,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      meta.toUpperCase(),
                      style: GoogleFonts.inter(
                        color: Colors.white,
                        fontSize: 9,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 0.5,
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    title,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: GoogleFonts.spaceGrotesk(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildGlobalImpact() {
    const curve = Curves.easeOutCubic;
    final t = _statsLoaded ? curve.transform(_counterCtrl.value) : 0.0;
    final co2Val = _co2 * t;
    final wasteVal = _waste * t;
    final treesVal = (_trees * t).toInt();

    return Container(
      margin: const EdgeInsets.all(20),
      padding: const EdgeInsets.all(28),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF0F172A), Color(0xFF1E293B)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(28),
        boxShadow: [
          BoxShadow(
            color: AppTheme.deepNavy.withOpacity(0.25),
            blurRadius: 20,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Column(
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: AppTheme.primaryGreen.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(FontAwesomeIcons.earthAfrica, color: AppTheme.primaryGreen, size: 16),
              ),
              const SizedBox(width: 12),
              Text(
                'IMPACT GLOBAL ECOREWIND',
                style: GoogleFonts.inter(
                  color: Colors.white,
                  fontSize: 11,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 2,
                ),
              ),
              const Spacer(),
              if (_statsLoaded)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: AppTheme.primaryGreen.withOpacity(0.15),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: AppTheme.primaryGreen.withOpacity(0.25)),
                  ),
                  child: Row(mainAxisSize: MainAxisSize.min, children: [
                    Container(width: 5, height: 5, decoration: const BoxDecoration(color: AppTheme.primaryGreen, shape: BoxShape.circle)),
                    const SizedBox(width: 4),
                    Text('LIVE', style: GoogleFonts.inter(color: AppTheme.primaryGreen, fontSize: 8, fontWeight: FontWeight.w900, letterSpacing: 1)),
                  ]),
                ),
            ],
          ),
          const SizedBox(height: 28),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              Expanded(child: _buildImpactStat(_fmt(co2Val), 'CO₂ ÉVITÉ', Icons.cloud_done_rounded)),
              Container(width: 1, height: 40, color: Colors.white.withOpacity(0.08)),
              Expanded(child: _buildImpactStat(_fmt(wasteVal, kg: true), 'TRIÉ', Icons.recycling_rounded)),
              Container(width: 1, height: 40, color: Colors.white.withOpacity(0.08)),
              Expanded(child: _buildImpactStat('$treesVal 🌳', 'ARBRES', Icons.forest_rounded)),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildImpactStat(String value, String label, IconData icon) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, color: AppTheme.accentTeal, size: 24),
        const SizedBox(height: 10),
        FittedBox(
          fit: BoxFit.scaleDown,
          child: Text(
            value,
            style: GoogleFonts.outfit(
              color: Colors.white,
              fontSize: 22,
              fontWeight: FontWeight.w900,
            ),
          ),
        ),
        const SizedBox(height: 2),
        FittedBox(
          fit: BoxFit.scaleDown,
          child: Text(
            label,
            style: GoogleFonts.inter(
              color: Colors.white.withOpacity(0.4),
              fontSize: 9,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.5,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildFeedTeaser() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 24, 20, 12),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Actualités',
                style: GoogleFonts.spaceGrotesk(
                  fontSize: 20,
                  fontWeight: FontWeight.w800,
                  color: AppTheme.deepNavy,
                ),
              ),
              GestureDetector(
                onTap: () => widget.onNavigate(1),
                child: Text(
                  'Tout voir →',
                  style: GoogleFonts.inter(
                    fontWeight: FontWeight.w700,
                    color: AppTheme.primaryGreen,
                    fontSize: 13,
                  ),
                ),
              ),
            ],
          ),
        ),
        ValueListenableBuilder<List<Post>>(
          valueListenable: PostRegistry.postsNotifier,
          builder: (context, posts, child) {
            final teaserPosts = posts.take(3).toList();
            if (teaserPosts.isEmpty) {
              return Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Container(
                  padding: const EdgeInsets.all(24),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: Colors.grey.shade100),
                  ),
                  child: Center(
                    child: Text(
                      'Aucune publication pour le moment',
                      style: GoogleFonts.inter(
                        color: AppTheme.textMuted,
                        fontSize: 14,
                      ),
                    ),
                  ),
                ),
              );
            }
            return SizedBox(
              height: 136,
              child: ListView.builder(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 12),
                itemCount: teaserPosts.length,
                itemBuilder: (context, index) {
                  return _buildMiniPostCard(teaserPosts[index]);
                },
              ),
            );
          },
        ),
      ],
    );
  }

  Widget _buildMiniPostCard(Post post) {
    return Container(
      width: 225,
      margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 12, offset: const Offset(0, 4)),
        ],
        border: Border.all(color: Colors.grey.shade100),
      ),
      child: Row(
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(14),
            child: Image.network(
              post.imageUrl,
              width: 52,
              height: 52,
              fit: BoxFit.cover,
              errorBuilder: (c, e, s) => Container(
                width: 52,
                height: 52,
                color: AppTheme.primaryGreen.withOpacity(0.1),
                child: const Icon(Icons.image, color: AppTheme.primaryGreen, size: 20),
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  post.userName,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.outfit(fontSize: 13, fontWeight: FontWeight.w800, color: AppTheme.deepNavy),
                ),
                const SizedBox(height: 2),
                Text(
                  post.description,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.inter(fontSize: 11, color: AppTheme.textMuted, height: 1.3),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
