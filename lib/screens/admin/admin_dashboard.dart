import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import '../../theme/app_theme.dart';
import 'add_sorting_center_screen.dart';
import '../../services/auth_service.dart';
import '../../services/messaging_service.dart';
import '../client/profile_tab.dart';
import 'user_management_screen.dart';
import 'admin_proposals_screen.dart';
import 'admin_analytics_tab.dart';
import '../../services/l10n_service.dart';
import '../messaging/messaging_screen.dart';


class AdminDashboardScreen extends StatefulWidget {
  const AdminDashboardScreen({Key? key}) : super(key: key);

  @override
  State<AdminDashboardScreen> createState() => _AdminDashboardScreenState();
}

class _AdminDashboardScreenState extends State<AdminDashboardScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final AuthService _authService = AuthService();
  int _unreadMessages = 0;

  // Admin stats (loaded from API)

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 8, vsync: this);
    L10n.addListener(_onLocaleChange);
    _loadStats();
    _loadUnreadCount();
  }

  void _onLocaleChange() {
    if (mounted) setState(() {});
  }

  Future<void> _loadStats() async {
    await _authService.fetchAdminStats();
  }

  Future<void> _loadUnreadCount() async {
    final count = await MessagingService.getUnreadCount();
    if (mounted) setState(() => _unreadMessages = count);
  }

  @override
  void dispose() {
    L10n.removeListener(_onLocaleChange);
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      body: NestedScrollView(
        headerSliverBuilder: (context, innerBoxIsScrolled) => [
          SliverAppBar(
            automaticallyImplyLeading: false,
            expandedHeight: 200,
            floating: false,
            pinned: true,
            backgroundColor: const Color(0xFF0D1B2A),
            elevation: 0,
            title: Row(children: [
              Container(
                padding: const EdgeInsets.all(7),
                decoration: BoxDecoration(
                  color: AppTheme.primaryGreen,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(Icons.eco_rounded, color: Colors.white, size: 18),
              ),
              const SizedBox(width: 10),
              Text(L10n.tr('admin_app_bar_title'),
                style: GoogleFonts.outfit(
                  color: Colors.white, fontWeight: FontWeight.w800, fontSize: 16)),
            ]),
            flexibleSpace: FlexibleSpaceBar(
              collapseMode: CollapseMode.pin,
              background: _AdminHeader(),
            ),
            bottom: PreferredSize(
              preferredSize: const Size.fromHeight(46),
              child: Container(
                color: const Color(0xFF0D1B2A),
                child: TabBar(
                  controller: _tabController,
                  isScrollable: true,
                  labelColor: AppTheme.primaryGreen,
                  unselectedLabelColor: Colors.white38,
                  indicatorColor: AppTheme.primaryGreen,
                  indicatorWeight: 2.5,
                  indicatorPadding: const EdgeInsets.symmetric(horizontal: 2),
                  labelStyle: GoogleFonts.outfit(fontWeight: FontWeight.w800, fontSize: 12, letterSpacing: 0.8),
                  unselectedLabelStyle: GoogleFonts.outfit(fontWeight: FontWeight.w500, fontSize: 12),
                  tabs: [
                    Tab(text: L10n.tr('admin_tab_indicators')),
                    Tab(text: L10n.tr('admin_tab_moderation')),
                    Tab(text: L10n.tr('admin_tab_content')),
                    Tab(text: L10n.tr('admin_tab_proposals')),
                    Tab(text: L10n.tr('admin_tab_points')),
                    Tab(text: L10n.tr('admin_tab_users')),
                    Tab(
                      child: Row(mainAxisSize: MainAxisSize.min, children: [
                        const Text('Messages'),
                        if (_unreadMessages > 0) ...[
                          const SizedBox(width: 6),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                            decoration: BoxDecoration(
                              color: AppTheme.primaryGreen,
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Text('$_unreadMessages',
                              style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.w800)),
                          ),
                        ],
                      ]),
                    ),
                    Tab(text: L10n.tr('admin_tab_profile')),
                  ],
                ),
              ),
            ),
          ),
        ],
        body: TabBarView(
          controller: _tabController,
          children: [
            const AdminAnalyticsTab(),
            _PostsModerationTab(onStatsUpdated: _loadStats),
            _buildContentValidationTab(),
            const AdminProposalsScreen(),
            _buildPointsManagementTab(),
            const UserManagementScreen(),
            const MessagingScreen(key: ValueKey('admin_messaging')),
            const ProfileTab(),
          ],
        ),
      ),
    );
  }

  Widget _buildContentValidationTab() {
    return _TestimonialsManagementTab();
  }

  Widget _buildPointsManagementTab() {
    return _CollectionPointsManagementTab();
  }

}

// =========================================
// HEADER ANIMÉ PINTEREST
// =========================================

class _AdminHeader extends StatefulWidget {
  @override
  State<_AdminHeader> createState() => _AdminHeaderState();
}

