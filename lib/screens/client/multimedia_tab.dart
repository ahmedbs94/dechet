import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../../theme/app_theme.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:video_player/video_player.dart';
import 'package:chewie/chewie.dart';
import '../../services/auth_service.dart';
import '../../constants.dart';
import '../../widgets/meetings_section.dart';
import '../../widgets/auth_prompt_dialog.dart';
import '../../models/user_model.dart';
import '../../services/l10n_service.dart';
import 'quiz_play_screen.dart';
import '../../widgets/app_states.dart';

// Écran principal gérant l'affichage des contenus éducatifs (Vidéos, Articles, Quiz)
class MultimediaTab extends StatefulWidget {
  const MultimediaTab({Key? key}) : super(key: key);

  @override
  State<MultimediaTab> createState() => _MultimediaTabState();
}

class _MultimediaTabState extends State<MultimediaTab> {
  // État local pour gérer les filtres et les catégories
  String _selectedCategory = 'Tout';
  final List<String> _categories = ['Tout', 'Vidéos', 'Quiz'];

  // Quiz dynamiques depuis l'API
  final AuthService _authService = AuthService();
  List<dynamic> _apiQuizzes = [];
  bool _quizzesLoaded = false;
  // IDs des quiz déjà complétés par l'utilisateur
  final Set<int> _completedQuizIds = {};

  // Vidéos éducateur depuis l'API
  List<dynamic> _educatorVideos = [];
  List<dynamic> _videoCategories = [];
  bool _videosLoaded = false;

  @override
  void initState() {
    super.initState();
    L10n.addListener(_onLocaleChange);
    _loadApiQuizzes();
    _loadEducatorVideos();
    _loadVideoCategories();
  }

  void _onLocaleChange() {
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    L10n.removeListener(_onLocaleChange);
    super.dispose();
  }

  Future<void> _loadApiQuizzes() async {
    final quizzes = await _authService.fetchAvailableQuizzes();
    if (mounted) {
      setState(() { _apiQuizzes = quizzes; _quizzesLoaded = true; });
      _checkCompletedQuizzes(quizzes);
    }
  }

  Future<void> _checkCompletedQuizzes(List<dynamic> quizzes) async {
    for (final quiz in quizzes) {
      final id = quiz['id'] as int?;
      if (id == null) continue;
      try {
        final result = await _authService.fetchMyQuizResult(id);
        if (result != null && mounted) {
          setState(() => _completedQuizIds.add(id));
        }
      } catch (_) {}
    }
  }

  Future<void> _loadEducatorVideos() async {
    final videos = await _authService.fetchEducatorVideos();
    if (mounted) setState(() { _educatorVideos = videos; _videosLoaded = true; });
  }

  Future<void> _loadVideoCategories() async {
    final cats = await _authService.fetchVideoCategories();
    if (mounted) setState(() => _videoCategories = cats);
  }

