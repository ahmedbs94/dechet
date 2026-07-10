import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:file_picker/file_picker.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../theme/app_theme.dart';
import '../../services/auth_service.dart';
import '../../services/l10n_service.dart';
import '../../services/meetings_service.dart';
import '../../services/messaging_service.dart';
import '../educator/create_meeting_screen.dart';
import '../educator/manage_groups_screen.dart';
import '../messaging/messaging_screen.dart';


class EducatorTab extends StatefulWidget {
  const EducatorTab({Key? key}) : super(key: key);

  @override
  State<EducatorTab> createState() => _EducatorTabState();
}

class _EducatorTabState extends State<EducatorTab> {
  final AuthService _authService = AuthService();
  List<dynamic> _quizzes = [];
  List<dynamic> _myVideos = [];
  List<dynamic> _categories = [];
  List<dynamic> _meetings = [];
  bool _isLoading = false;
  bool _isUploading = false;
  bool _isPublishingVideo = false;
  int _unreadMessages = 0;

  @override
  void initState() {
    super.initState();
    L10n.addListener(_onLocaleChange);
    _loadQuizzes();
    _loadMyVideos();
    _loadCategories();
    _loadMeetings();
    _loadUnreadMessages();
  }

  void _onLocaleChange() {
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    L10n.removeListener(_onLocaleChange);
    super.dispose();
  }

  String _t(String fr, String ar) => L10n.isArabic ? ar : fr;

  Future<void> _loadUnreadMessages() async {
    final count = await MessagingService.getUnreadCount();
    if (mounted) setState(() => _unreadMessages = count);
  }

  Future<void> _loadQuizzes() async {
    setState(() => _isLoading = true);
    final quizzes = await _authService.fetchMyQuizzes();
    if (mounted) setState(() { _quizzes = quizzes; _isLoading = false; });
  }

  Future<void> _loadMyVideos() async {
    final videos = await _authService.fetchMyEducatorVideos();
    if (mounted) setState(() => _myVideos = videos);
  }

  Future<void> _loadCategories() async {
    final cats = await _authService.fetchVideoCategories();
    if (mounted) setState(() => _categories = cats);
  }

  Future<void> _loadMeetings() async {
    final data = await MeetingsService.getMyMeetings();
    if (mounted) setState(() => _meetings = data);
  }

