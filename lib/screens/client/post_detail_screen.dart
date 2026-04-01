import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:timeago/timeago.dart' as timeago;
import '../../theme/app_theme.dart';
import '../../models/user_model.dart';
import '../../services/auth_service.dart';


/// Screen that shows a single post with all interactions.
/// Navigated to from notifications.
class PostDetailScreen extends StatefulWidget {
  final Map<String, dynamic> post;

  const PostDetailScreen({Key? key, required this.post}) : super(key: key);

  @override
  State<PostDetailScreen> createState() => _PostDetailScreenState();
}

class _PostDetailScreenState extends State<PostDetailScreen> {
  final AuthService _authService = AuthService();
  late bool _isLiked;
  late int _likeCount;
  late bool _isSaved;
  late Map<String, dynamic> _post;

  @override
  void initState() {
    super.initState();
    timeago.setLocaleMessages('fr', timeago.FrMessages());
    _post = Map<String, dynamic>.from(widget.post);
    _likeCount = _post['likes_count'] ?? 0;
    _isLiked = _post['is_liked'] == true;
    _isSaved = _post['is_saved'] == true;
  }

  String _formatTime(String? dateStr) {
    if (dateStr == null) return '';
    try { return timeago.format(DateTime.parse(dateStr), locale: 'fr'); } catch (_) { return ''; }
  }

  Future<void> _handleLike() async {
    if (!AuthState.isLoggedIn) return;
    setState(() { _isLiked = !_isLiked; _isLiked ? _likeCount++ : _likeCount--; });
    final result = await _authService.toggleLikePost(_post['id'].toString());
    if (result['success'] == true) {
      setState(() { _isLiked = result['liked'] ?? _isLiked; _likeCount = result['count'] ?? _likeCount; });
    }
  }

  Future<void> _handleSave() async {
    if (!AuthState.isLoggedIn) return;
    setState(() => _isSaved = !_isSaved);
    final result = await _authService.toggleSavePost(_post['id'].toString());
    if (result['success'] == true) setState(() => _isSaved = result['saved'] ?? _isSaved);
  }