class _AdminHeaderState extends State<_AdminHeader> with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  late Animation<double> _fade;
  late Animation<Offset> _slide;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 900));
    _fade = CurvedAnimation(parent: _ctrl, curve: Curves.easeOut);
    _slide = Tween<Offset>(begin: const Offset(0, 0.25), end: Offset.zero)
        .animate(CurvedAnimation(parent: _ctrl, curve: Curves.easeOutCubic));
    _ctrl.forward();
  }

  @override
  void dispose() { _ctrl.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    final dateStr = '${now.day}/${now.month}/${now.year}';
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [Color(0xFF0A1628), Color(0xFF0D2137), Color(0xFF0F3460)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          stops: [0.0, 0.5, 1.0],
        ),
      ),
      child: Stack(children: [
        // Grand cercle décoratif droit
        Positioned(right: -80, top: -80, child: Container(
          width: 280, height: 280,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            gradient: RadialGradient(colors: [
              const Color(0xFF16DB93).withOpacity(0.12),
              Colors.transparent,
            ]),
          ),
        )),
        // Petit cercle accent
        Positioned(right: 60, bottom: 10, child: Container(
          width: 80, height: 80,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            gradient: RadialGradient(colors: [
              Colors.blue.withOpacity(0.15),
              Colors.transparent,
            ]),
          ),
        )),
        // Ligne décorative verticale
        Positioned(left: 0, top: 0, bottom: 0, child: Container(
          width: 3,
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              colors: [Colors.transparent, AppTheme.primaryGreen, Colors.transparent],
              begin: Alignment.topCenter, end: Alignment.bottomCenter,
            ),
          ),
        )),
        // Points de grille discrets
        Positioned.fill(child: Opacity(opacity: 0.025,
          child: CustomPaint(painter: _GridPainter()))),
        // Contenu animé
        Padding(
          padding: const EdgeInsets.fromLTRB(22, 56, 22, 60),
          child: SlideTransition(
            position: _slide,
            child: FadeTransition(
              opacity: _fade,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  // Titre principal avec accent coloré
                  RichText(text: TextSpan(
                    style: GoogleFonts.outfit(
                      color: Colors.white, fontWeight: FontWeight.w900,
                      fontSize: 24, height: 1.15, letterSpacing: -0.5),
                    children: [
                      TextSpan(text: L10n.tr('admin_header_title'),
                        style: TextStyle(
                          foreground: Paint()..shader = const LinearGradient(
                            colors: [Color(0xFF16DB93), Color(0xFF00B4D8)],
                          ).createShader(const Rect.fromLTWH(0, 0, 180, 28)),
                        )),
                    ],
                  )),
                  const SizedBox(height: 8),
                  // Badges info
                  Wrap(spacing: 8, runSpacing: 6, children: [
                    _pill(Icons.calendar_today_rounded, dateStr, Colors.white24, Colors.white60),
                    _pill(Icons.circle, L10n.tr('admin_system_active'), AppTheme.primaryGreen.withOpacity(0.2),
                      AppTheme.primaryGreen),
                  ]),
                ],
              ),
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
}

class _GridPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..color = Colors.white..strokeWidth = 0.5;
    const step = 28.0;
    for (double x = 0; x < size.width; x += step) {
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), paint);
    }
    for (double y = 0; y < size.height; y += step) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y), paint);
    }
  }
  @override
  bool shouldRepaint(_) => false;
}

// =========================================
// TESTIMONIALS MANAGEMENT TAB
// =========================================

class _TestimonialsManagementTab extends StatefulWidget {
  @override
  State<_TestimonialsManagementTab> createState() => _TestimonialsManagementTabState();
}

class _TestimonialsManagementTabState extends State<_TestimonialsManagementTab> {
  final AuthService _authService = AuthService();
  List<Map<String, dynamic>> _testimonials = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadTestimonials();
  }

  Future<void> _loadTestimonials() async {
    setState(() => _isLoading = true);
    try {
      final response = await _authService.authenticatedGet(
        '${AuthService.baseUrl}/admin/testimonials',
      );
      if (response.statusCode == 200) {
        final Map<String, dynamic> data = json.decode(utf8.decode(response.bodyBytes));
        final List<dynamic> items = data['testimonials'] ?? [];
        if (mounted) setState(() { _testimonials = items.cast<Map<String, dynamic>>(); _isLoading = false; });
      } else {
        if (mounted) setState(() => _isLoading = false);
      }
    } catch (e) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _approveTestimonial(int id) async {
    final prefs = await SharedPreferences.getInstance();
    final jwt = prefs.getString('jwt_token');
    await http.put(
      Uri.parse('${AuthService.baseUrl}/admin/testimonials/$id/approve'),
      headers: {'Authorization': 'Bearer $jwt', 'Content-Type': 'application/json'},
    );
    _loadTestimonials();
  }

  Future<void> _rejectTestimonial(int id) async {
    final prefs = await SharedPreferences.getInstance();
    final jwt = prefs.getString('jwt_token');
    await http.put(
      Uri.parse('${AuthService.baseUrl}/admin/testimonials/$id/reject'),
      headers: {'Authorization': 'Bearer $jwt', 'Content-Type': 'application/json'},
    );
    _loadTestimonials();
  }

  Future<void> _toggleFeatured(int id) async {
    final prefs = await SharedPreferences.getInstance();
    final jwt = prefs.getString('jwt_token');
    await http.put(
      Uri.parse('${AuthService.baseUrl}/admin/testimonials/$id/feature'),
      headers: {'Authorization': 'Bearer $jwt', 'Content-Type': 'application/json'},
    );
    _loadTestimonials();
  }

  @override
  Widget build(BuildContext context) {
    final pending = _testimonials.where((t) => t['is_approved'] != true).toList();
    final approved = _testimonials.where((t) => t['is_approved'] == true).toList();

    return SingleChildScrollView(
      key: const PageStorageKey('admin_testimonials'),
      primary: false,
      padding: const EdgeInsets.all(24),
      physics: const BouncingScrollPhysics(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('TÉMOIGNAGES CITOYENS',
            style: GoogleFonts.outfit(fontWeight: FontWeight.w900, letterSpacing: 1.5, fontSize: 12, color: AppTheme.textMuted)),
          const SizedBox(height: 24),

          if (_isLoading)
            const Center(child: Padding(
              padding: EdgeInsets.all(40),
              child: CircularProgressIndicator(color: AppTheme.primaryGreen),
            ))
          else ...[
            // Pending
            if (pending.isNotEmpty) ...[
              Text('EN ATTENTE D\'APPROBATION (${pending.length})',
                style: GoogleFonts.outfit(fontWeight: FontWeight.w900, letterSpacing: 1, fontSize: 11, color: Colors.orange.shade800)),
              const SizedBox(height: 12),
              ...pending.map((t) => _buildTestimonialCard(t, isPending: true)),
              const SizedBox(height: 32),
            ],

            // Approved
            Text('APPROUVÉS (${approved.length})',
              style: GoogleFonts.outfit(fontWeight: FontWeight.w900, letterSpacing: 1, fontSize: 11, color: Colors.green.shade800)),
            const SizedBox(height: 12),
            if (approved.isEmpty)
              Container(
                padding: const EdgeInsets.all(40),
                child: Center(child: Text('Aucun témoignage approuvé', style: GoogleFonts.inter(color: AppTheme.textMuted))),
              )
            else
              ...approved.map((t) => _buildTestimonialCard(t, isPending: false)),
          ],
          const SizedBox(height: 100),
        ],
      ),
    );
  }

  Widget _buildTestimonialCard(Map<String, dynamic> t, {required bool isPending}) {
    final stars = t['rating'] ?? 5;
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(16),
        boxShadow: Theme.of(context).brightness == Brightness.dark ? [] : AppTheme.tightShadow,
        border: Border.all(color: isPending ? Colors.orange.shade100 : (Theme.of(context).brightness == Brightness.dark ? const Color(0xFF334155) : Colors.grey.shade100)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              CircleAvatar(
                radius: 20,
                backgroundColor: AppTheme.primaryGreen.withOpacity(0.1),
                child: Text((t['user_name'] ?? 'U')[0].toUpperCase(), style: GoogleFonts.outfit(fontWeight: FontWeight.bold, color: AppTheme.primaryGreen)),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(t['user_name'] ?? 'Anonyme', style: GoogleFonts.outfit(fontWeight: FontWeight.bold)),
                    Row(children: List.generate(5, (i) => Icon(i < stars ? Icons.star : Icons.star_border, size: 14, color: Colors.amber))),
                  ],
                ),
              ),
              if (t['is_featured'] == true)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(color: Colors.amber.shade100, borderRadius: BorderRadius.circular(8)),
                  child: Text('★ Mis en avant', style: GoogleFonts.inter(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.amber.shade900)),
                ),
            ],
          ),
          const SizedBox(height: 12),
          Text(t['content'] ?? '', style: GoogleFonts.inter(fontSize: 14, color: Theme.of(context).textTheme.bodyLarge?.color ?? AppTheme.deepSlate, height: 1.5)),
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              if (isPending) ...[
                _actionBtn(Icons.check_circle, Colors.green, 'Approuver', () => _approveTestimonial(t['id'])),
                const SizedBox(width: 8),
                _actionBtn(Icons.cancel, Colors.red, 'Rejeter', () => _rejectTestimonial(t['id'])),
              ] else ...[
                _actionBtn(
                  t['is_featured'] == true ? Icons.star : Icons.star_border,
                  Colors.amber.shade700,
                  t['is_featured'] == true ? 'Retirer' : 'Mettre en avant',
                  () => _toggleFeatured(t['id']),
                ),
                const SizedBox(width: 8),
                _actionBtn(Icons.delete_outline, Colors.red, 'Supprimer', () => _rejectTestimonial(t['id'])),
              ],
            ],
          ),
        ],
      ),
    ).animate().slideX(begin: 0.1);
  }

  Widget _actionBtn(IconData icon, Color color, String tooltip, VoidCallback onTap) {
    return Tooltip(
      message: tooltip,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(8),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          decoration: BoxDecoration(color: color.withOpacity(0.1), borderRadius: BorderRadius.circular(8)),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 16, color: color),
              const SizedBox(width: 4),
              Text(tooltip, style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.w700, color: color)),
            ],
          ),
        ),
      ),
    );
  }
}

