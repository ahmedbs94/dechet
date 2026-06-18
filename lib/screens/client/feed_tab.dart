import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:image_picker/image_picker.dart';
import 'package:timeago/timeago.dart' as timeago;
import '../../theme/app_theme.dart';
import '../../models/user_model.dart';
import '../../services/auth_service.dart';
import '../../widgets/auth_prompt_dialog.dart';
import '../../widgets/safe_network_image.dart';
import '../../constants.dart';
import '../../services/l10n_service.dart';
import 'post_detail_screen.dart';

class FeedTab extends StatefulWidget {
  const FeedTab({Key? key}) : super(key: key);
  @override
  State<FeedTab> createState() => _FeedTabState();
}

class _FeedTabState extends State<FeedTab> with SingleTickerProviderStateMixin {
  final AuthService _auth = AuthService();
  final ScrollController _scroll = ScrollController();
  final TextEditingController _postCtrl = TextEditingController();

  List<Map<String, dynamic>> _posts = [];
  bool _loading = true;
  bool _loadingMore = false;
  bool _hasMore = true;
  String? _error;
  int _skip = 0;
  static const int _pageSize = 20;

  late AnimationController _fabCtrl;

  @override
  void initState() {
    super.initState();
    L10n.addListener(_onLocaleChange);
    timeago.setLocaleMessages('fr', timeago.FrMessages());
    _fabCtrl = AnimationController(vsync: this, duration: 300.ms);
    _scroll.addListener(_onScroll);
    _loadPosts();
  }

  void _onLocaleChange() {
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    L10n.removeListener(_onLocaleChange);
    _scroll.removeListener(_onScroll);
    _scroll.dispose();
    _postCtrl.dispose();
    _fabCtrl.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (_scroll.offset > 80) {
      _fabCtrl.forward();
    } else {
      _fabCtrl.reverse();
    }
    if (_scroll.position.pixels >= _scroll.position.maxScrollExtent - 400) {
      _loadMore();
    }
  }

  Future<void> _loadPosts() async {
    setState(() { _loading = true; _error = null; _skip = 0; _hasMore = true; });
    try {
      final p = await _auth.fetchPosts(skip: 0, limit: _pageSize);
      if (mounted) setState(() { _posts = p.cast<Map<String, dynamic>>(); _loading = false; _skip = p.length; _hasMore = p.length >= _pageSize; });
    } catch (_) {
      if (mounted) setState(() { _error = L10n.tr('Impossible de charger le fil'); _loading = false; });
    }
  }

  Future<void> _loadMore() async {
    if (_loadingMore || !_hasMore) return;
    setState(() => _loadingMore = true);
    try {
      final p = await _auth.fetchPosts(skip: _skip, limit: _pageSize);
      if (mounted) setState(() { _posts.addAll(p.cast<Map<String, dynamic>>()); _skip += p.length; _hasMore = p.length >= _pageSize; _loadingMore = false; });
    } catch (_) { if (mounted) setState(() => _loadingMore = false); }
  }

  String _time(String? d) { if (d == null) return ''; try { return timeago.format(DateTime.parse(d), locale: 'fr'); } catch (_) { return ''; } }