  void _showLikersModal() {
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
                future: _authService.fetchPostLikers(_post['id'].toString()),
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
                        decoration: BoxDecoration(color: Colors.grey.shade50, borderRadius: BorderRadius.circular(16)),
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

  void _showCommentModal() {
    final TextEditingController commentController = TextEditingController();
    final List<dynamic> comments = List<dynamic>.from(_post['comments'] ?? []);
    Timer? refreshTimer;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => StatefulBuilder(
        builder: (context, setModalState) {
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
                        ]))
                      : ListView.builder(
                          padding: const EdgeInsets.all(24),
                          itemCount: comments.length,
                          itemBuilder: (context, index) {
                            final comment = comments[index];
                            final commentUserName = comment['user_name'] ?? 'Anonyme';
                            final commentContent = comment['content'] ?? '';
                            String commentTime;
                            if (comment['_local_created_at'] != null) {
                              commentTime = timeago.format(comment['_local_created_at'] as DateTime, locale: 'fr');
                            } else {
                              commentTime = _formatTime(comment['created_at']);
                            }

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
                                      Text(commentTime, style: GoogleFonts.inter(fontSize: 10, color: AppTheme.textMuted)),
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
                if (AuthState.isLoggedIn)
                  Padding(
                    padding: EdgeInsets.fromLTRB(24, 0, 24, MediaQuery.of(context).viewInsets.bottom + 24),
                    child: Row(children: [
                      Expanded(child: TextField(
                        controller: commentController,
                        decoration: InputDecoration(
                          hintText: 'Ajouter un commentaire...',
                          filled: true, fillColor: Colors.grey.shade100,
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(24), borderSide: BorderSide.none),
                          contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                        ),
                      )),
                      const SizedBox(width: 8),
                      IconButton(
                        onPressed: () async {
                          if (commentController.text.isNotEmpty) {
                            final user = AuthState.currentUser;
                            final result = await _authService.addComment(_post['id'].toString(), user?.name ?? 'Anonyme', user?.avatarUrl, commentController.text);
                            if (result['success'] == true) {
                              final newComment = Map<String, dynamic>.from(result['data'] as Map);
                              newComment['_local_created_at'] = DateTime.now();
                              setModalState(() => comments.insert(0, newComment));
                              setState(() {});
                              commentController.clear();
                            }
                          }
                        },
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

  @override
  Widget build(BuildContext context) {
    final userName = _post['user_name'] ?? 'Anonyme';
    final description = _post['description'] ?? '';
    final imageUrl = _post['image_url'] ?? '';
    final timeStr = _formatTime(_post['created_at']);
    final comments = _post['comments'] as List<dynamic>? ?? [];
    final commentCount = comments.length;

    return Scaffold(
      backgroundColor: AppTheme.backgroundLight,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 18, color: Color(0xFF1E293B)),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text('Publication', style: GoogleFonts.outfit(fontSize: 20, fontWeight: FontWeight.bold, color: const Color(0xFF1E293B))),
      ),
      body: SingleChildScrollView(
        physics: const BouncingScrollPhysics(),
        child: Animate(
          effects: [FadeEffect(duration: 400.ms), SlideEffect(begin: const Offset(0, 0.05))],
          child: Container(
            margin: const EdgeInsets.all(20),
            decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(32), boxShadow: AppTheme.premiumShadow),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              // Header
              Padding(
                padding: const EdgeInsets.all(24),
                child: Row(children: [
                  Container(
                    padding: const EdgeInsets.all(2),
                    decoration: BoxDecoration(shape: BoxShape.circle, border: Border.all(color: AppTheme.primaryGreen.withOpacity(0.1))),
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
                  // Like
                  GestureDetector(
                    onTap: _handleLike,
                    child: Row(children: [
                      Icon(_isLiked ? Icons.favorite_rounded : Icons.favorite_border_rounded, size: 24, color: _isLiked ? Colors.pink : AppTheme.textMuted),
                      const SizedBox(width: 8),
                      GestureDetector(
                        onTap: _likeCount > 0 ? _showLikersModal : null,
                        child: Text('$_likeCount', style: GoogleFonts.outfit(fontWeight: FontWeight.bold, fontSize: 14, color: _isLiked ? Colors.pink : AppTheme.textMuted)),
                      ),
                    ]),
                  ),
                  const SizedBox(width: 20),
                  // Comment
                  GestureDetector(
                    onTap: _showCommentModal,
                    child: Row(children: [
                      const Icon(Icons.chat_bubble_outline_rounded, size: 24, color: AppTheme.textMuted),
                      const SizedBox(width: 8),
                      Text('$commentCount', style: GoogleFonts.outfit(fontWeight: FontWeight.bold, fontSize: 14, color: AppTheme.textMuted)),
                    ]),
                  ),
                  const Spacer(),
                  // Save
                  IconButton(
                    onPressed: _handleSave,
                    icon: Icon(_isSaved ? Icons.bookmark_rounded : Icons.bookmark_border_rounded, color: _isSaved ? AppTheme.primaryGreen : AppTheme.textMuted, size: 24),
                  ),
                ]),
              ),

              // Show likers hint
              if (_likeCount > 0)
                Padding(
                  padding: const EdgeInsets.fromLTRB(24, 0, 24, 16),
                  child: GestureDetector(
                    onTap: _showLikersModal,
                    child: Text(
                      'Voir les $_likeCount personne${_likeCount > 1 ? 's' : ''} qui ${_likeCount > 1 ? 'ont' : 'a'} aimé',
                      style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w600, color: Colors.pink.shade300),
                    ),
                  ),
                ),

              // Inline comments preview
              if (comments.isNotEmpty) ...[
                Padding(
                  padding: const EdgeInsets.fromLTRB(24, 0, 24, 8),
                  child: Text('Commentaires récents', style: GoogleFonts.outfit(fontSize: 15, fontWeight: FontWeight.bold, color: AppTheme.deepSlate)),
                ),
                ...comments.take(3).map((comment) {
                  final name = comment['user_name'] ?? 'Anonyme';
                  final content = comment['content'] ?? '';
                  return Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 4),
                    child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      CircleAvatar(
                        radius: 14,
                        backgroundColor: AppTheme.primaryGreen.withOpacity(0.1),
                        child: Text(name.isNotEmpty ? name[0].toUpperCase() : '?', style: GoogleFonts.outfit(fontSize: 11, color: AppTheme.primaryGreen, fontWeight: FontWeight.bold)),
                      ),
                      const SizedBox(width: 10),
                      Expanded(child: RichText(
                        text: TextSpan(children: [
                          TextSpan(text: '$name  ', style: GoogleFonts.inter(fontWeight: FontWeight.bold, fontSize: 13, color: AppTheme.textMain)),
                          TextSpan(text: content, style: GoogleFonts.inter(fontSize: 13, color: AppTheme.textMain.withOpacity(0.8))),
                        ]),
                      )),
                    ]),
                  );
                }),
                if (commentCount > 3)
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
                    child: GestureDetector(
                      onTap: _showCommentModal,
                      child: Text('Voir les $commentCount commentaires', style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w600, color: AppTheme.primaryGreen)),
                    ),
                  ),
                const SizedBox(height: 16),
              ],
            ]),
          ),
        ),
      ),
    );
  }
}
