import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'dart:ui';

import '../../theme/app_theme.dart';
import '../../services/auth_service.dart';
import '../../models/user_model.dart';

// ══════════════════════════════════════════════════════
// FORGOT PASSWORD SCREEN — 3 étapes séparées
// Étape 0 : Email  |  Étape 1 : Code OTP  |  Étape 2 : Nouveau MDP
// ══════════════════════════════════════════════════════

class ForgotPasswordScreen extends StatefulWidget {
  const ForgotPasswordScreen({Key? key}) : super(key: key);

  @override
  State<ForgotPasswordScreen> createState() => _ForgotPasswordScreenState();
}

class _ForgotPasswordScreenState extends State<ForgotPasswordScreen> {
  final _authService = AuthService();
  final _pageController = PageController();

  // Controllers
  final _emailController = TextEditingController();
  final _newPasswordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();

  // OTP : 6 champs individuels
  final List<TextEditingController> _otpControllers =
      List.generate(6, (_) => TextEditingController());
  final List<FocusNode> _otpFocusNodes = List.generate(6, (_) => FocusNode());

  int _step = 0;
  bool _isLoading = false;
  bool _obscureNew = true;
  bool _obscureConfirm = true;

  @override
  void dispose() {
    _pageController.dispose();
    _emailController.dispose();
    _newPasswordController.dispose();
    _confirmPasswordController.dispose();
    for (final c in _otpControllers) { c.dispose(); }
    for (final f in _otpFocusNodes) { f.dispose(); }
    super.dispose();
  }

  String get _otpCode =>
      _otpControllers.map((c) => c.text).join();

