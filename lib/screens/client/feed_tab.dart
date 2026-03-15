import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:timeago/timeago.dart' as timeago;
import '../../theme/app_theme.dart';
import '../../models/user_model.dart';
import '../../services/auth_service.dart';

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
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final posts = await _authService.fetchAllPosts();
      if (mounted) {
        setState(() {
          _posts = posts.cast<Map<String, dynamic>>();
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = 'Impossible de charger les publications';
          _isLoading = false;
        });
      }
    }
  }

  String _formatTime(String? dateStr) {
    if (dateStr == null) return '';
    try {
      final date = DateTime.parse(dateStr);
      return timeago.format(date, locale: 'fr');
    } catch (_) {
      return '';
    }
  }

  void _createNewPost() {
    if (!AuthState.isLoggedIn) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Connectez-vous pour publier'), backgroundColor: Colors.orange),
      );
      return;
    }

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        height: MediaQuery.of(context).size.height * 0.7,
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(32)),
        ),
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('Créer une annonce', style: GoogleFonts.outfit(fontSize: 24, fontWeight: FontWeight.bold)),
                IconButton(onPressed: () => Navigator.pop(context), icon: const Icon(Icons.close)),
              ],
            ),
            const SizedBox(height: 24),
            TextField(
              controller: _postController,
              maxLines: 5,
              decoration: InputDecoration(
                hintText: "Quoi de neuf dans votre démarche éco-responsable ?",
                hintStyle: GoogleFonts.inter(color: AppTheme.textMuted),
                border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(16), borderSide: BorderSide(color: Colors.grey.shade200)),
                enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(16), borderSide: BorderSide(color: Colors.grey.shade200)),
              ),
            ),
            const SizedBox(height: 20),
            Container(
              height: 150,
              width: double.infinity,
              decoration: BoxDecoration(
                color: AppTheme.primaryGreen.withOpacity(0.05),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: AppTheme.primaryGreen.withOpacity(0.2), style: BorderStyle.solid),
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.add_photo_alternate_rounded, size: 40, color: AppTheme.primaryGreen),
                  const SizedBox(height: 8),
                  Text('Ajouter une image',
                      style: GoogleFonts.outfit(color: AppTheme.primaryGreen, fontWeight: FontWeight.w600)),
                ],
              ),
            ),
            const Spacer(),
            ElevatedButton(
              onPressed: () async {
                if (_postController.text.isNotEmpty) {
                  final user = AuthState.currentUser;
                  final result = await _authService.createPost(
                    userName: user?.name ?? 'Anonyme',
                    userAvatarUrl: user?.avatarUrl ?? '',
                    imageUrl: '',
                    description: _postController.text,
                  );

                  if (result['success'] == true) {
                    _postController.clear();
                    Navigator.pop(context);
                    _loadPosts(); // Recharger depuis le backend
                    if (mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                            content: Text('Annonce publiée avec succès !'), backgroundColor: AppTheme.primaryGreen),
                      );
                    }
                  } else {
                    if (mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text(result['message'] ?? 'Erreur'), backgroundColor: Colors.red),
                      );
                    }
                  }
                }
              },
              style: ElevatedButton.styleFrom(
                minimumSize: const Size(double.infinity, 56),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              ),
              child: const Text('PUBLIER'),
            ),
          ],
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
            elevation: 0,
            floating: true,
            centerTitle: false,
            title: Animate(
              effects: [FadeEffect(), SlideEffect(begin: const Offset(-0.2, 0))],
              child: Text('Communauté', style: AppTheme.seniorTheme.textTheme.headlineMedium?.copyWith(fontSize: 28)),
            ),
            actions: [
              IconButton(
                icon: const Icon(Icons.refresh_rounded, color: AppTheme.deepSlate),
                onPressed: _loadPosts,
              ),
              const SizedBox(width: 24),
            ],
          ),
          if (_isLoading)
            const SliverFillRemaining(
              child: Center(child: CircularProgressIndicator(color: AppTheme.primaryGreen)),
            )
          else if (_error != null)
            SliverFillRemaining(
              child: Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.cloud_off_rounded, size: 64, color: AppTheme.textMuted),
                    const SizedBox(height: 16),
                    Text(_error!, style: GoogleFonts.inter(color: AppTheme.textMuted, fontSize: 16)),
                    const SizedBox(height: 16),
                    ElevatedButton.icon(
                      onPressed: _loadPosts,
                      icon: const Icon(Icons.refresh),
                      label: const Text('Réessayer'),
                      style: ElevatedButton.styleFrom(backgroundColor: AppTheme.primaryGreen),
                    ),
                  ],
                ),
              ),
            )
          else if (_posts.isEmpty)
            SliverFillRemaining(
              child: Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.article_outlined, size: 64, color: AppTheme.textMuted),
                    const SizedBox(height: 16),
                    Text('Aucune publication', style: GoogleFonts.outfit(fontSize: 18, color: AppTheme.textMuted)),
                    const SizedBox(height: 8),
                    Text('Soyez le premier à publier !', style: GoogleFonts.inter(color: AppTheme.textMuted)),
                  ],
                ),
              ),
            )
          else
            SliverList(
              delegate: SliverChildBuilderDelegate(
                (context, index) {
                  final post = _posts[index];
                  return Animate(
                    key: ValueKey(post['id']),
                    effects: [
                      FadeEffect(delay: (index * 50).ms, duration: 600.ms),
                      SlideEffect(begin: const Offset(0, 0.1)),
                    ],
                    child: Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: _RealPostCard(
                        post: post,
                        authService: _authService,
                        onRefresh: _loadPosts,
                        formatTime: _formatTime,
                      ),
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
// Carte de publication avec données réelles
// ============================================
class _RealPostCard extends StatefulWidget {
  final Map<String, dynamic> post;
  final AuthService authService;
  final VoidCallback onRefresh;
  final String Function(String?) formatTime;

  const _RealPostCard({
    required this.post,
    required this.authService,
    required this.onRefresh,
    required this.formatTime,
  });

  @override
  State<_RealPostCard> createState() => _RealPostCardState();
}

class _RealPostCardState extends State<_RealPostCard> {
  late bool _isLiked;
  late int _likeCount;
  bool _isSaved = false;

  @override
  void initState() {
    super.initState();
    _likeCount = widget.post['likes_count'] ?? 0;
    _isLiked = false;
  }

  Future<void> _handleLike() async {
    if (!AuthState.isLoggedIn) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Connectez-vous pour liker'), behavior: SnackBarBehavior.floating),
      );
      return;
    }

    setState(() {
      _isLiked = !_isLiked;
      _isLiked ? _likeCount++ : _likeCount--;
    });

    final result = await widget.authService.toggleLikePost(widget.post['id'].toString());
    if (result['success'] == true) {
      setState(() {
        _isLiked = result['liked'] ?? _isLiked;
        _likeCount = result['count'] ?? _likeCount;
      });
    }
  }

  Future<void> _handleSave() async {
    if (!AuthState.isLoggedIn) return;

    setState(() => _isSaved = !_isSaved);

    final result = await widget.authService.toggleSavePost(widget.post['id'].toString());
    if (result['success'] == true) {
      setState(() => _isSaved = result['saved'] ?? _isSaved);
    }

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(_isSaved ? 'Annonce enregistrée !' : 'Annonce retirée des favoris.'),
          duration: const Duration(seconds: 2),
          backgroundColor: _isSaved ? AppTheme.primaryGreen : AppTheme.deepSlate,
        ),
      );
    }
  }

  void _showCommentModal() {
    final TextEditingController commentController = TextEditingController();
    final List<dynamic> comments = List<dynamic>.from(widget.post['comments'] ?? []);

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => StatefulBuilder(
        builder: (context, setModalState) => Container(
          height: MediaQuery.of(context).size.height * 0.75,
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(32)),
          ),
          child: Column(
            children: [
              Container(
                width: 40,
                height: 4,
                margin: const EdgeInsets.symmetric(vertical: 12),
                decoration: BoxDecoration(color: Colors.grey.shade300, borderRadius: BorderRadius.circular(2)),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text('Commentaires (${comments.length})',
                        style: GoogleFonts.outfit(fontSize: 20, fontWeight: FontWeight.bold)),
                    IconButton(onPressed: () => Navigator.pop(context), icon: const Icon(Icons.close)),
                  ],
                ),
              ),
              Expanded(
                child: comments.isEmpty
                    ? Center(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.chat_bubble_outline, size: 48, color: Colors.grey.shade300),
                            const SizedBox(height: 12),
                            Text('Aucun commentaire', style: GoogleFonts.inter(color: AppTheme.textMuted)),
                            Text('Soyez le premier à commenter !',
                                style: GoogleFonts.inter(color: AppTheme.textMuted, fontSize: 12)),
                          ],
                        ),
                      )
                    : ListView.builder(
                        padding: const EdgeInsets.all(24),
                        itemCount: comments.length,
                        itemBuilder: (context, index) {
                          final comment = comments[index];
                          final commentUserName = comment['user_name'] ?? 'Anonyme';
                          final commentContent = comment['content'] ?? '';
                          final commentTime = widget.formatTime(comment['created_at']);

                          return Padding(
                            padding: const EdgeInsets.only(bottom: 16),
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                CircleAvatar(
                                  radius: 18,
                                  backgroundColor: AppTheme.primaryGreen.withOpacity(0.1),
                                  child: Text(
                                    commentUserName.isNotEmpty ? commentUserName[0].toUpperCase() : '?',
                                    style:
                                        GoogleFonts.outfit(color: AppTheme.primaryGreen, fontWeight: FontWeight.bold),
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Container(
                                    padding: const EdgeInsets.all(12),
                                    decoration: BoxDecoration(
                                        color: Colors.grey.shade50, borderRadius: BorderRadius.circular(16)),
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Row(
                                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                          children: [
                                            Text(commentUserName,
                                                style: GoogleFonts.inter(fontWeight: FontWeight.bold, fontSize: 13)),
                                            Text(commentTime,
                                                style: GoogleFonts.inter(fontSize: 10, color: AppTheme.textMuted)),
                                          ],
                                        ),
                                        const SizedBox(height: 4),
                                        Text(commentContent, style: GoogleFonts.inter(fontSize: 14)),
                                      ],
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          );
                        },
                      ),
              ),
              Padding(
                padding: EdgeInsets.fromLTRB(24, 0, 24, MediaQuery.of(context).viewInsets.bottom + 24),
                child: Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: commentController,
                        decoration: InputDecoration(
                          hintText:
                              AuthState.isLoggedIn ? 'Ajouter un commentaire...' : 'Connectez-vous pour commenter',
                          enabled: AuthState.isLoggedIn,
                          filled: true,
                          fillColor: Colors.grey.shade100,
                          border:
                              OutlineInputBorder(borderRadius: BorderRadius.circular(24), borderSide: BorderSide.none),
                          contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    IconButton(
                      onPressed: AuthState.isLoggedIn
                          ? () async {
                              if (commentController.text.isNotEmpty) {
                                final user = AuthState.currentUser;
                                final result = await widget.authService.addComment(
                                  widget.post['id'].toString(),
                                  user?.name ?? 'Anonyme',
                                  user?.avatarUrl,
                                  commentController.text,
                                );

                                if (result['success'] == true) {
                                  setModalState(() {
                                    comments.insert(0, result['data']);
                                  });
                                  setState(() {}); // Update main count
                                  commentController.clear();
                                }
                              }
                            }
                          : null,
                      icon: const Icon(Icons.send_rounded, color: AppTheme.primaryGreen),
                    ),
                  ],
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
    final userName = widget.post['user_name'] ?? 'Anonyme';
    final description = widget.post['description'] ?? '';
    final imageUrl = widget.post['image_url'] ?? '';
    final timeStr = widget.formatTime(widget.post['created_at']);
    final comments = widget.post['comments'] as List<dynamic>? ?? [];
    final commentCount = comments.length;

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(32),
        boxShadow: AppTheme.premiumShadow,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header: avatar + nom + temps
          Padding(
            padding: const EdgeInsets.all(24),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(2),
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(color: AppTheme.primaryGreen.withOpacity(0.1), width: 1),
                  ),
                  child: CircleAvatar(
                    radius: 22,
                    backgroundColor: AppTheme.primaryGreen.withOpacity(0.1),
                    child: Text(
                      userName.isNotEmpty ? userName[0].toUpperCase() : '?',
                      style:
                          GoogleFonts.outfit(fontSize: 20, fontWeight: FontWeight.bold, color: AppTheme.primaryGreen),
                    ),
                  ),
                ),
                const SizedBox(width: 14),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(userName, style: GoogleFonts.outfit(fontWeight: FontWeight.bold, fontSize: 16)),
                    Text(timeStr,
                        style: const TextStyle(fontSize: 12, color: AppTheme.textMuted, fontWeight: FontWeight.w500)),
                  ],
                ),
                const Spacer(),
                const Icon(Icons.more_horiz_rounded, color: AppTheme.textMuted),
              ],
            ),
          ),

          // Description
          if (description.isNotEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: Text(
                description,
                style: GoogleFonts.inter(fontSize: 15, height: 1.6, color: AppTheme.textMain),
              ),
            ),

          // Image (si disponible)
          if (imageUrl.isNotEmpty) ...[
            const SizedBox(height: 16),
            Container(
              height: 340,
              width: double.infinity,
              margin: const EdgeInsets.symmetric(horizontal: 20),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(24),
                image: DecorationImage(image: NetworkImage(imageUrl), fit: BoxFit.cover),
                boxShadow: [
                  BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10, offset: const Offset(0, 5))
                ],
              ),
            ),
          ],

          // Actions: like, commentaire, save
          Padding(
            padding: const EdgeInsets.all(24),
            child: Row(
              children: [
                _buildActionIcon(
                  _isLiked ? Icons.favorite_rounded : Icons.favorite_border_rounded,
                  '$_likeCount',
                  _isLiked ? Colors.pink : AppTheme.textMuted,
                  onTap: _handleLike,
                ),
                const SizedBox(width: 20),
                _buildActionIcon(
                  Icons.chat_bubble_outline_rounded,
                  '$commentCount',
                  AppTheme.textMuted,
                  onTap: _showCommentModal,
                ),
                const Spacer(),
                IconButton(
                  onPressed: _handleSave,
                  icon: Icon(
                    _isSaved ? Icons.bookmark_rounded : Icons.bookmark_border_rounded,
                    color: _isSaved ? AppTheme.primaryGreen : AppTheme.textMuted,
                    size: 24,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildActionIcon(IconData icon, String count, Color color, {VoidCallback? onTap}) {
    return GestureDetector(
      onTap: onTap,
      child: Row(
        children: [
          Icon(icon, size: 24, color: color),
          const SizedBox(width: 8),
          Text(count, style: GoogleFonts.outfit(fontWeight: FontWeight.bold, fontSize: 14, color: color)),
        ],
      ),
    );
  }
}
