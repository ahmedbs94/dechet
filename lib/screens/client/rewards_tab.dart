import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../theme/app_theme.dart';
import '../../widgets/glass_card.dart';
import '../../models/user_model.dart';
import 'dart:math';

class RewardsTab extends StatelessWidget {
  const RewardsTab({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final user = AuthState.currentUser;
    final isLoggedIn = user != null;
    final userPoints = user?.points ?? 0;
    final userName = user?.name ?? 'Visiteur';

    // Déterminer le niveau de l'utilisateur
    String currentLevel;
    Color levelColor;
    double levelProgress;
    int nextLevelPoints;

    if (userPoints >= 5000) {
      currentLevel = 'Élite';
      levelColor = const Color(0xFFF59E0B);
      levelProgress = 1.0;
      nextLevelPoints = 5000;
    } else if (userPoints >= 2500) {
      currentLevel = 'Ambassadeur';
      levelColor = const Color(0xFF8B5CF6);
      levelProgress = (userPoints - 2500) / 2500;
      nextLevelPoints = 5000;
    } else if (userPoints >= 1000) {
      currentLevel = 'Expert';
      levelColor = const Color(0xFF3B82F6);
      levelProgress = (userPoints - 1000) / 1500;
      nextLevelPoints = 2500;
    } else if (userPoints >= 500) {
      currentLevel = 'Engagé';
      levelColor = const Color(0xFF10B981);
      levelProgress = (userPoints - 500) / 500;
      nextLevelPoints = 1000;
    } else {
      currentLevel = 'Débutant';
      levelColor = const Color(0xFF94A3B8);
      levelProgress = userPoints / 500;
      nextLevelPoints = 500;
    }

    return SingleChildScrollView(
      physics: const BouncingScrollPhysics(),
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Animate(
            effects: const [FadeEffect(), SlideEffect(begin: Offset(-0.1, 0))],
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Récompenses',
                        style:
                            GoogleFonts.outfit(fontSize: 32, fontWeight: FontWeight.bold, color: AppTheme.deepSlate)),
                    Text('Triez et gagnez des cadeaux',
                        style: GoogleFonts.inter(color: AppTheme.textMuted, fontSize: 13)),
                  ],
                ),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF59E0B).withOpacity(0.1),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.card_giftcard_rounded, color: Color(0xFFF59E0B), size: 28),
                ),
              ],
            ),
          ),

          const SizedBox(height: 24),

          // ============================================
          // CARTE DE SCORE DE L'UTILISATEUR (données réelles)
          // ============================================
          if (isLoggedIn) ...[
            Animate(
              effects: [FadeEffect(delay: 100.ms), const SlideEffect(begin: Offset(0, 0.05))],
              child: Container(
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFF0A3D2E), Color(0xFF0F172A)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(28),
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFF0F172A).withOpacity(0.3),
                      blurRadius: 25,
                      offset: const Offset(0, 12),
                    ),
                  ],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        CircleAvatar(
                          radius: 24,
                          backgroundColor: AppTheme.primaryGreen.withOpacity(0.2),
                          child: Text(
                            userName.isNotEmpty ? userName[0].toUpperCase() : '?',
                            style: GoogleFonts.outfit(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.white),
                          ),
                        ),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(userName,
                                  style: GoogleFonts.outfit(
                                      color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
                              Row(
                                children: [
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                    decoration: BoxDecoration(
                                      color: levelColor.withOpacity(0.2),
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                    child: Text(currentLevel.toUpperCase(),
                                        style: GoogleFonts.outfit(
                                            color: levelColor,
                                            fontSize: 10,
                                            fontWeight: FontWeight.w900,
                                            letterSpacing: 1)),
                                  ),
                                  const SizedBox(width: 8),
                                  Text(user.roleDisplayName,
                                      style: GoogleFonts.inter(color: Colors.white54, fontSize: 11)),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 24),
                    Row(
                      children: [
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('VOS POINTS',
                                style: GoogleFonts.inter(
                                    color: AppTheme.accentMint,
                                    fontSize: 10,
                                    fontWeight: FontWeight.w900,
                                    letterSpacing: 1.5)),
                            const SizedBox(height: 6),
                            Row(
                              crossAxisAlignment: CrossAxisAlignment.end,
                              children: [
                                Text('$userPoints',
                                    style: GoogleFonts.outfit(
                                        color: Colors.white, fontSize: 36, fontWeight: FontWeight.w900)),
                                Padding(
                                  padding: const EdgeInsets.only(bottom: 6, left: 4),
                                  child: Text('pts',
                                      style: GoogleFonts.inter(
                                          color: Colors.white38, fontSize: 14, fontWeight: FontWeight.w600)),
                                ),
                              ],
                            ),
                          ],
                        ),
                        const Spacer(),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            Text('PROCHAIN NIVEAU',
                                style: GoogleFonts.inter(
                                    color: Colors.white38, fontSize: 9, fontWeight: FontWeight.w800, letterSpacing: 1)),
                            const SizedBox(height: 4),
                            Text('$nextLevelPoints pts',
                                style:
                                    GoogleFonts.outfit(color: levelColor, fontSize: 16, fontWeight: FontWeight.w800)),
                          ],
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(10),
                      child: LinearProgressIndicator(
                        value: levelProgress,
                        minHeight: 8,
                        backgroundColor: Colors.white.withOpacity(0.1),
                        color: levelColor,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      '${(levelProgress * 100).toInt()}% vers $currentLevel',
                      style: GoogleFonts.inter(color: Colors.white38, fontSize: 11),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 28),

            // ============================================
            // MON IMPACT ENVIRONNEMENTAL (PERSONNALISÉ)
            // ============================================
            _buildSectionHeader('MON IMPACT ENVIRONNEMENTAL'),
            const SizedBox(height: 6),
            Text('Basé sur votre activité de tri',
                style: GoogleFonts.inter(color: AppTheme.textMuted, fontSize: 12)),
            const SizedBox(height: 16),
            _buildPersonalImpactGrid(userPoints),
            const SizedBox(height: 28),

            // ============================================
            // MES ACTIVITÉS RÉCENTES
            // ============================================
            _buildSectionHeader('MON HISTORIQUE'),
            const SizedBox(height: 16),
            _buildPersonalActivityTimeline(userPoints, userName),
            const SizedBox(height: 32),
          ],

          // ============================================
          // COMMENT GAGNER DES POINTS
          // ============================================
          _buildSectionHeader('COMMENT GAGNER DES POINTS'),
          const SizedBox(height: 16),
          _buildHowToEarnCard(
            icon: Icons.qr_code_2_rounded,
            title: 'Déposez aux bornes',
            description:
                'Présentez votre badge QR à la borne de tri. La borne pèse vos déchets et calcule vos points automatiquement.',
            points: '10 à 50 pts',
            color: AppTheme.primaryGreen,
            delay: 0,
          ),
          const SizedBox(height: 12),
          _buildHowToEarnCard(
            icon: Icons.quiz_rounded,
            title: 'Répondez aux quiz',
            description: 'Testez vos connaissances sur le tri et l\'environnement pour gagner des points bonus.',
            points: '50 à 120 pts',
            color: const Color(0xFF3B82F6),
            delay: 100,
          ),
          const SizedBox(height: 12),
          _buildHowToEarnCard(
            icon: Icons.people_alt_rounded,
            title: 'Parrainez un ami',
            description: 'Invitez vos proches à rejoindre EcoRewind et recevez des points de parrainage.',
            points: '200 pts',
            color: const Color(0xFF8B5CF6),
            delay: 200,
          ),

          const SizedBox(height: 40),

          // ============================================
          // BADGES DISPONIBLES
          // ============================================
          _buildSectionHeader('BADGES À DÉBLOQUER'),
          const SizedBox(height: 16),
          SizedBox(
            height: 170,
            child: ListView(
              scrollDirection: Axis.horizontal,
              physics: const BouncingScrollPhysics(),
              children: [
                _buildBadgeCard('Éco-Débutant', 'Première dépose', Icons.spa_rounded, const Color(0xFF10B981), '0 pts',
                    userPoints >= 0),
                _buildBadgeCard('Tri Expert', '500 points cumulés', Icons.recycling_rounded, const Color(0xFF3B82F6),
                    '500 pts', userPoints >= 500),
                _buildBadgeCard('Sentinelle Verte', '1 000 points', Icons.security_rounded, const Color(0xFF8B5CF6),
                    '1 000 pts', userPoints >= 1000),
                _buildBadgeCard('Élite Éco', 'Top 1% utilisateurs', Icons.workspace_premium_rounded,
                    const Color(0xFFF59E0B), '2 500 pts', userPoints >= 2500),
                _buildBadgeCard('Zéro Carbone', 'Champion du climat', Icons.eco_rounded, const Color(0xFF059669),
                    '5 000 pts', userPoints >= 5000),
              ],
            ),
          ),

          const SizedBox(height: 40),

          // ============================================
          // CATALOGUE DE RÉCOMPENSES
          // ============================================
          _buildSectionHeader('CATALOGUE DES RÉCOMPENSES'),
          const SizedBox(height: 16),
          _buildRewardCatalogCard(
            title: 'Bon d\'achat 5 DT',
            partner: 'Carrefour Market',
            cost: '250 pts',
            icon: Icons.shopping_cart_rounded,
            color: const Color(0xFF3B82F6),
            canRedeem: userPoints >= 250,
          ),
          const SizedBox(height: 12),
          _buildRewardCatalogCard(
            title: 'Entrée gratuite piscine',
            partner: 'Centre Sportif Municipal',
            cost: '400 pts',
            icon: Icons.pool_rounded,
            color: const Color(0xFF06B6D4),
            canRedeem: userPoints >= 400,
          ),
          const SizedBox(height: 12),
          _buildRewardCatalogCard(
            title: 'Menu offert',
            partner: 'Restaurant Le Vert',
            cost: '600 pts',
            icon: Icons.restaurant_rounded,
            color: const Color(0xFFF59E0B),
            canRedeem: userPoints >= 600,
          ),
          const SizedBox(height: 12),
          _buildRewardCatalogCard(
            title: 'Réduction -20%',
            partner: 'Boutique Éco-Responsable',
            cost: '150 pts',
            icon: Icons.storefront_rounded,
            color: const Color(0xFF10B981),
            canRedeem: userPoints >= 150,
          ),
          const SizedBox(height: 12),
          _buildRewardCatalogCard(
            title: 'Arbre planté en votre nom',
            partner: 'Association Forêt Verte',
            cost: '1 000 pts',
            icon: Icons.park_rounded,
            color: const Color(0xFF059669),
            canRedeem: userPoints >= 1000,
          ),

          const SizedBox(height: 40),

          // ============================================
          // NIVEAUX DE PROGRESSION
          // ============================================
          _buildSectionHeader('NIVEAUX DE PROGRESSION'),
          const SizedBox(height: 16),
          _buildLevelCard('Débutant', '0 - 499 pts', userPoints >= 0 ? (userPoints < 500 ? userPoints / 500 : 1.0) : 0,
              const Color(0xFF94A3B8), userPoints < 500 && userPoints >= 0),
          _buildLevelCard(
              'Engagé',
              '500 - 999 pts',
              userPoints >= 500 ? (userPoints < 1000 ? (userPoints - 500) / 500 : 1.0) : 0,
              const Color(0xFF10B981),
              userPoints >= 500 && userPoints < 1000),
          _buildLevelCard(
              'Expert',
              '1 000 - 2 499 pts',
              userPoints >= 1000 ? (userPoints < 2500 ? (userPoints - 1000) / 1500 : 1.0) : 0,
              const Color(0xFF3B82F6),
              userPoints >= 1000 && userPoints < 2500),
          _buildLevelCard(
              'Ambassadeur',
              '2 500 - 4 999 pts',
              userPoints >= 2500 ? (userPoints < 5000 ? (userPoints - 2500) / 2500 : 1.0) : 0,
              const Color(0xFF8B5CF6),
              userPoints >= 2500 && userPoints < 5000),
          _buildLevelCard(
              'Élite', '5 000+ pts', userPoints >= 5000 ? 1.0 : 0, const Color(0xFFF59E0B), userPoints >= 5000),

          // CTA pour les non-connectés
          if (!isLoggedIn) ...[
            const SizedBox(height: 40),
            Center(
              child: GlassCard(
                padding: const EdgeInsets.all(28),
                child: Column(
                  children: [
                    const Icon(Icons.stars_rounded, color: Color(0xFFF59E0B), size: 48),
                    const SizedBox(height: 16),
                    Text(
                      'Commencez à cumuler des points !',
                      textAlign: TextAlign.center,
                      style: GoogleFonts.outfit(fontSize: 20, fontWeight: FontWeight.bold, color: AppTheme.deepSlate),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Créez votre compte gratuit pour commencer à gagner des récompenses à chaque geste de tri.',
                      textAlign: TextAlign.center,
                      style: GoogleFonts.inter(fontSize: 13, color: AppTheme.textMuted, height: 1.5),
                    ),
                    const SizedBox(height: 20),
                    ElevatedButton(
                      onPressed: () => Navigator.pushNamed(context, '/signup'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppTheme.primaryGreen,
                        foregroundColor: Colors.white,
                        minimumSize: const Size(double.infinity, 52),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                      ),
                      child: Text('CRÉER MON COMPTE',
                          style: GoogleFonts.outfit(fontWeight: FontWeight.w800, letterSpacing: 1)),
                    ),
                  ],
                ),
              ),
            ).animate().fadeIn(delay: 400.ms).slideY(begin: 0.1),
          ],

          const SizedBox(height: 120),
        ],
      ),
    );
  }

  Widget _buildSectionHeader(String title) {
    return Text(
      title,
      style:
          GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w900, letterSpacing: 1.5, color: AppTheme.textMuted),
    );
  }

  Widget _buildHowToEarnCard({
    required IconData icon,
    required String title,
    required String description,
    required String points,
    required Color color,
    required int delay,
  }) {
    return Animate(
      effects: [FadeEffect(delay: delay.ms), SlideEffect(begin: const Offset(0, 0.05), delay: delay.ms)],
      child: GlassCard(
        padding: const EdgeInsets.all(20),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                gradient: LinearGradient(colors: [color.withOpacity(0.2), color.withOpacity(0.05)]),
                shape: BoxShape.circle,
              ),
              child: Icon(icon, color: color, size: 28),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title,
                      style: GoogleFonts.outfit(fontWeight: FontWeight.bold, fontSize: 15, color: AppTheme.deepSlate)),
                  const SizedBox(height: 4),
                  Text(description,
                      style: GoogleFonts.inter(fontSize: 12, color: AppTheme.textMuted, height: 1.3),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis),
                ],
              ),
            ),
            const SizedBox(width: 12),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: color.withOpacity(0.1),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Text(points, style: GoogleFonts.outfit(fontSize: 11, fontWeight: FontWeight.w800, color: color)),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBadgeCard(
      String name, String requirement, IconData icon, Color color, String pointsNeeded, bool isUnlocked) {
    return Container(
      width: 130,
      margin: const EdgeInsets.only(right: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isUnlocked ? Colors.white : Colors.grey.shade50,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: isUnlocked ? color.withOpacity(0.3) : Colors.grey.shade200, width: 1.5),
        boxShadow:
            isUnlocked ? [BoxShadow(color: color.withOpacity(0.1), blurRadius: 12, offset: const Offset(0, 6))] : [],
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Animate(
            onPlay: isUnlocked ? (c) => c.repeat(reverse: true) : null,
            effects: isUnlocked
                ? [MoveEffect(begin: const Offset(0, -2), end: const Offset(0, 2), duration: 2.seconds)]
                : [],
            child: Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: isUnlocked ? color.withOpacity(0.1) : Colors.grey.shade100,
                shape: BoxShape.circle,
                border: Border.all(color: isUnlocked ? color.withOpacity(0.2) : Colors.grey.shade200, width: 2),
              ),
              child: Icon(icon, color: isUnlocked ? color : Colors.grey.shade400, size: 28),
            ),
          ),
          const SizedBox(height: 10),
          Text(name,
              style: GoogleFonts.outfit(
                fontSize: 12,
                fontWeight: FontWeight.w800,
                color: isUnlocked ? AppTheme.deepSlate : Colors.grey.shade400,
              ),
              textAlign: TextAlign.center),
          const SizedBox(height: 4),
          Text(requirement,
              style: GoogleFonts.inter(fontSize: 9, color: AppTheme.textMuted, fontWeight: FontWeight.w500),
              textAlign: TextAlign.center,
              maxLines: 1,
              overflow: TextOverflow.ellipsis),
          const SizedBox(height: 4),
          if (isUnlocked)
            Text('✓ Débloqué', style: GoogleFonts.outfit(fontSize: 10, fontWeight: FontWeight.w700, color: color))
          else
            Text(pointsNeeded,
                style: GoogleFonts.outfit(fontSize: 10, fontWeight: FontWeight.w700, color: Colors.grey.shade400)),
        ],
      ),
    );
  }

  Widget _buildRewardCatalogCard({
    required String title,
    required String partner,
    required String cost,
    required IconData icon,
    required Color color,
    bool canRedeem = false,
  }) {
    return Animate(
      effects: const [FadeEffect(), SlideEffect(begin: Offset(0.05, 0))],
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: canRedeem ? color.withOpacity(0.2) : Colors.grey.shade100, width: 1.5),
          boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.03), blurRadius: 12, offset: const Offset(0, 4))],
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: color.withOpacity(0.1),
                borderRadius: BorderRadius.circular(14),
              ),
              child: Icon(icon, color: color, size: 24),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title,
                      style: GoogleFonts.outfit(fontWeight: FontWeight.bold, fontSize: 15, color: AppTheme.deepSlate)),
                  const SizedBox(height: 2),
                  Text(partner, style: GoogleFonts.inter(fontSize: 12, color: AppTheme.textMuted)),
                ],
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                gradient: canRedeem
                    ? LinearGradient(colors: [color, color.withOpacity(0.7)])
                    : LinearGradient(colors: [color.withOpacity(0.15), color.withOpacity(0.05)]),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                canRedeem ? 'Échanger' : cost,
                style: GoogleFonts.outfit(
                  fontSize: 13,
                  fontWeight: FontWeight.w800,
                  color: canRedeem ? Colors.white : color,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLevelCard(String name, String range, double progress, Color color, bool isCurrent) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Animate(
        effects: const [FadeEffect(), SlideEffect(begin: Offset(0, 0.05))],
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: isCurrent ? color.withOpacity(0.05) : Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: isCurrent ? color.withOpacity(0.3) : color.withOpacity(0.1)),
          ),
          child: Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: color.withOpacity(isCurrent ? 0.2 : 0.1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Center(
                  child: isCurrent
                      ? Icon(Icons.arrow_forward_rounded, color: color, size: 20)
                      : Icon(progress >= 1.0 ? Icons.check_rounded : Icons.star_rounded, color: color, size: 20),
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Row(
                          children: [
                            Text(name,
                                style: GoogleFonts.outfit(
                                    fontWeight: FontWeight.bold, fontSize: 14, color: AppTheme.deepSlate)),
                            if (isCurrent) ...[
                              const SizedBox(width: 8),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                decoration: BoxDecoration(
                                  color: color.withOpacity(0.15),
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                child: Text('ACTUEL',
                                    style: GoogleFonts.inter(
                                        fontSize: 8, fontWeight: FontWeight.w900, color: color, letterSpacing: 0.5)),
                              ),
                            ],
                          ],
                        ),
                        Text(range,
                            style: GoogleFonts.inter(
                                fontSize: 11, color: AppTheme.textMuted, fontWeight: FontWeight.w500)),
                      ],
                    ),
                    const SizedBox(height: 8),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(10),
                      child: LinearProgressIndicator(
                        value: progress.clamp(0.0, 1.0),
                        minHeight: 8,
                        backgroundColor: color.withOpacity(0.1),
                        color: color,
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

  // ============================================
  // IMPACT ENVIRONNEMENTAL PERSONNALISÉ
  // ============================================
  Widget _buildPersonalImpactGrid(int points) {
    // Calculs basés sur les points réels de l'utilisateur
    // 1 point ≈ 0.5 kg de déchets triés
    // 1 kg de déchets triés ≈ 2.5 kg CO2 évités
    // 1 kg de déchets triés ≈ 15 litres d'eau économisés
    // 80 kg de papier recyclé ≈ 1 arbre sauvé
    final double dechetsTries = points * 0.5;
    final double co2Evite = dechetsTries * 2.5;
    final double eauEconomisee = dechetsTries * 15;
    final double arbresEquivalent = dechetsTries / 80;

    return Animate(
      effects: [FadeEffect(delay: 200.ms), const SlideEffect(begin: Offset(0, 0.05))],
      child: Column(
        children: [
          Row(
            children: [
              Expanded(
                child: _buildImpactStatCard(
                  icon: Icons.cloud_done_rounded,
                  value: co2Evite >= 1000 ? '${(co2Evite / 1000).toStringAsFixed(1)} t' : '${co2Evite.toStringAsFixed(1)} kg',
                  label: 'CO₂ évité',
                  color: const Color(0xFF3B82F6),
                  subtitle: 'grâce à votre tri',
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildImpactStatCard(
                  icon: Icons.delete_sweep_rounded,
                  value: dechetsTries >= 1000 ? '${(dechetsTries / 1000).toStringAsFixed(1)} t' : '${dechetsTries.toStringAsFixed(0)} kg',
                  label: 'Déchets triés',
                  color: const Color(0xFF10B981),
                  subtitle: 'par vous',
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: _buildImpactStatCard(
                  icon: Icons.water_drop_rounded,
                  value: eauEconomisee >= 1000 ? '${(eauEconomisee / 1000).toStringAsFixed(1)} m³' : '${eauEconomisee.toStringAsFixed(0)} L',
                  label: 'Eau économisée',
                  color: const Color(0xFF06B6D4),
                  subtitle: 'ressource préservée',
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildImpactStatCard(
                  icon: Icons.park_rounded,
                  value: arbresEquivalent >= 1 ? '${arbresEquivalent.toStringAsFixed(1)}' : '${(arbresEquivalent * 100).toStringAsFixed(0)}%',
                  label: arbresEquivalent >= 1 ? 'Arbres sauvés' : 'vers 1 arbre',
                  color: const Color(0xFF059669),
                  subtitle: arbresEquivalent >= 1 ? 'équivalent forêt' : '${(80 - dechetsTries).clamp(0, 80).toStringAsFixed(0)} kg restants',
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildImpactStatCard({
    required IconData icon,
    required String value,
    required String label,
    required Color color,
    String? subtitle,
  }) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: color.withOpacity(0.15), width: 1.5),
        boxShadow: [
          BoxShadow(color: color.withOpacity(0.06), blurRadius: 14, offset: const Offset(0, 6)),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              gradient: LinearGradient(colors: [color.withOpacity(0.15), color.withOpacity(0.05)]),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, color: color, size: 22),
          ),
          const SizedBox(height: 14),
          Text(value,
              style: GoogleFonts.outfit(fontSize: 24, fontWeight: FontWeight.w900, color: AppTheme.deepSlate)),
          const SizedBox(height: 2),
          Text(label,
              style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w700, color: color)),
          if (subtitle != null) ...[
            const SizedBox(height: 2),
            Text(subtitle,
                style: GoogleFonts.inter(fontSize: 10, color: AppTheme.textMuted),
                maxLines: 1,
                overflow: TextOverflow.ellipsis),
          ],
        ],
      ),
    );
  }

  // ============================================
  // HISTORIQUE D'ACTIVITÉ PERSONNALISÉ
  // ============================================
  Widget _buildPersonalActivityTimeline(int points, String userName) {
    // Générer des activités basées sur les points réels
    final List<Map<String, dynamic>> activities = [];

    // Toujours montrer l'inscription
    activities.add({
      'icon': Icons.person_add_rounded,
      'title': 'Inscription sur EcoRewind',
      'subtitle': 'Bienvenue $userName !',
      'color': const Color(0xFF10B981),
      'done': true,
    });

    if (points > 0) {
      activities.add({
        'icon': Icons.qr_code_2_rounded,
        'title': 'Premier dépôt effectué',
        'subtitle': '+${min(points, 25)} points gagnés',
        'color': const Color(0xFF3B82F6),
        'done': true,
      });
    }

    if (points >= 100) {
      activities.add({
        'icon': Icons.quiz_rounded,
        'title': 'Quiz complétés',
        'subtitle': '${(points / 80).floor()} quiz réussis',
        'color': const Color(0xFF8B5CF6),
        'done': true,
      });
    }

    if (points >= 250) {
      activities.add({
        'icon': Icons.shopping_cart_rounded,
        'title': 'Première récompense échangée',
        'subtitle': 'Bon d\'achat 5 DT débloqué',
        'color': const Color(0xFFF59E0B),
        'done': true,
      });
    }

    if (points >= 500) {
      activities.add({
        'icon': Icons.military_tech_rounded,
        'title': 'Niveau Engagé atteint',
        'subtitle': '500 points cumulés !',
        'color': const Color(0xFF10B981),
        'done': true,
      });
    }

    // Prochain objectif (pas encore atteint)
    if (points < 500) {
      activities.add({
        'icon': Icons.flag_rounded,
        'title': 'Prochain objectif : Niveau Engagé',
        'subtitle': '${500 - points} points restants',
        'color': const Color(0xFF94A3B8),
        'done': false,
      });
    } else if (points < 1000) {
      activities.add({
        'icon': Icons.flag_rounded,
        'title': 'Prochain objectif : Niveau Expert',
        'subtitle': '${1000 - points} points restants',
        'color': const Color(0xFF94A3B8),
        'done': false,
      });
    } else if (points < 2500) {
      activities.add({
        'icon': Icons.flag_rounded,
        'title': 'Prochain objectif : Ambassadeur',
        'subtitle': '${2500 - points} points restants',
        'color': const Color(0xFF94A3B8),
        'done': false,
      });
    }

    return Column(
      children: List.generate(activities.length, (index) {
        final activity = activities[index];
        final bool isDone = activity['done'] as bool;
        final Color color = activity['color'] as Color;
        return Animate(
          effects: [FadeEffect(delay: (index * 100).ms), SlideEffect(begin: const Offset(0, 0.05), delay: (index * 100).ms)],
          child: Padding(
            padding: const EdgeInsets.only(bottom: 4),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Timeline line
                Column(
                  children: [
                    Container(
                      width: 36,
                      height: 36,
                      decoration: BoxDecoration(
                        color: isDone ? color.withOpacity(0.15) : Colors.grey.shade100,
                        shape: BoxShape.circle,
                        border: Border.all(color: isDone ? color.withOpacity(0.3) : Colors.grey.shade300, width: 2),
                      ),
                      child: Icon(
                        isDone ? (activity['icon'] as IconData) : Icons.lock_outline_rounded,
                        color: isDone ? color : Colors.grey.shade400,
                        size: 16,
                      ),
                    ),
                    if (index < activities.length - 1)
                      Container(
                        width: 2,
                        height: 30,
                        color: isDone ? color.withOpacity(0.2) : Colors.grey.shade200,
                      ),
                  ],
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Container(
                    padding: const EdgeInsets.only(bottom: 16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(activity['title'] as String,
                            style: GoogleFonts.outfit(
                              fontWeight: FontWeight.w700,
                              fontSize: 14,
                              color: isDone ? AppTheme.deepSlate : Colors.grey.shade400,
                            )),
                        const SizedBox(height: 2),
                        Text(activity['subtitle'] as String,
                            style: GoogleFonts.inter(
                              fontSize: 12,
                              color: isDone ? AppTheme.textMuted : Colors.grey.shade400,
                            )),
                      ],
                    ),
                  ),
                ),
                if (isDone)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: color.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text('✓',
                        style: GoogleFonts.outfit(color: color, fontSize: 12, fontWeight: FontWeight.w800)),
                  ),
              ],
            ),
          ),
        );
      }),
    );
  }
}