  Future<void> _createCategory() async {
    final titleCtrl = TextEditingController();
    final descCtrl = TextEditingController();
    dynamic coverFile;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(builder: (ctx, setDState) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        title: Text(_t('Nouveau Dossier','مجلد جديد'), style: GoogleFonts.outfit(fontWeight: FontWeight.bold)),
        content: SingleChildScrollView(child: Column(mainAxisSize: MainAxisSize.min, children: [
          // Cover image picker
          GestureDetector(
            onTap: () async {
              final res = await FilePicker.platform.pickFiles(type: FileType.image, withData: true);
              if (res != null && res.files.isNotEmpty) {
                setDState(() => coverFile = res.files.first);
              }
            },
            child: Container(
              height: 120, width: double.infinity,
              decoration: BoxDecoration(
                color: Theme.of(context).brightness == Brightness.dark ? const Color(0xFF1E293B) : Colors.grey.shade100, borderRadius: BorderRadius.circular(16),
                border: Border.all(color: Theme.of(context).brightness == Brightness.dark ? const Color(0xFF334155) : Colors.grey.shade300, style: BorderStyle.solid),
                image: coverFile != null && coverFile.bytes != null
                    ? DecorationImage(image: MemoryImage(coverFile.bytes!), fit: BoxFit.cover)
                    : null,
              ),
              child: coverFile == null
                  ? Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                      Icon(Icons.add_photo_alternate_rounded, size: 36, color: Colors.grey.shade400),
                      const SizedBox(height: 6),
                      Text(_t('Image de couverture','صورة الغلاف'), style: GoogleFonts.inter(color: Colors.grey.shade500, fontSize: 12)),
                    ])
                  : null,
            ),
          ),
          const SizedBox(height: 16),
          TextField(controller: titleCtrl, decoration: InputDecoration(labelText: _t('Titre du sujet','عنوان الموضوع'), prefixIcon: const Icon(Icons.folder_special), border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)))),
          const SizedBox(height: 14),
          TextField(controller: descCtrl, maxLines: 2, decoration: InputDecoration(labelText: _t('Description (optionnel)','وصف (اختياري)'), prefixIcon: const Icon(Icons.description), border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)))),
        ])),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: Text(_t('Annuler','إلغاء'))),
          ElevatedButton.icon(
            onPressed: () => Navigator.pop(ctx, true),
            icon: const Icon(Icons.create_new_folder, size: 18),
            label: Text(_t('Créer','إنشاء'), style: const TextStyle(color: Colors.white)),
            style: ElevatedButton.styleFrom(backgroundColor: AppTheme.primaryGreen, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
          ),
        ],
      )),
    );

    if (confirmed != true || titleCtrl.text.isEmpty) return;

    final wrapper = coverFile != null ? _VideoFileWrapper(coverFile.name ?? 'cover.jpg', coverFile.bytes!) : null;
    final res = await _authService.createVideoCategory(
      title: titleCtrl.text,
      description: descCtrl.text.isNotEmpty ? descCtrl.text : null,
      coverImage: wrapper,
    );
    if (res['success'] == true && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(_t('Dossier créé !','تم إنشاء المجلد بنجاح')), backgroundColor: AppTheme.primaryGreen, behavior: SnackBarBehavior.floating));
      _loadCategories();
    }
  }

  Future<void> _publishVideo() async {
    final result = await FilePicker.platform.pickFiles(type: FileType.custom, allowedExtensions: ['mp4', 'webm', 'mov', 'avi', 'mkv'], withData: true);
    if (result == null || result.files.isEmpty) return;
    final file = result.files.first;
    if (file.bytes == null) return;

    final titleCtrl = TextEditingController(text: file.name.replaceAll(RegExp(r'\.[^.]+$'), ''));
    final descCtrl = TextEditingController();
    final durationCtrl = TextEditingController();
    int? selectedCatId;

    if (!mounted) return;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(builder: (ctx, setDState) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        title: Text(_t('Publier une Vidéo','نشر فيديو'), style: GoogleFonts.outfit(fontWeight: FontWeight.bold)),
        content: SingleChildScrollView(child: Column(mainAxisSize: MainAxisSize.min, children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(color: Colors.teal.shade50, borderRadius: BorderRadius.circular(16)),
            child: Row(children: [
              Icon(Icons.video_file_rounded, color: Colors.teal.shade400, size: 32),
              const SizedBox(width: 12),
              Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(file.name, style: GoogleFonts.inter(fontWeight: FontWeight.w600, fontSize: 13), maxLines: 1, overflow: TextOverflow.ellipsis),
                Text('${(file.size / (1024 * 1024)).toStringAsFixed(1)} Mo', style: GoogleFonts.inter(color: AppTheme.textMuted, fontSize: 11)),
              ])),
            ]),
          ),
          const SizedBox(height: 16),
          DropdownButtonFormField<int?>(
            value: selectedCatId,
            decoration: InputDecoration(labelText: _t('Dossier (sujet)','المجلد (الموضوع)'), prefixIcon: const Icon(Icons.folder_special), border: OutlineInputBorder(borderRadius: BorderRadius.circular(14))),
            items: [
              DropdownMenuItem<int?>(value: null, child: Text(_t('— Aucun dossier —','— بدون مجلد —')),),
              ..._categories.map((c) => DropdownMenuItem<int?>(value: c['id'] as int, child: Text(c['title'] ?? ''))),
            ],
            onChanged: (v) => setDState(() => selectedCatId = v),
          ),
          const SizedBox(height: 14),
          TextField(controller: titleCtrl, decoration: InputDecoration(labelText: _t('Titre','عنوان'), prefixIcon: const Icon(Icons.title), border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)))),
          const SizedBox(height: 14),
          TextField(controller: descCtrl, maxLines: 3, decoration: InputDecoration(labelText: _t('Description (optionnel)','وصف (اختياري)'), prefixIcon: const Icon(Icons.description), border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)))),
          const SizedBox(height: 14),
          TextField(controller: durationCtrl, decoration: InputDecoration(labelText: _t('Durée (ex: 5:30)','المدة (مثال: 5:30)'), prefixIcon: const Icon(Icons.timer), border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)))),
        ])),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: Text(_t('Annuler','إلغاء'))),
          ElevatedButton.icon(
            onPressed: () => Navigator.pop(ctx, true),
            icon: const Icon(Icons.cloud_upload_rounded, size: 18),
            label: Text(_t('Publier','نشر'), style: const TextStyle(color: Colors.white)),
            style: ElevatedButton.styleFrom(backgroundColor: AppTheme.primaryGreen, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
          ),
        ],
      )),
    );

    if (confirmed != true || titleCtrl.text.isEmpty) return;
    setState(() => _isPublishingVideo = true);
    final res = await _authService.uploadEducatorVideo(
      videoFile: _VideoFileWrapper(file.name, file.bytes!),
      title: titleCtrl.text,
      description: descCtrl.text.isNotEmpty ? descCtrl.text : null,
      duration: durationCtrl.text.isNotEmpty ? durationCtrl.text : null,
      categoryId: selectedCatId,
    );
    setState(() => _isPublishingVideo = false);
    if (res['success'] == true && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(_t('Vidéo publiée !','تم نشر الفيديو بنجاح')), backgroundColor: AppTheme.primaryGreen, behavior: SnackBarBehavior.floating));
      _loadMyVideos();
      _loadCategories();
    } else if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(res['message'] ?? _t('Erreur','خطأ')), backgroundColor: Colors.red, behavior: SnackBarBehavior.floating));
    }
  }

  Future<void> _deleteVideo(int id) async {
    final ok = await showDialog<bool>(context: context, builder: (ctx) => AlertDialog(
      title: Text(_t('Supprimer cette vidéo ?','حذف هذا الفيديو ؟')),
      actions: [TextButton(onPressed: () => Navigator.pop(ctx, false), child: Text(_t('Annuler','إلغاء'))), TextButton(onPressed: () => Navigator.pop(ctx, true), child: Text(_t('Supprimer','حذف'), style: const TextStyle(color: Colors.red)))],
    ));
    if (ok != true) return;
    final deleted = await _authService.deleteEducatorVideo(id);
    if (deleted && mounted) { _loadMyVideos(); ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(_t('Vidéo supprimée','تم حذف الفيديو')))); }
  }

  Future<void> _uploadQuizPdf() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['pdf'],
      withData: true,
    );
    if (result == null || result.files.isEmpty) return;

    final file = result.files.first;
    if (file.bytes == null) return;

    // Demander le titre
    final titleController = TextEditingController(text: file.name.replaceAll('.pdf', ''));
    if (!mounted) return;
    final title = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        title: Text(_t('Nouveau Quiz','اختبار جديد'), style: GoogleFonts.outfit(fontWeight: FontWeight.bold)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.purple.shade50,
                borderRadius: BorderRadius.circular(16),
              ),
              child: Row(children: [
                Icon(Icons.picture_as_pdf, color: Colors.red.shade400, size: 32),
                const SizedBox(width: 12),
                Expanded(child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(file.name, style: GoogleFonts.inter(fontWeight: FontWeight.w600, fontSize: 13)),
                    Text('${(file.size / 1024).toStringAsFixed(1)} Ko', style: GoogleFonts.inter(color: AppTheme.textMuted, fontSize: 11)),
                  ],
                )),
              ]),
            ),
            const SizedBox(height: 20),
            TextField(
              controller: titleController,
              decoration: InputDecoration(
                labelText: _t('Titre du quiz','عنوان الاختبار'),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
                focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: const BorderSide(color: AppTheme.primaryGreen, width: 2)),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Annuler')),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, titleController.text),
            style: ElevatedButton.styleFrom(backgroundColor: AppTheme.primaryGreen, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
            child: Text(_t('Analyser avec l\'IA','تحليل بالذكاء الاصطناعي'), style: const TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
    if (title == null || title.isEmpty) return;

    setState(() => _isUploading = true);

    // Créer un wrapper pour les bytes du fichier
    final fakeFile = _PdfFileWrapper(file.name, file.bytes!);
    final res = await _authService.createQuizFromPdf(fakeFile, title: title);

    setState(() => _isUploading = false);

    if (res['success'] == true && mounted) {
      final quiz = res['quiz'];
      final totalQ = quiz?['total_questions'] ?? 0;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Row(children: [
          const Icon(Icons.check_circle, color: Colors.white, size: 20),
          const SizedBox(width: 10),
          Expanded(child: Text(_t('Quiz créé ! $totalQ questions extraites par Gemini.','تم إنشاء الاختبار! $totalQ سؤال استُخرج بواسطة Gemini.'), style: GoogleFonts.inter(fontWeight: FontWeight.w600))),
        ]),
        backgroundColor: AppTheme.primaryGreen,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      ));
      _loadQuizzes();
    } else if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(res['message'] ?? _t('Erreur lors de la création du quiz','خطأ أثناء إنشاء الاختبار')),
        backgroundColor: Colors.red,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ));
    }
  }

  void _viewQuizResults(Map<String, dynamic> quiz) async {
    final quizId = quiz['id'];
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => const Center(child: CircularProgressIndicator(color: AppTheme.primaryGreen)),
    );

    final results = await _authService.fetchQuizResults(quizId);
    if (mounted) Navigator.pop(context);

    if (!mounted) return;

    final stats = results['stats'] ?? {};
    final submissions = (results['submissions'] as List?) ?? [];
    final questions = (quiz['questions'] as List?) ?? [];

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        height: MediaQuery.of(context).size.height * 0.85,
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surface,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(32)),
        ),
        child: Column(
          children: [
            Container(width: 40, height: 4, margin: const EdgeInsets.symmetric(vertical: 12), decoration: BoxDecoration(color: Colors.grey.shade300, borderRadius: BorderRadius.circular(2))),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(child: Text(quiz['title'] ?? 'Quiz', style: GoogleFonts.outfit(fontSize: 22, fontWeight: FontWeight.bold), overflow: TextOverflow.ellipsis)),
                  IconButton(onPressed: () => Navigator.pop(context), icon: const Icon(Icons.close)),
                ],
              ),
            ),
            // Stats cards
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: Row(
                children: [
                  _buildMiniStat(_t('Soumissions','التقديمات'), '${stats['total_submissions'] ?? 0}', Icons.people_rounded, Colors.blue),
                  const SizedBox(width: 10),
                  _buildMiniStat(_t('Moyenne','المتوسط'), '${stats['average_score'] ?? 0}/10', Icons.analytics_rounded, Colors.orange),
                  const SizedBox(width: 10),
                  _buildMiniStat(_t('Meilleure','الأفضل'), '${stats['highest_score'] ?? 0}/10', Icons.emoji_events_rounded, Colors.amber),
                ],
              ),
            ),
            const SizedBox(height: 16),
            // Questions preview
            if (questions.isNotEmpty) ...[
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                child: Align(alignment: Alignment.centerLeft, child: Text('${questions.length} ${_t('Questions extraites par l\'IA','سؤال استخرجته الذكاء الاصطناعي')}', style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w700, color: AppTheme.primaryGreen))),
              ),
              const SizedBox(height: 8),
            ],
            // Submissions list
            Expanded(
              child: submissions.isEmpty
                  ? Center(child: Column(mainAxisSize: MainAxisSize.min, children: [
                      Icon(Icons.inbox_rounded, size: 48, color: Colors.grey.shade300),
                      const SizedBox(height: 12),
                      Text(_t('Aucune soumission','لا توجد تقديمات'), style: GoogleFonts.inter(color: AppTheme.textMuted)),
                    ]))
                  : ListView.builder(
                      padding: const EdgeInsets.symmetric(horizontal: 24),
                      itemCount: submissions.length,
                      itemBuilder: (_, i) {
                        final sub = submissions[i];
                        final score = (sub['score'] as num?)?.toDouble() ?? 0;
                        final color = score >= 7 ? Colors.green : score >= 5 ? Colors.orange : Colors.red;
                        return Container(
                          margin: const EdgeInsets.only(bottom: 12),
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: Colors.grey.shade50,
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(color: color.withOpacity(0.2)),
                          ),
                          child: Row(children: [
                            CircleAvatar(
                              radius: 20,
                              backgroundColor: color.withOpacity(0.1),
                              child: Text(score.toStringAsFixed(1), style: GoogleFonts.outfit(color: color, fontWeight: FontWeight.bold, fontSize: 14)),
                            ),
                            const SizedBox(width: 14),
                            Expanded(child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(sub['student_name'] ?? _t('Étudiant','طالب'), style: GoogleFonts.inter(fontWeight: FontWeight.w600, fontSize: 14)),
                                Text(sub['submitted_at'] ?? '', style: GoogleFonts.inter(fontSize: 11, color: AppTheme.textMuted)),
                              ],
                            )),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                              decoration: BoxDecoration(color: color.withOpacity(0.1), borderRadius: BorderRadius.circular(20)),
                              child: Text('${score.toStringAsFixed(1)}/10', style: GoogleFonts.outfit(color: color, fontWeight: FontWeight.bold, fontSize: 13)),
                            ),
                          ]),
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMiniStat(String label, String value, IconData icon, Color color) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 10),
        decoration: BoxDecoration(
          color: color.withOpacity(0.06),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: color.withOpacity(0.12)),
        ),
        child: Column(children: [
          Icon(icon, color: color, size: 20),
          const SizedBox(height: 6),
          Text(value, style: GoogleFonts.outfit(fontSize: 16, fontWeight: FontWeight.bold, color: Theme.of(context).colorScheme.onSurface)),
          Text(label, style: GoogleFonts.inter(fontSize: 9, color: AppTheme.textMuted, fontWeight: FontWeight.w600)),
        ]),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      body: SingleChildScrollView(
        key: const PageStorageKey('educator_tab'),
        primary: false,
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
        physics: const BouncingScrollPhysics(),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildHeader(),
            const SizedBox(height: 32),
            _buildQuickStats(context),
            const SizedBox(height: 48),

            _buildSectionHeader(L10n.isArabic ? 'اختبار تلقائي (ذكاء Gemini)' : 'QUIZ AUTOMATIQUE (IA GEMINI)', Icons.auto_awesome_rounded),
            const SizedBox(height: 20),
            _buildUploadCard(),
            const SizedBox(height: 20),

            // Liste des quiz créés
            if (_isLoading)
              const Center(child: Padding(padding: EdgeInsets.all(32), child: CircularProgressIndicator(color: AppTheme.primaryGreen)))
            else if (_quizzes.isNotEmpty) ...[
              Text(L10n.isArabic ? 'اختباراتي (${_quizzes.length})' : 'Mes Quiz (${_quizzes.length})', style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w800, color: AppTheme.textMuted, letterSpacing: 1)),
              const SizedBox(height: 12),
              ..._quizzes.map((q) => _buildQuizCard(q)).toList(),
            ],

            const SizedBox(height: 40),
            _buildSectionHeader(L10n.isArabic ? 'فيديوهات تعليمية' : 'VIDÉOS ÉDUCATIVES', Icons.video_library_rounded),
            const SizedBox(height: 20),
            // Create folder + Upload video buttons
            Row(children: [
              Expanded(child: _buildActionCard(_t('Nouveau Dossier','مجلد جديد'), Icons.create_new_folder_rounded, Colors.indigo, _createCategory)),
              const SizedBox(width: 14),
              Expanded(child: _buildActionCard(_t('Publier Vidéo','نشر فيديو'), Icons.video_call_rounded, Colors.teal, _isPublishingVideo ? null : _publishVideo)),
            ]),
            const SizedBox(height: 20),
            // Category folders
            if (_categories.isNotEmpty) ...[
              Text(L10n.isArabic ? 'المجلدات (${_categories.length})' : 'DOSSIERS (${_categories.length})', style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w800, color: AppTheme.textMuted, letterSpacing: 1)),
              const SizedBox(height: 12),
              ..._categories.map((c) => _buildCategoryCard(c)).toList(),
              const SizedBox(height: 20),
            ],
            // Videos without category
            if (_myVideos.isNotEmpty) ...[
              Text(L10n.isArabic ? 'فيديوهاتي (${_myVideos.length})' : 'MES VIDÉOS (${_myVideos.length})', style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w800, color: AppTheme.textMuted, letterSpacing: 1)),
              const SizedBox(height: 12),
              ..._myVideos.map((v) => _buildMyVideoCard(v)).toList(),
            ] else if (_categories.isEmpty)
              Center(child: Padding(padding: const EdgeInsets.all(24), child: Text(_t('Aucune vidéo publiée.','لا توجد فيديوهات منشورة.'), style: GoogleFonts.inter(color: AppTheme.textMuted)))),

            const SizedBox(height: 40),
            _buildSectionHeader(L10n.isArabic ? 'مجموعات المواطنين' : 'GROUPES DE CITOYENS', Icons.group_rounded),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: () async {
                  await Navigator.push(context, MaterialPageRoute(
                    builder: (_) => const ManageGroupsScreen(),
                  ));
                  _loadMeetings(); // refresh après retour
                },
                icon: const Icon(Icons.group_add_rounded),
                label: Text(_t('Gérer mes groupes de citoyens','إدارة مجموعات المواطنين'),
                  style: GoogleFonts.outfit(fontWeight: FontWeight.bold)),
                style: OutlinedButton.styleFrom(
                  foregroundColor: const Color(0xFF6C5CE7),
                  side: const BorderSide(color: Color(0xFF6C5CE7), width: 1.5),
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
              ),
            ),

            const SizedBox(height: 40),
            _buildSectionHeader(L10n.isArabic ? 'جلسات Google Meet' : 'SÉANCES GOOGLE MEET', Icons.video_camera_front_rounded),
            const SizedBox(height: 16),
            _buildAwarenessSessions(context),
            const SizedBox(height: 100),
          ],
        ),
      ),
      floatingActionButton: Padding(
        padding: const EdgeInsets.only(bottom: 76),
        child: FloatingActionButton.extended(
          heroTag: 'fab_educator_new_quiz',
          onPressed: _isUploading ? null : _uploadQuizPdf,
          backgroundColor: _isUploading ? Colors.grey : AppTheme.primaryGreen,
          icon: _isUploading
              ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
              : const Icon(Icons.upload_file_rounded),
          label: Text(L10n.isArabic ? (_isUploading ? 'جار التحليل...' : 'رفع اختبار PDF') : (_isUploading ? 'ANALYSE IA...' : 'UPLOADER UN QUIZ PDF')),
        ),
      ),

    );
  }

  Widget _buildHeader() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Expanded(
              child: Text(
                _t('Espace Éducateur', 'فضاء المعلم'),
                style: GoogleFonts.outfit(
                  fontSize: 32,
                  fontWeight: FontWeight.bold,
                  color: Theme.of(context).colorScheme.onSurface,
                ),
                overflow: TextOverflow.ellipsis,
              ),
            ),
            Row(
              children: [
                // Messages Button
                Stack(
                  clipBehavior: Clip.none,
                  children: [
                    IconButton(
                      onPressed: () => Navigator.push(
                        context,
                        MaterialPageRoute(builder: (_) => const MessagingScreen()),
                      ),
                      icon: Icon(
                        Icons.forum_rounded,
                        color: Theme.of(context).colorScheme.onSurface.withOpacity(0.8),
                        size: 26,
                      ),
                    ),
                    if (_unreadMessages > 0)
                      Positioned(
                        top: 2,
                        right: 2,
                        child: Container(
                          padding: const EdgeInsets.all(4),
                          decoration: const BoxDecoration(
                            color: Colors.red,
                            shape: BoxShape.circle,
                          ),
                          constraints: const BoxConstraints(
                            minWidth: 16,
                            minHeight: 16,
                          ),
                          child: Text(
                            '$_unreadMessages',
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 9,
                              fontWeight: FontWeight.bold,
                            ),
                            textAlign: TextAlign.center,
                          ),
                        ),
                      ),
                  ],
                ),
                const SizedBox(width: 8),
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: AppTheme.primaryGreen.withOpacity(0.1),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.verified_user_rounded, color: AppTheme.primaryGreen),
                ),
              ],
            ),
          ],
        ),
        const SizedBox(height: 8),
        Text(
          _t('Gérez vos quiz et contenus pédagogiques.', 'أدر اختباراتك ومحتوياتك التعليمية.'),
          style: GoogleFonts.inter(color: AppTheme.textMuted, fontSize: 16),
        ),
      ],
    ).animate().fadeIn().slideX();
  }

  Widget _buildQuickStats(BuildContext context) {
    return Row(
      children: [
        _buildStatCard(context, _t('Quiz Créés','اختبارات منشأة'), '${_quizzes.length}', Icons.quiz_rounded, Colors.purple),
        const SizedBox(width: 12),
        _buildStatCard(context, _t('Soumissions','التقديمات'), '${_quizzes.fold<int>(0, (sum, q) => sum + ((q['submissions_count'] as num?) ?? 0).toInt())}', Icons.assignment_turned_in_rounded, Colors.orange),
        const SizedBox(width: 12),
        _buildStatCard(context, _t('Corrigés IA','صحح بالذكاء'), '${_quizzes.fold<int>(0, (sum, q) => sum + ((q['submissions_count'] as num?) ?? 0).toInt())}', Icons.auto_awesome, Colors.amber),
      ],
    );
  }

  Widget _buildStatCard(BuildContext context, String label, String value, IconData icon, Color color) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 12),
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surface,
          borderRadius: BorderRadius.circular(16),
          boxShadow: AppTheme.tightShadow,
          border: Border.all(color: color.withOpacity(0.1)),
        ),
        child: Column(
          children: [
            Icon(icon, color: color, size: 24),
            const SizedBox(height: 8),
            Text(value, style: GoogleFonts.outfit(fontSize: 20, fontWeight: FontWeight.bold, color: Theme.of(context).colorScheme.onSurface)),
            Text(label, style: const TextStyle(fontSize: 10, color: AppTheme.textMuted, fontWeight: FontWeight.w600), textAlign: TextAlign.center),
          ],
        ),
      ),
    ).animate().scale(delay: 200.ms);
  }

  Widget _buildSectionHeader(String title, IconData icon) {
    return Row(
      children: [
        Icon(icon, size: 18, color: AppTheme.primaryGreen),
        const SizedBox(width: 10),
        Text(title, style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w900, letterSpacing: 1.5, color: AppTheme.textMuted)),
      ],
    );
  }

  Widget _buildUploadCard() {
    return GestureDetector(
      onTap: _isUploading ? null : _uploadQuizPdf,
      child: Container(
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          gradient: LinearGradient(colors: [Colors.purple.shade400, Colors.deepPurple.shade600]),
          borderRadius: BorderRadius.circular(24),
          boxShadow: [BoxShadow(color: Colors.purple.withOpacity(0.3), blurRadius: 20, offset: const Offset(0, 10))],
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(color: Colors.white.withOpacity(0.15), borderRadius: BorderRadius.circular(18)),
              child: const Icon(Icons.auto_awesome_rounded, color: Colors.white, size: 32),
            ),
            const SizedBox(width: 20),
            Expanded(child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(_t('Quiz Automatique','اختبار تلقائي'), style: GoogleFonts.outfit(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 20)),
                const SizedBox(height: 4),
                Text(
                  _t('Uploadez un PDF → Gemini extrait les questions, corrige et note automatiquement sur 10.','ارفع ملف PDF → Gemini يستخرج الأسئلة ويصححها تلقائياً.'),
                  style: GoogleFonts.inter(color: Colors.white.withOpacity(0.8), fontSize: 12, height: 1.4),
                ),
              ],
            )),
            Icon(Icons.arrow_forward_ios_rounded, color: Colors.white.withOpacity(0.6), size: 16),
          ],
        ),
      ),
    ).animate().fadeIn().slideY(begin: 0.1);
  }

  Widget _buildQuizCard(dynamic quiz) {
    final status = quiz['status'] ?? 'processing';
    final total = quiz['total_questions'] ?? 0;
    final subs = quiz['submissions_count'] ?? 0;
    final isReady = status == 'ready';
    final isError = status == 'error';
    final errorMsg = quiz['error_message'] ?? '';

    Color statusColor = isReady ? AppTheme.primaryGreen : isError ? Colors.red : Colors.orange;
    String statusLabel = isReady ? _t('PRÊT','جاهز') : isError ? _t('ERREUR','خطأ') : _t('EN COURS','جاري');

    return GestureDetector(
      onTap: isReady ? () => _viewQuizResults(Map<String, dynamic>.from(quiz)) : null,
      child: Container(
        margin: const EdgeInsets.only(bottom: 14),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surface,
          borderRadius: BorderRadius.circular(20),
          boxShadow: AppTheme.tightShadow,
          border: Border(left: BorderSide(color: statusColor, width: 4)),
        ),
        child: Column(
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: statusColor.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Icon(
                    isReady ? Icons.quiz_rounded : isError ? Icons.error_outline_rounded : Icons.hourglass_top_rounded,
                    color: statusColor,
                    size: 24,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(quiz['title'] ?? 'Quiz', style: GoogleFonts.outfit(fontWeight: FontWeight.bold, fontSize: 15)),
                    const SizedBox(height: 4),
                    Row(children: [
                      const Icon(Icons.help_outline, size: 13, color: AppTheme.textMuted),
                      const SizedBox(width: 4),
                       Flexible(child: Text('$total ${_t('questions','سؤال')}', style: GoogleFonts.inter(fontSize: 12, color: AppTheme.textMuted), overflow: TextOverflow.ellipsis)),
                      const SizedBox(width: 10),
                      const Icon(Icons.people_outline, size: 13, color: AppTheme.textMuted),
                      const SizedBox(width: 4),
                      Flexible(child: Text('$subs ${_t('soumissions','تقديم')}', style: GoogleFonts.inter(fontSize: 12, color: AppTheme.textMuted), overflow: TextOverflow.ellipsis)),
                    ]),
                  ],
                )),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                  decoration: BoxDecoration(
                    color: statusColor.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Text(
                    statusLabel,
                    style: GoogleFonts.outfit(fontSize: 10, fontWeight: FontWeight.w800, color: statusColor),
                  ),
                ),
              ],
            ),
            // Bouton Réessayer + Supprimer pour les quiz en erreur
            if (isError) ...[
              const SizedBox(height: 12),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: Colors.red.shade50,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Column(
                  children: [
                    if (errorMsg.isNotEmpty)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 8),
                        child: Text(
                          errorMsg.length > 100 ? '${errorMsg.substring(0, 100)}...' : errorMsg,
                          style: GoogleFonts.inter(fontSize: 11, color: Colors.red.shade700),
                          maxLines: 2, overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    Row(
                      children: [
                        Expanded(
                          child: ElevatedButton.icon(
                            onPressed: () => _retryQuiz(quiz['id']),
                            icon: const Icon(Icons.refresh_rounded, size: 16),
                            label: Text(_t('RÉESSAYER','إعادة المحاولة'), style: GoogleFonts.outfit(fontWeight: FontWeight.w700, fontSize: 11)),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.orange,
                              foregroundColor: Colors.white,
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                              padding: const EdgeInsets.symmetric(vertical: 10),
                            ),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: ElevatedButton.icon(
                            onPressed: () => _deleteQuiz(quiz['id']),
                            icon: const Icon(Icons.delete_outline_rounded, size: 16),
                            label: Text(_t('SUPPRIMER','حذف'), style: GoogleFonts.outfit(fontWeight: FontWeight.w700, fontSize: 11)),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.red.shade600,
                              foregroundColor: Colors.white,
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                              padding: const EdgeInsets.symmetric(vertical: 10),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    ).animate().fadeIn().slideX(begin: 0.05);
  }

  Future<void> _deleteQuiz(int quizId) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text(_t('Supprimer ce quiz ?','حذف هذا الاختبار ؟'), style: GoogleFonts.outfit(fontWeight: FontWeight.bold)),
        content: Text(_t('Cette action est irréversible. Le fichier PDF et toutes les données seront supprimés.','هذا الإجراء لا رجعة منه.'), style: GoogleFonts.inter(color: AppTheme.textMuted)),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: Text(_t('Annuler','إلغاء'))),
          ElevatedButton.icon(
            onPressed: () => Navigator.pop(ctx, true),
            icon: const Icon(Icons.delete_forever_rounded, size: 18),
            label: Text(_t('Supprimer','حذف'), style: const TextStyle(color: Colors.white)),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
          ),
        ],
      ),
    );
    if (confirmed != true) return;

    final res = await _authService.deleteQuiz(quizId);
    if (res['success'] == true && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(_t('Quiz supprimé','تم حذف الاختبار')),
        backgroundColor: Colors.red.shade600,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ));
      _loadQuizzes();
    } else if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(res['message'] ?? _t('Erreur lors de la suppression','خطأ أثناء الحذف')),
        backgroundColor: Colors.red,
        behavior: SnackBarBehavior.floating,
      ));
    }
  }

  Future<void> _retryQuiz(int quizId) async {
    setState(() => _isUploading = true);
    final res = await _authService.retryQuiz(quizId);
    setState(() => _isUploading = false);

    if (res['success'] == true && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Row(children: [
          const Icon(Icons.check_circle, color: Colors.white, size: 20),
          const SizedBox(width: 10),
          Expanded(child: Text(res['message'] ?? _t('Quiz re-traité avec succès !','تمت إعادة معالجة الاختبار بنجاح!'), style: GoogleFonts.inter(fontWeight: FontWeight.w600))),
        ]),
        backgroundColor: AppTheme.primaryGreen,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      ));
      _loadQuizzes();
    } else if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(res['message'] ?? _t('Erreur lors du retry','خطأ أثناء الإعادة')),
        backgroundColor: Colors.red,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ));
    }
  }


  Widget _buildActionCard(String label, IconData icon, Color color, VoidCallback? onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 16),
        decoration: BoxDecoration(
          gradient: LinearGradient(colors: [color.withOpacity(0.8), color]),
          borderRadius: BorderRadius.circular(20),
          boxShadow: [BoxShadow(color: color.withOpacity(0.25), blurRadius: 14, offset: const Offset(0, 6))],
        ),
        child: Column(children: [
          Icon(icon, color: Colors.white, size: 32),
          const SizedBox(height: 8),
          Text(label, style: GoogleFonts.outfit(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14), textAlign: TextAlign.center),
        ]),
      ),
    ).animate().fadeIn().scale(begin: const Offset(0.9, 0.9));
  }

  Widget _buildCategoryCard(dynamic cat) {
    final title = cat['title'] ?? 'Dossier';
    final desc = cat['description'] ?? '';
    final videoCount = cat['video_count'] ?? 0;
    final coverUrl = cat['cover_image_url'];
    final catId = cat['id'] as int?;

    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      decoration: BoxDecoration(color: Theme.of(context).colorScheme.surface, borderRadius: BorderRadius.circular(20), boxShadow: AppTheme.tightShadow),
      child: Row(children: [
        ClipRRect(
          borderRadius: const BorderRadius.only(topLeft: Radius.circular(20), bottomLeft: Radius.circular(20)),
          child: SizedBox(width: 90, height: 80,
            child: coverUrl != null
                ? Image.network('${AuthService.baseUrl}$coverUrl', fit: BoxFit.cover, errorBuilder: (_, __, ___) => Container(color: Colors.indigo.shade50, child: const Icon(Icons.folder, color: Colors.indigo, size: 32)))
                : Container(color: Colors.indigo.shade50, child: const Icon(Icons.folder_special, color: Colors.indigo, size: 32)),
          ),
        ),
        const SizedBox(width: 14),
        Expanded(child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 12),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(title, style: GoogleFonts.outfit(fontWeight: FontWeight.bold, fontSize: 15), maxLines: 1, overflow: TextOverflow.ellipsis),
            if (desc.isNotEmpty) Text(desc, style: GoogleFonts.inter(fontSize: 11, color: AppTheme.textMuted), maxLines: 1, overflow: TextOverflow.ellipsis),
            const SizedBox(height: 4),
            Row(children: [
              Icon(Icons.video_library_rounded, size: 13, color: Colors.indigo.shade300),
              const SizedBox(width: 4),
              Text('$videoCount ${_t('vidéo(s)','فيديو')}', style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.w600, color: Colors.indigo)),
            ]),
          ]),
        )),
        if (catId != null) IconButton(
          icon: Icon(Icons.delete_outline_rounded, color: Colors.red.shade300, size: 20),
          onPressed: () async {
            final ok = await showDialog<bool>(context: context, builder: (ctx) => AlertDialog(
              title: Text(_t('Supprimer ce dossier ?','حذف هذا المجلد؟')), content: Text(_t('Les vidéos ne seront pas supprimées.','لن يتم حذف الفيديوهات.')),
              actions: [TextButton(onPressed: () => Navigator.pop(ctx, false), child: Text(_t('Annuler','إلغاء'))), TextButton(onPressed: () => Navigator.pop(ctx, true), child: Text(_t('Supprimer','حذف'), style: const TextStyle(color: Colors.red)))],
            ));
            if (ok == true) { await _authService.deleteVideoCategory(catId); _loadCategories(); _loadMyVideos(); }
          },
        ),
      ]),
    ).animate().fadeIn().slideX(begin: 0.05);
  }

  Widget _buildMyVideoCard(dynamic video) {
    final title = video['title'] ?? 'Vidéo';
    final duration = video['duration'] ?? '';
    final createdAt = video['created_at'] ?? '';
    final thumbnail = video['thumbnail_url'];
    final videoId = video['id'] as int?;

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

    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(20),
        boxShadow: AppTheme.tightShadow,
        border: const Border(left: BorderSide(color: Colors.teal, width: 4)),
      ),
      child: Row(
        children: [
          // Thumbnail
          ClipRRect(
            borderRadius: const BorderRadius.only(topLeft: Radius.circular(20), bottomLeft: Radius.circular(20)),
            child: SizedBox(
              width: 100, height: 80,
              child: thumbnail != null
                  ? Image.network(thumbnail, fit: BoxFit.cover, errorBuilder: (_, __, ___) => Container(color: Colors.grey.shade200, child: const Icon(Icons.play_circle_fill, color: Colors.teal, size: 36)))
                  : Container(color: Colors.teal.shade50, child: const Icon(Icons.play_circle_fill, color: Colors.teal, size: 36)),
            ),
          ),
          const SizedBox(width: 14),
          // Info
          Expanded(child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: GoogleFonts.outfit(fontWeight: FontWeight.bold, fontSize: 14), maxLines: 1, overflow: TextOverflow.ellipsis),
                const SizedBox(height: 4),
                Row(children: [
                  if (duration.isNotEmpty) ...[
                    const Icon(Icons.timer_outlined, size: 12, color: AppTheme.textMuted),
                    const SizedBox(width: 3),
                    Text(duration, style: GoogleFonts.inter(fontSize: 11, color: AppTheme.textMuted)),
                    const SizedBox(width: 10),
                  ],
                  const Icon(Icons.calendar_today_outlined, size: 12, color: AppTheme.textMuted),
                  const SizedBox(width: 3),
                  Flexible(child: Text(dateLabel, style: GoogleFonts.inter(fontSize: 11, color: AppTheme.textMuted), overflow: TextOverflow.ellipsis)),
                ]),
              ],
            ),
          )),
          // Delete button
          if (videoId != null)
            IconButton(
              icon: Icon(Icons.delete_outline_rounded, color: Colors.red.shade300, size: 20),
              onPressed: () => _deleteVideo(videoId),
              tooltip: _t('Supprimer','حذف'),
            ),
          const SizedBox(width: 4),
        ],
      ),
    ).animate().fadeIn().slideX(begin: 0.05);
  }


  Widget _buildAwarenessSessions(BuildContext context) {
    const kGreen = Color(0xFF00C896);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // ── Bouton créer séance ──────────────────────────────────────────
        SizedBox(
          width: double.infinity,
          child: ElevatedButton.icon(
            onPressed: () async {
              final ok = await Navigator.push<bool>(context, MaterialPageRoute(
                builder: (_) => const CreateMeetingScreen(),
              ));
              if (ok == true) _loadMeetings();
            },
            icon: const Icon(Icons.add_rounded),
            label: Text(_t('Planifier une séance Google Meet','جدولة جلسة Google Meet'),
              style: GoogleFonts.outfit(fontWeight: FontWeight.bold)),
            style: ElevatedButton.styleFrom(
              backgroundColor: kGreen,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 14),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
          ),
        ),
        const SizedBox(height: 20),

        // ── Liste des séances ────────────────────────────────────────────
        if (_meetings.isEmpty)
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: Colors.grey.shade50,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: Colors.grey.shade200),
            ),
            child: Center(child: Column(mainAxisSize: MainAxisSize.min, children: [
              Icon(Icons.event_note_rounded, size: 40, color: Colors.grey.shade400),
              const SizedBox(height: 10),
              Text(_t('Aucune séance planifiée','لا توجد جلسات مجدولة'), style: GoogleFonts.outfit(
                  color: AppTheme.textMuted, fontWeight: FontWeight.w600)),
              const SizedBox(height: 4),
              Text(_t('Créez votre première séance Google Meet\npour vos citoyens.','أنشئ أول جلسة Google Meet\nلمواطنيك.'),
                textAlign: TextAlign.center,
                style: GoogleFonts.inter(color: AppTheme.textMuted, fontSize: 12, height: 1.5)),
            ])),
          )
        else
          ..._meetings.map((m) {
            final scheduledAt = DateTime.tryParse(m['scheduled_at'] ?? '') ?? DateTime.now();
            final isPast = scheduledAt.isBefore(DateTime.now());
            return Container(
              margin: const EdgeInsets.only(bottom: 12),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.surface,
                borderRadius: BorderRadius.circular(14),
                boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 8)],
                border: Border.all(
                  color: isPast ? Theme.of(context).dividerColor : kGreen.withOpacity(0.3),
                ),
              ),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                // Header
                Container(
                  padding: const EdgeInsets.fromLTRB(16, 12, 12, 10),
                  decoration: BoxDecoration(
                    color: isPast ? Colors.grey.shade50 : kGreen.withOpacity(0.05),
                    borderRadius: const BorderRadius.vertical(top: Radius.circular(14)),
                  ),
                  child: Row(children: [
                    Icon(Icons.video_camera_front_rounded,
                      color: isPast ? Colors.grey : kGreen, size: 20),
                    const SizedBox(width: 10),
                    Expanded(child: Text(m['title'] ?? '',
                      style: GoogleFonts.outfit(fontWeight: FontWeight.bold, fontSize: 15,
                        color: Theme.of(context).colorScheme.onSurface))),
                    // Status badge
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: isPast ? (Theme.of(context).brightness == Brightness.dark ? const Color(0xFF1E293B) : Colors.grey.shade100) : kGreen.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(isPast ? _t('Terminée','انتهت') : _t('Planifiée','مجدولة'),
                        style: GoogleFonts.inter(
                          color: isPast ? Colors.grey : kGreen,
                          fontSize: 11, fontWeight: FontWeight.w700)),
                    ),
                  ]),
                ),
                // Body
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Row(children: [
                      const Icon(Icons.calendar_today_rounded, size: 14, color: AppTheme.textMuted),
                      const SizedBox(width: 6),
                      Text(
                        DateFormat('dd/MM/yyyy à HH:mm').format(scheduledAt),
                        style: GoogleFonts.inter(color: AppTheme.textMuted, fontSize: 13)),
                      const SizedBox(width: 16),
                      const Icon(Icons.timer_rounded, size: 14, color: AppTheme.textMuted),
                      const SizedBox(width: 4),
                      Text('${m['duration_minutes']} ${_t('min','دقيقة')}',
                        style: GoogleFonts.inter(color: AppTheme.textMuted, fontSize: 13)),
                    ]),
                    if ((m['group_name'] as String? ?? '').isNotEmpty) ...[
                      const SizedBox(height: 6),
                      Row(children: [
                        const Icon(Icons.group_rounded, size: 14, color: AppTheme.textMuted),
                        const SizedBox(width: 6),
                        Text(m['group_name'], style: GoogleFonts.inter(
                            color: AppTheme.textMuted, fontSize: 13)),
                      ]),
                    ],
                    const SizedBox(height: 6),
                    Row(children: [
                      const Icon(Icons.people_rounded, size: 14, color: AppTheme.textMuted),
                      const SizedBox(width: 6),
                       Text('${m['participants_count']} ${_t('participant(s)','مشارك')}',
                        style: GoogleFonts.inter(color: AppTheme.textMuted, fontSize: 13)),
                    ]),
                    const SizedBox(height: 12),
                    Row(children: [
                      // Rejoindre
                      Expanded(child: OutlinedButton.icon(
                        onPressed: () async {
                          final uri = Uri.parse(m['meet_link'] ?? '');
                          if (await canLaunchUrl(uri)) launchUrl(uri, mode: LaunchMode.externalApplication);
                        },
                        icon: const Icon(Icons.open_in_new_rounded, size: 16),
                        label: Text(_t('Ouvrir Meet','فتح Meet'), style: GoogleFonts.outfit()),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: kGreen,
                          side: BorderSide(color: kGreen.withOpacity(0.5)),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                        ),
                      )),
                      const SizedBox(width: 8),
                      // Modifier
                      IconButton(
                        onPressed: () async {
                          final ok = await Navigator.push<bool>(context, MaterialPageRoute(
                            builder: (_) => CreateMeetingScreen(existingMeeting: m),
                          ));
                          if (ok == true) _loadMeetings();
                        },
                        icon: const Icon(Icons.edit_rounded, size: 20),
                        color: Colors.blue,
                        tooltip: 'Modifier',
                      ),
                      // Supprimer
                      IconButton(
                        onPressed: () async {
                          final confirm = await showDialog<bool>(context: context, builder: (_) =>
                            AlertDialog(
                              title: Text(_t('Supprimer la séance ?','حذف الجلسة ؟'), style: GoogleFonts.outfit()),
                              content: Text(_t('Cette action est irréversible.','هذا الإجراء لا رجعة منه.'), style: GoogleFonts.inter()),
                              actions: [
                                TextButton(onPressed: () => Navigator.pop(context, false),
                                  child: Text(_t('Annuler','إلغاء'))),
                                TextButton(onPressed: () => Navigator.pop(context, true),
                                  child: Text(_t('Supprimer','حذف'), style: const TextStyle(color: Colors.red))),
                              ],
                            ));
                          if (confirm == true) {
                            await MeetingsService.deleteMeeting(m['id']);
                            _loadMeetings();
                          }
                        },
                        icon: const Icon(Icons.delete_outline_rounded, size: 20),
                        color: Colors.red,
                        tooltip: 'Supprimer',
                      ),
                    ]),
                  ]),
                ),
              ]),
            ).animate().fadeIn().slideY(begin: 0.05);
          }).toList(),
      ],
    );
  }
}


/// Wrapper pour envoyer des bytes comme un XFile
class _PdfFileWrapper {
  final String name;
  final List<int> _bytes;
  _PdfFileWrapper(this.name, this._bytes);
  Future<List<int>> readAsBytes() async => _bytes;
}

/// Wrapper pour envoyer des bytes vidéo
class _VideoFileWrapper {
  final String name;
  final List<int> _bytes;
  _VideoFileWrapper(this.name, this._bytes);
  Future<List<int>> readAsBytes() async => _bytes;
}
