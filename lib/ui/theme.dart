import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

/// Paleta Organic: areia, sálvia e musgo, com fontes locais.
class AppTheme {
  static const sand = Color(0xFFE8DCC7);
  static const sage = Color(0xFF8B9D83);
  static const moss = Color(0xFF606C38);
  static const clay = Color(0xFFB08B6E);
  static const darkBg = Color(0xFF202820);
  static const darkBgSecondary = Color(0xFF293329);
  static const darkCard = Color(0xFF303C30);
  static const darkPrimary = Color(0xFFBBCB9B);
  static const darkAccent = Color(0xFFD4B895);
  static const darkTextPrimary = sand;
  static const darkTextSecondary = Color(0xFFBAC6B3);
  static const lightBg = sand;
  static const lightCard = Color(0xFFDED2BD);
  // Variante do musgo para texto/controles com contraste em superfícies claras.
  static const lightPrimary = Color(0xFF465227);
  static const lightAccent = Color(0xFF80563D);
  static const lightTextPrimary = Color(0xFF293329);
  static const lightTextSecondary = Color(0xFF505C49);

  static ThemeData get darkTheme => _build(Brightness.dark);
  static ThemeData get lightTheme => _build(Brightness.light);

  static ThemeData _build(Brightness brightness) {
    final dark = brightness == Brightness.dark;
    final primary = dark ? darkPrimary : lightPrimary;
    final text = dark ? darkTextPrimary : lightTextPrimary;
    final muted = dark ? darkTextSecondary : lightTextSecondary;
    final bg = dark ? darkBg : lightBg;
    final card = dark ? darkCard : lightCard;
    final scheme = ColorScheme.fromSeed(seedColor: moss, brightness: brightness)
        .copyWith(
          primary: primary,
          onPrimary: dark ? darkBg : sand,
          primaryContainer: dark ? darkCard : sage,
          onPrimaryContainer: text,
          secondary: dark ? darkAccent : lightAccent,
          onSecondary: dark ? darkBg : sand,
          secondaryContainer: dark ? darkBgSecondary : const Color(0xFFD4B895),
          onSecondaryContainer: text,
          surface: card,
          onSurface: text,
          onSurfaceVariant: muted,
          surfaceContainerLowest: bg,
          surfaceContainerLow: card,
          surfaceContainer: card,
          surfaceContainerHigh: dark
              ? const Color(0xFF3A4636)
              : const Color(0xFFD4C7B0),
          surfaceContainerHighest: dark
              ? const Color(0xFF44513F)
              : const Color(0xFFCDBFA6),
          outline: dark ? const Color(0xFF84917B) : const Color(0xFF707A63),
          outlineVariant: dark
              ? const Color(0xFF465240)
              : const Color(0xFFB9AF98),
          error: dark ? const Color(0xFFE8A48B) : const Color(0xFF963E29),
          onError: dark ? darkBg : sand,
          errorContainer: dark
              ? const Color(0xFF57392D)
              : const Color(0xFFDAC0AA),
          onErrorContainer: text,
          inverseSurface: dark ? sand : darkBg,
          onInverseSurface: dark ? darkBg : sand,
        );
    TextStyle type(double size, FontWeight weight, {Color? color}) =>
        GoogleFonts.outfit(
          fontSize: size,
          fontWeight: weight,
          color: color ?? text,
          height: 1.35,
        );
    final textTheme = GoogleFonts.outfitTextTheme().copyWith(
      displayLarge: type(40, FontWeight.w600),
      displayMedium: type(34, FontWeight.w600),
      headlineLarge: type(32, FontWeight.w600),
      headlineMedium: type(28, FontWeight.w600),
      headlineSmall: type(24, FontWeight.w600),
      titleLarge: type(22, FontWeight.w600),
      titleMedium: type(18, FontWeight.w600),
      titleSmall: type(15, FontWeight.w600),
      bodyLarge: type(16, FontWeight.w400),
      bodyMedium: type(14, FontWeight.w400, color: muted),
      bodySmall: type(12, FontWeight.w400, color: muted),
      labelLarge: type(14, FontWeight.w600),
      labelMedium: type(12, FontWeight.w600),
      labelSmall: type(11, FontWeight.w500, color: muted),
    );
    final shape = RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(24),
    );
    final inputShape = BorderRadius.circular(16);
    return ThemeData(
      useMaterial3: true,
      brightness: brightness,
      primaryColor: primary,
      colorScheme: scheme,
      scaffoldBackgroundColor: bg,
      textTheme: textTheme,
      iconTheme: IconThemeData(color: primary),
      dividerColor: scheme.outlineVariant,
      cardTheme: CardThemeData(
        color: card,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        margin: const EdgeInsets.symmetric(vertical: 6, horizontal: 12),
        shape: shape.copyWith(
          side: BorderSide(color: scheme.outlineVariant.withValues(alpha: .5)),
        ),
      ),
      appBarTheme: AppBarTheme(
        backgroundColor: bg,
        foregroundColor: text,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: false,
        titleSpacing: 24,
        toolbarHeight: 72,
        titleTextStyle: textTheme.titleLarge,
        iconTheme: IconThemeData(color: primary),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: dark ? darkBgSecondary : sand,
        hintStyle: type(14, FontWeight.w400, color: muted),
        labelStyle: type(14, FontWeight.w500, color: muted),
        border: OutlineInputBorder(
          borderRadius: inputShape,
          borderSide: BorderSide(color: scheme.outline),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: inputShape,
          borderSide: BorderSide(color: scheme.outline),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: inputShape,
          borderSide: BorderSide(color: primary, width: 2),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: inputShape,
          borderSide: BorderSide(color: scheme.error),
        ),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 18,
          vertical: 18,
        ),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: primary,
          foregroundColor: scheme.onPrimary,
          minimumSize: const Size(48, 52),
          elevation: 0,
          padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 24),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          textStyle: textTheme.labelLarge,
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: primary,
          minimumSize: const Size(48, 48),
          textStyle: textTheme.labelLarge,
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: primary,
          foregroundColor: scheme.onPrimary,
          minimumSize: const Size(48, 52),
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          textStyle: textTheme.labelLarge,
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: primary,
          minimumSize: const Size(48, 48),
          side: BorderSide(color: scheme.outline),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          textStyle: textTheme.labelLarge,
        ),
      ),
      iconButtonTheme: IconButtonThemeData(
        style: IconButton.styleFrom(minimumSize: const Size(48, 48)),
      ),
      floatingActionButtonTheme: FloatingActionButtonThemeData(
        backgroundColor: primary,
        foregroundColor: scheme.onPrimary,
        elevation: 0,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      ),
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: card,
        surfaceTintColor: Colors.transparent,
        indicatorColor: primary.withValues(alpha: .18),
        height: 80,
        labelTextStyle: WidgetStateProperty.resolveWith(
          (states) => textTheme.labelMedium!.copyWith(
            color: states.contains(WidgetState.selected) ? primary : muted,
          ),
        ),
        iconTheme: WidgetStateProperty.resolveWith(
          (states) => IconThemeData(
            color: states.contains(WidgetState.selected) ? primary : muted,
          ),
        ),
      ),
      navigationRailTheme: NavigationRailThemeData(
        backgroundColor: card,
        indicatorColor: primary.withValues(alpha: .18),
        selectedIconTheme: IconThemeData(color: primary),
        unselectedIconTheme: IconThemeData(color: muted),
        selectedLabelTextStyle: textTheme.labelLarge!.copyWith(color: primary),
        unselectedLabelTextStyle: textTheme.labelLarge!.copyWith(color: muted),
      ),
      tabBarTheme: TabBarThemeData(
        labelColor: primary,
        unselectedLabelColor: muted,
        labelStyle: textTheme.labelLarge,
        unselectedLabelStyle: textTheme.labelLarge,
        dividerColor: scheme.outlineVariant,
        indicatorColor: primary,
        indicatorSize: TabBarIndicatorSize.label,
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: card,
        surfaceTintColor: Colors.transparent,
        shape: shape,
      ),
      bottomSheetTheme: BottomSheetThemeData(
        backgroundColor: card,
        surfaceTintColor: Colors.transparent,
        constraints: const BoxConstraints(maxWidth: 680),
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
        ),
      ),
      chipTheme: ChipThemeData(
        backgroundColor: card,
        side: BorderSide.none,
        shape: shape,
        labelStyle: textTheme.labelMedium,
      ),
      progressIndicatorTheme: ProgressIndicatorThemeData(
        color: primary,
        linearTrackColor: scheme.outlineVariant,
        borderRadius: BorderRadius.circular(16),
      ),
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        backgroundColor: scheme.inverseSurface,
        contentTextStyle: textTheme.bodyMedium!.copyWith(
          color: scheme.onInverseSurface,
        ),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      ),
    );
  }
}
