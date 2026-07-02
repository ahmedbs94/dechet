import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../widgets/auth_prompt_dialog.dart';
import '../../services/l10n_service.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import '../../models/user_model.dart';
import 'feed_tab.dart';
import 'map_tab.dart';
import 'rewards_tab.dart';
import 'profile_tab.dart';
import 'multimedia_tab.dart';
import 'community_screen.dart';

import '../admin/collector_tab.dart';
import '../admin/intercommunality_tab.dart';
import '../admin/point_manager_tab.dart';
import '../admin/educator_tab.dart';
import '../../theme/app_theme.dart';
import '../../theme/platform_ui.dart';
import '../../layouts/web_shell.dart';
import 'package:google_fonts/google_fonts.dart';

class MainNavigationShell extends StatefulWidget {
  final int initialTab;
  const MainNavigationShell({Key? key, this.initialTab = 0}) : super(key: key);

  @override
  State<MainNavigationShell> createState() => _MainNavigationShellState();
}

class _MainNavigationShellState extends State<MainNavigationShell> {
  late int _currentIndex;
  late final List<Widget> _pages;
  late final bool _isLoggedIn;


  // GlobalKeys pour accéder aux states des tabs et appeler refresh()
  final GlobalKey<ProfileTabState> _profileKey = GlobalKey<ProfileTabState>();

  @override
  void initState() {
    super.initState();
    L10n.addListener(_onLocaleChange);
    _isLoggedIn = AuthState.currentUser != null;
    final role = AuthState.currentUser?.role ?? UserRole.user;
    _pages = _initializePages(role);
    _currentIndex = widget.initialTab.clamp(0, _pages.length - 1);

    if (!_isLoggedIn) {
      Future.delayed(const Duration(milliseconds: 700), () {
        if (mounted) AuthPromptDialog.show(context: context);
      });
    }
  }

  @override
  void dispose() {
    L10n.removeListener(_onLocaleChange);
    super.dispose();
  }

  void _onLocaleChange() {
    if (mounted) setState(() {});
  }


  /// Appelé quand on change d'onglet — simple setState pour conserver l'état des tabs
  void _onTabSelected(int index) {
    if (_currentIndex == index) return;
    final role = AuthState.currentUser?.role ?? UserRole.user;
    // Rafraîchir le score quand on arrive sur l'onglet Profil
    final profileIndex = (role == UserRole.educator) ? 2 : (role == UserRole.user ? 5 : 4);
    if (index == profileIndex) _profileKey.currentState?.refreshScore();
    setState(() => _currentIndex = index);
  }