  void _openQuiz(Map<String, dynamic> quiz) {
    // Garde d'authentification
    if (!AuthState.isLoggedIn) {
      AuthPromptDialog.show(context: context);
      return;
    }
    final id = quiz['id'] as int?;
    if (id != null && _completedQuizIds.contains(id)) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Row(
            children: [
              Icon(Icons.check_circle, color: Colors.white, size: 18),
              SizedBox(width: 10),
              Expanded(child: Text('Vous avez déjà complété ce quiz. Chaque quiz ne peut être passé qu\'une seule fois.')),
            ],
          ),
          backgroundColor: Colors.orange.shade700,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
      );
      return;
    }
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => QuizPlayScreen(quiz: quiz)),
    ).then((_) {
      // Rafraîchir la liste après retour (le quiz vient peut-être d'être complété)
      if (id != null) _checkCompletedQuizzes(_apiQuizzes);
    });
  }





  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).brightness == Brightness.dark ? const Color(0xFF0F172A) : const Color(0xFFF4F7F6),
      body: CustomScrollView(
        physics: const BouncingScrollPhysics(),
        slivers: [
          // En-tête Premium
          SliverAppBar(
            automaticallyImplyLeading: false,
            pinned: true,
            floating: false,
            expandedHeight: 110 + MediaQuery.of(context).padding.top,
            backgroundColor: Theme.of(context).colorScheme.surface,
            surfaceTintColor: Colors.transparent,
            elevation: 0,
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
                    child: const Icon(Icons.school_rounded, color: Colors.white, size: 16),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    L10n.tr('tab_multimedia_title'),
                    style: GoogleFonts.outfit(
                      fontSize: 20,
                      fontWeight: FontWeight.w900,
                      color: Theme.of(context).textTheme.titleLarge?.color ?? const Color(0xFF0F172A),
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

          // Filtres
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(24, 24, 24, 8),
              child: _buildCategoryList(),
            ),
          ),

          // Loading globaux
          if (!_quizzesLoaded || !_videosLoaded)
            const SliverFillRemaining(
              child: AppLoadingView(message: "Chargement du contenu pédagogique..."),
            )
          else ...[
            // ── Séances Google Meet ──────────────────────────────────────
            if (_selectedCategory == 'Tout')
              const SliverToBoxAdapter(
                child: MeetingsSection(),
              ),
            // Section Dossiers Vidéos (catégories)
            if ((_selectedCategory == 'Tout' || _selectedCategory == 'Vidéos') && (_videoCategories.isNotEmpty || _educatorVideos.isNotEmpty))
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(Icons.video_library_rounded, size: 20, color: Colors.teal.shade600),
                          const SizedBox(width: 8),
                          Text(L10n.tr('VIDÉOS ÉDUCATIVES'), style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w900, letterSpacing: 1.2, color: Colors.teal.shade800)),
                        ],
                      ),
                      const SizedBox(height: 16),
                      // Category folder cards grid
                      if (_videoCategories.isNotEmpty) ...[
                        GridView.builder(
                          padding: EdgeInsets.zero,
                          shrinkWrap: true,
                          physics: const NeverScrollableScrollPhysics(),
                          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(crossAxisCount: 2, childAspectRatio: 1.0, crossAxisSpacing: 16, mainAxisSpacing: 16),
                          itemCount: _videoCategories.length,
                          itemBuilder: (_, i) => _buildCategoryFolderCard(_videoCategories[i]),
                        ),
                        const SizedBox(height: 24),
                      ],
                      // Uncategorized videos
                      if (_educatorVideos.where((v) => v['category_id'] == null).isNotEmpty) ...[
                        Text(L10n.tr('AUTRES VIDÉOS'), style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w800, color: AppTheme.textMuted, letterSpacing: 1)),
                        const SizedBox(height: 12),
                        ..._educatorVideos.where((v) => v['category_id'] == null).map((v) => _buildEducatorVideoCard(v)).toList(),
                      ],
                    ],
                  ).animate().fadeIn().slideY(begin: 0.1),
                ),
              ),

            // Section Quiz IA dynamiques
            if ((_selectedCategory == 'Tout' || _selectedCategory == 'Quiz') && _apiQuizzes.isNotEmpty)
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(Icons.auto_awesome, size: 20, color: Colors.purple.shade500),
                          const SizedBox(width: 8),
                          Text(L10n.tr('QUIZ IA'), style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w900, letterSpacing: 1.2, color: Colors.purple.shade700)),
                          const Spacer(),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                            decoration: BoxDecoration(color: Colors.purple.withOpacity(0.1), borderRadius: BorderRadius.circular(10)),
                            child: Text(L10n.isArabic ? '${_apiQuizzes.length} اختبارات' : '${_apiQuizzes.length} quiz', style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.w700, color: Colors.purple)),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      ..._apiQuizzes.map((q) => _buildApiQuizCard(q)).toList(),
                    ],
                  ).animate().fadeIn().slideY(begin: 0.1),
                ),
              ),

            // État vide
            if (_selectedCategory == 'Quiz' && _apiQuizzes.isEmpty)
              SliverFillRemaining(
                child: Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.quiz_outlined, size: 64, color: Colors.grey.shade300),
                      const SizedBox(height: 16),
                      Text(L10n.tr('Aucun quiz'), style: GoogleFonts.outfit(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.grey.shade500)),
                      const SizedBox(height: 8),
                      Text(L10n.tr('Revenez plus tard pour de nouveaux défis'), style: GoogleFonts.inter(color: Colors.grey.shade400)),
                    ],
                  ),
                ),
              ),
          ],
          const SliverToBoxAdapter(child: SizedBox(height: 80)),
        ],
      ),
    );
  }

  // Widget de liste horizontale pour les catégories
  Widget _buildCategoryList() {
    return SizedBox(
      height: 40,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        itemCount: _categories.length,
        itemBuilder: (context, index) {
          final category = _categories[index];
          final isSelected = _selectedCategory == category;
          return GestureDetector(
            onTap: () => setState(() => _selectedCategory = category),
            child: AnimatedContainer(
              duration: 300.ms,
              curve: Curves.easeOutCubic,
              margin: const EdgeInsets.only(right: 12),
              padding: const EdgeInsets.symmetric(horizontal: 24),
              decoration: BoxDecoration(
                gradient: isSelected ? LinearGradient(colors: [Colors.teal.shade500, Colors.teal.shade700]) : LinearGradient(colors: [Theme.of(context).colorScheme.surface, Theme.of(context).colorScheme.surface]),
                borderRadius: BorderRadius.circular(20),
                boxShadow: isSelected ? [BoxShadow(color: Colors.teal.withOpacity(0.3), blurRadius: 10, offset: const Offset(0, 4))] : [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 4, offset: const Offset(0, 2))],
              ),
              child: Center(
                child: Text(
                  L10n.tr(category),
                  style: GoogleFonts.inter(
                    color: isSelected ? Colors.white : AppTheme.textMuted,
                    fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                    fontSize: 13,
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildApiQuizCard(dynamic quiz) {
    final title = quiz['title'] ?? 'Quiz';
    final totalQ = quiz['total_questions'] ?? 0;
    final desc = quiz['description'] ?? '';
    final id = quiz['id'] as int?;
    final isCompleted = id != null && _completedQuizIds.contains(id);

    return GestureDetector(
      onTap: () => _openQuiz(Map<String, dynamic>.from(quiz)),
      child: Container(
        margin: const EdgeInsets.only(bottom: 14),
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          gradient: isCompleted
              ? LinearGradient(colors: [Colors.green.shade500, Colors.teal.shade600])
              : LinearGradient(colors: [Colors.purple.shade400, Colors.deepPurple.shade600]),
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: (isCompleted ? Colors.green : Colors.purple).withOpacity(0.25),
              blurRadius: 16,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.15),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Icon(
                isCompleted ? Icons.check_circle_rounded : Icons.quiz_rounded,
                color: Colors.white,
                size: 28,
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title,
                    style: GoogleFonts.outfit(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 17,
                    )),
                  const SizedBox(height: 4),
                  Text(
                    isCompleted
                        ? (L10n.isArabic ? 'اكتمل الاختبار ✓ • تم تسجيل النتيجة' : 'Quiz complété ✓  •  Score enregistré')
                        : (desc.isNotEmpty ? desc : (L10n.isArabic ? '$totalQ أسئلة • مصحح بالذكاء الاصطناعي' : '$totalQ questions • Corrigé par IA')),
                    style: GoogleFonts.inter(
                      color: Colors.white.withOpacity(0.75),
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.2),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                isCompleted ? (L10n.isArabic ? 'مكتمل' : 'TERMINÉ') : (L10n.isArabic ? 'لعب' : 'JOUER'),
                style: GoogleFonts.outfit(
                  color: Colors.white,
                  fontWeight: FontWeight.w800,
                  fontSize: 12,
                ),
              ),
            ),
          ],
        ),
      ),
    ).animate().fadeIn().slideX(begin: 0.05);
  }

  Widget _buildCategoryFolderCard(dynamic cat) {
    final title = cat['title'] ?? '';
    final coverUrl = cat['cover_image_url'];
    final videoCount = cat['video_count'] ?? 0;
    final catId = cat['id'] as int?;

    return GestureDetector(
      onTap: () { if (catId != null) _openCategoryDetail(catId, title); },
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(20),
          boxShadow: AppTheme.tightShadow,
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(20),
          child: Stack(children: [
            // Cover image
            Positioned.fill(
              child: coverUrl != null
                  ? Image.network('${ApiConstants.baseUrl}$coverUrl', fit: BoxFit.cover,
                      errorBuilder: (_, __, ___) => Container(
                        decoration: BoxDecoration(gradient: LinearGradient(colors: [Colors.indigo.shade200, Colors.indigo.shade400])),
                        child: const Icon(Icons.folder, color: Colors.white, size: 48),
                      ))
                  : Container(
                      decoration: BoxDecoration(gradient: LinearGradient(colors: [Colors.indigo.shade200, Colors.indigo.shade400])),
                      child: const Icon(Icons.folder, color: Colors.white, size: 48),
                    ),
            ),
            // Dark overlay
            Positioned.fill(child: Container(
              decoration: BoxDecoration(gradient: LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter, colors: [Colors.transparent, Colors.black.withOpacity(0.7)])),
            )),
            // Title & count
            Positioned(
              bottom: 12, left: 14, right: 14,
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(title, style: GoogleFonts.outfit(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 15), maxLines: 2, overflow: TextOverflow.ellipsis),
                const SizedBox(height: 4),
                Row(children: [
                  const Icon(Icons.play_circle_fill, size: 14, color: Colors.white70),
                  const SizedBox(width: 4),
                  Text('$videoCount vidéo${videoCount > 1 ? 's' : ''}', style: GoogleFonts.inter(color: Colors.white70, fontSize: 11, fontWeight: FontWeight.w600)),
                ]),
              ]),
            ),
          ]),
        ),
      ),
    ).animate().fadeIn().scale(begin: const Offset(0.92, 0.92));
  }

  void _openCategoryDetail(int catId, String title) {
    // Garde d'authentification
    if (!AuthState.isLoggedIn) {
      AuthPromptDialog.show(context: context);
      return;
    }
    Navigator.push(context, MaterialPageRoute(
      builder: (_) => _CategoryDetailPage(catId: catId, title: title),
    ));
  }

  Widget _buildEducatorVideoCard(dynamic video) {
    final title = video['title'] ?? 'Vidéo';
    final educatorName = video['educator_name'] ?? 'Éducateur';
    final duration = video['duration'] ?? '';
    final createdAt = video['created_at'] ?? '';
    final videoUrl = video['video_url'] ?? '';
    final description = video['description'] ?? '';

    // Format date
    String dateLabel = '';
    if (createdAt.isNotEmpty) {
      try {
        final dt = DateTime.parse(createdAt).toLocal();
        dateLabel = '${dt.day.toString().padLeft(2, '0')}/${dt.month.toString().padLeft(2, '0')}/${dt.year} à ${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
      } catch (_) {
        dateLabel = createdAt;
      }
    }

    return GestureDetector(
      onTap: () {
        if (videoUrl.isNotEmpty) {
          _openVideoPlayer(videoUrl, title, educatorName, dateLabel);
        }
      },
      child: Container(
        margin: const EdgeInsets.only(bottom: 14),
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surface,
          borderRadius: BorderRadius.circular(20),
          boxShadow: AppTheme.tightShadow,
        ),
        child: Column(
          children: [
            // Play icon placeholder
            Container(
              height: 160, width: double.infinity,
              decoration: BoxDecoration(
                gradient: LinearGradient(colors: [Colors.teal.shade300, Colors.cyan.shade600]),
                borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
              ),
              child: Stack(children: [
                const Center(child: Icon(Icons.play_circle_fill_rounded, color: Colors.white, size: 60)),
                if (duration.isNotEmpty)
                  Positioned(
                    bottom: 10, right: 10,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(color: Colors.black87, borderRadius: BorderRadius.circular(6)),
                      child: Text(duration, style: GoogleFonts.inter(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w700)),
                    ),
                  ),
              ]),
            ),
            // Info section
            Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: GoogleFonts.outfit(fontWeight: FontWeight.bold, fontSize: 16, color: Theme.of(context).brightness == Brightness.dark ? Colors.white : AppTheme.deepSlate), maxLines: 2, overflow: TextOverflow.ellipsis),
                  if (description.isNotEmpty) ...[
                    const SizedBox(height: 6),
                    Text(description, style: GoogleFonts.inter(fontSize: 12, color: AppTheme.textMuted, height: 1.4), maxLines: 2, overflow: TextOverflow.ellipsis),
                  ],
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      CircleAvatar(
                        radius: 14,
                        backgroundColor: Colors.teal.withOpacity(0.1),
                        child: const Icon(Icons.person, size: 16, color: Colors.teal),
                      ),
                      const SizedBox(width: 8),
                      Expanded(child: Text(educatorName, style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w600, color: Theme.of(context).brightness == Brightness.dark ? Colors.white : AppTheme.deepSlate), overflow: TextOverflow.ellipsis)),
                      const Icon(Icons.access_time_rounded, size: 13, color: AppTheme.textMuted),
                      const SizedBox(width: 4),
                      Text(dateLabel, style: GoogleFonts.inter(fontSize: 11, color: AppTheme.textMuted)),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    ).animate().fadeIn().slideY(begin: 0.05);
  }

  /// Ouvre le lecteur vidéo intégré dans un bottom sheet
  void _openVideoPlayer(String videoUrl, String title, String educatorName, String dateLabel) {
    // Garde d'authentification
    if (!AuthState.isLoggedIn) {
      AuthPromptDialog.show(context: context);
      return;
    }
    // Build full URL from relative path
    String fullUrl = videoUrl;
    if (videoUrl.startsWith('/')) {
      fullUrl = '${ApiConstants.baseUrl}$videoUrl';
    }

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => _VideoPlayerSheet(
        videoUrl: fullUrl,
        title: title,
        educatorName: educatorName,
        dateLabel: dateLabel,
      ),
    );
  }
}

