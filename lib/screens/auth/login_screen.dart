import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:lottie/lottie.dart';
import '../../theme/app_theme.dart';
import '../../widgets/glass_card.dart';
import '../../models/user_model.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({Key? key}) : super(key: key);

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  UserRole _selectedRole = UserRole.user;
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();

  void _handleLogin() {
    AuthState.login(_selectedRole);
    if (_selectedRole == UserRole.admin) {
      Navigator.pushReplacementNamed(context, '/admin');
    } else {
      Navigator.pushReplacementNamed(context, '/home');
    }
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
                            ScaleEffect(begin: const Offset(1, 1), end: const Offset(1.5, 1.5), duration: 4.seconds, curve: Curves.easeInOut),
                            FadeEffect(begin: 0.2, end: 0, duration: 4.seconds),
                          ],
                          child: Container(
                            width: 140,
                            height: 140,
                            decoration: BoxDecoration(shape: BoxShape.circle, color: AppTheme.primaryGreen.withOpacity(0.15)),
                          ),
                        ),
                        SizedBox(
                          height: 160,
                          child: Lottie.network(
                            'https://assets9.lottiefiles.com/packages/lf20_m6cu9k02.json',
                            height: 160,
                            fit: BoxFit.contain,
                            errorBuilder: (context, error, stackTrace) => const Icon(Icons.eco_rounded, size: 80, color: AppTheme.primaryGreen),
                          ),
                        ),
                      ],
                    ),
                    
                    const SizedBox(height: 24),
                    Animate(
                      effects: [FadeEffect(duration: 800.ms), SlideEffect(begin: const Offset(0, 0.1))],
                      child: Text(
                        'TriDéchet',
                        style: GoogleFonts.outfit(fontSize: 56, fontWeight: FontWeight.w900, color: AppTheme.deepSlate, letterSpacing: -1.5),
                      ),
                    ),
                    
                    Animate(
                      effects: [FadeEffect(delay: 300.ms)],
                      child: Text(
                        'Révolutionner le tri en Tunisie'.toUpperCase(),
                        style: GoogleFonts.inter(letterSpacing: 3, color: AppTheme.textMuted, fontWeight: FontWeight.w900, fontSize: 9),
                      ),
                    ),
                    
                    const SizedBox(height: 54),

                    // Modern Login Form
                    Animate(
                      effects: [FadeEffect(delay: 600.ms), SlideEffect(begin: const Offset(0, 0.05))],
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
                            _buildRoleSelector(),
                            const SizedBox(height: 40),
                            
                            TextField(
                              controller: _emailController,
                              style: GoogleFonts.inter(fontWeight: FontWeight.w600, color: AppTheme.deepSlate),
                              decoration: const InputDecoration(
                                labelText: 'Email',
                                prefixIcon: Icon(Icons.alternate_email_rounded, size: 20, color: AppTheme.primaryGreen),
                                labelStyle: TextStyle(fontWeight: FontWeight.bold),
                              ),
                            ),
                            const SizedBox(height: 24),
                            
                            TextField(
                              controller: _passwordController,
                              obscureText: true,
                              style: GoogleFonts.inter(fontWeight: FontWeight.w600, color: AppTheme.deepSlate),
                              decoration: const InputDecoration(
                                labelText: 'Mot de passe',
                                prefixIcon: Icon(Icons.lock_outline_rounded, size: 20, color: AppTheme.primaryGreen),
                                labelStyle: TextStyle(fontWeight: FontWeight.bold),
                              ),
                            ),
                            const SizedBox(height: 48),
                            
                            Animate(
                              onPlay: (controller) => controller.repeat(reverse: true),
                              effects: [ShimmerEffect(delay: 3.seconds, duration: 2.seconds, color: Colors.white24)],
                              child: Container(
                                decoration: BoxDecoration(
                                  borderRadius: BorderRadius.circular(20),
                                  boxShadow: [
                                    BoxShadow(color: AppTheme.primaryGreen.withOpacity(0.3), blurRadius: 20, offset: const Offset(0, 10))
                                  ],
                                ),
                                child: ElevatedButton(
                                  onPressed: _handleLogin,
                                  style: ElevatedButton.styleFrom(
                                    padding: const EdgeInsets.symmetric(vertical: 22),
                                    backgroundColor: AppTheme.primaryGreen,
                                    elevation: 0,
                                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                                  ),
                                  child: Text('SE CONNECTER', style: GoogleFonts.outfit(fontWeight: FontWeight.w900, letterSpacing: 2, fontSize: 13)),
                                ),
                              ),
                            ),
                            
                            const SizedBox(height: 24),
                            
                            Row(
                              children: [
                                Expanded(child: Divider(color: Colors.grey.shade200)),
                                Padding(
                                  padding: const EdgeInsets.symmetric(horizontal: 16),
                                  child: Text('OU', style: GoogleFonts.inter(fontSize: 10, fontWeight: FontWeight.bold, color: AppTheme.textMuted)),
                                ),
                                Expanded(child: Divider(color: Colors.grey.shade200)),
                              ],
                            ),
                            
                            const SizedBox(height: 24),
                            
                            OutlinedButton.icon(
                              onPressed: () {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(content: Text('Connexion Google en cours...'), behavior: SnackBarBehavior.floating),
                                );
                              },
                              icon: const FaIcon(FontAwesomeIcons.google, size: 18, color: Color(0xFFDB4437)),
                              label: Text('CONTINUER AVEC GOOGLE', style: GoogleFonts.outfit(fontWeight: FontWeight.w800, letterSpacing: 1, fontSize: 12, color: AppTheme.deepSlate)),
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
                                      style: GoogleFonts.outfit(color: AppTheme.primaryGreen, fontWeight: FontWeight.w900),
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

  Widget _buildRoleSelector() {
    return Container(
      padding: const EdgeInsets.all(6),
      decoration: BoxDecoration(
        color: AppTheme.backgroundLight,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: Colors.grey.shade100),
      ),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        physics: const BouncingScrollPhysics(),
        child: Row(
          children: UserRole.values.map((role) {
            final isSelected = _selectedRole == role;
            return GestureDetector(
              onTap: () => setState(() => _selectedRole = role),
              child: AnimatedContainer(
                duration: 400.ms,
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                curve: Curves.easeOutExpo,
                decoration: BoxDecoration(
                  color: isSelected ? Colors.white : Colors.transparent,
                  borderRadius: BorderRadius.circular(20),
                  boxShadow: isSelected ? [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10, offset: const Offset(0, 4))] : [],
                ),
                child: Text(
                  _getRoleDisplayName(role).toUpperCase(),
                  style: GoogleFonts.outfit(
                    fontSize: 10,
                    fontWeight: isSelected ? FontWeight.w900 : FontWeight.bold,
                    color: isSelected ? AppTheme.primaryGreen : AppTheme.textMuted,
                    letterSpacing: 1,
                  ),
                ),
              ),
            );
          }).toList(),
        ),
      ),
    );
  }
  String _getRoleDisplayName(UserRole role) {
    switch (role) {
      case UserRole.user:
        return 'User';
      case UserRole.admin:
        return 'Admin';
      case UserRole.educator:
        return 'Éducateur';
      case UserRole.intercommunality:
        return 'Interco';
      case UserRole.pointManager:
        return 'Gestionnaire';
      case UserRole.collector:
        return 'Collecteur';
    }
  }
}
