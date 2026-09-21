import 'package:flutter/material.dart';

/// Product colors shared by the Flutter UI and the approved design mock-up.
abstract final class AppColors {
  static const canvas = Color(0xFFFFFFFF);
  static const surface = Color(0xFFFFFFFF);
  static const raised = Color(0xFFFFFFFF);
  static const interactive = Color(0xFFEEF2F5);
  static const line = Color(0xFFE4E9ED);
  static const text = Color(0xFF17212B);
  static const muted = Color(0xFF6D7882);
  static const faint = Color(0xFF9AA4AD);
  static const accent = Color(0xFF2B9FD3);
  static const accentSoft = Color(0xFF5CB9DE);
  static const accentDeep = Color(0xFF197EAF);
  static const accentPale = Color(0xFFDDF2FB);
  static const success = Color(0xFF36A66A);
  static const queued = Color(0xFFE89B26);
  static const error = Color(0xFFD94A56);
}

ThemeData buildAppTheme() {
  const scheme = ColorScheme.light(
    primary: AppColors.accent,
    onPrimary: Colors.white,
    primaryContainer: AppColors.accentDeep,
    onPrimaryContainer: Colors.white,
    secondary: AppColors.accentSoft,
    onSecondary: Colors.white,
    surface: AppColors.surface,
    onSurface: AppColors.text,
    error: AppColors.error,
    onError: Colors.white,
    outline: AppColors.line,
    outlineVariant: AppColors.line,
  );

  const baseText = TextStyle(
    color: AppColors.text,
    fontFamily: 'Segoe UI Variable',
    height: 1.35,
  );

  return ThemeData(
    useMaterial3: true,
    brightness: Brightness.light,
    colorScheme: scheme,
    scaffoldBackgroundColor: AppColors.canvas,
    canvasColor: AppColors.canvas,
    dividerColor: AppColors.line,
    splashFactory: InkSparkle.splashFactory,
    textTheme: TextTheme(
      displaySmall: baseText.copyWith(
        fontSize: 40,
        height: 1.06,
        fontWeight: FontWeight.w800,
        letterSpacing: -1.5,
      ),
      headlineLarge: baseText.copyWith(
        fontSize: 30,
        height: 1.1,
        fontWeight: FontWeight.w800,
        letterSpacing: -0.9,
      ),
      headlineMedium: baseText.copyWith(
        fontSize: 24,
        height: 1.15,
        fontWeight: FontWeight.w800,
        letterSpacing: -0.55,
      ),
      headlineSmall: baseText.copyWith(
        fontSize: 20,
        fontWeight: FontWeight.w700,
        letterSpacing: -0.3,
      ),
      titleLarge: baseText.copyWith(fontSize: 18, fontWeight: FontWeight.w700),
      titleMedium: baseText.copyWith(fontWeight: FontWeight.w700),
      bodyLarge: baseText.copyWith(fontSize: 15, color: AppColors.text),
      bodyMedium: baseText.copyWith(fontSize: 14, color: AppColors.muted),
      bodySmall: baseText.copyWith(fontSize: 12, color: AppColors.muted),
      labelLarge: baseText.copyWith(fontSize: 14, fontWeight: FontWeight.w700),
      labelMedium: baseText.copyWith(fontSize: 12, fontWeight: FontWeight.w700),
    ),
    appBarTheme: const AppBarTheme(
      elevation: 0,
      scrolledUnderElevation: 0,
      backgroundColor: AppColors.canvas,
      foregroundColor: AppColors.text,
      centerTitle: false,
      titleTextStyle: TextStyle(
        color: AppColors.text,
        fontFamily: 'Segoe UI Variable',
        fontSize: 20,
        fontWeight: FontWeight.w700,
      ),
      iconTheme: IconThemeData(size: 22, color: AppColors.text),
    ),
    iconTheme: const IconThemeData(color: AppColors.text, size: 22),
    cardTheme: const CardThemeData(
      elevation: 0,
      color: AppColors.raised,
      margin: EdgeInsets.zero,
      clipBehavior: Clip.antiAlias,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.all(Radius.circular(18)),
        side: BorderSide(color: AppColors.line),
      ),
    ),
    inputDecorationTheme: const InputDecorationTheme(
      filled: true,
      fillColor: AppColors.raised,
      hintStyle: TextStyle(color: AppColors.muted),
      labelStyle: TextStyle(color: AppColors.muted),
      contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.all(Radius.circular(14)),
        borderSide: BorderSide.none,
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.all(Radius.circular(14)),
        borderSide: BorderSide.none,
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.all(Radius.circular(14)),
        borderSide: BorderSide(color: AppColors.accentSoft, width: 1.4),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.all(Radius.circular(14)),
        borderSide: BorderSide(color: AppColors.error),
      ),
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        minimumSize: const Size(0, 48),
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
        backgroundColor: AppColors.accent,
        foregroundColor: Colors.white,
        disabledBackgroundColor: AppColors.interactive,
        disabledForegroundColor: AppColors.faint,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
        textStyle: const TextStyle(
          fontFamily: 'Segoe UI Variable',
          fontWeight: FontWeight.w700,
        ),
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        minimumSize: const Size(0, 48),
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
        foregroundColor: AppColors.text,
        side: const BorderSide(color: AppColors.line),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
        textStyle: const TextStyle(
          fontFamily: 'Segoe UI Variable',
          fontWeight: FontWeight.w700,
        ),
      ),
    ),
    textButtonTheme: TextButtonThemeData(
      style: TextButton.styleFrom(
        minimumSize: const Size(44, 44),
        foregroundColor: AppColors.accentSoft,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        textStyle: const TextStyle(fontWeight: FontWeight.w700),
      ),
    ),
    iconButtonTheme: IconButtonThemeData(
      style: IconButton.styleFrom(
        minimumSize: const Size(44, 44),
        foregroundColor: AppColors.text,
        backgroundColor: AppColors.interactive,
        shape: const CircleBorder(),
      ),
    ),
    navigationBarTheme: NavigationBarThemeData(
      height: 64,
      elevation: 0,
      backgroundColor: AppColors.surface,
      indicatorColor: Colors.transparent,
      iconTheme: WidgetStateProperty.resolveWith(
        (states) => IconThemeData(
          size: 22,
          color: states.contains(WidgetState.selected)
              ? AppColors.accent
              : AppColors.muted,
        ),
      ),
      labelTextStyle: WidgetStateProperty.resolveWith(
        (states) => TextStyle(
          color: states.contains(WidgetState.selected)
              ? AppColors.accentDeep
              : AppColors.muted,
          fontSize: 11,
          fontWeight: states.contains(WidgetState.selected)
              ? FontWeight.w700
              : FontWeight.w500,
        ),
      ),
    ),
    navigationRailTheme: const NavigationRailThemeData(
      elevation: 0,
      backgroundColor: AppColors.surface,
      indicatorColor: AppColors.accentPale,
      selectedIconTheme: IconThemeData(color: AppColors.accent),
      unselectedIconTheme: IconThemeData(color: AppColors.muted),
      selectedLabelTextStyle: TextStyle(
        color: AppColors.text,
        fontWeight: FontWeight.w700,
      ),
      unselectedLabelTextStyle: TextStyle(color: AppColors.muted),
    ),
    segmentedButtonTheme: SegmentedButtonThemeData(
      style: ButtonStyle(
        backgroundColor: WidgetStateProperty.resolveWith(
          (states) => states.contains(WidgetState.selected)
              ? AppColors.accentPale
              : AppColors.interactive,
        ),
        foregroundColor: WidgetStateProperty.resolveWith(
          (states) => states.contains(WidgetState.selected)
              ? AppColors.accentDeep
              : AppColors.muted,
        ),
        side: const WidgetStatePropertyAll(BorderSide.none),
        minimumSize: const WidgetStatePropertyAll(Size(0, 44)),
        shape: WidgetStatePropertyAll(
          RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
      ),
    ),
    checkboxTheme: CheckboxThemeData(
      fillColor: WidgetStateProperty.resolveWith(
        (states) => states.contains(WidgetState.selected)
            ? AppColors.accent
            : AppColors.interactive,
      ),
      side: const BorderSide(color: AppColors.line),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
    ),
    bottomSheetTheme: const BottomSheetThemeData(
      backgroundColor: AppColors.raised,
      modalBackgroundColor: AppColors.raised,
      showDragHandle: true,
      dragHandleColor: AppColors.faint,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
    ),
    snackBarTheme: const SnackBarThemeData(
      backgroundColor: AppColors.text,
      contentTextStyle: TextStyle(color: Colors.white),
      behavior: SnackBarBehavior.floating,
    ),
  );
}
