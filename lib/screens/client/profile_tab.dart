import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter_animate/flutter_animate.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:image_picker/image_picker.dart';
import 'package:qr_flutter/qr_flutter.dart';
import '../../theme/app_theme.dart';
import '../../models/user_model.dart';
import '../../widgets/premium_widgets.dart';
import '../../services/auth_service.dart';
import '../../services/l10n_service.dart';
import 'notifications_screen.dart';
import 'post_detail_screen.dart';

class ProfileTab extends StatefulWidget {
  const ProfileTab({Key? key}) : super(key: key);

  @override
  State<ProfileTab> createState() => ProfileTabState();
}

class ProfileTabState extends State<ProfileTab> {
  bool _pushNotifications = true;
  bool _mfaEnabled = false;
  final AuthService _authService = AuthService();
  final ImagePicker _imagePicker = ImagePicker();
  int _unreadNotifCount = 0;
  bool _isUploadingAvatar = false;
  Map<String, dynamic> _myStats = {};

  @override
  void initState() {
    super.initState();
    L10n.addListener(_onLocaleChange);
    _loadUnreadCount();
    _loadMyStats();
    refreshScore(); // Charge le score au premier montage
  }

  @override
  void dispose() {
    L10n.removeListener(_onLocaleChange);
    super.dispose();
  }

  void _onLocaleChange() {
    if (mounted) setState(() {});
  }

  /// Méthode publique appelée par le shell quand on arrive sur cet onglet
  Future<void> refreshScore() async {
    if (!AuthState.isLoggedIn) return;
    try {
      final userData = await _authService.fetchUserProfile();
      if (userData != null && mounted) {
        final u = AuthState.currentUser;
        if (u != null) {
          final newScore = (userData['global_score'] as num?)?.toDouble() ?? u.globalScore;
          if (newScore != u.globalScore) {
            AuthState.currentUser = User(
              id: u.id,
              name: u.name,
              email: u.email,
              role: u.role,
              points: u.points,
              globalScore: newScore,
              avatarUrl: u.avatarUrl,
              qrCode: u.qrCode,
            );
          }
          // Toujours rafraîchir l'UI même si le score n'a pas changé
          if (mounted) setState(() {});
        }
      }
    } catch (_) {}
  }

  Future<void> _loadMyStats() async {
    if (!AuthState.isLoggedIn) return;
    final stats = await _authService.fetchMyStats();
    if (mounted) setState(() => _myStats = stats);
  }

  Future<void> _loadUnreadCount() async {
    if (!AuthState.isLoggedIn) return;
    final count = await _authService.fetchUnreadCount();
    if (mounted) setState(() => _unreadNotifCount = count);
  }

  String get _currentAvatarUrl {
    final url = AuthState.currentUser?.avatarUrl ?? '';
    if (url.isNotEmpty) return url;
    // Fallback: generate initials-based avatar (reliable, no external dependency)
    final name = AuthState.currentUser?.name ?? 'User';
    return 'https://ui-avatars.com/api/?name=${Uri.encodeComponent(name)}&size=300&background=059669&color=fff&bold=true';
  }

