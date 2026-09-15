// Sipi — sistema de diseño (colores, radios, sombras y estilos compartidos).
import 'package:flutter/material.dart';

class SipiColors {
  static const primary = Color(0xFF2456E6);
  static const primaryDark = Color(0xFF1A3FB8);
  static const primarySoft = Color(0xFFE8EDFD);
  static const accent = Color(0xFF7C5CFF);
  static const background = Color(0xFFF4F6FB);
  static const card = Colors.white;
  static const text = Color(0xFF1B2340);
  static const muted = Color(0xFF8A93B2);
  static const border = Color(0xFFE6EAF3);
  static const success = Color(0xFF22B573);
  static const successSoft = Color(0xFFE2F6EC);
  static const warning = Color(0xFFF5A623);
  static const warningSoft = Color(0xFFFDF1DC);
  static const danger = Color(0xFFE5484D);
  static const dangerSoft = Color(0xFFFBE4E5);
}

class SipiRadii {
  static const sm = 10.0;
  static const md = 14.0;
  static const lg = 18.0;
  static const xl = 24.0;
}

class SipiShadows {
  static List<BoxShadow> get card => [
        BoxShadow(
          color: const Color(0xFF1B2340).withValues(alpha: 0.05),
          blurRadius: 16,
          offset: const Offset(0, 6),
        ),
      ];
  static List<BoxShadow> get soft => [
        BoxShadow(
          color: const Color(0xFF1B2340).withValues(alpha: 0.04),
          blurRadius: 10,
          offset: const Offset(0, 3),
        ),
      ];
}

ThemeData sipiTheme() {
  final base = ThemeData.light(useMaterial3: true);
  final scheme = ColorScheme.fromSeed(
    seedColor: SipiColors.primary,
    primary: SipiColors.primary,
    surface: SipiColors.background,
  );
  return base.copyWith(
    colorScheme: scheme,
    scaffoldBackgroundColor: SipiColors.background,
    appBarTheme: const AppBarTheme(
      backgroundColor: SipiColors.background,
      elevation: 0,
      scrolledUnderElevation: 0,
      centerTitle: true,
      titleTextStyle: TextStyle(
          color: SipiColors.text, fontSize: 17, fontWeight: FontWeight.w700),
      iconTheme: IconThemeData(color: SipiColors.text),
    ),
    tabBarTheme: const TabBarThemeData(
      labelColor: SipiColors.primary,
      unselectedLabelColor: SipiColors.muted,
      indicatorColor: SipiColors.primary,
      labelStyle: TextStyle(fontWeight: FontWeight.w700, fontSize: 14),
      unselectedLabelStyle:
          TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
    ),
    navigationBarTheme: NavigationBarThemeData(
      backgroundColor: Colors.white,
      elevation: 0,
      indicatorColor: SipiColors.primarySoft,
      labelTextStyle: WidgetStateProperty.resolveWith((states) {
        final selected = states.contains(WidgetState.selected);
        return TextStyle(
          fontSize: 12,
          fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
          color: selected ? SipiColors.primary : SipiColors.muted,
        );
      }),
      iconTheme: WidgetStateProperty.resolveWith((states) {
        final selected = states.contains(WidgetState.selected);
        return IconThemeData(
            color: selected ? SipiColors.primary : SipiColors.muted);
      }),
    ),
    cardTheme: CardThemeData(
      color: SipiColors.card,
      elevation: 0,
      margin: EdgeInsets.zero,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(SipiRadii.lg),
        side: const BorderSide(color: SipiColors.border),
      ),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: Colors.white,
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 15),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(SipiRadii.md),
        borderSide: const BorderSide(color: SipiColors.border),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(SipiRadii.md),
        borderSide: const BorderSide(color: SipiColors.border),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(SipiRadii.md),
        borderSide: const BorderSide(color: SipiColors.primary, width: 1.6),
      ),
      hintStyle: const TextStyle(color: SipiColors.muted),
      prefixIconColor: SipiColors.muted,
      suffixIconColor: SipiColors.muted,
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        backgroundColor: SipiColors.primary,
        foregroundColor: Colors.white,
        disabledBackgroundColor: SipiColors.border,
        minimumSize: const Size.fromHeight(54),
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(SipiRadii.md)),
        textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
        elevation: 0,
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        foregroundColor: SipiColors.primary,
        minimumSize: const Size.fromHeight(54),
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(SipiRadii.md)),
        side: const BorderSide(color: SipiColors.primary, width: 1.4),
        textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
      ),
    ),
    snackBarTheme: SnackBarThemeData(
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(SipiRadii.md)),
      backgroundColor: SipiColors.text,
    ),
    progressIndicatorTheme: const ProgressIndicatorThemeData(
      color: SipiColors.primary,
    ),
    dividerTheme: const DividerThemeData(color: SipiColors.border),
  );
}
