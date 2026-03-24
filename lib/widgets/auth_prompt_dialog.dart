import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../theme/app_theme.dart';
import '../models/user_model.dart';

/// Wrapper widget qui affiche le dialogue d'auth après l'ouverture de la page.
/// Utilisation : Enveloppez n'importe quelle page avec ce widget.
///   AuthPromptWrapper(child: MaPage())
/// Le dialogue s'affiche 600ms après l'ouverture de la page.
class AuthPromptWrapper extends StatefulWidget {
  final Widget child;
  const AuthPromptWrapper({Key? key, required this.child}) : super(key: key);

  @override
  State<AuthPromptWrapper> createState() => _AuthPromptWrapperState();
}

class _AuthPromptWrapperState extends State<AuthPromptWrapper> {
  @override
  void initState() {
    super.initState();
    if (!AuthState.isLoggedIn) {
      // Attendre que la page s'affiche complètement, puis montrer le dialogue
      Future.delayed(const Duration(milliseconds: 600), () {
        if (mounted) {
          AuthPromptDialog.show(context: context);
        }
      });
    }
  }

  @override
  Widget build(BuildContext context) => widget.child;
}

/// Utilitaire global pour afficher le dialogue d'authentification.
class AuthPromptDialog {
  /// Affiche le dialogue directement (pour les actions comme poster, liker).
  /// Si l'utilisateur est connecté, ne fait rien et retourne true.
  /// Si non connecté, affiche le dialogue et retourne false.
  static bool guardAction(BuildContext context) {
    if (AuthState.isLoggedIn) return true;
    show(context: context);
    return false;
  }

  /// Affiche le bottom sheet premium avec les 3 options.
  /// - Créer un compte → /signup
  /// - J'ai déjà un compte → /login
  /// - Continuer sans compte → ferme le dialogue
  static void show({required BuildContext context}) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (ctx) => Container(
        padding: const EdgeInsets.fromLTRB(28, 8, 28, 40),
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(32)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Drag handle
            Container(
              width: 40,
              height: 4,
              margin: const EdgeInsets.only(bottom: 28),
              decoration: BoxDecoration(
                color: Colors.grey.shade300,
                borderRadius: BorderRadius.circular(2),
              ),
            ),

            // Icon with gradient glow
            Container(
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(0xFF059669), Color(0xFF2DD4BF)],
                ),
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFF059669).withOpacity(0.3),
                    blurRadius: 20,
                    offset: const Offset(0, 8),
                  ),
                ],
              ),
              child: const Icon(Icons.eco_rounded, color: Colors.white, size: 32),
            ),
            const SizedBox(height: 24),

            // Title
            Text(
              'Bienvenue sur EcoRewind',
              textAlign: TextAlign.center,
              style: GoogleFonts.spaceGrotesk(
                fontSize: 22,
                fontWeight: FontWeight.w900,
                color: AppTheme.deepNavy,
              ),
            ),
            const SizedBox(height: 8),

            // Description
            Text(
              'Connectez-vous pour profiter pleinement de toutes les fonctionnalités.',
              textAlign: TextAlign.center,
              style: GoogleFonts.inter(
                fontSize: 14,
                color: AppTheme.textMuted,
                height: 1.5,
              ),
            ),
            const SizedBox(height: 30),

            // ─── Button 1: Créer un compte ───
            SizedBox(
              width: double.infinity,
              height: 54,
              child: ElevatedButton(
                onPressed: () {
                  Navigator.pop(ctx);
                  Navigator.pushNamed(context, '/signup');
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.primaryGreen,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                  elevation: 0,
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(Icons.person_add_rounded, size: 20),
                    const SizedBox(width: 10),
                    Text(
                      'CRÉER UN COMPTE',
                      style: GoogleFonts.outfit(
                        fontWeight: FontWeight.w800,
                        fontSize: 15,
                        letterSpacing: 0.5,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 12),

            // ─── Button 2: Se connecter ───
            SizedBox(
              width: double.infinity,
              height: 54,
              child: OutlinedButton(
                onPressed: () {
                  Navigator.pop(ctx);
                  Navigator.pushNamed(context, '/login');
                },
                style: OutlinedButton.styleFrom(
                  side: BorderSide(
                      color: AppTheme.primaryGreen.withOpacity(0.3),
                      width: 1.5),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.login_rounded,
                        size: 20, color: AppTheme.primaryGreen),
                    const SizedBox(width: 10),
                    Text(
                      'J\'AI DÉJÀ UN COMPTE',
                      style: GoogleFonts.outfit(
                        fontWeight: FontWeight.w800,
                        fontSize: 15,
                        color: AppTheme.primaryGreen,
                        letterSpacing: 0.5,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 12),

            // ─── Button 3: Continuer sans compte ───
            SizedBox(
              width: double.infinity,
              height: 48,
              child: TextButton(
                onPressed: () {
                  Navigator.pop(ctx);
                },
                style: TextButton.styleFrom(
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.visibility_rounded,
                        size: 18, color: AppTheme.textMuted),
                    const SizedBox(width: 8),
                    Text(
                      'Continuer sans compte',
                      style: GoogleFonts.inter(
                        fontWeight: FontWeight.w600,
                        fontSize: 14,
                        color: AppTheme.textMuted,
                      ),
                    ),
                    const SizedBox(width: 4),
                    Icon(Icons.arrow_forward_rounded,
                        size: 16, color: AppTheme.textMuted),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