  void _changeProfileImage() {
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
            Container(width: 40, height: 4, margin: const EdgeInsets.only(bottom: 20), decoration: BoxDecoration(color: Colors.grey.shade300, borderRadius: BorderRadius.circular(2))),
            Text('Changer la photo de profil', style: GoogleFonts.outfit(fontSize: 20, fontWeight: FontWeight.bold)),
            const SizedBox(height: 24),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                // Caméra uniquement sur mobile (pas supporté sur Chrome web)
                if (!kIsWeb)
                  _buildImageSourceOption(
                    icon: Icons.camera_alt_rounded,
                    label: 'Caméra',
                    color: const Color(0xFF5B8DEF),
                    onTap: () {
                      Navigator.pop(context);
                      _pickAndUploadImage(ImageSource.camera);
                    },
                  ),
                _buildImageSourceOption(
                  icon: Icons.photo_library_rounded,
                  label: kIsWeb ? 'Choisir une image' : 'Galerie',
                  color: AppTheme.primaryGreen,
                  onTap: () {
                    Navigator.pop(context);
                    _pickAndUploadImage(ImageSource.gallery);
                  },
                ),
              ],
            ),
            if (kIsWeb) ...[
              const SizedBox(height: 12),
              Text(
                'La caméra n\'est disponible que sur l\'application mobile',
                style: GoogleFonts.inter(fontSize: 11, color: const Color(0xFF94A3B8)),
                textAlign: TextAlign.center,
              ),
            ],
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }

  Widget _buildImageSourceOption({
    required IconData icon,
    required String label,
    required Color color,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Column(
        children: [
          Container(
            width: 72, height: 72,
            decoration: BoxDecoration(
              color: color.withOpacity(0.1),
              borderRadius: BorderRadius.circular(24),
              border: Border.all(color: color.withOpacity(0.2)),
            ),
            child: Icon(icon, color: color, size: 32),
          ),
          const SizedBox(height: 10),
          Text(label, style: GoogleFonts.inter(fontWeight: FontWeight.w600, fontSize: 14, color: color)),
        ],
      ),
    );
  }

  Future<void> _pickAndUploadImage(ImageSource source) async {
    try {
      final XFile? picked = await _imagePicker.pickImage(
        source: source,
        maxWidth: 800,
        maxHeight: 800,
        imageQuality: 95,
      );
      if (picked == null) return;

      setState(() => _isUploadingAvatar = true);

      // Upload l'image
      final uploadedUrl = await _authService.uploadImageFromXFile(picked);

      if (uploadedUrl != null) {
        // Mettre à jour l'avatar sur le backend
        final result = await _authService.updateAvatar(uploadedUrl);

        if (result['success'] == true && mounted) {
          // Mettre à jour AuthState localement
          final user = AuthState.currentUser;
          if (user != null) {
            AuthState.currentUser = User(
              id: user.id,
              name: user.name,
              email: user.email,
              role: user.role,
              points: user.points,
              globalScore: user.globalScore,
              avatarUrl: uploadedUrl,
              qrCode: user.qrCode,
            );
          }
          setState(() => _isUploadingAvatar = false);
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Row(children: [
              const Icon(Icons.check_circle_rounded, color: Colors.white, size: 20),
              const SizedBox(width: 10),
              Text('Photo de profil mise à jour !', style: GoogleFonts.inter(fontWeight: FontWeight.w600)),
            ]),
            backgroundColor: AppTheme.primaryGreen,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          ));
        } else {
          setState(() => _isUploadingAvatar = false);
          _showErrorSnack('Erreur lors de la mise à jour du profil');
        }
      } else {
        setState(() => _isUploadingAvatar = false);
        _showErrorSnack('Échec de l\'upload de l\'image');
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isUploadingAvatar = false);
        _showErrorSnack('Erreur: $e');
      }
    }
  }

  void _showErrorSnack(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(message, style: GoogleFonts.inter(fontWeight: FontWeight.w500)),
      backgroundColor: Colors.red.shade400,
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
    ));
  }

  void _showMfaDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        title: Text('Authentification Forte', style: GoogleFonts.outfit(fontWeight: FontWeight.bold)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.security_rounded, size: 60, color: AppTheme.primaryGreen),
            const SizedBox(height: 20),
            const Text('Activez la validation en deux étapes pour sécuriser votre compte éco-responsable.'),
            const SizedBox(height: 20),
            ListTile(
              title: const Text('Utiliser l\'application'),
              subtitle: const Text('Google Authenticator / Authy'),
              trailing: Switch(
                  value: _mfaEnabled,
                  onChanged: (v) {
                    setState(() => _mfaEnabled = v);
                    Navigator.pop(context);
                  },
                  activeColor: AppTheme.primaryGreen),
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('FERMER')),
        ],
      ),
    );
  }

  void _showPasswordDialog() {
    showDialog(
      context: context,
      builder: (context) => _ChangePasswordDialog(authService: _authService),
    );
  }

  void _viewSavedPosts(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (sheetContext) {
        return _SavedPostsSheet(authService: _authService);
      },
    );
  }


  @override
  Widget build(BuildContext context) {
    final user = AuthState.currentUser;
    // Masquer les statistiques de gamification pour les rôles Admin/Directeur
    final showStats = user?.role == UserRole.user;

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      body: SafeArea(
        bottom: false,
        child: SingleChildScrollView(
          physics: const BouncingScrollPhysics(),
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: Column(
            children: [
              const SizedBox(height: 24),

            Animate(
              effects: const [FadeEffect(), ScaleEffect()],
              child: _buildProfileHeader(user),
            ),

            const SizedBox(height: 32),

            // Afficher les statistiques de gamification uniquement pour un utilisateur standard
            if (showStats)
              Animate(
                effects: [FadeEffect(delay: 300.ms), const SlideEffect(begin: Offset(0, 0.1))],
                child: _buildStatsGrid(),
              ),

            if (!showStats) ...[
              _buildProfessionalBadge(),
              const SizedBox(height: 32),
            ],

            // Section QR Code Eco-Badge (citoyens uniquement)
            if (showStats) ...[ 
              const SizedBox(height: 24),
              Animate(
                effects: [FadeEffect(delay: 400.ms), const SlideEffect(begin: Offset(0, 0.1))],
                child: _buildQrBadgeButton(),
              ),
              const SizedBox(height: 12),
              // Bouton scanner poubelle intelligente (mobile uniquement)
              if (!kIsWeb)
                Animate(
                  effects: [FadeEffect(delay: 500.ms), const SlideEffect(begin: Offset(0, 0.1))],
                  child: _buildBinScannerButton(),
                ),
            ],

            const SizedBox(height: 40),

            _buildMenuSection(L10n.tr('menu_sec_security'), [
              _MenuAction(
                icon: FontAwesomeIcons.userShield,
                title: L10n.tr('menu_mfa'),
                subtitle: _mfaEnabled ? L10n.tr('menu_mfa_enabled') : L10n.tr('menu_mfa_disabled'),
                onTap: _showMfaDialog,
              ),
              _MenuAction(
                icon: FontAwesomeIcons.key,
                title: L10n.tr('menu_change_pass'),
                subtitle: L10n.tr('menu_change_pass_sub'),
                onTap: _showPasswordDialog,
              ),
              _MenuAction(
                // New menu item for saved posts
                icon: FontAwesomeIcons.bookmark,
                title: L10n.tr('menu_saved_posts'),
                subtitle: L10n.tr('menu_saved_posts_sub'),
                onTap: () => _viewSavedPosts(context),
              ),
              _MenuAction(
                icon: FontAwesomeIcons.bell,
                title: L10n.tr('menu_notifications'),
                subtitle: _unreadNotifCount > 0 ? '$_unreadNotifCount ${_unreadNotifCount > 1 ? L10n.tr('menu_notif_unreads') : L10n.tr('menu_notif_unread')}' : L10n.tr('menu_notif_none'),
                trailing: _unreadNotifCount > 0 ? Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(color: const Color(0xFFFF6B8A), borderRadius: BorderRadius.circular(12)),
                  child: Text('$_unreadNotifCount', style: GoogleFonts.outfit(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold)),
                ) : null,
                onTap: () async {
                  await Navigator.push(context, MaterialPageRoute(builder: (_) => const NotificationsScreen()));
                  _loadUnreadCount(); // Refresh count when returning
                },
              ),

            ]),

            const SizedBox(height: 32),

            _buildMenuSection(L10n.tr('menu_sec_preferences'), [
              _MenuAction(
                icon: FontAwesomeIcons.language,
                title: L10n.tr('menu_lang'),
                subtitle: L10n.locale == 'fr' ? 'Français' : 'العربية',
                onTap: () {
                  final newLang = L10n.locale == 'fr' ? 'ar' : 'fr';
                  L10n.setLocale(newLang);
                },
              ),
              _MenuAction(
                icon: FontAwesomeIcons.bell,
                title: L10n.tr('menu_push_notif'),
                trailing: Switch(
                    value: _pushNotifications,
                    onChanged: (v) => setState(() => _pushNotifications = v),
                    activeColor: AppTheme.primaryGreen),
              ),
              _MenuAction(
                icon: FontAwesomeIcons.moon,
                title: L10n.tr('menu_dark_mode'),
                subtitle: L10n.tr('menu_dark_mode_sub'),
                onTap: () {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Thème : Basculement en cours...')),
                  );
                },
              ),
            ]),

            const SizedBox(height: 60),

            Animate(
              effects: [FadeEffect(delay: 1.seconds)],
              child: GestureDetector(
                onTap: () => Navigator.pushNamedAndRemoveUntil(context, '/login', (route) => false),
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFFF1F2),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: Colors.red.shade100),
                  ),
                  child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                    Icon(Icons.logout_rounded, color: Colors.red.shade400, size: 18),
                    const SizedBox(width: 10),
                    Text(L10n.tr('menu_logout'), style: GoogleFonts.outfit(color: Colors.red.shade400, fontWeight: FontWeight.w700, fontSize: 15)),
                  ]),
                ),
              ),
            ),

            const SizedBox(height: 100),
            ],  // children Column
          ),   // Column
        ),     // SingleChildScrollView
      ),       // SafeArea
    );         // Scaffold
  }

  Widget _buildProfessionalBadge() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [AppTheme.deepSlate, Colors.blueGrey.shade800],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
        boxShadow: AppTheme.premiumShadow,
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(color: Colors.white.withOpacity(0.1), shape: BoxShape.circle),
            child: const Icon(Icons.business_center_rounded, color: Colors.white, size: 28),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(L10n.tr('prof_badge_title'),
                    style: GoogleFonts.outfit(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16)),
                const SizedBox(height: 4),
                Text(L10n.tr('prof_badge_desc'),
                    style: const TextStyle(color: Colors.white70, fontSize: 12)),
              ],
            ),
          ),
        ],
      ),
    ).animate().fadeIn(delay: 400.ms).slideY(begin: 0.1);
  }

  Widget _buildProfileHeader(User? user) {
    return Column(
      children: [
        GestureDetector(
          onTap: _changeProfileImage,
          child: Stack(
            alignment: Alignment.center,
            children: [
              // Lueur professionnelle propre au lieu des particules de jeu
              Container(
                width: 130,
                height: 130,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(color: AppTheme.primaryGreen.withOpacity(0.2), blurRadius: 40, spreadRadius: 10),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.all(4),
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: Colors.white,
                  boxShadow: AppTheme.tightShadow,
                ),
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    CircleAvatar(
                      radius: 60,
                      backgroundColor: AppTheme.primaryGreen.withOpacity(0.1),
                      backgroundImage: NetworkImage(_currentAvatarUrl),
                      onBackgroundImageError: (_, __) {},
                      child: Text(
                        (user?.name ?? 'U')[0].toUpperCase(),
                        style: GoogleFonts.outfit(fontSize: 40, fontWeight: FontWeight.bold, color: AppTheme.primaryGreen),
                      ),
                    ),
                    if (_isUploadingAvatar)
                      Container(
                        width: 120, height: 120,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: Colors.black.withOpacity(0.4),
                        ),
                        child: const Center(
                          child: SizedBox(
                            width: 30, height: 30,
                            child: CircularProgressIndicator(color: Colors.white, strokeWidth: 3),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
              Positioned(
                bottom: 0,
                right: 0,
                child: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: AppTheme.deepSlate,
                    shape: BoxShape.circle,
                    border: Border.all(color: Colors.white, width: 2),
                  ),
                  child: const Icon(Icons.camera_alt_rounded, color: Colors.white, size: 14),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 24),
        Text(user?.name ?? 'Admin',
            style: GoogleFonts.outfit(
                fontSize: 28,
                fontWeight: FontWeight.bold,
                color: Theme.of(context).textTheme.titleLarge?.color ?? AppTheme.deepSlate)),
        Text(user?.email ?? 'admin@ecorewind.com',
            style: GoogleFonts.inter(color: AppTheme.textMuted, fontWeight: FontWeight.w500)),
        const SizedBox(height: 20),

        // Suppression du badge de rang générique pour l'admin, conservé uniquement pour les utilisateurs si nécessaire ou remplacé par un tag professionnel
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
          decoration: BoxDecoration(
            color: AppTheme.primaryGreen.withOpacity(0.1),
            borderRadius: BorderRadius.circular(30),
            border: Border.all(color: AppTheme.primaryGreen.withOpacity(0.2)),
          ),
          child: Text(user?.role == UserRole.admin ? L10n.tr('prof_role_admin') : L10n.tr('prof_role_user'),
              style: GoogleFonts.outfit(
                  color: AppTheme.primaryGreen, fontWeight: FontWeight.w900, fontSize: 10, letterSpacing: 1.5)),
        ),
      ],
    );
  }

  Widget _buildStatsGrid() {
    final postsCount = (_myStats['posts_count'] as num?)?.toInt() ?? 0;
    final likesReceived = (_myStats['likes_received'] as num?)?.toInt() ?? 0;
    final commentsCount = (_myStats['comments_count'] as num?)?.toInt() ?? 0;
    final globalScore = AuthState.currentUser?.globalScore ?? 0.0;

    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(AppTheme.borderRadiusLarge),
        boxShadow: AppTheme.premiumShadow,
      ),
      child: Column(
        children: [
          // Score global en haut
          Container(
            width: double.infinity,
            margin: const EdgeInsets.only(bottom: 20),
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [AppTheme.primaryGreen.withOpacity(0.08), AppTheme.accentTeal.withOpacity(0.05)],
              ),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: AppTheme.primaryGreen.withOpacity(0.15)),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.emoji_events_rounded, color: AppTheme.primaryGreen, size: 24),
                const SizedBox(width: 12),
                Text(L10n.tr('prof_stats_score'), style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.w900, color: AppTheme.textMuted, letterSpacing: 1)),
                const SizedBox(width: 12),
                Text(globalScore.toStringAsFixed(1), style: GoogleFonts.outfit(fontSize: 26, fontWeight: FontWeight.bold, color: AppTheme.primaryGreen)),
                const SizedBox(width: 4),
                Text('pts', style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w600, color: AppTheme.textMuted)),
              ],
            ),
          ),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _buildStatItem(L10n.tr('prof_stats_posts'), '$postsCount', Icons.photo_library_rounded),
              _buildDivider(),
              _buildStatItem(L10n.tr('prof_stats_likes'), '$likesReceived', Icons.favorite_rounded),
              _buildDivider(),
              _buildStatItem(L10n.tr('prof_stats_comments'), '$commentsCount', Icons.chat_bubble_rounded),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildDivider() => Container(height: 40, width: 1, color: Theme.of(context).dividerColor);

  Widget _buildStatItem(String label, String value, IconData icon) {
    return Column(
      children: [
        Icon(icon, color: AppTheme.primaryGreen.withOpacity(0.5), size: 20),
        const SizedBox(height: 8),
        Text(value, style: GoogleFonts.outfit(fontSize: 22, fontWeight: FontWeight.bold, color: Theme.of(context).textTheme.titleLarge?.color ?? AppTheme.deepSlate)),
        Text(label,
            style: const TextStyle(
                fontSize: 10, fontWeight: FontWeight.w900, color: AppTheme.textMuted, letterSpacing: 1)),
      ],
    );
  }

  Widget _buildQrBadgeButton() {
    return GestureDetector(
      onTap: _showQrBadge,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            colors: [AppTheme.deepSlate, Color(0xFF1E293B)],
          ),
          borderRadius: BorderRadius.circular(24),
          boxShadow: [
            BoxShadow(
              color: AppTheme.deepSlate.withOpacity(0.3),
              blurRadius: 20,
              offset: const Offset(0, 10),
            ),
          ],
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.1),
                borderRadius: BorderRadius.circular(16),
              ),
              child: const Icon(Icons.qr_code_2_rounded, color: Colors.white, size: 32),
            ),
            const SizedBox(width: 20),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    L10n.tr('prof_btn_eco_badge'),
                    style: GoogleFonts.outfit(
                      fontSize: 18,
                      fontWeight: FontWeight.w800,
                      color: Colors.white,
                    ),
                  ),
                  Text(
                    L10n.tr('prof_btn_eco_badge_sub'),
                    style: GoogleFonts.inter(
                      fontSize: 13,
                      color: Colors.white.withOpacity(0.7),
                    ),
                  ),
                ],
              ),
            ),
            const Icon(Icons.arrow_forward_ios_rounded, color: Colors.white, size: 16),
          ],
        ),
      ),
    );
  }

  /// Bouton d'accès au scanner QR des poubelles intelligentes
  Widget _buildBinScannerButton() {
    return GestureDetector(
      onTap: () => Navigator.pushNamed(context, '/bin-scanner').then((_) {
        // Rafraîchir le score après un scan réussi
        refreshScore();
      }),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 18),
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            colors: [Color(0xFF059669), Color(0xFF10B981)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(24),
          boxShadow: [
            BoxShadow(
              color: const Color(0xFF059669).withOpacity(0.35),
              blurRadius: 20,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.2),
                borderRadius: BorderRadius.circular(14),
              ),
              child: const Icon(Icons.qr_code_scanner_rounded, color: Colors.white, size: 28),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    L10n.tr('prof_btn_scan_bin'),
                    style: GoogleFonts.outfit(
                      fontSize: 17,
                      fontWeight: FontWeight.w800,
                      color: Colors.white,
                    ),
                  ),
                  Text(
                    L10n.tr('prof_btn_scan_bin_sub'),
                    style: GoogleFonts.inter(
                      fontSize: 12,
                      color: Colors.white.withOpacity(0.8),
                    ),
                  ),
                ],
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.2),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.star_rounded, color: Colors.white, size: 14),
                  const SizedBox(width: 4),
                  Text('+ pts', style: GoogleFonts.outfit(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w700)),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showQrBadge() {
    showDialog(
      context: context,
      useRootNavigator: true,
      builder: (context) => Dialog(
        backgroundColor: Colors.transparent,
        elevation: 0,
        insetPadding: const EdgeInsets.symmetric(horizontal: 20),
        child: Material(
          color: Colors.transparent,
          child: PremiumGlassCard(
            padding: const EdgeInsets.all(32),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'Mon Eco-Badge',
                  textAlign: TextAlign.center,
                  style: GoogleFonts.outfit(
                    fontSize: 24,
                    fontWeight: FontWeight.w900,
                    color: AppTheme.deepSlate,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Scannez ce code sur une borne pour ouvrir la trappe.',
                  textAlign: TextAlign.center,
                  style: GoogleFonts.inter(
                    fontSize: 14,
                    color: AppTheme.textMuted,
                  ),
                ),
                const SizedBox(height: 32),
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(20),
                    boxShadow: [
                      BoxShadow(
                        color: AppTheme.primaryGreen.withOpacity(0.1),
                        blurRadius: 20,
                      ),
                    ],
                  ),
                  child: SizedBox(
                    width: 200,
                    height: 200,
                    child: QrImageView(
                      data: AuthState.currentUser?.qrCode ?? 'INVALID-NO-QR',
                      version: QrVersions.auto,
                      size: 200.0,
                      eyeStyle: const QrEyeStyle(eyeShape: QrEyeShape.square, color: AppTheme.deepSlate),
                      dataModuleStyle: const QrDataModuleStyle(
                        dataModuleShape: QrDataModuleShape.square,
                        color: AppTheme.primaryGreen,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 32),
                PremiumButton(
                  text: 'FERMER',
                  onPressed: () => Navigator.pop(context),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildMenuSection(String title, List<Widget> children) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(left: 8.0),
          child: Text(title,
              style: const TextStyle(
                  fontSize: 11, fontWeight: FontWeight.w900, color: AppTheme.textMuted, letterSpacing: 1.5)),
        ),
        const SizedBox(height: 16),
        Container(
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.surface,
            borderRadius: BorderRadius.circular(24),
            boxShadow: [
              BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 20, offset: const Offset(0, 8))
            ],
          ),
          child: Column(children: children),
        ),
      ],
    );
  }
}