  // ── Étape 0 → Envoyer le code ──────────────────────
  Future<void> _sendCode() async {
    final email = _emailController.text.trim();
    if (email.isEmpty || !email.contains('@')) {
      _toast('Veuillez entrer un email valide', isError: true);
      return;
    }
    setState(() => _isLoading = true);
    try {
      final res = await _authService.forgotPassword(email);
      if (!mounted) return;
      if (res['success'] == true) {
        _goToStep(1);
        _toast('Code envoyé à $email');
      } else {
        _toast(res['message'] ?? 'Erreur', isError: true);
      }
    } catch (_) {
      _toast('Erreur réseau', isError: true);
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  // ── Étape 1 → Valider le code ──────────────────────
  Future<void> _verifyCode() async {
    final code = _otpCode;
    if (code.length < 6) {
      _toast('Entrez les 6 chiffres du code', isError: true);
      return;
    }
    setState(() => _isLoading = true);
    try {
      final res = await _authService.verifyResetCode(
          _emailController.text.trim(), code);
      if (!mounted) return;
      if (res['success'] == true) {
        _goToStep(2);
      } else {
        _toast(res['message'] ?? 'Code invalide', isError: true);
      }
    } catch (_) {
      _toast('Erreur réseau', isError: true);
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  // ── Étape 2 → Réinitialiser le MDP ─────────────────
  Future<void> _resetPassword() async {
    final newPwd = _newPasswordController.text;
    final confirm = _confirmPasswordController.text;
    if (newPwd.length < 6) {
      _toast('Minimum 6 caractères', isError: true);
      return;
    }
    if (newPwd != confirm) {
      _toast('Les mots de passe ne correspondent pas', isError: true);
      return;
    }
    setState(() => _isLoading = true);
    try {
      final res = await _authService.resetPassword(_otpCode, newPwd);
      if (!mounted) return;
      if (res['success'] == true) {
        // Connexion automatique
        final login = await _authService.login(
            _emailController.text.trim(), newPwd);
        if (!mounted) return;
        if (login['success'] == true) {
          final roleStr = login['role'] as String? ?? 'user';
          UserRole role = UserRole.values.firstWhere(
            (e) => e.toString().split('.').last == roleStr,
            orElse: () => UserRole.user,
          );
          AuthState.currentUser = User(
            id: (login['id'] ?? 0).toString(),
            name: login['full_name'] ?? 'Utilisateur',
            email: _emailController.text.trim(),
            role: role,
            avatarUrl: login['avatar_url'] ??
                'https://ui-avatars.com/api/?name=${Uri.encodeComponent(login['full_name'] ?? 'User')}&size=300&background=059669&color=fff&bold=true',
            qrCode: login['qr_code'] as String? ?? '',
          );
          if (!mounted) return;
          _toast('Mot de passe mis à jour ! Bienvenue 🌿');
          Navigator.pushNamedAndRemoveUntil(
              context, '/home', (route) => false);
        } else {
          if (!mounted) return;
          _toast('Mot de passe mis à jour ! Veuillez vous connecter.');
          Navigator.pop(context);
        }
      } else {
        _toast(res['message'] ?? 'Erreur', isError: true);
      }
    } catch (_) {
      _toast('Erreur réseau', isError: true);
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _goToStep(int step) {
    setState(() => _step = step);
    _pageController.animateToPage(
      step,
      duration: const Duration(milliseconds: 400),
      curve: Curves.easeInOutCubic,
    );
  }

  void _toast(String msg, {bool isError = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(msg,
          style: GoogleFonts.inter(fontWeight: FontWeight.w600,
              color: Colors.white)),
      backgroundColor: isError ? const Color(0xFFEF4444) : AppTheme.primaryGreen,
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      margin: const EdgeInsets.all(16),
    ));
  }

  // ══════════════════════════════════════════════════════
  // BUILD
  // ══════════════════════════════════════════════════════
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.backgroundSoft,
      body: Stack(children: [
        _background(),
        SafeArea(
          child: Column(children: [
            _topBar(),
            _stepIndicator(),
            Expanded(
              child: PageView(
                controller: _pageController,
                physics: const NeverScrollableScrollPhysics(),
                children: [
                  _StepEmail(
                    controller: _emailController,
                    isLoading: _isLoading,
                    onSend: _sendCode,
                  ),
                  _StepCode(
                    otpControllers: _otpControllers,
                    otpFocusNodes: _otpFocusNodes,
                    email: _emailController.text,
                    isLoading: _isLoading,
                    onVerify: _verifyCode,
                    onResend: () {
                      for (final c in _otpControllers) { c.clear(); }
                      _goToStep(0);
                    },
                  ),
                  _StepPassword(
                    newController: _newPasswordController,
                    confirmController: _confirmPasswordController,
                    isLoading: _isLoading,
                    obscureNew: _obscureNew,
                    obscureConfirm: _obscureConfirm,
                    onToggleNew: () =>
                        setState(() => _obscureNew = !_obscureNew),
                    onToggleConfirm: () =>
                        setState(() => _obscureConfirm = !_obscureConfirm),
                    onReset: _resetPassword,
                  ),
                ],
              ),
            ),
          ]),
        ),
      ]),
    );
  }

  Widget _topBar() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
      child: Row(children: [
        if (_step > 0)
          GestureDetector(
            onTap: () => _goToStep(_step - 1),
            child: Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                  color: Colors.white,
                  shape: BoxShape.circle,
                  boxShadow: AppTheme.tightShadow),
              child: const Icon(Icons.arrow_back_ios_new_rounded,
                  size: 16, color: AppTheme.deepNavy),
            ),
          )
        else
          GestureDetector(
            onTap: () => Navigator.pop(context),
            child: Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                  color: Colors.white,
                  shape: BoxShape.circle,
                  boxShadow: AppTheme.tightShadow),
              child: const Icon(Icons.arrow_back_ios_new_rounded,
                  size: 16, color: AppTheme.deepNavy),
            ),
          ),
      ]),
    ).animate().fadeIn().slideX(begin: -0.2);
  }

  Widget _stepIndicator() {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 32),
      child: Row(
        children: List.generate(3, (i) {
          final active = i == _step;
          final done = i < _step;
          return Expanded(
            child: Row(children: [
              Expanded(
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 300),
                  height: 4,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(2),
                    color: done || active
                        ? AppTheme.primaryGreen
                        : Colors.grey.shade200,
                  ),
                ),
              ),
              if (i < 2) const SizedBox(width: 4),
            ]),
          );
        }),
      ),
    );
  }

  Widget _background() => Stack(children: [
        Container(color: const Color(0xFF0F172A)),
        Positioned(
          top: -200, right: -100,
          child: _blob(600, AppTheme.primaryGreen.withOpacity(0.25)),
        ).animate(onPlay: (c) => c.repeat(reverse: true))
            .move(begin: Offset.zero, end: const Offset(-50, 100), duration: 20.seconds),
        Positioned(
          bottom: -150, left: -100,
          child: _blob(500, AppTheme.accentTeal.withOpacity(0.15)),
        ).animate(onPlay: (c) => c.repeat(reverse: true))
            .move(begin: Offset.zero, end: const Offset(50, -100), duration: 25.seconds),
        Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter, end: Alignment.bottomCenter,
              colors: [
                const Color(0xFF0F172A).withOpacity(0.65),
                const Color(0xFF0F172A).withOpacity(0.92),
              ],
            ),
          ),
        ),
      ]);

  Widget _blob(double size, Color color) => Container(
        width: size, height: size,
        decoration: BoxDecoration(shape: BoxShape.circle, color: color),
        child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 120, sigmaY: 120),
            child: Container(color: Colors.transparent)),
      );
}

