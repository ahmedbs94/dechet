import 'dart:convert';
import 'dart:math' as math;
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:http/http.dart' as http;
import '../../theme/app_theme.dart';
import '../../widgets/safe_network_image.dart';
import '../../constants.dart';

class SectionTestimonials extends StatefulWidget {
  const SectionTestimonials({Key? key}) : super(key: key);

  @override
  State<SectionTestimonials> createState() => _SectionTestimonialsState();
}

class _SectionTestimonialsState extends State<SectionTestimonials>
    with TickerProviderStateMixin {
  List<Map<String, dynamic>> _testimonials = [];
  bool _isLoading = true;
  String? _error;
  late AnimationController _shimmerController;
  late AnimationController _floatController;
  late PageController _featuredController;
  int _featuredPage = 0;

  @override
  void initState() {
    super.initState();
    _shimmerController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    )..repeat();
    _floatController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 3),
    )..repeat(reverse: true);
    _featuredController = PageController(viewportFraction: 0.88);
    _loadTestimonials();
  }

  @override
  void dispose() {
    _shimmerController.dispose();
    _floatController.dispose();
    _featuredController.dispose();
    super.dispose();
  }

  Future<void> _loadTestimonials() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });
    try {
      final response = await http
          .get(
            Uri.parse(
                '${ApiConstants.baseUrl}/testimonials/landing?limit=20'),
            headers: {'Accept': 'application/json'},
          )
          .timeout(const Duration(seconds: 10));
      if (response.statusCode == 200) {
        final List<dynamic> data = json.decode(utf8.decode(response.bodyBytes));
        setState(() {
          _testimonials = data.cast<Map<String, dynamic>>();
          _isLoading = false;
        });
      } else {
        setState(() {
          _error = 'Erreur serveur (${response.statusCode})';
          _isLoading = false;
        });
      }
    } catch (e) {
      setState(() {
        _error = 'Impossible de charger les témoignages.';
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0D0D1A),
      body: CustomScrollView(
        physics: const BouncingScrollPhysics(),
        slivers: [
          SliverToBoxAdapter(child: _buildHeader(context)),
          SliverToBoxAdapter(child: _buildBody()),
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
          colors: [Color(0xFF1E0533), Color(0xFF2D1B69), Color(0xFF0D0D1A)],
          begin: Alignment.topLeft,
          end: Alignment.bottomCenter,
        ),
      ),
      child: Stack(
        children: [
          // Floating orbs
          ...List.generate(4, (i) {
            return AnimatedBuilder(
              animation: _floatController,
              builder: (_, __) {
                final angle = (i * 90.0 + _floatController.value * 30) *
                    math.pi / 180;
                return Positioned(
                  right: 20 + i * 30.0 + math.cos(angle) * 15,
                  top: 20 + i * 25.0 + math.sin(angle) * 10,
                  child: Container(
                    width: 60 + i * 20.0,
                    height: 60 + i * 20.0,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: RadialGradient(colors: [
                        [
                          const Color(0xFF6366F1),
                          const Color(0xFF8B5CF6),
                          const Color(0xFFEC4899),
                          const Color(0xFF06B6D4),
                        ][i]
                            .withOpacity(0.2),
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
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 52),
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
                          border: Border.all(
                              color: Colors.white.withOpacity(0.12)),
                        ),
                        child: const Icon(Icons.arrow_back_ios_new_rounded,
                            color: Colors.white, size: 18),
                      ),
                    ).animate().fadeIn(duration: 300.ms).slideX(begin: -0.15),
                  const SizedBox(height: 32),

                  // Quote icon with gradient
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [Color(0xFF6366F1), Color(0xFF8B5CF6)],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      borderRadius: BorderRadius.circular(20),
                      boxShadow: [
                        BoxShadow(
                          color: const Color(0xFF6366F1).withOpacity(0.5),
                          blurRadius: 20,
                          offset: const Offset(0, 8),
                        ),
                      ],
                    ),
                    child: const Icon(Icons.format_quote_rounded,
                        color: Colors.white, size: 28),
                  )
                      .animate()
                      .fadeIn(delay: 150.ms)
                      .scale(
                          begin: const Offset(0.8, 0.8),
                          curve: Curves.easeOutBack),
                  const SizedBox(height: 20),

                  ShaderMask(
                    shaderCallback: (b) => const LinearGradient(
                      colors: [Colors.white, Color(0xFFC4B5FD)],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ).createShader(b),
                    child: Text(
                      'Ils nous font\nconfiance',
                      style: GoogleFonts.spaceGrotesk(
                        color: Colors.white,
                        fontSize: 38,
                        fontWeight: FontWeight.w900,
                        height: 1.05,
                        letterSpacing: -1.5,
                      ),
                    ),
                  ).animate().fadeIn(delay: 250.ms).slideY(begin: 0.15),
                  const SizedBox(height: 14),

                  Text(
                    'Témoignages authentiques, validés par notre équipe.',
                    style: GoogleFonts.inter(
                      color: Colors.white.withOpacity(0.55),
                      fontSize: 14,
                      height: 1.5,
                    ),
                  ).animate().fadeIn(delay: 350.ms),

                  // Stats pills
                  if (!_isLoading && _testimonials.isNotEmpty) ...[
                    const SizedBox(height: 24),
                    Row(
                      children: [
                        _buildStatPill(
                          '${_testimonials.length}',
                          'Avis',
                          Icons.star_rounded,
                          const Color(0xFFFBBF24),
                        ),
                        const SizedBox(width: 10),
                        _buildStatPill(
                          '${_testimonials.where((t) => t['is_featured'] == true).length}',
                          'Mis en avant',
                          Icons.verified_rounded,
                          const Color(0xFF6366F1),
                        ),
                        const SizedBox(width: 10),
                        _buildStatPill(
                          '5.0',
                          'Note moy.',
                          Icons.thumb_up_rounded,
                          AppTheme.primaryGreen,
                        ),
                      ],
                    ).animate().fadeIn(delay: 450.ms),
                  ],
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatPill(
      String value, String label, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
      decoration: BoxDecoration(
        color: color.withOpacity(0.12),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: color.withOpacity(0.25)),
      ),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        Icon(icon, color: color, size: 14),
        const SizedBox(width: 6),
        Text(
          '$value $label',
          style: GoogleFonts.inter(
            color: color,
            fontSize: 11,
            fontWeight: FontWeight.w800,
          ),
        ),
      ]),
    );
  }

  Widget _buildBody() {
    if (_isLoading) return _buildLoadingState();
    if (_error != null) return _buildErrorState();
    if (_testimonials.isEmpty) return _buildEmptyState();

    final featured =
        _testimonials.where((t) => t['is_featured'] == true).toList();
    final regular =
        _testimonials.where((t) => t['is_featured'] != true).toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Featured carousel
        if (featured.isNotEmpty) ...[
          _buildSectionLabel('⭐  MIS EN AVANT', const Color(0xFFFBBF24)),
          SizedBox(
            height: 240,
            child: PageView.builder(
              controller: _featuredController,
              itemCount: featured.length,
              onPageChanged: (i) => setState(() => _featuredPage = i),
              itemBuilder: (_, i) => _buildFeaturedCard(featured[i], i),
            ),
          ),
          // Dots
          Center(
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: List.generate(
                featured.length,
                (i) => AnimatedContainer(
                  duration: 300.ms,
                  margin: const EdgeInsets.symmetric(horizontal: 3, vertical: 12),
                  width: _featuredPage == i ? 20 : 6,
                  height: 6,
                  decoration: BoxDecoration(
                    color: _featuredPage == i
                        ? const Color(0xFF8B5CF6)
                        : Colors.white.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(3),
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(height: 8),
        ],

        // Regular testimonials
        if (regular.isNotEmpty) ...[
          _buildSectionLabel(
              '✅  TÉMOIGNAGES VALIDÉS (${regular.length})', AppTheme.primaryGreen),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Column(
              children: regular.asMap().entries.map((e) {
                return _buildRegularCard(e.value, e.key);
              }).toList(),
            ),
          ),
        ],

        // All featured (if no regular)
        if (featured.isNotEmpty && regular.isEmpty) ...[
          _buildSectionLabel('✅  TOUS LES TÉMOIGNAGES', AppTheme.primaryGreen),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Column(
              children: featured.asMap().entries.map((e) {
                return _buildRegularCard(e.value, e.key);
              }).toList(),
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildSectionLabel(String text, Color color) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 24, 20, 16),
      child: Text(
        text,
        style: GoogleFonts.inter(
          fontSize: 10,
          fontWeight: FontWeight.w900,
          color: color,
          letterSpacing: 1.5,
        ),
      ),
    );
  }

  // ── Featured card (carousel) ──────────────────────────────────────────────
  Widget _buildFeaturedCard(Map<String, dynamic> t, int index) {
    final name = t['user_name'] ?? 'Éco-Citoyen';
    final content = t['content'] ?? '';
    final rating = (t['rating'] as num?)?.toInt() ?? 5;
    final avatarUrl = _resolveAvatar(t, index);

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 8),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF1E1B4B), Color(0xFF312E81)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(28),
        border: Border.all(
          color: const Color(0xFF6366F1).withOpacity(0.4),
          width: 1.5,
        ),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF6366F1).withOpacity(0.2),
            blurRadius: 30,
            offset: const Offset(0, 12),
          ),
        ],
      ),
      child: Stack(
        children: [
          // Decorative top-right orb
          Positioned(
            top: -20,
            right: -20,
            child: Container(
              width: 100,
              height: 100,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(colors: [
                  const Color(0xFF8B5CF6).withOpacity(0.25),
                  Colors.transparent,
                ]),
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
                    // Stars
                    Row(
                      children: List.generate(
                        5,
                        (i) => Icon(
                          i < rating
                              ? Icons.star_rounded
                              : Icons.star_outline_rounded,
                          color: const Color(0xFFFBBF24),
                          size: 16,
                        ),
                      ),
                    ),
                    const Spacer(),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 10, vertical: 5),
                      decoration: BoxDecoration(
                        color: const Color(0xFF6366F1).withOpacity(0.25),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(
                            color: const Color(0xFF6366F1).withOpacity(0.4)),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.verified_rounded,
                              color: Color(0xFFA5B4FC), size: 12),
                          const SizedBox(width: 4),
                          Text(
                            'Vérifié',
                            style: GoogleFonts.inter(
                              color: const Color(0xFFA5B4FC),
                              fontSize: 10,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),

                // Large quote mark
                Text(
                  '"',
                  style: GoogleFonts.spaceGrotesk(
                    color: const Color(0xFF6366F1),
                    fontSize: 56,
                    fontWeight: FontWeight.w900,
                    height: 0.5,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  content,
                  maxLines: 3,
                  overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.inter(
                    color: Colors.white.withOpacity(0.85),
                    fontSize: 13,
                    fontStyle: FontStyle.italic,
                    height: 1.6,
                  ),
                ),
                const Spacer(),

                // User info
                Row(
                  children: [
                    SafeNetworkCircleAvatar(url: avatarUrl, radius: 20),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        name,
                        style: GoogleFonts.spaceGrotesk(
                          fontWeight: FontWeight.w800,
                          fontSize: 14,
                          color: Colors.white,
                        ),
                      ),
                    ),
                    const Icon(Icons.format_quote_rounded,
                        color: Color(0xFF6366F1), size: 20),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    ).animate().fadeIn(delay: (index * 80).ms).scale(
          begin: const Offset(0.95, 0.95),
          curve: Curves.easeOutBack,
        );
  }

  // ── Regular testimonial card ──────────────────────────────────────────────
  Widget _buildRegularCard(Map<String, dynamic> t, int index) {
    final name = t['user_name'] ?? 'Éco-Citoyen';
    final content = t['content'] ?? '';
    final rating = (t['rating'] as num?)?.toInt() ?? 5;
    final avatarUrl = _resolveAvatar(t, index);

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: const Color(0xFF111827),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.white.withOpacity(0.06)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Top accent line
          Container(
            height: 3,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  [
                    const Color(0xFF6366F1),
                    const Color(0xFF10B981),
                    const Color(0xFFF59E0B),
                    const Color(0xFFEC4899),
                    const Color(0xFF3B82F6),
                  ][index % 5],
                  Colors.transparent,
                ],
              ),
              borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
            ),
          ),

          Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    // Stars
                    Row(
                      children: List.generate(
                        5,
                        (i) => Icon(
                          i < rating
                              ? Icons.star_rounded
                              : Icons.star_outline_rounded,
                          color: const Color(0xFFFBBF24),
                          size: 15,
                        ),
                      ),
                    ),
                    const Spacer(),
                    Text(
                      '$rating/5',
                      style: GoogleFonts.outfit(
                        color: const Color(0xFFFBBF24),
                        fontSize: 12,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),

                // Quote
                RichText(
                  text: TextSpan(
                    children: [
                      TextSpan(
                        text: '" ',
                        style: GoogleFonts.spaceGrotesk(
                          color: const Color(0xFF6366F1),
                          fontSize: 24,
                          fontWeight: FontWeight.w900,
                          height: 0.9,
                        ),
                      ),
                      TextSpan(
                        text: content,
                        style: GoogleFonts.inter(
                          color: Colors.white.withOpacity(0.75),
                          fontSize: 13,
                          fontStyle: FontStyle.italic,
                          height: 1.6,
                        ),
                      ),
                      TextSpan(
                        text: ' "',
                        style: GoogleFonts.spaceGrotesk(
                          color: const Color(0xFF6366F1),
                          fontSize: 24,
                          fontWeight: FontWeight.w900,
                          height: 0.9,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),

                // Divider
                Divider(color: Colors.white.withOpacity(0.05)),
                const SizedBox(height: 12),

                // User
                Row(
                  children: [
                    SafeNetworkCircleAvatar(url: avatarUrl, radius: 18),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            name,
                            style: GoogleFonts.spaceGrotesk(
                              fontWeight: FontWeight.w800,
                              fontSize: 13,
                              color: Colors.white,
                            ),
                          ),
                          Text(
                            'Éco-citoyen EcoRewind',
                            style: GoogleFonts.inter(
                              fontSize: 11,
                              color: Colors.white.withOpacity(0.35),
                            ),
                          ),
                        ],
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.all(7),
                      decoration: BoxDecoration(
                        color: const Color(0xFF6366F1).withOpacity(0.12),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.verified_rounded,
                        color: Color(0xFF6366F1),
                        size: 14,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    ).animate().fadeIn(delay: (300 + index * 80).ms).slideY(begin: 0.05);
  }

  // ── Loading shimmer ───────────────────────────────────────────────────────
  Widget _buildLoadingState() {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: List.generate(
          3,
          (i) => AnimatedBuilder(
            animation: _shimmerController,
            builder: (_, __) {
              return Container(
                margin: const EdgeInsets.only(bottom: 12),
                height: 160,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(20),
                  gradient: LinearGradient(
                    colors: const [
                      Color(0xFF1A1A2E),
                      Color(0xFF16213E),
                      Color(0xFF1A1A2E),
                    ],
                    stops: [
                      0.0,
                      _shimmerController.value,
                      1.0,
                    ],
                  ),
                ),
              );
            },
          ),
        ),
      ),
    );
  }

  // ── Error state ───────────────────────────────────────────────────────────
  Widget _buildErrorState() {
    return Padding(
      padding: const EdgeInsets.all(32),
      child: Container(
        padding: const EdgeInsets.all(28),
        decoration: BoxDecoration(
          color: Colors.red.withOpacity(0.07),
          borderRadius: BorderRadius.circular(24),
          border: Border.all(color: Colors.red.withOpacity(0.15)),
        ),
        child: Column(
          children: [
            const Icon(Icons.wifi_off_rounded, size: 44, color: Colors.redAccent),
            const SizedBox(height: 16),
            Text(
              _error!,
              textAlign: TextAlign.center,
              style: GoogleFonts.inter(
                  color: Colors.red.shade300, fontSize: 14),
            ),
            const SizedBox(height: 20),
            ElevatedButton.icon(
              onPressed: _loadTestimonials,
              icon: const Icon(Icons.refresh_rounded, size: 18),
              label: Text('Réessayer',
                  style: GoogleFonts.inter(fontWeight: FontWeight.w700)),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF6366F1),
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14)),
                padding: const EdgeInsets.symmetric(
                    horizontal: 24, vertical: 12),
                elevation: 0,
              ),
            ),
          ],
        ),
      ).animate().fadeIn().scale(),
    );
  }

  // ── Empty state ───────────────────────────────────────────────────────────
  Widget _buildEmptyState() {
    return Padding(
      padding: const EdgeInsets.all(32),
      child: Container(
        padding: const EdgeInsets.all(40),
        decoration: BoxDecoration(
          color: const Color(0xFF111827),
          borderRadius: BorderRadius.circular(24),
          border: Border.all(color: Colors.white.withOpacity(0.06)),
        ),
        child: Column(
          children: [
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: const Color(0xFF6366F1).withOpacity(0.12),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.chat_bubble_outline_rounded,
                  size: 40, color: Color(0xFF6366F1)),
            ),
            const SizedBox(height: 20),
            Text(
              'Aucun témoignage pour l\'instant',
              style: GoogleFonts.spaceGrotesk(
                fontSize: 18,
                fontWeight: FontWeight.w800,
                color: Colors.white,
              ),
            ),
            const SizedBox(height: 10),
            Text(
              'Les témoignages validés par notre équipe\napparaîtront ici.',
              textAlign: TextAlign.center,
              style: GoogleFonts.inter(
                color: Colors.white.withOpacity(0.4),
                fontSize: 13,
                height: 1.6,
              ),
            ),
          ],
        ),
      ).animate().fadeIn().scale(),
    );
  }

  // ── Helpers ───────────────────────────────────────────────────────────────
  String _resolveAvatar(Map<String, dynamic> t, int index) {
    final avatarUrl = t['user_avatar_url'] as String?;
    final name = t['user_name'] ?? 'User';
    final colors = [
      '6366F1', 'EC4899', '059669', 'F59E0B', '3B82F6', 'EF4444', '8B5CF6'
    ];
    final colorHex = colors[index % colors.length];
    final generatedUrl =
        'https://ui-avatars.com/api/?name=${Uri.encodeComponent(name)}&size=150&background=$colorHex&color=fff&bold=true';

    if (avatarUrl == null || avatarUrl.isEmpty) return generatedUrl;
    if (avatarUrl.startsWith('/')) {
      return '${ApiConstants.baseUrl}$avatarUrl';
    }
    return avatarUrl;
  }
}