class _MenuAction extends StatelessWidget {
  final IconData icon;
  final String title;
  final String? subtitle;
  final Widget? trailing;
  final VoidCallback? onTap;

  const _MenuAction({required this.icon, required this.title, this.subtitle, this.trailing, this.onTap});

  @override
  Widget build(BuildContext context) {
    return ListTile(
      onTap: onTap,
      contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
      leading: Container(
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(color: AppTheme.primaryGreen.withOpacity(0.05), shape: BoxShape.circle),
        child: FaIcon(icon, size: 16, color: AppTheme.primaryGreen),
      ),
      title: Text(title, style: GoogleFonts.inter(fontWeight: FontWeight.w600, fontSize: 15)),
      subtitle:
          subtitle != null ? Text(subtitle!, style: const TextStyle(fontSize: 12, color: AppTheme.textMuted)) : null,
      trailing: trailing ?? const Icon(Icons.chevron_right, size: 16, color: AppTheme.textMuted),
    );
  }
}

// ============================================
// Dialog de changement de mot de passe (réel)
// ============================================
class _ChangePasswordDialog extends StatefulWidget {
  final AuthService authService;
  const _ChangePasswordDialog({required this.authService});

  @override
  State<_ChangePasswordDialog> createState() => _ChangePasswordDialogState();
}

