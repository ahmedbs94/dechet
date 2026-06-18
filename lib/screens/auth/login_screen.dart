import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import '../../theme/app_theme.dart';
import '../../theme/platform_ui.dart';
import '../../models/user_model.dart';
import '../../services/auth_service.dart';
import '../../services/l10n_service.dart';
import 'web_login.dart';
import 'pinterest_bg.dart';
class LoginScreen extends StatefulWidget {
  const LoginScreen({Key? key}) : super(key: key);

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> with SingleTickerProviderStateMixin {
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _authService = AuthService();
  bool _isLoading = false;
  bool _obscurePassword = true;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
  }

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _handleLogin() async {
    final email = _emailController.text.trim();
    final password = _passwordController.text.trim();

    if (email.isEmpty || password.isEmpty) {
      setState(() => _errorMessage = L10n.isArabic ? 'يرجى ملء جميع الحقول' : 'Veuillez remplir tous les champs');
      return;
    }

    setState(() { _isLoading = true; _errorMessage = null; });

    try {
      final result = await _authService.login(email, password);
      if (!mounted) return;

      if (result['success'] == true) {
        // Tenter de charger le profil complet depuis /users/me
        final userDetailsResult = await _authService.getCurrentUserDetails();
        if (userDetailsResult['success'] == true && mounted) {
          final userData = userDetailsResult['user'] as Map<String, dynamic>;
          AuthState.currentUser = User.fromBackend(userData);
        } else {
          AuthState.currentUser = User.fromBackend({
            'id': result['id'],
            'full_name': result['full_name'],
            'email': result['email'],
            'role': result['role'] ?? 'user',
            'points': 0,
            'qr_code': result['qr_code'] ?? '',
            'avatar_url': result['avatar_url'] ?? '',
          });
        }

        if (!mounted) return;
        final userRole = AuthState.currentUser?.role ?? UserRole.user;
        if (userRole == UserRole.admin) {
          Navigator.pushReplacementNamed(context, '/admin');
        } else {
          Navigator.pushReplacementNamed(context, '/home');
        }
      } else {
        setState(() => _errorMessage = result['message'] ?? (L10n.isArabic ? 'بريد إلكتروني أو كلمة مرور خاطئة' : 'Email ou mot de passe incorrect'));
      }
    } catch (e) {
      if (mounted) setState(() => _errorMessage = L10n.isArabic ? 'خطأ في الاتصال. تحقق من شبكتك.' : 'Erreur de connexion. Vérifiez votre réseau.');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _handleSocialAuthResult(Map<String, dynamic> result) async {
    if (!mounted) return;
    if (result['success'] == true) {
      // Tenter de charger le profil complet depuis /users/me
      final userDetailsResult = await _authService.getCurrentUserDetails();
      if (userDetailsResult['success'] == true && mounted) {
        final userData = userDetailsResult['user'] as Map<String, dynamic>;
        AuthState.currentUser = User.fromBackend(userData);
      } else {
        AuthState.currentUser = User.fromBackend({
          'id': result['id'],
          'full_name': result['full_name'] ?? 'Utilisateur',
          'email': result['email'] ?? '',
          'role': result['role'] ?? 'user',
          'points': 0,
          'qr_code': result['qr_code'] ?? '',
          'avatar_url': result['avatar_url'] ?? '',
        });
      }
      if (!mounted) return;
      final userRole = AuthState.currentUser?.role ?? UserRole.user;
      if (userRole == UserRole.admin) {
        Navigator.pushReplacementNamed(context, '/admin');
      } else {
        Navigator.pushReplacementNamed(context, '/home');
      }
    } else {
      setState(() => _errorMessage = result['message'] ?? (L10n.isArabic ? 'خطأ في المصادقة' : 'Erreur d\'authentification'));
    }
  }

  Future<void> _handleGoogleSignIn() async {
    setState(() { _isLoading = true; _errorMessage = null; });
    try {
      final result = await _authService.signInWithGoogle();
      _handleSocialAuthResult(result);
    } catch (e) {
      if (mounted) setState(() => _errorMessage = 'Erreur Google Sign In : $e');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _handleFacebookSignIn() async {
    setState(() { _isLoading = true; _errorMessage = null; });
    try {
      final result = await _authService.signInWithFacebook();
      _handleSocialAuthResult(result);
    } catch (e) {
      if (mounted) setState(() => _errorMessage = 'Erreur Facebook Sign In : $e');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _navigateToForgotPassword() {
    showDialog(context: context, builder: (context) => _ForgotPasswordDialog(authService: _authService));
  }

  @override
  Widget build(BuildContext context) {
    // ── Web : layout professionnel split-screen ──────────────────────
    if (PlatformUI.isWeb) {
      return WebLoginBody(
        emailController: _emailController,
        passwordController: _passwordController,
        isLoading: _isLoading,
        obscurePassword: _obscurePassword,
        errorMessage: _errorMessage,
        onLogin: _handleLogin,
        onTogglePassword: () => setState(() => _obscurePassword = !_obscurePassword),
        onForgotPassword: _navigateToForgotPassword,
        onGoogleSignIn: _handleGoogleSignIn,
        onFacebookSignIn: _handleFacebookSignIn,
        onSignUp: () => Navigator.pushNamed(context, '/signup'),
      );
    }

    // ── Mobile : design Pinterest-like avec PinterestBackground ───────────────────
    return Scaffold(
      backgroundColor: const Color(0xFF0F172A),
      body: Stack(
        children: [
          // ── Pinterest Masonry Background ──
          const Positioned.fill(child: PinterestBackground()),

          // ── Main content ──
          SafeArea(
            child: Center(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(horizontal: 28),
                physics: const BouncingScrollPhysics(),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const SizedBox(height: 40),

                    // ── Logo & Brand ──
                    Container(
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.1),
                        shape: BoxShape.circle,
                        border: Border.all(color: Colors.white.withOpacity(0.2)),
                        boxShadow: [
                          BoxShadow(color: Colors.black.withOpacity(0.2), blurRadius: 20, offset: const Offset(0, 10))
                        ],
                      ),
                      child: Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          gradient: const LinearGradient(colors: [AppTheme.primaryGreen, AppTheme.accentTeal]),
                          borderRadius: BorderRadius.circular(20),
                          boxShadow: [BoxShadow(color: AppTheme.primaryGreen.withOpacity(0.4), blurRadius: 24, offset: const Offset(0, 8))],
                        ),
                        child: ClipOval(
                          child: Image.asset(
                            'assets/images/ecorewind_logo.png',
                            width: 36,
                            height: 36,
                            fit: BoxFit.cover,
                          ),
                        ),
                      ),
                    ).animate().scale(begin: const Offset(0.5, 0.5), curve: Curves.elasticOut, duration: 800.ms),

                    const SizedBox(height: 24),

                    ShaderMask(
                      shaderCallback: (bounds) => const LinearGradient(colors: [Colors.white, Color(0xFF86EFAC)]).createShader(bounds),
                      child: Text('EcoRewind', style: GoogleFonts.spaceGrotesk(fontSize: 40, fontWeight: FontWeight.w900, color: Colors.white, letterSpacing: -1)),
                    ).animate().fadeIn(delay: 200.ms).slideY(begin: 0.1, end: 0),

                    const SizedBox(height: 8),

                    Text(L10n.isArabic ? 'تأثيرك يبدأ هنا' : 'Votre impact commence ici', style: GoogleFonts.inter(color: Colors.white.withOpacity(0.8), fontSize: 14, fontWeight: FontWeight.w500)).animate().fadeIn(delay: 300.ms),

                    const SizedBox(height: 40),

                    // ── Form card (glassmorphism pro) ──
                    Container(
                      padding: const EdgeInsets.all(32),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.12),
                        borderRadius: BorderRadius.circular(32),
                        border: Border.all(color: Colors.white.withOpacity(0.25)),
                        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.25), blurRadius: 40, offset: const Offset(0, 20))],
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          // Error message
                          if (_errorMessage != null) ...[
                            Container(
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: Colors.red.withOpacity(0.1),
                                borderRadius: BorderRadius.circular(14),
                                border: Border.all(color: Colors.red.withOpacity(0.2)),
                              ),
                              child: Row(children: [
                                Icon(Icons.error_outline, color: Colors.red.shade300, size: 18),
                                const SizedBox(width: 10),
                                Expanded(child: Text(_errorMessage!, style: GoogleFonts.inter(color: Colors.red.shade300, fontSize: 12))),
                              ]),
                            ).animate().shakeX(hz: 3, amount: 4, duration: 300.ms),
                            const SizedBox(height: 20),
                          ],

                          // Email field
                          _buildTextField(
                            controller: _emailController,
                            label: 'Email',
                            icon: Icons.alternate_email_rounded,
                            keyboardType: TextInputType.emailAddress,
                          ),
                          const SizedBox(height: 16),

                          // Password field
                          _buildTextField(
                            controller: _passwordController,
                            label: L10n.isArabic ? 'كلمة المرور' : 'Mot de passe',
                            icon: Icons.lock_outline_rounded,
                            obscure: _obscurePassword,
                            suffixIcon: IconButton(
                              icon: Icon(_obscurePassword ? Icons.visibility_off_rounded : Icons.visibility_rounded, size: 18, color: const Color(0xFF94A3B8)),
                              onPressed: () => setState(() => _obscurePassword = !_obscurePassword),
                            ),
                          ),

                          // Forgot password
                          Align(
                            alignment: Alignment.centerRight,
                            child: TextButton(
                              onPressed: _navigateToForgotPassword,
                              style: TextButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 8)),
                              child: Text(L10n.isArabic ? 'نسيت كلمة المرور ؟' : 'Mot de passe oublié ?', style: GoogleFonts.inter(fontSize: 12, color: Colors.white, fontWeight: FontWeight.w600)),
                            ),
                          ),

                          const SizedBox(height: 8),

                          // Login button
                          Animate(
                            onPlay: (c) => c.repeat(reverse: true),
                            effects: [ShimmerEffect(delay: 3.seconds, duration: 2.seconds, color: Colors.white10)],
                            child: Container(
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(20),
                                gradient: const LinearGradient(colors: [AppTheme.primaryGreen, AppTheme.accentTeal]),
                                boxShadow: [BoxShadow(color: AppTheme.primaryGreen.withOpacity(0.4), blurRadius: 20, offset: const Offset(0, 8))],
                              ),
                              child: ElevatedButton(
                                onPressed: _isLoading ? null : _handleLogin,
                                style: ElevatedButton.styleFrom(
                                  padding: const EdgeInsets.symmetric(vertical: 18),
                                  backgroundColor: Colors.transparent,
                                  shadowColor: Colors.transparent,
                                  disabledBackgroundColor: Colors.transparent,
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                                ),
                                child: _isLoading
                                    ? const SizedBox(width: 22, height: 22, child: CircularProgressIndicator(strokeWidth: 2.5, valueColor: AlwaysStoppedAnimation<Color>(Colors.white)))
                                    : Text(L10n.isArabic ? 'تسجيل الدخول' : 'SE CONNECTER', style: GoogleFonts.outfit(fontWeight: FontWeight.w900, letterSpacing: 2, fontSize: 15, color: Colors.white)),
                              ),
                            ),
                          ),

                          const SizedBox(height: 28),

                          // Divider
                          Row(children: [
                            Expanded(child: Container(height: 1, color: Colors.white.withOpacity(0.15))),
                            Padding(
                              padding: const EdgeInsets.symmetric(horizontal: 16),
                              child: Text(L10n.isArabic ? 'أو' : 'OU', style: GoogleFonts.inter(fontSize: 10, fontWeight: FontWeight.w800, color: Colors.white.withOpacity(0.5), letterSpacing: 2)),
                            ),
                            Expanded(child: Container(height: 1, color: Colors.white.withOpacity(0.15))),
                          ]),

                          const SizedBox(height: 24),

                          // Social buttons (Simple Icons)
                          Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              _buildSocialIcon(
                                onPressed: _isLoading ? null : _handleGoogleSignIn,
                                icon: FontAwesomeIcons.google,
                                iconColor: Colors.white,
                                bgColor: const Color(0xFFDB4437),
                              ),
                              const SizedBox(width: 24),
                              _buildSocialIcon(
                                onPressed: _isLoading ? null : _handleFacebookSignIn,
                                icon: FontAwesomeIcons.facebookF,
                                iconColor: Colors.white,
                                bgColor: const Color(0xFF1877F2),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ).animate().fadeIn(delay: 500.ms, duration: 600.ms).slideY(begin: 0.06, end: 0),

                    const SizedBox(height: 32),

                    // Sign up link
                    TextButton(
                      onPressed: () => Navigator.pushNamed(context, '/signup'),
                      child: RichText(text: TextSpan(
                        text: L10n.isArabic ? 'ليس لديك حساب ؟ ' : 'Pas encore de compte ? ',
                        style: GoogleFonts.inter(color: Colors.white.withOpacity(0.8), fontSize: 14),
                        children: [
                          TextSpan(text: L10n.isArabic ? 'إنشاء حساب' : 'S\'inscrire', style: GoogleFonts.outfit(color: Colors.white, fontWeight: FontWeight.w900)),
                        ],
                      )),
                    ).animate().fadeIn(delay: 700.ms),

                    const SizedBox(height: 40),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    required IconData icon,
    bool obscure = false,
    TextInputType? keyboardType,
    Widget? suffixIcon,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withOpacity(0.15)),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.08), blurRadius: 10, offset: const Offset(0, 4))],
      ),
      child: TextField(
        controller: controller,
        obscureText: obscure,
        keyboardType: keyboardType,
        style: GoogleFonts.inter(color: const Color(0xFF1E293B), fontWeight: FontWeight.w500, fontSize: 14),
        cursorColor: AppTheme.primaryGreen,
        decoration: InputDecoration(
          labelText: label,
          labelStyle: GoogleFonts.inter(color: const Color(0xFF94A3B8), fontSize: 13),
          prefixIcon: Icon(icon, size: 20, color: AppTheme.primaryGreen),
          suffixIcon: suffixIcon,
          filled: false,
          border: InputBorder.none,
          contentPadding: const EdgeInsets.symmetric(vertical: 18, horizontal: 16),
          floatingLabelStyle: GoogleFonts.inter(color: AppTheme.primaryGreen, fontSize: 13, fontWeight: FontWeight.w600),
        ),
        onSubmitted: (_) => _handleLogin(),
      ),
    );
  }

  Widget _buildSocialIcon({VoidCallback? onPressed, required IconData icon, required Color iconColor, required Color bgColor}) {
    return GestureDetector(
      onTap: onPressed,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: bgColor,
          shape: BoxShape.circle,
          boxShadow: [
            BoxShadow(color: bgColor.withOpacity(0.4), blurRadius: 16, offset: const Offset(0, 8)),
          ],
        ),
        child: FaIcon(icon, size: 24, color: iconColor),
      ),
    );
  }
}

