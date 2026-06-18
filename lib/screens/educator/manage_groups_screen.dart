// lib/screens/educator/manage_groups_screen.dart
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../../services/groups_service.dart';
import '../../services/l10n_service.dart';

class ManageGroupsScreen extends StatefulWidget {
  const ManageGroupsScreen({Key? key}) : super(key: key);
  @override
  State<ManageGroupsScreen> createState() => _ManageGroupsScreenState();
}

class _ManageGroupsScreenState extends State<ManageGroupsScreen> {
  List<dynamic> _groups = [];
  bool _loading = true;

  static const _kGreen  = Color(0xFF00C896);
  static const _kBg     = Color(0xFF0F1923);
  static const _kCard   = Color(0xFF1A2634);

  // Palette de couleurs pour les groupes
  static const _kPalette = [
    '#00C896', '#6C5CE7', '#FDCB6E', '#E17055',
    '#0984E3', '#00B894', '#FD79A8', '#55EFC4',
  ];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final data = await GroupsService.getMyGroups();
    if (mounted) setState(() { _groups = data; _loading = false; });
  }

  // ── Créer / Modifier un groupe ─────────────────────────────────────────────

  Future<void> _showGroupDialog({Map<String, dynamic>? existing}) async {
    final nameCtrl = TextEditingController(text: existing?['name'] ?? '');
    final descCtrl = TextEditingController(text: existing?['description'] ?? '');
    String selectedColor = existing?['color'] ?? _kPalette[0];

    await showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(builder: (ctx, setInner) {
        return Dialog(
          backgroundColor: _kCard,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(existing == null ? (L10n.isArabic ? 'مجموعة جديدة' : 'Nouveau groupe') : (L10n.isArabic ? 'تعديل المجموعة' : 'Modifier le groupe'),
                style: GoogleFonts.outfit(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
              const SizedBox(height: 20),

              // Nom
              TextField(
                controller: nameCtrl,
                style: GoogleFonts.inter(color: Colors.white),
                decoration: _inputDeco(L10n.isArabic ? 'اسم المجموعة' : 'Nom du groupe', Icons.group_rounded),
              ),
              const SizedBox(height: 14),

              // Description
              TextField(
                controller: descCtrl,
                style: GoogleFonts.inter(color: Colors.white),
                maxLines: 2,
                decoration: _inputDeco(L10n.isArabic ? 'وصف (اختياري)' : 'Description (optionnel)', Icons.notes_rounded),
              ),
              const SizedBox(height: 16),

              // Couleur
              Text(L10n.isArabic ? 'اللون' : 'Couleur', style: GoogleFonts.inter(color: Colors.white70, fontSize: 12)),
              const SizedBox(height: 8),
              Wrap(spacing: 10, children: _kPalette.map((c) {
                final color = _hexColor(c);
                final sel = selectedColor == c;
                return GestureDetector(
                  onTap: () => setInner(() => selectedColor = c),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 150),
                    width: 32, height: 32,
                    decoration: BoxDecoration(
                      color: color,
                      shape: BoxShape.circle,
                      border: sel ? Border.all(color: Colors.white, width: 3) : null,
                      boxShadow: sel ? [BoxShadow(color: color.withOpacity(0.6), blurRadius: 8)] : [],
                    ),
                    child: sel ? const Icon(Icons.check, color: Colors.white, size: 18) : null,
                  ),
                );
              }).toList()),

              const SizedBox(height: 24),
              Row(children: [
                Expanded(child: TextButton(
                  onPressed: () => Navigator.pop(ctx),
                  child: Text(L10n.isArabic ? 'إلغاء' : 'Annuler', style: GoogleFonts.outfit(color: Colors.white54)),
                )),
                const SizedBox(width: 10),
                Expanded(child: ElevatedButton(
                  onPressed: () async {
                    if (nameCtrl.text.trim().isEmpty) return;
                    Navigator.pop(ctx);
                    if (existing == null) {
                      final res = await GroupsService.createGroup(
                        name: nameCtrl.text.trim(),
                        description: descCtrl.text.trim(),
                        color: selectedColor,
                      );
                      if (res['success'] == true) _load();
                    } else {
                      await GroupsService.updateGroup(
                        existing['id'], nameCtrl.text.trim(),
                        descCtrl.text.trim(), selectedColor,
                      );
                      _load();
                    }
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _kGreen,
                    foregroundColor: Colors.black,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                  child: Text(existing == null ? (L10n.isArabic ? 'إنشاء' : 'Créer') : (L10n.isArabic ? 'حفظ' : 'Enregistrer'),
                    style: GoogleFonts.outfit(fontWeight: FontWeight.bold)),
                )),
              ]),
            ]),
          ),
        );
      }),
    );
  }

  // ── Ouvrir le détail du groupe avec ses membres ────────────────────────────

  Future<void> _openGroupDetail(Map<String, dynamic> group) async {
    await Navigator.push(context, MaterialPageRoute(
      builder: (_) => _GroupDetailScreen(group: group),
    ));
    _load(); // refresh après retour
  }

  // ── Supprimer un groupe ────────────────────────────────────────────────────

  Future<void> _deleteGroup(Map<String, dynamic> group) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: _kCard,
        title: Text('${L10n.isArabic ? 'حذف' : 'Supprimer'} "${group['name']}" ?',
          style: GoogleFonts.outfit(color: Colors.white)),
        content: Text(L10n.isArabic ? 'سيتم إزالة جميع الأعضاء.' : 'Tous les membres seront retirés.',
          style: GoogleFonts.inter(color: Colors.white70)),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false),
            child: Text(L10n.isArabic ? 'إلغاء' : 'Annuler', style: GoogleFonts.outfit(color: Colors.white54))),
          TextButton(onPressed: () => Navigator.pop(context, true),
            child: Text(L10n.isArabic ? 'حذف' : 'Supprimer', style: GoogleFonts.outfit(color: Colors.red))),
        ],
      ),
    );
    if (confirm == true) {
      await GroupsService.deleteGroup(group['id']);
      _load();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _kBg,
      appBar: AppBar(
        backgroundColor: _kBg,
        elevation: 0,
        title: Text(L10n.isArabic ? 'مجموعات المواطنين' : 'Groupes de citoyens',
          style: GoogleFonts.outfit(color: Colors.white, fontWeight: FontWeight.bold)),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh_rounded, color: Colors.white54),
            onPressed: _load,
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _showGroupDialog(),
        backgroundColor: _kGreen,
        foregroundColor: Colors.black,
        icon: const Icon(Icons.add_rounded),
        label: Text(L10n.isArabic ? 'مجموعة جديدة' : 'Nouveau groupe', style: GoogleFonts.outfit(fontWeight: FontWeight.bold)),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator(color: _kGreen))
          : _groups.isEmpty
              ? _EmptyGroups(onCreate: () => _showGroupDialog())
              : ListView.builder(
                  padding: const EdgeInsets.fromLTRB(20, 16, 20, 100),
                  itemCount: _groups.length,
                  itemBuilder: (_, i) {
                    final g = _groups[i] as Map<String, dynamic>;
                    final color = _hexColor(g['color'] ?? '#00C896');
                    return _GroupCard(
                      group: g,
                      color: color,
                      onTap: () => _openGroupDetail(g),
                      onEdit: () => _showGroupDialog(existing: g),
                      onDelete: () => _deleteGroup(g),
                    ).animate().fadeIn(delay: Duration(milliseconds: i * 60)).slideY(begin: 0.05);
                  },
                ),
    );
  }

  InputDecoration _inputDeco(String hint, IconData icon) => InputDecoration(
    hintText: hint,
    hintStyle: GoogleFonts.inter(color: Colors.white38),
    prefixIcon: Icon(icon, color: _kGreen, size: 20),
    filled: true,
    fillColor: const Color(0xFF0F1923),
    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
    focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12),
      borderSide: const BorderSide(color: _kGreen, width: 1.5)),
  );
}

