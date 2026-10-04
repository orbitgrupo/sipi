// Sipi — sistema de diseño (colores, radios, sombras y estilos compartidos).
//
// Estilo de referencia "FreshCut": fondo blanco limpio, verde bosque profundo
// como color primario, piezas planas con bordes suaves y sombras sutiles,
// tipografía negra en negrita para títulos.
import 'package:flutter/material.dart';

class SipiColors {
  // Verde bosque (primario de la referencia).
  static const primary = Color(0xFF1C5C42);
  static const primaryLight = Color(0xFF2E7D5B);
  static const primaryDark = Color(0xFF143F2E);
  static const primarySoft = Color(0xFFE7F1EB);
  static const accent = Color(0xFF2E7D5B);
  static const accentLight = Color(0xFF4C9A76);
  static const accentDark = Color(0xFF143F2E);
  static const background = Color(0xFFFFFFFF);
  static const backgroundSoft = Color(0xFFF7F8FA);
  static const card = Colors.white;
  static const text = Color(0xFF101828);
  static const muted = Color(0xFF667085);
  static const border = Color(0xFFE9EBEF);
  static const success = Color(0xFF1C7A4D);
  static const successSoft = Color(0xFFE7F4EC);
  static const warning = Color(0xFFF59E0B);
  static const warningDark = Color(0xFFB45309);
  static const warningSoft = Color(0xFFFDF3E0);
  static const danger = Color(0xFFDC2626);
  static const dangerSoft = Color(0xFFFDECEC);
  static const gold = Color(0xFFF5A623);
  static const pink = Color(0xFFE1306C);
  // Tintes suaves para piezas de colores (iconos de categoría, etc.).
  static const clayBlue = Color(0xFFE7F1EB);
  static const clayPink = Color(0xFFFDECEC);
  static const clayGreen = Color(0xFFE7F4EC);
  static const clayYellow = Color(0xFFFDF3E0);
  static const clayPurple = Color(0xFFEFE9FB);
}

class SipiRadii {
  static const sm = 10.0;
  static const md = 14.0;
  static const lg = 16.0;
  static const xl = 20.0;
}

/// Helpers de superficie estilo referencia: piezas blancas planas con
/// borde suave y sombra sutil. (Mantiene la API usada en las pantallas.)
class Clay {
  static const shadowColor = Color(0xFF101828);

  /// Sombra sutil única.
  static List<BoxShadow> shadows({double depth = 7, Color? dark}) => [
        BoxShadow(
          color: shadowColor.withValues(alpha: 0.08),
          blurRadius: 16,
          offset: const Offset(0, 6),
        ),
      ];

  /// Tarjeta blanca plana.
  static BoxDecoration card(
          {Color? color, double radius = SipiRadii.lg, double depth = 7}) =>
      BoxDecoration(
        color: color ?? SipiColors.card,
        borderRadius: BorderRadius.circular(radius),
        border: Border.all(color: SipiColors.border, width: 1),
        boxShadow: shadows(),
      );

  /// Botón sólido con sombra sutil.
  static BoxDecoration button(Color color,
      {double radius = SipiRadii.md, double depth = 6}) {
    return BoxDecoration(
      color: color,
      borderRadius: BorderRadius.circular(radius),
      boxShadow: [
        BoxShadow(
          color: color.withValues(alpha: 0.35),
          blurRadius: 14,
          offset: const Offset(0, 6),
        ),
      ],
    );
  }

  /// Círculo sólido con sombra sutil (iconos, avatares).
  static BoxDecoration circle(Color color, {double depth = 6}) => BoxDecoration(
        color: color,
        shape: BoxShape.circle,
        boxShadow: [
          BoxShadow(
            color: shadowColor.withValues(alpha: 0.1),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      );

  /// Versión atenuada para estado presionado.
  static BoxDecoration pressed(
      {Color? color, double radius = SipiRadii.lg}) {
    final c = color ?? SipiColors.card;
    return BoxDecoration(
      color: Color.lerp(c, SipiColors.border, 0.35),
      borderRadius: BorderRadius.circular(radius),
      border: Border.all(color: SipiColors.border, width: 1),
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
      backgroundColor: Colors.white,
      elevation: 0,
      indicatorColor: SipiColors.primarySoft,
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
      shadowColor: Colors.transparent,
    ),
    dialogTheme: DialogThemeData(
      backgroundColor: SipiColors.card,
      shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(SipiRadii.xl)),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: const Color(0xFFF4F5F7),
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 15),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide.none,
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide.none,
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: SipiColors.primary, width: 1.5),
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
      backgroundColor: const Color(0xFFF1F2F4),
      selectedColor: SipiColors.primary,
      shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20)),
      labelStyle: const TextStyle(fontWeight: FontWeight.w600),
    ),
  );
}
