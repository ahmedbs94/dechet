import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:google_fonts/google_fonts.dart';
import 'dart:ui';
import '../../theme/app_theme.dart';
import '../../models/user_model.dart';
import '../../services/auth_service.dart';
import '../../services/l10n_service.dart';
import '../../services/levels_service.dart';

class RewardsTab extends StatefulWidget {
  const RewardsTab({Key? key}) : super(key: key);

  @override
  State<RewardsTab> createState() => _RewardsTabState();
}

class _RewardsTabState extends State<RewardsTab> {
  final AuthService   _authService   = AuthService();
  final LevelsService _levelsService = LevelsService();

  // Score & loading
  double _score   = 0;
  bool   _loaded  = false;
  bool   _loading = false;

  // Impact
  int    _scanCount        = 0;
  int    _quizCount        = 0;
  double _totalScanPoints  = 0;
  double _totalQuizPoints  = 0;
  int    _postsCount       = 0;
  int    _likesReceived    = 0;
  List<dynamic> _history   = [];

  // ── Données backend niveaux ───────────────────────────────────────────────
  UserLevelData? _levelData;        // GET /users/me/level
  List<LevelInfo> _allLevels = [];  // GET /levels/all

  @override
  void initState() {
    super.initState();
    L10n.addListener(_onLocaleChange);
    _loadAll();
  }

  void _onLocaleChange() { if (mounted) setState(() {}); }

  @override
  void dispose() {
    L10n.removeListener(_onLocaleChange);
    super.dispose();
  }

  // ── Chargement ────────────────────────────────────────────────────────────

  Future<void> _loadAll() async {
    if (_loading) return;
    if (mounted) setState(() { _loading = true; });

    final cached = AuthState.currentUser?.globalScore ?? 0;
    if (mounted) setState(() { _score = cached; _loaded = true; });

    if (!AuthState.isLoggedIn) {
      if (mounted) setState(() { _loading = false; });
      return;
    }

    try {
      final results = await Future.wait([
        _authService.fetchUserProfile(),
        _authService.fetchMyImpact(),
        _authService.fetchPointsHistory(),
        _levelsService.fetchMyLevel(),
        _levelsService.fetchAllLevels(),
      ]);

      final profile    = results[0] as Map<String, dynamic>?;
      final impact     = results[1] as Map<String, dynamic>;
      final history    = results[2] as List<dynamic>;
      final levelData  = results[3] as UserLevelData?;
      final allLevels  = results[4] as List<LevelInfo>;

      if (!mounted) return;

      if (profile != null) {
        AuthState.currentUser = User.fromBackend(profile);
        _score = AuthState.currentUser?.globalScore ?? cached;
      }

      _scanCount       = (impact['scan_count']        as num?)?.toInt()    ?? 0;
      _quizCount       = (impact['quiz_count']        as num?)?.toInt()    ?? 0;
      _totalScanPoints = (impact['total_scan_points'] as num?)?.toDouble() ?? 0;
      _totalQuizPoints = (impact['total_quiz_points'] as num?)?.toDouble() ?? 0;
      _postsCount      = (impact['posts_count']       as num?)?.toInt()    ?? 0;
      _likesReceived   = (impact['likes_received']    as num?)?.toInt()    ?? 0;
      _history         = history;

      // Données backend niveaux (avec fallback si l'endpoint échoue)
      if (levelData != null) {
        _levelData = levelData;
        _score     = levelData.score;
      }
      if (allLevels.isNotEmpty) _allLevels = allLevels;

      if (mounted) setState(() { _loaded = true; _loading = false; });
    } catch (e) {
      if (mounted) setState(() { _loading = false; });
    }
  }

  // ── Helpers couleur ──────────────────────────────────────────────────────

  Color _hexColor(String hex) {
    try {
      final h = hex.replaceAll('#', '');
      return Color(int.parse('FF$h', radix: 16));
    } catch (_) {
      return AppTheme.primaryGreen;
    }
  }

