import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';

class AppConstants {
  // --- KONFIGURASI WARNA (HEX) ---

  // Warna Utama (Merah Albirr)
  static const Color primaryColor = Color(0xFFA01C1C);

  // Warna Aksen/Secondary (Bisa disamakan atau dibedakan)
  static const Color secondaryColor = Color(0xFFA01C1C);

  // Warna Background
  static const Color backgroundColor = Colors.white;
  static const Color surfaceColor =
      Color(0xFFF5F5F5); // Abu-abu sangat muda untuk Card

  // Warna Text
  static const Color textPrimary = Colors.black87;
  static const Color textSecondary = Colors.grey;
  static const Color textWhite = Colors.white;

  // Warna Status
  static const Color errorColor = Colors.red;
  static const Color successColor = Colors.green;
  static const Color warningColor = Colors.amber;

  // --- ZEGO CLOUD CONFIG ---
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