/// Bottom sheet avec lecteur vidéo Chewie intégré
class _VideoPlayerSheet extends StatefulWidget {
  final String videoUrl;
  final String title;
  final String educatorName;
  final String dateLabel;

  const _VideoPlayerSheet({
    required this.videoUrl,
    required this.title,
    required this.educatorName,
    required this.dateLabel,
  });

  @override
  State<_VideoPlayerSheet> createState() => _VideoPlayerSheetState();
}

class _VideoPlayerSheetState extends State<_VideoPlayerSheet> {
  late VideoPlayerController _videoController;
  ChewieController? _chewieController;
  bool _hasError = false;

  @override
  void initState() {
    super.initState();
    _initializePlayer();
  }

  Future<void> _initializePlayer() async {
    _videoController = VideoPlayerController.networkUrl(Uri.parse(widget.videoUrl));
    try {
      await _videoController.initialize();
      if (!mounted) return;
      _chewieController = ChewieController(
        videoPlayerController: _videoController,
        autoPlay: true,
        looping: false,
        aspectRatio: _videoController.value.aspectRatio,
        allowFullScreen: true,
        allowMuting: true,
        showControls: true,
        materialProgressColors: ChewieProgressColors(
          playedColor: AppTheme.primaryGreen,
          handleColor: AppTheme.primaryGreen,
          bufferedColor: Colors.teal.shade100,
          backgroundColor: Colors.grey.shade300,
        ),
      );
      setState(() {});
    } catch (e) {
      if (mounted) setState(() => _hasError = true);
    }
  }

