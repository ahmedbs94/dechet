/// lib/features/scan/scan_history_screen.dart
///
/// Écran Historique des scans & Classement Global
/// ─────────────────────────────────────────────
/// Affiche :
///   • Résumé du citoyen (total scans, total points QR)
///   • Historique chronologique des scans (avec type, points, date)
///   • Leaderboard top-10 des citoyens éco

import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../models/user_model.dart';
import '../../theme/app_theme.dart';
import 'scan_service.dart';

// ── Couleurs et icônes par type de déchet ───────────────────────────────────
const Map<String, Map<String, dynamic>> _wasteInfo = {
  'plastique':    {'label': 'Plastique',    'icon': Icons.local_drink_rounded,   'color': Color(0xFF3B82F6)},
  'verre':        {'label': 'Verre',        'icon': Icons.wine_bar_rounded,       'color': Color(0xFF10B981)},
  'papier':       {'label': 'Papier',       'icon': Icons.article_rounded,        'color': Color(0xFF8B5CF6)},
  'metal':        {'label': 'Métal',        'icon': Icons.hardware_rounded,       'color': Color(0xFFF59E0B)},
  'organique':    {'label': 'Organique',    'icon': Icons.eco_rounded,            'color': Color(0xFF22C55E)},
  'electronique': {'label': 'Électronique', 'icon': Icons.devices_rounded,        'color': Color(0xFFEF4444)},
  'general':      {'label': 'Général',      'icon': Icons.delete_rounded,         'color': Color(0xFF6B7280)},
};

Map<String, dynamic> _waste(String? type) =>
    _wasteInfo[type?.toLowerCase()] ?? _wasteInfo['general']!;

// ── Médailles pour le leaderboard ───────────────────────────────────────────
const List<Map<String, dynamic>> _medals = [
  {'icon': '🥇', 'color': Color(0xFFFFD700)},
  {'icon': '🥈', 'color': Color(0xFFC0C0C0)},
  {'icon': '🥉', 'color': Color(0xFFCD7F32)},
];

class ScanHistoryScreen extends StatefulWidget {
  const ScanHistoryScreen({Key? key}) : super(key: key);

  @override
  State<ScanHistoryScreen> createState() => _ScanHistoryScreenState();
}