class _ChangePasswordDialogState extends State<_ChangePasswordDialog> {
  final _oldPassController = TextEditingController();
  final _newPassController = TextEditingController();
  final _confirmPassController = TextEditingController();
  bool _isLoading = false;
  String? _errorMessage;
  String? _successMessage;
  bool _obscureOld = true;
  bool _obscureNew = true;
  bool _obscureConfirm = true;

  Future<void> _handleChangePassword() async {
    final oldPass = _oldPassController.text.trim();
    final newPass = _newPassController.text.trim();
    final confirmPass = _confirmPassController.text.trim();

    // Validation
    if (oldPass.isEmpty || newPass.isEmpty || confirmPass.isEmpty) {
      setState(() => _errorMessage = 'Veuillez remplir tous les champs');
      return;
    }

    if (newPass != confirmPass) {
      setState(() => _errorMessage = 'Les mots de passe ne correspondent pas');
      return;
    }

    if (newPass.length < 6) {
      setState(() => _errorMessage = 'Le mot de passe doit contenir au moins 6 caractères');
      return;
    }

    if (oldPass == newPass) {
      setState(() => _errorMessage = 'Le nouveau mot de passe doit être différent');
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = null;
      _successMessage = null;
    });

    try {
      final result = await widget.authService.changePassword(oldPass, newPass);

      if (!mounted) return;

      if (result['success'] == true) {
        setState(() {
          _successMessage = result['message'] ?? 'Mot de passe modifié avec succès';
          _isLoading = false;
        });
        // Fermer le dialog après 1.5 secondes
        Future.delayed(const Duration(milliseconds: 1500), () {
          if (mounted) Navigator.pop(context);
        });
      } else {
        String msg = result['message'] ?? 'Erreur lors du changement';
        // Traduction des erreurs techniques
        if (msg.contains('Ancien mot de passe incorrect') || msg.contains('incorrect')) {
          msg = 'Le mot de passe actuel est incorrect';
        } else if (msg.contains('validate credentials') || msg.contains('401')) {
          msg = 'Session expirée. Veuillez vous reconnecter.';
        }
        setState(() {
          _errorMessage = msg;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _errorMessage = 'Erreur réseau. Vérifiez votre connexion.';
          _isLoading = false;
        });
      }
    }
  }

  @override
  void dispose() {
    _oldPassController.dispose();
    _newPassController.dispose();
    _confirmPassController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      title: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: AppTheme.primaryGreen.withOpacity(0.1),
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Icon(Icons.lock_outline_rounded, color: AppTheme.primaryGreen, size: 20),
          ),
          const SizedBox(width: 12),
          Text('Changer le mot de passe', style: GoogleFonts.outfit(fontWeight: FontWeight.bold, fontSize: 18)),
        ],
      ),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Message de succès
            if (_successMessage != null)
              Container(
                padding: const EdgeInsets.all(12),
                margin: const EdgeInsets.only(bottom: 16),
                decoration: BoxDecoration(
                  color: AppTheme.primaryGreen.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: AppTheme.primaryGreen.withOpacity(0.3)),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.check_circle_rounded, color: AppTheme.primaryGreen, size: 20),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(_successMessage!,
                          style: GoogleFonts.inter(
                              color: AppTheme.primaryGreen, fontSize: 13, fontWeight: FontWeight.w600)),
                    ),
                  ],
                ),
              ),

            // Message d'erreur
            if (_errorMessage != null)
              Container(
                padding: const EdgeInsets.all(12),
                margin: const EdgeInsets.only(bottom: 16),
                decoration: BoxDecoration(
                  color: Colors.red.shade50,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.red.shade200),
                ),
                child: Row(
                  children: [
                    Icon(Icons.error_outline, color: Colors.red.shade400, size: 20),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(_errorMessage!, style: GoogleFonts.inter(color: Colors.red.shade700, fontSize: 13)),
                    ),
                  ],
                ),
              ),

            // Champs
            _buildPasswordField('Mot de passe actuel', _oldPassController, _obscureOld,
                () => setState(() => _obscureOld = !_obscureOld)),
            const SizedBox(height: 16),
            _buildPasswordField('Nouveau mot de passe', _newPassController, _obscureNew,
                () => setState(() => _obscureNew = !_obscureNew)),
            const SizedBox(height: 16),
            _buildPasswordField('Confirmer', _confirmPassController, _obscureConfirm,
                () => setState(() => _obscureConfirm = !_obscureConfirm)),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: _isLoading ? null : () => Navigator.pop(context),
          child: Text('ANNULER', style: GoogleFonts.outfit(color: AppTheme.textMuted, fontWeight: FontWeight.w700)),
        ),
        ElevatedButton(
          onPressed: _isLoading || _successMessage != null ? null : _handleChangePassword,
          style: ElevatedButton.styleFrom(
            backgroundColor: AppTheme.primaryGreen,
            disabledBackgroundColor: AppTheme.primaryGreen.withOpacity(0.5),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
          ),
          child: _isLoading
              ? const SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                )
              : Text('METTRE À JOUR', style: GoogleFonts.outfit(fontWeight: FontWeight.w800, letterSpacing: 0.5)),
        ),
      ],
    );
  }

  Widget _buildPasswordField(
      String label, TextEditingController controller, bool obscure, VoidCallback toggleVisibility) {
    return TextField(
      controller: controller,
      obscureText: obscure,
      style: GoogleFonts.inter(fontWeight: FontWeight.w600),
      decoration: InputDecoration(
        labelText: label,
        labelStyle: GoogleFonts.inter(fontSize: 13, color: AppTheme.textMuted),
        prefixIcon: const Icon(Icons.lock_outline, size: 18, color: AppTheme.primaryGreen),
        suffixIcon: IconButton(
          icon: Icon(
            obscure ? Icons.visibility_off_rounded : Icons.visibility_rounded,
            size: 18,
            color: AppTheme.textMuted,
          ),
          onPressed: toggleVisibility,
        ),
        filled: true,
        fillColor: Colors.grey.shade50,
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: AppTheme.primaryGreen, width: 2),
        ),
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      ),
    );
  }
}

