import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../theme/app_theme.dart';

class RewardsTab extends StatelessWidget {
  const RewardsTab({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      physics: const BouncingScrollPhysics(),
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── EN-TÊTE ──
          Animate(
            effects: [FadeEffect(), SlideEffect(begin: const Offset(-0.1, 0))],
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Récompenses', style: GoogleFonts.outfit(fontSize: 32, fontWeight: FontWeight.bold, color: AppTheme.deepSlate)),
                    Text('Gagnez des points, débloquez des récompenses', style: GoogleFonts.inter(color: AppTheme.textMuted, fontSize: 13)),
                  ],
                ),
                Animate(
                  onPlay: (c) => c.repeat(reverse: true),
                  effects: [
                    ScaleEffect(begin: const Offset(1, 1), end: const Offset(1.1, 1.1), duration: 2.seconds),
                  ],
                  child: Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: AppTheme.primaryGreen.withOpacity(0.1),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.card_giftcard_rounded, color: AppTheme.primaryGreen, size: 28),
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 32),

          // ── COMMENT ÇA MARCHE ──
          _buildHowItWorksSection(),

          const SizedBox(height: 36),

          // ── NIVEAUX DU PROGRAMME ──
          _buildSectionHeader('NIVEAUX DU PROGRAMME'),
          const SizedBox(height: 16),
          _buildLevelCard(
            'Explorateur',
            '0 - 500 pts',
            'Commencez votre aventure écologique',
            Icons.explore_rounded,
            const Color(0xFF60A5FA),
            0.25,
          ),
          const SizedBox(height: 12),
          _buildLevelCard(
            'Éco-Citoyen',
            '500 - 2000 pts',
            'Réductions chez nos partenaires locaux',
            Icons.eco_rounded,
            const Color(0xFF34D399),
            0.50,
          ),
          const SizedBox(height: 12),
          _buildLevelCard(
            'Champion Vert',
            '2000 - 5000 pts',
            'Cadeaux exclusifs et accès VIP',
            Icons.emoji_events_rounded,
            const Color(0xFFFBBF24),
            0.75,
          ),
          const SizedBox(height: 12),
          _buildLevelCard(
            'Légende Éco',
            '5000+ pts',
            'Statut ambassadeur et récompenses premium',
            Icons.workspace_premium_rounded,
            const Color(0xFFF472B6),
            1.0,
          ),

          const SizedBox(height: 36),

          // ── BADGES DISPONIBLES ──
          _buildSectionHeader('BADGES À DÉBLOQUER'),
          const SizedBox(height: 16),
          SizedBox(
            height: 150,
            child: ListView(
              scrollDirection: Axis.horizontal,
              physics: const BouncingScrollPhysics(),
              children: [
                _buildBadgeCard('Premier Tri', 'Triez votre premier déchet', Icons.recycling_rounded, Colors.blue),
                _buildBadgeCard('Série 7 jours', '7 jours consécutifs de tri', Icons.local_fire_department_rounded, Colors.orange),
                _buildBadgeCard('Expert Quiz', 'Score 100% à un quiz', Icons.quiz_rounded, Colors.purple),
                _buildBadgeCard('Communauté', 'Partagez 10 publications', Icons.groups_rounded, Colors.teal),
                _buildBadgeCard('Cartographe', 'Visitez 5 bornes de tri', Icons.map_rounded, Colors.green),
              ],
            ),
          ),

          const SizedBox(height: 36),

          // ── RÉCOMPENSES DISPONIBLES ──
          _buildSectionHeader('RÉCOMPENSES DISPONIBLES'),
          const SizedBox(height: 16),
          _buildRewardItem(
            'Bon d\'achat 10 DT',
            '1000 points',
            'Utilisable chez tous nos partenaires',
            Icons.shopping_bag_rounded,
            const Color(0xFF3B82F6),
          ),
          const SizedBox(height: 12),
          _buildRewardItem(
            'Gourde écologique',
            '2500 points',
            'Gourde réutilisable en inox 500ml',
            Icons.water_drop_rounded,
            const Color(0xFF10B981),
          ),
          const SizedBox(height: 12),
          _buildRewardItem(
            'Sac en toile bio',
            '1500 points',
            'Sac shopping 100% coton biologique',
            Icons.shopping_cart_rounded,
            const Color(0xFF8B5CF6),
          ),
          const SizedBox(height: 12),
          _buildRewardItem(
            'Plantation d\'arbre',
            '3000 points',
            'Un arbre planté en votre nom en Tunisie',
            Icons.park_rounded,
            const Color(0xFF059669),
          ),