  @override
  void dispose() {
    _chewieController?.dispose();
    _videoController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      height: MediaQuery.of(context).size.height * 0.75,
      decoration: const BoxDecoration(
        color: Colors.black,
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      child: Column(
        children: [
          // Handle bar
          Container(
            margin: const EdgeInsets.only(top: 12),
            width: 40, height: 4,
            decoration: BoxDecoration(color: Colors.grey.shade600, borderRadius: BorderRadius.circular(2)),
          ),
          // Header
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 16, 12, 8),
            child: Row(
              children: [
                Expanded(child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(widget.title, style: GoogleFonts.outfit(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 18), maxLines: 1, overflow: TextOverflow.ellipsis),
                    const SizedBox(height: 4),
                    Row(children: [
                      const Icon(Icons.person, size: 14, color: Colors.teal),
                      const SizedBox(width: 4),
                      Flexible(child: Text(widget.educatorName, style: GoogleFonts.inter(color: Colors.white70, fontSize: 12), overflow: TextOverflow.ellipsis)),
                      const SizedBox(width: 12),
                      const Icon(Icons.access_time_rounded, size: 12, color: Colors.white54),
                      const SizedBox(width: 4),
                      Text(widget.dateLabel, style: GoogleFonts.inter(color: Colors.white54, fontSize: 11)),
                    ]),
                  ],
                )),
                IconButton(
                  icon: const Icon(Icons.close, color: Colors.white70),
                  onPressed: () => Navigator.pop(context),
                ),
              ],
            ),
          ),
          // Video player
          Expanded(
            child: _hasError
                ? Center(child: Column(mainAxisSize: MainAxisSize.min, children: [
                    const Icon(Icons.error_outline, color: Colors.red, size: 48),
                    const SizedBox(height: 12),
                    Text('Impossible de lire la vidéo', style: GoogleFonts.inter(color: Colors.white70)),
                  ]))
                : _chewieController != null
                    ? Chewie(controller: _chewieController!)
                    : const Center(child: CircularProgressIndicator(color: AppTheme.primaryGreen)),
          ),
        ],
      ),
    );
  }
}

