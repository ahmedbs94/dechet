import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

enum PostStatus { approved, pendingAI, rejectedByAI }

class Post {
  final String id;
  final String userName;
  final String userAvatarUrl;
  final String timeAgo;
  final String imageUrl;
  final String description;
  int likes;
  int comments;
  final List<String> commentList;
  bool isSaved;
  bool isLiked;
  final bool isFlagged;
  final String? personalNote;
  PostStatus status;

  Post({
    required this.id,
    required this.userName,
    required this.userAvatarUrl,
    required this.timeAgo,
    required this.imageUrl,
    required this.description,
    this.likes = 0,
    this.comments = 0,
    this.commentList = const [],
    this.isSaved = false,
    this.isLiked = false,
    this.isFlagged = false,
    this.personalNote,
    this.status = PostStatus.approved,
  });

  Post copyWith({
    String? id,
    String? userName,
    String? userAvatarUrl,
    String? timeAgo,
    String? imageUrl,
    String? description,
    int? likes,
    int? comments,
    List<String>? commentList,
    bool? isSaved,
    bool? isLiked,
    bool? isFlagged,
    String? personalNote,
    PostStatus? status,
  }) {
    return Post(
      id: id ?? this.id,
      userName: userName ?? this.userName,
      userAvatarUrl: userAvatarUrl ?? this.userAvatarUrl,
      timeAgo: timeAgo ?? this.timeAgo,
      imageUrl: imageUrl ?? this.imageUrl,
      description: description ?? this.description,
      likes: likes ?? this.likes,
      comments: comments ?? this.comments,
      commentList: commentList ?? this.commentList,
      isSaved: isSaved ?? this.isSaved,
      isLiked: isLiked ?? this.isLiked,
      isFlagged: isFlagged ?? this.isFlagged,
      personalNote: personalNote ?? this.personalNote,
      status: status ?? this.status,
    );
  }

  // Factory constructor for creating a new Post instance from a map (simulating JSON from API)
  factory Post.fromJson(Map<String, dynamic> json) {
    return Post(
      id: json['id'],
      userName: json['userName'],
      userAvatarUrl: json['userAvatarUrl'],
      timeAgo: json['timeAgo'],
      imageUrl: json['imageUrl'],
      description: json['description'],
      likes: json['likes'] ?? 0,
      comments: json['comments'] ?? 0,
      commentList: List<String>.from(json['commentList'] ?? []),
      isSaved: json['isSaved'] ?? false,
      isLiked: json['isLiked'] ?? false,
      isFlagged: json['isFlagged'] ?? false,
      personalNote: json['personalNote'],
      status: PostStatus.values
          .firstWhere((e) => e.toString() == 'PostStatus.${json['status']}', orElse: () => PostStatus.approved),
    );
  }
}

// Mock Data for demonstration
final List<Post> mockPosts = [
  Post(
    id: '1',
    userName: 'Amine T.',
    userAvatarUrl: 'https://images.unsplash.com/photo-1599566150163-29194dcaad36?w=100&h=100&fit=crop',
    timeAgo: 'Il y a 2h',
    imageUrl: 'https://images.unsplash.com/photo-1532996122724-e3c354a0b15b?w=800&q=80',
    description:
        'Je viens de recycler 5kg de plastique ! Pensez à rincer vos bouteilles avant de les jeter. #EcoVie #Recyclage',
    likes: 24,
    comments: 2,
    commentList: ['Bravo Amine !', 'Très bon conseil pour le rinçage.'],
    status: PostStatus.approved,
  ),
  Post(
    id: '2',
    userName: 'Sarah B.',
    userAvatarUrl: 'https://images.unsplash.com/photo-1494790108377-be9c29b29330?w=100&h=100&fit=crop',
    timeAgo: 'Il y a 4h',
    imageUrl: 'https://images.unsplash.com/photo-1542601906990-b4d3fb778b09?w=800&q=80',
    description:
        'J\'ai commencé mon premier bac à compost aujourd\'hui ! 🌱 C\'est incroyable tout ce qu\'on peut réduire comme déchets.',
    likes: 45,
    comments: 1,
    commentList: ['C\'est super Sarah, le compost change tout !'],
    status: PostStatus.approved,
  ),
  Post(
    id: '3',
    userName: 'Collectif Vert',
    userAvatarUrl: 'https://images.unsplash.com/photo-1554151228-14d9def656e4?w=100&h=100&fit=crop',
    timeAgo: 'Hier',
    imageUrl:
        'https://media.istockphoto.com/id/1156692026/fr/vectoriel/b%C3%A9n%C3%A9voles-ramassant-les-ordures-en-plastique-%C3%A0-lext%C3%A9rieur-concept-de-volontariat.jpg?s=612x612&w=0&k=20&c=yRbJL49HMH_KYLDcRq7ehn5DWNMRiP87sms-WYpGBDU=',
    description:
        'Une journée incroyable de nettoyage avec nos bénévoles. Plus de 200kg collectés ! Rejoignez-nous la semaine prochaine. 🌍💙 #Volontariat #PlanètePropre',
    likes: 156,
    comments: 3,
    commentList: ['Merci pour votre engagement.', 'C\'était une super journée !', 'À la semaine prochaine.'],
    status: PostStatus.approved,
  ),
  Post(
    id: '4',
    userName: 'Utilisateur Test',
    userAvatarUrl: 'https://images.unsplash.com/photo-1599566150163-29194dcaad36?w=100&h=100&fit=crop',
    timeAgo: 'Il y a 1h',
    imageUrl: 'https://images.unsplash.com/photo-1557683316-973673baf926?w=800&q=80',
    description: 'Description suspecte bloquée par l\'IA.',
    status: PostStatus.rejectedByAI,
  ),
];