          const SizedBox(height: 36),

          // ── PARTENAIRES ──
          _buildSectionHeader('NOS PARTENAIRES'),
          const SizedBox(height: 16),
          _buildPartnersSection(),

          const SizedBox(height: 100),
        ],
      ),
    );
  }

  // ── COMMENT ÇA MARCHE ──
  Widget _buildHowItWorksSection() {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            AppTheme.primaryGreen.withOpacity(0.06),
            AppTheme.accentTeal.withOpacity(0.03),
          ],
        ),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: AppTheme.primaryGreen.withOpacity(0.12)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: AppTheme.primaryGreen.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(Icons.lightbulb_rounded, color: AppTheme.primaryGreen, size: 20),
              ),
              const SizedBox(width: 12),
              Text('Comment gagner des points ?', style: GoogleFonts.spaceGrotesk(
                fontSize: 18, fontWeight: FontWeight.w800, color: AppTheme.deepNavy,
              )),
            ],
          ),
          const SizedBox(height: 20),
          _buildStepRow('1', 'Triez vos déchets', 'Scannez et triez correctement pour gagner des points'),
          const SizedBox(height: 14),
          _buildStepRow('2', 'Participez aux quiz', 'Testez vos connaissances et gagnez des bonus'),
          const SizedBox(height: 14),
          _buildStepRow('3', 'Partagez vos actions', 'Inspirez la communauté et recevez des likes'),
          const SizedBox(height: 14),
          _buildStepRow('4', 'Échangez vos points', 'Convertissez vos points en récompenses réelles'),
        ],
      ),
    ).animate().fadeIn(delay: 200.ms).slideY(begin: 0.05, end: 0);
  }

  Widget _buildStepRow(String num, String title, String desc) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 28, height: 28,
          decoration: BoxDecoration(
            color: AppTheme.primaryGreen,
            borderRadius: BorderRadius.circular(8),
          ),
          child: Center(child: Text(num, style: GoogleFonts.outfit(
            color: Colors.white, fontWeight: FontWeight.w900, fontSize: 14,
          ))),
        ),
        const SizedBox(width: 14),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: GoogleFonts.spaceGrotesk(
                fontSize: 15, fontWeight: FontWeight.w700, color: AppTheme.deepNavy,
              )),
              Text(desc, style: GoogleFonts.inter(
                fontSize: 12, color: AppTheme.textMuted, height: 1.4,
              )),
            ],
          ),
        ),
      ],
    );
  }

  // ── NIVEAUX ──
  Widget _buildLevelCard(String name, String range, String desc, IconData icon, Color color, double progress) {
    return Animate(
      effects: [FadeEffect(), SlideEffect(begin: const Offset(0, 0.08))],
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: color.withOpacity(0.15)),
          boxShadow: [
            BoxShadow(color: color.withOpacity(0.06), blurRadius: 16, offset: const Offset(0, 6)),
          ],
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                gradient: LinearGradient(colors: [color.withOpacity(0.15), color.withOpacity(0.05)]),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Icon(icon, color: color, size: 28),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(name, style: GoogleFonts.spaceGrotesk(
                        fontSize: 16, fontWeight: FontWeight.w800, color: AppTheme.deepNavy,
                      )),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: color.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Text(range, style: GoogleFonts.inter(
                          fontSize: 11, fontWeight: FontWeight.w700, color: color,
                        )),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(desc, style: GoogleFonts.inter(fontSize: 12, color: AppTheme.textMuted)),
                  const SizedBox(height: 10),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(10),
                    child: LinearProgressIndicator(
                      value: progress,
                      minHeight: 6,
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
    );
  }

  // ── BADGES ──
  Widget _buildBadgeCard(String label, String desc, IconData icon, Color color) {
    return Container(
      width: 130,
      margin: const EdgeInsets.only(right: 14),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withOpacity(0.12)),
        boxShadow: [
          BoxShadow(color: color.withOpacity(0.05), blurRadius: 12, offset: const Offset(0, 4)),
        ],
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: color.withOpacity(0.1),
              shape: BoxShape.circle,
              border: Border.all(color: color.withOpacity(0.2), width: 2),
            ),
            child: Icon(icon, color: color, size: 26),
          ),
          const SizedBox(height: 10),
          Text(label, style: GoogleFonts.spaceGrotesk(
            fontSize: 12, fontWeight: FontWeight.w800, color: AppTheme.deepNavy,
          ), textAlign: TextAlign.center),
          const SizedBox(height: 3),
          Text(desc, style: GoogleFonts.inter(
            fontSize: 9, color: AppTheme.textMuted, height: 1.3,
          ), textAlign: TextAlign.center, maxLines: 2, overflow: TextOverflow.ellipsis),
        ],
      ),
    ).animate().fadeIn().scale(begin: const Offset(0.9, 0.9), curve: Curves.easeOutBack);
  }

  // ── RÉCOMPENSES ──
  Widget _buildRewardItem(String title, String points, String desc, IconData icon, Color color) {
    return Animate(
      effects: [FadeEffect(), SlideEffect(begin: const Offset(0.05, 0))],
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: Colors.grey.shade100),
          boxShadow: [
            BoxShadow(color: Colors.black.withOpacity(0.03), blurRadius: 12, offset: const Offset(0, 4)),
          ],
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: color.withOpacity(0.1),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Icon(icon, color: color, size: 26),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: GoogleFonts.spaceGrotesk(
                    fontSize: 15, fontWeight: FontWeight.w800, color: AppTheme.deepNavy,
                  )),
                  const SizedBox(height: 3),
                  Text(desc, style: GoogleFonts.inter(
                    fontSize: 12, color: AppTheme.textMuted,
                  )),
                ],
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: color.withOpacity(0.1),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Text(points, style: GoogleFonts.outfit(
                fontSize: 12, fontWeight: FontWeight.w800, color: color,
              )),
            ),
          ],
        ),
      ),
    );
  }

  // ── PARTENAIRES ──
  Widget _buildPartnersSection() {
    final partners = [
      {'name': 'Carrefour', 'icon': Icons.storefront_rounded, 'color': const Color(0xFF3B82F6)},
      {'name': 'Monoprix', 'icon': Icons.shopping_basket_rounded, 'color': const Color(0xFFEF4444)},
      {'name': 'Géant', 'icon': Icons.store_rounded, 'color': const Color(0xFF10B981)},
      {'name': 'Aziza', 'icon': Icons.local_mall_rounded, 'color': const Color(0xFFF59E0B)},
    ];

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.grey.shade100),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Échangez vos points chez nos partenaires',
            style: GoogleFonts.inter(fontSize: 13, color: AppTheme.textMuted),
          ),
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: partners.map((p) {
              final color = p['color'] as Color;
              return Column(
                children: [
                  Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: color.withOpacity(0.1),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(p['icon'] as IconData, color: color, size: 24),
                  ),
                  const SizedBox(height: 8),
                  Text(p['name'] as String, style: GoogleFonts.inter(
                    fontSize: 11, fontWeight: FontWeight.w600, color: AppTheme.deepNavy,
                  )),
                ],
              );
            }).toList(),
          ),
        ],
      ),
    ).animate().fadeIn(delay: 300.ms);
  }

  Widget _buildSectionHeader(String title) {
    return Text(
      title,
      style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w900, letterSpacing: 1.5, color: AppTheme.textMuted),
    );
  }
}