/// Page de détail d'une catégorie — affiche toutes les vidéos du dossier
class _CategoryDetailPage extends StatefulWidget {
  final int catId;
  final String title;
  const _CategoryDetailPage({required this.catId, required this.title});
  @override
  State<_CategoryDetailPage> createState() => _CategoryDetailPageState();
}

class _CategoryDetailPageState extends State<_CategoryDetailPage> {
  final AuthService _authService = AuthService();
  List<dynamic> _videos = [];
  bool _loading = true;
  String _description = '';
  String? _coverUrl;

  @override
  void initState() {
    super.initState();
    _loadCategory();
  }

  Future<void> _loadCategory() async {
    final data = await _authService.fetchCategoryDetail(widget.catId);
    if (data != null && mounted) {
      setState(() {
        _videos = data['videos'] ?? [];
        _description = data['description'] ?? '';
        _coverUrl = data['cover_image_url'];
        _loading = false;
      });
    } else if (mounted) {
      setState(() => _loading = false);
    }
  }

  void _playVideo(String videoUrl, String title, String educatorName, String dateLabel) {
    String fullUrl = videoUrl;
    if (videoUrl.startsWith('/')) fullUrl = '${ApiConstants.baseUrl}$videoUrl';
    showModalBottomSheet(
      context: context, isScrollControlled: true, backgroundColor: Colors.transparent,
      builder: (ctx) => _VideoPlayerSheet(videoUrl: fullUrl, title: title, educatorName: educatorName, dateLabel: dateLabel),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).brightness == Brightness.dark ? const Color(0xFF0F172A) : const Color(0xFFF5F7FA),
      body: CustomScrollView(slivers: [
        SliverAppBar(
          expandedHeight: 200,
          pinned: true,
          backgroundColor: Colors.indigo,
          flexibleSpace: FlexibleSpaceBar(
            title: Text(widget.title, style: GoogleFonts.outfit(fontWeight: FontWeight.bold, fontSize: 18)),
            background: Stack(children: [
              if (_coverUrl != null) Positioned.fill(child: Image.network('${ApiConstants.baseUrl}$_coverUrl', fit: BoxFit.cover, errorBuilder: (_, __, ___) => Container(color: Colors.indigo))),
              Positioned.fill(child: Container(decoration: BoxDecoration(gradient: LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter, colors: [Colors.transparent, Colors.black.withOpacity(0.6)])))),
            ]),
          ),
        ),
        if (_description.isNotEmpty)
          SliverToBoxAdapter(child: Padding(
            padding: const EdgeInsets.fromLTRB(24, 20, 24, 8),
            child: Text(_description, style: GoogleFonts.inter(fontSize: 13, color: AppTheme.textMuted, height: 1.5)),
          )),
        if (_loading)
          const SliverFillRemaining(child: AppLoadingView(message: "Chargement des vidéos..."))
        else if (_videos.isEmpty)
          SliverFillRemaining(child: AppEmptyView(
            title: L10n.tr('Aucune vidéo'),
            description: L10n.tr('Aucune vidéo disponible dans ce dossier pour le moment.'),
            icon: Icons.video_library_outlined,
          ))
        else
          SliverList(delegate: SliverChildBuilderDelegate(
            (ctx, i) {
              final v = _videos[i];
              final title = v['title'] ?? 'Vidéo';
              final educator = v['educator_name'] ?? '';
              final duration = v['duration'] ?? '';
              final videoUrl = v['video_url'] ?? '';
              final createdAt = v['created_at'] ?? '';
              String dateLabel = '';
              if (createdAt.isNotEmpty) {
                try {
                  final dt = DateTime.parse(createdAt).toLocal();
                  dateLabel = '${dt.day.toString().padLeft(2, '0')}/${dt.month.toString().padLeft(2, '0')}/${dt.year}';
                } catch (_) {}
              }
              return GestureDetector(
                onTap: () => _playVideo(videoUrl, title, educator, dateLabel),
                child: Container(
                  margin: const EdgeInsets.symmetric(horizontal: 24, vertical: 7),
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(color: Theme.of(context).colorScheme.surface, borderRadius: BorderRadius.circular(18), boxShadow: AppTheme.tightShadow),
                  child: Row(children: [
                    Container(
                      width: 52, height: 52,
                      decoration: BoxDecoration(gradient: LinearGradient(colors: [Colors.teal.shade300, Colors.cyan.shade600]), borderRadius: BorderRadius.circular(14)),
                      child: const Icon(Icons.play_arrow_rounded, color: Colors.white, size: 28),
                    ),
                    const SizedBox(width: 16),
                    Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Text(title, style: GoogleFonts.outfit(fontWeight: FontWeight.bold, fontSize: 14), maxLines: 1, overflow: TextOverflow.ellipsis),
                      const SizedBox(height: 4),
                      Row(children: [
                        if (educator.isNotEmpty) ...[
                          const Icon(Icons.person, size: 12, color: Colors.teal),
                          const SizedBox(width: 4),
                          Flexible(child: Text(educator, style: GoogleFonts.inter(fontSize: 11, color: AppTheme.textMuted), overflow: TextOverflow.ellipsis)),
                          const SizedBox(width: 8),
                        ],
                        if (dateLabel.isNotEmpty) Text(dateLabel, style: GoogleFonts.inter(fontSize: 11, color: AppTheme.textMuted)),
                      ]),
                    ])),
                    if (duration.isNotEmpty) Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(color: Theme.of(context).brightness == Brightness.dark ? const Color(0xFF1E293B) : Colors.grey.shade100, borderRadius: BorderRadius.circular(8)),
                      child: Text(duration, style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.w700, color: Theme.of(context).colorScheme.onSurface)),
                    ),
                  ]),
                ),
              );
            },
            childCount: _videos.length,
          )),
        const SliverToBoxAdapter(child: SizedBox(height: 40)),
      ]),
    );
  }
}
