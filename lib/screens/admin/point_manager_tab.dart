import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import '../../theme/app_theme.dart';
import '../../services/auth_service.dart';

class PointManagerTab extends StatefulWidget {
  const PointManagerTab({Key? key}) : super(key: key);

  @override
  State<PointManagerTab> createState() => _PointManagerTabState();
}

class _PointManagerTabState extends State<PointManagerTab>
    with AutomaticKeepAliveClientMixin {
  @override
  bool get wantKeepAlive => true;

  Timer? _pollingTimer;

  List<Map<String, dynamic>> _alerts = [];
  List<Map<String, dynamic>> _centers = [];
  int _unreadCount = 0;
  bool _loadingAlerts = true;
  bool _loadingCenters = true;
  bool _markingRead = false;

  @override
  void initState() {
    super.initState();
    _loadAll();
    // Polling toutes les 30 secondes
    _pollingTimer = Timer.periodic(const Duration(seconds: 30), (_) => _loadAll());
  }

  @override
  void dispose() {
    _pollingTimer?.cancel();
    super.dispose();
  }

  Future<void> _loadAll() async {
    await Future.wait([_loadAlerts(), _loadCenters()]);
  }

  Future<void> _loadAlerts() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final jwt = prefs.getString('jwt_token');
      if (jwt == null) return;

      final response = await http.get(
        Uri.parse('${AuthService.baseUrl}/admin/collection-points/alerts?limit=50'),
        headers: {'Authorization': 'Bearer $jwt'},
      );
      final countRes = await http.get(
        Uri.parse('${AuthService.baseUrl}/admin/collection-points/alerts/unread-count'),
        headers: {'Authorization': 'Bearer $jwt'},
      );

      if (!mounted) return;
      if (response.statusCode == 200) {
        final data = json.decode(utf8.decode(response.bodyBytes)) as List;
        final count = countRes.statusCode == 200
            ? (json.decode(countRes.body)['count'] ?? 0) as int
            : 0;
        setState(() {
          _alerts = data.cast<Map<String, dynamic>>();
          _unreadCount = count;
          _loadingAlerts = false;
        });
      } else {
        setState(() => _loadingAlerts = false);
      }
    } catch (_) {
      if (mounted) setState(() => _loadingAlerts = false);
    }
  }

  Future<void> _loadCenters() async {
    try {
      final response = await http.get(
        Uri.parse('${AuthService.baseUrl}/collection-points'),
      );
      if (!mounted) return;
      if (response.statusCode == 200) {
        final data = json.decode(utf8.decode(response.bodyBytes)) as List;
        setState(() {
          _centers = data.cast<Map<String, dynamic>>();
          _loadingCenters = false;
        });
      } else {
        setState(() => _loadingCenters = false);
      }
    } catch (_) {
      if (mounted) setState(() => _loadingCenters = false);
    }
  }

  Future<void> _markAllRead() async {
    if (_markingRead) return;
    setState(() => _markingRead = true);
    try {
      final prefs = await SharedPreferences.getInstance();
      final jwt = prefs.getString('jwt_token');
      if (jwt == null) return;
      await http.put(
        Uri.parse('${AuthService.baseUrl}/admin/collection-points/alerts/read-all'),
        headers: {'Authorization': 'Bearer $jwt'},
      );
      await _loadAlerts();
    } catch (_) {}
    if (mounted) setState(() => _markingRead = false);
  }

  String _timeAgo(String? isoDate) {
    if (isoDate == null) return '';
    try {
      final dt = DateTime.parse(isoDate).toLocal();
      final diff = DateTime.now().difference(dt);
      if (diff.inMinutes < 1) return 'À l\'instant';
      if (diff.inMinutes < 60) return 'Il y a ${diff.inMinutes} min';
      if (diff.inHours < 24) return 'Il y a ${diff.inHours}h';
      return 'Il y a ${diff.inDays}j';
    } catch (_) {
      return '';
    }
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);

    final criticalCenters = _centers
        .where((c) => (c['status'] ?? '') == 'saturé' || (c['status'] ?? '') == 'maintenance')
        .toList();
    final satureCenters = _centers.where((c) => (c['status'] ?? '') == 'saturé').toList();
    final maintenanceCenters = _centers.where((c) => (c['status'] ?? '') == 'maintenance').toList();

    return CustomScrollView(
      physics: const BouncingScrollPhysics(),
      slivers: [
        // ── AppBar ─────────────────────────────────────────────────────────
        SliverAppBar(
          expandedHeight: 220,
          floating: false,
          pinned: true,
          backgroundColor: const Color(0xFF0D1B2A),
          elevation: 0,
          flexibleSpace: FlexibleSpaceBar(
            collapseMode: CollapseMode.pin,
            background: _buildHeader(criticalCenters.length),
          ),
          title: Row(children: [
            Container(
              padding: const EdgeInsets.all(7),
              decoration: BoxDecoration(
                color: AppTheme.primaryGreen,
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Icon(Icons.location_on_rounded, color: Colors.white, size: 16),
            ),
            const SizedBox(width: 10),
            Text('Supervision des Points',
                style: GoogleFonts.outfit(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 15)),
            const Spacer(),
            if (_unreadCount > 0)
              _buildBadge(_unreadCount),
          ]),
        ),

        SliverPadding(
          padding: const EdgeInsets.all(20),
          sliver: SliverList(
            delegate: SliverChildListDelegate([
              // ── Résumé rapide ───────────────────────────────────────────
              _buildQuickStats(satureCenters.length, maintenanceCenters.length, _centers.length),
              const SizedBox(height: 28),

              // ── Bannière critique ───────────────────────────────────────
              if (criticalCenters.isNotEmpty) ...[
                _buildCriticalBanner(criticalCenters),
                const SizedBox(height: 28),
              ],

              // ── Alertes ─────────────────────────────────────────────────
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(7),
                    decoration: BoxDecoration(
                      color: Colors.red.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(Icons.notifications_active_rounded, color: Colors.red, size: 16),
                  ),
                  const SizedBox(width: 10),
                  Text('ALERTES EN TEMPS RÉEL',
                      style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.w900, letterSpacing: 1.5, color: AppTheme.textMuted)),
                  const Spacer(),
                  if (_unreadCount > 0)
                    GestureDetector(
                      onTap: _markAllRead,
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                        decoration: BoxDecoration(
                          color: AppTheme.primaryGreen.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: _markingRead
                            ? const SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2, color: AppTheme.primaryGreen))
                            : Text('Tout lire',
                                style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.w700, color: AppTheme.primaryGreen)),
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 16),

              if (_loadingAlerts)
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 32),
                  child: Center(child: CircularProgressIndicator(color: AppTheme.primaryGreen)),
                )
              else if (_alerts.isEmpty)
                _buildEmptyAlerts()
              else
                ..._alerts.map((alert) => _buildAlertCard(alert)).toList(),

              const SizedBox(height: 28),

              // ── Centres en temps réel ───────────────────────────────────
              Row(children: [
                Container(
                  padding: const EdgeInsets.all(7),
                  decoration: BoxDecoration(
                    color: AppTheme.primaryGreen.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(Icons.place_rounded, color: AppTheme.primaryGreen, size: 16),
                ),
                const SizedBox(width: 10),
                Text('ÉTAT DES CENTRES',
                    style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.w900, letterSpacing: 1.5, color: AppTheme.textMuted)),
              ]),
              const SizedBox(height: 16),

              if (_loadingCenters)
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 24),
                  child: Center(child: CircularProgressIndicator(color: AppTheme.primaryGreen)),
                )
              else
                ..._centers.map((c) => _buildCenterCard(c)).toList(),

              const SizedBox(height: 28),

              // ── Bouton intervention ─────────────────────────────────────
              Container(
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFF0D1B2A), Color(0xFF0F3460)],
                  ),
                  borderRadius: BorderRadius.circular(20),
                  boxShadow: AppTheme.premiumShadow,
                ),
                child: Material(
                  color: Colors.transparent,
                  child: InkWell(
                    onTap: () {},
                    borderRadius: BorderRadius.circular(20),
                    child: Padding(
                      padding: const EdgeInsets.all(20),
                      child: Row(children: [
                        const Icon(Icons.engineering_rounded, color: Colors.white, size: 24),
                        const SizedBox(width: 16),
                        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                          Text('PLANIFIER UNE INTERVENTION',
                              style: GoogleFonts.outfit(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 13, letterSpacing: 0.5)),
                          Text('Assigner une équipe à un centre critique',
                              style: GoogleFonts.inter(color: Colors.white54, fontSize: 11)),
                        ])),
                        const Icon(Icons.arrow_forward_ios_rounded, color: Colors.white38, size: 14),
                      ]),
                    ),
                  ),
                ),
              ).animate().fadeIn(delay: 300.ms),

              const SizedBox(height: 100),
            ]),
          ),
        ),
      ],
    );
  }

  // ── Header animé ────────────────────────────────────────────────────────────
  Widget _buildHeader(int criticalCount) {
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [Color(0xFF0A1628), Color(0xFF0D2137), Color(0xFF0F3460)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      child: Stack(children: [
        Positioned(right: -60, top: -60, child: Container(
          width: 240, height: 240,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            gradient: RadialGradient(colors: [AppTheme.primaryGreen.withOpacity(0.12), Colors.transparent]),
          ),
        )),
        Positioned(left: 0, top: 0, bottom: 0, child: Container(
          width: 3,
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              colors: [Colors.transparent, AppTheme.primaryGreen, Colors.transparent],
              begin: Alignment.topCenter, end: Alignment.bottomCenter,
            ),
          ),
        )),
        SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(22, 56, 22, 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                RichText(text: TextSpan(
                  style: GoogleFonts.outfit(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 22, height: 1.15),
                  children: [
                    const TextSpan(text: 'Supervision des '),
                    TextSpan(text: 'Centres de Tri',
                      style: TextStyle(
                        foreground: Paint()..shader = const LinearGradient(
                          colors: [Color(0xFF16DB93), Color(0xFF00B4D8)],
                        ).createShader(const Rect.fromLTWH(0, 0, 200, 28)),
                      )),
                  ],
                )),
                const SizedBox(height: 12),
                Row(children: [
                  _pill(Icons.sensors, 'IoT Actif', AppTheme.primaryGreen.withOpacity(0.2), AppTheme.primaryGreen),
                  const SizedBox(width: 8),
                  if (criticalCount > 0)
                    _pill(Icons.warning_amber_rounded, '$criticalCount alerte(s)', Colors.red.withOpacity(0.2), Colors.red)
                  else
                    _pill(Icons.check_circle_outline, 'Tout normal', Colors.green.withOpacity(0.2), Colors.green),
                ]),
              ],
            ),
          ),
        ),
      ]),
    );
  }

  Widget _pill(IconData icon, String label, Color bg, Color fg) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
    decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(20)),
    child: Row(mainAxisSize: MainAxisSize.min, children: [
      Icon(icon, size: 10, color: fg),
      const SizedBox(width: 5),
      Text(label, style: GoogleFonts.inter(color: fg, fontSize: 10, fontWeight: FontWeight.w600)),
    ]),
  );

  Widget _buildBadge(int count) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
    decoration: BoxDecoration(color: Colors.red, borderRadius: BorderRadius.circular(20)),
    child: Text('$count',
        style: GoogleFonts.outfit(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 11)),
  ).animate(onPlay: (c) => c.repeat()).shimmer(duration: 2.seconds, color: Colors.white30);

  // ── Résumé ──────────────────────────────────────────────────────────────────
  Widget _buildQuickStats(int sature, int maintenance, int total) {
    return Row(children: [
      _statCard('$total', 'Centres', Icons.place_rounded, Colors.blue),
      const SizedBox(width: 12),
      _statCard('$sature', 'Saturés', Icons.warning_rounded, Colors.red),
      const SizedBox(width: 12),
      _statCard('$maintenance', 'Maint.', Icons.build_rounded, Colors.orange),
    ].map((w) => Expanded(child: w)).toList());
  }

  Widget _statCard(String val, String label, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: AppTheme.tightShadow,
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(color: color.withOpacity(0.1), borderRadius: BorderRadius.circular(10)),
          child: Icon(icon, color: color, size: 16),
        ),
        const SizedBox(height: 10),
        Text(val, style: GoogleFonts.outfit(fontWeight: FontWeight.w900, fontSize: 20, color: AppTheme.deepSlate)),
        Text(label, style: GoogleFonts.inter(fontSize: 10, color: AppTheme.textMuted, fontWeight: FontWeight.w600)),
      ]),
    ).animate().fadeIn().slideY(begin: 0.2);
  }

  // ── Bannière critique ────────────────────────────────────────────────────────
  Widget _buildCriticalBanner(List<Map<String, dynamic>> criticalCenters) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [Colors.red.shade700, Colors.red.shade900],
          begin: Alignment.topLeft, end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [BoxShadow(color: Colors.red.withOpacity(0.3), blurRadius: 20, offset: const Offset(0, 8))],
      ),
      child: Row(children: [
        Animate(
          onPlay: (c) => c.repeat(),
          effects: const [ShimmerEffect(duration: Duration(seconds: 2), color: Colors.white24)],
          child: const Icon(Icons.warning_amber_rounded, color: Colors.white, size: 32),
        ),
        const SizedBox(width: 16),
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('${criticalCenters.length} Centre(s) Nécessitent une Attention',
              style: GoogleFonts.outfit(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 13)),
          const SizedBox(height: 4),
          Text(criticalCenters.map((c) => c['name'] ?? '').join(' • '),
              style: GoogleFonts.inter(color: Colors.white70, fontSize: 11)),
        ])),
      ]),
    ).animate().fadeIn().shake(hz: 1, curve: Curves.easeInOut);
  }

  // ── Carte alerte ─────────────────────────────────────────────────────────────
  Widget _buildAlertCard(Map<String, dynamic> alert) {
    final isSature = (alert['title'] ?? '').toString().contains('Saturé');
    final isRead = alert['is_read'] == true;
    final color = isSature ? Colors.red : Colors.orange;
    final icon = isSature ? Icons.error_rounded : Icons.build_circle_rounded;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: isRead ? Colors.white : color.withOpacity(0.04),
        borderRadius: BorderRadius.circular(20),
        boxShadow: AppTheme.tightShadow,
        border: Border.all(
          color: isRead ? Colors.grey.shade100 : color.withOpacity(0.25),
          width: isRead ? 1 : 1.5,
        ),
      ),
      child: Row(children: [
        Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(color: color.withOpacity(0.1), shape: BoxShape.circle),
          child: Icon(icon, color: color, size: 20),
        ),
        const SizedBox(width: 14),
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            Expanded(
              child: Text(alert['title'] ?? '',
                  style: GoogleFonts.outfit(
                    fontWeight: FontWeight.bold, fontSize: 13,
                    color: isRead ? AppTheme.textMuted : AppTheme.deepSlate,
                  )),
            ),
            if (!isRead)
              Container(
                width: 8, height: 8,
                decoration: BoxDecoration(color: color, shape: BoxShape.circle),
              ),
          ]),
          const SizedBox(height: 4),
          Text(alert['body'] ?? '',
              style: GoogleFonts.inter(fontSize: 11, color: AppTheme.textMuted, height: 1.4)),
          const SizedBox(height: 6),
          Text(_timeAgo(alert['created_at']),
              style: GoogleFonts.inter(fontSize: 10, color: AppTheme.textMuted.withOpacity(0.7), fontWeight: FontWeight.w600)),
        ])),
      ]),
    ).animate().fadeIn().slideX(begin: 0.08);
  }

  Widget _buildEmptyAlerts() {
    return Container(
      padding: const EdgeInsets.all(40),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: AppTheme.tightShadow,
      ),
      child: Column(children: [
        Icon(Icons.check_circle_outline_rounded, size: 48, color: AppTheme.primaryGreen.withOpacity(0.5)),
        const SizedBox(height: 16),
        Text('Aucune alerte active', style: GoogleFonts.outfit(fontWeight: FontWeight.bold, fontSize: 15, color: AppTheme.deepSlate)),
        const SizedBox(height: 4),
        Text('Tous les centres fonctionnent normalement', style: GoogleFonts.inter(fontSize: 12, color: AppTheme.textMuted)),
      ]),
    );
  }

  // ── Carte centre ─────────────────────────────────────────────────────────────
  Widget _buildCenterCard(Map<String, dynamic> center) {
    final status = (center['status'] ?? 'disponible').toString();
    final loadLevel = double.tryParse(center['load_level']?.toString() ?? '0') ?? 0.0;

    Color statusColor;
    IconData statusIcon;
    String statusLabel;

    switch (status) {
      case 'saturé':
        statusColor = Colors.red;
        statusIcon = Icons.error_rounded;
        statusLabel = 'SATURÉ';
        break;
      case 'maintenance':
        statusColor = Colors.orange;
        statusIcon = Icons.build_rounded;
        statusLabel = 'MAINTENANCE';
        break;
      default:
        statusColor = AppTheme.primaryGreen;
        statusIcon = Icons.check_circle_rounded;
        statusLabel = 'DISPONIBLE';
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: AppTheme.tightShadow,
        border: Border.all(
          color: status == 'disponible' ? Colors.grey.shade100 : statusColor.withOpacity(0.2),
        ),
      ),
      child: Column(children: [
        Row(children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(color: statusColor.withOpacity(0.1), shape: BoxShape.circle),
            child: Icon(statusIcon, color: statusColor, size: 18),
          ),
          const SizedBox(width: 14),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(center['name'] ?? '',
                style: GoogleFonts.outfit(fontWeight: FontWeight.bold, fontSize: 14, color: AppTheme.deepSlate)),
            Text(center['address'] ?? '',
                style: GoogleFonts.inter(fontSize: 11, color: AppTheme.textMuted),
                maxLines: 1, overflow: TextOverflow.ellipsis),
          ])),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
            decoration: BoxDecoration(
              color: statusColor.withOpacity(0.1),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Text(statusLabel,
                style: GoogleFonts.inter(color: statusColor, fontSize: 9, fontWeight: FontWeight.w900, letterSpacing: 0.5)),
          ),
        ]),
        const SizedBox(height: 14),
        Row(children: [
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
              Text('Taux de remplissage',
                  style: GoogleFonts.inter(fontSize: 10, color: AppTheme.textMuted, fontWeight: FontWeight.w600)),
              Text('${(loadLevel * 100).toStringAsFixed(0)}%',
                  style: GoogleFonts.outfit(fontSize: 12, fontWeight: FontWeight.w900, color: statusColor)),
            ]),
            const SizedBox(height: 6),
            ClipRRect(
              borderRadius: BorderRadius.circular(6),
              child: LinearProgressIndicator(
                value: loadLevel.clamp(0.0, 1.0),
                minHeight: 7,
                color: loadLevel > 0.85 ? Colors.red : loadLevel > 0.6 ? Colors.orange : AppTheme.primaryGreen,
                backgroundColor: Colors.grey.shade100,
              ),
            ),
          ])),
        ]),
      ]),
    ).animate().fadeIn(delay: 50.ms).slideX(begin: 0.05);
  }
}