  void _showCreatePost() {
    if (!AuthState.isLoggedIn) { AuthPromptDialog.show(context: context); return; }
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => _CreatePostSheet(auth: _auth, onPosted: _loadPosts),
    );
  }

  @override
  Widget build(BuildContext context) {
    final top = MediaQuery.of(context).padding.top;
    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      body: RefreshIndicator(
        onRefresh: _loadPosts,
        color: AppTheme.primaryGreen,
        strokeWidth: 2.5,
        child: CustomScrollView(
          controller: _scroll,
          physics: const AlwaysScrollableScrollPhysics(parent: BouncingScrollPhysics()),
          slivers: [
            // ── App Bar ──
            SliverAppBar(
              automaticallyImplyLeading: false,
              pinned: true,
              floating: false,
              expandedHeight: 110 + top,
              backgroundColor: Theme.of(context).colorScheme.surface,
              surfaceTintColor: Colors.transparent,
              elevation: 0,
              systemOverlayStyle: Theme.of(context).brightness == Brightness.dark
                  ? SystemUiOverlayStyle.light
                  : SystemUiOverlayStyle.dark,
              flexibleSpace: FlexibleSpaceBar(
                titlePadding: const EdgeInsets.fromLTRB(20, 0, 20, 14),
                title: Row(
                  children: [
                    Container(
                      width: 28, height: 28,
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(colors: [AppTheme.primaryGreen, AppTheme.accentTeal]),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Icon(Icons.eco_rounded, color: Colors.white, size: 16),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      L10n.tr('tab_feed'),
                      style: GoogleFonts.outfit(
                        fontSize: 20,
                        fontWeight: FontWeight.w900,
                        color: Theme.of(context).textTheme.titleLarge?.color ?? const Color(0xFF0F172A),
                      ),
                    ),
                    const Spacer(),
                    GestureDetector(
                      onTap: _showCreatePost,
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                        decoration: BoxDecoration(
                          gradient: const LinearGradient(colors: [AppTheme.primaryGreen, AppTheme.accentTeal]),
                          borderRadius: BorderRadius.circular(20),
                          boxShadow: [BoxShadow(color: AppTheme.primaryGreen.withOpacity(0.3), blurRadius: 8, offset: const Offset(0, 3))],
                        ),
                        child: Row(mainAxisSize: MainAxisSize.min, children: [
                          const Icon(Icons.add_rounded, color: Colors.white, size: 16),
                          const SizedBox(width: 4),
                        Text(L10n.tr('Publier'), style: GoogleFonts.outfit(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w700)),
                        ]),
                      ),
                    ),
                  ],
                ),
              ),
              bottom: PreferredSize(
                preferredSize: const Size.fromHeight(1),
                child: Container(
                  height: 1,
                  color: Theme.of(context).dividerColor,
                ),
              ),
            ),

            // ── Contenu ──
            if (_loading)
              const SliverFillRemaining(child: Center(child: CircularProgressIndicator(color: AppTheme.primaryGreen, strokeWidth: 2)))
            else if (_error != null)
              SliverFillRemaining(child: _ErrorView(message: _error!, onRetry: _loadPosts))
            else if (_posts.isEmpty)
              SliverFillRemaining(child: _EmptyView(onTap: _showCreatePost))
            else ...[
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(16, 14, 16, 0),
                sliver: _MasonryGrid(posts: _posts, auth: _auth, onRefresh: _loadPosts, formatTime: _time),
              ),
              if (_loadingMore)
                const SliverToBoxAdapter(child: Padding(padding: EdgeInsets.all(20), child: Center(child: CircularProgressIndicator(color: AppTheme.primaryGreen, strokeWidth: 2)))),
              const SliverToBoxAdapter(child: SizedBox(height: 100)),
            ],
          ],
        ),
      ),
    );
  }
}

// ── Liste verticale (1 post par ligne) ───────────────────────────────────────
class _MasonryGrid extends StatelessWidget {
  final List<Map<String, dynamic>> posts;
  final AuthService auth;
  final VoidCallback onRefresh;
  final String Function(String?) formatTime;

  const _MasonryGrid({required this.posts, required this.auth, required this.onRefresh, required this.formatTime});

  @override
  Widget build(BuildContext context) {
    return SliverList(
      delegate: SliverChildBuilderDelegate(
        (ctx, i) => Padding(
          padding: const EdgeInsets.only(bottom: 16),
          child: _PinCard(
            key: ValueKey(posts[i]['id']),
            post: posts[i],
            auth: auth,
            onRefresh: onRefresh,
            formatTime: formatTime,
          ).animate().fadeIn(delay: (i * 60).ms, duration: 400.ms).slideY(begin: 0.06),
        ),
        childCount: posts.length,
      ),
    );
  }
}


