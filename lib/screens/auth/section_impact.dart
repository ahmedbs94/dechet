import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../theme/app_theme.dart';

class SectionImpact extends StatefulWidget {
  const SectionImpact({Key? key}) : super(key: key);

  @override
  State<SectionImpact> createState() => _SectionImpactState();
}

class _SectionImpactState extends State<SectionImpact>
    with SingleTickerProviderStateMixin {
  late AnimationController _counterController;
  int _animCO2 = 0;
  int _animUsers = 0;
  int _animCenters = 0;

  @override
  void initState() {
    super.initState();
    _counterController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2000),
    );

    _counterController.addListener(() {
      if (mounted) {
        setState(() {
          _animCO2 = (1200 * _counterController.value).toInt();
          _animUsers = (850 * _counterController.value).toInt();
          _animCenters = (15 * _counterController.value).toInt();
        });
      }
    });

    // Start animation after a short delay
    Future.delayed(const Duration(milliseconds: 500), () {
      if (mounted) _counterController.forward();
    });
  }

  @override
  void dispose() {
    _counterController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.backgroundLight,
      body: CustomScrollView(
        physics: const BouncingScrollPhysics(),
        slivers: [
          SliverToBoxAdapter(child: _buildHeader(context)),
          SliverToBoxAdapter(child: _buildCounters()),
          SliverToBoxAdapter(child: _buildImpactDetails()),
          SliverToBoxAdapter(child: _buildEcoFacts()),
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
          colors: [Color(0xFF0F172A), Color(0xFF1E293B)],
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
                child: const Icon(Icons.public_rounded,
                    color: Colors.white, size: 28),
              ).animate().fadeIn(delay: 150.ms).scale(
                    begin: const Offset(0.8, 0.8),
                    curve: Curves.easeOutBack,
                  ),
              const SizedBox(height: 20),
              Text(
                'Notre Impact\nCollectif',
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
                'Chaque geste compte. Voici l\'impact réel de notre communauté sur l\'environnement.',
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

  Widget _buildCounters() {
    return Container(
      margin: const EdgeInsets.all(20),
      padding: const EdgeInsets.symmetric(vertical: 32, horizontal: 20),
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
            blurRadius: 30,
            offset: const Offset(0, 15),
          ),
        ],
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          _buildCounterStat(
            '$_animCO2',
            'KG CO₂ ÉVITÉS',
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
    ).animate().fadeIn(delay: 400.ms).slideY(begin: 0.1, end: 0);
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

  Widget _buildImpactDetails() {
    final items = [
      _ImpactItem(
        icon: Icons.recycling_rounded,
        title: 'Recyclage efficace',
        value: '850 tonnes',
        description: 'De déchets correctement triés et recyclés',
        color: AppTheme.primaryGreen,
      ),
      _ImpactItem(
        icon: Icons.forest_rounded,
        title: 'Arbres sauvés',
        value: '12 000',
        description: 'Arbres préservés grâce au recyclage du papier',
        color: const Color(0xFF10B981),
      ),
      _ImpactItem(
        icon: Icons.water_drop_rounded,
        title: 'Eau économisée',
        value: '2.4M litres',
        description: 'D\'eau préservée par le recyclage du plastique',
        color: const Color(0xFF3B82F6),
      ),
    ];

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Détails de notre impact',
            style: GoogleFonts.spaceGrotesk(
              fontSize: 22,
              fontWeight: FontWeight.w800,
              color: AppTheme.deepNavy,
            ),
          ),
          const SizedBox(height: 16),
          ...items.asMap().entries.map((entry) {
            final i = entry.key;
            final item = entry.value;
            return Container(
              margin: const EdgeInsets.only(bottom: 14),
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(24),
                border: Border.all(color: Colors.grey.shade100),
                boxShadow: [
                  BoxShadow(
                    color: item.color.withOpacity(0.06),
                    blurRadius: 20,
                    offset: const Offset(0, 8),
                  ),
                ],
              ),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: item.color.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Icon(item.icon, color: item.color, size: 26),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          item.title,
                          style: GoogleFonts.spaceGrotesk(
                            fontSize: 15,
                            fontWeight: FontWeight.w700,
                            color: AppTheme.deepNavy,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          item.description,
                          style: GoogleFonts.inter(
                            fontSize: 12,
                            color: AppTheme.textMuted,
                            height: 1.3,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Text(
                    item.value,
                    style: GoogleFonts.outfit(
                      fontSize: 16,
                      fontWeight: FontWeight.w900,
                      color: item.color,
                    ),
                  ),
                ],
              ),
            ).animate().fadeIn(delay: (600 + i * 100).ms).slideX(begin: 0.05, end: 0);
          }),
        ],
      ),
    );
  }

  Widget _buildEcoFacts() {
    return Padding(
      padding: const EdgeInsets.all(20),
      child: Container(
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
                  child: const Icon(Icons.lightbulb_rounded,
                      color: AppTheme.primaryGreen, size: 20),
                ),
                const SizedBox(width: 12),
                Text(
                  'Le saviez-vous ?',
                  style: GoogleFonts.spaceGrotesk(
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                    color: AppTheme.deepNavy,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Text(
              'Recycler une tonne de plastique permet d\'économiser 700 kg de CO₂. '
              'En triant correctement vos déchets, vous contribuez directement '
              'à la réduction des émissions de gaz à effet de serre.',
              style: GoogleFonts.inter(
                fontSize: 14,
                color: AppTheme.textMuted,
                height: 1.6,
              ),
            ),
          ],
        ),
      ),
    ).animate().fadeIn(delay: 900.ms);
  }
}

class _ImpactItem {
  final IconData icon;
  final String title;
  final String value;
  final String description;
  final Color color;

  _ImpactItem({
    required this.icon,
    required this.title,
    required this.value,
    required this.description,
    required this.color,
  });
}