/// Comment model for posts
class PostComment {
  final String id;
  final String userId;
  final String userName;
  final String userAvatar;
  final String content;
  final DateTime createdAt;

  PostComment({
    required this.id,
    required this.userId,
    required this.userName,
    required this.userAvatar,
    required this.content,
    DateTime? createdAt,
  }) : createdAt = createdAt ?? DateTime.now();
}

/// Global registry for managing posts with reactive updates
class PostRegistry {
  static final ValueNotifier<List<Post>> postsNotifier = ValueNotifier<List<Post>>(List<Post>.from(mockPosts));

  /// Signal for navigating to a specific post (postId or null)
  static final ValueNotifier<String?> navigationSignal = ValueNotifier<String?>(null);

  /// Clé de stockage pour les publications enregistrées
  static const String _savedPostsKey = 'saved_post_ids';

  static List<Post> get posts => postsNotifier.value;

  /// Initialiser les états sauvegardés depuis le stockage local
  /// Doit être appelé au démarrage de l'application
  static Future<void> loadSavedStates() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final savedIds = prefs.getStringList(_savedPostsKey) ?? [];
      if (savedIds.isNotEmpty) {
        final newList = List<Post>.from(postsNotifier.value);
        for (int i = 0; i < newList.length; i++) {
          if (savedIds.contains(newList[i].id)) {
            newList[i] = newList[i].copyWith(isSaved: true);
          }
        }
        postsNotifier.value = newList;
      }
    } catch (e) {
      debugPrint('Erreur chargement des posts enregistrés: $e');
    }
  }

  /// Persister l'état des publications enregistrées
  static Future<void> _persistSavedStates() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final savedIds = postsNotifier.value.where((p) => p.isSaved).map((p) => p.id).toList();
      await prefs.setStringList(_savedPostsKey, savedIds);
    } catch (e) {
      debugPrint('Erreur sauvegarde des posts enregistrés: $e');
    }
  }

  static void addPost(Post post) {
    postsNotifier.value = [post, ...postsNotifier.value];
  }

  static void updatePost(Post updatedPost) {
    final index = postsNotifier.value.indexWhere((p) => p.id == updatedPost.id);
    if (index != -1) {
      final oldPost = postsNotifier.value[index];
      final newList = List<Post>.from(postsNotifier.value);
      newList[index] = updatedPost;
      postsNotifier.value = newList;

      // Si l'état isSaved a changé, persister automatiquement
      if (oldPost.isSaved != updatedPost.isSaved) {
        _persistSavedStates();
      }
    }
  }

  static void removePost(String postId) {
    postsNotifier.value = postsNotifier.value.where((p) => p.id != postId).toList();
    _persistSavedStates(); // Nettoyer les IDs enregistrés
  }

  /// Alias for removePost, used by feed_tab_new
  static void deletePost(String postId) => removePost(postId);

  static void notifyListeners() {
    postsNotifier.value = List<Post>.from(postsNotifier.value);
  }

  /// Sync all posts (simulated - in a real app this would fetch from server)
  static Future<void> syncAllPosts() async {
    await Future.delayed(const Duration(milliseconds: 500));
    // Recharger les états sauvegardés après synchronisation
    await loadSavedStates();
  }

  /// Navigate to a specific post by setting the navigationSignal
  static void navigateToPost(String postId) {
    navigationSignal.value = postId;
    Future.delayed(const Duration(seconds: 1), () {
      navigationSignal.value = null;
    });
  }

  /// Add a comment to a post
  static void addComment(String postId, PostComment comment) {
    final index = postsNotifier.value.indexWhere((p) => p.id == postId);
    if (index != -1) {
      final post = postsNotifier.value[index];
      final newCommentList = List<String>.from(post.commentList)..add(comment.content);
      final updatedPost = post.copyWith(
        commentList: newCommentList,
        comments: post.comments + 1,
      );
      final newList = List<Post>.from(postsNotifier.value);
      newList[index] = updatedPost;
      postsNotifier.value = newList;
    }
  }

  /// Update a comment in a post
  static void updateComment(String postId, String commentId, String newContent) {
    // Since comments are stored as strings, we update by index
    final index = postsNotifier.value.indexWhere((p) => p.id == postId);
    if (index != -1) {
      final post = postsNotifier.value[index];
      final commentIndex = int.tryParse(commentId) ?? -1;
      if (commentIndex >= 0 && commentIndex < post.commentList.length) {
        final newCommentList = List<String>.from(post.commentList);
        newCommentList[commentIndex] = newContent;
        final updatedPost = post.copyWith(commentList: newCommentList);
        final newList = List<Post>.from(postsNotifier.value);
        newList[index] = updatedPost;
        postsNotifier.value = newList;
      }
    }
  }

  /// Delete a comment from a post
  static void deleteComment(String postId, String commentId) {
    final index = postsNotifier.value.indexWhere((p) => p.id == postId);
    if (index != -1) {
      final post = postsNotifier.value[index];
      final commentIndex = int.tryParse(commentId) ?? -1;
      if (commentIndex >= 0 && commentIndex < post.commentList.length) {
        final newCommentList = List<String>.from(post.commentList);
        newCommentList.removeAt(commentIndex);
        final updatedPost = post.copyWith(
          commentList: newCommentList,
          comments: post.comments - 1,
        );
        final newList = List<Post>.from(postsNotifier.value);
        newList[index] = updatedPost;
        postsNotifier.value = newList;
      }
    }
  }
}
