import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter_animate/flutter_animate.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:image_picker/image_picker.dart';
import 'package:timeago/timeago.dart' as timeago;
import '../../theme/app_theme.dart';
import '../../models/user_model.dart';
import '../../services/auth_service.dart';
import '../../widgets/auth_prompt_dialog.dart';

class FeedTab extends StatefulWidget {
  const FeedTab({Key? key}) : super(key: key);

  @override
  State<FeedTab> createState() => _FeedTabState();
}

class _FeedTabState extends State<FeedTab> {
  final AuthService _authService = AuthService();
  List<Map<String, dynamic>> _posts = [];
  bool _isLoading = true;
  String? _error;
  final TextEditingController _postController = TextEditingController();

  @override
  void initState() {
    super.initState();
    timeago.setLocaleMessages('fr', timeago.FrMessages());
    _loadPosts();
  }

  Future<void> _loadPosts() async {
    setState(() { _isLoading = true; _error = null; });
    try {
      final posts = await _authService.fetchAllPosts();
      if (mounted) setState(() { _posts = posts.cast<Map<String, dynamic>>(); _isLoading = false; });
    } catch (e) {
      if (mounted) setState(() { _error = 'Impossible de charger les publications'; _isLoading = false; });
    }
  }

  String _formatTime(String? dateStr) {
    if (dateStr == null) return '';
    try { return timeago.format(DateTime.parse(dateStr), locale: 'fr'); } catch (_) { return ''; }
  }