// ══════════ Forgot Password Dialog — 3 étapes ══════════
class _ForgotPasswordDialog extends StatefulWidget {
  final AuthService authService;
  const _ForgotPasswordDialog({required this.authService});

  @override
  State<_ForgotPasswordDialog> createState() => _ForgotPasswordDialogState();
}

class _ForgotPasswordDialogState extends State<_ForgotPasswordDialog> {
  final _emailController = TextEditingController();
  final _codeController = TextEditingController();
  final _newPasswordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();
  bool _isLoading = false;
  bool _obscureNew = true;
  bool _obscureConfirm = true;
  String? _message;
  bool _isError = false;
  int _step = 0;

  Future<void> _sendResetEmail() async {
    final email = _emailController.text.trim();
    if (email.isEmpty) { setState(() { _message = 'Veuillez entrer votre email'; _isError = true; }); return; }
    setState(() { _isLoading = true; _message = null; });
    try {
      await widget.authService.forgotPassword(email);
      if (mounted) setState(() { _isLoading = false; _step = 1; _message = 'Un code a été envoyé à $email.'; _isError = false; });
    } catch (e) {
      if (mounted) setState(() { _message = 'Erreur réseau. Réessayez plus tard.'; _isError = true; _isLoading = false; });
    }
  }

  Future<void> _resetPassword() async {
    final code = _codeController.text.trim();
    final newPassword = _newPasswordController.text;
    final confirmPassword = _confirmPasswordController.text;
    if (code.isEmpty) { setState(() { _message = 'Veuillez entrer le code'; _isError = true; }); return; }
    if (newPassword.isEmpty) { setState(() { _message = 'Veuillez entrer un nouveau mot de passe'; _isError = true; }); return; }
    if (newPassword.length < 6) { setState(() { _message = 'Le mot de passe doit contenir au moins 6 caractères'; _isError = true; }); return; }
    if (newPassword != confirmPassword) { setState(() { _message = 'Les mots de passe ne correspondent pas'; _isError = true; }); return; }
    setState(() { _isLoading = true; _message = null; });
    try {
      final result = await widget.authService.resetPassword(code, newPassword);
      if (mounted) {
        if (result['success'] == true) {
          final email = _emailController.text.trim();
          final loginResult = await widget.authService.login(email, newPassword);
          if (mounted) {
            if (loginResult['success'] == true) {
              // Utiliser directement les données du login (avatar_url inclus)
              AuthState.currentUser = User.fromBackend({
                'id': loginResult['id'],
                'full_name': loginResult['full_name'] ?? 'Utilisateur',
                'email': loginResult['email'] ?? email,
                'role': loginResult['role'] ?? 'user',
                'points': 0,
                'qr_code': loginResult['qr_code'] ?? '',
                'avatar_url': loginResult['avatar_url'] ?? '',
              });
              final userRole = AuthState.currentUser?.role ?? UserRole.user;
              Navigator.pop(context);
              if (userRole == UserRole.admin) { Navigator.pushReplacementNamed(context, '/admin'); } else { Navigator.pushReplacementNamed(context, '/home'); }
              return;
            }
          }
          if (mounted) setState(() { _isLoading = false; _step = 2; _message = null; _isError = false; });
        } else {
          setState(() { _isLoading = false; _message = result['message'] ?? 'Code invalide ou expiré'; _isError = true; });
        }
      }
    } catch (e) {
      if (mounted) setState(() { _message = 'Erreur réseau.'; _isError = true; _isLoading = false; });
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      title: Row(children: [
        if (_step == 1) IconButton(icon: const Icon(Icons.arrow_back_rounded, size: 20), onPressed: () => setState(() { _step = 0; _message = null; }), padding: EdgeInsets.zero, constraints: const BoxConstraints()),
        if (_step == 1) const SizedBox(width: 8),
        Icon(_step == 2 ? Icons.check_circle_rounded : Icons.lock_reset_rounded, color: AppTheme.primaryGreen, size: 28),
        const SizedBox(width: 10),
        Expanded(child: Text(_step == 0 ? (L10n.isArabic ? 'نسيت كلمة المرور' : 'Mot de passe oublié') : _step == 1 ? (L10n.isArabic ? 'إعادة تعيين' : 'Réinitialisation') : (L10n.isArabic ? 'تم تغيير كلمة المرور !' : 'Mot de passe modifié !'), style: GoogleFonts.outfit(fontWeight: FontWeight.bold, fontSize: 18))),
      ]),
      content: AnimatedSwitcher(
        duration: const Duration(milliseconds: 300),
        child: _step == 0 ? _buildStepEmail() : _step == 1 ? _buildStepCode() : _buildStepSuccess(),
      ),
      actions: _step == 2
          ? [ElevatedButton(onPressed: () => Navigator.pop(context), style: ElevatedButton.styleFrom(backgroundColor: AppTheme.primaryGreen, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)), padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 12)), child: Text(L10n.isArabic ? 'العودة إلى تسجيل الدخول' : 'Retour à la connexion', style: GoogleFonts.outfit(fontWeight: FontWeight.bold)))]
          : [
              TextButton(onPressed: () => Navigator.pop(context), child: Text(L10n.isArabic ? 'إلغاء' : 'Annuler', style: GoogleFonts.inter(color: AppTheme.textMuted))),
              ElevatedButton(
                onPressed: _isLoading ? null : (_step == 0 ? _sendResetEmail : _resetPassword),
                style: ElevatedButton.styleFrom(backgroundColor: AppTheme.primaryGreen, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
                child: _isLoading ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white)) : Text(_step == 0 ? (L10n.isArabic ? 'إرسال الرمز' : 'Envoyer le code') : (L10n.isArabic ? 'تغيير كلمة المرور' : 'Changer le mot de passe'), style: GoogleFonts.outfit(fontWeight: FontWeight.bold)),
              ),
            ],
    );
  }

  Widget _buildStepEmail() {
    return Column(key: const ValueKey('step_email'), mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text(L10n.isArabic ? 'أدخل بريدك الإلكتروني لتلقي رمز إعادة التعيين.' : 'Entrez votre email pour recevoir un code de réinitialisation.', style: GoogleFonts.inter(fontSize: 13, color: AppTheme.textMuted)),
      const SizedBox(height: 16),
      TextField(controller: _emailController, keyboardType: TextInputType.emailAddress, decoration: InputDecoration(labelText: 'Email', prefixIcon: const Icon(Icons.email_outlined, color: AppTheme.primaryGreen), border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)))),
      if (_message != null) ...[const SizedBox(height: 12), _buildMessage()],
    ]);
  }

  Widget _buildStepCode() {
    return Column(key: const ValueKey('step_code'), mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
      Container(padding: const EdgeInsets.all(12), decoration: BoxDecoration(color: AppTheme.primaryGreen.withOpacity(0.08), borderRadius: BorderRadius.circular(12), border: Border.all(color: AppTheme.primaryGreen.withOpacity(0.2))),
        child: Row(children: [const Icon(Icons.mark_email_read_rounded, color: AppTheme.primaryGreen, size: 20), const SizedBox(width: 10), Expanded(child: Text('${L10n.isArabic ? 'تم إرسال الرمز إلى' : 'Code envoyé à'} ${_emailController.text.trim()}', style: GoogleFonts.inter(fontSize: 12, color: AppTheme.primaryGreen, fontWeight: FontWeight.w600)))])),
      const SizedBox(height: 20),
      TextField(controller: _codeController, decoration: InputDecoration(labelText: L10n.isArabic ? 'رمز التحقق' : 'Code de vérification', prefixIcon: const Icon(Icons.pin_rounded, color: AppTheme.primaryGreen), border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)))),
      const SizedBox(height: 16),
      TextField(controller: _newPasswordController, obscureText: _obscureNew, decoration: InputDecoration(labelText: L10n.isArabic ? 'كلمة مرور جديدة' : 'Nouveau mot de passe', prefixIcon: const Icon(Icons.lock_outline_rounded, color: AppTheme.primaryGreen), border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)), suffixIcon: IconButton(icon: Icon(_obscureNew ? Icons.visibility_off : Icons.visibility, size: 20), onPressed: () => setState(() => _obscureNew = !_obscureNew)))),
      const SizedBox(height: 16),
      TextField(controller: _confirmPasswordController, obscureText: _obscureConfirm, decoration: InputDecoration(labelText: L10n.isArabic ? 'تأكيد كلمة المرور' : 'Confirmer le mot de passe', prefixIcon: const Icon(Icons.lock_reset_rounded, color: AppTheme.primaryGreen), border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)), suffixIcon: IconButton(icon: Icon(_obscureConfirm ? Icons.visibility_off : Icons.visibility, size: 20), onPressed: () => setState(() => _obscureConfirm = !_obscureConfirm)))),
      if (_message != null) ...[const SizedBox(height: 12), _buildMessage()],
    ]);
  }

  Widget _buildStepSuccess() {
    return Column(key: const ValueKey('step_success'), mainAxisSize: MainAxisSize.min, children: [
      const Icon(Icons.check_circle_rounded, color: AppTheme.primaryGreen, size: 60),
      const SizedBox(height: 16),
      Text(L10n.isArabic ? 'تم تغيير كلمة المرور بنجاح !' : 'Votre mot de passe a été modifié avec succès !', textAlign: TextAlign.center, style: GoogleFonts.inter(fontSize: 14, color: AppTheme.deepSlate)),
    ]);
  }

  Widget _buildMessage() {
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(color: (_isError ? Colors.red : AppTheme.primaryGreen).withOpacity(0.08), borderRadius: BorderRadius.circular(10), border: Border.all(color: (_isError ? Colors.red : AppTheme.primaryGreen).withOpacity(0.2))),
      child: Row(children: [Icon(_isError ? Icons.error_outline : Icons.info_outline, size: 18, color: _isError ? Colors.red : AppTheme.primaryGreen), const SizedBox(width: 8), Expanded(child: Text(_message!, style: GoogleFonts.inter(fontSize: 12, color: _isError ? Colors.red.shade700 : AppTheme.primaryGreen)))]),
    );
  }
}
