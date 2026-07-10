import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter_animate/flutter_animate.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:image_picker/image_picker.dart';
import 'package:qr_flutter/qr_flutter.dart';
import '../../theme/app_theme.dart';
import '../../models/user_model.dart';
import '../../services/auth_service.dart';
import '../../services/l10n_service.dart';
import 'notifications_screen.dart';
import 'post_detail_screen.dart';
import '../../services/theme_service.dart';
import 'points_history_screen.dart';

class ProfileTab extends StatefulWidget {
  const ProfileTab({Key? key}) : super(key: key);

  @override
  State<ProfileTab> createState() => ProfileTabState();
}

class ProfileTabState extends State<ProfileTab> {
  bool _mfaEnabled = false;
  bool get _isDarkMode => ThemeService.isDarkMode;
  final AuthService _authService = AuthService();
  final ImagePicker _imagePicker = ImagePicker();
  int _unreadNotifCount = 0;
  bool _isUploadingAvatar = false;
  Map<String, dynamic> _myStats = {};

  @override
  void initState() {
    super.initState();
    _mfaEnabled = AuthState.currentUser?.mfaEnabled ?? false;
    L10n.addListener(_onLocaleChange);
    ThemeService.addListener(_onThemeChange);
    _loadUnreadCount();
    _loadMyStats();
    refreshScore(); // Charge le score au premier montage
  }

  void _onThemeChange() {
    if (mounted) setState(() {});
  }