// ════════════════════════════════════════════
// Saved Posts Sheet (connected to backend)
// ════════════════════════════════════════════
class _SavedPostsSheet extends StatefulWidget {
  final AuthService authService;
  const _SavedPostsSheet({required this.authService});

  @override
  State<_SavedPostsSheet> createState() => _SavedPostsSheetState();
}

class _SavedPostsSheetState extends State<_SavedPostsSheet> {
  List<Map<String, dynamic>> _savedPosts = [];
  bool _isLoading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadSavedPosts();
  }

  Future<void> _loadSavedPosts() async {
    setState(() { _isLoading = true; _error = null; });
    try {
      final posts = await widget.authService.fetchSavedPosts();
      if (mounted) {
        setState(() {
          _savedPosts = posts?.cast<Map<String, dynamic>>() ?? [];
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) setState(() { _error = 'Impossible de charger les favoris'; _isLoading = false; });
    }
  }

  Future<void> _unsavePost(String postId, int index) async {
    final result = await widget.authService.toggleSavePost(postId);
    if (result['success'] == true && mounted) {
      setState(() => _savedPosts.removeAt(index));
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Publication retirée des favoris', style: GoogleFonts.inter(fontWeight: FontWeight.w600)),
          backgroundColor: AppTheme.deepSlate,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      height: MediaQuery.of(context).size.height * 0.75,
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(30)),
      ),
      child: Column(
        children: [
          Container(
            width: 40, height: 5,
            margin: const EdgeInsets.symmetric(vertical: 12),
            decoration: BoxDecoration(color: Colors.grey[300], borderRadius: BorderRadius.circular(10)),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(24, 8, 24, 16),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('Publications sauvegardées', style: GoogleFonts.outfit(fontSize: 22, fontWeight: FontWeight.bold, color: AppTheme.deepSlate)),
                IconButton(onPressed: () => Navigator.pop(context), icon: const Icon(Icons.close_rounded)),
              ],
            ),
          ),
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator(color: AppTheme.primaryGreen))
                : _error != null
                    ? Center(child: Column(mainAxisSize: MainAxisSize.min, children: [
                        Icon(Icons.cloud_off_rounded, size: 48, color: Colors.grey.shade300),
                        const SizedBox(height: 12),
                        Text(_error!, style: GoogleFonts.inter(color: AppTheme.textMuted)),
                        const SizedBox(height: 12),
                        TextButton(onPressed: _loadSavedPosts, child: Text('Réessayer', style: GoogleFonts.inter(color: AppTheme.primaryGreen, fontWeight: FontWeight.w600))),
                      ]))
                    : _savedPosts.isEmpty
                        ? Center(child: Column(mainAxisSize: MainAxisSize.min, children: [
                            Icon(Icons.bookmark_outline_rounded, size: 60, color: AppTheme.textMuted.withOpacity(0.4)),
                            const SizedBox(height: 16),
                            Text('Aucune publication sauvegardée', style: GoogleFonts.outfit(fontSize: 16, color: AppTheme.textMuted)),
                            const SizedBox(height: 6),
                            Text('Appuyez sur le bookmark pour sauvegarder', style: GoogleFonts.inter(fontSize: 12, color: AppTheme.textMuted.withOpacity(0.6))),
                          ]))
                        : ListView.builder(
                            padding: const EdgeInsets.symmetric(horizontal: 16),
                            itemCount: _savedPosts.length,
                            itemBuilder: (context, index) {
                              final post = _savedPosts[index];
                              final userName = post['user_name'] ?? 'Anonyme';
                              final description = post['description'] ?? '';
                              final postId = post['id']?.toString() ?? '';
                              return Dismissible(
                                key: ValueKey(postId),
                                direction: DismissDirection.endToStart,
                                background: Container(
                                  alignment: Alignment.centerRight,
                                  padding: const EdgeInsets.only(right: 24),
                                  margin: const EdgeInsets.symmetric(vertical: 6),
                                  decoration: BoxDecoration(
                                    color: Colors.red.shade50,
                                    borderRadius: BorderRadius.circular(16),
                                  ),
                                  child: Icon(Icons.delete_outline_rounded, color: Colors.red.shade400),
                                ),
                                onDismissed: (_) => _unsavePost(postId, index),
                                child: Card(
                                  margin: const EdgeInsets.symmetric(vertical: 6),
                                  elevation: 0,
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                                  color: AppTheme.backgroundLight,
                                  child: ListTile(
                                    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                                    leading: CircleAvatar(
                                      backgroundColor: AppTheme.primaryGreen.withOpacity(0.1),
                                      child: Text(userName.isNotEmpty ? userName[0].toUpperCase() : '?', style: GoogleFonts.outfit(color: AppTheme.primaryGreen, fontWeight: FontWeight.bold)),
                                    ),
                                    title: Text(userName, style: GoogleFonts.outfit(fontWeight: FontWeight.bold, fontSize: 14)),
                                    subtitle: Text(description, maxLines: 2, overflow: TextOverflow.ellipsis, style: GoogleFonts.inter(fontSize: 12, color: AppTheme.textMuted)),
                                    trailing: IconButton(
                                      icon: const Icon(Icons.bookmark_rounded, color: AppTheme.primaryGreen, size: 20),
                                      onPressed: () => _unsavePost(postId, index),
                                    ),
                                    onTap: () {
                                      Navigator.pop(context); // Fermer le sheet
                                      Navigator.push(
                                        context,
                                        MaterialPageRoute(
                                          builder: (_) => PostDetailScreen(post: post),
                                        ),
                                      );
                                    },
                                  ),
                                ),
                              );
                            },
                          ),
          ),
        ],
      ),
    );
  }
}