// ── Carte groupe ──────────────────────────────────────────────────────────────

class _GroupCard extends StatelessWidget {
  final Map<String, dynamic> group;
  final Color color;
  final VoidCallback onTap, onEdit, onDelete;
  const _GroupCard({required this.group, required this.color,
    required this.onTap, required this.onEdit, required this.onDelete});

  @override
  Widget build(BuildContext context) {
    final memberCount = group['member_count'] ?? 0;
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      child: Material(
        color: const Color(0xFF1A2634),
        borderRadius: BorderRadius.circular(16),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(16),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(children: [
              // Avatar couleur
              Container(
                width: 48, height: 48,
                decoration: BoxDecoration(
                  color: color.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: color.withOpacity(0.4)),
                ),
                child: Center(child: Text(
                  group['name'].substring(0, 1).toUpperCase(),
                  style: GoogleFonts.outfit(color: color, fontSize: 22, fontWeight: FontWeight.bold),
                )),
              ),
              const SizedBox(width: 14),
              Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(group['name'],
                  style: GoogleFonts.outfit(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
                if ((group['description'] as String? ?? '').isNotEmpty) ...[
                  const SizedBox(height: 2),
                  Text(group['description'],
                    style: GoogleFonts.inter(color: Colors.white54, fontSize: 12),
                    maxLines: 1, overflow: TextOverflow.ellipsis),
                ],
                const SizedBox(height: 6),
                Row(children: [
                  Icon(Icons.people_rounded, size: 14, color: color),
                  const SizedBox(width: 4),
                  Text('$memberCount ${L10n.isArabic ? 'مواطن' : 'citoyen${memberCount != 1 ? 's' : ''}'}',
                    style: GoogleFonts.inter(color: color, fontSize: 12, fontWeight: FontWeight.w600)),
                ]),
              ])),
              PopupMenuButton<String>(
                color: const Color(0xFF1A2634),
                icon: const Icon(Icons.more_vert_rounded, color: Colors.white54),
                onSelected: (v) {
                  if (v == 'edit') onEdit();
                  if (v == 'delete') onDelete();
                },
                itemBuilder: (_) => [
                  PopupMenuItem(value: 'edit',
                    child: Row(children: [
                      const Icon(Icons.edit_rounded, color: Colors.blue, size: 18),
                      const SizedBox(width: 10),
                      Text(L10n.isArabic ? 'تعديل' : 'Modifier', style: GoogleFonts.inter(color: Colors.white)),
                    ])),
                  PopupMenuItem(value: 'delete',
                    child: Row(children: [
                      const Icon(Icons.delete_rounded, color: Colors.red, size: 18),
                      const SizedBox(width: 10),
                      Text(L10n.isArabic ? 'حذف' : 'Supprimer', style: GoogleFonts.inter(color: Colors.white)),
                    ])),
                ],
              ),
            ]),
          ),
        ),
      ),
    );
  }
}

