import 'package:google_fonts/google_fonts.dart';
import 'package:material_ui/material_ui.dart';

class AppTheme {
  static const burgundy = Color(0xFF8F0401);
  static const gold = Color(0xFFDCA321);
  static const cream = Color(0xFFF3EEE5);
  static const ink = Color(0xFF292323);

  static final light = _build(Brightness.light);
  static final dark = _build(Brightness.dark);

  static ThemeData _build(Brightness brightness) {
    final isDark = brightness == Brightness.dark;
    final colorScheme =
        ColorScheme.fromSeed(
          seedColor: burgundy,
          brightness: brightness,
        ).copyWith(
          primary: isDark ? const Color(0xFFFFAEA4) : burgundy,
          onPrimary: isDark ? const Color(0xFF4E0000) : Colors.white,
          secondary: gold,
          onSecondary: ink,
          surface: isDark ? const Color(0xFF171717) : cream,
          onSurface: isDark ? const Color(0xFFF5F5F5) : ink,
          onSurfaceVariant: isDark
              ? const Color(0xFFBDBDBD)
              : const Color(0xFF645954),
          surfaceContainer: isDark
              ? const Color(0xFF222222)
              : const Color(0xFFFFF6EE),
          surfaceContainerLow: isDark
              ? const Color(0xFF222222)
              : const Color(0xFFFFFCF9),
          surfaceContainerHigh: isDark ? const Color(0xFF292929) : Colors.white,
          surfaceContainerHighest: isDark
              ? const Color(0xFF292929)
              : const Color(0xFFF1E6DC),
          outlineVariant: isDark
              ? const Color(0xFF424242)
              : const Color(0xFFEAE2D9),
          outline: isDark ? const Color(0xFF909090) : const Color(0xFF77675F),
        );
    final base = ThemeData(
      useMaterial3: true,
      colorScheme: colorScheme,
      scaffoldBackgroundColor: colorScheme.surface,
    );

    return base.copyWith(
      textTheme: GoogleFonts.dmSansTextTheme(base.textTheme).apply(
        bodyColor: colorScheme.onSurface,
        displayColor: colorScheme.onSurface,
      ),
      appBarTheme: const AppBarTheme(
        backgroundColor: burgundy,
        foregroundColor: Colors.white,
        elevation: 0,
        centerTitle: false,
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: colorScheme.surfaceContainerHigh,
      ),
      drawerTheme: DrawerThemeData(
        backgroundColor: colorScheme.surfaceContainerHigh,
      ),
      cardTheme: CardThemeData(
        color: colorScheme.surfaceContainerHigh,
        elevation: 0,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
          side: BorderSide(color: colorScheme.outlineVariant),
        ),
      ),
      inputDecorationTheme: InputDecorationThemeData(
        filled: true,
        fillColor: colorScheme.surfaceContainerHigh,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 14,
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide(color: colorScheme.outlineVariant),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide(color: colorScheme.primary, width: 1.5),
        ),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: burgundy,
          foregroundColor: Colors.white,
          minimumSize: const Size(48, 48),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
        ),
      ),
    );
  }
}

extension CampusThemeContext on BuildContext {
  ColorScheme get colors => Theme.of(this).colorScheme;

  Color adaptiveColor(Color lightColor, Color darkColor) =>
      colors.brightness == Brightness.dark ? darkColor : lightColor;
}