  // ── Build ─────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      body: RefreshIndicator(
        color: AppTheme.primaryGreen,
        onRefresh: _loadAll,
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
                    _buildScoreCard(),
                    const SizedBox(height: 32),
                    _buildSectionTitle(L10n.tr('Niveaux & Avantages')),
                    const SizedBox(height: 16),
                    _buildLevelCarousel(),
                    const SizedBox(height: 32),
                    if (_levelData != null && _levelData!.advantages.isNotEmpty) ...[
                      _buildSectionTitle(L10n.tr('Vos Avantages Actuels')),
                      const SizedBox(height: 16),
                      _buildAdvantagesSection(),
                      const SizedBox(height: 32),
                    ],
                    _buildSectionTitle(L10n.tr('Mon Impact Écologique')),
                    const SizedBox(height: 16),
                    _buildImpactSection(),
                    const SizedBox(height: 32),
                    _buildSectionTitle(L10n.tr('Vos Badges')),
                    const SizedBox(height: 16),
                    _buildBadgesGrid(context),
                    if (_history.isNotEmpty) ...[
                      const SizedBox(height: 32),
                      _buildSectionTitle(L10n.tr('Activités Récentes')),
                      const SizedBox(height: 16),
                      _buildRecentActivity(),
                    ],
                    const SizedBox(height: 32),
                    _buildSectionTitle(L10n.tr('Récompenses Exclusives')),
                    const SizedBox(height: 16),
                    _buildRewardsSection(),
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

  // ── AppBar ────────────────────────────────────────────────────────────────

