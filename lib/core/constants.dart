import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';

import 'theme/app_theme.dart';

class AppConstants {
  static const Color primaryColor = AppColors.primary;
  static const Color secondaryColor = AppColors.accentGold;

  static const Color backgroundColor = AppColors.background;
  static const Color surfaceColor = AppColors.surface;

  static const Color textPrimary = AppColors.textPrimary;
  static const Color textSecondary = AppColors.textSecondary;
  static const Color textWhite = AppColors.textOnPrimary;

  static const Color errorColor = AppColors.error;
  static const Color successColor = AppColors.success;
  static const Color warningColor = AppColors.warning;

  static int get zegoAppID {
    final envVal = dotenv.env['ZEGO_APP_ID'];
    if (envVal != null) {
      return int.tryParse(envVal) ?? 1693455749;
    }
    return const int.fromEnvironment('ZEGO_APP_ID', defaultValue: 1693455749);
  }

  static String get zegoAppSign =>
      dotenv.env['ZEGO_APP_SIGN'] ??
      const String.fromEnvironment('ZEGO_APP_SIGN', defaultValue: "");
}