  void _createNewPost() {
    if (!AuthState.isLoggedIn) { AuthPromptDialog.show(context: context); return; }

    XFile? _selectedImage;
    bool _isUploading = false;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => StatefulBuilder(
        builder: (context, setModalState) => Container(
          height: MediaQuery.of(context).size.height * 0.75,
          decoration: const BoxDecoration(color: Colors.white, borderRadius: BorderRadius.vertical(top: Radius.circular(32))),
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                Text('Nouvelle publication', style: GoogleFonts.outfit(fontSize: 22, fontWeight: FontWeight.bold)),
                IconButton(onPressed: () => Navigator.pop(context), icon: const Icon(Icons.close)),
              ]),
              const SizedBox(height: 20),
              TextField(
                controller: _postController,
                maxLines: 4,
                decoration: InputDecoration(
                  hintText: 'Partagez votre geste éco-responsable...',
                  hintStyle: GoogleFonts.inter(color: AppTheme.textMuted),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide(color: Colors.grey.shade200)),
                  enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide(color: Colors.grey.shade200)),
                  focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: const BorderSide(color: AppTheme.primaryGreen, width: 2)),
                ),
              ),
              const SizedBox(height: 16),

              // Image picker area
              GestureDetector(
                onTap: () async {
                  final picker = ImagePicker();
                  final picked = await picker.pickImage(source: ImageSource.gallery, maxWidth: 1200, imageQuality: 85);
                  if (picked != null) setModalState(() => _selectedImage = picked);
                },
                child: Container(
                  height: _selectedImage != null ? 200 : 120,
                  width: double.infinity,
                  decoration: BoxDecoration(
                    color: AppTheme.primaryGreen.withOpacity(0.05),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: AppTheme.primaryGreen.withOpacity(0.2)),
                    image: _selectedImage != null && !kIsWeb
                        ? DecorationImage(image: FileImage(File(_selectedImage!.path)), fit: BoxFit.cover)
                        : null,
                  ),
                  child: _selectedImage != null
                      ? Stack(children: [
                          if (kIsWeb) Center(child: Column(mainAxisSize: MainAxisSize.min, children: [
                            const Icon(Icons.check_circle_rounded, size: 40, color: AppTheme.primaryGreen),
                            const SizedBox(height: 8),
                            Text('Image sélectionnée', style: GoogleFonts.inter(color: AppTheme.primaryGreen, fontWeight: FontWeight.w600)),
                          ])),
                          Positioned(
                            top: 8, right: 8,
                            child: GestureDetector(
                              onTap: () => setModalState(() => _selectedImage = null),
                              child: Container(
                                padding: const EdgeInsets.all(6),
                                decoration: BoxDecoration(color: Colors.black.withOpacity(0.5), shape: BoxShape.circle),
                                child: const Icon(Icons.close, color: Colors.white, size: 16),
                              ),
                            ),
                          ),
                        ])
                      : Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                          Icon(Icons.add_photo_alternate_rounded, size: 36, color: AppTheme.primaryGreen.withOpacity(0.6)),
                          const SizedBox(height: 8),
                          Text('Ajouter une image', style: GoogleFonts.inter(color: AppTheme.primaryGreen, fontWeight: FontWeight.w600, fontSize: 13)),
                          Text('depuis la galerie', style: GoogleFonts.inter(color: AppTheme.textMuted, fontSize: 11)),
                        ]),
                ),
              ),

              const Spacer(),

              // Publish button
              Container(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(18),
                  gradient: const LinearGradient(colors: [AppTheme.primaryGreen, AppTheme.accentTeal]),
                  boxShadow: [BoxShadow(color: AppTheme.primaryGreen.withOpacity(0.3), blurRadius: 16, offset: const Offset(0, 6))],
                ),
                child: ElevatedButton(
                  onPressed: _isUploading ? null : () async {
                    if (_postController.text.isEmpty) return;
                    setModalState(() => _isUploading = true);

                    String imageUrl = '';
                    // Upload image if selected
                    if (_selectedImage != null) {
                      final uploadedUrl = await _authService.uploadImage(_selectedImage!.path);
                      if (uploadedUrl != null) imageUrl = uploadedUrl;
                    }

                    final user = AuthState.currentUser;
                    final result = await _authService.createPost(
                      userName: user?.name ?? 'Anonyme',
                      userAvatarUrl: user?.avatarUrl ?? '',
                      imageUrl: imageUrl,
                      description: _postController.text,
                    );

                    if (result['success'] == true) {
                      _postController.clear();
                      Navigator.pop(context);
                      _loadPosts();
                      if (mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text('Publication créée !', style: GoogleFonts.inter(fontWeight: FontWeight.w600)), backgroundColor: AppTheme.primaryGreen, behavior: SnackBarBehavior.floating, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
                        );
                      }
                    } else {
                      setModalState(() => _isUploading = false);
                      if (mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text(result['message'] ?? 'Erreur'), backgroundColor: Colors.red),
                        );
                      }
                    }
                  },
                  style: ElevatedButton.styleFrom(
                    minimumSize: const Size(double.infinity, 56),
                    backgroundColor: Colors.transparent,
                    shadowColor: Colors.transparent,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
                  ),
                  child: _isUploading
                      ? Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                          const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2.5, valueColor: AlwaysStoppedAnimation<Color>(Colors.white))),
                          const SizedBox(width: 12),
                          Text('Publication en cours...', style: GoogleFonts.outfit(fontWeight: FontWeight.w700, color: Colors.white)),
                        ])
                      : Text('PUBLIER', style: GoogleFonts.outfit(fontWeight: FontWeight.w900, letterSpacing: 2, fontSize: 14, color: Colors.white)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.backgroundLight,
      floatingActionButton: FloatingActionButton(
        onPressed: _createNewPost,
        backgroundColor: AppTheme.primaryGreen,
        child: const Icon(Icons.add, color: Colors.white),
      ).animate().scale(delay: 1.seconds, curve: Curves.elasticOut),
      body: CustomScrollView(
        physics: const BouncingScrollPhysics(),
        slivers: [
          SliverAppBar(
            backgroundColor: AppTheme.backgroundLight,
            elevation: 0, floating: true, centerTitle: false,
            title: Animate(
              effects: [FadeEffect(), SlideEffect(begin: const Offset(-0.2, 0))],
              child: Text('Communauté', style: AppTheme.seniorTheme.textTheme.headlineMedium?.copyWith(fontSize: 28)),
            ),
            actions: [
              IconButton(icon: const Icon(Icons.refresh_rounded, color: AppTheme.deepSlate), onPressed: _loadPosts),
              const SizedBox(width: 24),
            ],
          ),
          if (_isLoading)
            const SliverFillRemaining(child: Center(child: CircularProgressIndicator(color: AppTheme.primaryGreen)))
          else if (_error != null)
            SliverFillRemaining(
              child: Center(child: Column(mainAxisSize: MainAxisSize.min, children: [
                Container(padding: const EdgeInsets.all(20), decoration: BoxDecoration(color: Colors.red.withOpacity(0.08), shape: BoxShape.circle), child: const Icon(Icons.cloud_off_rounded, size: 48, color: Colors.red)),
                const SizedBox(height: 20),
                Text(_error!, style: GoogleFonts.inter(color: AppTheme.textMuted, fontSize: 16)),
                const SizedBox(height: 8),
                Text('Vérifiez que le serveur backend est démarré', style: GoogleFonts.inter(color: AppTheme.textMuted.withOpacity(0.6), fontSize: 12)),
                const SizedBox(height: 20),
                ElevatedButton.icon(
                  onPressed: _loadPosts, icon: const Icon(Icons.refresh_rounded), label: const Text('Réessayer'),
                  style: ElevatedButton.styleFrom(backgroundColor: AppTheme.primaryGreen, foregroundColor: Colors.white, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)), padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12)),
                ),
              ])),
            )
          else if (_posts.isEmpty)
            SliverFillRemaining(
              child: Center(child: Column(mainAxisSize: MainAxisSize.min, children: [
                const Icon(Icons.article_outlined, size: 64, color: AppTheme.textMuted),
                const SizedBox(height: 16),
                Text('Aucune publication', style: GoogleFonts.outfit(fontSize: 18, color: AppTheme.textMuted)),
                const SizedBox(height: 8),
                Text('Soyez le premier à publier !', style: GoogleFonts.inter(color: AppTheme.textMuted)),
              ])),
            )
          else
            SliverList(
              delegate: SliverChildBuilderDelegate(
                (context, index) {
                  final post = _posts[index];
                  return Animate(
                    key: ValueKey(post['id']),
                    effects: [FadeEffect(delay: (index * 50).ms, duration: 600.ms), SlideEffect(begin: const Offset(0, 0.1))],
                    child: Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: _RealPostCard(post: post, authService: _authService, onRefresh: _loadPosts, formatTime: _formatTime),
                    ),
                  );
                },
                childCount: _posts.length,
              ),
            ),
          const SliverToBoxAdapter(child: SizedBox(height: 100)),
        ],
      ),
    );
  }
}