// ── Pinterest Pin Card ────────────────────────────────────────────────────────
class _PinCard extends StatefulWidget {
  final Map<String, dynamic> post;
  final AuthService auth;
  final VoidCallback onRefresh;
  final String Function(String?) formatTime;
  const _PinCard({super.key, required this.post, required this.auth, required this.onRefresh, required this.formatTime});
  @override
  State<_PinCard> createState() => _PinCardState();
}

class _PinCardState extends State<_PinCard> {
  late bool _liked;
  late int _likes;
  late bool _saved;

  @override
  void initState() {
    super.initState();
    _liked = widget.post['is_liked'] == true;
    _likes = widget.post['likes_count'] ?? 0;
    _saved = widget.post['is_saved'] == true;
  }

  Future<void> _toggleLike() async {
    if (!AuthState.isLoggedIn) { AuthPromptDialog.show(context: context); return; }
    setState(() { _liked = !_liked; _liked ? _likes++ : _likes = (_likes - 1).clamp(0, 9999); });
    final r = await widget.auth.toggleLikePost(widget.post['id'].toString());
    if (r['success'] == true && mounted) { setState(() { _liked = r['liked'] ?? _liked; _likes = r['count'] ?? _likes; }); }
  }

  Future<void> _toggleSave() async {
    if (!AuthState.isLoggedIn) { AuthPromptDialog.show(context: context); return; }
    setState(() => _saved = !_saved);
    final r = await widget.auth.toggleSavePost(widget.post['id'].toString());
    if (r['success'] == true && mounted) { setState(() => _saved = r['saved'] ?? _saved); }
    else if (mounted) { setState(() => _saved = !_saved); }
  }

