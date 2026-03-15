import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../theme/app_theme.dart';
import 'premium_widgets.dart';

class AuthGuardDialog extends StatelessWidget {
  final String? featureName;

  const AuthGuardDialog({Key? key, this.featureName}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.transparent,
      elevation: 0,
      insetPadding: const EdgeInsets.symmetric(horizontal: 24),
      child: Container(
        constraints: const BoxConstraints(maxWidth: 400),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(32),
          boxShadow: [
            BoxShadow(
              color: AppTheme.primaryGreen.withOpacity(0.15),
              blurRadius: 40,
              offset: const Offset(0, 20),
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Top accent gradient bar
            Container(
              height: 5,
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  colors: [AppTheme.primaryGreen, AppTheme.accentTeal, AppTheme.secondaryGold],
                ),
                borderRadius: BorderRadius.vertical(top: Radius.circular(32)),
              ),
            ),

            Padding(
              padding: const EdgeInsets.fromLTRB(32, 36, 32, 28),
              child: Column(
                children: [
                  // Animated Icon
                  TweenAnimationBuilder<double>(
                    tween: Tween(begin: 0.0, end: 1.0),
                    duration: const Duration(milliseconds: 600),
                    curve: Curves.elasticOut,
                    builder: (context, value, child) => Transform.scale(
                      scale: value,
                      child: child,
                    ),
                    child: Container(
                      width: 80,
                      height: 80,
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          colors: [AppTheme.primaryGreen, AppTheme.accentTeal],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                        shape: BoxShape.circle,
                        boxShadow: [
                          BoxShadow(
                            color: AppTheme.primaryGreen.withOpacity(0.3),
                            blurRadius: 24,
                            offset: const Offset(0, 10),
                          ),
                        ],
                      ),
                      child: const Icon(
                        Icons.lock_open_rounded,
                        color: Colors.white,
                        size: 36,
                      ),
                    ),
                  ),

                  const SizedBox(height: 24),

                  Text(
                    'Rejoignez EcoRewind !',
                    textAlign: TextAlign.center,
                    style: GoogleFonts.spaceGrotesk(
                      fontSize: 24,
                      fontWeight: FontWeight.w900,
                      color: AppTheme.deepNavy,
                      height: 1.2,
                    ),
                  ),

                  const SizedBox(height: 12),

                  Text(
                    featureName != null
                        ? 'Pour accéder à "$featureName" et débloquer toutes les fonctionnalités, créez votre compte gratuit.'
                        : 'Créez votre compte gratuit pour liker, commenter, gagner des points et suivre votre impact écologique.',
                    textAlign: TextAlign.center,
                    style: GoogleFonts.inter(
                      fontSize: 14,
                      color: AppTheme.textMuted,
                      height: 1.6,
                    ),
                  ),

                  const SizedBox(height: 20),

                  // Quick benefits
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: AppTheme.primaryGreen.withOpacity(0.04),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: AppTheme.primaryGreen.withOpacity(0.1)),
                    ),
                    child: Column(
                      children: [
                        _buildBenefitRow(Icons.flash_on_rounded, 'Inscription en 30 secondes'),
                        const SizedBox(height: 8),
                        _buildBenefitRow(Icons.card_giftcard_rounded, '200 points de bienvenue'),
                        const SizedBox(height: 8),
                        _buildBenefitRow(Icons.shield_rounded, '100% gratuit et sécurisé'),
                      ],
                    ),
                  ),

                  const SizedBox(height: 28),

                  PremiumButton(
                    text: 'CRÉER MON COMPTE',
                    icon: Icons.arrow_forward_rounded,
                    onPressed: () {
                      Navigator.pop(context);
                      Navigator.pushNamed(context, '/signup');
                    },
                  ),

                  const SizedBox(height: 12),

                  TextButton(
                    onPressed: () {
                      Navigator.pop(context);
                      Navigator.pushNamed(context, '/login');
                    },
                    child: RichText(
                      text: TextSpan(
                        text: 'Déjà membre ? ',
                        style: GoogleFonts.inter(
                          color: AppTheme.textMuted,
                          fontSize: 14,
                        ),
                        children: [
                          TextSpan(
                            text: 'Se connecter',
                            style: GoogleFonts.inter(
                              color: AppTheme.primaryGreen,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBenefitRow(IconData icon, String text) {
    return Row(
      children: [
        Icon(icon, color: AppTheme.primaryGreen, size: 18),
        const SizedBox(width: 10),
        Text(
          text,
          style: GoogleFonts.inter(
            color: AppTheme.deepNavy,
            fontSize: 13,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }

  /// Shows the auth guard dialog. Returns false always (for inline use).
  static bool check(BuildContext context, {String? feature}) {
    showGeneralDialog(
      context: context,
      barrierDismissible: true,
      barrierLabel: '',
      barrierColor: Colors.black45,
      transitionDuration: const Duration(milliseconds: 350),
      transitionBuilder: (context, a1, a2, widget) {
        return Transform.scale(
          scale: Curves.easeOutBack.transform(a1.value),
          child: Opacity(opacity: a1.value, child: widget),
        );
      },
      pageBuilder: (context, a1, a2) => AuthGuardDialog(featureName: feature),
    );
    return false;
  }
}
