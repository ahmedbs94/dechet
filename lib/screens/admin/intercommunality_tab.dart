import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'dart:io';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_map_cancellable_tile_provider/flutter_map_cancellable_tile_provider.dart';
import 'package:latlong2/latlong.dart';
import '../../services/auth_service.dart';
import '../../services/l10n_service.dart';
import '../../theme/app_theme.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../../core/firebase/firebase_admin_stats_service.dart';
import '../../services/messaging_service.dart';
import '../messaging/messaging_screen.dart';

class IntercommunalityTab extends StatefulWidget {
  const IntercommunalityTab({Key? key}) : super(key: key);

  @override
  State<IntercommunalityTab> createState() => _IntercommunalityTabState();
}

class _IntercommunalityTabState extends State<IntercommunalityTab>
    with AutomaticKeepAliveClientMixin, SingleTickerProviderStateMixin {

  late final TabController _tabCtrl;

  // ── F1 : Consignes ───────────────────────────────────────────────────────
  List<Map<String, dynamic>> _instructions   = [];
  bool   _loadingInstructions = false;
  String _f1FilterWasteType  = '';
  String _f1FilterTerritory  = '';
  bool?  _f1FilterActive;

  // ── F2 : Points de collecte ───────────────────────────────────────────────
  List<Map<String, dynamic>> _points          = [];
  bool   _loadingPoints = false;
  String _f2Search    = '';

  // ── F3 : Acteurs ─────────────────────────────────────────────────────────
  List<Map<String, dynamic>> _actors         = [];
  List<Map<String, dynamic>> _customGroups   = [];
  bool   _loadingActors  = false;
  String _f3FilterRole   = '';
  bool   _showGroups     = false;

  // ── F4 : Réponses / notifications reçues ─────────────────────────────────
  List<Map<String, dynamic>> _replies         = [];
  bool   _loadingReplies  = false;
  int    _unreadRepliesCount = 0;

  // ── F5 : Pilotage (zones & affectations) ─────────────────────────────────
  List<Map<String, dynamic>> _zones           = [];
  List<Map<String, dynamic>> _assignments     = [];
  List<Map<String, dynamic>> _collectors      = [];
  bool   _loadingPilotage = false;
  Map<String, dynamic>?     _dashboard;
  int    _unreadMessages  = 0;

  // ── Autocomplete / Presets Data ──────────────────────────────────────────
  static const List<String> _wasteTypesList = [
    'Plastique',
    'Verre',
    'Papier / Carton',
    'Métal',
    'Organique',
    'Électronique',
    'Dangereux',
    'Autre'
  ];

  static const Map<String, List<String>> _territoryCitiesMap = {
    'Tunis': ['Tunis Ville', 'La Marsa', 'Carthage', 'Sidi Bou Saïd'],
    'Ariana': ['Ariana Ville', 'La Soukra', 'Mnihla', 'Ghazela'],
    'Ben Arous': ['Ben Arous', 'Radès', 'Megrine', 'Hammam Lif'],
    'Sousse': ['Sousse Ville', 'Kantaoui', 'Akouda', 'Hammam Sousse'],
    'Sfax': ['Sfax Ville', 'Sakiet Ezzit', 'Sakiet Eddaier'],
    'Nabeul': ['Nabeul Ville', 'Hammamet', 'Kélibia', 'Dar Chaâbane'],
    'Bizerte': ['Bizerte Ville', 'Menzel Bourguiba', 'Mateur'],
  };

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    _tabCtrl = TabController(length: 5, vsync: this);
    _tabCtrl.addListener(() => setState(() {})); // Rebuild FAB on tab changes
    L10n.addListener(_onLocaleChange);
    _loadInstructions();
    _loadPoints();
    _loadActors();
    _loadCustomGroups();
    _loadReplies();
    _loadPilotage();
    _loadDashboard();
    _loadUnreadMessages();
  }

  @override
  void dispose() {
    _tabCtrl.dispose();
    L10n.removeListener(_onLocaleChange);
    super.dispose();
  }

  void _onLocaleChange() {
    if (mounted) setState(() {});
  }

  Future<void> _loadUnreadMessages() async {
    final count = await MessagingService.getUnreadCount();
    if (mounted) setState(() => _unreadMessages = count);
  }

  // ── Auth helpers ──────────────────────────────────────────────────────────
  Future<String?> _jwt() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString('jwt_token');
  }

  Map<String, String> _headers(String jwt) => {
    'Authorization': 'Bearer $jwt',
    'Content-Type': 'application/json',
    'Accept': 'application/json',
  };

  // ── API Loaders ───────────────────────────────────────────────────────────
  Future<void> _loadInstructions() async {
    if (!mounted) return;
    setState(() => _loadingInstructions = true);
    try {
      final jwt = await _jwt();
      if (jwt == null) return;
      final res = await http.get(
        Uri.parse('${AuthService.baseUrl}/intercommunality/instructions'),
        headers: _headers(jwt),
      );
      if (res.statusCode == 200 && mounted) {
        final data = json.decode(res.body) as List;
        setState(() => _instructions = data.cast<Map<String, dynamic>>());
      }
    } catch (_) {}
    if (mounted) setState(() => _loadingInstructions = false);
  }

  Future<void> _loadPoints() async {
    if (!mounted) return;
    setState(() => _loadingPoints = true);
    try {
      final jwt = await _jwt();
      if (jwt == null) return;
      final res = await http.get(
        Uri.parse('${AuthService.baseUrl}/intercommunality/collection-points'),
        headers: _headers(jwt),
      );
      if (res.statusCode == 200 && mounted) {
        final data = json.decode(res.body) as List;
        setState(() => _points = data.cast<Map<String, dynamic>>());
      }
    } catch (_) {}
    if (mounted) setState(() => _loadingPoints = false);
  }

  Future<void> _loadActors() async {
    if (!mounted) return;
    setState(() => _loadingActors = true);
    try {
      final jwt = await _jwt();
      if (jwt == null) return;
      final res = await http.get(
        Uri.parse('${AuthService.baseUrl}/intercommunality/actors'),
        headers: _headers(jwt),
      );
      if (res.statusCode == 200 && mounted) {
        final data = json.decode(res.body) as List;
        setState(() => _actors = data.cast<Map<String, dynamic>>());
      }
    } catch (_) {}
    if (mounted) setState(() => _loadingActors = false);
  }

  Future<void> _loadCustomGroups() async {
    try {
      final jwt = await _jwt();
      if (jwt == null) return;
      final res = await http.get(
        Uri.parse('${AuthService.baseUrl}/intercommunality/custom-groups'),
        headers: _headers(jwt),
      );
      if (res.statusCode == 200 && mounted) {
        final data = json.decode(res.body) as List;
        setState(() => _customGroups = data.cast<Map<String, dynamic>>());
      }
    } catch (_) {}
  }

  Future<void> _loadReplies() async {
    if (!mounted) return;
    setState(() => _loadingReplies = true);
    try {
      final jwt = await _jwt();
      if (jwt == null) return;
      final res = await http.get(
        Uri.parse('${AuthService.baseUrl}/notifications?unread_only=false'),
        headers: _headers(jwt),
      );
      if (res.statusCode == 200 && mounted) {
        final data = json.decode(res.body) as List;
        final replies = data.cast<Map<String, dynamic>>();
        setState(() {
          _replies = replies;
          _unreadRepliesCount = replies.where((r) => r['is_read'] == false).length;
        });
      }
    } catch (_) {}
    if (mounted) setState(() => _loadingReplies = false);
  }

  Future<void> _loadPilotage() async {
    if (!mounted) return;
    setState(() => _loadingPilotage = true);
    try {
      final jwt = await _jwt();
      if (jwt == null) return;
      final results = await Future.wait([
        http.get(Uri.parse('${AuthService.baseUrl}/intercommunality/zones'), headers: _headers(jwt)),
        http.get(Uri.parse('${AuthService.baseUrl}/intercommunality/assignments'), headers: _headers(jwt)),
        http.get(Uri.parse('${AuthService.baseUrl}/intercommunality/actors?role=collector'), headers: _headers(jwt)),
      ]);
      if (!mounted) return;
      if (results[0].statusCode == 200) {
        setState(() => _zones = (json.decode(results[0].body) as List).cast<Map<String, dynamic>>());
      }
      if (results[1].statusCode == 200) {
        setState(() => _assignments = (json.decode(results[1].body) as List).cast<Map<String, dynamic>>());
      }
      if (results[2].statusCode == 200) {
        setState(() => _collectors = (json.decode(results[2].body) as List).cast<Map<String, dynamic>>());
      }
    } catch (_) {}
    if (mounted) setState(() => _loadingPilotage = false);
  }

  Future<void> _loadDashboard() async {
    try {
      final jwt = await _jwt();
      if (jwt == null) return;
      final res = await http.get(
        Uri.parse('${AuthService.baseUrl}/intercommunality/dashboard'),
        headers: _headers(jwt),
      );
      if (res.statusCode == 200 && mounted) {
        setState(() => _dashboard = json.decode(res.body) as Map<String, dynamic>);
      }
    } catch (_) {}
  }

  // ── Empty State Helper ───────────────────────────────────────────────────
  Widget _emptyState({required IconData icon, required String title, required String sub, Color color = const Color(0xFF6C3EB8)}) {
    return SingleChildScrollView(
      physics: const AlwaysScrollableScrollPhysics(),
      child: Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 60, horizontal: 20),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, size: 56, color: color.withOpacity(0.3)),
              const SizedBox(height: 12),
              Text(
                title,
                style: GoogleFonts.outfit(fontSize: 16, fontWeight: FontWeight.w700, color: AppTheme.deepSlate),
              ),
              const SizedBox(height: 4),
              Text(
                sub,
                style: GoogleFonts.inter(fontSize: 12, color: AppTheme.textMuted),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ── Dashboard KPI Cards Row ──────────────────────────────────────────────
  Widget _buildDashboardCards() {
    final dash = _dashboard;
    final totalInstructions = dash?['total_instructions'] ?? _instructions.length;
    final totalPoints       = dash?['total_points']       ?? _points.length;
    final totalActors       = dash?['total_actors']       ?? _actors.length;
    final unread            = _unreadRepliesCount;
    return Container(
      color: Colors.white,
      padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
      child: Row(
        children: [
          _kpiCard(value: '$totalInstructions', label: 'Consignes',  icon: Icons.rule_rounded,          color: const Color(0xFF6C3EB8)),
          const SizedBox(width: 8),
          _kpiCard(value: '$totalPoints',       label: 'Points',     icon: Icons.location_city_rounded,  color: const Color(0xFF1A6B3C)),
          const SizedBox(width: 8),
          _kpiCard(value: '$totalActors',       label: 'Acteurs',    icon: Icons.groups_rounded,         color: const Color(0xFFE8961A)),
          const SizedBox(width: 8),
          _kpiCard(value: '$unread',            label: 'Non lus',    icon: Icons.forum_rounded,          color: unread > 0 ? Colors.red : AppTheme.textMuted),
        ],
      ),
    );
  }

  Widget _kpiCard({required String value, required String label, required IconData icon, required Color color}) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 12),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: AppTheme.tightShadow,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, color: color, size: 20),
            const SizedBox(height: 8),
            Text(value, style: GoogleFonts.outfit(fontSize: 18, fontWeight: FontWeight.w900, color: AppTheme.deepSlate)),
            Text(label, style: GoogleFonts.outfit(fontSize: 10, fontWeight: FontWeight.w700, color: AppTheme.textMuted), maxLines: 1, overflow: TextOverflow.ellipsis),
          ],
        ),
      ),
    );
  }

  // ── Operations & Dialog Methods ──────────────────────────────────────────
  Future<void> _notifyCustomGroup(int groupId, String groupName) async {
    final titleCtrl = TextEditingController();
    final msgCtrl   = TextEditingController();
    await showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Notifier : $groupName', style: GoogleFonts.outfit(fontWeight: FontWeight.w800)),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(controller: titleCtrl, decoration: InputDecoration(labelText: 'Titre', border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)))),
              const SizedBox(height: 8),
              TextField(controller: msgCtrl, maxLines: 3, decoration: InputDecoration(labelText: 'Message', border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)))),
            ],
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Annuler')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF6C3EB8)),
            onPressed: () async {
              final jwt = await _jwt();
              if (jwt == null) return;
              await http.post(
                Uri.parse('${AuthService.baseUrl}/intercommunality/custom-groups/$groupId/notify'),
                headers: _headers(jwt),
                body: json.encode({'title': titleCtrl.text.trim(), 'message': msgCtrl.text.trim()}),
              );
              if (ctx.mounted) Navigator.pop(ctx);
              if (mounted) {
                ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('✅ Message envoyé au groupe'), backgroundColor: Colors.green));
              }
            },
            child: const Text('Envoyer', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  Future<void> _notifyIndividualActor(Map<String, dynamic> actor) async {
    final titleCtrl = TextEditingController();
    final msgCtrl   = TextEditingController();
    final name      = actor['full_name'] ?? 'Acteur';
    await showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Message à : $name', style: GoogleFonts.outfit(fontWeight: FontWeight.w800)),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(controller: titleCtrl, decoration: InputDecoration(labelText: 'Titre', border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)))),
              const SizedBox(height: 8),
              TextField(controller: msgCtrl, maxLines: 3, decoration: InputDecoration(labelText: 'Message', border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)))),
            ],
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Annuler')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF6C3EB8)),
            onPressed: () async {
              final jwt = await _jwt();
              if (jwt == null) return;
              await http.post(
                Uri.parse('${AuthService.baseUrl}/intercommunality/actors/${actor['id']}/notify'),
                headers: _headers(jwt),
                body: json.encode({'title': titleCtrl.text.trim(), 'message': msgCtrl.text.trim()}),
              );
              if (ctx.mounted) Navigator.pop(ctx);
              if (mounted) {
                ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('✅ Message envoyé'), backgroundColor: Colors.green));
              }
            },
            child: const Text('Envoyer', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  Future<void> _verifyPoint(int id, bool verified) async {
    final jwt = await _jwt();
    if (jwt == null) return;
    await http.put(
      Uri.parse('${AuthService.baseUrl}/intercommunality/collection-points/$id/verify?verified=$verified'),
      headers: _headers(jwt),
    );
    _loadPoints();
  }

  Future<void> _deleteInstruction(int id) async {
    final jwt = await _jwt();
    if (jwt == null) return;
    await http.delete(
      Uri.parse('${AuthService.baseUrl}/intercommunality/instructions/$id'),
      headers: _headers(jwt),
    );
    _loadInstructions();
  }

  Future<void> _markReplyRead(Map<String, dynamic> reply) async {
    if (reply['is_read'] == true) return;
    final jwt = await _jwt();
    if (jwt == null) return;
    final id = reply['id'];
    await http.put(
      Uri.parse('${AuthService.baseUrl}/notifications/$id/read'),
      headers: _headers(jwt),
    );
    setState(() => reply['is_read'] = true);
    _loadReplies();
  }

  Future<void> _createAssignment({
    int? zoneId,
    List<int>? collectionPointIds,
    int? collectionPointId, // rétro-compat singulier
    int? collectorId,
    int? groupId,
    String? message,
    required String priority,
  }) async {
    final jwt = await _jwt();
    if (jwt == null) return;
    final bodyData = {
      if (zoneId != null) 'zone_id': zoneId,
      // Mode multi-centres
      if (collectionPointIds != null && collectionPointIds.isNotEmpty)
        'collection_point_ids': collectionPointIds,
      // Rétro-compat
      if (collectionPointId != null && collectionPointIds == null)
        'collection_point_id': collectionPointId,
      if (collectorId != null) 'collector_id': collectorId,
      if (groupId != null) 'group_id': groupId,
      'mission_message': message,
      'priority': priority,
    };
    final res = await http.post(
      Uri.parse('${AuthService.baseUrl}/intercommunality/assignments'),
      headers: _headers(jwt),
      body: json.encode(bodyData),
    );
    if (res.statusCode == 201 && mounted) {
      final body = json.decode(utf8.decode(res.bodyBytes));
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('✅ ${body['message']}'), backgroundColor: Colors.green));
      _loadPilotage();
    } else if (mounted) {
      try {
        final err = json.decode(utf8.decode(res.bodyBytes));
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('❌ ${err['detail'] ?? 'Erreur lors de l\'affectation'}'), backgroundColor: Colors.red));
      } catch (_) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('❌ Erreur de communication avec le serveur'), backgroundColor: Colors.red));
      }
    }
  }

  Future<void> _updateAssignmentStatus(int id, String status) async {
    final jwt = await _jwt();
    if (jwt == null) return;
    await http.patch(
      Uri.parse('${AuthService.baseUrl}/intercommunality/assignments/$id/status'),
      headers: _headers(jwt),
      body: json.encode({'status': status}),
    );
    _loadPilotage();
  }

  Future<void> _deleteAssignment(int id) async {
    final jwt = await _jwt();
    if (jwt == null) return;
    await http.delete(
      Uri.parse('${AuthService.baseUrl}/intercommunality/assignments/$id'),
      headers: _headers(jwt),
    );
    _loadPilotage();
  }

  Future<void> _notifyActors(List<String> roles, String title, String msg) async {
    final jwt = await _jwt();
    if (jwt == null) return;
    final queryParams = '${roles.map((r) => 'roles=$r').join('&')}&title=${Uri.encodeQueryComponent(title)}&message=${Uri.encodeQueryComponent(msg)}';
    final res = await http.post(
      Uri.parse('${AuthService.baseUrl}/intercommunality/actors/notify?$queryParams'),
      headers: _headers(jwt),
    );
    if (res.statusCode == 200 && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('✅ Notification envoyée aux rôles sélectionnés'), backgroundColor: Colors.green));
    }
  }

  Future<void> _createZone(String name, String territory, String description, Color color, {List<int> pointIds = const []}) async {
    final jwt = await _jwt();
    if (jwt == null) return;
    final colorHex = '#${color.value.toRadixString(16).substring(2, 8)}';
    await http.post(
      Uri.parse('${AuthService.baseUrl}/intercommunality/zones'),
      headers: _headers(jwt),
      body: json.encode({
        'name': name,
        'territory': territory,
        'description': description.isEmpty ? null : description,
        'color_hex': colorHex,
        if (pointIds.isNotEmpty) 'collection_point_ids': pointIds,
      }),
    );
    _loadPilotage();
  }

  Future<void> _deleteZone(int id, String name) async {
    final jwt = await _jwt();
    if (jwt == null) return;
    await http.delete(
      Uri.parse('${AuthService.baseUrl}/intercommunality/zones/$id'),
      headers: _headers(jwt),
    );
    _loadPilotage();
  }

  // ── BUILD PRINCIPAL ──────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    super.build(context);
    return Scaffold(
      backgroundColor: const Color(0xFFF5F7FA),
      body: NestedScrollView(
        headerSliverBuilder: (ctx, _) => [
          SliverToBoxAdapter(child: _buildHeader()),
          SliverToBoxAdapter(child: _buildDashboardCards()),
          SliverPersistentHeader(
            pinned: true,
            delegate: _TabHeaderDelegate(
              TabBar(
                controller: _tabCtrl,
                isScrollable: false,
                labelColor: const Color(0xFF6C3EB8),
                unselectedLabelColor: AppTheme.textMuted,
                indicatorColor: const Color(0xFF6C3EB8),
                indicatorWeight: 3,
                labelStyle: GoogleFonts.outfit(fontWeight: FontWeight.w800, fontSize: 12),
                unselectedLabelStyle: GoogleFonts.outfit(fontWeight: FontWeight.w500, fontSize: 12),
                tabs: const [
                  Tab(icon: Icon(Icons.rule_rounded, size: 18),          text: 'Consignes'),
                  Tab(icon: Icon(Icons.location_city_rounded, size: 18), text: 'Points'),
                  Tab(icon: Icon(Icons.groups_rounded, size: 18),        text: 'Acteurs'),
                  Tab(icon: Icon(Icons.forum_rounded, size: 18),         text: 'Réponses'),
                  Tab(icon: Icon(Icons.route_rounded, size: 18),         text: 'Pilotage'),
                ],
              ),
            ),
          ),
        ],
        body: TabBarView(
          controller: _tabCtrl,
          children: [
            _buildF1Consignes(),
            _buildF2Points(),
            _buildF3Acteurs(),
            _buildF4Reponses(),
            _buildF5Pilotage(),
          ],
        ),
      ),
      floatingActionButton: _buildFAB(),
    );
  }

  // ── HEADER ───────────────────────────────────────────────────────────────
  Widget _buildHeader() {
    return StreamBuilder<AdminStatsSnapshot>(
      stream: FirebaseAdminStatsService().watchAdminStats(),
      builder: (context, snapshot) {
        final stats = snapshot.data ?? const AdminStatsSnapshot();
        final f1 = (_dashboard?['f1_consignes'] as Map?) ?? {};
        final f3 = (_dashboard?['f3_acteurs'] as Map?) ?? {};
        final f2 = (_dashboard?['f2_points_de_collecte'] as Map?) ?? {};
        
        final totalScans = stats.totalScans > 0 ? stats.totalScans : (f1['total_scans'] ?? 0);
        final totalUsers = stats.totalUsers > 0 ? stats.totalUsers : (f3['total_users'] ?? 0);

        return Container(
          padding: EdgeInsets.fromLTRB(20, MediaQuery.of(context).padding.top + 12, 20, 16),
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              colors: [Color(0xFF1E0442), Color(0xFF4A1F8A), Color(0xFF7B3FC4)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          L10n.tr('Coordination Territoriale'),
                          style: GoogleFonts.outfit(color: Colors.white, fontSize: 22, fontWeight: FontWeight.w900),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          L10n.tr('Gérez les politiques de tri et les acteurs locaux.'),
                          style: GoogleFonts.inter(color: Colors.white.withOpacity(0.7), fontSize: 12, fontWeight: FontWeight.w500),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(color: Colors.white.withOpacity(0.12), borderRadius: BorderRadius.circular(20)),
                    child: Text('En ligne', style: GoogleFonts.outfit(color: Colors.greenAccent, fontSize: 11, fontWeight: FontWeight.w600)),

                  ),

                  const SizedBox(width: 8),

                  Stack(

                    clipBehavior: Clip.none,

                    children: [

                      GestureDetector(

                        onTap: () => Navigator.push(context,

                          MaterialPageRoute(builder: (_) => const MessagingScreen())),

                        child: Container(

                          padding: const EdgeInsets.all(7),

                          decoration: BoxDecoration(

                            color: Colors.white.withOpacity(0.15),

                            borderRadius: BorderRadius.circular(10),

                            border: Border.all(color: Colors.white30),

                          ),

                          child: const Icon(Icons.forum_outlined, color: Colors.white, size: 18),

                        ),

                      ),

                      if (_unreadMessages > 0)

                        Positioned(

                          top: -4, right: -4,

                          child: Container(

                            width: 16, height: 16,

                            decoration: const BoxDecoration(

                              color: Color(0xFF00E676), shape: BoxShape.circle),

                            child: Center(

                              child: Text('$_unreadMessages',

                                style: const TextStyle(color: Colors.black,

                                  fontSize: 9, fontWeight: FontWeight.w900)),

                            ),

                          ),

                        ),

                    ],

                  ),

                ],

              ),
              const SizedBox(height: 14),
              Row(
                children: [
                  _headerStat('$totalScans', 'Scans', Icons.qr_code_scanner_rounded),
                  _headerDivider(),
                  _headerStat('$totalUsers', 'Acteurs', Icons.people_alt_rounded),
                  _headerDivider(),
                  _headerStat('${f2['verified'] ?? 0}/${f2['total'] ?? 0}', 'Points', Icons.location_city_rounded),
                  _headerDivider(),
                  _headerStat(
                    '${_assignments.where((a) => a['status'] == 'pending' || a['status'] == 'in_progress').length}',
                    'Missions',
                    Icons.route_rounded,
                  ),
                ],
              ),
            ],
          ),
        ).animate().fadeIn(duration: 300.ms);
      },
    );
  }

  Widget _headerStat(String value, String label, IconData icon) {
    return Expanded(
      child: Column(
        children: [
          Icon(icon, color: Colors.white.withOpacity(0.6), size: 16),
          const SizedBox(height: 4),
          Text(value, style: GoogleFonts.outfit(color: Colors.white, fontSize: 15, fontWeight: FontWeight.w900)),
          Text(label, style: GoogleFonts.inter(color: Colors.white.withOpacity(0.6), fontSize: 9, fontWeight: FontWeight.w500), maxLines: 1, overflow: TextOverflow.ellipsis),
        ],
      ),
    );
  }

  Widget _headerDivider() {
    return Container(height: 24, width: 1, color: Colors.white.withOpacity(0.15));
  }

  // ── F1 : UI Consignes ────────────────────────────────────────────────────
  Widget _buildF1Consignes() {
    if (_loadingInstructions && _instructions.isEmpty) {
      return const Center(child: CircularProgressIndicator());
    }

    final filtered = _instructions.where((instr) {
      final wasteOk = _f1FilterWasteType.isEmpty ||
          (instr['waste_type'] ?? '').toString().toLowerCase().contains(_f1FilterWasteType.toLowerCase());
      final terrOk = _f1FilterTerritory.isEmpty ||
          (instr['territory'] ?? '').toString().toLowerCase().contains(_f1FilterTerritory.toLowerCase());
      final activeOk = _f1FilterActive == null || instr['is_active'] == _f1FilterActive;
      return wasteOk && terrOk && activeOk;
    }).toList();

    return RefreshIndicator(
      onRefresh: _loadInstructions,
      child: Column(
        children: [
          Container(
            color: Colors.grey.shade50,
            padding: const EdgeInsets.fromLTRB(12, 10, 12, 6),
            child: Column(
              children: [
                Row(
                  children: [
                    Expanded(
                      child: DropdownButtonFormField<String>(
                        value: _f1FilterWasteType.isEmpty ? null : _f1FilterWasteType,
                        isExpanded: true,
                        decoration: InputDecoration(
                          hintText: 'Déchet...',
                          prefixIcon: const Icon(Icons.recycling_rounded, size: 20),
                          isDense: true,
                          contentPadding: const EdgeInsets.symmetric(vertical: 8),
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                          filled: true,
                          fillColor: Colors.white,
                        ),
                        selectedItemBuilder: (BuildContext context) {
                          return [
                            const Text('Tous', style: TextStyle(overflow: TextOverflow.ellipsis)),
                            ..._wasteTypesList.map((w) => Text(w, style: const TextStyle(overflow: TextOverflow.ellipsis))),
                          ];
                        },
                        items: [
                          const DropdownMenuItem<String>(value: '', child: Text('Tous les déchets')),
                          ..._wasteTypesList.map((w) => DropdownMenuItem<String>(value: w, child: Text(w))),
                        ],
                        onChanged: (v) => setState(() => _f1FilterWasteType = v ?? ''),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: _filterTerritoryAutocomplete(
                        currentValue: _f1FilterTerritory,
                        onChanged: (v) => setState(() => _f1FilterTerritory = v),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          Expanded(
            child: filtered.isEmpty
                ? _emptyState(icon: Icons.rule_folder_rounded, title: 'Aucune consigne', sub: 'Modifiez vos filtres ou créez-en une.')
                : ListView.builder(
                    padding: const EdgeInsets.fromLTRB(12, 6, 12, 100),
                    itemCount: filtered.length,
                    itemBuilder: (ctx, i) => _instructionCard(filtered[i]),
                  ),
          ),
        ],
      ),
    );
  }

  Widget _filterTerritoryAutocomplete({required String currentValue, required ValueChanged<String> onChanged}) {
    return Autocomplete<String>(
      initialValue: TextEditingValue(text: currentValue),
      optionsBuilder: (TextEditingValue textEditingValue) {
        if (textEditingValue.text.isEmpty) {
          return const Iterable<String>.empty();
        }
        return _territoryCitiesMap.keys.where((String option) {
          return option.toLowerCase().contains(textEditingValue.text.toLowerCase());
        });
      },
      onSelected: (String selection) {
        onChanged(selection);
      },
      fieldViewBuilder: (context, textEditingController, focusNode, onFieldSubmitted) {
        return TextField(
          controller: textEditingController,
          focusNode: focusNode,
          decoration: InputDecoration(
            hintText: 'Territoire...',
            prefixIcon: const Icon(Icons.map_outlined, size: 20),
            isDense: true,
            contentPadding: const EdgeInsets.symmetric(vertical: 8),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
            filled: true,
            fillColor: Colors.white,
          ),
        );
      },
    );
  }

  Widget _instructionCard(Map<String, dynamic> instr) {
    final active = instr['is_active'] == true;
    final waste = instr['waste_type'] ?? 'Autre';
    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(color: const Color(0xFF6C3EB8).withOpacity(0.08), borderRadius: BorderRadius.circular(8)),
                  child: Text(waste, style: GoogleFonts.outfit(fontWeight: FontWeight.bold, fontSize: 10, color: const Color(0xFF6C3EB8))),
                ),
                Switch.adaptive(
                  value: active,
                  activeColor: const Color(0xFF6C3EB8),
                  onChanged: (v) async {
                    final jwt = await _jwt();
                    if (jwt == null) return;
                    await http.put(
                      Uri.parse('${AuthService.baseUrl}/intercommunality/instructions/${instr['id']}'),
                      headers: _headers(jwt),
                      body: json.encode({'is_active': v}),
                    );
                    _loadInstructions();
                  },
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(instr['title'] ?? 'Consigne', style: GoogleFonts.outfit(fontWeight: FontWeight.bold, fontSize: 14)),
            const SizedBox(height: 4),
            Text(instr['instruction'] ?? '', style: GoogleFonts.inter(fontSize: 12, color: Colors.grey.shade700)),
            const SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('${instr['city'] ?? ''} · ${instr['territory'] ?? ''}', style: GoogleFonts.inter(fontSize: 10, color: Colors.grey)),
                Row(
                  children: [
                    IconButton(
                      icon: const Icon(Icons.edit_outlined, size: 18, color: Colors.blue),
                      onPressed: () => _showEditInstructionDialog(instr),
                    ),
                    IconButton(
                      icon: const Icon(Icons.delete_outline, size: 18, color: Colors.red),
                      onPressed: () => _deleteInstruction(instr['id']),
                    ),
                  ],
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  // ── F2 : UI Points ───────────────────────────────────────────────────────
  Widget _buildF2Points() {
    if (_loadingPoints && _points.isEmpty) {
      return const Center(child: CircularProgressIndicator());
    }

    final filtered = _points.where((p) {
      final query = _f2Search.toLowerCase();
      final name = (p['name'] ?? '').toString().toLowerCase();
      final addr = (p['address'] ?? '').toString().toLowerCase();
      return name.contains(query) || addr.contains(query);
    }).toList();

    const primaryColor = Color(0xFF1A6B3C);

    return RefreshIndicator(
      onRefresh: _loadPoints,
      color: primaryColor,
      child: Column(
        children: [
          Container(
            color: Colors.white,
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
            child: TextField(
              decoration: InputDecoration(
                hintText: 'Rechercher un point de collecte…',
                prefixIcon: const Icon(Icons.search, size: 20),
                isDense: true,
                contentPadding: const EdgeInsets.symmetric(vertical: 10),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                filled: true,
                fillColor: Colors.grey.shade50,
              ),
              onChanged: (v) => setState(() => _f2Search = v),
            ),
          ),
          Expanded(
            child: filtered.isEmpty
                ? _emptyState(icon: Icons.location_off_rounded, title: 'Aucun point trouvé', sub: 'Essayez un autre mot clé.', color: primaryColor)
                : ListView.builder(
                    padding: const EdgeInsets.fromLTRB(16, 8, 16, 100),
                    itemCount: filtered.length,
                    itemBuilder: (ctx, i) {
                      final p = filtered[i];
                      final isVerified = p['is_verified'] == true;
                      return Card(
                        margin: const EdgeInsets.only(bottom: 12),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                        elevation: 1,
                        child: Padding(
                          padding: const EdgeInsets.all(14),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Container(
                                padding: const EdgeInsets.all(10),
                                decoration: BoxDecoration(color: primaryColor.withOpacity(0.08), borderRadius: BorderRadius.circular(12)),
                                child: const Icon(Icons.location_on, color: primaryColor, size: 22),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(p['name'] ?? 'Point de collecte', style: GoogleFonts.outfit(fontWeight: FontWeight.w800, fontSize: 14)),
                                    const SizedBox(height: 4),
                                    Row(
                                      children: [
                                        const Icon(Icons.pin_drop_outlined, size: 12, color: Colors.grey),
                                        const SizedBox(width: 4),
                                        Expanded(
                                          child: Text(
                                            p['address'] ?? 'Sans adresse',
                                            style: GoogleFonts.inter(fontSize: 11, color: Colors.grey.shade600),
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 6),
                                    if (p['waste_type'] != null)
                                      Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                        decoration: BoxDecoration(color: Colors.grey.shade100, borderRadius: BorderRadius.circular(6)),
                                        child: Text(
                                          p['waste_type'],
                                          style: GoogleFonts.inter(fontSize: 10, color: Colors.grey.shade700, fontWeight: FontWeight.bold),
                                        ),
                                      ),
                                  ],
                                ),
                              ),
                              const SizedBox(width: 8),
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.end,
                                children: [
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                    decoration: BoxDecoration(
                                      color: isVerified ? Colors.green.shade50 : Colors.amber.shade50,
                                      borderRadius: BorderRadius.circular(12),
                                      border: Border.all(color: isVerified ? Colors.green.shade200 : Colors.amber.shade200),
                                    ),
                                    child: Text(
                                      isVerified ? 'Vérifié' : 'Non vérifié',
                                      style: GoogleFonts.inter(fontSize: 9, fontWeight: FontWeight.bold, color: isVerified ? Colors.green.shade700 : Colors.amber.shade800),
                                    ),
                                  ),
                                  const SizedBox(height: 12),
                                  OutlinedButton(
                                    style: OutlinedButton.styleFrom(
                                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                                      minimumSize: Size.zero,
                                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                                      side: BorderSide(color: isVerified ? Colors.amber.shade600 : Colors.green.shade600),
                                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                                    ),
                                    onPressed: () => _verifyPoint(p['id'], !isVerified),
                                    child: Text(
                                      isVerified ? 'Révoquer' : 'Vérifier',
                                      style: GoogleFonts.outfit(fontSize: 10, fontWeight: FontWeight.bold, color: isVerified ? Colors.amber.shade800 : Colors.green.shade700),
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }

  // ── F3 : UI Acteurs ──────────────────────────────────────────────────────
  Widget _buildF3Acteurs() {
    if (_loadingActors && _actors.isEmpty) {
      return const Center(child: CircularProgressIndicator());
    }

    final filteredActors = _f3FilterRole.isEmpty
        ? _actors
        : _actors.where((a) => (a['role'] ?? '') == _f3FilterRole).toList();

    return RefreshIndicator(
      onRefresh: () async {
        await _loadActors();
        await _loadCustomGroups();
      },
      child: CustomScrollView(
        slivers: [
          SliverToBoxAdapter(
            child: Container(
              color: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              child: Row(
                children: [
                  Expanded(
                    child: DropdownButtonFormField<String>(
                      value: _f3FilterRole.isEmpty ? null : _f3FilterRole,
                      decoration: InputDecoration(
                        hintText: 'Rôle...',
                        prefixIcon: const Icon(Icons.filter_list_rounded, size: 20),
                        isDense: true,
                        contentPadding: const EdgeInsets.symmetric(vertical: 8),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                      items: const [
                        DropdownMenuItem<String>(value: '', child: Text('Tous les rôles')),
                        DropdownMenuItem<String>(value: 'pointManager', child: Text('Gestionnaires')),
                        DropdownMenuItem<String>(value: 'collector', child: Text('Collecteurs')),
                        DropdownMenuItem<String>(value: 'educator', child: Text('Éducateurs')),
                      ],
                      onChanged: (v) => setState(() => _f3FilterRole = v ?? ''),
                    ),
                  ),
                  const SizedBox(width: 8),
                  TextButton.icon(
                    onPressed: () => setState(() => _showGroups = !_showGroups),
                    icon: Icon(_showGroups ? Icons.person_outline_rounded : Icons.group_work_outlined),
                    label: Text(_showGroups ? 'Acteurs' : 'Groupes', style: GoogleFonts.outfit(fontWeight: FontWeight.bold)),
                  ),
                  const SizedBox(width: 8),
                  IconButton(
                    onPressed: _showNotifyActorsDialog,
                    icon: const Icon(Icons.notifications_active_outlined, color: Color(0xFF6C3EB8)),
                    tooltip: 'Notifier les acteurs',
                  ),
                ],
              ),
            ),
          ),
          if (_showGroups)
            _customGroups.isEmpty
                ? SliverFillRemaining(child: _emptyState(icon: Icons.groups_rounded, title: 'Aucun groupe', sub: 'Créez-en un avec le bouton FAB.'))
                : SliverPadding(
                    padding: const EdgeInsets.fromLTRB(16, 8, 16, 100),
                    sliver: SliverList(
                      delegate: SliverChildBuilderDelegate(
                        (ctx, i) => _customGroupCard(_customGroups[i]),
                        childCount: _customGroups.length,
                      ),
                    ),
                  )
          else
            filteredActors.isEmpty
                ? SliverFillRemaining(child: _emptyState(icon: Icons.person_off_rounded, title: 'Aucun acteur', sub: 'Aucun acteur ne correspond.'))
                : SliverPadding(
                    padding: const EdgeInsets.fromLTRB(16, 8, 16, 100),
                    sliver: SliverList(
                      delegate: SliverChildBuilderDelegate(
                        (ctx, i) => _actorCard(filteredActors[i]),
                        childCount: filteredActors.length,
                      ),
                    ),
                  ),
        ],
      ),
    );
  }

  Widget _customGroupCard(Map<String, dynamic> group) {
    final memberCount = (group['member_ids'] as List?)?.length ?? 0;
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: ExpansionTile(
        title: Text(group['name'] ?? 'Groupe', style: GoogleFonts.outfit(fontWeight: FontWeight.w800, color: const Color(0xFF6C3EB8))),
        subtitle: Text('$memberCount membres', style: GoogleFonts.inter(fontSize: 11, color: Colors.grey)),
        children: [
          Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (group['description'] != null && group['description'].toString().isNotEmpty) ...[
                  Text(group['description'], style: GoogleFonts.inter(fontSize: 12, color: Colors.grey.shade700)),
                  const SizedBox(height: 12),
                ],
                ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF6C3EB8),
                    minimumSize: const Size.fromHeight(40),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                  onPressed: () => _notifyCustomGroup(group['id'], group['name']),
                  icon: const Icon(Icons.send_rounded, color: Colors.white, size: 14),
                  label: Text('Notifier le groupe', style: GoogleFonts.outfit(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 12)),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _actorCard(Map<String, dynamic> actor) {
    final role = actor['role'] as String? ?? '';
    Color roleColor;
    IconData roleIcon;
    switch (role) {
      case 'pointManager': roleColor = const Color(0xFF2980B9); roleIcon = Icons.manage_accounts_rounded; break;
      case 'collector':    roleColor = const Color(0xFF27AE60); roleIcon = Icons.local_shipping_rounded;  break;
      case 'educator':     roleColor = const Color(0xFFE67E22); roleIcon = Icons.school_rounded;           break;
      default:             roleColor = AppTheme.textMuted;      roleIcon = Icons.person_rounded;
    }
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16), boxShadow: AppTheme.tightShadow),
      child: Row(
        children: [
          Container(
            width: 40, height: 40,
            decoration: BoxDecoration(color: roleColor.withOpacity(0.1), borderRadius: BorderRadius.circular(12)),
            child: Icon(roleIcon, color: roleColor, size: 20),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(actor['full_name'] ?? 'Acteur', style: GoogleFonts.outfit(fontSize: 14, fontWeight: FontWeight.w800, color: AppTheme.deepSlate)),
                Text(actor['email'] ?? '', style: GoogleFonts.outfit(fontSize: 11, color: AppTheme.textMuted), maxLines: 1, overflow: TextOverflow.ellipsis),
              ],
            ),
          ),
          IconButton(
            icon: const Icon(Icons.send_rounded, color: Color(0xFF6C3EB8), size: 18),
            onPressed: () => _notifyIndividualActor(actor),
          ),
        ],
      ),
    ).animate().fadeIn().slideY(begin: 0.05);
  }

  // ── F4 : UI Réponses ─────────────────────────────────────────────────────
  Widget _buildF4Reponses() {
    if (_loadingReplies && _replies.isEmpty) {
      return const Center(child: CircularProgressIndicator());
    }
    return RefreshIndicator(
      onRefresh: _loadReplies,
      child: _replies.isEmpty
          ? _emptyState(icon: Icons.forum_outlined, title: 'Aucune réponse', sub: "Les réponses s'afficheront ici.")
          : ListView.builder(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 100),
              itemCount: _replies.length,
              itemBuilder: (ctx, i) => _replyCard(_replies[i], i),
            ),
    );
  }

  Widget _replyCard(Map<String, dynamic> reply, int index) {
    final isRead   = reply['is_read'] == true;
    final fromUser = reply['from_user_name'] ?? 'Acteur';
    final body     = reply['body'] ?? '';
    final time     = reply['created_at'] != null ? _formatRelativeTime(reply['created_at']) : '';
    const color = Color(0xFF6C3EB8);

    return GestureDetector(
      onTap: () => _markReplyRead(reply),
      child: Container(
        margin: const EdgeInsets.only(bottom: 10),
        decoration: BoxDecoration(
          color: isRead ? Colors.white : color.withOpacity(0.04),
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: isRead ? Colors.grey.shade100 : color.withOpacity(0.2)),
          boxShadow: isRead ? [] : [BoxShadow(color: color.withOpacity(0.08), blurRadius: 12, offset: const Offset(0, 4))],
        ),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 40, height: 40,
                decoration: BoxDecoration(gradient: LinearGradient(colors: [color.withOpacity(0.2), color.withOpacity(0.1)]), borderRadius: BorderRadius.circular(12)),
                child: Center(
                  child: Text(fromUser.isNotEmpty ? fromUser[0].toUpperCase() : '?', style: GoogleFonts.outfit(fontWeight: FontWeight.bold, color: color, fontSize: 16)),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(fromUser, style: GoogleFonts.outfit(fontWeight: FontWeight.w800, fontSize: 14)),
                        Text(time, style: GoogleFonts.inter(fontSize: 11, color: AppTheme.textMuted)),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Text(body, style: GoogleFonts.inter(fontSize: 12, height: 1.4, color: AppTheme.deepSlate)),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ── F5 : UI Pilotage ─────────────────────────────────────────────────────
  Widget _buildF5Pilotage() {
    if (_loadingPilotage) {
      return const Center(child: CircularProgressIndicator(color: Color(0xFF1A6B3C)));
    }
    return RefreshIndicator(
      onRefresh: _loadPilotage,
      color: const Color(0xFF1A6B3C),
      child: CustomScrollView(
        slivers: [
          SliverPadding(
            padding: const EdgeInsets.all(16),
            sliver: SliverList(
              delegate: SliverChildBuilderDelegate(
                (ctx, i) {
                  final zone = _zones[i];
                  final activeCount = _assignments.where((a) => a['zone_id'] == zone['id'] && a['status'] != 'done').length;
                  return Card(
                    margin: const EdgeInsets.only(bottom: 12),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                    child: ListTile(
                      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                      leading: CircleAvatar(
                        backgroundColor: const Color(0xFF1A6B3C).withOpacity(0.15),
                        child: const Icon(Icons.map_outlined, color: Color(0xFF1A6B3C)),
                      ),
                      title: Text(zone['name'] ?? '', style: GoogleFonts.outfit(fontWeight: FontWeight.w800)),
                      subtitle: Text('${zone['territory'] ?? ''} · $activeCount mission(s) active(s)', style: GoogleFonts.outfit(fontSize: 12, color: AppTheme.textMuted)),
                      trailing: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          IconButton(
                            icon: const Icon(Icons.person_add_rounded, color: Color(0xFF1A6B3C)),
                            onPressed: () => _showAssignCollectorDialog(zone),
                          ),
                          IconButton(
                            icon: const Icon(Icons.delete_outline_rounded, color: Colors.red),
                            onPressed: () => _deleteZone(zone['id'], zone['name']),
                          ),
                        ],
                      ),
                    ),
                  );
                },
                childCount: _zones.length,
              ),
            ),
          ),
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              child: Text('Missions et affectations actives', style: GoogleFonts.outfit(fontWeight: FontWeight.bold, fontSize: 14)),
            ),
          ),
          _assignments.isEmpty
              ? const SliverFillRemaining(child: Center(child: Text('Aucune mission en cours', style: TextStyle(color: Colors.grey))))
              : SliverPadding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  sliver: SliverList(
                    delegate: SliverChildBuilderDelegate(
                      (ctx, idx) {
                        final a = _assignments[idx];
                        final status = a['status'] ?? 'pending';
                        final priority = a['priority'] ?? 'normal';
                        final msg = a['mission_message'] ?? '';
                        return Card(
                          margin: const EdgeInsets.only(bottom: 12),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                          child: Padding(
                            padding: const EdgeInsets.all(14),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  children: [
                                    Text(
                                      a['zone_name'] != null
                                          ? 'Zone: ${a['zone_name']}'
                                          : 'Centre: ${a['collection_point_name'] ?? ''}',
                                      style: GoogleFonts.outfit(fontWeight: FontWeight.bold, fontSize: 13),
                                    ),
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                      decoration: BoxDecoration(
                                        color: priority == 'urgent' ? Colors.red.shade50 : Colors.blue.shade50,
                                        borderRadius: BorderRadius.circular(8),
                                      ),
                                      child: Text(priority.toString().toUpperCase(), style: TextStyle(color: priority == 'urgent' ? Colors.red : Colors.blue, fontWeight: FontWeight.bold, fontSize: 9)),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 6),
                                Text(
                                  a['collector_name'] != null
                                      ? 'Affecté à : ${a['collector_name']}'
                                      : 'Groupe : ${a['group_name'] ?? ''}',
                                  style: const TextStyle(fontSize: 12, color: Colors.grey),
                                ),
                                if (msg.isNotEmpty) ...[
                                  const SizedBox(height: 6),
                                  Text('Message : $msg', style: const TextStyle(fontSize: 12, fontStyle: FontStyle.italic)),
                                ],
                                const SizedBox(height: 10),
                                Row(
                                  children: [
                                    if (status == 'pending')
                                      _actionBtn('En cours', Colors.blue, () => _updateAssignmentStatus(a['id'], 'in_progress')),
                                    if (status == 'in_progress')
                                      _actionBtn('Terminer', Colors.green, () => _updateAssignmentStatus(a['id'], 'done')),
                                    const SizedBox(width: 8),
                                    _actionBtn('Annuler', Colors.red, () => _deleteAssignment(a['id'])),
                                  ],
                                ),
                              ],
                            ),
                          ),
                        );
                      },
                      childCount: _assignments.length,
                    ),
                  ),
                ),
        ],
      ),
    );
  }

  Widget _actionBtn(String label, Color color, VoidCallback onTap) {
    return ElevatedButton(
      style: ElevatedButton.styleFrom(
        backgroundColor: color,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
      onPressed: onTap,
      child: Text(label, style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold)),
    );
  }

  // ── FAB & Dialogs ────────────────────────────────────────────────────────
  Widget? _buildFAB() {
    Widget? fab;
    if (_tabCtrl.index == 0) {
      fab = FloatingActionButton.extended(
        heroTag: 'fab_intercommunality_consigne',
        backgroundColor: const Color(0xFF6C3EB8),
        icon: const Icon(Icons.add_rounded, color: Colors.white),
        label: Text('Nouvelle consigne', style: GoogleFonts.outfit(color: Colors.white, fontWeight: FontWeight.w700)),
        onPressed: _showAddInstructionDialog,
      );
    }
    if (_tabCtrl.index == 2 && _showGroups) {
      fab = FloatingActionButton.extended(
        heroTag: 'fab_intercommunality_groupe',
        backgroundColor: const Color(0xFF6C3EB8),
        icon: const Icon(Icons.group_add_rounded, color: Colors.white),
        label: Text('Nouveau groupe', style: GoogleFonts.outfit(color: Colors.white, fontWeight: FontWeight.w700)),
        onPressed: _showCreateGroupDialog,
      );
    }
    if (_tabCtrl.index == 4) {
      fab = FloatingActionButton.extended(
        heroTag: 'fab_intercommunality_affecter',
        backgroundColor: const Color(0xFF1A6B3C),
        icon: const Icon(Icons.add_rounded, color: Colors.white),
        label: Text('Affecter & Piloter', style: GoogleFonts.outfit(color: Colors.white, fontWeight: FontWeight.w700)),
        onPressed: () {
          showModalBottomSheet(
            context: context,
            backgroundColor: Colors.transparent,
            builder: (ctx) => Container(
              decoration: const BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
              ),
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Center(child: Container(width: 40, height: 4, decoration: BoxDecoration(color: Colors.grey.shade300, borderRadius: BorderRadius.circular(2)))),
                  const SizedBox(height: 16),
                  Text('Actions de Pilotage', style: GoogleFonts.outfit(fontSize: 18, fontWeight: FontWeight.w900)),
                  const SizedBox(height: 16),
                  ListTile(
                    leading: CircleAvatar(
                      backgroundColor: const Color(0xFF1A6B3C).withOpacity(0.1),
                      child: const Icon(Icons.assignment_ind_rounded, color: Color(0xFF1A6B3C)),
                    ),
                    title: Text('Affecter une mission', style: GoogleFonts.outfit(fontWeight: FontWeight.bold)),
                    subtitle: Text('Affecter un collecteur ou groupe à un centre ou une zone', style: GoogleFonts.outfit(fontSize: 12, color: Colors.grey)),
                    onTap: () {
                      Navigator.pop(ctx);
                      _showAssignMissionDialog();
                    },
                  ),
                  const Divider(),
                  ListTile(
                    leading: CircleAvatar(
                      backgroundColor: Colors.blue.withOpacity(0.1),
                      child: const Icon(Icons.add_location_alt_rounded, color: Colors.blue),
                    ),
                    title: Text('Créer une nouvelle zone', style: GoogleFonts.outfit(fontWeight: FontWeight.bold)),
                    subtitle: Text('Ajouter une zone territoriale de tri', style: GoogleFonts.outfit(fontSize: 12, color: Colors.grey)),
                    onTap: () {
                      Navigator.pop(ctx);
                      _showCreateZoneDialog();
                    },
                  ),
                  const SizedBox(height: 12),
                ],
              ),
            ),
          );
        },
      );
    }
    
    if (fab != null) {
      return Padding(
        padding: const EdgeInsets.only(bottom: 76),
        child: fab,
      );
    }
    return null;
  }


  Future<void> _showAddInstructionDialog() async {
    final territoryCtrl = TextEditingController();
    final cityCtrl = TextEditingController();
    final wasteTypeCtrl = TextEditingController();
    final titleCtrl = TextEditingController();
    final instructionCtrl = TextEditingController();

    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => _instructionForm(
        title: 'Nouvelle consigne de tri',
        territoryCtrl: territoryCtrl,
        cityCtrl: cityCtrl,
        wasteTypeCtrl: wasteTypeCtrl,
        titleCtrl: titleCtrl,
        instructionCtrl: instructionCtrl,
        onSave: () async {
          final jwt = await _jwt();
          if (jwt == null) return;
          await http.post(
            Uri.parse('${AuthService.baseUrl}/intercommunality/instructions'),
            headers: _headers(jwt),
            body: json.encode({
              'territory':   territoryCtrl.text.trim(),
              'city':        cityCtrl.text.trim().isEmpty ? null : cityCtrl.text.trim(),
              'waste_type':  wasteTypeCtrl.text.trim(),
              'title':       titleCtrl.text.trim(),
              'instruction': instructionCtrl.text.trim(),
              'is_active':   true,
            }),
          );
          _loadInstructions();
          if (ctx.mounted) Navigator.pop(ctx);
        },
      ),
    );
  }

  Future<void> _showEditInstructionDialog(Map<String, dynamic> instr) async {
    final territoryCtrl = TextEditingController(text: instr['territory']);
    final cityCtrl = TextEditingController(text: instr['city'] ?? '');
    final wasteTypeCtrl = TextEditingController(text: instr['waste_type']);
    final titleCtrl = TextEditingController(text: instr['title']);
    final instructionCtrl = TextEditingController(text: instr['instruction']);

    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => _instructionForm(
        title: 'Modifier la consigne',
        territoryCtrl: territoryCtrl,
        cityCtrl: cityCtrl,
        wasteTypeCtrl: wasteTypeCtrl,
        titleCtrl: titleCtrl,
        instructionCtrl: instructionCtrl,
        onSave: () async {
          final jwt = await _jwt();
          if (jwt == null) return;
          await http.put(
            Uri.parse('${AuthService.baseUrl}/intercommunality/instructions/${instr['id']}'),
            headers: _headers(jwt),
            body: json.encode({
              'territory':   territoryCtrl.text.trim(),
              'city':        cityCtrl.text.trim().isEmpty ? null : cityCtrl.text.trim(),
              'waste_type':  wasteTypeCtrl.text.trim(),
              'title':       titleCtrl.text.trim(),
              'instruction': instructionCtrl.text.trim(),
            }),
          );
          _loadInstructions();
          if (ctx.mounted) Navigator.pop(ctx);
        },
      ),
    );
  }

  Widget _instructionForm({
    required String title,
    required TextEditingController territoryCtrl,
    required TextEditingController cityCtrl,
    required TextEditingController wasteTypeCtrl,
    required TextEditingController titleCtrl,
    required TextEditingController instructionCtrl,
    required VoidCallback onSave,
  }) {
    return StatefulBuilder(
      builder: (ctx, setFormState) {
        final currentTerritory = territoryCtrl.text.trim();
        final cities = _territoryCitiesMap[currentTerritory] ?? [];
        
        return Container(
          decoration: const BoxDecoration(color: Colors.white, borderRadius: BorderRadius.vertical(top: Radius.circular(28))),
          padding: EdgeInsets.fromLTRB(24, 20, 24, MediaQuery.of(ctx).viewInsets.bottom + 24),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(child: Container(width: 40, height: 4, decoration: BoxDecoration(color: Colors.grey.shade300, borderRadius: BorderRadius.circular(2)))),
                const SizedBox(height: 16),
                Text(title, style: GoogleFonts.outfit(fontSize: 20, fontWeight: FontWeight.w900, color: AppTheme.deepSlate)),
                const SizedBox(height: 16),
                
                // Territory Autocomplete
                Autocomplete<String>(
                  initialValue: TextEditingValue(text: territoryCtrl.text),
                  optionsBuilder: (TextEditingValue textEditingValue) {
                    return _territoryCitiesMap.keys.where((t) => t.toLowerCase().contains(textEditingValue.text.toLowerCase()));
                  },
                  onSelected: (String val) {
                    setFormState(() {
                      territoryCtrl.text = val;
                      cityCtrl.clear();
                    });
                  },
                  fieldViewBuilder: (ctx2, textEditingController, focusNode, onFieldSubmitted) {
                    return TextField(
                      controller: textEditingController,
                      focusNode: focusNode,
                      decoration: InputDecoration(
                        labelText: 'Territoire (Gouvernorat) *',
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                      onChanged: (val) {
                        setFormState(() {
                          territoryCtrl.text = val;
                        });
                      },
                    );
                  },
                ),
                const SizedBox(height: 12),
                
                // City Dropdown
                DropdownButtonFormField<String>(
                  value: cityCtrl.text.isEmpty ? null : cityCtrl.text,
                  decoration: InputDecoration(
                    labelText: 'Ville *',
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  items: cities.map((c) => DropdownMenuItem<String>(value: c, child: Text(c))).toList(),
                  onChanged: (val) {
                    setFormState(() {
                      cityCtrl.text = val ?? '';
                    });
                  },
                ),
                const SizedBox(height: 12),
                
                // Waste Type Dropdown
                DropdownButtonFormField<String>(
                  value: wasteTypeCtrl.text.isEmpty ? null : wasteTypeCtrl.text,
                  decoration: InputDecoration(
                    labelText: 'Type de déchet *',
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  items: _wasteTypesList.map((w) => DropdownMenuItem<String>(value: w, child: Text(w))).toList(),
                  onChanged: (val) {
                    setFormState(() {
                      wasteTypeCtrl.text = val ?? '';
                    });
                  },
                ),
                const SizedBox(height: 12),
                
                // Title Field
                TextField(
                  controller: titleCtrl,
                  decoration: InputDecoration(
                    labelText: 'Titre de la consigne *',
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                ),
                const SizedBox(height: 12),
                
                // Instruction Field
                TextField(
                  controller: instructionCtrl,
                  maxLines: 4,
                  decoration: InputDecoration(
                    labelText: 'Texte de la consigne *',
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                ),
                const SizedBox(height: 20),
                
                // Save Button
                SizedBox(
                  width: double.infinity,
                  height: 48,
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF6C3EB8),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    onPressed: onSave,
                    child: Text('Enregistrer', style: GoogleFonts.outfit(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16)),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Future<void> _showCreateGroupDialog() async {
    final nameCtrl = TextEditingController();
    final descCtrl = TextEditingController();
    final selectedActorIds = <int>{};

    await showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDlgState) => AlertDialog(
          title: Text("Nouveau groupe d'acteurs", style: GoogleFonts.outfit(fontWeight: FontWeight.w900)),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                TextField(controller: nameCtrl, decoration: const InputDecoration(labelText: 'Nom du groupe *')),
                const SizedBox(height: 8),
                TextField(controller: descCtrl, decoration: const InputDecoration(labelText: 'Description')),
                const SizedBox(height: 16),
                Text('Membres du groupe', style: GoogleFonts.outfit(fontWeight: FontWeight.bold, fontSize: 14)),
                const SizedBox(height: 8),
                if (_actors.isEmpty)
                  Text('Aucun acteur disponible', style: GoogleFonts.inter(color: Colors.grey))
                else
                  Container(
                    height: 200,
                    width: double.maxFinite,
                    decoration: BoxDecoration(border: Border.all(color: Colors.grey.shade300), borderRadius: BorderRadius.circular(12)),
                    child: ListView.builder(
                      itemCount: _actors.length,
                      itemBuilder: (context, idx) {
                        final actor = _actors[idx];
                        final id = actor['id'] as int;
                        final name = actor['full_name'] ?? 'Acteur';
                        final role = actor['role'] ?? '';
                        final isChecked = selectedActorIds.contains(id);
                        return CheckboxListTile(
                          value: isChecked,
                          title: Text(name, style: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.w600)),
                          subtitle: Text(_roleLabel(role).toUpperCase(), style: GoogleFonts.inter(fontSize: 10, color: Colors.grey)),
                          activeColor: const Color(0xFF6C3EB8),
                          onChanged: (val) {
                            setDlgState(() {
                              if (val == true) {
                                selectedActorIds.add(id);
                              } else {
                                selectedActorIds.remove(id);
                              }
                            });
                          },
                        );
                      },
                    ),
                  ),
              ],
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Annuler')),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF6C3EB8),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              onPressed: () async {
                final name = nameCtrl.text.trim();
                if (name.isEmpty) {
                  ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Le nom du groupe est obligatoire'), backgroundColor: Colors.red));
                  return;
                }
                final messenger = ScaffoldMessenger.of(context);
                final jwt = await _jwt();
                if (jwt == null) return;
                final res = await http.post(
                  Uri.parse('${AuthService.baseUrl}/intercommunality/custom-groups'),
                  headers: _headers(jwt),
                  body: json.encode({
                    'name': name,
                    'description': descCtrl.text.trim(),
                    'member_ids': selectedActorIds.toList(),
                  }),
                );
                if (res.statusCode == 201) {
                  _loadCustomGroups();
                  if (ctx.mounted) Navigator.pop(ctx);
                  messenger.showSnackBar(const SnackBar(content: Text('✅ Groupe créé avec succès'), backgroundColor: Colors.green));
                } else {
                  messenger.showSnackBar(const SnackBar(content: Text('❌ Erreur lors de la création du groupe'), backgroundColor: Colors.red));
                }
              },
              child: Text('Créer', style: GoogleFonts.outfit(color: Colors.white, fontWeight: FontWeight.bold)),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _showCreateZoneDialog() async {
    final result = await Navigator.push<Map<String, dynamic>>(
      context,
      MaterialPageRoute(
        builder: (_) => _CreateZoneMapPage(points: _points),
      ),
    );
    if (result != null && mounted) {
      _createZone(
        result['name'] as String,
        result['territory'] as String,
        result['description'] as String,
        result['color'] as Color,
        pointIds: result['pointIds'] as List<int>,
      );
    }
  }

  Future<void> _showAssignCollectorDialog(Map<String, dynamic> zone) async {
    if (_collectors.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Aucun collecteur disponible')));
      return;
    }
    int? selectedCollectorId = _collectors.first['id'] as int?;
    String priority = 'normal';
    final msgCtrl = TextEditingController();

    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setSt) => Container(
          decoration: const BoxDecoration(color: Colors.white, borderRadius: BorderRadius.vertical(top: Radius.circular(28))),
          padding: EdgeInsets.fromLTRB(24, 20, 24, MediaQuery.of(ctx).viewInsets.bottom + 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(child: Container(width: 40, height: 4, decoration: BoxDecoration(color: Colors.grey.shade300, borderRadius: BorderRadius.circular(2)))),
              const SizedBox(height: 16),
              Text('Affecter à : ${zone['name']}', style: GoogleFonts.outfit(fontSize: 18, fontWeight: FontWeight.w900)),
              Text(zone['territory'] ?? '', style: GoogleFonts.outfit(color: AppTheme.textMuted, fontSize: 13)),
              const SizedBox(height: 16),
              Text('Collecteur', style: GoogleFonts.outfit(fontWeight: FontWeight.w700)),
              const SizedBox(height: 6),
              DropdownButtonFormField<int>(
                value: selectedCollectorId,
                decoration: InputDecoration(border: OutlineInputBorder(borderRadius: BorderRadius.circular(12))),
                items: _collectors.map((c) => DropdownMenuItem<int>(
                  value: c['id'] as int,
                  child: Text(c['full_name'] ?? c['email'] ?? 'ID ${c['id']}'),
                )).toList(),
                onChanged: (v) => setSt(() => selectedCollectorId = v),
              ),
              const SizedBox(height: 10),
              Text('Priorité', style: GoogleFonts.outfit(fontWeight: FontWeight.w700)),
              const SizedBox(height: 6),
              Row(
                children: [
                  _priorityChip('normal',  'Normal',  Colors.blue,   priority, (v) => setSt(() => priority = v)),
                  const SizedBox(width: 8),
                  _priorityChip('urgent',  'Urgent',  Colors.orange, priority, (v) => setSt(() => priority = v)),
                ],
              ),
              const SizedBox(height: 10),
              TextField(controller: msgCtrl, maxLines: 3, decoration: InputDecoration(labelText: 'Message de mission (optionnel)', border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)))),
              const SizedBox(height: 20),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF1A6B3C),
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                  ),
                  onPressed: () {
                    if (selectedCollectorId == null) return;
                    Navigator.pop(ctx);
                    _createAssignment(
                      zoneId: zone['id'],
                      collectorId: selectedCollectorId!,
                      message: msgCtrl.text.trim(),
                      priority: priority,
                    );
                  },
                  child: Text('Affecter le collecteur', style: GoogleFonts.outfit(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 16)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _showNotifyActorsDialog() async {
    final selectedRoles = <String>{'pointManager', 'collector', 'educator'};
    final titleCtrl = TextEditingController();
    final msgCtrl = TextEditingController();

    await showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDlgState) => AlertDialog(
          title: Text('Notifier les acteurs', style: GoogleFonts.outfit(fontWeight: FontWeight.w900)),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Rôles cibles', style: GoogleFonts.outfit(fontWeight: FontWeight.w700, fontSize: 13)),
                const SizedBox(height: 6),
                Wrap(
                  spacing: 8,
                  children: ['pointManager', 'collector', 'educator'].map((role) {
                    final isSelected = selectedRoles.contains(role);
                    return FilterChip(
                      label: Text(_roleLabel(role), style: GoogleFonts.outfit(fontSize: 12, fontWeight: isSelected ? FontWeight.bold : FontWeight.normal)),
                      selected: isSelected,
                      onSelected: (v) {
                        setDlgState(() {
                          if (v) {
                            selectedRoles.add(role);
                          } else {
                            selectedRoles.remove(role);
                          }
                        });
                      },
                      selectedColor: const Color(0xFF6C3EB8).withOpacity(0.15),
                      checkmarkColor: const Color(0xFF6C3EB8),
                    );
                  }).toList(),
                ),
                const SizedBox(height: 14),
                TextField(
                  controller: titleCtrl,
                  decoration: InputDecoration(labelText: 'Titre', border: OutlineInputBorder(borderRadius: BorderRadius.circular(12))),
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: msgCtrl,
                  maxLines: 4,
                  decoration: InputDecoration(labelText: 'Message', border: OutlineInputBorder(borderRadius: BorderRadius.circular(12))),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Annuler')),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF6C3EB8),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              onPressed: () {
                if (titleCtrl.text.trim().isEmpty || msgCtrl.text.trim().isEmpty) return;
                if (selectedRoles.isEmpty) {
                  ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Veuillez sélectionner au moins un rôle'), backgroundColor: Colors.red));
                  return;
                }
                Navigator.pop(ctx);
                _notifyActors(selectedRoles.toList(), titleCtrl.text.trim(), msgCtrl.text.trim());
              },
              child: Text('Envoyer', style: GoogleFonts.outfit(color: Colors.white, fontWeight: FontWeight.bold)),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _showAssignMissionDialog() async {
    if (_collectors.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Aucun collecteur disponible')));
      return;
    }

    String targetType = 'points'; // 'zone' or 'points'
    final Set<int> selectedPointIds = {};
    int? selectedZoneId     = _zones.isNotEmpty ? _zones.first['id'] as int? : null;
    int? selectedCollectorId = _collectors.isNotEmpty ? _collectors.first['id'] as int? : null;
    String priority          = 'normal';
    String pointSearch       = '';
    final msgCtrl            = TextEditingController();

    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setSt) {
          final filteredPoints = pointSearch.isEmpty
              ? _points
              : _points.where((p) {
                  final name = (p['name'] ?? '').toLowerCase();
                  final addr = (p['address'] ?? '').toLowerCase();
                  return name.contains(pointSearch.toLowerCase()) ||
                         addr.contains(pointSearch.toLowerCase());
                }).toList();

          return Container(
            decoration: const BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
            ),
            padding: EdgeInsets.fromLTRB(24, 20, 24, MediaQuery.of(ctx).viewInsets.bottom + 24),
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Center(child: Container(width: 40, height: 4, decoration: BoxDecoration(color: Colors.grey.shade300, borderRadius: BorderRadius.circular(2)))),
                  const SizedBox(height: 16),
                  Text('Affecter une mission', style: GoogleFonts.outfit(fontSize: 18, fontWeight: FontWeight.w900)),
                  const SizedBox(height: 16),

                  // ── Type de cible ──────────────────────────────────
                  Text('Cible de la mission', style: GoogleFonts.outfit(fontWeight: FontWeight.w700)),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Expanded(
                        child: GestureDetector(
                          onTap: () => setSt(() => targetType = 'points'),
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 200),
                            padding: const EdgeInsets.symmetric(vertical: 12),
                            decoration: BoxDecoration(
                              color: targetType == 'points' ? const Color(0xFF1A6B3C) : Colors.grey.shade100,
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(color: targetType == 'points' ? const Color(0xFF1A6B3C) : Colors.grey.shade300),
                            ),
                            child: Column(
                              children: [
                                Icon(Icons.location_city_rounded, size: 22, color: targetType == 'points' ? Colors.white : Colors.grey),
                                const SizedBox(height: 4),
                                Text('Centres de tri', style: GoogleFonts.outfit(fontSize: 12, fontWeight: FontWeight.w700, color: targetType == 'points' ? Colors.white : Colors.grey)),
                              ],
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: GestureDetector(
                          onTap: () => setSt(() => targetType = 'zone'),
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 200),
                            padding: const EdgeInsets.symmetric(vertical: 12),
                            decoration: BoxDecoration(
                              color: targetType == 'zone' ? const Color(0xFF1A6B3C) : Colors.grey.shade100,
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(color: targetType == 'zone' ? const Color(0xFF1A6B3C) : Colors.grey.shade300),
                            ),
                            child: Column(
                              children: [
                                Icon(Icons.map_rounded, size: 22, color: targetType == 'zone' ? Colors.white : Colors.grey),
                                const SizedBox(height: 4),
                                Text('Zone existante', style: GoogleFonts.outfit(fontSize: 12, fontWeight: FontWeight.w700, color: targetType == 'zone' ? Colors.white : Colors.grey)),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),

                  // ── Mode Zone ─────────────────────────────────────
                  if (targetType == 'zone') ...[
                    Text('Sélectionner la zone', style: GoogleFonts.outfit(fontWeight: FontWeight.w700)),
                    const SizedBox(height: 6),
                    if (_zones.isEmpty)
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(color: Colors.orange.shade50, borderRadius: BorderRadius.circular(10)),
                        child: Row(children: [
                          Icon(Icons.info_outline, color: Colors.orange.shade700, size: 16),
                          const SizedBox(width: 8),
                          Expanded(child: Text('Aucune zone disponible. Créez-en une d\'abord.', style: GoogleFonts.outfit(fontSize: 12, color: Colors.orange.shade800))),
                        ]),
                      )
                    else
                      DropdownButtonFormField<int>(
                        value: selectedZoneId,
                        decoration: InputDecoration(
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                          contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                        ),
                        items: _zones.map((z) => DropdownMenuItem<int>(
                          value: z['id'] as int,
                          child: Text('${z['name']} · ${z['territory'] ?? ''}', style: GoogleFonts.outfit(fontSize: 13)),
                        )).toList(),
                        onChanged: (v) => setSt(() => selectedZoneId = v),
                      ),
                  ],

                  // ── Mode Centres (multi-checkbox) ──────────────────
                  if (targetType == 'points') ...[
                    Row(
                      children: [
                        Text('Centres de tri', style: GoogleFonts.outfit(fontWeight: FontWeight.w700)),
                        const Spacer(),
                        if (selectedPointIds.isNotEmpty)
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
                            decoration: BoxDecoration(
                              color: const Color(0xFF1A6B3C),
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: Text('${selectedPointIds.length} sélectionné(s)', style: GoogleFonts.outfit(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w700)),
                          ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    // Barre de recherche
                    TextField(
                      decoration: InputDecoration(
                        hintText: 'Rechercher un centre…',
                        hintStyle: GoogleFonts.outfit(fontSize: 13, color: Colors.grey),
                        prefixIcon: const Icon(Icons.search_rounded, size: 18, color: Colors.grey),
                        isDense: true,
                        contentPadding: const EdgeInsets.symmetric(vertical: 10, horizontal: 12),
                        filled: true,
                        fillColor: Colors.grey.shade100,
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                      ),
                      onChanged: (v) => setSt(() => pointSearch = v),
                    ),
                    const SizedBox(height: 8),
                    // Liste checkbox
                    if (_points.isEmpty)
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(color: Colors.red.shade50, borderRadius: BorderRadius.circular(10)),
                        child: Text('Aucun centre de tri disponible.', style: GoogleFonts.outfit(color: Colors.red.shade700, fontSize: 12)),
                      )
                    else
                      Container(
                        constraints: const BoxConstraints(maxHeight: 260),
                        decoration: BoxDecoration(
                          border: Border.all(color: Colors.grey.shade200),
                          borderRadius: BorderRadius.circular(14),
                        ),
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(14),
                          child: ListView.separated(
                            shrinkWrap: true,
                            itemCount: filteredPoints.length,
                            separatorBuilder: (_, __) => Divider(height: 1, color: Colors.grey.shade100),
                            itemBuilder: (_, i) {
                              final p = filteredPoints[i];
                              final id = p['id'] as int;
                              final isChecked = selectedPointIds.contains(id);
                              return InkWell(
                                onTap: () => setSt(() {
                                  if (isChecked) { selectedPointIds.remove(id); }
                                  else { selectedPointIds.add(id); }
                                }),
                                child: Padding(
                                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                                  child: Row(
                                    children: [
                                      AnimatedContainer(
                                        duration: const Duration(milliseconds: 180),
                                        width: 22, height: 22,
                                        decoration: BoxDecoration(
                                          color: isChecked ? const Color(0xFF1A6B3C) : Colors.transparent,
                                          borderRadius: BorderRadius.circular(6),
                                          border: Border.all(
                                            color: isChecked ? const Color(0xFF1A6B3C) : Colors.grey.shade400,
                                            width: 1.5,
                                          ),
                                        ),
                                        child: isChecked
                                            ? const Icon(Icons.check_rounded, color: Colors.white, size: 14)
                                            : null,
                                      ),
                                      const SizedBox(width: 12),
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            Text(p['name'] ?? '', style: GoogleFonts.outfit(fontSize: 13, fontWeight: FontWeight.w600, color: const Color(0xFF1E293B))),
                                            if (p['address'] != null)
                                              Text(p['address'], style: GoogleFonts.outfit(fontSize: 11, color: Colors.grey.shade500), maxLines: 1, overflow: TextOverflow.ellipsis),
                                          ],
                                        ),
                                      ),
                                      if (p['status'] != null)
                                        Container(
                                          padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                                          decoration: BoxDecoration(
                                            color: p['status'] == 'disponible' ? Colors.green.shade50 : Colors.orange.shade50,
                                            borderRadius: BorderRadius.circular(6),
                                          ),
                                          child: Text(
                                            p['status'] == 'disponible' ? '✓' : '⚠',
                                            style: TextStyle(fontSize: 11, color: p['status'] == 'disponible' ? Colors.green.shade700 : Colors.orange.shade700),
                                          ),
                                        ),
                                    ],
                                  ),
                                ),
                              );
                            },
                          ),
                        ),
                      ),
                  ],
                  const SizedBox(height: 16),

                  // ── Collecteur ────────────────────────────────────
                  Text('Collecteur', style: GoogleFonts.outfit(fontWeight: FontWeight.w700)),
                  const SizedBox(height: 6),
                  DropdownButtonFormField<int>(
                    value: selectedCollectorId,
                    decoration: InputDecoration(
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                      prefixIcon: const Icon(Icons.local_shipping_rounded, size: 18, color: Color(0xFF1A6B3C)),
                    ),
                    items: _collectors.map((c) => DropdownMenuItem<int>(
                      value: c['id'] as int,
                      child: Text(c['full_name'] ?? c['email'] ?? 'ID ${c['id']}', style: GoogleFonts.outfit(fontSize: 13)),
                    )).toList(),
                    onChanged: (v) => setSt(() => selectedCollectorId = v),
                  ),
                  const SizedBox(height: 14),

                  // ── Priorité ──────────────────────────────────────
                  Text('Priorité', style: GoogleFonts.outfit(fontWeight: FontWeight.w700)),
                  const SizedBox(height: 6),
                  Row(
                    children: [
                      _priorityChip('normal', 'Normal', Colors.blue, priority, (v) => setSt(() => priority = v)),
                      const SizedBox(width: 8),
                      _priorityChip('urgent', '🚨 Urgent', Colors.red.shade600, priority, (v) => setSt(() => priority = v)),
                    ],
                  ),
                  const SizedBox(height: 14),

                  // ── Message ───────────────────────────────────────
                  TextField(
                    controller: msgCtrl,
                    maxLines: 3,
                    decoration: InputDecoration(
                      labelText: 'Message de mission (optionnel)',
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                  ),
                  const SizedBox(height: 20),

                  // ── Bouton Affecter ───────────────────────────────
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF1A6B3C),
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                      ),
                      icon: const Icon(Icons.check_circle_rounded, color: Colors.white, size: 20),
                      label: Text('Affecter la mission', style: GoogleFonts.outfit(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 15)),
                      onPressed: () {
                        // Validation
                        if (targetType == 'points' && selectedPointIds.isEmpty) {
                          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Sélectionnez au moins un centre de tri'), backgroundColor: Colors.red));
                          return;
                        }
                        if (targetType == 'zone' && selectedZoneId == null) {
                          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Sélectionnez une zone'), backgroundColor: Colors.red));
                          return;
                        }
                        if (selectedCollectorId == null) {
                          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Sélectionnez un collecteur'), backgroundColor: Colors.red));
                          return;
                        }
                        Navigator.pop(ctx);
                        _createAssignment(
                          zoneId:             targetType == 'zone'   ? selectedZoneId : null,
                          collectionPointIds: targetType == 'points' ? selectedPointIds.toList() : null,
                          collectorId:        selectedCollectorId,
                          message:            msgCtrl.text.trim(),
                          priority:           priority,
                        );
                      },
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }


  Widget _priorityChip(String value, String label, Color color, String current, void Function(String) onTap) {
    final selected = current == value;
    return GestureDetector(
      onTap: () => onTap(value),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: selected ? color : Colors.grey.shade100,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: selected ? color : Colors.grey.shade300),
        ),
        child: Text(
          label,
          style: GoogleFonts.outfit(fontSize: 13, fontWeight: FontWeight.w700, color: selected ? Colors.white : AppTheme.textMuted),
        ),
      ),
    );
  }

  // ── Utils & Helper Methods ───────────────────────────────────────────────
  String _formatRelativeTime(String dateStr) {
    try {
      final dt = DateTime.parse(dateStr).toLocal();
      final now = DateTime.now();
      final diff = now.difference(dt);
      if (diff.inSeconds < 60) return "À l'instant";
      if (diff.inMinutes < 60) return 'Il y a ${diff.inMinutes} min';
      if (diff.inHours < 24) return 'Il y a ${diff.inHours} h';
      if (diff.inDays < 7) return 'Il y a ${diff.inDays} j';
      return '${dt.day}/${dt.month}/${dt.year}';
    } catch (_) {
      return '';
    }
  }

  String _roleLabel(String role) {
    switch (role) {
      case 'pointManager': return 'Gestionnaire';
      case 'collector':    return 'Collecteur';
      case 'educator':     return 'Éducateur';
      default:             return role;
    }
  }

}

class _TabHeaderDelegate extends SliverPersistentHeaderDelegate {
  final TabBar tabBar;
  const _TabHeaderDelegate(this.tabBar);

  @override
  double get minExtent => tabBar.preferredSize.height;
  @override
  double get maxExtent => tabBar.preferredSize.height;

  @override
  Widget build(BuildContext context, double shrinkOffset, bool overlapsContent) {
    return Container(color: Colors.white, child: tabBar);
  }

  @override
  bool shouldRebuild(_TabHeaderDelegate oldDelegate) => false;
}

// ─────────────────────────────────────────────────────────────────────────────
// Page plein-écran : création d'une zone avec carte OSM intégrée
// ─────────────────────────────────────────────────────────────────────────────
class _CreateZoneMapPage extends StatefulWidget {
  final List<Map<String, dynamic>> points;
  const _CreateZoneMapPage({required this.points});

  @override
  State<_CreateZoneMapPage> createState() => _CreateZoneMapPageState();
}

class _CreateZoneMapPageState extends State<_CreateZoneMapPage> {
  final _nameCtrl  = TextEditingController();
  final _terrCtrl  = TextEditingController();
  final _descCtrl  = TextEditingController();
  final _mapCtrl   = MapController();
  Color _zoneColor = Colors.green;
  final Set<int> _selectedIds = {};
  bool _mapOnline         = false;
  bool _checkingConnectivity = true;

  static const _colors = [Colors.green, Colors.blue, Colors.orange, Colors.purple, Colors.red];

  @override
  void initState() {
    super.initState();
    _checkConnectivity();
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _terrCtrl.dispose();
    _descCtrl.dispose();
    super.dispose();
  }

  Future<void> _checkConnectivity() async {
    try {
      final s = await Socket.connect('tile.openstreetmap.org', 80,
          timeout: const Duration(seconds: 3));
      s.destroy();
      if (mounted) setState(() { _mapOnline = true; _checkingConnectivity = false; });
    } catch (_) {
      if (mounted) setState(() => _checkingConnectivity = false);
    }
  }

  void _submit() {
    final name = _nameCtrl.text.trim();
    final terr = _terrCtrl.text.trim();
    if (name.isEmpty || terr.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(
          name.isEmpty ? '⚠️ Nom de la zone obligatoire' : '⚠️ Territoire obligatoire',
          style: GoogleFonts.inter(fontWeight: FontWeight.w600),
        ),
        backgroundColor: Colors.red.shade700,
        behavior: SnackBarBehavior.floating,
        duration: const Duration(seconds: 2),
      ));
      return;
    }
    Navigator.pop(context, {
      'name':        name,
      'territory':   terr,
      'description': _descCtrl.text.trim(),
      'color':       _zoneColor,
      'pointIds':    _selectedIds.toList(),
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F7FA),
      appBar: AppBar(
        title: Text('Nouvelle zone de collecte',
            style: GoogleFonts.outfit(fontWeight: FontWeight.w900, color: Colors.white, fontSize: 17)),
        backgroundColor: const Color(0xFF1A6B3C),
        foregroundColor: Colors.white,
        elevation: 0,
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 12, top: 8, bottom: 8),
            child: ElevatedButton(
              onPressed: _submit,
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.white,
                foregroundColor: const Color(0xFF1A6B3C),
                elevation: 0,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                padding: const EdgeInsets.symmetric(horizontal: 16),
              ),
              child: Text('Créer', style: GoogleFonts.outfit(fontWeight: FontWeight.w800, fontSize: 14)),
            ),
          ),
        ],
      ),
      body: Column(
        children: [
          // ── Bande de formulaire compacte ───────────────────────────────
          Container(
            color: Colors.white,
            padding: const EdgeInsets.fromLTRB(16, 10, 16, 10),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Nom + Territoire en ligne
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _nameCtrl,
                        decoration: InputDecoration(
                          labelText: 'Nom *',
                          labelStyle: GoogleFonts.inter(fontSize: 12),
                          prefixIcon: const Icon(Icons.map_outlined, size: 16),
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                          contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
                          isDense: true,
                        ),
                        style: GoogleFonts.inter(fontSize: 13),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: TextField(
                        controller: _terrCtrl,
                        decoration: InputDecoration(
                          labelText: 'Territoire *',
                          labelStyle: GoogleFonts.inter(fontSize: 12),
                          prefixIcon: const Icon(Icons.public_rounded, size: 16),
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                          contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
                          isDense: true,
                        ),
                        style: GoogleFonts.inter(fontSize: 13),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                // Couleur + badge sélectionnés
                Row(
                  children: [
                    Text('Couleur :', style: GoogleFonts.outfit(fontWeight: FontWeight.w700, fontSize: 12)),
                    const SizedBox(width: 8),
                    ..._colors.map((c) {
                      final sel = _zoneColor == c;
                      return GestureDetector(
                        onTap: () => setState(() => _zoneColor = c),
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 150),
                          margin: const EdgeInsets.only(right: 6),
                          width: 24, height: 24,
                          decoration: BoxDecoration(
                            color: c,
                            shape: BoxShape.circle,
                            border: sel ? Border.all(color: Colors.black87, width: 2) : null,
                            boxShadow: sel ? [BoxShadow(color: c.withOpacity(0.5), blurRadius: 6)] : null,
                          ),
                          child: sel ? const Icon(Icons.check, color: Colors.white, size: 13) : null,
                        ),
                      );
                    }),
                    const Spacer(),
                    if (_selectedIds.isNotEmpty)
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
                        decoration: BoxDecoration(
                          color: const Color(0xFF1A6B3C),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(Icons.location_on_rounded, color: Colors.white, size: 12),
                            const SizedBox(width: 4),
                            Text('${_selectedIds.length} centre(s)',
                                style: GoogleFonts.inter(fontSize: 11, color: Colors.white, fontWeight: FontWeight.w600)),
                          ],
                        ),
                      ),
                  ],
                ),
              ],
            ),
          ),
          // ── Carte ou liste hors-ligne ───────────────────────────────
          Expanded(
            child: _checkingConnectivity
                ? const Center(child: CircularProgressIndicator(color: Color(0xFF1A6B3C)))
                : _mapOnline
                    ? _buildMap()
                    : _buildOfflineList(),
          ),
        ],
      ),
    );
  }

  Widget _buildMap() {
    return Stack(
      children: [
        FlutterMap(
          mapController: _mapCtrl,
          options: const MapOptions(
            initialCenter: LatLng(36.8065, 10.1815),
            initialZoom: 8.0,
            minZoom: 5,
            maxZoom: 18,
          ),
          children: [
            TileLayer(
              urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
              userAgentPackageName: 'com.ecorewind.app',
              tileProvider: CancellableNetworkTileProvider(),
              errorTileCallback: (tile, error, stackTrace) {},
            ),
            MarkerLayer(
              markers: widget.points
                  .where((p) => p['lat'] != null && p['lng'] != null)
                  .map((p) {
                final id  = p['id'] as int? ?? 0;
                final lat = (p['lat'] as num).toDouble();
                final lng = (p['lng'] as num).toDouble();
                final sel = _selectedIds.contains(id);
                return Marker(
                  point: LatLng(lat, lng),
                  width: 46,
                  height: 46,
                  child: GestureDetector(
                    onTap: () => setState(() {
                      if (sel) { _selectedIds.remove(id); } else { _selectedIds.add(id); }
                    }),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 200),
                      decoration: BoxDecoration(
                        color: sel ? const Color(0xFF1A6B3C) : Colors.white,
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: sel ? const Color(0xFF1A6B3C) : Colors.grey.shade400,
                          width: 2.5,
                        ),
                        boxShadow: const [BoxShadow(color: Colors.black26, blurRadius: 8, offset: Offset(0, 3))],
                      ),
                      child: Icon(
                        sel ? Icons.check_rounded : Icons.delete_outline_rounded,
                        color: sel ? Colors.white : Colors.grey.shade500,
                        size: 22,
                      ),
                    ),
                  ),
                );
              }).toList(),
            ),
          ],
        ),
        // Tooltip d'instruction
        Positioned(
          top: 12, left: 0, right: 0,
          child: Center(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 7),
              decoration: BoxDecoration(
                color: Colors.black.withOpacity(0.68),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.touch_app_rounded, color: Colors.white70, size: 14),
                  const SizedBox(width: 6),
                  Text('Tapez un marqueur pour l\'inclure dans la zone',
                      style: GoogleFonts.inter(color: Colors.white, fontSize: 12)),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildOfflineList() {
    if (widget.points.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.location_off_rounded, size: 48, color: Colors.grey.shade400),
            const SizedBox(height: 12),
            Text('Aucun centre de tri disponible',
                style: GoogleFonts.inter(color: Colors.grey, fontSize: 14)),
          ],
        ),
      );
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: double.infinity,
          color: Colors.amber.shade50,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: Row(
            children: [
              Icon(Icons.wifi_off_rounded, size: 14, color: Colors.amber.shade800),
              const SizedBox(width: 6),
              Text('Mode hors-ligne — sélection par liste',
                  style: GoogleFonts.inter(fontSize: 12, color: Colors.amber.shade800)),
            ],
          ),
        ),
        Expanded(
          child: ListView.separated(
            padding: const EdgeInsets.symmetric(vertical: 4),
            itemCount: widget.points.length,
            separatorBuilder: (_, __) => Divider(height: 1, color: Colors.grey.shade200),
            itemBuilder: (_, i) {
              final pt  = widget.points[i];
              final id  = pt['id'] as int? ?? 0;
              final sel = _selectedIds.contains(id);
              return CheckboxListTile(
                value: sel,
                activeColor: const Color(0xFF1A6B3C),
                title: Text(pt['name'] ?? 'Centre #$id',
                    style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w600)),
                subtitle: pt['address'] != null
                    ? Text(pt['address'].toString(),
                        style: GoogleFonts.inter(fontSize: 11, color: Colors.grey.shade600),
                        maxLines: 1, overflow: TextOverflow.ellipsis)
                    : null,
                secondary: Container(
                  width: 8, height: 8,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: pt['is_verified'] == true ? Colors.green : Colors.orange,
                  ),
                ),
                onChanged: (v) => setState(() {
                  if (v == true) { _selectedIds.add(id); } else { _selectedIds.remove(id); }
                }),
              );
            },
          ),
        ),
      ],
    );
  }
}