// ══════════════════════════════════════════════════════
// ÉTAPE 0 — Email
// ══════════════════════════════════════════════════════
class _StepEmail extends StatelessWidget {
  final TextEditingController controller;
  final bool isLoading;
  final VoidCallback onSend;

  const _StepEmail({
    required this.controller,
    required this.isLoading,
    required this.onSend,
  });

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 28),
      child: Column(children: [
        const SizedBox(height: 16),
        Container(
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: AppTheme.primaryGreen.withOpacity(0.12),
            shape: BoxShape.circle,
          ),
          child: const Icon(Icons.lock_reset_rounded,
              size: 52, color: AppTheme.primaryGreen),
        ).animate().scale(duration: 600.ms, curve: Curves.elasticOut),
        const SizedBox(height: 28),
        Text('Mot de passe oublié ?',
            textAlign: TextAlign.center,
            style: GoogleFonts.outfit(
                fontSize: 26,
                fontWeight: FontWeight.w800,
                color: Colors.white,
                letterSpacing: -0.5)),
        const SizedBox(height: 10),
        Text('Entrez votre email pour recevoir un code de vérification à 6 chiffres.',
            textAlign: TextAlign.center,
            style: GoogleFonts.inter(
                fontSize: 14,
                color: Colors.white70,
                height: 1.5)),
        const SizedBox(height: 40),
        _glassField(
          controller: controller,
          label: 'Adresse email',
          hint: 'votre@email.com',
          icon: Icons.alternate_email_rounded,
          keyboardType: TextInputType.emailAddress,
        ),
        const SizedBox(height: 32),
        _primaryButton(
          label: 'ENVOYER LE CODE',
          isLoading: isLoading,
          onPressed: onSend,
        ),
        const SizedBox(height: 40),
      ]),
    ).animate().fadeIn(delay: 100.ms).slideX(begin: 0.05, end: 0);
  }
}

// ══════════════════════════════════════════════════════
// ÉTAPE 1 — Code OTP (6 chiffres individuels)
// ══════════════════════════════════════════════════════
class _StepCode extends StatelessWidget {
  final List<TextEditingController> otpControllers;
  final List<FocusNode> otpFocusNodes;
  final String email;
  final bool isLoading;
  final VoidCallback onVerify;
  final VoidCallback onResend;

