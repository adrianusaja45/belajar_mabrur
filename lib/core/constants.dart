import 'package:flutter/material.dart';

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
  static const int zegoAppID = 1693455749;
  static const String zegoAppSign =
      "7788285c1340e7587298498be7f43d43e376b911688f8b984d8fe74f95bff6a5";
}
