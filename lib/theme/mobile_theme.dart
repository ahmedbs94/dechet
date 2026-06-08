import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'app_theme.dart';

/// Thème mobile Pinterest-like : dark, rounded, immersif, moderne.
class MobileTheme {
  // ── Couleurs Mobile ────────────────────────────────────────────────────────
  static const Color bgDark = Color(0xFF0F172A);
  static const Color bgDarkAlt = Color(0xFF1a1a2e);
  static const Color surfaceDark = Color(0xFF1E293B);
  static const Color cardBg = Color(0xFF16213E);
  static const Color inputBg = Colors.white;
  static const Color inputBorder = Color(0xFFE2E8F0);

  // Tokens de forme
  static const double cardRadius = 24.0;
  static const double inputRadius = 16.0;
  static const double buttonRadius = 18.0;

  // Ombres
  static List<BoxShadow> cardShadow = [
    BoxShadow(
      color: Colors.black.withOpacity(0.15),
      blurRadius: 24,
      offset: const Offset(0, 12),
    ),
  ];

  static List<BoxShadow> inputShadow = [
    BoxShadow(
      color: Colors.black.withOpacity(0.08),
      blurRadius: 10,
      offset: const Offset(0, 4),
    ),
  ];

  static BoxDecoration get cardDecoration => BoxDecoration(
        color: Colors.white.withOpacity(0.07),
        borderRadius: BorderRadius.circular(cardRadius),
        border: Border.all(color: Colors.white.withOpacity(0.1)),
        boxShadow: cardShadow,
      );

  static BoxDecoration get inputDecoration => BoxDecoration(
        color: inputBg,
        borderRadius: BorderRadius.circular(inputRadius),
        border: Border.all(color: inputBorder),
        boxShadow: inputShadow,
      );

  static BoxDecoration get gradientButtonDecoration => BoxDecoration(
        borderRadius: BorderRadius.circular(buttonRadius),
        gradient: const LinearGradient(
          colors: [AppTheme.primaryGreen, AppTheme.accentTeal],
        ),
        boxShadow: [
          BoxShadow(
            color: AppTheme.primaryGreen.withOpacity(0.35),
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
        ],
      );

  /// ThemeData complet pour mobile
  static ThemeData get theme => ThemeData(
        useMaterial3: true,
        brightness: Brightness.dark,
        scaffoldBackgroundColor: bgDark,
        primaryColor: AppTheme.primaryGreen,
        colorScheme: const ColorScheme.dark(
          primary: AppTheme.primaryGreen,
          secondary: AppTheme.accentTeal,
          surface: surfaceDark,
          error: AppTheme.errorRed,
        ),
        textTheme: TextTheme(
          displayLarge: GoogleFonts.spaceGrotesk(
            fontSize: 42,
            fontWeight: FontWeight.w900,
            color: Colors.white,
            letterSpacing: -1.5,
          ),
          headlineMedium: GoogleFonts.spaceGrotesk(
            fontSize: 28,
            fontWeight: FontWeight.w800,
            color: Colors.white,
            letterSpacing: -0.5,
          ),
          titleLarge: GoogleFonts.outfit(
            fontSize: 22,
            fontWeight: FontWeight.w700,
            color: Colors.white,
          ),
          bodyLarge: GoogleFonts.inter(
            fontSize: 16,
            color: Colors.white.withOpacity(0.9),
            height: 1.6,
          ),
          bodyMedium: GoogleFonts.inter(
            fontSize: 14,
            color: Colors.white.withOpacity(0.6),
          ),
          labelSmall: GoogleFonts.inter(
            fontSize: 11,
            fontWeight: FontWeight.w600,
            color: Colors.white.withOpacity(0.4),
            letterSpacing: 1,
          ),
        ),
        elevatedButtonTheme: ElevatedButtonThemeData(
          style: ElevatedButton.styleFrom(
            backgroundColor: AppTheme.primaryGreen,
            foregroundColor: Colors.white,
            elevation: 0,
            padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 18),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(buttonRadius),
            ),
            textStyle: GoogleFonts.outfit(
              fontWeight: FontWeight.w900,
              fontSize: 14,
              letterSpacing: 1.5,
            ),
          ),
        ),
        inputDecorationTheme: InputDecorationTheme(
          filled: true,
          fillColor: Colors.white,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(inputRadius),
            borderSide: BorderSide.none,
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(inputRadius),
            borderSide: BorderSide.none,
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(inputRadius),
            borderSide: const BorderSide(
              color: AppTheme.primaryGreen,
              width: 2,
            ),
          ),
          contentPadding:
              const EdgeInsets.symmetric(vertical: 18, horizontal: 16),
          labelStyle: GoogleFonts.inter(
            color: const Color(0xFF94A3B8),
            fontSize: 13,
          ),
          floatingLabelStyle: GoogleFonts.inter(
            color: AppTheme.primaryGreen,
            fontSize: 13,
            fontWeight: FontWeight.w600,
          ),
        ),
      );
}