class _ScanHistoryScreenState extends State<ScanHistoryScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabs;
  final ScanService _service = ScanService();

  // Data
  List<Map<String, dynamic>> _history = [];
  List<Map<String, dynamic>> _leaderboard = [];
  int _totalScans = 0;
  double _totalPoints = 0;

  bool _loadingHistory = true;
  bool _loadingBoard = true;

  @override
  void initState() {
    super.initState();
    _tabs = TabController(length: 2, vsync: this);
    _loadHistory();
    _loadLeaderboard();
  }

  @override
  void dispose() {
    _tabs.dispose();
    super.dispose();
  }

  Future<void> _loadHistory() async {
    setState(() => _loadingHistory = true);
    final data = await _service.getScanHistory(limit: 50);
    if (mounted) {
      final scans = (data['scans'] as List? ?? []).cast<Map<String, dynamic>>();
      double pts = 0;
      for (final s in scans) {
        pts += (s['points_earned'] as num?)?.toDouble() ?? 0;
      }
      setState(() {
        _history = scans;
        _totalScans = data['total_scans'] as int? ?? scans.length;
        _totalPoints = pts;
        _loadingHistory = false;
      });
    }
  }

  Future<void> _loadLeaderboard() async {
    setState(() => _loadingBoard = true);
    final data = await _service.getLeaderboard(limit: 10);
    if (mounted) {
      setState(() {
        _leaderboard = data;
        _loadingBoard = false;
      });
    }
  }

  // ── Build ────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.deepNavy,
      body: NestedScrollView(
        headerSliverBuilder: (_, __) => [_buildSliverHeader()],
        body: Column(
          children: [
            _buildTabBar(),
            Expanded(
              child: TabBarView(
                controller: _tabs,
                children: [
                  _buildHistoryTab(),
                  _buildLeaderboardTab(),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ── Sliver header avec résumé ────────────────────────────────────────────

  Widget _buildSliverHeader() {
    final user = AuthState.currentUser;
    return SliverAppBar(
      expandedHeight: 220,
      floating: false,
      pinned: true,
      backgroundColor: AppTheme.deepNavy,
      surfaceTintColor: Colors.transparent,
      leading: IconButton(
        icon: const Icon(Icons.arrow_back_ios_rounded, color: Colors.white),
        onPressed: () => Navigator.pop(context),
      ),
      title: Text(
        'Mes Recyclages',
        style: GoogleFonts.outfit(
          color: Colors.white,
          fontWeight: FontWeight.w800,
          fontSize: 18,
        ),
      ),
      flexibleSpace: FlexibleSpaceBar(
        collapseMode: CollapseMode.parallax,
        background: Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [Color(0xFF052E24), AppTheme.deepNavy],
            ),
          ),
          child: SafeArea(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 60, 20, 0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const SizedBox(height: 12),
                  Text(
                    user?.name ?? 'Éco-Citoyen',
                    style: GoogleFonts.outfit(
                      color: Colors.white,
                      fontSize: 22,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Score global : ${user?.globalScore.toStringAsFixed(0) ?? "0"} pts',
                    style: GoogleFonts.inter(
                      color: AppTheme.accentMint,
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 20),
                  // Summary cards
                  Row(
                    children: [
                      _summaryCard(
                        icon: Icons.qr_code_scanner_rounded,
                        label: 'Scans totaux',
                        value: '$_totalScans',
                        color: AppTheme.primaryGreen,
                      ),
                      const SizedBox(width: 12),
                      _summaryCard(
                        icon: Icons.stars_rounded,
                        label: 'Points QR gagnés',
                        value: '+${_totalPoints.toStringAsFixed(0)}',
                        color: AppTheme.secondaryGold,
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _summaryCard({
    required IconData icon,
    required String label,
    required String value,
    required Color color,
  }) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.07),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Colors.white.withOpacity(0.1)),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: color.withOpacity(0.15),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(icon, color: color, size: 18),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    value,
                    style: GoogleFonts.outfit(
                      color: Colors.white,
                      fontSize: 20,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  Text(
                    label,
                    style: GoogleFonts.inter(
                      color: Colors.white54,
                      fontSize: 10,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ── Tab bar ──────────────────────────────────────────────────────────────

  Widget _buildTabBar() {
    return Container(
      color: AppTheme.deepNavy,
      child: TabBar(
        controller: _tabs,
        labelColor: AppTheme.primaryGreen,
        unselectedLabelColor: Colors.white38,
        indicatorColor: AppTheme.primaryGreen,
        indicatorWeight: 2.5,
        labelStyle: GoogleFonts.outfit(fontWeight: FontWeight.w700, fontSize: 14),
        unselectedLabelStyle: GoogleFonts.outfit(fontSize: 14),
        tabs: const [
          Tab(text: 'Historique'),
          Tab(text: 'Classement'),
        ],
      ),
    );
  }

  // ── Onglet Historique ────────────────────────────────────────────────────

  Widget _buildHistoryTab() {
    if (_loadingHistory) {
      return const Center(
        child: CircularProgressIndicator(color: AppTheme.primaryGreen),
      );
    }

    if (_history.isEmpty) {
      return _emptyState(
        icon: Icons.qr_code_scanner_rounded,
        title: 'Aucun scan encore',
        subtitle: 'Scannez votre première poubelle intelligente pour gagner des points !',
      );
    }

    return RefreshIndicator(
      color: AppTheme.primaryGreen,
      backgroundColor: AppTheme.deepNavy,
      onRefresh: _loadHistory,
      child: ListView.builder(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 100),
        itemCount: _history.length,
        itemBuilder: (context, i) =>
            _buildScanCard(_history[i], i).animate(delay: (i * 40).ms).fadeIn().slideX(begin: 0.1),
      ),
    );
  }

  Widget _buildScanCard(Map<String, dynamic> scan, int index) {
    final type = scan['bin_type'] as String? ?? 'general';
    final info = _waste(type);
    final color = info['color'] as Color;
    final points = (scan['points_earned'] as num?)?.toDouble() ?? 0;
    final rawDate = scan['scanned_at'] as String?;
    final date = rawDate != null ? _formatDate(rawDate) : 'Date inconnue';
    final binCode = scan['bin_code'] as String? ?? '';

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: const Color(0xFF1E293B),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: Colors.white.withOpacity(0.06)),
      ),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        leading: Container(
          width: 48,
          height: 48,
          decoration: BoxDecoration(
            color: color.withOpacity(0.15),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: color.withOpacity(0.25)),
          ),
          child: Icon(info['icon'] as IconData, color: color, size: 22),
        ),
        title: Text(
          info['label'] as String,
          style: GoogleFonts.outfit(
            color: Colors.white,
            fontWeight: FontWeight.w700,
            fontSize: 15,
          ),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 2),
            Text(
              binCode,
              style: GoogleFonts.inter(
                color: Colors.white38,
                fontSize: 11,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              date,
              style: GoogleFonts.inter(
                color: Colors.white24,
                fontSize: 11,
              ),
            ),
          ],
        ),
        trailing: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          decoration: BoxDecoration(
            color: color.withOpacity(0.12),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: color.withOpacity(0.2)),
          ),
          child: Text(
            '+${points.toStringAsFixed(0)}',
            style: GoogleFonts.outfit(
              color: color,
              fontWeight: FontWeight.w900,
              fontSize: 14,
            ),
          ),
        ),
      ),
    );
  }

  // ── Onglet Classement ────────────────────────────────────────────────────

  Widget _buildLeaderboardTab() {
    if (_loadingBoard) {
      return const Center(
        child: CircularProgressIndicator(color: AppTheme.primaryGreen),
      );
    }

    if (_leaderboard.isEmpty) {
      return _emptyState(
        icon: Icons.emoji_events_rounded,
        title: 'Classement vide',
        subtitle: 'Soyez le premier à scanner une poubelle !',
      );
    }

    return RefreshIndicator(
      color: AppTheme.primaryGreen,
      backgroundColor: AppTheme.deepNavy,
      onRefresh: _loadLeaderboard,
      child: ListView.builder(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 100),
        itemCount: _leaderboard.length,
        itemBuilder: (context, i) {
          final entry = _leaderboard[i];
          final rank = i + 1;
          final name = entry['user_name'] as String? ?? 'Anonyme';
          final score = (entry['global_score'] as num?)?.toDouble() ?? 0;
          final scans = entry['total_scans'] as int? ?? 0;
          final isMe = entry['user_id'] == AuthState.currentUser?.id;

          return _buildLeaderboardCard(rank, name, score, scans, isMe, i);
        },
      ),
    );
  }

  Widget _buildLeaderboardCard(
    int rank,
    String name,
    double score,
    int scans,
    bool isMe,
    int index,
  ) {
    final isMedal = rank <= 3;
    final medalData = isMedal ? _medals[rank - 1] : null;
    final borderColor = isMe ? AppTheme.primaryGreen : Colors.white.withOpacity(0.06);

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        gradient: isMe
            ? LinearGradient(
                colors: [
                  AppTheme.primaryGreen.withOpacity(0.12),
                  AppTheme.accentTeal.withOpacity(0.06),
                ],
              )
            : null,
        color: isMe ? null : const Color(0xFF1E293B),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: borderColor, width: isMe ? 1.5 : 1),
      ),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        leading: SizedBox(
          width: 48,
          child: isMedal
              ? Text(
                  medalData!['icon'] as String,
                  style: const TextStyle(fontSize: 32),
                  textAlign: TextAlign.center,
                )
              : Container(
                  width: 40,
                  height: 40,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.05),
                    shape: BoxShape.circle,
                  ),
                  child: Text(
                    '#$rank',
                    style: GoogleFonts.outfit(
                      color: Colors.white54,
                      fontWeight: FontWeight.w800,
                      fontSize: 13,
                    ),
                  ),
                ),
        ),
        title: Row(
          children: [
            Expanded(
              child: Text(
                name,
                style: GoogleFonts.outfit(
                  color: isMe ? AppTheme.accentMint : Colors.white,
                  fontWeight: FontWeight.w800,
                  fontSize: 15,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            if (isMe)
              Container(
                margin: const EdgeInsets.only(left: 6),
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: AppTheme.primaryGreen.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  'Vous',
                  style: GoogleFonts.inter(
                    color: AppTheme.primaryGreen,
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
          ],
        ),
        subtitle: Text(
          '$scans scan${scans > 1 ? 's' : ''}',
          style: GoogleFonts.inter(color: Colors.white38, fontSize: 12),
        ),
        trailing: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Text(
              score.toStringAsFixed(0),
              style: GoogleFonts.outfit(
                color: isMedal
                    ? (medalData!['color'] as Color)
                    : (isMe ? AppTheme.accentMint : Colors.white70),
                fontWeight: FontWeight.w900,
                fontSize: 20,
              ),
            ),
            Text(
              'pts',
              style: GoogleFonts.inter(
                color: Colors.white38,
                fontSize: 10,
              ),
            ),
          ],
        ),
      ),
    )
        .animate(delay: (index * 50).ms)
        .fadeIn()
        .slideX(begin: 0.08, curve: Curves.easeOutCubic);
  }

  // ── Helpers ──────────────────────────────────────────────────────────────

  Widget _emptyState({
    required IconData icon,
    required String title,
    required String subtitle,
  }) {
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
              child: Icon(icon, color: AppTheme.primaryGreen, size: 48),
            ),
            const SizedBox(height: 24),
            Text(
              title,
              style: GoogleFonts.outfit(
                color: Colors.white,
                fontSize: 20,
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              subtitle,
              textAlign: TextAlign.center,
              style: GoogleFonts.inter(
                color: Colors.white38,
                fontSize: 14,
                height: 1.5,
              ),
            ),
          ],
        ),
      ),
    ).animate().fadeIn(delay: 200.ms).scale(begin: const Offset(0.9, 0.9));
  }

  String _formatDate(String iso) {
    try {
      final dt = DateTime.parse(iso).toLocal();
      final now = DateTime.now();
      final diff = now.difference(dt);
      if (diff.inMinutes < 60) return 'il y a ${diff.inMinutes} min';
      if (diff.inHours < 24) return 'il y a ${diff.inHours}h';
      if (diff.inDays == 1) return 'hier';
      if (diff.inDays < 7) return 'il y a ${diff.inDays}j';
      return '${dt.day}/${dt.month}/${dt.year}';
    } catch (_) {
      return iso;
    }
  }
}