// ============================================
// Post Card with persistent like/save state
// ============================================
class _RealPostCard extends StatefulWidget {
  final Map<String, dynamic> post;
  final AuthService authService;
  final VoidCallback onRefresh;
  final String Function(String?) formatTime;

  const _RealPostCard({required this.post, required this.authService, required this.onRefresh, required this.formatTime});

  @override
  State<_RealPostCard> createState() => _RealPostCardState();
}

class _RealPostCardState extends State<_RealPostCard> {
  late bool _isLiked;
  late int _likeCount;
  late bool _isSaved;

  @override
  void initState() {
    super.initState();
    _likeCount = widget.post['likes_count'] ?? 0;
    // Read persistent like/save state from backend response
    _isLiked = widget.post['is_liked'] == true;
    _isSaved = widget.post['is_saved'] == true;
  }

  Future<void> _handleLike() async {
    if (!AuthState.isLoggedIn) { _showAuthSnackBar('Connectez-vous pour liker'); return; }

    setState(() { _isLiked = !_isLiked; _isLiked ? _likeCount++ : _likeCount--; });

    final result = await widget.authService.toggleLikePost(widget.post['id'].toString());
    if (result['success'] == true) {
      setState(() { _isLiked = result['liked'] ?? _isLiked; _likeCount = result['count'] ?? _likeCount; });
    }
  }