// =========================================
// COLLECTION POINTS MANAGEMENT TAB
// =========================================

class _CollectionPointsManagementTab extends StatefulWidget {
  @override
  State<_CollectionPointsManagementTab> createState() => _CollectionPointsManagementTabState();
}

class _CollectionPointsManagementTabState extends State<_CollectionPointsManagementTab> {
  final AuthService _authService = AuthService();
  List<Map<String, dynamic>> _points = [];
  List<Map<String, dynamic>> _alerts = [];
  int _unreadCount = 0;
  bool _loadingAlerts = true;
  bool _showAlerts = true;
  Timer? _pollingTimer;
  // Types pré-remplis (liste fixe du backend) + complétés par les centres chargés
  List<String> _typesFromApi = [
    'Plastique', 'Verre', 'Papier', 'Carton',
    'Métal', 'Électronique', 'Batteries', 'Compost',
    'Vêtements', 'Général',
  ];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadPoints();
    _loadAlerts();
    _pollingTimer = Timer.periodic(const Duration(seconds: 30), (_) => _loadAlerts());
  }

  @override
  void dispose() {
    _pollingTimer?.cancel();
    super.dispose();
  }

  Future<void> _loadAlerts() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final jwt = prefs.getString('jwt_token');
      if (jwt == null) return;
      final response = await http.get(
        Uri.parse('${AuthService.baseUrl}/admin/collection-points/alerts?limit=20'),
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

  Future<void> _markAlertsRead() async {
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
  }

  Future<void> _updatePointStatus(int id, String newStatus) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final jwt = prefs.getString('jwt_token');
      final response = await http.put(
        Uri.parse('${AuthService.baseUrl}/admin/collection-points/$id'),
        headers: {'Authorization': 'Bearer $jwt', 'Content-Type': 'application/json'},
        body: json.encode({'status': newStatus}),
      );
      if (!mounted) return;
      if (response.statusCode == 200) {
        final statusLabel = newStatus == 'disponible' ? '✅ Disponible'
            : newStatus == 'saturé' ? '🔴 Saturé'
            : '🟡 Maintenance';
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('Statut mis à jour : $statusLabel'),
          backgroundColor: newStatus == 'disponible' ? Colors.green
              : newStatus == 'saturé' ? Colors.red : Colors.orange,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ));
        _loadPoints();
        _loadAlerts();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('Erreur: $e'), backgroundColor: Colors.red,
          behavior: SnackBarBehavior.floating,
        ));
      }
    }
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
    } catch (_) { return ''; }
  }

  Future<void> _loadPoints() async {
    setState(() => _isLoading = true);
    try {
      final prefs = await SharedPreferences.getInstance();
      final jwt = prefs.getString('jwt_token');
      if (jwt != null) {
        http.post(
          Uri.parse('${AuthService.baseUrl}/admin/collection-points/backfill-addresses'),
          headers: {'Authorization': 'Bearer $jwt'},
        ).ignore();
      }
      final points = await _authService.fetchCollectionPoints();

      // Extraire dynamiquement les types uniques présents dans les centres chargés
      final Set<String> typesSet = {};
      for (final p in points) {
        final raw = p['types'];
        if (raw is List) {
          for (final t in raw) {
            final s = t.toString().trim();
            if (s.isNotEmpty) typesSet.add(s);
          }
        }
      }
      // Si aucun type extrait → fallback liste statique
      final types = typesSet.isEmpty
          ? ['Plastique', 'Verre', 'Papier', 'Carton', 'Métal', 'Électronique', 'Batteries', 'Compost', 'Vêtements', 'Général']
          : (typesSet.toList()..sort());

      if (mounted) {
        setState(() {
          _points = points;
          _typesFromApi = types;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _deletePoint(int id) async {
    final prefs = await SharedPreferences.getInstance();
    final jwt = prefs.getString('jwt_token');
    final response = await http.delete(
      Uri.parse('${AuthService.baseUrl}/admin/collection-points/$id'),
      headers: {'Authorization': 'Bearer $jwt'},
    );
    if (!mounted) return;
    if (response.statusCode == 200) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Point supprimé'), backgroundColor: Colors.green));
      _loadPoints();
    }
  }

  Future<void> _openAddEditScreen({Map<String, dynamic>? existing}) async {
    final result = await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => AddSortingCenterScreen(existingCenter: existing)),
    );
    if (result == null || result is! Map) return;

    final prefs = await SharedPreferences.getInstance();
    final jwt = prefs.getString('jwt_token');
    final location = result['location'];
    final latStr = location.latitude.toString();
    final lngStr = location.longitude.toString();

    // Détecter si la position a changé pour forcer le re-géocodage
    final bool locationChanged = existing != null &&
      (existing['lat'].toString() != latStr || existing['lng'].toString() != lngStr);

    final bodyMap = {
      'name': result['name'],
      'lat': latStr,
      'lng': lngStr,
      'types': result['types'],
      'hours': result['hours'],
      'status': result['status'],
      // Si la position a changé → vider l'adresse pour forcer le re-géocodage backend
      if (locationChanged) 'address': '',
    };
    final body = json.encode(bodyMap);

    try {
      http.Response response;
      if (existing == null) {
        response = await http.post(
          Uri.parse('${AuthService.baseUrl}/admin/collection-points'),
          headers: {'Authorization': 'Bearer $jwt', 'Content-Type': 'application/json'},
          body: body,
        );
      } else {
        response = await http.put(
          Uri.parse('${AuthService.baseUrl}/admin/collection-points/${existing['id']}'),
          headers: {'Authorization': 'Bearer $jwt', 'Content-Type': 'application/json'},
          body: body,
        );
      }
      if (!mounted) return;
      if (response.statusCode == 200 || response.statusCode == 201) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(existing == null
            ? '✅ Point "${result['name']}" ajouté avec succès'
            : '✅ Point "${result['name']}" mis à jour'),
          backgroundColor: AppTheme.primaryGreen,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ));
        _loadPoints();
      } else {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('❌ Erreur ${response.statusCode} — Vérifiez les données'),
          backgroundColor: Colors.red,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ));
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text('❌ Erreur de connexion : $e'),
        backgroundColor: Colors.red,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ));
    }
  }

  String _filtreStatut = 'Tous';
  String _filtreType = 'Tous';

  List<String> get _typesDisponibles => ['Tous', ..._typesFromApi];

  List<Map<String, dynamic>> get _pointsFiltres {
    var liste = _points;
    // Filtre statut
    if (_filtreStatut != 'Tous') {
      final map = {'Disponible': 'disponible', 'Saturé': 'saturé', 'Maintenance': 'maintenance'};
      liste = liste.where((p) => (p['status'] ?? '').toLowerCase() == map[_filtreStatut]).toList();
    }
    // Filtre type de déchets
    if (_filtreType != 'Tous') {
      liste = liste.where((p) {
        try {
          final raw = p['types'];
          List<String> types = [];
          if (raw is List) {
            types = raw.map((e) => e.toString()).toList();
          } else if (raw is String && raw.isNotEmpty) {
            final decoded = json.decode(raw);
            if (decoded is List) {
              types = decoded.cast<String>();
            } else if (decoded is Map) {
              for (final v in decoded.values) {
                if (v is List) { types.addAll(v.cast<String>()); }
              }
            }
          }
          return types.any((t) => t.toLowerCase() == _filtreType.toLowerCase());
        } catch (_) { return false; }
      }).toList();
    }
    return liste;
  }

  @override
  Widget build(BuildContext context) {
    final nbDispo = _points.where((p) => (p['status'] ?? '').toLowerCase() == 'disponible').length;
    final nbSat = _points.where((p) => (p['status'] ?? '').toLowerCase() == 'saturé').length;
    final nbMaint = _points.where((p) => (p['status'] ?? '').toLowerCase() == 'maintenance').length;

    return SingleChildScrollView(
      key: const PageStorageKey('admin_points'),
      primary: false,
      padding: const EdgeInsets.all(24),
      physics: const BouncingScrollPhysics(),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        // En-tête
        Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('RÉSEAU DE COLLECTE', style: GoogleFonts.outfit(
                fontWeight: FontWeight.w900, letterSpacing: 1.5, fontSize: 11, color: AppTheme.textMuted)),
              Text('${_points.length} points recensés',
                style: GoogleFonts.outfit(fontWeight: FontWeight.w900, fontSize: 20, color: Theme.of(context).textTheme.titleLarge?.color ?? AppTheme.deepSlate)),
            ]),
          ),
          const SizedBox(width: 8),
          ElevatedButton.icon(
            onPressed: () => _openAddEditScreen(),
            icon: const Icon(Icons.add_location_alt_rounded, size: 18),
            label: const Text('AJOUTER'),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.primaryGreen,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
            ),
          ),
        ]),
        const SizedBox(height: 16),

        // Résumé statuts
        Wrap(
          spacing: 8,
          runSpacing: 6,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            _statBadge('$nbDispo Disponibles', Colors.green, Icons.check_circle_rounded),
            _statBadge('$nbSat Saturés', Colors.red, Icons.warning_rounded),
            _statBadge('$nbMaint Maintenance', Colors.orange, Icons.build_rounded),
            IconButton(
              onPressed: _loadPoints,
              icon: const Icon(Icons.refresh_rounded, color: AppTheme.primaryGreen, size: 20),
              tooltip: 'Actualiser',
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(),
            ),
          ],
        ),
        const SizedBox(height: 20),

        // ── Panneau Alertes Centres ──────────────────────────────────────────
        GestureDetector(
          onTap: () => setState(() => _showAlerts = !_showAlerts),
          child: Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: _unreadCount > 0 ? Colors.red.shade50 : Colors.grey.shade50,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: _unreadCount > 0 ? Colors.red.shade200 : Colors.grey.shade200,
              ),
            ),
            child: Row(children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: (_unreadCount > 0 ? Colors.red : Colors.grey).withOpacity(0.1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(Icons.notifications_active_rounded,
                    color: _unreadCount > 0 ? Colors.red : Colors.grey, size: 16),
              ),
              const SizedBox(width: 12),
              Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text('ALERTES CENTRES DE TRI',
                    style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.w900,
                        letterSpacing: 1, color: _unreadCount > 0 ? Colors.red.shade800 : AppTheme.textMuted)),
                Text(_unreadCount > 0 ? '$_unreadCount alerte(s) non lue(s)' : 'Aucune alerte non lue',
                    style: GoogleFonts.inter(fontSize: 11,
                        color: _unreadCount > 0 ? Colors.red.shade600 : AppTheme.textMuted)),
              ])),
              if (_unreadCount > 0)
                TextButton(
                  onPressed: _markAlertsRead,
                  style: TextButton.styleFrom(padding: const EdgeInsets.symmetric(horizontal: 10)),
                  child: Text('Tout lire', style: GoogleFonts.inter(
                      fontSize: 11, fontWeight: FontWeight.w700, color: AppTheme.primaryGreen)),
                ),
              Icon(_showAlerts ? Icons.keyboard_arrow_up_rounded : Icons.keyboard_arrow_down_rounded,
                  color: AppTheme.textMuted, size: 18),
            ]),
          ),
        ),

        if (_showAlerts) ...[
          const SizedBox(height: 12),
          if (_loadingAlerts)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 20),
              child: Center(child: CircularProgressIndicator(color: AppTheme.primaryGreen)),
            )
          else if (_alerts.isEmpty)
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.surface,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: Theme.of(context).brightness == Brightness.dark ? const Color(0xFF334155) : Colors.grey.shade100),
              ),
              child: Row(children: [
                Icon(Icons.check_circle_outline_rounded, color: AppTheme.primaryGreen.withOpacity(0.6), size: 20),
                const SizedBox(width: 12),
                Expanded(
                  child: Text('Aucune alerte récente — tous les centres sont normaux.',
                      style: GoogleFonts.inter(fontSize: 12, color: AppTheme.textMuted)),
                ),
              ]),
            )
          else
            ..._alerts.map((alert) {
              final isSature = (alert['title'] ?? '').toString().contains('Saturé');
              final isRead = alert['is_read'] == true;
              final color = isSature ? Colors.red : Colors.orange;
              return Container(
                margin: const EdgeInsets.only(bottom: 8),
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: isRead ? Theme.of(context).colorScheme.surface : color.withOpacity(0.04),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(
                    color: isRead ? (Theme.of(context).brightness == Brightness.dark ? const Color(0xFF334155) : Colors.grey.shade100) : color.withOpacity(0.25),
                    width: isRead ? 1 : 1.5,
                  ),
                ),
                child: Row(children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(color: color.withOpacity(0.1), shape: BoxShape.circle),
                    child: Icon(
                      isSature ? Icons.error_rounded : Icons.build_circle_rounded,
                      color: color, size: 16,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Row(children: [
                      Expanded(child: Text(alert['title'] ?? '',
                          style: GoogleFonts.outfit(
                            fontWeight: FontWeight.bold, fontSize: 12,
                             color: isRead ? AppTheme.textMuted : (Theme.of(context).textTheme.titleLarge?.color ?? AppTheme.deepSlate),
                          ))),
                      if (!isRead) Container(width: 7, height: 7,
                          decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
                    ]),
                    const SizedBox(height: 3),
                    Text(alert['body'] ?? '',
                        style: GoogleFonts.inter(fontSize: 11, color: AppTheme.textMuted),
                        maxLines: 2, overflow: TextOverflow.ellipsis),
                    const SizedBox(height: 4),
                    Text(_timeAgo(alert['created_at']?.toString()),
                        style: GoogleFonts.inter(fontSize: 10, color: AppTheme.textMuted.withOpacity(0.6),
                            fontWeight: FontWeight.w600)),
                  ])),
                ]),
              );
            }).toList(),
        ],

        const SizedBox(height: 20),

        // Filtres statut
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(children: ['Tous','Disponible','Saturé','Maintenance'].map((f) =>
            GestureDetector(
              onTap: () => setState(() => _filtreStatut = f),
              child: Container(
                margin: const EdgeInsets.only(right: 8),
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                decoration: BoxDecoration(
                  color: _filtreStatut == f ? _filtreColor(f) : (Theme.of(context).brightness == Brightness.dark ? const Color(0xFF1E293B) : Colors.grey.shade100),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(f, style: GoogleFonts.inter(
                  fontSize: 12, fontWeight: FontWeight.w700,
                  color: _filtreStatut == f ? Colors.white : AppTheme.textMuted)),
              ),
            )
          ).toList()),
        ),
        const SizedBox(height: 10),

        // Filtres type de déchets (dynamique)
        if (_typesDisponibles.length > 1) ...[
          Text('Type de déchets', style: GoogleFonts.inter(
            fontSize: 10, fontWeight: FontWeight.w700, color: AppTheme.textMuted,
            letterSpacing: 0.5)),
          const SizedBox(height: 6),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(children: _typesDisponibles.map((t) =>
              GestureDetector(
                onTap: () => setState(() => _filtreType = t),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  margin: const EdgeInsets.only(right: 7),
                  padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 6),
                  decoration: BoxDecoration(
                    color: _filtreType == t ? AppTheme.primaryGreen : (Theme.of(context).brightness == Brightness.dark ? const Color(0xFF1E293B) : Colors.grey.shade50),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: _filtreType == t ? AppTheme.primaryGreen : (Theme.of(context).brightness == Brightness.dark ? const Color(0xFF334155) : Colors.grey.shade200)),
                  ),
                  child: Text(t, style: GoogleFonts.inter(
                    fontSize: 11, fontWeight: FontWeight.w700,
                    color: _filtreType == t ? Colors.white : (Theme.of(context).textTheme.bodyLarge?.color ?? AppTheme.deepSlate))),
                ),
              )
            ).toList()),
          ),
        ],
        const SizedBox(height: 16),

        if (_isLoading)
          const Center(child: Padding(padding: EdgeInsets.all(40),
            child: CircularProgressIndicator(color: AppTheme.primaryGreen)))
        else if (_pointsFiltres.isEmpty)
          Center(child: Padding(padding: const EdgeInsets.all(40),
            child: Column(children: [
              Icon(Icons.location_off_rounded, size: 40, color: Colors.grey.shade300),
              const SizedBox(height: 12),
              Text('Aucun point $_filtreStatut'.trim(),
                style: GoogleFonts.inter(color: AppTheme.textMuted, fontSize: 14)),
            ])))
        else
          ..._pointsFiltres.map((p) => _buildPointCard(p)),
        const SizedBox(height: 80),
      ]),
    );
  }

  Color _filtreColor(String f) {
    switch (f) {
      case 'Disponible': return Colors.green;
      case 'Saturé': return Colors.red;
      case 'Maintenance': return Colors.orange;
      default: return AppTheme.primaryGreen;
    }
  }

  Widget _statBadge(String label, Color color, IconData icon) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: color.withOpacity(0.08),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: color.withOpacity(0.2)),
      ),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        Icon(icon, color: color, size: 13),
        const SizedBox(width: 5),
        Text(label, style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.w700, color: color)),
      ]),
    );
  }

  Widget _buildPointCard(Map<String, dynamic> p) {
    final rawStatus = (p['status'] ?? 'disponible').toString().toLowerCase();
    final Color couleur = rawStatus == 'disponible' ? Colors.green
      : rawStatus == 'saturé' ? Colors.red : Colors.orange;
    final IconData iconeStatut = rawStatus == 'disponible' ? Icons.check_circle_rounded
      : rawStatus == 'saturé' ? Icons.warning_rounded : Icons.build_rounded;
    final String libelle = rawStatus == 'disponible' ? 'Disponible'
      : rawStatus == 'saturé' ? 'Saturé' : 'Maintenance';

    final address = p['address']?.toString() ?? '';
    final hours = p['hours']?.toString() ?? '';

    // Types de déchets acceptés
    List<String> types = [];
    try {
      final raw = p['types'];
      if (raw is String && raw.isNotEmpty) {
        final decoded = json.decode(raw);
        if (decoded is Map) {
          for (final entry in decoded.entries) {
            if ((entry.value as List?)?.isNotEmpty ?? false) {
              types.addAll((entry.value as List).cast<String>());
            }
          }
        } else if (decoded is List) {
          types = decoded.cast<String>();
        }
      }
    } catch (_) {}

    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border(left: BorderSide(color: couleur, width: 4)),
        boxShadow: [BoxShadow(color: couleur.withOpacity(0.06), blurRadius: 16, offset: const Offset(0, 4))],
      ),
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            // Icône
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: couleur.withOpacity(0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(Icons.location_on_rounded, color: couleur, size: 22),
            ),
            const SizedBox(width: 14),
            // Nom + statut + adresse
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(p['name'] ?? '', style: GoogleFonts.outfit(
                fontWeight: FontWeight.w900, fontSize: 16, color: Theme.of(context).textTheme.titleLarge?.color ?? AppTheme.deepSlate)),
              const SizedBox(height: 4),
              // Badge statut
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: couleur.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(mainAxisSize: MainAxisSize.min, children: [
                  Icon(iconeStatut, color: couleur, size: 11),
                  const SizedBox(width: 4),
                  Text(libelle, style: GoogleFonts.inter(
                    color: couleur, fontWeight: FontWeight.w800, fontSize: 11)),
                ]),
              ),
              if (address.isNotEmpty) ...[
                const SizedBox(height: 6),
                Row(children: [
                  const Icon(Icons.place_outlined, size: 12, color: AppTheme.textMuted),
                  const SizedBox(width: 4),
                  Expanded(child: Text(address, style: GoogleFonts.inter(
                    color: AppTheme.textMuted, fontSize: 11), maxLines: 2,
                    overflow: TextOverflow.ellipsis)),
                ]),
              ],
              if (hours.isNotEmpty) ...[
                const SizedBox(height: 3),
                Row(children: [
                  const Icon(Icons.access_time_rounded, size: 12, color: AppTheme.textMuted),
                  const SizedBox(width: 4),
                  Expanded(child: Text(hours, style: GoogleFonts.inter(color: AppTheme.textMuted, fontSize: 11), maxLines: 2, overflow: TextOverflow.ellipsis)),
                ]),
              ],
            ])),
            // Menu actions
            PopupMenuButton(
              tooltip: 'Options',
              icon: const Icon(Icons.more_vert, color: AppTheme.textMuted),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
              itemBuilder: (ctx) => [
                PopupMenuItem(value: 'edit', child: Row(children: [
                  Icon(Icons.edit_rounded, size: 16, color: Colors.blue.shade600),
                  const SizedBox(width: 10),
                  Text('Modifier', style: GoogleFonts.inter(fontWeight: FontWeight.w600)),
                ])),
                PopupMenuItem(value: 'delete', child: Row(children: [
                  const Icon(Icons.delete_rounded, size: 16, color: Colors.red),
                  const SizedBox(width: 10),
                  Text('Supprimer', style: GoogleFonts.inter(
                    fontWeight: FontWeight.w600, color: Colors.red)),
                ])),
              ],
              onSelected: (val) {
                if (val == 'edit') _openAddEditScreen(existing: p);
                if (val == 'delete') _deletePoint(p['id']);
              },
            ),
          ]),

          // Types de déchets
          if (types.isNotEmpty) ...[
            const SizedBox(height: 12),
            const Divider(height: 1, color: Color(0xFFF1F5F9)),
            const SizedBox(height: 10),
            Wrap(spacing: 6, runSpacing: 5, children: types.take(6).map((t) =>
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: Theme.of(context).brightness == Brightness.dark ? const Color(0xFF1E293B) : Colors.grey.shade50,
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(color: Theme.of(context).brightness == Brightness.dark ? const Color(0xFF334155) : Colors.grey.shade200),
                ),
                child: Text(t, style: GoogleFonts.inter(fontSize: 10, color: Theme.of(context).textTheme.bodyLarge?.color ?? AppTheme.deepSlate,
                  fontWeight: FontWeight.w600)),
              )
            ).toList()),
          ],

          // ── Changement rapide de statut ─────────────────────────────────
          const SizedBox(height: 14),
          const Divider(height: 1, color: Color(0xFFF1F5F9)),
          const SizedBox(height: 12),
          Wrap(
            alignment: WrapAlignment.start,
            crossAxisAlignment: WrapCrossAlignment.center,
            spacing: 6,
            runSpacing: 6,
            children: [
              Text('STATUT RAPIDE', style: GoogleFonts.inter(
                  fontSize: 9, fontWeight: FontWeight.w900, letterSpacing: 1, color: AppTheme.textMuted)),
              const SizedBox(width: 4),
              _StatusBtn(
                label: 'Disponible',
                color: Colors.green,
                icon: Icons.check_circle_rounded,
                active: rawStatus == 'disponible',
                onTap: rawStatus == 'disponible' ? null : () => _updatePointStatus(p['id'], 'disponible'),
              ),
              _StatusBtn(
                label: 'Saturé',
                color: Colors.red,
                icon: Icons.warning_rounded,
                active: rawStatus == 'saturé',
                onTap: rawStatus == 'saturé' ? null : () => _updatePointStatus(p['id'], 'saturé'),
              ),
              _StatusBtn(
                label: 'Maint.',
                color: Colors.orange,
                icon: Icons.build_rounded,
                active: rawStatus == 'maintenance',
                onTap: rawStatus == 'maintenance' ? null : () => _updatePointStatus(p['id'], 'maintenance'),
              ),
            ],
          ),

        ]),
      ),
    );
  }
}

