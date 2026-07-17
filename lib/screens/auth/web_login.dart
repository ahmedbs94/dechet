import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../../theme/app_theme.dart';
import '../../services/auth_service.dart';

/// Login web : split-screen, professionnel, ultra-premium.
class WebLoginBody extends StatefulWidget {
  final TextEditingController emailController;
  final TextEditingController passwordController;
  final bool isLoading;
  final bool obscurePassword;
  final String? errorMessage;
  final VoidCallback onLogin;
  final VoidCallback onTogglePassword;
  final VoidCallback onForgotPassword;
  final VoidCallback onGoogleSignIn;
  final VoidCallback onFacebookSignIn;
  final VoidCallback onSignUp;

  const WebLoginBody({
    Key? key,
    required this.emailController,
    required this.passwordController,
    required this.isLoading,
    required this.obscurePassword,
    required this.errorMessage,
    required this.onLogin,
    required this.onTogglePassword,
    required this.onForgotPassword,
    required this.onGoogleSignIn,
    required this.onFacebookSignIn,
    required this.onSignUp,
  }) : super(key: key);

  @override
  State<WebLoginBody> createState() => _WebLoginBodyState();
}

class _WebLoginBodyState extends State<WebLoginBody> with SingleTickerProviderStateMixin {
  late AnimationController _bgController;
  
  String _heroUsers = '...';
  String _heroWaste = '...';

