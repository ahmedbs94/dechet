import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../theme/app_theme.dart';
import '../../models/post_model.dart';
import '../../models/user_model.dart';
import '../../widgets/premium_widgets.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:io';
import '../../widgets/safe_network_image.dart';
import '../../widgets/auth_guard_dialog.dart';
import 'package:flutter/foundation.dart' show kIsWeb;

class FeedTab extends StatefulWidget {
  const FeedTab({Key? key}) : super(key: key);

  @override
  State<FeedTab> createState() => _FeedTabState();
}

class _FeedTabState extends State<FeedTab> with TickerProviderStateMixin {
  late List<Post> _posts;
  final TextEditingController _postController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _posts = PostRegistry.postsNotifier.value.where((p) => p.status == PostStatus.approved).toList();
    PostRegistry.postsNotifier.addListener(_onPostsChanged);
    PostRegistry.navigationSignal.addListener(_handleNavigationSignal);
    _loadInitialPosts();
  }

  void _handleNavigationSignal() {
    final postId = PostRegistry.navigationSignal.value;
    if (postId != null && mounted) {
      final index = _posts.indexWhere((p) => p.id == postId);
      if (index != -1) {
        // Attendre un peu que l'onglet soit affiché si changement d'onglet
        Future.delayed(const Duration(milliseconds: 300), () {
          if (_scrollController.hasClients) {
            // Estimation de la hauteur : environ 400px par post (carte + marges)
            // On peut aussi chercher le contexte de l'item si on utilisait une GlobalKey
            _scrollController.animateTo(
              index * 450.0 + 150.0, // 450px par carte env + header
              duration: const Duration(milliseconds: 800),
              curve: Curves.easeInOutExpo,
            );
          }
        });
      }
    }
  }

  void _onPostsChanged() {
    if (mounted) {
      setState(() {
        _posts = PostRegistry.postsNotifier.value.where((p) => p.status == PostStatus.approved).toList();
      });
    }
  }

  @override
  void dispose() {
    PostRegistry.postsNotifier.removeListener(_onPostsChanged);
    PostRegistry.navigationSignal.removeListener(_handleNavigationSignal);
    _postController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _loadInitialPosts() async {
    setState(() => _isLoading = true);
    await PostRegistry.syncAllPosts();
    if (mounted) setState(() => _isLoading = false);
  }

  Future<void> _handleRefresh() async {
    HapticFeedback.mediumImpact();
    await PostRegistry.syncAllPosts();
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Actualisé avec succès', style: GoogleFonts.manrope(color: Colors.white)),
          backgroundColor: AppTheme.primaryGreen,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        ),
      );
    }
  }

  void _createNewPost() {
    if (AuthState.currentUser == null) {
      AuthGuardDialog.check(context);
      return;
    }
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => _PremiumCreatePostModal(
        postController: _postController,
        onPost: (text, imagePath) {
          final newPost = Post(
            id: DateTime.now().toString(),
            userName: 'Vous',
            userAvatarUrl: 'https://i.pravatar.cc/150?u=a042581f4e29026704d',
            timeAgo: 'À l\'instant',
            imageUrl: imagePath ?? 'https://images.unsplash.com/photo-1542601906990-24d4c16419d4?w=800&q=80',
            description: text,
            likes: 0,
            comments: 0,
            status: PostStatus.approved,
          );
          PostRegistry.addPost(newPost);
          _postController.clear();
        },
      ),
    );
  }

  Widget _buildIndicatorCard(String title, String value, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: color.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
        border: Border.all(color: color.withOpacity(0.1), width: 1),
      ),
      child: Column(
        children: [
          Icon(icon, color: color, size: 24),
          const SizedBox(height: 8),
          Text(
            value,
            style: GoogleFonts.outfit(
              fontSize: 16,
              fontWeight: FontWeight.w900,
              color: AppTheme.deepNavy,
            ),
          ),
          Text(
            title,
            style: GoogleFonts.inter(
              fontSize: 8,
              fontWeight: FontWeight.w800,
              color: AppTheme.textMuted,
              letterSpacing: 0.5,
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      color: AppTheme.backgroundSoft,
      child: Stack(
        children: [
          // Background Decor elements
          Positioned(
            top: -100,
            right: -50,
            child: Container(
              width: 300,
              height: 300,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(
                  colors: [
                    AppTheme.primaryGreen.withOpacity(0.15),
                    Colors.transparent,
                  ],
                ),
              ),
            )
                .animate(onPlay: (c) => c.repeat(reverse: true))
                .scale(begin: const Offset(1, 1), end: const Offset(1.2, 1.2), duration: 5.seconds),
          ),

          Positioned.fill(
            child: RefreshIndicator(
              onRefresh: _handleRefresh,
              color: AppTheme.primaryGreen,
              backgroundColor: Colors.white,
              displacement: 60,
              child: CustomScrollView(
                controller: _scrollController,
                physics: const BouncingScrollPhysics(),
                slivers: [
                  // 1. Sustainability Indicators Header
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(24, 20, 24, 0),
                      child: Row(
                        children: [
                          Expanded(
                            child: _buildIndicatorCard(
                              'CO2 ÉVITÉ',
                              '1,240 kg',
                              Icons.cloud_done_rounded,
                              Colors.blueAccent,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: _buildIndicatorCard(
                              'DÉCHETS TRIÉS',
                              '850 kg',
                              Icons.auto_awesome_rounded,
                              Colors.amber,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: _buildIndicatorCard(
                              'ARBRES SAUVÉS',
                              '12',
                              Icons.forest_rounded,
                              Colors.green.shade600,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),

                  // 2. Pinterest Style Minimalist Search Header
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(24, 60, 24, 16),
                      child: Column(
                        children: [
                          Row(
                            children: [
                              Expanded(
                                child: Container(
                                  height: 48,
                                  padding: const EdgeInsets.symmetric(horizontal: 16),
                                  decoration: BoxDecoration(
                                    color: Colors.grey.shade100,
                                    borderRadius: BorderRadius.circular(24),
                                    border: Border.all(color: Colors.grey.shade200),
                                  ),
                                  child: Row(
                                    children: [
                                      const Icon(Icons.search_rounded, color: AppTheme.textMuted, size: 20),
                                      const SizedBox(width: 12),
                                      Text(
                                        'Rechercher sur TriDéchet...',
                                        style: GoogleFonts.manrope(
                                          color: AppTheme.textMuted,
                                          fontSize: 14,
                                          fontWeight: FontWeight.w500,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                              const SizedBox(width: 12),
                              Container(
                                padding: const EdgeInsets.all(2),
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  border: Border.all(color: AppTheme.primaryGreen.withOpacity(0.3), width: 1.5),
                                ),
                                child: ClipOval(
                                  child: Container(
                                    width: 38,
                                    height: 38,
                                    color: Colors.grey.shade100,
                                    child: Image.network(
                                      AuthState.currentUser?.avatarUrl ?? 'https://i.pravatar.cc/150?u=user',
                                      fit: BoxFit.cover,
                                      errorBuilder: (c, e, s) => const Icon(Icons.person),
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 20),
                          // Categories Chip Bar
                          SingleChildScrollView(
                            scrollDirection: Axis.horizontal,
                            physics: const BouncingScrollPhysics(),
                            child: Row(
                              children: [
                                _buildPinterestTab('Pour vous', isSelected: true),
                                _buildPinterestTab('Plastique'),
                                _buildPinterestTab('Événements'),
                                _buildPinterestTab('Défis'),
                                _buildPinterestTab('Compost'),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),

                  // 2. Pinterest Recommendation Card (Professional Mission)
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(24, 8, 24, 28),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(36),
                        child: Container(
                          height: 200,
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(36),
                            boxShadow: [
                              BoxShadow(
                                  color: Colors.black.withOpacity(0.08), blurRadius: 20, offset: const Offset(0, 10)),
                            ],
                          ),
                          child: Stack(
                            children: [
                              Positioned.fill(
                                child: SafeNetworkImage(
                                  'https://images.unsplash.com/photo-1542601906990-b4d3fb778b09?w=800&q=80',
                                  fit: BoxFit.cover,
                                  placeholder: Container(color: Colors.grey.shade200),
                                ),
                              ),
                              Container(
                                decoration: BoxDecoration(
                                  borderRadius: BorderRadius.circular(36),
                                  gradient: LinearGradient(
                                    begin: Alignment.bottomCenter,
                                    end: Alignment.topCenter,
                                    colors: [Colors.black.withOpacity(0.85), Colors.transparent],
                                  ),
                                ),
                                padding: const EdgeInsets.all(28),
                                child: Column(
                                  mainAxisAlignment: MainAxisAlignment.end,
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      'MISSION DU JOUR',
                                      style: GoogleFonts.manrope(
                                        fontSize: 10,
                                        fontWeight: FontWeight.w900,
                                        color: AppTheme.primaryGreen,
                                        letterSpacing: 1.5,
                                      ),
                                    ),
                                    const SizedBox(height: 6),
                                    Text(
                                      'Objectif : 10 bouteilles recyclées',
                                      style: GoogleFonts.outfit(
                                        fontSize: 24,
                                        fontWeight: FontWeight.w800,
                                        color: Colors.white,
                                      ),
                                    ),
                                    const SizedBox(height: 8),
                                    PremiumButton(
                                      text: 'PARTICIPER +100 PTS',
                                      onPressed: () {
                                        if (AuthState.currentUser == null) {
                                          AuthGuardDialog.check(context);
                                        } else {
                                          // Action de participation
                                        }
                                      },
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ).animate().fadeIn(delay: 200.ms).slideY(begin: 0.1, end: 0, curve: Curves.easeOutBack),
                  ),

                  // 3. Pinterest Style Grid
                  _isLoading
                      ? const GridSkeletonLoader()
                      : SliverPadding(
                          padding: const EdgeInsets.symmetric(horizontal: 20),
                          sliver: SliverGrid(
                            delegate: SliverChildBuilderDelegate(
                              (context, index) {
                                return PinterestPostCard(
                                  post: _posts[index],
                                  onLike: () => _handleLike(index),
                                  onSave: () => _handleSave(index),
                                  onComment: () => _showCommentModal(_posts[index]),
                                  onTap: () => PostRegistry.navigateToPost(_posts[index].id),
                                  onMore: (_posts[index].userName == 'Vous' ||
                                          _posts[index].userName == AuthState.currentUser?.name)
                                      ? () => _showPinterestOptionsMenu(context, _posts[index])
                                      : null,
                                )
                                    .animate()
                                    .fadeIn(delay: (index * 50).ms, duration: 600.ms)
                                    .slideY(begin: 0.2, end: 0, curve: Curves.easeOutCubic);
                              },
                              childCount: _posts.length,
                            ),
                            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                              crossAxisCount: 2,
                              mainAxisSpacing: 24,
                              crossAxisSpacing: 16,
                              childAspectRatio: 0.62,
                            ),
                          ),
                        ),

                  const SliverToBoxAdapter(child: SizedBox(height: 120)),
                ],
              ),
            ),
          ),

          // Floating Action Button
          Positioned(
            bottom: 110,
            right: 20,
            child: GestureDetector(
              onTap: _createNewPost,
              child: Container(
                width: 56,
                height: 56,
                decoration: const BoxDecoration(
                  color: AppTheme.deepNavy,
                  shape: BoxShape.circle,
                  boxShadow: [BoxShadow(color: Colors.black26, blurRadius: 10, offset: Offset(0, 4))],
                ),
                child: const Icon(Icons.add, color: Colors.white),
              ),
            ),
          )
        ],
      ),
    );
  }

  void _showPinterestOptionsMenu(BuildContext context, Post post) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        padding: const EdgeInsets.all(24),
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(32)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.edit_rounded, color: AppTheme.primaryGreen),
              title: const Text("Modifier"),
              onTap: () {
                Navigator.pop(context);
                _editPost(post);
              },
            ),
            ListTile(
              leading: const Icon(Icons.delete_outline_rounded, color: Colors.redAccent),
              title: const Text("Supprimer", style: TextStyle(color: Colors.redAccent)),
              onTap: () {
                Navigator.pop(context);
                _deletePost(post);
              },
            ),
            const SizedBox(height: 16),
            PremiumButton(text: "ANNULER", onPressed: () => Navigator.pop(context)),
          ],
        ),
      ),
    );
  }

  Widget _buildPinterestTab(String label, {bool isSelected = false}) {
    return Container(
      margin: const EdgeInsets.only(right: 8),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      decoration: BoxDecoration(
        color: isSelected ? AppTheme.deepNavy : Colors.transparent,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        label,
        style: GoogleFonts.manrope(
          color: isSelected ? Colors.white : AppTheme.deepNavy,
          fontWeight: isSelected ? FontWeight.w800 : FontWeight.w700,
          fontSize: 13,
        ),
      ),
    );
  }

  void _handleLike(int index) {
    if (AuthState.currentUser == null) {
      AuthGuardDialog.check(context);
      return;
    }
    HapticFeedback.lightImpact();
    final post = _posts[index];
    final updatedPost = post.copyWith(
      isLiked: !post.isLiked,
      likes: post.isLiked ? post.likes - 1 : post.likes + 1,
    );
    PostRegistry.updatePost(updatedPost);
  }

  void _showCommentModal(Post post) {
    if (AuthState.currentUser == null) {
      AuthGuardDialog.check(context);
      return;
    }
    final TextEditingController commentController = TextEditingController();
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
                    Text('Commentaires', style: GoogleFonts.outfit(fontSize: 20, fontWeight: FontWeight.bold)),
                    IconButton(onPressed: () => Navigator.pop(context), icon: const Icon(Icons.close)),
                  ],
                ),
              ),
              Expanded(
                child: post.commentList.isEmpty
                    ? Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.chat_bubble_outline_rounded, size: 48, color: Colors.grey.shade300),
                            const SizedBox(height: 16),
                            Text(
                              "Aucun commentaire pour le moment.\nSoyez le premier à commenter !",
                              textAlign: TextAlign.center,
                              style: GoogleFonts.manrope(color: AppTheme.textMuted),
                            ),
                          ],
                        ),
                      )
                    : ListView.builder(
                        padding: const EdgeInsets.all(24),
                        itemCount: post.commentList.length,
                        itemBuilder: (context, index) {
                          final comment = post.commentList[index];
                          return Padding(
                            padding: const EdgeInsets.only(bottom: 16),
                            child: GestureDetector(
                              onLongPress: () {
                                final currentUserId = int.tryParse(AuthState.currentUser?.id ?? '');
                                if (comment.userId == currentUserId && comment.id != null) {
                                  showModalBottomSheet(
                                    context: context,
                                    backgroundColor: Colors.transparent,
                                    builder: (context) => Container(
                                      decoration: const BoxDecoration(
                                        color: Colors.white,
                                        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
                                      ),
                                      child: Column(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          const SizedBox(height: 8),
                                          Container(
                                            width: 40,
                                            height: 4,
                                            decoration: BoxDecoration(
                                              color: Colors.grey.shade300,
                                              borderRadius: BorderRadius.circular(2),
                                            ),
                                          ),
                                          ListTile(
                                            leading: const Icon(Icons.edit_rounded, color: AppTheme.primaryGreen),
                                            title: const Text('Modifier le commentaire'),
                                            onTap: () {
                                              Navigator.pop(context);
                                              _showEditCommentDialog(context, post.id, comment, () {
                                                setModalState(() {});
                                              });
                                            },
                                          ),
                                          ListTile(
                                            leading: const Icon(Icons.delete_outline_rounded, color: Colors.red),
                                            title: const Text('Supprimer', style: TextStyle(color: Colors.red)),
                                            onTap: () {
                                              PostRegistry.deleteComment(post.id, comment.id!);
                                              Navigator.pop(context);
                                              setModalState(() {});
                                            },
                                          ),
                                          const SizedBox(height: 24),
                                        ],
                                      ),
                                    ),
                                  );
                                }
                              },
                              child: Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  comment.userAvatar != null
                                      ? Container(
                                          width: 36,
                                          height: 36,
                                          decoration: BoxDecoration(
                                            color: AppTheme.primaryGreen.withOpacity(0.1),
                                            shape: BoxShape.circle,
                                          ),
                                          child: ClipOval(
                                            child: SafeNetworkImage(comment.userAvatar!, fit: BoxFit.cover),
                                          ),
                                        )
                                      : CircleAvatar(
                                          radius: 18,
                                          backgroundColor: AppTheme.primaryGreen.withOpacity(0.1),
                                          child: const Icon(Icons.person, size: 20, color: AppTheme.primaryGreen),
                                        ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: Container(
                                      padding: const EdgeInsets.all(12),
                                      decoration: BoxDecoration(
                                        color: Colors.grey.shade50,
                                        borderRadius: BorderRadius.circular(16),
                                        border: Border.all(color: Colors.grey.shade100),
                                      ),
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            comment.userName,
                                            style: GoogleFonts.manrope(fontWeight: FontWeight.bold, fontSize: 13),
                                          ),
                                          const SizedBox(height: 4),
                                          Text(
                                            comment.content,
                                            style: GoogleFonts.manrope(fontSize: 14),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                ],
                              ),
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
                          hintText: 'Ajouter un commentaire...',
                          filled: true,
                          fillColor: Colors.grey.shade100,
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(24),
                            borderSide: BorderSide.none,
                          ),
                          contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Container(
                      decoration: const BoxDecoration(color: AppTheme.primaryGreen, shape: BoxShape.circle),
                      child: IconButton(
                        onPressed: () {
                          if (commentController.text.isNotEmpty) {
                            final user = AuthState.currentUser;
                            final newComment = PostComment(
                              userName: user?.name ?? 'Citoyen',
                              content: commentController.text,
                              userAvatar: user?.avatarUrl,
                            );
                            PostRegistry.addComment(post.id, newComment);
                            setModalState(() {}); // Feedback visuel immédiat dans le modal
                            commentController.clear();
                          }
                        },
                        icon: const Icon(Icons.send_rounded, color: Colors.white, size: 20),
                      ),
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

  void _showEditCommentDialog(BuildContext context, String postId, PostComment comment, VoidCallback onUpdate) {
    final controller = TextEditingController(text: comment.content);
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Modifier votre commentaire', style: GoogleFonts.manrope(fontWeight: FontWeight.bold)),
        content: TextField(
          controller: controller,
          maxLines: 3,
          decoration: InputDecoration(
            hintText: 'Votre message...',
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('Annuler', style: TextStyle(color: Colors.grey.shade600)),
          ),
          ElevatedButton(
            onPressed: () {
              if (controller.text.isNotEmpty && controller.text != comment.content) {
                PostRegistry.updateComment(postId, comment.id!, controller.text);
                onUpdate();
              }
              Navigator.pop(context);
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.primaryGreen,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
            child: const Text('Enregistrer', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  void _handleSave(int index) {
    if (AuthState.currentUser == null) {
      AuthGuardDialog.check(context);
      return;
    }
    HapticFeedback.mediumImpact();
    final post = _posts[index];
    final updatedPost = post.copyWith(isSaved: !post.isSaved);
    PostRegistry.updatePost(updatedPost);

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(_posts[index].isSaved ? 'Publication enregistrée !' : 'Enregistrement retiré'),
        behavior: SnackBarBehavior.floating,
        backgroundColor: _posts[index].isSaved ? AppTheme.primaryGreen : AppTheme.deepNavy,
        duration: const Duration(seconds: 1),
      ),
    );
  }

  void _editPost(Post post) {
    _postController.text = post.description;
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => _PremiumCreatePostModal(
        postController: _postController,
        isEditing: true,
        initialImageUrl: post.imageUrl,
        onPost: (text, imagePath) {
          if (mounted) {
            setState(() {
              final index = _posts.indexWhere((p) => p.id == post.id);
              if (index != -1) {
                final updatedPost = _posts[index].copyWith(
                  description: text,
                );
                PostRegistry.updatePost(updatedPost);
              }
            });
          }
          _postController.clear();
        },
      ),
    );
  }

  void _deletePost(Post post) {
    HapticFeedback.vibrate();
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text("Supprimer la publication ?", style: GoogleFonts.outfit(fontWeight: FontWeight.bold)),
        content: const Text("Cette action est irréversible."),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text("ANNULER", style: GoogleFonts.manrope(color: AppTheme.textMuted)),
          ),
          TextButton(
            onPressed: () {
              if (mounted) {
                PostRegistry.deletePost(post.id);
              }
              Navigator.pop(context);
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text('Publication supprimée', style: GoogleFonts.manrope()),
                  backgroundColor: Colors.redAccent,
                  behavior: SnackBarBehavior.floating,
                ),
              );
            },
            child: Text("SUPPRIMER", style: GoogleFonts.manrope(color: Colors.redAccent, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }
}

class _PremiumCreatePostModal extends StatefulWidget {
  final TextEditingController postController;
  final Function(String, String?) onPost;
  final bool isEditing;
  final String? initialImageUrl;
  const _PremiumCreatePostModal({
    required this.postController,
    required this.onPost,
    this.isEditing = false,
    this.initialImageUrl,
  });

  @override
  State<_PremiumCreatePostModal> createState() => _PremiumCreatePostModalState();
}

class _PremiumCreatePostModalState extends State<_PremiumCreatePostModal> {
  XFile? _selectedImage;
  final ImagePicker _picker = ImagePicker();

  Future<void> _pickImage() async {
    try {
      final XFile? image = await _picker.pickImage(source: ImageSource.gallery);
      if (image != null) {
        setState(() {
          _selectedImage = image;
        });
      }
    } catch (e) {
      debugPrint("Erreur picking image: $e");
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(32)),
      ),
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom + 24,
        left: 24,
        right: 24,
        top: 24,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                widget.isEditing ? "Modifier la Publication" : "Nouvelle Publication",
                style: GoogleFonts.outfit(fontSize: 22, fontWeight: FontWeight.bold, color: AppTheme.deepNavy),
              ),
              IconButton(
                onPressed: () {
                  widget.postController.clear();
                  Navigator.pop(context);
                },
                icon: const Icon(Icons.close_rounded),
              ),
            ],
          ),
          const SizedBox(height: 20),
          TextField(
            controller: widget.postController,
            style: GoogleFonts.manrope(fontSize: 16),
            decoration: InputDecoration(
              hintText: "Partagez votre impact écologique...",
              hintStyle: GoogleFonts.manrope(color: AppTheme.textMuted),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(16),
                borderSide: BorderSide(color: Colors.grey.shade200),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(16),
                borderSide: BorderSide(color: Colors.grey.shade200),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(16),
                borderSide: const BorderSide(color: AppTheme.primaryGreen),
              ),
              filled: true,
              fillColor: Colors.grey.shade50,
            ),
            maxLines: 4,
          ),
          const SizedBox(height: 16),

          // Aperçu de l'image
          if (_selectedImage != null || widget.initialImageUrl != null)
            Stack(
              children: [
                Container(
                  height: 180,
                  width: double.infinity,
                  decoration: BoxDecoration(borderRadius: BorderRadius.circular(16)),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(16),
                    child: _selectedImage != null
                        ? (kIsWeb
                            ? SafeNetworkImage(_selectedImage!.path, fit: BoxFit.cover, placeholder: Container(color: Colors.grey.shade200))
                            : Image.file(File(_selectedImage!.path), fit: BoxFit.cover))
                        : (widget.initialImageUrl!.startsWith('http') || widget.initialImageUrl!.startsWith('blob:')
                            ? SafeNetworkImage(widget.initialImageUrl!, fit: BoxFit.cover, placeholder: Container(color: Colors.grey.shade200))
                            : Image.file(File(widget.initialImageUrl!), fit: BoxFit.cover)),
                  ),
                ),
                if (!widget.isEditing || _selectedImage != null)
                  Positioned(
                    top: 8,
                    right: 8,
                    child: GestureDetector(
                      onTap: () => setState(() => _selectedImage = null),
                      child: Container(
                        padding: const EdgeInsets.all(4),
                        decoration: const BoxDecoration(color: Colors.black54, shape: BoxShape.circle),
                        child: const Icon(Icons.close, color: Colors.white, size: 20),
                      ),
                    ),
                  ),
              ],
            )
          else
            GestureDetector(
              onTap: _pickImage,
              child: Container(
                height: 100,
                decoration: BoxDecoration(
                  color: AppTheme.primaryGreen.withOpacity(0.05),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: AppTheme.primaryGreen.withOpacity(0.2), style: BorderStyle.solid),
                ),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(Icons.add_a_photo_rounded, color: AppTheme.primaryGreen, size: 32),
                    const SizedBox(height: 8),
                    Text(
                      "Ajouter une image",
                      style: GoogleFonts.manrope(
                        color: AppTheme.primaryGreen,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
            ),

          const SizedBox(height: 24),
          PremiumButton(
            text: widget.isEditing ? "Enregistrer" : "Publier",
            onPressed: () {
              if (widget.postController.text.isNotEmpty || _selectedImage != null || widget.initialImageUrl != null) {
                widget.onPost(widget.postController.text, _selectedImage?.path);
                Navigator.pop(context);
              }
            },
          ),
        ],
      ),
    );
  }
}