  const _StepCode({
    required this.otpControllers,
    required this.otpFocusNodes,
    required this.email,
    required this.isLoading,
    required this.onVerify,
    required this.onResend,
  });

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 28),
      child: Column(children: [
        const SizedBox(height: 16),
        Container(
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: Colors.blue.withOpacity(0.12),
            shape: BoxShape.circle,
          ),
          child: const Icon(Icons.mark_email_read_rounded,
              size: 52, color: Colors.lightBlueAccent),
        ).animate().scale(duration: 600.ms, curve: Curves.elasticOut),
        const SizedBox(height: 28),
        Text('Vérifiez votre email',
            textAlign: TextAlign.center,
            style: GoogleFonts.outfit(
                fontSize: 26,
                fontWeight: FontWeight.w800,
                color: Colors.white,
                letterSpacing: -0.5)),
        const SizedBox(height: 10),
        RichText(
          textAlign: TextAlign.center,
          text: TextSpan(
            style: GoogleFonts.inter(fontSize: 14, color: Colors.white60, height: 1.5),
            children: [
              const TextSpan(text: 'Nous avons envoyé un code à\n'),
              TextSpan(
                text: email,
                style: GoogleFonts.inter(
                    fontWeight: FontWeight.w700,
                    color: AppTheme.primaryGreen),
              ),
            ],
          ),
        ),
        const SizedBox(height: 40),
        // 6 boxes OTP
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: List.generate(6, (i) => _OtpBox(
            controller: otpControllers[i],
            focusNode: otpFocusNodes[i],
            nextFocus: i < 5 ? otpFocusNodes[i + 1] : null,
            prevFocus: i > 0 ? otpFocusNodes[i - 1] : null,
          )),
        ),
        const SizedBox(height: 40),
        _primaryButton(
          label: 'VALIDER LE CODE',
          isLoading: isLoading,
          onPressed: onVerify,
        ),
        const SizedBox(height: 20),
        // Renvoyer le code
        Row(mainAxisAlignment: MainAxisAlignment.center, children: [
          Text('Vous n\'avez pas reçu de code ? ',
              style: GoogleFonts.inter(fontSize: 13, color: Colors.white54)),
          GestureDetector(
            onTap: onResend,
            child: Text('Renvoyer',
                style: GoogleFonts.inter(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: AppTheme.primaryGreen)),
          ),
        ]),
        const SizedBox(height: 40),
      ]),
    ).animate().fadeIn(delay: 100.ms).slideX(begin: 0.05, end: 0);
  }
}

class _OtpBox extends StatelessWidget {
  final TextEditingController controller;
  final FocusNode focusNode;
  final FocusNode? nextFocus;
  final FocusNode? prevFocus;

  const _OtpBox({
    required this.controller,
    required this.focusNode,
    this.nextFocus,
    this.prevFocus,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 46,
      height: 56,
      margin: const EdgeInsets.symmetric(horizontal: 4),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.08),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.white.withOpacity(0.2), width: 1.5),
      ),
      child: TextField(
        controller: controller,
        focusNode: focusNode,
        textAlign: TextAlign.center,
        keyboardType: TextInputType.number,
        maxLength: 1,
        style: GoogleFonts.outfit(
            fontSize: 22,
            fontWeight: FontWeight.w900,
            color: Colors.white),
        inputFormatters: [FilteringTextInputFormatter.digitsOnly],
        decoration: const InputDecoration(
          counterText: '',
          border: InputBorder.none,
        ),
        onChanged: (val) {
          if (val.isNotEmpty && nextFocus != null) {
            FocusScope.of(context).requestFocus(nextFocus);
          } else if (val.isEmpty && prevFocus != null) {
            FocusScope.of(context).requestFocus(prevFocus);
          }
        },
      ),
    );
  }
}

// ══════════════════════════════════════════════════════
// ÉTAPE 2 — Nouveau mot de passe
// ══════════════════════════════════════════════════════
class _StepPassword extends StatelessWidget {
  final TextEditingController newController;
  final TextEditingController confirmController;
  final bool isLoading;
  final bool obscureNew;
  final bool obscureConfirm;
  final VoidCallback onToggleNew;
  final VoidCallback onToggleConfirm;
  final VoidCallback onReset;