  @override
  void initState() {
    super.initState();
    _bgController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 20),
    )..repeat(reverse: true);
    _loadStats();
  }

  void _loadStats() async {
    try {
      final stats = await AuthService().fetchPlatformStats();
      if (mounted && stats.isNotEmpty) {
        setState(() {
          final users = (stats['total_users'] ?? 0).toInt();
          final waste = (stats['waste_sorted_kg'] ?? 0).toInt();

          _heroUsers = '$users';
          if (users >= 1000) {
            _heroUsers = '${(users / 1000).toStringAsFixed(1)}K+';
          }
          
          _heroWaste = '$waste';
          if (waste >= 1000) {
            _heroWaste = '${(waste / 1000).toStringAsFixed(1)}K+';
          }
        });
      }
    } catch (e) {
      debugPrint('Error loading stats: $e');
    }
  }

  @override
  void dispose() {
    _bgController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      body: Stack(
        children: [
          // ── Animated Background Orbs ──
          AnimatedBuilder(
            animation: _bgController,
            builder: (context, child) {
              return Stack(
                children: [
                  Positioned(
                    top: -200 + 100 * _bgController.value,
                    right: -100 - 50 * _bgController.value,
                    child: Container(
                      width: 600,
                      height: 600,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: AppTheme.primaryGreen.withOpacity(0.05),
                      ),
                    ).animate(onPlay: (c) => c.repeat(reverse: true))
                     .scale(duration: 8.seconds, begin: const Offset(0.8, 0.8), end: const Offset(1.2, 1.2)),
                  ),
                  Positioned(
                    bottom: -300 - 100 * _bgController.value,
                    left: -200 + 150 * _bgController.value,
                    child: Container(
                      width: 800,
                      height: 800,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: AppTheme.accentTeal.withOpacity(0.04),
                      ),
                    ).animate(onPlay: (c) => c.repeat(reverse: true))
                     .scale(duration: 10.seconds, begin: const Offset(1.1, 1.1), end: const Offset(0.9, 0.9)),
                  ),
                ],
              );
            },
          ),
          
          // ── Glass Background Blur ──
          Positioned.fill(
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 80, sigmaY: 80),
              child: Container(color: Colors.transparent),
            ),
          ),

          // ── Main Content Container ──
          Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(vertical: 24),
              child: Container(
                constraints: const BoxConstraints(maxWidth: 1100),
                height: 700,
                margin: const EdgeInsets.symmetric(horizontal: 24),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.9),
                borderRadius: BorderRadius.circular(32),
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFF0F172A).withOpacity(0.12),
                    blurRadius: 60,
                    offset: const Offset(0, 24),
                  ),
                  BoxShadow(
                    color: AppTheme.primaryGreen.withOpacity(0.05),
                    blurRadius: 30,
                    spreadRadius: 10,
                  ),
                ],
                border: Border.all(color: Colors.white, width: 2),
              ),
              clipBehavior: Clip.antiAlias,
              child: Row(
                children: [
                  // ── Panneau Gauche : Illustration Premium Animée ───────────────────────────
                  Expanded(
                    flex: 5,
                    child: Container(
                      clipBehavior: Clip.antiAlias,
                      decoration: const BoxDecoration(
                        color: Color(0xFF064E3B),
                      ),
                      child: Stack(
                        fit: StackFit.expand,
                        children: [
                          // Illustration de connexion Web (login_illustration.png) avec zoom lent
                          AnimatedBuilder(
                            animation: _bgController,
                            builder: (context, child) {
                              final scale = 1.0 + (_bgController.value * 0.05);
                              return Transform.scale(
                                scale: scale,
                                child: child,
                              );
                            },
                            child: Image.asset(
                              'assets/images/login_illustration.png',
                              fit: BoxFit.cover,
                              errorBuilder: (context, error, stackTrace) => Container(
                                decoration: const BoxDecoration(
                                  gradient: LinearGradient(
                                    colors: [
                                      Color(0xFF0F2D1F),
                                      Color(0xFF0A1628),
                                    ],
                                    begin: Alignment.topLeft,
                                    end: Alignment.bottomRight,
                                  ),
                                ),
                              ),
                            ),
                          ),
                          // Overlay gradient
                          Container(
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                begin: Alignment.topCenter,
                                end: Alignment.bottomCenter,
                                colors: [
                                  const Color(0xFF0B1120).withOpacity(0.3),
                                  const Color(0xFF0B1120).withOpacity(0.8),
                                ],
                              ),
                            ),
                          ),
                          // Contenu
                          Center(
                            child: Padding(
                              padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 40),
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  // Logo avec effet glow
                                  Container(
                                    padding: const EdgeInsets.all(24),
                                    decoration: BoxDecoration(
                                      color: Colors.white.withOpacity(0.08),
                                      shape: BoxShape.circle,
                                      border: Border.all(color: Colors.white.withOpacity(0.2)),
                                      boxShadow: [
                                        BoxShadow(color: AppTheme.primaryGreen.withOpacity(0.3), blurRadius: 40, spreadRadius: 5)
                                      ],
                                    ),
                                    child: Image.asset(
                                      'assets/images/ecorewind_logo.png',
                                      width: 64,
                                      height: 64,
                                      fit: BoxFit.cover,
                                    ),
                                  ).animate().scale(begin: const Offset(0.5, 0.5), duration: 800.ms, curve: Curves.easeOutBack),
                                  
                                  const SizedBox(height: 32),
                                  
                                  FittedBox(
                                    fit: BoxFit.scaleDown,
                                    child: Text(
                                      'EcoRewind',
                                      style: GoogleFonts.spaceGrotesk(
                                        fontSize: 48,
                                        fontWeight: FontWeight.w900,
                                        color: Colors.white,
                                        letterSpacing: -1.5,
                                      ),
                                    ),
                                  ).animate().fadeIn(delay: 200.ms).slideY(begin: 0.2, end: 0, duration: 600.ms, curve: Curves.easeOutQuart),
                                  
                                  const SizedBox(height: 16),
                                  
                                  Text(
                                    'L\'excellence en gestion\néco-citoyenne des déchets.',
                                    textAlign: TextAlign.center,
                                    style: GoogleFonts.inter(
                                      fontSize: 18,
                                      color: Colors.white.withOpacity(0.8),
                                      height: 1.5,
                                      fontWeight: FontWeight.w400,
                                    ),
                                  ).animate().fadeIn(delay: 400.ms).slideY(begin: 0.2, end: 0, duration: 600.ms, curve: Curves.easeOutQuart),
                                  
                                  const SizedBox(height: 40),
                                  
                                  // Badges statistiques animés (Wrap pour éviter overflow)
                                  Wrap(
                                    alignment: WrapAlignment.center,
                                    spacing: 16,
                                    runSpacing: 16,
                                    children: [
                                      _PremiumStatBadge(value: _heroUsers, label: 'Utilisateurs')
                                          .animate().fadeIn(delay: 600.ms).slideX(begin: -0.2),
                                      _PremiumStatBadge(value: '$_heroWaste kg', label: 'Kilos Triés')
                                          .animate().fadeIn(delay: 700.ms).slideX(begin: 0.2),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),

                  // ── Panneau Droit : Formulaire Élégant ───────────────────────────────
                  Expanded(
                    flex: 6,
                    child: Container(
                      color: Colors.white,
                      child: Center(
                        child: SingleChildScrollView(
                          padding: const EdgeInsets.symmetric(horizontal: 72, vertical: 40),
                          child: ConstrainedBox(
                            constraints: const BoxConstraints(maxWidth: 420),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                Text(
                                  'Bienvenue',
                                  style: GoogleFonts.outfit(
                                    fontSize: 36,
                                    fontWeight: FontWeight.w800,
                                    color: const Color(0xFF0F172A),
                                    letterSpacing: -0.5,
                                  ),
                                ).animate().fadeIn(duration: 600.ms).slideY(begin: -0.1),
                                
                                const SizedBox(height: 8),
                                
                                Text(
                                  'Connectez-vous à votre espace personnel',
                                  style: GoogleFonts.inter(fontSize: 16, color: const Color(0xFF64748B)),
                                ).animate().fadeIn(delay: 100.ms, duration: 600.ms).slideY(begin: -0.1),
                                
                                const SizedBox(height: 48),

                                // Message d'erreur
                                if (widget.errorMessage != null) ...[
                                  Container(
                                    padding: const EdgeInsets.all(16),
                                    decoration: BoxDecoration(
                                      color: const Color(0xFFFEF2F2),
                                      borderRadius: BorderRadius.circular(16),
                                      border: Border.all(color: const Color(0xFFFECACA), width: 1.5),
                                    ),
                                    child: Row(children: [
                                      const Icon(Icons.error_outline_rounded, color: Color(0xFFEF4444), size: 20),
                                      const SizedBox(width: 12),
                                      Expanded(child: Text(widget.errorMessage!, style: GoogleFonts.inter(color: const Color(0xFFB91C1C), fontSize: 13, fontWeight: FontWeight.w500))),
                                    ]),
                                  ).animate().shakeX(hz: 3, amount: 4, duration: 400.ms),
                                  const SizedBox(height: 24),
                                ],

                                // Champ Email
                                _PremiumTextField(
                                  label: 'Adresse e-mail',
                                  controller: widget.emailController,
                                  hintText: 'nom@entreprise.com',
                                  icon: Icons.mail_outline_rounded,
                                  keyboardType: TextInputType.emailAddress,
                                  onSubmitted: (_) => widget.onLogin(),
                                ).animate().fadeIn(delay: 200.ms).slideY(begin: 0.1),
                                
                                const SizedBox(height: 24),

                                // Champ Mot de passe
                                Column(
                                  crossAxisAlignment: CrossAxisAlignment.stretch,
                                  children: [
                                    Row(
                                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                      children: [
                                        Padding(
                                          padding: const EdgeInsets.only(bottom: 8, left: 4),
                                          child: Text('Mot de passe', style: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.w600, color: const Color(0xFF334155))),
                                        ),
                                        TextButton(
                                          onPressed: widget.onForgotPassword,
                                          style: TextButton.styleFrom(padding: EdgeInsets.zero, minimumSize: Size.zero, tapTargetSize: MaterialTapTargetSize.shrinkWrap),
                                          child: Text('Oublié ?', style: GoogleFonts.inter(fontSize: 13, color: AppTheme.primaryGreen, fontWeight: FontWeight.w600)),
                                        ),
                                      ],
                                    ),
                                    TextField(
                                      controller: widget.passwordController,
                                      obscureText: widget.obscurePassword,
                                      style: GoogleFonts.inter(fontSize: 15, color: const Color(0xFF0F172A), fontWeight: FontWeight.w500),
                                      decoration: InputDecoration(
                                        hintText: '••••••••',
                                        hintStyle: GoogleFonts.inter(color: const Color(0xFF94A3B8), letterSpacing: 3),
                                        prefixIcon: const Icon(Icons.lock_outline_rounded, size: 20, color: Color(0xFF94A3B8)),
                                        suffixIcon: IconButton(
                                          icon: Icon(widget.obscurePassword ? Icons.visibility_off_rounded : Icons.visibility_rounded, size: 20, color: const Color(0xFF94A3B8)),
                                          onPressed: widget.onTogglePassword,
                                        ),
                                        filled: true,
                                        fillColor: const Color(0xFFF8FAFC),
                                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide.none),
                                        enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: const BorderSide(color: Color(0xFFE2E8F0))),
                                        focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: const BorderSide(color: AppTheme.primaryGreen, width: 2)),
                                        contentPadding: const EdgeInsets.symmetric(vertical: 20, horizontal: 16),
                                      ),
                                      onSubmitted: (_) => widget.onLogin(),
                                    ),
                                  ],
                                ).animate().fadeIn(delay: 300.ms).slideY(begin: 0.1),

                                const SizedBox(height: 40),

                                // Bouton Connexion Principal
                                SizedBox(
                                  height: 56,
                                  child: ElevatedButton(
                                    onPressed: widget.isLoading ? null : widget.onLogin,
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: const Color(0xFF0F172A),
                                      foregroundColor: Colors.white,
                                      elevation: 8,
                                      shadowColor: const Color(0xFF0F172A).withOpacity(0.3),
                                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                                    ),
                                    child: widget.isLoading
                                        ? const SizedBox(width: 24, height: 24, child: CircularProgressIndicator(strokeWidth: 2.5, color: Colors.white))
                                        : Text('Se connecter', style: GoogleFonts.outfit(fontWeight: FontWeight.bold, fontSize: 16, letterSpacing: 0.5)),
                                  ),
                                ).animate().fadeIn(delay: 400.ms).slideY(begin: 0.1),

                                const SizedBox(height: 32),

                                // Divider "Ou continuer avec"
                                Row(children: [
                                  const Expanded(child: Divider(color: Color(0xFFE2E8F0))),
                                  Padding(
                                    padding: const EdgeInsets.symmetric(horizontal: 16),
                                    child: Text('ou continuer avec', style: GoogleFonts.inter(fontSize: 13, color: const Color(0xFF94A3B8), fontWeight: FontWeight.w500)),
                                  ),
                                  const Expanded(child: Divider(color: Color(0xFFE2E8F0))),
                                ]).animate().fadeIn(delay: 500.ms),
                                
                                const SizedBox(height: 32),

                                // Social Auth Button
                                SizedBox(
                                  height: 56,
                                  child: OutlinedButton.icon(
                                    onPressed: widget.isLoading ? null : widget.onGoogleSignIn,
                                    icon: const FaIcon(FontAwesomeIcons.google, size: 18, color: Color(0xFF475569)),
                                    label: FittedBox(
                                      fit: BoxFit.scaleDown,
                                      child: Text('Continuer avec Google', style: GoogleFonts.inter(fontSize: 15, color: const Color(0xFF334155), fontWeight: FontWeight.w600)),
                                    ),
                                    style: OutlinedButton.styleFrom(
                                      backgroundColor: Colors.white,
                                      side: const BorderSide(color: Color(0xFFCBD5E1), width: 1.5),
                                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                                    ),
                                  ),
                                ).animate().fadeIn(delay: 600.ms).slideY(begin: 0.1),

                                const SizedBox(height: 40),

                                // Lien d'inscription
                                Wrap(
                                  alignment: WrapAlignment.center,
                                  crossAxisAlignment: WrapCrossAlignment.center,
                                  children: [
                                    Text('Nouveau sur EcoRewind ? ', style: GoogleFonts.inter(color: const Color(0xFF64748B), fontSize: 14)),
                                    TextButton(
                                      onPressed: widget.onSignUp,
                                      style: TextButton.styleFrom(padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4), minimumSize: Size.zero),
                                      child: Text("Créer un compte", style: GoogleFonts.inter(color: AppTheme.primaryGreen, fontWeight: FontWeight.bold, fontSize: 14)),
                                    ),
                                  ],
                                ).animate().fadeIn(delay: 700.ms),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ).animate().fadeIn(duration: 800.ms, curve: Curves.easeOutQuad).scale(begin: const Offset(0.95, 0.95)),
            ),
          ),
        ],
      ),
    );
  }
}

