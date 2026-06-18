import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../theme/app_theme.dart';
import '../../widgets/web_back_button.dart';
import '../../services/auth_service.dart';
import '../../services/l10n_service.dart';
import '../../services/theme_service.dart';
import '../../models/user_model.dart';

class PointsHistoryScreen extends StatefulWidget {
  const PointsHistoryScreen({Key? key}) : super(key: key);

  @override
  State<PointsHistoryScreen> createState() => _PointsHistoryScreenState();
}

class _PointsHistoryScreenState extends State<PointsHistoryScreen> {
  final AuthService _authService = AuthService();
  bool _loading = true;
  String? _error;
  List<dynamic> _history = [];
  double _totalScore = 0.0;

  bool get _isDarkMode => ThemeService.isDarkMode;

  @override
  void initState() {
    super.initState();
    _loadHistory();
  }

  Future<void> _loadHistory() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      // 1. Charger le profil utilisateur le plus récent pour obtenir le score global précis
      final profile = await _authService.fetchUserProfile();
      if (profile != null) {
        _totalScore = (profile['global_score'] as num?)?.toDouble() ?? 0.0;
      } else {
        _totalScore = AuthState.currentUser?.globalScore ?? 0.0;
      }

      // 2. Charger l'historique complet des points
      final data = await _authService.fetchPointsHistory();
      if (mounted) {
        setState(() {
          _history = data;
          _loading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = L10n.isArabic
              ? 'تعذر تحميل سجل النقاط : $e'
              : 'Impossible de charger l\'historique des points : $e';
          _loading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final title = L10n.isArabic ? 'سجل النقاط' : 'Historique des points';

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: webLeading(IconButton(
          onPressed: () => Navigator.pop(context),
          icon: Icon(
            Icons.arrow_back_ios_new_rounded,
            color: _isDarkMode ? Colors.white : AppTheme.deepSlate,
          ),
        )),
        title: Text(
          title,
          style: GoogleFonts.outfit(
            fontSize: 24,
            fontWeight: FontWeight.bold,
            color: _isDarkMode ? Colors.white : AppTheme.deepSlate,
          ),
        ),
        actions: [
          IconButton(
            icon: Icon(
              Icons.refresh_rounded,
              color: _isDarkMode ? Colors.white : AppTheme.deepSlate,
            ),
            onPressed: _loadHistory,
            tooltip: L10n.isArabic ? 'تحديث' : 'Actualiser',
          ),
        ],
      ),
      body: _loading
          ? _buildLoader()
          : _error != null
              ? _buildError()
              : _history.isEmpty
                  ? _buildEmpty()
                  : _buildContent(),
    );
  }

  Widget _buildLoader() {
    return const Center(
      child: CircularProgressIndicator(color: AppTheme.primaryGreen),
    );
  }