  List<Widget> _initializePages(UserRole role) {
    if (!_isLoggedIn) {
      return [
        const FeedTab(key: ValueKey('feed')),
        const MultimediaTab(key: ValueKey('multimedia')),
        const RewardsTab(key: ValueKey('rewards')),
        const MapTab(key: ValueKey('map')),
      ];
    }

    switch (role) {
      // ── Rôle Éducateur : 3 onglets uniquement (Fil, Éducateur, Profil) ──
      case UserRole.educator:
        return [
          const FeedTab(key: ValueKey('feed')),
          const EducatorTab(key: ValueKey('educator')),
          ProfileTab(key: _profileKey),
        ];

      // ── Rôle Collecteur : même structure, Formation → Espace Collecteur ──
      case UserRole.collector:
        return [
          const FeedTab(key: ValueKey('feed')),

> [!CAUTION]
> **L'historique des collectes du collecteur n'est pas enregistré.**  
> Quand un collecteur scanne une poubelle, le code retourne directement une réponse sans insérer d'enregistrement dans `bin_scans` (contrairement au flux citoyen qui fait `db.add(scan)`). Il n'existe aucune table `collector_logs` ou équivalent pour tracer :
> - La date/heure de la collecte
> - La poubelle vidée
> - La quantité collectée (poids avant vidage)
> - L'identifiant du collecteur

> [!TIP]
> **Correction recommandée** : Avant d'appeler `update_bin_status(poids=0.0)`, récupérer le poids actuel de la poubelle depuis Firebase et l'insérer dans un enregistrement de collecte.

---

## 4. Notification à l'Intercommunalité après Collecte

### Ce qui est implémenté

L'application dispose d'une infrastructure de notifications FCM ([fcm_push_service.py](file:///c:/Users/lenovo/Desktop/EcoRewind/backend/services/fcm_push_service.py)) et d'un onglet Intercommunalité ([intercommunality_tab.dart](file:///c:/Users/lenovo/Desktop/EcoRewind/lib/screens/admin/intercommunality_tab.dart)).

### ❌ Lacune critique

> [!CAUTION]
> **Aucune notification n'est envoyée à l'intercommunalité après une collecte.**
>
> Votre spec exige qu'après chaque vidage de poubelle, une notification soit envoyée contenant :
> - Nom et ID du collecteur
> - ID de la poubelle
> - Date et heure de l'opération
> - Confirmation du vidage
>
> Dans le code actuel du flux collecteur ([`qr_bins.py` L.156-184](file:///c:/Users/lenovo/Desktop/EcoRewind/backend/routers/qr_bins.py)), après `update_bin_status()`, **aucun appel à `send_push_to_user` ou `create_notification` n'est présent**.
>
> L'`IntercommunalityTab` dans Flutter est également une **page statique avec des données fictives** (chiffres codés en dur : "342 points", "12 prestataires") sans connexion réelle au backend.

> [!TIP]
> **Correction recommandée dans `qr_bins.py`**, dans le bloc collecteur :
> ```python
> # Après update_bin_status(bin_code, poids=0.0, etat="vide")
> 
> # 1. Enregistrer la collecte dans une table collector_logs
> # 2. Identifier les utilisateurs avec role="intercommunality"
> # 3. Envoyer une notification FCM via send_push_to_user()
> intercom_users = db.query(User).filter(User.role == "intercommunality").all()
> for u in intercom_users:
>     send_push_to_user(db, u.id,
>         title="🗑️ Collecte effectuée",
>         body=f"{user.full_name} a vidé {bin_code} le {datetime.utcnow()}"
>     )
> ```

---

## 5. Historique — Citoyen & Collecteur

### Historique Citoyen

**Table `bin_scans`** — Champs disponibles vs. requis :

| Champ requis par la spec | Champ dans `bin_scans` | Statut |
|---|---|---|
| Date et heure du dépôt | `scanned_at` | ✅ |
| Poubelle utilisée | `smart_bin_id` + `bin_id` (bin_code) | ✅ |
| Type de déchet | `waste_type` | ✅ |
| Poids déposé | `weight_kg` | ✅ |
| Points gagnés | `points_earned` | ✅ |

**Endpoint** `GET /qr/scan-history` retourne toutes ces données. ✅  
**Écran Flutter** `ScanHistoryScreen` — accessible depuis `bin_scanner_screen.dart`. ✅

> [!WARNING]
> L'écran `TrackRecordsScreen` ([track_records_screen.dart](file:///c:/Users/lenovo/Desktop/EcoRewind/lib/screens/client/track_records_screen.dart)) utilise encore le `WasteRecordService` avec des **données fictives mock**, pas les vraies données du backend. Il faudra le connecter à `ScanService().getScanHistory()`.

### Historique Collecteur

> [!CAUTION]
> **Aucune table ni endpoint n'existe pour l'historique des collecteurs.** La spec exige :
> - Date et heure de la collecte
> - Poubelle vidée
> - Quantité collectée (poids)
>
> **Ces données ne sont ni sauvegardées ni consultables** dans l'état actuel.

---

## 6. Architecture Firebase RTDB — Nœuds Présents vs. Requis

### Nœuds existants

```
Firebase RTDB
├── /scores/{user_id}/          ← Score du citoyen (total, last_points, last_scan)
├── /utilisateurs/{user_id}/    ← Rôle + QR code
├── /poubelles/{bin_code}/      ← Poids + état + timestamp
├── /leaderboard/               ← Classement public
├── /admin_dashboard/           ← (bloqué, write:false)
└── /notifications/             ← (bloqué, read:false, write:false)
```

### Nœuds manquants
    _loadCustomGroups();
  }

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
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('✅ Notification envoyée au groupe'), backgroundColor: Colors.green),
                );
              }
            },
            child: Text('Envoyer', style: GoogleFonts.outfit(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  Future<void> _notifyIndividualActor(Map<String, dynamic> actor) async {
    final titleCtrl = TextEditingController();
    final msgCtrl   = TextEditingController();
    await showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Message à ${actor['full_name']}', style: GoogleFonts.outfit(fontWeight: FontWeight.w800)),
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
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('✅ Message envoyé à ${actor['full_name']}'), backgroundColor: Colors.green),
                );
              }
            },
            child: Text('Envoyer', style: GoogleFonts.outfit(color: Colors.white)),
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
                      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          AnimatedScale(
                            scale: active ? 1.12 : 1.0,
                            duration: const Duration(milliseconds: 200),
                            child: active
                              ? ShaderMask(
                                  shaderCallback: (b) => const LinearGradient(colors: [AppTheme.primaryGreen, AppTheme.accentTeal]).createShader(b),
                                  child: IconTheme(data: const IconThemeData(color: Colors.white, size: 20), child: dest.icon),
                                )
                              : IconTheme(data: const IconThemeData(color: Color(0xFF64748B), size: 18), child: dest.icon),
                          ),
                          const SizedBox(height: 3),
                          AnimatedDefaultTextStyle(
                            duration: const Duration(milliseconds: 200),
                            style: active
                              ? GoogleFonts.outfit(fontSize: count > 4 ? 9.0 : 10.0, fontWeight: FontWeight.w800, color: AppTheme.primaryGreen)
                              : GoogleFonts.inter(fontSize: count > 4 ? 8.5 : 9.5, fontWeight: FontWeight.w500, color: const Color(0xFF64748B)),
                            child: Text(dest.label, overflow: TextOverflow.ellipsis, maxLines: 1),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            );
          }),
        ),
      ),
    );
  }
}

                    ),
                  ),
                ),
              ),
            );
          }),
        ),
      ),
    );
  }
}

    );
    setState(() => reply['is_read'] = true);
  }

  // ── F4 : UI des réponses reçues ──────────────────────────────────────────
  Widget _buildF4Reponses() {
    if (_loadingReplies && _replies.isEmpty) {
      return const Center(child: CircularProgressIndicator());
    }
    return RefreshIndicator(
      onRefresh: _loadReplies,
      child: _replies.isEmpty
          ? _emptyState(
              icon: Icons.forum_outlined,
              title: 'Aucune réponse reçue',
              sub: 'Les acteurs pourront répondre à vos messages ici.',
              color: const Color(0xFF6C3EB8),
            )
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
    final time     = reply['created_at'] != null
        ? _formatRelativeTime(reply['created_at'])
        : '';
    const color = Color(0xFF6C3EB8);

    return GestureDetector(
      onTap: () => _markReplyRead(reply),
      child: Container(
        margin: const EdgeInsets.only(bottom: 10),
        decoration: BoxDecoration(
          color: isRead ? Colors.white : color.withOpacity(0.04),
          borderRadius: BorderRadius.circular(18),
          border: Border.all(
            color: isRead ? Colors.grey.shade100 : color.withOpacity(0.2),
          ),
          boxShadow: isRead
              ? []
              : [BoxShadow(color: color.withOpacity(0.08), blurRadius: 12, offset: const Offset(0, 4))],
        ),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            // Avatar avec initiales
            Container(
              width: 44, height: 44,
              decoration: BoxDecoration(
                gradient: LinearGradient(colors: [color.withOpacity(0.2), color.withOpacity(0.1)]),
                borderRadius: BorderRadius.circular(14),
              ),
              child: Center(
                child: Text(
                  fromUser.isNotEmpty ? fromUser[0].toUpperCase() : '?',
      body: json.encode({
        'zone_id': zoneId, 'collector_id': collectorId,
        'mission_message': message, 'priority': priority,
      }),
    );
    if (res.statusCode == 201 && mounted) {
      final body = json.decode(utf8.decode(res.bodyBytes));
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('âœ… ${body['message']}'), backgroundColor: Colors.green));
      _loadPilotage();
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

  Future<void> _deleteInstruction(int id) async {
    final jwt = await _jwt();
    if (jwt == null) return;
    await http.delete(
      Uri.parse('${AuthService.baseUrl}/intercommunality/instructions/$id'),
      headers: _headers(jwt),
    );
    _loadInstructions();
  }

  Future<void> _notifyActors(List<String> roles, String title, String msg) async {
    final jwt = await _jwt();
    if (jwt == null) return;
    await http.post(
      Uri.parse('${AuthService.baseUrl}/intercommunality/actors/notify'),
  // ══════════════════════════════════════════════════════════════════════════
  // BUILD PRINCIPAL
  // ══════════════════════════════════════════════════════════════════════════

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
                tabs: [
                  const Tab(icon: Icon(Icons.rule_rounded, size: 18),          text: 'Consignes'),
                  const Tab(icon: Icon(Icons.location_city_rounded, size: 18), text: 'Points'),
                  const Tab(icon: Icon(Icons.groups_rounded, size: 18),        text: 'Acteurs'),
    final jwt = await _jwt();
    if (jwt == null) return;
    final id = reply['id'];
    await http.put(
      Uri.parse('${AuthService.baseUrl}/notifications/$id/read'),
      headers: _headers(jwt),
    );
    setState(() => reply['is_read'] = true);
  }

  // â”€â”€ F4 : UI des réponses reçues â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
  Widget _buildF4Reponses() {
    if (_loadingReplies && _replies.isEmpty) {
      return const Center(child: CircularProgressIndicator());
    }
    return RefreshIndicator(
      onRefresh: _loadReplies,
      child: _replies.isEmpty
          ? _emptyState(
              icon: Icons.forum_outlined,
              title: 'Aucune réponse reçue',
              sub: 'Les acteurs pourront répondre Ã  vos messages ici.',
              color: const Color(0xFF6C3EB8),
            )
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
    final time     = reply['created_at'] != null
        ? _formatRelativeTime(reply['created_at'])
        : '';
    const color = Color(0xFF6C3EB8);

    return GestureDetector(
      onTap: () => _markReplyRead(reply),
      child: Container(
        margin: const EdgeInsets.only(bottom: 10),
        decoration: BoxDecoration(
          color: isRead ? Colors.white : color.withOpacity(0.04),
          borderRadius: BorderRadius.circular(18),
          border: Border.all(
            color: isRead ? Colors.grey.shade100 : color.withOpacity(0.2),
          ),
          boxShadow: isRead
              ? []
              : [BoxShadow(color: color.withOpacity(0.08), blurRadius: 12, offset: const Offset(0, 4))],
        ),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            // Avatar avec initiales
            Container(
              width: 44, height: 44,
              decoration: BoxDecoration(
                gradient: LinearGradient(colors: [color.withOpacity(0.2), color.withOpacity(0.1)]),
                borderRadius: BorderRadius.circular(14),
              ),
              child: Center(
                child: Text(
                  fromUser.isNotEmpty ? fromUser[0].toUpperCase() : '?',
                  style: GoogleFonts.outfit(fontSize: 18, fontWeight: FontWeight.w900, color: color),
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Row(children: [
                  Expanded(
                    child: Text(fromUser, style: GoogleFonts.outfit(
                      fontSize: 14, fontWeight: isRead ? FontWeight.w600 : FontWeight.w900,
                      color: const Color(0xFF1E293B),
                    )),
                  ),
                  Text(time, style: GoogleFonts.inter(fontSize: 11, color: AppTheme.textMuted)),
                  if (!isRead) ...[
                    const SizedBox(width: 6),
                    Container(
                      width: 8, height: 8,
                      decoration: const BoxDecoration(color: Color(0xFF6C3EB8), shape: BoxShape.circle),
                    ),
                  ],
                ]),
                const SizedBox(height: 4),
                Text(body,
                  style: GoogleFonts.inter(fontSize: 13, color: const Color(0xFF64748B)),
                  maxLines: 4,
                  overflow: TextOverflow.ellipsis,
                ),
              ]),
            ),
          ]),
        ),
      ),
    ).animate().fadeIn(delay: (30 * index).ms).slideY(begin: 0.04);
  }

  String _formatRelativeTime(String dateStr) {
    try {
      final dt = DateTime.parse(dateStr).toLocal();
      final diff = DateTime.now().difference(dt);
      if (diff.inMinutes < 1) return 'Ã€ l\'instant';
      if (diff.inMinutes < 60) return 'Il y a ${diff.inMinutes} min';
      if (diff.inHours < 24) return 'Il y a ${diff.inHours} h';
      if (diff.inDays < 7) return 'Il y a ${diff.inDays} j';
      return '${dt.day}/${dt.month}/${dt.year}';
    } catch (_) { return ''; }
  }

  // â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•
  // BUILD PRINCIPAL
  // â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•

  @override
  Widget build(BuildContext context) {
    super.build(context);
    return Scaffold(
      backgroundColor: const Color(0xFFF5F7FA),
      resizeToAvoidBottomInset: false, // évite le bottom overflow quand le clavier s'ouvre
      body: NestedScrollView(
        headerSliverBuilder: (ctx, _) => [
          SliverToBoxAdapter(child: _buildHeader()),
          SliverToBoxAdapter(child: _buildDashboardCards()),
          SliverPersistentHeader(
            pinned: true,
            delegate: _TabHeaderDelegate(
              TabBar(
                controller: _tabCtrl,
                isScrollable: true,
                tabAlignment: TabAlignment.start,
                labelColor: const Color(0xFF6C3EB8),
                unselectedLabelColor: AppTheme.textMuted,
                indicator: BoxDecoration(
                  color: const Color(0xFF6C3EB8).withOpacity(0.1),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: const Color(0xFF6C3EB8).withOpacity(0.4)),
                ),
                indicatorSize: TabBarIndicatorSize.tab,
                indicatorPadding: const EdgeInsets.symmetric(horizontal: 4, vertical: 6),
                dividerColor: Colors.transparent,
                labelStyle: GoogleFonts.outfit(fontWeight: FontWeight.w800, fontSize: 12),
                unselectedLabelStyle: GoogleFonts.outfit(fontWeight: FontWeight.w500, fontSize: 12),
                padding: const EdgeInsets.symmetric(horizontal: 12),
                tabs: [
                  const Tab(icon: Icon(Icons.rule_rounded, size: 16), text: 'Consignes'),
                  const Tab(icon: Icon(Icons.location_city_rounded, size: 16), text: 'Points'),
                  const Tab(icon: Icon(Icons.groups_rounded, size: 16), text: 'Acteurs'),
                  Tab(
                    icon: Stack(
                      clipBehavior: Clip.none,
                      children: [
                        const Icon(Icons.forum_rounded, size: 16),
                        if (_unreadRepliesCount > 0)
                          Positioned(
                            right: -6, top: -4,
                            child: Container(
                              padding: const EdgeInsets.all(2),
                              decoration: const BoxDecoration(color: Colors.red, shape: BoxShape.circle),
                              child: Text('$_unreadRepliesCount',
                                style: const TextStyle(color: Colors.white, fontSize: 8, fontWeight: FontWeight.bold)),
                            ),
                          ),
                      ],
                    ),
                    text: 'Réponses',
                  ),
                  const Tab(icon: Icon(Icons.route_rounded, size: 16), text: 'Pilotage'),
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

  // â”€â”€ Header â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€

  Widget _buildHeader() {
    final f1 = (_dashboard?['f1_consignes'] as Map?) ?? {};
    final f2 = (_dashboard?['f2_points_de_collecte'] as Map?) ?? {};
    final f3 = (_dashboard?['f3_acteurs'] as Map?) ?? {};
    // Firebase RTDB prime sur l'API REST si données disponibles
    final totalScans  = _adminStats.totalScans > 0 ? _adminStats.totalScans : null;
    final totalUsers  = _adminStats.totalUsers > 0 ? _adminStats.totalUsers : null;
    return Container(
      padding: EdgeInsets.fromLTRB(20, MediaQuery.of(context).padding.top + 12, 20, 16),
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [Color(0xFF1E0442), Color(0xFF4A1F8A), Color(0xFF7B3FC4)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          sub: '${f1['total'] ?? 0} total',
        ),
        const SizedBox(width: 10),
        _kpiCard(
          icon: Icons.location_city_rounded,
          color: const Color(0xFF2980B9),
          label: 'Points vérifiés',
          value: '${f2['verified'] ?? 0}/${f2['total'] ?? 0}',
          ),
          // Badge last sync
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.12),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Text('En ligne', style: GoogleFonts.outfit(color: Colors.greenAccent, fontSize: 11, fontWeight: FontWeight.w600)),
          ),
        ]),
        const SizedBox(height: 14),
        // ── Mini KPI inline ─────────────────────────────────────────
        Row(children: [
          _headerStat('${f1['active'] ?? 0}', 'Consignes', Icons.rule_rounded),
  Widget _kpiCard({
    required IconData icon,
    required Color color,
    required String label,
    required String value,
    required String sub,
    bool alert = false,
  }) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: AppTheme.tightShadow,
        ),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
                  decoration: const BoxDecoration(color: Colors.greenAccent, shape: BoxShape.circle),
                ),
              Text(_loadingDashboard ? 'Sync...' : 'En ligne',
                style: GoogleFonts.outfit(
                  color: _loadingDashboard ? Colors.amber : Colors.greenAccent,
                  fontSize: 11, fontWeight: FontWeight.w600)),
            ]),
          ),
        ]),
        const SizedBox(height: 14),
        // ── Mini KPI inline ─────────────────────────────────────────
        Row(children: [
          _headerStat('${f1['active'] ?? 0}', 'Consignes', Icons.rule_rounded),
          _headerDivider(),
          _headerStat('${f2['verified'] ?? 0}/${f2['total'] ?? 0}', 'Points', Icons.location_city_rounded),
          _headerDivider(),
          _headerStat('${f3['total'] ?? 0}', 'Acteurs', Icons.groups_rounded),
          _headerDivider(),
          _headerStat('${_assignments.where((a) => a['status'] == 'pending' || a['status'] == 'in_progress').length}', 'Missions', Icons.route_rounded),
        ]),
      ]),
    ).animate().fadeIn(duration: 300.ms);
  }

  Widget _headerStat(String value, String label, IconData icon) {
    return Expanded(
      child: Column(children: [
        Icon(icon, color: Colors.white54, size: 14),
        const SizedBox(height: 2),
            if (alert) ...[
              const Spacer(),
              Container(width: 8, height: 8, decoration: const BoxDecoration(color: Colors.red, shape: BoxShape.circle)),
            ],
          ]),
          const SizedBox(height: 8),
          Text(value, style: GoogleFonts.outfit(fontSize: 17, fontWeight: FontWeight.w900, color: color)),
          Text(label, style: GoogleFonts.outfit(fontSize: 9, fontWeight: FontWeight.w700, color: AppTheme.deepSlate), maxLines: 1, overflow: TextOverflow.ellipsis),
          Text(sub, style: GoogleFonts.outfit(fontSize: 8, color: AppTheme.textMuted), maxLines: 1, overflow: TextOverflow.ellipsis),
        ]),
      ),
    );
  }

  // ══════════════════════════════════════════════════════════════════════════
  // F1 — CONSIGNES LOCALES DE TRI
  // ══════════════════════════════════════════════════════════════════════════

  Widget _buildF1Consignes() {
    if (_loadingInstructions && _instructions.isEmpty) {
      return const Center(child: CircularProgressIndicator());
    }

    // Filtrage client-side
    final filtered = _instructions.where((instr) {
      final wasteOk = _f1FilterWasteType.isEmpty ||
          (instr['waste_type'] ?? '').toString().toLowerCase()
      final terrOk = _f1FilterTerritory.isEmpty ||
          (instr['territory'] ?? '').toString().toLowerCase()
              .contains(_f1FilterTerritory.toLowerCase());
      final activeOk = _f1FilterActive == null || instr['is_active'] == _f1FilterActive;
      return wasteOk && terrOk && activeOk;
    }).toList();

    return RefreshIndicator(
      onRefresh: _loadInstructions,
      child: Column(children: [
        // ── Barre de filtres ────────────────────────────────────────────
        Container(
          color: Colors.grey.shade50,
          padding: const EdgeInsets.fromLTRB(12, 10, 12, 6),
          child: Column(children: [
            Row(children: [
              Expanded(child: TextField(
                decoration: InputDecoration(
                  hintText: 'Territoire…',
                  prefixIcon: const Icon(Icons.location_on_outlined, size: 18),
                  isDense: true, contentPadding: const EdgeInsets.symmetric(vertical: 8),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                  filled: true, fillColor: Colors.white,
                ),
                onChanged: (v) => setState(() => _f1FilterTerritory = v),
              )),
              const SizedBox(width: 8),
              Expanded(child: TextField(
                decoration: InputDecoration(
                  hintText: 'Type de déchet…',
                  prefixIcon: const Icon(Icons.recycling_rounded, size: 18),
                  isDense: true, contentPadding: const EdgeInsets.symmetric(vertical: 8),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                  filled: true, fillColor: Colors.white,
                ),
                onChanged: (v) => setState(() => _f1FilterWasteType = v),
              )),
            ]),
            const SizedBox(height: 6),
            Row(children: [
              Text('Statut : ', style: GoogleFonts.outfit(fontSize: 12, color: AppTheme.textMuted)),
              ...[null, true, false].map((v) {
                final label = v == null ? 'Tous' : (v ? 'Actives' : 'Inactives');
                final selected = _f1FilterActive == v;
                return Padding(
                  padding: const EdgeInsets.only(right: 6),
                  child: GestureDetector(
                    onTap: () => setState(() => _f1FilterActive = v),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: selected ? const Color(0xFF6C3EB8) : Colors.grey.shade200,
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: Text(label, style: GoogleFonts.outfit(
                        fontSize: 11, fontWeight: FontWeight.w600,
                        color: selected ? Colors.white : AppTheme.textMuted,
                      )),
                    ),
                  ),
                );
              }),
    // Le Column reçoit une hauteur bornée depuis le TabBarView, l'Expanded
    // consomme l'espace restant pour le RefreshIndicator+ListView.
    return Column(children: [
      // â”€â”€ Barre de filtres (fixe, hauteur déterminée) â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
      Container(
        decoration: BoxDecoration(
          color: Colors.white,
          boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 4, offset: const Offset(0, 2))],
        ),
        padding: const EdgeInsets.fromLTRB(12, 10, 12, 8),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          // Champs de recherche
          Row(children: [
            Expanded(child: _filterField(
              hint: 'Territoire…',
              icon: Icons.location_on_outlined,
              onChanged: (v) => setState(() => _f1FilterTerritory = v),
            )),
            const SizedBox(width: 8),
            Expanded(child: _filterField(
              hint: 'Type de déchet…',
              icon: Icons.recycling_rounded,
              onChanged: (v) => setState(() => _f1FilterWasteType = v),
            )),
          ]),
          const SizedBox(height: 8),
          // Chips statut
          Row(children: [
            Text('Statut :', style: GoogleFonts.outfit(fontSize: 11, color: AppTheme.textMuted, fontWeight: FontWeight.w600)),
            const SizedBox(width: 8),
            ...[null, true, false].map((v) {
              final label = v == null ? 'Tous' : (v ? 'Actives' : 'Inactives');
              final selected = _f1FilterActive == v;
              return Padding(
                padding: const EdgeInsets.only(right: 6),
                child: GestureDetector(
                  onTap: () => setState(() => _f1FilterActive = v),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                    decoration: BoxDecoration(
                      color: selected ? const Color(0xFF6C3EB8) : Colors.grey.shade100,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: selected ? const Color(0xFF6C3EB8) : Colors.grey.shade300),
                    ),
                    child: Text(label, style: GoogleFonts.outfit(
                      fontSize: 11, fontWeight: FontWeight.w700,
                      color: selected ? Colors.white : AppTheme.textMuted,
                    )),
                  ),
                ),
              );
            }),
            const Spacer(),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
              decoration: BoxDecoration(color: const Color(0xFF6C3EB8).withOpacity(0.1), borderRadius: BorderRadius.circular(10)),
              child: Text('${filtered.length}', style: GoogleFonts.outfit(fontSize: 11, fontWeight: FontWeight.w800, color: const Color(0xFF6C3EB8))),
            ),
          ]),
        ]),
      ),

      // â”€â”€ Liste (Expanded + RefreshIndicator = hauteur bornée) â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
      Expanded(
        child: filtered.isEmpty
          ? _emptyState(
              icon: _instructions.isEmpty ? Icons.rule_rounded : Icons.search_off_rounded,
              title: _instructions.isEmpty ? 'Aucune consigne' : 'Aucun résultat',
              sub: _instructions.isEmpty
                  ? 'Créez votre première consigne de tri territoriale.'
                  : 'Modifiez vos filtres de recherche.',
              color: const Color(0xFF6C3EB8))
          : RefreshIndicator(
              onRefresh: _loadInstructions,
              color: const Color(0xFF6C3EB8),
              child: ListView.builder(
                padding: const EdgeInsets.fromLTRB(14, 10, 14, 100),
                itemCount: filtered.length,
                itemBuilder: (ctx, i) => _instructionCard(filtered[i]),
              ),
            ),
      ),
    ]);
  }

  /// Champ de filtre réutilisable (InputDecoration premium)
  Widget _filterField({required String hint, required IconData icon, required ValueChanged<String> onChanged}) {
    return TextField(
      onChanged: onChanged,
      style: GoogleFonts.outfit(fontSize: 13),
      decoration: InputDecoration(
        hintText: hint,
        hintStyle: GoogleFonts.outfit(color: Colors.grey.shade400, fontSize: 13),
        prefixIcon: Icon(icon, size: 16, color: Colors.grey.shade400),
        isDense: true,
        contentPadding: const EdgeInsets.symmetric(vertical: 10, horizontal: 12),
        filled: true,
        fillColor: Colors.grey.shade50,
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: Colors.grey.shade200)),
        enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: Colors.grey.shade200)),
        focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Color(0xFF6C3EB8), width: 1.5)),
      ),
    );
  }

  Widget _instructionCard(Map<String, dynamic> instr) {
    final isActive    = instr['is_active'] == true;
    const accentColor = Color(0xFF6C3EB8);
    final wasteType   = instr['waste_type'] as String? ?? '';
    final wasteIcon   = _wasteIcon(wasteType);
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(color: Colors.blue.withOpacity(0.1), borderRadius: BorderRadius.circular(20)),
                child: Text(instr['city'], style: GoogleFonts.outfit(fontSize: 10, color: Colors.blue.shade700)),
              ),
            const Spacer(),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(
                color: isActive ? Colors.green.withOpacity(0.1) : Colors.grey.withOpacity(0.1),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Text(
                isActive ? 'Active' : 'Inactive',
                style: GoogleFonts.outfit(fontSize: 10, color: isActive ? Colors.green.shade700 : Colors.grey),
              ),
            ),
          ]),
        ),
        // Corps
        Padding(
          padding: const EdgeInsets.all(16),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(instr['title'] ?? '', style: GoogleFonts.outfit(fontSize: 15, fontWeight: FontWeight.w800, color: AppTheme.deepSlate)),
            const SizedBox(height: 6),
            Text(instr['instruction'] ?? '', style: GoogleFonts.outfit(fontSize: 13, color: AppTheme.textMuted, height: 1.5)),
            const SizedBox(height: 10),
            Row(children: [
              const Icon(Icons.map_outlined, size: 13, color: AppTheme.textMuted),
              const SizedBox(width: 4),
              Text(instr['territory'] ?? '', style: GoogleFonts.outfit(fontSize: 12, color: AppTheme.textMuted)),
              const Spacer(),
              IconButton(
                icon: const Icon(Icons.edit_outlined, size: 18),
                color: color,
                onPressed: () => _showEditInstructionDialog(instr),
                constraints: const BoxConstraints(),
                padding: EdgeInsets.zero,
              ),
              const SizedBox(width: 12),
              IconButton(
                icon: const Icon(Icons.delete_outline_rounded, size: 18),
                color: Colors.red.shade400,
                onPressed: () => _confirmDeleteInstruction(instr['id']),
                constraints: const BoxConstraints(),
                padding: EdgeInsets.zero,
              ),
            ]),
          ]),
        ),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(wasteType, style: GoogleFonts.outfit(fontSize: 10, fontWeight: FontWeight.w800, color: accentColor)),
                  ),
                  if ((instr['city'] as String? ?? '').isNotEmpty) ...[\
                    const SizedBox(width: 6),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                      decoration: BoxDecoration(color: Colors.blue.withOpacity(0.08), borderRadius: BorderRadius.circular(20)),
                      child: Text(instr['city'], style: GoogleFonts.outfit(fontSize: 10, color: Colors.blue.shade700)),
                    ),
    }
    final filtered = _f2Search.isEmpty
        ? _points
        : _points.where((p) {
            final name    = (p['name'] ?? '').toString().toLowerCase();
            final address = (p['address'] ?? '').toString().toLowerCase();
            final q = _f2Search.toLowerCase();
            return name.contains(q) || address.contains(q);
          }).toList();

    return RefreshIndicator(
      onRefresh: _loadPoints,
      child: CustomScrollView(
        slivers: [
          SliverToBoxAdapter(child: _buildPointsOverview()),
  Widget _buildPointsOverview() {
    if (_pointsOverview == null) return const SizedBox();
    final ov = _pointsOverview!;
    final quality = ov['data_quality'] as Map? ?? {};
    return Padding(
      );
    }
    return null;
  }

  // ══════════════════════════════════════════════════════════════════════════
  // DIALOGS
  // ══════════════════════════════════════════════════════════════════════════

  Future<void> _showAddInstructionDialog() async {
                      const SizedBox(width: 6),
                      Text('Notifier le groupe', style: GoogleFonts.outfit(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w700)),
                    ]),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              GestureDetector(
                onTap: () => _confirmDeleteGroup(group['id'] as int, group['name'] as String),
                child: Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(color: Colors.red.withOpacity(0.08), borderRadius: BorderRadius.circular(10)),
                  child: const Icon(Icons.delete_outline_rounded, color: Colors.red, size: 18),
                ),
              ),
            ]),
          ]),
        ),
      ]),
    ).animate().fadeIn().slideY(begin: 0.05);
  }

  Widget _buildActorsOverview() {
    if (_actorsOverview == null) return const SizedBox();
    if (t.contains('plast')) return 'â™»ï¸';
    if (t.contains('verre') || t.contains('glass')) return 'ðŸ«™';
    if (t.contains('papier') || t.contains('carton')) return 'ðŸ“¦';
    if (t.contains('metal') || t.contains('m\u00e9tal')) return 'ðŸ”©';
    if (t.contains('organi') || t.contains('alim')) return 'ðŸŒ±';
    if (t.contains('électro') || t.contains('electro')) return 'ðŸ”Œ';
    if (t.contains('dangereux') || t.contains('chimique')) return 'âš ï¸';
    return 'ðŸ—‘ï¸';
  }

  /// Bouton icône compact pour les actions de card
  Widget _iconBtn(IconData icon, Color color, VoidCallback onTap) {
    return IconButton(
      icon: Icon(icon, size: 18, color: color),
      onPressed: onTap,
      constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
      padding: const EdgeInsets.all(6),
      splashRadius: 18,
    );
  }

    return RefreshIndicator(
      onRefresh: () async { await _loadActors(); await _loadCustomGroups(); },
      child: CustomScrollView(
        slivers: [
          SliverToBoxAdapter(child: _buildActorsOverview()),
          // ── Toggle Acteurs / Groupes ────────────────────────
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 4, 16, 0),
              child: Row(children: [
                Expanded(
                  child: GestureDetector(
                    onTap: () => setState(() => _showGroups = false),
                    child: Container(
            return name.contains(q) || address.contains(q);
          }).toList();

    return RefreshIndicator(
      onRefresh: _loadPoints,
      child: CustomScrollView(
        slivers: [
          SliverToBoxAdapter(child: _buildPointsOverview()),
          // â”€â”€ Barre de recherche améliorée â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(14, 10, 14, 4),
              child: Row(children: [
                Expanded(child: _filterField(
                  hint: 'Rechercher un point de collecte…',
                  icon: Icons.search_rounded,
                  onChanged: (v) => setState(() => _f2Search = v),
                )),
                const SizedBox(width: 8),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 9),
                  decoration: BoxDecoration(
                    color: const Color(0xFF2980B9).withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: const Color(0xFF2980B9).withOpacity(0.3)),
                  ),
                  child: Text('${filtered.length}/${_points.length}',
                    style: GoogleFonts.outfit(fontSize: 12, fontWeight: FontWeight.w800, color: const Color(0xFF2980B9))),
                ),
              ]),
            ),
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
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16), boxShadow: AppTheme.tightShadow),
      child: Row(children: [
        Container(
          width: 44, height: 44,
          decoration: BoxDecoration(color: roleColor.withOpacity(0.1), borderRadius: BorderRadius.circular(12)),
          child: Icon(roleIcon, color: roleColor, size: 22),
        ),
        const SizedBox(width: 12),
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(actor['full_name'] ?? '—', style: GoogleFonts.outfit(fontSize: 14, fontWeight: FontWeight.w800, color: AppTheme.deepSlate)),
          Text(actor['email'] ?? '', style: GoogleFonts.outfit(fontSize: 11, color: AppTheme.textMuted)),
        ])),
        // Badge rôle
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          decoration: BoxDecoration(color: roleColor.withOpacity(0.1), borderRadius: BorderRadius.circular(20)),
          child: Text(_roleLabel(role), style: GoogleFonts.outfit(fontSize: 10, color: roleColor, fontWeight: FontWeight.w700)),
        ),
        const SizedBox(width: 6),
        // Bouton message individuel
  Widget _buildF3Acteurs() {
    if (_loadingActors && _actors.isEmpty) {
      return const Center(child: CircularProgressIndicator());
    }

    // Filtrage par rôle
    final filteredActors = _f3FilterRole.isEmpty
        ? _actors
        : _actors.where((a) => (a['role'] ?? '') == _f3FilterRole).toList();

    return RefreshIndicator(
      onRefresh: () async { await _loadActors(); await _loadCustomGroups(); },
      child: CustomScrollView(
        slivers: [
          SliverToBoxAdapter(child: _buildActorsOverview()),
          // ── Filtre par rôle ─────────────────────────────────────────
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(children: [
                  ...[('', 'Tous'), ('pointManager', '🏭 Gestionnaires'),
                      ('collector', '🚛 Collecteurs'), ('educator', '📚 Éducateurs')]
                    .map((e) => Padding(
                      padding: const EdgeInsets.only(right: 6),
                      child: GestureDetector(
                        onTap: () => setState(() => _f3FilterRole = e.$1),
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                          decoration: BoxDecoration(
                            color: _f3FilterRole == e.$1 ? const Color(0xFF6C3EB8) : Colors.grey.shade100,
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Text(e.$2, style: GoogleFonts.outfit(
                            fontSize: 12, fontWeight: FontWeight.w600,
                            color: _f3FilterRole == e.$1 ? Colors.white : AppTheme.textMuted,
                          )),
                        ),
                      ),
  Widget _pointCard(Map<String, dynamic> p) {
    final status = p['status'] as String? ?? 'disponible';
    final isVerified = p['is_verified'] == true;
    final load = (p['load_level'] as num?)?.toDouble() ?? 0.0;

    Color statusColor;
    switch (status) {
      case 'saturÃ©': case 'sature': statusColor = Colors.red; break;
      case 'maintenance': statusColor = Colors.orange; break;
      default: statusColor = Colors.green;
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: AppTheme.tightShadow,
      ),
      child: Row(children: [
        Container(
          width: 44, height: 44,
          decoration: BoxDecoration(
            color: statusColor.withOpacity(0.1),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Icon(Icons.location_on_rounded, color: statusColor, size: 22),
        ),
        const SizedBox(width: 12),
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(p['name'] ?? '', style: GoogleFonts.outfit(fontSize: 14, fontWeight: FontWeight.w800, color: AppTheme.deepSlate)),
          Text(p['address'] ?? '', style: GoogleFonts.outfit(fontSize: 11, color: AppTheme.textMuted)),
          const SizedBox(height: 4),
          Row(children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
              decoration: BoxDecoration(color: statusColor.withOpacity(0.1), borderRadius: BorderRadius.circular(10)),
              child: Text(status, style: GoogleFonts.outfit(fontSize: 10, color: statusColor, fontWeight: FontWeight.w700)),
            ),
            const SizedBox(width: 6),
            SizedBox(
              width: 60,
              child: ClipRRect(
                borderRadius: BorderRadius.circular(4),
                child: LinearProgressIndicator(
                  value: load,
                  minHeight: 6,
                  color: load > 0.8 ? Colors.red : (load > 0.5 ? Colors.orange : Colors.green),
                  backgroundColor: Colors.grey.shade100,
                ),
              ),
            ),
            const SizedBox(width: 4),
            Text('${(load * 100).toInt()}%', style: GoogleFonts.outfit(fontSize: 10, color: AppTheme.textMuted)),
          ]),
        ])),
        // VÃ©rification toggle
        GestureDetector(
          onTap: () => _verifyPoint(p['id'] as int, !isVerified),
          child: Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: isVerified ? Colors.green.withOpacity(0.1) : Colors.grey.withOpacity(0.1),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(
              isVerified ? Icons.verified_rounded : Icons.verified_outlined,
              color: isVerified ? Colors.green : Colors.grey,
              size: 20,
            ),
          ),
        ),
      ]),
    ).animate().fadeIn().slideY(begin: 0.05);
  }

  // â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•
  // F3 â€” COORDINATION DES ACTEURS LOCAUX
  // â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•

  Widget _buildF3Acteurs() {
    if (_loadingActors && _actors.isEmpty) {
      return const Center(child: CircularProgressIndicator());
          icon: Icons.group_add_rounded,
          title: 'Aucun groupe créé',
          sub: 'Appuyez sur + pour créer un groupe d\'acteurs sur-mesure.',
          color: const Color(0xFF6C3EB8),
        ),
      );
    }
    return SliverList(
      delegate: SliverChildBuilderDelegate(
        (ctx, i) => _customGroupCard(_customGroups[i]),
        childCount: _customGroups.length,
      ),
    );
  }

  Widget _customGroupCard(Map<String, dynamic> group) {
    final memberCount = (group['member_ids'] as List?)?.length ?? 0;
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        boxShadow: AppTheme.tightShadow,
        border: Border.all(color: const Color(0xFF6C3EB8).withOpacity(0.12)),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        // En-tête
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          decoration: BoxDecoration(
        label: Text('Nouvelle consigne', style: GoogleFonts.outfit(color: Colors.white, fontWeight: FontWeight.w700)),
        onPressed: _showAddInstructionDialog,
      );
    }
    if (_tabCtrl.index == 2 && _showGroups) {
      return FloatingActionButton.extended(
        backgroundColor: const Color(0xFF6C3EB8),
        icon: const Icon(Icons.group_add_rounded, color: Colors.white),
        label: Text('Nouveau groupe', style: GoogleFonts.outfit(color: Colors.white, fontWeight: FontWeight.w700)),
        onPressed: _showCreateGroupDialog,
      );
    }
    return null;
  }
    // Filtrage par rôle
    final filteredActors = _f3FilterRole.isEmpty
        ? _actors
        : _actors.where((a) => (a['role'] ?? '') == _f3FilterRole).toList();

    return RefreshIndicator(
      onRefresh: () async { await _loadActors(); await _loadCustomGroups(); },
      child: CustomScrollView(
        slivers: [
          SliverToBoxAdapter(child: _buildActorsOverview()),
          // â”€â”€ Filtre par rôle â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(children: [
                   ...[('', 'Tous'), ('pointManager', '🏢 Gestionnaires'),
                       ('collector', '🚛 Collecteurs'), ('educator', '📚 Éducateurs')]
                    .map((e) => Padding(
                      padding: const EdgeInsets.only(right: 6),
                      child: GestureDetector(
                        onTap: () => setState(() => _f3FilterRole = e.$1),
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                          decoration: BoxDecoration(
                            color: _f3FilterRole == e.$1 ? const Color(0xFF6C3EB8) : Colors.grey.shade100,
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Text(e.$2, style: GoogleFonts.outfit(
                            fontSize: 12, fontWeight: FontWeight.w600,
                            color: _f3FilterRole == e.$1 ? Colors.white : AppTheme.textMuted,
                          )),
                        ),
                      ),
                    )),
                ]),
              ),
            ),
          ),
          // â”€â”€ Toggle Acteurs / Groupes â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 4, 16, 0),
              child: Row(children: [
                Expanded(
                  child: GestureDetector(
                    onTap: () => setState(() => _showGroups = false),
                    child: Container(
                      padding: const EdgeInsets.symmetric(vertical: 10),
                      decoration: BoxDecoration(
                        color: !_showGroups ? const Color(0xFF6C3EB8) : Colors.grey.shade100,
                        borderRadius: const BorderRadius.only(topLeft: Radius.circular(12), bottomLeft: Radius.circular(12)),
                      ),
                      child: Center(child: Text('Acteurs (${filteredActors.length})', style: GoogleFonts.outfit(
                        fontSize: 12, fontWeight: FontWeight.w700,
                        color: !_showGroups ? Colors.white : AppTheme.textMuted,
                      ))),
                    ),
                  ),
                ),
                Expanded(
                  child: GestureDetector(
                    onTap: () => setState(() => _showGroups = true),
                    child: Container(
                      padding: const EdgeInsets.symmetric(vertical: 10),
                      decoration: BoxDecoration(
                        color: _showGroups ? const Color(0xFF6C3EB8) : Colors.grey.shade100,
                        borderRadius: const BorderRadius.only(topRight: Radius.circular(12), bottomRight: Radius.circular(12)),
                      ),
                      child: Center(child: Row(mainAxisSize: MainAxisSize.min, children: [
                        Text('Mes groupes', style: GoogleFonts.outfit(
                          fontSize: 12, fontWeight: FontWeight.w700,
                          color: _showGroups ? Colors.white : AppTheme.textMuted,
                        )),
                        if (_customGroups.isNotEmpty) ...[
                          const SizedBox(width: 4),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                            decoration: const BoxDecoration(color: Colors.white24, shape: BoxShape.circle),
                            child: Text('${_customGroups.length}', style: GoogleFonts.outfit(fontSize: 9, color: _showGroups ? Colors.white : AppTheme.textMuted, fontWeight: FontWeight.w800)),
                          ),
                        ],
                      ])),
                    ),
                  ),
                    decoration: InputDecoration(
                      labelText: 'Nom du groupe',
              ]),
            ),
          ),
          // â”€â”€ Liste acteurs OU groupes personnalisés â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
          if (!_showGroups)
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 10  Widget _actorCard(Map<String, dynamic> actor) {
    final role     = actor['role'] as String? ?? '';
    final name     = actor['full_name'] as String? ?? '—';
    final email    = actor['email'] as String? ?? '';
    final joinedAt = actor['created_at'] as String?;

    Color roleColor;
    IconData roleIcon;
    String roleEmoji;
    switch (role) {
      case 'pointManager':
        roleColor = const Color(0xFF2980B9);
        roleIcon  = Icons.manage_accounts_rounded;
        roleEmoji = '🏢';
        break;
      case 'collector':
        roleColor = const Color(0xFF27AE60);
        roleIcon  = Icons.local_shipping_rounded;
        roleEmoji = '🚛';
        break;
      case 'educator':
        roleColor = const Color(0xFFE67E22);
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
                            subtitle: Text(role.toString().toUpperCase(), style: GoogleFonts.inter(fontSize: 10, color: Colors.grey)),
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
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Le nom du groupe est obligatoire'), backgroundColor: Colors.red),
                  );
                  return;
                }
                final messenger = ScaffoldMessenger.of(context);
                final jwt = await _jwt();
                if (jwt == null) return;
                final res = await http.post(
                  Uri.parse('${AuthService.baseUrl}/intercommunality/custom-groups'),
                  headers: {
                    ..._headers(jwt),
                    'Content-Type': 'application/json',
                  },
                  body: json.encode({
                    'name': name,
                    'description': descCtrl.text.trim(),
                    'member_ids': selectedActorIds.toList(),
                  }),
                );
                if (res.statusCode == 201) {
                  _loadCustomGroups();
                  if (ctx.mounted) Navigator.pop(ctx);
                  messenger.showSnackBar(
                    const SnackBar(content: Text('✅ Groupe créé avec succès'), backgroundColor: Colors.green),
                  );
                } else {
                  messenger.showSnackBar(
                    const SnackBar(content: Text('❌ Erreur lors de la création du groupe'), backgroundColor: Colors.red),
                  );
                }
              },
              child: Text('Créer', style: GoogleFonts.outfit(color: Colors.white, fontWeight: FontWeight.bold)),
            ),
          ],
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
        builder: (ctx, setDlg) => AlertDialog(
          title: Text('Notifier les acteurs', style: GoogleFonts.outfit(fontWeight: FontWeight.w900)),
          content: SingleChildScrollView(
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              // Rôles cibles
              Wrap(spacing: 8, children: [
                for (final role in ['pointManager', 'collector', 'educator'])
                  FilterChip(
                    label: Text(_roleLabel(role), style: GoogleFonts.outfit(fontSize: 12)),
                    selected: selectedRoles.contains(role),
                    onSelected: (v) => setDlg(() => v ? selectedRoles.add(role) : selectedRoles.remove(role)),
                    selectedColor: const Color(0xFF6C3EB8).withOpacity(0.15),
                    checkmarkColor: const Color(0xFF6C3EB8),
                  ),
              ]),
              const SizedBox(height: 12),
                  ),
                ),
              ]),
            ]),
          ),
        ]),
      ),
    ).animate().fadeIn(duration: 250.ms).slideX(begin: 0.04);
  }