class _PremiumTextField extends StatelessWidget {
  final String label;
  final String hintText;
  final IconData icon;
  final TextEditingController controller;
  final TextInputType keyboardType;
  final void Function(String)? onSubmitted;

  const _PremiumTextField({
    required this.label,
    required this.hintText,
    required this.icon,
    required this.controller,
    this.keyboardType = TextInputType.text,
    this.onSubmitted,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.only(bottom: 8, left: 4),
          child: Text(label, style: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.w600, color: const Color(0xFF334155))),
        ),
        TextField(
          controller: controller,
          keyboardType: keyboardType,
          style: GoogleFonts.inter(fontSize: 15, color: const Color(0xFF0F172A), fontWeight: FontWeight.w500),
          decoration: InputDecoration(
            hintText: hintText,
            hintStyle: GoogleFonts.inter(color: const Color(0xFF94A3B8)),
            prefixIcon: Icon(icon, size: 20, color: const Color(0xFF94A3B8)),
            filled: true,
            fillColor: const Color(0xFFF8FAFC),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide.none),
            enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: const BorderSide(color: Color(0xFFE2E8F0))),
            focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: const BorderSide(color: AppTheme.primaryGreen, width: 2)),
            contentPadding: const EdgeInsets.symmetric(vertical: 20, horizontal: 16),
          ),
          onSubmitted: onSubmitted,
        ),
      ],
    );
  }
}

class _PremiumStatBadge extends StatelessWidget {
  final String value;
  final String label;
  
  const _PremiumStatBadge({required this.value, required this.label});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.08),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.white.withOpacity(0.15)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 20,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Column(
        children: [
          Text(value, style: GoogleFonts.spaceGrotesk(fontSize: 32, fontWeight: FontWeight.w900, color: Colors.white, letterSpacing: -1)),
          const SizedBox(height: 4),
          Text(label, style: GoogleFonts.inter(fontSize: 13, color: Colors.white.withOpacity(0.7), fontWeight: FontWeight.w600, letterSpacing: 1)),
        ],
      ),
    );
  }
}