// ── Détail d'un groupe (membres) ──────────────────────────────────────────────

class _GroupDetailScreen extends StatefulWidget {
  final Map<String, dynamic> group;
  const _GroupDetailScreen({required this.group});
  @override
  State<_GroupDetailScreen> createState() => _GroupDetailScreenState();
}

class _GroupDetailScreenState extends State<_GroupDetailScreen> {
  List<dynamic> _members = [];
  List<dynamic> _allCitizens = [];
  String _search = '';
  bool _loadingCitizens = false;

  static const _kGreen = Color(0xFF00C896);
  static const _kBg    = Color(0xFF0F1923);
  static const _kCard  = Color(0xFF1A2634);

  @override
  void initState() {
    super.initState();
    _members = List<dynamic>.from(widget.group['members'] ?? []);
    _loadCitizens();
  }

  Future<void> _loadCitizens({String q = ''}) async {
    setState(() => _loadingCitizens = true);
    final data = await GroupsService.searchCitizens(q: q);
    if (mounted) setState(() { _allCitizens = data; _loadingCitizens = false; });
  }

  bool _isMember(int userId) => _members.any((m) => m['user_id'] == userId);

  Future<void> _toggle(Map<String, dynamic> citizen) async {
    final uid = citizen['id'] as int;
    if (_isMember(uid)) {
      final ok = await GroupsService.removeMember(widget.group['id'], uid);
      if (ok && mounted) {
        setState(() => _members.removeWhere((m) => m['user_id'] == uid));
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('${citizen['full_name']} ${L10n.isArabic ? 'أُزيل من المجموعة' : 'retiré du groupe'}'),
          backgroundColor: Colors.orange,
        ));
      }
    } else {
      final ok = await GroupsService.addMember(widget.group['id'], uid);
      if (ok && mounted) {
        setState(() => _members.add({
          'user_id': uid,
          'user_name': citizen['full_name'],
          'email': citizen['email'],
        }));
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('${citizen['full_name']} ${L10n.isArabic ? 'أُضيف إلى المجموعة' : 'ajouté au groupe'}'),
          backgroundColor: _kGreen,
        ));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final color = _hexColor(widget.group['color'] ?? '#00C896');
    final filtered = _allCitizens.where((c) {
      if (_search.isEmpty) return true;
      final name = (c['full_name'] as String? ?? '').toLowerCase();
      final email = (c['email'] as String? ?? '').toLowerCase();
      return name.contains(_search.toLowerCase()) || email.contains(_search.toLowerCase());
    }).toList();

    return Scaffold(
      backgroundColor: _kBg,
      appBar: AppBar(
        backgroundColor: _kBg,
        elevation: 0,
        title: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(widget.group['name'],
            style: GoogleFonts.outfit(color: Colors.white, fontWeight: FontWeight.bold)),
          Text('${_members.length} ${L10n.isArabic ? 'عضو' : 'membre(s)'}',
            style: GoogleFonts.inter(color: Colors.white54, fontSize: 12)),
        ]),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: Column(children: [
        // ── Barre de recherche ─────────────────────────────────────────
        Padding(
          padding: const EdgeInsets.all(16),
          child: TextField(
            style: GoogleFonts.inter(color: Colors.white),
            onChanged: (v) {
              setState(() => _search = v);
              if (v.length > 1) { _loadCitizens(q: v); }
              else if (v.isEmpty) { _loadCitizens(); }
            },
            decoration: InputDecoration(
              hintText: L10n.isArabic ? 'البحث عن مواطن...' : 'Rechercher un citoyen...',
              hintStyle: GoogleFonts.inter(color: Colors.white38),
              prefixIcon: const Icon(Icons.search_rounded, color: _kGreen),
              filled: true,
              fillColor: _kCard,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide.none,
              ),
            ),
          ),
        ),

        // ── Membres actuels chips ──────────────────────────────────────
        if (_members.isNotEmpty)
          Container(
            height: 42,
            margin: const EdgeInsets.only(bottom: 8),
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 16),
              itemCount: _members.length,
              separatorBuilder: (_, __) => const SizedBox(width: 8),
              itemBuilder: (_, i) {
                final m = _members[i];
                return Chip(
                  backgroundColor: color.withOpacity(0.15),
                  side: BorderSide(color: color.withOpacity(0.4)),
                  label: Text(m['user_name'] ?? '',
                    style: GoogleFonts.inter(color: color, fontSize: 12)),
                  deleteIcon: Icon(Icons.close_rounded, size: 14, color: color),
                  onDeleted: () => _toggle({'id': m['user_id'], 'full_name': m['user_name']}),
                );
              },
            ),
          ),

        // ── Liste tous les citoyens ────────────────────────────────────
        Expanded(
          child: _loadingCitizens
              ? const Center(child: CircularProgressIndicator(color: _kGreen))
              : ListView.builder(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  itemCount: filtered.length,
                  itemBuilder: (_, i) {
                    final c = filtered[i] as Map<String, dynamic>;
                    final uid = c['id'] as int;
                    final inGroup = _isMember(uid);
                    return ListTile(
                      contentPadding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                      leading: CircleAvatar(
                        backgroundColor: color.withOpacity(0.15),
                        backgroundImage: (c['avatar_url'] as String? ?? '').isNotEmpty
                            ? NetworkImage(c['avatar_url']) : null,
                        onBackgroundImageError: (_, __) {},
                        child: (c['avatar_url'] as String? ?? '').isEmpty
                            ? Text((c['full_name'] as String? ?? 'U')[0].toUpperCase(),
                                style: GoogleFonts.outfit(color: color, fontWeight: FontWeight.bold))
                            : null,
                      ),
                      title: Text(c['full_name'] ?? '',
                        style: GoogleFonts.inter(color: Colors.white, fontSize: 14)),
                      subtitle: Text(c['email'] ?? '',
                        style: GoogleFonts.inter(color: Colors.white54, fontSize: 12)),
                      trailing: AnimatedSwitcher(
                        duration: const Duration(milliseconds: 200),
                        child: inGroup
                            ? Container(
                                key: const ValueKey('in'),
                                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                                decoration: BoxDecoration(
                                  color: _kGreen.withOpacity(0.15),
                                  borderRadius: BorderRadius.circular(8),
                                  border: Border.all(color: _kGreen.withOpacity(0.4)),
                                ),
                                child: Text(L10n.isArabic ? 'عضو ✓' : 'Membre ✓',
                                  style: GoogleFonts.inter(color: _kGreen, fontSize: 12, fontWeight: FontWeight.w600)),
                              )
                            : OutlinedButton(
                                key: const ValueKey('out'),
                                onPressed: () => _toggle(c),
                                style: OutlinedButton.styleFrom(
                                  foregroundColor: Colors.white70,
                                  side: const BorderSide(color: Colors.white24),
                                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                                ),
                                child: Text(L10n.isArabic ? 'إضافة' : 'Ajouter', style: GoogleFonts.inter(fontSize: 12)),
                              ),
                      ),
                      onTap: () => _toggle(c),
                    );
                  },
                ),
        ),
      ]),
    );
  }
}