  Future<void> _handleSave() async {
    if (!AuthState.isLoggedIn) { _showAuthSnackBar('Connectez-vous pour enregistrer'); return; }

    setState(() => _isSaved = !_isSaved);

    final result = await widget.authService.toggleSavePost(widget.post['id'].toString());
    if (result['success'] == true) setState(() => _isSaved = result['saved'] ?? _isSaved);

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(_isSaved ? 'Publication enregistrée !' : 'Publication retirée des favoris.'),
        duration: const Duration(seconds: 2),
        backgroundColor: _isSaved ? AppTheme.primaryGreen : AppTheme.deepSlate,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ));
    }
  }

  String _formatCommentTime(dynamic comment) {
    // If we have a local _createdAt DateTime (just created), use it directly
    if (comment is Map && comment['_local_created_at'] != null) {
      final dt = comment['_local_created_at'] as DateTime;
      return timeago.format(dt, locale: 'fr');
    }
    return widget.formatTime(comment['created_at']);
  }

  void _showCommentModal() {
    final TextEditingController commentController = TextEditingController();
    final List<dynamic> comments = List<dynamic>.from(widget.post['comments'] ?? []);
    Timer? refreshTimer;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => StatefulBuilder(
        builder: (context, setModalState) {
          // Auto-refresh timestamps every 30 seconds
          refreshTimer ??= Timer.periodic(const Duration(seconds: 30), (_) {
            if (context.mounted) setModalState(() {});
          });

          return Container(
            height: MediaQuery.of(context).size.height * 0.75,
            decoration: const BoxDecoration(color: Colors.white, borderRadius: BorderRadius.vertical(top: Radius.circular(32))),
            child: Column(
              children: [
                Container(width: 40, height: 4, margin: const EdgeInsets.symmetric(vertical: 12), decoration: BoxDecoration(color: Colors.grey.shade300, borderRadius: BorderRadius.circular(2))),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
                  child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                    Text('Commentaires (${comments.length})', style: GoogleFonts.outfit(fontSize: 20, fontWeight: FontWeight.bold)),
                    IconButton(onPressed: () { refreshTimer?.cancel(); Navigator.pop(context); }, icon: const Icon(Icons.close)),
                  ]),
                ),
                Expanded(
                  child: comments.isEmpty
                      ? Center(child: Column(mainAxisSize: MainAxisSize.min, children: [
                          Icon(Icons.chat_bubble_outline, size: 48, color: Colors.grey.shade300),
                          const SizedBox(height: 12),
                          Text('Aucun commentaire', style: GoogleFonts.inter(color: AppTheme.textMuted)),
                          Text('Soyez le premier à commenter !', style: GoogleFonts.inter(color: AppTheme.textMuted, fontSize: 12)),
                        ]))
                      : ListView.builder(
                          padding: const EdgeInsets.all(24),
                          itemCount: comments.length,
                          itemBuilder: (context, index) {
                            final comment = comments[index];
                            final commentUserName = comment['user_name'] ?? 'Anonyme';
                            final commentContent = comment['content'] ?? '';
                            final commentTime = _formatCommentTime(comment);
                            final isMyComment = AuthState.isLoggedIn && commentUserName == AuthState.currentUser?.name;

                            return Padding(
                              padding: const EdgeInsets.only(bottom: 16),
                              child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                                CircleAvatar(
                                  radius: 18,
                                  backgroundColor: AppTheme.primaryGreen.withOpacity(0.1),
                                  child: Text(commentUserName.isNotEmpty ? commentUserName[0].toUpperCase() : '?', style: GoogleFonts.outfit(color: AppTheme.primaryGreen, fontWeight: FontWeight.bold)),
                                ),
                                const SizedBox(width: 12),
                                Expanded(child: Container(
                                  padding: const EdgeInsets.all(12),
                                  decoration: BoxDecoration(color: Colors.grey.shade50, borderRadius: BorderRadius.circular(16)),
                                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                                    Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                                      Text(commentUserName, style: GoogleFonts.inter(fontWeight: FontWeight.bold, fontSize: 13)),
                                      Row(mainAxisSize: MainAxisSize.min, children: [
                                        Text(commentTime, style: GoogleFonts.inter(fontSize: 10, color: AppTheme.textMuted)),
                                        if (isMyComment) ...[
                                          const SizedBox(width: 4),
                                          GestureDetector(
                                            onTap: () async {
                                              final commentId = comment['id'];
                                              if (commentId != null) {
                                                final deleted = await widget.authService.deleteComment(commentId is int ? commentId : int.parse(commentId.toString()));
                                                if (deleted) {
                                                  setModalState(() => comments.removeAt(index));
                                                  setState(() {}); // update main count
                                                }
                                              }
                                            },
                                            child: Icon(Icons.delete_outline, size: 16, color: Colors.red.shade300),
                                          ),
                                        ],
                                      ]),
                                    ]),
                                    const SizedBox(height: 4),
                                    Text(commentContent, style: GoogleFonts.inter(fontSize: 14)),
                                  ]),
                                )),
                              ]),
                            );
                          },
                        ),
                ),
                Padding(
                  padding: EdgeInsets.fromLTRB(24, 0, 24, MediaQuery.of(context).viewInsets.bottom + 24),
                  child: Row(children: [
                    Expanded(child: TextField(
                      controller: commentController,
                      decoration: InputDecoration(
                        hintText: AuthState.isLoggedIn ? 'Ajouter un commentaire...' : 'Connectez-vous pour commenter',
                        enabled: AuthState.isLoggedIn,
                        filled: true, fillColor: Colors.grey.shade100,
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(24), borderSide: BorderSide.none),
                        contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                      ),
                    )),
                    const SizedBox(width: 8),
                    IconButton(
                      onPressed: AuthState.isLoggedIn ? () async {
                        if (commentController.text.isNotEmpty) {
                          final user = AuthState.currentUser;
                          final result = await widget.authService.addComment(widget.post['id'].toString(), user?.name ?? 'Anonyme', user?.avatarUrl, commentController.text);
                          if (result['success'] == true) {
                            // Inject local DateTime for instant "à l'instant" display
                            final newComment = Map<String, dynamic>.from(result['data'] as Map);
                            newComment['_local_created_at'] = DateTime.now();
                            setModalState(() => comments.insert(0, newComment));
                            setState(() {}); // Update main count
                            commentController.clear();
                          }
                        }
                      } : null,
                      icon: const Icon(Icons.send_rounded, color: AppTheme.primaryGreen),
                    ),
                  ]),
                ),
              ],
            ),
          );
        },
      ),
    ).whenComplete(() => refreshTimer?.cancel());
  }

  void _showLikersModal() async {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        height: MediaQuery.of(context).size.height * 0.5,
        decoration: const BoxDecoration(color: Colors.white, borderRadius: BorderRadius.vertical(top: Radius.circular(32))),
        child: Column(
          children: [
            Container(width: 40, height: 4, margin: const EdgeInsets.symmetric(vertical: 12), decoration: BoxDecoration(color: Colors.grey.shade300, borderRadius: BorderRadius.circular(2))),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
              child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                Row(children: [
                  const Icon(Icons.favorite_rounded, color: Colors.pink, size: 22),
                  const SizedBox(width: 10),
                  Text('J\'aime ($_likeCount)', style: GoogleFonts.outfit(fontSize: 20, fontWeight: FontWeight.bold)),
                ]),
                IconButton(onPressed: () => Navigator.pop(context), icon: const Icon(Icons.close)),
              ]),
            ),
            Expanded(
              child: FutureBuilder<List<Map<String, dynamic>>>(
                future: widget.authService.fetchPostLikers(widget.post['id'].toString()),
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const Center(child: CircularProgressIndicator(color: AppTheme.primaryGreen));
                  }
                  final likers = snapshot.data ?? [];
                  if (likers.isEmpty) {
                    return Center(child: Column(mainAxisSize: MainAxisSize.min, children: [
                      Icon(Icons.favorite_border_rounded, size: 48, color: Colors.grey.shade300),
                      const SizedBox(height: 12),
                      Text('Aucun j\'aime', style: GoogleFonts.inter(color: AppTheme.textMuted)),
                    ]));
                  }
                  return ListView.builder(
                    padding: const EdgeInsets.symmetric(horizontal: 24),
                    itemCount: likers.length,
                    itemBuilder: (context, index) {
                      final liker = likers[index];
                      final name = liker['full_name'] ?? 'Utilisateur';
                      final email = liker['email'] ?? '';
                      return Container(
                        margin: const EdgeInsets.only(bottom: 8),
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                        decoration: BoxDecoration(
                          color: Colors.grey.shade50,
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: Row(children: [
                          CircleAvatar(
                            radius: 20,
                            backgroundColor: Colors.pink.withOpacity(0.1),
                            child: Text(name.isNotEmpty ? name[0].toUpperCase() : '?', style: GoogleFonts.outfit(color: Colors.pink, fontWeight: FontWeight.bold, fontSize: 16)),
                          ),
                          const SizedBox(width: 14),
                          Expanded(child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(name, style: GoogleFonts.outfit(fontWeight: FontWeight.w600, fontSize: 15)),
                              if (email.isNotEmpty)
                                Text(email, style: GoogleFonts.inter(fontSize: 12, color: AppTheme.textMuted)),
                            ],
                          )),
                          const Icon(Icons.favorite_rounded, color: Colors.pink, size: 18),
                        ]),
                      );
                    },
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final userName = widget.post['user_name'] ?? 'Anonyme';
    final description = widget.post['description'] ?? '';
    final imageUrl = widget.post['image_url'] ?? '';
    final timeStr = widget.formatTime(widget.post['created_at']);
    final comments = widget.post['comments'] as List<dynamic>? ?? [];
    final commentCount = comments.length;
    final isMyPost = AuthState.isLoggedIn && userName == AuthState.currentUser?.name;

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(32), boxShadow: AppTheme.premiumShadow),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        // Header
        Padding(
          padding: const EdgeInsets.all(24),
          child: Row(children: [
            Container(
              padding: const EdgeInsets.all(2),
              decoration: BoxDecoration(shape: BoxShape.circle, border: Border.all(color: AppTheme.primaryGreen.withOpacity(0.1), width: 1)),
              child: CircleAvatar(
                radius: 22, backgroundColor: AppTheme.primaryGreen.withOpacity(0.1),
                child: Text(userName.isNotEmpty ? userName[0].toUpperCase() : '?', style: GoogleFonts.outfit(fontSize: 20, fontWeight: FontWeight.bold, color: AppTheme.primaryGreen)),
              ),
            ),
            const SizedBox(width: 14),
            Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(userName, style: GoogleFonts.outfit(fontWeight: FontWeight.bold, fontSize: 16)),
              Text(timeStr, style: const TextStyle(fontSize: 12, color: AppTheme.textMuted, fontWeight: FontWeight.w500)),
            ]),
            const Spacer(),
            if (isMyPost)
              PopupMenuButton<String>(
                icon: const Icon(Icons.more_horiz_rounded, color: AppTheme.textMuted),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                onSelected: (value) async {
                  if (value == 'delete') {
                    final confirmed = await showDialog<bool>(context: context, builder: (ctx) => AlertDialog(
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                      title: Text('Supprimer ?', style: GoogleFonts.outfit(fontWeight: FontWeight.bold)),
                      content: const Text('Cette action est irréversible.'),
                      actions: [TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Annuler')), ElevatedButton(onPressed: () => Navigator.pop(ctx, true), style: ElevatedButton.styleFrom(backgroundColor: Colors.red), child: const Text('Supprimer'))],
                    ));
                    if (confirmed == true) {
                      await widget.authService.deletePost(widget.post['id'].toString());
                      widget.onRefresh();
                    }
                  }
                },
                itemBuilder: (ctx) => [const PopupMenuItem(value: 'delete', child: Row(children: [Icon(Icons.delete_outline, color: Colors.red, size: 18), SizedBox(width: 8), Text('Supprimer')]))],
              )
            else
              const Icon(Icons.more_horiz_rounded, color: AppTheme.textMuted),
          ]),
        ),

        // Description
        if (description.isNotEmpty)
          Padding(padding: const EdgeInsets.symmetric(horizontal: 24), child: Text(description, style: GoogleFonts.inter(fontSize: 15, height: 1.6, color: AppTheme.textMain))),

        // Image
        if (imageUrl.isNotEmpty) ...[
          const SizedBox(height: 16),
          Container(
            height: 340, width: double.infinity,
            margin: const EdgeInsets.symmetric(horizontal: 20),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(24),
              image: DecorationImage(image: NetworkImage(imageUrl), fit: BoxFit.cover),
              boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10, offset: const Offset(0, 5))],
            ),
          ),
        ],

        // Actions
        Padding(
          padding: const EdgeInsets.all(24),
          child: Row(children: [
            _buildActionIcon(_isLiked ? Icons.favorite_rounded : Icons.favorite_border_rounded, '$_likeCount', _isLiked ? Colors.pink : AppTheme.textMuted, onTap: _handleLike, onLongPress: _likeCount > 0 ? _showLikersModal : null, onCountTap: _likeCount > 0 ? _showLikersModal : null),
            const SizedBox(width: 20),
            _buildActionIcon(Icons.chat_bubble_outline_rounded, '$commentCount', AppTheme.textMuted, onTap: _showCommentModal),
            const Spacer(),
            IconButton(
              onPressed: _handleSave,
              icon: Icon(_isSaved ? Icons.bookmark_rounded : Icons.bookmark_border_rounded, color: _isSaved ? AppTheme.primaryGreen : AppTheme.textMuted, size: 24),
            ),
          ]),
        ),
      ]),
    );
  }

  void _showAuthSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Row(children: [const Icon(Icons.lock_outline_rounded, color: Colors.white, size: 18), const SizedBox(width: 10), Expanded(child: Text(message))]),
      behavior: SnackBarBehavior.floating,
      backgroundColor: AppTheme.deepNavy,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      action: SnackBarAction(label: 'CONNEXION', textColor: AppTheme.primaryGreen, onPressed: () => Navigator.pushNamed(context, '/login')),
    ));
  }

  Widget _buildActionIcon(IconData icon, String count, Color color, {VoidCallback? onTap, VoidCallback? onLongPress, VoidCallback? onCountTap}) {
    return Row(children: [
      GestureDetector(
        onTap: onTap,
        onLongPress: onLongPress,
        child: Icon(icon, size: 24, color: color),
      ),
      const SizedBox(width: 8),
      GestureDetector(
        onTap: onCountTap ?? onTap,
        child: Text(count, style: GoogleFonts.outfit(fontWeight: FontWeight.bold, fontSize: 14, color: color)),
      ),
    ]);
  }
}
