import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:google_fonts/google_fonts.dart';
import 'dart:ui';
import '../../theme/app_theme.dart';
import '../../widgets/safe_network_image.dart';
import '../../models/user_model.dart';
import '../../services/auth_service.dart';
import '../../services/l10n_service.dart';



class RewardsTab extends StatefulWidget {
  const RewardsTab({Key? key}) : super(key: key);

  @override
  State<RewardsTab> createState() => _RewardsTabState();
}

class _RewardsTabState extends State<RewardsTab> {
  final AuthService _authService = AuthService();

  // Score & loading
  double _score = 0;
  bool _loaded = false;
  bool _loading = false;

  // Stats depuis /users/me/stats
  int _postsCount = 0;
  int _likesReceived = 0;

  // Depuis /users/me/points-history
  List<dynamic> _history = [];
  int _scanCount = 0;
  int _quizCount = 0;
  double _totalScanPoints = 0;
  double _totalQuizPoints = 0;

  // Impact écologique
  double _co2Saved = 0;
  int _treesEquivalent = 0;

  @override
  void initState() {
    super.initState();
    L10n.addListener(_onLocaleChange);
    _loadAll();
  }

  void _onLocaleChange() {
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    L10n.removeListener(_onLocaleChange);
    super.dispose();
  }

  // ── Chargement de toutes les données ─────────────────────────────────────