  Widget _buildError() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.error_outline_rounded, size: 56, color: Colors.redAccent),
            const SizedBox(height: 16),
            Text(
              _error!,
              textAlign: TextAlign.center,
              style: GoogleFonts.inter(
                color: _isDarkMode ? const Color(0xFF94A3B8) : AppTheme.textMuted,
                fontSize: 14,
              ),
            ),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              onPressed: _loadHistory,
              icon: const Icon(Icons.refresh_rounded),
              label: Text(
                L10n.isArabic ? 'إعادة المحاولة' : 'Réessayer',
                style: GoogleFonts.outfit(fontWeight: FontWeight.w700),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.primaryGreen,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 14),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmpty() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(40),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: AppTheme.primaryGreen.withOpacity(0.08),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.history_toggle_off_rounded,
                size: 56,
                color: AppTheme.primaryGreen,
              ),
            ),
            const SizedBox(height: 24),
            Text(
              L10n.isArabic ? 'لا يوجد سجل بعد' : 'Aucun point gagné',
              style: GoogleFonts.outfit(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: _isDarkMode ? Colors.white : AppTheme.deepSlate,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              L10n.isArabic
                  ? 'قم بحل الاختبارات البيئية أو فرز النفايات للبدء في كسب النقاط !'
                  : 'Répondez aux quiz ou triez vos déchets\npour commencer à cumuler des points !',
              textAlign: TextAlign.center,
              style: GoogleFonts.inter(
                fontSize: 14,
                color: _isDarkMode ? const Color(0xFF94A3B8) : AppTheme.textMuted,
                height: 1.5,
              ),
            ),
          ],
        ),
      ).animate().fadeIn(delay: 200.ms).scale(begin: const Offset(0.9, 0.9)),
    );
  }

  Widget _buildContent() {
    return RefreshIndicator(
      color: AppTheme.primaryGreen,
      onRefresh: _loadHistory,
      child: ListView(
        physics: const BouncingScrollPhysics(),
        padding: const EdgeInsets.symmetric(horizontal: 20),
        children: [
          const SizedBox(height: 12),
          // ── Carte récapitulative du Score Total ──────────────────────────
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: _isDarkMode
                    ? [const Color(0xFF065F46), const Color(0xFF064E3B)]
                    : [const Color(0xFF059669), const Color(0xFF10B981)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(24),
              boxShadow: [
                BoxShadow(
                  color: AppTheme.primaryGreen.withOpacity(0.3),
                  blurRadius: 20,
                  offset: const Offset(0, 8),
                ),
              ],
            ),
            child: Column(
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(Icons.stars_rounded, color: Colors.white, size: 28),
                    const SizedBox(width: 8),
                    Text(
                      L10n.isArabic ? 'مجموع النقاط' : 'Score Total',
                      style: GoogleFonts.outfit(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: Colors.white70,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  _totalScore.toStringAsFixed(1),
                  style: GoogleFonts.outfit(
                    fontSize: 44,
                    fontWeight: FontWeight.w900,
                    color: Colors.white,
                  ),
                ),
                Text(
                  L10n.isArabic ? 'نقاط بيئية تراكمية' : 'points éco-citoyens',
                  style: GoogleFonts.inter(
                    fontSize: 12,
                    color: Colors.white.withOpacity(0.8),
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ).animate().fadeIn().slideY(begin: -0.15, curve: Curves.easeOutCubic),

          const SizedBox(height: 28),

          // ── Liste de l'historique ──────────────────────────
          Text(
            L10n.isArabic ? 'تفاصيل المعاملات' : 'Détail des gains',
            style: GoogleFonts.outfit(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: _isDarkMode ? Colors.white : AppTheme.deepSlate,
            ),
          ),
          const SizedBox(height: 12),

          ListView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: _history.length,
            itemBuilder: (context, index) {
              final item = _history[index];
              return _buildHistoryCard(item, index);
            },
          ),
          const SizedBox(height: 32),
        ],
      ),
    );
  }

  Widget _buildHistoryCard(Map<String, dynamic> item, int index) {
    final type = item['type'] as String? ?? 'tri';
    final points = (item['points'] as num?)?.toDouble() ?? 0.0;
    final dateStr = item['date'] as String?;
    final desc = item['description'] as String? ?? '';

    final isQuiz = type == 'quiz';

    // Différenciation de style
    final Color itemColor = isQuiz ? const Color(0xFF8B5CF6) : const Color(0xFF10B981);
    final IconData icon = isQuiz ? Icons.school_rounded : Icons.recycling_rounded;
    final String categoryLabel = isQuiz
        ? (L10n.isArabic ? 'اختبار بيئي' : 'Quiz éco-responsable')
        : (L10n.isArabic ? 'فرز النفايات' : 'Tri de déchets');

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: _isDarkMode ? const Color(0xFF1E293B) : Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: _isDarkMode
              ? Colors.white.withOpacity(0.05)
              : Colors.black.withOpacity(0.04),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(_isDarkMode ? 0.2 : 0.03),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Indicateur latéral de couleur
              Container(
                width: 6,
                color: itemColor,
              ),
              const SizedBox(width: 12),

              // Contenu principal
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 4),
                  child: Row(
                    children: [
                      // Icône type
                      Container(
                        width: 44,
                        height: 44,
                        decoration: BoxDecoration(
                          color: itemColor.withOpacity(0.12),
                          shape: BoxShape.circle,
                        ),
                        child: Icon(icon, color: itemColor, size: 22),
                      ),
                      const SizedBox(width: 16),

                      // Description et dates
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text(
                              categoryLabel,
                              style: GoogleFonts.outfit(
                                fontSize: 13,
                                fontWeight: FontWeight.bold,
                                color: itemColor,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              desc,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: GoogleFonts.inter(
                                fontSize: 14,
                                fontWeight: FontWeight.w600,
                                color: _isDarkMode ? Colors.white : AppTheme.deepSlate,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              dateStr != null ? _formatDate(dateStr) : '—',
                              style: GoogleFonts.inter(
                                fontSize: 11,
                                color: _isDarkMode ? const Color(0xFF64748B) : AppTheme.textMuted,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 12),

                      // Nombre de points gagnés
                      Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Text(
                            '+${points.toStringAsFixed(1)}',
                            style: GoogleFonts.outfit(
                              fontSize: 18,
                              fontWeight: FontWeight.w900,
                              color: itemColor,
                            ),
                          ),
                          Text(
                            'pts',
                            style: GoogleFonts.inter(
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                              color: _isDarkMode ? const Color(0xFF64748B) : AppTheme.textMuted,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(width: 8),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    ).animate(delay: (index * 60).ms).fadeIn(duration: 300.ms).slideX(begin: 0.08);
  }

  String _formatDate(String iso) {
    try {
      final dt = DateTime.parse(iso).toLocal();
      final now = DateTime.now();
      final diff = now.difference(dt);
      if (diff.inMinutes < 60) {
        return L10n.isArabic ? 'منذ ${diff.inMinutes} دقيقة' : 'il y a ${diff.inMinutes} min';
      }
      if (diff.inHours < 24) {
        return L10n.isArabic ? 'منذ ${diff.inHours} ساعة' : 'il y a ${diff.inHours}h';
      }
      if (diff.inDays == 1) {
        return L10n.isArabic ? 'أمس' : 'hier';
      }
      if (diff.inDays < 7) {
        return L10n.isArabic ? 'منذ ${diff.inDays} أيام' : 'il y a ${diff.inDays}j';
      }
      return '${dt.day.toString().padLeft(2, '0')}/${dt.month.toString().padLeft(2, '0')}/${dt.year}';
    } catch (_) {
      return iso;
    }
  }
}
