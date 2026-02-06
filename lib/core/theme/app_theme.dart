import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class AppTheme {
  // Brand Colors
  static const Color primary = Colors.teal;
  static const Color success = Color(0xFF4ADE80);
  static const Color error = Color(0xFFEF4444);
  static const Color warning = Color(0xFFF59E0B);
  static const Color transparent = Colors.transparent;

  // Neutral Palette (Slate)
  static const Color slate50 = Color(0xFFF8FAFC);
  static const Color slate100 = Color(0xFFF1F5F9);
  static const Color slate200 = Color(0xFFE2E8F0);
  static const Color slate300 = Color(0xFFCBD5E1);
  static const Color slate400 = Color(0xFF94A3B8);
  static const Color slate500 = Color(0xFF64748B);
  static const Color slate600 = Color(0xFF475569);
  static const Color slate700 = Color(0xFF334155);
  static const Color slate800 = Color(0xFF1E293B);
  static const Color slate900 = Color(0xFF0F172A);

  // Semantic Aliases
  static const Color lightScaffold = slate50;
  static const Color darkScaffold = slate900;
  static const Color lightCard = Colors.white;
  static const Color darkCard = slate800;
  static const Color lightBorder = slate200;
  static const Color darkBorder = slate700;

  // Text Styles
  static TextStyle get headlineSmall =>
      GoogleFonts.outfit(fontSize: 24, fontWeight: FontWeight.bold);
  static TextStyle get titleLarge =>
      GoogleFonts.outfit(fontSize: 22, fontWeight: FontWeight.bold);
  static TextStyle get titleMedium =>
      GoogleFonts.outfit(fontSize: 18, fontWeight: FontWeight.w600);
  static TextStyle get titleSmall =>
      GoogleFonts.outfit(fontSize: 14, fontWeight: FontWeight.bold);
  static TextStyle get bodyLarge =>
      GoogleFonts.outfit(fontSize: 16, fontWeight: FontWeight.normal);
  static TextStyle get bodyMedium =>
      GoogleFonts.outfit(fontSize: 14, fontWeight: FontWeight.normal);
  static TextStyle get bodySmall => GoogleFonts.outfit(
    fontSize: 12,
    fontWeight: FontWeight.normal,
    color: slate500,
  );
  static TextStyle get labelSmall =>
      GoogleFonts.outfit(fontSize: 11, fontWeight: FontWeight.w500);

  // Easy Access Methods
  static Color primaryColor(BuildContext context) =>
      Theme.of(context).colorScheme.primary;
  static Color scaffoldColor(BuildContext context) =>
      Theme.of(context).scaffoldBackgroundColor;
  static Color cardColor(BuildContext context) => Theme.of(context).cardColor;
  static Color textColor(BuildContext context) =>
      Theme.of(context).textTheme.bodyMedium?.color ??
      (isDark(context) ? Colors.white : slate900);
  static Color surfaceColor(BuildContext context) =>
      Theme.of(context).colorScheme.surface;
  static bool isDark(BuildContext context) =>
      Theme.of(context).brightness == Brightness.dark;

  static Color borderColor(BuildContext context) {
    return isDark(context) ? darkBorder : lightBorder;
  }

  // Themes
  static ThemeData get lightTheme {
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.light,
      colorSchemeSeed: primary,
      scaffoldBackgroundColor: lightScaffold,
      cardColor: lightCard,
      textTheme: GoogleFonts.outfitTextTheme(ThemeData.light().textTheme),
      appBarTheme: const AppBarTheme(
        backgroundColor: lightScaffold,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        centerTitle: true,
      ),
      cardTheme: CardThemeData(
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: const BorderSide(color: lightBorder),
        ),
        color: lightCard,
      ),
      elevatedButtonTheme: _buttonTheme(),
      filledButtonTheme: _filledButtonTheme(),
    );
  }

  static ThemeData get darkTheme {
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      colorSchemeSeed: primary,
      scaffoldBackgroundColor: darkScaffold,
      cardColor: darkCard,
      textTheme: GoogleFonts.outfitTextTheme(ThemeData.dark().textTheme),
      appBarTheme: const AppBarTheme(
        backgroundColor: darkScaffold,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        centerTitle: true,
      ),
      cardTheme: CardThemeData(
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: const BorderSide(color: darkBorder),
        ),
        color: darkCard,
      ),
      elevatedButtonTheme: _buttonTheme(),
      filledButtonTheme: _filledButtonTheme(),
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: darkCard,
        indicatorColor: primary.withValues(alpha: 0.2),
        labelTextStyle: WidgetStateProperty.all(
          GoogleFonts.outfit(fontSize: 12, fontWeight: FontWeight.w500),
        ),
      ),
    );
  }

  static ElevatedButtonThemeData _buttonTheme() {
    return ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        elevation: 0,
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        textStyle: GoogleFonts.outfit(fontWeight: FontWeight.w600),
      ),
    );
  }

  static FilledButtonThemeData _filledButtonTheme() {
    return FilledButtonThemeData(
      style: FilledButton.styleFrom(
        elevation: 0,
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        textStyle: GoogleFonts.outfit(fontWeight: FontWeight.w600),
      ),
    );
  }

  static BoxDecoration containerDecoration(BuildContext context) {
    return BoxDecoration(
      color: cardColor(context),
      borderRadius: BorderRadius.circular(16),
      border: Border.all(color: borderColor(context)),
    );
  }
}