  void _goToDetails() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => PostDetailScreen(post: widget.post),
      ),
    ).then((_) {
      widget.onRefresh();
    });
  }

  @override
  Widget build(BuildContext context) {
    final imageUrl = widget.post['image_url'] as String? ?? '';
    final hasImage = imageUrl.isNotEmpty;
    final name = widget.post['user_name'] as String? ?? 'Anonyme';
    final desc = widget.post['description'] as String? ?? '';
    final avatarUrl = widget.post['user_avatar_url'] as String? ?? '';
    final timeStr = widget.formatTime(widget.post['created_at']);
    final isOwn = AuthState.isLoggedIn && name == AuthState.currentUser?.name;
    final commentsCount = (widget.post['comments'] as List?)?.length ?? 0;

    return GestureDetector(
      onTap: _goToDetails,
      child: Container(
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surface,
          borderRadius: BorderRadius.circular(20),
          boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.06), blurRadius: 12, offset: const Offset(0, 4))],
        ),
        clipBehavior: Clip.hardEdge,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── Image avec overlay actions ──
            if (hasImage)
              Stack(children: [
                AspectRatio(
                  aspectRatio: 0.75,
                  child: SafeNetworkImage(
                    ApiConstants.resolveUrl(imageUrl),
                    fit: BoxFit.cover,
                    width: double.infinity,
                  ),
                ),
                // Overlay gradient bas
                Positioned(
                  bottom: 0, left: 0, right: 0,
                  child: Container(
                    height: 70,
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.bottomCenter, end: Alignment.topCenter,
                        colors: [Colors.black.withOpacity(0.55), Colors.transparent],
                      ),
                    ),
                  ),
                ),
                // Boutons action overlay (Toujours visible)
                Positioned(
                  bottom: 8, right: 8,
                  child: Row(children: [
                    _ActionBtn(
                      icon: _liked ? Icons.favorite_rounded : Icons.favorite_border_rounded,
                      color: _liked ? const Color(0xFFFF4B6E) : Colors.white,
                      label: '$_likes',
                      onTap: _toggleLike,
                    ),
                    const SizedBox(width: 6),
                    _ActionBtn(
                      icon: Icons.chat_bubble_outline_rounded,
                      color: Colors.white,
                      label: '$commentsCount',
                      onTap: _goToDetails,
                    ),
                  ]),
                ),
                // Bouton save toujours visible en haut à droite
                Positioned(
                  top: 8, right: 8,
                  child: GestureDetector(
                    onTap: _toggleSave,
                    child: Container(
                      width: 32, height: 32,
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.9),
                        shape: BoxShape.circle,
                        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.1), blurRadius: 6)],
                      ),
                      child: Icon(_saved ? Icons.bookmark_rounded : Icons.bookmark_border_rounded, size: 16, color: _saved ? AppTheme.primaryGreen : Colors.grey.shade600),
                    ),
                  ),
                ),
              ]),

            // ── Texte & Auteur ──
            Padding(
              padding: const EdgeInsets.all(10),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (desc.isNotEmpty) ...[
                    Text(
                      desc,
                      style: GoogleFonts.inter(
                        fontSize: 12.5,
                        height: 1.45,
                        color: Theme.of(context).textTheme.bodyLarge?.color?.withOpacity(0.9) ?? const Color(0xFF1E293B),
                      ),
                      maxLines: hasImage ? 2 : 5,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 8),
                  ],
                  // Si pas d'image, afficher les likes et commentaires ici
                  if (!hasImage)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: Row(children: [
                        GestureDetector(onTap: _toggleLike, child: Icon(_liked ? Icons.favorite_rounded : Icons.favorite_border_rounded, size: 16, color: _liked ? const Color(0xFFFF4B6E) : Colors.grey.shade400)),
                        const SizedBox(width: 4),
                        Text('$_likes', style: GoogleFonts.inter(fontSize: 11, color: Colors.grey.shade500)),
                        const SizedBox(width: 12),
                        GestureDetector(
                          onTap: _goToDetails,
                          child: Icon(Icons.chat_bubble_outline_rounded, size: 15, color: Colors.grey.shade400),
                        ),
                        const SizedBox(width: 4),
                        Text('$commentsCount', style: GoogleFonts.inter(fontSize: 11, color: Colors.grey.shade500)),
                        const Spacer(),
                        GestureDetector(onTap: _toggleSave, child: Icon(_saved ? Icons.bookmark_rounded : Icons.bookmark_border_rounded, size: 16, color: _saved ? AppTheme.primaryGreen : Colors.grey.shade400)),
                      ]),
                    ),
                  // Auteur
                  Row(children: [
                    if (avatarUrl.isNotEmpty)
                      ClipOval(child: SizedBox(width: 22, height: 22, child: SafeNetworkImage(ApiConstants.resolveUrl(avatarUrl), fit: BoxFit.cover)))
                    else
                      CircleAvatar(radius: 11, backgroundColor: AppTheme.primaryGreen.withOpacity(0.15), child: Text(name.isNotEmpty ? name[0].toUpperCase() : '?', style: GoogleFonts.outfit(fontSize: 10, fontWeight: FontWeight.bold, color: AppTheme.primaryGreen))),
                    const SizedBox(width: 6),
                    Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Text(
                        name,
                        style: GoogleFonts.inter(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: Theme.of(context).textTheme.bodyLarge?.color?.withOpacity(0.8) ?? const Color(0xFF334155),
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                      if (timeStr.isNotEmpty)
                        Text(timeStr, style: GoogleFonts.inter(fontSize: 9.5, color: Colors.grey.shade400)),
                    ])),
                    if (isOwn)
                      GestureDetector(
                        onTap: () async {
                          final ok = await showDialog<bool>(context: context, builder: (ctx) => AlertDialog(
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                            title: Text('Supprimer ?', style: GoogleFonts.outfit(fontWeight: FontWeight.bold)),
                            actions: [
                              TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Annuler')),
                              ElevatedButton(onPressed: () => Navigator.pop(ctx, true), style: ElevatedButton.styleFrom(backgroundColor: Colors.red), child: const Text('Supprimer')),
                            ],
                          ));
                          if (ok == true) { await widget.auth.deletePost(widget.post['id'].toString()); widget.onRefresh(); }
                        },
                        child: Icon(Icons.more_horiz_rounded, size: 18, color: Colors.grey.shade400),
                      ),
                  ]),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ActionBtn extends StatelessWidget {
  final IconData icon;
  final Color color;
  final String? label;
  final VoidCallback onTap;
  const _ActionBtn({required this.icon, required this.color, required this.onTap, this.label});
  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
        decoration: BoxDecoration(color: Colors.black.withOpacity(0.4), borderRadius: BorderRadius.circular(20)),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          Icon(icon, size: 14, color: color),
          if (label != null) ...[const SizedBox(width: 4), Text(label!, style: GoogleFonts.outfit(fontSize: 11, color: Colors.white, fontWeight: FontWeight.w700))],
        ]),
      ),
    );
  }
}

