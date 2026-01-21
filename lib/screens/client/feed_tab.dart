import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../theme/app_theme.dart';
import '../../models/post_model.dart';
import '../../widgets/glass_card.dart';

class FeedTab extends StatefulWidget {
  const FeedTab({Key? key}) : super(key: key);

  @override
  State<FeedTab> createState() => _FeedTabState();
}

class _FeedTabState extends State<FeedTab> {
  late List<Post> _posts;
  final TextEditingController _postController = TextEditingController();

  @override
  void initState() {
    super.initState();
    // Simulate a larger list by duplicating and giving unique IDs
    // Only show approved posts in the main feed
    _posts = mockPosts.where((p) => p.status == PostStatus.approved).toList();
  }

  void _createNewPost() {
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
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide(color: Colors.grey.shade200)),
                enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide(color: Colors.grey.shade200)),
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
                  Text('Ajouter une image', style: GoogleFonts.outfit(color: AppTheme.primaryGreen, fontWeight: FontWeight.w600)),
                ],
              ),
            ),
            const Spacer(),
            ElevatedButton(
              onPressed: () {
                if (_postController.text.isNotEmpty) {
                  final text = _postController.text.toLowerCase();
                  bool isSpam = text.contains('spam') || text.contains('mauvais');
                  
                  final newPost = Post(
                    id: DateTime.now().toString(),
                    userName: 'Moi',
                    userAvatarUrl: 'https://images.unsplash.com/photo-1599566150163-29194dcaad36?w=100&h=100&fit=crop',
                    timeAgo: 'À l\'instant',
                    imageUrl: 'https://images.unsplash.com/photo-1532996122724-e3c354a0b15b?w=800&q=80',
                    description: _postController.text,
                    likes: 0,
                    comments: 0,
                    status: isSpam ? PostStatus.rejectedByAI : PostStatus.approved,
                  );

                  if (!isSpam) {
                    setState(() {
                      _posts.insert(0, newPost);
                    });
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Annonce publiée avec succès !'), backgroundColor: AppTheme.primaryGreen),
                    );
                  } else {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Détection IA : Contenu suspect. En attente de validation admin.'), 
                        backgroundColor: Colors.orange,
                        duration: Duration(seconds: 4),
                      ),
                    );
                    // In a real app, this would be saved to DB with rejectedByAI status
                    mockPosts.add(newPost); 
                  }
                  
                  _postController.clear();
                  Navigator.pop(context);
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
              child: Text('Communauté', 
                style: AppTheme.seniorTheme.textTheme.headlineMedium?.copyWith(fontSize: 28)),
            ),
            actions: [
              IconButton(
                icon: const Icon(Icons.search_rounded, color: AppTheme.deepSlate),
                onPressed: () {},
              ),
              const SizedBox(width: 24),
            ],
          ),

          SliverList(
            delegate: SliverChildBuilderDelegate(
              (context, index) {
                final post = _posts[index];
                return Animate(
                  key: ValueKey(post.id),
                  effects: [
                    FadeEffect(delay: (index * 50).ms, duration: 600.ms),
                    SlideEffect(begin: const Offset(0, 0.1)),
                  ],
                  child: Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: _PremiumPostCard(
                      post: post,
                      onLike: () {
                        setState(() {
                          // Simple mock like toggle simulation
                          // In a real app we'd have a local 'isLiked' state
                        });
                      },
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

class _PremiumPostCard extends StatefulWidget {
  final Post post;
  final VoidCallback onLike;
  const _PremiumPostCard({required this.post, required this.onLike});

  @override
  State<_PremiumPostCard> createState() => _PremiumPostCardState();
}

class _PremiumPostCardState extends State<_PremiumPostCard> {
  bool _isLiked = false;
  late int _likeCount;
  bool _isSaved = false;

  @override
  void initState() {
    super.initState();
    _likeCount = widget.post.likes;
    _isSaved = widget.post.isSaved;
  }

  void _handleLike() {
    setState(() {
      _isLiked = !_isLiked;
      _isLiked ? _likeCount++ : _likeCount--;
    });
    widget.onLike();
  }

  void _handleSave() {
    setState(() {
      _isSaved = !_isSaved;
      widget.post.isSaved = _isSaved;
    });
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(_isSaved ? 'Annonce enregistrée !' : 'Annonce retirée des favoris.'),
        duration: const Duration(seconds: 2),
        backgroundColor: _isSaved ? AppTheme.primaryGreen : AppTheme.deepSlate,
      ),
    );
  }

  void _showCommentModal() {
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
                width: 40, height: 4,
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
                child: ListView.builder(
                  padding: const EdgeInsets.all(24),
                  itemCount: widget.post.commentList.length,
                  itemBuilder: (context, index) => Padding(
                    padding: const EdgeInsets.only(bottom: 16),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const CircleAvatar(radius: 18, backgroundColor: AppTheme.backgroundLight, child: Icon(Icons.person, size: 20, color: AppTheme.primaryGreen)),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(color: Colors.grey.shade50, borderRadius: BorderRadius.circular(16)),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text('Utilisateur', style: GoogleFonts.inter(fontWeight: FontWeight.bold, fontSize: 13)),
                                const SizedBox(height: 4),
                                Text(widget.post.commentList[index], style: GoogleFonts.inter(fontSize: 14)),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
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
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(24), borderSide: BorderSide.none),
                          contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    IconButton(
                      onPressed: () {
                        if (commentController.text.isNotEmpty) {
                          setModalState(() {
                            widget.post.commentList.insert(0, commentController.text);
                            widget.post.comments++;
                          });
                          setState(() {}); // Update main UI counter
                          commentController.clear();
                        }
                      },
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
                    backgroundImage: NetworkImage(widget.post.userAvatarUrl),
                  ),
                ),
                const SizedBox(width: 14),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(widget.post.userName, style: GoogleFonts.outfit(fontWeight: FontWeight.bold, fontSize: 16)),
                    Text(widget.post.timeAgo, style: const TextStyle(fontSize: 12, color: AppTheme.textMuted, fontWeight: FontWeight.w500)),
                  ],
                ),
                const Spacer(),
                const Icon(Icons.more_horiz_rounded, color: AppTheme.textMuted),
              ],
            ),
          ),

          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: Text(
              widget.post.description,
              style: GoogleFonts.inter(fontSize: 15, height: 1.6, color: AppTheme.textMain),
            ),
          ),

          const SizedBox(height: 16),

          Animate(
            effects: [FadeEffect(duration: 800.ms), ScaleEffect(begin: const Offset(0.98, 0.98))],
            child: Container(
              height: 340,
              width: double.infinity,
              margin: const EdgeInsets.symmetric(horizontal: 20),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(24),
                image: DecorationImage(image: NetworkImage(widget.post.imageUrl), fit: BoxFit.cover),
                boxShadow: [
                  BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10, offset: const Offset(0, 5))
                ],
              ),
              child: Stack(
                fit: StackFit.expand,
                children: [
                  Positioned(
                    top: 16,
                    right: 16,
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(12),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                        color: Colors.black45,
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(Icons.eco_rounded, color: AppTheme.accentMint, size: 14),
                            const SizedBox(width: 6),
                            Text('TRI BIEN VÉRIFIÉ', style: GoogleFonts.outfit(fontSize: 9, fontWeight: FontWeight.w900, color: Colors.white, letterSpacing: 1)),
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),

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
                  '${widget.post.comments}', 
                  AppTheme.textMuted,
                  onTap: _showCommentModal,
                ),
                const Spacer(),
                IconButton(
                  onPressed: _handleSave,
                  icon: Icon(
                    _isSaved ? Icons.bookmark_rounded : Icons.bookmark_border_rounded, 
                    color: _isSaved ? AppTheme.primaryGreen : AppTheme.textMuted, 
                    size: 24
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