  Widget _buildSliverAppBar() {
    return SliverAppBar(
      automaticallyImplyLeading: false,
      pinned: true,
      floating: false,
      expandedHeight: 110 + MediaQuery.of(context).padding.top,
      backgroundColor: Theme.of(context).colorScheme.surface,
      surfaceTintColor: Colors.transparent,
      elevation: 0,
      flexibleSpace: FlexibleSpaceBar(
        titlePadding: const EdgeInsets.fromLTRB(20, 0, 20, 14),
        title: Row(
          children: [
            Container(
              width: 28, height: 28,
              decoration: BoxDecoration(
                gradient: const LinearGradient(colors: [AppTheme.primaryGreen, AppTheme.accentTeal]),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Icon(Icons.workspace_premium_rounded, color: Colors.white, size: 16),
            ),
            const SizedBox(width: 8),
            Text(
              L10n.tr('tab_rewards_title'),
              style: GoogleFonts.outfit(
                fontSize: 20,
                fontWeight: FontWeight.w900,
                color: Theme.of(context).textTheme.titleLarge?.color ?? const Color(0xFF0F172A),
              ),
            ),
          ],
        ),
      ),
      bottom: PreferredSize(
        preferredSize: const Size.fromHeight(1),
        child: Container(height: 1, color: Theme.of(context).dividerColor),
      ),
    );
  }

  // ── Score Card ────────────────────────────────────────────────────────────

  Widget _buildScoreCard() {
    final ld          = _levelData;
    final levelName   = ld?.currentLevel.name   ?? _fallbackLevelName(_score);
    final levelIcon   = ld?.currentLevel.icon   ?? '🌱';
    final progress    = ld != null ? (ld.progressPercent / 100).clamp(0.0, 1.0) : _fallbackProgress();
    final nextName    = ld?.nextLevel?.name;
    final ptsToNext   = ld?.pointsToNext ?? 0;

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
              // Badge niveau actuel
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
                    Text(levelIcon, style: const TextStyle(fontSize: 14)),
                    const SizedBox(width: 6),
                    Text(
                      L10n.tr(levelName),
                      style: GoogleFonts.inter(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
              // Multiplicateurs
              if (ld != null)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(
                    color: AppTheme.accentMint.withOpacity(0.12),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: AppTheme.accentMint.withOpacity(0.2)),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.bolt_rounded, color: AppTheme.accentMint, size: 14),
                      const SizedBox(width: 4),
                      Text(
                        'x${ld.scanMultiplier.toStringAsFixed(1)} scan',
                        style: GoogleFonts.inter(
                          color: AppTheme.accentMint,
                          fontWeight: FontWeight.w700,
                          fontSize: 10,
                        ),
                      ),
                    ],
                  ),
                )
              else if (_loading)
                const SizedBox(
                  width: 20, height: 20,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    valueColor: AlwaysStoppedAnimation<Color>(Colors.white38),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 24),
          Text(
            L10n.tr('Solde Actuel'),
            style: GoogleFonts.inter(color: Colors.white.withOpacity(0.7), fontSize: 14),
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
                L10n.tr('pts'),
                style: GoogleFonts.inter(
                  color: AppTheme.accentMint,
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          // Barre de progression
          if (nextName != null) ...[
            const SizedBox(height: 20),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Vers $nextName',
                  style: GoogleFonts.inter(color: Colors.white.withOpacity(0.7), fontSize: 11),
                ),
                Text(
                  '${ptsToNext.toStringAsFixed(0)} pts restants',
                  style: GoogleFonts.inter(
                    color: Colors.white.withOpacity(0.8),
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                  ),
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
            const SizedBox(height: 8),
            Text(
              '${(progress * 100).toStringAsFixed(1)}% vers $nextName',
              style: GoogleFonts.inter(color: Colors.white38, fontSize: 10),
            ),
          ] else if (ld != null) ...[
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: const Color(0xFFFFD700).withOpacity(0.1),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: const Color(0xFFFFD700).withOpacity(0.3)),
              ),
              child: Row(children: [
                const Text('👑', style: TextStyle(fontSize: 16)),
                const SizedBox(width: 8),
                Text(
                  L10n.tr('Niveau Maximum atteint ! 🎉'),
                  style: GoogleFonts.inter(
                    color: const Color(0xFFFFD700),
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ]),
            ),
          ],
        ],
      ),
    ).animate().fadeIn(duration: 600.ms).slideY(begin: 0.1);
  }

  double _fallbackProgress() {
    if (_score >= 50000) return 1.0;
    if (_score >= 20000) return ((_score - 20000) / 30000).clamp(0.0, 1.0);
    if (_score >= 10000) return ((_score - 10000) / 10000).clamp(0.0, 1.0);
    if (_score >= 5000)  return ((_score - 5000)  / 5000).clamp(0.0, 1.0);
    if (_score >= 2000)  return ((_score - 2000)  / 3000).clamp(0.0, 1.0);
    return (_score / 2000).clamp(0.0, 1.0);
  }

  String _fallbackLevelName(double score) {
    if (score >= 50000) return 'Légende Verte';
    if (score >= 20000) return 'Ambassadeur Éco';
    if (score >= 10000) return 'Héros du Recyclage';
    if (score >= 5000)  return 'Gardien de la Terre';
    if (score >= 2000)  return 'Champion Vert';
    return 'Éco-Citoyen';
  }

  // ── Section title ─────────────────────────────────────────────────────────

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

  // ── Level Carousel (données backend) ─────────────────────────────────────

  Widget _buildLevelCarousel() {
    // Fallback statique si le backend n'a pas encore répondu
    final levels = _allLevels.isNotEmpty
        ? _allLevels
        : _fallbackLevels();

    return SizedBox(
      height: 190,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        physics: const BouncingScrollPhysics(),
        clipBehavior: Clip.none,
        itemCount: levels.length,
        itemBuilder: (_, i) {
          final lvl        = levels[i];
          final isCurrent  = _levelData != null
              ? (_levelData!.currentLevel.rank == lvl.rank)
              : (_score >= lvl.minPoints && (i == levels.length - 1 || _score < levels[i + 1].minPoints));
          final isUnlocked = _score >= lvl.minPoints;
          final color      = _hexColor(lvl.color);

          return Padding(
            padding: EdgeInsets.only(right: i < levels.length - 1 ? 16 : 0),
            child: _buildLevelCard(
              name:       lvl.name,
              subtitle:   '${lvl.minPoints.toStringAsFixed(0)} pts',
              icon:       lvl.icon,
              color:      color,
              isCurrent:  isCurrent,
              isUnlocked: isUnlocked,
              rank:       lvl.rank,
            ),
          );
        },
      ),
    ).animate().fadeIn(delay: 300.ms).slideX(begin: 0.1);
  }

  List<LevelInfo> _fallbackLevels() => [
    const LevelInfo(rank: 1, name: 'Éco-Citoyen',        icon: '🌱', color: '#4CAF50', gradient: [], minPoints: 0,      advantages: [], exclusiveRewards: []),
    const LevelInfo(rank: 2, name: 'Champion Vert',       icon: '🏆', color: '#FF9800', gradient: [], minPoints: 2000,   advantages: [], exclusiveRewards: []),
    const LevelInfo(rank: 3, name: 'Gardien de la Terre', icon: '🌍', color: '#2196F3', gradient: [], minPoints: 5000,   advantages: [], exclusiveRewards: []),
    const LevelInfo(rank: 4, name: 'Héros du Recyclage',  icon: '♻️', color: '#9C27B0', gradient: [], minPoints: 10000,  advantages: [], exclusiveRewards: []),
    const LevelInfo(rank: 5, name: 'Ambassadeur Éco',     icon: '⭐', color: '#FF5722', gradient: [], minPoints: 20000,  advantages: [], exclusiveRewards: []),
    const LevelInfo(rank: 6, name: 'Légende Verte',       icon: '👑', color: '#FFD700', gradient: [], minPoints: 50000,  advantages: [], exclusiveRewards: []),
  ];

  Widget _buildLevelCard({
    required String   name,
    required String   subtitle,
    required String   icon,
    required Color    color,
    required bool     isCurrent,
    required bool     isUnlocked,
    required int      rank,
  }) {
    return Container(
      width: 150,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: isCurrent
            ? color
            : (isUnlocked ? color.withOpacity(0.08) : Theme.of(context).colorScheme.surface),
        borderRadius: BorderRadius.circular(28),
        border: isCurrent
            ? null
            : Border.all(
                color: isUnlocked ? color.withOpacity(0.3) : Theme.of(context).dividerColor,
              ),
        boxShadow: isCurrent
            ? [BoxShadow(color: color.withOpacity(0.3), blurRadius: 20, offset: const Offset(0, 10))]
            : [],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Stack(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: isCurrent ? Colors.white.withOpacity(0.2) : color.withOpacity(0.1),
                  shape: BoxShape.circle,
                ),
                child: Text(icon, style: const TextStyle(fontSize: 24)),
              ),
              if (!isUnlocked && !isCurrent)
                Positioned(
                  right: 0,
                  top: 0,
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
                L10n.tr(name),
                style: GoogleFonts.spaceGrotesk(
                  fontSize: 13,
                  fontWeight: FontWeight.bold,
                  color: isCurrent ? Colors.white : (isUnlocked ? color : Theme.of(context).textTheme.titleLarge?.color ?? AppTheme.deepNavy),
                  height: 1.1,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                isCurrent ? (L10n.isArabic ? 'المستوى الحالي ✓' : 'Niveau Actuel ✓') : subtitle,
                style: GoogleFonts.inter(
                  fontSize: 10,
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

  // ── Avantages du niveau actuel (données backend) ──────────────────────────

  Widget _buildAdvantagesSection() {
    final advantages = _levelData?.advantages ?? [];
    if (advantages.isEmpty) return const SizedBox.shrink();

    final color = _levelData != null
        ? _hexColor(_levelData!.currentLevel.color)
        : AppTheme.primaryGreen;

    return Column(
      children: advantages.asMap().entries.map((entry) {
        final i   = entry.key;
        final adv = entry.value;
        return Container(
          margin: const EdgeInsets.only(bottom: 10),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          decoration: BoxDecoration(
            color: color.withOpacity(0.06),
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: color.withOpacity(0.15)),
          ),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: color.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(Icons.check_circle_rounded, color: color, size: 18),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      adv['label'] as String? ?? '',
                      style: GoogleFonts.inter(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        color: Theme.of(context).textTheme.bodyLarge?.color,
                      ),
                    ),
                    if ((adv['description'] as String? ?? '').isNotEmpty)
                      Text(
                        adv['description'] as String,
                        style: GoogleFonts.inter(fontSize: 11, color: AppTheme.textMuted),
                      ),
                  ],
                ),
              ),
            ],
          ),
        ).animate().fadeIn(delay: Duration(milliseconds: 100 + i * 60)).slideX(begin: 0.05);
      }).toList(),
    );
  }

  // ── Impact Écologique ─────────────────────────────────────────────────────

  Widget _buildImpactSection() {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    if (!_loaded && !_loading) return const SizedBox.shrink();

    final tiles = [
      _ImpactTile(icon: Icons.recycling_rounded, color: const Color(0xFF10B981),
          value: _scanCount.toString(),
          label: L10n.isArabic ? 'عمليات الفرز' : 'Tris effectués',
          sublabel: '${_totalScanPoints.toStringAsFixed(0)} pts gagnés'),
      _ImpactTile(icon: Icons.quiz_rounded, color: const Color(0xFF8B5CF6),
          value: _quizCount.toString(),
          label: L10n.isArabic ? 'اختبارات' : 'Quiz joués',
          sublabel: '${_totalQuizPoints.toStringAsFixed(0)} pts gagnés'),
      _ImpactTile(icon: Icons.article_rounded, color: const Color(0xFF3B82F6),
          value: _postsCount.toString(),
          label: L10n.isArabic ? 'منشورات' : 'Posts publiés',
          sublabel: '$_likesReceived like(s)'),
    ];

    return GridView.builder(
      physics: const NeverScrollableScrollPhysics(),
      shrinkWrap: true,
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2, crossAxisSpacing: 12, mainAxisSpacing: 12, childAspectRatio: 1.15,
      ),
      itemCount: tiles.length,
      itemBuilder: (_, i) {
        final t = tiles[i];
        return Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: isDark ? t.color.withOpacity(0.08) : t.color.withOpacity(0.05),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: t.color.withOpacity(0.15), width: 1.2),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(color: t.color.withOpacity(0.15), borderRadius: BorderRadius.circular(12)),
                child: Icon(t.icon, color: t.color, size: 20),
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _loading
                      ? Container(width: 50, height: 20, decoration: BoxDecoration(color: t.color.withOpacity(0.15), borderRadius: BorderRadius.circular(6)))
                      : Text(t.value, style: GoogleFonts.spaceGrotesk(fontSize: 20, fontWeight: FontWeight.w900, color: t.color)),
                  Text(t.label, style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.w700, color: isDark ? Colors.white70 : AppTheme.deepNavy)),
                  Text(_loading ? '...' : t.sublabel, style: GoogleFonts.inter(fontSize: 10, color: AppTheme.textMuted)),
                ],
              ),
            ],
          ),
        ).animate().fadeIn(delay: Duration(milliseconds: 200 + i * 80)).slideY(begin: 0.1);
      },
    );
  }

  // ── Badges ────────────────────────────────────────────────────────────────

  Widget _buildBadgesGrid(BuildContext context) {
    // Badges statiques basés sur l'activité + badges débloqués via le backend
    final unlockedKeys = _levelData?.unlockedRewards
            .map((r) => r['reward_key'] as String)
            .toSet() ??
        {};

    final badges = [
      _BadgeData(Icons.recycling_rounded, const Color(0xFF3B82F6),
          L10n.isArabic ? 'أول فرز' : 'Premier Tri',
          _scanCount >= 1,
          L10n.isArabic ? 'افرز ولو مرة واحدة' : 'Effectuer au moins 1 scan'),
      _BadgeData(Icons.local_fire_department_rounded, const Color(0xFFF59E0B),
          'Série 7J', _score >= 100, '100 pts requis'),
      _BadgeData(Icons.quiz_rounded, const Color(0xFF8B5CF6),
          'Expert Quiz', _quizCount >= 1, 'Compléter 1 quiz'),
      _BadgeData(Icons.groups_rounded, const Color(0xFF10B981),
          'Communauté', _postsCount >= 1, 'Publier 1 post'),
      _BadgeData(Icons.workspace_premium_rounded, const Color(0xFFFF9800),
          'Champion', unlockedKeys.contains('badge_champion_vert'), '2 000 pts requis'),
      _BadgeData(Icons.public_rounded, const Color(0xFF2196F3),
          'Gardien', unlockedKeys.contains('badge_gardien_terre'), '5 000 pts requis'),
    ];

    final double screenWidth = MediaQuery.of(context).size.width;
    final int crossAxisCount = screenWidth > 900 ? 4 : (screenWidth > 600 ? 3 : 2);
    final double cardWidth = (screenWidth - 40 - ((crossAxisCount - 1) * 16)) / crossAxisCount;

    return Wrap(
      spacing: 16,
      runSpacing: 16,
      children: badges.asMap().entries.map((entry) {
        final i = entry.key;
        final b = entry.value;
        final color = b.unlocked ? b.color : Colors.grey.shade400;
        return Container(
          width: cardWidth,
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: b.unlocked ? color.withOpacity(0.05) : Theme.of(context).colorScheme.surface,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: b.unlocked ? color.withOpacity(0.2) : Theme.of(context).dividerColor),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(children: [
                Container(
                  padding: const EdgeInsets.all(9),
                  decoration: BoxDecoration(
                    color: b.unlocked ? color.withOpacity(0.15) : (Theme.of(context).brightness == Brightness.dark ? Colors.white.withOpacity(0.05) : Colors.grey.shade200),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(b.icon, color: color, size: 18),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(b.title,
                    style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w700,
                      color: b.unlocked ? (Theme.of(context).textTheme.titleLarge?.color ?? AppTheme.deepNavy) : Colors.grey.shade500),
                    maxLines: 1, overflow: TextOverflow.ellipsis),
                ),
              ]),
              const SizedBox(height: 8),
              if (b.unlocked)
                Row(children: [
                  Icon(Icons.check_circle_rounded, color: color, size: 12),
                  const SizedBox(width: 4),
                  Text(L10n.isArabic ? 'مفتوح ✓' : 'Débloqué ✓',
                    style: GoogleFonts.inter(fontSize: 10, color: color, fontWeight: FontWeight.w700)),
                ])
              else
                Row(children: [
                  Icon(Icons.lock_rounded, color: Colors.grey.shade400, size: 11),
                  const SizedBox(width: 4),
                  Expanded(
                    child: Text(b.hint,
                      style: GoogleFonts.inter(fontSize: 9, color: Colors.grey.shade400),
                      maxLines: 1, overflow: TextOverflow.ellipsis),
                  ),
                ]),
            ],
          ),
        ).animate().fadeIn(delay: Duration(milliseconds: 400 + i * 60)).slideY(begin: 0.08);
      }).toList(),
    );
  }

  // ── Activités récentes ────────────────────────────────────────────────────

  Widget _buildRecentActivity() {
    final recent = _history.take(5).toList();
    return Column(
      children: recent.asMap().entries.map((entry) {
        final i    = entry.key;
        final item = entry.value as Map<String, dynamic>;
        final type   = item['type'] as String? ?? 'tri';
        final points = (item['points'] as num?)?.toDouble() ?? 0;
        final desc   = item['description'] as String? ?? '';
        final date   = _formatDate(item['date'] as String?);
        final isQuiz = type == 'quiz';
        final color  = isQuiz ? const Color(0xFF8B5CF6) : const Color(0xFF10B981);
        final icon   = isQuiz ? Icons.quiz_rounded : Icons.recycling_rounded;
        final isDark = Theme.of(context).brightness == Brightness.dark;

        return Container(
          margin: const EdgeInsets.only(bottom: 10),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          decoration: BoxDecoration(
            color: isDark ? color.withOpacity(0.06) : color.withOpacity(0.04),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: color.withOpacity(0.12)),
          ),
          child: Row(children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(color: color.withOpacity(0.15), borderRadius: BorderRadius.circular(10)),
              child: Icon(icon, color: color, size: 16),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    desc.isNotEmpty ? desc : (isQuiz ? 'Quiz complété' : 'Tri effectué'),
                    style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w600,
                      color: isDark ? Colors.white.withOpacity(0.87) : AppTheme.deepNavy),
                    maxLines: 1, overflow: TextOverflow.ellipsis,
                  ),
                  if (date.isNotEmpty)
                    Text(date, style: GoogleFonts.inter(fontSize: 10, color: AppTheme.textMuted)),
                ],
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(color: color.withOpacity(0.12), borderRadius: BorderRadius.circular(10)),
              child: Text('+${points.toStringAsFixed(0)} pts',
                style: GoogleFonts.spaceGrotesk(color: color, fontWeight: FontWeight.w800, fontSize: 12)),
            ),
          ]),
        ).animate().fadeIn(delay: Duration(milliseconds: 300 + i * 60)).slideX(begin: 0.05);
      }).toList(),
    );
  }

  // ── Récompenses exclusives (données backend) ──────────────────────────────

  Widget _buildRewardsSection() {
    final unlockedRewards = _levelData?.unlockedRewards ?? [];

    // Si on a des données backend, on affiche les récompenses réelles
    if (unlockedRewards.isNotEmpty || _levelData != null) {
      return _buildBackendRewardsGrid(unlockedRewards);
    }

    // Fallback sur les données statiques
    return _buildStaticRewardsGrid();
  }

  Widget _buildBackendRewardsGrid(List<Map<String, dynamic>> rewards) {
    // Toutes les récompenses de tous les niveaux (débloquées ou verrouillées)
    final allRewards = _allLevels.isEmpty
        ? _fallbackLevels().expand((l) => l.exclusiveRewards).toList()
        : _allLevels.expand((l) => l.exclusiveRewards).toList();

    final unlockedKeys = rewards.map((r) => r['reward_key'] as String).toSet();

    final typeIcons = {
      'badge':       Icons.workspace_premium_rounded,
      'discount':    Icons.local_offer_rounded,
      'feature':     Icons.auto_awesome_rounded,
      'certificate': Icons.military_tech_rounded,
    };
    final typeColors = {
      'badge':       const Color(0xFFFF9800),
      'discount':    const Color(0xFF10B981),
      'feature':     const Color(0xFF8B5CF6),
      'certificate': const Color(0xFF2196F3),
    };

    return Column(
      children: allRewards.asMap().entries.map((entry) {
        final i      = entry.key;
        final reward = entry.value;
        final key    = reward['key'] as String? ?? '';
        final isUnlocked = unlockedKeys.contains(key);
        final type   = reward['reward_type'] as String? ?? 'badge';
        final color  = typeColors[type] ?? AppTheme.primaryGreen;
        final icon   = typeIcons[type] ?? Icons.star_rounded;
        final isDark = Theme.of(context).brightness == Brightness.dark;

        return Container(
          margin: const EdgeInsets.only(bottom: 12),
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: isUnlocked
                ? color.withOpacity(isDark ? 0.08 : 0.05)
                : Theme.of(context).colorScheme.surface,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: isUnlocked ? color.withOpacity(0.25) : Theme.of(context).dividerColor,
              width: isUnlocked ? 1.5 : 1,
            ),
          ),
          child: Row(children: [
            // Icône + emoji
            Stack(
              clipBehavior: Clip.none,
              children: [
                Container(
                  width: 48, height: 48,
                  decoration: BoxDecoration(
                    color: isUnlocked ? color.withOpacity(0.15) : Colors.grey.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Center(
                    child: Text(
                      reward['icon'] as String? ?? '🎁',
                      style: TextStyle(fontSize: isUnlocked ? 22 : 18),
                    ),
                  ),
                ),
                if (!isUnlocked)
                  Positioned(
                    right: -4, bottom: -4,
                    child: Container(
                      padding: const EdgeInsets.all(3),
                      decoration: BoxDecoration(color: Colors.grey.shade600, shape: BoxShape.circle),
                      child: const Icon(Icons.lock, color: Colors.white, size: 9),
                    ),
                  ),
                if (isUnlocked)
                  Positioned(
                    right: -4, bottom: -4,
                    child: Container(
                      padding: const EdgeInsets.all(3),
                      decoration: BoxDecoration(color: color, shape: BoxShape.circle),
                      child: const Icon(Icons.check, color: Colors.white, size: 9),
                    ),
                  ),
              ],
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(children: [
                    Expanded(
                      child: Text(
                        reward['label'] as String? ?? '',
                        style: GoogleFonts.spaceGrotesk(
                          fontSize: 14,
                          fontWeight: FontWeight.w800,
                          color: isUnlocked
                              ? (Theme.of(context).textTheme.titleLarge?.color ?? AppTheme.deepNavy)
                              : Colors.grey.shade500,
                        ),
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: (isUnlocked ? color : Colors.grey).withOpacity(0.12),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Row(mainAxisSize: MainAxisSize.min, children: [
                        Icon(icon, color: isUnlocked ? color : Colors.grey, size: 10),
                        const SizedBox(width: 3),
                        Text(
                          type,
                          style: GoogleFonts.inter(
                            fontSize: 9, fontWeight: FontWeight.w700,
                            color: isUnlocked ? color : Colors.grey,
                          ),
                        ),
                      ]),
                    ),
                  ]),
                  const SizedBox(height: 3),
                  Text(
                    reward['description'] as String? ?? '',
                    style: GoogleFonts.inter(fontSize: 11, color: AppTheme.textMuted),
                    maxLines: 2, overflow: TextOverflow.ellipsis,
                  ),
                  if (isUnlocked) ...[
                    const SizedBox(height: 6),
                    Row(children: [
                      Icon(Icons.check_circle_rounded, color: color, size: 12),
                      const SizedBox(width: 4),
                      Text('Débloqué ✓',
                        style: GoogleFonts.inter(fontSize: 10, color: color, fontWeight: FontWeight.w700)),
                    ]),
                  ],
                ],
              ),
            ),
          ]),
        ).animate().fadeIn(delay: Duration(milliseconds: 300 + i * 50)).slideY(begin: 0.08);
      }).toList(),
    );
  }

  Widget _buildStaticRewardsGrid() {
    final cards = [
      (
        title: "Bon d'achat 10 DT",
        points: '1000 pts',
        icon: Icons.confirmation_number_rounded,
        grad: [const Color(0xFF064E3B), const Color(0xFF0D9488)],
        asset: 'assets/images/reward_voucher.png',
        threshold: 1000.0,
        h: 220.0,
      ),
      (
        title: 'Sac en toile bio',
        points: '1500 pts',
        icon: Icons.shopping_bag_rounded,
        grad: [const Color(0xFF3B0764), const Color(0xFF7C3AED)],
        asset: 'assets/images/reward_ecobag.png',
        threshold: 1500.0,
        h: 260.0,
      ),
      (
        title: 'Gourde ecologique',
        points: '2500 pts',
        icon: Icons.water_drop_rounded,
        grad: [const Color(0xFF0C4A6E), const Color(0xFF0891B2)],
        asset: 'assets/images/card_community.png',
        threshold: 2500.0,
        h: 260.0,
      ),
      (
        title: "Plantation d'arbre",
        points: '3000 pts',
        icon: Icons.park_rounded,
        grad: [const Color(0xFF14532D), const Color(0xFF059669)],
        asset: 'assets/images/card_impact.png',
        threshold: 3000.0,
        h: 220.0,
      ),
    ];

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: Column(children: [
            _buildRewardCard(cards[0], _score),
            const SizedBox(height: 16),
            _buildRewardCard(cards[1], _score),
          ]),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: Column(children: [
            _buildRewardCard(cards[2], _score),
            const SizedBox(height: 16),
            _buildRewardCard(cards[3], _score),
          ]),
        ),
      ],
    ).animate().fadeIn(delay: 500.ms).slideY(begin: 0.1);
  }

  Widget _buildRewardCard(
    ({String title, String points, IconData icon, List<Color> grad, String asset, double threshold, double h}) card,
    double score,
  ) {
    final unlocked = score >= card.threshold;
    return Container(
      height: card.h,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(28),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(unlocked ? 0.2 : 0.08),
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(28),
        child: Stack(
          fit: StackFit.expand,
          children: [
            // Image illustrative du produit
            Image.asset(
              card.asset,
              fit: BoxFit.cover,
              errorBuilder: (c, e, s) => Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: card.grad,
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                ),
                child: Center(
                  child: Icon(card.icon, size: 72, color: Colors.white.withOpacity(0.4)),
                ),
              ),
            ),
            // Overlay flou si verrouille
            if (!unlocked)
              BackdropFilter(
                filter: ImageFilter.blur(sigmaX: 3, sigmaY: 3),
                child: Container(color: Colors.black.withOpacity(0.4)),
              ),
            // Degradé sombre en bas pour le texte
            Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [Colors.transparent, Colors.black.withOpacity(0.80)],
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  stops: const [0.35, 1.0],
                ),
              ),
            ),
            // Badge points
            Positioned(
              top: 12, right: 12,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  color: unlocked
                      ? Colors.white.withOpacity(0.95)
                      : Colors.black.withOpacity(0.55),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (!unlocked) ...[
                      const Icon(Icons.lock, color: Colors.white70, size: 10),
                      const SizedBox(width: 4),
                    ],
                    Text(
                      L10n.tr(card.points),
                      style: GoogleFonts.outfit(
                        color: unlocked ? card.grad.last : Colors.white70,
                        fontWeight: FontWeight.w900,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            // Titre
            Positioned(
              left: 16, right: 16, bottom: 16,
              child: Text(
                L10n.tr(card.title),
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

  String _formatDate(String? iso) {
    if (iso == null || iso.isEmpty) return '';
    try {
      final dt   = DateTime.parse(iso).toLocal();
      final now  = DateTime.now();
      final diff = now.difference(dt);
      if (diff.inDays == 0) {
        if (diff.inHours == 0) return 'Il y a ${diff.inMinutes}min';
        return 'Il y a ${diff.inHours}h';
      }
      if (diff.inDays == 1) return 'Hier';
      if (diff.inDays < 7) return 'Il y a ${diff.inDays} jours';
      return '${dt.day}/${dt.month}/${dt.year}';
    } catch (_) { return ''; }
  }
}

// ── Data classes ──────────────────────────────────────────────────────────────

class _BadgeData {
  final IconData icon;
  final Color color;
  final String title;
  final bool unlocked;
  final String hint;
  const _BadgeData(this.icon, this.color, this.title, this.unlocked, this.hint);
}

class _ImpactTile {
  final IconData icon;
  final Color color;
  final String value;
  final String label;
  final String sublabel;
  const _ImpactTile({required this.icon, required this.color, required this.value, required this.label, required this.sublabel});
}