lor: Color(0xFF6C3EB8), size: 18),
            const SizedBox(width: 8),
            Expanded(child: Text(group['name'] ?? '', style: GoogleFonts.outfit(fontSize: 14, fontWeight: FontWeight.w800, color: const Color(0xFF6C3EB8)))),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(color: const Color(0xFF6C3EB8).withOpacity(0.12), borderRadius: BorderRadius.circular(20)),
              child: Text('$memberCount membre${memberCount > 1 ? 's' : ''}', style: GoogleFonts.outfit(fontSize: 10, color: const Color(0xFF6C3EB8), fontWeight: FontWeight.w700)),
            ),
          ]),
        ),
        // Corps
        Padding(
          padding: const EdgeInsets.all(14),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            if (group['description'] != null && (group['description'] as String).isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: Text(group['description'], style: GoogleFonts.outfit(fontSize: 12, color: AppTheme.textMuted)),
              ),
            Row(children: [
              Expanded(
                child: GestureDetector(
                  onTap: () => _notifyCustomGroup(group['id'] as int, group['name'] as String),
                  child: Container(
                    padding: const EdgeInsets.symmetric(vertical: 10),
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(colors: [Color(0xFF6C3EB8), Color(0xFF9B59B6)]),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                      const Icon(Icons.send_rounded, color: Colors.white, size: 14),
                      const SizedBox(width: 6),
                      Text('Notifier le groupe', style: GoogleFonts.outfit(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w700)),
                    ]),
                  ),
                ),
        const SizedBox(width: 6),
        // Bouton message individuel
        GestureDetector(
          onTap: () => _notifyIndividualActor(actor),
          child: Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(color: const Color(0xFF6C3EB8).withOpacity(0.08), borderRadius: BorderRadius.circular(10)),
            child: const Icon(Icons.send_rounded, color: Color(0xFF6C3EB8), size: 16),
          ),
        ),
      ]),
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
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16), boxShadow: AppTheme.tightShadow),
      child: Row(children: [
        Container(
          width: 44, height: 44,
          decoration: BoxDecoration(color: roleColor.withOpacity(0.1), borderRadius: BorderRadius.circular(12)),
          child: Icon(roleIcon, color: roleColor, size: 22),
        ),
        const SizedBox(width: 12),
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(actor['full_name'] ?? 'â€”', style: GoogleFonts.outfit(fontSize: 14, fontWeight: FontWeight.w800, color: AppTheme.deepSlate)),
          Text(actor['email'] ?? '', style: GoogleFonts.outfit(fontSize: 11, color: AppTheme.textMuted)),
        ])),
        // Badge rôle
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          decoration: BoxDecoration(color: roleColor.withOpacity(0.1), borderRadius: BorderRadius.circular(20)),
          child: Text(_roleLabel(role), style: GoogleFonts.outfit(fontSize: 10, color: roleColor, fontWeight: FontWeight.w700)),
        ),
        const SizedBox(width: 6),
        // Bouton message individuel
        GestureDetector(
          onTap: () => _notifyIndividualActor(actor),
          child: Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(color: const Color(0xFF6C3EB8).withOpacity(0.08), borderRadius: BorderRadius.circular(10)),
            child: const Icon(Icons.send_rounded, color: Color(0xFF6C3EB8), size: 16),
          ),
        ),
      ]),
    ).animate().fadeIn().slideY(begin: 0.05);
  }

  String _roleLabel(String role) {
    switch (role) {
      case 'pointManager': return 'Gestionnaire';
      case 'collector':    return 'Collecteur';
      case 'educator':     return 'Éducateur';
      default:             return role;
    }
  }

  // â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•
  // FAB dynamique selon l'onglet




      return FloatingActionButton.extended(
        backgroundColor: const Color(0xFF6C3EB8),
        icon: const Icon(Icons.add_rounded, color: Colors.white),
        label: Text('Nouvelle consigne', style: GoogleFonts.outfit(color: Colors.white, fontWeight: FontWeight.w700)),
        onPressed: _showAddInstructionDialog,
      );
    }
    if (_tabCtrl.index == 2 && _showGroups) {
      return FloatingActionButton.extended(
        backgroundColor: const Color(0xFF6C3EB8),
        icon: const Icon(Icons.group_add_rounded, color: Colors.white),
        label: Text('Nouveau groupe', style: GoogleFonts.outfit(color: Colors.white, fontWeight: FontWeight.w700)),
        onPressed: _showCreateGroupDialog,
      );
    }
    if (_tabCtrl.index == 4) {
      return FloatingActionButton.extended(
        backgroundColor: const Color(0xFF1A6B3C),
        icon: const Icon(Icons.add_location_alt_rounded, color: Colors.white),
        label: Text('Nouvelle zone', style: GoogleFonts.outfit(color: Colors.white, fontWeight: FontWeight.w700)),
        onPressed: _showCreateZoneDialog,
      );
    }
    return null;
  }

  // â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•
  // F5 â€” PILOTAGE COLLECTEURS (Widget)
  // â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•

  Widget _buildF5Pilotage() {
    if (_loadingPilotage) {
                    color: roleColor.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: roleColor.withOpacity(0.25)),
                  ),
                  child: Row(mainAxisSize: MainAxisSize.min, children: [
                    Icon(roleIcon, size: 10, color: roleColor),
                    const SizedBox(width: 4),
                    Text(_roleLabel(role),
                      style: GoogleFonts.outfit(fontSize: 10, color: roleColor, fontWeight: FontWeight.w700)),
                  ]),
                ),
                const SizedBox(height: 8),
                GestureDetector(
                  onTap: () => _notifyIndividualActor(actor),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(colors: [Color(0xFF6C3EB8), Color(0xFF9B59B6)]),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Row(mainAxisSize: MainAxisSize.min, children: [
                      const Icon(Icons.send_rounded, color: Colors.white, size: 12),
                      const SizedBox(width: 4),
                      Text('Notifier', style: GoogleFonts.outfit(fontSize: 10,
                        fontWeight: FontWeight.w700, color: Colors.white)),
                    ]),
                  ),
                ),
              ]),
            ]),
          ),
        ]),
      ),
    ).animate().fadeIn(duration: 250.ms).slideX(begin: 0.04);
  }

  String _roleLabel(String role) {
    switch (role) {
      case 'pointManager': return 'Gestionnaire';
      case 'collector':    return 'Collecteur';
      case 'educator':     return 'Éducateur';
      default:             return role;
    }
  }

  // â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•
  // FAB dynamique selon l'onglet
  // â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•

  Widget? _buildFAB() {
    if (_tabCtrl.index == 0) {
      return FloatingActionButton.extended(
        backgroundColor: const Color(0xFF6C3EB8),
        icon: const Icon(Icons.add_rounded, color: Colors.white),
        label: Text('Nouvelle consigne', style: GoogleFonts.outfit(color: Colors.white, fontWeight: FontWeight.w700)),
        onPressed: _showAddInstructionDialog,
      );
    }
    if (_tabCtrl.index == 2 && _showGroups) {
      return FloatingActionButton.extended(
        backgroundColor: const Color(0xFF6C3EB8),
        icon: const Icon(Icons.group_add_rounded, color: Colors.white),
        label: Text('Nouveau groupe', style: GoogleFonts.outfit(color: Colors.white, fontWeight: FontWeight.w700)),
        onPressed: _showCreateGroupDialog,
      );
    }
    if (_tabCtrl.index == 4) {
      return FloatingActionButton.extended(
        backgroundColor: const Color(0xFF1A6B3C),
        icon: const Icon(Icons.add_location_alt_rounded, color: Colors.white),
        label: Text('Nouvelle zone', style: GoogleFonts.outfit(color: Colors.white, fontWeight: FontWeight.w700)),
        onPressed: _showCreateZoneDialog,
      );
    }
    return null;
  }

  // â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•
  // F5 â€” PILOTAGE COLLECTEURS (Widget)
  // â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•

  Widget _buildF5Pilotage() {
    if (_loadingPilotage) {
      return const Center(child: CircularProgressIndicator(color: Color(0xFF1A6B3C)));
    }
    return RefreshIndicator(
      onRefresh: _loadPilotage,
      color: const Color(0xFF1A6B3C),
      child: CustomScrollView(
        slivers: [
          // â”€â”€ KPI bar â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 8, offset: const Offset(0, 3))],
      ),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        leading: CircleAvatar(
          backgroundColor: zoneColor.withOpacity(0.15),
          child: Icon(Icons.map_outlined, color: zoneColor),
        ),
        title: Text(zone['name'] ?? '', style: GoogleFonts.outfit(fontWeight: FontWeight.w800)),
        subtitle: Text('${zone['territory'] ?? ''} · $activeCount affectation(s) active(s)',
          style: GoogleFonts.outfit(fontSize: 12, color: AppTheme.textMuted)),
        trailing: Row(mainAxisSize: MainAxisSize.min, children: [
          IconButton(
            icon: const Icon(Icons.person_add_rounded, color: Color(0xFF1A6B3C)),
            tooltip: 'Affecter un collecteur',
            onPressed: () => _showAssignCollectorDialog(zone),
          ),
          IconButton(
            icon: const Icon(Icons.delete_outline_rounded, color: Colors.red),
            tooltip: 'Supprimer la zone',
            onPressed: () async {
              final ok = await showDialog<bool>(
                context: context,
                builder: (ctx) => AlertDialog(
                  title: Text('Supprimer "${zone['name']}" ?', style: GoogleFonts.outfit(fontWeight: FontWeight.w800)),
                  content: const Text('Cette action est irréversible.'),
                  actions: [
                    TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Annuler')),
                    ElevatedButton(
                      style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
                      onPressed: () => Navigator.pop(ctx, true),
                      child: const Text('Supprimer', style: TextStyle(color: Colors.white)),
                    ),
                  ],
                ),
              );
              if (ok == true) _deleteZone(zone['id'], zone['name']);
            },
          ),
        ]),
      ),
    );
  }

  Widget _buildAssignmentCard(Map<String, dynamic> a) {
    final status   = a['status'] as String? ?? 'pending';
    final priority = a['priority'] as String? ?? 'normal';
    final isUrgent = priority == 'urgent';
    final Color statusColor = _assignmentStatusColor(status);
    final Color zoneColor   = _parseColor(a['zone_color'] ?? '#4CAF50');

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border(left: BorderSide(color: isUrgent ? Colors.orange : zoneColor, width: 4)),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 8, offset: const Offset(0, 3))],
      ),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            Expanded(
              child: Text('${a['zone_name'] ?? 'Zone ?'} — ${a['zone_territory'] ?? ''}',
                style: GoogleFonts.outfit(fontWeight: FontWeight.w800, fontSize: 14)),
            ),
            if (isUrgent)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(color: Colors.orange.shade100, borderRadius: BorderRadius.circular(8)),
    ]);
  }

  Widget _buildZoneCard(Map<String, dynamic> zone) {
    final Color zoneColor = _parseColor(zone['color_hex'] ?? '#4CAF50');
    final int activeCount = (zone['active_assignments'] ?? 0) as int;
    final territory = zone['territory'] as String? ?? '';
    final activeCount = (zone['active_assignments'] ?? 0) as int;
    // Bins en alerte depuis Firebase (global — pas de champ localisation dans PoubelleSnapshot)
    final totalBins      = _poubelles.length;
    final totalBinsAlert = _poubelles.where((p) => p.isPlein || p.poids > 80).length;

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 14, vertical: 5),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        boxShadow: [BoxShadow(color: zoneColor.withOpacity(0.15), blurRadius: 12, offset: const Offset(0, 5))],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(18),
        child: IntrinsicHeight(child: Row(children: [
          // Bande colorÃ©e gauche
                },
                childCount: _filteredAssignments.length,
              ),
            ),

          // â”€â”€ Zones existantes â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 20, 16, 8),
              child: Text('ðŸ—º Zones territoriales',
                style: GoogleFonts.outfit(fontWeight: FontWeight.w800, fontSize: 14)),
            ),
          ),
          if (_zones.isEmpty)
            SliverToBoxAdapter(
              child: Center(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Text('Aucune zone créée. Utilisez le bouton + pour en créer une.',
                    style: GoogleFonts.outfit(color: AppTheme.textMuted, fontSize: 13)),
                ),
                Row(children: [
                  _zoneStat('$activeCount', 'missions', Icons.pending_actions_rounded, zoneColor),
                  const SizedBox(width: 10),
                  if (zoneBins > 0)
                    _zoneStat('$totalBins', 'bins', Icons.delete_rounded, Colors.blueGrey),
                  ],
                  if (totalBinsAlert > 0) ...[
                    const SizedBox(width: 6),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(color: Colors.orange.shade50, borderRadius: BorderRadius.circular(8), border: Border.all(color: Colors.orange.shade200)),
                      child: Text('ðŸ”´ $zoneBinsAlert urgents', style: GoogleFonts.outfit(fontSize: 9, fontWeight: FontWeight.w700, color: Colors.orange.shade800)),
                    ),
                  ],
                ]),
              ])),
              // Actions
                _iconBtn(Icons.person_add_rounded, const Color(0xFF1A6B3C), () => _showAssignCollectorDialog(zone)),
                _iconBtn(Icons.delete_outline_rounded, Colors.red.shade300, () async {
                  final ok = await showDialog<bool>(context: context,
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border(left: BorderSide(color: isUrgent ? Colors.orange : zoneColor, width: 4)),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 8, offset: const Offset(0, 3))],
      ),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            Expanded(
              child: Text('${a['zone_name'] ?? 'Zone ?'} — ${a['zone_territory'] ?? ''}',
                style: GoogleFonts.outfit(fontWeight: FontWeight.w800, fontSize: 14)),
            ),
            if (isUrgent)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(color: Colors.orange.shade100, borderRadius: BorderRadius.circular(8)),
        ),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [BoxShadow(color: Colors.green.withOpacity(0.3), blurRadius: 20, offset: const Offset(0, 8))],
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          _kpiPilotage('$totalZones',   'Zones',       Icons.map_rounded),
          _kpiPilotageDivider(),
          _kpiPilotage('$activeAssign', 'En cours',    Icons.pending_rounded),
          _kpiPilotageDivider(),
          _kpiPilotage('$doneAssign',   'Terminées',   Icons.check_circle_outline_rounded),
          _kpiPilotageDivider(),
          _kpiPilotage('$collectors',   'Collecteurs', Icons.local_shipping_rounded),
          _kpiPilotageDivider(),
          _kpiPilotageAlert('$alerts', 'ðŸ”´ Alertes', alerts > 0),
        ],
      ),
    ).animate().fadeIn(duration: 300.ms);
  }

  Widget _kpiPilotageDivider() =>
    Container(width: 1, height: 28, color: Colors.white.withOpacity(0.2));

  Widget _kpiPilotage(String value, String label, IconData icon) {
    return Column(children: [
            if (status == 'in_progress') ...[
              _actionBtn('Terminée ✓', Colors.green, () => _updateAssignmentStatus(a['id'], 'done')),
              const SizedBox(width: 6),
            ],
            if (status != 'done' && status != 'cancelled')
              _actionBtn('Annuler', Colors.red.shade300, () => _deleteAssignment(a['id'])),
          ]),
        ]),
      ),
    );
  }

  Widget _actionBtn(String label, Color color, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
        decoration: BoxDecoration(color: color.withOpacity(0.1), borderRadius: BorderRadius.circular(10),
          border: Border.all(color: color.withOpacity(0.4))),
        child: Text(label, style: GoogleFonts.outfit(fontSize: 11, fontWeight: FontWeight.w700, color: color)),
      ),
    );
  }

  Color _assignmentStatusColor(String status) {
        : Text(value, style: GoogleFonts.outfit(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 20)),
      Text(label, style: GoogleFonts.outfit(color: color, fontSize: 10)),
    ]);
  }

  Widget _buildZoneCard(Map<String, dynamic> zone) {
    final Color zoneColor  = _parseColor(zone['color_hex'] ?? '#4CAF50');
    final territory        = zone['territory'] as String? ?? '';
    final int activeCount  = (zone['active_assignments'] ?? 0) as int;
    // Bins en alerte depuis Firebase (global — PoubelleSnapshot n'a pas de champ localisation)
    final totalBins        = _poubelles.length;
    final totalBinsAlert   = _poubelles.where((p) => p.isPlein || p.poids > 80).length;

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 14, vertical: 5),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        boxShadow: [BoxShadow(color: zoneColor.withOpacity(0.15), blurRadius: 12, offset: const Offset(0, 5))],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(18),
        child: IntrinsicHeight(child: Row(children: [
          // Bande colorée gauche
          Container(width: 5, decoration: BoxDecoration(color: zoneColor)),
          // Contenu
          Expanded(child: Padding(
            padding: const EdgeInsets.fromLTRB(14, 12, 8, 12),
            child: Row(children: [
              // Icône zone
              Container(
                width: 44, height: 44,
                decoration: BoxDecoration(color: zoneColor.withOpacity(0.12), shape: BoxShape.circle),
                child: Icon(Icons.map_rounded, color: zoneColor, size: 22),
              ),
              const SizedBox(width: 12),
              // Infos
              Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(zone['name'] ?? '', style: GoogleFonts.outfit(fontWeight: FontWeight.w800, fontSize: 14)),
                const SizedBox(height: 3),
                Row(children: [
                  Icon(Icons.location_on_outlined, size: 11, color: Colors.grey.shade400),
                  const SizedBox(width: 2),
                  Expanded(child: Text(territory, style: GoogleFonts.outfit(fontSize: 11, color: Colors.grey.shade500), overflow: TextOverflow.ellipsis)),
                ]),
                const SizedBox(height: 6),
                Row(children: [
                  _zoneStat('$activeCount', 'missions', Icons.pending_actions_rounded, zoneColor),
                  if (totalBins > 0) ...[
                    const SizedBox(width: 10),
                    _zoneStat('$totalBins', 'bins', Icons.delete_rounded, Colors.blueGrey),
                  ],
                  if (totalBinsAlert > 0) ...[
                    const SizedBox(width: 6),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(color: Colors.orange.shade50, borderRadius: BorderRadius.circular(8), border: Border.all(color: Colors.orange.shade200)),
                      child: Text('🔴 $totalBinsAlert urgents', style: GoogleFonts.outfit(fontSize: 9, fontWeight: FontWeight.w700, color: Colors.orange.shade800)),
                    ),
                  ],
                ]),
              ])),
              // Actions
              Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                _iconBtn(Icons.person_add_rounded, const Color(0xFF1A6B3C), () => _showAssignCollectorDialog(zone)),
                _iconBtn(Icons.delete_outline_rounded, Colors.red.shade300, () async {
                  final ok = await showDialog<bool>(context: context,
                    builder: (ctx) => AlertDialog(
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                      title: Text('Supprimer "${zone['name']}" ?', style: GoogleFonts.outfit(fontWeight: FontWeight.w800)),
                      content: Text('Cette action est irréversible.', style: GoogleFonts.outfit()),
                      actions: [
                        TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Annuler')),
                        ElevatedButton(
                          style: ElevatedButton.styleFrom(backgroundColor: Colors.red, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10))),
                          onPressed: () => Navigator.pop(ctx, true),
                          child: const Text('Supprimer', style: TextStyle(color: Colors.white)),
                        ),
                      ],
                    ),
                  );
                  if (ok == true) _deleteZone(zone['id'], zone['name']);
                }),
              ]),
            ]),
          )),
        ])),
      ),
    ).animate().fadeIn(duration: 200.ms).slideX(begin: -0.03);
  }

  Widget _zoneStat(String value, String label, IconData icon, Color color) {
    return Row(mainAxisSize: MainAxisSize.min, children: [
      Icon(icon, size: 12, color: color),
      const SizedBox(width: 3),
      Text('$value $label', style: GoogleFonts.outfit(fontSize: 10, fontWeight: FontWeight.w700, color: color)),
    ]);
  }

  Widget _buildAssignmentCard(Map<String, dynamic> a) {
    final status   = a['status'] as String? ?? 'pending';
    final priority = a['priority'] as String? ?? 'normal';
    final isUrgent = priority == 'urgent';
    final Color statusColor = _assignmentStatusColor(status);
    final Color zoneColor   = _parseColor(a['zone_color'] ?? '#4CAF50');
    final steps  = ['pending', 'in_progress', 'done'];
    final stepIdx = steps.indexOf(status).clamp(0, 2);

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        boxShadow: [BoxShadow(
          color: (isUrgent ? Colors.orange : statusColor).withOpacity(0.12),
          blurRadius: 14, offset: const Offset(0, 5),
        )],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(18),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          // â”€â”€ Barre de progression colorée â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
          LinearProgressIndicator(
            value: (stepIdx + 1) / 3.0,
            minHeight: 3,
            backgroundColor: Colors.grey.shade100,
            valueColor: AlwaysStoppedAnimation<Color>(isUrgent ? Colors.orange : statusColor),
          ),
          Padding(
            padding: const EdgeInsets.all(14),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              // â”€â”€ Ligne 1 : zone + badges â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
              Row(children: [
                Container(
                  padding: const EdgeInsets.all(7),
                  decoration: BoxDecoration(color: zoneColor.withOpacity(0.12), borderRadius: BorderRadius.circular(10)),
                  child: Icon(Icons.map_rounded, color: zoneColor, size: 16),
                ),
                const SizedBox(width: 10),
                Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(a['zone_name'] ?? 'Zone ?',
                    style: GoogleFonts.outfit(fontWeight: FontWeight.w800, fontSize: 14), overflow: TextOverflow.ellipsis),
                  if ((a['zone_territory'] as String? ?? '').isNotEmpty)
                    Text(a['zone_territory'], style: GoogleFonts.outfit(fontSize: 11, color: Colors.grey.shade500)),
                ])),
                if (isUrgent)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(colors: [Color(0xFFFF6B35), Color(0xFFFF8C00)]),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text('URGENT', style: GoogleFonts.outfit(fontSize: 9, fontWeight: FontWeight.w900, color: Colors.white, letterSpacing: 0.5)),
                  ),
                const SizedBox(width: 6),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: statusColor.withOpacity(0.12),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: statusColor.withOpacity(0.3)),
                  ),
                  child: Text(_statusLabel(status), style: GoogleFonts.outfit(fontSize: 10, fontWeight: FontWeight.w700, color: statusColor)),
                ),
              ]),
              const SizedBox(height: 10),
              // â”€â”€ Ligne 2 : collecteur â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
              Row(children: [
                Container(
                  width: 28, height: 28,
                  decoration: BoxDecoration(color: Colors.grey.shade100, shape: BoxShape.circle),
                  child: const Icon(Icons.local_shipping_rounded, size: 14, color: Colors.grey),
                ),
                const SizedBox(width: 8),
                Text(a['collector_name'] ?? 'Collecteur ?',
                  style: GoogleFonts.outfit(fontSize: 13, fontWeight: FontWeight.w600, color: const Color(0xFF1A1A2E))),
              ]),
              if ((a['mission_message'] ?? '').isNotEmpty) ...[
                const SizedBox(height: 8),
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(color: Colors.grey.shade50, borderRadius: BorderRadius.circular(10)),
                  child: Text(a['mission_message'], style: GoogleFonts.outfit(fontSize: 12, color: Colors.grey.shade700),
                    maxLines: 2, overflow: TextOverflow.ellipsis),
                ),
              ],
              const SizedBox(height: 12),
              // â”€â”€ Actions â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
              Row(children: [
                if (status == 'pending') ...[
                  _actionBtn('â–¶ En cours', Colors.blue, () => _updateAssignmentStatus(a['id'], 'in_progress')),
                  const SizedBox(width: 6),
                ],
                if (status == 'in_progress') ...[
                  _actionBtn('âœ“ Terminée', Colors.green, () => _updateAssignmentStatus(a['id'], 'done')),
                  const SizedBox(width: 6),
                ],
                if (status != 'done' && status != 'cancelled')
                  _actionBtn('âœ• Annuler', Colors.red.shade400, () => _deleteAssignment(a['id'])),
              ]),
            ]),
          ),
        ]),
      ),
    ).animate().fadeIn(duration: 220.ms).slideY(begin: 0.04);
  }

  Widget _actionBtn(String label, Color color, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
        decoration: BoxDecoration(
          color: color.withOpacity(0.1),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: color.withOpacity(0.35)),
        ),
        child: Text(label, style: GoogleFonts.outfit(fontSize: 12, fontWeight: FontWeight.w700, color: color)),
      ),
    );
  }

  Color _assignmentStatusColor(String status) {
    switch (status) {
      case 'pending':     return Colors.orange;
      case 'in_progress': return Colors.blue;
      case 'done':        return Colors.green;
      case 'cancelled':   return Colors.red;
      default:            return Colors.grey;
    }
  }

  String _statusLabel(String status) {
    switch (status) {
      case 'pending':     return 'En attente';
      case 'in_progress': return 'En cours';
      case 'done':        return 'Terminée';
      case 'cancelled':   return 'Annulée';
      default:            return status;
    }
  }

  Color _parseColor(String hex) {
    try {
      final h = hex.replaceAll('#', '');
      return Color(int.parse('FF$h', radix: 16));
    } catch (_) {
      return Colors.green;
    }
  }

  // â”€â”€ Dialogs F5 â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€

  Future<void> _showCreateZoneDialog() async {
    final nameCtrl   = TextEditingController();
    final terrCtrl   = TextEditingController();
    final descCtrl   = TextEditingController();
    String color     = '#4CAF50';
    final colors     = ['#4CAF50', '#2196F3', '#FF9800', '#9C27B0', '#F44336', '#00BCD4'];

    await showModalBottomSheet(
      context: context, isScrollControlled: true, backgroundColor: Colors.transparent,
      builder: (ctx) => StatefulBuilder(builder: (ctx, setSt) => Container(
        decoration: const BoxDecoration(
          color: Colors.white, borderRadius: BorderRadius.vertical(top: Radius.circular(28))),
        padding: EdgeInsets.fromLTRB(24, 20, 24, MediaQuery.of(ctx).viewInsets.bottom + 24),
        child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
          Center(child: Container(width: 40, height: 4, decoration: BoxDecoration(color: Colors.grey.shade300, borderRadius: BorderRadius.circular(2)))),
          const SizedBox(height: 16),
          Text('Nouvelle zone territoriale', style: GoogleFonts.outfit(fontSize: 18, fontWeight: FontWeight.w900)),
          const SizedBox(height: 16),
          TextField(controller: nameCtrl, decoration: InputDecoration(labelText: 'Nom de la zone *', border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)))),
          const SizedBox(height: 10),
          TextField(controller: terrCtrl, decoration: InputDecoration(labelText: 'Territoire *', border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)))),
          const SizedBox(height: 10),
          TextField(controller: descCtrl, maxLines: 2, decoration: InputDecoration(labelText: 'Description', border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)))),
          const SizedBox(height: 10),
          Text('Couleur', style: GoogleFonts.outfit(fontWeight: FontWeight.w700)),
          const SizedBox(height: 6),
          Row(children: colors.map((c) => GestureDetector(
            onTap: () => setSt(() => color = c),
            child: Container(
              margin: const EdgeInsets.only(right: 8),
              width: 32, height: 32,
              decoration: BoxDecoration(
                color: _parseColor(c), shape: BoxShape.circle,
                border: Border.all(width: color == c ? 3 : 0, color: Colors.black87),
              ),
            ),
          )).toList()),
          const SizedBox(height: 20),
          SizedBox(width: double.infinity,
            child: ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF1A6B3C),
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14))),
              onPressed: () {
                if (nameCtrl.text.trim().isEmpty || terrCtrl.text.trim().isEmpty) return;
                Navigator.pop(ctx);
                _createZone(nameCtrl.text.trim(), terrCtrl.text.trim(), descCtrl.text.trim(), color);
              },
              child: Text('Créer la zone', style: GoogleFonts.outfit(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 16)),
            ),
          ),
        ]),
      )),
    );
  }

  Future<void> _showAssignCollectorDialog(Map<String, dynamic> zone) async {
    if (_collectors.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Aucun collecteur disponible')));
      return;
    }
    int? selectedCollectorId = _collectors.first['id'] as int?;
    String priority = 'normal';
    final msgCtrl = TextEditingController();

    await showModalBottomSheet(
      context: context, isScrollControlled: true, backgroundColor: Colors.transparent,
      builder: (ctx) => StatefulBuilder(builder: (ctx, setSt) => Container(
        decoration: const BoxDecoration(
          color: Colors.white, borderRadius: BorderRadius.vertical(top: Radius.circular(28))),
        padding: EdgeInsets.fromLTRB(24, 20, 24, MediaQuery.of(ctx).viewInsets.bottom + 24),
        child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
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
          Row(children: [
            _priorityChip('normal',  'Normal',  Colors.blue,   priority, (v) => setSt(() => priority = v)),
            const SizedBox(width: 8),
            _priorityChip('urgent',  'Urgent',  Colors.orange, priority, (v) => setSt(() => priority = v)),
          ]),
          const SizedBox(height: 10),
          TextField(controller: msgCtrl, maxLines: 3,
            decoration: InputDecoration(labelText: 'Message de mission (optionnel)', border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)))),
          const SizedBox(height: 20),
          SizedBox(width: double.infinity,
            child: ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF1A6B3C),
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14))),
              onPressed: () {
                if (selectedCollectorId == null) return;
                Navigator.pop(ctx);
                _createAssignment(
                  zoneId: zone['id'], collectorId: selectedCollectorId!,
                  message: msgCtrl.text.trim(), priority: priority,
                );
              },
              child: Text('Affecter le collecteur', style: GoogleFonts.outfit(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 16)),
            ),
          ),
        ]),
      )),
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
class _TabHeaderDelegate extends SliverPersistentHeaderDelegate {
  final TabBar tabBar;
  const _TabHeaderDelegate(this.tabBar);

