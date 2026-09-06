import 'package:flutter/material.dart';

abstract final class TimerColors {
  static const background = Color(0xFFF8F6F2);
  static const ink = Color(0xFF283D35);
  static const muted = Color(0xFF7D837B);
  static const orange = Color(0xFFE87C46);
  static const line = Color(0xFFE9E8E0);
  static const cream = Color(0xFFF1EBDE);
}

final timerTheme = ThemeData(
  useMaterial3: true,
  scaffoldBackgroundColor: TimerColors.background,
  colorScheme: ColorScheme.fromSeed(
    seedColor: TimerColors.orange,
    primary: TimerColors.orange,
    secondary: TimerColors.ink,
    surface: TimerColors.background,
    onSurface: TimerColors.ink,
  ),
  fontFamilyFallback: const [
    'Noto Sans CJK SC',
    'Microsoft YaHei',
    'sans-serif',
  ],
  appBarTheme: const AppBarTheme(
    backgroundColor: TimerColors.background,
    foregroundColor: TimerColors.ink,
    elevation: 0,
  ),
  textTheme: const TextTheme(
    headlineMedium: TextStyle(fontWeight: FontWeight.w800, letterSpacing: -1),
    titleLarge: TextStyle(fontWeight: FontWeight.w700, fontSize: 21),
    titleMedium: TextStyle(fontWeight: FontWeight.w700, fontSize: 17),
    bodyMedium: TextStyle(fontSize: 14, height: 1.5),
  ).apply(bodyColor: TimerColors.ink, displayColor: TimerColors.ink),
  filledButtonTheme: FilledButtonThemeData(
    style: FilledButton.styleFrom(
      minimumSize: const Size(48, 54),
      textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
    ),
  ),
  inputDecorationTheme: InputDecorationTheme(
    filled: true,
    fillColor: TimerColors.background,
    border: OutlineInputBorder(
      borderRadius: BorderRadius.circular(16),
      borderSide: BorderSide.none,
    ),
    focusedBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(16),
      borderSide: const BorderSide(color: TimerColors.orange, width: 1.5),
    ),
  ),
  snackBarTheme: SnackBarThemeData(
    behavior: SnackBarBehavior.floating,
    backgroundColor: TimerColors.ink,
    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
  ),
);
