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

/// Comment model for posts
class PostComment {
  final String? id;
  final String? userId;
  final String userName;
  final String? userAvatar;
  final String content;
  final DateTime createdAt;

  PostComment({
    this.id,
    this.userId,
    required this.userName,
    this.userAvatar,
    required this.content,
    DateTime? createdAt,
  }) : createdAt = createdAt ?? DateTime.now();
}

/// Global registry for managing posts with reactive updates
class PostRegistry {
  // Liste vide — les vraies donnees viennent de l'API via FeedTab (fetchPosts)
  static final ValueNotifier<List<Post>> postsNotifier = ValueNotifier<List<Post>>([]);

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
      if (savedIds.isNotEmpty && postsNotifier.value.isNotEmpty) {
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

  static void deletePost(String postId) => removePost(postId);

  static void notifyListeners() {
    postsNotifier.value = List<Post>.from(postsNotifier.value);
  }

  /// Sync avec le backend — appelé pour forcer un rechargement
  static Future<void> syncAllPosts() async {
    await Future.delayed(const Duration(milliseconds: 100));
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
          comments: (post.comments - 1).clamp(0, 999999),
        );
        final newList = List<Post>.from(postsNotifier.value);
        newList[index] = updatedPost;
        postsNotifier.value = newList;
      }
    }
  }
}