// ── Create Post Bottom Sheet ──────────────────────────────────────────────────
class _CreatePostSheet extends StatefulWidget {
  final AuthService auth;
  final VoidCallback onPosted;
  const _CreatePostSheet({required this.auth, required this.onPosted});
  @override
  State<_CreatePostSheet> createState() => _CreatePostSheetState();
}

class _CreatePostSheetState extends State<_CreatePostSheet> {
  final _ctrl = TextEditingController();
  XFile? _image;
  bool _uploading = false;

  @override
  void dispose() { _ctrl.dispose(); super.dispose(); }

  Future<void> _pickImage() async {
    final img = await ImagePicker().pickImage(source: ImageSource.gallery, imageQuality: 85);
    if (img != null) setState(() => _image = img);
  }

  Future<void> _submit() async {
    if (_uploading) return;
    setState(() => _uploading = true);
    try {
      String? url;
      if (_image != null) url = await widget.auth.uploadImageFromXFile(_image!);
      final u = AuthState.currentUser;
      final r = await widget.auth.createPost(
        userName: u?.name ?? 'Anonyme',
        userAvatarUrl: u?.avatarUrl ?? '',
        imageUrl: url ?? '',
        description: _ctrl.text,
      );
      if (!mounted) return;
      Navigator.pop(context);
      if (r['success'] == true) {
        final pending = r['ai_flagged'] == true || r['status'] == 'pending_review';
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(pending ? (L10n.isArabic ? '⏳ المنشور في انتظار التحقق' : '⏳ Publication en attente de validation') : (L10n.isArabic ? '✅ تم نشر المنشور!' : '✅ Publication publiée !')),
          backgroundColor: pending ? Colors.orange : AppTheme.primaryGreen,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        ));
        widget.onPosted();
      }
    } finally { if (mounted) setState(() => _uploading = false); }
  }

  @override
  Widget build(BuildContext context) {
    final kb = MediaQuery.of(context).viewInsets.bottom;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      padding: EdgeInsets.fromLTRB(20, 20, 20, 20 + kb),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
      ),
      child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Center(child: Container(width: 36, height: 4, decoration: BoxDecoration(color: isDark ? Colors.grey.shade700 : Colors.grey.shade300, borderRadius: BorderRadius.circular(2)))),
        const SizedBox(height: 16),
        Row(children: [
          Text(
            L10n.tr('Nouvelle publication'),
            style: GoogleFonts.outfit(
              fontSize: 18,
              fontWeight: FontWeight.w800,
              color: Theme.of(context).textTheme.titleLarge?.color ?? const Color(0xFF0F172A),
            ),
          ),
          const Spacer(),
          IconButton(onPressed: () => Navigator.pop(context), icon: const Icon(Icons.close_rounded), color: Colors.grey.shade500),
        ]),
        const SizedBox(height: 12),
        TextField(
          controller: _ctrl,
          maxLines: 3,
          style: GoogleFonts.inter(fontSize: 14),
          decoration: InputDecoration(
            hintText: L10n.tr('Partagez votre geste écologique...'),
            hintStyle: GoogleFonts.inter(color: Colors.grey.shade400),
            filled: true,
            fillColor: isDark ? Colors.white.withOpacity(0.05) : const Color(0xFFF8F7F5),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide.none),
            contentPadding: const EdgeInsets.all(14),
          ),
        ),
        const SizedBox(height: 12),
        if (_image != null)
          Stack(children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(16),
              child: kIsWeb
                ? Image.network(_image!.path, height: 160, width: double.infinity, fit: BoxFit.cover)
                : Image.file(File(_image!.path), height: 160, width: double.infinity, fit: BoxFit.cover),
            ),
            Positioned(top: 8, right: 8, child: GestureDetector(
              onTap: () => setState(() => _image = null),
              child: Container(padding: const EdgeInsets.all(4), decoration: const BoxDecoration(color: Colors.black54, shape: BoxShape.circle), child: const Icon(Icons.close, color: Colors.white, size: 16)),
            )),
          ])
        else
          GestureDetector(
            onTap: _pickImage,
            child: Container(
              height: 80,
              decoration: BoxDecoration(
                color: const Color(0xFFF0FDF4),
                border: Border.all(color: AppTheme.primaryGreen.withOpacity(0.3), width: 1.5),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                const Icon(Icons.add_photo_alternate_rounded, color: AppTheme.primaryGreen, size: 22),
                const SizedBox(width: 8),
                Text(L10n.tr('Ajouter une photo'), style: GoogleFonts.inter(color: AppTheme.primaryGreen, fontWeight: FontWeight.w600, fontSize: 13)),
              ]),
            ),
          ),
        const SizedBox(height: 16),
        ElevatedButton(
          onPressed: (_uploading || (_ctrl.text.isEmpty && _image == null)) ? null : _submit,
          style: ElevatedButton.styleFrom(
            backgroundColor: AppTheme.primaryGreen,
            disabledBackgroundColor: Colors.grey.shade200,
            padding: const EdgeInsets.symmetric(vertical: 15),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            elevation: 0,
          ),
          child: _uploading
            ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
            : Text(L10n.tr('Publier'), style: GoogleFonts.outfit(fontSize: 16, fontWeight: FontWeight.w800, color: Colors.white)),
        ),
      ]),
    );
  }
}

