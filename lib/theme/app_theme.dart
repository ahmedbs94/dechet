import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class AppTheme {
  // --- Elegant & Professional Color Palette ---
  static const Color primaryGreen = Color(0xFF00B894);
  static const Color accentMint = Color(0xFF55E6C1);
  static const Color deepSlate = Color(0xFF0F172A);
  static const Color backgroundLight = Color(0xFFF8FAFC);
  static const Color surfaceWhite = Color(0xFFFFFFFF);
  static const Color textMain = Color(0xFF1E293B);
  static const Color textMuted = Color(0xFF64748B);
  static const Color errorRed = Color(0xFFFF4D4F);

  // Extended color palette used across the app
  static const Color deepNavy = Color(0xFF0F172A); // Deep dark blue for headings/emphasis
  static const Color accentTeal = Color(0xFF00D2A8); // Teal accent for gradients
  static const Color backgroundSoft = Color(0xFFF1F5F9); // Soft grey background
  static const Color secondaryGold = Color(0xFFF59E0B); // Gold/amber secondary color
  static const Color gradientStart = Color(0xFF00B894); // Gradient start (matches primaryGreen)
  static const Color gradientEnd = Color(0xFF00D2A8); // Gradient end (matches accentTeal)
  static const Color successLeaf = Color(0xFF10B981); // Success green for positive indicators

  // Custom Design Tokens
  static const double borderRadiusLarge = 32.0;
  static const double borderRadiusMedium = 20.0;

  static List<BoxShadow> premiumShadow = [
    BoxShadow(
      color: deepSlate.withOpacity(0.04),
      blurRadius: 30,
      offset: const Offset(0, 15),
    ),
  ];

  static List<BoxShadow> tightShadow = [
    BoxShadow(
      color: Colors.black.withOpacity(0.02),
      blurRadius: 10,
      offset: const Offset(0, 4),
    ),
  ];

  static const LinearGradient premiumGradient = LinearGradient(
    colors: [primaryGreen, accentMint],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static const LinearGradient darkGradient = LinearGradient(
    colors: [Color(0xFF1E293B), Color(0xFF0F172A)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static ThemeData get seniorTheme {
    return ThemeData(
      useMaterial3: true,
      scaffoldBackgroundColor: backgroundLight,
      primaryColor: primaryGreen,
      colorScheme: ColorScheme.fromSeed(
        seedColor: primaryGreen,
        primary: primaryGreen,
        secondary: deepSlate,
        surface: surfaceWhite,
        error: errorRed,
      ),
      textTheme: TextTheme(
        displayLarge: GoogleFonts.outfit(
          fontSize: 48,
          fontWeight: FontWeight.w800,
          color: deepSlate,
          letterSpacing: -1.5,
        ),
        headlineMedium: GoogleFonts.outfit(
          fontSize: 32,
          fontWeight: FontWeight.bold,
          color: deepSlate,
          letterSpacing: -0.5,
        ),
        titleLarge: GoogleFonts.outfit(
          fontSize: 22,
          fontWeight: FontWeight.w700,
          color: deepSlate,
        ),
        bodyLarge: GoogleFonts.inter(
          fontSize: 16,
          color: textMain,
          height: 1.6,
        ),
        bodyMedium: GoogleFonts.inter(
          fontSize: 14,
          color: textMuted,
        ),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: primaryGreen,
          foregroundColor: Colors.white,
          elevation: 0,
          padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 18),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(borderRadiusMedium)),
          textStyle: GoogleFonts.outfit(fontWeight: FontWeight.w700, fontSize: 16),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: Colors.grey.shade50,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(borderRadiusMedium),
          borderSide: BorderSide(color: Colors.grey.shade200),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(borderRadiusMedium),
          borderSide: BorderSide(color: Colors.grey.shade200),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(borderRadiusMedium),
          borderSide: const BorderSide(color: primaryGreen, width: 1.5),
        ),
        contentPadding: const EdgeInsets.all(20),
      ),
    );
  }

  // Backward compatibility
  static const Color backgroundDark = deepSlate;
  static const Color textCardGrey = textMuted;
  static const Color textDark = deepSlate;
  static const Color textGrey = textMuted;
  static const Color white = surfaceWhite;
}