// ── Widget bouton statut rapide ───────────────────────────────────────────────
class _StatusBtn extends StatelessWidget {
  final String label;
  final Color color;
  final IconData icon;
  final bool active;
  final VoidCallback? onTap;
  const _StatusBtn({required this.label, required this.color, required this.icon, required this.active, this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
        decoration: BoxDecoration(
          color: active ? color : color.withOpacity(0.07),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: active ? color : color.withOpacity(0.2)),
        ),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          Icon(icon, size: 11, color: active ? Colors.white : color),
          const SizedBox(width: 4),
          Text(label, style: GoogleFonts.inter(
              fontSize: 10, fontWeight: FontWeight.w800,
              color: active ? Colors.white : color)),
        ]),
      ),
    );
  }
}

// _ValidationItem removed (unused)


// =========================================
// POSTS MODERATION TAB
// =========================================

class _PostsModerationTab extends StatefulWidget {
  final VoidCallback? onStatsUpdated;
  const _PostsModerationTab({this.onStatsUpdated});

  @override
  State<_PostsModerationTab> createState() => _PostsModerationTabState();
}

class _PostsModerationTabState extends State<_PostsModerationTab> {
  final AuthService _authService = AuthService();
  List<Map<String, dynamic>> _posts = [];
  int _total = 0;
  bool _isLoading = true;
  Map<String, dynamic> _stats = {};

