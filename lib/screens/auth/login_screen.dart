import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:lottie/lottie.dart';
import '../../theme/app_theme.dart';
import '../../models/user_model.dart';
import '../../services/auth_service.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({Key? key}) : super(key: key);

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _authService = AuthService();
  bool _isLoading = false;
  bool _obscurePassword = true;
  String? _errorMessage;

  Future<void> _handleLogin() async {
    final email = _emailController.text.trim();
    final password = _passwordController.text.trim();

    if (email.isEmpty || password.isEmpty) {
      setState(() => _errorMessage = 'Veuillez remplir tous les champs');
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final result = await _authService.login(email, password);

      if (!mounted) return;

      if (result['success'] == true) {
        final role = result['role'] as String? ?? 'user';
        final fullName = result['full_name'] as String? ?? 'Utilisateur';
        final userEmail = result['email'] as String? ?? email;

        // Mapper le rôle du backend vers UserRole
        UserRole userRole;
        switch (role) {
          case 'admin':
            userRole = UserRole.admin;
            break;
          case 'educator':
            userRole = UserRole.educator;
            break;
          case 'intercommunality':
            userRole = UserRole.intercommunality;
            break;
          case 'pointManager':
            userRole = UserRole.pointManager;
            break;
          case 'collector':
            userRole = UserRole.collector;
            break;
          default:
            userRole = UserRole.user;
        }

        // Mettre à jour AuthState avec les vraies infos
        AuthState.currentUser = User(
          id: (result['id'] ?? 0).toString(),
          name: fullName,
          email: userEmail,
          role: userRole,
          points: 0,
        );

        // Naviguer selon le rôle
        if (userRole == UserRole.admin) {
          Navigator.pushReplacementNamed(context, '/admin');
        } else {
          Navigator.pushReplacementNamed(context, '/home');
        }
      } else {
        setState(() {
          _errorMessage = result['message'] ?? 'Email ou mot de passe incorrect';
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _errorMessage = 'Erreur de connexion. Vérifiez votre réseau.';
        });
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  /// Gère le résultat d'une authentification sociale (Google/Facebook)
  void _handleSocialAuthResult(Map<String, dynamic> result) {
    if (!mounted) return;

    if (result['success'] == true) {
      final role = result['role'] as String? ?? 'user';
      final fullName = result['full_name'] as String? ?? 'Utilisateur';
      final userEmail = result['email'] as String? ?? '';

      UserRole userRole;
      switch (role) {
        case 'admin':
          userRole = UserRole.admin;
          break;
        case 'educator':
          userRole = UserRole.educator;
          break;
        case 'intercommunality':
          userRole = UserRole.intercommunality;
          break;
        case 'pointManager':
          userRole = UserRole.pointManager;
          break;
        case 'collector':
          userRole = UserRole.collector;
          break;
        default:
          userRole = UserRole.user;
      }

      AuthState.currentUser = User(
        id: (result['id'] ?? 0).toString(),
        name: fullName,
        email: userEmail,
        role: userRole,
        points: 0,
      );

      if (userRole == UserRole.admin) {
        Navigator.pushReplacementNamed(context, '/admin');
      } else {
        Navigator.pushReplacementNamed(context, '/home');
      }
    } else {
      setState(() {
        _errorMessage = result['message'] ?? 'Erreur d\'authentification';
      });
    }
  }

  Future<void> _handleGoogleSignIn() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final result = await _authService.signInWithGoogle();
      _handleSocialAuthResult(result);
    } catch (e) {
      if (mounted) {
        setState(() => _errorMessage = 'Erreur Google Sign In : $e');
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _handleFacebookSignIn() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final result = await _authService.signInWithFacebook();
      _handleSocialAuthResult(result);
    } catch (e) {
      if (mounted) {
        setState(() => _errorMessage = 'Erreur Facebook Sign In : $e');
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _navigateToForgotPassword() {
    showDialog(
      context: context,
      builder: (context) => _ForgotPasswordDialog(authService: _authService),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          // Premium Dynamic Background
          Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [AppTheme.backgroundLight, Colors.white, AppTheme.backgroundLight.withOpacity(0.5)],
              ),
            ),
          ),

          Positioned(
            top: -150,
            right: -100,
            child: Animate(
              onPlay: (c) => c.repeat(reverse: true),
              effects: [FadeEffect(duration: 2.seconds), MoveEffect(end: const Offset(-30, 30), duration: 8.seconds)],
              child: _buildOrb(400, AppTheme.primaryGreen.withOpacity(0.06)),
            ),
          ),

          Positioned(
            bottom: -50,
            left: -100,
            child: Animate(
              onPlay: (c) => c.repeat(reverse: true),
              effects: [FadeEffect(delay: 500.ms), MoveEffect(end: const Offset(30, -30), duration: 10.seconds)],
              child: _buildOrb(300, AppTheme.accentMint.withOpacity(0.04)),
            ),
          ),

          SafeArea(
            child: Center(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(horizontal: 32),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    // Premium Brand Section
                    Stack(
                      alignment: Alignment.center,
                      children: [
                        Animate(
                          onPlay: (c) => c.repeat(),
                          effects: [
                            ScaleEffect(
                                begin: const Offset(1, 1),
                                end: const Offset(1.5, 1.5),
                                duration: 4.seconds,
                                curve: Curves.easeInOut),
                            FadeEffect(begin: 0.2, end: 0, duration: 4.seconds),
                          ],
                          child: Container(
                            width: 140,
                            height: 140,
                            decoration:
                                BoxDecoration(shape: BoxShape.circle, color: AppTheme.primaryGreen.withOpacity(0.15)),
                          ),
                        ),
                        SizedBox(
                          height: 160,
                          child: Lottie.network(
                            'https://assets9.lottiefiles.com/packages/lf20_m6cu9k02.json',
                            height: 160,
                            fit: BoxFit.contain,
                            errorBuilder: (context, error, stackTrace) =>
                                const Icon(Icons.eco_rounded, size: 80, color: AppTheme.primaryGreen),
                          ),
                        ),
                      ],
                    ),

                    const SizedBox(height: 24),
                    Animate(
                      effects: [FadeEffect(duration: 800.ms), const SlideEffect(begin: Offset(0, 0.1))],
                      child: Text(
                        'EcoRewind',
                        style: GoogleFonts.outfit(
                            fontSize: 56, fontWeight: FontWeight.w900, color: AppTheme.deepSlate, letterSpacing: -1.5),
                      ),
                    ),

                    Animate(
                      effects: [FadeEffect(delay: 300.ms)],
                      child: Text(
                        'Révolutionner le tri en Tunisie'.toUpperCase(),
                        style: GoogleFonts.inter(
                            letterSpacing: 3, color: AppTheme.textMuted, fontWeight: FontWeight.w900, fontSize: 9),
                      ),
                    ),

                    const SizedBox(height: 54),

                    // Modern Login Form — PAS de sélecteur de rôle
                    Animate(
                      effects: [FadeEffect(delay: 600.ms), const SlideEffect(begin: Offset(0, 0.05))],
                      child: Container(
                        padding: const EdgeInsets.all(32),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(AppTheme.borderRadiusLarge),
                          boxShadow: AppTheme.premiumShadow,
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            // Titre du formulaire
                            Text(
                              'Connexion',
                              style: GoogleFonts.outfit(
                                  fontSize: 24, fontWeight: FontWeight.w800, color: AppTheme.deepSlate),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              'Connectez-vous avec votre compte',
                              style: GoogleFonts.inter(fontSize: 13, color: AppTheme.textMuted),
                            ),
                            const SizedBox(height: 32),

                            // Message d'erreur
                            if (_errorMessage != null) ...[
                              Container(
                                padding: const EdgeInsets.all(12),
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
                                      child: Text(
                                        _errorMessage!,
                                        style: GoogleFonts.inter(color: Colors.red.shade700, fontSize: 13),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(height: 20),
                            ],

                            TextField(
                              controller: _emailController,
                              keyboardType: TextInputType.emailAddress,
                              style: GoogleFonts.inter(fontWeight: FontWeight.w600, color: AppTheme.deepSlate),
                              decoration: const InputDecoration(
                                labelText: 'Email',
                                prefixIcon: Icon(Icons.alternate_email_rounded, size: 20, color: AppTheme.primaryGreen),
                                labelStyle: TextStyle(fontWeight: FontWeight.bold),
                              ),
                              onSubmitted: (_) => _handleLogin(),
                            ),
                            const SizedBox(height: 24),

                            TextField(
                              controller: _passwordController,
                              obscureText: _obscurePassword,
                              style: GoogleFonts.inter(fontWeight: FontWeight.w600, color: AppTheme.deepSlate),
                              decoration: InputDecoration(
                                labelText: 'Mot de passe',
                                prefixIcon:
                                    const Icon(Icons.lock_outline_rounded, size: 20, color: AppTheme.primaryGreen),
                                labelStyle: const TextStyle(fontWeight: FontWeight.bold),
                                suffixIcon: IconButton(
                                  icon: Icon(
                                    _obscurePassword ? Icons.visibility_off_rounded : Icons.visibility_rounded,
                                    size: 20,
                                    color: AppTheme.textMuted,
                                  ),
                                  onPressed: () => setState(() => _obscurePassword = !_obscurePassword),
                                ),
                              ),
                              onSubmitted: (_) => _handleLogin(),
                            ),

                            // Mot de passe oublié
                            Align(
                              alignment: Alignment.centerRight,
                              child: TextButton(
                                onPressed: _navigateToForgotPassword,
                                style: TextButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 8)),
                                child: Text(
                                  'Mot de passe oublié ?',
                                  style: GoogleFonts.inter(
                                      fontSize: 12, color: AppTheme.primaryGreen, fontWeight: FontWeight.w600),
                                ),
                              ),
                            ),

                            const SizedBox(height: 16),

                            Animate(
                              onPlay: (controller) => controller.repeat(reverse: true),
                              effects: [ShimmerEffect(delay: 3.seconds, duration: 2.seconds, color: Colors.white24)],
                              child: Container(
                                decoration: BoxDecoration(
                                  borderRadius: BorderRadius.circular(20),
                                  boxShadow: [
                                    BoxShadow(
                                        color: AppTheme.primaryGreen.withOpacity(0.3),
                                        blurRadius: 20,
                                        offset: const Offset(0, 10))
                                  ],
                                ),
                                child: ElevatedButton(
                                  onPressed: _isLoading ? null : _handleLogin,
                                  style: ElevatedButton.styleFrom(
                                    padding: const EdgeInsets.symmetric(vertical: 22),
                                    backgroundColor: AppTheme.primaryGreen,
                                    disabledBackgroundColor: AppTheme.primaryGreen.withOpacity(0.6),
                                    elevation: 0,
                                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                                  ),
                                  child: _isLoading
                                      ? const SizedBox(
                                          width: 24,
                                          height: 24,
                                          child: CircularProgressIndicator(
                                            strokeWidth: 2.5,
                                            valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                                          ),
                                        )
                                      : Text('SE CONNECTER',
                                          style: GoogleFonts.outfit(
                                              fontWeight: FontWeight.w900, letterSpacing: 2, fontSize: 13)),
                                ),
                              ),
                            ),

                            const SizedBox(height: 24),

                            Row(
                              children: [
                                Expanded(child: Divider(color: Colors.grey.shade200)),
                                Padding(
                                  padding: const EdgeInsets.symmetric(horizontal: 16),
                                  child: Text('OU',
                                      style: GoogleFonts.inter(
                                          fontSize: 10, fontWeight: FontWeight.bold, color: AppTheme.textMuted)),
                                ),
                                Expanded(child: Divider(color: Colors.grey.shade200)),
                              ],
                            ),

                            const SizedBox(height: 24),

                            OutlinedButton.icon(
                              onPressed: _isLoading ? null : _handleGoogleSignIn,
                              icon: const FaIcon(FontAwesomeIcons.google, size: 18, color: Color(0xFFDB4437)),
                              label: Text('CONTINUER AVEC GOOGLE',
                                  style: GoogleFonts.outfit(
                                      fontWeight: FontWeight.w800,
                                      letterSpacing: 1,
                                      fontSize: 12,
                                      color: AppTheme.deepSlate)),
                              style: OutlinedButton.styleFrom(
                                padding: const EdgeInsets.symmetric(vertical: 18),
                                side: BorderSide(color: Colors.grey.shade200),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                              ),
                            ),

                            const SizedBox(height: 12),

                            OutlinedButton.icon(
                              onPressed: _isLoading ? null : _handleFacebookSignIn,
                              icon: const FaIcon(FontAwesomeIcons.facebook, size: 18, color: Color(0xFF1877F2)),
                              label: Text('CONTINUER AVEC FACEBOOK',
                                  style: GoogleFonts.outfit(
                                      fontWeight: FontWeight.w800,
                                      letterSpacing: 1,
                                      fontSize: 12,
                                      color: AppTheme.deepSlate)),
                              style: OutlinedButton.styleFrom(
                                padding: const EdgeInsets.symmetric(vertical: 18),
                                side: BorderSide(color: Colors.grey.shade200),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                              ),
                            ),

                            const SizedBox(height: 32),
                            TextButton(
                              onPressed: () => Navigator.pushNamed(context, '/signup'),
                              child: RichText(
                                text: TextSpan(
                                  text: 'Pas encore de compte ? ',
                                  style: GoogleFonts.inter(color: AppTheme.textMuted, fontSize: 13),
                                  children: [
                                    TextSpan(
                                      text: 'S\'inscrire',
                                      style:
                                          GoogleFonts.outfit(color: AppTheme.primaryGreen, fontWeight: FontWeight.w900),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildOrb(double size, Color color) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: RadialGradient(colors: [color, Colors.transparent]),
      ),
    );
  }
}

// Dialog Mot de Passe Oublié — 3 étapes
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
  
  // 0 = email, 1 = code + new password, 2 = succès
  int _step = 0;

  Future<void> _sendResetEmail() async {
    final email = _emailController.text.trim();
    if (email.isEmpty) {
      setState(() { _message = 'Veuillez entrer votre email'; _isError = true; });
      return;
    }

    setState(() { _isLoading = true; _message = null; });

    try {
      await widget.authService.forgotPassword(email);
      if (mounted) {
        setState(() {
          _isLoading = false;
          _step = 1; // Passer à l'étape de saisie du code
          _message = 'Un code a été envoyé à $email. Vérifiez votre boîte mail.';
          _isError = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _message = 'Erreur réseau. Réessayez plus tard.';
          _isError = true;
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _resetPassword() async {
    final code = _codeController.text.trim();
    final newPassword = _newPasswordController.text;
    final confirmPassword = _confirmPasswordController.text;

    if (code.isEmpty) {
      setState(() { _message = 'Veuillez entrer le code reçu par email'; _isError = true; });
      return;
    }
    if (newPassword.isEmpty) {
      setState(() { _message = 'Veuillez entrer un nouveau mot de passe'; _isError = true; });
      return;
    }
    if (newPassword.length < 6) {
      setState(() { _message = 'Le mot de passe doit contenir au moins 6 caractères'; _isError = true; });
      return;
    }
    if (newPassword != confirmPassword) {
      setState(() { _message = 'Les mots de passe ne correspondent pas'; _isError = true; });
      return;
    }

    setState(() { _isLoading = true; _message = null; });

    try {
      final result = await widget.authService.resetPassword(code, newPassword);
      if (mounted) {
        if (result['success'] == true) {
          // Connexion automatique avec le nouveau mot de passe
          final email = _emailController.text.trim();
          final loginResult = await widget.authService.login(email, newPassword);
          
          if (mounted) {
            if (loginResult['success'] == true) {
              final role = loginResult['role'] as String? ?? 'user';
              final fullName = loginResult['full_name'] as String? ?? 'Utilisateur';
              final userEmail = loginResult['email'] as String? ?? email;

              UserRole userRole;
              switch (role) {
                case 'admin': userRole = UserRole.admin; break;
                case 'educator': userRole = UserRole.educator; break;
                case 'intercommunality': userRole = UserRole.intercommunality; break;
                case 'pointManager': userRole = UserRole.pointManager; break;
                case 'collector': userRole = UserRole.collector; break;
                default: userRole = UserRole.user;
              }

              AuthState.currentUser = User(
                id: (loginResult['id'] ?? 0).toString(),
                name: fullName,
                email: userEmail,
                role: userRole,
                points: 0,
              );

              Navigator.pop(context); // Fermer le dialog
              if (userRole == UserRole.admin) {
                Navigator.pushReplacementNamed(context, '/admin');
              } else {
                Navigator.pushReplacementNamed(context, '/home');
              }
              return;
            }
          }
          // Si la connexion auto échoue, afficher le succès classique
          if (mounted) {
            setState(() {
              _isLoading = false;
              _step = 2;
              _message = null;
              _isError = false;
            });
          }
        } else {
          setState(() {
            _isLoading = false;
            _message = result['message'] ?? 'Code invalide ou expiré';
            _isError = true;
          });
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _message = 'Erreur réseau. Réessayez plus tard.';
          _isError = true;
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      title: Row(
        children: [
          if (_step == 1)
            IconButton(
              icon: const Icon(Icons.arrow_back_rounded, size: 20),
              onPressed: () => setState(() { _step = 0; _message = null; }),
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(),
            ),
          if (_step == 1) const SizedBox(width: 8),
          Icon(
            _step == 2 ? Icons.check_circle_rounded : Icons.lock_reset_rounded,
            color: _step == 2 ? AppTheme.primaryGreen : AppTheme.primaryGreen,
            size: 28,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              _step == 0 ? 'Mot de passe oublié'
                : _step == 1 ? 'Réinitialisation'
                : 'Mot de passe modifié !',
              style: GoogleFonts.outfit(fontWeight: FontWeight.bold, fontSize: 18),
            ),
          ),
        ],
      ),
      content: AnimatedSwitcher(
        duration: const Duration(milliseconds: 300),
        child: _step == 0 ? _buildStepEmail()
             : _step == 1 ? _buildStepCode()
             : _buildStepSuccess(),
      ),
      actions: _step == 2
          ? [
              ElevatedButton(
                onPressed: () => Navigator.pop(context),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.primaryGreen,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 12),
                ),
                child: Text('Retour à la connexion', style: GoogleFonts.outfit(fontWeight: FontWeight.bold)),
              ),
            ]
          : [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: Text('Annuler', style: GoogleFonts.inter(color: AppTheme.textMuted)),
              ),
              ElevatedButton(
                onPressed: _isLoading ? null : (_step == 0 ? _sendResetEmail : _resetPassword),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.primaryGreen,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                child: _isLoading
                    ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                    : Text(
                        _step == 0 ? 'Envoyer le code' : 'Changer le mot de passe',
                        style: GoogleFonts.outfit(fontWeight: FontWeight.bold),
                      ),
              ),
            ],
    );
  }

  // Étape 1 : Saisir l'email
  Widget _buildStepEmail() {
    return Column(
      key: const ValueKey('step_email'),
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Entrez votre email pour recevoir un code de réinitialisation.',
          style: GoogleFonts.inter(fontSize: 13, color: AppTheme.textMuted),
        ),
        const SizedBox(height: 16),
        TextField(
          controller: _emailController,
          keyboardType: TextInputType.emailAddress,
          decoration: InputDecoration(
            labelText: 'Email',
            prefixIcon: const Icon(Icons.email_outlined, color: AppTheme.primaryGreen),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
          ),
        ),
        if (_message != null) ...[
          const SizedBox(height: 12),
          _buildMessage(),
        ],
      ],
    );
  }

  // Étape 2 : Saisir le code + nouveau mot de passe
  Widget _buildStepCode() {
    return Column(
      key: const ValueKey('step_code'),
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Message de succès d'envoi
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: AppTheme.primaryGreen.withOpacity(0.08),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: AppTheme.primaryGreen.withOpacity(0.2)),
          ),
          child: Row(
            children: [
              Icon(Icons.mark_email_read_rounded, color: AppTheme.primaryGreen, size: 20),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  'Code envoyé à ${_emailController.text.trim()}',
                  style: GoogleFonts.inter(fontSize: 12, color: AppTheme.primaryGreen, fontWeight: FontWeight.w600),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 20),
        
        // Champ du code
        TextField(
          controller: _codeController,
          decoration: InputDecoration(
            labelText: 'Code de réinitialisation',
            hintText: 'Collez le code reçu par email',
            prefixIcon: const Icon(Icons.vpn_key_rounded, color: AppTheme.primaryGreen),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
          ),
          style: GoogleFonts.inter(fontWeight: FontWeight.w600, letterSpacing: 0.5),
        ),
        const SizedBox(height: 16),
        
        // Nouveau mot de passe
        TextField(
          controller: _newPasswordController,
          obscureText: _obscureNew,
          decoration: InputDecoration(
            labelText: 'Nouveau mot de passe',
            prefixIcon: const Icon(Icons.lock_outline_rounded, color: AppTheme.primaryGreen),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
            suffixIcon: IconButton(
              icon: Icon(_obscureNew ? Icons.visibility_off_rounded : Icons.visibility_rounded, size: 20, color: AppTheme.textMuted),
              onPressed: () => setState(() => _obscureNew = !_obscureNew),
            ),
          ),
        ),
        const SizedBox(height: 16),
        
        // Confirmer le mot de passe
        TextField(
          controller: _confirmPasswordController,
          obscureText: _obscureConfirm,
          decoration: InputDecoration(
            labelText: 'Confirmer le mot de passe',
            prefixIcon: const Icon(Icons.lock_outline_rounded, color: AppTheme.primaryGreen),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
            suffixIcon: IconButton(
              icon: Icon(_obscureConfirm ? Icons.visibility_off_rounded : Icons.visibility_rounded, size: 20, color: AppTheme.textMuted),
              onPressed: () => setState(() => _obscureConfirm = !_obscureConfirm),
            ),
          ),
        ),

        if (_message != null) ...[
          const SizedBox(height: 12),
          _buildMessage(),
        ],

        const SizedBox(height: 8),
        TextButton(
          onPressed: _isLoading ? null : _sendResetEmail,
          child: Text(
            'Renvoyer le code',
            style: GoogleFonts.inter(fontSize: 12, color: AppTheme.primaryGreen, fontWeight: FontWeight.w600),
          ),
        ),
      ],
    );
  }

  // Étape 3 : Succès
  Widget _buildStepSuccess() {
    return Column(
      key: const ValueKey('step_success'),
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: AppTheme.primaryGreen.withOpacity(0.08),
            shape: BoxShape.circle,
          ),
          child: Icon(Icons.check_rounded, color: AppTheme.primaryGreen, size: 48),
        ),
        const SizedBox(height: 20),
        Text(
          'Votre mot de passe a été modifié avec succès !',
          textAlign: TextAlign.center,
          style: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.w600, color: AppTheme.primaryGreen),
        ),
        const SizedBox(height: 8),
        Text(
          'Vous pouvez maintenant vous connecter avec votre nouveau mot de passe.',
          textAlign: TextAlign.center,
          style: GoogleFonts.inter(fontSize: 13, color: AppTheme.textMuted),
        ),
      ],
    );
  }

  Widget _buildMessage() {
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: _isError ? Colors.red.shade50 : AppTheme.primaryGreen.withOpacity(0.08),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        children: [
          Icon(
            _isError ? Icons.error_outline : Icons.info_outline,
            color: _isError ? Colors.red.shade400 : AppTheme.primaryGreen,
            size: 18,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              _message!,
              style: GoogleFonts.inter(
                fontSize: 12,
                color: _isError ? Colors.red.shade700 : AppTheme.primaryGreen,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