  const _StepPassword({
    required this.newController,
    required this.confirmController,
    required this.isLoading,
    required this.obscureNew,
    required this.obscureConfirm,
    required this.onToggleNew,
    required this.onToggleConfirm,
    required this.onReset,
  });

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 28),
      child: Column(children: [
        const SizedBox(height: 16),
        Container(
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: AppTheme.primaryGreen.withOpacity(0.12),
            shape: BoxShape.circle,
          ),
          child: const Icon(Icons.lock_open_rounded,
              size: 52, color: AppTheme.primaryGreen),
        ).animate().scale(duration: 600.ms, curve: Curves.elasticOut),
        const SizedBox(height: 28),
        Text('Nouveau mot de passe',
            textAlign: TextAlign.center,
            style: GoogleFonts.outfit(
                fontSize: 26,
                fontWeight: FontWeight.w800,
                color: Colors.white,
                letterSpacing: -0.5)),
        const SizedBox(height: 10),
        Text('Choisissez un mot de passe fort de minimum 6 caractères.',
            textAlign: TextAlign.center,
            style: GoogleFonts.inter(
                fontSize: 14, color: Colors.white70, height: 1.5)),
        const SizedBox(height: 40),
        _glassField(
          controller: newController,
          label: 'Nouveau mot de passe',
          hint: 'Minimum 6 caractères',
          icon: Icons.lock_outline_rounded,
          obscure: obscureNew,
          suffixIcon: IconButton(
            icon: Icon(
              obscureNew ? Icons.visibility_off_rounded : Icons.visibility_rounded,
              size: 18, color: Colors.white54,
            ),
            onPressed: onToggleNew,
          ),
        ),
        const SizedBox(height: 16),
        _glassField(
          controller: confirmController,
          label: 'Confirmer le mot de passe',
          hint: 'Identique au champ précédent',
          icon: Icons.lock_reset_rounded,
          obscure: obscureConfirm,
          suffixIcon: IconButton(
            icon: Icon(
              obscureConfirm ? Icons.visibility_off_rounded : Icons.visibility_rounded,
              size: 18, color: Colors.white54,
            ),
            onPressed: onToggleConfirm,
          ),
        ),
        const SizedBox(height: 32),
        _primaryButton(
          label: 'CHANGER LE MOT DE PASSE',
          isLoading: isLoading,
          onPressed: onReset,
        ),
        const SizedBox(height: 40),
      ]),
    ).animate().fadeIn(delay: 100.ms).slideX(begin: 0.05, end: 0);
  }
}

// ── Shared Widgets ──────────────────────────────────────

Widget _glassField({
  required TextEditingController controller,
  required String label,
  required String hint,
  required IconData icon,
  bool obscure = false,
  TextInputType? keyboardType,
  Widget? suffixIcon,
}) {
  return Container(
    decoration: BoxDecoration(
      color: Colors.white.withOpacity(0.09),
      borderRadius: BorderRadius.circular(16),
      border: Border.all(color: Colors.white.withOpacity(0.18)),
    ),
    child: TextField(
      controller: controller,
      obscureText: obscure,
      keyboardType: keyboardType,
      style: GoogleFonts.inter(color: Colors.white, fontWeight: FontWeight.w500),
      cursorColor: AppTheme.primaryGreen,
      decoration: InputDecoration(
        labelText: label,
        hintText: hint,
        labelStyle: GoogleFonts.inter(color: Colors.white54, fontSize: 13),
        hintStyle: GoogleFonts.inter(color: Colors.white30, fontSize: 13),
        prefixIcon: Icon(icon, size: 20, color: AppTheme.primaryGreen),
        suffixIcon: suffixIcon,
        border: InputBorder.none,
        contentPadding:
            const EdgeInsets.symmetric(vertical: 18, horizontal: 16),
        floatingLabelStyle:
            GoogleFonts.inter(color: AppTheme.primaryGreen, fontSize: 12),
      ),
    ),
  );
}

Widget _primaryButton({
  required String label,
  required bool isLoading,
  required VoidCallback onPressed,
}) {
  return SizedBox(
    width: double.infinity,
    child: Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(18),
        gradient: const LinearGradient(
            colors: [AppTheme.primaryGreen, AppTheme.accentTeal]),
        boxShadow: [
          BoxShadow(
              color: AppTheme.primaryGreen.withOpacity(0.4),
              blurRadius: 20,
              offset: const Offset(0, 8))
        ],
      ),
      child: ElevatedButton(
        onPressed: isLoading ? null : onPressed,
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.transparent,
          shadowColor: Colors.transparent,
          disabledBackgroundColor: Colors.transparent,
          padding: const EdgeInsets.symmetric(vertical: 18),
          shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(18)),
        ),
        child: isLoading
            ? const SizedBox(
                width: 22,
                height: 22,
                child: CircularProgressIndicator(
                    strokeWidth: 2.5,
                    valueColor:
                        AlwaysStoppedAnimation<Color>(Colors.white)))
            : Text(label,
                style: GoogleFonts.outfit(
                    fontWeight: FontWeight.w900,
                    letterSpacing: 1.5,
                    fontSize: 14,
                    color: Colors.white)),
      ),
    ),
  );
}