  Future<void> _loadAll() async {
    if (_loading) return;
    if (mounted) setState(() { _loading = true; });

    // Affichage immédiat du cache local
    final cached = AuthState.currentUser?.globalScore ?? 0;
    if (mounted) setState(() { _score = cached; _loaded = true; });

    if (!AuthState.isLoggedIn) {
      if (mounted) setState(() { _loading = false; });
      return;
    }

    try {
      // 2 appels parallèles : profil + impact personnel unifié
      final results = await Future.wait([
        _authService.fetchUserProfile(),
        _authService.fetchMyImpact(),
        _authService.fetchPointsHistory(),
      ]);

      final profile = results[0] as Map<String, dynamic>?;
      final impact  = results[1] as Map<String, dynamic>;
      final history = results[2] as List<dynamic>;

      if (!mounted) return;

      // Score mis à jour
      if (profile != null) {
        AuthState.currentUser = User.fromBackend(profile);
        _score = AuthState.currentUser?.globalScore ?? cached;
      }

      // Impact personnel depuis /users/me/impact
      _scanCount        = (impact['scan_count']        as num?)?.toInt()    ?? 0;
      _quizCount        = (impact['quiz_count']        as num?)?.toInt()    ?? 0;
      _totalScanPoints  = (impact['total_scan_points'] as num?)?.toDouble() ?? 0;
      _totalQuizPoints  = (impact['total_quiz_points'] as num?)?.toDouble() ?? 0;
      _co2Saved         = (impact['co2_saved_kg']      as num?)?.toDouble() ?? (_scanCount * 0.25);
      _treesEquivalent  = (impact['trees_equivalent']  as num?)?.toInt()    ?? 0;
      _postsCount       = (impact['posts_count']       as num?)?.toInt()    ?? 0;
      _likesReceived    = (impact['likes_received']    as num?)?.toInt()    ?? 0;

      // Historique pour le mini-feed
      _history = history;

      if (mounted) {
        setState(() {
          _loaded  = true;
          _loading = false;
        });
      }
    } catch (e) {
      if (mounted) setState(() { _loading = false; });
    }
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

  // ── Build ─────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final level = _computeLevel(_score);
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
                    _buildScoreCard(level),
                    const SizedBox(height: 32),
                    _buildSectionTitle(L10n.tr('Niveaux & Avantages')),
                    const SizedBox(height: 16),
                    _buildLevelCarousel(level),
                    const SizedBox(height: 32),
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
        child: Container(
          height: 1,
          color: Theme.of(context).dividerColor,
        ),
      ),
    );
  }

  // ── Score Card ────────────────────────────────────────────────────────────

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
                      L10n.tr(level.label),
                      style: GoogleFonts.inter(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
              // Loading indicator
              if (_loading)
                const SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    valueColor: AlwaysStoppedAnimation<Color>(Colors.white38),
                  ),
                )
              else
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
            L10n.tr('Solde Actuel'),
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
                L10n.tr('pts'),
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
                  L10n.isArabic
                      ? 'إلى ${L10n.tr(_nextLevelLabel(nextScore))}'
                      : 'Vers ${_nextLevelLabel(nextScore)}',
                  style: GoogleFonts.inter(
                      color: Colors.white.withOpacity(0.7), fontSize: 11),
                ),
                Text(
                  L10n.isArabic
                      ? '${(_score).toStringAsFixed(0)} / $nextScore ن'
                      : '${(_score).toStringAsFixed(0)} / $nextScore pts',
                  style: GoogleFonts.inter(
                      color: Colors.white.withOpacity(0.8),
                      fontSize: 11,
                      fontWeight: FontWeight.w700),
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
                valueColor:
                    const AlwaysStoppedAnimation<Color>(AppTheme.accentMint),
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
                const Icon(Icons.workspace_premium_rounded,
                    color: AppTheme.accentMint, size: 16),
                const SizedBox(width: 6),
                Text(
                  L10n.tr('Niveau Maximum atteint ! 🎉'),
                  style: GoogleFonts.inter(
                      color: Colors.white,
                      fontSize: 12,
                      fontWeight: FontWeight.w700),
                ),
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

  // ── Level carousel ────────────────────────────────────────────────────────

  Widget _buildLevelCarousel(_LevelInfo current) {
    const levels = [
      _LevelData('Éco-Citoyen',  'Niveau de départ',           Icons.eco_rounded,                Color(0xFF10B981), 0),
      _LevelData('Champion Vert','2 000 pts',                   Icons.emoji_events_rounded,       Color(0xFFF59E0B), 2000),
      _LevelData('Légende Éco',  '5 000 pts',                  Icons.workspace_premium_rounded,  Color(0xFF8B5CF6), 5000),
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
          final isCurrent  = current.label == lvl.name;
          final isUnlocked = _score >= lvl.threshold;
          return Padding(
            padding: EdgeInsets.only(right: i < levels.length - 1 ? 16 : 0),
            child: _buildLevelCard(
              L10n.tr(lvl.name), L10n.tr(lvl.subtitle),
              lvl.icon, lvl.color, isCurrent, isUnlocked,
            ),
          );
        },
      ),
    ).animate().fadeIn(delay: 300.ms).slideX(begin: 0.1);
  }

  Widget _buildLevelCard(String title, String subtitle, IconData icon,
      Color color, bool isCurrent, bool isUnlocked) {
    return Container(
      width: 150,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: isCurrent
            ? color
            : (isUnlocked
                ? color.withOpacity(0.08)
                : Theme.of(context).colorScheme.surface),
        borderRadius: BorderRadius.circular(28),
        border: isCurrent
            ? null
            : Border.all(
                color: isUnlocked
                    ? color.withOpacity(0.3)
                    : Theme.of(context).dividerColor),
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
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: isCurrent
                      ? Colors.white.withOpacity(0.2)
                      : color.withOpacity(0.1),
                  shape: BoxShape.circle,
                ),
                child: Icon(icon,
                    color: isCurrent ? Colors.white : color, size: 28),
              ),
              if (!isUnlocked && !isCurrent)
                Positioned(
                  right: 0,
                  top: 0,
                  child: Container(
                    padding: const EdgeInsets.all(3),
                    decoration: const BoxDecoration(
                        color: Colors.grey, shape: BoxShape.circle),
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
                  color: isCurrent
                      ? Colors.white
                      : (isUnlocked
                          ? color
                          : Theme.of(context).textTheme.titleLarge?.color ??
                              AppTheme.deepNavy),
                  height: 1.1,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                isCurrent
                    ? (L10n.isArabic ? 'المستوى الحالي ✓' : 'Niveau Actuel ✓')
                    : subtitle,
                style: GoogleFonts.inter(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  color: isCurrent
                      ? Colors.white.withOpacity(0.8)
                      : AppTheme.textMuted,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // ── Impact Écologique ─────────────────────────────────────────────────────

  Widget _buildImpactSection() {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    if (!_loaded && !_loading) {
      return const SizedBox.shrink();
    }

    final tiles = [
      _ImpactTile(
        icon: Icons.recycling_rounded,
        color: const Color(0xFF10B981),
        value: _scanCount.toString(),
        label: L10n.isArabic ? 'عمليات الفرز' : 'Tris effectués',
        sublabel: L10n.isArabic
            ? '${_totalScanPoints.toStringAsFixed(0)} ن'
            : '${_totalScanPoints.toStringAsFixed(0)} pts gagnés',
      ),
      _ImpactTile(
        icon: Icons.eco_rounded,
        color: const Color(0xFF00B894),
        value: '${_co2Saved.toStringAsFixed(1)} kg',
        label: L10n.isArabic ? 'CO₂ موفر' : 'CO₂ économisé',
        sublabel: L10n.isArabic
            ? '$_treesEquivalent شجرة مكافئة'
            : '$_treesEquivalent arbre(s)',
      ),
      _ImpactTile(
        icon: Icons.quiz_rounded,
        color: const Color(0xFF8B5CF6),
        value: _quizCount.toString(),
        label: L10n.isArabic ? 'اختبارات' : 'Quiz joués',
        sublabel: L10n.isArabic
            ? '${_totalQuizPoints.toStringAsFixed(0)} ن'
            : '${_totalQuizPoints.toStringAsFixed(0)} pts gagnés',
      ),
      _ImpactTile(
        icon: Icons.article_rounded,
        color: const Color(0xFF3B82F6),
        value: _postsCount.toString(),
        label: L10n.isArabic ? 'منشورات' : 'Posts publiés',
        sublabel: L10n.isArabic
            ? '$_likesReceived إعجاب'
            : '$_likesReceived like(s)',
      ),
    ];

    return GridView.builder(
      physics: const NeverScrollableScrollPhysics(),
      shrinkWrap: true,
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        crossAxisSpacing: 12,
        mainAxisSpacing: 12,
        childAspectRatio: 1.15,
      ),
      itemCount: tiles.length,
      itemBuilder: (_, i) {
        final t = tiles[i];
        return Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: isDark
                ? t.color.withOpacity(0.08)
                : t.color.withOpacity(0.05),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: t.color.withOpacity(0.15), width: 1.2),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: t.color.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(t.icon, color: t.color, size: 20),
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _loading
                      ? Container(
                          width: 50,
                          height: 20,
                          decoration: BoxDecoration(
                            color: t.color.withOpacity(0.15),
                            borderRadius: BorderRadius.circular(6),
                          ),
                        )
                      : Text(
                          t.value,
                          style: GoogleFonts.spaceGrotesk(
                            fontSize: 20,
                            fontWeight: FontWeight.w900,
                            color: t.color,
                          ),
                        ),
                  Text(
                    t.label,
                    style: GoogleFonts.inter(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      color: isDark ? Colors.white70 : AppTheme.deepNavy,
                    ),
                  ),
                  Text(
                    _loading ? '...' : t.sublabel,
                    style: GoogleFonts.inter(
                      fontSize: 10,
                      color: AppTheme.textMuted,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ).animate().fadeIn(delay: Duration(milliseconds: 200 + i * 80)).slideY(begin: 0.1);
      },
    );
  }

  // ── Badges dynamiques ──────────────────────────────────────────────────────

  Widget _buildBadgesGrid(BuildContext context) {
    final badges = [
      _BadgeData(
        Icons.recycling_rounded,
        const Color(0xFF3B82F6),
        L10n.isArabic ? 'أول فرز' : 'Premier Tri',
        _scanCount >= 1,
        L10n.isArabic ? 'افرز ولو مرة واحدة' : 'Effectuer au moins 1 scan',
      ),
      _BadgeData(
        Icons.local_fire_department_rounded,
        const Color(0xFFF59E0B),
        L10n.isArabic ? 'سلسلة 7 أيام' : 'Série 7J',
        _score >= 100,
        L10n.isArabic ? '100 نقطة مطلوبة' : '100 pts requis',
      ),
      _BadgeData(
        Icons.quiz_rounded,
        const Color(0xFF8B5CF6),
        L10n.isArabic ? 'خبير الاختبارات' : 'Expert Quiz',
        _quizCount >= 1,
        L10n.isArabic ? 'أكمل اختباراً واحداً' : 'Compléter 1 quiz',
      ),
      _BadgeData(
        Icons.groups_rounded,
        const Color(0xFF10B981),
        L10n.isArabic ? 'المجتمع' : 'Communauté',
        _postsCount >= 1,
        L10n.isArabic ? 'انشر منشوراً واحداً' : 'Publier 1 post',
      ),
    ];

    final double screenWidth = MediaQuery.of(context).size.width;
    final int crossAxisCount =
        screenWidth > 900 ? 4 : (screenWidth > 600 ? 3 : 2);
    final double cardWidth =
        (screenWidth - 40 - ((crossAxisCount - 1) * 16)) / crossAxisCount;

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
            color: b.unlocked
                ? color.withOpacity(0.05)
                : Theme.of(context).colorScheme.surface,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: b.unlocked
                  ? color.withOpacity(0.2)
                  : Theme.of(context).dividerColor,
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(9),
                    decoration: BoxDecoration(
                      color: b.unlocked
                          ? color.withOpacity(0.15)
                          : (Theme.of(context).brightness == Brightness.dark
                              ? Colors.white.withOpacity(0.05)
                              : Colors.grey.shade200),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(b.icon, color: color, size: 18),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      b.title,
                      style: GoogleFonts.inter(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: b.unlocked
                            ? (Theme.of(context).textTheme.titleLarge?.color ??
                                AppTheme.deepNavy)
                            : Colors.grey.shade500,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              if (b.unlocked)
                Row(
                  children: [
                    Icon(Icons.check_circle_rounded, color: color, size: 12),
                    const SizedBox(width: 4),
                    Text(
                      L10n.isArabic ? 'مفتوح ✓' : 'Débloqué ✓',
                      style: GoogleFonts.inter(
                          fontSize: 10, color: color, fontWeight: FontWeight.w700),
                    ),
                  ],
                )
              else
                Row(
                  children: [
                    Icon(Icons.lock_rounded, color: Colors.grey.shade400, size: 11),
                    const SizedBox(width: 4),
                    Expanded(
                      child: Text(
                        b.hint,
                        style: GoogleFonts.inter(
                            fontSize: 9, color: Colors.grey.shade400),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
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
            color: isDark
                ? color.withOpacity(0.06)
                : color.withOpacity(0.04),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: color.withOpacity(0.12)),
          ),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: color.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(icon, color: color, size: 16),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      desc.isNotEmpty ? desc : (isQuiz ? 'Quiz complété' : 'Tri effectué'),
                      style: GoogleFonts.inter(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: isDark ? Colors.white.withOpacity(0.87) : AppTheme.deepNavy,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    if (date.isNotEmpty)
                      Text(
                        date,
                        style: GoogleFonts.inter(
                            fontSize: 10, color: AppTheme.textMuted),
                      ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: color.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  '+${points.toStringAsFixed(0)} pts',
                  style: GoogleFonts.spaceGrotesk(
                    color: color,
                    fontWeight: FontWeight.w800,
                    fontSize: 12,
                  ),
                ),
              ),
            ],
          ),
        ).animate().fadeIn(delay: Duration(milliseconds: 300 + i * 60)).slideX(begin: 0.05);
      }).toList(),
    );
  }

  String _formatDate(String? iso) {
    if (iso == null || iso.isEmpty) return '';
    try {
      final dt = DateTime.parse(iso).toLocal();
      final now = DateTime.now();
      final diff = now.difference(dt);
      if (diff.inDays == 0) {
        if (diff.inHours == 0) return L10n.isArabic ? 'منذ ${diff.inMinutes} د' : 'Il y a ${diff.inMinutes}min';
        return L10n.isArabic ? 'منذ ${diff.inHours} س' : 'Il y a ${diff.inHours}h';
      }
      if (diff.inDays == 1) return L10n.isArabic ? 'أمس' : 'Hier';
      if (diff.inDays < 7) return L10n.isArabic ? 'منذ ${diff.inDays} أيام' : 'Il y a ${diff.inDays} jours';
      return '${dt.day}/${dt.month}/${dt.year}';
    } catch (_) {
      return '';
    }
  }

  // ── Récompenses exclusives ────────────────────────────────────────────────

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
                imageUrl:
                    'https://images.unsplash.com/photo-1542838132-92c53300491e?w=400&q=80',
                height: 220,
                unlocked: _score >= 1000,
              ),
              const SizedBox(height: 16),
              _buildRewardCard(
                title: 'Sac en toile bio',
                points: '1500 pts',
                imageUrl:
                    'https://images.unsplash.com/photo-1597348989645-46b190ce4918?w=400&q=80',
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
                imageUrl:
                    'https://images.unsplash.com/photo-1602143407151-7111542de6e8?w=400&q=80',
                height: 260,
                unlocked: _score >= 2500,
              ),
              const SizedBox(height: 16),
              _buildRewardCard(
                title: 'Plantation d\'arbre',
                points: '3000 pts',
                imageUrl:
                    'https://images.unsplash.com/photo-1542601906990-b4d3fb778b09?w=400&q=80',
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
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  color: unlocked
                      ? Colors.white.withOpacity(0.95)
                      : Colors.black.withOpacity(0.6),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (!unlocked)
                      const Icon(Icons.lock, color: Colors.white70, size: 10),
                    if (!unlocked) const SizedBox(width: 4),
                    Text(
                      L10n.tr(points),
                      style: GoogleFonts.outfit(
                        color: unlocked
                            ? AppTheme.primaryGreen
                            : Colors.white70,
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
                L10n.tr(title),
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
  final String hint;
  const _BadgeData(this.icon, this.color, this.title, this.unlocked, this.hint);
}

class _ImpactTile {
  final IconData icon;
  final Color color;
  final String value;
  final String label;
  final String sublabel;
  const _ImpactTile({
    required this.icon,
    required this.color,
    required this.value,
    required this.label,
    required this.sublabel,
  });
}