  @override
  double get minExtent => tabBar.preferredSize.height;
  @override
  double get maxExtent => tabBar.preferredSize.height;

  @override
  Widget build(BuildContext context, double shrinkOffset, bool overlapsContent) {
    return Container(
      color: Colors.white,
      child: tabBar,
    );
  }

  @override
  bool shouldRebuild(_TabHeaderDelegate oldDelegate) => false;
}

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
          // ignore: use_build_context_synchronously
          if (ctx.mounted) Navigator.pop(ctx);
          _loadInstructions();
        },
      ),
    );
  }

  Future<void> _showEditInstructionDialog(Map<String, dynamic> instr) async {
    final territoryCtrl   = TextEditingController(text: instr['territory'] ?? '');
    final cityCtrl        = TextEditingController(text: instr['city'] ?? '');
    final wasteTypeCtrl   = TextEditingController(text: instr['waste_type'] ?? '');
    final titleCtrl       = TextEditingController(text: instr['title'] ?? '');
    final instructionCtrl = TextEditingController(text: instr['instruction'] ?? '');

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
          // ignore: use_build_context_synchronously
          if (ctx.mounted) Navigator.pop(ctx);
          _loadInstructions();
        },
      ),
    );
  }

      padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Center(child: Container(width: 40, height: 4, decoration: BoxDecoration(color: Colors.grey.shade300, borderRadius: BorderRadius.circular(2)))),
          const SizedBox(height: 16),
          Text(title, style: GoogleFonts.outfit(fontSize: 18, fontWeight: FontWeight.w900, color: AppTheme.deepSlate)),
          const SizedBox(height: 20),
          _field('Territoire *', territoryCtrl, hint: 'ex: Grand Tunis'),
          _field('Ville (optionnel)', cityCtrl, hint: 'ex: Ariana'),
          _field('Type de déchet *', wasteTypeCtrl, hint: 'ex: Plastique'),
          _field('Titre *', titleCtrl, hint: 'ex: Comment trier le plastique'),
          _field('Consigne *', instructionCtrl, hint: 'Texte de la consigne locale...', maxLines: 4),
          const SizedBox(height: 24),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF6C3EB8),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                padding: const EdgeInsets.symmetric(vertical: 16),
              ),
              onPressed: onSave,
              child: Text('Enregistrer', style: GoogleFonts.outfit(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 16)),
            ),
          ),
        ]),
      ),
    );
  }

  Widget _field(String label, TextEditingController ctrl, {String hint = '', int maxLines = 1}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(label, style: GoogleFonts.outfit(fontSize: 12, fontWeight: FontWeight.w700, color: AppTheme.deepSlate)),
        const SizedBox(height: 6),
        TextField(
          controller: ctrl,
          maxLines: maxLines,
          decoration: InputDecoration(
            hintText: hint,
            hintStyle: GoogleFonts.outfit(fontSize: 13, color: AppTheme.textMuted),
            filled: true,
            fillColor: const Color(0xFFF5F7FA),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
            contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          ),
        ),
      ]),
    );
  }

  Future<void> _confirmDeleteInstruction(int id) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
          ),
        ),
      ]),
    );
  }

  Future<void> _confirmDeleteInstruction(int id) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Supprimer la consigne ?', style: GoogleFonts.outfit(fontWeight: FontWeight.w800)),
        content: Text('Cette action est irréversible.', style: GoogleFonts.outfit()),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Annuler')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Supprimer'),
          ),
              }
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
              if (ctx.mounted) Navigator.pop(ctx);
              _loadInstructions();
            },
          );
        }
      ),
    );
  }

  Future<void> _showEditInstructionDialog(Map<String, dynamic> instr) async {
    final territoryCtrl   = TextEditingController(text: instr['territory'] ?? '');
    final cityCtrl        = TextEditingController(text: instr['city'] ?? '');
    final wasteTypeCtrl   = TextEditingController(text: instr['waste_type'] ?? '');
    final titleCtrl       = TextEditingController(text: instr['title'] ?? '');
    final instructionCtrl = TextEditingController(text: instr['instruction'] ?? '');

    String? selectedTerritory = instr['territory'];
    if (selectedTerritory != null && !_territoryCitiesMap.containsKey(selectedTerritory)) {
      selectedTerritory = null;
    }
    
    List<String> citiesForSelectedTerritory = selectedTerritory != null 
        ? (_territoryCitiesMap[selectedTerritory] ?? []) 
        : [];
        
    String? selectedCity = instr['city'];
    if (selectedCity != null && !citiesForSelectedTerritory.contains(selectedCity)) {
      selectedCity = null;
    }

    String? selectedWasteType = instr['waste_type'];
    if (selectedWasteType != null) {
      final matched = _wasteTypesList.firstWhere(
        (t) => t.toLowerCase() == selectedWasteType!.toLowerCase(),
        orElse: () => '',
      );
      selectedWasteType = matched.isNotEmpty ? matched : null;
    }

    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setSheetState) {
          return _instructionForm(
            title: 'Modifier la consigne',
            territoryCtrl: territoryCtrl,
            cityCtrl: cityCtrl,
            wasteTypeCtrl: wasteTypeCtrl,
            titleCtrl: titleCtrl,
            instructionCtrl: instructionCtrl,
            selectedTerritory: selectedTerritory,
            selectedCity: selectedCity,
            selectedWasteType: selectedWasteType,
            citiesList: citiesForSelectedTerritory,
            onTerritoryChanged: (val) {
              setSheetState(() {
                selectedTerritory = val;
                territoryCtrl.text = val ?? '';
                citiesForSelectedTerritory = val != null ? (_territoryCitiesMap[val] ?? []) : [];
                selectedCity = null;
                cityCtrl.text = '';
              });
            },
            onCityChanged: (val) {
              setSheetState(() {
                selectedCity = val;
                cityCtrl.text = val ?? '';
              });
            },
            onWasteTypeChanged: (val) {
              setSheetState(() {
                selectedWasteType = val;
                wasteTypeCtrl.text = val ?? '';
              });
            },
            setSheetState: setSheetState,
            onSave: () async {
              if (territoryCtrl.text.trim().isEmpty ||
                  wasteTypeCtrl.text.trim().isEmpty ||
                  titleCtrl.text.trim().isEmpty ||
                  instructionCtrl.text.trim().isEmpty) {
                ScaffoldMessenger.of(ctx).showSnackBar(
                  const SnackBar(content: Text('Veuillez remplir tous les champs obligatoires (*)')),
                );
                return;
              }
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
              if (ctx.mounted) Navigator.pop(ctx);
              _loadInstructions();
            },
          );
        }
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
    required String? selectedTerritory,
    required String? selectedCity,
    required String? selectedWasteType,
    required List<String> citiesList,
    required ValueChanged<String?> onTerritoryChanged,
    required ValueChanged<String?> onCityChanged,
    required ValueChanged<String?> onWasteTypeChanged,
    required StateSetter setSheetState,
    required VoidCallback onSave,
  }) {
    return Container(
      padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
          Center(child: Container(width: 40, height: 4, decoration: BoxDecoration(color: Colors.grey.shade300, borderRadius: BorderRadius.circular(2)))),
          const SizedBox(height: 16),
          Text(title, style: GoogleFonts.outfit(fontSize: 18, fontWeight: FontWeight.w900, color: AppTheme.deepSlate)),
          const SizedBox(height: 20),
          
          // Territoire Dropdown
          Padding(
            padding: const EdgeInsets.only(bottom: 14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Territoire (Gouvernorat) *', style: GoogleFonts.outfit(fontSize: 12, fontWeight: FontWeight.w700, color: AppTheme.deepSlate)),
                const SizedBox(height: 6),
                DropdownButtonFormField<String>(
                  value: selectedTerritory,
                  hint: Text('Choisir un territoire...', style: GoogleFonts.outfit(fontSize: 13, color: AppTheme.textMuted)),
                  items: _territoryCitiesMap.keys.map((terr) {
                    return DropdownMenuItem<String>(
                      value: terr,
                      child: Text(terr, style: GoogleFonts.outfit(fontSize: 13, color: AppTheme.deepSlate)),
                    );
                  }).toList(),
                  onChanged: onTerritoryChanged,
                  decoration: InputDecoration(
                    filled: true,
                    fillColor: const Color(0xFFF5F7FA),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                  ),
                ),
              ],
            ),
          ),

          // Ville Dropdown
          Padding(










































































                        filled: true,
                        fillColor: const Color(0xFFF5F7FA),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                        suffixIcon: const Icon(Icons.keyboard_arrow_down_rounded, size: 16, color: Colors.grey),
                    );
                  },
                  optionsViewBuilder: (context, onSelected, options) {
                    return Align(
                      alignment: Alignment.topLeft,
                      child: Material(
                        elevation: 4.0,
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(12),
                        child: SizedBox(
                          width: 280, // Match typical modal field width
                          maxHeight: 180,
                          child: ListView.builder(
                            padding: EdgeInsets.zero,
                            shrinkWrap: true,
                            itemCount: options.length,
                            itemBuilder: (BuildContext context, int index) {
                              final String option = options.elementAt(index);
                              return ListTile(
                                dense: true,
                                title: Text(option, style: GoogleFonts.outfit(fontSize: 13, color: const Color(0xFF1E293B))),
                                title: Text(option, style: GoogleFonts.outfit(fontSize: 13, color: const Color(0xFF1E293B))),
                                onTap: () {
                                  onSelected(option);
                                },
                              );
                            },
                          ),
                        ),
                      ),
                    );


































                  }).toList(),
                  onChanged: selectedTerritory == null ? null : onCityChanged,
                  decoration: InputDecoration(
                    filled: true,
                    fillColor: selectedTerritory == null ? const Color(0xFFE2E8F0) : const Color(0xFFF5F7FA),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                  ),
                ),
              ],
            ),
          ),

          // Type de déchet Dropdown
          Padding(
            padding: const EdgeInsets.only(bottom: 1),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                ScaffoldMessenger.of(ctx).showSnackBar(
                  const SnackBar(content: Text('❌ Erreur lors de la création du groupe'), backgroundColor: Colors.red),
                ),
                Text('Type de déchet *', style: GoogleFonts.outfit(fontSize: 12, fontWeight: FontWeight.w700, color: AppTheme.deepSlate)),
                const SizedBox(height: 6),
                DropdownButtonFormField<String>(
                  value: selectedWasteType,
                  hint: Text('Choisir un type...', style: GoogleFonts.outfit(fontSize: 13, color: AppTheme.textMuted)),
                  items: _wasteTypesList.map((type) {
                    final emoji = _wasteIcon(type);
                    return DropdownMenuItem<String>(
                      value: type,
                      child: Text('$emoji $type', style: GoogleFonts.outfit(fontSize: 13, color: AppTheme.deepSlate)),
                    );
                  }).toList(),
                  onChanged: onWasteTypeChanged,
                  decoration: InputDecoration(
                    filled: true,
                    fillColor: const Color(0xFFF5F7FA),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                  ),
                ),
              ],
            ),
          ),

          _field('Titre *', titleCtrl, hint: 'ex: Comment trier le plastique'),
          _field('Consigne *', instructionCtrl, hint: 'Texte de la consigne locale...', maxLines: 4),

          // Puces de règles de tri rapides (Presets)
          Padding(







































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
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Le nom du groupe est obligatoire'), backgroundColor: Colors.red),
                  );
                  return;
                }
                final messenger = ScaffoldMessenger.of(context);
                final jwt = await _jwt();
                if (jwt == null) return;
                final res = await http.post(
                  Uri.parse('${AuthService.baseUrl}/intercommunality/custom-groups'),
                  headers: {
                    ..._headers(jwt),
                    'Content-Type': 'application/json',
                  },
                  body: json.encode({
                    'name': name,
                    'description': descCtrl.text.trim(),
                    'member_ids': selectedActorIds.toList(),
                  }),
                );
                if (res.statusCode == 201) {
                  _loadCustomGroups();
                  if (ctx.mounted) Navigator.pop(ctx);
                  messenger.showSnackBar(
                    const SnackBar(content: Text('✅ Groupe créé avec succès'), backgroundColor: Colors.green),
                  );
                } else {
                  messenger.showSnackBar(
                    const SnackBar(content: Text('âŒ Erreur lors de la création du groupe'), backgroundColor: Colors.red),
                  );
                }
              },
              child: Text('Créer', style: GoogleFonts.outfit(color: Colors.white, fontWeight: FontWeight.bold)),
            ),
          ],
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
        builder: (ctx, setDlg) => AlertDialog(
          title: Text('Notifier les acteurs', style: GoogleFonts.outfit(fontWeight: FontWeight.w900)),
          content: SingleChildScrollView(
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              // Rôles cibles
              Wrap(spacing: 8, children: [
                for (final role in ['pointManager', 'collector', 'educator'])
                  FilterChip(
                    label: Text(_roleLabel(role), style: GoogleFonts.outfit(fontSize: 12)),
                    selected: selectedRoles.contains(role),
                    onSelected: (v) => setDlg(() => v ? selectedRoles.add(role) : selectedRoles.remove(role)),
                    selectedColor: const Color(0xFF6C3EB8).withOpacity(0.15),
                    checkmarkColor: const Color(0xFF6C3EB8),
                  ),
            width: double.maxFinite,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextField(
                    controller: nameCtrl,
                    decoration: InputDecoration(
                      labelText: 'Nom du groupe',
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: descCtrl,
                    maxLines: 2,
                    decoration: InputDecoration(
                      labelText: 'Description',
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'Membres du groupe',
                    style: GoogleFonts.outfit(fontWeight: FontWeight.bold, fontSize: 14),
                  ),
                  const SizedBox(height: 8),
                  if (_actors.isEmpty)
                    Text('Aucun acteur disponible', style: GoogleFonts.inter(color: Colors.grey))
                  else
                    Container(
                      height: 200,
                      decoration: BoxDecoration(
                        border: Border.all(color: Colors.grey.shade300),
                        borderRadius: BorderRadius.circular(12),
                      ),
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
                            subtitle: Text(role.toString().toUpperCase(), style: GoogleFonts.inter(fontSize: 10, color: Colors.grey)),
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
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Le nom du groupe est obligatoire'), backgroundColor: Colors.red),
                  );
                  return;
                }
                final messenger = ScaffoldMessenger.of(context);
                final jwt = await _jwt();
                if (jwt == null) return;
                final res = await http.post(
                  Uri.parse('${AuthService.baseUrl}/intercommunality/custom-groups'),
                  headers: {
                    ..._headers(jwt),
                    'Content-Type': 'application/json',
                  },
                  body: json.encode({
                    'name': name,
                    'description': descCtrl.text.trim(),
                    'member_ids': selectedActorIds.toList(),
                  }),
                );
                if (res.statusCode == 201) {
                  _loadCustomGroups();
                  if (ctx.mounted) Navigator.pop(ctx);
                  messenger.showSnackBar(
                    const SnackBar(content: Text('âœ… Groupe crÃ©Ã© avec succÃ¨s'), backgroundColor: Colors.green),
                  );
                } else {
                  messenger.showSnackBar(
                    const SnackBar(content: Text('Ã¢ÂÅ’ Erreur lors de la crÃ©ation du groupe'), backgroundColor: Colors.red),
                  );
                }
              },
              child: Text('CrÃ©er', style: GoogleFonts.outfit(color: Colors.white, fontWeight: FontWeight.bold)),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _showNotifyActorsDialog() async {
    final selectedRoles = <String>{'pointManager', 'collector', 'educator'};
    final titleCtrl = TextEditingController();
    final msgCtrl = TextEditingController();
