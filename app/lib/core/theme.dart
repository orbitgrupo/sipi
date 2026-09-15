// Sipi — tema visual (colores y estilos compartidos, basados en el mockup).
import 'package:flutter/material.dart';

class SipiColors {
  static const primary = Color(0xFF2456E6);
  static const primaryDark = Color(0xFF1A3FB8);
  static const background = Color(0xFFF4F6FB);
  static const card = Colors.white;
  static const text = Color(0xFF1B2340);
  static const muted = Color(0xFF8A93B2);
  static const success = Color(0xFF22B573);
  static const warning = Color(0xFFF5A623);
  static const danger = Color(0xFFE5484D);
}

ThemeData sipiTheme() {
  final base = ThemeData.light(useMaterial3: true);
  return base.copyWith(
    colorScheme: ColorScheme.fromSeed(
      seedColor: SipiColors.primary,
      primary: SipiColors.primary,
      surface: SipiColors.background,
    ),
    scaffoldBackgroundColor: SipiColors.background,
    appBarTheme: const AppBarTheme(
      backgroundColor: SipiColors.background,
      elevation: 0,
      centerTitle: true,
      titleTextStyle: TextStyle(
          color: SipiColors.text, fontSize: 17, fontWeight: FontWeight.w700),
      iconTheme: IconThemeData(color: SipiColors.text),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: Colors.white,
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14), borderSide: BorderSide.none),
      hintStyle: const TextStyle(color: SipiColors.muted),
      prefixIconColor: SipiColors.muted,
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        backgroundColor: SipiColors.primary,
        foregroundColor: Colors.white,
        minimumSize: const Size.fromHeight(52),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
      ),
    ),
  );
}
