import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import '../../theme/app_theme.dart';
import '../../services/auth_service.dart';

class CollectorTab extends StatefulWidget {
  const CollectorTab({Key? key}) : super(key: key);

  @override
  State<CollectorTab> createState() => _CollectorTabState();
}

class _CollectorTabState extends State<CollectorTab>
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
  bool _showAlerts = true;

  @override
  void initState() {
    super.initState();
    _loadAll();
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
        Uri.parse('${AuthService.baseUrl}/admin/collection-points/alerts?limit=30'),
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
        // Trier: saturés en premier, puis maintenance, puis disponibles
        final sorted = data.cast<Map<String, dynamic>>();
        sorted.sort((a, b) {
          const order = {'saturé': 0, 'maintenance': 1, 'disponible': 2};
          final sa = order[a['status'] ?? 'disponible'] ?? 2;
          final sb = order[b['status'] ?? 'disponible'] ?? 2;
          return sa.compareTo(sb);
        });
        setState(() {
          _centers = sorted;
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

    final satureCenters = _centers.where((c) => c['status'] == 'saturé').toList();
    final maintenanceCenters = _centers.where((c) => c['status'] == 'maintenance').toList();
    final hasCritical = satureCenters.isNotEmpty || maintenanceCenters.isNotEmpty;

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
            background: _buildHeader(satureCenters.length, maintenanceCenters.length),
          ),
          title: Row(children: [
            Container(
              padding: const EdgeInsets.all(7),
              decoration: BoxDecoration(
                color: AppTheme.primaryGreen,
                borderRadius: BorderRadius.circular(10),
              ),
              child: const FaIcon(FontAwesomeIcons.truckFast, color: Colors.white, size: 14),
            ),
            const SizedBox(width: 10),
            Text('Logistique Temps Réel',
                style: GoogleFonts.outfit(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 15)),
            const Spacer(),
            if (_unreadCount > 0) _buildBadge(_unreadCount),
          ]),
        ),

        SliverPadding(
          padding: const EdgeInsets.all(20),
          sliver: SliverList(
            delegate: SliverChildListDelegate([
              // ── Bannière d'urgence ──────────────────────────────────────
              if (hasCritical) ...[
                _buildUrgentBanner(satureCenters, maintenanceCenters),
                const SizedBox(height: 24),
              ],

              // ── Tour actif ──────────────────────────────────────────────
              _buildActiveTourCard(),
              const SizedBox(height: 28),

              // ── Résumé flux ─────────────────────────────────────────────
              _buildFluxStats(satureCenters.length, maintenanceCenters.length, _centers.length),
              const SizedBox(height: 28),

              // ── Alertes ─────────────────────────────────────────────────
              GestureDetector(
                onTap: () => setState(() => _showAlerts = !_showAlerts),
                child: Row(children: [
                  Container(
                    padding: const EdgeInsets.all(7),
                    decoration: BoxDecoration(
                      color: (_unreadCount > 0 ? Colors.red : Colors.grey).withOpacity(0.1),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Icon(Icons.notifications_active_rounded,
                        color: _unreadCount > 0 ? Colors.red : Colors.grey, size: 16),
                  ),
                  const SizedBox(width: 10),
                  Text('NOTIFICATIONS CENTRES',
                      style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.w900,
                          letterSpacing: 1.5, color: AppTheme.textMuted)),
                  if (_unreadCount > 0) ...[
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                      decoration: BoxDecoration(color: Colors.red, borderRadius: BorderRadius.circular(20)),
                      child: Text('$_unreadCount',
                          style: GoogleFonts.outfit(color: Colors.white, fontSize: 10, fontWeight: FontWeight.w900)),
                    ),
                  ],
                  const Spacer(),
                  Icon(_showAlerts ? Icons.keyboard_arrow_up_rounded : Icons.keyboard_arrow_down_rounded,
                      color: AppTheme.textMuted, size: 20),
                ]),
              ),

              if (_showAlerts) ...[
                const SizedBox(height: 16),
                if (_unreadCount > 0)
                  Align(
                    alignment: Alignment.centerRight,
                    child: GestureDetector(
                      onTap: _markAllRead,
                      child: Container(
                        margin: const EdgeInsets.only(bottom: 12),
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
                        decoration: BoxDecoration(
                          color: AppTheme.primaryGreen.withOpacity(0.08),
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(color: AppTheme.primaryGreen.withOpacity(0.2)),
                        ),
                        child: _markingRead
                            ? const SizedBox(width: 14, height: 14,
                                child: CircularProgressIndicator(strokeWidth: 2, color: AppTheme.primaryGreen))
                            : Row(mainAxisSize: MainAxisSize.min, children: [
                                const Icon(Icons.done_all_rounded, size: 14, color: AppTheme.primaryGreen),
                                const SizedBox(width: 6),
                                Text('Tout marquer comme lu',
                                    style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.w700,
                                        color: AppTheme.primaryGreen)),
                              ]),
                      ),
                    ),
                  ),
                if (_loadingAlerts)
                  const Padding(
                    padding: EdgeInsets.symmetric(vertical: 24),
                    child: Center(child: CircularProgressIndicator(color: AppTheme.primaryGreen)),
                  )
                else if (_alerts.isEmpty)
                  _buildEmptyAlerts()
                else
                  ..._alerts.take(8).map((a) => _buildAlertCard(a)).toList(),
              ],

              const SizedBox(height: 28),

              // ── Flux par centre ─────────────────────────────────────────
              Row(children: [
                Container(
                  padding: const EdgeInsets.all(7),
                  decoration: BoxDecoration(
                    color: AppTheme.primaryGreen.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(Icons.route_rounded, color: AppTheme.primaryGreen, size: 16),
                ),
                const SizedBox(width: 10),
                Text('ORIENTATION DES FLUX (TONNAGE)',
                    style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.w900,
                        letterSpacing: 1.5, color: AppTheme.textMuted)),
              ]),
              const SizedBox(height: 16),

              if (_loadingCenters)
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 20),
                  child: Center(child: CircularProgressIndicator(color: AppTheme.primaryGreen)),
                )
              else
                ..._centers.map((c) => _buildFlowItem(c)).toList(),

              const SizedBox(height: 28),

              // ── Optimisation route ──────────────────────────────────────
              _buildRouteOptimizationCard(),
              const SizedBox(height: 28),

              // ── Manifeste ──────────────────────────────────────────────
              Animate(
                onPlay: (c) => c.repeat(),
                effects: [ShimmerEffect(duration: 3.seconds)],
                child: ElevatedButton.icon(
                  onPressed: () {},
                  icon: const Icon(Icons.file_present_rounded),
                  label: const Text('GÉNÉRER LE MANIFESTE DE TRANSPORT'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.deepSlate,
                    padding: const EdgeInsets.symmetric(vertical: 20),
                    minimumSize: const Size(double.infinity, 56),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  ),
                ),
              ),
              const SizedBox(height: 100),
            ]),
          ),
        ),
      ],
    );
  }

  // ── Header ──────────────────────────────────────────────────────────────────
  Widget _buildHeader(int sature, int maintenance) {
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [Color(0xFF0A1628), Color(0xFF0D2137), Color(0xFF0F3460)],
          begin: Alignment.topLeft, end: Alignment.bottomRight,
        ),
      ),
      child: Stack(children: [
        Positioned(right: -40, bottom: -40, child: Container(
          width: 200, height: 200,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            gradient: RadialGradient(colors: [AppTheme.primaryGreen.withOpacity(0.12), Colors.transparent]),
          ),
        )),
        Positioned(left: 0, top: 0, bottom: 0, child: Container(
          width: 3,
          decoration: BoxDecoration(
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
                    const TextSpan(text: 'Logistique '),
                    TextSpan(text: 'Temps Réel',
                      style: TextStyle(
                        foreground: Paint()..shader = const LinearGradient(
                          colors: [Color(0xFF16DB93), Color(0xFF00B4D8)],
                        ).createShader(const Rect.fromLTWH(0, 0, 180, 28)),
                      )),
                  ],
                )),
                const SizedBox(height: 12),
                Row(children: [
                  _pill(FontAwesomeIcons.truckFast, 'Tour Actif', AppTheme.primaryGreen.withOpacity(0.2), AppTheme.primaryGreen),
                  const SizedBox(width: 8),
                  if (sature > 0 || maintenance > 0)
                    _pill(Icons.warning_amber_rounded, '${sature + maintenance} alerte(s)',
                        Colors.red.withOpacity(0.2), Colors.red)
                  else
                    _pill(Icons.check_circle_outline, 'Flux normal', Colors.green.withOpacity(0.2), Colors.green),
                ]),
              ],
            ),
          ),
        ),
      ]),
    );
  }

  Widget _pill(dynamic icon, String label, Color bg, Color fg) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
    decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(20)),
    child: Row(mainAxisSize: MainAxisSize.min, children: [
      icon is IconData
          ? Icon(icon, size: 10, color: fg)
          : FaIcon(icon as dynamic, size: 10, color: fg),
      const SizedBox(width: 5),
      Text(label, style: GoogleFonts.inter(color: fg, fontSize: 10, fontWeight: FontWeight.w600)),
    ]),
  );

  Widget _buildBadge(int count) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
    decoration: BoxDecoration(color: Colors.red, borderRadius: BorderRadius.circular(20)),
    child: Text('$count', style: GoogleFonts.outfit(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 11)),
  ).animate(onPlay: (c) => c.repeat()).shimmer(duration: 2.seconds, color: Colors.white30);

  // ── Bannière urgence ─────────────────────────────────────────────────────────
  Widget _buildUrgentBanner(List<Map<String, dynamic>> sature, List<Map<String, dynamic>> maintenance) {
    final count = sature.length + maintenance.length;
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [Colors.red.shade700, Colors.red.shade900],
          begin: Alignment.topLeft, end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [BoxShadow(color: Colors.red.withOpacity(0.35), blurRadius: 20, offset: const Offset(0, 8))],
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Animate(
            onPlay: (c) => c.repeat(),
            effects: [const ShimmerEffect(duration: Duration(seconds: 2), color: Colors.white24)],
            child: const Icon(Icons.warning_amber_rounded, color: Colors.white, size: 26),
          ),
          const SizedBox(width: 12),
          Expanded(child: Text(
            '$count Centre(s) Requièrent une Intervention',
            style: GoogleFonts.outfit(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 13),
          )),
        ]),
        if (sature.isNotEmpty) ...[
          const SizedBox(height: 10),
          _urgentRow(Icons.error_rounded, 'Saturés:', sature.map((c) => c['name'] ?? '').join(', ')),
        ],
        if (maintenance.isNotEmpty) ...[
          const SizedBox(height: 6),
          _urgentRow(Icons.build_rounded, 'Maintenance:', maintenance.map((c) => c['name'] ?? '').join(', ')),
        ],
      ]),
    ).animate().fadeIn().shake(hz: 1, curve: Curves.easeInOut);
  }

  Widget _urgentRow(IconData icon, String label, String value) => Row(children: [
    Icon(icon, color: Colors.white70, size: 13),
    const SizedBox(width: 6),
    Text('$label ', style: GoogleFonts.inter(color: Colors.white60, fontSize: 11, fontWeight: FontWeight.w700)),
    Expanded(child: Text(value, style: GoogleFonts.inter(color: Colors.white, fontSize: 11), overflow: TextOverflow.ellipsis)),
  ]);

  // ── Tour actif ───────────────────────────────────────────────────────────────
  Widget _buildActiveTourCard() {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: AppTheme.deepSlate,
        borderRadius: BorderRadius.circular(AppTheme.borderRadiusLarge),
        boxShadow: AppTheme.premiumShadow,
        gradient: AppTheme.darkGradient,
      ),
      child: Column(children: [
        Row(children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(color: Colors.white.withOpacity(0.1), shape: BoxShape.circle),
            child: const FaIcon(FontAwesomeIcons.truckFront, color: AppTheme.primaryGreen, size: 24),
          ),
          const SizedBox(width: 16),
          const Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('TOUR RÉEL #TC-202',
                style: TextStyle(fontWeight: FontWeight.w900, fontSize: 13, color: Colors.white, letterSpacing: 1)),
            Text('Chauffeur : Ahmed B. • ACTIF',
                style: TextStyle(color: Colors.white60, fontSize: 11, fontWeight: FontWeight.w500)),
          ])),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(color: AppTheme.primaryGreen, borderRadius: BorderRadius.circular(30)),
            child: Text('85%',
                style: GoogleFonts.outfit(fontWeight: FontWeight.w900, color: Colors.white, fontSize: 12)),
          ),
        ]),
        const SizedBox(height: 24),
        Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: const [
          _TourStat(label: 'Vitesse', value: '45 km/h'),
          _TourStat(label: 'Arrêts', value: '18/24'),
          _TourStat(label: 'ETA', value: '14:45'),
        ]),
      ]),
    ).animate().fadeIn().slideX();
  }

  // ── Stats flux ───────────────────────────────────────────────────────────────
  Widget _buildFluxStats(int sature, int maintenance, int total) {
    final disponible = total - sature - maintenance;
    return Row(children: [
      _fluxStat('$disponible', 'Disponibles', AppTheme.primaryGreen),
      const SizedBox(width: 10),
      _fluxStat('$sature', 'Saturés', Colors.red),
      const SizedBox(width: 10),
      _fluxStat('$maintenance', 'Maintenance', Colors.orange),
    ].map((w) => Expanded(child: w)).toList());
  }

  Widget _fluxStat(String val, String label, Color color) => Container(
    padding: const EdgeInsets.all(14),
    decoration: BoxDecoration(
      color: color.withOpacity(0.06),
      borderRadius: BorderRadius.circular(16),
      border: Border.all(color: color.withOpacity(0.15)),
    ),
    child: Column(children: [
      Text(val, style: GoogleFonts.outfit(fontWeight: FontWeight.w900, fontSize: 18, color: color)),
      Text(label, style: GoogleFonts.inter(fontSize: 9, color: color.withOpacity(0.7), fontWeight: FontWeight.w700),
          textAlign: TextAlign.center),
    ]),
  );

  // ── Carte alerte ─────────────────────────────────────────────────────────────
  Widget _buildAlertCard(Map<String, dynamic> alert) {
    final isSature = (alert['title'] ?? '').toString().contains('Saturé');
    final isRead = alert['is_read'] == true;
    final color = isSature ? Colors.red : Colors.orange;
    final icon = isSature ? Icons.error_rounded : Icons.build_circle_rounded;

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isRead ? Colors.white : color.withOpacity(0.04),
        borderRadius: BorderRadius.circular(18),
        boxShadow: AppTheme.tightShadow,
        border: Border.all(
          color: isRead ? Colors.grey.shade100 : color.withOpacity(0.2),
          width: isRead ? 1 : 1.5,
        ),
      ),
      child: Row(children: [
        Container(
          padding: const EdgeInsets.all(9),
          decoration: BoxDecoration(color: color.withOpacity(0.1), shape: BoxShape.circle),
          child: Icon(icon, color: color, size: 18),
        ),
        const SizedBox(width: 12),
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            Expanded(child: Text(alert['title'] ?? '',
                style: GoogleFonts.outfit(
                  fontWeight: FontWeight.bold, fontSize: 12,
                  color: isRead ? AppTheme.textMuted : AppTheme.deepSlate,
                ))),
            if (!isRead)
              Container(width: 7, height: 7,
                  decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
          ]),
          const SizedBox(height: 3),
          Text(alert['body'] ?? '',
              style: GoogleFonts.inter(fontSize: 11, color: AppTheme.textMuted, height: 1.4),
              maxLines: 2, overflow: TextOverflow.ellipsis),
          const SizedBox(height: 5),
          Text(_timeAgo(alert['created_at']),
              style: GoogleFonts.inter(fontSize: 10, color: AppTheme.textMuted.withOpacity(0.6), fontWeight: FontWeight.w600)),
        ])),
      ]),
    ).animate().fadeIn().slideX(begin: 0.06);
  }

  Widget _buildEmptyAlerts() => Container(
    padding: const EdgeInsets.all(32),
    margin: const EdgeInsets.only(bottom: 4),
    decoration: BoxDecoration(
      color: Colors.white, borderRadius: BorderRadius.circular(18), boxShadow: AppTheme.tightShadow,
    ),
    child: Column(children: [
      Icon(Icons.notifications_none_rounded, size: 40, color: AppTheme.primaryGreen.withOpacity(0.4)),
      const SizedBox(height: 12),
      Text('Aucune alerte', style: GoogleFonts.outfit(fontWeight: FontWeight.bold, fontSize: 14, color: AppTheme.deepSlate)),
      Text('Tous les centres fonctionnent normalement', style: GoogleFonts.inter(fontSize: 11, color: AppTheme.textMuted)),
    ]),
  );

  // ── Flux par centre ──────────────────────────────────────────────────────────
  Widget _buildFlowItem(Map<String, dynamic> center) {
    final status = center['status'] ?? 'disponible';
    final loadLevel = double.tryParse(center['load_level']?.toString() ?? '0') ?? 0.0;
    final types = (center['types'] as List? ?? []).cast<String>();

    Color color;
    switch (status) {
      case 'saturé': color = Colors.red; break;
      case 'maintenance': color = Colors.orange; break;
      default: color = AppTheme.primaryGreen;
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withOpacity(status == 'disponible' ? 0.05 : 0.2)),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.03), blurRadius: 10, offset: const Offset(0, 4))],
      ),
      child: Row(children: [
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(color: color.withOpacity(0.1), shape: BoxShape.circle),
          child: Icon(
            status == 'saturé' ? Icons.error_rounded :
            status == 'maintenance' ? Icons.build_rounded :
            Icons.token_rounded,
            color: color, size: 20,
          ),
        ),
        const SizedBox(width: 14),
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(center['name'] ?? '',
              style: GoogleFonts.outfit(fontWeight: FontWeight.bold, fontSize: 14, color: AppTheme.deepSlate)),
          if (types.isNotEmpty)
            Text(types.take(3).join(' · '),
                style: const TextStyle(fontSize: 10, color: AppTheme.textMuted, fontWeight: FontWeight.w500)),
          const SizedBox(height: 8),
          Stack(children: [
            ClipRRect(borderRadius: BorderRadius.circular(6),
              child: LinearProgressIndicator(
                value: loadLevel.clamp(0.0, 1.0), minHeight: 6,
                color: color, backgroundColor: Colors.grey.shade100,
              )),
          ]),
        ])),
        const SizedBox(width: 12),
        Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
          Text('${(loadLevel * 100).toStringAsFixed(0)}%',
              style: GoogleFonts.outfit(fontWeight: FontWeight.w900, fontSize: 16, color: color)),
          Text(status.toUpperCase(),
              style: GoogleFonts.inter(fontSize: 8, color: color, fontWeight: FontWeight.w900, letterSpacing: 0.5)),
        ]),
      ]),
    );
  }

  // ── Optimisation route ───────────────────────────────────────────────────────
  Widget _buildRouteOptimizationCard() {
    return Container(
      padding: const EdgeInsets.all(28),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(AppTheme.borderRadiusLarge),
        boxShadow: AppTheme.premiumShadow,
      ),
      child: Column(children: [
        Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
          Text('Efficacité Carburant',
              style: GoogleFonts.outfit(fontWeight: FontWeight.bold, fontSize: 16)),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
                color: AppTheme.primaryGreen.withOpacity(0.1), borderRadius: BorderRadius.circular(10)),
            child: const Text('OPTIMAL',
                style: TextStyle(color: AppTheme.primaryGreen, fontWeight: FontWeight.w900, fontSize: 9)),
          ),
        ]),
        const SizedBox(height: 20),
        Stack(children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(10),
            child: LinearProgressIndicator(
                value: 0.92, minHeight: 12, color: AppTheme.primaryGreen, backgroundColor: Colors.grey.shade50),
          ),
          Animate(
            onPlay: (c) => c.repeat(),
            effects: [ShimmerEffect(duration: 2.seconds, color: Colors.white30)],
            child: Container(height: 12, width: double.infinity, color: Colors.transparent),
          ),
        ]),
        const SizedBox(height: 28),
        const Row(mainAxisAlignment: MainAxisAlignment.spaceAround, children: [
          _MiniStat(label: 'Consommation', value: '8.4L/100'),
          _MiniStat(label: 'CO2 Réduit', value: '1.2 Tons'),
        ]),
      ]),
    );
  }
}

// ── Widgets helper ────────────────────────────────────────────────────────────

class _TourStat extends StatelessWidget {
  final String label, value;
  const _TourStat({required this.label, required this.value});
  @override
  Widget build(BuildContext context) => Column(children: [
    Text(value, style: GoogleFonts.outfit(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16)),
    Text(label, style: const TextStyle(color: Colors.white54, fontSize: 10, fontWeight: FontWeight.w600, letterSpacing: 0.5)),
  ]);
}

class _MiniStat extends StatelessWidget {
  final String label, value;
  const _MiniStat({required this.label, required this.value});
  @override
  Widget build(BuildContext context) => Column(children: [
    Text(value, style: GoogleFonts.outfit(fontWeight: FontWeight.w900, fontSize: 16, color: AppTheme.deepSlate)),
    Text(label, style: const TextStyle(fontSize: 11, color: AppTheme.textMuted, fontWeight: FontWeight.bold)),
  ]);
}
