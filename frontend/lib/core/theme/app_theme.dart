import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class AppTheme {
  // Light Palette: Warm Editorial Paper & Ink
  static const Color lightBg = Color(0xFFF9F8F6);
  static const Color lightSurface = Color(0xFFFFFFFF);
  static const Color lightInk = Color(0xFF1A1A1A);
  static const Color lightInkSecondary = Color(0xFF4A5568);
  static const Color lightBorder = Color(0xFFE2E8F0);
  static const Color lightAccent = Color(0xFFC05621); // Rich Terracotta / Amber
  static const Color lightAccentSubtle = Color(0xFFFEEBC8);

  // Dark Palette: Sleek Architectural Slate
  static const Color darkBg = Color(0xFF121417);
  static const Color darkSurface = Color(0xFF1A202C);
  static const Color darkInk = Color(0xFFF7FAFC);
  static const Color darkInkSecondary = Color(0xFFA0AEC0);
  static const Color darkBorder = Color(0xFF2D3748);
  static const Color darkAccent = Color(0xFFED8936); // Vibrant Warm Amber
  static const Color darkAccentSubtle = Color(0xFF7B341E);

  /// Builds the Light Theme with Fraunces serif headlines and Inter sans body
  static ThemeData get lightTheme {
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.light,
      scaffoldBackgroundColor: lightBg,
      colorScheme: const ColorScheme.light(
        primary: lightAccent,
        onPrimary: Colors.white,
        secondary: lightAccent,
        surface: lightSurface,
        onSurface: lightInk,
        background: lightBg,
        onBackground: lightInk,
        outline: lightBorder,
      ),
      appBarTheme: AppBarTheme(
        backgroundColor: lightBg,
        elevation: 0,
        scrolledUnderElevation: 1,
        centerTitle: false,
        iconTheme: const IconThemeData(color: lightInk),
        titleTextStyle: GoogleFonts.fraunces(
          fontSize: 24,
          fontWeight: FontWeight.w700,
          color: lightInk,
          letterSpacing: -0.5,
        ),
      ),
      cardTheme: CardThemeData(
        color: lightSurface,
        elevation: 0,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: const BorderSide(color: lightBorder, width: 1),
        ),
      ),
      textTheme: TextTheme(
        displayLarge: GoogleFonts.fraunces(
          fontSize: 32,
          fontWeight: FontWeight.w700,
          color: lightInk,
          letterSpacing: -0.8,
        ),
        headlineLarge: GoogleFonts.fraunces(
          fontSize: 26,
          fontWeight: FontWeight.w700,
          color: lightInk,
          letterSpacing: -0.5,
        ),
        headlineMedium: GoogleFonts.fraunces(
          fontSize: 20,
          fontWeight: FontWeight.w600,
          color: lightInk,
          letterSpacing: -0.3,
        ),
        titleLarge: GoogleFonts.fraunces(
          fontSize: 18,
          fontWeight: FontWeight.w600,
          color: lightInk,
        ),
        bodyLarge: GoogleFonts.inter(
          fontSize: 16,
          fontWeight: FontWeight.w400,
          color: lightInk,
          height: 1.6,
        ),
        bodyMedium: GoogleFonts.inter(
          fontSize: 14,
          fontWeight: FontWeight.w400,
          color: lightInkSecondary,
          height: 1.5,
        ),
        labelSmall: GoogleFonts.inter(
          fontSize: 12,
          fontWeight: FontWeight.w600,
          color: lightInkSecondary,
          letterSpacing: 0.5,
        ),
      ),
      dividerTheme: const DividerThemeData(
        color: lightBorder,
        thickness: 1,
        space: 1,
      ),
    );
  }

  /// Builds the Dark Theme with high-contrast slate surfaces and warm accents
  static ThemeData get darkTheme {
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      scaffoldBackgroundColor: darkBg,
      colorScheme: const ColorScheme.dark(
        primary: darkAccent,
        onPrimary: Colors.black,
        secondary: darkAccent,
        surface: darkSurface,
        onSurface: darkInk,
        background: darkBg,
        onBackground: darkInk,
        outline: darkBorder,
      ),
      appBarTheme: AppBarTheme(
        backgroundColor: darkBg,
        elevation: 0,
        scrolledUnderElevation: 1,
        centerTitle: false,
        iconTheme: const IconThemeData(color: darkInk),
        titleTextStyle: GoogleFonts.fraunces(
          fontSize: 24,
          fontWeight: FontWeight.w700,
          color: darkInk,
          letterSpacing: -0.5,
        ),
      ),
      cardTheme: CardThemeData(
        color: darkSurface,
        elevation: 0,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: const BorderSide(color: darkBorder, width: 1),
        ),
      ),
      textTheme: TextTheme(
        displayLarge: GoogleFonts.fraunces(
          fontSize: 32,
          fontWeight: FontWeight.w700,
          color: darkInk,
          letterSpacing: -0.8,
        ),
        headlineLarge: GoogleFonts.fraunces(
          fontSize: 26,
          fontWeight: FontWeight.w700,
          color: darkInk,
          letterSpacing: -0.5,
        ),
        headlineMedium: GoogleFonts.fraunces(
          fontSize: 20,
          fontWeight: FontWeight.w600,
          color: darkInk,
          letterSpacing: -0.3,
        ),
        titleLarge: GoogleFonts.fraunces(
          fontSize: 18,
          fontWeight: FontWeight.w600,
          color: darkInk,
        ),
        bodyLarge: GoogleFonts.inter(
          fontSize: 16,
          fontWeight: FontWeight.w400,
          color: darkInk,
          height: 1.6,
        ),
        bodyMedium: GoogleFonts.inter(
          fontSize: 14,
          fontWeight: FontWeight.w400,
          color: darkInkSecondary,
          height: 1.5,
        ),
        labelSmall: GoogleFonts.inter(
          fontSize: 12,
          fontWeight: FontWeight.w600,
          color: darkInkSecondary,
          letterSpacing: 0.5,
        ),
      ),
      dividerTheme: const DividerThemeData(
        color: darkBorder,
        thickness: 1,
        space: 1,
      ),
    );
  }
}
