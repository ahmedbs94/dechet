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
  final bool isFlagged;
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
    this.isFlagged = false,
    this.status = PostStatus.approved,
  });

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
      isFlagged: json['isFlagged'] ?? false,
      status: PostStatus.values.firstWhere((e) => e.toString() == 'PostStatus.${json['status']}', orElse: () => PostStatus.approved),
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
    description: 'Je viens de recycler 5kg de plastique ! Pensez à rincer vos bouteilles avant de les jeter. #EcoVie #Recyclage',
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
    description: 'J\'ai commencé mon premier bac à compost aujourd\'hui ! 🌱 C\'est incroyable tout ce qu\'on peut réduire comme déchets.',
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
    imageUrl: 'https://media.istockphoto.com/id/1156692026/fr/vectoriel/b%C3%A9n%C3%A9voles-ramassant-les-ordures-en-plastique-%C3%A0-lext%C3%A9rieur-concept-de-volontariat.jpg?s=612x612&w=0&k=20&c=yRbJL49HMH_KYLDcRq7ehn5DWNMRiP87sms-WYpGBDU=',
    description: 'Une journée incroyable de nettoyage avec nos bénévoles. Plus de 200kg collectés ! Rejoignez-nous la semaine prochaine. 🌍💙 #Volontariat #PlanètePropre',
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
