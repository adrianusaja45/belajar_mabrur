import 'package:flutter/material.dart';

class AppConstants {
  // --- KONFIGURASI WARNA (HEX) ---
  
  // Warna Utama (Merah Albirr)
  static const Color primaryColor = Color(0xFFA01C1C);
  
  // Warna Aksen/Secondary (Bisa disamakan atau dibedakan)
  static const Color secondaryColor = Color(0xFFA01C1C);

  // Warna Background
  static const Color backgroundColor = Colors.white;
  static const Color surfaceColor = Color(0xFFF5F5F5); // Abu-abu sangat muda untuk Card

  // Warna Text
  static const Color textPrimary = Colors.black87;
  static const Color textSecondary = Colors.grey;
  static const Color textWhite = Colors.white;

  // Warna Status
  static const Color errorColor = Colors.red;
  static const Color successColor = Colors.green;
  static const Color warningColor = Colors.amber;

  // --- ZEGO CLOUD CONFIG ---
  static const int zegoAppID = 331924508;
  static const String zegoAppSign = "6b3e9cfa30bcd9589b1e72e4de8e01dde3784c75d0fa02ca425a1fec31428890";
}