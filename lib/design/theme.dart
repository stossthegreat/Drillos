import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'tokens.dart';

ThemeData buildDarkTheme() {
  final baseText = GoogleFonts.inter(
    color: DSXColors.textPrimary,
    fontWeight: FontWeight.w600,
    letterSpacing: -0.2,
  );

  return ThemeData(
    brightness: Brightness.dark,
    scaffoldBackgroundColor: DSXColors.base,
    colorScheme: const ColorScheme.dark().copyWith(
      surface: DSXColors.base,
      primary: DSXColors.accent,
      secondary: DSXColors.warn,
      error: DSXColors.danger,
    ),
    textTheme: TextTheme(
      displayLarge: baseText.copyWith(fontSize: 32, fontWeight: FontWeight.w800),
      displayMedium: baseText.copyWith(fontSize: 24, fontWeight: FontWeight.w800),
      titleLarge: baseText.copyWith(fontSize: 20, fontWeight: FontWeight.w800),
      titleMedium: baseText.copyWith(fontSize: 16, fontWeight: FontWeight.w700),
      bodyLarge: baseText.copyWith(fontSize: 14, fontWeight: FontWeight.w600),
      bodyMedium: baseText.copyWith(fontSize: 13, fontWeight: FontWeight.w600, color: DSXColors.textSecondary),
      labelLarge: baseText.copyWith(fontSize: 12, fontWeight: FontWeight.w700),
    ),
    useMaterial3: true,
    appBarTheme: const AppBarTheme(
      backgroundColor: Colors.transparent,
      surfaceTintColor: Colors.transparent,
      elevation: 0,
      centerTitle: true,
    ),
  );
} 