import 'package:flutter/material.dart';

class AppColors {
  static const red = Color(0xFFE10600);
  static const redDark = Color(0xFFB00500);
  static const white = Colors.white;
  static const ink = Color(0xFF141414);
  static const muted = Color(0xFF6B6B6B);
  static const faint = Color(0xFFA0A0A6);
  static const chevron = Color(0xFFB5B5BB);
  static const bg = Color(0xFFF6F6F7);
  static const redTint = Color(0xFFFDECEB);
  static const border = Color(0xFFECECEE);
}

class AppAssets {
  static const logo = 'assets/images/aoj_logo.png';
  static const mark = 'assets/images/aoj_mark.png';
  static const appIcon = 'assets/icon/mark.png';
  static const onboardingBg = 'assets/images/onboarding_site.jpg';
}

class AppTheme {
  static ThemeData get light {
    return ThemeData(
      useMaterial3: true,
      fontFamily: 'Poppins',
      colorScheme: ColorScheme.fromSeed(
        seedColor: AppColors.red,
        primary: AppColors.red,
        surface: AppColors.white,
      ),
      scaffoldBackgroundColor: AppColors.white,
    );
  }
}
