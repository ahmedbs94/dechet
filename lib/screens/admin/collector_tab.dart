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
import '../../services/l10n_service.dart';
import '../../services/messaging_service.dart';
import '../messaging/messaging_screen.dart';

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
  List<Map<String, dynamic>> _missions = [];
  int _unreadCount = 0;
  int _unreadMessages = 0;
  bool _loadingAlerts = true;
  bool _loadingCenters = true;
  bool _loadingMissions = true;
  bool _markingRead = false;
  bool _showAlerts = true;
  bool _showAllAlerts = false;
  bool _showMissions = true;

  @override
  void initState() {
    super.initState();
    L10n.addListener(_onLocaleChange);
    _loadAll();
    _loadUnreadMessages();
    _pollingTimer = Timer.periodic(const Duration(seconds: 30), (_) {
      _loadAll();
      _loadUnreadMessages();
    });
  }

  void _onLocaleChange() {
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    L10n.removeListener(_onLocaleChange);
    _pollingTimer?.cancel();
    super.dispose();
  }

  Future<void> _loadAll() async {
    await Future.wait([_loadAlerts(), _loadCenters(), _loadMissions()]);
  }

  Future<void> _loadMissions() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final jwt = prefs.getString('jwt_token');
      if (jwt == null) { if (mounted) setState(() => _loadingMissions = false); return; }
      final resp = await http.get(
        Uri.parse('${AuthService.baseUrl}/intercommunality/my-assignments'),
        headers: {'Authorization': 'Bearer $jwt'},
      );
      if (!mounted) return;
      if (resp.statusCode == 200) {
        final data = json.decode(utf8.decode(resp.bodyBytes)) as List;
        setState(() {
          _missions = data.cast<Map<String, dynamic>>();
          _loadingMissions = false;
        });
      } else {
        setState(() => _loadingMissions = false);
      }
    } catch (_) {
      if (mounted) setState(() => _loadingMissions = false);
    }
  }

  Future<void> _loadUnreadMessages() async {
    final count = await MessagingService.getUnreadCount();
    if (mounted) setState(() => _unreadMessages = count);
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

  String _t(String fr, String ar) => L10n.isArabic ? ar : fr;

  String _timeAgo(String? isoDate) {
    if (isoDate == null) return '';
    try {
      final dt = DateTime.parse(isoDate).toLocal();
      final diff = DateTime.now().difference(dt);
      if (diff.inMinutes < 1) return _t('À l\'instant', 'الآن');
      if (diff.inMinutes < 60) return _t('Il y a ${diff.inMinutes} min', 'منذ ${diff.inMinutes} دقيقة');
      if (diff.inHours < 24) return _t('Il y a ${diff.inHours}h', 'منذ ${diff.inHours} ساعة');
      return _t('Il y a ${diff.inDays}j', 'منذ ${diff.inDays} يوم');
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

    return RefreshIndicator(
      color: AppTheme.primaryGreen,
      backgroundColor: Theme.of(context).colorScheme.surface,
      onRefresh: _loadAll,
      child: CustomScrollView(
        physics: const AlwaysScrollableScrollPhysics(parent: BouncingScrollPhysics()),
        slivers: [
        // ── AppBar ─────────────────────────────────────────────────────────
        SliverAppBar(
          automaticallyImplyLeading: false,
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
            Text(_t('Logistique Temps Réel','اللوجستيك الفوري'),
                style: GoogleFonts.outfit(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 15)),
            const Spacer(),
            if (_unreadCount > 0) _buildBadge(_unreadCount),
            const SizedBox(width: 8),
            _buildMessagesButton(),
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

              // ── Mes Missions (assignées par l'intercommunalité) ──────────
              _buildMissionsSection(),
              const SizedBox(height: 28),

              // ── Résumé flux ─────────────────────────────────────────────
              _buildFluxStats(satureCenters.length, maintenanceCenters.length, _centers.length),
              const SizedBox(height: 28),

              // ── Alertes ─────────────────────────────────────────────────
              Material(
                color: Colors.transparent,
                child: InkWell(
                  onTap: () => setState(() => _showAlerts = !_showAlerts),
                  borderRadius: BorderRadius.circular(12),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 8.0, horizontal: 4.0),
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
                      Text(_t('NOTIFICATIONS CENTRES','إشعارات المراكز'),
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
                ),
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
                                Text(_t('Tout marquer comme lu','تحديد الكل كمقروء'),
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
                else ...[
                  ...(_showAllAlerts ? _alerts : _alerts.take(8)).map((a) => _buildAlertCard(a)).toList(),
                  if (_alerts.length > 8)
                    Center(
                      child: TextButton.icon(
                        onPressed: () => setState(() => _showAllAlerts = !_showAllAlerts),
                        icon: Icon(_showAllAlerts ? Icons.keyboard_arrow_up_rounded : Icons.keyboard_arrow_down_rounded, color: AppTheme.primaryGreen),
                        label: Text(
                          _showAllAlerts 
                            ? _t('Voir moins', 'عرض أقل') 
                            : '${_t('Voir tout', 'عرض الكل')} (${_alerts.length})',
                          style: GoogleFonts.outfit(fontWeight: FontWeight.bold, color: AppTheme.primaryGreen),
                        ),
                      ),
                    ),
                ],
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
                Text(_t('ORIENTATION DES FLUX (TONNAGE)','توجيه التدفق (بالطن)'),
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

              // ── Manifeste ──────────────────────────────────────────────
              Animate(
                onPlay: (c) => c.repeat(),
                effects: const [ShimmerEffect(duration: Duration(seconds: 3))],
                child: ElevatedButton.icon(
                  onPressed: () {
                    showModalBottomSheet(
                      context: context,
                      backgroundColor: Theme.of(context).colorScheme.surface,
                      shape: const RoundedRectangleBorder(
                        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
                      ),
                      builder: (context) {
                        final toCollect = _centers.where((c) => c['status'] == 'saturé').toList();
                        return SafeArea(
                          child: Padding(
                            padding: const EdgeInsets.all(24),
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  _t('Manifeste de Transport', 'بيان النقل'),
                                  style: GoogleFonts.outfit(fontWeight: FontWeight.bold, fontSize: 18),
                                ),
                                const SizedBox(height: 8),
                                Text(
                                  _t(
                                    'Centres de tri saturés à collecter en priorité :',
                                    'مراكز الفرز الممتلئة المطلوب جمعها كأولوية:'
                                  ),
                                  style: GoogleFonts.inter(color: AppTheme.textMuted, fontSize: 12),
                                ),
                                const SizedBox(height: 16),
                                if (toCollect.isEmpty)
                                  Padding(
                                    padding: const EdgeInsets.symmetric(vertical: 20),
                                    child: Center(
                                      child: Text(
                                        _t('Aucun centre saturé à collecter.', 'لا توجد مراكز ممتلئة للجمع.'),
                                        style: GoogleFonts.inter(fontStyle: FontStyle.italic, color: AppTheme.textMuted),
                                      ),
                                    ),
                                  )
                                else
                                  ConstrainedBox(
                                    constraints: const BoxConstraints(maxHeight: 200),
                                    child: ListView.builder(
                                      shrinkWrap: true,
                                      itemCount: toCollect.length,
                                      itemBuilder: (context, idx) {
                                        final c = toCollect[idx];
                                        return ListTile(
                                          leading: const Icon(Icons.error_rounded, color: Colors.red),
                                          title: Text(c['name'] ?? '', style: GoogleFonts.outfit(fontWeight: FontWeight.bold)),
                                          subtitle: Text(c['address'] ?? '', style: GoogleFonts.inter(fontSize: 11)),
                                        );
                                      },
                                    ),
                                  ),
                                const SizedBox(height: 16),
                                Row(
                                  children: [
                                    Expanded(
                                      child: TextButton(
                                        onPressed: () => Navigator.pop(context),
                                        child: Text(
                                          _t('Fermer', 'إغلاق'),
                                          style: GoogleFonts.outfit(fontWeight: FontWeight.bold, color: AppTheme.textMuted),
                                        ),
                                      ),
                                    ),
                                    const SizedBox(width: 12),
                                    Expanded(
                                      child: ElevatedButton.icon(
                                        onPressed: () {
                                          Navigator.pop(context);
                                          ScaffoldMessenger.of(context).showSnackBar(
                                            SnackBar(
                                              content: Text(_t(
                                                'Manifeste exporté avec succès (Simulation)',
                                                'تم تصدير البيان بنجاح (محاكاة)'
                                              )),
                                              behavior: SnackBarBehavior.floating,
                                            ),
                                          );
                                        },
                                        icon: const Icon(Icons.share_rounded),
                                        label: Text(_t('Exporter', 'تصدير')),
                                        style: ElevatedButton.styleFrom(
                                          backgroundColor: AppTheme.primaryGreen,
                                          foregroundColor: Colors.white,
                                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                        );
                      },
                    );
                  },
                  icon: const Icon(Icons.file_present_rounded),
                  label: Text(_t('GÉNÉRER LE MANIFESTE DE TRANSPORT','إنشاء بيان النقل')),
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
    ),
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
                    TextSpan(text: L10n.isArabic ? 'اللوجستيك ' : 'Logistique '),
                    TextSpan(text: L10n.isArabic ? 'الفوري' : 'Temps Réel',
                      style: TextStyle(
                        foreground: Paint()..shader = const LinearGradient(
                          colors: [Color(0xFF16DB93), Color(0xFF00B4D8)],
                        ).createShader(const Rect.fromLTWH(0, 0, 180, 28)),
                      )),
                  ],
                )),
                const SizedBox(height: 12),
                Row(children: [
                   _pill(FontAwesomeIcons.truckFast, _t('Tour Actif','الجولة نشطة'), AppTheme.primaryGreen.withOpacity(0.2), AppTheme.primaryGreen),
                   const SizedBox(width: 8),
                   if (sature > 0 || maintenance > 0)
                     _pill(Icons.warning_amber_rounded, '${sature + maintenance} ${_t('alerte(s)','تنبيه')}',
                         Colors.red.withOpacity(0.2), Colors.red)
                   else
                     _pill(Icons.check_circle_outline, _t('Flux normal','تدفق طبيعي'), Colors.green.withOpacity(0.2), Colors.green),
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

  Widget _buildMessagesButton() {
    return Stack(
      clipBehavior: Clip.none,
      children: [
        GestureDetector(
          onTap: () => Navigator.push(context,
            MaterialPageRoute(builder: (_) => const MessagingScreen())),
          child: Container(
            padding: const EdgeInsets.all(7),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.12),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: Colors.white24),
            ),
            child: const Icon(Icons.forum_rounded, color: Colors.white, size: 18),
          ),
        ),
        if (_unreadMessages > 0)
          Positioned(
            top: -4, right: -4,
            child: Container(
              width: 16, height: 16,
              decoration: const BoxDecoration(
                color: AppTheme.primaryGreen, shape: BoxShape.circle),
              child: Center(
                child: Text('$_unreadMessages',
                  style: const TextStyle(color: Colors.white, fontSize: 9,
                    fontWeight: FontWeight.w900)),
              ),
            ),
          ),
      ],
    );
  }

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
            effects: const [ShimmerEffect(duration: Duration(seconds: 2), color: Colors.white24)],
            child: const Icon(Icons.warning_amber_rounded, color: Colors.white, size: 26),
          ),
          const SizedBox(width: 12),
          Expanded(child: Text(
            L10n.isArabic ? '$count مركز تحتاج تدخلاً' : '$count Centre(s) Requièrent une Intervention',
            style: GoogleFonts.outfit(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 13),
          )),
        ]),
        if (sature.isNotEmpty) ...[
          const SizedBox(height: 10),
          _urgentRow(Icons.error_rounded, _t('Saturés:','ممتلئة:'), sature.map((c) => c['name'] ?? '').join(', ')),
        ],
        if (maintenance.isNotEmpty) ...[
          const SizedBox(height: 6),
          _urgentRow(Icons.build_rounded, _t('Maintenance:','صيانة:'), maintenance.map((c) => c['name'] ?? '').join(', ')),
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

  // ── Stats flux ───────────────────────────────────────────────────────────────
  Widget _buildFluxStats(int sature, int maintenance, int total) {
    final disponible = total - sature - maintenance;
    return Row(children: [
      _fluxStat('$disponible', _t('Disponibles','متاحة'), AppTheme.primaryGreen),
      const SizedBox(width: 10),
      _fluxStat('$sature', _t('Saturés','ممتلئة'), Colors.red),
      const SizedBox(width: 10),
      _fluxStat('$maintenance', _t('Maintenance','صيانة'), Colors.orange),
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
        color: isRead ? Theme.of(context).colorScheme.surface : color.withOpacity(0.04),
        borderRadius: BorderRadius.circular(18),
        boxShadow: AppTheme.tightShadow,
        border: Border.all(
          color: isRead ? (Theme.of(context).brightness == Brightness.dark ? const Color(0xFF334155) : Colors.grey.shade100) : color.withOpacity(0.2),
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
      color: Theme.of(context).colorScheme.surface, borderRadius: BorderRadius.circular(18), boxShadow: AppTheme.tightShadow,
    ),
    child: Column(children: [
      Icon(Icons.notifications_none_rounded, size: 40, color: AppTheme.primaryGreen.withOpacity(0.4)),
      const SizedBox(height: 12),
      Text(_t('Aucune alerte','لا توجد تنبيهات'), style: GoogleFonts.outfit(fontWeight: FontWeight.bold, fontSize: 14, color: AppTheme.deepSlate)),
      Text(_t('Tous les centres fonctionnent normalement','جميع المراكز تعمل بشكل طبيعي'), style: GoogleFonts.inter(fontSize: 11, color: AppTheme.textMuted)),
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
        color: Theme.of(context).colorScheme.surface,
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
                color: color, backgroundColor: Theme.of(context).brightness == Brightness.dark ? const Color(0xFF1E293B) : Colors.grey.shade100,
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

  // ── Section Mes Missions ───────────────────────────────────────────────────

  static const _missionPrimary = Color(0xFF1565C0);

  Widget _buildMissionsSection() {
    final activeMissions = _missions
        .where((m) => m['status'] != 'done' && m['status'] != 'cancelled')
        .toList();
    final doneMissions = _missions
        .where((m) => m['status'] == 'done' || m['status'] == 'cancelled')
        .toList();

    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      // ── En-tête section ─────────────────────────────────────────────────
      Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () => setState(() => _showMissions = !_showMissions),
          borderRadius: BorderRadius.circular(12),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
            child: Row(children: [
              Container(
                padding: const EdgeInsets.all(7),
                decoration: BoxDecoration(
                  color: _missionPrimary.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(Icons.assignment_turned_in_rounded,
                    color: _missionPrimary, size: 16),
              ),
              const SizedBox(width: 10),
              Text(_t('MES MISSIONS', 'مهامي'),
                  style: GoogleFonts.inter(
                      fontSize: 11, fontWeight: FontWeight.w900,
                      letterSpacing: 1.5, color: AppTheme.textMuted)),
              if (activeMissions.isNotEmpty) ...[
                const SizedBox(width: 8),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                  decoration: BoxDecoration(
                      color: _missionPrimary,
                      borderRadius: BorderRadius.circular(20)),
                  child: Text('${activeMissions.length}',
                      style: GoogleFonts.outfit(
                          color: Colors.white, fontSize: 10,
                          fontWeight: FontWeight.w900)),
                ),
              ],
              const Spacer(),
              Icon(
                _showMissions
                    ? Icons.keyboard_arrow_up_rounded
                    : Icons.keyboard_arrow_down_rounded,
                color: AppTheme.textMuted, size: 20,
              ),
            ]),
          ),
        ),
      ),

      if (_showMissions) ...[
        const SizedBox(height: 16),

        if (_loadingMissions)
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 24),
            child: Center(child: CircularProgressIndicator(color: _missionPrimary)),
          )
        else if (_missions.isEmpty)
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(vertical: 32, horizontal: 20),
            decoration: BoxDecoration(
              color: Colors.grey.shade50,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: Colors.grey.shade200),
            ),
            child: Column(children: [
              Icon(Icons.inbox_rounded, size: 40, color: Colors.grey.shade400),
              const SizedBox(height: 12),
              Text(_t('Aucune mission assignée', 'لا توجد مهام مخصصة'),
                  style: GoogleFonts.outfit(
                      color: Colors.grey.shade500,
                      fontWeight: FontWeight.w600, fontSize: 14)),
              const SizedBox(height: 4),
              Text(
                _t('L\'intercommunalité vous assignera des missions ici',
                    'ستُعيَّن لك المهام من قِبل الوكالة البيئية هنا'),
                textAlign: TextAlign.center,
                style: GoogleFonts.inter(
                    color: Colors.grey.shade400, fontSize: 12),
              ),
            ]),
          )
        else ...[
          // Missions actives
          if (activeMissions.isNotEmpty) ...[
            ...activeMissions.map((m) => _buildMissionCard(m)).toList(),
          ],
          // Missions terminées (repliables)
          if (doneMissions.isNotEmpty) ...[
            const SizedBox(height: 12),
            Padding(
              padding: const EdgeInsets.only(left: 4, bottom: 8),
              child: Text(
                _t('Missions terminées / annulées', 'المهام المنجزة / الملغاة'),
                style: GoogleFonts.inter(
                    fontSize: 11, fontWeight: FontWeight.w700,
                    color: Colors.grey.shade500, letterSpacing: 0.5),
              ),
            ),
            ...doneMissions.map((m) => _buildMissionCard(m, dimmed: true)).toList(),
          ],
          // Refresh
          const SizedBox(height: 12),
          Center(
            child: TextButton.icon(
              onPressed: () => _loadMissions(),
              icon: const Icon(Icons.refresh_rounded, size: 16, color: _missionPrimary),
              label: Text(_t('Actualiser', 'تحديث'),
                  style: GoogleFonts.outfit(
                      fontWeight: FontWeight.w600, color: _missionPrimary, fontSize: 13)),
            ),
          ),
        ],
      ],
    ]);
  }

  Widget _buildMissionCard(Map<String, dynamic> m, {bool dimmed = false}) {
    final status = m['status'] as String? ?? 'pending';
    final priority = m['priority'] as String? ?? 'normale';
    final label = m['target_label'] as String?
        ?? m['zone_name'] as String?
        ?? _t('Mission sans titre', 'مهمة بدون عنوان');
    final points = m['collection_points_data'] as List<dynamic>? ?? [];
    final assigner = m['assigner_name'] as String? ?? '';
    final msg = m['mission_message'] as String? ?? '';
    final zoneColor = m['zone_color'] as String? ?? '#1565C0';
    final assignmentId = m['id'] as int? ?? 0;

    Color statusColor() {
      switch (status) {
        case 'in_progress': return Colors.orange.shade700;
        case 'done': return Colors.green.shade600;
        case 'cancelled': return Colors.red.shade400;
        default: return _missionPrimary;
      }
    }

    String statusLabel() {
      switch (status) {
        case 'pending': return _t('En attente', 'في الانتظار');
        case 'in_progress': return _t('En cours', 'جارٍ');
        case 'done': return _t('Terminée', 'منجزة');
        case 'cancelled': return _t('Annulée', 'ملغاة');
        default: return status;
      }
    }

    IconData priorityIcon() {
      switch (priority) {
        case 'urgente': return Icons.priority_high_rounded;
        case 'haute': return Icons.keyboard_double_arrow_up_rounded;
        case 'basse': return Icons.keyboard_double_arrow_down_rounded;
        default: return Icons.remove_rounded;
      }
    }

    Color priorityColor() {
      switch (priority) {
        case 'urgente': return Colors.red;
        case 'haute': return Colors.orange;
        case 'basse': return Colors.teal;
        default: return Colors.grey;
      }
    }

    Color cardColor;
    try {
      final hex = zoneColor.replaceAll('#', '');
      cardColor = Color(int.parse('FF$hex', radix: 16));
    } catch (_) {
      cardColor = _missionPrimary;
    }

    return Opacity(
      opacity: dimmed ? 0.6 : 1.0,
      child: Container(
        margin: const EdgeInsets.only(bottom: 14),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(
              color: statusColor().withOpacity(0.25), width: 1.5),
          boxShadow: [
            BoxShadow(
                color: Colors.black.withOpacity(0.05),
                blurRadius: 12, offset: const Offset(0, 4)),
          ],
        ),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          // ── En-tête carte couleur zone ─────────────────────────────────
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: cardColor.withOpacity(0.08),
              borderRadius: const BorderRadius.vertical(top: Radius.circular(18)),
            ),
            child: Row(children: [
              Container(
                width: 10, height: 10,
                decoration: BoxDecoration(
                    color: cardColor, shape: BoxShape.circle),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(label,
                    style: GoogleFonts.outfit(
                        fontWeight: FontWeight.w800,
                        fontSize: 14,
                        color: AppTheme.deepSlate),
                    overflow: TextOverflow.ellipsis),
              ),
              // Badge statut
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                    color: statusColor().withOpacity(0.12),
                    borderRadius: BorderRadius.circular(20)),
                child: Text(statusLabel(),
                    style: GoogleFonts.outfit(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        color: statusColor())),
              ),
              const SizedBox(width: 8),
              // Badge priorité
              Icon(priorityIcon(), size: 18, color: priorityColor()),
            ]),
          ),

          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 14),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              // Assigné par
              if (assigner.isNotEmpty)
                Row(children: [
                  const Icon(Icons.person_outline_rounded,
                      size: 13, color: AppTheme.textMuted),
                  const SizedBox(width: 5),
                  Text(_t('Assigné par ', 'أُسند من قِبل ') + assigner,
                      style: GoogleFonts.inter(
                          fontSize: 11, color: AppTheme.textMuted)),
                ]),
              if (assigner.isNotEmpty) const SizedBox(height: 8),

              // Message de mission
              if (msg.isNotEmpty) ...[
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: Colors.blue.shade50,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: Colors.blue.shade100),
                  ),
                  child: Text(msg,
                      style: GoogleFonts.inter(
                          fontSize: 12, color: Colors.blue.shade700)),
                ),
                const SizedBox(height: 12),
              ],

              // Liste des centres de tri
              if (points.isNotEmpty) ...[
                Text(
                  '${points.length} ${_t('centre(s) de tri', 'مركز (مراكز) فرز')}',
                  style: GoogleFonts.outfit(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: AppTheme.deepSlate),
                ),
                const SizedBox(height: 8),
                ...points.take(3).map((p) {
                  final pt = p as Map<String, dynamic>;
                  final ptStatus = pt['status'] as String? ?? 'disponible';
                  Color ptColor() {
                    switch (ptStatus) {
                      case 'saturé': return Colors.red.shade400;
                      case 'maintenance': return Colors.orange.shade400;
                      default: return Colors.green.shade400;
                    }
                  }
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 5),
                    child: Row(children: [
                      Container(
                        width: 8, height: 8,
                        decoration: BoxDecoration(
                            color: ptColor(), shape: BoxShape.circle),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          pt['name'] as String? ?? '',
                          style: GoogleFonts.inter(
                              fontSize: 12, color: AppTheme.deepSlate),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      Text(ptStatus,
                          style: GoogleFonts.inter(
                              fontSize: 10,
                              color: ptColor(),
                              fontWeight: FontWeight.w600)),
                    ]),
                  );
                }).toList(),
                if (points.length > 3)
                  Padding(
                    padding: const EdgeInsets.only(top: 2),
                    child: Text(
                      '+ ${points.length - 3} ${_t('autres', 'آخرين')}',
                      style: GoogleFonts.inter(
                          fontSize: 11, color: AppTheme.textMuted),
                    ),
                  ),
                const SizedBox(height: 14),
              ],

              // Bouton Ouvrir la carte
              if (points.isNotEmpty && status != 'cancelled')
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: () {
                      Navigator.of(context).pushNamed(
                        '/mission-map',
                        arguments: {'assignment_id': assignmentId},
                      );
                    },
                    icon: const Icon(Icons.map_rounded, size: 18,
                        color: Colors.white),
                    label: Text(
                      _t('Ouvrir la carte des centres', 'فتح خريطة المراكز'),
                      style: GoogleFonts.outfit(
                          fontWeight: FontWeight.w700,
                          fontSize: 13,
                          color: Colors.white),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: status == 'done'
                          ? Colors.green.shade600
                          : _missionPrimary,
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12)),
                      padding: const EdgeInsets.symmetric(vertical: 13),
                      elevation: 0,
                    ),
                  ),
                )
              else if (points.isEmpty && status != 'cancelled')
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(vertical: 10),
                  decoration: BoxDecoration(
                    color: Colors.grey.shade100,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Center(
                    child: Text(
                      _t('Aucun centre de tri sur cette mission',
                          'لا توجد مراكز فرز في هذه المهمة'),
                      style: GoogleFonts.inter(
                          fontSize: 11, color: Colors.grey.shade500),
                    ),
                  ),
                ),
            ]),
          ),
        ]),
      ).animate().fadeIn(duration: 350.ms).slideY(begin: 0.08, end: 0),
    );
  }
}

// ── Widgets helper ────────────────────────────────────────────────────────────

