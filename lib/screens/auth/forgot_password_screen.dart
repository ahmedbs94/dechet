import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'dart:ui';

import '../../theme/app_theme.dart';
import '../../services/auth_service.dart';
import '../../models/user_model.dart';
import '../../widgets/premium_widgets.dart';

class ForgotPasswordScreen extends StatefulWidget {
  const ForgotPasswordScreen({Key? key}) : super(key: key);

  @override
  State<ForgotPasswordScreen> createState() => _ForgotPasswordScreenState();
}

class _ForgotPasswordScreenState extends State<ForgotPasswordScreen> {
  final _emailController = TextEditingController();
  final _tokenController = TextEditingController();
  final _newPasswordController = TextEditingController();
  final _authService = AuthService();

  bool _isLoading = false;
  bool _tokenSent = false;

  @override
  void dispose() {
    _emailController.dispose();
    _tokenController.dispose();
    _newPasswordController.dispose();
    super.dispose();
  }

  Future<void> _handleForgotPassword() async {
    final email = _emailController.text.trim();
    if (email.isEmpty) {
      _showMessage('Veuillez entrer votre email', isError: true);
      return;
    }

    setState(() => _isLoading = true);
    try {
      final result = await _authService.forgotPassword(email);
      if (result['success']) {
        setState(() => _tokenSent = true);
        _showMessage('Token envoyé à votre adresse (Vérifiez la console)');
      } else {
        _showMessage(result['message'] ?? 'Erreur lors de l\'envoi', isError: true);
      }
    } catch (e) {
      _showMessage('Erreur réseau', isError: true);
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _handleResetPassword() async {
    final token = _tokenController.text.trim();
    final newPassword = _newPasswordController.text.trim();
    final email = _emailController.text.trim();

    if (token.isEmpty || newPassword.isEmpty) {
      _showMessage('Veuillez remplir tous les champs', isError: true);
      return;
    }

    if (newPassword.length < 6) {
      _showMessage('Le mot de passe doit contenir au moins 6 caractères', isError: true);
      return;
    }

    setState(() => _isLoading = true);
    try {
      final result = await _authService.resetPassword(token, newPassword);
      if (result['success']) {
        // Tentative de connexion automatique après reset
        final loginResult = await _authService.login(email, newPassword);

        if (loginResult['success']) {
          final userRoleStr = loginResult['role'] as String;
          UserRole role = UserRole.values.firstWhere(
            (e) => e.toString().split('.').last == userRoleStr,
            orElse: () => UserRole.user,
          );

          final user = User(
            id: loginResult['id'].toString(),
            name: loginResult['full_name'] ?? 'Utilisateur',
            email: email,
            role: role,
            avatarUrl: loginResult['avatar_url'] ?? 'https://i.pravatar.cc/300?u=$email',
          );

          AuthState.currentUser = user;

          if (!mounted) return;
          _showMessage('Mot de passe mis à jour ! Bienvenue.');

          // Navigation vers l'accueil en retirant l'historique de navigation
          Navigator.pushNamedAndRemoveUntil(context, '/home', (route) => false);
        } else {
          // Fallback : Retour au login si la connexion auto échoue
          if (!mounted) return;
          _showMessage('Mot de passe mis à jour ! Veuillez vous connecter.');
          Navigator.pop(context);
        }
      } else {
        if (!mounted) return;
        _showMessage(result['message'] ?? 'Token invalide ou expiré', isError: true);
      }
    } catch (e) {
      if (!mounted) return;
      _showMessage('Erreur réseau', isError: true);
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _showMessage(String message, {bool isError = false}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message, style: GoogleFonts.manrope(fontWeight: FontWeight.w600)),
        backgroundColor: isError ? AppTheme.errorRed : AppTheme.primaryGreen,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        margin: const EdgeInsets.all(16),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.backgroundSoft,
      body: Stack(
        children: [
          _buildSophisticatedBackground(),
          SafeArea(
            child: Column(
              children: [
                // Back Button
                Align(
                  alignment: Alignment.centerLeft,
                  child: Padding(
                    padding: const EdgeInsets.all(24.0),
                    child: GestureDetector(
                      onTap: () => Navigator.pop(context),
                      child: Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          shape: BoxShape.circle,
                          boxShadow: AppTheme.tightShadow,
                        ),
                        child: const Icon(Icons.arrow_back_ios_new_rounded, size: 18, color: AppTheme.deepNavy),
                      ),
                    ),
                  ),
                ).animate().fadeIn().slideX(begin: -0.2, end: 0),

                Expanded(
                  child: Center(
                    child: SingleChildScrollView(
                      padding: const EdgeInsets.symmetric(horizontal: 24),
                      child: Container(
                        constraints: const BoxConstraints(maxWidth: 440),
                        child: PremiumGlassCard(
                          padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 56),
                          borderRadius: 40,
                          blur: 25,
                          child: AnimatedSwitcher(
                            duration: const Duration(milliseconds: 500),
                            child: _tokenSent ? _buildResetForm() : _buildEmailForm(),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmailForm() {
    return Column(
      key: const ValueKey('email_form'),
      mainAxisSize: MainAxisSize.min,
      children: [
        const Icon(Icons.lock_reset_rounded, size: 60, color: AppTheme.primaryGreen)
            .animate()
            .scale(duration: 600.ms, curve: Curves.elasticOut),
        const SizedBox(height: 24),
        Text(
          'Mot de passe oublié ?',
          textAlign: TextAlign.center,
          style: GoogleFonts.outfit(
            fontSize: 28,
            fontWeight: FontWeight.w800,
            color: AppTheme.deepNavy,
            letterSpacing: -0.8,
          ),
        ),
        const SizedBox(height: 12),
        Text(
          'Entrez votre email pour recevoir votre code de récupération.',
          textAlign: TextAlign.center,
          style: GoogleFonts.manrope(
            fontSize: 15,
            color: AppTheme.textMuted,
            fontWeight: FontWeight.w500,
          ),
        ),
        const SizedBox(height: 40),
        PremiumGlassTextField(
          controller: _emailController,
          label: 'Email',
          hint: 'votre@email.com',
          icon: Icons.alternate_email_rounded,
          keyboardType: TextInputType.emailAddress,
        ),
        const SizedBox(height: 32),
        PremiumButton(
          text: 'ENVOYER LE CODE',
          onPressed: _handleForgotPassword,
          isLoading: _isLoading,
        ),
      ],
    );
  }

  Widget _buildResetForm() {
    return Column(
      key: const ValueKey('reset_form'),
      mainAxisSize: MainAxisSize.min,
      children: [
        const Icon(Icons.verified_user_rounded, size: 60, color: AppTheme.accentTeal)
            .animate()
            .scale(duration: 600.ms, curve: Curves.elasticOut),
        const SizedBox(height: 24),
        Text(
          'Nouveau mot de passe',
          textAlign: TextAlign.center,
          style: GoogleFonts.outfit(
            fontSize: 28,
            fontWeight: FontWeight.w800,
            color: AppTheme.deepNavy,
            letterSpacing: -0.8,
          ),
        ),
        const SizedBox(height: 12),
        Text(
          'Saisissez le code reçu et votre nouveau mot de passe.',
          textAlign: TextAlign.center,
          style: GoogleFonts.manrope(
            fontSize: 15,
            color: AppTheme.textMuted,
            fontWeight: FontWeight.w500,
          ),
        ),
        const SizedBox(height: 40),
        PremiumGlassTextField(
          controller: _tokenController,
          label: 'Code de récupération',
          hint: 'Entrez le code ici',
          icon: Icons.vpn_key_outlined,
        ),
        const SizedBox(height: 16),
        PremiumGlassTextField(
          controller: _newPasswordController,
          label: 'Nouveau mot de passe',
          hint: 'Minimum 6 caractères',
          icon: Icons.lock_outline_rounded,
          obscureText: true,
        ),
        const SizedBox(height: 32),
        PremiumButton(
          text: 'RÉINITIALISER',
          onPressed: _handleResetPassword,
          isLoading: _isLoading,
        ),
        const SizedBox(height: 16),
        TextButton(
          onPressed: () => setState(() => _tokenSent = false),
          child: Text(
            'Renvoyer un code',
            style: GoogleFonts.manrope(
              color: AppTheme.primaryGreen,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildSophisticatedBackground() {
    return Stack(
      children: [
        Container(color: AppTheme.deepNavy),
        Positioned(
          top: -200,
          right: -100,
          child: _buildBlob(size: 600, color: AppTheme.primaryGreen.withOpacity(0.3)),
        )
            .animate(onPlay: (c) => c.repeat(reverse: true))
            .move(begin: const Offset(0, 0), end: const Offset(-50, 100), duration: 20.seconds),
        Positioned(
          bottom: -150,
          left: -100,
          child: _buildBlob(size: 500, color: AppTheme.accentTeal.withOpacity(0.2)),
        )
            .animate(onPlay: (c) => c.repeat(reverse: true))
            .move(begin: const Offset(0, 0), end: const Offset(50, -100), duration: 25.seconds),
        Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [
                AppTheme.deepNavy.withOpacity(0.7),
                AppTheme.deepNavy.withOpacity(0.9),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildBlob({required double size, required Color color}) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(shape: BoxShape.circle, color: color),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 120, sigmaY: 120),
        child: Container(color: Colors.transparent),
      ),
    );
  }
}
