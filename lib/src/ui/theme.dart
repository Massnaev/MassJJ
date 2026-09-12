import 'package:flutter/material.dart';

ThemeData buildAppTheme() {
  const ink = Color(0xFF17201C);
  const paper = Color(0xFFF4F1E9);
  const moss = Color(0xFF315C49);
  const line = Color(0xFFD8D4C9);

  final scheme = ColorScheme.fromSeed(
    seedColor: moss,
    brightness: Brightness.light,
    surface: paper,
  );
  return ThemeData(
    useMaterial3: true,
    colorScheme: scheme,
    scaffoldBackgroundColor: paper,
    fontFamily: 'Segoe UI',
    dividerColor: line,
    textTheme: const TextTheme(
      displaySmall: TextStyle(
        color: ink,
        fontSize: 46,
        height: 1.04,
        fontWeight: FontWeight.w700,
        letterSpacing: -1.7,
      ),
      headlineLarge: TextStyle(
        color: ink,
        fontSize: 34,
        height: 1.1,
        fontWeight: FontWeight.w700,
        letterSpacing: -1.1,
      ),
      headlineSmall: TextStyle(
        color: ink,
        fontSize: 22,
        fontWeight: FontWeight.w700,
        letterSpacing: -0.35,
      ),
      titleMedium: TextStyle(color: ink, fontWeight: FontWeight.w600),
      bodyLarge: TextStyle(color: ink, height: 1.4),
      bodyMedium: TextStyle(color: Color(0xFF4D5752), height: 1.4),
    ),
    cardTheme: const CardThemeData(
      elevation: 0,
      color: Color(0xFFFBF9F3),
      margin: EdgeInsets.zero,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.all(Radius.circular(16)),
        side: BorderSide(color: line),
      ),
    ),
    inputDecorationTheme: const InputDecorationTheme(
      filled: true,
      fillColor: Color(0xFFFBF9F3),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.all(Radius.circular(16)),
        borderSide: BorderSide(color: line),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.all(Radius.circular(16)),
        borderSide: BorderSide(color: line),
      ),
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        minimumSize: const Size(0, 48),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        textStyle: const TextStyle(fontWeight: FontWeight.w700),
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        minimumSize: const Size(0, 48),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        textStyle: const TextStyle(fontWeight: FontWeight.w600),
      ),
    ),
  );
}
