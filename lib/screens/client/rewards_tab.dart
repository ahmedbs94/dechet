import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:google_fonts/google_fonts.dart';
import 'dart:ui';
import '../../theme/app_theme.dart';
import '../../widgets/safe_network_image.dart';
import '../../models/user_model.dart';
import '../../services/auth_service.dart';

class RewardsTab extends StatefulWidget {
  const RewardsTab({Key? key}) : super(key: key);

  @override
  State<RewardsTab> createState() => _RewardsTabState();
}

class _RewardsTabState extends State<RewardsTab> {
  final AuthService _authService = AuthService();
  double _score = 0;
  bool _loaded = false;

  @override
  void initState() {
    super.initState();
    _loadScore();
  }

  Future<void> _loadScore() async {
    // 1. Affichage immédiat depuis le cache local
    final cached = AuthState.currentUser?.globalScore ?? 0;
    if (mounted) setState(() { _score = cached; _loaded = true; });

    // 2. Rafraîchissement depuis l'API (si connecté)
    if (!AuthState.isLoggedIn) return;
    try {
      final userData = await _authService.fetchUserProfile();
      if (userData != null && mounted) {
        final fresh = (userData['global_score'] as num?)?.toDouble() ?? cached;
        // Mettre à jour le cache AuthState
        final u = AuthState.currentUser;
        if (u != null && fresh != u.globalScore) {
          AuthState.currentUser = User(
            id: u.id, name: u.name, email: u.email,
            role: u.role, points: u.points,
            globalScore: fresh,
            avatarUrl: u.avatarUrl, qrCode: u.qrCode,
          );
        }
        if (mounted) setState(() => _score = fresh);
      }
    } catch (_) {}
  }

  // ── Calcul du niveau ─────────────────────────────────────────────────────
  _LevelInfo _computeLevel(double score) {
    if (score >= 5000) {
      return const _LevelInfo('Légende Éco', Icons.workspace_premium_rounded, Color(0xFF8B5CF6), 5000, null);
    } else if (score >= 2000) {
      return const _LevelInfo('Champion Vert', Icons.emoji_events_rounded, Color(0xFFF59E0B), 2000, 5000);
    } else {
      return const _LevelInfo('Éco-Citoyen', Icons.eco_rounded, Color(0xFF10B981), 0, 2000);
    }
  }

