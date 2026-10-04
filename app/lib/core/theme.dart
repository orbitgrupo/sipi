// Sipi — sistema de diseño claymorphism (colores, radios, sombras y estilos).
//
// El claymorphism busca piezas suaves y "esponjosas" como de arcilla:
// fondo pastel, superficies claras con doble sombra (luz arriba-izquierda,
// sombra abajo-derecha) y bordes muy redondeados.
import 'package:flutter/material.dart';

class SipiColors {
  static const primary = Color(0xFF2456E6);
  static const primaryLight = Color(0xFF2F63F0);
  static const primaryDark = Color(0xFF1A3FB8);
  static const primarySoft = Color(0xFFE8EDFD);
  static const accent = Color(0xFF7C5CFF);
  static const accentLight = Color(0xFF9D7BFF);
  static const accentDark = Color(0xFF4A2FD6);
  // Fondo clay: pastel frío que hace resaltar las piezas.
  static const background = Color(0xFFE6EBF5);
  static const card = Color(0xFFF4F7FC);
  static const text = Color(0xFF1B2340);
  static const muted = Color(0xFF8A93B2);
  static const border = Color(0xFFD9E0F0);
  static const success = Color(0xFF22B573);
  static const successSoft = Color(0xFFDFF5E9);
  static const warning = Color(0xFFF5A623);
  static const warningDark = Color(0xFFB45309);
  static const warningSoft = Color(0xFFFDEFD4);
  static const danger = Color(0xFFE5484D);
  static const dangerSoft = Color(0xFFFADFDF);
  static const gold = Color(0xFFFFD54F);
  static const pink = Color(0xFFE1306C);
  // Tonos pastel para piezas clay de colores.
  static const clayBlue = Color(0xFFD7E3FD);
  static const clayPink = Color(0xFFFBDCE6);
  static const clayGreen = Color(0xFFD9F2E3);
  static const clayYellow = Color(0xFFFBEFC9);
  static const clayPurple = Color(0xFFE4DCFB);
}

class SipiRadii {
  static const sm = 12.0;
  static const md = 16.0;
  static const lg = 22.0;
  static const xl = 28.0;
}

/// Sombras y decoraciones estilo clay: luz blanca arriba-izquierda y
/// sombra suave abajo-derecha sobre el fondo pastel.
class Clay {
  static const shadowDark = Color(0xFFAEB9D4);

  /// Doble sombra clay estándar.
  static List<BoxShadow> shadows({double depth = 7, Color? dark}) => [
        const BoxShadow(
          color: Colors.white,
          offset: Offset(-6, -6),
          blurRadius: 14,
        ),
        BoxShadow(
          color: (dark ?? shadowDark).withValues(alpha: 0.55),
          offset: Offset(depth, depth),
          blurRadius: 14,
        ),
      ];

  /// Tarjeta clay clara.
  static BoxDecoration card(
          {Color? color, double radius = SipiRadii.lg, double depth = 7}) =>
      BoxDecoration(
        color: color ?? SipiColors.card,
        borderRadius: BorderRadius.circular(radius),
        boxShadow: shadows(depth: depth),
      );

  /// Pastilla/botón de color sólido con relieve clay y brillo superior.
  static BoxDecoration button(Color color,
      {double radius = SipiRadii.md, double depth = 6}) {
    final top = Color.lerp(color, Colors.white, 0.22)!;
    return BoxDecoration(
      gradient: LinearGradient(
        colors: [top, color],
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
      ),
      borderRadius: BorderRadius.circular(radius),
      boxShadow: [
        const BoxShadow(
          color: Colors.white,
          offset: Offset(-4, -4),
          blurRadius: 10,
        ),
        BoxShadow(
          color: color.withValues(alpha: 0.45),
          offset: Offset(depth, depth),
          blurRadius: 12,
        ),
      ],
    );
  }

  /// Círculo clay (iconos, avatares).
  static BoxDecoration circle(Color color, {double depth = 6}) => BoxDecoration(
        color: color,
        shape: BoxShape.circle,
        boxShadow: shadows(depth: depth),
      );

  /// Versión "hundida" para estado presionado.
  static BoxDecoration pressed(
      {Color? color, double radius = SipiRadii.lg}) {
    final c = color ?? SipiColors.card;
    return BoxDecoration(
      color: Color.lerp(c, Clay.shadowDark, 0.08),
      borderRadius: BorderRadius.circular(radius),
      boxShadow: const [
        BoxShadow(
          color: Colors.white,
          offset: Offset(-3, -3),
          blurRadius: 8,
        ),
        BoxShadow(
          color: Color(0xFFB9C3DA),
          offset: Offset(3, 3),
          blurRadius: 8,
        ),
      ],
    );
  }
}

class SipiShadows {
  static List<BoxShadow> get card => Clay.shadows();
  static List<BoxShadow> get soft => Clay.shadows(depth: 5);
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
          color: SipiColors.text, fontSize: 17, fontWeight: FontWeight.w800),
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
      backgroundColor: SipiColors.card,
      elevation: 0,
      indicatorColor: SipiColors.primary,
      indicatorShape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(SipiRadii.md)),
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
            color: selected ? Colors.white : SipiColors.muted);
      }),
    ),
    cardTheme: CardThemeData(
      color: SipiColors.card,
      elevation: 0,
      margin: EdgeInsets.zero,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(SipiRadii.lg),
      ),
      shadowColor: Colors.transparent,
    ),
    dialogTheme: DialogThemeData(
      backgroundColor: SipiColors.card,
      shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(SipiRadii.xl)),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: const Color(0xFFDDE4F2),
      contentPadding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(SipiRadii.md),
        borderSide: BorderSide.none,
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(SipiRadii.md),
        borderSide: BorderSide.none,
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(SipiRadii.md),
        borderSide: const BorderSide(color: SipiColors.primary, width: 2),
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
    chipTheme: base.chipTheme.copyWith(
      backgroundColor: SipiColors.card,
      selectedColor: SipiColors.primary,
      shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20)),
      labelStyle: const TextStyle(fontWeight: FontWeight.w600),
    ),
  );
}