  @override
  void initState() {
    super.initState();
    _loadPendingPosts();
  }

  Future<void> _loadPendingPosts() async {
    setState(() => _isLoading = true);
    try {
      final result = await _authService.fetchPendingPosts();
      final moderationStats = await _authService.fetchModerationStats();
      if (mounted) {
        setState(() {
          final raw = result['posts'];
          _posts = raw is List ? raw.cast<Map<String, dynamic>>() : [];
          _total = result['total'] ?? 0;
          _stats = moderationStats;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _approve(int id) async {
    final ok = await _authService.approvePost(id);
    if (ok) {
      widget.onStatsUpdated?.call();
      _loadPendingPosts();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('✅ Publication approuvée'),
          backgroundColor: Colors.green,
          behavior: SnackBarBehavior.floating,
        ));
      }
    }
  }

  Future<void> _reject(int id, String description) async {
    final reasonCtrl = TextEditingController();
    final reason = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text('Rejeter la publication', style: GoogleFonts.outfit(fontWeight: FontWeight.bold)),
        content: TextField(
          controller: reasonCtrl,
          maxLines: 2,
          decoration: InputDecoration(
            hintText: 'Raison du rejet (optionnel)',
            hintStyle: GoogleFonts.inter(color: AppTheme.textMuted),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Annuler')),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, reasonCtrl.text.trim()),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red.shade400),
            child: const Text('Rejeter', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
    if (reason == null) return; // cancelled
    final ok = await _authService.rejectPost(id, reason: reason.isNotEmpty ? reason : null);
    if (ok) {
      widget.onStatsUpdated?.call();
      _loadPendingPosts();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: const Text('❌ Publication rejetée'),
          backgroundColor: Colors.red.shade400,
          behavior: SnackBarBehavior.floating,
        ));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return RefreshIndicator(
      color: AppTheme.primaryGreen,
      onRefresh: _loadPendingPosts,
      child: SingleChildScrollView(
        key: const PageStorageKey('admin_moderation'),
        primary: false,
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Stats bar
            if (_stats.isNotEmpty) ...[
              _buildStatsBar(),
              const SizedBox(height: 24),
            ],

            Row(
              children: [
                Text(
                  _isLoading ? 'CHARGEMENT...' : 'EN ATTENTE ($_total)',
                  style: GoogleFonts.outfit(
                    fontWeight: FontWeight.w900, letterSpacing: 1.5,
                    fontSize: 12, color: AppTheme.textMuted,
                  ),
                ),
                const Spacer(),
                IconButton(
                  onPressed: _loadPendingPosts,
                  icon: const Icon(Icons.refresh, color: AppTheme.primaryGreen),
                ),
              ],
            ),
            const SizedBox(height: 12),

            if (_isLoading)
              const Center(child: Padding(
                padding: EdgeInsets.all(60),
                child: CircularProgressIndicator(color: AppTheme.primaryGreen),
              ))
            else if (_posts.isEmpty)
              _buildEmptyState()
            else
              ..._posts.map((p) => _buildPostCard(p)).toList(),

            const SizedBox(height: 100),
          ],
        ),
      ),
    );
  }

  Widget _buildStatsBar() {
    final published = _stats['published'] ?? 0;
    final pending = _stats['pending_review'] ?? 0;
    final rejected = _stats['rejected'] ?? 0;
    final total = _stats['total_posts'] ?? 0;

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [Colors.blueGrey.shade900, Colors.blueGrey.shade800],
        ),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Wrap(
        alignment: WrapAlignment.spaceAround,
        spacing: 12,
        runSpacing: 12,
        children: [
          _statChip('Publiés', published, Colors.green),
          _statChip('En attente', pending, Colors.amber),
          _statChip('Rejetés', rejected, Colors.red),
          _statChip('Total', total, Colors.white),
        ],
      ),
    ).animate().fadeIn();
  }