  Future<void> _toggleDarkMode(bool value) async {
    await ThemeService.setDarkMode(value);
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    L10n.removeListener(_onLocaleChange);
    ThemeService.removeListener(_onThemeChange);
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
        AuthState.currentUser = User.fromBackend(userData);
        _mfaEnabled = AuthState.currentUser?.mfaEnabled ?? false;
        if (mounted) setState(() {});
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

  void _showMfaDialog(BuildContext context) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) {
        bool showSetupStep = false;
        bool showDisableStep = false;
        bool setupLoading = false;
        bool actionLoading = false;
        String? setupSecret;
        String? setupOtpauthUrl;
        String? dialogError;
        
        final TextEditingController codeController = TextEditingController();
        final TextEditingController passwordController = TextEditingController();

        return StatefulBuilder(
          builder: (context, setDialogState) {
            Future<void> startSetup() async {
              setDialogState(() {
                setupLoading = true;
                dialogError = null;
              });
              final result = await _authService.setupMfa();
              if (result['success'] == true) {
                setDialogState(() {
                  setupSecret = result['secret'];
                  setupOtpauthUrl = result['otpauth_url'];
                  showSetupStep = true;
                  setupLoading = false;
                });
              } else {
                setDialogState(() {
                  dialogError = result['message'];
                  setupLoading = false;
                });
              }
            }

            Future<void> submitEnable() async {
              final code = codeController.text.trim();
              if (code.isEmpty || code.length != 6) {
                setDialogState(() => dialogError = 'Veuillez entrer le code à 6 chiffres');
                return;
              }
              setDialogState(() {
                actionLoading = true;
                dialogError = null;
              });
              // Capturer les deux contexts avant l'await
              final messenger = ScaffoldMessenger.of(context);
              final dialogNav = Navigator.of(dialogContext);
              final result = await _authService.verifyEnableMfa(code);
              if (result['success'] == true) {
                dialogNav.pop();
                if (mounted) {
                  setState(() => _mfaEnabled = true);
                  refreshScore();
                  messenger.showSnackBar(SnackBar(
                    content: Text('Authentification forte activée avec succès.', style: GoogleFonts.inter(fontWeight: FontWeight.w500)),
                    backgroundColor: AppTheme.primaryGreen,
                    behavior: SnackBarBehavior.floating,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ));
                }
              } else {
                setDialogState(() {
                  dialogError = result['message'];
                  actionLoading = false;
                });
              }
            }

            Future<void> submitDisable() async {
              final password = passwordController.text.trim();
              final code = codeController.text.trim();

              if (password.isEmpty && code.isEmpty) {
                setDialogState(() => dialogError = 'Veuillez saisir votre mot de passe ou un code MFA.');
                return;
              }

              setDialogState(() {
                actionLoading = true;
                dialogError = null;
              });

              // Capturer les deux contexts avant l'await
              final messenger = ScaffoldMessenger.of(context);
              final dialogNav = Navigator.of(dialogContext);
              final result = await _authService.disableMfa(
                password: password.isNotEmpty ? password : null,
                code: code.isNotEmpty ? code : null,
              );

              if (result['success'] == true) {
                dialogNav.pop();
                if (mounted) {
                  setState(() => _mfaEnabled = false);
                  refreshScore();
                  messenger.showSnackBar(SnackBar(
                    content: Text('Authentification forte désactivée.', style: GoogleFonts.inter(fontWeight: FontWeight.w500)),
                    backgroundColor: Colors.amber.shade700,
                    behavior: SnackBarBehavior.floating,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ));
                }
              } else {
                setDialogState(() {
                  dialogError = result['message'];
                  actionLoading = false;
                });
              }
            }

            if (setupLoading) {
              return AlertDialog(
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
                content: const SizedBox(
                  height: 100,
                  child: Center(child: CircularProgressIndicator(color: AppTheme.primaryGreen)),
                ),
              );
            }

            if (showSetupStep) {
              return AlertDialog(
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
                title: Text('Activer la validation TOTP', style: GoogleFonts.outfit(fontWeight: FontWeight.bold)),
                content: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        '1. Scannez ce code QR avec Google Authenticator ou Authy :',
                        style: GoogleFonts.inter(fontSize: 14),
                      ),
                      const SizedBox(height: 15),
                      if (setupOtpauthUrl != null)
                        Container(
                          width: 200,
                          height: 200,
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(16),
                            boxShadow: const [BoxShadow(color: Colors.black12, blurRadius: 8)],
                          ),
                          child: QrImageView(
                            data: setupOtpauthUrl!,
                            version: QrVersions.auto,
                          ),
                        ),
                      const SizedBox(height: 15),
                      Text(
                        'Ou saisissez cette clé manuellement :',
                        style: GoogleFonts.inter(fontSize: 14),
                      ),
                      const SizedBox(height: 5),
                      SelectableText(
                        setupSecret ?? '',
                        style: GoogleFonts.outfit(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: AppTheme.primaryGreen,
                        ),
                      ),
                      const SizedBox(height: 20),
                      Text(
                        '2. Entrez le code à 6 chiffres affiché par l\'application :',
                        style: GoogleFonts.inter(fontSize: 14),
                      ),
                      const SizedBox(height: 10),
                      TextField(
                        controller: codeController,
                        keyboardType: TextInputType.number,
                        maxLength: 6,
                        textAlign: TextAlign.center,
                        style: GoogleFonts.outfit(fontSize: 18, fontWeight: FontWeight.bold, letterSpacing: 4),
                        decoration: InputDecoration(
                          hintText: '000000',
                          counterText: '',
                          filled: true,
                          fillColor: Colors.grey.shade100,
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                        ),
                        onSubmitted: (_) => actionLoading ? null : submitEnable(),
                      ),
                      if (dialogError != null) ...[
                        const SizedBox(height: 12),
                        Text(
                          dialogError!,
                          style: GoogleFonts.inter(color: Colors.red.shade400, fontSize: 12, fontWeight: FontWeight.w500),
                        ),
                      ],
                    ],
                  ),
                ),
                actions: [
                  TextButton(
                    onPressed: actionLoading ? null : () => Navigator.pop(dialogContext),
                    child: const Text('ANNULER'),
                  ),
                  ElevatedButton(
                    onPressed: actionLoading ? null : submitEnable,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppTheme.primaryGreen,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    child: actionLoading
                        ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                        : const Text('ACTIVER'),
                  ),
                ],
              );
            }

            if (showDisableStep) {
              return AlertDialog(
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
                title: Text('Désactiver l\'authentification forte', style: GoogleFonts.outfit(fontWeight: FontWeight.bold)),
                content: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Pour des raisons de sécurité, veuillez confirmer votre identité.',
                        style: GoogleFonts.inter(fontSize: 14, color: Colors.grey.shade600),
                      ),
                      const SizedBox(height: 20),
                      Text(
                        'Entrez votre mot de passe actuel :',
                        style: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.w500),
                      ),
                      const SizedBox(height: 8),
                      TextField(
                        controller: passwordController,
                        obscureText: true,
                        decoration: InputDecoration(
                          hintText: 'Votre mot de passe',
                          filled: true,
                          fillColor: Colors.grey.shade100,
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                        ),
                        onSubmitted: (_) => actionLoading ? null : submitDisable(),
                      ),
                      const SizedBox(height: 15),
                      Text(
                        'Ou entrez un code MFA actuel (si compte social) :',
                        style: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.w500),
                      ),
                      const SizedBox(height: 8),
                      TextField(
                        controller: codeController,
                        keyboardType: TextInputType.number,
                        maxLength: 6,
                        textAlign: TextAlign.center,
                        style: GoogleFonts.outfit(fontSize: 16, fontWeight: FontWeight.bold, letterSpacing: 4),
                        decoration: InputDecoration(
                          hintText: '000000',
                          counterText: '',
                          filled: true,
                          fillColor: Colors.grey.shade100,
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                        ),
                        onSubmitted: (_) => actionLoading ? null : submitDisable(),
                      ),
                      if (dialogError != null) ...[
                        const SizedBox(height: 12),
                        Text(
                          dialogError!,
                          style: GoogleFonts.inter(color: Colors.red.shade400, fontSize: 12, fontWeight: FontWeight.w500),
                        ),
                      ],
                    ],
                  ),
                ),
                actions: [
                  TextButton(
                    onPressed: actionLoading ? null : () => Navigator.pop(dialogContext),
                    child: const Text('ANNULER'),
                  ),
                  ElevatedButton(
                    onPressed: actionLoading ? null : submitDisable,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.red.shade400,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    child: actionLoading
                        ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                        : const Text('DÉSACTIVER'),
                  ),
                ],
              );
            }

            return AlertDialog(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
              title: Text('Authentification Forte', style: GoogleFonts.outfit(fontWeight: FontWeight.bold)),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.security_rounded, size: 60, color: AppTheme.primaryGreen),
                    const SizedBox(height: 20),
                    const Text('Sécurisez l\'accès à votre compte en activant la validation en deux étapes (MFA/TOTP).'),
                    const SizedBox(height: 20),
                    ListTile(
                      title: const Text('Validation TOTP'),
                      subtitle: const Text('Google Authenticator / Authy'),
                      trailing: Switch(
                        value: _mfaEnabled,
                        onChanged: (v) {
                          if (v) {
                            startSetup();
                          } else {
                            setDialogState(() {
                              showDisableStep = true;
                              dialogError = null;
                            });
                          }
                        },
                        activeColor: AppTheme.primaryGreen,
                      ),
                    ),
                    if (dialogError != null) ...[
                      const SizedBox(height: 12),
                      Text(
                        dialogError!,
                        style: GoogleFonts.inter(color: Colors.red.shade400, fontSize: 12, fontWeight: FontWeight.w500),
                      ),
                    ],
                  ],
                ),
              ),
              actions: [
                TextButton(onPressed: () => Navigator.pop(dialogContext), child: const Text('FERMER')),
              ],
            );
          },
        );
      },
    );
  }

  void _showPasswordDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (dialogContext) => _ChangePasswordDialog(authService: _authService, isDarkMode: _isDarkMode),
    );
  }

  void _viewSavedPosts(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (sheetContext) {
        return _SavedPostsSheet(authService: _authService, isDarkMode: _isDarkMode);
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final user = AuthState.currentUser;
    // Masquer les statistiques de gamification pour les rôles Admin/Directeur
    final showStats = user?.role == UserRole.user;
    final isCollector = user?.role == UserRole.collector;

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
                    child: _buildProfileHeader(context, user),
                  ),

                  const SizedBox(height: 32),

                  // Afficher les statistiques de gamification uniquement pour un utilisateur standard
                  if (showStats)
                    Animate(
                      effects: [FadeEffect(delay: 300.ms), const SlideEffect(begin: Offset(0, 0.1))],
                      child: _buildStatsGrid(context),
                    ),

                  if (!showStats) ...[
                    _buildProfessionalBadge(context),
                    const SizedBox(height: 32),
                  ],

                  // Section QR Code Eco-Badge (citoyens)
                  if (showStats) ...[
                    const SizedBox(height: 24),
                    Animate(
                      effects: [FadeEffect(delay: 400.ms), const SlideEffect(begin: Offset(0, 0.1))],
                      child: _buildQrBadgeButton(context),
                    ),
                  ],

                  // Section QR Code Badge Collecteur
                  if (isCollector) ...[
                    const SizedBox(height: 8),
                    Animate(
                      effects: [FadeEffect(delay: 400.ms), const SlideEffect(begin: Offset(0, 0.1))],
                      child: _buildCollectorQrButton(context),
                    ),
                    const SizedBox(height: 8),
                  ],

                  const SizedBox(height: 40),

                  _buildMenuSection(context, L10n.tr('menu_sec_security'), [
                    _MenuAction(
                      icon: FontAwesomeIcons.userShield,
                      title: L10n.tr('menu_mfa'),
                      subtitle: _mfaEnabled ? L10n.tr('menu_mfa_enabled') : L10n.tr('menu_mfa_disabled'),
                      onTap: () => _showMfaDialog(context),
                    ),
                    _MenuAction(
                      icon: FontAwesomeIcons.key,
                      title: L10n.tr('menu_change_pass'),
                      subtitle: L10n.tr('menu_change_pass_sub'),
                      onTap: () => _showPasswordDialog(context),
                    ),
                    if (showStats)
                      _MenuAction(
                        // New menu item for saved posts
                        icon: FontAwesomeIcons.bookmark,
                        title: L10n.tr('menu_saved_posts'),
                        subtitle: L10n.tr('menu_saved_posts_sub'),
                        onTap: () => _viewSavedPosts(context),
                      ),
                    if (showStats)
                      _MenuAction(
                        icon: FontAwesomeIcons.clockRotateLeft,
                        title: L10n.isArabic ? 'سجل النقاط' : 'Historique des points',
                        subtitle: L10n.isArabic ? 'النقاط المكتسبة من الاختبارات والفرز' : 'Points gagnés par quiz, tri, etc.',
                        onTap: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(builder: (_) => const PointsHistoryScreen()),
                          ).then((_) => refreshScore());
                        },
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

                  _buildMenuSection(context, L10n.tr('menu_sec_preferences'), [
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
                      icon: FontAwesomeIcons.moon,
                      title: L10n.tr('menu_dark_mode'),
                      subtitle: L10n.tr('menu_dark_mode_sub'),
                      trailing: Switch(
                          value: _isDarkMode,
                          onChanged: _toggleDarkMode,
                          activeColor: AppTheme.primaryGreen),
                    ),
                  ]),

                  const SizedBox(height: 60),

                  Animate(
                    effects: const [FadeEffect(delay: Duration(seconds: 1))],
                    child: GestureDetector(
                      onTap: () async {
                        // Afficher une confirmation avant de déconnecter
                        final confirm = await showDialog<bool>(
                          context: context,
                          builder: (ctx) => AlertDialog(
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                            title: Row(children: [
                              Icon(Icons.logout_rounded, color: Colors.red.shade400, size: 22),
                              const SizedBox(width: 10),
                              Text(L10n.tr('menu_logout'),
                                  style: GoogleFonts.outfit(fontWeight: FontWeight.bold, fontSize: 18)),
                            ]),
                            content: Text(
                              L10n.isArabic
                                  ? 'هل أنت متأكد أنك تريد تسجيل الخروج؟'
                                  : 'Voulez-vous vraiment vous déconnecter ?',
                              style: GoogleFonts.inter(fontSize: 14),
                            ),
                            actions: [
                              TextButton(
                                onPressed: () => Navigator.pop(ctx, false),
                                child: Text(L10n.isArabic ? 'إلغاء' : 'Annuler',
                                    style: GoogleFonts.outfit(fontWeight: FontWeight.w600)),
                              ),
                              ElevatedButton(
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: Colors.red.shade400,
                                  foregroundColor: Colors.white,
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                ),
                                onPressed: () => Navigator.pop(ctx, true),
                                child: Text(
                                  L10n.isArabic ? 'تسجيل الخروج' : 'Se déconnecter',
                                  style: GoogleFonts.outfit(fontWeight: FontWeight.bold),
                                ),
                              ),
                            ],
                          ),
                        );
                        if (confirm != true) return;
                        if (!context.mounted) return;
                        // Capturer le navigator avant l'await (context.mounted vérifié juste avant)
                        final nav = Navigator.of(context);

                        // ── Déconnexion complète ──────────────────────────────
                        // 1. Appel service : efface jwt_token + refresh_token de
                        //    SharedPreferences, déconnecte Firebase et FCM.
                        await AuthService().logout();
                        // 2. Vider la mémoire en-cours (AuthState statique)
                        AuthState.logout();
                        AuthState.authToken = null;

                        if (!mounted) return;
                        // 3. Naviguer vers la page d'accueil publique (landing)
                        //    et supprimer tout l'historique de navigation.
                        nav.pushNamedAndRemoveUntil(
                          '/', (route) => false,
                        );
                      },
                      child: Container(
                        width: double.infinity,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        decoration: BoxDecoration(
                          color: _isDarkMode ? Colors.red.shade900.withOpacity(0.2) : const Color(0xFFFFF1F2),
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: _isDarkMode ? Colors.red.shade900.withOpacity(0.5) : Colors.red.shade100),
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
                  ],
                ),
              ),
            ),
          );
  }

  Widget _buildProfessionalBadge(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: _isDarkMode ? [const Color(0xFF1E293B), const Color(0xFF0F172A)] : [AppTheme.deepSlate, Colors.blueGrey.shade800],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
        boxShadow: _isDarkMode ? [] : AppTheme.premiumShadow,
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

  Widget _buildProfileHeader(BuildContext context, User? user) {
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
                  color: _isDarkMode ? const Color(0xFF1E293B) : Colors.white,
                  boxShadow: _isDarkMode ? [] : AppTheme.tightShadow,
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
                    color: _isDarkMode ? const Color(0xFF334155) : AppTheme.deepSlate,
                    shape: BoxShape.circle,
                    border: Border.all(color: _isDarkMode ? const Color(0xFF1E293B) : Colors.white, width: 2),
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
            style: GoogleFonts.inter(color: _isDarkMode ? const Color(0xFF94A3B8) : AppTheme.textMuted, fontWeight: FontWeight.w500)),
        const SizedBox(height: 20),

        // Suppression du badge de rang générique pour l'admin, conservé uniquement pour les utilisateurs si nécessaire ou remplacé par un tag professionnel
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
          decoration: BoxDecoration(
            color: AppTheme.primaryGreen.withOpacity(0.1),
            borderRadius: BorderRadius.circular(30),
            border: Border.all(color: AppTheme.primaryGreen.withOpacity(0.2)),
          ),
          child: Text(
              user?.role == UserRole.superadmin
                  ? L10n.tr('prof_role_superadmin')
                  : (user?.role == UserRole.admin
                      ? L10n.tr('prof_role_admin')
                      : L10n.tr('prof_role_user')),
              style: GoogleFonts.outfit(
                  color: AppTheme.primaryGreen, fontWeight: FontWeight.w900, fontSize: 10, letterSpacing: 1.5)),
        ),
      ],
    );
  }

  Widget _buildStatsGrid(BuildContext context) {
    final postsCount = (_myStats['posts_count'] as num?)?.toInt() ?? 0;
    final likesReceived = (_myStats['likes_received'] as num?)?.toInt() ?? 0;
    final commentsCount = (_myStats['comments_count'] as num?)?.toInt() ?? 0;
    final globalScore = AuthState.currentUser?.globalScore ?? 0.0;

    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(AppTheme.borderRadiusLarge),
        boxShadow: _isDarkMode ? [] : AppTheme.premiumShadow,
      ),
      child: Column(
        children: [
          // Score global en haut
          // Score global en haut (cliquable pour voir l'historique)
          GestureDetector(
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const PointsHistoryScreen()),
              ).then((_) => refreshScore()); // Actualise le score si retour d'écran
            },
            child: Container(
              width: double.infinity,
              margin: const EdgeInsets.only(bottom: 20),
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: _isDarkMode ? [const Color(0xFF334155).withOpacity(0.3), const Color(0xFF1E293B)] : [AppTheme.primaryGreen.withOpacity(0.08), AppTheme.accentTeal.withOpacity(0.05)],
                ),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: _isDarkMode ? const Color(0xFF475569) : AppTheme.primaryGreen.withOpacity(0.15)),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.emoji_events_rounded, color: AppTheme.primaryGreen, size: 24),
                  const SizedBox(width: 12),
                  Text(L10n.tr('prof_stats_score'), style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.w900, color: _isDarkMode ? const Color(0xFF94A3B8) : AppTheme.textMuted, letterSpacing: 1)),
                  const SizedBox(width: 12),
                  Text(globalScore.toStringAsFixed(1), style: GoogleFonts.outfit(fontSize: 26, fontWeight: FontWeight.bold, color: AppTheme.primaryGreen)),
                  const SizedBox(width: 4),
                  Text('pts', style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w600, color: _isDarkMode ? const Color(0xFF94A3B8) : AppTheme.textMuted)),
                  const SizedBox(width: 12),
                  Icon(
                    Icons.arrow_forward_ios_rounded,
                    size: 14,
                    color: _isDarkMode ? const Color(0xFF64748B) : AppTheme.textMuted,
                  ),
                ],
              ),
            ),
          ),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _buildStatItem(context, L10n.tr('prof_stats_posts'), '$postsCount', Icons.photo_library_rounded),
              _buildDivider(context),
              _buildStatItem(context, L10n.tr('prof_stats_likes'), '$likesReceived', Icons.favorite_rounded),
              _buildDivider(context),
              _buildStatItem(context, L10n.tr('prof_stats_comments'), '$commentsCount', Icons.chat_bubble_rounded),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildDivider(BuildContext context) => Container(height: 40, width: 1, color: Theme.of(context).dividerColor);

  Widget _buildStatItem(BuildContext context, String label, String value, IconData icon) {
    return Column(
      children: [
        Icon(icon, color: AppTheme.primaryGreen.withOpacity(0.5), size: 20),
        const SizedBox(height: 8),
        Text(value, style: GoogleFonts.outfit(fontSize: 22, fontWeight: FontWeight.bold, color: Theme.of(context).textTheme.titleLarge?.color ?? AppTheme.deepSlate)),
        Text(label,
            style: TextStyle(
                fontSize: 10, fontWeight: FontWeight.w900, color: _isDarkMode ? const Color(0xFF94A3B8) : AppTheme.textMuted, letterSpacing: 1)),
      ],
    );
  }

  Widget _buildQrBadgeButton(BuildContext context) {
    return GestureDetector(
      onTap: () => _showQrBadge(context, isCollector: false),
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

  // ── Bouton QR pour le collecteur ─────────────────────────────────────────────
  Widget _buildCollectorQrButton(BuildContext context) {
    return GestureDetector(
      onTap: () => _showQrBadge(context, isCollector: true),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            colors: [Color(0xFF0D2137), Color(0xFF0F3460)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(24),
          border: Border.all(color: AppTheme.primaryGreen.withOpacity(0.35), width: 1.5),
          boxShadow: [
            BoxShadow(
              color: AppTheme.primaryGreen.withOpacity(0.18),
              blurRadius: 20,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppTheme.primaryGreen.withOpacity(0.15),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: AppTheme.primaryGreen.withOpacity(0.4)),
              ),
              child: const Icon(Icons.qr_code_2_rounded, color: AppTheme.primaryGreen, size: 32),
            ),
            const SizedBox(width: 20),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    L10n.isArabic ? 'بطاقة الجمع' : 'Badge Collecteur',
                    style: GoogleFonts.outfit(
                      fontSize: 18,
                      fontWeight: FontWeight.w800,
                      color: Colors.white,
                    ),
                  ),
                  Text(
                    L10n.isArabic
                        ? 'رمز QR الخاص بك للتعريف'
                        : 'Votre QR d\'identification pour les collectes',
                    style: GoogleFonts.inter(
                      fontSize: 13,
                      color: AppTheme.primaryGreen.withOpacity(0.85),
                    ),
                  ),
                ],
              ),
            ),
            const Icon(Icons.arrow_forward_ios_rounded, color: AppTheme.primaryGreen, size: 16),
          ],
        ),
      ),
    );
  }

  // ── Dialog QR partagé (citoyen + collecteur) ─────────────────────────────────
  void _showQrBadge(BuildContext context, {bool isCollector = false}) {
    final qrData = AuthState.currentUser?.qrCode ?? '';
    final qrColor  = isCollector ? AppTheme.primaryGreen : AppTheme.primaryGreen;
    final eyeColor = isCollector ? AppTheme.deepSlate    : AppTheme.deepSlate;
    final title    = isCollector
        ? (L10n.isArabic ? 'بطاقة الجمع' : 'Badge Collecteur')
        : 'Mon Eco-Badge';
    final subtitle = isCollector
        ? (L10n.isArabic
            ? 'يُستخدم هذا الرمز للتعريف بك أثناء عمليات الجمع.'
            : 'Présentez ce QR lors de vos opérations de collecte.')
        : 'Scannez ce code sur une borne pour ouvrir la trappe.';
    final accentColor = isCollector ? AppTheme.primaryGreen : AppTheme.primaryGreen;

    showDialog(
      context: context,
      useRootNavigator: true,
      builder: (dialogContext) => Dialog(
        backgroundColor: Colors.transparent,
        elevation: 0,
        insetPadding: const EdgeInsets.symmetric(horizontal: 20),
        child: Material(
          color: Colors.transparent,
          child: Container(
            decoration: BoxDecoration(
              color: _isDarkMode ? const Color(0xFF1E293B) : Colors.white,
              borderRadius: BorderRadius.circular(28),
              border: Border.all(
                color: isCollector
                    ? AppTheme.primaryGreen.withOpacity(0.35)
                    : Colors.transparent,
                width: 1.5,
              ),
              boxShadow: [
                BoxShadow(
                  color: accentColor.withOpacity(0.15),
                  blurRadius: 40,
                  offset: const Offset(0, 16),
                ),
              ],
            ),
            padding: const EdgeInsets.all(32),
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // ── Icône en tête ──
                  Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: accentColor.withOpacity(0.12),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      isCollector ? Icons.local_shipping_rounded : Icons.eco_rounded,
                      color: accentColor,
                      size: 28,
                    ),
                  ),
                  const SizedBox(height: 16),

                  // ── Titre ──
                  Text(
                    title,
                    textAlign: TextAlign.center,
                    style: GoogleFonts.outfit(
                      fontSize: 22,
                      fontWeight: FontWeight.w900,
                      color: _isDarkMode ? Colors.white : AppTheme.deepSlate,
                    ),
                  ),
                  const SizedBox(height: 6),

                  // ── Sous-titre ──
                  Text(
                    subtitle,
                    textAlign: TextAlign.center,
                    style: GoogleFonts.inter(
                      fontSize: 13,
                      height: 1.5,
                      color: _isDarkMode ? const Color(0xFF94A3B8) : AppTheme.textMuted,
                    ),
                  ),
                  const SizedBox(height: 28),

                  // ── QR Code ──
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(20),
                      boxShadow: [
                        BoxShadow(
                          color: accentColor.withOpacity(0.12),
                          blurRadius: 24,
                        ),
                      ],
                    ),
                    child: qrData.isNotEmpty
                      ? QrImageView(
                          data: qrData,
                          version: QrVersions.auto,
                          size: 200.0,
                          eyeStyle: QrEyeStyle(
                            eyeShape: QrEyeShape.square,
                            color: eyeColor,
                          ),
                          dataModuleStyle: QrDataModuleStyle(
                            dataModuleShape: QrDataModuleShape.square,
                            color: qrColor,
                          ),
                        )
                      : SizedBox(
                          width: 200,
                          height: 200,
                          child: Center(
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(Icons.qr_code_2_rounded,
                                    size: 60, color: Colors.grey.shade300),
                                const SizedBox(height: 12),
                                Text(
                                  L10n.isArabic
                                      ? 'لا يوجد رمز QR'
                                      : 'QR code absent',
                                  style: GoogleFonts.inter(
                                      fontSize: 13, color: Colors.grey),
                                ),
                              ],
                            ),
                          ),
                        ),
                  ),
                  const SizedBox(height: 16),

                  // ── Identifiant tronqué ──
                  if (qrData.isNotEmpty)
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                      decoration: BoxDecoration(
                        color: accentColor.withOpacity(0.07),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: accentColor.withOpacity(0.2)),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.tag_rounded, size: 14, color: accentColor),
                          const SizedBox(width: 6),
                          Text(
                            qrData.length > 20
                                ? '${qrData.substring(0, 8)}...${qrData.substring(qrData.length - 6)}'
                                : qrData,
                            style: GoogleFonts.sourceCodePro(
                              fontSize: 11,
                              color: accentColor,
                              fontWeight: FontWeight.w700,
                              letterSpacing: 0.5,
                            ),
                          ),
                        ],
                      ),
                    ),

                  const SizedBox(height: 28),

                  // ── Bouton fermer ──
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: () => Navigator.pop(dialogContext),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: accentColor,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                        elevation: 0,
                      ),
                      child: Text(
                        L10n.isArabic ? 'إغلاق' : 'FERMER',
                        style: GoogleFonts.outfit(
                          fontWeight: FontWeight.w800,
                          fontSize: 15,
                          letterSpacing: 1,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildMenuSection(BuildContext context, String title, List<Widget> children) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(left: 8.0),
          child: Text(title,
              style: TextStyle(
                  fontSize: 11, fontWeight: FontWeight.w900, color: _isDarkMode ? const Color(0xFF94A3B8) : AppTheme.textMuted, letterSpacing: 1.5)),
        ),
        const SizedBox(height: 16),
        Container(
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.surface,
            borderRadius: BorderRadius.circular(24),
            boxShadow: [
              BoxShadow(color: _isDarkMode ? Colors.black.withOpacity(0.25) : Colors.black.withOpacity(0.04), blurRadius: 20, offset: const Offset(0, 8))
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
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return ListTile(
      onTap: onTap,
      contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
      leading: Container(
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(color: AppTheme.primaryGreen.withOpacity(0.05), shape: BoxShape.circle),
        child: FaIcon(icon, size: 16, color: AppTheme.primaryGreen),
      ),
      title: Text(title, style: GoogleFonts.inter(fontWeight: FontWeight.w600, fontSize: 15, color: isDark ? Colors.white : AppTheme.deepSlate)),
      subtitle:
          subtitle != null ? Text(subtitle!, style: TextStyle(fontSize: 12, color: isDark ? const Color(0xFF94A3B8) : AppTheme.textMuted)) : null,
      trailing: trailing ?? Icon(Icons.chevron_right, size: 16, color: isDark ? const Color(0xFF94A3B8) : AppTheme.textMuted),
    );
  }
}

// ============================================
// Dialog de changement de mot de passe (réel)
// ============================================
class _ChangePasswordDialog extends StatefulWidget {
  final AuthService authService;
  final bool isDarkMode;
  const _ChangePasswordDialog({required this.authService, required this.isDarkMode});

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
    final isDark = widget.isDarkMode;
    return AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      backgroundColor: isDark ? const Color(0xFF1E293B) : Colors.white,
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
          Text('Changer le mot de passe', style: GoogleFonts.outfit(fontWeight: FontWeight.bold, fontSize: 18, color: isDark ? Colors.white : Colors.black)),
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
                  color: isDark ? Colors.red.shade900.withOpacity(0.2) : Colors.red.shade50,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: isDark ? Colors.red.shade900.withOpacity(0.5) : Colors.red.shade200),
                ),
                child: Row(
                  children: [
                    Icon(Icons.error_outline, color: Colors.red.shade400, size: 20),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(_errorMessage!, style: GoogleFonts.inter(color: isDark ? Colors.red.shade200 : Colors.red.shade700, fontSize: 13)),
                    ),
                  ],
                ),
              ),

            // Champs
            _buildPasswordField('Mot de passe actuel', _oldPassController, _obscureOld,
                () => setState(() => _obscureOld = !_obscureOld), isDark),
            const SizedBox(height: 16),
            _buildPasswordField('Nouveau mot de passe', _newPassController, _obscureNew,
                () => setState(() => _obscureNew = !_obscureNew), isDark),
            const SizedBox(height: 16),
            _buildPasswordField('Confirmer', _confirmPassController, _obscureConfirm,
                () => setState(() => _obscureConfirm = !_obscureConfirm), isDark),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: _isLoading ? null : () => Navigator.pop(context),
          child: Text('ANNULER', style: GoogleFonts.outfit(color: isDark ? const Color(0xFF94A3B8) : AppTheme.textMuted, fontWeight: FontWeight.w700)),
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
      String label, TextEditingController controller, bool obscure, VoidCallback toggleVisibility, bool isDark) {
    return TextField(
      controller: controller,
      obscureText: obscure,
      style: GoogleFonts.inter(fontWeight: FontWeight.w600, color: isDark ? Colors.white : Colors.black),
      decoration: InputDecoration(
        labelText: label,
        labelStyle: GoogleFonts.inter(fontSize: 13, color: isDark ? const Color(0xFF94A3B8) : AppTheme.textMuted),
        prefixIcon: const Icon(Icons.lock_outline, size: 18, color: AppTheme.primaryGreen),
        suffixIcon: IconButton(
          icon: Icon(
            obscure ? Icons.visibility_off_rounded : Icons.visibility_rounded,
            size: 18,
            color: isDark ? const Color(0xFF94A3B8) : AppTheme.textMuted,
          ),
          onPressed: toggleVisibility,
        ),
        filled: true,
        fillColor: isDark ? const Color(0xFF334155).withOpacity(0.3) : Colors.grey.shade50,
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
  final bool isDarkMode;
  const _SavedPostsSheet({required this.authService, required this.isDarkMode});

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
    final isDark = widget.isDarkMode;
    return Container(
      height: MediaQuery.of(context).size.height * 0.75,
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E293B) : Colors.white,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(30)),
      ),
      child: Column(
        children: [
          Container(
            width: 40, height: 5,
            margin: const EdgeInsets.symmetric(vertical: 12),
            decoration: BoxDecoration(color: isDark ? const Color(0xFF334155) : Colors.grey[300], borderRadius: BorderRadius.circular(10)),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(24, 8, 24, 16),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('Publications sauvegardées', style: GoogleFonts.outfit(fontSize: 22, fontWeight: FontWeight.bold, color: isDark ? Colors.white : AppTheme.deepSlate)),
                IconButton(onPressed: () => Navigator.pop(context), icon: Icon(Icons.close_rounded, color: isDark ? Colors.white : Colors.black)),
              ],
            ),
          ),
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator(color: AppTheme.primaryGreen))
                : _error != null
                    ? Center(child: Column(mainAxisSize: MainAxisSize.min, children: [
                        Icon(Icons.cloud_off_rounded, size: 48, color: isDark ? const Color(0xFF334155) : Colors.grey.shade300),
                        const SizedBox(height: 12),
                        Text(_error!, style: GoogleFonts.inter(color: isDark ? const Color(0xFF94A3B8) : AppTheme.textMuted)),
                        const SizedBox(height: 12),
                        TextButton(onPressed: _loadSavedPosts, child: Text('Réessayer', style: GoogleFonts.inter(color: AppTheme.primaryGreen, fontWeight: FontWeight.w600))),
                      ]))
                    : _savedPosts.isEmpty
                        ? Center(child: Column(mainAxisSize: MainAxisSize.min, children: [
                            Icon(Icons.bookmark_outline_rounded, size: 60, color: isDark ? const Color(0xFF334155) : AppTheme.textMuted.withOpacity(0.4)),
                            const SizedBox(height: 16),
                            Text('Aucune publication sauvegardée', style: GoogleFonts.outfit(fontSize: 16, color: isDark ? const Color(0xFF94A3B8) : AppTheme.textMuted)),
                            const SizedBox(height: 6),
                            Text('Appuyez sur le bookmark pour sauvegarder', style: GoogleFonts.inter(fontSize: 12, color: isDark ? const Color(0xFF64748B) : AppTheme.textMuted.withOpacity(0.6))),
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
                                    color: isDark ? Colors.red.shade900.withOpacity(0.2) : Colors.red.shade50,
                                    borderRadius: BorderRadius.circular(16),
                                  ),
                                  child: Icon(Icons.delete_outline_rounded, color: Colors.red.shade400),
                                ),
                                onDismissed: (_) => _unsavePost(postId, index),
                                child: Card(
                                  margin: const EdgeInsets.symmetric(vertical: 6),
                                  elevation: 0,
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                                  color: isDark ? const Color(0xFF334155).withOpacity(0.3) : AppTheme.backgroundLight,
                                  child: ListTile(
                                    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                                    leading: CircleAvatar(
                                      backgroundColor: AppTheme.primaryGreen.withOpacity(0.1),
                                      child: Text(userName.isNotEmpty ? userName[0].toUpperCase() : '?', style: GoogleFonts.outfit(color: AppTheme.primaryGreen, fontWeight: FontWeight.bold)),
                                    ),
                                    title: Text(userName, style: GoogleFonts.outfit(fontWeight: FontWeight.bold, fontSize: 14, color: isDark ? Colors.white : Colors.black)),
                                    subtitle: Text(description, maxLines: 2, overflow: TextOverflow.ellipsis, style: GoogleFonts.inter(fontSize: 12, color: isDark ? const Color(0xFF94A3B8) : AppTheme.textMuted)),
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