  @override
  Widget build(BuildContext context) {
    final level = _computeLevel(_score);
    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      body: RefreshIndicator(
        color: AppTheme.primaryGreen,
        onRefresh: _loadScore,
        child: CustomScrollView(
          physics: const BouncingScrollPhysics(),
          slivers: [
            _buildSliverAppBar(),
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildScoreCard(level),
                    const SizedBox(height: 32),
                    _buildSectionTitle('Niveaux & Avantages'),
                    const SizedBox(height: 16),
                    _buildLevelCarousel(level),
                    const SizedBox(height: 32),
                    _buildSectionTitle('Vos Badges'),
                    const SizedBox(height: 16),
                    _buildBadgesGrid(context),
                    const SizedBox(height: 32),
                    _buildSectionTitle('Récompenses Exclusives'),
                    const SizedBox(height: 16),
                    _buildRewardsGrid(),
                    const SizedBox(height: 40),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSliverAppBar() {
    return SliverAppBar(
      expandedHeight: 120.0,
      floating: true,
      pinned: true,
      elevation: 0,
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      surfaceTintColor: Colors.transparent,
      flexibleSpace: FlexibleSpaceBar(
        titlePadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
        title: Text(
          'Récompenses',
          style: GoogleFonts.spaceGrotesk(
            color: Theme.of(context).brightness == Brightness.dark ? Colors.white : AppTheme.deepNavy,
            fontWeight: FontWeight.w900,
            fontSize: 24,
            letterSpacing: -0.5,
          ),
        ),
        background: Stack(
          children: [
            Positioned(
              right: -50,
              top: -50,
              child: Container(
                width: 150,
                height: 150,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: AppTheme.primaryGreen.withOpacity(0.05),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildScoreCard(_LevelInfo level) {
    final nextScore = level.nextThreshold;
    final prevScore = level.currentThreshold;
    final progress = nextScore == null
        ? 1.0
        : ((_score - prevScore) / (nextScore - prevScore)).clamp(0.0, 1.0);

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF07201B), Color(0xFF0F172A)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(32),
        border: Border.all(color: Colors.white.withOpacity(0.08), width: 1.5),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF00B894).withOpacity(0.12),
            blurRadius: 30,
            offset: const Offset(0, 15),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.08),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: Colors.white.withOpacity(0.1)),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(level.icon, color: Colors.white, size: 16),
                    const SizedBox(width: 6),
                    Text(
                      level.label,
                      style: GoogleFonts.inter(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.08),
                  shape: BoxShape.circle,
                  border: Border.all(color: Colors.white.withOpacity(0.1)),
                ),
                child: const Icon(Icons.info_outline_rounded, color: Colors.white, size: 20),
              ),
            ],
          ),
          const SizedBox(height: 24),
          Text(
            'Solde Actuel',
            style: GoogleFonts.inter(
              color: Colors.white.withOpacity(0.7),
              fontSize: 14,
            ),
          ),
          const SizedBox(height: 4),
          Row(
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            children: [
              Text(
                _loaded ? _score.toStringAsFixed(0) : '—',
                style: GoogleFonts.spaceGrotesk(
                  color: Colors.white,
                  fontSize: 48,
                  fontWeight: FontWeight.w900,
                  height: 1.0,
                ),
              ),
              const SizedBox(width: 8),
              Text(
                'pts',
                style: GoogleFonts.inter(
                  color: AppTheme.accentMint,
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          // Barre de progression vers le niveau suivant
          if (nextScore != null) ...[
            const SizedBox(height: 20),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Vers ${_nextLevelLabel(nextScore)}',
                  style: GoogleFonts.inter(color: Colors.white.withOpacity(0.7), fontSize: 11),
                ),
                Text(
                  '${(_score).toStringAsFixed(0)} / $nextScore pts',
                  style: GoogleFonts.inter(color: Colors.white.withOpacity(0.8), fontSize: 11, fontWeight: FontWeight.w700),
                ),
              ],
            ),
            const SizedBox(height: 6),
            ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: LinearProgressIndicator(
                value: progress,
                minHeight: 8,
                backgroundColor: Colors.white.withOpacity(0.1),
                valueColor: const AlwaysStoppedAnimation<Color>(AppTheme.accentMint),
              ),
            ),
          ] else ...[
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.08),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.white.withOpacity(0.1)),
              ),
              child: Row(children: [
                const Icon(Icons.workspace_premium_rounded, color: AppTheme.accentMint, size: 16),
                const SizedBox(width: 6),
                Text('Niveau Maximum atteint ! 🎉',
                  style: GoogleFonts.inter(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w700)),
              ]),
            ),
          ],
        ],
      ),
    ).animate().fadeIn(duration: 600.ms).slideY(begin: 0.1);
  }

  String _nextLevelLabel(double nextThreshold) {
    if (nextThreshold >= 5000) return 'Légende Éco';
    if (nextThreshold >= 2000) return 'Champion Vert';
    return 'Éco-Citoyen';
  }

  Widget _buildSectionTitle(String title) {
    return Text(
      title,
      style: GoogleFonts.spaceGrotesk(
        fontSize: 20,
        fontWeight: FontWeight.w800,
        color: Theme.of(context).textTheme.titleLarge?.color ?? AppTheme.deepNavy,
      ),
    ).animate().fadeIn(delay: 200.ms).slideX(begin: -0.05);
  }

  Widget _buildLevelCarousel(_LevelInfo current) {
    const levels = [
      _LevelData('Éco-Citoyen', 'Niveau de départ', Icons.eco_rounded, Color(0xFF10B981), 0),
      _LevelData('Champion Vert', '2 000 pts', Icons.emoji_events_rounded, Color(0xFFF59E0B), 2000),
      _LevelData('Légende Éco', '5 000 pts', Icons.workspace_premium_rounded, Color(0xFF8B5CF6), 5000),
    ];
    return SizedBox(
      height: 180,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        physics: const BouncingScrollPhysics(),
        clipBehavior: Clip.none,
        itemCount: levels.length,
        itemBuilder: (_, i) {
          final lvl = levels[i];
          final isCurrent = current.label == lvl.name;
          final isUnlocked = _score >= lvl.threshold;
          return Padding(
            padding: EdgeInsets.only(right: i < levels.length - 1 ? 16 : 0),
            child: _buildLevelCard(lvl.name, lvl.subtitle, lvl.icon, lvl.color, isCurrent, isUnlocked),
          );
        },
      ),
    ).animate().fadeIn(delay: 300.ms).slideX(begin: 0.1);
  }

  Widget _buildLevelCard(String title, String subtitle, IconData icon, Color color, bool isCurrent, bool isUnlocked) {
    return Container(
      width: 150,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: isCurrent ? color : (isUnlocked ? color.withOpacity(0.08) : Theme.of(context).colorScheme.surface),
        borderRadius: BorderRadius.circular(28),
        border: isCurrent ? null : Border.all(color: isUnlocked ? color.withOpacity(0.3) : Theme.of(context).dividerColor),
        boxShadow: isCurrent ? [
          BoxShadow(
            color: color.withOpacity(0.3),
            blurRadius: 20,
            offset: const Offset(0, 10),
          )
        ] : [],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Stack(
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: isCurrent ? Colors.white.withOpacity(0.2) : color.withOpacity(0.1),
                  shape: BoxShape.circle,
                ),
                child: Icon(icon, color: isCurrent ? Colors.white : color, size: 28),
              ),
              if (!isUnlocked && !isCurrent)
                Positioned(right: 0, top: 0,
                  child: Container(
                    padding: const EdgeInsets.all(3),
                    decoration: const BoxDecoration(color: Colors.grey, shape: BoxShape.circle),
                    child: const Icon(Icons.lock, color: Colors.white, size: 10),
                  ),
                ),
            ],
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: GoogleFonts.spaceGrotesk(
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                  color: isCurrent ? Colors.white : (isUnlocked ? color : Theme.of(context).textTheme.titleLarge?.color ?? AppTheme.deepNavy),
                  height: 1.1,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                isCurrent ? 'Niveau Actuel ✓' : subtitle,
                style: GoogleFonts.inter(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  color: isCurrent ? Colors.white.withOpacity(0.8) : AppTheme.textMuted,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildBadgesGrid(BuildContext context) {
    final badges = [
      _BadgeData(Icons.recycling_rounded, const Color(0xFF3B82F6), 'Premier Tri', _score >= 10),
      _BadgeData(Icons.local_fire_department_rounded, const Color(0xFFF59E0B), 'Série 7J', _score >= 100),
      _BadgeData(Icons.quiz_rounded, const Color(0xFF8B5CF6), 'Expert Quiz', _score >= 500),
      _BadgeData(Icons.groups_rounded, const Color(0xFF10B981), 'Communauté', _score >= 1000), // ignore: prefer_const_constructors
    ];

    final double screenWidth = MediaQuery.of(context).size.width;
    final int crossAxisCount = screenWidth > 900 ? 4 : (screenWidth > 600 ? 3 : 2);
    final double cardWidth = (screenWidth - 40 - ((crossAxisCount - 1) * 16)) / crossAxisCount;

    return Wrap(
      spacing: 16,
      runSpacing: 16,
      children: badges.map((b) {
        final color = b.unlocked ? b.color : Colors.grey.shade400;
        return Container(
          width: cardWidth,
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: b.unlocked ? color.withOpacity(0.05) : Theme.of(context).colorScheme.surface,
            borderRadius: BorderRadius.circular(24),
            border: Border.all(color: b.unlocked ? color.withOpacity(0.1) : Theme.of(context).dividerColor),
          ),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: b.unlocked ? color.withOpacity(0.15) : (Theme.of(context).brightness == Brightness.dark ? Colors.white.withOpacity(0.05) : Colors.grey.shade200),
                  shape: BoxShape.circle,
                ),
                child: Icon(b.icon, color: color, size: 20),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      b.title,
                      style: GoogleFonts.inter(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        color: b.unlocked ? (Theme.of(context).textTheme.titleLarge?.color ?? AppTheme.deepNavy) : Colors.grey.shade500,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    if (b.unlocked)
                      Text('Débloqué ✓', style: GoogleFonts.inter(fontSize: 10, color: color, fontWeight: FontWeight.w600))
                    else
                      Text('Verrouillé', style: GoogleFonts.inter(fontSize: 10, color: Colors.grey.shade400)),
                  ],
                ),
              ),
            ],
          ),
        );
      }).toList(),
    ).animate().fadeIn(delay: 400.ms).slideY(begin: 0.1);
  }

  Widget _buildRewardsGrid() {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: Column(
            children: [
              _buildRewardCard(
                title: 'Bon d\'achat 10 DT',
                points: '1000 pts',
                imageUrl: 'https://images.unsplash.com/photo-1542838132-92c53300491e?w=400&q=80',
                height: 220,
                unlocked: _score >= 1000,
              ),
              const SizedBox(height: 16),
              _buildRewardCard(
                title: 'Sac en toile bio',
                points: '1500 pts',
                imageUrl: 'https://images.unsplash.com/photo-1597348989645-46b190ce4918?w=400&q=80',
                height: 260,
                unlocked: _score >= 1500,
              ),
            ],
          ),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: Column(
            children: [
              _buildRewardCard(
                title: 'Gourde écologique',
                points: '2500 pts',
                imageUrl: 'https://images.unsplash.com/photo-1602143407151-7111542de6e8?w=400&q=80',
                height: 260,
                unlocked: _score >= 2500,
              ),
              const SizedBox(height: 16),
              _buildRewardCard(
                title: 'Plantation d\'arbre',
                points: '3000 pts',
                imageUrl: 'https://images.unsplash.com/photo-1542601906990-b4d3fb778b09?w=400&q=80',
                height: 220,
                unlocked: _score >= 3000,
              ),
            ],
          ),
        ),
      ],
    ).animate().fadeIn(delay: 500.ms).slideY(begin: 0.1);
  }

  Widget _buildRewardCard({
    required String title,
    required String points,
    required String imageUrl,
    required double height,
    required bool unlocked,
  }) {
    return Container(
      height: height,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(28),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.06),
            blurRadius: 16,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(28),
        child: Stack(
          fit: StackFit.expand,
          children: [
            SafeNetworkImage(
              imageUrl,
              fit: BoxFit.cover,
              placeholder: Container(color: Colors.grey.shade200),
            ),
            // Overlay flouté si verrouillé
            if (!unlocked)
              BackdropFilter(
                filter: ImageFilter.blur(sigmaX: 4, sigmaY: 4),
                child: Container(color: Colors.black.withOpacity(0.35)),
              ),
            Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    Colors.transparent,
                    Colors.black.withOpacity(0.85),
                  ],
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  stops: const [0.4, 1.0],
                ),
              ),
            ),
            Positioned(
              top: 12,
              right: 12,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  color: unlocked ? Colors.white.withOpacity(0.95) : Colors.black.withOpacity(0.6),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (!unlocked)
                      const Icon(Icons.lock, color: Colors.white70, size: 10),
                    if (!unlocked) const SizedBox(width: 4),
                    Text(
                      points,
                      style: GoogleFonts.outfit(
                        color: unlocked ? AppTheme.primaryGreen : Colors.white70,
                        fontWeight: FontWeight.w900,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            Positioned(
              left: 16,
              right: 16,
              bottom: 16,
              child: Text(
                title,
                style: GoogleFonts.spaceGrotesk(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                  height: 1.2,
                ),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Data classes ──────────────────────────────────────────────────────────────

class _LevelInfo {
  final String label;
  final IconData icon;
  final Color color;
  final double currentThreshold;
  final double? nextThreshold;
  const _LevelInfo(this.label, this.icon, this.color, this.currentThreshold, this.nextThreshold);
}

class _LevelData {
  final String name;
  final String subtitle;
  final IconData icon;
  final Color color;
  final double threshold;
  const _LevelData(this.name, this.subtitle, this.icon, this.color, this.threshold);
}

class _BadgeData {
  final IconData icon;
  final Color color;
  final String title;
  final bool unlocked;
  const _BadgeData(this.icon, this.color, this.title, this.unlocked);
}