  Widget _statChip(String label, int count, Color color) {
    return Column(
      children: [
        Text('$count', style: GoogleFonts.outfit(color: color, fontWeight: FontWeight.w900, fontSize: 22)),
        Text(label, style: GoogleFonts.inter(color: Colors.white54, fontSize: 11)),
      ],
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 60),
        child: Column(
          children: [
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: Colors.green.withOpacity(0.08),
                shape: BoxShape.circle,
              ),
              child: Icon(Icons.check_circle_outline_rounded, size: 48, color: Colors.green.shade400),
            ),
            const SizedBox(height: 20),
            Text('Tout est à jour !', style: GoogleFonts.outfit(
              fontSize: 18, fontWeight: FontWeight.w700, color: Theme.of(context).textTheme.titleLarge?.color ?? AppTheme.deepSlate)),
            const SizedBox(height: 6),
            Text('Aucune publication en attente de validation.',
              style: GoogleFonts.inter(fontSize: 13, color: AppTheme.textMuted)),
          ],
        ),
      ),
    );
  }

  Widget _buildPostCard(Map<String, dynamic> post) {
    final id = post['id'] as int;
    final userName = post['user_name'] ?? 'Inconnu';
    final description = post['description'] ?? '';
    final imageUrl = post['image_url'] ?? '';
    final score = (post['moderation_score'] as num?)?.toDouble() ?? 0.0;
    final reason = post['moderation_reason'] ?? '';
    final createdAt = post['created_at'] ?? '';

    String fmtDate(String iso) {
      try {
        final dt = DateTime.parse(iso);
        return '${dt.day}/${dt.month}/${dt.year} ${dt.hour}:${dt.minute.toString().padLeft(2, '0')}';
      } catch (_) { return iso; }
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(20),
        boxShadow: Theme.of(context).brightness == Brightness.dark ? [] : AppTheme.tightShadow,
        border: Border.all(color: Theme.of(context).brightness == Brightness.dark ? const Color(0xFF334155) : Colors.orange.shade100),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Image (if any)
          if (imageUrl.isNotEmpty)
            ClipRRect(
              borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
              child: Image.network(
                imageUrl,
                height: 180,
                width: double.infinity,
                fit: BoxFit.cover,
                errorBuilder: (_, __, ___) => Container(
                  height: 100,
                  color: Theme.of(context).brightness == Brightness.dark ? const Color(0xFF1E293B) : Colors.grey.shade100,
                  child: const Icon(Icons.broken_image_outlined, color: Colors.grey, size: 40),
                ),
              ),
            ),
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Header
                Row(
                  children: [
                    CircleAvatar(
                      radius: 18,
                      backgroundColor: AppTheme.primaryGreen.withOpacity(0.1),
                      child: Text(userName[0].toUpperCase(),
                        style: GoogleFonts.outfit(fontWeight: FontWeight.bold, color: AppTheme.primaryGreen)),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(userName, style: GoogleFonts.outfit(fontWeight: FontWeight.bold, fontSize: 14)),
                          Text(fmtDate(createdAt),
                            style: GoogleFonts.inter(fontSize: 11, color: AppTheme.textMuted)),
                        ],
                      ),
                    ),
                    // Score badge
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: score > 0.5 ? Colors.orange.shade50 : Colors.green.shade50,
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(
                          color: score > 0.5 ? Colors.orange.shade200 : Colors.green.shade200),
                      ),
                      child: Text(
                        'Score: ${(score * 100).toInt()}%',
                        style: GoogleFonts.inter(
                          fontSize: 11, fontWeight: FontWeight.w700,
                          color: score > 0.5 ? Colors.orange.shade700 : Colors.green.shade700,
                        ),
                      ),
                    ),
                  ],
                ),
                if (description.isNotEmpty) ...[
                  const SizedBox(height: 12),
                  Text(description, style: GoogleFonts.inter(fontSize: 13, color: Theme.of(context).textTheme.bodyLarge?.color ?? AppTheme.deepSlate, height: 1.5),
                    maxLines: 3, overflow: TextOverflow.ellipsis),
                ],
                if (reason.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: Colors.amber.shade50,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: Colors.amber.shade200),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.info_outline, size: 14, color: Colors.amber),
                        const SizedBox(width: 6),
                        Expanded(child: Text(reason,
                          style: GoogleFonts.inter(fontSize: 11, color: Colors.amber.shade800))),
                      ],
                    ),
                  ),
                ],
                const SizedBox(height: 14),
                // Action buttons
                Row(
                  children: [
                    Expanded(
                      child: ElevatedButton.icon(
                        onPressed: () => _approve(id),
                        icon: const Icon(Icons.check_circle_rounded, size: 16),
                        label: const Text('Approuver'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.green.shade600,
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          elevation: 0,
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: ElevatedButton.icon(
                        onPressed: () => _reject(id, description),
                        icon: const Icon(Icons.cancel_rounded, size: 16),
                        label: const Text('Rejeter'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.red.shade400,
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          elevation: 0,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    ).animate().fadeIn(delay: 100.ms).slideY(begin: 0.05, end: 0);
  }
}