// ── Empty & Error views ───────────────────────────────────────────────────────
class _EmptyView extends StatelessWidget {
  final VoidCallback onTap;
  const _EmptyView({required this.onTap});
  @override
  Widget build(BuildContext context) {
    return Center(child: Column(mainAxisSize: MainAxisSize.min, children: [
      Container(padding: const EdgeInsets.all(24), decoration: BoxDecoration(color: AppTheme.primaryGreen.withOpacity(0.08), shape: BoxShape.circle),
        child: const Icon(Icons.eco_rounded, size: 52, color: AppTheme.primaryGreen)),
      const SizedBox(height: 20),
      Text(L10n.tr('Aucune publication'), style: GoogleFonts.outfit(fontSize: 20, fontWeight: FontWeight.w800, color: const Color(0xFF0F172A))),
      const SizedBox(height: 8),
      Text(L10n.tr('Soyez le premier à partager un geste éco !'), style: GoogleFonts.inter(fontSize: 14, color: Colors.grey.shade500), textAlign: TextAlign.center),
      const SizedBox(height: 24),
      ElevatedButton.icon(
        onPressed: onTap,
        icon: const Icon(Icons.add_rounded, size: 18),
        label: Text(L10n.tr('Créer une publication'), style: GoogleFonts.outfit(fontWeight: FontWeight.w700)),
        style: ElevatedButton.styleFrom(backgroundColor: AppTheme.primaryGreen, foregroundColor: Colors.white,
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16))),
      ),
    ]));
  }
}

class _ErrorView extends StatelessWidget {
  final String message;
  final VoidCallback onRetry;
  const _ErrorView({required this.message, required this.onRetry});
  @override
  Widget build(BuildContext context) {
    return Center(child: Column(mainAxisSize: MainAxisSize.min, children: [
      Icon(Icons.wifi_off_rounded, size: 48, color: Colors.grey.shade400),
      const SizedBox(height: 16),
      Text(message, style: GoogleFonts.inter(color: const Color(0xFF334155), fontWeight: FontWeight.w600)),
      const SizedBox(height: 12),
      TextButton.icon(onPressed: onRetry, icon: const Icon(Icons.refresh_rounded), label: Text(L10n.tr('Réessayer')), style: TextButton.styleFrom(foregroundColor: AppTheme.primaryGreen)),
    ]));
  }
}