// ── Empty state ───────────────────────────────────────────────────────────────

class _EmptyGroups extends StatelessWidget {
  final VoidCallback onCreate;
  const _EmptyGroups({required this.onCreate});
  @override
  Widget build(BuildContext context) => Center(
    child: Column(mainAxisSize: MainAxisSize.min, children: [
      Container(
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: const Color(0xFF00C896).withOpacity(0.08),
          shape: BoxShape.circle,
        ),
        child: const Icon(Icons.group_add_rounded, color: Color(0xFF00C896), size: 48),
      ),
      const SizedBox(height: 16),
      Text(L10n.isArabic ? 'لا توجد مجموعات' : 'Aucun groupe créé',
        style: GoogleFonts.outfit(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
      const SizedBox(height: 8),
      Text(L10n.isArabic ? 'أنشئ مجموعات لتنظيم\nمواطنيك وجدولة الجلسات.' : 'Créez des groupes pour organiser\nvos citoyens et planifier des séances.',
        textAlign: TextAlign.center,
        style: GoogleFonts.inter(color: Colors.white54, fontSize: 13, height: 1.5)),
      const SizedBox(height: 24),
      ElevatedButton.icon(
        onPressed: onCreate,
        icon: const Icon(Icons.add_rounded),
        label: Text(L10n.isArabic ? 'إنشاء مجموعة' : 'Créer un groupe', style: GoogleFonts.outfit(fontWeight: FontWeight.bold)),
        style: ElevatedButton.styleFrom(
          backgroundColor: const Color(0xFF00C896),
          foregroundColor: Colors.black,
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
      ),
    ]),
  );
}

// ── Utilitaire couleur hex ────────────────────────────────────────────────────

Color _hexColor(String hex) {
  final h = hex.replaceAll('#', '');
  return Color(int.parse('FF$h', radix: 16));
}
