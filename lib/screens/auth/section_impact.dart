import 'dart:convert';
import 'dart:math' as math;
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:http/http.dart' as http;
import '../../theme/app_theme.dart';
import '../../constants.dart';

import 'package:shared_preferences/shared_preferences.dart';

class SectionImpact extends StatefulWidget {
  const SectionImpact({Key? key}) : super(key: key);

  @override
  State<SectionImpact> createState() => _SectionImpactState();
}

class _SectionImpactState extends State<SectionImpact>
    with TickerProviderStateMixin {
  late AnimationController _counterController;
  late AnimationController _pulseController;

  // Valeurs cibles depuis l'API
  int _targetUsers = 0;
  int _targetCenters = 0;
  double _targetWaste = 0;
  int _targetTrees = 0;

  // Valeurs animées
  double _animUsers = 0;
  double _animCenters = 0;
  double _animWaste = 0;
  double _animTrees = 0;

  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _counterController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2200),
    );
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1800),
    )..repeat(reverse: true);

    _counterController.addListener(() {
      if (mounted) {
        final v = Curves.easeOutCubic.transform(_counterController.value);
        setState(() {
          _animUsers = _targetUsers * v;
          _animCenters = _targetCenters * v;
          _animWaste = _targetWaste * v;
          _animTrees = _targetTrees * v;
        });
      }
    });

    _fetchStats();
  }

  Future<void> _fetchStats() async {
    try {
      final response = await http
          .get(Uri.parse('${ApiConstants.baseUrl}/stats'))
          .timeout(const Duration(seconds: 8));
      if (response.statusCode == 200) {
        final data = json.decode(utf8.decode(response.bodyBytes));
        if (mounted) {
          setState(() {
            _targetUsers = (data['total_users'] as num?)?.toInt() ?? 0;
            _targetCenters =
                (data['total_collection_points'] as num?)?.toInt() ?? 0;
            _targetWaste =
                (data['waste_sorted_kg'] as num?)?.toDouble() ?? 0;
            _targetTrees = (data['trees_equivalent'] as num?)?.toInt() ?? 0;
            _isLoading = false;
          });
          Future.delayed(const Duration(milliseconds: 300), () {
            if (mounted) _counterController.forward();
          });
        }
      } else {
        _useFallback();
      }
    } catch (_) {
      _useFallback();
    }
  }

  void _useFallback() async {
    int offlineCenters = 10;
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString('map_points_cache_v2');
      if (raw != null && raw.isNotEmpty) {
        final List<dynamic> decoded = json.decode(raw);
        if (decoded.isNotEmpty) {
          offlineCenters = decoded.length;
        }
      }
    } catch (_) {}

    if (mounted) {
      setState(() {
        _targetUsers = 0;
        _targetCenters = offlineCenters;
        _targetWaste = 0;
        _targetTrees = 0;
        _isLoading = false;
      });
      Future.delayed(const Duration(milliseconds: 300), () {
        if (mounted) _counterController.forward();
      });
    }
  }


  String _fmtKg(double v) {
    if (v >= 1000000) return '${(v / 1000000).toStringAsFixed(1)}M kg';
    if (v >= 1000) return '${(v / 1000).toStringAsFixed(1)}k kg';
    return '${v.toInt()} kg';
  }

  String _fmtNum(double v) {
    if (v >= 1000000) return '${(v / 1000000).toStringAsFixed(1)}M';
    if (v >= 1000) return '${(v / 1000).toStringAsFixed(1)}k';
    return '${v.toInt()}';
  }

  @override
  void dispose() {
    _counterController.dispose();
    _pulseController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0A0F1E),
      body: CustomScrollView(
        physics: const BouncingScrollPhysics(),
        slivers: [
          SliverToBoxAdapter(child: _buildHeader(context)),
          SliverToBoxAdapter(child: _buildLiveCounters()),
          SliverToBoxAdapter(child: _buildImpactGrid()),
          SliverToBoxAdapter(child: _buildEcoFact()),
          const SliverToBoxAdapter(child: SizedBox(height: 80)),
        ],
      ),
    );
  }

  Widget _buildHeader(BuildContext context) {
    return Container(
      width: double.infinity,
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [Color(0xFF0A0F1E), Color(0xFF0F2027)],
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
        ),
      ),
      child: Stack(
        children: [
          // Animated orbs background
          ...List.generate(3, (i) {
            return AnimatedBuilder(
              animation: _pulseController,
              builder: (_, __) {
                final r = 80.0 + i * 40 + _pulseController.value * 20;
                return Positioned(
                  right: -30 + i * 60.0,
                  top: 40 + i * 50.0,
                  child: Container(
                    width: r,
                    height: r,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: RadialGradient(colors: [
                        [AppTheme.primaryGreen, AppTheme.accentTeal, const Color(0xFF6366F1)][i]
                            .withOpacity(0.15),
                        Colors.transparent,
                      ]),
                    ),
                  ),
                );
              },
            );
          }),

          SafeArea(
            bottom: false,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 48),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Back button — masqué sur web
                  if (!kIsWeb)
                    GestureDetector(
                      onTap: () => Navigator.pop(context),
                      child: Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.08),
                          borderRadius: BorderRadius.circular(14),
                          border:
                              Border.all(color: Colors.white.withOpacity(0.12)),
                        ),
                        child: const Icon(Icons.arrow_back_ios_new_rounded,
                            color: Colors.white, size: 18),
                      ),
                    ).animate().fadeIn(duration: 300.ms).slideX(begin: -0.15),
                  const SizedBox(height: 32),

                  // Live badge
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 14, vertical: 7),
                    decoration: BoxDecoration(
                      color: AppTheme.primaryGreen.withOpacity(0.15),
                      borderRadius: BorderRadius.circular(30),
                      border: Border.all(
                          color: AppTheme.primaryGreen.withOpacity(0.3)),
                    ),
                    child: Row(mainAxisSize: MainAxisSize.min, children: [
                      AnimatedBuilder(
                        animation: _pulseController,
                        builder: (_, __) => Container(
                          width: 8,
                          height: 8,
                          decoration: BoxDecoration(
                            color: AppTheme.primaryGreen.withOpacity(
                                0.5 + 0.5 * _pulseController.value),
                            shape: BoxShape.circle,
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        'DONNÉES EN TEMPS RÉEL',
                        style: GoogleFonts.inter(
                            color: AppTheme.primaryGreen,
                            fontSize: 10,
                            fontWeight: FontWeight.w800,
                            letterSpacing: 1),
                      ),
                    ]),
                  ).animate().fadeIn(delay: 100.ms),
                  const SizedBox(height: 20),

                  ShaderMask(
                    shaderCallback: (b) => const LinearGradient(
                      colors: [Colors.white, Color(0xFF86EFAC)],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ).createShader(b),
                    child: Text(
                      'Notre Impact\nCollectif',
                      style: GoogleFonts.spaceGrotesk(
                        color: Colors.white,
                        fontSize: 38,
                        fontWeight: FontWeight.w900,
                        height: 1.05,
                        letterSpacing: -1.5,
                      ),
                    ),
                  ).animate().fadeIn(delay: 200.ms).slideY(begin: 0.15),
                  const SizedBox(height: 14),

                  Text(
                    'Chaque geste compte. Voici l\'impact réel de notre communauté sur l\'environnement, mesuré en direct.',
                    style: GoogleFonts.inter(
                      color: Colors.white.withOpacity(0.6),
                      fontSize: 14,
                      height: 1.6,
                    ),
                  ).animate().fadeIn(delay: 350.ms),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLiveCounters() {
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 0, 16, 16),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF111827), Color(0xFF1F2937)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(28),
        border: Border.all(color: Colors.white.withOpacity(0.06)),
        boxShadow: [
          BoxShadow(
            color: AppTheme.primaryGreen.withOpacity(0.12),
            blurRadius: 40,
            offset: const Offset(0, 16),
          ),
        ],
      ),
      child: _isLoading
          ? const Padding(
              padding: EdgeInsets.all(48),
              child: Center(
                child: CircularProgressIndicator(
                    color: AppTheme.primaryGreen, strokeWidth: 2),
              ),
            )
          : Padding(
              padding: const EdgeInsets.symmetric(vertical: 32, horizontal: 16),
              child: Column(
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: AppTheme.primaryGreen.withOpacity(0.12),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: const Icon(Icons.public_rounded,
                            color: AppTheme.primaryGreen, size: 16),
                      ),
                      const SizedBox(width: 10),
                      Text(
                        'IMPACT GLOBAL ECOREWIND',
                        style: GoogleFonts.inter(
                          color: Colors.white.withOpacity(0.7),
                          fontSize: 10,
                          fontWeight: FontWeight.w900,
                          letterSpacing: 2,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 28),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: [
                      _buildCounterItem(
                        _fmtNum(_animUsers),
                        'CITOYENS',
                        Icons.people_alt_rounded,
                        AppTheme.accentTeal,
                      ),
                      _buildDivider(),
                      _buildCounterItem(
                        '${_animCenters.toInt()}',
                        'CENTRES TRI',
                        Icons.location_on_rounded,
                        const Color(0xFF6366F1),
                      ),
                    ],
                  ),
                ],
              ),
            ),
    ).animate().fadeIn(delay: 400.ms).slideY(begin: 0.08);
  }

  Widget _buildDivider() => Container(
        width: 1,
        height: 50,
        color: Colors.white.withOpacity(0.08),
      );

  Widget _buildCounterItem(
      String value, String label, IconData icon, Color color) {
    return Column(
      children: [
        Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: color.withOpacity(0.12),
            shape: BoxShape.circle,
          ),
          child: Icon(icon, color: color, size: 20),
        ),
        const SizedBox(height: 12),
        Text(
          value,
          style: GoogleFonts.outfit(
            color: Colors.white,
            fontSize: 22,
            fontWeight: FontWeight.w900,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          label,
          textAlign: TextAlign.center,
          style: GoogleFonts.inter(
            color: Colors.white.withOpacity(0.4),
            fontSize: 9,
            fontWeight: FontWeight.w800,
            letterSpacing: 1,
          ),
        ),
      ],
    );
  }

  Widget _buildImpactGrid() {
    final cards = [
      _ImpactCard(
        icon: Icons.recycling_rounded,
        title: 'Déchets recyclés',
        value: _isLoading ? '...' : _fmtKg(_animWaste),
        subtitle: 'correctement triés et recyclés',
        gradient: [const Color(0xFF10B981), const Color(0xFF059669)],
        bgColor: const Color(0xFFECFDF5),
      ),
      _ImpactCard(
        icon: Icons.forest_rounded,
        title: 'Arbres équivalents',
        value: _isLoading ? '...' : '${_animTrees.toInt()} 🌳',
        subtitle: 'préservés grâce au recyclage',
        gradient: [const Color(0xFF22C55E), const Color(0xFF16A34A)],
        bgColor: const Color(0xFFF0FDF4),
      ),
      _ImpactCard(
        icon: Icons.water_drop_rounded,
        title: 'Eau économisée',
        value: _isLoading
            ? '...'
            : '${(_animWaste * 2.8).toInt()} L',
        subtitle: 'préservée par le plastique recyclé',
        gradient: [const Color(0xFF3B82F6), const Color(0xFF2563EB)],
        bgColor: const Color(0xFFEFF6FF),
      ),
    ];

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(bottom: 16, top: 8),
            child: Row(
              children: [
                Container(
                  width: 4,
                  height: 24,
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [AppTheme.primaryGreen, AppTheme.accentTeal],
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                    ),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                const SizedBox(width: 12),
                Text(
                  'Détails de l\'impact',
                  style: GoogleFonts.spaceGrotesk(
                    fontSize: 20,
                    fontWeight: FontWeight.w800,
                    color: Colors.white,
                  ),
                ),
              ],
            ),
          ),
          ...cards.asMap().entries.map((e) => _buildImpactCard(e.value, e.key)),
        ],
      ),
    );
  }

  Widget _buildImpactCard(_ImpactCard card, int index) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: const Color(0xFF111827),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.white.withOpacity(0.06)),
      ),
      child: Row(
        children: [
          Container(
            width: 52,
            height: 52,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: card.gradient,
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Icon(card.icon, color: Colors.white, size: 24),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  card.title,
                  style: GoogleFonts.inter(
                    fontSize: 12,
                    color: Colors.white.withOpacity(0.5),
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  card.value,
                  style: GoogleFonts.outfit(
                    fontSize: 20,
                    fontWeight: FontWeight.w900,
                    color: Colors.white,
                  ),
                ),
                Text(
                  card.subtitle,
                  style: GoogleFonts.inter(
                    fontSize: 11,
                    color: Colors.white.withOpacity(0.35),
                  ),
                ),
              ],
            ),
          ),
          // Progress arc
          SizedBox(
            width: 44,
            height: 44,
            child: CustomPaint(
              painter: _ArcPainter(
                color: card.gradient.first,
                progress: math.min(1.0, _counterController.value),
              ),
            ),
          ),
        ],
      ),
    ).animate().fadeIn(delay: (500 + index * 100).ms).slideX(begin: 0.08);
  }

  Widget _buildEcoFact() {
    return Container(
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            AppTheme.primaryGreen.withOpacity(0.08),
            AppTheme.accentTeal.withOpacity(0.04),
          ],
        ),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: AppTheme.primaryGreen.withOpacity(0.15)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: AppTheme.primaryGreen.withOpacity(0.15),
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Icon(Icons.lightbulb_rounded,
                color: AppTheme.primaryGreen, size: 20),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Le saviez-vous ?',
                  style: GoogleFonts.spaceGrotesk(
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Recycler 1 tonne de plastique permet d\'économiser 700 kg de CO₂ '
                  'et 5 000 kWh d\'énergie. Chaque geste de tri vous rapproche '
                  'd\'un impact mesurable sur le climat.',
                  style: GoogleFonts.inter(
                    fontSize: 13,
                    color: Colors.white.withOpacity(0.6),
                    height: 1.6,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    ).animate().fadeIn(delay: 900.ms);
  }
}

// ─── Arc painter pour les cartes d'impact ────────────────────────────────────
class _ArcPainter extends CustomPainter {
  final Color color;
  final double progress;
  _ArcPainter({required this.color, required this.progress});

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width / 2 - 4;

    // Background track
    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius),
      -math.pi / 2,
      2 * math.pi,
      false,
      Paint()
        ..color = Colors.white.withOpacity(0.06)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 3
        ..strokeCap = StrokeCap.round,
    );

    // Progress arc
    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius),
      -math.pi / 2,
      2 * math.pi * progress,
      false,
      Paint()
        ..color = color
        ..style = PaintingStyle.stroke
        ..strokeWidth = 3
        ..strokeCap = StrokeCap.round,
    );
  }

  @override
  bool shouldRepaint(_ArcPainter old) => old.progress != progress;
}

class _ImpactCard {
  final IconData icon;
  final String title;
  final String value;
  final String subtitle;
  final List<Color> gradient;
  final Color bgColor;

  _ImpactCard({
    required this.icon,
    required this.title,
    required this.value,
    required this.subtitle,
    required this.gradient,
    required this.bgColor,
  });
}
