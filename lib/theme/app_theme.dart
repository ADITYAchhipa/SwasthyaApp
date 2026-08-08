import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class AppTheme {
  // ─── Light Mode Palette ───────────────────────────────────────────────────
  static const Color lightBg      = Color(0xFFF8FAFC);
  static const Color cardBg       = Color(0xFFFFFFFF);
  static const Color surfaceColor = Color(0xFFF1F5F9);
  static const Color borderColor  = Color(0xFFE2E8F0);

  static const Color accentTeal   = Color(0xFF0F766E); // Medical Teal 700 primary
  static const Color accentRed    = Color(0xFFDC2626); // Emergency Red 600
  static const Color accentAmber  = Color(0xFFF59E0B); // Accent Amber 500
  static const Color accentGreen  = Color(0xFF16A34A); // Success Green 600
  static const Color primaryLight = Color(0xFFCCFBF1); // Light Teal 100
  static const Color hospitalBlue = Color(0xFF1E40AF); // Hospital Blue

  static const Color textPrimary   = Color(0xFF1E293B);
  static const Color textSecondary = Color(0xFF64748B);

  // Alias kept for legacy references
  static const Color darkBg = lightBg;

  // ─── Gradients ─────────────────────────────────────────────────────────────
  static const LinearGradient tealGradient = LinearGradient(
    colors: [Color(0xFF0F766E), Color(0xFF0D9488)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );
  static const LinearGradient redGradient = LinearGradient(
    colors: [Color(0xFFDC2626), Color(0xFFB91C1C)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );
  static const LinearGradient goldGradient = LinearGradient(
    colors: [Color(0xFFF59E0B), Color(0xFFD97706)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );
  static const LinearGradient darkCardGradient = LinearGradient(
    colors: [Color(0xFF0F172A), Color(0xFF1E293B)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );
  static const LinearGradient neonBlueGradient = LinearGradient(
    colors: [Color(0xFF0EA5E9), Color(0xFF7C3AED)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  // ─── Card Decoration ───────────────────────────────────────────────────────
  static BoxDecoration glassCardDecoration({
    Color? borderColor,
    double borderRadius = 16.0,
  }) {
    return BoxDecoration(
      color: cardBg,
      borderRadius: BorderRadius.circular(borderRadius),
      border: Border.all(color: borderColor ?? AppTheme.borderColor),
      boxShadow: const [
        BoxShadow(color: Color(0x0A000000), blurRadius: 8, offset: Offset(0, 2)),
        BoxShadow(color: Color(0x06000000), blurRadius: 20, offset: Offset(0, 6)),
      ],
    );
  }

  // ─── Premium Input Decoration ──────────────────────────────────────────────
  static InputDecoration premiumInputDecoration({
    required String label,
    required IconData icon,
    String? hint,
    bool isRequired = false,
  }) {
    return InputDecoration(
      label: isRequired
          ? Text.rich(
              TextSpan(
                text: label,
                style: const TextStyle(color: textSecondary, fontSize: 13),
                children: const [
                  TextSpan(
                    text: ' *',
                    style: TextStyle(color: accentRed, fontWeight: FontWeight.bold),
                  ),
                ],
              ),
            )
          : null,
      labelText: isRequired ? null : label,
      hintText: hint,
      hintStyle: const TextStyle(color: textSecondary, fontSize: 13),
      labelStyle: const TextStyle(color: textSecondary, fontSize: 13),
      prefixIcon: Icon(icon, color: accentTeal, size: 20),
      filled: true,
      fillColor: surfaceColor,
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: borderColor),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: accentTeal, width: 1.5),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: accentRed),
      ),
      focusedErrorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: accentRed, width: 1.5),
      ),
      errorStyle: const TextStyle(color: accentRed, fontSize: 11),
    );
  }

  // ─── Theme ─────────────────────────────────────────────────────────────────
  static ThemeData get darkTheme {
    return ThemeData(
      brightness: Brightness.light,
      primaryColor: accentTeal,
      scaffoldBackgroundColor: lightBg,
      cardColor: cardBg,
      fontFamily: GoogleFonts.poppins().fontFamily,
      textTheme: TextTheme(
        displayLarge: GoogleFonts.poppins(fontSize: 32, fontWeight: FontWeight.bold, color: textPrimary, letterSpacing: -0.5),
        displayMedium: GoogleFonts.poppins(fontSize: 26, fontWeight: FontWeight.bold, color: textPrimary, letterSpacing: -0.5),
        titleLarge: GoogleFonts.poppins(fontSize: 20, fontWeight: FontWeight.w600, color: textPrimary),
        bodyLarge: GoogleFonts.poppins(fontSize: 16, color: textPrimary, height: 1.5),
        bodyMedium: GoogleFonts.poppins(fontSize: 14, color: textSecondary, height: 1.5),
        labelLarge: GoogleFonts.poppins(fontSize: 14, fontWeight: FontWeight.bold, color: textPrimary, letterSpacing: 0.3),
      ),
      colorScheme: ColorScheme.light(
        primary: accentTeal,
        secondary: accentTeal,
        surface: cardBg,
        error: accentRed,
      ),
      iconTheme: const IconThemeData(color: textPrimary),
      appBarTheme: AppBarTheme(
        backgroundColor: cardBg,
        elevation: 0,
        scrolledUnderElevation: 0.5,
        shadowColor: Colors.black.withOpacity(0.06),
        surfaceTintColor: Colors.transparent,
        iconTheme: const IconThemeData(color: textPrimary),
        titleTextStyle: GoogleFonts.poppins(
          color: textPrimary, fontSize: 18, fontWeight: FontWeight.bold,
        ),
      ),
      dividerTheme: const DividerThemeData(color: borderColor, thickness: 1),
      switchTheme: SwitchThemeData(
        thumbColor: MaterialStateProperty.resolveWith(
          (s) => s.contains(MaterialState.selected) ? cardBg : Colors.grey[400],
        ),
        trackColor: MaterialStateProperty.resolveWith(
          (s) => s.contains(MaterialState.selected) ? accentTeal : Colors.grey[300],
        ),
      ),
      sliderTheme: SliderThemeData(
        activeTrackColor: accentTeal,
        inactiveTrackColor: borderColor,
        thumbColor: accentTeal,
        overlayColor: accentTeal.withOpacity(0.1),
      ),
      checkboxTheme: CheckboxThemeData(
        fillColor: MaterialStateProperty.resolveWith(
          (s) => s.contains(MaterialState.selected) ? accentTeal : Colors.transparent,
        ),
        side: const BorderSide(color: borderColor, width: 1.5),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          elevation: 0,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
      ),
    );
  }
}
